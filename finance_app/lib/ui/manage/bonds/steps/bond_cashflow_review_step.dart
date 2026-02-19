import 'package:flutter/material.dart';
import 'package:vittara_fin_os/ui/manage/bonds/bonds_wizard_controller_v2.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';

class BondCashFlowReviewStep extends StatelessWidget {
  final BondsWizardControllerV2 ctrl;

  const BondCashFlowReviewStep(this.ctrl, {super.key});

  @override
  Widget build(BuildContext context) {
    final isProfit = ctrl.gainLoss >= 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Generated Cash Flows', style: AppStyles.titleStyle(context)),
          const SizedBox(height: 10),
          Text(
            'This is your bond\'s payment schedule. Every cash flow is listed below.',
            style: TextStyle(
              fontSize: 12,
              color: AppStyles.getSecondaryTextColor(context),
            ),
          ),
          const SizedBox(height: 20),
          // Cash Flow Table
          Container(
            decoration: BoxDecoration(
              color: AppStyles.getCardColor(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00A6CC).withValues(alpha: 0.1),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          'Date',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: const Color(0xFF00A6CC),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          'Amount',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: const Color(0xFF00A6CC),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          'Description',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: const Color(0xFF00A6CC),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Rows
                ...List.generate(ctrl.generatedCashFlows.length, (index) {
                  final cf = ctrl.generatedCashFlows[index];
                  final isNegative = cf.amount < 0;
                  return Column(
                    children: [
                      Divider(
                        height: 1,
                        color: Colors.grey.withValues(alpha: 0.1),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(
                                '${cf.date.day}/${cf.date.month}/${cf.date.year}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                '${isNegative ? '-' : '+'}₹${cf.amount.abs().toStringAsFixed(2)}',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isNegative ? Colors.red : Colors.green,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                cf.description,
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontSize: 11,
                                  color:
                                      AppStyles.getSecondaryTextColor(context),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Summary
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isProfit
                  ? Colors.green.withValues(alpha: 0.1)
                  : Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isProfit
                    ? Colors.green.withValues(alpha: 0.3)
                    : Colors.red.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              children: [
                _SummaryRow(
                  label: 'Total Invested',
                  value: '₹${ctrl.totalInvested.toStringAsFixed(2)}',
                  color: Colors.red,
                ),
                const SizedBox(height: 12),
                _SummaryRow(
                  label: 'Total Received',
                  value: '₹${ctrl.totalReceived.toStringAsFixed(2)}',
                  color: Colors.green,
                ),
                const SizedBox(height: 12),
                Divider(color: AppStyles.getDividerColor(context)),
                const SizedBox(height: 12),
                _SummaryRow(
                  label: 'Gain/Loss',
                  value:
                      '${isProfit ? '+' : ''}₹${ctrl.gainLoss.toStringAsFixed(2)}',
                  color: isProfit ? Colors.green : Colors.red,
                  isBold: true,
                ),
                const SizedBox(height: 12),
                _SummaryRow(
                  label: 'Return %',
                  value:
                      '${isProfit ? '+' : ''}${ctrl.gainLossPercent.toStringAsFixed(2)}%',
                  color: isProfit ? Colors.green : Colors.red,
                  isBold: true,
                ),
                const SizedBox(height: 12),
                _SummaryRow(
                  label: 'Yield to Maturity (IRR)',
                  value:
                      '${(ctrl.calculatedYield ?? 0).toStringAsFixed(4)} / ${((ctrl.calculatedYield ?? 0) * 100).toStringAsFixed(2)}%',
                  color: const Color(0xFF00A6CC),
                  isBold: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool isBold;

  const _SummaryRow({
    required this.label,
    required this.value,
    required this.color,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isBold ? 13 : 12,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            color: AppStyles.getTextColor(context),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 13 : 12,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
