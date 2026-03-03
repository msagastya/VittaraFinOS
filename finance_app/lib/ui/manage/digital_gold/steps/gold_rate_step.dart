import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/ui/manage/digital_gold/digital_gold_wizard_controller.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';

class GoldRateStep extends StatefulWidget {
  const GoldRateStep({super.key});

  @override
  State<GoldRateStep> createState() => _GoldRateStepState();
}

class _GoldRateStepState extends State<GoldRateStep> {
  late TextEditingController _rateController;

  @override
  void initState() {
    super.initState();
    final controller =
        Provider.of<DigitalGoldWizardController>(context, listen: false);
    _rateController = TextEditingController(
      text: controller.investmentRate > 0
          ? controller.investmentRate.toString()
          : '',
    );
  }

  void _updateRate() {
    final controller =
        Provider.of<DigitalGoldWizardController>(context, listen: false);
    final rate = double.tryParse(_rateController.text) ?? 0;
    controller.updateInvestmentRate(rate);
  }

  @override
  void dispose() {
    _rateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<DigitalGoldWizardController>(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(Spacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Investment Rate',
            style: AppStyles.titleStyle(context),
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            'Enter the rate per gram at the time of investment',
            style: TextStyle(color: AppStyles.getSecondaryTextColor(context)),
          ),
          const SizedBox(height: 30),
          Text(
            'Rate per gram (₹)',
            style: TextStyle(
              color: AppStyles.getTextColor(context),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: Spacing.sm),
          CupertinoTextField(
            controller: _rateController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            placeholder: '0.00',
            padding: const EdgeInsets.all(Spacing.lg),
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
            onChanged: (_) => _updateRate(),
          ),
          const SizedBox(height: 30),
          // Summary calculation
          if (controller.investedAmount > 0 &&
              controller.investmentRate > 0) ...{
            Container(
              padding: const EdgeInsets.all(Spacing.lg),
              decoration: BoxDecoration(
                color: const Color(0xFFFFB81C).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFFFB81C).withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Actual Gold Cost',
                        style: TextStyle(
                          color: AppStyles.getSecondaryTextColor(context),
                          fontSize: TypeScale.footnote,
                        ),
                      ),
                      Text(
                        '₹${controller.actualAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: TypeScale.body,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Spacing.md),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Weight (grams)',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '${controller.weightInGrams.toStringAsFixed(4)} g',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: TypeScale.body,
                          color: Color(0xFFFFB81C),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Spacing.md),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'GST (${controller.gstRate}%)',
                        style: TextStyle(
                          color: AppStyles.getSecondaryTextColor(context),
                          fontSize: TypeScale.footnote,
                        ),
                      ),
                      Text(
                        '₹${controller.gstAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: TypeScale.body,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Investment',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: TypeScale.body,
                        ),
                      ),
                      Text(
                        '₹${controller.investedAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: TypeScale.headline,
                          color: Color(0xFFFFB81C),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          },
          const SizedBox(height: Spacing.xl),
        ],
      ),
    );
  }
}
