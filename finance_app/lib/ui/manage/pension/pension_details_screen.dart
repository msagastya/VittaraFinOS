import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/investment_model.dart';
import 'package:vittara_fin_os/logic/investments_controller.dart';
import 'package:vittara_fin_os/logic/pension_model.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/widgets/common_widgets.dart';
import 'package:vittara_fin_os/ui/widgets/toast_notification.dart';

class PensionDetailsScreen extends StatefulWidget {
  final Investment investment;

  const PensionDetailsScreen({super.key, required this.investment});

  @override
  State<PensionDetailsScreen> createState() => _PensionDetailsScreenState();
}

class _PensionDetailsScreenState extends State<PensionDetailsScreen> {
  late PensionScheme pension;

  @override
  void initState() {
    super.initState();
    final meta = widget.investment.metadata ?? {};
    pension = PensionScheme.fromMap(
        meta['pensionData'] as Map<String, dynamic>? ?? {});
  }

  @override
  Widget build(BuildContext context) {
    final investmentsCtrl =
        Provider.of<InvestmentsController>(context, listen: false);
    final isPositive = pension.gainLoss >= 0;

    return CupertinoPageScaffold(
      backgroundColor: AppStyles.getBackground(context),
      navigationBar: CupertinoNavigationBar(
        middle: Text(pension.getTypeLabel(),
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
                title: 'Account Information',
                children: [
                  _DetailRow('Scheme', pension.getTypeLabel()),
                  _DetailRow('Account Number', pension.accountNumber),
                ],
              ),
              const SizedBox(height: Spacing.xl),
              _DetailCard(
                title: 'Financial Summary',
                children: [
                  _DetailRow('Principal Contributed',
                      '₹${pension.principalContributed.toStringAsFixed(2)}'),
                  _DetailRow('Current Value',
                      '₹${pension.currentValue.toStringAsFixed(2)}',
                      isBold: true),
                  _DetailRow(
                    'Gain/Loss',
                    '${isPositive ? '+' : ''}₹${pension.gainLoss.toStringAsFixed(2)}',
                    isGainLoss: true,
                    isPositive: isPositive,
                  ),
                  _DetailRow(
                    'Return %',
                    '${isPositive ? '+' : ''}${pension.gainLossPercent.toStringAsFixed(2)}%',
                    isGainLoss: true,
                    isPositive: isPositive,
                    isBold: true,
                  ),
                ],
              ),
              if (pension.notes != null && pension.notes!.isNotEmpty) ...[
                const SizedBox(height: Spacing.xl),
                _DetailCard(
                  title: 'Notes',
                  children: [
                    _DetailRow('', pension.notes ?? ''),
                  ],
                ),
              ],
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: CupertinoButton.filled(
                  onPressed: () => _showEditSheet(context, investmentsCtrl),
                  child: const Text('Edit Account'),
                ),
              ),
              const SizedBox(height: Spacing.md),
              SizedBox(
                width: double.infinity,
                child: CupertinoButton(
                  color: CupertinoColors.systemRed.withValues(alpha: 0.1),
                  onPressed: () {
                    showCupertinoDialog(
                      context: context,
                      builder: (ctx) => CupertinoAlertDialog(
                        title: const Text('Delete Pension Account'),
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
                                toast.showSuccess('Pension account deleted!');
                                Navigator.pop(context);
                              }
                            },
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Text('Delete Account',
                      style: TextStyle(color: CupertinoColors.systemRed)),
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
    final valueCtrl =
        TextEditingController(text: pension.currentValue.toStringAsFixed(2));
    final notesCtrl = TextEditingController(text: pension.notes ?? '');

    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final isDark = AppStyles.isDarkMode(ctx);
          return Container(
            height: MediaQuery.of(ctx).size.height * 0.5,
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
                    'Edit ${pension.getTypeLabel()}',
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
                            final newValue = double.tryParse(valueCtrl.text) ??
                                pension.currentValue;
                            final newNotes = notesCtrl.text.trim().isEmpty
                                ? null
                                : notesCtrl.text.trim();
                            final updatedMap = pension.toMap();
                            updatedMap['currentValue'] = newValue;
                            updatedMap['notes'] = newNotes;
                            final updatedPension =
                                PensionScheme.fromMap(updatedMap);
                            final updatedMeta = Map<String, dynamic>.from(
                                widget.investment.metadata ?? {});
                            updatedMeta['pensionData'] = updatedPension.toMap();
                            final updatedInvestment =
                                widget.investment.copyWith(
                              amount: newValue,
                              metadata: updatedMeta,
                            );
                            await investmentsCtrl
                                .updateInvestment(updatedInvestment);
                            if (ctx.mounted) {
                              setState(() => pension = updatedPension);
                              Navigator.pop(ctx);
                              toast.showSuccess('Account updated');
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
          isPositive ? CupertinoColors.systemGreen : CupertinoColors.systemRed;
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
