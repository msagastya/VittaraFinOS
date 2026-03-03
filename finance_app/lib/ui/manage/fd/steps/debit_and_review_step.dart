import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/ui/manage/fd/fd_wizard_controller.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';

class DebitAndReviewStep extends StatefulWidget {
  const DebitAndReviewStep({super.key});

  @override
  State<DebitAndReviewStep> createState() => _DebitAndReviewStepState();
}

class _DebitAndReviewStepState extends State<DebitAndReviewStep> {
  late TextEditingController _nameController;
  late TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    final controller = Provider.of<FDWizardController>(context, listen: false);
    _nameController = TextEditingController(text: controller.fdName);
    _notesController = TextEditingController(text: controller.fdNotes ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<FDWizardController>(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(Spacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Review & Confirm',
            style: AppStyles.titleStyle(context),
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            'Review FD details before creation',
            style: TextStyle(color: AppStyles.getSecondaryTextColor(context)),
          ),
          const SizedBox(height: 30),
          Text(
            'FD Name',
            style: TextStyle(
              color: AppStyles.getTextColor(context),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: Spacing.sm),
          CupertinoTextField(
            controller: _nameController,
            placeholder: 'e.g., My FD',
            padding: const EdgeInsets.all(Spacing.md),
            decoration: BoxDecoration(
              color: AppStyles.getCardColor(context),
              borderRadius: BorderRadius.circular(8),
            ),
            style: TextStyle(color: AppStyles.getTextColor(context)),
            onChanged: (value) => controller.updateFDName(value),
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
            placeholder: 'Bank name, account details, etc.',
            padding: const EdgeInsets.all(Spacing.md),
            minLines: 2,
            maxLines: 3,
            decoration: BoxDecoration(
              color: AppStyles.getCardColor(context),
              borderRadius: BorderRadius.circular(8),
            ),
            style: TextStyle(color: AppStyles.getTextColor(context)),
            onChanged: (value) =>
                controller.updateFDNotes(value.isEmpty ? null : value),
          ),
          const SizedBox(height: 30),
          // Summary Card
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
                  'Summary',
                  style: TextStyle(
                    color: AppStyles.getTextColor(context),
                    fontWeight: FontWeight.bold,
                    fontSize: TypeScale.headline,
                  ),
                ),
                const SizedBox(height: Spacing.lg),
                _buildSummaryRow(
                    'Account', controller.selectedAccount?.name ?? 'N/A'),
                _buildSummaryRow('Invested Date',
                    '${controller.investmentDate.day}/${controller.investmentDate.month}/${controller.investmentDate.year}'),
                _buildSummaryRow(
                    'Principal', '₹${controller.principal.toStringAsFixed(2)}'),
                _buildSummaryRow(
                    'Rate', '${controller.interestRate.toStringAsFixed(2)}%'),
                _buildSummaryRow('Tenure', '${controller.tenureMonths} months'),
                _buildSummaryRow(
                    'Compounding', controller.compoundingFrequency.name),
                if (!controller.isCumulative)
                  _buildSummaryRow('Payouts', controller.payoutFrequency.name),
                const SizedBox(height: Spacing.md),
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
                        'Est. Maturity Value',
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
                            'Deduct ₹${controller.principal.toStringAsFixed(2)} from ${controller.selectedAccount?.name ?? 'account'}',
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
                          'Turn on only if you want to debit now. For old FDs, leave off.',
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
          // Auto-Link Toggle
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
                        'Auto-Link Payouts',
                        style: TextStyle(
                          color: AppStyles.getTextColor(context),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: Spacing.xs),
                      Text(
                        'Auto-credit payouts to account',
                        style: TextStyle(
                          color: AppStyles.getSecondaryTextColor(context),
                          fontSize: TypeScale.footnote,
                        ),
                      ),
                    ],
                  ),
                ),
                CupertinoSwitch(
                  value: controller.autoLinkEnabled,
                  onChanged: (value) => controller.toggleAutoLink(value),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppStyles.getSecondaryTextColor(context),
              fontSize: TypeScale.subhead,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: AppStyles.getTextColor(context),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
