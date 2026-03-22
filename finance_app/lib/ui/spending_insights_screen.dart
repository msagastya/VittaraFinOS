import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/budgets_controller.dart';
import 'package:vittara_fin_os/logic/transactions_controller.dart';
import 'package:vittara_fin_os/ui/dashboard/widgets/insights_widget.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Full-screen Spending Intelligence Screen
// ─────────────────────────────────────────────────────────────────────────────

class SpendingInsightsScreen extends StatelessWidget {
  const SpendingInsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Spending Intelligence'),
        backgroundColor: isDark ? AppStyles.darkBackground : AppStyles.lightBackground,
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.07)
                : Colors.black.withValues(alpha: 0.07),
            width: 0.5,
          ),
        ),
      ),
      child: Consumer2<TransactionsController, BudgetsController>(
        builder: (context, txCtrl, budgetsCtrl, _) {
          final data = computeSpendIntel(txCtrl.transactions, budgetsCtrl.budgets);
          return _SpendIntelBody(data: data, isDark: isDark);
        },
      ),
    );
  }
}

class _SpendIntelBody extends StatelessWidget {
  final SpendIntelData data;
  final bool isDark;

  const _SpendIntelBody({required this.data, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? AppStyles.darkBackground : AppStyles.lightBackground;
    final cardBg = isDark
        ? Colors.white.withValues(alpha: 0.04)
        : Colors.black.withValues(alpha: 0.025);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(Spacing.md, Spacing.md, Spacing.md, Spacing.xl),
        children: [
          // ── Summary tiles row ───────────────────────────────────────────
          _SummaryRow(data: data, isDark: isDark, cardBg: cardBg),

          const SizedBox(height: Spacing.lg),

          // ── Narrative Intelligence Cards (all cards, vertical) ──────────
          SpendSectionLabel('AI INSIGHTS  ·  ${data.narratives.length} signals this month'),
          const SizedBox(height: Spacing.sm),
          ...data.narratives.map((insight) => Padding(
                padding: const EdgeInsets.only(bottom: Spacing.sm),
                child: _FullNarrativeCard(insight: insight, isDark: isDark),
              )),

          const SizedBox(height: Spacing.md),

          // ── Month Forecast ──────────────────────────────────────────────
          if (data.hasData && data.projectedMonthEnd > 0) ...[
            SpendSectionLabel('MONTH FORECAST'),
            const SizedBox(height: Spacing.sm),
            Container(
              padding: const EdgeInsets.all(Spacing.md),
              decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(Radii.lg)),
              child: SpendForecastBar(data: data, isDark: isDark),
            ),
            const SizedBox(height: Spacing.lg),
          ],

          // ── Category Breakdown (full list) ──────────────────────────────
          if (data.categoryDrifts.isNotEmpty) ...[
            SpendSectionLabel('CATEGORY PULSE  ·  this month vs last'),
            const SizedBox(height: Spacing.sm),
            Container(
              padding: const EdgeInsets.all(Spacing.md),
              decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(Radii.lg)),
              child: _FullCategoryTable(drifts: data.categoryDrifts, total: data.totalThisMonth, isDark: isDark),
            ),
            const SizedBox(height: Spacing.lg),
          ],

          // ── Day-of-week rhythm (taller) ─────────────────────────────────
          if (data.hasData) ...[
            SpendSectionLabel('SPEND RHYTHM  ·  by day of week'),
            const SizedBox(height: Spacing.sm),
            Container(
              padding: const EdgeInsets.all(Spacing.md),
              decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(Radii.lg)),
              child: SpendDowHeatmap(dowSpend: data.dowSpend, isDark: isDark, barHeight: 80),
            ),
            const SizedBox(height: Spacing.lg),
          ],

          // ── Top Merchants (full list) ───────────────────────────────────
          if (data.topMerchants.isNotEmpty && data.totalThisMonth > 0) ...[
            SpendSectionLabel('TOP MERCHANTS  ·  by share of wallet'),
            const SizedBox(height: Spacing.sm),
            Container(
              padding: const EdgeInsets.all(Spacing.md),
              decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(Radii.lg)),
              child: SpendTopMerchantsSection(
                merchants: data.topMerchants,
                totalThisMonth: data.totalThisMonth,
                isDark: isDark,
              ),
            ),
            const SizedBox(height: Spacing.lg),
          ],

          // ── Monthly trend bars (last 4 months) ──────────────────────────
          _MonthlyTrendSection(data: data, cardBg: cardBg, isDark: isDark),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Summary row: 3 key stat tiles
