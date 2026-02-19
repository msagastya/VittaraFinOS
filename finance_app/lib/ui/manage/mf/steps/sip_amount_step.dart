import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/ui/manage/mf/sip_wizard_controller.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';

class SIPAmountStep extends StatefulWidget {
  const SIPAmountStep({super.key});

  @override
  State<SIPAmountStep> createState() => _SIPAmountStepState();
}

class _SIPAmountStepState extends State<SIPAmountStep> {
  late TextEditingController _amountController;

  @override
  void initState() {
    super.initState();
    final controller = Provider.of<SIPWizardController>(context, listen: false);
    _amountController = TextEditingController(
      text: controller.sipAmount > 0 ? controller.sipAmount.toString() : '',
    );
  }

  void _updateAmount() {
    final controller = Provider.of<SIPWizardController>(context, listen: false);
    final amount = double.tryParse(_amountController.text) ?? 0;
    controller.updateSIPAmount(amount);
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SIP Amount',
            style: AppStyles.titleStyle(context),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter the monthly SIP amount you want to invest',
            style: TextStyle(color: AppStyles.getSecondaryTextColor(context)),
          ),
          const SizedBox(height: 40),
          Text(
            'Monthly SIP Amount',
            style: TextStyle(
              color: AppStyles.getTextColor(context),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          CupertinoTextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            placeholder: '0.00',
            padding: const EdgeInsets.all(16),
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
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: CupertinoColors.systemBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: CupertinoColors.systemBlue.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  CupertinoIcons.info,
                  size: 16,
                  color: AppStyles.getSecondaryTextColor(context),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'This amount will be automatically deducted from your selected bank account every month.',
                    style: TextStyle(
                      color: AppStyles.getSecondaryTextColor(context),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
