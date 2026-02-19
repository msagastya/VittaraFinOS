import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/account_model.dart';
import 'package:vittara_fin_os/logic/accounts_controller.dart';
import 'package:vittara_fin_os/ui/manage/account_wizard.dart';
import 'package:vittara_fin_os/ui/manage/mf/sip_wizard_controller.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/widgets/animations.dart';

class SIPFrequencyDeductionStep extends StatefulWidget {
  const SIPFrequencyDeductionStep({super.key});

  @override
  State<SIPFrequencyDeductionStep> createState() =>
      _SIPFrequencyDeductionStepState();
}

class _SIPFrequencyDeductionStepState extends State<SIPFrequencyDeductionStep> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) {
        await Provider.of<AccountsController>(context, listen: false)
            .loadAccounts();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final sipController = Provider.of<SIPWizardController>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SIP Frequency & Deduction',
            style: AppStyles.titleStyle(context),
          ),
          const SizedBox(height: 8),
          Text(
            'Select frequency and bank account for SIP deduction',
            style: TextStyle(color: AppStyles.getSecondaryTextColor(context)),
          ),
          const SizedBox(height: 30),

          // SIP Frequency
          Text(
            'SIP Frequency',
            style: TextStyle(
              color: AppStyles.getTextColor(context),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          CupertinoSegmentedControl<SIPFrequency>(
            children: const {
              SIPFrequency.daily: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text('Daily'),
              ),
              SIPFrequency.weekly: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text('Weekly'),
              ),
              SIPFrequency.monthly: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text('Monthly'),
              ),
            },
            groupValue: sipController.frequency,
            onValueChanged: (value) {
              sipController.updateFrequency(value);
            },
          ),
          const SizedBox(height: 20),

          // Day/Date Selection based on frequency
          if (sipController.frequency == SIPFrequency.weekly) ...[
            Text(
              'Select Day of Week',
              style: TextStyle(
                color: AppStyles.getTextColor(context),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                  .asMap()
                  .entries
                  .map(
                    (entry) => GestureDetector(
                      onTap: () {
                        sipController.updateWeekday(entry.key);
                      },
                      child: Container(
                        width: 45,
                        height: 45,
                        decoration: BoxDecoration(
                          color: sipController.selectedWeekday == entry.key
                              ? SemanticColors.investments
                              : AppStyles.getCardColor(context),
                          borderRadius: BorderRadius.circular(8),
                          border: sipController.selectedWeekday == entry.key
                              ? null
                              : Border.all(
                                  color: Colors.grey.withValues(alpha: 0.3),
                                ),
                        ),
                        child: Center(
                          child: Text(
                            entry.value,
                            style: TextStyle(
                              color: sipController.selectedWeekday == entry.key
                                  ? Colors.white
                                  : AppStyles.getTextColor(context),
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 20),
          ] else if (sipController.frequency == SIPFrequency.monthly) ...[
            Text(
              'Day of Month',
              style: TextStyle(
                color: AppStyles.getTextColor(context),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppStyles.getCardColor(context),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Deduct on: ${sipController.selectedMonthDay}${_getDaySuffix(sipController.selectedMonthDay)} of every month',
                    style: TextStyle(color: AppStyles.getTextColor(context)),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      _showMonthDayPicker(context);
                    },
                    child: const Icon(CupertinoIcons.calendar),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Deduction Account Selection
          Text(
            'Deduction Bank Account',
            style: TextStyle(
              color: AppStyles.getTextColor(context),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Consumer<AccountsController>(
            builder: (context, accountsController, child) {
              final bankAccounts = accountsController.accounts
                  .where((acc) => acc.type == AccountType.savings)
                  .toList();

              return Column(
                children: [
                  if (bankAccounts.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.orange.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        'No bank accounts found. Please add one.',
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
                            sipController.deductionAccount?.id == account.id;

                        return GestureDetector(
                          onTap: () {
                            sipController.updateDeductionAccount(account);
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
                                    color: account.color.withValues(alpha: 0.2),
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
                          sipController.updateDeductionAccount(result);
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
      ),
    );
  }

  void _showMonthDayPicker(BuildContext context) {
    final sipController =
        Provider.of<SIPWizardController>(context, listen: false);
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
          child: CupertinoPicker(
            itemExtent: 40,
            scrollController: FixedExtentScrollController(
              initialItem: sipController.selectedMonthDay - 1,
            ),
            onSelectedItemChanged: (index) {
              sipController.updateMonthDay(index + 1);
            },
            children: List.generate(
              31,
              (index) => Center(
                child: Text('${index + 1}'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _getDaySuffix(int day) {
    if (day >= 11 && day <= 13) return 'th';
    switch (day % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }
}