// ─────────────────────────────────────────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  final SpendIntelData data;
  final bool isDark;
  final Color cardBg;

  const _SummaryRow({required this.data, required this.isDark, required this.cardBg});

  @override
  Widget build(BuildContext context) {
    final momColor = data.momChange > 0 ? AppStyles.loss(context) : AppStyles.gain(context);
    final srColor = data.savingsRate >= 20
        ? AppStyles.gain(context)
        : data.savingsRate >= 5
            ? AppStyles.accentOrange
            : AppStyles.loss(context);

    return Row(
      children: [
        Expanded(
          child: _StatTile(
            label: 'Spent',
            value: spendFmt(data.totalThisMonth),
            sub: 'this month',
            color: AppStyles.teal(context),
            cardBg: cardBg,
          ),
        ),
        const SizedBox(width: Spacing.sm),
        Expanded(
          child: _StatTile(
            label: 'vs Last Mo',
            value: '${data.momChange >= 0 ? '+' : ''}${data.momChange.toStringAsFixed(1)}%',
            sub: spendFmt(data.totalLastMonth),
            color: momColor,
            cardBg: cardBg,
          ),
        ),
        const SizedBox(width: Spacing.sm),
        Expanded(
          child: _StatTile(
            label: 'Saved',
            value: data.savingsRate >= 0
                ? '${data.savingsRate.toStringAsFixed(1)}%'
                : '—',
            sub: 'of income',
            color: srColor,
            cardBg: cardBg,
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final String sub;
  final Color color;
  final Color cardBg;

  const _StatTile({
    required this.label,
    required this.value,
    required this.sub,
    required this.color,
    required this.cardBg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.sm, vertical: Spacing.md),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
              color: AppStyles.getSecondaryTextColor(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: TypeScale.footnote,
              fontWeight: FontWeight.w800,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            sub,
            style: TextStyle(
              fontSize: 9,
              color: AppStyles.getSecondaryTextColor(context),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Full narrative card (taller, more detail than carousel version)
// ─────────────────────────────────────────────────────────────────────────────

class _FullNarrativeCard extends StatelessWidget {
  final SpendNarrative insight;
  final bool isDark;

  const _FullNarrativeCard({required this.insight, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final accent = insight.color(isDark);
    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.lg),
        color: accent.withValues(alpha: isDark ? 0.07 : 0.05),
        border: Border(left: BorderSide(color: accent, width: 3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(Radii.md),
            ),
            child: Icon(insight.icon, size: 19, color: accent),
          ),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  insight.headline,
                  style: TextStyle(
                    fontSize: TypeScale.footnote,
                    fontWeight: FontWeight.w700,
                    color: accent,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  insight.detail,
                  style: TextStyle(
                    fontSize: TypeScale.caption,
                    color: AppStyles.getSecondaryTextColor(context),
                    height: 1.4,
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

// ─────────────────────────────────────────────────────────────────────────────
// Full category table (all categories, with share bar + MoM delta)
// ─────────────────────────────────────────────────────────────────────────────

class _FullCategoryTable extends StatelessWidget {
  final List<SpendCategoryDrift> drifts;
  final double total;
  final bool isDark;

  const _FullCategoryTable({
    required this.drifts,
    required this.total,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: drifts.asMap().entries.map((entry) {
        final drift = entry.value;
        final share = total > 0 ? (drift.thisMonth / total).clamp(0.0, 1.0) : 0.0;
        final isLast = entry.key == drifts.length - 1;
        final delta = drift.momDelta;
        final deltaColor = drift.isAnomalous
            ? AppStyles.loss(context)
            : delta > 5
                ? AppStyles.accentOrange
                : delta < -5
                    ? AppStyles.gain(context)
                    : AppStyles.getSecondaryTextColor(context);
        final trackColor = isDark
            ? Colors.white.withValues(alpha: 0.07)
            : Colors.black.withValues(alpha: 0.05);

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
              child: Row(
                children: [
                  Text(drift.emoji, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: Spacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              drift.name,
                              style: TextStyle(
                                fontSize: TypeScale.caption,
                                fontWeight: FontWeight.w600,
                                color: AppStyles.getTextColor(context),
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  spendFmt(drift.thisMonth),
                                  style: TextStyle(
                                    fontSize: TypeScale.caption,
                                    fontWeight: FontWeight.w700,
                                    color: AppStyles.getTextColor(context),
                                  ),
                                ),
                                const SizedBox(width: Spacing.sm),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: deltaColor.withValues(alpha: 0.12),
                                    borderRadius:
                                        BorderRadius.circular(Radii.full),
                                  ),
                                  child: Text(
                                    delta == 0
                                        ? '—'
                                        : '${delta > 0 ? '↑' : '↓'}${delta.abs().toStringAsFixed(0)}%',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: deltaColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        // Share bar
                        ClipRRect(
                          borderRadius: BorderRadius.circular(Radii.full),
                          child: Stack(
                            children: [
                              Container(height: 4, color: trackColor),
                              FractionallySizedBox(
                                widthFactor: share,
                                child: Container(
                                  height: 4,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(colors: [
                                      AppStyles.teal(context).withValues(alpha: 0.6),
                                      AppStyles.teal(context),
                                    ]),
                                    borderRadius:
                                        BorderRadius.circular(Radii.full),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${(share * 100).toStringAsFixed(1)}% of total',
                          style: TextStyle(
                            fontSize: 9,
                            color: AppStyles.getSecondaryTextColor(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (!isLast)
              Divider(
                height: 1,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.05),
              ),
          ],
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Monthly trend section — last 4 months bar comparison
// ─────────────────────────────────────────────────────────────────────────────

class _MonthlyTrendSection extends StatelessWidget {
  final SpendIntelData data;
  final Color cardBg;
  final bool isDark;

  const _MonthlyTrendSection({
    required this.data,
    required this.cardBg,
    required this.isDark,
  });

  static final _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    // Build labels + mock totals from what we know
    // We only have this month + last month's actual total from SpendIntelData
    // Show a 2-bar comparison rather than 4 to avoid fabricating data
    if (data.totalThisMonth == 0 && data.totalLastMonth == 0) {
      return const SizedBox.shrink();
    }

    final thisLabel = _monthNames[(now.month - 1) % 12];
    final lastLabel = _monthNames[(now.month - 2 + 12) % 12];
    final maxVal = math.max(data.totalThisMonth, data.totalLastMonth);
    if (maxVal == 0) return const SizedBox.shrink();

    final thisFrac = (data.totalThisMonth / maxVal).clamp(0.0, 1.0);
    final lastFrac = (data.totalLastMonth / maxVal).clamp(0.0, 1.0);
    const maxBarH = 80.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SpendSectionLabel('MONTH COMPARISON'),
        const SizedBox(height: Spacing.sm),
        Container(
          padding: const EdgeInsets.all(Spacing.md),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(Radii.lg),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Last month bar
              Expanded(
                child: Column(
                  children: [
                    Text(
                      spendFmt(data.totalLastMonth),
                      style: TextStyle(
                        fontSize: TypeScale.caption,
                        fontWeight: FontWeight.w700,
                        color: AppStyles.getSecondaryTextColor(context),
                      ),
                    ),
                    const SizedBox(height: Spacing.xs),
                    Container(
                      height: maxBarH * lastFrac + 4,
                      margin: const EdgeInsets.symmetric(horizontal: Spacing.sm),
                      decoration: BoxDecoration(
                        color: AppStyles.accentBlue.withValues(alpha: 0.4),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                      ),
                    ),
                    const SizedBox(height: Spacing.xs),
                    Text(
                      lastLabel,
                      style: TextStyle(
                        fontSize: TypeScale.caption,
                        color: AppStyles.getSecondaryTextColor(context),
                      ),
                    ),
                    Text(
                      'Full month',
                      style: TextStyle(
                        fontSize: 9,
                        color: AppStyles.getSecondaryTextColor(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Spacing.sm),
              // This month bar (current — partial)
              Expanded(
                child: Column(
                  children: [
                    Column(
                      children: [
                        Text(
                          spendFmt(data.totalThisMonth),
                          style: TextStyle(
                            fontSize: TypeScale.caption,
                            fontWeight: FontWeight.w800,
                            color: AppStyles.teal(context),
                          ),
                        ),
                        if (data.projectedMonthEnd > 0)
                          Text(
                            '→ ${spendFmt(data.projectedMonthEnd)} projected',
                            style: TextStyle(
                              fontSize: 9,
                              color: AppStyles.accentOrange,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: Spacing.xs),
                    Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        // Projected ghost bar
                        if (data.projectedMonthEnd > 0)
                          Container(
                            height: maxBarH *
                                    (data.projectedMonthEnd / maxVal).clamp(0.0, 1.0) +
                                4,
                            margin: const EdgeInsets.symmetric(horizontal: Spacing.sm),
                            decoration: BoxDecoration(
                              color: AppStyles.teal(context).withValues(alpha: 0.12),
                              borderRadius:
                                  const BorderRadius.vertical(top: Radius.circular(6)),
                              border: Border.all(
                                color: AppStyles.teal(context).withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                          ),
                        // Actual bar
                        Container(
                          height: maxBarH * thisFrac + 4,
                          margin: const EdgeInsets.symmetric(horizontal: Spacing.sm),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                AppStyles.teal(context).withValues(alpha: 0.6),
                                AppStyles.teal(context),
                              ],
                            ),
                            borderRadius:
                                const BorderRadius.vertical(top: Radius.circular(6)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Spacing.xs),
                    Text(
                      thisLabel,
                      style: TextStyle(
                        fontSize: TypeScale.caption,
                        fontWeight: FontWeight.w700,
                        color: AppStyles.teal(context),
                      ),
                    ),
                    Text(
                      'Day ${data.dayOfMonth}/${data.daysInMonth}',
                      style: TextStyle(
                        fontSize: 9,
                        color: AppStyles.getSecondaryTextColor(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
