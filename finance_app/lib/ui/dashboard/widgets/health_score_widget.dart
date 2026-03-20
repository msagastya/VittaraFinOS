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
// Data model for computed health score
// ---------------------------------------------------------------------------

class _HealthScoreData {
  final int savingsScore; // 0–25
  final int budgetScore; // 0–25
  final int diversityScore; // 0–25
  final int debtScore; // 0–25

  const _HealthScoreData({
    required this.savingsScore,
    required this.budgetScore,
    required this.diversityScore,
    required this.debtScore,
  });

  int get total => savingsScore + budgetScore + diversityScore + debtScore;

  /// Returns the colour associated with the band.
  Color get bandColor {
    final t = total;
    if (t >= 80) return const Color(0xFF00C853); // Excellent — green
    if (t >= 60) return const Color(0xFFFFD600); // Good — yellow
    if (t >= 40) return const Color(0xFFFF6D00); // Fair — orange
    return const Color(0xFFDD2C00); // Needs attention — red
  }

  String get bandLabel {
    final t = total;
    if (t >= 80) return 'Excellent';
    if (t >= 60) return 'Good';
    if (t >= 40) return 'Fair';
    return 'Needs Attention';
  }
}

// ---------------------------------------------------------------------------
// Scoring helpers (pure functions — no BuildContext dependency)
// ---------------------------------------------------------------------------

