import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/accounts_controller.dart';
import 'package:vittara_fin_os/logic/account_model.dart';
import 'package:vittara_fin_os/logic/budgets_controller.dart';
import 'package:vittara_fin_os/logic/budget_model.dart';
import 'package:vittara_fin_os/logic/investments_controller.dart';
import 'package:vittara_fin_os/logic/investment_model.dart';
import 'package:vittara_fin_os/logic/transactions_controller.dart';
import 'package:vittara_fin_os/logic/transaction_model.dart';
import 'package:vittara_fin_os/ui/dashboard/base_dashboard_widget.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';

// ---------------------------------------------------------------------------
// Data model (public — reused by NetWorthWidget)
// ---------------------------------------------------------------------------

class HealthScoreData {
  final int savingsScore;
  final int budgetScore;
  final int diversityScore;
  final int debtScore;

  const HealthScoreData({
    required this.savingsScore,
    required this.budgetScore,
    required this.diversityScore,
    required this.debtScore,
  });

  int get total => savingsScore + budgetScore + diversityScore + debtScore;

  Color get bandColor {
    final t = total;
    if (t >= 80) return const Color(0xFF00C853);
    if (t >= 60) return const Color(0xFFFFD600);
    if (t >= 40) return const Color(0xFFFF6D00);
    return const Color(0xFFDD2C00);
  }

  String get bandLabel {
    final t = total;
    if (t >= 80) return 'Excellent';
    if (t >= 60) return 'Good';
    if (t >= 40) return 'Fair';
    return 'Needs Attention';
  }

  String get grade {
    final t = total;
    if (t >= 90) return 'A+';
    if (t >= 80) return 'A';
    if (t >= 70) return 'B+';
    if (t >= 60) return 'B';
    if (t >= 50) return 'C';
    if (t >= 40) return 'D';
    return 'F';
  }

  String get topRecommendation {
    final scores = <String, int>{
      'savings rate': savingsScore,
      'budget adherence': budgetScore,
      'investment diversity': diversityScore,
      'debt management': debtScore,
    };
    final weakest = scores.entries
        .reduce((a, b) => a.value < b.value ? a : b);
    switch (weakest.key) {
      case 'savings rate':
        return 'Save at least 20% of monthly income to boost your score.';
      case 'budget adherence':
        return 'Resolve exceeded budgets to improve your adherence score.';
      case 'investment diversity':
        return 'Add equity, FD, or gold to diversify your portfolio.';
      case 'debt management':
        return 'Keep EMIs below 40% of income to improve debt ratio.';
      default:
        return 'Track income and expenses consistently for better insights.';
    }
  }
}

// ---------------------------------------------------------------------------
// Scoring computation
// ---------------------------------------------------------------------------

HealthScoreData computeHealthScore({
  required List<Transaction> transactions,
  required List<Budget> budgets,
  required List<Investment> investments,
  required List<Account> accounts,
}) {
  final now = DateTime.now();
  final monthStart = DateTime(now.year, now.month, 1);
  double income = 0;
  double expenses = 0;
  for (final tx in transactions) {
    if (tx.dateTime.isBefore(monthStart)) continue;
    if (tx.type == TransactionType.income || tx.type == TransactionType.cashback) {
      income += tx.amount;
    } else if (tx.type == TransactionType.expense) {
      expenses += tx.amount;
    }
  }

  int savingsScore;
  if (income <= 0) {
    savingsScore = 0;
  } else {
    final rate = (income - expenses) / income * 100;
    if (rate >= 20) savingsScore = 25;
    else if (rate >= 10) savingsScore = 15;
    else if (rate >= 0) savingsScore = 8;
    else savingsScore = 0;
  }

  final activeBudgets = budgets.where((b) => b.isActive).toList();
  int budgetScore;
  if (activeBudgets.isEmpty) {
    budgetScore = 0;
  } else {
    final onTrack = activeBudgets.where((b) => b.status != BudgetStatus.exceeded).length;
    final ratio = onTrack / activeBudgets.length;
    if (ratio >= 1.0) budgetScore = 25;
    else if (ratio > 0.75) budgetScore = 15;
    else if (ratio > 0.50) budgetScore = 8;
    else budgetScore = 0;
  }

  final activeInvestments = investments.where((inv) => inv.metadata?['isWithdrawn'] != true).toList();
  final distinctTypes = activeInvestments.map((inv) => inv.type).toSet().length;
  int diversityScore;
  if (distinctTypes >= 4) diversityScore = 25;
  else if (distinctTypes == 3) diversityScore = 18;
  else if (distinctTypes == 2) diversityScore = 10;
  else if (distinctTypes == 1) diversityScore = 5;
  else diversityScore = 0;

  double totalAssets = 0;
  double totalDebt = 0;
  for (final acc in accounts) {
    if (acc.type == AccountType.credit || acc.type == AccountType.payLater) {
      totalDebt += acc.balance;
      totalAssets += acc.creditLimit ?? acc.balance;
    } else {
      totalAssets += acc.balance;
    }
  }
  for (final inv in investments) {
    final currentValue = (inv.metadata?['currentValue'] as num?)?.toDouble() ?? inv.amount;
    totalAssets += currentValue;
  }

  int debtScore;
  if (totalAssets <= 0) {
    debtScore = 25;
  } else {
    final ratio = totalDebt / totalAssets;
    if (ratio < 0.1) debtScore = 25;
    else if (ratio < 0.2) debtScore = 18;
    else if (ratio < 0.35) debtScore = 10;
    else if (ratio < 0.5) debtScore = 5;
    else debtScore = 0;
  }

  return HealthScoreData(
    savingsScore: savingsScore,
    budgetScore: budgetScore,
    diversityScore: diversityScore,
    debtScore: debtScore,
  );
}

