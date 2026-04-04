import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/investment_model.dart';
import 'package:vittara_fin_os/logic/investments_controller.dart';
import 'package:vittara_fin_os/logic/fo_model.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/widgets/common_widgets.dart';
import 'package:vittara_fin_os/ui/widgets/toast_notification.dart';

class FODetailsScreen extends StatefulWidget {
  final Investment investment;

  const FODetailsScreen({super.key, required this.investment});

  @override
  State<FODetailsScreen> createState() => _FODetailsScreenState();
}

class _FODetailsScreenState extends State<FODetailsScreen> {
  late Investment _investment;
  late FuturesOptions fo;

  @override
  void initState() {
    super.initState();
    _investment = widget.investment;
    final meta = investment.metadata ?? {};
    fo = FuturesOptions.fromMap(meta['foData'] as Map<String, dynamic>? ?? {});
  }

  Investment get investment => _investment;

  @override
  Widget build(BuildContext context) {
    // Keep investment in sync with controller for real-time updates
    _investment = context.watch<InvestmentsController>().investments
        .firstWhere((i) => i.id == investment.id, orElse: () => _investment);

    final investmentsCtrl =
        Provider.of<InvestmentsController>(context, listen: false);
    final isPositive = fo.gainLoss >= 0;

    return CupertinoPageScaffold(
      backgroundColor: AppStyles.getBackground(context),
      navigationBar: AppStyles.isLandscape(context) ? null : CupertinoNavigationBar(
        previousPageTitle: 'Back',
        middle: Text(fo.name,
            style: TextStyle(color: AppStyles.getTextColor(context))),
        backgroundColor: AppStyles.getBackground(context),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.back),
          onPressed: () => Navigator.pop(context),
        ),
        border: null,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Spacing.xl),
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
              const SizedBox(height: Spacing.xl),
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
              const SizedBox(height: Spacing.xl),
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
                const SizedBox(height: Spacing.xl),
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
                const SizedBox(height: Spacing.xl),
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
                                  .deleteInvestment(_investment.id);
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
        TextEditingController(text: fo.currentPrice.toStringAsFixed(2));
    final quantityCtrl = TextEditingController(text: fo.quantity.toString());
    final notesCtrl = TextEditingController(text: fo.notes ?? '');

    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final isDark = AppStyles.isDarkMode(ctx);
          return Container(
            height: AppStyles.sheetMaxHeight(ctx),
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
                  Text(
                    'Edit ${fo.name}',
                    style: TextStyle(
                        color: AppStyles.getTextColor(ctx),
                        fontSize: TypeScale.title2,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _EditField(
                              label: 'Current Price (₹)',
                              controller: priceCtrl,
                              isDark: isDark,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true)),
                          const SizedBox(height: 12),
                          _EditField(
                              label: 'Quantity (lots)',
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
                                fo.currentPrice;
                            final newQty = double.tryParse(quantityCtrl.text) ??
                                fo.quantity;
                            final newNotes = notesCtrl.text.trim().isEmpty
                                ? null
                                : notesCtrl.text.trim();
                            final updatedMap = fo.toMap();
                            updatedMap['currentPrice'] = newPrice;
                            updatedMap['quantity'] = newQty;
                            updatedMap['notes'] = newNotes;
                            final updatedFo =
                                FuturesOptions.fromMap(updatedMap);
                            final updatedMeta = Map<String, dynamic>.from(
                                _investment.metadata ?? {});
                            updatedMeta['foData'] = updatedFo.toMap();
                            final updatedInvestment =
                                _investment.copyWith(
                              amount: updatedFo.currentValue,
                              metadata: updatedMeta,
                            );
                            await investmentsCtrl
                                .updateInvestment(updatedInvestment);
                            if (ctx.mounted) {
                              setState(() => fo = updatedFo);
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
              style: const TextStyle(
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
