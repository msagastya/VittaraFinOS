import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/ui/manage/rd/rd_wizard_controller.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';

class ReviewStep extends StatefulWidget {
  const ReviewStep({super.key});

  @override
  State<ReviewStep> createState() => _ReviewStepState();
}

class _ReviewStepState extends State<ReviewStep> {
  late TextEditingController _nameController;
  late TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    final controller = Provider.of<RDWizardController>(context, listen: false);
    _nameController = TextEditingController(text: controller.rdName);
    _notesController = TextEditingController(text: controller.rdNotes ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<RDWizardController>(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(Spacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Review RD Details',
            style: AppStyles.titleStyle(context),
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            'Review and confirm your RD details before creation',
            style: TextStyle(color: AppStyles.getSecondaryTextColor(context)),
          ),
          const SizedBox(height: 30),
          Text(
            'RD Name',
            style: TextStyle(
              color: AppStyles.getTextColor(context),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: Spacing.sm),
          CupertinoTextField(
            controller: _nameController,
            placeholder: 'e.g., Monthly Savings RD',
            padding: const EdgeInsets.all(Spacing.md),
            decoration: BoxDecoration(
              color: AppStyles.getCardColor(context),
              borderRadius: BorderRadius.circular(8),
            ),
            style: TextStyle(color: AppStyles.getTextColor(context)),
            onChanged: (value) => controller.updateRDName(value),
          ),
          const SizedBox(height: Spacing.xl),
          Text(
            'Notes (Optional)',
            style: TextStyle(
              color: AppStyles.getTextColor(context),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: Spacing.sm),
          CupertinoTextField(
            controller: _notesController,
            placeholder: 'Add any notes...',
            padding: const EdgeInsets.all(Spacing.md),
            minLines: 2,
            maxLines: 4,
            decoration: BoxDecoration(
              color: AppStyles.getCardColor(context),
              borderRadius: BorderRadius.circular(8),
            ),
            style: TextStyle(color: AppStyles.getTextColor(context)),
            onChanged: (value) =>
                controller.updateRDNotes(value.isEmpty ? null : value),
          ),
          const SizedBox(height: 30),
          Container(
            padding: const EdgeInsets.all(Spacing.lg),
            decoration: BoxDecoration(
              color: AppStyles.getBackground(context).withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color:
                    AppStyles.getPrimaryColor(context).withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'RD Summary',
                  style: TextStyle(
                    color: AppStyles.getTextColor(context),
                    fontWeight: FontWeight.bold,
                    fontSize: TypeScale.headline,
                  ),
                ),
                const SizedBox(height: Spacing.lg),
                _buildSummaryRow(
                  context,
                  'Linked Account',
                  controller.selectedAccount?.name ?? 'N/A',
                ),
                const SizedBox(height: Spacing.md),
                _buildSummaryRow(
                  context,
                  'Per Installment',
                  '₹${controller.monthlyAmount.toStringAsFixed(2)}',
                ),
                const SizedBox(height: Spacing.md),
                _buildSummaryRow(
                  context,
                  'Total Installments',
                  '${controller.totalInstallments}',
                ),
                const SizedBox(height: Spacing.md),
                _buildSummaryRow(
                  context,
                  'Interest Rate',
                  '${controller.interestRate.toStringAsFixed(2)}% p.a.',
                ),
                const SizedBox(height: Spacing.md),
                _buildSummaryRow(
                  context,
                  'Payment Frequency',
                  controller.paymentFrequency.name,
                ),
                const SizedBox(height: Spacing.lg),
                Container(
                  padding: const EdgeInsets.all(Spacing.md),
                  decoration: BoxDecoration(
                    color: AppStyles.getPrimaryColor(context)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Estimated Maturity Value',
                        style: TextStyle(
                          color: AppStyles.getTextColor(context),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '₹${controller.maturityValue.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: AppStyles.getPrimaryColor(context),
                          fontWeight: FontWeight.bold,
                          fontSize: TypeScale.headline,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Spacing.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Interest',
                      style: TextStyle(
                        color: AppStyles.getSecondaryTextColor(context),
                        fontSize: TypeScale.subhead,
                      ),
                    ),
                    Text(
                      '₹${controller.totalInterestAtMaturity.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: AppStyles.getSecondaryTextColor(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: Spacing.xl),
          // Debit Toggle
          Container(
            padding: const EdgeInsets.all(Spacing.lg),
            decoration: BoxDecoration(
              color: AppStyles.getCardColor(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color:
                    AppStyles.getPrimaryColor(context).withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Debit from Account',
                            style: TextStyle(
                              color: AppStyles.getTextColor(context),
                              fontWeight: FontWeight.w600,
                              fontSize: TypeScale.callout,
                            ),
                          ),
                          const SizedBox(height: Spacing.xs),
                          Text(
                            'Deduct ₹${controller.monthlyAmount.toStringAsFixed(2)} from ${controller.selectedAccount?.name ?? 'account'}',
                            style: TextStyle(
                              color: AppStyles.getSecondaryTextColor(context),
                              fontSize: TypeScale.footnote,
                            ),
                          ),
                        ],
                      ),
                    ),
                    CupertinoSwitch(
                      value: controller.debitFromAccount,
                      onChanged: (value) =>
                          controller.toggleDebitFromAccount(value),
                    ),
                  ],
                ),
                const SizedBox(height: Spacing.md),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color:
                        AppStyles.getBackground(context).withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        CupertinoIcons.info,
                        size: 14,
                        color: AppStyles.getSecondaryTextColor(context),
                      ),
                      const SizedBox(width: Spacing.sm),
                      Expanded(
                        child: Text(
                          'Turn on only if you want to debit now. For legacy RDs, leave off.',
                          style: TextStyle(
                            color: AppStyles.getSecondaryTextColor(context),
                            fontSize: TypeScale.caption,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Spacing.xl),
          // Auto-Payment Toggle
          Container(
            padding: const EdgeInsets.all(Spacing.lg),
            decoration: BoxDecoration(
              color: AppStyles.getCardColor(context),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Auto-Payment',
                        style: TextStyle(
                          color: AppStyles.getTextColor(context),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: Spacing.xs),
                      Text(
                        'Automatically debit future installments',
                        style: TextStyle(
                          color: AppStyles.getSecondaryTextColor(context),
                          fontSize: TypeScale.footnote,
                        ),
                      ),
                    ],
                  ),
                ),
                CupertinoSwitch(
                  value: controller.autoPaymentEnabled,
                  onChanged: (value) => controller.toggleAutoPayment(value),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(BuildContext context, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(color: AppStyles.getSecondaryTextColor(context)),
        ),
        Text(
          value,
          style: TextStyle(
            color: AppStyles.getTextColor(context),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
