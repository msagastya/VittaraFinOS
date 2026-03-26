import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/budgets_controller.dart';
import 'package:vittara_fin_os/logic/transaction_model.dart';
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
      navigationBar: AppStyles.isLandscape(context) ? null : CupertinoNavigationBar(
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
          return _SpendIntelBody(
            data: data,
            isDark: isDark,
            transactions: txCtrl.transactions,
          );
        },
      ),
    );
  }
}

class _SpendIntelBody extends StatelessWidget {
  final SpendIntelData data;
  final bool isDark;
  final List<Transaction> transactions;

  const _SpendIntelBody({
    required this.data,
    required this.isDark,
    required this.transactions,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? AppStyles.darkBackground : AppStyles.lightBackground;
    final cardBg = isDark
        ? Colors.white.withValues(alpha: 0.04)
        : Colors.black.withValues(alpha: 0.025);
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final thisMonthExp = transactions
        .where((t) =>
            t.type == TransactionType.expense &&
            !t.dateTime.isBefore(monthStart))
        .toList();

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

          // ── Category Breakdown (full list, expandable) ──────────────────
          if (data.categoryDrifts.isNotEmpty) ...[
            SpendSectionLabel('CATEGORY PULSE  ·  tap to expand'),
            const SizedBox(height: Spacing.sm),
            Container(
              padding: const EdgeInsets.all(Spacing.md),
              decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(Radii.lg)),
              child: _ExpandableCategoryTable(
                drifts: data.categoryDrifts,
                total: data.totalThisMonth,
                isDark: isDark,
                transactions: thisMonthExp,
              ),
            ),
            const SizedBox(height: Spacing.lg),
          ],

          // ── Day-of-week rhythm (expandable) ─────────────────────────────
          if (data.hasData) ...[
            SpendSectionLabel('SPEND RHYTHM  ·  tap a day to expand'),
            const SizedBox(height: Spacing.sm),
            Container(
              padding: const EdgeInsets.all(Spacing.md),
              decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(Radii.lg)),
              child: _ExpandableRhythm(
                dowSpend: data.dowSpend,
                isDark: isDark,
                transactions: thisMonthExp,
              ),
            ),
            const SizedBox(height: Spacing.lg),
          ],

