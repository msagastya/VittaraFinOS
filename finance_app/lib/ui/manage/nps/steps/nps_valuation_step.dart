import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/ui/manage/nps/nps_wizard_controller.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';

class NPSValuationStep extends StatefulWidget {
  const NPSValuationStep({super.key});

  @override
  State<NPSValuationStep> createState() => _NPSValuationStepState();
}

class _NPSValuationStepState extends State<NPSValuationStep> {
  late TextEditingController _valueController;

  @override
  void initState() {
    super.initState();
    final ctrl = Provider.of<NPSWizardController>(context, listen: false);
    _valueController = TextEditingController(
      text: ctrl.currentValue != null ? ctrl.currentValue!.toString() : '',
    );
  }

  @override
  void dispose() {
    _valueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = Provider.of<NPSWizardController>(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Current Valuation', style: AppStyles.titleStyle(context)),
          const SizedBox(height: 8),
          Text('Enter current account value',
              style:
                  TextStyle(color: AppStyles.getSecondaryTextColor(context))),
          const SizedBox(height: 30),
          Text('Current Account Value (₹)',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 12),
          CupertinoTextField(
            controller: _valueController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            placeholder: '0.00',
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppStyles.getCardColor(context),
              borderRadius: BorderRadius.circular(12),
            ),
            prefix: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Text('₹',
                  style: TextStyle(color: AppStyles.getTextColor(context))),
            ),
            onChanged: (v) {
              final val = double.tryParse(v) ?? 0;
              if (val > 0) ctrl.updateCurrentValue(val);
            },
          ),
          const SizedBox(height: 30),
          if (ctrl.currentValue != null && ctrl.totalContributed != null) ...{
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF9B59B6).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFF9B59B6).withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  _StatRow(
                    'Total Contribution',
                    '₹${ctrl.totalContributed!.toStringAsFixed(2)}',
                  ),
                  const SizedBox(height: 12),
                  _StatRow(
                    'Current Value',
                    '₹${ctrl.currentValue!.toStringAsFixed(2)}',
                    isBold: true,
                  ),
                  const SizedBox(height: 12),
                  _StatRow(
                    'Estimated Returns',
                    '₹${ctrl.estimatedReturns.toStringAsFixed(2)}',
                    isPositive: ctrl.estimatedReturns >= 0,
                  ),
                  const SizedBox(height: 12),
                  _StatRow(
                    'Return %',
                    '${ctrl.gainLossPercent.toStringAsFixed(2)}%',
                    isHighlight: true,
                    isPositive: ctrl.gainLossPercent >= 0,
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

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;
  final bool isHighlight;
  final bool isPositive;

  const _StatRow(
    this.label,
    this.value, {
    this.isBold = false,
    this.isHighlight = false,
    this.isPositive = true,
  });

  @override
  Widget build(BuildContext context) {
    final color = isHighlight
        ? (isPositive ? CupertinoColors.systemGreen : CupertinoColors.systemRed)
        : (isPositive ? null : CupertinoColors.systemRed);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 13, color: AppStyles.getSecondaryTextColor(context))),
        Text(value,
            style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
                fontSize: isHighlight ? 14 : 13,
                color: color ?? const Color(0xFF9B59B6))),
      ],
    );
  }
}
