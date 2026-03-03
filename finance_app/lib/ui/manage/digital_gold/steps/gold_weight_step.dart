import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/ui/manage/digital_gold/digital_gold_wizard_controller.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';

class GoldWeightStep extends StatefulWidget {
  const GoldWeightStep({super.key});

  @override
  State<GoldWeightStep> createState() => _GoldWeightStepState();
}

class _GoldWeightStepState extends State<GoldWeightStep> {
  late TextEditingController _weightController;

  @override
  void initState() {
    super.initState();
    final controller =
        Provider.of<DigitalGoldWizardController>(context, listen: false);
    _weightController = TextEditingController(
      text: controller.weight > 0 ? controller.weight.toString() : '',
    );
  }

  void _updateWeight() {
    final controller =
        Provider.of<DigitalGoldWizardController>(context, listen: false);
    final weight = double.tryParse(_weightController.text) ?? 0;
    controller.updateWeight(weight);
  }

  @override
  void dispose() {
    _weightController.dispose();
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
            'Gold Weight',
            style: AppStyles.titleStyle(context),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter the amount of gold you want to invest',
            style: TextStyle(color: AppStyles.getSecondaryTextColor(context)),
          ),
          const SizedBox(height: 30),
          Text(
            'Weight (in grams)',
            style: TextStyle(
              color: AppStyles.getTextColor(context),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          CupertinoTextField(
            controller: _weightController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            placeholder: '0.00',
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppStyles.getCardColor(context),
              borderRadius: BorderRadius.circular(12),
            ),
            suffix: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                'g',
                style:
                    TextStyle(color: AppStyles.getSecondaryTextColor(context)),
              ),
            ),
            style: TextStyle(color: AppStyles.getTextColor(context)),
            onChanged: (_) => _updateWeight(),
          ),
          const SizedBox(height: 30),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: CupertinoColors.activeBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Tip: 1 gram of gold is the smallest unit you can buy. Most platforms offer flexible weights from 0.1 grams onwards.',
              style: TextStyle(
                color: AppStyles.getSecondaryTextColor(context),
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}
