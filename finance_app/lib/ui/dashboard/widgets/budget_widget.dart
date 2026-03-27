import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/budgets_controller.dart';
import 'package:vittara_fin_os/ui/manage/budgets/budgets_screen.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/widgets/animations.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Budget Dashboard Widget (2×2) — radial gauge + top 3 category bars
// ─────────────────────────────────────────────────────────────────────────────

class BudgetDashboardWidget extends StatelessWidget {
  const BudgetDashboardWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<BudgetsController>(
      builder: (context, ctrl, _) {
        final activeBudgets = ctrl.activeBudgets;

        if (activeBudgets.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemOrange.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(CupertinoIcons.chart_pie,
                      size: 28, color: CupertinoColors.systemOrange),
                ),
                const SizedBox(height: Spacing.sm),
                Text(
                  'No budgets set',
                  style: TextStyle(
                    fontSize: TypeScale.subhead,
                    fontWeight: FontWeight.w600,
                    color: AppStyles.getTextColor(context),
                  ),
                ),
                const SizedBox(height: Spacing.xs),
                Text(
                  'Create a budget to track\nyour spending limits',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: TypeScale.caption,
                    color: AppStyles.getSecondaryTextColor(context),
                  ),
                ),
                const SizedBox(height: Spacing.md),
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(
                      horizontal: Spacing.lg, vertical: Spacing.xs),
                  color: CupertinoColors.systemOrange,
                  borderRadius: BorderRadius.circular(Radii.md),
                  onPressed: () => Navigator.of(context).push(
                    FadeScalePageRoute(page: const BudgetsScreen()),
                  ),
                  child: const Text(
                    'Create your first budget',
                    style: TextStyle(
                      fontSize: TypeScale.caption,
                      color: CupertinoColors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        // Overall utilization
        double totalLimit = 0;
        double totalSpent = 0;
        for (final b in activeBudgets) {
          totalLimit += b.limitAmount;
          totalSpent += b.spentAmount;
        }
        final overallPct =
            totalLimit > 0 ? (totalSpent / totalLimit).clamp(0.0, 1.5) : 0.0;

        // Burn rate
        final now = DateTime.now();
        final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
        final daysFraction = now.day / daysInMonth;
        final bool overspending = overallPct > daysFraction * 1.2;
        final bool onTrack = overallPct <= daysFraction * 1.05;
        final gaugeColor = overallPct > 1.0
            ? CupertinoColors.systemRed
            : overspending
                ? CupertinoColors.systemOrange
                : AppStyles.accentGreen;

        // Top 3 budgets by spend
        final top3 = [...activeBudgets]
          ..sort((a, b) => b.spentAmount.compareTo(a.spentAmount));
        final topBudgets = top3.take(3).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Radial gauge
                SizedBox(
                  width: 80,
                  height: 80,
                  child: CustomPaint(
                    painter: _ArcGaugePainter(
                      value: overallPct.clamp(0.0, 1.0),
                      color: gaugeColor,
                      trackColor: AppStyles.getDividerColor(context),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${(overallPct * 100).clamp(0, 999).toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontSize: TypeScale.footnote,
                              fontWeight: FontWeight.w700,
                              color: gaugeColor,
                              height: 1,
                            ),
                          ),
                          Text(
                            'used',
                            style: TextStyle(
                              fontSize: 9,
                              color: AppStyles.getSecondaryTextColor(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: Spacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${activeBudgets.length} Budget${activeBudgets.length == 1 ? '' : 's'}',
                        style: TextStyle(
                          fontSize: TypeScale.subhead,
                          fontWeight: FontWeight.w600,
                          color: AppStyles.getTextColor(context),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        onTrack && overallPct <= 1.0
                            ? 'Spending on track'
                            : overspending && overallPct <= 1.0
                                ? 'Spending faster than pace'
                                : overallPct > 1.0
                                    ? 'Budget exceeded'
                                    : 'Spending within pace',
                        style: TextStyle(
                          fontSize: TypeScale.caption,
                          color: gaugeColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _fmt(totalSpent) + ' / ' + _fmt(totalLimit),
                        style: TextStyle(
                          fontSize: TypeScale.caption,
                          color: AppStyles.getSecondaryTextColor(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: Spacing.md),
            // Top 3 category bars
            ...topBudgets.map((b) {
              final pct = b.limitAmount > 0
                  ? (b.spentAmount / b.limitAmount).clamp(0.0, 1.0)
                  : 0.0;
              final barColor = pct >= 1.0
                  ? CupertinoColors.systemRed
                  : pct >= 0.8
                      ? CupertinoColors.systemOrange
                      : AppStyles.accentGreen;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            b.name,
                            style: TextStyle(
                              fontSize: TypeScale.caption,
                              fontWeight: FontWeight.w500,
                              color: AppStyles.getTextColor(context),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${(pct * 100).toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: TypeScale.caption,
                            fontWeight: FontWeight.w600,
                            color: barColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 5,
                        backgroundColor:
                            barColor.withValues(alpha: 0.15),
                        valueColor: AlwaysStoppedAnimation<Color>(barColor),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        );
      },
    );
  }

  String _fmt(double v) {
    if (v >= 100000) return '₹${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '₹${(v / 1000).toStringAsFixed(1)}K';
    return '₹${v.toStringAsFixed(0)}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Arc gauge painter
// ─────────────────────────────────────────────────────────────────────────────

class _ArcGaugePainter extends CustomPainter {
  final double value; // 0.0–1.0
  final Color color;
  final Color trackColor;

  _ArcGaugePainter({
    required this.value,
    required this.color,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const startAngle = math.pi * 0.75;
    const sweepFull = math.pi * 1.5;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 6;
    const strokeWidth = 8.0;

    final trackPaint = Paint()
      ..color = trackColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final valuePaint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(rect, startAngle, sweepFull, false, trackPaint);
    if (value > 0) {
      canvas.drawArc(rect, startAngle, sweepFull * value, false, valuePaint);
    }
  }

  @override
  bool shouldRepaint(_ArcGaugePainter old) =>
      old.value != value || old.color != color;
}
