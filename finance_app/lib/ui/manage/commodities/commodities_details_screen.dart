import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/investment_model.dart';
import 'package:vittara_fin_os/logic/investments_controller.dart';
import 'package:vittara_fin_os/logic/commodities_model.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/widgets/toast_notification.dart';

class CommoditiesDetailsScreen extends StatefulWidget {
  final Investment investment;

  const CommoditiesDetailsScreen({super.key, required this.investment});

  @override
  State<CommoditiesDetailsScreen> createState() =>
      _CommoditiesDetailsScreenState();
}

class _CommoditiesDetailsScreenState extends State<CommoditiesDetailsScreen> {
  late Commodity commodity;

  @override
  void initState() {
    super.initState();
    final meta = widget.investment.metadata ?? {};
    commodity =
        Commodity.fromMap(meta['commodityData'] as Map<String, dynamic>? ?? {});
  }

  @override
  Widget build(BuildContext context) {
    final investmentsCtrl =
        Provider.of<InvestmentsController>(context, listen: false);
    final isPositive = commodity.gainLoss >= 0;

    return CupertinoPageScaffold(
      backgroundColor: AppStyles.getBackground(context),
      navigationBar: CupertinoNavigationBar(
        middle: Text(commodity.name,
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
                title: 'Commodity Information',
                children: [
                  _DetailRow('Name', commodity.name),
                  _DetailRow('Type', commodity.getTypeLabel()),
                  _DetailRow('Exchange', commodity.exchange),
                  _DetailRow('Position', commodity.position.name.toUpperCase()),
                ],
              ),
              const SizedBox(height: 20),
              _DetailCard(
                title: 'Quantity & Unit',
                children: [
                  _DetailRow('Quantity', '${commodity.quantity}'),
                  _DetailRow('Unit', commodity.unit),
                ],
              ),
              const SizedBox(height: 20),
              _DetailCard(
                title: 'Price Information',
                children: [
                  _DetailRow('Buy Price',
                      '₹${commodity.buyPrice.toStringAsFixed(2)}/${commodity.unit}'),
                  _DetailRow('Current Price',
                      '₹${commodity.currentPrice.toStringAsFixed(2)}/${commodity.unit}'),
                  _DetailRow('Purchase Date',
                      '${commodity.purchaseDate.day}/${commodity.purchaseDate.month}/${commodity.purchaseDate.year}'),
                ],
              ),
              const SizedBox(height: 20),
              _DetailCard(
                title: 'Financial Summary',
                children: [
                  _DetailRow('Total Cost',
                      '₹${commodity.totalCost.toStringAsFixed(2)}'),
                  _DetailRow('Current Value',
                      '₹${commodity.currentValue.toStringAsFixed(2)}',
                      isBold: true),
                  _DetailRow(
                    'Gain/Loss',
                    '${isPositive ? '+' : ''}₹${commodity.gainLoss.toStringAsFixed(2)}',
                    isGainLoss: true,
                    isPositive: isPositive,
                  ),
                  _DetailRow(
                    'Return %',
                    '${isPositive ? '+' : ''}${commodity.gainLossPercent.toStringAsFixed(2)}%',
                    isGainLoss: true,
                    isPositive: isPositive,
                    isBold: true,
                  ),
                ],
              ),
              if (commodity.notes != null && commodity.notes!.isNotEmpty) ...[
                const SizedBox(height: 20),
                _DetailCard(
                  title: 'Notes',
                  children: [
                    _DetailRow('', commodity.notes ?? ''),
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
                        title: const Text('Delete Commodity Investment'),
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
                                toast.showSuccess(
                                    'Commodity investment deleted!');
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
