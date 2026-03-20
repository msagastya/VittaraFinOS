import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/budgets_controller.dart';
import 'package:vittara_fin_os/logic/transaction_model.dart';
import 'package:vittara_fin_os/logic/transactions_controller.dart';
import 'package:vittara_fin_os/ui/dashboard/base_dashboard_widget.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Data models
// ─────────────────────────────────────────────────────────────────────────────

enum _InsightLevel { positive, warning, alert, neutral }

class _NarrativeInsight {
  final String headline;
  final String detail;
  final IconData icon;
  final _InsightLevel level;

  const _NarrativeInsight({
    required this.headline,
    required this.detail,
    required this.icon,
    required this.level,
  });

  Color color(bool isDark) {
    switch (level) {
      case _InsightLevel.positive:
        return AppStyles.bioGreen;
      case _InsightLevel.warning:
        return AppStyles.accentOrange;
      case _InsightLevel.alert:
        return AppStyles.plasmaRed;
      case _InsightLevel.neutral:
        return AppStyles.aetherTeal;
    }
  }
}

class _CategoryDrift {
  final String name;
  final String emoji;
  final double thisMonth;
  final double lastMonth;
  final double threeMonthAvg;

  const _CategoryDrift({
    required this.name,
    required this.emoji,
    required this.thisMonth,
    required this.lastMonth,
    required this.threeMonthAvg,
  });

  double get momDelta =>
      lastMonth > 0 ? ((thisMonth - lastMonth) / lastMonth) * 100 : 0;
  double get vsAvgDelta =>
      threeMonthAvg > 0 ? ((thisMonth - threeMonthAvg) / threeMonthAvg) * 100 : 0;
  bool get isAnomalous => thisMonth > 0 && vsAvgDelta > 40;
}

class _SpendIntelData {
  final List<_NarrativeInsight> narratives;
  final List<_CategoryDrift> categoryDrifts;
  final List<double> dowSpend; // index 0=Mon..6=Sun
  final double totalThisMonth;
  final double totalLastMonth;
  final double projectedMonthEnd;
  final double incomeThisMonth;
  final int dayOfMonth;
  final int daysInMonth;
  final List<MapEntry<String, double>> topMerchants;
  final bool hasData;

  const _SpendIntelData({
    required this.narratives,
    required this.categoryDrifts,
    required this.dowSpend,
    required this.totalThisMonth,
    required this.totalLastMonth,
    required this.projectedMonthEnd,
    required this.incomeThisMonth,
    required this.dayOfMonth,
    required this.daysInMonth,
    required this.topMerchants,
    required this.hasData,
  });

  double get monthElapsedFraction => daysInMonth > 0 ? dayOfMonth / daysInMonth : 0;
  double get momChange => totalLastMonth > 0
      ? ((totalThisMonth - totalLastMonth) / totalLastMonth) * 100
      : 0;
  double get savingsRate =>
      incomeThisMonth > 0 ? ((incomeThisMonth - totalThisMonth) / incomeThisMonth) * 100 : -1;
}

// ─────────────────────────────────────────────────────────────────────────────
// Intelligence computation engine
// ─────────────────────────────────────────────────────────────────────────────

String _fmt(double v) {
  if (v >= 100000) return '₹${(v / 100000).toStringAsFixed(1)}L';
  if (v >= 1000) return '₹${(v / 1000).toStringAsFixed(1)}K';
  return '₹${v.toStringAsFixed(0)}';
}

String _dowName(int i) =>
    ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][i.clamp(0, 6)];

String _catEmoji(String cat) {
  const m = {
    'food': '🍔',
    'dining': '🍽️',
    'groceries': '🛒',
    'transport': '🚗',
    'travel': '✈️',
    'entertainment': '🎬',
    'shopping': '🛍️',
    'health': '💊',
    'medical': '🏥',
    'utilities': '⚡',
    'bills': '📋',
    'education': '📚',
    'fitness': '💪',
    'investment': '📈',
    'savings': '🏦',
    'other': '📌',
  };
  final lower = cat.toLowerCase();
  for (final e in m.entries) {
    if (lower.contains(e.key)) return e.value;
  }
  return '💳';
}

