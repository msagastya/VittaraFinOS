import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/account_model.dart';
import 'package:vittara_fin_os/logic/accounts_controller.dart';
import 'package:vittara_fin_os/ui/manage/account_wizard.dart';
import 'package:vittara_fin_os/ui/manage/mf/mf_wizard_controller.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/widgets/animations.dart';

class MFNewInvestmentDetailsStep extends StatefulWidget {
  const MFNewInvestmentDetailsStep({super.key});

  @override
  State<MFNewInvestmentDetailsStep> createState() =>
      _MFNewInvestmentDetailsStepState();
}

class _MFNewInvestmentDetailsStepState
    extends State<MFNewInvestmentDetailsStep> {
  late TextEditingController _amountController;
  bool _isFetchingNAV = false;
  String _navError = '';

  @override
  void initState() {
    super.initState();
    final controller = Provider.of<MFWizardController>(context, listen: false);
    _amountController = TextEditingController(
      text: controller.investmentAmount > 0
          ? controller.investmentAmount.toString()
          : '',
    );
  }

  void _updateAmount() {
    final controller = Provider.of<MFWizardController>(context, listen: false);
    final amount = double.tryParse(_amountController.text) ?? 0;
    controller.updateNewMFDetails(
      amount: amount,
      date: controller.investmentDate,
      deduct: controller.deductFromAccount,
      deductAccount: controller.deductionAccount,
      fetchedNav: controller.fetchedNAV,
    );
  }

  Future<void> _fetchNAVForDate() async {
    final controller = Provider.of<MFWizardController>(context, listen: false);

    if (controller.selectedMF == null) {
      setState(() {
        _navError = 'Please select a mutual fund first';
      });
      return;
    }

    setState(() {
      _isFetchingNAV = true;
      _navError = '';
    });

    try {
      // TODO: Implement actual NAV fetching from API for historical date
      // For now, use current NAV as placeholder
      final nav = controller.selectedMF!.nav ?? 0;

      if (nav > 0) {
        controller.setFetchedNAV(nav);
        setState(() {
          _isFetchingNAV = false;
        });
      } else {
        setState(() {
          _isFetchingNAV = false;
          _navError = 'Could not fetch NAV for selected date';
        });
      }
    } catch (e) {
      setState(() {
        _isFetchingNAV = false;
        _navError = 'Error fetching NAV: $e';
      });
    }
  }

  void _showDatePicker() {
    final controller = Provider.of<MFWizardController>(context, listen: false);
    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        height: 216,
        padding: const EdgeInsets.only(top: 6.0),
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: SafeArea(
          top: false,
          child: CupertinoDatePicker(
            initialDateTime: controller.investmentDate,
            mode: CupertinoDatePickerMode.date,
            maximumDate: DateTime.now(),
            onDateTimeChanged: (DateTime newDate) {
              controller.updatePurchaseDate(newDate);
              // Reset fetched NAV when date changes
              controller.setFetchedNAV(null);
              setState(() {
                _navError = '';
              });
            },
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mfController = Provider.of<MFWizardController>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Investment Details',
            style: AppStyles.titleStyle(context),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter amount and date for ${mfController.selectedMF?.schemeName ?? "Mutual Fund"}',
            style: TextStyle(color: AppStyles.getSecondaryTextColor(context)),
          ),
          const SizedBox(height: 30),

          // Investment Amount
          Text(
            'Investment Amount',
            style: TextStyle(
              color: AppStyles.getTextColor(context),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          CupertinoTextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            placeholder: '0.00',
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppStyles.getCardColor(context),
              borderRadius: BorderRadius.circular(12),
            ),
            prefix: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Text(
                '₹',
                style: TextStyle(color: AppStyles.getTextColor(context)),
              ),
            ),
            style: TextStyle(color: AppStyles.getTextColor(context)),
            onChanged: (_) => _updateAmount(),
          ),
          const SizedBox(height: 20),

          // Date of Investment
          Text(
            'Date of Investment',
            style: TextStyle(
              color: AppStyles.getTextColor(context),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _showDatePicker,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppStyles.getCardColor(context),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${mfController.investmentDate.day} ${_monthName(mfController.investmentDate.month)} ${mfController.investmentDate.year}',
                    style: TextStyle(color: AppStyles.getTextColor(context)),
                  ),
                  Icon(
                    CupertinoIcons.calendar,
                    color: AppStyles.getSecondaryTextColor(context),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Fetch NAV Button
          SizedBox(
            width: double.infinity,
            child: CupertinoButton(
              color: CupertinoColors.systemBlue,
              onPressed: _isFetchingNAV ? null : _fetchNAVForDate,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isFetchingNAV)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CupertinoActivityIndicator(),
                    )
                  else
                    const Icon(CupertinoIcons.cloud_download, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    _isFetchingNAV
                        ? 'Fetching NAV...'
                        : mfController.fetchedNAV != null
                            ? 'NAV: ₹${mfController.fetchedNAV!.toStringAsFixed(2)}'
                            : 'Fetch NAV for Date',
                  ),
                ],
              ),
            ),
          ),

          if (_navError.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: Text(
                _navError,
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 12,
                ),
              ),
            ),
          ],

          const SizedBox(height: 30),

          // Deduct from Bank Account Toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Deduct from Bank Account?',
                style: TextStyle(
                  color: AppStyles.getTextColor(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
              CupertinoSwitch(
                value: mfController.deductFromAccount,
                onChanged: (value) {
                  mfController.updateNewMFDetails(
                    amount: mfController.investmentAmount,
                    date: mfController.investmentDate,
                    deduct: value,
                    deductAccount: value ? mfController.deductionAccount : null,
                    fetchedNav: mfController.fetchedNAV,
                  );
                },
              ),
            ],
          ),

          if (mfController.deductFromAccount) ...[
            const SizedBox(height: 20),
            Text(
              'Select Bank Account',
              style: TextStyle(
                color: AppStyles.getTextColor(context),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Consumer<AccountsController>(
              builder: (context, accountsController, child) {
                final bankAccounts = accountsController.accounts
                    .where((acc) =>
                        acc.type == AccountType.savings ||
                        acc.type == AccountType.current)
                    .toList();

                return Column(
                  children: [
                    if (bankAccounts.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'No bank accounts found',
                          style: TextStyle(
                            color: AppStyles.getSecondaryTextColor(context),
                            fontSize: 12,
                          ),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: bankAccounts.length,
                        itemBuilder: (context, index) {
                          final account = bankAccounts[index];
                          final isSelected =
                              mfController.deductionAccount?.id == account.id;

                          return GestureDetector(
                            onTap: () {
                              mfController.updateNewMFDetails(
                                amount: mfController.investmentAmount,
                                date: mfController.investmentDate,
                                deduct: true,
                                deductAccount: account,
                                fetchedNav: mfController.fetchedNAV,
                              );
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? SemanticColors.investments
                                        .withValues(alpha: 0.1)
                                    : AppStyles.getCardColor(context),
                                border: isSelected
                                    ? Border.all(
                                        color: SemanticColors.investments,
                                      )
                                    : null,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color:
                                          account.color.withValues(alpha: 0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      CupertinoIcons.money_dollar_circle,
                                      color: account.color,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          account.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        Text(
                                          '₹${account.balance.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            color:
                                                AppStyles.getSecondaryTextColor(
                                                    context),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isSelected)
                                    const Icon(
                                      CupertinoIcons.check_mark_circled_solid,
                                      color: SemanticColors.investments,
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    const SizedBox(height: 12),
                    CupertinoButton(
                      color: isDark ? Colors.grey[800] : Colors.grey[200],
                      onPressed: () {
                        final accountsController =
                            Provider.of<AccountsController>(context,
                                listen: false);
                        Navigator.push<Account>(
                          context,
                          FadeScalePageRoute(
                            page: const AccountWizard(isInvestment: false),
                          ),
                        ).then((result) {
                          if (result != null) {
                            accountsController.addAccount(result);
                            mfController.updateNewMFDetails(
                              amount: mfController.investmentAmount,
                              date: mfController.investmentDate,
                              deduct: true,
                              deductAccount: result,
                              fetchedNav: mfController.fetchedNAV,
                            );
                          }
                        });
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            CupertinoIcons.add,
                            color: AppStyles.getTextColor(context),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Add Bank Account',
                            style: TextStyle(
                              color: AppStyles.getTextColor(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ],

          const SizedBox(height: 30),

          // NAV and Units Display
          if (mfController.fetchedNAV != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: SemanticColors.investments.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: SemanticColors.investments.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'NAV on Date',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '₹${mfController.fetchedNAV!.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: SemanticColors.investments,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Units',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        mfController.calculatedUnits.toStringAsFixed(4),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: SemanticColors.investments,
                        ),
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

  String _monthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return months[month - 1];
  }
}
