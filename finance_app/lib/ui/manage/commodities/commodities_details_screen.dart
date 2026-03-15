import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/investment_model.dart';
import 'package:vittara_fin_os/logic/investments_controller.dart';
import 'package:vittara_fin_os/logic/commodities_model.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/widgets/toast_notification.dart';
import 'package:vittara_fin_os/ui/widgets/common_widgets.dart';

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
          padding: const EdgeInsets.all(Spacing.xl),
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
              const SizedBox(height: Spacing.xl),
              _DetailCard(
                title: 'Quantity & Unit',
                children: [
                  _DetailRow('Quantity', '${commodity.quantity}'),
                  _DetailRow('Unit', commodity.unit),
                ],
              ),
              const SizedBox(height: Spacing.xl),
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
              const SizedBox(height: Spacing.xl),
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
                const SizedBox(height: Spacing.xl),
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
                  onPressed: () => _showEditSheet(context, investmentsCtrl),
                  child: const Text('Edit Investment'),
                ),
              ),
              const SizedBox(height: Spacing.md),
              SizedBox(
                width: double.infinity,
                child: CupertinoButton(
                  color: AppStyles.plasmaRed.withValues(alpha: 0.1),
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
                      style: TextStyle(color: AppStyles.plasmaRed)),
                ),
              ),
              const SizedBox(height: Spacing.xl),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditSheet(
      BuildContext context, InvestmentsController investmentsCtrl) {
    final priceCtrl =
        TextEditingController(text: commodity.currentPrice.toStringAsFixed(2));
    final quantityCtrl =
        TextEditingController(text: commodity.quantity.toStringAsFixed(4));
    final notesCtrl = TextEditingController(text: commodity.notes ?? '');

    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final isDark = AppStyles.isDarkMode(ctx);
          return Container(
            height: MediaQuery.of(ctx).size.height * 0.7,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C1C1E) : CupertinoColors.white,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  const ModalHandle(),
                  const SizedBox(height: 16),
                  Text('Edit ${commodity.name}',
                      style: TextStyle(
                          color: AppStyles.getTextColor(ctx),
                          fontSize: TypeScale.title2,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _EditField(
                              label: 'Current Price (per unit)',
                              controller: priceCtrl,
                              isDark: isDark,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true)),
                          const SizedBox(height: 12),
                          _EditField(
                              label: 'Quantity',
                              controller: quantityCtrl,
                              isDark: isDark,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true)),
                          const SizedBox(height: 12),
                          _EditField(
                              label: 'Notes',
                              controller: notesCtrl,
                              isDark: isDark,
                              maxLines: 3),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(children: [
                      Expanded(
                        child: CupertinoButton(
                          color: isDark
                              ? const Color(0xFF3A3A3C)
                              : CupertinoColors.systemGrey5,
                          onPressed: () => Navigator.pop(ctx),
                          child: Text('Cancel',
                              style: TextStyle(
                                  color: AppStyles.getTextColor(ctx))),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: CupertinoButton.filled(
                          onPressed: () async {
                            final newPrice = double.tryParse(priceCtrl.text) ??
                                commodity.currentPrice;
                            final newQty = double.tryParse(quantityCtrl.text) ??
                                commodity.quantity;
                            final updatedCommodity = Commodity(
                              id: commodity.id,
                              name: commodity.name,
                              type: commodity.type,
                              quantity: newQty,
                              unit: commodity.unit,
                              buyPrice: commodity.buyPrice,
                              currentPrice: newPrice,
                              position: commodity.position,
                              purchaseDate: commodity.purchaseDate,
                              exchange: commodity.exchange,
                              createdDate: commodity.createdDate,
                              notes: notesCtrl.text.trim().isEmpty
                                  ? null
                                  : notesCtrl.text.trim(),
                            );
                            final updatedMeta = Map<String, dynamic>.from(
                                widget.investment.metadata ?? {});
                            updatedMeta['commodityData'] =
                                updatedCommodity.toMap();
                            final updatedInvestment =
                                widget.investment.copyWith(
                              amount: updatedCommodity.currentValue,
                              metadata: updatedMeta,
                            );
                            await investmentsCtrl
                                .updateInvestment(updatedInvestment);
                            if (ctx.mounted) {
                              setState(() => commodity = updatedCommodity);
                              Navigator.pop(ctx);
                              toast.showSuccess('Investment updated');
                            }
                          },
                          child: const Text('Save'),
                        ),
                      ),
                    ]),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ).whenComplete(() {
      priceCtrl.dispose();
      quantityCtrl.dispose();
      notesCtrl.dispose();
    });
  }
}

class _EditField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool isDark;
  final TextInputType? keyboardType;
  final int maxLines;

  const _EditField({
    required this.label,
    required this.controller,
    required this.isDark,
    this.keyboardType,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                color: AppStyles.getSecondaryTextColor(context),
                fontSize: TypeScale.footnote,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        CupertinoTextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: TextStyle(color: AppStyles.getTextColor(context)),
          decoration: BoxDecoration(
            color:
                isDark ? const Color(0xFF2C2C2E) : CupertinoColors.systemGrey6,
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ],
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
      color =
          isPositive ? AppStyles.bioGreen : AppStyles.plasmaRed;
    }

    return Row(
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
    );
  }
}
