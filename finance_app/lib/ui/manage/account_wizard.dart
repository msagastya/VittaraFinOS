import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/account_model.dart';
import 'package:vittara_fin_os/logic/banks_controller.dart';
import 'package:vittara_fin_os/logic/brokers_controller.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/widgets/animations.dart';
import 'package:vittara_fin_os/ui/widgets/common_widgets.dart';
import 'package:vittara_fin_os/ui/widgets/toast_notification.dart' as toast_lib;

class AccountWizard extends StatefulWidget {
  final bool isInvestment;
  final Account? existingAccount; // For editing existing accounts
  const AccountWizard(
      {super.key, this.isInvestment = false, this.existingAccount});

  @override
  State<AccountWizard> createState() => _AccountWizardState();
}

class _AccountWizardState extends State<AccountWizard> {
  static const String _cashBankName = 'Cash';

  final PageController _pageController = PageController();
  int _currentStep = 0;
  late final int _totalSteps;

  // Form Data
  String? _selectedBank;
  String? _selectedBroker;
  Color? _selectedColor;

  // Step 2: Account Type Selection (for bank accounts)
  AccountType? _selectedAccountType;
  final TextEditingController _nameController = TextEditingController();

  // Step 3: Account Details (type-specific)
  final TextEditingController _accountNumberController =
      TextEditingController();
  final TextEditingController _ifscController = TextEditingController();
  final TextEditingController _debitCardNumberController =
      TextEditingController();
  final TextEditingController _debitCardExpiryController =
      TextEditingController();
  final TextEditingController _debitCardCvvController = TextEditingController();
  final TextEditingController _debitCardNameController = TextEditingController();
  final TextEditingController _creditLimitController = TextEditingController();
  final TextEditingController _amountUsedController = TextEditingController();
  final TextEditingController _creditCardNumberController =
      TextEditingController();
  final TextEditingController _creditCardExpiryController =
      TextEditingController();
  final TextEditingController _creditCardCvvController = TextEditingController();
  final TextEditingController _creditCardNameController = TextEditingController();
  final TextEditingController _balanceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Set total steps based on account type
    _totalSteps = widget.isInvestment ? 3 : 4;

    // Pre-populate fields if editing existing account
    if (widget.existingAccount != null) {
      final account = widget.existingAccount!;
      _selectedBank = account.bankName;
      _selectedBroker = account.bankName;
      _selectedColor = account.color;
      _selectedAccountType = account.type;
      _nameController.text = account.name;
      _balanceController.text = account.balance.toStringAsFixed(2);

      final meta = account.metadata ?? {};
      if (account.type == AccountType.credit ||
          account.type == AccountType.payLater) {
        _creditLimitController.text =
            (account.creditLimit ?? 0.0).toStringAsFixed(2);
        final amountUsed = (account.creditLimit ?? 0.0) - account.balance;
        _amountUsedController.text = amountUsed.toStringAsFixed(2);
        if (account.creditCardNumber != null) {
          _creditCardNumberController.text = account.creditCardNumber!;
        }
        _creditCardExpiryController.text =
            (meta['cardExpiry'] as String?) ?? '';
        _creditCardCvvController.text = (meta['cardCvv'] as String?) ?? '';
        _creditCardNameController.text = (meta['nameOnCard'] as String?) ?? '';
      } else if (account.type == AccountType.savings ||
          account.type == AccountType.current) {
        _accountNumberController.text =
            (meta['accountNumber'] as String?) ?? '';
        _ifscController.text = (meta['ifscCode'] as String?) ?? '';
        _debitCardNumberController.text =
            (meta['debitCardNumber'] as String?) ?? '';
        _debitCardExpiryController.text =
            (meta['debitCardExpiry'] as String?) ?? '';
        _debitCardCvvController.text = (meta['debitCardCvv'] as String?) ?? '';
        _debitCardNameController.text =
            (meta['debitCardNameOnCard'] as String?) ?? '';
      }
    }

