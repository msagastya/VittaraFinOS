import 'package:flutter/cupertino.dart';
import 'package:vittara_fin_os/logic/fo_model.dart';
import 'package:vittara_fin_os/ui/manage/fo/fo_wizard_controller.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';

class FORiskAnalysisStep extends StatelessWidget {
  final FOWizardController ctrl;

  const FORiskAnalysisStep(this.ctrl, {super.key});

  @override
  Widget build(BuildContext context) {
    final maxProfit = ctrl.selectedType == FOType.futures
        ? 'Unlimited'
        : (ctrl.selectedType == FOType.callOption
            ? 'Unlimited'
            : '₹${((ctrl.strikePrice ?? 0) - (ctrl.entryPrice ?? 0)) * (ctrl.quantity ?? 0)}');

    final maxLoss = ctrl.selectedType == FOType.futures
        ? 'Unlimited'
        : (ctrl.selectedType == FOType.callOption
            ? '₹${ctrl.totalCost}'
            : 'Unlimited');

    final breakeven = ctrl.selectedType == FOType.futures
        ? '₹${(ctrl.entryPrice ?? 0)}'
        : (ctrl.selectedType == FOType.callOption
            ? '₹${((ctrl.entryPrice ?? 0) + (ctrl.strikePrice ?? 0))}'
            : '₹${((ctrl.strikePrice ?? 0) - (ctrl.entryPrice ?? 0))}');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(Spacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Risk Analysis', style: AppStyles.titleStyle(context)),
          const SizedBox(height: 30),
          _AnalysisCard(
            title: 'Position Overview',
            children: [
              _AnalysisRow(
                  'Type',
                  ctrl.selectedType.name == 'futures'
                      ? 'Futures'
                      : (ctrl.selectedType.name == 'callOption'
                          ? 'Call Option'
                          : 'Put Option')),
              _AnalysisRow('Symbol', ctrl.symbol),
              _AnalysisRow('Quantity', ctrl.quantity?.toString() ?? '0'),
              _AnalysisRow('Days to Expiry',
                  '${ctrl.expiryDate.difference(DateTime.now()).inDays}'),
            ],
          ),
          const SizedBox(height: Spacing.xl),
          _AnalysisCard(
            title: 'Risk/Reward Profile',
            children: [
              _AnalysisRow('Max Profit', maxProfit, isProfit: true),
              _AnalysisRow('Max Loss', maxLoss, isProfit: false),
              _AnalysisRow('Breakeven Price', breakeven, isBold: true),
            ],
          ),
          const SizedBox(height: Spacing.xl),
          _AnalysisCard(
            title: 'Current Position',
            children: [
              _AnalysisRow('Entry Price', '₹${ctrl.entryPrice}'),
              _AnalysisRow('Current Price', '₹${ctrl.currentPrice}'),
              _AnalysisRow(
                  'Total Cost', '₹${ctrl.totalCost.toStringAsFixed(2)}'),
              _AnalysisRow(
                  'Current Value', '₹${ctrl.currentValue.toStringAsFixed(2)}',
                  isBold: true),
              _AnalysisRow('Unrealized P&L',
                  '${ctrl.gainLoss >= 0 ? '+' : ''}₹${ctrl.gainLoss.toStringAsFixed(2)}',
                  isProfit: ctrl.gainLoss >= 0, isBold: true),
            ],
          ),
          if (ctrl.selectedType != FOType.futures) ...[
            const SizedBox(height: Spacing.xl),
            _AnalysisCard(
              title: 'Greeks Impact',
              children: [
                _AnalysisRow(
                    'Delta', ctrl.greeks?.delta.toStringAsFixed(4) ?? 'N/A',
                    note:
                        '1 unit move in underlying = ${(ctrl.greeks?.delta ?? 0).toStringAsFixed(4)} point change'),
                _AnalysisRow('Theta (Time Decay)',
                    ctrl.greeks?.theta.toStringAsFixed(4) ?? 'N/A',
                    note: 'Per day loss from time decay'),
                _AnalysisRow(
                    'Vega', ctrl.greeks?.vega.toStringAsFixed(4) ?? 'N/A',
                    note:
                        '1% volatility increase = ${(ctrl.greeks?.vega ?? 0).toStringAsFixed(4)} point change'),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _AnalysisCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _AnalysisCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Spacing.lg),
      decoration: BoxDecoration(
        color: AppStyles.getCardColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: CupertinoColors.systemGrey.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: TypeScale.body)),
          const SizedBox(height: Spacing.lg),
          ...List.generate(
            children.length,
            (i) => Column(
              children: [
                children[i],
                if (i < children.length - 1) const SizedBox(height: Spacing.md),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AnalysisRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isProfit;
  final bool isBold;
  final String? note;

  const _AnalysisRow(
    this.label,
    this.value, {
    this.isProfit = true,
    this.isBold = false,
    this.note,
  });

  @override
  Widget build(BuildContext context) {
    Color? color;
    if (label.contains('P&L') || label.contains('Loss')) {
      color =
          isProfit ? AppStyles.bioGreen : AppStyles.plasmaRed;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(
                    color: AppStyles.getSecondaryTextColor(context),
                    fontSize: TypeScale.subhead)),
            Text(value,
                style: TextStyle(
                    fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
                    fontSize: isBold ? 14 : 13,
                    color: color)),
          ],
        ),
        if (note != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(note!,
                style: TextStyle(
                    fontSize: TypeScale.caption,
                    color: AppStyles.getSecondaryTextColor(context))),
          ),
      ],
    );
  }
}
