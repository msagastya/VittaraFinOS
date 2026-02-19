import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/ui/manage/digital_gold/digital_gold_wizard_controller.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';

class GoldGSTStep extends StatefulWidget {
  const GoldGSTStep({super.key});

  @override
  State<GoldGSTStep> createState() => _GoldGSTStepState();
}

class _GoldGSTStepState extends State<GoldGSTStep> {
  late TextEditingController _gstController;

  @override
  void initState() {
    super.initState();
    final controller =
        Provider.of<DigitalGoldWizardController>(context, listen: false);
    _gstController = TextEditingController(
      text: controller.gstRate.toString(),
    );
  }

  void _updateGST() {
    final controller =
        Provider.of<DigitalGoldWizardController>(context, listen: false);
    final gst = double.tryParse(_gstController.text) ?? 3.0;
    controller.updateGSTRate(gst);
  }

  @override
  void dispose() {
    _gstController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<DigitalGoldWizardController>(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'GST Rate',
            style: AppStyles.titleStyle(context),
          ),
          const SizedBox(height: 8),
          Text(
            'Confirm the GST rate (default 3%)',
            style: TextStyle(color: AppStyles.getSecondaryTextColor(context)),
          ),
          const SizedBox(height: 30),
          Text(
            'GST Rate (%)',
            style: TextStyle(
              color: AppStyles.getTextColor(context),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          CupertinoTextField(
            controller: _gstController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            placeholder: '3.0',
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
            onChanged: (_) => _updateGST(),
          ),
          const SizedBox(height: 30),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.orange.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Information',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppStyles.getTextColor(context),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '• Standard GST on gold is 3%\n• The total amount you entered already includes this GST\n• Different providers may have different rates\n• Adjust if your provider uses a different rate',
                  style: TextStyle(
                    color: AppStyles.getSecondaryTextColor(context),
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          // Summary breakdown
          if (controller.investedAmount > 0) ...{
            Container(
              padding: const EdgeInsets.all(16),
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
                      const Text(
                        'Actual Gold Cost',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '₹${controller.actualAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFFFB81C),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'GST Amount',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '₹${controller.gstAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFFFB81C),
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
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '₹${controller.investedAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Color(0xFFFFB81C),
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
