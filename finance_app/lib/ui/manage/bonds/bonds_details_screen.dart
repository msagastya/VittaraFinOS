import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/bond_cashflow_model.dart';
import 'package:vittara_fin_os/logic/investment_model.dart';
import 'package:vittara_fin_os/logic/investments_controller.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/widgets/toast_notification.dart';

class BondsDetailsScreen extends StatefulWidget {
  final Investment investment;

  const BondsDetailsScreen({
    super.key,
    required this.investment,
  });

  @override
  State<BondsDetailsScreen> createState() => _BondsDetailsScreenState();
}

class _BondsDetailsScreenState extends State<BondsDetailsScreen> {
  @override
  Widget build(BuildContext context) {
    final investmentsController =
        Provider.of<InvestmentsController>(context, listen: false);
    final metadata = widget.investment.metadata ?? {};

    // Extract bond data from metadata
    final bondName = widget.investment.name;
    final bondType = metadata['bondType'] as String? ?? 'Unknown';
    final faceValue = (metadata['faceValue'] as num?)?.toDouble() ?? 0;
    final purchasePrice = (metadata['purchasePrice'] as num?)?.toDouble() ?? 0;
    final totalInvested =
        (metadata['totalInvested'] as num?)?.toDouble() ?? purchasePrice;
    final totalReceived = (metadata['totalReceived'] as num?)?.toDouble() ?? 0;
    final gainLoss = (metadata['gainLoss'] as num?)?.toDouble() ?? 0;
    final gainLossPercent =
        (metadata['gainLossPercent'] as num?)?.toDouble() ?? 0;
    final ytm = (metadata['yieldToMaturity'] as num?)?.toDouble() ?? 0;
    final paymentsPerYear = metadata['paymentsPerYear'] as int? ?? 1;
    final purchaseDate = metadata['purchaseDate'] != null
        ? DateTime.parse(metadata['purchaseDate'] as String)
        : DateTime.now();
    final maturityDate = metadata['maturityDate'] != null
        ? DateTime.parse(metadata['maturityDate'] as String)
        : DateTime.now();

    // Extract cash flows
    final List<BondCashFlow> cashFlows = [];
    if (metadata['cashFlows'] is List) {
      for (final cf in metadata['cashFlows'] as List) {
        if (cf is Map<String, dynamic>) {
          cashFlows.add(BondCashFlow(
            date: DateTime.parse(cf['date'] as String),
            amount: (cf['amount'] as num?)?.toDouble() ?? 0,
            description: cf['description'] as String? ?? '',
          ));
        }
      }
    }

    final isProfit = gainLoss >= 0;

    return CupertinoPageScaffold(
      backgroundColor: AppStyles.getBackground(context),
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          bondName,
          style: TextStyle(color: AppStyles.getTextColor(context)),
        ),
        backgroundColor: AppStyles.getBackground(context),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Bond Summary Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppStyles.getCardColor(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bondName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _DetailRow(
                      label: 'Bond Type',
                      value: bondType,
                    ),
                    const SizedBox(height: 8),
                    _DetailRow(
                      label: 'Face Value',
                      value: '₹${faceValue.toStringAsFixed(2)}',
                    ),
                    const SizedBox(height: 8),
                    _DetailRow(
                      label: 'Payment Frequency',
                      value: paymentsPerYear == 12
                          ? 'Monthly'
                          : paymentsPerYear == 2
                              ? 'Semi-Annual'
                              : 'Annual',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Dates Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppStyles.getCardColor(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Important Dates',
                      style: TextStyle(
                        color: AppStyles.getTextColor(context),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _DetailRow(
                      label: 'Purchase Date',
                      value:
                          '${purchaseDate.day}/${purchaseDate.month}/${purchaseDate.year}',
                    ),
                    const SizedBox(height: 8),
                    _DetailRow(
                      label: 'Maturity Date',
                      value:
                          '${maturityDate.day}/${maturityDate.month}/${maturityDate.year}',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Financial Summary
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Financial Summary',
                      style: TextStyle(
                        color: AppStyles.getTextColor(context),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _DetailRow(
                      label: 'Total Invested',
                      value: '₹${totalInvested.toStringAsFixed(2)}',
                      color: Colors.red,
                    ),
                    const SizedBox(height: 12),
                    _DetailRow(
                      label: 'Total to Receive',
                      value: '₹${totalReceived.toStringAsFixed(2)}',
                      color: Colors.green,
                    ),
                    const SizedBox(height: 12),
                    Divider(color: AppStyles.getDividerColor(context)),
                    const SizedBox(height: 12),
                    _DetailRow(
                      label: 'Gain/Loss',
                      value:
                          '${isProfit ? '+' : ''}₹${gainLoss.toStringAsFixed(2)}',
                      color: isProfit ? Colors.green : Colors.red,
                      isBold: true,
                    ),
                    const SizedBox(height: 8),
                    _DetailRow(
                      label: 'Return %',
                      value:
                          '${isProfit ? '+' : ''}${gainLossPercent.toStringAsFixed(2)}%',
                      color: isProfit ? Colors.green : Colors.red,
                      isBold: true,
                    ),
                    const SizedBox(height: 8),
                    _DetailRow(
                      label: 'Yield to Maturity (IRR)',
                      value:
                          '${ytm.toStringAsFixed(4)} / ${(ytm * 100).toStringAsFixed(2)}%',
                      color: const Color(0xFF00A6CC),
                      isBold: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Cash Flow Schedule
              if (cashFlows.isNotEmpty)
                Container(
                  decoration: BoxDecoration(
                    color: AppStyles.getCardColor(context),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: Colors.grey.withValues(alpha: 0.2)),
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
                      ...List.generate(cashFlows.length, (index) {
                        final cf = cashFlows[index];
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
                                        color: isNegative
                                            ? Colors.red
                                            : Colors.green,
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
                                        color: AppStyles.getSecondaryTextColor(
                                            context),
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
              const SizedBox(height: 30),
              // Action Buttons
              SizedBox(
                width: double.infinity,
                child: CupertinoButton.filled(
                  onPressed: () {
                    toast.showInfo('Edit functionality coming soon!');
                  },
                  child: const Text('Edit Bond Details'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: CupertinoButton(
                  color: Colors.red.withValues(alpha: 0.1),
                  onPressed: () async {
                    showCupertinoDialog(
                      context: context,
                      builder: (context) => CupertinoAlertDialog(
                        title: const Text('Delete Bond'),
                        content: const Text(
                          'Are you sure you want to delete this bond investment?',
                        ),
                        actions: [
                          CupertinoDialogAction(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                          CupertinoDialogAction(
                            isDestructiveAction: true,
                            onPressed: () async {
                              Navigator.pop(context);
                              await investmentsController
                                  .deleteInvestment(widget.investment.id);
                              if (context.mounted) {
                                toast.showSuccess(
                                  'Bond investment deleted successfully!',
                                );
                                Navigator.pop(context);
                              }
                            },
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Text(
                    'Delete Bond',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;
  final Color? color;

  const _DetailRow({
    required this.label,
    required this.value,
    this.isBold = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final valueColor = color ?? AppStyles.getTextColor(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppStyles.getSecondaryTextColor(context),
            fontSize: 13,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            fontSize: isBold ? 13 : 12,
          ),
        ),
      ],
    );
  }
}
