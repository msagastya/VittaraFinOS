import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/investment_model.dart';
import 'package:vittara_fin_os/logic/investments_controller.dart';
import 'package:vittara_fin_os/logic/fo_model.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/widgets/toast_notification.dart';

class FODetailsScreen extends StatefulWidget {
  final Investment investment;

  const FODetailsScreen({super.key, required this.investment});

  @override
  State<FODetailsScreen> createState() => _FODetailsScreenState();
}

class _FODetailsScreenState extends State<FODetailsScreen> {
  late FuturesOptions fo;

  @override
  void initState() {
    super.initState();
    final meta = widget.investment.metadata ?? {};
    fo = FuturesOptions.fromMap(meta['foData'] as Map<String, dynamic>? ?? {});
  }

  @override
  Widget build(BuildContext context) {
    final investmentsCtrl =
        Provider.of<InvestmentsController>(context, listen: false);
    final isPositive = fo.gainLoss >= 0;

    return CupertinoPageScaffold(
      backgroundColor: AppStyles.getBackground(context),
      navigationBar: CupertinoNavigationBar(
        middle: Text(fo.name,
            style: TextStyle(color: AppStyles.getTextColor(context))),
        backgroundColor: AppStyles.getBackground(context),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DetailCard(
                title: 'Contract Information',
                children: [
                  _DetailRow('Symbol', fo.symbol),
                  _DetailRow('Type', fo.getTypeLabel()),
                  _DetailRow('Entry Date',
                      '${fo.entryDate.day}/${fo.entryDate.month}/${fo.entryDate.year}'),
                  _DetailRow('Expiry Date',
                      '${fo.expiryDate.day}/${fo.expiryDate.month}/${fo.expiryDate.year}'),
                  _DetailRow('Days to Expiry', '${fo.daysToExpiry} days'),
                ],
              ),
              const SizedBox(height: 20),
              _DetailCard(
                title: 'Pricing & Quantity',
                children: [
                  _DetailRow('Quantity', fo.quantity.toString()),
                  _DetailRow(
                      'Entry Price', '₹${fo.entryPrice.toStringAsFixed(2)}'),
                  _DetailRow('Current Price',
                      '₹${fo.currentPrice.toStringAsFixed(2)}'),
                  if (fo.strikePrice != null)
                    _DetailRow('Strike Price',
                        '₹${fo.strikePrice!.toStringAsFixed(2)}'),
                ],
              ),
              const SizedBox(height: 20),
              _DetailCard(
                title: 'Financial Summary',
                children: [
                  _DetailRow(
                      'Total Cost', '₹${fo.totalCost.toStringAsFixed(2)}'),
                  _DetailRow(
                      'Current Value', '₹${fo.currentValue.toStringAsFixed(2)}',
                      isBold: true),
                  _DetailRow(
                    'Unrealized P&L',
                    '${isPositive ? '+' : ''}₹${fo.gainLoss.toStringAsFixed(2)}',
                    isGainLoss: true,
                    isPositive: isPositive,
                  ),
                  _DetailRow(
                    'Return %',
                    '${isPositive ? '+' : ''}${fo.gainLossPercent.toStringAsFixed(2)}%',
                    isGainLoss: true,
                    isPositive: isPositive,
                    isBold: true,
                  ),
                ],
              ),
              if (fo.greeks != null) ...[
                const SizedBox(height: 20),
                _DetailCard(
                  title: 'Greeks',
                  children: [
                    _DetailRow('Delta', fo.greeks!.delta.toStringAsFixed(4)),
                    _DetailRow('Gamma', fo.greeks!.gamma.toStringAsFixed(6)),
                    _DetailRow('Theta', fo.greeks!.theta.toStringAsFixed(4)),
                    _DetailRow('Vega', fo.greeks!.vega.toStringAsFixed(4)),
                    _DetailRow('Rho', fo.greeks!.rho.toStringAsFixed(4)),
                  ],
                ),
              ],
              if (fo.notes != null && fo.notes!.isNotEmpty) ...[
                const SizedBox(height: 20),
                _DetailCard(
                  title: 'Notes',
                  children: [
                    _DetailRow('', fo.notes ?? ''),
                  ],
                ),
              ],
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: CupertinoButton.filled(
                  onPressed: () {
                    toast.showInfo('Edit functionality coming soon!');
                  },
                  child: const Text('Edit Investment'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: CupertinoButton(
                  color: CupertinoColors.systemRed.withValues(alpha: 0.1),
                  onPressed: () {
                    showCupertinoDialog(
                      context: context,
                      builder: (ctx) => CupertinoAlertDialog(
                        title: const Text('Delete F&O Investment'),
                        content: const Text('Are you sure?'),
                        actions: [
                          CupertinoDialogAction(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancel'),
                          ),
                          CupertinoDialogAction(
                            isDestructiveAction: true,
                            onPressed: () async {
                              Navigator.pop(ctx);
                              await investmentsCtrl
                                  .deleteInvestment(widget.investment.id);
                              if (context.mounted) {
                                toast.showSuccess('F&O investment deleted!');
                                Navigator.pop(context);
                              }
                            },
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Text('Delete Investment',
                      style: TextStyle(color: CupertinoColors.systemRed)),
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

class _DetailCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _DetailCard({required this.title, required this.children});

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 16),
          ...List.generate(
            children.length,
            (i) => Column(
              children: [
                children[i],
                if (i < children.length - 1) const SizedBox(height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;
  final bool isGainLoss;
  final bool isPositive;

  const _DetailRow(
    this.label,
    this.value, {
    this.isBold = false,
    this.isGainLoss = false,
    this.isPositive = true,
  });

  @override
  Widget build(BuildContext context) {
    Color? color;
    if (isGainLoss) {
      color = isPositive ? CupertinoColors.systemGreen : CupertinoColors.systemRed;
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
