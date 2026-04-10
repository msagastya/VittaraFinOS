import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/cupertino.dart';
import 'package:vittara_fin_os/logic/transaction_model.dart';
import 'package:vittara_fin_os/logic/transactions_controller.dart';
import 'package:vittara_fin_os/ui/dashboard/quick_entry_sheet.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Cash Flow Dashboard Widget (4×2) — weekly income/expense bar chart
// ─────────────────────────────────────────────────────────────────────────────

class CashFlowDashboardWidget extends StatelessWidget {
  const CashFlowDashboardWidget({super.key});

  static String _fmt(double v) {
    if (v >= 100000) return '₹${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '₹${(v / 1000).toStringAsFixed(1)}K';
    return '₹${v.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TransactionsController>(
      builder: (context, txCtrl, _) {
        final now = DateTime.now();
        final monthStart = DateTime(now.year, now.month, 1);
        final monthEnd = DateTime(now.year, now.month + 1, 0);
        final monthLabel =
            '${_monthName(now.month)} ${now.year}';

        // Group by week-of-month (1–5)
        final incomeByWeek = List<double>.filled(5, 0);
        final expenseByWeek = List<double>.filled(5, 0);
        double totalIncome = 0;
        double totalExpense = 0;

        for (final tx in txCtrl.transactions) {
          if (tx.dateTime.isBefore(monthStart) ||
              tx.dateTime.isAfter(monthEnd)) continue;
          final weekIdx = ((tx.dateTime.day - 1) ~/ 7).clamp(0, 4);
          if (tx.type == TransactionType.income ||
              tx.type == TransactionType.cashback) {
            incomeByWeek[weekIdx] += tx.amount;
            totalIncome += tx.amount;
          } else if (tx.type == TransactionType.expense) {
            expenseByWeek[weekIdx] += tx.amount;
            totalExpense += tx.amount;
          }
        }

        final net = totalIncome - totalExpense;
        final maxVal = [
          ...incomeByWeek,
          ...expenseByWeek,
        ].fold<double>(1, (m, v) => v > m ? v : m);

        if (totalIncome == 0 && totalExpense == 0) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.bar_chart_rounded,
                    size: 32,
                    color: AppStyles.getSecondaryTextColor(context)),
                const SizedBox(height: Spacing.sm),
                Text(
                  'No data for $monthLabel',
                  style: TextStyle(
                    fontSize: TypeScale.subhead,
                    fontWeight: FontWeight.w600,
                    color: AppStyles.getTextColor(context),
                  ),
                ),
                const SizedBox(height: Spacing.xs),
                Text(
                  'Track income and expenses to see\nyour cash flow',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: TypeScale.caption,
                    color: AppStyles.getSecondaryTextColor(context),
                  ),
                ),
                const SizedBox(height: Spacing.sm),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => showQuickEntrySheet(context),
                  child: Text(
                    'Add transaction →',
                    style: TextStyle(
                      fontSize: TypeScale.caption,
                      color: AppStyles.aetherTeal,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Expanded(
                  child: Text(
                    monthLabel,
                    style: TextStyle(
                      fontSize: TypeScale.caption,
                      fontWeight: FontWeight.w600,
                      color: AppStyles.getSecondaryTextColor(context),
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                _Legend(
                  color: const Color(0xFF34C759),
                  label: 'In',
                ),
                const SizedBox(width: Spacing.sm),
                _Legend(
                  color: const Color(0xFFFF6B6B),
                  label: 'Out',
                ),
              ],
            ),
            const SizedBox(height: Spacing.md),

            // Bar chart — flexible height so it fills available card space
            Flexible(
              flex: 3,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(5, (i) {
                  final inH = maxVal > 0
                      ? (incomeByWeek[i] / maxVal * 72).clamp(2.0, 72.0)
                      : 2.0;
                  final exH = maxVal > 0
                      ? (expenseByWeek[i] / maxVal * 72).clamp(2.0, 72.0)
                      : 2.0;
                  final hasData =
                      incomeByWeek[i] > 0 || expenseByWeek[i] > 0;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _Bar(
                                height: hasData
                                    ? (incomeByWeek[i] > 0 ? inH : 2)
                                    : 2,
                                color: const Color(0xFF34C759),
                                faded: incomeByWeek[i] == 0,
                                delay: Duration(milliseconds: i * 70),
                              ),
                              const SizedBox(width: 3),
                              _Bar(
                                height: hasData
                                    ? (expenseByWeek[i] > 0 ? exH : 2)
                                    : 2,
                                color: const Color(0xFFFF6B6B),
                                faded: expenseByWeek[i] == 0,
                                delay: Duration(milliseconds: i * 70 + 30),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'W${i + 1}',
                            style: TextStyle(
                              fontSize: 9,
                              color: AppStyles.getSecondaryTextColor(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: Spacing.md),

            // Totals row
            Row(
              children: [
                Expanded(
                  child: _TotalChip(
                    label: 'Income',
                    value: _fmt(totalIncome),
                    color: const Color(0xFF34C759),
                  ),
                ),
                const SizedBox(width: Spacing.xs),
                Expanded(
                  child: _TotalChip(
                    label: 'Expense',
                    value: _fmt(totalExpense),
                    color: const Color(0xFFFF6B6B),
                  ),
                ),
                const SizedBox(width: Spacing.xs),
                Expanded(
                  child: _TotalChip(
                    label: 'Net',
                    value: _fmt(net.abs()),
                    color: net >= 0
                        ? AppStyles.aetherTeal
                        : const Color(0xFFFF6B6B),
                    prefix: net >= 0 ? '+' : '-',
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  String _monthName(int month) {
    const names = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return names[(month - 1).clamp(0, 11)];
  }
}

class _Bar extends StatefulWidget {
  final double height;
  final Color color;
  final bool faded;
  final Duration delay;

  const _Bar({
    required this.height,
    required this.color,
    this.faded = false,
    this.delay = Duration.zero,
  });

  @override
  State<_Bar> createState() => _BarState();
}

class _BarState extends State<_Bar> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    if (widget.delay == Duration.zero) {
      _ctrl.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _ctrl.forward();
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        final h = widget.faded
            ? widget.height
            : (widget.height * _anim.value).clamp(2.0, widget.height + 1);
        return Container(
          width: 10,
          height: h,
          decoration: BoxDecoration(
            color: widget.faded ? widget.color.withValues(alpha: 0.15) : widget.color,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
          ),
        );
      },
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;

  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: TypeScale.caption,
            color: AppStyles.getSecondaryTextColor(context),
          ),
        ),
      ],
    );
  }
}

class _TotalChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final String prefix;

  const _TotalChip({
    required this.label,
    required this.value,
    required this.color,
    this.prefix = '',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: AppStyles.getSecondaryTextColor(context),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$prefix$value',
            style: TextStyle(
              fontSize: TypeScale.caption,
              fontWeight: FontWeight.w700,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
