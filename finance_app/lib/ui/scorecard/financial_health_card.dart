import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:vittara_fin_os/logic/ai/financial_health_score.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';

/// Full financial health scorecard with hexagonal spider chart.
/// Embed inside any screen or show as a modal page.
class FinancialHealthCard extends StatefulWidget {
  final FinancialHealthScore score;

  const FinancialHealthCard({required this.score, super.key});

  @override
  State<FinancialHealthCard> createState() => _FinancialHealthCardState();
}

class _FinancialHealthCardState extends State<FinancialHealthCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _anim;
  int? _expandedIndex;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _anim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final score = widget.score;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(Spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context, score),
          const SizedBox(height: Spacing.xxl),
          _buildSpiderChart(context, score),
          const SizedBox(height: Spacing.xxl),
          _buildDimensionList(context, score),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, FinancialHealthScore score) {
    final trendIcon = _trendIcon(score.overallTrend);
    final trendColor = _trendColor(score.overallTrend, context);

    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Financial Health',
              style: TextStyle(
                fontSize: 14,
                color: AppStyles.getSecondaryTextColor(context),
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  score.overallScore.toStringAsFixed(0),
                  style: TextStyle(
                    fontSize: 52,
                    fontWeight: FontWeight.bold,
                    color: AppStyles.getTextColor(context),
                    height: 1.0,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8, left: 4),
                  child: Text(
                    '/ 100',
                    style: TextStyle(
                      fontSize: 18,
                      color: AppStyles.getSecondaryTextColor(context),
                    ),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Icon(trendIcon, color: trendColor, size: 16),
                const SizedBox(width: 4),
                Text(
                  score.overallLabel,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: trendColor,
                  ),
                ),
              ],
            ),
          ],
        ),
        const Spacer(),
        Text(
          'Updated ${_formatDate(score.computedAt)}',
          style: TextStyle(
            fontSize: 11,
            color: AppStyles.getSecondaryTextColor(context),
          ),
        ),
      ],
    );
  }

  Widget _buildSpiderChart(BuildContext context, FinancialHealthScore score) {
    return Center(
      child: AnimatedBuilder(
        animation: _anim,
        builder: (context, _) {
          return SizedBox(
            width: 240,
            height: 240,
            child: CustomPaint(
              painter: _SpiderChartPainter(
                scores: score.dimensions.map((d) => d.score / 100.0).toList(),
                progress: _anim.value,
                accentColor: AppStyles.aetherTeal,
                gridColor: AppStyles.getSecondaryTextColor(context)
                    .withValues(alpha: 0.15),
                fillColor: AppStyles.aetherTeal.withValues(alpha: 0.15),
                labels: score.dimensions.map((d) => d.name.split(' ')[0]).toList(),
                labelColor: AppStyles.getSecondaryTextColor(context),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDimensionList(BuildContext context, FinancialHealthScore score) {
    return Column(
      children: score.dimensions.asMap().entries.map((entry) {
        final i = entry.key;
        final dim = entry.value;
        final isExpanded = _expandedIndex == i;
        return _buildDimensionTile(context, dim, i, isExpanded);
      }).toList(),
    );
  }

  Widget _buildDimensionTile(
    BuildContext context,
    HealthDimension dim,
    int index,
    bool isExpanded,
  ) {
    final color = _scoreColor(dim.score, context);
    return GestureDetector(
      onTap: () => setState(() {
        _expandedIndex = isExpanded ? null : index;
      }),
      child: Container(
        margin: const EdgeInsets.only(bottom: Spacing.sm),
        padding: const EdgeInsets.all(Spacing.md),
        decoration: BoxDecoration(
          color: AppStyles.getCardColor(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isExpanded
                ? color.withValues(alpha: 0.4)
                : AppStyles.getCardColor(context),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Score pill
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      dim.score.toStringAsFixed(0),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: color,
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
                        dim.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppStyles.getTextColor(context),
                        ),
                      ),
                      Row(
                        children: [
                          Icon(
                            _trendIcon(dim.trend),
                            size: 12,
                            color: _trendColor(dim.trend, context),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            _trendLabel(dim.trend),
                            style: TextStyle(
                              fontSize: 11,
                              color: _trendColor(dim.trend, context),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Mini score bar
                SizedBox(
                  width: 60,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: dim.score / 100,
                      minHeight: 6,
                      backgroundColor: color.withValues(alpha: 0.1),
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
                  ),
                ),
                const SizedBox(width: Spacing.sm),
                Icon(
                  isExpanded
                      ? CupertinoIcons.chevron_up
                      : CupertinoIcons.chevron_down,
                  size: 14,
                  color: AppStyles.getSecondaryTextColor(context),
                ),
              ],
            ),
            // Expanded action sentence
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: Spacing.md, left: 56),
                child: Text(
                  dim.actionSentence,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppStyles.getSecondaryTextColor(context),
                    height: 1.5,
                  ),
                ),
              ),
              crossFadeState: isExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 200),
            ),
          ],
        ),
      ),
    );
  }

  Color _scoreColor(double score, BuildContext context) {
    if (score >= 75) return AppStyles.gain(context);
    if (score >= 50) return const Color(0xFFFFB800);
    return AppStyles.loss(context);
  }

  IconData _trendIcon(ScoreTrend t) {
    switch (t) {
      case ScoreTrend.improving: return CupertinoIcons.arrow_up_right;
      case ScoreTrend.declining: return CupertinoIcons.arrow_down_right;
      case ScoreTrend.stable: return CupertinoIcons.arrow_right;
    }
  }

  Color _trendColor(ScoreTrend t, BuildContext context) {
    switch (t) {
      case ScoreTrend.improving: return AppStyles.gain(context);
      case ScoreTrend.declining: return AppStyles.loss(context);
      case ScoreTrend.stable: return AppStyles.getSecondaryTextColor(context);
    }
  }

  String _trendLabel(ScoreTrend t) {
    switch (t) {
      case ScoreTrend.improving: return 'Improving';
      case ScoreTrend.declining: return 'Declining';
      case ScoreTrend.stable: return 'Stable';
    }
  }

  String _formatDate(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${dt.day} ${months[dt.month - 1]}';
  }
}