    // Trigger a single rebuild per user keystroke using onChanged on each field.
  }

  // Investment brokers (for future use)
  final List<Map<String, dynamic>> _brokers = [
    {'name': 'Zerodha', 'color': const Color(0xFF387ED1)},
    {'name': 'Groww', 'color': const Color(0xFF00D09C)},
    {'name': 'Upstox', 'color': const Color(0xFF633092)},
    {'name': 'Angel One', 'color': const Color(0xFFF26722)},
  ];

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _accountNumberController.dispose();
    _debitCardNumberController.dispose();
    _creditLimitController.dispose();
    _amountUsedController.dispose();
    _creditCardNumberController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  void _updateNickname() {
    if (widget.isInvestment) {
      if (_selectedBroker != null) {
        _nameController.text = '$_selectedBroker - Demat';
      }
    } else {
      if (_selectedAccountType == AccountType.cash) {
        _nameController.text = 'Cash in Hand';
      } else if (_selectedBank != null && _selectedAccountType != null) {
        final typeLabel = _getAccountTypeLabel(_selectedAccountType!);
        _nameController.text = '$_selectedBank - $typeLabel';
      }
    }
  }

  String _getAccountTypeLabel(AccountType type) {
    switch (type) {
      case AccountType.savings:
        return 'Savings Account';
      case AccountType.current:
        return 'Current Account';
      case AccountType.credit:
        return 'Credit Card';
      case AccountType.payLater:
        return 'Pay Later (BNPL)';
      case AccountType.wallet:
        return 'Digital Wallet';
      case AccountType.investment:
        return 'Investment';
      case AccountType.cash:
        return 'Cash in Hand';
    }
  }

  void _nextStep() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_currentStep < _totalSteps - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
      setState(() => _currentStep++);
    } else {
      _finishWizard();
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

  void _finishWizard() {
    double finalBalance = 0.0;
    final isEditing = widget.existingAccount != null;
    final accountId = isEditing
        ? widget.existingAccount!.id
        : DateTime.now().millisecondsSinceEpoch.toString();

    if (widget.isInvestment) {
      // Investment account: use balance directly
      finalBalance = double.tryParse(_balanceController.text) ?? 0.0;

      final account = Account(
        id: accountId,
        name: _nameController.text,
        bankName: _selectedBroker ?? 'Unknown Broker',
        type: AccountType.investment,
        balance: finalBalance,
        color: _selectedColor ?? CupertinoColors.systemBlue,
      );
      Navigator.pop(context, account);
    } else {
      final banksController = context.read<BanksController>();

      // Bank account: calculate balance based on account type
      if (_selectedAccountType == AccountType.credit ||
          _selectedAccountType == AccountType.payLater) {
        // For credit card and pay later: Balance = Credit Limit - Amount Used
        final creditLimit = double.tryParse(_creditLimitController.text) ?? 0.0;
        final amountUsed = double.tryParse(_amountUsedController.text) ?? 0.0;
        finalBalance = creditLimit - amountUsed;
      } else {
        // For other types: use opening balance directly
        finalBalance = double.tryParse(_balanceController.text) ?? 0.0;
      }

      if (_selectedAccountType != AccountType.cash) {
        final selectedBankName = (_selectedBank ?? '').trim();
        if (selectedBankName.isNotEmpty) {
          banksController.ensureBankEnabledByName(
            selectedBankName,
            color: _selectedColor,
          );
        }
      }

      // Build metadata with account/debit card numbers for SMS matching
      final Map<String, dynamic> acctMeta = {};

      if (_selectedAccountType == AccountType.savings ||
          _selectedAccountType == AccountType.current) {
        final rawAcctNum = _accountNumberController.text.trim();
        if (rawAcctNum.isNotEmpty) {
          acctMeta['accountNumber'] = rawAcctNum;
          final digitsOnly = rawAcctNum.replaceAll(RegExp(r'\D'), '');
          if (digitsOnly.length >= 4) {
            acctMeta['accountLast4'] =
                digitsOnly.substring(digitsOnly.length - 4);
          }
        }
        final rawIfsc = _ifscController.text.trim();
        if (rawIfsc.isNotEmpty) acctMeta['ifscCode'] = rawIfsc.toUpperCase();

        final rawDebitCard = _debitCardNumberController.text.trim();
        if (rawDebitCard.isNotEmpty) {
          acctMeta['debitCardNumber'] = rawDebitCard;
          final digitsOnly = rawDebitCard.replaceAll(RegExp(r'\D'), '');
          if (digitsOnly.length >= 4) {
            acctMeta['debitCardLast4'] =
                digitsOnly.substring(digitsOnly.length - 4);
          }
        }
        final rawDebitExpiry = _debitCardExpiryController.text.trim();
        if (rawDebitExpiry.isNotEmpty) acctMeta['debitCardExpiry'] = rawDebitExpiry;
        final rawDebitCvv = _debitCardCvvController.text.trim();
        if (rawDebitCvv.isNotEmpty) acctMeta['debitCardCvv'] = rawDebitCvv;
        final rawDebitName = _debitCardNameController.text.trim();
        if (rawDebitName.isNotEmpty) acctMeta['debitCardNameOnCard'] = rawDebitName;
      } else if (_selectedAccountType == AccountType.credit ||
          _selectedAccountType == AccountType.payLater) {
        final rawExpiry = _creditCardExpiryController.text.trim();
        if (rawExpiry.isNotEmpty) acctMeta['cardExpiry'] = rawExpiry;
        final rawCvv = _creditCardCvvController.text.trim();
        if (rawCvv.isNotEmpty) acctMeta['cardCvv'] = rawCvv;
        final rawName = _creditCardNameController.text.trim();
        if (rawName.isNotEmpty) acctMeta['nameOnCard'] = rawName;
      }

      final account = Account(
        id: accountId,
        name: _nameController.text,
        bankName: _selectedAccountType == AccountType.cash
            ? _cashBankName
            : _selectedBank ?? 'Other',
        type: _selectedAccountType ?? AccountType.savings,
        balance: finalBalance,
        color: _selectedAccountType == AccountType.cash
            ? AppStyles.gain(context)
            : _selectedColor ?? CupertinoColors.systemBlue,
        creditCardNumber: (_selectedAccountType == AccountType.credit ||
                _selectedAccountType == AccountType.payLater)
            ? (_creditCardNumberController.text.isNotEmpty
                ? _creditCardNumberController.text
                : null)
            : null,
        creditLimit: (_selectedAccountType == AccountType.credit ||
                _selectedAccountType == AccountType.payLater)
            ? (double.tryParse(_creditLimitController.text) ?? 0.0)
            : null,
        metadata: acctMeta.isNotEmpty ? acctMeta : null,
      );
      Navigator.pop(context, account);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppStyles.getBackground(context),
      navigationBar: AppStyles.isLandscape(context) ? null : CupertinoNavigationBar(
        middle: Text(widget.existingAccount != null
            ? 'Edit Account'
            : (widget.isInvestment ? 'Investment Wizard' : 'Bank Wizard')),
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
                children: widget.isInvestment
                    ? [
                        _buildBrokerSelectionStep(),
                        _buildInvestmentDetailsStep(),
                        _buildInvestmentReviewStep(),
                      ]
                    : [
                        _buildBankSelectionStep(),
                        _buildAccountTypeStep(),
                        _buildAccountDetailsStep(),
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

  Widget _buildBrokerSelectionStep() {
    return Consumer<BrokersController>(
      builder: (context, brokersController, child) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(Spacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select your Broker',
                style: AppStyles.titleStyle(context).copyWith(fontSize: 24),
              ),
              const SizedBox(height: Spacing.sm),
              Text(
                'Which broker do you use?',
                style:
                    TextStyle(color: AppStyles.getSecondaryTextColor(context)),
              ),
              const SizedBox(height: Spacing.xxxl),
              LayoutBuilder(
                builder: (context, constraints) {
                  const cols = 2;
                  const spacing = 16.0;
                  final itemW = (constraints.maxWidth - (cols - 1) * spacing) / cols;
                  return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  crossAxisSpacing: spacing,
                  mainAxisSpacing: 16,
                  childAspectRatio: itemW / (itemW * 1.2),
                ),
                itemCount: brokersController.brokers.length,
                itemBuilder: (context, index) {
                  final broker = brokersController.brokers[index];
                  final isSelected = _selectedBroker == broker['name'];
                  return BouncyButton(
                    onPressed: () {
                      setState(() {
                        _selectedBroker = broker['name'];
                        _selectedColor = broker['color'];
                        _updateNickname();
                      });
                      // Auto-proceed to next step when broker is selected
                      _nextStep();
                    },
                    child: Container(
                      decoration: AppStyles.cardDecoration(context).copyWith(
                        border: isSelected
                            ? Border.all(
                                color: CupertinoColors.systemBlue, width: 2)
                            : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(Spacing.md),
                            decoration: BoxDecoration(
                              color: (broker['color'] as Color)
                                  .withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              CupertinoIcons.chart_bar_square_fill,
                              color: broker['color'],
                            ),
                          ),
                          const SizedBox(height: Spacing.md),
                          Text(broker['name'],
                              style: AppStyles.titleStyle(context)
                                  .copyWith(fontSize: TypeScale.body)),
                        ],
                      ),
                    ),
                  );
                },
              );
                },
              ),
              const SizedBox(height: Spacing.xxl),
              Text(
                'What should we call this account?',
                style: AppStyles.headerStyle(context),
              ),
              const SizedBox(height: Spacing.sm),
              CupertinoTextField(
                controller: _nameController,
                placeholder: 'e.g. My Demat Account',
                padding: const EdgeInsets.all(Spacing.lg),
                decoration: BoxDecoration(
                  color: AppStyles.getCardColor(context),
                  borderRadius: BorderRadius.circular(Radii.md),
                ),
                style: TextStyle(color: AppStyles.getTextColor(context)),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: Spacing.xxl),
              if (brokersController.brokers.length < 15)
                BouncyButton(
                  onPressed: () =>
                      _showAddBrokerSheet(context, brokersController),
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
                            'Add Broker',
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

  void _showAddBrokerSheet(
      BuildContext context, BrokersController brokersController) {
    final brokerNameController = TextEditingController();
    Color selectedColor = CupertinoColors.systemBlue;

    showCupertinoModalPopup(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Container(
              height: AppStyles.sheetMaxHeight(context),
              decoration: BoxDecoration(
                color: AppStyles.getCardColor(context),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      children: [
                        const ModalHandle(),
                        const SizedBox(height: Spacing.lg),
                        Text(
                          'Add New Broker',
                          style: AppStyles.titleStyle(context)
                              .copyWith(fontSize: TypeScale.title2),
                        ),
                      ],
                    ),
                  ),
                  Divider(
                      color: AppStyles.getSecondaryTextColor(context)
                          .withValues(alpha: 0.1)),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(Spacing.xxl),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Broker Name',
                            style: TextStyle(
                              fontSize: TypeScale.body,
                              fontWeight: FontWeight.w500,
                              color: AppStyles.getSecondaryTextColor(context),
                            ),
                          ),
                          const SizedBox(height: Spacing.sm),
                          CupertinoTextField(
                            controller: brokerNameController,
                            placeholder: 'Enter broker name',
                            padding: const EdgeInsets.all(Spacing.lg),
                            decoration: BoxDecoration(
                              color: AppStyles.getCardColor(context),
                              border: Border.all(
                                color: CupertinoColors.systemBlue
                                    .withValues(alpha: 0.2),
                              ),
                              borderRadius: BorderRadius.circular(Radii.md),
                            ),
                            style: TextStyle(
                                color: AppStyles.getTextColor(context)),
                          ),
                          const SizedBox(height: Spacing.xxl),
                          Text(
                            'Select Color',
                            style: TextStyle(
                              fontSize: TypeScale.body,
                              fontWeight: FontWeight.w500,
                              color: AppStyles.getSecondaryTextColor(context),
                            ),
                          ),
                          const SizedBox(height: Spacing.md),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                CupertinoColors.systemBlue,
                                AppStyles.gain(context),
                                AppStyles.loss(context),
                                CupertinoColors.systemPurple,
                                CupertinoColors.systemOrange,
                                CupertinoColors.systemTeal,
                                CupertinoColors.systemPink,
                                CupertinoColors.systemIndigo,
                              ]
                                  .map((color) => GestureDetector(
                                        onTap: () => setDialogState(
                                            () => selectedColor = color),
                                        child: Container(
                                          width: 50,
                                          height: 50,
                                          margin:
                                              const EdgeInsets.only(right: 12),
                                          decoration: BoxDecoration(
                                            color: color,
                                            shape: BoxShape.circle,
                                            border: selectedColor == color
                                                ? Border.all(
                                                    color: Colors.white,
                                                    width: 3)
                                                : null,
                                          ),
                                        ),
                                      ))
                                  .toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(Spacing.xxl),
                    child: Row(
                      children: [
                        Expanded(
                          child: BouncyButton(
                            onPressed: () => Navigator.pop(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: AppStyles.getCardColor(context),
                                border: Border.all(
                                  color: CupertinoColors.systemGrey3,
                                ),
                                borderRadius: BorderRadius.circular(Radii.md),
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
                        const SizedBox(width: Spacing.md),
                        Expanded(
                          child: BouncyButton(
                            onPressed: () {
                              if (brokerNameController.text.isNotEmpty) {
                                final newBrokerId = brokerNameController.text
                                    .replaceAll(' ', '_')
                                    .toLowerCase();
                                final newBroker = {
                                  'id': newBrokerId,
                                  'name': brokerNameController.text,
                                  'color': selectedColor,
                                };

                                brokersController.addBroker(newBroker);

                                setState(() {
                                  _selectedBroker = brokerNameController.text;
                                  _selectedColor = selectedColor;
                                  _updateNickname();
                                });

                                Navigator.pop(context);
                                // Auto-proceed to next step after adding and selecting broker
                                _nextStep();
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: CupertinoColors.systemBlue,
                                borderRadius: BorderRadius.circular(Radii.md),
                              ),
                              child: const Center(
                                child: Text(
                                  'Add & Select',
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
    ).whenComplete(brokerNameController.dispose);
  }

  Widget _buildInvestmentDetailsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(Spacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Demat Balance',
            style: AppStyles.titleStyle(context).copyWith(fontSize: 24),
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            'How much cash is available in your Demat account?',
            style: TextStyle(color: AppStyles.getSecondaryTextColor(context)),
          ),
          const SizedBox(height: Spacing.huge),
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
                    controller: _balanceController,
                    placeholder: '0.00',
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: BoxDecoration(
                      color: AppStyles.getCardColor(context),
                      borderRadius: BorderRadius.circular(Radii.md),
                    ),
                    style: AppStyles.titleStyle(context).copyWith(
                        fontSize: TypeScale.display,
                        fontWeight: FontWeight.bold),
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (value) {
                      // Auto-proceed when user taps Done on keyboard
                      if (_balanceController.text.isNotEmpty) {
                        _nextStep();
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvestmentReviewStep() {
    final balance = double.tryParse(_balanceController.text) ?? 0.0;
    final displayBalance = '₹${balance.toStringAsFixed(2)}';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(Spacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Review & Finish',
            style: AppStyles.titleStyle(context).copyWith(fontSize: 24),
          ),
          const SizedBox(height: Spacing.xxxl),
          Container(
            padding: const EdgeInsets.all(Spacing.xl),
            decoration: BoxDecoration(
              color: AppStyles.getCardColor(context),
              borderRadius: BorderRadius.circular(Radii.lg),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildReviewRow('Broker', _selectedBroker ?? 'Unknown'),
                const SizedBox(height: Spacing.lg),
                _buildReviewRow('Account Name', _nameController.text),
                const SizedBox(height: Spacing.lg),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    border: Border(
                        top: BorderSide(
                            color: CupertinoColors.systemGrey
                                .withValues(alpha: 0.2))),
                  ),
                ),
                Text(
                  'Demat Balance',
                  style: TextStyle(
                    color: AppStyles.getSecondaryTextColor(context),
                    fontSize: TypeScale.body,
                  ),
                ),
                const SizedBox(height: Spacing.sm),
                Text(
                  displayBalance,
                  style: AppStyles.titleStyle(context).copyWith(
                    fontSize: TypeScale.largeTitle,
                    color: AppStyles.accentBlue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBankSelectionStep() {
    if (widget.isInvestment) {
      // Investment brokers - use hardcoded list for now
      final items = _brokers;
      return SingleChildScrollView(
        padding: const EdgeInsets.all(Spacing.xxl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select your Broker',
              style: AppStyles.titleStyle(context).copyWith(fontSize: 24),
            ),
            const SizedBox(height: Spacing.sm),
            Text(
              'Where do you keep your money?',
              style: TextStyle(color: AppStyles.getSecondaryTextColor(context)),
            ),
            const SizedBox(height: Spacing.xxxl),
            LayoutBuilder(
              builder: (context, constraints) {
                const cols = 2;
                const spacing = 16.0;
                final itemW = (constraints.maxWidth - (cols - 1) * spacing) / cols;
                return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                crossAxisSpacing: spacing,
                mainAxisSpacing: 16,
                childAspectRatio: itemW / (itemW * 1.2),
              ),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final isSelected = _selectedBank == item['name'];
                return BouncyButton(
                  onPressed: () {
                    setState(() {
                      _selectedBank = item['name'];
                      _selectedColor = item['color'];
                    });
                    _nextStep();
                  },
                  child: Container(
                    decoration: AppStyles.cardDecoration(context).copyWith(
                      border: isSelected
                          ? Border.all(
                              color: CupertinoColors.systemBlue, width: 2)
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(Spacing.md),
                          decoration: BoxDecoration(
                            color:
                                (item['color'] as Color).withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            CupertinoIcons.chart_bar_square_fill,
                            color: item['color'],
                          ),
                        ),
                        const SizedBox(height: Spacing.md),
                        Text(item['name'],
                            style: AppStyles.titleStyle(context)
                                .copyWith(fontSize: TypeScale.body)),
                      ],
                    ),
                  ),
                );
              },
                );
              },
            ),
          ],
        ),
      );
    }

    // Bank selection with enabled banks + Add Bank option
    return Consumer<BanksController>(
      builder: (context, banksController, child) {
        final enabledBanks = banksController.enabledBanks;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(Spacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select your Bank',
                style: AppStyles.titleStyle(context).copyWith(fontSize: 24),
              ),
              const SizedBox(height: Spacing.sm),
              Text(
                'Which bank do you use?',
                style:
                    TextStyle(color: AppStyles.getSecondaryTextColor(context)),
              ),
              const SizedBox(height: Spacing.xxxl),
              if (enabledBanks.isEmpty)
                Center(
                  child: Column(
                    children: [
                      Icon(
                        CupertinoIcons.exclamationmark_circle,
                        size: 48,
                        color: AppStyles.getSecondaryTextColor(context)
                            .withValues(alpha: 0.3),
                      ),
                      const SizedBox(height: Spacing.lg),
                      Text(
                        'No banks added yet',
                        style: TextStyle(
                          color: AppStyles.getSecondaryTextColor(context),
                          fontSize: TypeScale.headline,
                        ),
                      ),
                      const SizedBox(height: Spacing.xxl),
                      BouncyButton(
                        onPressed: () =>
                            _showAddBankModal(context, banksController),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: CupertinoColors.systemBlue,
                            borderRadius: BorderRadius.circular(Radii.md),
                          ),
                          child: const Center(
                            child: Text(
                              'Add Bank',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: TypeScale.headline,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Column(
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        const cols = 2;
                        const spacing = 16.0;
                        final itemW = (constraints.maxWidth - (cols - 1) * spacing) / cols;
                        return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: cols,
                        crossAxisSpacing: spacing,
                        mainAxisSpacing: 16,
                        childAspectRatio: itemW / (itemW * 1.2),
                      ),
                      itemCount: enabledBanks.length,
                      itemBuilder: (context, index) {
                        final item = enabledBanks[index];
                        final isSelected = _selectedBank == item['name'];
                        return BouncyButton(
                          onPressed: () {
                            setState(() {
                              _selectedBank = item['name'];
                              _selectedColor = item['color'];
                            });
                            _nextStep();
                          },
                          child: Container(
                            decoration:
                                AppStyles.cardDecoration(context).copyWith(
                              border: isSelected
                                  ? Border.all(
                                      color: CupertinoColors.systemBlue,
                                      width: 2)
                                  : null,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(Spacing.md),
                                  decoration: BoxDecoration(
                                    color: (item['color'] as Color)
                                        .withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    CupertinoIcons.building_2_fill,
                                    color: item['color'],
                                  ),
                                ),
                                const SizedBox(height: Spacing.md),
                                Text(item['name'],
                                    style: AppStyles.titleStyle(context)
                                        .copyWith(fontSize: TypeScale.body)),
                              ],
                            ),
                          ),
                        );
                      },
                        );
                      },
                    ),
                    const SizedBox(height: Spacing.xxl),
                    BouncyButton(
                      onPressed: () =>
                          _showAddBankModal(context, banksController),
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
                                'Add Bank',
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

  void _showAddBankModal(
      BuildContext context, BanksController banksController) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) {
        final disabledBanks = banksController.disabledBanks;

        return Container(
          height: AppStyles.sheetMaxHeight(context),
          decoration: BoxDecoration(
            color: AppStyles.getCardColor(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Header with Add button
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Column(
                  children: [
                    const ModalHandle(),
                    const SizedBox(height: Spacing.lg),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Select Bank',
                          style: AppStyles.titleStyle(context)
                              .copyWith(fontSize: TypeScale.title2),
                        ),
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: () =>
                              _showAddCustomBankSheet(context, banksController),
                          minimumSize: const Size(40, 40),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: CupertinoColors.systemBlue
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Center(
                              child: Icon(
                                CupertinoIcons.add,
                                color: CupertinoColors.systemBlue,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Divider(
                  color: AppStyles.getSecondaryTextColor(context)
                      .withValues(alpha: 0.1)),
              // List
              Expanded(
                child: disabledBanks.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              CupertinoIcons.exclamationmark_circle,
                              size: 48,
                              color: AppStyles.getSecondaryTextColor(context)
                                  .withValues(alpha: 0.3),
                            ),
                            const SizedBox(height: Spacing.lg),
                            Text(
                              'All banks are already added',
                              style: TextStyle(
                                  color:
                                      AppStyles.getSecondaryTextColor(context)),
                            ),
                            const SizedBox(height: Spacing.lg),
                            Text(
                              'Tap + to add a custom bank',
                              style: TextStyle(
                                color: AppStyles.getSecondaryTextColor(context)
                                    .withValues(alpha: 0.7),
                                fontSize: TypeScale.footnote,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: disabledBanks.length,
                        itemBuilder: (context, index) {
                          final bank = disabledBanks[index];
                          return BouncyButton(
                            onPressed: () {
                              // Toggle bank on
                              banksController.toggleBank(bank['id'], true);
                              // Select it for wizard
                              setState(() {
                                _selectedBank = bank['name'];
                                _selectedColor = bank['color'];
                              });
                              // Close modal and move to next step
                              Navigator.pop(context);
                              _nextStep();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 16),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color:
                                        AppStyles.getSecondaryTextColor(context)
                                            .withValues(alpha: 0.1),
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: (bank['color'] as Color)
                                          .withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Icon(
                                        CupertinoIcons.building_2_fill,
                                        color: bank['color'],
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: Spacing.lg),
                                  Expanded(
                                    child: Text(
                                      bank['name'],
                                      style: AppStyles.titleStyle(context),
                                    ),
                                  ),
                                  Icon(
                                    CupertinoIcons.chevron_right,
                                    size: 16,
                                    color:
                                        AppStyles.getSecondaryTextColor(context)
                                            .withValues(alpha: 0.5),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAddCustomBankSheet(
      BuildContext context, BanksController banksController) {
    final bankNameController = TextEditingController();
    Color selectedColor = CupertinoColors.systemBlue;

    showCupertinoModalPopup(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Container(
              height: AppStyles.sheetMaxHeight(context),
              decoration: BoxDecoration(
                color: AppStyles.getCardColor(context),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      children: [
                        const ModalHandle(),
                        const SizedBox(height: Spacing.lg),
                        Text(
                          'Add New Bank',
                          style: AppStyles.titleStyle(context)
                              .copyWith(fontSize: TypeScale.title2),
                        ),
                      ],
                    ),
                  ),
                  Divider(
                      color: AppStyles.getSecondaryTextColor(context)
                          .withValues(alpha: 0.1)),
                  // Content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(Spacing.xxl),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bank Name',
                            style: TextStyle(
                              fontSize: TypeScale.body,
                              fontWeight: FontWeight.w500,
                              color: AppStyles.getSecondaryTextColor(context),
                            ),
                          ),
                          const SizedBox(height: Spacing.sm),
                          CupertinoTextField(
                            controller: bankNameController,
                            placeholder: 'Enter bank name',
                            padding: const EdgeInsets.all(Spacing.lg),
                            decoration: BoxDecoration(
                              color: AppStyles.getCardColor(context),
                              border: Border.all(
                                color: CupertinoColors.systemBlue
                                    .withValues(alpha: 0.2),
                              ),
                              borderRadius: BorderRadius.circular(Radii.md),
                            ),
                            style: TextStyle(
                                color: AppStyles.getTextColor(context)),
                          ),
                          const SizedBox(height: Spacing.xxl),
                          Text(
                            'Select Color',
                            style: TextStyle(
                              fontSize: TypeScale.body,
                              fontWeight: FontWeight.w500,
                              color: AppStyles.getSecondaryTextColor(context),
                            ),
                          ),
                          const SizedBox(height: Spacing.md),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                CupertinoColors.systemBlue,
                                AppStyles.gain(context),
                                AppStyles.loss(context),
                                CupertinoColors.systemPurple,
                                CupertinoColors.systemOrange,
                                CupertinoColors.systemTeal,
                                CupertinoColors.systemPink,
                                CupertinoColors.systemIndigo,
                              ]
                                  .map((color) => GestureDetector(
                                        onTap: () => setDialogState(
                                            () => selectedColor = color),
                                        child: Container(
                                          width: 50,
                                          height: 50,
                                          margin:
                                              const EdgeInsets.only(right: 12),
                                          decoration: BoxDecoration(
                                            color: color,
                                            shape: BoxShape.circle,
                                            border: selectedColor == color
                                                ? Border.all(
                                                    color: Colors.white,
                                                    width: 3)
                                                : null,
                                          ),
                                        ),
                                      ))
                                  .toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Footer buttons
                  Container(
                    padding: const EdgeInsets.all(Spacing.xxl),
                    child: Row(
                      children: [
                        Expanded(
                          child: BouncyButton(
                            onPressed: () => Navigator.pop(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: AppStyles.getCardColor(context),
                                border: Border.all(
                                  color: CupertinoColors.systemGrey3,
                                ),
                                borderRadius: BorderRadius.circular(Radii.md),
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
                        const SizedBox(width: Spacing.md),
                        Expanded(
                          child: BouncyButton(
                            onPressed: () {
                              if (bankNameController.text.trim().isNotEmpty) {
                                final name = bankNameController.text.trim();
                                if (banksController.bankNameExists(name)) {
                                  toast_lib.toast
                                      .showError('"$name" already exists');
                                  return;
                                }
                                // Add new bank to controller
                                final newBankId =
                                    name.replaceAll(' ', '_').toLowerCase();
                                final newBank = {
                                  'id': newBankId,
                                  'name': name,
                                  'color': selectedColor,
                                  'isEnabled': true,
                                  'senderIds': <String>[],
                                };

                                // Add to controller
                                banksController.addBank(newBank);

                                // Select it for wizard
                                setState(() {
                                  _selectedBank = name;
                                  _selectedColor = selectedColor;
                                });

                                // Close modals and move to next step
                                Navigator.pop(context); // Close add bank sheet
                                Navigator.pop(
                                    context); // Close select bank modal
                                _nextStep();
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: CupertinoColors.systemBlue,
                                borderRadius: BorderRadius.circular(Radii.md),
                              ),
                              child: const Center(
                                child: Text(
                                  'Add & Select',
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
    ).whenComplete(bankNameController.dispose);
  }

  Widget _buildAccountTypeStep() {
    final accountTypes = [
      {
        'type': AccountType.savings,
        'label': 'Savings Account',
        'icon': CupertinoIcons.book_fill
      },
      {
        'type': AccountType.current,
        'label': 'Current Account',
        'icon': CupertinoIcons.briefcase_fill
      },
      {
        'type': AccountType.credit,
        'label': 'Credit Card',
        'icon': CupertinoIcons.creditcard_fill
      },
      {
        'type': AccountType.payLater,
        'label': 'Pay Later (BNPL)',
        'icon': CupertinoIcons.clock_fill
      },
      {
        'type': AccountType.wallet,
        'label': 'Digital Wallet',
        'icon': CupertinoIcons.square_stack_3d_down_right_fill
      },
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(Spacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Account Type',
            style: AppStyles.titleStyle(context).copyWith(fontSize: 24),
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            'What type of account?',
            style: TextStyle(color: AppStyles.getSecondaryTextColor(context)),
          ),
          const SizedBox(height: Spacing.xxxl),
          Column(
            children: accountTypes.map((item) {
              final isSelected = _selectedAccountType == item['type'];
              return GestureDetector(
                onTap: () {
                  final selectedType = item['type'] as AccountType;
                  setState(() {
                    _selectedAccountType = selectedType;
                    if (selectedType == AccountType.cash) {
                      _selectedBank = _cashBankName;
                      _selectedColor = AppStyles.gain(context);
                    } else if (_selectedBank == _cashBankName) {
                      _selectedBank = 'Other';
                    }
                    _updateNickname();
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
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color:
                              CupertinoColors.systemBlue.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Icon(
                            item['icon'] as IconData,
                            color: CupertinoColors.systemBlue,
                            size: 24,
                          ),
                        ),
                      ),
                      const SizedBox(width: Spacing.lg),
                      Expanded(
                        child: Text(
                          item['label'] as String,
                          style: AppStyles.titleStyle(context)
                              .copyWith(fontSize: TypeScale.headline),
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
          const SizedBox(height: Spacing.lg),
          Text(
            'Account Nickname',
            style: AppStyles.headerStyle(context),
          ),
          const SizedBox(height: Spacing.sm),
          CupertinoTextField(
            controller: _nameController,
            placeholder: 'e.g. My Savings Account',
            padding: const EdgeInsets.all(Spacing.lg),
            decoration: BoxDecoration(
              color: AppStyles.getCardColor(context),
              borderRadius: BorderRadius.circular(Radii.md),
            ),
            style: TextStyle(color: AppStyles.getTextColor(context)),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountDetailsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(Spacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Account Details',
            style: AppStyles.titleStyle(context).copyWith(fontSize: 24),
          ),
          const SizedBox(height: Spacing.xxxl),
          if (_selectedAccountType == AccountType.savings ||
              _selectedAccountType == AccountType.current) ...[
            Text('Account Number', style: AppStyles.headerStyle(context)),
            const SizedBox(height: Spacing.xs),
            Text(
              '(Optional - full or last 4 digits)',
              style: TextStyle(
                  fontSize: TypeScale.footnote,
                  color: AppStyles.getSecondaryTextColor(context)),
            ),
            const SizedBox(height: Spacing.sm),
            CupertinoTextField(
              controller: _accountNumberController,
              placeholder: 'Enter account number',
              keyboardType: TextInputType.number,
              padding: const EdgeInsets.all(Spacing.lg),
              decoration: BoxDecoration(
                color: AppStyles.getCardColor(context),
                borderRadius: BorderRadius.circular(Radii.md),
              ),
              style: TextStyle(color: AppStyles.getTextColor(context)),
            ),
            const SizedBox(height: Spacing.xl),
            Text('IFSC Code', style: AppStyles.headerStyle(context)),
            const SizedBox(height: Spacing.xs),
            Text(
              '(Optional)',
              style: TextStyle(
                  fontSize: TypeScale.footnote,
                  color: AppStyles.getSecondaryTextColor(context)),
            ),
            const SizedBox(height: Spacing.sm),
            CupertinoTextField(
              controller: _ifscController,
              placeholder: 'e.g. HDFC0001234',
              textCapitalization: TextCapitalization.characters,
              padding: const EdgeInsets.all(Spacing.lg),
              decoration: BoxDecoration(
                color: AppStyles.getCardColor(context),
                borderRadius: BorderRadius.circular(Radii.md),
              ),
              style: TextStyle(color: AppStyles.getTextColor(context)),
            ),
            const SizedBox(height: Spacing.xxxl),
            Text('Debit Card', style: AppStyles.titleStyle(context).copyWith(fontSize: 18)),
            const SizedBox(height: Spacing.xs),
            Text(
              'Optional — leave blank if no debit card',
              style: TextStyle(
                  fontSize: TypeScale.footnote,
                  color: AppStyles.getSecondaryTextColor(context)),
            ),
            const SizedBox(height: Spacing.lg),
            Text('Card Number', style: AppStyles.headerStyle(context)),
            const SizedBox(height: Spacing.xs),
            Text(
              '(Full or last 4 digits)',
              style: TextStyle(
                  fontSize: TypeScale.footnote,
                  color: AppStyles.getSecondaryTextColor(context)),
            ),
            const SizedBox(height: Spacing.sm),
            CupertinoTextField(
              controller: _debitCardNumberController,
              placeholder: 'Enter debit card number',
              keyboardType: TextInputType.number,
              padding: const EdgeInsets.all(Spacing.lg),
              decoration: BoxDecoration(
                color: AppStyles.getCardColor(context),
                borderRadius: BorderRadius.circular(Radii.md),
              ),
              style: TextStyle(color: AppStyles.getTextColor(context)),
            ),
            const SizedBox(height: Spacing.xl),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Expiry', style: AppStyles.headerStyle(context)),
                      const SizedBox(height: Spacing.sm),
                      CupertinoTextField(
                        controller: _debitCardExpiryController,
                        placeholder: 'MM/YY',
                        keyboardType: TextInputType.number,
                        inputFormatters: [_ExpiryInputFormatter()],
                        maxLength: 5,
                        padding: const EdgeInsets.all(Spacing.lg),
                        decoration: BoxDecoration(
                          color: AppStyles.getCardColor(context),
                          borderRadius: BorderRadius.circular(Radii.md),
                        ),
                        style: TextStyle(color: AppStyles.getTextColor(context)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: Spacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('CVV', style: AppStyles.headerStyle(context)),
                      const SizedBox(height: Spacing.sm),
                      CupertinoTextField(
                        controller: _debitCardCvvController,
                        placeholder: '•••',
                        keyboardType: TextInputType.number,
                        padding: const EdgeInsets.all(Spacing.lg),
                        decoration: BoxDecoration(
                          color: AppStyles.getCardColor(context),
                          borderRadius: BorderRadius.circular(Radii.md),
                        ),
                        style: TextStyle(color: AppStyles.getTextColor(context)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: Spacing.xl),
            Text('Name on Card', style: AppStyles.headerStyle(context)),
            const SizedBox(height: Spacing.sm),
            CupertinoTextField(
              controller: _debitCardNameController,
              placeholder: 'As printed on card',
              textCapitalization: TextCapitalization.words,
              padding: const EdgeInsets.all(Spacing.lg),
              decoration: BoxDecoration(
                color: AppStyles.getCardColor(context),
                borderRadius: BorderRadius.circular(Radii.md),
              ),
              style: TextStyle(color: AppStyles.getTextColor(context)),
            ),
            const SizedBox(height: Spacing.xl),
            Text('Opening Balance', style: AppStyles.headerStyle(context)),
            const SizedBox(height: Spacing.sm),
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
                      controller: _balanceController,
                      placeholder: '0.00',
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: BoxDecoration(
                        color: AppStyles.getCardColor(context),
                        borderRadius: BorderRadius.circular(Radii.md),
                      ),
                      style: AppStyles.titleStyle(context).copyWith(
                          fontSize: TypeScale.display,
                          fontWeight: FontWeight.bold),
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (value) {
                        // Auto-proceed when user taps Done on keyboard
                        if (_balanceController.text.isNotEmpty) {
                          _nextStep();
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ] else if (_selectedAccountType == AccountType.credit ||
              _selectedAccountType == AccountType.payLater) ...[
            Text('Credit Limit', style: AppStyles.headerStyle(context)),
            const SizedBox(height: Spacing.sm),
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
                      controller: _creditLimitController,
                      placeholder: '0.00',
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
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
            const SizedBox(height: Spacing.xl),
            Text('Amount Used', style: AppStyles.headerStyle(context)),
            const SizedBox(height: Spacing.sm),
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
                      controller: _amountUsedController,
                      placeholder: '0.00',
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: BoxDecoration(
                        color: AppStyles.getCardColor(context),
                        borderRadius: BorderRadius.circular(Radii.md),
                      ),
                      style: AppStyles.titleStyle(context).copyWith(
                          fontSize: TypeScale.display,
                          fontWeight: FontWeight.bold),
                      onSubmitted: (value) {
                        // Auto-proceed when user taps Done on keyboard if credit limit is filled
                        if (_creditLimitController.text.isNotEmpty) {
                          _nextStep();
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Spacing.xl),
            Text('Credit Card Number', style: AppStyles.headerStyle(context)),
            const SizedBox(height: Spacing.xs),
            Text(
              '(Optional - full or last 4 digits)',
              style: TextStyle(
                  fontSize: TypeScale.footnote,
                  color: AppStyles.getSecondaryTextColor(context)),
            ),
            const SizedBox(height: Spacing.sm),
            CupertinoTextField(
              controller: _creditCardNumberController,
              placeholder: 'Enter credit card number',
              keyboardType: TextInputType.number,
              padding: const EdgeInsets.all(Spacing.lg),
              decoration: BoxDecoration(
                color: AppStyles.getCardColor(context),
                borderRadius: BorderRadius.circular(Radii.md),
              ),
              style: TextStyle(color: AppStyles.getTextColor(context)),
            ),
            const SizedBox(height: Spacing.xl),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Expiry', style: AppStyles.headerStyle(context)),
                      const SizedBox(height: Spacing.sm),
                      CupertinoTextField(
                        controller: _creditCardExpiryController,
                        placeholder: 'MM/YY',
                        keyboardType: TextInputType.number,
                        inputFormatters: [_ExpiryInputFormatter()],
                        maxLength: 5,
                        padding: const EdgeInsets.all(Spacing.lg),
                        decoration: BoxDecoration(
                          color: AppStyles.getCardColor(context),
                          borderRadius: BorderRadius.circular(Radii.md),
                        ),
                        style: TextStyle(color: AppStyles.getTextColor(context)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: Spacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('CVV', style: AppStyles.headerStyle(context)),
                      const SizedBox(height: Spacing.sm),
                      CupertinoTextField(
                        controller: _creditCardCvvController,
                        placeholder: '•••',
                        keyboardType: TextInputType.number,
                        padding: const EdgeInsets.all(Spacing.lg),
                        decoration: BoxDecoration(
                          color: AppStyles.getCardColor(context),
                          borderRadius: BorderRadius.circular(Radii.md),
                        ),
                        style: TextStyle(color: AppStyles.getTextColor(context)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: Spacing.xl),
            Text('Name on Card', style: AppStyles.headerStyle(context)),
            const SizedBox(height: Spacing.sm),
            CupertinoTextField(
              controller: _creditCardNameController,
              placeholder: 'As printed on card',
              textCapitalization: TextCapitalization.words,
              padding: const EdgeInsets.all(Spacing.lg),
              decoration: BoxDecoration(
                color: AppStyles.getCardColor(context),
                borderRadius: BorderRadius.circular(Radii.md),
              ),
              style: TextStyle(color: AppStyles.getTextColor(context)),
            ),
          ] else if (_selectedAccountType == AccountType.wallet ||
              _selectedAccountType == AccountType.investment ||
              _selectedAccountType == AccountType.cash) ...[
            Text(
              'Opening Balance',
              style: AppStyles.headerStyle(context),
            ),
            const SizedBox(height: Spacing.sm),
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
                      controller: _balanceController,
                      placeholder: '0.00',
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: BoxDecoration(
                        color: AppStyles.getCardColor(context),
                        borderRadius: BorderRadius.circular(Radii.md),
                      ),
                      style: AppStyles.titleStyle(context).copyWith(
                          fontSize: TypeScale.display,
                          fontWeight: FontWeight.bold),
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (value) {
                        // Auto-proceed when user taps Done on keyboard
                        if (_balanceController.text.isNotEmpty) {
                          _nextStep();
                        }
                      },
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

  Widget _buildReviewStep() {
    String displayBalance = '₹0.00';
    if (_selectedAccountType == AccountType.credit ||
        _selectedAccountType == AccountType.payLater) {
      final creditLimit = double.tryParse(_creditLimitController.text) ?? 0.0;
      final amountUsed = double.tryParse(_amountUsedController.text) ?? 0.0;
      final available = creditLimit - amountUsed;
      displayBalance = '₹${available.toStringAsFixed(2)}';
    } else {
      final balance = double.tryParse(_balanceController.text) ?? 0.0;
      displayBalance = '₹${balance.toStringAsFixed(2)}';
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(Spacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Review & Finish',
            style: AppStyles.titleStyle(context).copyWith(fontSize: 24),
          ),
          const SizedBox(height: Spacing.xxxl),
          Container(
            padding: const EdgeInsets.all(Spacing.xl),
            decoration: BoxDecoration(
              color: AppStyles.getCardColor(context),
              borderRadius: BorderRadius.circular(Radii.lg),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildReviewRow(
                  _selectedAccountType == AccountType.cash ? 'Source' : 'Bank',
                  _selectedAccountType == AccountType.cash
                      ? _cashBankName
                      : _selectedBank ?? 'Unknown',
                ),
                const SizedBox(height: Spacing.lg),
                _buildReviewRow(
                    'Account Type',
                    _getAccountTypeLabel(
                        _selectedAccountType ?? AccountType.savings)),
                const SizedBox(height: Spacing.lg),
                _buildReviewRow('Account Name', _nameController.text),
                const SizedBox(height: Spacing.lg),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    border: Border(
                        top: BorderSide(
                            color: CupertinoColors.systemGrey
                                .withValues(alpha: 0.2))),
                  ),
                ),
                Text(
                  'Available Balance',
                  style: TextStyle(
                    color: AppStyles.getSecondaryTextColor(context),
                    fontSize: TypeScale.body,
                  ),
                ),
                const SizedBox(height: Spacing.sm),
                Text(
                  displayBalance,
                  style: AppStyles.titleStyle(context).copyWith(
                    fontSize: TypeScale.largeTitle,
                    color: AppStyles.accentBlue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppStyles.getSecondaryTextColor(context),
            fontSize: TypeScale.body,
          ),
        ),
        const SizedBox(width: Spacing.sm),
        Expanded(
          child: Text(
            value,
            style: AppStyles.titleStyle(context)
                .copyWith(fontWeight: FontWeight.w600),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    bool canGoNext = false;

    if (widget.isInvestment) {
      // Investment account validation (3 steps)
      switch (_currentStep) {
        case 0: // Select Broker
          canGoNext =
              _selectedBroker != null && _nameController.text.isNotEmpty;
          break;
        case 1: // Account Balance
          canGoNext = _balanceController.text.isNotEmpty;
          break;
        case 2: // Review
          canGoNext = true;
          break;
      }
    } else {
      // Bank account validation (4 steps)
      switch (_currentStep) {
        case 0: // Select Bank
          canGoNext = _selectedBank != null;
          break;
        case 1: // Account Type
          canGoNext =
              _selectedAccountType != null && _nameController.text.isNotEmpty;
          break;
        case 2: // Account Details
          if (_selectedAccountType == AccountType.credit ||
              _selectedAccountType == AccountType.payLater) {
            canGoNext = _creditLimitController.text.isNotEmpty;
          } else {
            canGoNext = _balanceController.text.isNotEmpty;
          }
          break;
        case 3: // Review
          canGoNext = true;
          break;
      }
    }

    return Padding(
      padding: const EdgeInsets.all(Spacing.xxl),
      child: BouncyButton(
        onPressed: canGoNext ? _nextStep : () {},
        child: Opacity(
          opacity: canGoNext ? 1.0 : 0.5,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: CupertinoColors.systemBlue,
              borderRadius: BorderRadius.circular(Radii.lg),
            ),
            child: Center(
              child: Text(
                _currentStep == _totalSteps - 1 ? 'Finish' : 'Next',
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

/// Auto-inserts "/" after the first two digits so expiry is formatted MM/YY.
class _ExpiryInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    // Cap at 4 digits (MMYY)
    final capped = digits.length > 4 ? digits.substring(0, 4) : digits;

    String formatted;
    if (capped.length <= 2) {
      formatted = capped;
    } else {
      formatted = '${capped.substring(0, 2)}/${capped.substring(2)}';
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
