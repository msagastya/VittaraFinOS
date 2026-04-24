import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, LinearProgressIndicator;
import 'package:vittara_fin_os/logic/ai/habit_constructor.dart';
import 'package:vittara_fin_os/logic/ai/habit_weekly_checker.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';

/// T-106: Habit detail bottom sheet.
///
/// Shows: name, weekly progress bar, spend trend sparkline,
/// streak count, best week, and "Stop tracking" option.
class HabitDetailSheet extends StatelessWidget {
  final HabitWeeklyProgress progress;
  final VoidCallback? onStop;

  const HabitDetailSheet({
    super.key,
    required this.progress,
    this.onStop,
  });

  static Future<void> show(
    BuildContext context,
    HabitWeeklyProgress progress, {
    VoidCallback? onStop,
  }) {
    return showCupertinoModalPopup<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => HabitDetailSheet(progress: progress, onStop: onStop),
    );
  }

  @override
  Widget build(BuildContext context) {
    final h = progress.habit;
    final isDark = AppStyles.isDarkMode(context);
    final progressRatio =
        progress.weeklyTarget > 0 ? progress.actualCount / progress.weeklyTarget : 0.0;
    final progressColor = progressRatio >= 1.0
        ? AppStyles.accentGreen
        : progressRatio >= 0.5
            ? AppStyles.accentAmber
            : AppStyles.accentCoral;

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF0D0D0D)
              : CupertinoColors.systemBackground,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: progressColor.withValues(alpha: 0.25),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: 10, bottom: 4),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.15)
                      : Colors.black.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  Spacing.xl, Spacing.md, Spacing.xl, Spacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title + streak badge
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          h.title,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppStyles.getTextColor(context),
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: Spacing.sm),
                      if (progress.streakWeeks > 0)
                        _StreakBadge(weeks: progress.streakWeeks),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    h.category,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppStyles.getSecondaryTextColor(context),
                    ),
                  ),

                  const SizedBox(height: Spacing.xl),

                  // Weekly progress section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'This week',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppStyles.getSecondaryTextColor(context),
                        ),
                      ),
                      Text(
                        '${progress.actualCount}/${progress.weeklyTarget} days'
                        '  ·  ₹${_fmt(progress.actualSpend)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: progressColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Spacing.sm),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progressRatio.clamp(0.0, 1.0),
                      minHeight: 8,
                      backgroundColor: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.06),
                      valueColor: AlwaysStoppedAnimation(progressColor),
                    ),
                  ),

                  const SizedBox(height: Spacing.xl),

                  // Sparkline: weekly history
                  if (progress.weekHistory.isNotEmpty) ...[
                    Text(
                      'Weekly trend',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppStyles.getSecondaryTextColor(context),
                      ),
                    ),
                    const SizedBox(height: Spacing.sm),
                    _HabitSparkline(
                      history: [...progress.weekHistory, progress.actualCount],
                      target: progress.weeklyTarget,
                    ),
                    const SizedBox(height: Spacing.lg),
                  ],

                  // Stats row
                  Row(
                    children: [
                      _StatPill(
                        label: 'Streak',
                        value: '${progress.streakWeeks} wks',
                        color: AppStyles.aetherTeal,
                      ),
                      const SizedBox(width: Spacing.sm),
                      _StatPill(
                        label: 'Best week',
                        value: '${progress.bestWeek} days',
                        color: AppStyles.accentAmber,
                      ),
                      const SizedBox(width: Spacing.sm),
                      _StatPill(
                        label: 'Tracked since',
                        value: h.confirmedAt != null
                            ? '${h.confirmedAt!.day}/${h.confirmedAt!.month}'
                            : 'Now',
                        color: AppStyles.accentPurple,
                      ),
                    ],
                  ),

                  const SizedBox(height: Spacing.xl),

                  // Stop tracking button
                  SizedBox(
                    width: double.infinity,
                    child: CupertinoButton(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      color: AppStyles.accentCoral.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      onPressed: () {
                        Navigator.of(context).pop();
                        onStop?.call();
                      },
                      child: Text(
                        'Stop tracking this habit',
                        style: TextStyle(
                          fontSize: 15,
                          color: AppStyles.accentCoral,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _fmt(double v) {
    if (v >= 1000) return '₹${(v / 1000).toStringAsFixed(1)}K';
    return '₹${v.toInt()}';
  }
}

// ─── Streak badge ─────────────────────────────────────────────────────────────

class _StreakBadge extends StatelessWidget {
  final int weeks;
  const _StreakBadge({required this.weeks});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppStyles.accentAmber.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(Radii.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🔥', style: TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          Text(
            '$weeks wks',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppStyles.accentAmber,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Stat pill ────────────────────────────────────────────────────────────────

class _StatPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatPill({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: Spacing.sm, horizontal: Spacing.md),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: AppStyles.getSecondaryTextColor(context),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── T-106: Habit sparkline ───────────────────────────────────────────────────

class _HabitSparkline extends StatelessWidget {
  final List<int> history;
  final int target;

  const _HabitSparkline({required this.history, required this.target});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: CustomPaint(
        painter: _SparklinePainter(
          history: history,
          target: target,
          lineColor: AppStyles.aetherTeal,
          targetColor: AppStyles.getSecondaryTextColor(context)
              .withValues(alpha: 0.4),
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<int> history;
  final int target;
  final Color lineColor;
  final Color targetColor;

  const _SparklinePainter({
    required this.history,
    required this.target,
    required this.lineColor,
    required this.targetColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (history.length < 2) return;
    final maxVal = math.max(history.reduce(math.max), target).toDouble();
    if (maxVal == 0) return;

    // Target line
    final targetY = size.height - (target / maxVal * size.height);
    final targetPaint = Paint()
      ..color = targetColor
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(0, targetY), Offset(size.width, targetY), targetPaint);

    // Sparkline
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    for (int i = 0; i < history.length; i++) {
      final x = i / (history.length - 1) * size.width;
      final y = size.height - (history[i] / maxVal * size.height);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, linePaint);

    // Dot at current week
    final dotX = size.width;
    final dotY = size.height - (history.last / maxVal * size.height);
    canvas.drawCircle(Offset(dotX, dotY), 3.5, Paint()..color = lineColor);
  }

  @override
  bool shouldRepaint(_SparklinePainter old) => false;
}