_HealthScoreData _computeHealthScore({
  required List<Transaction> transactions,
  required List<Budget> budgets,
  required List<Investment> investments,
  required List<Account> accounts,
}) {
  // ── Savings rate (25 pts) ──────────────────────────────────────────────
  final now = DateTime.now();
  final monthStart = DateTime(now.year, now.month, 1);
  double income = 0;
  double expenses = 0;
  for (final tx in transactions) {
    if (tx.dateTime.isBefore(monthStart)) continue;
    if (tx.type == TransactionType.income ||
        tx.type == TransactionType.cashback) {
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
    if (rate >= 20) {
      savingsScore = 25;
    } else if (rate >= 10) {
      savingsScore = 15;
    } else if (rate >= 0) {
      savingsScore = 8;
    } else {
      savingsScore = 0;
    }
  }

  // ── Budget adherence (25 pts) ──────────────────────────────────────────
  final activeBudgets = budgets.where((b) => b.isActive).toList();
  int budgetScore;
  if (activeBudgets.isEmpty) {
    budgetScore = 0;
  } else {
    final onTrack =
        activeBudgets.where((b) => b.status != BudgetStatus.exceeded).length;
    final ratio = onTrack / activeBudgets.length;
    if (ratio >= 1.0) {
      budgetScore = 25;
    } else if (ratio > 0.75) {
      budgetScore = 15;
    } else if (ratio > 0.50) {
      budgetScore = 8;
    } else {
      budgetScore = 0;
    }
  }

  // ── Investment diversity (25 pts) ──────────────────────────────────────
  final activeInvestments =
      investments.where((inv) => inv.metadata?['isWithdrawn'] != true).toList();
  final distinctTypes =
      activeInvestments.map((inv) => inv.type).toSet().length;
  int diversityScore;
  if (distinctTypes >= 4) {
    diversityScore = 25;
  } else if (distinctTypes == 3) {
    diversityScore = 18;
  } else if (distinctTypes == 2) {
    diversityScore = 10;
  } else if (distinctTypes == 1) {
    diversityScore = 5;
  } else {
    diversityScore = 0;
  }

  // ── Debt ratio (25 pts) ────────────────────────────────────────────────
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
  // Add investment value to assets
  for (final inv in investments) {
    final currentValue =
        (inv.metadata?['currentValue'] as num?)?.toDouble() ?? inv.amount;
    totalAssets += currentValue;
  }

  int debtScore;
  if (totalAssets <= 0) {
    debtScore = 25; // No assets recorded → neutral
  } else {
    final ratio = totalDebt / totalAssets;
    if (ratio < 0.1) {
      debtScore = 25;
    } else if (ratio < 0.2) {
      debtScore = 18;
    } else if (ratio < 0.35) {
      debtScore = 10;
    } else if (ratio < 0.5) {
      debtScore = 5;
    } else {
      debtScore = 0;
    }
  }

  return _HealthScoreData(
    savingsScore: savingsScore,
    budgetScore: budgetScore,
    diversityScore: diversityScore,
    debtScore: debtScore,
  );
}

// ---------------------------------------------------------------------------
// Arc painter for the circular gauge
// ---------------------------------------------------------------------------

class _ScoreArcPainter extends CustomPainter {
  final double fraction; // 0.0 – 1.0
  final Color scoreColor;
  final Color trackColor;

  const _ScoreArcPainter({
    required this.fraction,
    required this.scoreColor,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = size.width * 0.085;
    final radius = (size.width - strokeWidth) / 2;
    final center = Offset(size.width / 2, size.height / 2);

    const startAngle = math.pi * 0.75; // Bottom-left
    const sweepAngle = math.pi * 1.5; // 270° arc

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

    // Track
    canvas.drawArc(rect, startAngle, sweepAngle, false, trackPaint);

    // Score fill
    if (fraction > 0) {
      canvas.drawArc(
          rect, startAngle, sweepAngle * fraction, false, scorePaint);
    }
  }

  @override
  bool shouldRepaint(_ScoreArcPainter old) =>
      old.fraction != fraction ||
      old.scoreColor != scoreColor ||
      old.trackColor != trackColor;
}

// ---------------------------------------------------------------------------
// Sub-score bar row
// ---------------------------------------------------------------------------

class _SubScoreBar extends StatelessWidget {
  final String label;
  final int score;
  final int maxScore;
  final Color color;

  const _SubScoreBar({
    required this.label,
    required this.score,
    required this.maxScore,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = maxScore > 0 ? (score / maxScore).clamp(0.0, 1.0) : 0.0;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final trackColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);

    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: TypeScale.caption,
                  fontWeight: FontWeight.w500,
                  color: AppStyles.getSecondaryTextColor(context),
                ),
              ),
              Text(
                '$score/$maxScore',
                style: TextStyle(
                  fontSize: TypeScale.caption,
                  fontWeight: FontWeight.w700,
                  color: color,
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
                      color: color,
                      borderRadius: BorderRadius.circular(Radii.full),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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

  /// The dashboard card in main.dart already renders the outer card shell
  /// (icon badge + title + border). Overriding build() here means we skip
  /// BaseDashboardWidget's inner card + inner header entirely — no duplicate
  /// title, no nested card.
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
        builder: (
          context,
          txController,
          budgetsController,
          investmentsController,
          accountsController,
          child,
        ) {
          final data = _computeHealthScore(
            transactions: txController.transactions,
            budgets: budgetsController.budgets,
            investments: investmentsController.investments,
            accounts: accountsController.accounts,
          );

          final isDark = Theme.of(context).brightness == Brightness.dark;
          final trackColor = isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Gauge + score ──────────────────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 90,
                    height: 90,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CustomPaint(
                          size: const Size(90, 90),
                          painter: _ScoreArcPainter(
                            fraction: data.total / 100.0,
                            scoreColor: data.bandColor,
                            trackColor: trackColor,
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${data.total}',
                              style: TextStyle(
                                fontSize: TypeScale.title1,
                                fontWeight: FontWeight.w800,
                                color: data.bandColor,
                                height: 1.1,
                              ),
                            ),
                            Text(
                              'of 100',
                              style: TextStyle(
                                fontSize: TypeScale.caption,
                                fontWeight: FontWeight.w500,
                                color:
                                    AppStyles.getSecondaryTextColor(context),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: Spacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: Spacing.sm, vertical: Spacing.xxs),
                          decoration: BoxDecoration(
                            color:
                                data.bandColor.withValues(alpha: 0.15),
                            borderRadius:
                                BorderRadius.circular(Radii.full),
                          ),
                          child: Text(
                            data.bandLabel,
                            style: TextStyle(
                              fontSize: TypeScale.caption,
                              fontWeight: FontWeight.w700,
                              color: data.bandColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: Spacing.sm),
                        Text(
                          _bandDescription(data.total),
                          style: TextStyle(
                            fontSize: TypeScale.caption,
                            color:
                                AppStyles.getSecondaryTextColor(context),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: Spacing.md),

              // ── Divider ────────────────────────────────────────────────
              Divider(
                height: 1,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.07)
                    : Colors.black.withValues(alpha: 0.07),
              ),

              const SizedBox(height: Spacing.md),

              // ── Sub-score bars ─────────────────────────────────────────
              _SubScoreBar(
                label: 'Savings Rate',
                score: data.savingsScore,
                maxScore: 25,
                color: const Color(0xFF00C853),
              ),
              _SubScoreBar(
                label: 'Budget Adherence',
                score: data.budgetScore,
                maxScore: 25,
                color: AppStyles.accentBlue,
              ),
              _SubScoreBar(
                label: 'Investment Diversity',
                score: data.diversityScore,
                maxScore: 25,
                color: AppStyles.accentTeal,
              ),
              _SubScoreBar(
                label: 'Debt Ratio',
                score: data.debtScore,
                maxScore: 25,
                color: AppStyles.accentOrange,
              ),
            ],
          );
        },
      ),
    );
  }

  String _bandDescription(int score) {
    if (score >= 80) return 'Your finances are in great shape. Keep it up!';
    if (score >= 60) return 'Good financial health with room to improve.';
    if (score >= 40) return 'Some areas need attention to stay on track.';
    return 'Focus on savings, budgets, and reducing debt.';
  }
}
