import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/ui/manage/digital_gold/digital_gold_wizard_controller.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';

class GoldInvestedAmountStep extends StatefulWidget {
  const GoldInvestedAmountStep({super.key});

  @override
  State<GoldInvestedAmountStep> createState() => _GoldInvestedAmountStepState();
}

class _GoldInvestedAmountStepState extends State<GoldInvestedAmountStep> {
  late TextEditingController _amountController;

  @override
  void initState() {
    super.initState();
    final controller =
        Provider.of<DigitalGoldWizardController>(context, listen: false);
    _amountController = TextEditingController(
      text: controller.investedAmount > 0
          ? controller.investedAmount.toString()
          : '',
    );
  }

  void _updateAmount() {
    final controller =
        Provider.of<DigitalGoldWizardController>(context, listen: false);
    final amount = double.tryParse(_amountController.text) ?? 0;
    controller.updateInvestedAmount(amount);
  }

  @override
  void dispose() {
    _amountController.dispose();
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
            'Invested Amount',
            style: AppStyles.titleStyle(context),
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            'Enter the total amount you spent (including GST)',
            style: TextStyle(color: AppStyles.getSecondaryTextColor(context)),
          ),
          const SizedBox(height: 30),
          Text(
            'Total Amount Invested (₹)',
            style: TextStyle(
              color: AppStyles.getTextColor(context),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: Spacing.sm),
          CupertinoTextField(
            controller: _amountController,
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
            onChanged: (_) => _updateAmount(),
          ),
          const SizedBox(height: 30),
          Container(
            padding: const EdgeInsets.all(Spacing.lg),
            decoration: BoxDecoration(
              color: AppStyles.teal(context).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppStyles.teal(context).withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'How it works',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppStyles.getTextColor(context),
                    fontSize: TypeScale.footnote,
                  ),
                ),
                const SizedBox(height: Spacing.sm),
                Text(
                  'Example: You spent ₹49.44\n• Actual gold cost: ₹48 (49.44 ÷ 1.03)\n• GST (3%): ₹1.44\n• Total: ₹49.44\n\nJust enter your total spent amount, we\'ll calculate the rest!',
                  style: TextStyle(
                    color: AppStyles.getSecondaryTextColor(context),
                    fontSize: TypeScale.footnote,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          // Summary calculation
          if (controller.investedAmount > 0) ...{
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
                        'Total Invested',
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
