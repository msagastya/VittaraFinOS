import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, InkWell;
import 'package:flutter/services.dart';
import 'package:vittara_fin_os/logic/ai/voice_controller.dart';
import 'package:vittara_fin_os/logic/ai/voice_fill_engine.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';

/// Confirmation card shown after voice parsing.
///
/// Each parsed field is shown as an individual tappable row.
/// Fields the engine is uncertain about are highlighted in amber with a ⚠ icon.
/// User can tap any field to type-correct it, or tap "Try Again" to re-speak.
class VoiceResultCard extends StatefulWidget {
  final VoiceResult result;
  final VoidCallback onConfirm;
  final VoidCallback onEdit;   // "Try Again" — re-opens voice overlay
  final VoidCallback? onRetry; // re-speaks from scratch

  const VoiceResultCard({
    required this.result,
    required this.onConfirm,
    required this.onEdit,
    this.onRetry,
    super.key,
  });

  @override
  State<VoiceResultCard> createState() => _VoiceResultCardState();
}

class _VoiceResultCardState extends State<VoiceResultCard> {
  late Map<String, dynamic> _fields;
  late VoiceIntent _intent;

  @override
  void initState() {
    super.initState();
    _fields = Map.from(widget.result.fields);
    _intent = widget.result.intent;
  }

  bool _isUncertain(String field) =>
      widget.result.uncertainFields.contains(field);

