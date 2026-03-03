import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/ui/manage/mf/sip_wizard_controller.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';

class SIPStepUpStep extends StatefulWidget {
  const SIPStepUpStep({super.key});

  @override
  State<SIPStepUpStep> createState() => _SIPStepUpStepState();
}

class _SIPStepUpStepState extends State<SIPStepUpStep> {
  late TextEditingController _percentController;
  late TextEditingController _durationController;

  @override
  void initState() {
    super.initState();
    final controller = Provider.of<SIPWizardController>(context, listen: false);
    _percentController = TextEditingController(
      text: controller.stepUpPercent > 0
          ? controller.stepUpPercent.toString()
          : '',
    );
    _durationController = TextEditingController(
      text: controller.stepUpDuration.toString(),
    );
  }

  void _updateStepUp() {
    final controller = Provider.of<SIPWizardController>(context, listen: false);
    final percent = double.tryParse(_percentController.text) ?? 0;
    final duration = int.tryParse(_durationController.text) ?? 1;
    controller.updateStepUp(
      percent: percent,
      tenure: controller.stepUpTenure,
      duration: duration,
    );
  }

  @override
  void dispose() {
    _percentController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sipController = Provider.of<SIPWizardController>(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Step Up Configuration',
            style: AppStyles.titleStyle(context),
          ),
          const SizedBox(height: 8),
          Text(
            'Automatically increase your SIP amount over time',
            style: TextStyle(color: AppStyles.getSecondaryTextColor(context)),
          ),
          const SizedBox(height: 30),

          // Step Up Toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Enable Step Up',
                style: TextStyle(
                  color: AppStyles.getTextColor(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
              CupertinoSwitch(
                value: sipController.stepUpEnabled,
                onChanged: (value) {
                  sipController.toggleStepUp(value);
                },
                activeTrackColor: SemanticColors.investments,
              ),
            ],
          ),
          const SizedBox(height: 30),

          if (sipController.stepUpEnabled) ...[
            // Step Up Percent
            Text(
              'Step Up Percentage (%)',
              style: TextStyle(
                color: AppStyles.getTextColor(context),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            CupertinoTextField(
              controller: _percentController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              placeholder: '0.00',
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppStyles.getCardColor(context),
                borderRadius: BorderRadius.circular(12),
              ),
              suffix: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Text(
                  '%',
                  style: TextStyle(color: AppStyles.getTextColor(context)),
                ),
              ),
              style: TextStyle(color: AppStyles.getTextColor(context)),
              onChanged: (_) => _updateStepUp(),
            ),
            const SizedBox(height: 20),

            // Step Up Tenure
            Text(
              'Step Up Tenure',
              style: TextStyle(
                color: AppStyles.getTextColor(context),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            CupertinoSegmentedControl<StepUpTenure>(
              children: const {
                StepUpTenure.monthly: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('Monthly'),
                ),
                StepUpTenure.yearly: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('Yearly'),
                ),
              },
              groupValue: sipController.stepUpTenure,
              onValueChanged: (value) {
                sipController.updateStepUp(
                  percent: sipController.stepUpPercent,
                  tenure: value,
                  duration: sipController.stepUpDuration,
                );
              },
            ),
            const SizedBox(height: 20),

            // Duration Input
            Text(
              sipController.stepUpTenure == StepUpTenure.yearly
                  ? 'Every (Years)'
                  : 'Every (Months)',
              style: TextStyle(
                color: AppStyles.getTextColor(context),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            CupertinoTextField(
              controller: _durationController,
              keyboardType: TextInputType.number,
              placeholder: '1',
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppStyles.getCardColor(context),
                borderRadius: BorderRadius.circular(12),
              ),
              style: TextStyle(color: AppStyles.getTextColor(context)),
              onChanged: (_) => _updateStepUp(),
            ),
            const SizedBox(height: 30),

            // Info Box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: CupertinoColors.systemBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: CupertinoColors.systemBlue.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        CupertinoIcons.info,
                        size: 16,
                        color: AppStyles.getSecondaryTextColor(context),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Example',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'If you set 10% step up every 1 year:\nYear 1: ₹${sipController.sipAmount.toStringAsFixed(0)}/month\nYear 2: ₹${(sipController.sipAmount * 1.1).toStringAsFixed(0)}/month\nYear 3: ₹${(sipController.sipAmount * 1.21).toStringAsFixed(0)}/month',
                    style: TextStyle(
                      color: AppStyles.getSecondaryTextColor(context),
                      fontSize: TypeScale.footnote,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Step Up is disabled. Your SIP amount will remain constant.',
                style: TextStyle(
                  color: AppStyles.getSecondaryTextColor(context),
                  fontSize: TypeScale.footnote,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
