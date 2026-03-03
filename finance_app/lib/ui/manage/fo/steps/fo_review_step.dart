import 'package:flutter/cupertino.dart';
import 'package:vittara_fin_os/logic/fo_model.dart';
import 'package:vittara_fin_os/ui/manage/fo/fo_wizard_controller.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';

class FOReviewStep extends StatelessWidget {
  final FOWizardController ctrl;

  const FOReviewStep(this.ctrl, {super.key});

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
              _Row(
                  'Type',
                  ctrl.selectedType.name == 'futures'
                      ? 'Futures'
                      : (ctrl.selectedType.name == 'callOption'
                          ? 'Call Option'
                          : 'Put Option')),
              _Row('Symbol', ctrl.symbol),
              _Row('Contract', ctrl.contractName),
              _Row('Quantity', ctrl.quantity?.toString() ?? '0'),
              _Row('Entry Price',
                  '₹${ctrl.entryPrice?.toStringAsFixed(2) ?? '0'}'),
              _Row('Current Price',
                  '₹${ctrl.currentPrice?.toStringAsFixed(2) ?? '0'}'),
              if (ctrl.selectedType != FOType.futures)
                _Row('Strike Price',
                    '₹${ctrl.strikePrice?.toStringAsFixed(2) ?? '0'}'),
              _Row('Entry Date',
                  '${ctrl.entryDate.day}/${ctrl.entryDate.month}/${ctrl.entryDate.year}'),
              _Row('Expiry Date',
                  '${ctrl.expiryDate.day}/${ctrl.expiryDate.month}/${ctrl.expiryDate.year}'),
            ],
          ),
          const SizedBox(height: 20),
          _Card(
            children: [
              _Row('Total Cost', '₹${ctrl.totalCost.toStringAsFixed(2)}'),
              _Row('Current Value', '₹${ctrl.currentValue.toStringAsFixed(2)}',
                  isBold: true),
              _Row('Unrealized P&L',
                  '${isGain ? '+' : ''}₹${ctrl.gainLoss.toStringAsFixed(2)}',
                  isGain: isGain),
              _Row('Return %',
                  '${isGain ? '+' : ''}${ctrl.gainLossPercent.toStringAsFixed(2)}%',
                  isBold: true, isGain: isGain),
            ],
          ),
          if (ctrl.selectedType != FOType.futures && ctrl.greeks != null) ...[
            const SizedBox(height: 20),
            _Card(
              children: [
                _Row('Delta', ctrl.greeks!.delta.toStringAsFixed(4)),
                _Row('Gamma', ctrl.greeks!.gamma.toStringAsFixed(6)),
                _Row('Theta', ctrl.greeks!.theta.toStringAsFixed(4)),
                _Row('Vega', ctrl.greeks!.vega.toStringAsFixed(4)),
                _Row('Rho', ctrl.greeks!.rho.toStringAsFixed(4)),
              ],
            ),
          ],
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
    if (label.contains('P&L') || label.contains('Return')) {
      color = isGain ? CupertinoColors.systemGreen : CupertinoColors.systemRed;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                color: AppStyles.getSecondaryTextColor(context), fontSize: 13)),
        Text(value,
            style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
                fontSize: isBold ? 14 : 13,
                color: color)),
      ],
    );
  }
}
