import 'package:flutter/cupertino.dart';
import 'package:vittara_fin_os/ui/manage/commodities/commodities_wizard_controller.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';

class CommodityReviewStep extends StatelessWidget {
  final CommoditiesWizardController ctrl;

  const CommodityReviewStep(this.ctrl, {super.key});

  @override
  Widget build(BuildContext context) {
    final isGain = ctrl.gainLoss >= 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Review & Confirm', style: AppStyles.titleStyle(context)),
          const SizedBox(height: 30),
          _Card(
            children: [
              _Row('Commodity', ctrl.commodityName),
              _Row('Type', ctrl.selectedType.name.toUpperCase()),
              _Row('Quantity', '${ctrl.quantity} ${ctrl.unit}'),
              _Row('Purchase Price',
                  '₹${ctrl.buyPrice?.toStringAsFixed(2) ?? '0'}/${ctrl.unit}'),
              _Row('Current Price',
                  '₹${ctrl.currentPrice?.toStringAsFixed(2) ?? '0'}/${ctrl.unit}'),
              _Row('Exchange', ctrl.exchange ?? 'N/A'),
              _Row('Position', ctrl.position.name.toUpperCase()),
            ],
          ),
          const SizedBox(height: 20),
          _Card(
            children: [
              _Row('Total Cost', '₹${ctrl.totalCost.toStringAsFixed(2)}'),
              _Row('Current Value', '₹${ctrl.currentValue.toStringAsFixed(2)}',
                  isBold: true),
              _Row('Gain/Loss', '₹${ctrl.gainLoss.toStringAsFixed(2)}',
                  isGain: isGain),
              _Row('Return %', '${ctrl.gainLossPercent.toStringAsFixed(2)}%',
                  isBold: true, isGain: isGain),
            ],
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final List<Widget> children;

  const _Card({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppStyles.getCardColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CupertinoColors.systemGrey.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: List.generate(
          children.length,
          (i) => Column(
            children: [
              children[i],
              if (i < children.length - 1) const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;
  final bool isGain;

  const _Row(this.label, this.value, {this.isBold = false, this.isGain = true});

  @override
  Widget build(BuildContext context) {
    Color? color;
    if (label.contains('Return %') || label.contains('Gain/Loss')) {
      color = isGain ? CupertinoColors.systemGreen : CupertinoColors.systemRed;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                color: AppStyles.getSecondaryTextColor(context), fontSize: TypeScale.subhead)),
        Text(value,
            style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
                fontSize: isBold ? 14 : 13,
                color: color)),
      ],
    );
  }
}
