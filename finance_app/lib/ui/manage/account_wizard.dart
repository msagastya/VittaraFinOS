import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/account_model.dart';
import 'package:vittara_fin_os/logic/banks_controller.dart';
import 'package:vittara_fin_os/logic/brokers_controller.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/widgets/animations.dart';

class AccountWizard extends StatefulWidget {
  final bool isInvestment;
  const AccountWizard({super.key, this.isInvestment = false});

  @override
  State<AccountWizard> createState() => _AccountWizardState();
}

class _AccountWizardState extends State<AccountWizard> {
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
  final TextEditingController _accountNumberController = TextEditingController();
  final TextEditingController _debitCardNumberController = TextEditingController();
  final TextEditingController _creditLimitController = TextEditingController();
  final TextEditingController _amountUsedController = TextEditingController();
  final TextEditingController _balanceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Set total steps based on account type
    _totalSteps = widget.isInvestment ? 3 : 4;

    // Add listeners to update UI when text changes
    _creditLimitController.addListener(() => setState(() {}));
    _amountUsedController.addListener(() => setState(() {}));
    _balanceController.addListener(() => setState(() {}));
    _nameController.addListener(() => setState(() {}));
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
    _balanceController.dispose();
    super.dispose();
  }

  void _updateNickname() {
    if (widget.isInvestment) {
      if (_selectedBroker != null) {
        _nameController.text = '$_selectedBroker - Demat';
      }
    } else {
      if (_selectedBank != null && _selectedAccountType != null) {
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
    }
  }

  void _nextStep() {
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

    if (widget.isInvestment) {
      // Investment account: use balance directly
      finalBalance = double.tryParse(_balanceController.text) ?? 0.0;

      final account = Account(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text,
        bankName: _selectedBroker ?? 'Unknown Broker',
        type: AccountType.investment,
        balance: finalBalance,
        color: _selectedColor ?? CupertinoColors.systemBlue,
      );
      Navigator.pop(context, account);
    } else {
      // Bank account: calculate balance based on account type
      if (_selectedAccountType == AccountType.credit || _selectedAccountType == AccountType.payLater) {
        // For credit card and pay later: Balance = Credit Limit - Amount Used
        final creditLimit = double.tryParse(_creditLimitController.text) ?? 0.0;
        final amountUsed = double.tryParse(_amountUsedController.text) ?? 0.0;
        finalBalance = creditLimit - amountUsed;
      } else {
        // For other types: use opening balance directly
        finalBalance = double.tryParse(_balanceController.text) ?? 0.0;
      }

      final account = Account(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text,
        bankName: _selectedBank ?? 'Other',
        type: _selectedAccountType ?? AccountType.savings,
        balance: finalBalance,
        color: _selectedColor ?? CupertinoColors.systemBlue,
      );
      Navigator.pop(context, account);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppStyles.getBackground(context),
      navigationBar: CupertinoNavigationBar(
        middle: Text(widget.isInvestment ? 'Investment Wizard' : 'Bank Wizard'),
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
                color: isActive ? CupertinoColors.systemBlue : CupertinoColors.systemGrey.withValues(alpha: 0.2),
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
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select your Broker',
                style: AppStyles.titleStyle(context).copyWith(fontSize: 24),
              ),
              const SizedBox(height: 8),
              Text(
                'Which broker do you use?',
                style: TextStyle(color: AppStyles.getSecondaryTextColor(context)),
              ),
              const SizedBox(height: 32),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.2,
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
                            ? Border.all(color: CupertinoColors.systemBlue, width: 2)
                            : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: (broker['color'] as Color).withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              CupertinoIcons.chart_bar_square_fill,
                              color: broker['color'],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(broker['name'],
                              style: AppStyles.titleStyle(context)
                                  .copyWith(fontSize: 14)),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              Text(
                'What should we call this account?',
                style: AppStyles.headerStyle(context),
              ),
              const SizedBox(height: 8),
              CupertinoTextField(
                controller: _nameController,
                placeholder: 'e.g. My Demat Account',
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppStyles.getCardColor(context),
                  borderRadius: BorderRadius.circular(12),
                ),
                style: TextStyle(color: AppStyles.getTextColor(context)),
              ),
              const SizedBox(height: 24),
              if (brokersController.brokers.length < 15)
                BouncyButton(
                  onPressed: () => _showAddBrokerSheet(context, brokersController),
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
                          Icon(CupertinoIcons.add, color: CupertinoColors.systemBlue),
                          const SizedBox(width: 8),
                          Text(
                            'Add Broker',
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

  void _showAddBrokerSheet(BuildContext context, BrokersController brokersController) {
    final brokerNameController = TextEditingController();
    Color selectedColor = CupertinoColors.systemBlue;

    showCupertinoModalPopup(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.6,
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
                          'Add New Broker',
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
                            'Broker Name',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppStyles.getSecondaryTextColor(context),
                            ),
                          ),
                          const SizedBox(height: 8),
                          CupertinoTextField(
                            controller: brokerNameController,
                            placeholder: 'Enter broker name',
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
                            'Select Color',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppStyles.getSecondaryTextColor(context),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                CupertinoColors.systemBlue,
                                CupertinoColors.systemGreen,
                                CupertinoColors.systemRed,
                                CupertinoColors.systemPurple,
                                CupertinoColors.systemOrange,
                                CupertinoColors.systemTeal,
                                CupertinoColors.systemPink,
                                CupertinoColors.systemIndigo,
                              ]
                                  .map((color) => GestureDetector(
                                    onTap: () => setDialogState(() => selectedColor = color),
                                    child: Container(
                                      width: 50,
                                      height: 50,
                                      margin: const EdgeInsets.only(right: 12),
                                      decoration: BoxDecoration(
                                        color: color,
                                        shape: BoxShape.circle,
                                        border: selectedColor == color
                                            ? Border.all(color: Colors.white, width: 3)
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
                    padding: const EdgeInsets.all(24),
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
                                borderRadius: BorderRadius.circular(12),
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
    );
  }

  Widget _buildInvestmentDetailsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Demat Balance',
            style: AppStyles.titleStyle(context).copyWith(fontSize: 24),
          ),
          const SizedBox(height: 8),
          Text(
            'How much cash is available in your Demat account?',
            style: TextStyle(color: AppStyles.getSecondaryTextColor(context)),
          ),
          const SizedBox(height: 48),
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('₹', style: AppStyles.titleStyle(context).copyWith(fontSize: 32)),
                const SizedBox(width: 8),
                IntrinsicWidth(
                  child: CupertinoTextField(
                    controller: _balanceController,
                    placeholder: '0.00',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: BoxDecoration(
                      color: AppStyles.getCardColor(context),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    style: AppStyles.titleStyle(context).copyWith(fontSize: 32, fontWeight: FontWeight.bold),
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
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Review & Finish',
            style: AppStyles.titleStyle(context).copyWith(fontSize: 24),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppStyles.getCardColor(context),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildReviewRow('Broker', _selectedBroker ?? 'Unknown'),
                const SizedBox(height: 16),
                _buildReviewRow('Account Name', _nameController.text),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    border: Border(
                        top: BorderSide(
                            color: CupertinoColors.systemGrey.withValues(alpha: 0.2))),
                  ),
                ),
                Text(
                  'Demat Balance',
                  style: TextStyle(
                    color: AppStyles.getSecondaryTextColor(context),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  displayBalance,
                  style: AppStyles.titleStyle(context).copyWith(
                    fontSize: 28,
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
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select your Broker',
              style: AppStyles.titleStyle(context).copyWith(fontSize: 24),
            ),
            const SizedBox(height: 8),
            Text(
              'Where do you keep your money?',
              style: TextStyle(color: AppStyles.getSecondaryTextColor(context)),
            ),
            const SizedBox(height: 32),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.2,
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
                      border: isSelected ? Border.all(color: CupertinoColors.systemBlue, width: 2) : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: (item['color'] as Color).withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            CupertinoIcons.chart_bar_square_fill,
                            color: item['color'],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(item['name'], style: AppStyles.titleStyle(context).copyWith(fontSize: 14)),
                      ],
                    ),
                  ),
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
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select your Bank',
                style: AppStyles.titleStyle(context).copyWith(fontSize: 24),
              ),
              const SizedBox(height: 8),
              Text(
                'Where do you keep your money?',
                style: TextStyle(color: AppStyles.getSecondaryTextColor(context)),
              ),
              const SizedBox(height: 32),
              if (enabledBanks.isEmpty)
                Center(
                  child: Column(
                    children: [
                      Icon(
                        CupertinoIcons.exclamationmark_circle,
                        size: 48,
                        color: AppStyles.getSecondaryTextColor(context).withValues(alpha: 0.3),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No banks added yet',
                        style: TextStyle(
                          color: AppStyles.getSecondaryTextColor(context),
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 24),
                      BouncyButton(
                        onPressed: () => _showAddBankModal(context, banksController),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: CupertinoColors.systemBlue,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              'Add Bank',
                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
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
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 1.2,
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
                            decoration: AppStyles.cardDecoration(context).copyWith(
                              border: isSelected ? Border.all(color: CupertinoColors.systemBlue, width: 2) : null,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: (item['color'] as Color).withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    CupertinoIcons.building_2_fill,
                                    color: item['color'],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(item['name'], style: AppStyles.titleStyle(context).copyWith(fontSize: 14)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    BouncyButton(
                      onPressed: () => _showAddBankModal(context, banksController),
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
                              Icon(CupertinoIcons.add, color: CupertinoColors.systemBlue),
                              const SizedBox(width: 8),
                              Text(
                                'Add Bank',
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
            ],
          ),
        );
      },
    );
  }

  void _showAddBankModal(BuildContext context, BanksController banksController) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) {
        final disabledBanks = banksController.disabledBanks;

        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: AppStyles.getCardColor(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Header with Add button
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Select Bank',
                          style: AppStyles.titleStyle(context).copyWith(fontSize: 20),
                        ),
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          minSize: 40,
                          onPressed: () => _showAddCustomBankSheet(context, banksController),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: CupertinoColors.systemBlue.withValues(alpha: 0.1),
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
              Divider(color: AppStyles.getSecondaryTextColor(context).withValues(alpha: 0.1)),
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
                              color: AppStyles.getSecondaryTextColor(context).withValues(alpha: 0.3),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'All banks are already added',
                              style: TextStyle(color: AppStyles.getSecondaryTextColor(context)),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Tap + to add a custom bank',
                              style: TextStyle(
                                color: AppStyles.getSecondaryTextColor(context).withValues(alpha: 0.7),
                                fontSize: 12,
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
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: AppStyles.getSecondaryTextColor(context).withValues(alpha: 0.1),
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: (bank['color'] as Color).withValues(alpha: 0.1),
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
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Text(
                                      bank['name'],
                                      style: AppStyles.titleStyle(context),
                                    ),
                                  ),
                                  Icon(
                                    CupertinoIcons.chevron_right,
                                    size: 16,
                                    color: AppStyles.getSecondaryTextColor(context).withValues(alpha: 0.5),
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

  void _showAddCustomBankSheet(BuildContext context, BanksController banksController) {
    final bankNameController = TextEditingController();
    Color selectedColor = CupertinoColors.systemBlue;

    showCupertinoModalPopup(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.6,
              decoration: BoxDecoration(
                color: AppStyles.getCardColor(context),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  // Header
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
                          'Add New Bank',
                          style: AppStyles.titleStyle(context).copyWith(fontSize: 20),
                        ),
                      ],
                    ),
                  ),
                  Divider(color: AppStyles.getSecondaryTextColor(context).withValues(alpha: 0.1)),
                  // Content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bank Name',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppStyles.getSecondaryTextColor(context),
                            ),
                          ),
                          const SizedBox(height: 8),
                          CupertinoTextField(
                            controller: bankNameController,
                            placeholder: 'Enter bank name',
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
                            'Select Color',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppStyles.getSecondaryTextColor(context),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                CupertinoColors.systemBlue,
                                CupertinoColors.systemGreen,
                                CupertinoColors.systemRed,
                                CupertinoColors.systemPurple,
                                CupertinoColors.systemOrange,
                                CupertinoColors.systemTeal,
                                CupertinoColors.systemPink,
                                CupertinoColors.systemIndigo,
                              ]
                                  .map((color) => GestureDetector(
                                    onTap: () => setDialogState(() => selectedColor = color),
                                    child: Container(
                                      width: 50,
                                      height: 50,
                                      margin: const EdgeInsets.only(right: 12),
                                      decoration: BoxDecoration(
                                        color: color,
                                        shape: BoxShape.circle,
                                        border: selectedColor == color
                                            ? Border.all(color: Colors.white, width: 3)
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
                    padding: const EdgeInsets.all(24),
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
                              if (bankNameController.text.isNotEmpty) {
                                // Add new bank to controller
                                final newBankId =
                                    bankNameController.text.replaceAll(' ', '_').toLowerCase();
                                final newBank = {
                                  'id': newBankId,
                                  'name': bankNameController.text,
                                  'color': selectedColor,
                                  'isEnabled': true,
                                  'senderIds': <String>[],
                                };

                                // Add to controller
                                banksController.addBank(newBank);

                                // Select it for wizard
                                setState(() {
                                  _selectedBank = bankNameController.text;
                                  _selectedColor = selectedColor;
                                });

                                // Close modals and move to next step
                                Navigator.pop(context); // Close add bank sheet
                                Navigator.pop(context); // Close select bank modal
                                _nextStep();
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
    );
  }

  Widget _buildAccountTypeStep() {
    final accountTypes = [
      {'type': AccountType.savings, 'label': 'Savings Account', 'icon': CupertinoIcons.book_fill},
      {'type': AccountType.current, 'label': 'Current Account', 'icon': CupertinoIcons.briefcase_fill},
      {'type': AccountType.credit, 'label': 'Credit Card', 'icon': CupertinoIcons.creditcard_fill},
      {'type': AccountType.payLater, 'label': 'Pay Later (BNPL)', 'icon': CupertinoIcons.clock_fill},
      {'type': AccountType.wallet, 'label': 'Digital Wallet', 'icon': CupertinoIcons.square_stack_3d_down_right_fill},
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Account Type',
            style: AppStyles.titleStyle(context).copyWith(fontSize: 24),
          ),
          const SizedBox(height: 8),
          Text(
            'What type of account?',
            style: TextStyle(color: AppStyles.getSecondaryTextColor(context)),
          ),
          const SizedBox(height: 32),
          Column(
            children: accountTypes.map((item) {
              final isSelected = _selectedAccountType == item['type'];
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedAccountType = item['type'] as AccountType;
                    _updateNickname();
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
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: CupertinoColors.systemBlue.withValues(alpha: 0.1),
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
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          item['label'] as String,
                          style: AppStyles.titleStyle(context).copyWith(fontSize: 16),
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
          const SizedBox(height: 16),
          Text(
            'Account Nickname',
            style: AppStyles.headerStyle(context),
          ),
          const SizedBox(height: 8),
          CupertinoTextField(
            controller: _nameController,
            placeholder: 'e.g. My Savings Account',
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppStyles.getCardColor(context),
              borderRadius: BorderRadius.circular(12),
            ),
            style: TextStyle(color: AppStyles.getTextColor(context)),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountDetailsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Account Details',
            style: AppStyles.titleStyle(context).copyWith(fontSize: 24),
          ),
          const SizedBox(height: 32),
          if (_selectedAccountType == AccountType.savings || _selectedAccountType == AccountType.current) ...[
            Text('Account Number', style: AppStyles.headerStyle(context)),
            const SizedBox(height: 4),
            Text(
              '(Optional - full or last 4 digits)',
              style: TextStyle(fontSize: 12, color: AppStyles.getSecondaryTextColor(context)),
            ),
            const SizedBox(height: 8),
            CupertinoTextField(
              controller: _accountNumberController,
              placeholder: 'Enter account number',
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppStyles.getCardColor(context),
                borderRadius: BorderRadius.circular(12),
              ),
              style: TextStyle(color: AppStyles.getTextColor(context)),
            ),
            const SizedBox(height: 20),
            Text('Debit Card Number', style: AppStyles.headerStyle(context)),
            const SizedBox(height: 4),
            Text(
              '(Optional - full or last 4 digits)',
              style: TextStyle(fontSize: 12, color: AppStyles.getSecondaryTextColor(context)),
            ),
            const SizedBox(height: 8),
            CupertinoTextField(
              controller: _debitCardNumberController,
              placeholder: 'Enter debit card number',
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppStyles.getCardColor(context),
                borderRadius: BorderRadius.circular(12),
              ),
              style: TextStyle(color: AppStyles.getTextColor(context)),
            ),
            const SizedBox(height: 20),
            Text('Opening Balance', style: AppStyles.headerStyle(context)),
            const SizedBox(height: 8),
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('₹', style: AppStyles.titleStyle(context).copyWith(fontSize: 32)),
                  const SizedBox(width: 8),
                  IntrinsicWidth(
                    child: CupertinoTextField(
                      controller: _balanceController,
                      placeholder: '0.00',
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: BoxDecoration(
                        color: AppStyles.getCardColor(context),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      style: AppStyles.titleStyle(context).copyWith(fontSize: 32, fontWeight: FontWeight.bold),
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
          ] else if (_selectedAccountType == AccountType.credit || _selectedAccountType == AccountType.payLater) ...[
            Text('Credit Limit', style: AppStyles.headerStyle(context)),
            const SizedBox(height: 8),
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('₹', style: AppStyles.titleStyle(context).copyWith(fontSize: 32)),
                  const SizedBox(width: 8),
                  IntrinsicWidth(
                    child: CupertinoTextField(
                      controller: _creditLimitController,
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
            const SizedBox(height: 20),
            Text('Amount Used', style: AppStyles.headerStyle(context)),
            const SizedBox(height: 8),
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('₹', style: AppStyles.titleStyle(context).copyWith(fontSize: 32)),
                  const SizedBox(width: 8),
                  IntrinsicWidth(
                    child: CupertinoTextField(
                      controller: _amountUsedController,
                      placeholder: '0.00',
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: BoxDecoration(
                        color: AppStyles.getCardColor(context),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      style: AppStyles.titleStyle(context).copyWith(fontSize: 32, fontWeight: FontWeight.bold),
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
          ] else if (_selectedAccountType == AccountType.wallet || _selectedAccountType == AccountType.investment) ...[
            Text('Opening Balance', style: AppStyles.headerStyle(context)),
            const SizedBox(height: 8),
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('₹', style: AppStyles.titleStyle(context).copyWith(fontSize: 32)),
                  const SizedBox(width: 8),
                  IntrinsicWidth(
                    child: CupertinoTextField(
                      controller: _balanceController,
                      placeholder: '0.00',
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: BoxDecoration(
                        color: AppStyles.getCardColor(context),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      style: AppStyles.titleStyle(context).copyWith(fontSize: 32, fontWeight: FontWeight.bold),
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
    if (_selectedAccountType == AccountType.credit || _selectedAccountType == AccountType.payLater) {
      final creditLimit = double.tryParse(_creditLimitController.text) ?? 0.0;
      final amountUsed = double.tryParse(_amountUsedController.text) ?? 0.0;
      final available = creditLimit - amountUsed;
      displayBalance = '₹${available.toStringAsFixed(2)}';
    } else {
      final balance = double.tryParse(_balanceController.text) ?? 0.0;
      displayBalance = '₹${balance.toStringAsFixed(2)}';
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Review & Finish',
            style: AppStyles.titleStyle(context).copyWith(fontSize: 24),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppStyles.getCardColor(context),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildReviewRow('Bank', _selectedBank ?? 'Unknown'),
                const SizedBox(height: 16),
                _buildReviewRow('Account Type', _getAccountTypeLabel(_selectedAccountType ?? AccountType.savings)),
                const SizedBox(height: 16),
                _buildReviewRow('Account Name', _nameController.text),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: CupertinoColors.systemGrey.withValues(alpha: 0.2))),
                  ),
                ),
                Text(
                  'Available Balance',
                  style: TextStyle(
                    color: AppStyles.getSecondaryTextColor(context),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  displayBalance,
                  style: AppStyles.titleStyle(context).copyWith(
                    fontSize: 28,
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
          style: AppStyles.titleStyle(context).copyWith(fontWeight: FontWeight.w600),
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
          canGoNext = _selectedBroker != null && _nameController.text.isNotEmpty;
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
          canGoNext = _selectedAccountType != null && _nameController.text.isNotEmpty;
          break;
        case 2: // Account Details
          if (_selectedAccountType == AccountType.credit || _selectedAccountType == AccountType.payLater) {
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
      padding: const EdgeInsets.all(24),
      child: BouncyButton(
        onPressed: canGoNext ? _nextStep : () {},
        child: Opacity(
          opacity: canGoNext ? 1.0 : 0.5,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: CupertinoColors.systemBlue,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                _currentStep == _totalSteps - 1 ? 'Finish' : 'Next',
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
