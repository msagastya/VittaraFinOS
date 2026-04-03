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

class MFDeductionStep extends StatefulWidget {
  const MFDeductionStep({super.key});

  @override
  State<MFDeductionStep> createState() => _MFDeductionStepState();
}

class _MFDeductionStepState extends State<MFDeductionStep> {
  late TextEditingController _chargesController;

  @override
  void initState() {
    super.initState();
    final controller = Provider.of<MFWizardController>(context, listen: false);
    _chargesController = TextEditingController(
      text: controller.extraCharges > 0 ? controller.extraCharges.toString() : '',
    );
  }

  void _updateController(bool value) {
    final controller = Provider.of<MFWizardController>(context, listen: false);
    final charges = double.tryParse(_chargesController.text) ?? 0;

    // Update deduction settings based on MF type
    if (controller.selectedMFType == MFType.newMF) {
      controller.updateNewMFDetails(
        amount: controller.investmentAmount,
        date: controller.investmentDate,
        deduct: value,
        deductAccount: value ? controller.deductionAccount : null,
        fetchedNav: controller.fetchedNAV,
      );
    } else {
      // For existing MF, use generic deduction update
      controller.updateDeduction(
        deduct: value,
        deductAccount: value ? controller.deductionAccount : null,
      );
    }
    controller.updateCharges(charges);
  }

  void _onChargesChanged(String value) {
    final controller = Provider.of<MFWizardController>(context, listen: false);
    final charges = double.tryParse(value) ?? 0;
    controller.updateCharges(charges);
  }

  @override
  void dispose() {
    _chargesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<MFWizardController>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(Spacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Payment',
            style: AppStyles.titleStyle(context),
          ),
          const SizedBox(height: Spacing.xl),
          Container(
            padding: const EdgeInsets.all(Spacing.lg),
            decoration: AppStyles.cardDecoration(context),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Deduct from Bank Account?',
                        style: TextStyle(
                          color: AppStyles.getTextColor(context),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    CupertinoSwitch(
                      value: controller.deductFromAccount,
                      activeTrackColor: SemanticColors.investments,
                      onChanged: (val) => _updateController(val),
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Divider(height: 1),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Extra Charges',
                        style:
                            TextStyle(color: AppStyles.getTextColor(context)),
                      ),
                    ),
                    SizedBox(
                      width: 100,
                      child: CupertinoTextField(
                        controller: _chargesController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        placeholder: '0.00',
                        padding: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 12),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey[800] : Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        style:
                            TextStyle(color: AppStyles.getTextColor(context)),
                        onChanged: _onChargesChanged,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: Spacing.xl),
          if (controller.deductFromAccount) ...[
            Text(
              'Select Bank Account',
              style: TextStyle(
                color: AppStyles.getTextColor(context),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: Spacing.md),
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
                        padding: const EdgeInsets.all(Spacing.lg),
                        decoration: BoxDecoration(
                          color: CupertinoColors.systemOrange
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(Radii.md),
                        ),
                        child: Text(
                          'No bank accounts found',
                          style: TextStyle(
                            color: AppStyles.getSecondaryTextColor(context),
                            fontSize: TypeScale.footnote,
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
                              controller.deductionAccount?.id == account.id;

                          return GestureDetector(
                            onTap: () {
                              if (controller.selectedMFType == MFType.newMF) {
                                controller.updateNewMFDetails(
                                  amount: controller.investmentAmount,
                                  date: controller.investmentDate,
                                  deduct: true,
                                  deductAccount: account,
                                  fetchedNav: controller.fetchedNAV,
                                );
                              } else {
                                controller.updateDeduction(
                                  deduct: true,
                                  deductAccount: account,
                                );
                              }
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(Spacing.md),
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
                                borderRadius: BorderRadius.circular(Radii.md),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(Spacing.sm),
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
                                  const SizedBox(width: Spacing.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          account.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: TypeScale.body,
                                          ),
                                        ),
                                        Text(
                                          '₹${account.balance.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            color:
                                                AppStyles.getSecondaryTextColor(
                                                    context),
                                            fontSize: TypeScale.footnote,
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
                    const SizedBox(height: Spacing.md),
                    CupertinoButton(
                      color: isDark ? Colors.grey[800] : Colors.grey[200],
                      onPressed: () {
                        Navigator.push<Account>(
                          context,
                          FadeScalePageRoute(
                            page: const AccountWizard(isInvestment: false),
                          ),
                        ).then((result) {
                          if (result != null) {
                            accountsController.addAccount(result);
                            if (controller.selectedMFType == MFType.newMF) {
                              controller.updateNewMFDetails(
                                amount: controller.investmentAmount,
                                date: controller.investmentDate,
                                deduct: true,
                                deductAccount: result,
                                fetchedNav: controller.fetchedNAV,
                              );
                            } else {
                              controller.updateDeduction(
                                deduct: true,
                                deductAccount: result,
                              );
                            }
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
                          const SizedBox(width: Spacing.sm),
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
            const SizedBox(height: Spacing.xl),
            Container(
              padding: const EdgeInsets.all(Spacing.lg),
              decoration: BoxDecoration(
                color: SemanticColors.investments.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: SemanticColors.investments.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Investment Amount:'),
                      Text(
                        '₹${controller.investmentAmount.toStringAsFixed(2)}',
                      ),
                    ],
                  ),
                  const SizedBox(height: Spacing.sm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Charges:'),
                      Text(
                        '₹${controller.extraCharges.toStringAsFixed(2)}',
                      ),
                    ],
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Deduction:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '₹${controller.investmentAmount.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
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
}
