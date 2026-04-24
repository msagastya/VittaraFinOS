import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:vittara_fin_os/logic/ai/financial_health_score.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';

// ─── T-095: Health Score Dimension Bottom Sheet ────────────────────────────────

/// Shows detailed breakdown of one health score dimension.
/// Spring-in bottom sheet with:
/// - Dimension name + animated score fill arc
/// - "Why this score" (reasons list)
/// - "How to improve" (specific tip)
/// - T-097: Trend sparkline (last 6 month estimates from current score)
class HealthScoreDimensionSheet extends StatefulWidget {
  final HealthDimension dimension;
  const HealthScoreDimensionSheet({super.key, required this.dimension});

  static Future<void> show(BuildContext context, HealthDimension dimension) {
    return showCupertinoModalPopup<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => HealthScoreDimensionSheet(dimension: dimension),
    );
  }

  @override
  State<HealthScoreDimensionSheet> createState() =>
      _HealthScoreDimensionSheetState();
}

class _HealthScoreDimensionSheetState
    extends State<HealthScoreDimensionSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fillAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fillAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dim = widget.dimension;
    final isDark = AppStyles.isDarkMode(context);
    final scoreColor = _scoreColor(dim.score, context);

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0D0D0D) : CupertinoColors.systemBackground,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: scoreColor.withValues(alpha: 0.25),
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
                  Spacing.xl, Spacing.lg, Spacing.xl, Spacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header: arc + name
                  Row(
                    children: [
                      AnimatedBuilder(
                        animation: _fillAnim,
                        builder: (_, __) => CustomPaint(
                          size: const Size(72, 72),
                          painter: _ScoreArcPainter(
                            progress: _fillAnim.value * (dim.score / 100),
                            color: scoreColor,
                            score: dim.score,
                            isDark: isDark,
                          ),
                        ),
                      ),
                      const SizedBox(width: Spacing.lg),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              dim.name,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: AppStyles.getTextColor(context),
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              dim.description,
                              style: TextStyle(
                                fontSize: 13,
                                color: AppStyles.getSecondaryTextColor(context),
                              ),
                            ),
                            const SizedBox(height: 6),
                            _TrendBadge(trend: dim.trend),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: Spacing.xl),

                  // Why this score
                  Text(
                    'Why this score',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppStyles.getSecondaryTextColor(context),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: Spacing.sm),
                  ...dim.reasons.map((reason) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              margin: const EdgeInsets.only(top: 5, right: 8),
                              decoration: BoxDecoration(
                                color: scoreColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                reason,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppStyles.getTextColor(context),
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),

                  const SizedBox(height: Spacing.lg),

                  // How to improve
                  Text(
                    'How to improve',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppStyles.getSecondaryTextColor(context),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: Spacing.sm),
                  Container(
                    padding: const EdgeInsets.all(Spacing.md),
                    decoration: BoxDecoration(
                      color: scoreColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(CupertinoIcons.lightbulb_fill,
                            size: 16, color: scoreColor),
                        const SizedBox(width: Spacing.sm),
                        Expanded(
                          child: Text(
                            dim.improvementTip,
                            style: TextStyle(
                              fontSize: 14,
                              color: AppStyles.getTextColor(context),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: Spacing.lg),

                  // T-097: Trend sparkline
                  Text(
                    'Trend (estimated)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppStyles.getSecondaryTextColor(context),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: Spacing.sm),
                  _TrendSparkline(
                    currentScore: dim.score,
                    trend: dim.trend,
                    color: scoreColor,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _scoreColor(double score, BuildContext context) {
    if (score >= 75) return AppStyles.accentGreen;
    if (score >= 50) return AppStyles.accentAmber;
    return AppStyles.accentCoral;
  }
}

// ─── Score arc painter ────────────────────────────────────────────────────────

class _ScoreArcPainter extends CustomPainter {
  final double progress; // 0.0–1.0 (animated)
  final Color color;
  final double score;
  final bool isDark;

  const _ScoreArcPainter({
    required this.progress,
    required this.color,
    required this.score,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;
    const startAngle = -math.pi * 0.75;
    const sweepTotal = math.pi * 1.5;

    final trackPaint = Paint()
      ..color = isDark
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.black.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepTotal,
      false,
      trackPaint,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepTotal * progress,
      false,
      progressPaint,
    );

    // Score text
    final textPainter = TextPainter(
      text: TextSpan(
        text: score.toStringAsFixed(0),
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(center.dx - textPainter.width / 2,
          center.dy - textPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(_ScoreArcPainter old) => old.progress != progress;
}

// ─── T-097: Trend sparkline ───────────────────────────────────────────────────

class _TrendSparkline extends StatelessWidget {
  final double currentScore;
  final ScoreTrend trend;
  final Color color;

  const _TrendSparkline({
    required this.currentScore,
    required this.trend,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    // Estimate last 6 months based on trend
    final scores = _estimateHistory(currentScore, trend);
    final trendColor = trend == ScoreTrend.improving
        ? AppStyles.accentGreen
        : trend == ScoreTrend.declining
            ? AppStyles.accentCoral
            : const Color(0xFF8E8E93);

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: AppStyles.getCardColor(context),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          Expanded(
            child: CustomPaint(
              painter: _SparklinePainter(scores: scores, color: trendColor),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            trend == ScoreTrend.improving
                ? '↑ Improving'
                : trend == ScoreTrend.declining
                    ? '↓ Declining'
                    : '→ Stable',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: trendColor,
            ),
          ),
        ],
      ),
    );
  }

  List<double> _estimateHistory(double current, ScoreTrend trend) {
    // Estimate 6 monthly scores ending at current
    const n = 6;
    final delta = trend == ScoreTrend.improving
        ? -2.5
        : trend == ScoreTrend.declining
            ? 2.5
            : 0.0;
    final result = <double>[];
    for (int i = n - 1; i >= 0; i--) {
      result.add((current + delta * i + (i * i * 0.2 * (delta > 0 ? -1 : 1)))
          .clamp(0, 100));
    }
    return result;
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> scores;
  final Color color;

  const _SparklinePainter({required this.scores, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (scores.length < 2) return;
    final minS = scores.reduce(math.min);
    final maxS = scores.reduce(math.max);
    final range = (maxS - minS).clamp(10.0, double.infinity);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    for (int i = 0; i < scores.length; i++) {
      final x = i / (scores.length - 1) * size.width;
      final y = size.height - ((scores[i] - minS) / range * size.height);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);

    // Dot at current (last) value
    final dotX = size.width;
    final dotY = size.height -
        ((scores.last - minS) / range * size.height);
    canvas.drawCircle(
      Offset(dotX, dotY),
      3.5,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_SparklinePainter old) => false;
}

// ─── Trend badge ─────────────────────────────────────────────────────────────

class _TrendBadge extends StatelessWidget {
  final ScoreTrend trend;
  const _TrendBadge({required this.trend});

  @override
  Widget build(BuildContext context) {
    final color = trend == ScoreTrend.improving
        ? AppStyles.accentGreen
        : trend == ScoreTrend.declining
            ? AppStyles.accentCoral
            : const Color(0xFF8E8E93);
    final label = trend == ScoreTrend.improving
        ? 'Improving'
        : trend == ScoreTrend.declining
            ? 'Declining'
            : 'Stable';
    final icon = trend == ScoreTrend.improving
        ? CupertinoIcons.arrow_up_right
        : trend == ScoreTrend.declining
            ? CupertinoIcons.arrow_down_right
            : CupertinoIcons.minus;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(Radii.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
