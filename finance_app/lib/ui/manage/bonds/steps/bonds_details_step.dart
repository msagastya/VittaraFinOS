import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/bonds_model.dart';
import 'package:vittara_fin_os/ui/manage/bonds/bonds_wizard_controller.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';

class BondsDetailsStep extends StatefulWidget {
  const BondsDetailsStep({super.key});

  @override
  State<BondsDetailsStep> createState() => _BondsDetailsStepState();
}

class _BondsDetailsStepState extends State<BondsDetailsStep> {
  late TextEditingController _couponRateController;
  late TextEditingController _quantityController;
  late TextEditingController _creditRatingController;

  @override
  void initState() {
    super.initState();
    final controller =
        Provider.of<BondsWizardController>(context, listen: false);
    _couponRateController = TextEditingController(
      text: controller.couponRate != null
          ? controller.couponRate!.toString()
          : '',
    );
    _quantityController = TextEditingController(
      text: controller.purchaseQuantity.toString(),
    );
    _creditRatingController = TextEditingController(
      text: controller.creditRating ?? '',
    );
  }

  @override
  void dispose() {
    _couponRateController.dispose();
    _quantityController.dispose();
    _creditRatingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<BondsWizardController>(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bond Specifications',
            style: AppStyles.titleStyle(context),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter coupon details and quantity',
            style: TextStyle(color: AppStyles.getSecondaryTextColor(context)),
          ),
          const SizedBox(height: 30),
          // Coupon Rate
          Text(
            'Annual Coupon Rate (%)',
            style: TextStyle(
              color: AppStyles.getTextColor(context),
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          CupertinoTextField(
            controller: _couponRateController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            placeholder: '7.5',
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppStyles.getCardColor(context),
              borderRadius: BorderRadius.circular(12),
            ),
            suffix: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                '%',
                style:
                    TextStyle(color: AppStyles.getSecondaryTextColor(context)),
              ),
            ),
            style: TextStyle(color: AppStyles.getTextColor(context)),
            onChanged: (value) {
              final rate = double.tryParse(value) ?? 0;
              if (rate >= 0) {
                controller.updateCouponRate(rate);
              }
            },
          ),
          const SizedBox(height: 24),
          // Coupon Frequency
          Text(
            'Coupon Payment Frequency',
            style: TextStyle(
              color: AppStyles.getTextColor(context),
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          CupertinoSegmentedControl<CouponFrequency>(
            children: {
              CouponFrequency.annual: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Annual',
                  style: TextStyle(fontSize: 13),
                ),
              ),
              CouponFrequency.semiAnnual: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Semi-Annual',
                  style: TextStyle(fontSize: 13),
                ),
              ),
              CouponFrequency.quarterly: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Quarterly',
                  style: TextStyle(fontSize: 13),
                ),
              ),
              CouponFrequency.monthly: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Monthly',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            },
            groupValue: controller.couponFrequency,
            onValueChanged: (value) {
              controller.updateCouponFrequency(value);
            },
          ),
          const SizedBox(height: 24),
          // Quantity
          Text(
            'Quantity (Number of Bonds)',
            style: TextStyle(
              color: AppStyles.getTextColor(context),
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          CupertinoTextField(
            controller: _quantityController,
            keyboardType: TextInputType.number,
            placeholder: '10',
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppStyles.getCardColor(context),
              borderRadius: BorderRadius.circular(12),
            ),
            style: TextStyle(color: AppStyles.getTextColor(context)),
            onChanged: (value) {
              final qty = int.tryParse(value) ?? 1;
              if (qty > 0) {
                controller.updatePurchaseQuantity(qty);
              }
            },
          ),
          const SizedBox(height: 24),
          // Credit Rating
          Text(
            'Credit Rating (Optional)',
            style: TextStyle(
              color: AppStyles.getTextColor(context),
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ['AAA', 'AA', 'A', 'BBB', 'BB', 'B', 'C'].map((rating) {
              final isSelected = controller.creditRating == rating;
              return GestureDetector(
                onTap: () {
                  controller.updateCreditRating(rating);
                  _creditRatingController.text = rating;
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF007AFF)
                        : AppStyles.getCardColor(context),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF007AFF)
                          : CupertinoColors.systemGrey.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    rating,
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : AppStyles.getTextColor(context),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 30),
          // Summary
          if (controller.couponRate != null && controller.couponRate! > 0) ...{
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF007AFF).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF007AFF).withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Annual Coupon Payment',
                        style: TextStyle(
                          color: AppStyles.getSecondaryTextColor(context),
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        '₹${controller.annualCouponPayment.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Per Coupon Payment',
                        style: TextStyle(
                          color: AppStyles.getSecondaryTextColor(context),
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        '₹${controller.couponPerPayment.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Color(0xFF007AFF),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          },
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
