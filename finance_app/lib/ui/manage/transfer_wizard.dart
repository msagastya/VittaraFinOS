import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/account_model.dart';
import 'package:vittara_fin_os/logic/accounts_controller.dart';
import 'package:vittara_fin_os/logic/brokers_controller.dart';
import 'package:vittara_fin_os/logic/payment_apps_controller.dart';
import 'package:vittara_fin_os/logic/transaction_model.dart';
import 'package:vittara_fin_os/logic/transactions_controller.dart';
import 'package:vittara_fin_os/ui/manage/account_wizard.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/widgets/animations.dart';
import 'package:vittara_fin_os/ui/widgets/common_widgets.dart';
import 'package:vittara_fin_os/ui/widgets/toast_notification.dart';

class TransferWizard extends StatefulWidget {
  const TransferWizard({super.key});

  @override
  State<TransferWizard> createState() => _TransferWizardState();
}

class _TransferWizardState extends State<TransferWizard> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  static const int _totalSteps = 6;

  // Step data
  Account? _sourceAccount;
  Account? _destinationAccount;
  final _amountController = TextEditingController();
  final _chargesController = TextEditingController();
  final _appWalletAmountController = TextEditingController();
  final _cashbackAmountController = TextEditingController();
  String? _selectedPaymentApp;
  Account? _cashbackAccount;
  bool _paymentAppHasWallet = false;

  @override
  void initState() {
    super.initState();
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
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
      setState(() => _currentStep++);
    } else {
      _finishTransfer();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
      setState(() => _currentStep--);
    } else {
      Navigator.pop(context);
    }
  }

  void _finishTransfer() {
    final accountsController = Provider.of<AccountsController>(context, listen: false);
    final transactionsController = Provider.of<TransactionsController>(context, listen: false);

    // Calculate total deduction from source
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    final charges = double.tryParse(_chargesController.text) ?? 0.0;
    final appWalletAmount = double.tryParse(_appWalletAmountController.text) ?? 0.0;
    final cashbackAmount = double.tryParse(_cashbackAmountController.text) ?? 0.0;

    // Calculate deductions from source and app wallet
    final deductFromSource = amount - appWalletAmount;

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
      // This would need a payment apps update method
      // For now, just handle in transaction
    }

    // Add cashback to cashback account
    if (cashbackAmount > 0 && _cashbackAccount != null) {
      final updatedCashback = _cashbackAccount!.copyWith(
        balance: _cashbackAccount!.balance + cashbackAmount,
      );
      accountsController.updateAccount(updatedCashback);
    }

    // Create transaction record
    final transaction = Transaction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: TransactionType.transfer,
      description: '${_sourceAccount?.name} → ${_destinationAccount?.name}',
      dateTime: DateTime.now(),
      amount: amount,
      sourceAccountId: _sourceAccount?.id,
      sourceAccountName: _sourceAccount?.name,
      destinationAccountId: _destinationAccount?.id,
      destinationAccountName: _destinationAccount?.name,
      charges: charges > 0 ? charges : null,
      paymentAppName: _selectedPaymentApp,
      appWalletAmount: appWalletAmount > 0 ? appWalletAmount : null,
      cashbackAmount: cashbackAmount > 0 ? cashbackAmount : null,
      cashbackAccountId: _cashbackAccount?.id,
      cashbackAccountName: _cashbackAccount?.name,
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
        return _destinationAccount != null && _destinationAccount!.id != _sourceAccount!.id;
      case 2: // Amount
        final amount = double.tryParse(_amountController.text) ?? 0.0;
        return amount > 0 && amount <= (_sourceAccount?.balance ?? 0);
      case 3: // Payment app
        return true; // Optional step
      case 4: // Cashback
        return true; // Optional step
      case 5: // Review
        return true;
      default:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppStyles.getBackground(context),
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Transfer Money'),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _prevStep,
          child: Icon(_currentStep == 0 ? CupertinoIcons.xmark : CupertinoIcons.back),
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
                  _buildCashbackStep(),
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
                color: isActive ? CupertinoColors.systemBlue : CupertinoColors.systemGrey.withValues(alpha: 0.2),
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
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select Source Account',
                style: AppStyles.titleStyle(context).copyWith(fontSize: 24),
              ),
              const SizedBox(height: 8),
              Text(
                'Where will the money be deducted from?',
                style: TextStyle(color: AppStyles.getSecondaryTextColor(context)),
              ),
              const SizedBox(height: 32),
              Column(
                children: accountsController.accounts
                    .map((account) {
                      final isSelected = _sourceAccount?.id == account.id;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _sourceAccount = account;
                            // Auto-select broker if source is Demat/Investment
                            if (account.type == AccountType.investment) {
                              _selectedPaymentApp = account.bankName;
                              _paymentAppHasWallet = false; // Brokers don't have wallets
                            }
                          });
                          _nextStep();
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppStyles.getCardColor(context),
                            borderRadius: BorderRadius.circular(12),
                            border: isSelected
                                ? Border.all(color: CupertinoColors.systemBlue, width: 2)
                                : Border.all(
                                    color: AppStyles.getSecondaryTextColor(context).withValues(alpha: 0.1),
                                    width: 1,
                                  ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: account.color.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  account.type == AccountType.investment
                                      ? CupertinoIcons.chart_bar_square_fill
                                      : CupertinoIcons.building_2_fill,
                                  color: account.color,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      account.name,
                                      style: AppStyles.titleStyle(context).copyWith(fontSize: 16),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '₹${account.balance.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: TypeScale.footnote,
                                        color: AppStyles.getSecondaryTextColor(context),
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
                    })
                    .toList(),
              ),
              const SizedBox(height: 24),
              BouncyButton(
                onPressed: () => _showAddAccountModal(context, accountsController),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: CupertinoColors.systemBlue,
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(CupertinoIcons.add, color: CupertinoColors.systemBlue),
                        const SizedBox(width: 8),
                        Text(
                          'Add Account',
                          style: TextStyle(
                            color: CupertinoColors.systemBlue,
                            fontSize: 16,
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

  void _showAddAccountModal(BuildContext context, AccountsController accountsController) {
    Navigator.push<Account>(
      context,
      FadeScalePageRoute(
        page: const AccountWizard(isInvestment: false),
      ),
    ).then((result) {
      if (result != null) {
        accountsController.addAccount(result);
        setState(() => _sourceAccount = result);
        _nextStep();
      }
    });
  }

  Widget _buildDestinationAccountStep() {
    return Consumer<AccountsController>(
      builder: (context, accountsController, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select Receiving Account',
                style: AppStyles.titleStyle(context).copyWith(fontSize: 24),
              ),
              const SizedBox(height: 8),
              Text(
                'Where should the money go?',
                style: TextStyle(color: AppStyles.getSecondaryTextColor(context)),
              ),
              const SizedBox(height: 32),
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
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppStyles.getCardColor(context),
                            borderRadius: BorderRadius.circular(12),
                            border: isSelected
                                ? Border.all(color: CupertinoColors.systemBlue, width: 2)
                                : Border.all(
                                    color: AppStyles.getSecondaryTextColor(context).withValues(alpha: 0.1),
                                    width: 1,
                                  ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: account.color.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  account.type == AccountType.investment
                                      ? CupertinoIcons.chart_bar_square_fill
                                      : CupertinoIcons.building_2_fill,
                                  color: account.color,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      account.name,
                                      style: AppStyles.titleStyle(context).copyWith(fontSize: 16),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      account.bankName,
                                      style: TextStyle(
                                        fontSize: TypeScale.footnote,
                                        color: AppStyles.getSecondaryTextColor(context),
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
                    })
                    .toList(),
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
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Transfer Amount',
            style: AppStyles.titleStyle(context).copyWith(fontSize: 24),
          ),
          const SizedBox(height: 32),
          Text('Amount to Transfer', style: AppStyles.headerStyle(context)),
          const SizedBox(height: 12),
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('₹', style: AppStyles.titleStyle(context).copyWith(fontSize: 32)),
                const SizedBox(width: 8),
                IntrinsicWidth(
                  child: CupertinoTextField(
                    controller: _amountController,
                    placeholder: '0.00',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: BoxDecoration(
                      color: AppStyles.getCardColor(context),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    style: AppStyles.titleStyle(context).copyWith(fontSize: 32, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (sourceHasCharges) ...[
            Text('Extra Charges (Optional)', style: AppStyles.headerStyle(context)),
            const SizedBox(height: 4),
            Text(
              'Charges will be deducted but not credited to any account',
              style: TextStyle(fontSize: 12, color: AppStyles.getSecondaryTextColor(context)),
            ),
            const SizedBox(height: 12),
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('₹', style: AppStyles.titleStyle(context).copyWith(fontSize: 28)),
                  const SizedBox(width: 8),
                  IntrinsicWidth(
                    child: CupertinoTextField(
                      controller: _chargesController,
                      placeholder: '0.00',
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: BoxDecoration(
                        color: AppStyles.getCardColor(context),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      style: AppStyles.titleStyle(context).copyWith(fontSize: 28, fontWeight: FontWeight.bold),
                    ),
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
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isSourceDemat ? 'Broker (Demat)' : 'Payment App (Optional)',
                style: AppStyles.titleStyle(context).copyWith(fontSize: 24),
              ),
              const SizedBox(height: 8),
              Text(
                isSourceDemat
                    ? 'Cannot withdraw from Demat using other apps. Using: ${_sourceAccount!.bankName}'
                    : 'Which payment app are you using for this transfer?',
                style: TextStyle(color: AppStyles.getSecondaryTextColor(context)),
              ),
              const SizedBox(height: 32),
              if (isSourceDemat)
                // Show locked broker for Demat
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: CupertinoColors.systemGreen,
                      width: 2,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        CupertinoIcons.lock_fill,
                        color: CupertinoColors.systemGreen,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _sourceAccount!.bankName,
                              style: AppStyles.titleStyle(context).copyWith(fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Auto-selected (Fixed)',
                              style: TextStyle(
                                fontSize: TypeScale.footnote,
                                color: CupertinoColors.systemGreen,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        CupertinoIcons.checkmark_circle_fill,
                        color: CupertinoColors.systemGreen,
                        size: 24,
                      ),
                    ],
                  ),
                )
              else
                // Show payment apps for other accounts
                Column(
                  children: [
                    if (paymentAppsController.paymentApps.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Text(
                            'No payment apps added yet',
                            style: TextStyle(color: AppStyles.getSecondaryTextColor(context)),
                          ),
                        ),
                      )
                    else
                      Column(
                        children: paymentAppsController.paymentApps
                            .map((app) {
                              final isSelected = _selectedPaymentApp == app['name'];
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedPaymentApp = app['name'];
                                    _paymentAppHasWallet = app['hasWallet'] ?? false;
                                    if (!_paymentAppHasWallet) {
                                      _nextStep();
                                    }
                                  });
                                },
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: AppStyles.getCardColor(context),
                                    borderRadius: BorderRadius.circular(12),
                                    border: isSelected
                                        ? Border.all(color: CupertinoColors.systemBlue, width: 2)
                                        : Border.all(
                                            color: AppStyles.getSecondaryTextColor(context).withValues(alpha: 0.1),
                                            width: 1,
                                          ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        CupertinoIcons.square_stack_3d_down_right_fill,
                                        color: CupertinoColors.systemBlue,
                                        size: 24,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              app['name'],
                                              style: AppStyles.titleStyle(context).copyWith(fontSize: 16),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              (app['hasWallet'] ?? false) ? 'Has wallet' : 'No wallet',
                                              style: TextStyle(
                                                fontSize: TypeScale.footnote,
                                                color: AppStyles.getSecondaryTextColor(context),
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
                            })
                            .toList(),
                      ),
                    const SizedBox(height: 12),
                    BouncyButton(
                      onPressed: () => _showAddPaymentAppModal(context, paymentAppsController),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: CupertinoColors.systemBlue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: CupertinoColors.systemBlue,
                            width: 1.5,
                          ),
                        ),
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(CupertinoIcons.add, color: CupertinoColors.systemBlue),
                              const SizedBox(width: 8),
                              Text(
                                'Add Payment App',
                                style: TextStyle(
                                  color: CupertinoColors.systemBlue,
                                  fontSize: 16,
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
              if (_selectedPaymentApp != null && _paymentAppHasWallet && !isSourceDemat) ...[
                const SizedBox(height: 32),
                Text('Amount from App Wallet', style: AppStyles.headerStyle(context)),
                const SizedBox(height: 4),
                Text(
                  'How much of the transfer amount should come from this app\'s wallet?',
                  style: TextStyle(fontSize: 12, color: AppStyles.getSecondaryTextColor(context)),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('₹', style: AppStyles.titleStyle(context).copyWith(fontSize: 28)),
                      const SizedBox(width: 8),
                      IntrinsicWidth(
                        child: CupertinoTextField(
                          controller: _appWalletAmountController,
                          placeholder: '0.00',
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: BoxDecoration(
                            color: AppStyles.getCardColor(context),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          style: AppStyles.titleStyle(context).copyWith(fontSize: 28, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _showAddPaymentAppModal(BuildContext context, PaymentAppsController paymentAppsController) {
    final appNameController = TextEditingController();
    bool hasWallet = false;

    showCupertinoModalPopup(
      context: context,
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.5,
              decoration: BoxDecoration(
                color: AppStyles.getCardColor(context),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      children: [
                        Container(
                          width: 40,
                          height: 5,
                          decoration: BoxDecoration(
                            color: CupertinoColors.systemGrey3,
                            borderRadius: BorderRadius.circular(2.5),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Add Payment App',
                          style: AppStyles.titleStyle(context).copyWith(fontSize: 20),
                        ),
                      ],
                    ),
                  ),
                  Divider(color: AppStyles.getSecondaryTextColor(context).withValues(alpha: 0.1)),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'App Name',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppStyles.getSecondaryTextColor(context),
                            ),
                          ),
                          const SizedBox(height: 8),
                          CupertinoTextField(
                            controller: appNameController,
                            placeholder: 'e.g. Google Pay, PhonePe',
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppStyles.getCardColor(context),
                              border: Border.all(
                                color: CupertinoColors.systemBlue.withValues(alpha: 0.2),
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            style: TextStyle(color: AppStyles.getTextColor(context)),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Does this app have a wallet feature?',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppStyles.getSecondaryTextColor(context),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            decoration: BoxDecoration(
                              color: AppStyles.getSecondaryTextColor(context).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.all(4),
                            child: Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => setModalState(() => hasWallet = true),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      decoration: BoxDecoration(
                                        color: hasWallet ? CupertinoColors.systemGreen : Colors.transparent,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Center(
                                        child: Text(
                                          'Yes, Has Wallet',
                                          style: TextStyle(
                                            color: hasWallet ? Colors.white : AppStyles.getSecondaryTextColor(context),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => setModalState(() => hasWallet = false),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      decoration: BoxDecoration(
                                        color: !hasWallet ? CupertinoColors.systemRed : Colors.transparent,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Center(
                                        child: Text(
                                          'No Wallet',
                                          style: TextStyle(
                                            color: !hasWallet ? Colors.white : AppStyles.getSecondaryTextColor(context),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(24),
                    child: Row(
                      children: [
                        Expanded(
                          child: BouncyButton(
                            onPressed: () => Navigator.pop(modalContext),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: AppStyles.getCardColor(context),
                                border: Border.all(
                                  color: CupertinoColors.systemGrey3,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  'Cancel',
                                  style: TextStyle(
                                    color: AppStyles.getTextColor(context),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: BouncyButton(
                            onPressed: () {
                              if (appNameController.text.isNotEmpty) {
                                final newApp = {
                                  'id': appNameController.text.toLowerCase().replaceAll(' ', '_'),
                                  'name': appNameController.text,
                                  'hasWallet': hasWallet,
                                  'isEnabled': true,
                                };
                                paymentAppsController.addApp(newApp);
                                setState(() {
                                  _selectedPaymentApp = appNameController.text;
                                  _paymentAppHasWallet = hasWallet;
                                });
                                Navigator.pop(modalContext);
                                if (!hasWallet) {
                                  _nextStep();
                                }
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: CupertinoColors.systemBlue,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Center(
                                child: Text(
                                  'Add App',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCashbackStep() {
    return Consumer<AccountsController>(
      builder: (context, accountsController, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cashback (Optional)',
                style: AppStyles.titleStyle(context).copyWith(fontSize: 24),
              ),
              const SizedBox(height: 8),
              Text(
                'Did you receive cashback? Enter amount and select account',
                style: TextStyle(color: AppStyles.getSecondaryTextColor(context)),
              ),
              const SizedBox(height: 32),
              Text('Cashback Amount', style: AppStyles.headerStyle(context)),
              const SizedBox(height: 12),
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('₹', style: AppStyles.titleStyle(context).copyWith(fontSize: 32)),
                    const SizedBox(width: 8),
                    IntrinsicWidth(
                      child: CupertinoTextField(
                        controller: _cashbackAmountController,
                        placeholder: '0.00',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: BoxDecoration(
                          color: AppStyles.getCardColor(context),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        style: AppStyles.titleStyle(context).copyWith(fontSize: 32, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              if ((double.tryParse(_cashbackAmountController.text) ?? 0) > 0) ...[
                const SizedBox(height: 32),
                Text('Cashback Account', style: AppStyles.headerStyle(context)),
                const SizedBox(height: 12),
                Column(
                  children: accountsController.accounts
                      .where((account) => account.type != AccountType.investment)
                      .map((account) {
                        final isSelected = _cashbackAccount?.id == account.id;
                        return GestureDetector(
                          onTap: () => setState(() => _cashbackAccount = account),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppStyles.getCardColor(context),
                              borderRadius: BorderRadius.circular(12),
                              border: isSelected
                                  ? Border.all(color: CupertinoColors.systemGreen, width: 2)
                                  : Border.all(
                                      color: AppStyles.getSecondaryTextColor(context).withValues(alpha: 0.1),
                                      width: 1,
                                    ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: account.color.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    CupertinoIcons.building_2_fill,
                                    color: account.color,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    account.name,
                                    style: AppStyles.titleStyle(context).copyWith(fontSize: 14),
                                  ),
                                ),
                                if (isSelected)
                                  const Icon(
                                    CupertinoIcons.checkmark_circle_fill,
                                    color: CupertinoColors.systemGreen,
                                    size: 20,
                                  ),
                              ],
                            ),
                          ),
                        );
                      })
                      .toList(),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildReviewStep() {
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    final charges = double.tryParse(_chargesController.text) ?? 0.0;
    final appWalletAmount = double.tryParse(_appWalletAmountController.text) ?? 0.0;
    final cashbackAmount = double.tryParse(_cashbackAmountController.text) ?? 0.0;
    final deductFromSource = amount - appWalletAmount;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Review Transfer',
            style: AppStyles.titleStyle(context).copyWith(fontSize: 24),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppStyles.getCardColor(context),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildReviewRow('From', _sourceAccount?.name ?? 'Unknown'),
                const SizedBox(height: 12),
                _buildReviewRow('To', _destinationAccount?.name ?? 'Unknown'),
                const SizedBox(height: 12),
                Container(
                  height: 1,
                  color: AppStyles.getSecondaryTextColor(context).withValues(alpha: 0.1),
                ),
                const SizedBox(height: 12),
                _buildReviewRow('Transfer Amount', '₹${amount.toStringAsFixed(2)}'.toUpperCase(), isAmount: true),
                if (appWalletAmount > 0)
                  _buildReviewRow('From App Wallet', '-₹${appWalletAmount.toStringAsFixed(2)}'),
                _buildReviewRow('From Source Account', '-₹${deductFromSource.toStringAsFixed(2)}'),
                if (charges > 0)
                  _buildReviewRow('Charges', '-₹${charges.toStringAsFixed(2)}', isNegative: true),
                if (cashbackAmount > 0)
                  _buildReviewRow('Cashback to ${_cashbackAccount?.name}', '+₹${cashbackAmount.toStringAsFixed(2)}', isPositive: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

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
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: isPositive
                ? CupertinoColors.systemGreen
                : isNegative
                    ? CupertinoColors.systemRed
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
      padding: const EdgeInsets.all(24),
      child: BouncyButton(
        onPressed: _canProceed() ? _nextStep : () {},
        child: Opacity(
          opacity: _canProceed() ? 1.0 : 0.5,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: CupertinoColors.systemBlue,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                _currentStep == _totalSteps - 1 ? 'Complete Transfer' : 'Next',
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
