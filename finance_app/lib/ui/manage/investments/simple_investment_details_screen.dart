import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/investment_model.dart';
import 'package:vittara_fin_os/logic/investments_controller.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/widgets/common_widgets.dart';
import 'package:vittara_fin_os/ui/widgets/toast_notification.dart';

/// Generic details screen for simple investments (forex, etc.)
/// that use the simpleEntryMode metadata structure.
class SimpleInvestmentDetailsScreen extends StatefulWidget {
  final Investment investment;

  const SimpleInvestmentDetailsScreen({super.key, required this.investment});

  @override
  State<SimpleInvestmentDetailsScreen> createState() =>
      _SimpleInvestmentDetailsScreenState();
}

class _SimpleInvestmentDetailsScreenState
    extends State<SimpleInvestmentDetailsScreen> {

  @override
  Widget build(BuildContext context) {
    // Always read fresh investment from controller — rebuilds whenever any investment changes
    final fresh = context.watch<InvestmentsController>().investments
        .firstWhere((i) => i.id == widget.investment.id,
            orElse: () => widget.investment);
    final investmentsCtrl = context.read<InvestmentsController>();

    final meta = fresh.metadata ?? {};
    final currentValue =
        (meta['currentValue'] as num?)?.toDouble() ?? fresh.amount;
    final investmentAmount =
        (meta['investmentAmount'] as num?)?.toDouble() ?? fresh.amount;
    final notes = meta['notes'] as String?;
    final reference = meta['reference'] as String?;
    final dateStr =
        meta['investmentDate'] as String? ?? meta['purchaseDate'] as String?;
    final investmentDate = dateStr != null
        ? DateTime.tryParse(dateStr) ?? DateTime.now()
        : DateTime.now();

    final gainLoss = currentValue - investmentAmount;
    final gainLossPercent =
        investmentAmount > 0 ? (gainLoss / investmentAmount) * 100 : 0.0;
    final isPositive = gainLoss >= 0;

    return CupertinoPageScaffold(
      backgroundColor: AppStyles.getBackground(context),
      navigationBar: AppStyles.isLandscape(context) ? null : CupertinoNavigationBar(
        middle: Text(fresh.name,
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
                title: 'Investment Information',
                children: [
                  _DetailRow('Name', fresh.name),
                  _DetailRow('Type', fresh.getTypeLabel()),
                  _DetailRow(
                    'Date',
                    '${investmentDate.day}/${investmentDate.month}/${investmentDate.year}',
                  ),
                  if (reference != null && reference.isNotEmpty)
                    _DetailRow('Reference', reference),
                ],
              ),
              const SizedBox(height: Spacing.xl),
              _DetailCard(
                title: 'Financial Summary',
                children: [
                  _DetailRow(
                      'Invested', '₹${investmentAmount.toStringAsFixed(2)}'),
                  _DetailRow(
                    'Current Value',
                    '₹${currentValue.toStringAsFixed(2)}',
                    isBold: true,
                  ),
                  _DetailRow(
                    'Gain/Loss',
                    '${isPositive ? '+' : ''}₹${gainLoss.toStringAsFixed(2)}',
                    isGainLoss: true,
                    isPositive: isPositive,
                  ),
                  _DetailRow(
                    'Return %',
                    '${isPositive ? '+' : ''}${gainLossPercent.toStringAsFixed(2)}%',
                    isGainLoss: true,
                    isPositive: isPositive,
                    isBold: true,
                  ),
                ],
              ),
              if (notes != null && notes.isNotEmpty) ...[
                const SizedBox(height: Spacing.xl),
                _DetailCard(
                  title: 'Notes',
                  children: [_DetailRow('', notes)],
                ),
              ],
              const SizedBox(height: Spacing.xl),
              _buildActivityLog(context),
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
                  color: AppStyles.loss(context).withValues(alpha: 0.1),
                  onPressed: () {
                    showCupertinoDialog(
                      context: context,
                      builder: (ctx) => CupertinoAlertDialog(
                        title: const Text('Delete Investment'),
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
                                  .deleteInvestment(fresh.id);
                              if (context.mounted) {
                                toast.showSuccess('Investment deleted!');
                                Navigator.pop(context);
                              }
                            },
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: Text('Delete Investment',
                      style: TextStyle(color: AppStyles.loss(context))),
                ),
              ),
              const SizedBox(height: Spacing.xl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActivityLog(BuildContext context) {
    final inv = context.read<InvestmentsController>().investments
        .firstWhere((i) => i.id == widget.investment.id, orElse: () => widget.investment);
    final activityLog = (inv.metadata?['activityLog'] as List?)
        ?.cast<Map<String, dynamic>>() ?? [];
    if (activityLog.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Activity',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: TypeScale.headline,
              color: AppStyles.getTextColor(context),
            )),
        const SizedBox(height: Spacing.lg),
        ...activityLog.reversed.map((entry) {
          final type = entry['type'] as String? ?? 'create';
          final amount = (entry['amount'] as num?)?.toDouble() ?? 0.0;
          final description = entry['description'] as String? ?? '';
          final accountName = entry['accountName'] as String? ?? '';
          final dateStr = entry['date'] as String?;
          final date = dateStr != null ? DateTime.tryParse(dateStr) : null;

          final isSell = type == 'sell' || type == 'decrease';
          final isDividend = type == 'dividend';
          final color = isDividend
              ? const Color(0xFFFFB800)
              : isSell ? AppStyles.gain(context) : CupertinoColors.systemIndigo;
          final icon = isDividend
              ? CupertinoIcons.money_dollar_circle_fill
              : isSell ? CupertinoIcons.arrow_up_circle_fill : CupertinoIcons.arrow_down_circle_fill;

          return Container(
            margin: const EdgeInsets.only(bottom: Spacing.md),
            padding: const EdgeInsets.all(Spacing.lg),
            decoration: BoxDecoration(
              color: AppStyles.getCardColor(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: CupertinoColors.systemGrey.withValues(alpha: 0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(Spacing.sm),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(Radii.sm),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: Spacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              description.isNotEmpty ? description : (isDividend ? 'Dividend' : isSell ? 'Reduced' : 'Invested'),
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: TypeScale.subhead,
                                color: AppStyles.getTextColor(context),
                              ),
                            ),
                          ),
                          Text(
                            '${isSell || isDividend ? '+' : '-'}₹${amount.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: TypeScale.subhead,
                              color: color,
                            ),
                          ),
                        ],
                      ),
                      if (date != null) ...[
                        const SizedBox(height: Spacing.xs),
                        Text(
                          '${date.day}/${date.month}/${date.year}',
                          style: TextStyle(
                            color: AppStyles.getSecondaryTextColor(context),
                            fontSize: TypeScale.footnote,
                          ),
                        ),
                      ],
                      if (accountName.isNotEmpty) ...[
                        const SizedBox(height: Spacing.xs),
                        Row(
                          children: [
                            Icon(CupertinoIcons.creditcard_fill,
                                size: 12,
                                color: AppStyles.getSecondaryTextColor(context)),
                            const SizedBox(width: 4),
                            Text(accountName,
                                style: TextStyle(
                                  color: AppStyles.getSecondaryTextColor(context),
                                  fontSize: TypeScale.footnote,
                                )),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  void _showEditSheet(
      BuildContext context, InvestmentsController investmentsCtrl) {
    final fresh = investmentsCtrl.investments
        .firstWhere((i) => i.id == widget.investment.id, orElse: () => widget.investment);
    final meta = fresh.metadata ?? {};
    final curVal = (meta['currentValue'] as num?)?.toDouble() ?? fresh.amount;
    final curNotes = meta['notes'] as String?;
    final valueCtrl = TextEditingController(text: curVal.toStringAsFixed(2));
    final notesCtrl = TextEditingController(text: curNotes ?? '');

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
                    'Edit ${fresh.name}',
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
                              label: 'Current Value (₹)',
                              controller: valueCtrl,
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
                            final newValue = double.tryParse(valueCtrl.text) ?? curVal;
                            final newNotes = notesCtrl.text.trim().isEmpty
                                ? null
                                : notesCtrl.text.trim();
                            final latestFresh = investmentsCtrl.investments
                                .firstWhere((i) => i.id == widget.investment.id, orElse: () => fresh);
                            final updatedMeta = Map<String, dynamic>.from(latestFresh.metadata ?? {});
                            updatedMeta['currentValue'] = newValue;
                            updatedMeta['notes'] = newNotes;
                            final updatedInvestment = latestFresh.copyWith(
                              amount: newValue,
                              metadata: updatedMeta,
                            );
                            await investmentsCtrl.updateInvestment(updatedInvestment);
                            if (ctx.mounted) {
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
      valueCtrl.dispose();
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
          isPositive ? AppStyles.gain(context) : AppStyles.loss(context);
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
