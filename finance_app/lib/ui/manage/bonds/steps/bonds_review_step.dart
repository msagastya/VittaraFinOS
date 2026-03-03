import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/ui/manage/bonds/bonds_wizard_controller.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';

class BondsReviewStep extends StatelessWidget {
  const BondsReviewStep({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<BondsWizardController>(context);

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
            'Verify all details before saving',
            style: TextStyle(color: AppStyles.getSecondaryTextColor(context)),
          ),
          const SizedBox(height: 30),
          // Bond Information Card
          Container(
            padding: const EdgeInsets.all(Spacing.lg),
            decoration: BoxDecoration(
              color: AppStyles.getCardColor(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: CupertinoColors.systemGrey.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bond Information',
                  style: TextStyle(
                    color: AppStyles.getTextColor(context),
                    fontWeight: FontWeight.bold,
                    fontSize: TypeScale.body,
                  ),
                ),
                const SizedBox(height: Spacing.lg),
                _ReviewRow(
                  label: 'Bond Name',
                  value: controller.bondName ?? 'N/A',
                ),
                const SizedBox(height: Spacing.md),
                _ReviewRow(
                  label: 'Type',
                  value:
                      controller.selectedBondType?.toString().split('.').last ??
                          'N/A',
                ),
                const SizedBox(height: Spacing.md),
                _ReviewRow(
                  label: 'Issuer',
                  value: controller.selectedIssuer ?? 'N/A',
                ),
                const SizedBox(height: Spacing.md),
                _ReviewRow(
                  label: 'Face Value',
                  value:
                      '₹${controller.faceValue?.toStringAsFixed(2) ?? '0.00'}',
                ),
                if (controller.creditRating != null) ...[
                  const SizedBox(height: Spacing.md),
                  _ReviewRow(
                    label: 'Credit Rating',
                    value: controller.creditRating ?? 'N/A',
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: Spacing.xl),
          // Purchase Details Card
          Container(
            padding: const EdgeInsets.all(Spacing.lg),
            decoration: BoxDecoration(
              color: AppStyles.getCardColor(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: CupertinoColors.systemGrey.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Purchase Details',
                  style: TextStyle(
                    color: AppStyles.getTextColor(context),
                    fontWeight: FontWeight.bold,
                    fontSize: TypeScale.body,
                  ),
                ),
                const SizedBox(height: Spacing.lg),
                _ReviewRow(
                  label: 'Quantity',
                  value: '${controller.purchaseQuantity} bonds',
                ),
                const SizedBox(height: Spacing.md),
                _ReviewRow(
                  label: 'Purchase Price per Bond',
                  value:
                      '₹${controller.purchasePrice?.toStringAsFixed(2) ?? '0.00'}',
                ),
                const SizedBox(height: Spacing.md),
                _ReviewRow(
                  label: 'Total Cost',
                  value: '₹${controller.totalCost.toStringAsFixed(2)}',
                  isHighlight: true,
                ),
                const SizedBox(height: Spacing.md),
                _ReviewRow(
                  label: 'Purchase Date',
                  value:
                      '${controller.purchaseDate.day}/${controller.purchaseDate.month}/${controller.purchaseDate.year}',
                ),
              ],
            ),
          ),
          const SizedBox(height: Spacing.xl),
          // Coupon Details Card
          Container(
            padding: const EdgeInsets.all(Spacing.lg),
            decoration: BoxDecoration(
              color: AppStyles.getCardColor(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: CupertinoColors.systemGrey.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Coupon Payments',
                  style: TextStyle(
                    color: AppStyles.getTextColor(context),
                    fontWeight: FontWeight.bold,
                    fontSize: TypeScale.body,
                  ),
                ),
                const SizedBox(height: Spacing.lg),
                _ReviewRow(
                  label: 'Annual Coupon Rate',
                  value:
                      '${controller.couponRate?.toStringAsFixed(2) ?? '0.00'}%',
                ),
                const SizedBox(height: Spacing.md),
                _ReviewRow(
                  label: 'Coupon Frequency',
                  value: controller.couponFrequency.toString().split('.').last,
                ),
                const SizedBox(height: Spacing.md),
                _ReviewRow(
                  label: 'Annual Coupon Payment',
                  value:
                      '₹${controller.annualCouponPayment.toStringAsFixed(2)}',
                  isHighlight: true,
                ),
                const SizedBox(height: Spacing.md),
                _ReviewRow(
                  label: 'Per Coupon Payment',
                  value: '₹${controller.couponPerPayment.toStringAsFixed(2)}',
                ),
              ],
            ),
          ),
          const SizedBox(height: Spacing.xl),
          // Account Link Card
          if (controller.selectedAccountName != null)
            Container(
              padding: const EdgeInsets.all(Spacing.lg),
              decoration: BoxDecoration(
                color: const Color(0xFF007AFF).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF007AFF).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    CupertinoIcons.checkmark_circle_fill,
                    color: const Color(0xFF007AFF),
                  ),
                  const SizedBox(width: Spacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Linked Account',
                          style: TextStyle(
                            color: AppStyles.getSecondaryTextColor(context),
                            fontSize: TypeScale.footnote,
                          ),
                        ),
                        Text(
                          controller.selectedAccountName ?? 'N/A',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: TypeScale.body,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: Spacing.xl),
        ],
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isHighlight;

  const _ReviewRow({
    required this.label,
    required this.value,
    this.isHighlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
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
            color: isHighlight
                ? const Color(0xFF007AFF)
                : AppStyles.getTextColor(context),
            fontWeight: isHighlight ? FontWeight.bold : FontWeight.w500,
            fontSize: isHighlight ? 14 : 13,
          ),
        ),
      ],
    );
  }
}
