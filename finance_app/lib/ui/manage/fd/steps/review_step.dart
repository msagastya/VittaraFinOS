import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/ui/manage/fd/fd_wizard_controller.dart';
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
            'Review FD Details',
            style: AppStyles.titleStyle(context),
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            'Review and confirm your FD details before creation',
            style: TextStyle(color: AppStyles.getSecondaryTextColor(context)),
          ),
          const SizedBox(height: 30),
          // FD Name
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
            placeholder: 'e.g., Emergency Fund FD',
            padding: const EdgeInsets.all(Spacing.md),
            decoration: BoxDecoration(
              color: AppStyles.getCardColor(context),
              borderRadius: BorderRadius.circular(8),
            ),
            style: TextStyle(color: AppStyles.getTextColor(context)),
            onChanged: (value) => controller.updateFDName(value),
          ),
          const SizedBox(height: Spacing.xl),
          // Notes
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
                  'FD Summary',
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
                  'Principal Amount',
                  '₹${controller.principal.toStringAsFixed(2)}',
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
                  'Tenure',
                  '${controller.tenureMonths} months',
                ),
                const SizedBox(height: Spacing.md),
                _buildSummaryRow(
                  context,
                  'Compounding',
                  controller.compoundingFrequency.name,
                ),
                const SizedBox(height: Spacing.md),
                _buildSummaryRow(
                  context,
                  'FD Type',
                  controller.isCumulative ? 'Cumulative' : 'Non-Cumulative',
                ),
                const SizedBox(height: Spacing.md),
                _buildSummaryRow(
                  context,
                  'Payout Frequency',
                  controller.payoutFrequency.name,
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
          // Auto-Link Toggle
          Container(
            padding: const EdgeInsets.all(Spacing.md),
            decoration: BoxDecoration(
              color: AppStyles.getCardColor(context),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
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
                        'Automatically credit payouts to linked account',
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
