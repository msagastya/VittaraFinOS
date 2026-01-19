import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/account_model.dart';
import 'package:vittara_fin_os/logic/banks_controller.dart';
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
  final int _totalSteps = 3;

  // Form Data
  String? _selectedBank;
  Color? _selectedColor;
  final TextEditingController _nameController = TextEditingController();
  AccountType _selectedType = AccountType.savings;
  final TextEditingController _balanceController = TextEditingController();

  final List<Map<String, dynamic>> _banks = [
    {'name': 'HDFC Bank', 'color': const Color(0xFF004C8F)},
    {'name': 'ICICI Bank', 'color': const Color(0xFFF37E20)},
    {'name': 'SBI', 'color': const Color(0xFF007DCC)},
    {'name': 'Axis Bank', 'color': const Color(0xFF97144D)},
    {'name': 'Kotak Bank', 'color': const Color(0xFFED1C24)},
  ];

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
    _balanceController.dispose();
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
    final account = Account(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text,
      bankName: _selectedBank ?? 'Other',
      type: widget.isInvestment ? AccountType.investment : _selectedType,
      balance: double.tryParse(_balanceController.text) ?? 0.0,
      color: _selectedColor ?? CupertinoColors.systemBlue,
    );
    Navigator.pop(context, account);
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
                children: [
                  _buildBankSelectionStep(),
                  _buildDetailsStep(),
                  _buildBalanceStep(),
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
                      'Select Bank',
                      style: AppStyles.titleStyle(context).copyWith(fontSize: 20),
                    ),
                  ],
                ),
              ),
              Divider(color: AppStyles.getSecondaryTextColor(context).withValues(alpha: 0.1)),
              // List
              Expanded(
                child: disabledBanks.isEmpty
                    ? Center(
                        child: Text(
                          'All banks are already added',
                          style: TextStyle(color: AppStyles.getSecondaryTextColor(context)),
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

  Widget _buildDetailsStep() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Account Details', style: AppStyles.titleStyle(context).copyWith(fontSize: 24)),
          const SizedBox(height: 32),
          Text('Account Nickname', style: AppStyles.headerStyle(context)),
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
          if (!widget.isInvestment) ...[
            const SizedBox(height: 24),
            Text('Account Type', style: AppStyles.headerStyle(context)),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: CupertinoSlidingSegmentedControl<AccountType>(
                groupValue: _selectedType,
                children: const {
                  AccountType.savings: Text('Savings'),
                  AccountType.current: Text('Current'),
                  AccountType.credit: Text('Credit'),
                },
                onValueChanged: (val) {
                  if (val != null) setState(() => _selectedType = val);
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBalanceStep() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Current Balance', style: AppStyles.titleStyle(context).copyWith(fontSize: 24)),
          const SizedBox(height: 8),
          Text('How much is in there right now?', style: TextStyle(color: AppStyles.getSecondaryTextColor(context))),
          const SizedBox(height: 48),
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('₹', style: AppStyles.titleStyle(context).copyWith(fontSize: 40)),
                const SizedBox(width: 8),
                IntrinsicWidth(
                  child: CupertinoTextField(
                    controller: _balanceController,
                    placeholder: '0.00',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: null,
                    style: AppStyles.titleStyle(context).copyWith(fontSize: 48, fontWeight: FontWeight.bold),
                    autofocus: true,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    final canGoNext = _currentStep == 0 ? _selectedBank != null : (_currentStep == 1 ? _nameController.text.isNotEmpty : true);

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