_SpendIntelData _computeSpendIntel(
    List<Transaction> transactions, List budgets) {
  final now = DateTime.now();
  final dayOfMonth = now.day;
  final daysInMonth = DateTime(now.year, now.month + 1, 0).day;

  final monthStart = DateTime(now.year, now.month, 1);
  final prevMonthStart = DateTime(now.year, now.month - 1, 1);
  final prevMonthEnd = monthStart.subtract(const Duration(microseconds: 1));
  final twoMonthsAgoStart = DateTime(now.year, now.month - 2, 1);
  final twoMonthsAgoEnd =
      prevMonthStart.subtract(const Duration(microseconds: 1));
  final threeMonthsAgoStart = DateTime(now.year, now.month - 3, 1);
  final threeMonthsAgoEnd =
      twoMonthsAgoStart.subtract(const Duration(microseconds: 1));

  // Split transactions by month
  List<Transaction> expInPeriod(DateTime from, DateTime to) => transactions
      .where((t) =>
          t.type == TransactionType.expense &&
          !t.dateTime.isBefore(from) &&
          !t.dateTime.isAfter(to))
      .toList();

  final thisMonthExp = expInPeriod(monthStart, now);
  final lastMonthExp = expInPeriod(prevMonthStart, prevMonthEnd);
  final twoMoExp = expInPeriod(twoMonthsAgoStart, twoMonthsAgoEnd);
  final threeMoExp = expInPeriod(threeMonthsAgoStart, threeMonthsAgoEnd);

  final totalThis = thisMonthExp.fold(0.0, (s, t) => s + t.amount.abs());
  final totalLast = lastMonthExp.fold(0.0, (s, t) => s + t.amount.abs());
  final totalTwo = twoMoExp.fold(0.0, (s, t) => s + t.amount.abs());
  final totalThree = threeMoExp.fold(0.0, (s, t) => s + t.amount.abs());

  final incomeThis = transactions
      .where((t) =>
          t.type == TransactionType.income && !t.dateTime.isBefore(monthStart))
      .fold(0.0, (s, t) => s + t.amount.abs());

  final hasData = totalThis > 0 || totalLast > 0;

  // Projection: linear extrapolation
  final projected = dayOfMonth > 0
      ? (totalThis / dayOfMonth) * daysInMonth
      : 0.0;

  // ── Category aggregation ─────────────────────────────────────────────────
  Map<String, double> catTotal(List<Transaction> list) {
    final m = <String, double>{};
    for (final t in list) {
      final c = (t.metadata?['categoryName'] as String?) ?? 'Other';
      m[c] = (m[c] ?? 0) + t.amount.abs();
    }
    return m;
  }

  final catThis = catTotal(thisMonthExp);
  final catLast = catTotal(lastMonthExp);
  final catTwo = catTotal(twoMoExp);
  final catThree = catTotal(threeMoExp);

  final allCats = catThis.keys.toSet();
  final categoryDrifts = <_CategoryDrift>[];
  for (final cat in allCats) {
    final thisV = catThis[cat] ?? 0;
    final lastV = catLast[cat] ?? 0;
    final twoV = catTwo[cat] ?? 0;
    final threeV = catThree[cat] ?? 0;
    final historicMonths = [if (lastV > 0) lastV, if (twoV > 0) twoV, if (threeV > 0) threeV];
    final avg = historicMonths.isEmpty
        ? 0.0
        : historicMonths.fold(0.0, (a, b) => a + b) / historicMonths.length;
    categoryDrifts.add(_CategoryDrift(
      name: cat,
      emoji: _catEmoji(cat),
      thisMonth: thisV,
      lastMonth: lastV,
      threeMonthAvg: avg,
    ));
  }
  categoryDrifts.sort((a, b) => b.thisMonth.compareTo(a.thisMonth));
  final topCats = categoryDrifts.take(6).toList();

  // ── Day-of-week heatmap ──────────────────────────────────────────────────
  final dow = List.filled(7, 0.0);
  for (final t in thisMonthExp) {
    final idx = (t.dateTime.weekday - 1).clamp(0, 6);
    dow[idx] += t.amount.abs();
  }

  // ── Merchant concentration ───────────────────────────────────────────────
  final merchantTotals = <String, double>{};
  for (final t in thisMonthExp) {
    final m = (t.metadata?['merchant'] as String?) ??
        (t.description.isNotEmpty ? t.description : 'Unknown');
    merchantTotals[m] = (merchantTotals[m] ?? 0) + t.amount.abs();
  }
  final topMerchants = merchantTotals.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final top3Merchants = topMerchants.take(3).toList();

  // ── Narrative insights ───────────────────────────────────────────────────
  final narratives = <_NarrativeInsight>[];

  if (!hasData) {
    narratives.add(const _NarrativeInsight(
      headline: 'No spending data yet',
      detail: 'Add transactions to unlock AI-powered spending intelligence.',
      icon: CupertinoIcons.sparkles,
      level: _InsightLevel.neutral,
    ));
    return _SpendIntelData(
      narratives: narratives,
      categoryDrifts: topCats,
      dowSpend: dow,
      totalThisMonth: totalThis,
      totalLastMonth: totalLast,
      projectedMonthEnd: projected,
      incomeThisMonth: incomeThis,
      dayOfMonth: dayOfMonth,
      daysInMonth: daysInMonth,
      topMerchants: top3Merchants,
      hasData: false,
    );
  }

  // 1. Month forecast narrative
  if (projected > 0 && totalLast > 0) {
    final projDelta = ((projected - totalLast) / totalLast) * 100;
    final level = projDelta > 20
        ? _InsightLevel.alert
        : projDelta > 5
            ? _InsightLevel.warning
            : _InsightLevel.positive;
    narratives.add(_NarrativeInsight(
      headline: 'Month-end forecast: ${_fmt(projected)}',
      detail: projDelta >= 0
          ? '+${projDelta.toStringAsFixed(1)}% above last month (${_fmt(totalLast)})'
          : '${projDelta.toStringAsFixed(1)}% below last month — great pace!',
      icon: CupertinoIcons.chart_bar_alt_fill,
      level: level,
    ));
  }

  // 2. Category anomaly
  final anomalous = topCats.where((c) => c.isAnomalous).toList();
  if (anomalous.isNotEmpty) {
    final top = anomalous.first;
    final mult = top.threeMonthAvg > 0 ? top.thisMonth / top.threeMonthAvg : 0.0;
    narratives.add(_NarrativeInsight(
      headline: '${top.emoji} ${top.name} spike detected',
      detail:
          '${_fmt(top.thisMonth)} this month — ${mult.toStringAsFixed(1)}× your 3-month average of ${_fmt(top.threeMonthAvg)}',
      icon: CupertinoIcons.exclamationmark_triangle_fill,
      level: _InsightLevel.warning,
    ));
  }

  // 3. Savings rate narrative
  if (incomeThis > 0) {
    final rate = ((incomeThis - totalThis) / incomeThis) * 100;
    final level = rate >= 20
        ? _InsightLevel.positive
        : rate >= 5
            ? _InsightLevel.neutral
            : _InsightLevel.alert;
    narratives.add(_NarrativeInsight(
      headline: 'Savings rate: ${rate.clamp(-99, 100).toStringAsFixed(1)}%',
      detail: rate >= 20
          ? 'Excellent! You\'re saving ${_fmt(incomeThis - totalThis)} of ${_fmt(incomeThis)}'
          : rate >= 5
              ? 'Moderate — aim for 20%+ to build strong reserves'
              : 'Spending exceeds income this month — review your budgets',
      icon: rate >= 20
          ? CupertinoIcons.checkmark_seal_fill
          : CupertinoIcons.chart_pie_fill,
      level: level,
    ));
  }

  // 4. Top merchant share
  if (top3Merchants.isNotEmpty && totalThis > 0) {
    final top = top3Merchants.first;
    final share = (top.value / totalThis * 100).toStringAsFixed(1);
    narratives.add(_NarrativeInsight(
      headline: '${top.key} — $share% of spend',
      detail:
          '${_fmt(top.value)} this month. Top 3 merchants account for ${_fmt(top3Merchants.fold(0.0, (s, e) => s + e.value))} total.',
      icon: CupertinoIcons.building_2_fill,
      level: _InsightLevel.neutral,
    ));
  }

  // 5. Heaviest spending day
  final maxDow = dow.reduce(math.max);
  if (maxDow > 0) {
    final maxIdx = dow.indexOf(maxDow);
    final totalDow = dow.fold(0.0, (a, b) => a + b);
    final pct = (maxDow / totalDow * 100).toStringAsFixed(1);
    narratives.add(_NarrativeInsight(
      headline: '${_dowName(maxIdx)}s are your peak spend day',
      detail:
          '${_fmt(maxDow)} on ${_dowName(maxIdx)}s — $pct% of this month\'s expenses',
      icon: CupertinoIcons.calendar_today,
      level: _InsightLevel.neutral,
    ));
  }

  // 6. MoM summary
  if (totalLast > 0) {
    final pct = ((totalThis - totalLast) / totalLast * 100);
    final level = pct > 15
        ? _InsightLevel.warning
        : pct < -10
            ? _InsightLevel.positive
            : _InsightLevel.neutral;
    narratives.add(_NarrativeInsight(
      headline: pct >= 0
          ? '+${pct.toStringAsFixed(1)}% vs last month'
          : '${pct.toStringAsFixed(1)}% vs last month',
      detail:
          '${_fmt(totalThis)} spent so far (day $dayOfMonth) vs ${_fmt(totalLast)} all of last month',
      icon: pct >= 0
          ? CupertinoIcons.arrow_up_right_circle_fill
          : CupertinoIcons.arrow_down_right_circle_fill,
      level: level,
    ));
  }

  // 7. Average monthly trend (3-mo)
  if (totalTwo > 0 && totalThree > 0) {
    final threeMonthAvg = (totalLast + totalTwo + totalThree) / 3;
    narratives.add(_NarrativeInsight(
      headline: '3-month avg: ${_fmt(threeMonthAvg)}/mo',
      detail: totalThis < threeMonthAvg * 0.9
          ? 'You\'re spending below average — ${_fmt(threeMonthAvg - totalThis)} under pace'
          : totalThis > threeMonthAvg * 1.1
              ? 'Trending ${((totalThis / threeMonthAvg - 1) * 100).toStringAsFixed(0)}% above your rolling average'
              : 'Spending is in line with your rolling average',
      icon: CupertinoIcons.waveform_path,
      level: _InsightLevel.neutral,
    ));
  }

  return _SpendIntelData(
    narratives: narratives,
    categoryDrifts: topCats,
    dowSpend: dow,
    totalThisMonth: totalThis,
    totalLastMonth: totalLast,
    projectedMonthEnd: projected,
    incomeThisMonth: incomeThis,
    dayOfMonth: dayOfMonth,
    daysInMonth: daysInMonth,
    topMerchants: top3Merchants,
    hasData: true,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Section header
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.xs),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: isDark
              ? Colors.white.withValues(alpha: 0.35)
              : Colors.black.withValues(alpha: 0.35),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Narrative carousel — auto-cycling, swipeable
// ─────────────────────────────────────────────────────────────────────────────

class _NarrativeCarousel extends StatefulWidget {
  final List<_NarrativeInsight> insights;
  final bool isDark;

  const _NarrativeCarousel({required this.insights, required this.isDark});

  @override
  State<_NarrativeCarousel> createState() => _NarrativeCarouselState();
}

class _NarrativeCarouselState extends State<_NarrativeCarousel> {
  int _page = 0;
  late final PageController _ctrl;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _ctrl = PageController();
    if (widget.insights.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 4), (_) {
        if (!mounted) return;
        final next = (_page + 1) % widget.insights.length;
        _ctrl.animateToPage(
          next,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 88,
          child: PageView.builder(
            controller: _ctrl,
            itemCount: widget.insights.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (_, i) =>
                _NarrativeCard(insight: widget.insights[i], isDark: widget.isDark),
          ),
        ),
        if (widget.insights.length > 1) ...[
          const SizedBox(height: Spacing.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.insights.length, (i) {
              final active = i == _page;
              final color = widget.insights[i].color(widget.isDark);
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 2.5),
                width: active ? 18 : 5,
                height: 3,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(Radii.full),
                  color: active ? color : color.withValues(alpha: 0.25),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}

class _NarrativeCard extends StatelessWidget {
  final _NarrativeInsight insight;
  final bool isDark;

  const _NarrativeCard({required this.insight, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final accent = insight.color(isDark);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 1),
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.lg),
        color: accent.withValues(alpha: isDark ? 0.08 : 0.06),
        border: Border.all(color: accent.withValues(alpha: 0.25), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(Radii.md),
            ),
            child: Icon(insight.icon, size: 18, color: accent),
          ),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  insight.headline,
                  style: TextStyle(
                    fontSize: TypeScale.footnote,
                    fontWeight: FontWeight.w700,
                    color: accent,
                    height: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  insight.detail,
                  style: TextStyle(
                    fontSize: TypeScale.caption,
                    color: AppStyles.getSecondaryTextColor(context),
                    height: 1.35,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
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
// Month forecast bar
// ─────────────────────────────────────────────────────────────────────────────

class _ForecastBar extends StatelessWidget {
  final _SpendIntelData data;
  final bool isDark;

  const _ForecastBar({required this.data, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final elapsed = data.monthElapsedFraction.clamp(0.0, 1.0);
    final spendFrac = data.projectedMonthEnd > 0
        ? (data.totalThisMonth / data.projectedMonthEnd).clamp(0.0, 1.0)
        : elapsed;

    final barColor = data.momChange > 20
        ? AppStyles.plasmaRed
        : data.momChange > 5
            ? AppStyles.accentOrange
            : AppStyles.bioGreen;

    final trackColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Day ${data.dayOfMonth} of ${data.daysInMonth}',
              style: TextStyle(
                fontSize: TypeScale.caption,
                color: AppStyles.getSecondaryTextColor(context),
              ),
            ),
            Row(
              children: [
                Text(
                  _fmt(data.totalThisMonth),
                  style: TextStyle(
                    fontSize: TypeScale.caption,
                    fontWeight: FontWeight.w700,
                    color: AppStyles.getTextColor(context),
                  ),
                ),
                Text(
                  '  →  ${_fmt(data.projectedMonthEnd)}',
                  style: TextStyle(
                    fontSize: TypeScale.caption,
                    color: barColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: Spacing.xs),
        Stack(
          children: [
            // track
            Container(
              height: 6,
              decoration: BoxDecoration(
                color: trackColor,
                borderRadius: BorderRadius.circular(Radii.full),
              ),
            ),
            // spend fill
            FractionallySizedBox(
              widthFactor: spendFrac,
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [barColor.withValues(alpha: 0.7), barColor],
                  ),
                  borderRadius: BorderRadius.circular(Radii.full),
                ),
              ),
            ),
            // day marker line
            Positioned(
              left: 0,
              right: 0,
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: elapsed,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    width: 1.5,
                    height: 10,
                    color: Colors.white.withValues(alpha: 0.6),
                    margin: const EdgeInsets.only(top: -2),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: Spacing.xs),
        Text(
          data.totalLastMonth > 0
              ? '${data.momChange >= 0 ? '+' : ''}${data.momChange.toStringAsFixed(1)}% vs last month\'s ${_fmt(data.totalLastMonth)}'
              : 'At ${_fmt(data.projectedMonthEnd > 0 ? data.totalThisMonth / data.dayOfMonth : 0)}/day pace',
          style: TextStyle(
            fontSize: TypeScale.caption,
            color: barColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Category drift row — horizontal scrollable cards
// ─────────────────────────────────────────────────────────────────────────────

class _CategoryDriftRow extends StatelessWidget {
  final List<_CategoryDrift> drifts;
  final bool isDark;

  const _CategoryDriftRow({required this.drifts, required this.isDark});

  @override
  Widget build(BuildContext context) {
    if (drifts.isEmpty) {
      return Text(
        'Add categorised transactions to see drift.',
        style: TextStyle(
          fontSize: TypeScale.caption,
          color: AppStyles.getSecondaryTextColor(context),
        ),
      );
    }
    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: drifts.length,
        separatorBuilder: (_, __) => const SizedBox(width: Spacing.sm),
        itemBuilder: (_, i) => _CategoryDriftCard(drift: drifts[i], isDark: isDark),
      ),
    );
  }
}

class _CategoryDriftCard extends StatelessWidget {
  final _CategoryDrift drift;
  final bool isDark;

  const _CategoryDriftCard({required this.drift, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final delta = drift.momDelta;
    final isUp = delta >= 0;
    final barColor = drift.isAnomalous
        ? AppStyles.plasmaRed
        : isUp
            ? AppStyles.accentOrange
            : AppStyles.bioGreen;
    final maxForBar = math.max(drift.thisMonth, drift.lastMonth);
    final thisFrac =
        maxForBar > 0 ? (drift.thisMonth / maxForBar).clamp(0.0, 1.0) : 0.0;
    final lastFrac =
        maxForBar > 0 ? (drift.lastMonth / maxForBar).clamp(0.0, 1.0) : 0.0;

    return Container(
      width: 88,
      padding: const EdgeInsets.all(Spacing.sm),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(Radii.md),
        border: drift.isAnomalous
            ? Border.all(color: AppStyles.plasmaRed.withValues(alpha: 0.4), width: 1)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Category label + delta
          Row(
            children: [
              Text(drift.emoji, style: const TextStyle(fontSize: 11)),
              const SizedBox(width: 3),
              Expanded(
                child: Text(
                  drift.name,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: AppStyles.getSecondaryTextColor(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          // Amount
          Text(
            _fmt(drift.thisMonth),
            style: TextStyle(
              fontSize: TypeScale.caption,
              fontWeight: FontWeight.w700,
              color: AppStyles.getTextColor(context),
            ),
          ),
          // Mini twin bar
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // this month bar
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 14 * thisFrac + 2,
                      decoration: BoxDecoration(
                        color: barColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 2),
              // last month bar
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 14 * lastFrac + 2,
                      decoration: BoxDecoration(
                        color: barColor.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              // Delta badge
              Text(
                delta == 0
                    ? '—'
                    : '${isUp ? '↑' : '↓'}${delta.abs().toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: barColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Day-of-week heatmap
// ─────────────────────────────────────────────────────────────────────────────

class _DowHeatmap extends StatelessWidget {
  final List<double> dowSpend; // 0=Mon..6=Sun
  final bool isDark;

  const _DowHeatmap({required this.dowSpend, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final maxVal = dowSpend.reduce(math.max);
    if (maxVal == 0) {
      return Text(
        'No spending recorded this month yet.',
        style: TextStyle(
          fontSize: TypeScale.caption,
          color: AppStyles.getSecondaryTextColor(context),
        ),
      );
    }
    const barH = 40.0;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(7, (i) {
        final fraction = maxVal > 0 ? (dowSpend[i] / maxVal).clamp(0.0, 1.0) : 0.0;
        final isPeak = dowSpend[i] == maxVal;
        final h = fraction * barH;
        final color = isPeak
            ? AppStyles.novaPurple
            : Color.lerp(
                AppStyles.novaPurple.withValues(alpha: 0.25),
                AppStyles.novaPurple.withValues(alpha: 0.7),
                fraction,
              )!;

        return Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isPeak)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    _fmt(dowSpend[i]),
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      color: AppStyles.novaPurple,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              Container(
                height: h > 0 ? h : 2,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _dowName(i).substring(0, 2),
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: isPeak ? FontWeight.w700 : FontWeight.w500,
                  color: isPeak
                      ? AppStyles.novaPurple
                      : AppStyles.getSecondaryTextColor(context),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Top merchants minibar
// ─────────────────────────────────────────────────────────────────────────────

class _TopMerchantsSection extends StatelessWidget {
  final List<MapEntry<String, double>> merchants;
  final double totalThisMonth;
  final bool isDark;

  const _TopMerchantsSection({
    required this.merchants,
    required this.totalThisMonth,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    if (merchants.isEmpty || totalThisMonth == 0) return const SizedBox.shrink();
    final colors = [AppStyles.aetherTeal, AppStyles.accentBlue, AppStyles.solarGold];
    return Column(
      children: List.generate(merchants.length, (i) {
        final m = merchants[i];
        final share = (m.value / totalThisMonth).clamp(0.0, 1.0);
        final color = colors[i % colors.length];
        return Padding(
          padding: const EdgeInsets.only(bottom: Spacing.xs),
          child: Row(
            children: [
              SizedBox(
                width: 120,
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
                        child: Container(
                          height: 5,
                          color: color,
                        ),
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
            ],
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Main widget
// ─────────────────────────────────────────────────────────────────────────────

class InsightsWidget extends BaseDashboardWidget {
  const InsightsWidget({
    required super.config,
    super.onTap,
    super.key,
  });

  @override
  Widget buildContent(
    BuildContext context, {
    required int columnSpan,
    required int rowSpan,
    required double width,
    required double height,
  }) {
    return RepaintBoundary(
      child: Consumer2<TransactionsController, BudgetsController>(
        builder: (context, txCtrl, budgetsCtrl, _) {
          final data = _computeSpendIntel(
              txCtrl.transactions, budgetsCtrl.budgets);
          final isDark = Theme.of(context).brightness == Brightness.dark;

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── AI Insight Carousel ────────────────────────────────
                _NarrativeCarousel(insights: data.narratives, isDark: isDark),

                const SizedBox(height: Spacing.md),

                // ── Month Forecast ─────────────────────────────────────
                if (data.hasData && data.projectedMonthEnd > 0) ...[
                  _SectionLabel('MONTH FORECAST'),
                  _ForecastBar(data: data, isDark: isDark),
                  const SizedBox(height: Spacing.md),
                ],

                // ── Category Pulse ─────────────────────────────────────
                if (data.categoryDrifts.isNotEmpty) ...[
                  _SectionLabel('CATEGORY PULSE  ·  this month vs last'),
                  _CategoryDriftRow(drifts: data.categoryDrifts, isDark: isDark),
                  const SizedBox(height: Spacing.md),
                ],

                // ── Spend Rhythm ───────────────────────────────────────
                if (data.hasData) ...[
                  _SectionLabel('SPEND RHYTHM  ·  by day of week'),
                  _DowHeatmap(dowSpend: data.dowSpend, isDark: isDark),
                  const SizedBox(height: Spacing.md),
                ],

                // ── Top Merchants ──────────────────────────────────────
                if (data.topMerchants.isNotEmpty && data.totalThisMonth > 0) ...[
                  _SectionLabel('TOP MERCHANTS  ·  by share'),
                  _TopMerchantsSection(
                    merchants: data.topMerchants,
                    totalThisMonth: data.totalThisMonth,
                    isDark: isDark,
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