  @override
  Widget build(BuildContext context) {
    final isDark = AppStyles.isDarkMode(context);
    final intentColor = _intentColor(_intent);

    return Container(
      color: Colors.transparent,
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0D0D0D) : CupertinoColors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: intentColor.withValues(alpha: 0.3)),
            boxShadow: [
              BoxShadow(
                color: intentColor.withValues(alpha: 0.18),
                blurRadius: 28,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Header ──────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: intentColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(_intentIcon(_intent), color: intentColor, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _intentLabel(_intent),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: intentColor,
                        ),
                      ),
                    ),
                    // Uncertain badge
                    if (widget.result.uncertainFields.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF9500).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(CupertinoIcons.exclamationmark_triangle_fill,
                                size: 11, color: Color(0xFFFF9500)),
                            SizedBox(width: 4),
                            Text('Please verify',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFFFF9500),
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              // ── Field rows ───────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Column(
                  children: [
                    ..._buildFieldRows(context),
                    // Intent row (tap to switch expense/income/transfer)
                    _IntentSwitchRow(
                      intent: _intent,
                      onChanged: (v) => setState(() => _intent = v),
                    ),
                  ],
                ),
              ),

              // ── Action buttons ───────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                child: Column(
                  children: [
                    Row(
                      children: [
                        // Try Again
                        Expanded(
                          child: CupertinoButton(
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            color: CupertinoColors.systemGrey5,
                            borderRadius: BorderRadius.circular(12),
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              widget.onEdit();
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(CupertinoIcons.mic,
                                    size: 15,
                                    color: AppStyles.getTextColor(context)),
                                const SizedBox(width: 6),
                                Text('Try Again',
                                    style: TextStyle(
                                        fontSize: 14,
                                        color: AppStyles.getTextColor(context),
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Save
                        Expanded(
                          flex: 2,
                          child: CupertinoButton(
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            color: intentColor,
                            borderRadius: BorderRadius.circular(12),
                            onPressed: () {
                              HapticFeedback.mediumImpact();
                              // Push updated fields back before confirming
                              widget.result.fields.addAll(_fields);
                              widget.result.fields['_intent'] = _intent;
                              widget.onConfirm();
                            },
                            child: const Text('Save',
                                style: TextStyle(
                                    color: CupertinoColors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildFieldRows(BuildContext context) {
    final rows = <Widget>[];

    void row(String key, String label, String displayVal,
        {bool editable = true}) {
      final uncertain = _isUncertain(key);
      rows.add(_FieldRow(
        label: label,
        value: displayVal,
        isUncertain: uncertain,
        editable: editable,
        onEdit: editable
            ? () => _editField(context, key, label, displayVal)
            : null,
      ));
    }

    final amt = _fields['amount'] as double?;
    if (amt != null) {
      row('amount', 'Amount', '₹${_fmtAmt(amt)}');
    } else {
      // Missing amount — show prompt
      rows.add(_FieldRow(
        label: 'Amount',
        value: 'Tap to enter',
        isUncertain: true,
        editable: true,
        onEdit: () => _editField(context, 'amount', 'Amount', ''),
      ));
    }

    if (_fields['merchant'] != null) {
      row('merchant', 'For', _fields['merchant'] as String);
    }
    if (_fields['category'] != null) {
      row('category', 'Category', _fields['category'] as String);
    }
    if (_fields['account'] != null) {
      row('account', 'From', _fields['account'] as String);
    }
    if (_fields['toAccount'] != null) {
      row('toAccount', 'To', _fields['toAccount'] as String);
    }
    if (_fields['date'] != null) {
      final d = _fields['date'] as DateTime;
      row('date', 'Date', _fmtDate(d), editable: false);
    }
    if (_fields['investmentType'] != null) {
      row('investmentType', 'Type', _fields['investmentType'] as String);
    }

    return rows;
  }

  void _editField(BuildContext context, String key, String label, String current) {
    HapticFeedback.selectionClick();
    final ctrl = TextEditingController(text: current.replaceAll('₹', '').replaceAll(',', ''));
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: Text('Edit $label'),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: CupertinoTextField(
            controller: ctrl,
            autofocus: true,
            keyboardType: key == 'amount'
                ? const TextInputType.numberWithOptions(decimal: true)
                : TextInputType.text,
            placeholder: label,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              final val = ctrl.text.trim();
              if (val.isNotEmpty) {
                setState(() {
                  if (key == 'amount') {
                    _fields['amount'] = double.tryParse(val) ?? _fields['amount'];
                  } else {
                    _fields[key] = val;
                  }
                });
              }
              Navigator.pop(context);
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  String _fmtAmt(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(2)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(v == v.roundToDouble() ? 0 : 2);
  }

  String _fmtDate(DateTime d) {
    const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${d.day} ${m[d.month - 1]} ${d.year}';
  }

  Color _intentColor(VoiceIntent i) {
    switch (i) {
      case VoiceIntent.addExpense: return const Color(0xFFFF6B6B);
      case VoiceIntent.addIncome: return const Color(0xFF4CAF50);
      case VoiceIntent.addTransfer: return CupertinoColors.systemBlue;
      case VoiceIntent.addInvestment: return const Color(0xFF6C63FF);
      case VoiceIntent.setBudget: return const Color(0xFFFF9800);
      case VoiceIntent.setGoal: return const Color(0xFF00BCD4);
      default: return const Color(0xFF9E9E9E);
    }
  }

  IconData _intentIcon(VoiceIntent i) {
    switch (i) {
      case VoiceIntent.addExpense: return CupertinoIcons.arrow_down_circle_fill;
      case VoiceIntent.addIncome: return CupertinoIcons.arrow_up_circle_fill;
      case VoiceIntent.addTransfer: return CupertinoIcons.arrow_right_arrow_left;
      case VoiceIntent.addInvestment: return CupertinoIcons.chart_bar_square_fill;
      case VoiceIntent.setBudget: return CupertinoIcons.gauge;
      case VoiceIntent.setGoal: return CupertinoIcons.flag_fill;
      default: return CupertinoIcons.question_circle;
    }
  }

  String _intentLabel(VoiceIntent i) {
    switch (i) {
      case VoiceIntent.addExpense: return 'Expense';
      case VoiceIntent.addIncome: return 'Income';
      case VoiceIntent.addTransfer: return 'Transfer';
      case VoiceIntent.addInvestment: return 'Investment';
      case VoiceIntent.setBudget: return 'Set Budget';
      case VoiceIntent.setGoal: return 'New Goal';
      default: return 'Transaction';
    }
  }
}

// ── Individual field row ──────────────────────────────────────────────────────

class _FieldRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isUncertain;
  final bool editable;
  final VoidCallback? onEdit;

  const _FieldRow({
    required this.label,
    required this.value,
    required this.isUncertain,
    required this.editable,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppStyles.isDarkMode(context);
    final borderColor = isUncertain
        ? const Color(0xFFFF9500).withValues(alpha: 0.5)
        : (isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.06));
    final bgColor = isUncertain
        ? const Color(0xFFFF9500).withValues(alpha: isDark ? 0.08 : 0.05)
        : Colors.transparent;

    return InkWell(
      onTap: editable ? onEdit : null,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            if (isUncertain)
              const Padding(
                padding: EdgeInsets.only(right: 6),
                child: Icon(CupertinoIcons.exclamationmark_circle_fill,
                    size: 14, color: Color(0xFFFF9500)),
              ),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isUncertain
                    ? const Color(0xFFFF9500)
                    : AppStyles.getSecondaryTextColor(context),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppStyles.getTextColor(context),
                ),
              ),
            ),
            if (editable) ...[
              const SizedBox(width: 6),
              Icon(CupertinoIcons.pencil,
                  size: 13,
                  color: AppStyles.getSecondaryTextColor(context)
                      .withValues(alpha: 0.5)),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Intent switch row ─────────────────────────────────────────────────────────

class _IntentSwitchRow extends StatelessWidget {
  final VoiceIntent intent;
  final ValueChanged<VoiceIntent> onChanged;

  const _IntentSwitchRow({required this.intent, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const options = [
      (VoiceIntent.addExpense, 'Expense', Color(0xFFFF6B6B)),
      (VoiceIntent.addIncome, 'Income', Color(0xFF4CAF50)),
      (VoiceIntent.addTransfer, 'Transfer', CupertinoColors.systemBlue),
    ];

    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 2),
      child: Row(
        children: [
          Text('Type:',
              style: TextStyle(
                  fontSize: 12,
                  color: AppStyles.getSecondaryTextColor(context))),
          const SizedBox(width: 8),
          ...options.map((opt) {
            final selected = intent == opt.$1;
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onChanged(opt.$1);
              },
              child: Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: selected
                      ? opt.$3.withValues(alpha: 0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: selected
                        ? opt.$3
                        : AppStyles.getSecondaryTextColor(context)
                            .withValues(alpha: 0.2),
                  ),
                ),
                child: Text(
                  opt.$2,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? opt.$3 : AppStyles.getSecondaryTextColor(context),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