// ---------------------------------------------------------------------------
// Arc painter — animated
// ---------------------------------------------------------------------------

class _ScoreArcPainter extends CustomPainter {
  final double fraction;
  final Color scoreColor;
  final Color trackColor;
  final double glowOpacity;

  const _ScoreArcPainter({
    required this.fraction,
    required this.scoreColor,
    required this.trackColor,
    this.glowOpacity = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = size.width * 0.085;
    final radius = (size.width - strokeWidth) / 2;
    final center = Offset(size.width / 2, size.height / 2);

    const startAngle = math.pi * 0.75;
    const sweepAngle = math.pi * 1.5;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final scorePaint = Paint()
      ..color = scoreColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(rect, startAngle, sweepAngle, false, trackPaint);

    if (fraction > 0) {
      canvas.drawArc(rect, startAngle, sweepAngle * fraction, false, scorePaint);

      // Glow dot at arc end
      if (glowOpacity > 0 && fraction > 0.01) {
        final endAngle = startAngle + sweepAngle * fraction;
        final dotX = center.dx + radius * math.cos(endAngle);
        final dotY = center.dy + radius * math.sin(endAngle);
        final glowPaint = Paint()
          ..color = scoreColor.withValues(alpha: glowOpacity * 0.6)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
        canvas.drawCircle(Offset(dotX, dotY), strokeWidth * 0.85, glowPaint);
        final dotPaint = Paint()
          ..color = Colors.white.withValues(alpha: glowOpacity * 0.9);
        canvas.drawCircle(Offset(dotX, dotY), strokeWidth * 0.35, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(_ScoreArcPainter old) =>
      old.fraction != fraction ||
      old.scoreColor != scoreColor ||
      old.trackColor != trackColor ||
      old.glowOpacity != glowOpacity;
}

// ---------------------------------------------------------------------------
// Animated sub-score bar
// ---------------------------------------------------------------------------

class _AnimatedSubScoreBar extends StatefulWidget {
  final String label;
  final int score;
  final int maxScore;
  final Color color;
  final Animation<double> animation;
  final String tip;

  const _AnimatedSubScoreBar({
    required this.label,
    required this.score,
    required this.maxScore,
    required this.color,
    required this.animation,
    required this.tip,
  });

  @override
  State<_AnimatedSubScoreBar> createState() => _AnimatedSubScoreBarState();
}

class _AnimatedSubScoreBarState extends State<_AnimatedSubScoreBar> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final targetFraction = widget.maxScore > 0
        ? (widget.score / widget.maxScore).clamp(0.0, 1.0)
        : 0.0;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final trackColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);

    return AnimatedBuilder(
      animation: widget.animation,
      builder: (context, _) {
        final fraction = targetFraction * widget.animation.value;
        return GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.only(bottom: Spacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          widget.label,
                          style: TextStyle(
                            fontSize: TypeScale.caption,
                            fontWeight: FontWeight.w500,
                            color: AppStyles.getSecondaryTextColor(context),
                          ),
                        ),
                        const SizedBox(width: 4),
                        AnimatedRotation(
                          turns: _expanded ? 0.25 : 0.0,
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            CupertinoIcons.chevron_right,
                            size: 9,
                            color: AppStyles.getSecondaryTextColor(context)
                                .withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${widget.score}/${widget.maxScore}',
                      style: TextStyle(
                        fontSize: TypeScale.caption,
                        fontWeight: FontWeight.w700,
                        color: widget.color,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Spacing.xxs + 1),
                ClipRRect(
                  borderRadius: BorderRadius.circular(Radii.full),
                  child: Stack(
                    children: [
                      Container(height: 5, color: trackColor),
                      FractionallySizedBox(
                        widthFactor: fraction,
                        child: Container(
                          height: 5,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [
                              widget.color.withValues(alpha: 0.7),
                              widget.color,
                            ]),
                            borderRadius: BorderRadius.circular(Radii.full),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  child: _expanded
                      ? Padding(
                          padding: const EdgeInsets.only(top: Spacing.xs),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: Spacing.md, vertical: Spacing.sm),
                            decoration: BoxDecoration(
                              color: widget.color.withValues(alpha: 0.07),
                              borderRadius: BorderRadius.circular(Radii.md),
                              border: Border.all(
                                  color: widget.color.withValues(alpha: 0.18)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(CupertinoIcons.info_circle_fill,
                                    size: 12,
                                    color:
                                        widget.color.withValues(alpha: 0.7)),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    widget.tip,
                                    style: TextStyle(
                                      fontSize: TypeScale.caption,
                                      color:
                                          AppStyles.getSecondaryTextColor(context),
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Animated body — StatefulWidget that drives all animations
// ---------------------------------------------------------------------------

class HealthScoreBody extends StatefulWidget {
  final HealthScoreData data;
  final bool isDark;

  const HealthScoreBody({required this.data, required this.isDark});

  @override
  State<HealthScoreBody> createState() => HealthScoreBodyState();
}

class HealthScoreBodyState extends State<HealthScoreBody>
    with TickerProviderStateMixin {
  late AnimationController _entryCtrl;
  late AnimationController _pulseCtrl;

  // Entry animations
  late Animation<double> _arcAnim;
  late Animation<double> _scoreCountAnim;
  late Animation<double> _bandFadeAnim;
  late Animation<double> _bar1Anim;
  late Animation<double> _bar2Anim;
  late Animation<double> _bar3Anim;
  late Animation<double> _bar4Anim;

  // Pulse animation for glow dot
  late Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();

    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    final easeOut = CurvedAnimation(
      parent: _entryCtrl,
      curve: Curves.easeOutCubic,
    );

    _arcAnim = CurvedAnimation(
      parent: _entryCtrl,
      curve: const Interval(0.0, 0.75, curve: Curves.easeOutCubic),
    );

    _scoreCountAnim = CurvedAnimation(
      parent: _entryCtrl,
      curve: const Interval(0.0, 0.75, curve: Curves.easeOutCubic),
    );

    _bandFadeAnim = CurvedAnimation(
      parent: _entryCtrl,
      curve: const Interval(0.3, 0.7, curve: Curves.easeOut),
    );

    _bar1Anim = CurvedAnimation(
      parent: _entryCtrl,
      curve: const Interval(0.35, 0.80, curve: Curves.easeOutCubic),
    );
    _bar2Anim = CurvedAnimation(
      parent: _entryCtrl,
      curve: const Interval(0.45, 0.88, curve: Curves.easeOutCubic),
    );
    _bar3Anim = CurvedAnimation(
      parent: _entryCtrl,
      curve: const Interval(0.55, 0.95, curve: Curves.easeOutCubic),
    );
    _bar4Anim = CurvedAnimation(
      parent: _entryCtrl,
      curve: const Interval(0.65, 1.00, curve: Curves.easeOutCubic),
    );

    _glowAnim = CurvedAnimation(
      parent: _pulseCtrl,
      curve: Curves.easeInOut,
    );

    // Ignore easeOut — defined but not used directly
    easeOut;

    _entryCtrl.forward();
  }

  @override
  void didUpdateWidget(HealthScoreBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-animate if score changed
    if (oldWidget.data.total != widget.data.total) {
      _entryCtrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final isDark = widget.isDark;
    final trackColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Gauge + score + band ──────────────────────────────────────────
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Arc gauge
            SizedBox(
              width: 90,
              height: 90,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedBuilder(
                    animation: Listenable.merge([_arcAnim, _glowAnim]),
                    builder: (_, __) => CustomPaint(
                      size: const Size(90, 90),
                      painter: _ScoreArcPainter(
                        fraction: data.total / 100.0 * _arcAnim.value,
                        scoreColor: data.bandColor,
                        trackColor: trackColor,
                        glowOpacity: _glowAnim.value,
                      ),
                    ),
                  ),
                  // Score count-up + "of 100"
                  AnimatedBuilder(
                    animation: _scoreCountAnim,
                    builder: (_, __) => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${(data.total * _scoreCountAnim.value).round()}',
                          style: TextStyle(
                            fontSize: TypeScale.title1,
                            fontWeight: FontWeight.w800,
                            color: data.bandColor,
                            height: 1.1,
                          ),
                        ),
                        Text(
                          data.grade,
                          style: TextStyle(
                            fontSize: TypeScale.caption,
                            fontWeight: FontWeight.w800,
                            color: data.bandColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: Spacing.md),

            // Band label + description
            Expanded(
              child: FadeTransition(
                opacity: _bandFadeAnim,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.15, 0),
                    end: Offset.zero,
                  ).animate(_bandFadeAnim),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Band chip
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: Spacing.sm, vertical: Spacing.xxs),
                        decoration: BoxDecoration(
                          color: data.bandColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(Radii.full),
                          border: Border.all(
                            color: data.bandColor.withValues(alpha: 0.3),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: data.bandColor,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: data.bandColor.withValues(alpha: 0.8),
                                    blurRadius: 4,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              data.bandLabel,
                              style: TextStyle(
                                fontSize: TypeScale.caption,
                                fontWeight: FontWeight.w700,
                                color: data.bandColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: Spacing.sm),
                      Text(
                        _bandDescription(data.total),
                        style: TextStyle(
                          fontSize: TypeScale.caption,
                          color: AppStyles.getSecondaryTextColor(context),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: Spacing.md),

        // ── Divider ────────────────────────────────────────────────────────
        Divider(
          height: 1,
          color: isDark
              ? Colors.white.withValues(alpha: 0.07)
              : Colors.black.withValues(alpha: 0.07),
        ),

        const SizedBox(height: Spacing.md),

        // ── Animated sub-score bars ────────────────────────────────────────
        _AnimatedSubScoreBar(
          label: 'Savings Rate',
          score: data.savingsScore,
          maxScore: 25,
          color: const Color(0xFF00C853),
          animation: _bar1Anim,
          tip: 'Based on income vs savings ratio. Aim to save 20%+ of monthly income to score full marks.',
        ),
        _AnimatedSubScoreBar(
          label: 'Budget Adherence',
          score: data.budgetScore,
          maxScore: 25,
          color: AppStyles.accentBlue,
          animation: _bar2Anim,
          tip: 'Based on staying within your budgets. Review and resolve exceeded budgets to improve this score.',
        ),
        _AnimatedSubScoreBar(
          label: 'Investment Diversity',
          score: data.diversityScore,
          maxScore: 25,
          color: AppStyles.accentTeal,
          animation: _bar3Anim,
          tip: 'Based on spread across asset classes. Adding equity, debt, gold, and FDs improves diversity.',
        ),
        _AnimatedSubScoreBar(
          label: 'Debt Ratio',
          score: data.debtScore,
          maxScore: 25,
          color: AppStyles.accentOrange,
          animation: _bar4Anim,
          tip: 'Based on debt-to-income ratio. Keep EMIs below 40% of monthly income for a healthy score.',
        ),
        if (data.total < 90) ...[
          const SizedBox(height: Spacing.md),
          FadeTransition(
            opacity: _bandFadeAnim,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.md, vertical: Spacing.sm),
              decoration: BoxDecoration(
                color: data.bandColor.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(Radii.md),
                border: Border.all(
                    color: data.bandColor.withValues(alpha: 0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(CupertinoIcons.lightbulb_fill,
                      size: 12,
                      color: data.bandColor.withValues(alpha: 0.8)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      data.topRecommendation,
                      style: TextStyle(
                        fontSize: TypeScale.caption,
                        color: AppStyles.getSecondaryTextColor(context),
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  String _bandDescription(int score) {
    if (score >= 80) return 'Your finances are in great shape. Keep it up!';
    if (score >= 60) return 'Good financial health with room to improve.';
    if (score >= 40) return 'Some areas need attention to stay on track.';
    return 'Focus on savings, budgets, and reducing debt.';
  }
}

// ---------------------------------------------------------------------------
// Main widget
// ---------------------------------------------------------------------------

class HealthScoreWidget extends BaseDashboardWidget {
  const HealthScoreWidget({
    required super.config,
    super.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) => buildContent(
        context,
        columnSpan: config.columnSpan,
        rowSpan: config.rowSpan,
        width: double.infinity,
        height: double.infinity,
      );

  @override
  Widget buildContent(
    BuildContext context, {
    required int columnSpan,
    required int rowSpan,
    required double width,
    required double height,
  }) {
    return RepaintBoundary(
      child: Consumer4<TransactionsController, BudgetsController,
          InvestmentsController, AccountsController>(
        builder: (context, txController, budgetsController,
            investmentsController, accountsController, child) {
          final data = computeHealthScore(
            transactions: txController.transactions,
            budgets: budgetsController.budgets,
            investments: investmentsController.investments,
            accounts: accountsController.accounts,
          );
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return HealthScoreBody(data: data, isDark: isDark);
        },
      ),
    );
  }
}
