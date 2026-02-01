import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/ui/manage/bonds/bonds_wizard_controller.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';

class BondsReviewStep extends StatelessWidget {
  const BondsReviewStep({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<BondsWizardController>(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Review & Confirm',
            style: AppStyles.titleStyle(context),
          ),
          const SizedBox(height: 8),
          Text(
            'Verify all details before saving',
            style: TextStyle(color: AppStyles.getSecondaryTextColor(context)),
          ),
          const SizedBox(height: 30),
          // Bond Information Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppStyles.getCardColor(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.grey.withValues(alpha: 0.2),
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
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                _ReviewRow(
                  label: 'Bond Name',
                  value: controller.bondName ?? 'N/A',
                ),
                const SizedBox(height: 12),
                _ReviewRow(
                  label: 'Type',
                  value: controller.selectedBondType?.toString().split('.').last ?? 'N/A',
                ),
                const SizedBox(height: 12),
                _ReviewRow(
                  label: 'Issuer',
                  value: controller.selectedIssuer ?? 'N/A',
                ),
                const SizedBox(height: 12),
                _ReviewRow(
                  label: 'Face Value',
                  value: '₹${controller.faceValue?.toStringAsFixed(2) ?? '0.00'}',
                ),
                if (controller.creditRating != null) ...[
                  const SizedBox(height: 12),
                  _ReviewRow(
                    label: 'Credit Rating',
                    value: controller.creditRating ?? 'N/A',
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Purchase Details Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppStyles.getCardColor(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.grey.withValues(alpha: 0.2),
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
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                _ReviewRow(
                  label: 'Quantity',
                  value: '${controller.purchaseQuantity} bonds',
                ),
                const SizedBox(height: 12),
                _ReviewRow(
                  label: 'Purchase Price per Bond',
                  value: '₹${controller.purchasePrice?.toStringAsFixed(2) ?? '0.00'}',
                ),
                const SizedBox(height: 12),
                _ReviewRow(
                  label: 'Total Cost',
                  value: '₹${controller.totalCost.toStringAsFixed(2)}',
                  isHighlight: true,
                ),
                const SizedBox(height: 12),
                _ReviewRow(
                  label: 'Purchase Date',
                  value:
                      '${controller.purchaseDate.day}/${controller.purchaseDate.month}/${controller.purchaseDate.year}',
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Coupon Details Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppStyles.getCardColor(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.grey.withValues(alpha: 0.2),
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
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                _ReviewRow(
                  label: 'Annual Coupon Rate',
                  value: '${controller.couponRate?.toStringAsFixed(2) ?? '0.00'}%',
                ),
                const SizedBox(height: 12),
                _ReviewRow(
                  label: 'Coupon Frequency',
                  value: controller.couponFrequency.toString().split('.').last,
                ),
                const SizedBox(height: 12),
                _ReviewRow(
                  label: 'Annual Coupon Payment',
                  value: '₹${controller.annualCouponPayment.toStringAsFixed(2)}',
                  isHighlight: true,
                ),
                const SizedBox(height: 12),
                _ReviewRow(
                  label: 'Per Coupon Payment',
                  value: '₹${controller.couponPerPayment.toStringAsFixed(2)}',
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Account Link Card
          if (controller.selectedAccountName != null)
            Container(
              padding: const EdgeInsets.all(16),
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
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Linked Account',
                          style: TextStyle(
                            color: AppStyles.getSecondaryTextColor(context),
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          controller.selectedAccountName ?? 'N/A',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 20),
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
            fontSize: 13,
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
