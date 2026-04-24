import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:vittara_fin_os/utils/date_formatter.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/account_model.dart';
import 'package:vittara_fin_os/logic/accounts_controller.dart';
import 'package:vittara_fin_os/logic/brokers_controller.dart';
import 'package:vittara_fin_os/logic/payment_apps_controller.dart';
import 'package:vittara_fin_os/logic/transaction_model.dart';
import 'package:vittara_fin_os/logic/transactions_controller.dart';
import 'package:vittara_fin_os/utils/id_generator.dart';
import 'package:vittara_fin_os/ui/manage/account_wizard.dart';
import 'package:vittara_fin_os/ui/manage/payment_apps_screen.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/styles/responsive_utils.dart';
import 'package:vittara_fin_os/ui/widgets/animations.dart';
import 'package:vittara_fin_os/ui/widgets/app_date_picker.dart';
import 'package:vittara_fin_os/ui/widgets/toast_notification.dart';

class TransferWizard extends StatefulWidget {
  const TransferWizard({super.key});

  @override
  State<TransferWizard> createState() => _TransferWizardState();
}

class _TransferWizardState extends State<TransferWizard> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  static const int _totalSteps = 8;

  // Step data
  Account? _sourceAccount;
  Account? _destinationAccount;
  DateTime _selectedTransferDate = DateTime.now();
  final _amountController = TextEditingController();
  final _chargesController = TextEditingController();
  final _appWalletAmountController = TextEditingController();
  final _cashbackAmountController = TextEditingController();
  String? _selectedPaymentApp;
  // For cash transfers: 'direct' (hand-to-hand) or 'atm' (ATM withdrawal/deposit)
  String _cashMethod = 'direct';
  Account? _cashbackAccount;
  bool _cashbackToPaymentApp = false;
  bool _paymentAppHasWallet = false;
  double _selectedPaymentAppWalletBalance = 0.0;

  @override
  void initState() {
    super.initState();
    // Lock to portrait for the duration of this wizard so orientation changes
    // cannot rebuild the form and clear entered data.
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    _chargesController.addListener(() => setState(() {}));
    _appWalletAmountController.addListener(() => setState(() {}));
    _cashbackAmountController.addListener(() => setState(() {}));
    _amountController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _pageController.dispose();
    _amountController.dispose();
    _chargesController.dispose();
    _appWalletAmountController.dispose();
    _cashbackAmountController.dispose();
    // Restore all orientations when the wizard is dismissed.
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
        super.dispose();
  }

  /// True when either account is a cash account (ATM/direct instead of payment app)
  bool get _involvesCash =>
      _sourceAccount?.type == AccountType.cash ||
      _destinationAccount?.type == AccountType.cash;

  /// Steps to skip when cash accounts are involved: payment app (3) and app wallet (4)
  static const _cashSkipSteps = {3, 4};

  void _nextStep() {
    FocusManager.instance.primaryFocus?.unfocus();
    int next = _currentStep + 1;
    // Skip payment app + app wallet steps for cash transfers
    if (_involvesCash) {
      while (_cashSkipSteps.contains(next) && next < _totalSteps) {
        next++;
      }
    }
    if (next < _totalSteps) {
      final stepsToAdvance = next - _currentStep;
      for (var i = 0; i < stepsToAdvance; i++) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOutCubic,
        );
      }
      setState(() => _currentStep = next);
    } else {
      _finishTransfer();
    }
  }

  void _prevStep() {
    int prev = _currentStep - 1;
    // Skip payment app + app wallet steps going back for cash transfers
    if (_involvesCash) {
      while (_cashSkipSteps.contains(prev) && prev > 0) {
        prev--;
      }
    }
    if (prev >= 0) {
      final stepsBack = _currentStep - prev;
      for (var i = 0; i < stepsBack; i++) {
        _pageController.previousPage(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOutCubic,
        );
      }
      setState(() => _currentStep = prev);
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _finishTransfer() async {
    final accountsController =
        Provider.of<AccountsController>(context, listen: false);
    final transactionsController =
        Provider.of<TransactionsController>(context, listen: false);
    final paymentAppsController =
        Provider.of<PaymentAppsController>(context, listen: false);

    // Prevent transfer to same account
    if (_sourceAccount != null &&
        _destinationAccount != null &&
        _sourceAccount!.id == _destinationAccount!.id) {
      toast.showError('Source and destination accounts must be different');
      return;
    }

    // Calculate total deduction from source
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    final charges = double.tryParse(_chargesController.text) ?? 0.0;
    final appWalletAmount =
        double.tryParse(_appWalletAmountController.text) ?? 0.0;
    final cashbackAmount =
        double.tryParse(_cashbackAmountController.text) ?? 0.0;

    // Calculate deductions from source and app wallet
    final deductFromSource = amount - appWalletAmount;

    if (appWalletAmount > amount) {
      toast.showError('App wallet amount cannot exceed transfer amount');
      return;
    }

    if (_sourceAccount != null &&
        deductFromSource + charges > _sourceAccount!.balance) {
      toast.showWarning('Balance will go negative in ${_sourceAccount!.name}');
    }

    if (appWalletAmount > 0 && _selectedPaymentApp != null) {
      final app = paymentAppsController.getAppByName(_selectedPaymentApp!);
      final walletBalance = (app?['walletBalance'] as num?)?.toDouble() ?? 0.0;
      if (appWalletAmount > walletBalance) {
        toast.showWarning('Payment app wallet balance will go negative');
      }
    }

    Account? selectedCashbackAccount;
    if (_cashbackAccount != null) {
      for (final account in _cashbackEligibleAccounts()) {
        if (account.id == _cashbackAccount!.id) {
          selectedCashbackAccount = account;
          break;
        }
      }
    }
    final canCreditCashbackToApp = _cashbackToPaymentApp &&
        _paymentAppHasWallet &&
        (_selectedPaymentApp?.isNotEmpty ?? false);

    if (cashbackAmount > 0 &&
        selectedCashbackAccount == null &&
        !canCreditCashbackToApp) {
      toast.showError('Select where cashback should be credited');
      return;
    }

    // I12: Warn when transferring TO a credit card / pay-later account
    if (_destinationAccount != null &&
        (_destinationAccount!.type == AccountType.credit ||
            _destinationAccount!.type == AccountType.payLater)) {
      final proceed = await showCupertinoDialog<bool>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('Transferring to Credit Account'),
          content: const Text(
              'You are transferring money to a credit card or pay-later account. This will reduce the outstanding balance. Continue?'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Continue'),
            ),
          ],
        ),
      );
      if (proceed != true || !mounted) return;
    }

    // Update source account
    if (_sourceAccount != null) {
      final updatedSource = _sourceAccount!.copyWith(
        balance: _sourceAccount!.balance - deductFromSource - charges,
      );
      accountsController.updateAccount(updatedSource);
    }

    // Update destination account
    if (_destinationAccount != null) {
      final updatedDestination = _destinationAccount!.copyWith(
        balance: _destinationAccount!.balance + amount,
      );
      accountsController.updateAccount(updatedDestination);
    }

    // Update payment app wallet if used
    if (appWalletAmount > 0 && _selectedPaymentApp != null) {
      paymentAppsController.adjustWalletBalanceByName(
          _selectedPaymentApp!, -appWalletAmount);
    }

    // Add cashback to cashback account
    if (cashbackAmount > 0) {
      if (selectedCashbackAccount != null) {
        final updatedCashback = selectedCashbackAccount.copyWith(
          balance: selectedCashbackAccount.balance + cashbackAmount,
        );
        accountsController.updateAccount(updatedCashback);
      } else if (canCreditCashbackToApp && _selectedPaymentApp != null) {
        paymentAppsController.adjustWalletBalanceByName(
            _selectedPaymentApp!, cashbackAmount);
      }
    }

    // Create transaction record
    final transaction = Transaction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: TransactionType.transfer,
      description: _transferDescription(),
      dateTime: _selectedTransferDate,
      amount: amount,
      sourceAccountId: _sourceAccount?.id,
      sourceAccountName: _sourceAccount?.name,
      destinationAccountId: _destinationAccount?.id,
      destinationAccountName: _destinationAccount?.name,
      charges: charges > 0 ? charges : null,
      paymentAppName: _selectedPaymentApp,
      appWalletAmount: appWalletAmount > 0 ? appWalletAmount : null,
      cashbackAmount: cashbackAmount > 0 ? cashbackAmount : null,
      cashbackAccountId: selectedCashbackAccount?.id,
      cashbackAccountName: selectedCashbackAccount?.name,
      metadata: {
        'transferFlowType': _cashFlowType(),
        'transferDate': _selectedTransferDate.toIso8601String(),
        'cashbackFlow': cashbackAmount > 0
            ? (canCreditCashbackToApp ? 'paymentApp' : 'bank')
            : 'bank',
        'transferRef': IdGenerator.next(prefix: 'tref'),
        if (_involvesCash) 'cashMethod': _cashMethod,
        if (_sourceAccount != null)
          'sourceBalanceAfter': _sourceAccount!.balance - deductFromSource - charges,
        if (_sourceAccount?.creditLimit != null)
          'sourceCreditLimit': _sourceAccount!.creditLimit,
        if (_destinationAccount != null)
          'destBalanceAfter': _destinationAccount!.balance + amount,
        if (_destinationAccount?.creditLimit != null)
          'destCreditLimit': _destinationAccount!.creditLimit,
      },
    );

    transactionsController.addTransaction(transaction);

    Haptics.success();
    toast.showSuccess('Transfer completed successfully');
    Navigator.pop(context);
  }

  bool _canProceed() {
    switch (_currentStep) {
      case 0: // Source account
        return _sourceAccount != null;
      case 1: // Destination account
        return _destinationAccount != null &&
            _destinationAccount!.id != _sourceAccount!.id;
      case 2: // Amount
        final amount = double.tryParse(_amountController.text) ?? 0.0;
        return amount > 0;
      case 3: // Payment app
        return _selectedPaymentApp != null;
      case 4: // App wallet amount
        return true;
      case 5: // Cashback
        final cashbackAmount =
            double.tryParse(_cashbackAmountController.text) ?? 0.0;
        if (cashbackAmount <= 0) return true;

        final hasSelectedEligibleAccount = _cashbackAccount != null &&
            _isEligibleCashbackAccount(_cashbackAccount!);
        final canCreditToApp = _cashbackToPaymentApp &&
            _paymentAppHasWallet &&
            (_selectedPaymentApp?.isNotEmpty ?? false);
        return hasSelectedEligibleAccount || canCreditToApp;
      case 6: // Transfer date
        return true;
      case 7: // Review
        return true;
      default:
        return false;
    }
  }

  List<Account> _cashbackEligibleAccounts() {
    final accounts = <Account>[];
    final seenIds = <String>{};

    void addIfPresent(Account? account) {
      if (account == null || seenIds.contains(account.id)) return;
      seenIds.add(account.id);
      accounts.add(account);
    }

    addIfPresent(_sourceAccount);
    addIfPresent(_destinationAccount);
    return accounts;
  }

  bool _isEligibleCashbackAccount(Account account) {
    return _cashbackEligibleAccounts()
        .any((candidate) => candidate.id == account.id);
  }

  String _cashbackDestinationName() {
    if (_cashbackToPaymentApp &&
        _paymentAppHasWallet &&
        (_selectedPaymentApp?.isNotEmpty ?? false)) {
      return '${_selectedPaymentApp!} Wallet';
    }
    if (_cashbackAccount != null &&
        _isEligibleCashbackAccount(_cashbackAccount!)) {
      return _cashbackAccount!.name;
    }
    return 'Not selected';
  }

  String _cashFlowType() {
    final sourceType = _sourceAccount?.type;
    final destinationType = _destinationAccount?.type;
    if (sourceType == AccountType.cash && destinationType != AccountType.cash) {
      return 'cash_deposit';
    }
    if (destinationType == AccountType.cash && sourceType != AccountType.cash) {
      return 'cash_withdrawal';
    }
    if (destinationType == AccountType.cash && sourceType == AccountType.cash) {
      return 'cash_to_cash';
    }
    return 'standard';
  }

  String _transferDescription() {
    final flowType = _cashFlowType();
    if (flowType == 'cash_withdrawal') {
      return 'Cash withdrawal: ${_sourceAccount?.name} → ${_destinationAccount?.name}';
    }
    if (flowType == 'cash_deposit') {
      return 'Cash deposit: ${_sourceAccount?.name} → ${_destinationAccount?.name}';
    }
    return '${_sourceAccount?.name} → ${_destinationAccount?.name}';
  }

  IconData _iconForAccount(Account account) {
    switch (account.type) {
      case AccountType.investment:
        return CupertinoIcons.chart_bar_square_fill;
      case AccountType.credit:
      case AccountType.payLater:
        return CupertinoIcons.creditcard_fill;
      case AccountType.wallet:
        return CupertinoIcons.square_stack_3d_down_right_fill;
      case AccountType.cash:
        return CupertinoIcons.money_dollar_circle_fill;
      case AccountType.savings:
      case AccountType.current:
        return CupertinoIcons.building_2_fill;
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppStyles.getBackground(context),
      navigationBar: AppStyles.isLandscape(context) ? null : CupertinoNavigationBar(
        middle: const Text('Transfer Money'),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _prevStep,
          child: Icon(
              _currentStep == 0 ? CupertinoIcons.xmark : CupertinoIcons.back),
        ),
        backgroundColor: AppStyles.getBackground(context),
        border: null,
      ),
      child: SafeArea(
        child: Column(
          children: [
            _buildProgressBar(),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildSourceAccountStep(),
                  _buildDestinationAccountStep(),
                  _buildAmountStep(),
                  _buildPaymentAppStep(),
                  _buildAppWalletStep(),
                  _buildCashbackStep(),
                  _buildTransferDateStep(),
                  _buildReviewStep(),
                ],
              ),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: List.generate(_totalSteps, (index) {
          final isActive = index <= _currentStep;
          return Expanded(
            child: Container(
              height: 4,
              margin: EdgeInsets.only(right: index == _totalSteps - 1 ? 0 : 8),
              decoration: BoxDecoration(
                color: isActive
                    ? CupertinoColors.systemBlue
                    : CupertinoColors.systemGrey.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSourceAccountStep() {
    return Consumer2<AccountsController, BrokersController>(
      builder: (context, accountsController, brokersController, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(Spacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select Source Account',
                style: AppStyles.titleStyle(context).copyWith(fontSize: RT.largeTitle(context)),
              ),
              const SizedBox(height: Spacing.sm),
              Text(
                'Where will the money be deducted from?',
                style:
                    TextStyle(color: AppStyles.getSecondaryTextColor(context)),
              ),
              const SizedBox(height: Spacing.xxxl),
              Column(
                children: accountsController.accounts.map((account) {
                  final isSelected = _sourceAccount?.id == account.id;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _sourceAccount = account;
                        // Auto-select broker if source is Demat/Investment
                        if (account.type == AccountType.investment) {
                          _selectedPaymentApp = account.bankName;
                          _paymentAppHasWallet =
                              false; // Brokers don't have wallets
                        }
                      });
                      _nextStep();
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(Spacing.lg),
                      decoration: BoxDecoration(
                        color: AppStyles.getCardColor(context),
                        borderRadius: BorderRadius.circular(Radii.md),
                        border: isSelected
                            ? Border.all(
                                color: CupertinoColors.systemBlue, width: 2)
                            : Border.all(
                                color: AppStyles.getSecondaryTextColor(context)
                                    .withValues(alpha: 0.1),
                                width: 1,
                              ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(Spacing.md),
                            decoration: BoxDecoration(
                              color: account.color.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _iconForAccount(account),
                              color: account.color,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: Spacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  account.name,
                                  style: AppStyles.titleStyle(context)
                                      .copyWith(fontSize: TypeScale.headline),
                                ),
                                const SizedBox(height: Spacing.xs),
                                Text(
                                  '₹${account.balance.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: TypeScale.footnote,
                                    color: AppStyles.getSecondaryTextColor(
                                        context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            const Icon(
                              CupertinoIcons.checkmark_circle_fill,
                              color: CupertinoColors.systemBlue,
                              size: 24,
                            ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: Spacing.xxl),
              BouncyButton(
                onPressed: () => _showAddAccountModal(
                    context, accountsController,
                    isSource: true),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(Radii.md),
                    border: Border.all(
                      color: CupertinoColors.systemBlue,
                      width: 1.5,
                    ),
                  ),
                  child: const Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(CupertinoIcons.add,
                            color: CupertinoColors.systemBlue),
                        SizedBox(width: Spacing.sm),
                        Text(
                          'Add Account',
                          style: TextStyle(
                            color: CupertinoColors.systemBlue,
                            fontSize: TypeScale.headline,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAddAccountModal(
      BuildContext context, AccountsController accountsController,
      {bool isSource = true}) {
    Navigator.push<Account>(
      context,
      FadeScalePageRoute(
        page: const AccountWizard(isInvestment: false),
      ),
    ).then((result) {
      if (result != null) {
        accountsController.addAccount(result);
        if (isSource) {
          setState(() => _sourceAccount = result);
        } else {
          setState(() => _destinationAccount = result);
        }
        _nextStep();
      }
    });
  }

  Widget _buildDestinationAccountStep() {
    return Consumer<AccountsController>(
      builder: (context, accountsController, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(Spacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select Receiving Account',
                style: AppStyles.titleStyle(context).copyWith(fontSize: RT.largeTitle(context)),
              ),
              const SizedBox(height: Spacing.sm),
              Text(
                'Where should the money go?',
                style:
                    TextStyle(color: AppStyles.getSecondaryTextColor(context)),
              ),
              const SizedBox(height: Spacing.xxxl),
              Column(
                children: accountsController.accounts
                    .where((account) => account.id != _sourceAccount?.id)
                    .map((account) {
                  final isSelected = _destinationAccount?.id == account.id;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _destinationAccount = account);
                      _nextStep();
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(Spacing.lg),
                      decoration: BoxDecoration(
                        color: AppStyles.getCardColor(context),
                        borderRadius: BorderRadius.circular(Radii.md),
                        border: isSelected
                            ? Border.all(
                                color: CupertinoColors.systemBlue, width: 2)
                            : Border.all(
                                color: AppStyles.getSecondaryTextColor(context)
                                    .withValues(alpha: 0.1),
                                width: 1,
                              ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(Spacing.md),
                            decoration: BoxDecoration(
                              color: account.color.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _iconForAccount(account),
                              color: account.color,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: Spacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  account.name,
                                  style: AppStyles.titleStyle(context)
                                      .copyWith(fontSize: TypeScale.headline),
                                ),
                                const SizedBox(height: Spacing.xs),
                                Text(
                                  account.bankName,
                                  style: TextStyle(
                                    fontSize: TypeScale.footnote,
                                    color: AppStyles.getSecondaryTextColor(
                                        context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            const Icon(
                              CupertinoIcons.checkmark_circle_fill,
                              color: CupertinoColors.systemBlue,
                              size: 24,
                            ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: Spacing.xxl),
              BouncyButton(
                onPressed: () => _showAddAccountModal(
                    context, accountsController,
                    isSource: false),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(Radii.md),
                    border: Border.all(
                      color: CupertinoColors.systemBlue,
                      width: 1.5,
                    ),
                  ),
                  child: const Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(CupertinoIcons.add,
                            color: CupertinoColors.systemBlue),
                        SizedBox(width: Spacing.sm),
                        Text(
                          'Add Account',
                          style: TextStyle(
                            color: CupertinoColors.systemBlue,
                            fontSize: TypeScale.headline,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAmountStep() {
    final sourceHasCharges = _sourceAccount != null &&
        (_sourceAccount!.type == AccountType.credit ||
            _sourceAccount!.type == AccountType.payLater ||
            _sourceAccount!.type == AccountType.wallet ||
            _sourceAccount!.type == AccountType.investment);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(Spacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Transfer Amount',
            style: AppStyles.titleStyle(context).copyWith(fontSize: RT.largeTitle(context)),
          ),
          const SizedBox(height: Spacing.xxxl),
          Text('Amount to Transfer', style: AppStyles.headerStyle(context)),
          const SizedBox(height: Spacing.md),
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('₹',
                    style: AppStyles.titleStyle(context)
                        .copyWith(fontSize: TypeScale.display)),
                const SizedBox(width: Spacing.sm),
                IntrinsicWidth(
                  child: CupertinoTextField(
                    controller: _amountController,
                    autofocus: _currentStep == 2,
                    placeholder: '0.00',
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    textInputAction: TextInputAction.next,
                    onSubmitted: (_) {
                      if (_canProceed()) _nextStep();
                    },
                    decoration: BoxDecoration(
                      color: AppStyles.getCardColor(context),
                      borderRadius: BorderRadius.circular(Radii.md),
                    ),
                    style: AppStyles.titleStyle(context).copyWith(
                        fontSize: TypeScale.display,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Spacing.xxl),
          if (sourceHasCharges) ...[
            Text('Extra Charges (Optional)',
                style: AppStyles.headerStyle(context)),
            const SizedBox(height: Spacing.xs),
            Text(
              'Charges will be deducted but not credited to any account',
              style: TextStyle(
                  fontSize: TypeScale.footnote,
                  color: AppStyles.getSecondaryTextColor(context)),
            ),
            const SizedBox(height: Spacing.md),
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('₹',
                      style: AppStyles.titleStyle(context)
                          .copyWith(fontSize: RT.largeTitle(context))),
                  const SizedBox(width: Spacing.sm),
                  IntrinsicWidth(
                    child: CupertinoTextField(
                      controller: _chargesController,
                      placeholder: '0.00',
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      textInputAction: TextInputAction.next,
                      decoration: BoxDecoration(
                        color: AppStyles.getCardColor(context),
                        borderRadius: BorderRadius.circular(Radii.md),
                      ),
                      style: AppStyles.titleStyle(context).copyWith(
                          fontSize: RT.largeTitle(context),
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
          // Cash method selector — only for cash account transfers
          if (_involvesCash) ...[
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'How was cash handled?',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppStyles.getSecondaryTextColor(context),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _CashMethodChip(
                        label: 'Direct',
                        icon: CupertinoIcons.hand_draw,
                        selected: _cashMethod == 'direct',
                        onTap: () => setState(() => _cashMethod = 'direct'),
                      ),
                      const SizedBox(width: 10),
                      _CashMethodChip(
                        label: 'ATM',
                        icon: CupertinoIcons.creditcard_fill,
                        selected: _cashMethod == 'atm',
                        onTap: () => setState(() => _cashMethod = 'atm'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaymentAppStep() {
    final isSourceDemat = _sourceAccount?.type == AccountType.investment;

    return Consumer<PaymentAppsController>(
      builder: (context, paymentAppsController, _) {
        final enabledApps = paymentAppsController.enabledApps;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(Spacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isSourceDemat ? 'Broker (Demat)' : 'Payment App',
                style: AppStyles.titleStyle(context).copyWith(fontSize: RT.largeTitle(context)),
              ),
              const SizedBox(height: Spacing.sm),
              Text(
                isSourceDemat
                    ? 'Cannot withdraw from Demat using other apps. Using: ${_sourceAccount!.bankName}'
                    : 'Select one enabled app or choose a new app',
                style:
                    TextStyle(color: AppStyles.getSecondaryTextColor(context)),
              ),
              const SizedBox(height: Spacing.xxxl),
              if (isSourceDemat)
                // Show locked broker for Demat
                Container(
                  padding: const EdgeInsets.all(Spacing.lg),
                  decoration: BoxDecoration(
                    color: AppStyles.gain(context).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(Radii.md),
                    border: Border.all(
                      color: AppStyles.gain(context),
                      width: 2,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        CupertinoIcons.lock_fill,
                        color: AppStyles.gain(context),
                        size: 24,
                      ),
                      const SizedBox(width: Spacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _sourceAccount!.bankName,
                              style: AppStyles.titleStyle(context)
                                  .copyWith(fontSize: TypeScale.headline),
                            ),
                            const SizedBox(height: Spacing.xs),
                            Text(
                              'Auto-selected (Fixed)',
                              style: TextStyle(
                                fontSize: TypeScale.footnote,
                                color: AppStyles.gain(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        CupertinoIcons.checkmark_circle_fill,
                        color: AppStyles.gain(context),
                        size: 24,
                      ),
                    ],
                  ),
                )
              else
                // Show payment apps for other accounts
                Column(
                  children: [
                    if (enabledApps.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Text(
                            'No enabled payment apps. Tap "Select New App".',
                            style: TextStyle(
                                color:
                                    AppStyles.getSecondaryTextColor(context)),
                          ),
                        ),
                      )
                    else
                      Column(
                        children: enabledApps.map((app) {
                          final isSelected = _selectedPaymentApp == app['name'];
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedPaymentApp = app['name'];
                                _paymentAppHasWallet =
                                    app['hasWallet'] ?? false;
                                _selectedPaymentAppWalletBalance =
                                    (app['walletBalance'] as num?)
                                            ?.toDouble() ??
                                        0.0;
                                if (!_paymentAppHasWallet &&
                                    _cashbackToPaymentApp) {
                                  _cashbackToPaymentApp = false;
                                }
                              });
                              _nextStep();
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(Spacing.lg),
                              decoration: BoxDecoration(
                                color: AppStyles.getCardColor(context),
                                borderRadius: BorderRadius.circular(Radii.md),
                                border: isSelected
                                    ? Border.all(
                                        color: CupertinoColors.systemBlue,
                                        width: 2)
                                    : Border.all(
                                        color: AppStyles.getSecondaryTextColor(
                                                context)
                                            .withValues(alpha: 0.1),
                                        width: 1,
                                      ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    CupertinoIcons
                                        .square_stack_3d_down_right_fill,
                                    color: CupertinoColors.systemBlue,
                                    size: 24,
                                  ),
                                  const SizedBox(width: Spacing.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          app['name'],
                                          style: AppStyles.titleStyle(context)
                                              .copyWith(
                                                  fontSize: TypeScale.headline),
                                        ),
                                        const SizedBox(height: Spacing.xs),
                                        Text(
                                          (app['hasWallet'] ?? false)
                                              ? 'Wallet ₹${((app['walletBalance'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)}'
                                              : 'No wallet',
                                          style: TextStyle(
                                            fontSize: TypeScale.footnote,
                                            color:
                                                AppStyles.getSecondaryTextColor(
                                                    context),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isSelected)
                                    const Icon(
                                      CupertinoIcons.checkmark_circle_fill,
                                      color: CupertinoColors.systemBlue,
                                      size: 24,
                                    ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    const SizedBox(height: Spacing.md),
                    BouncyButton(
                      onPressed: () async {
                        final result = await Navigator.of(context)
                            .push<_PaymentAppSelectionResult>(
                          FadeScalePageRoute(
                            page: const _PaymentAppSetupWizard(),
                          ),
                        );
                        if (!mounted) return;
                        if (result != null) {
                          setState(() {
                            _selectedPaymentApp = result.appName;
                            _paymentAppHasWallet = result.hasWallet;
                            _selectedPaymentAppWalletBalance =
                                result.walletBalance;
                            if (!_paymentAppHasWallet) {
                              _appWalletAmountController.clear();
                              if (_cashbackToPaymentApp) {
                                _cashbackToPaymentApp = false;
                              }
                            }
                          });
                          _nextStep();
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color:
                              CupertinoColors.systemBlue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(Radii.md),
                          border: Border.all(
                            color: CupertinoColors.systemBlue,
                            width: 1.5,
                          ),
                        ),
                        child: const Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(CupertinoIcons.add,
                                  color: CupertinoColors.systemBlue),
                              SizedBox(width: Spacing.sm),
                              Text(
                                'Select New App',
                                style: TextStyle(
                                  color: CupertinoColors.systemBlue,
                                  fontSize: TypeScale.headline,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAppWalletStep() {
    final hasWallet = _paymentAppHasWallet && _selectedPaymentApp != null;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(Spacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Amount from App Wallet',
            style: AppStyles.titleStyle(context).copyWith(fontSize: RT.largeTitle(context)),
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            hasWallet
                ? 'How much should come from ${_selectedPaymentApp ?? 'this app'} wallet?'
                : 'Selected app has no wallet. Continue to next step.',
            style: TextStyle(color: AppStyles.getSecondaryTextColor(context)),
          ),
          if (!hasWallet) ...[
            const SizedBox(height: Spacing.xxl),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey6,
                borderRadius: BorderRadius.circular(Radii.md),
              ),
              child: Text(
                'Wallet not enabled for ${_selectedPaymentApp ?? 'selected app'}.',
                style:
                    TextStyle(color: AppStyles.getSecondaryTextColor(context)),
              ),
            ),
          ] else ...[
            const SizedBox(height: Spacing.xxl),
            Text(
              'Available wallet: ₹${_selectedPaymentAppWalletBalance.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: TypeScale.footnote,
                color: AppStyles.getSecondaryTextColor(context),
              ),
            ),
            const SizedBox(height: Spacing.md),
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('₹',
                      style: AppStyles.titleStyle(context)
                          .copyWith(fontSize: RT.largeTitle(context))),
                  const SizedBox(width: Spacing.sm),
                  IntrinsicWidth(
                    child: CupertinoTextField(
                      controller: _appWalletAmountController,
                      autofocus: _currentStep == 4,
                      placeholder: '0.00',
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      textInputAction: TextInputAction.next,
                      onSubmitted: (_) => _nextStep(),
                      decoration: BoxDecoration(
                        color: AppStyles.getCardColor(context),
                        borderRadius: BorderRadius.circular(Radii.md),
                      ),
                      style: AppStyles.titleStyle(context).copyWith(
                          fontSize: RT.largeTitle(context),
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Spacing.sm),
            CupertinoButton(
              onPressed: () async {
                await Navigator.of(context).push(
                  FadeScalePageRoute(page: const PaymentAppsScreen()),
                );
                if (!mounted) return;
                final app = Provider.of<PaymentAppsController>(
                  context,
                  listen: false,
                ).getAppByName(_selectedPaymentApp ?? '');
                setState(() {
                  _selectedPaymentAppWalletBalance =
                      (app?['walletBalance'] as num?)?.toDouble() ?? 0.0;
                  _paymentAppHasWallet = app?['hasWallet'] == true;
                  if (!_paymentAppHasWallet) {
                    _appWalletAmountController.clear();
                    if (_cashbackToPaymentApp) {
                      _cashbackToPaymentApp = false;
                    }
                  }
                });
              },
              child: const Text('Manage wallet balance'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCashbackStep() {
    final eligibleAccounts = _cashbackEligibleAccounts();
    final canCreditToPaymentApp =
        _paymentAppHasWallet && (_selectedPaymentApp?.isNotEmpty ?? false);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(Spacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cashback (Optional)',
            style: AppStyles.titleStyle(context).copyWith(fontSize: RT.largeTitle(context)),
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            'Enter cashback and choose where it should be credited.',
            style: TextStyle(color: AppStyles.getSecondaryTextColor(context)),
          ),
          const SizedBox(height: Spacing.xxxl),
          Text('Cashback Amount', style: AppStyles.headerStyle(context)),
          const SizedBox(height: Spacing.md),
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('₹',
                    style: AppStyles.titleStyle(context)
                        .copyWith(fontSize: TypeScale.display)),
                const SizedBox(width: Spacing.sm),
                IntrinsicWidth(
                  child: CupertinoTextField(
                    controller: _cashbackAmountController,
                    autofocus: _currentStep == 5,
                    placeholder: '0.00',
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    textInputAction: TextInputAction.next,
                    onSubmitted: (_) => _nextStep(),
                    decoration: BoxDecoration(
                      color: AppStyles.getCardColor(context),
                      borderRadius: BorderRadius.circular(Radii.md),
                    ),
                    style: AppStyles.titleStyle(context).copyWith(
                        fontSize: TypeScale.display,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          if ((double.tryParse(_cashbackAmountController.text) ?? 0) > 0) ...[
            const SizedBox(height: Spacing.xxxl),
            Text('Credit Cashback To', style: AppStyles.headerStyle(context)),
            const SizedBox(height: Spacing.sm),
            Text(
              'Choose sending account, receiving account, or app wallet (if enabled).',
              style: TextStyle(
                fontSize: TypeScale.footnote,
                color: AppStyles.getSecondaryTextColor(context),
              ),
            ),
            const SizedBox(height: Spacing.md),
            if (eligibleAccounts.isEmpty && !canCreditToPaymentApp)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey6,
                  borderRadius: BorderRadius.circular(Radii.md),
                ),
                child: Text(
                  'No eligible cashback destination available.',
                  style: TextStyle(
                    color: AppStyles.getSecondaryTextColor(context),
                  ),
                ),
              ),
            Column(
              children: [
                ...eligibleAccounts.map((account) {
                  final isSource = account.id == _sourceAccount?.id;
                  final isSelected = !_cashbackToPaymentApp &&
                      _cashbackAccount?.id == account.id;
                  return GestureDetector(
                    onTap: () => setState(() {
                      _cashbackToPaymentApp = false;
                      _cashbackAccount = account;
                    }),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(Spacing.md),
                      decoration: BoxDecoration(
                        color: AppStyles.getCardColor(context),
                        borderRadius: BorderRadius.circular(Radii.md),
                        border: isSelected
                            ? Border.all(
                                color: AppStyles.gain(context), width: 2)
                            : Border.all(
                                color: AppStyles.getSecondaryTextColor(context)
                                    .withValues(alpha: 0.1),
                                width: 1,
                              ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(Spacing.sm),
                            decoration: BoxDecoration(
                              color: account.color.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _iconForAccount(account),
                              color: account.color,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: Spacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  account.name,
                                  style: AppStyles.titleStyle(context)
                                      .copyWith(fontSize: TypeScale.body),
                                ),
                                const SizedBox(height: Spacing.xxs),
                                Text(
                                  isSource
                                      ? 'Sending Account'
                                      : 'Receiving Account',
                                  style: TextStyle(
                                    fontSize: TypeScale.footnote,
                                    color: AppStyles.getSecondaryTextColor(
                                        context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            Icon(
                              CupertinoIcons.checkmark_circle_fill,
                              color: AppStyles.gain(context),
                              size: 20,
                            ),
                        ],
                      ),
                    ),
                  );
                }),
                if (canCreditToPaymentApp)
                  GestureDetector(
                    onTap: () => setState(() {
                      _cashbackToPaymentApp = true;
                      _cashbackAccount = null;
                    }),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(Spacing.md),
                      decoration: BoxDecoration(
                        color: AppStyles.getCardColor(context),
                        borderRadius: BorderRadius.circular(Radii.md),
                        border: _cashbackToPaymentApp
                            ? Border.all(
                                color: AppStyles.gain(context), width: 2)
                            : Border.all(
                                color: AppStyles.getSecondaryTextColor(context)
                                    .withValues(alpha: 0.1),
                                width: 1,
                              ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(Spacing.sm),
                            decoration: BoxDecoration(
                              color: CupertinoColors.systemBlue
                                  .withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              CupertinoIcons.square_stack_3d_down_right_fill,
                              color: CupertinoColors.systemBlue,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: Spacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${_selectedPaymentApp!} Wallet',
                                  style: AppStyles.titleStyle(context)
                                      .copyWith(fontSize: TypeScale.body),
                                ),
                                const SizedBox(height: Spacing.xxs),
                                Text(
                                  'Payment App Wallet',
                                  style: TextStyle(
                                    fontSize: TypeScale.footnote,
                                    color: AppStyles.getSecondaryTextColor(
                                        context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_cashbackToPaymentApp)
                            Icon(
                              CupertinoIcons.checkmark_circle_fill,
                              color: AppStyles.gain(context),
                              size: 20,
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReviewStep() {
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    final charges = double.tryParse(_chargesController.text) ?? 0.0;
    final appWalletAmount =
        double.tryParse(_appWalletAmountController.text) ?? 0.0;
    final cashbackAmount =
        double.tryParse(_cashbackAmountController.text) ?? 0.0;
    final deductFromSource = amount - appWalletAmount;
    final transferFlowType = _cashFlowType();
    final transferFlowLabel = transferFlowType == 'cash_withdrawal'
        ? 'Cash Withdrawal'
        : transferFlowType == 'cash_deposit'
            ? 'Cash Deposit'
            : transferFlowType == 'cash_to_cash'
                ? 'Cash Transfer'
                : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(Spacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Review Transfer',
            style: AppStyles.titleStyle(context).copyWith(fontSize: RT.largeTitle(context)),
          ),
          const SizedBox(height: Spacing.xxxl),
          Container(
            padding: const EdgeInsets.all(Spacing.lg),
            decoration: BoxDecoration(
              color: AppStyles.getCardColor(context),
              borderRadius: BorderRadius.circular(Radii.md),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildReviewRow('From', _sourceAccount?.name ?? 'Unknown'),
                const SizedBox(height: Spacing.md),
                _buildReviewRow('To', _destinationAccount?.name ?? 'Unknown'),
                const SizedBox(height: Spacing.md),
                _buildReviewRow('Date', _formatDate(_selectedTransferDate)),
                if (transferFlowLabel != null) ...[
                  const SizedBox(height: Spacing.md),
                  _buildReviewRow('Flow', transferFlowLabel),
                ],
                const SizedBox(height: Spacing.md),
                Container(
                  height: 1,
                  color: AppStyles.getSecondaryTextColor(context)
                      .withValues(alpha: 0.1),
                ),
                const SizedBox(height: Spacing.md),
                _buildReviewRow('Transfer Amount',
                    '₹${amount.toStringAsFixed(2)}'.toUpperCase(),
                    isAmount: true),
                if (appWalletAmount > 0)
                  _buildReviewRow('From App Wallet',
                      '-₹${appWalletAmount.toStringAsFixed(2)}'),
                _buildReviewRow('From Source Account',
                    '-₹${deductFromSource.toStringAsFixed(2)}'),
                if (charges > 0)
                  _buildReviewRow('Charges', '-₹${charges.toStringAsFixed(2)}',
                      isNegative: true),
                if (cashbackAmount > 0)
                  _buildReviewRow('Cashback to ${_cashbackDestinationName()}',
                      '+₹${cashbackAmount.toStringAsFixed(2)}',
                      isPositive: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransferDateStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(Spacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Transfer Date',
            style: AppStyles.titleStyle(context).copyWith(fontSize: RT.largeTitle(context)),
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            'Select when this transfer happened.',
            style: TextStyle(color: AppStyles.getSecondaryTextColor(context)),
          ),
          const SizedBox(height: Spacing.xxxl),
          GestureDetector(
            onTap: _showTransferDatePicker,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(Spacing.lg),
              decoration: BoxDecoration(
                color: AppStyles.getCardColor(context),
                borderRadius: BorderRadius.circular(Radii.md),
                border: Border.all(
                  color: AppStyles.getSecondaryTextColor(context)
                      .withValues(alpha: 0.15),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    CupertinoIcons.calendar,
                    color: CupertinoColors.systemBlue,
                    size: 22,
                  ),
                  const SizedBox(width: Spacing.md),
                  Expanded(
                    child: Text(
                      _formatDate(_selectedTransferDate),
                      style:
                          AppStyles.titleStyle(context).copyWith(fontSize: 18),
                    ),
                  ),
                  const Text(
                    'Change',
                    style: TextStyle(
                      color: CupertinoColors.systemBlue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showTransferDatePicker() async {
    final picked = await showAppDatePicker(
      context: context,
      initialDate: _selectedTransferDate,
      minimumDate: DateTime.now().subtract(const Duration(days: 365 * 30)),
      maximumDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked != null) {
      setState(() => _selectedTransferDate = picked);
    }
  }

  String _formatDate(DateTime date) => DateFormatter.formatSlash(date);

  Widget _buildReviewRow(
    String label,
    String value, {
    bool isAmount = false,
    bool isPositive = false,
    bool isNegative = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppStyles.getSecondaryTextColor(context),
            fontSize: TypeScale.body,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: isPositive
                ? AppStyles.gain(context)
                : isNegative
                    ? AppStyles.loss(context)
                    : isAmount
                        ? CupertinoColors.systemBlue
                        : AppStyles.getTextColor(context),
            fontSize: isAmount ? 16 : 14,
            fontWeight: isAmount ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.all(Spacing.xxl),
      child: BouncyButton(
        onPressed: _canProceed() ? _nextStep : () {},
        child: Opacity(
          opacity: _canProceed() ? 1.0 : 0.5,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: CupertinoColors.systemBlue,
              borderRadius: BorderRadius.circular(Radii.lg),
            ),
            child: Center(
              child: Text(
                _currentStep == _totalSteps - 1 ? 'Complete Transfer' : 'Next',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PaymentAppSelectionResult {
  const _PaymentAppSelectionResult({
    required this.appName,
    required this.hasWallet,
    required this.walletBalance,
  });

  final String appName;
  final bool hasWallet;
  final double walletBalance;
}

enum _PaymentAppSetupStage { pickOrAdd, addName, wallet }

class _PaymentAppSetupWizard extends StatefulWidget {
  const _PaymentAppSetupWizard();

  @override
  State<_PaymentAppSetupWizard> createState() => _PaymentAppSetupWizardState();
}

class _PaymentAppSetupWizardState extends State<_PaymentAppSetupWizard> {
  _PaymentAppSetupStage _stage = _PaymentAppSetupStage.pickOrAdd;
  Map<String, dynamic>? _selectedDisabledApp;
  String _newAppName = '';
  bool _hasWallet = false;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _walletController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _walletController.dispose();
    super.dispose();
  }

  Future<void> _completeSetup(PaymentAppsController controller) async {
    if (_selectedDisabledApp != null) {
      final appId = _selectedDisabledApp!['id'] as String;
      final appName = _selectedDisabledApp!['name'] as String;
      final openingWallet =
          _hasWallet ? (double.tryParse(_walletController.text) ?? 0.0) : 0.0;
      await controller.toggleApp(appId, true);
      await controller.setWalletSupport(
        appId,
        _hasWallet,
        openingBalance: openingWallet,
      );
      if (!mounted) return;
      Navigator.pop(
        context,
        _PaymentAppSelectionResult(
          appName: appName,
          hasWallet: _hasWallet,
          walletBalance: openingWallet,
        ),
      );
      return;
    }

    final trimmed = _newAppName.trim();
    if (trimmed.isEmpty) {
      toast.showError('Enter app name');
      return;
    }
    final wallet =
        _hasWallet ? (double.tryParse(_walletController.text) ?? 0) : 0;
    final appId =
        '${trimmed.replaceAll(' ', '_').toLowerCase()}_${DateTime.now().millisecondsSinceEpoch}';
    await controller.addApp({
      'id': appId,
      'name': trimmed,
      'color': CupertinoColors.systemBlue,
      'isEnabled': true,
      'hasWallet': _hasWallet,
      'walletBalance': wallet,
    });
    if (!mounted) return;
    Navigator.pop(
      context,
      _PaymentAppSelectionResult(
        appName: trimmed,
        hasWallet: _hasWallet,
        walletBalance: wallet.toDouble(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PaymentAppsController>(
      builder: (context, controller, _) {
        final disabledApps = controller.disabledApps;
        return CupertinoPageScaffold(
          navigationBar: AppStyles.isLandscape(context) ? null : CupertinoNavigationBar(
            middle: const Text('Select New App'),
            leading: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () {
                if (_stage == _PaymentAppSetupStage.pickOrAdd) {
                  Navigator.pop(context);
                  return;
                }
                setState(() {
                  if (_stage == _PaymentAppSetupStage.wallet &&
                      _selectedDisabledApp == null) {
                    _stage = _PaymentAppSetupStage.addName;
                  } else {
                    _stage = _PaymentAppSetupStage.pickOrAdd;
                  }
                });
              },
              child: const Icon(CupertinoIcons.back),
            ),
            trailing: _stage == _PaymentAppSetupStage.pickOrAdd
                ? CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      setState(() {
                        _selectedDisabledApp = null;
                        _newAppName = '';
                        _nameController.clear();
                        _walletController.clear();
                        _hasWallet = false;
                        _stage = _PaymentAppSetupStage.addName;
                      });
                    },
                    child: const Text('Add'),
                  )
                : null,
            border: null,
          ),
          child: SafeArea(
            child: AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(Spacing.xl),
                child: _buildBody(controller, disabledApps),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody(
    PaymentAppsController controller,
    List<Map<String, dynamic>> disabledApps,
  ) {
    switch (_stage) {
      case _PaymentAppSetupStage.pickOrAdd:
        if (disabledApps.isEmpty) {
          return Text(
            'No disabled apps found. Tap Add to create a new app.',
            style: TextStyle(color: AppStyles.getSecondaryTextColor(context)),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Disabled Payment Apps',
              style: AppStyles.titleStyle(context)
                  .copyWith(fontSize: RT.title1(context)),
            ),
            const SizedBox(height: Spacing.sm),
            Text(
              'Tap any app to use it in this transfer',
              style: TextStyle(color: AppStyles.getSecondaryTextColor(context)),
            ),
            const SizedBox(height: Spacing.lg),
            ...disabledApps.map((app) {
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedDisabledApp = app;
                    _hasWallet = app['hasWallet'] == true;
                    final existing =
                        (app['walletBalance'] as num?)?.toDouble() ?? 0.0;
                    _walletController.text =
                        existing > 0 ? existing.toStringAsFixed(2) : '';
                    _stage = _PaymentAppSetupStage.wallet;
                  });
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppStyles.getCardColor(context),
                    borderRadius: BorderRadius.circular(Radii.md),
                  ),
                  child: Row(
                    children: [
                      Icon(CupertinoIcons.app, color: app['color']),
                      const SizedBox(width: Spacing.md),
                      Expanded(
                        child: Text(
                          app['name'] as String,
                          style: TextStyle(
                            color: AppStyles.getTextColor(context),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Icon(CupertinoIcons.chevron_right, size: 16),
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      case _PaymentAppSetupStage.addName:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add Payment App',
              style: AppStyles.titleStyle(context)
                  .copyWith(fontSize: RT.title1(context)),
            ),
            const SizedBox(height: Spacing.lg),
            CupertinoTextField(
              controller: _nameController,
              autofocus: true,
              placeholder: 'Enter app name',
              textInputAction: TextInputAction.done,
              onSubmitted: (_) {
                final value = _nameController.text.trim();
                if (value.isEmpty) {
                  toast.showError('Enter app name');
                  return;
                }
                setState(() {
                  _newAppName = value;
                  _stage = _PaymentAppSetupStage.wallet;
                });
              },
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppStyles.getCardColor(context),
                borderRadius: BorderRadius.circular(Radii.md),
              ),
            ),
            const SizedBox(height: Spacing.lg),
            BouncyButton(
              onPressed: () {
                final value = _nameController.text.trim();
                if (value.isEmpty) {
                  toast.showError('Enter app name');
                  return;
                }
                setState(() {
                  _newAppName = value;
                  _stage = _PaymentAppSetupStage.wallet;
                });
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemBlue,
                  borderRadius: BorderRadius.circular(Radii.md),
                ),
                child: const Center(
                  child: Text(
                    'Next',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        );
      case _PaymentAppSetupStage.wallet:
        final appName = _selectedDisabledApp?['name'] as String? ?? _newAppName;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add wallet for $appName?',
              style: AppStyles.titleStyle(context)
                  .copyWith(fontSize: RT.title1(context)),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: BouncyButton(
                    onPressed: () => setState(() => _hasWallet = true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _hasWallet
                            ? AppStyles.gain(context)
                            : CupertinoColors.systemGrey5,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          'Yes',
                          style: TextStyle(
                            color: _hasWallet
                                ? Colors.white
                                : AppStyles.getTextColor(context),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: BouncyButton(
                    onPressed: () => setState(() => _hasWallet = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: !_hasWallet
                            ? AppStyles.loss(context)
                            : CupertinoColors.systemGrey5,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          'No',
                          style: TextStyle(
                            color: !_hasWallet
                                ? Colors.white
                                : AppStyles.getTextColor(context),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (_hasWallet) ...[
              const SizedBox(height: Spacing.lg),
              CupertinoTextField(
                controller: _walletController,
                autofocus: true,
                placeholder: 'Opening wallet amount',
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _completeSetup(controller),
                prefix: const Padding(
                  padding: EdgeInsets.only(left: 12),
                  child: Text('₹'),
                ),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppStyles.getCardColor(context),
                  borderRadius: BorderRadius.circular(Radii.md),
                ),
              ),
            ],
            const SizedBox(height: Spacing.xl),
            BouncyButton(
              onPressed: () => _completeSetup(controller),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemBlue,
                  borderRadius: BorderRadius.circular(Radii.md),
                ),
                child: const Center(
                  child: Text(
                    'Continue',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        );
    }
  }
}

/// Small selectable chip for cash transfer method (Direct / ATM).
class _CashMethodChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _CashMethodChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppStyles.aetherTeal;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.15)
              : AppStyles.getCardColor(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color : AppStyles.getDividerColor(context),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16,
                color: selected
                    ? color
                    : AppStyles.getSecondaryTextColor(context)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight:
                    selected ? FontWeight.w700 : FontWeight.w500,
                color: selected
                    ? color
                    : AppStyles.getTextColor(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