/// Hexagonal spider chart painter.
class _SpiderChartPainter extends CustomPainter {
  final List<double> scores; // 0.0–1.0, must be length 6
  final double progress;
  final Color accentColor;
  final Color gridColor;
  final Color fillColor;
  final List<String> labels;
  final Color labelColor;

  _SpiderChartPainter({
    required this.scores,
    required this.progress,
    required this.accentColor,
    required this.gridColor,
    required this.fillColor,
    required this.labels,
    required this.labelColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 28;
    const sides = 6;
    const rings = 4;

    final gridPaint = Paint()
      ..color = gridColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // Draw grid rings
    for (int ring = 1; ring <= rings; ring++) {
      final r = radius * ring / rings;
      final path = Path();
      for (int i = 0; i < sides; i++) {
        final angle = (i * 2 * pi / sides) - pi / 2;
        final pt = Offset(center.dx + r * cos(angle), center.dy + r * sin(angle));
        i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
      }
      path.close();
      canvas.drawPath(path, gridPaint);
    }

    // Draw axis lines
    for (int i = 0; i < sides; i++) {
      final angle = (i * 2 * pi / sides) - pi / 2;
      final end = Offset(
        center.dx + radius * cos(angle),
        center.dy + radius * sin(angle),
      );
      canvas.drawLine(center, end, gridPaint);
    }

    // Draw filled polygon (animated)
    final dataPath = Path();
    for (int i = 0; i < sides; i++) {
      final angle = (i * 2 * pi / sides) - pi / 2;
      final score = (scores.length > i ? scores[i] : 0.5) * progress;
      final r = radius * score;
      final pt = Offset(center.dx + r * cos(angle), center.dy + r * sin(angle));
      i == 0 ? dataPath.moveTo(pt.dx, pt.dy) : dataPath.lineTo(pt.dx, pt.dy);
    }
    dataPath.close();
    canvas.drawPath(dataPath, fillPaint);
    canvas.drawPath(dataPath, strokePaint);

    // Draw score dots
    final dotPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.fill;
    for (int i = 0; i < sides; i++) {
      final angle = (i * 2 * pi / sides) - pi / 2;
      final score = (scores.length > i ? scores[i] : 0.5) * progress;
      final r = radius * score;
      final pt = Offset(center.dx + r * cos(angle), center.dy + r * sin(angle));
      canvas.drawCircle(pt, 4, dotPaint);
    }

    // Draw labels
    final textStyle = TextStyle(
      color: labelColor,
      fontSize: 10,
      fontWeight: FontWeight.w500,
    );
    for (int i = 0; i < sides && i < labels.length; i++) {
      final angle = (i * 2 * pi / sides) - pi / 2;
      final labelRadius = radius + 18;
      final pt = Offset(
        center.dx + labelRadius * cos(angle),
        center.dy + labelRadius * sin(angle),
      );
      final tp = TextPainter(
        text: TextSpan(text: labels[i], style: textStyle),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout(maxWidth: 56);
      tp.paint(
        canvas,
        Offset(pt.dx - tp.width / 2, pt.dy - tp.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(_SpiderChartPainter old) =>
      old.progress != progress || old.scores != scores;
}