          // ── Top Merchants (expandable) ───────────────────────────────────
          if (data.topMerchants.isNotEmpty && data.totalThisMonth > 0) ...[
            SpendSectionLabel('TOP MERCHANTS  ·  tap to expand'),
            const SizedBox(height: Spacing.sm),
            Container(
              padding: const EdgeInsets.all(Spacing.md),
              decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(Radii.lg)),
              child: _ExpandableMerchants(
                merchants: data.topMerchants,
                totalThisMonth: data.totalThisMonth,
                isDark: isDark,
                transactions: thisMonthExp,
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
// Shared transaction row helper
// ─────────────────────────────────────────────────────────────────────────────

Widget _buildTxRow(BuildContext context, Transaction tx, bool isDark) {
  final d = tx.dateTime;
  final dateStr = '${d.day}/${d.month}';
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        SizedBox(
          width: 36,
          child: Text(
            dateStr,
            style: TextStyle(fontSize: 10, color: AppStyles.getSecondaryTextColor(context)),
          ),
        ),
        Expanded(
          child: Text(
            tx.description.isNotEmpty ? tx.description : 'Transaction',
            style: TextStyle(fontSize: TypeScale.caption, color: AppStyles.getTextColor(context)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          spendFmt(tx.amount.abs()),
          style: TextStyle(
            fontSize: TypeScale.caption,
            fontWeight: FontWeight.w600,
            color: AppStyles.loss(context),
          ),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Expandable category table
// ─────────────────────────────────────────────────────────────────────────────

class _ExpandableCategoryTable extends StatefulWidget {
  final List<SpendCategoryDrift> drifts;
  final double total;
  final bool isDark;
  final List<Transaction> transactions;

  const _ExpandableCategoryTable({
    required this.drifts,
    required this.total,
    required this.isDark,
    required this.transactions,
  });

  @override
  State<_ExpandableCategoryTable> createState() => _ExpandableCategoryTableState();
}

class _ExpandableCategoryTableState extends State<_ExpandableCategoryTable> {
  String? _expandedName;

  List<Transaction> _txsForCategory(String name) {
    final txs = widget.transactions
        .where((t) =>
            ((t.metadata?['categoryName'] as String?) ?? 'Other') == name)
        .toList()
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
    return txs;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final trackColor = isDark
        ? Colors.white.withValues(alpha: 0.07)
        : Colors.black.withValues(alpha: 0.05);
    final divColor = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.black.withValues(alpha: 0.05);

    return Column(
      children: widget.drifts.asMap().entries.map((entry) {
        final drift = entry.value;
        final share = widget.total > 0
            ? (drift.thisMonth / widget.total).clamp(0.0, 1.0)
            : 0.0;
        final isLast = entry.key == widget.drifts.length - 1;
        final delta = drift.momDelta;
        final deltaColor = drift.isAnomalous
            ? AppStyles.loss(context)
            : delta > 5
                ? AppStyles.accentOrange
                : delta < -5
                    ? AppStyles.gain(context)
                    : AppStyles.getSecondaryTextColor(context);
        final isExpanded = _expandedName == drift.name;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(
                  () => _expandedName = isExpanded ? null : drift.name),
              child: Padding(
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
                              Row(
                                children: [
                                  Text(
                                    drift.name,
                                    style: TextStyle(
                                      fontSize: TypeScale.caption,
                                      fontWeight: FontWeight.w600,
                                      color: AppStyles.getTextColor(context),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    isExpanded
                                        ? CupertinoIcons.chevron_up
                                        : CupertinoIcons.chevron_down,
                                    size: 10,
                                    color: AppStyles.getSecondaryTextColor(context),
                                  ),
                                ],
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
                                        AppStyles.teal(context)
                                            .withValues(alpha: 0.6),
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
            ),
            // Expanded transactions
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              child: isExpanded
                  ? () {
                      final all = _txsForCategory(drift.name);
                      final txs = all.take(5).toList();
                      if (txs.isEmpty) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(
                            left: 28, bottom: Spacing.sm),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Divider(height: 1, color: divColor),
                            const SizedBox(height: Spacing.xs),
                            ...txs.map(
                                (t) => _buildTxRow(context, t, isDark)),
                            if (all.length > 5)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  '+${all.length - 5} more',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: AppStyles.getSecondaryTextColor(
                                          context)),
                                ),
                              ),
                          ],
                        ),
                      );
                    }()
                  : const SizedBox.shrink(),
            ),
            if (!isLast) Divider(height: 1, color: divColor),
          ],
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Expandable spend rhythm (day-of-week)
// ─────────────────────────────────────────────────────────────────────────────

class _ExpandableRhythm extends StatefulWidget {
  final List<double> dowSpend;
  final bool isDark;
  final List<Transaction> transactions;

  const _ExpandableRhythm({
    required this.dowSpend,
    required this.isDark,
    required this.transactions,
  });

  @override
  State<_ExpandableRhythm> createState() => _ExpandableRhythmState();
}

class _ExpandableRhythmState extends State<_ExpandableRhythm> {
  int? _expanded;

  List<Transaction> _txsForDow(int dow) {
    return widget.transactions
        .where((t) => t.dateTime.weekday - 1 == dow)
        .toList()
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final maxVal = widget.dowSpend.isEmpty
        ? 0.0
        : widget.dowSpend.reduce(math.max);
    if (maxVal == 0) {
      return Text(
        'No spending recorded this month yet.',
        style: TextStyle(
            fontSize: TypeScale.caption,
            color: AppStyles.getSecondaryTextColor(context)),
      );
    }
    const barH = 80.0;
    final peakColor = AppStyles.violet(context);
    final divColor = isDark
        ? Colors.white.withValues(alpha: 0.07)
        : Colors.black.withValues(alpha: 0.07);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(7, (i) {
            final fraction =
                maxVal > 0 ? (widget.dowSpend[i] / maxVal).clamp(0.0, 1.0) : 0.0;
            final isPeak = widget.dowSpend[i] == maxVal;
            final isExpanded = _expanded == i;
            final h = fraction * barH;
            final color = isPeak
                ? peakColor
                : Color.lerp(
                    peakColor.withValues(alpha: 0.25),
                    peakColor.withValues(alpha: 0.7),
                    fraction,
                  )!;

            return Expanded(
              child: GestureDetector(
                onTap: widget.dowSpend[i] > 0
                    ? () => setState(
                        () => _expanded = isExpanded ? null : i)
                    : null,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.dowSpend[i] > 0)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          spendFmt(widget.dowSpend[i]),
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight:
                                isPeak ? FontWeight.w700 : FontWeight.w500,
                            color: (isPeak || isExpanded)
                                ? peakColor
                                : AppStyles.getSecondaryTextColor(context),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    Container(
                      height: h > 0 ? h : 2,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: isExpanded ? peakColor : color,
                        borderRadius:
                            const BorderRadius.vertical(top: Radius.circular(3)),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      spendDowName(i).substring(0, 2),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: (isPeak || isExpanded)
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: (isPeak || isExpanded)
                            ? peakColor
                            : AppStyles.getSecondaryTextColor(context),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          child: _expanded != null && widget.dowSpend[_expanded!] > 0
              ? () {
                  final all = _txsForDow(_expanded!);
                  final txs = all.take(5).toList();
                  return Padding(
                    padding: const EdgeInsets.only(top: Spacing.sm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Divider(height: 1, color: divColor),
                        const SizedBox(height: Spacing.xs),
                        Text(
                          '${spendDowName(_expanded!)} transactions',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                            color: AppStyles.getSecondaryTextColor(context),
                          ),
                        ),
                        const SizedBox(height: Spacing.xs),
                        ...txs.map((t) => _buildTxRow(context, t, isDark)),
                        if (all.length > 5)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '+${all.length - 5} more',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: AppStyles.getSecondaryTextColor(
                                      context)),
                            ),
                          ),
                      ],
                    ),
                  );
                }()
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Expandable top merchants
// ─────────────────────────────────────────────────────────────────────────────

class _ExpandableMerchants extends StatefulWidget {
  final List<MapEntry<String, double>> merchants;
  final double totalThisMonth;
  final bool isDark;
  final List<Transaction> transactions;

  const _ExpandableMerchants({
    required this.merchants,
    required this.totalThisMonth,
    required this.isDark,
    required this.transactions,
  });

  @override
  State<_ExpandableMerchants> createState() => _ExpandableMerchantsState();
}

class _ExpandableMerchantsState extends State<_ExpandableMerchants> {
  String? _expanded;

  List<Transaction> _txsForMerchant(String name) {
    return widget.transactions.where((t) {
      final m = (t.metadata?['merchant'] as String?) ??
          (t.description.isNotEmpty ? t.description : 'Unknown');
      return m == name;
    }).toList()
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.merchants.isEmpty || widget.totalThisMonth == 0) {
      return const SizedBox.shrink();
    }
    final isDark = widget.isDark;
    final colors = [
      AppStyles.teal(context),
      AppStyles.accentBlue,
      AppStyles.gold(context)
    ];
    final divColor = isDark
        ? Colors.white.withValues(alpha: 0.07)
        : Colors.black.withValues(alpha: 0.07);

    return Column(
      children: List.generate(widget.merchants.length, (i) {
        final m = widget.merchants[i];
        final share = (m.value / widget.totalThisMonth).clamp(0.0, 1.0);
        final color = colors[i % colors.length];
        final isExpanded = _expanded == m.key;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(
                  () => _expanded = isExpanded ? null : m.key),
              child: Padding(
                padding: const EdgeInsets.only(bottom: Spacing.xs),
                child: Row(
                  children: [
                    SizedBox(
                      width: 120,
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              m.key,
                              style: TextStyle(
                                fontSize: TypeScale.caption,
                                color: AppStyles.getTextColor(context),
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            isExpanded
                                ? CupertinoIcons.chevron_up
                                : CupertinoIcons.chevron_down,
                            size: 10,
                            color: AppStyles.getSecondaryTextColor(context),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: Spacing.sm),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(Radii.full),
                        child: Stack(
                          children: [
                            Container(
                              height: 5,
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.07)
                                  : Colors.black.withValues(alpha: 0.05),
                            ),
                            FractionallySizedBox(
                              widthFactor: share,
                              child: Container(height: 5, color: color),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: Spacing.sm),
                    Text(
                      '${(share * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: TypeScale.caption,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: Spacing.xs),
                    Text(
                      spendFmt(m.value),
                      style: TextStyle(
                        fontSize: TypeScale.caption,
                        color: AppStyles.getSecondaryTextColor(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              child: isExpanded
                  ? () {
                      final all = _txsForMerchant(m.key);
                      final txs = all.take(5).toList();
                      if (txs.isEmpty) return const SizedBox.shrink();
                      return Padding(
                        padding:
                            const EdgeInsets.only(left: 8, bottom: Spacing.sm),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Divider(height: 1, color: divColor),
                            const SizedBox(height: Spacing.xs),
                            ...txs.map((t) => _buildTxRow(context, t, isDark)),
                            if (all.length > 5)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  '+${all.length - 5} more',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: AppStyles.getSecondaryTextColor(
                                          context)),
                                ),
                              ),
                          ],
                        ),
                      );
                    }()
                  : const SizedBox.shrink(),
            ),
          ],
        );
      }),
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
