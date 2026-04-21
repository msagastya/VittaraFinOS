import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:vittara_fin_os/logic/ai/voice_controller.dart';
import 'package:vittara_fin_os/logic/ai/voice_fill_engine.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';

/// Shows the parsed voice intent as a card for user confirmation before saving.
class VoiceResultCard extends StatelessWidget {
  final VoiceResult result;
  final VoidCallback onConfirm;
  final VoidCallback onEdit;

  const VoiceResultCard({
    required this.result,
    required this.onConfirm,
    required this.onEdit,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          decoration: BoxDecoration(
            color: AppStyles.getCardColor(context),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: _intentColor(result.intent).withValues(alpha: 0.3),
            ),
            boxShadow: [
              BoxShadow(
                color: _intentColor(result.intent).withValues(alpha: 0.2),
                blurRadius: 28,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(Spacing.xxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _intentColor(result.intent).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _intentIcon(result.intent),
                        color: _intentColor(result.intent),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: Spacing.md),
                    Text(
                      _intentLabel(result.intent),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _intentColor(result.intent),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Spacing.lg),

                // Confirmation summary
                Text(
                  result.confirmationText.replaceAll(' Confirm?', ''),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppStyles.getTextColor(context),
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: Spacing.xl),

                // Fields summary chips
                Wrap(
                  spacing: Spacing.sm,
                  runSpacing: Spacing.sm,
                  children: _buildFieldChips(context),
                ),
                const SizedBox(height: Spacing.xxl),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: CupertinoButton(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        color: CupertinoColors.systemGrey5,
                        borderRadius: BorderRadius.circular(12),
                        onPressed: onEdit,
                        child: Text(
                          'Edit',
                          style: TextStyle(
                            color: AppStyles.getTextColor(context),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: Spacing.md),
                    Expanded(
                      flex: 2,
                      child: CupertinoButton(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        color: _intentColor(result.intent),
                        borderRadius: BorderRadius.circular(12),
                        onPressed: onConfirm,
                        child: const Text(
                          'Save',
                          style: TextStyle(
                            color: CupertinoColors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildFieldChips(BuildContext context) {
    final chips = <Widget>[];
    final fields = result.fields;

    void chip(String label, String value) {
      chips.add(_FieldChip(label: label, value: value, context: context));
    }

    if (fields['amount'] != null) {
      chip('Amount', '₹${_fmtAmt((fields['amount'] as num).toDouble())}');
    }
    if (fields['account'] != null) chip('From', fields['account'] as String);
    if (fields['toAccount'] != null) chip('To', fields['toAccount'] as String);
    if (fields['merchant'] != null) chip('Merchant', fields['merchant'] as String);
    if (fields['category'] != null) chip('Category', fields['category'] as String);
    if (fields['date'] != null) {
      final d = fields['date'] as DateTime;
      chip('Date', '${d.day}/${d.month}/${d.year}');
    }
    if (fields['investmentType'] != null) chip('Type', fields['investmentType'] as String);
    if (fields['units'] != null) chip('Units', '${(fields['units'] as num).toInt()}');

    return chips;
  }

  String _fmtAmt(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
    return v.toInt().toString();
  }

  Color _intentColor(VoiceIntent intent) {
    switch (intent) {
      case VoiceIntent.addExpense: return const Color(0xFFFF6B6B);
      case VoiceIntent.addIncome: return const Color(0xFF4CAF50);
      case VoiceIntent.addTransfer: return CupertinoColors.systemBlue;
      case VoiceIntent.addInvestment: return const Color(0xFF6C63FF);
      case VoiceIntent.setBudget: return const Color(0xFFFF9800);
      case VoiceIntent.setGoal: return const Color(0xFF00BCD4);
      case VoiceIntent.navigate: return const Color(0xFF9E9E9E);
      default: return const Color(0xFF9E9E9E);
    }
  }

  IconData _intentIcon(VoiceIntent intent) {
    switch (intent) {
      case VoiceIntent.addExpense: return CupertinoIcons.arrow_down_circle_fill;
      case VoiceIntent.addIncome: return CupertinoIcons.arrow_up_circle_fill;
      case VoiceIntent.addTransfer: return CupertinoIcons.arrow_right_arrow_left;
      case VoiceIntent.addInvestment: return CupertinoIcons.chart_bar_square_fill;
      case VoiceIntent.setBudget: return CupertinoIcons.gauge;
      case VoiceIntent.setGoal: return CupertinoIcons.flag_fill;
      case VoiceIntent.navigate: return CupertinoIcons.arrow_right;
      default: return CupertinoIcons.question_circle;
    }
  }

  String _intentLabel(VoiceIntent intent) {
    switch (intent) {
      case VoiceIntent.addExpense: return 'Expense';
      case VoiceIntent.addIncome: return 'Income';
      case VoiceIntent.addTransfer: return 'Transfer';
      case VoiceIntent.addInvestment: return 'Investment';
      case VoiceIntent.setBudget: return 'Set Budget';
      case VoiceIntent.setGoal: return 'New Goal';
      case VoiceIntent.query: return 'Query';
      case VoiceIntent.queryBalance: return 'Balance Query';
      case VoiceIntent.queryGoal: return 'Goal Query';
      case VoiceIntent.navigate: return 'Navigate';
      case VoiceIntent.unknown: return 'Unknown';
    }
  }
}

class _FieldChip extends StatelessWidget {
  final String label;
  final String value;
  final BuildContext context;

  const _FieldChip({
    required this.label,
    required this.value,
    required this.context,
  });

  @override
  Widget build(BuildContext ctx) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppStyles.getSecondaryTextColor(ctx).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 12,
              color: AppStyles.getSecondaryTextColor(ctx),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppStyles.getTextColor(ctx),
            ),
          ),
        ],
      ),
    );
  }
}
