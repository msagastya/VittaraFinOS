import 'package:shared_preferences/shared_preferences.dart';
import 'package:vittara_fin_os/logic/transaction_model.dart';
import 'behavioral_fingerprint.dart';
import 'pattern_detector.dart';

// ─── T-089: NarrativeLens enum ────────────────────────────────────────────────

/// 8-value lens that drives which angle the monthly narrative takes.
/// Each lens produces a specific, data-driven story — never generic.
enum NarrativeLens {
  anomalySpotted,     // Unusual spike detected (highest priority)
  budgetExceeded,     // A budget was blown through
  goalOnTrack,        // A goal made meaningful progress
  savingStreak,       // Consecutive months of positive savings
  newHabitDetected,   // New recurring merchant appeared
  biggestSpike,       // Largest MoM category % increase
  investmentMilestone,// Investment crossed a round number or matured
  cashflowHealthy,    // Default: balanced, healthy month
}

// ─── MonthlyNarrative model ───────────────────────────────────────────────────

/// A paragraph-style explanation of the month — not a report, a narrative.
class MonthlyNarrative {
  final int year;
  final int month;

  /// 2-4 sentence paragraph explaining what happened this month.
  final String paragraph;

  /// One-line headline for card display.
  final String headline;

  /// Positive highlight (optional).
  final String? highlight;

  /// One thing to watch (optional).
  final String? watchOut;

  /// Which lens was used to generate this narrative.
  final NarrativeLens lens;

  const MonthlyNarrative({
    required this.year,
    required this.month,
    required this.paragraph,
    required this.headline,
    this.highlight,
    this.watchOut,
    this.lens = NarrativeLens.cashflowHealthy,
  });

  /// Plain-text export for clipboard/share.
  String toShareText() {
    final sb = StringBuffer();
    sb.writeln(headline);
    sb.writeln();
    sb.writeln(paragraph);
    if (highlight != null) {
      sb.writeln();
      sb.writeln('✓ $highlight');
    }
    if (watchOut != null) {
      sb.writeln();
      sb.writeln('⚠ $watchOut');
    }
    return sb.toString().trim();
  }
}

// ─── T-090/T-091/T-092: MonthlyNarrativeGenerator ────────────────────────────

class MonthlyNarrativeGenerator {
  MonthlyNarrativeGenerator._();

  // T-091: selectLens() — priority order, skipping last month's lens
  static Future<NarrativeLens> selectLens({
    required List<Transaction> transactions,
    required int year,
    required int month,
    List<Map<String, dynamic>>? budgets,
    List<Map<String, dynamic>>? goals,
    List<Map<String, dynamic>>? investments,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final lastLensName = prefs.getString('last_narrative_lens');
    final lastLens = lastLensName != null
        ? NarrativeLens.values.where((l) => l.name == lastLensName).firstOrNull
        : null;

    final allTx = transactions;
    final monthTx = allTx.where((t) =>
        t.dateTime.year == year && t.dateTime.month == month).toList();
    final prevDate = DateTime(year, month - 1, 1);
    final prevTx = allTx.where((t) =>
        t.dateTime.year == prevDate.year &&
        t.dateTime.month == prevDate.month).toList();

    // Priority order: anomaly > budget > goal > streak > habit > spike > investment > healthy
    final priority = [
      NarrativeLens.anomalySpotted,
      NarrativeLens.budgetExceeded,
      NarrativeLens.goalOnTrack,
      NarrativeLens.savingStreak,
      NarrativeLens.newHabitDetected,
      NarrativeLens.biggestSpike,
      NarrativeLens.investmentMilestone,
      NarrativeLens.cashflowHealthy,
    ];

    for (final lens in priority) {
      if (lens == lastLens) continue; // skip lens used last month
      if (_lensIsSupported(
        lens: lens,
        monthTx: monthTx,
        prevTx: prevTx,
        allTx: allTx,
        year: year,
        month: month,
        budgets: budgets,
        goals: goals,
        investments: investments,
      )) {
        await prefs.setString('last_narrative_lens', lens.name);
        return lens;
      }
    }
    // Fallback
    return NarrativeLens.cashflowHealthy;
  }

  // T-090: Check if a lens has enough data support
  static bool _lensIsSupported({
    required NarrativeLens lens,
    required List<Transaction> monthTx,
    required List<Transaction> prevTx,
    required List<Transaction> allTx,
    required int year,
    required int month,
    List<Map<String, dynamic>>? budgets,
    List<Map<String, dynamic>>? goals,
    List<Map<String, dynamic>>? investments,
  }) {
    switch (lens) {
      case NarrativeLens.anomalySpotted:
        return _hasAnomaly(monthTx, prevTx);
      case NarrativeLens.budgetExceeded:
        return _hasBudgetExceeded(monthTx, budgets, year, month);
      case NarrativeLens.goalOnTrack:
        return _hasGoalProgress(goals);
      case NarrativeLens.savingStreak:
        return _hasSavingStreak(allTx, year, month);
      case NarrativeLens.newHabitDetected:
        return _hasNewHabit(monthTx, prevTx);
      case NarrativeLens.biggestSpike:
        return _hasCategorySpike(monthTx, prevTx);
      case NarrativeLens.investmentMilestone:
        return _hasInvestmentMilestone(monthTx, investments);
      case NarrativeLens.cashflowHealthy:
        return true;
    }
  }

  // ─── Lens support checks ────────────────────────────────────────────────────

  static bool _hasAnomaly(List<Transaction> monthTx, List<Transaction> prevTx) {
    final prevExpense = prevTx
        .where((t) => t.type == TransactionType.expense)
        .fold(0.0, (s, t) => s + t.amount.abs());
    final monthExpense = monthTx
        .where((t) => t.type == TransactionType.expense)
        .fold(0.0, (s, t) => s + t.amount.abs());
    if (prevExpense == 0) return false;
    final delta = (monthExpense - prevExpense) / prevExpense * 100;
    return delta > 35; // 35%+ spike is anomalous
  }

  static bool _hasBudgetExceeded(
    List<Transaction> monthTx,
    List<Map<String, dynamic>>? budgets,
    int year,
    int month,
  ) {
    if (budgets == null || budgets.isEmpty) return false;
    for (final b in budgets) {
      final category = b['category'] as String? ?? '';
      final limit = (b['amount'] as num?)?.toDouble() ?? 0;
      if (limit == 0) continue;
      final spent = monthTx
          .where((t) =>
              t.type == TransactionType.expense &&
              ((t.metadata?['categoryName'] as String?) ?? '') == category)
          .fold(0.0, (s, t) => s + t.amount.abs());
      if (spent > limit) return true;
    }
    return false;
  }

  static bool _hasGoalProgress(List<Map<String, dynamic>>? goals) {
    if (goals == null || goals.isEmpty) return false;
    for (final g in goals) {
      final target = (g['targetAmount'] as num?)?.toDouble() ?? 0;
      final saved = (g['currentAmount'] as num?)?.toDouble() ?? 0;
      if (target > 0 && saved > 0 && saved < target) return true;
    }
    return false;
  }

  static bool _hasSavingStreak(
      List<Transaction> allTx, int year, int month) {
    int streak = 0;
    for (int i = 0; i < 3; i++) {
      final d = DateTime(year, month - i, 1);
      final income = allTx
          .where((t) =>
              t.type == TransactionType.income &&
              t.dateTime.year == d.year &&
              t.dateTime.month == d.month)
          .fold(0.0, (s, t) => s + t.amount);
      final expense = allTx
          .where((t) =>
              t.type == TransactionType.expense &&
              t.dateTime.year == d.year &&
              t.dateTime.month == d.month)
          .fold(0.0, (s, t) => s + t.amount.abs());
      if (income > expense) streak++;
    }
    return streak >= 2;
  }

  static bool _hasNewHabit(
      List<Transaction> monthTx, List<Transaction> prevTx) {
    final prevMerchants = prevTx
        .map((t) => (t.metadata?['merchant'] as String?) ?? t.description)
        .where((m) => m.isNotEmpty)
        .toSet();
    final newMerchants = monthTx
        .where((t) => t.type == TransactionType.expense)
        .map((t) => (t.metadata?['merchant'] as String?) ?? t.description)
        .where((m) => m.isNotEmpty && !prevMerchants.contains(m))
        .toSet();
    // Count how many times each new merchant appears
    for (final m in newMerchants) {
      final count = monthTx
          .where((t) =>
              ((t.metadata?['merchant'] as String?) ?? t.description) == m)
          .length;
      if (count >= 2) return true; // appeared 2+ times = habit forming
    }
    return false;
  }

  static bool _hasCategorySpike(
      List<Transaction> monthTx, List<Transaction> prevTx) {
    if (prevTx.isEmpty) return false;
    final prevCats = <String, double>{};
    for (final t in prevTx.where((t) => t.type == TransactionType.expense)) {
      final cat = (t.metadata?['categoryName'] as String?) ?? 'Other';
      prevCats[cat] = (prevCats[cat] ?? 0) + t.amount.abs();
    }
    final monthCats = <String, double>{};
    for (final t in monthTx.where((t) => t.type == TransactionType.expense)) {
      final cat = (t.metadata?['categoryName'] as String?) ?? 'Other';
      monthCats[cat] = (monthCats[cat] ?? 0) + t.amount.abs();
    }
    for (final entry in monthCats.entries) {
      final prev = prevCats[entry.key] ?? 0;
      if (prev > 0 && ((entry.value - prev) / prev) > 0.5) return true;
    }
    return false;
  }

  static bool _hasInvestmentMilestone(
      List<Transaction> monthTx, List<Map<String, dynamic>>? investments) {
    // Check if any investment transaction happened this month
    final hasInvTx = monthTx.any((t) => t.type == TransactionType.investment);
    if (!hasInvTx) return false;
    if (investments == null) return true;
    // Check if any investment crossed a round-number milestone
    for (final inv in investments) {
      final current = (inv['currentValue'] as num?)?.toDouble() ?? 0;
      final roundMilestones = [10000, 25000, 50000, 100000, 250000, 500000, 1000000];
      final invested = (inv['amount'] as num?)?.toDouble() ?? 0;
      for (final milestone in roundMilestones) {
        if (current >= milestone && invested < milestone) return true;
      }
    }
    return true;
  }

  // ─── T-092: Main generate() — now lens-aware ───────────────────────────────

  static MonthlyNarrative generate({
    required List<Transaction> transactions,
    required int year,
    required int month,
    BehavioralFingerprint? fingerprint,
    SpendingPatterns? patterns,
    NarrativeLens lens = NarrativeLens.cashflowHealthy,
    List<Map<String, dynamic>>? budgets,
    List<Map<String, dynamic>>? goals,
    List<Map<String, dynamic>>? investments,
  }) {
    final monthTx = transactions.where((t) {
      return t.dateTime.year == year && t.dateTime.month == month;
    }).toList();

    if (monthTx.isEmpty) {
      return MonthlyNarrative(
        year: year,
        month: month,
        paragraph: 'No transactions recorded for this month yet.',
        headline: 'No data yet',
        lens: lens,
      );
    }

    final prevDate = DateTime(year, month - 1, 1);
    final prevTx = transactions.where((t) =>
        t.dateTime.year == prevDate.year &&
        t.dateTime.month == prevDate.month).toList();

    final totalExpense = monthTx
        .where((t) => t.type == TransactionType.expense)
        .fold(0.0, (s, t) => s + t.amount.abs());
    final totalIncome = monthTx
        .where((t) => t.type == TransactionType.income)
        .fold(0.0, (s, t) => s + t.amount);
    final totalInvestments = monthTx
        .where((t) => t.type == TransactionType.investment)
        .fold(0.0, (s, t) => s + t.amount.abs());

    final prevExpense = prevTx
        .where((t) => t.type == TransactionType.expense)
        .fold(0.0, (s, t) => s + t.amount.abs());
    final expenseDelta = prevExpense > 0
        ? ((totalExpense - prevExpense) / prevExpense * 100)
        : 0.0;

    final savingsRate =
        totalIncome > 0 ? (totalIncome - totalExpense) / totalIncome * 100 : 0.0;

    final monthName = _monthName(month);
    final isDisciplined = fingerprint != null && fingerprint.disciplinedScore > 60;

    // Route to lens-specific narrative builder
    MonthlyNarrative? result;
    switch (lens) {
      case NarrativeLens.anomalySpotted:
        result = _buildAnomalyNarrative(
          monthTx: monthTx, prevTx: prevTx, monthName: monthName,
          totalExpense: totalExpense, prevExpense: prevExpense,
          expenseDelta: expenseDelta, year: year, month: month,
        );
        break;
      case NarrativeLens.budgetExceeded:
        result = _buildBudgetExceededNarrative(
          monthTx: monthTx, budgets: budgets, monthName: monthName,
          totalExpense: totalExpense, expenseDelta: expenseDelta,
          year: year, month: month,
        );
        break;
      case NarrativeLens.goalOnTrack:
        result = _buildGoalOnTrackNarrative(
          goals: goals, monthTx: monthTx, monthName: monthName,
          totalInvestments: totalInvestments, savingsRate: savingsRate,
          year: year, month: month,
        );
        break;
      case NarrativeLens.savingStreak:
        result = _buildSavingStreakNarrative(
          monthName: monthName, savingsRate: savingsRate,
          totalIncome: totalIncome, totalExpense: totalExpense,
          totalInvestments: totalInvestments, isDisciplined: isDisciplined,
          year: year, month: month,
        );
        break;
      case NarrativeLens.newHabitDetected:
        result = _buildNewHabitNarrative(
          monthTx: monthTx, prevTx: prevTx, monthName: monthName,
          totalExpense: totalExpense, expenseDelta: expenseDelta,
          year: year, month: month,
        );
        break;
      case NarrativeLens.biggestSpike:
        result = _buildBiggestSpikeNarrative(
          monthTx: monthTx, prevTx: prevTx, monthName: monthName,
          totalExpense: totalExpense, expenseDelta: expenseDelta,
          year: year, month: month,
        );
        break;
      case NarrativeLens.investmentMilestone:
        result = _buildInvestmentMilestoneNarrative(
          monthTx: monthTx, investments: investments, monthName: monthName,
          totalInvestments: totalInvestments, totalIncome: totalIncome,
          savingsRate: savingsRate, year: year, month: month,
        );
        break;
      case NarrativeLens.cashflowHealthy:
        break;
    }

    return result ?? _buildCashflowHealthyNarrative(
      monthTx: monthTx, monthName: monthName,
      totalExpense: totalExpense, totalIncome: totalIncome,
      totalInvestments: totalInvestments, expenseDelta: expenseDelta,
      savingsRate: savingsRate, isDisciplined: isDisciplined,
      year: year, month: month,
    );
  }

  // ─── T-090/T-092: Lens-specific builders ───────────────────────────────────

  /// Anomaly: 35%+ expense spike vs last month, names the top merchant
  static MonthlyNarrative _buildAnomalyNarrative({
    required List<Transaction> monthTx,
    required List<Transaction> prevTx,
    required String monthName,
    required double totalExpense,
    required double prevExpense,
    required double expenseDelta,
    required int year,
    required int month,
  }) {
    // Find the biggest single expense
    final biggest = monthTx
        .where((t) => t.type == TransactionType.expense)
        .fold<Transaction?>(null, (best, t) =>
            best == null || t.amount.abs() > best.amount.abs() ? t : best);

    final merchantName = biggest != null
        ? ((biggest.metadata?['merchant'] as String?) ??
            biggest.description.split(' ').first)
        : 'an unknown vendor';

    final biggestAmt = biggest != null ? _fmt(biggest.amount.abs()) : '0';

    // Top spiking category
    final prevCats = <String, double>{};
    for (final t in prevTx.where((t) => t.type == TransactionType.expense)) {
      final cat = (t.metadata?['categoryName'] as String?) ?? 'Other';
      prevCats[cat] = (prevCats[cat] ?? 0) + t.amount.abs();
    }
    final monthCats = <String, double>{};
    for (final t in monthTx.where((t) => t.type == TransactionType.expense)) {
      final cat = (t.metadata?['categoryName'] as String?) ?? 'Other';
      monthCats[cat] = (monthCats[cat] ?? 0) + t.amount.abs();
    }
    String spikeCat = 'expenses';
    double spikePercent = expenseDelta;
    for (final entry in monthCats.entries) {
      final prev = prevCats[entry.key] ?? 0;
      if (prev > 0) {
        final pct = (entry.value - prev) / prev * 100;
        if (pct > spikePercent) {
          spikePercent = pct;
          spikeCat = entry.key;
        }
      }
    }

    final para = '$monthName saw an unusual spending pattern — total expenses '
        'jumped to ₹${_fmt(totalExpense)}, up ${expenseDelta.toStringAsFixed(0)}% '
        'from ₹${_fmt(prevExpense)} last month. '
        '$spikeCat drove most of the spike (${spikePercent.toStringAsFixed(0)}% above last month). '
        'The single biggest outflow was ₹$biggestAmt at $merchantName. '
        'Worth reviewing if this was a one-time cost or something to plan for.';

    return MonthlyNarrative(
      year: year,
      month: month,
      paragraph: para,
      headline: 'Spending spike — ${expenseDelta.toStringAsFixed(0)}% above last month',
      highlight: null,
      watchOut: '$spikeCat alone jumped ${spikePercent.toStringAsFixed(0)}% vs last month.',
      lens: NarrativeLens.anomalySpotted,
    );
  }

  /// Budget exceeded: names the budget, by how much, and the top merchant in it
  static MonthlyNarrative? _buildBudgetExceededNarrative({
    required List<Transaction> monthTx,
    List<Map<String, dynamic>>? budgets,
    required String monthName,
    required double totalExpense,
    required double expenseDelta,
    required int year,
    required int month,
  }) {
    if (budgets == null) return null;

    String? exceededBudget;
    double? budgetLimit;
    double? actualSpend;

    for (final b in budgets) {
      final category = b['category'] as String? ?? '';
      final limit = (b['amount'] as num?)?.toDouble() ?? 0;
      if (limit == 0) continue;
      final spent = monthTx
          .where((t) =>
              t.type == TransactionType.expense &&
              ((t.metadata?['categoryName'] as String?) ?? '') == category)
          .fold(0.0, (s, t) => s + t.amount.abs());
      if (spent > limit && (actualSpend == null || spent > actualSpend!)) {
        exceededBudget = category;
        budgetLimit = limit;
        actualSpend = spent;
      }
    }

    if (exceededBudget == null || budgetLimit == null || actualSpend == null) {
      return null;
    }

    // Top merchant in that category
    final catTx = monthTx
        .where((t) =>
            t.type == TransactionType.expense &&
            ((t.metadata?['categoryName'] as String?) ?? '') == exceededBudget)
        .toList()
      ..sort((a, b) => b.amount.abs().compareTo(a.amount.abs()));
    final topMerchant = catTx.isNotEmpty
        ? ((catTx.first.metadata?['merchant'] as String?) ?? catTx.first.description.split(' ').first)
        : 'multiple merchants';

    final overBy = actualSpend - budgetLimit;
    final para = 'Your $exceededBudget budget was exceeded in $monthName — '
        'you spent ₹${_fmt(actualSpend)} against a limit of ₹${_fmt(budgetLimit)}, '
        '₹${_fmt(overBy)} over. '
        '$topMerchant was the biggest contributor in this category. '
        'Total spending across all categories was ₹${_fmt(totalExpense)}'
        '${expenseDelta.abs() > 5 ? ", ${expenseDelta > 0 ? 'up' : 'down'} ${expenseDelta.abs().toStringAsFixed(0)}% vs last month" : ""}.';

    return MonthlyNarrative(
      year: year,
      month: month,
      paragraph: para,
      headline: '$exceededBudget budget exceeded by ₹${_fmt(overBy)}',
      watchOut: 'Spent ₹${_fmt(overBy)} more than budgeted in $exceededBudget.',
      lens: NarrativeLens.budgetExceeded,
    );
  }

  /// Goal on track: names the goal, progress %, and the remaining amount
  static MonthlyNarrative? _buildGoalOnTrackNarrative({
    List<Map<String, dynamic>>? goals,
    required List<Transaction> monthTx,
    required String monthName,
    required double totalInvestments,
    required double savingsRate,
    required int year,
    required int month,
  }) {
    if (goals == null || goals.isEmpty) return null;

    Map<String, dynamic>? bestGoal;
    double bestProgress = 0;

    for (final g in goals) {
      final target = (g['targetAmount'] as num?)?.toDouble() ?? 0;
      final saved = (g['currentAmount'] as num?)?.toDouble() ?? 0;
      if (target > 0 && saved > 0 && saved < target) {
        final pct = saved / target * 100;
        if (pct > bestProgress) {
          bestProgress = pct;
          bestGoal = g;
        }
      }
    }

    if (bestGoal == null) return null;

    final goalName = bestGoal['name'] as String? ?? 'your goal';
    final target = (bestGoal['targetAmount'] as num?)?.toDouble() ?? 0;
    final saved = (bestGoal['currentAmount'] as num?)?.toDouble() ?? 0;
    final remaining = target - saved;

    final para = 'Your "$goalName" goal is ${bestProgress.toStringAsFixed(0)}% complete — '
        '₹${_fmt(saved)} saved toward a target of ₹${_fmt(target)}. '
        '₹${_fmt(remaining)} left to go. '
        '${savingsRate > 20 ? 'With a savings rate of ${savingsRate.toStringAsFixed(0)}% this month, you\'re building momentum.' : 'Keep adding to it each month to stay on track.'}';

    return MonthlyNarrative(
      year: year,
      month: month,
      paragraph: para,
      headline: '"$goalName" is ${bestProgress.toStringAsFixed(0)}% of the way there',
      highlight: '₹${_fmt(saved)} saved — ₹${_fmt(remaining)} more to complete "$goalName".',
      lens: NarrativeLens.goalOnTrack,
    );
  }

  /// Saving streak: 2+ consecutive months of positive savings
  static MonthlyNarrative _buildSavingStreakNarrative({
    required String monthName,
    required double savingsRate,
    required double totalIncome,
    required double totalExpense,
    required double totalInvestments,
    required bool isDisciplined,
    required int year,
    required int month,
  }) {
    final saved = totalIncome - totalExpense;

    final para = isDisciplined
        ? 'Another solid month — you saved ₹${_fmt(saved.abs())} in $monthName, '
          'keeping your savings rate at ${savingsRate.toStringAsFixed(0)}% for at least the second month running. '
          '${totalInvestments > 0 ? "₹${_fmt(totalInvestments)} went into investments, building your portfolio alongside the streak. " : ""}'
          'Consistent saving compounds over time — this streak is your biggest financial asset.'
        : 'You\'ve been saving consistently — ₹${_fmt(saved.abs())} saved in $monthName '
          '(${savingsRate.toStringAsFixed(0)}% of income) for the second month in a row. '
          '${totalInvestments > 0 ? "₹${_fmt(totalInvestments)} also went into investments. " : ""}'
          'Two months in a row is how habits are built.';

    return MonthlyNarrative(
      year: year,
      month: month,
      paragraph: para,
      headline: 'Saving streak — ${savingsRate.toStringAsFixed(0)}% rate for 2+ months',
      highlight: '₹${_fmt(saved.abs())} saved in $monthName. Streak is alive.',
      lens: NarrativeLens.savingStreak,
    );
  }

  /// New habit: a merchant appeared 2+ times this month but not last month
  static MonthlyNarrative? _buildNewHabitNarrative({
    required List<Transaction> monthTx,
    required List<Transaction> prevTx,
    required String monthName,
    required double totalExpense,
    required double expenseDelta,
    required int year,
    required int month,
  }) {
    final prevMerchants = prevTx
        .map((t) => (t.metadata?['merchant'] as String?) ?? t.description)
        .where((m) => m.isNotEmpty)
        .toSet();

    // Find new merchant with highest frequency
    final merchantCount = <String, int>{};
    final merchantAmount = <String, double>{};
    for (final t in monthTx.where((t) => t.type == TransactionType.expense)) {
      final m = (t.metadata?['merchant'] as String?) ?? t.description.split(' ').first;
      if (m.isNotEmpty && !prevMerchants.contains(m)) {
        merchantCount[m] = (merchantCount[m] ?? 0) + 1;
        merchantAmount[m] = (merchantAmount[m] ?? 0) + t.amount.abs();
      }
    }

    if (merchantCount.isEmpty) return null;

    final topEntry = merchantCount.entries
        .where((e) => e.value >= 2)
        .fold<MapEntry<String, int>?>(
            null, (best, e) => best == null || e.value > best.value ? e : best);

    if (topEntry == null) return null;

    final habitName = topEntry.key;
    final habitCount = topEntry.value;
    final habitAmt = merchantAmount[habitName] ?? 0;

    final para = 'A new spending pattern appeared in $monthName: '
        '$habitName showed up $habitCount times, costing ₹${_fmt(habitAmt)} total — '
        'a merchant you hadn\'t visited last month. '
        'Whether it\'s a new gym, a new café, or a new subscription, '
        'it\'s now a regular part of your spending at roughly ₹${_fmt(habitAmt / habitCount)} per visit. '
        'Total spending for the month was ₹${_fmt(totalExpense)}.';

    return MonthlyNarrative(
      year: year,
      month: month,
      paragraph: para,
      headline: 'New habit detected — $habitName, $habitCount visits in $monthName',
      watchOut: '$habitName is new this month — ₹${_fmt(habitAmt)} total across $habitCount visits.',
      lens: NarrativeLens.newHabitDetected,
    );
  }

  /// Biggest spike: category with highest MoM % increase, top merchant in it
  static MonthlyNarrative? _buildBiggestSpikeNarrative({
    required List<Transaction> monthTx,
    required List<Transaction> prevTx,
    required String monthName,
    required double totalExpense,
    required double expenseDelta,
    required int year,
    required int month,
  }) {
    if (prevTx.isEmpty) return null;

    final prevCats = <String, double>{};
    for (final t in prevTx.where((t) => t.type == TransactionType.expense)) {
      final cat = (t.metadata?['categoryName'] as String?) ?? 'Other';
      prevCats[cat] = (prevCats[cat] ?? 0) + t.amount.abs();
    }
    final monthCats = <String, double>{};
    for (final t in monthTx.where((t) => t.type == TransactionType.expense)) {
      final cat = (t.metadata?['categoryName'] as String?) ?? 'Other';
      monthCats[cat] = (monthCats[cat] ?? 0) + t.amount.abs();
    }

    String? spikeCat;
    double spikePercent = 0;
    double spikeAmount = 0;
    for (final entry in monthCats.entries) {
      final prev = prevCats[entry.key] ?? 0;
      if (prev > 0) {
        final pct = (entry.value - prev) / prev * 100;
        if (pct > spikePercent) {
          spikePercent = pct;
          spikeCat = entry.key;
          spikeAmount = entry.value;
        }
      }
    }

    if (spikeCat == null) return null;

    // Top merchant in spiking category
    final catTx = monthTx
        .where((t) =>
            t.type == TransactionType.expense &&
            ((t.metadata?['categoryName'] as String?) ?? '') == spikeCat)
        .toList()
      ..sort((a, b) => b.amount.abs().compareTo(a.amount.abs()));
    final topMerchant = catTx.isNotEmpty
        ? ((catTx.first.metadata?['merchant'] as String?) ?? catTx.first.description.split(' ').first)
        : 'various merchants';

    final prevCatAmt = prevCats[spikeCat] ?? 0;
    final para = '$spikeCat spend jumped ${spikePercent.toStringAsFixed(0)}% in $monthName — '
        '₹${_fmt(spikeAmount)} vs ₹${_fmt(prevCatAmt)} last month. '
        '$topMerchant was the biggest contributor. '
        'Overall spending was ₹${_fmt(totalExpense)}'
        '${expenseDelta.abs() > 5 ? ", ${expenseDelta > 0 ? 'up' : 'down'} ${expenseDelta.abs().toStringAsFixed(0)}% vs last month" : ""}.';

    return MonthlyNarrative(
      year: year,
      month: month,
      paragraph: para,
      headline: '$spikeCat up ${spikePercent.toStringAsFixed(0)}% — biggest category mover',
      watchOut: '$spikeCat: ₹${_fmt(spikeAmount)} this month vs ₹${_fmt(prevCatAmt)} last month.',
      lens: NarrativeLens.biggestSpike,
    );
  }

  /// Investment milestone: crossed a round number or consistent investing
  static MonthlyNarrative _buildInvestmentMilestoneNarrative({
    required List<Transaction> monthTx,
    List<Map<String, dynamic>>? investments,
    required String monthName,
    required double totalInvestments,
    required double totalIncome,
    required double savingsRate,
    required int year,
    required int month,
  }) {
    // Find investment that crossed a milestone
    String? milestoneInvestment;
    double? milestoneValue;

    if (investments != null) {
      for (final inv in investments) {
        final current = (inv['currentValue'] as num?)?.toDouble() ?? 0;
        final invested = (inv['amount'] as num?)?.toDouble() ?? 0;
        final name = inv['name'] as String? ?? 'Investment';
        final roundMilestones = [10000, 25000, 50000, 100000, 250000, 500000, 1000000];
        for (final milestone in roundMilestones) {
          if (current >= milestone && invested < milestone) {
            milestoneInvestment = name;
            milestoneValue = current.toDouble();
            break;
          }
        }
        if (milestoneInvestment != null) break;
      }
    }

    String para;
    String headline;
    String? highlight;

    if (milestoneInvestment != null && milestoneValue != null) {
      para = 'Your investment "$milestoneInvestment" has crossed ₹${_fmt(milestoneValue)} — '
          'a meaningful milestone. '
          'You added ₹${_fmt(totalInvestments)} in new investments in $monthName'
          '${totalIncome > 0 ? ", keeping your investment rate at ${(totalInvestments / totalIncome * 100).toStringAsFixed(0)}% of income" : ""}. '
          'Compound growth takes time — you\'re building it.';
      headline = '"$milestoneInvestment" crossed ₹${_fmt(milestoneValue)}';
      highlight = '₹${_fmt(milestoneValue)} portfolio value reached for "$milestoneInvestment".';
    } else {
      para = 'You invested ₹${_fmt(totalInvestments)} in $monthName'
          '${totalIncome > 0 ? ", about ${(totalInvestments / totalIncome * 100).toStringAsFixed(0)}% of your income" : ""}. '
          'Consistent monthly investing, even in small amounts, '
          'is how long-term wealth is built. '
          '${savingsRate > 0 ? "Your savings rate of ${savingsRate.toStringAsFixed(0)}% gives the investments room to grow." : ""}';
      headline = '₹${_fmt(totalInvestments)} invested in $monthName';
      highlight = 'Investments on track — ₹${_fmt(totalInvestments)} added this month.';
    }

    return MonthlyNarrative(
      year: year,
      month: month,
      paragraph: para,
      headline: headline,
      highlight: highlight,
      lens: NarrativeLens.investmentMilestone,
    );
  }

  /// Default: balanced summary with all key numbers
  static MonthlyNarrative _buildCashflowHealthyNarrative({
    required List<Transaction> monthTx,
    required String monthName,
    required double totalExpense,
    required double totalIncome,
    required double totalInvestments,
    required double expenseDelta,
    required double savingsRate,
    required bool isDisciplined,
    required int year,
    required int month,
  }) {
    final categorySpend = <String, double>{};
    for (final t in monthTx.where((t) => t.type == TransactionType.expense)) {
      final cat = (t.metadata?['categoryName'] as String?) ?? 'Other';
      categorySpend[cat] = (categorySpend[cat] ?? 0) + t.amount.abs();
    }
    final sortedCats = categorySpend.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topCat = sortedCats.isNotEmpty ? sortedCats.first : null;
    final topCatShare =
        totalExpense > 0 && topCat != null ? (topCat.value / totalExpense * 100) : 0.0;

    final largeCount = monthTx
        .where((t) => t.amount.abs() > 5000 && t.type == TransactionType.expense)
        .length;

    final sb = StringBuffer();
    if (totalExpense == 0) {
      sb.write('No expenses recorded in $monthName. ');
    } else if (expenseDelta > 20) {
      sb.write('$monthName was a higher-spend month — ₹${_fmt(totalExpense)} total, '
          'up ${expenseDelta.toStringAsFixed(0)}% from last month. ');
    } else if (expenseDelta < -15) {
      sb.write('Spending came in lower this month: ₹${_fmt(totalExpense)} — '
          'down ${(-expenseDelta).toStringAsFixed(0)}% from last month. ');
    } else {
      sb.write('Expenses in $monthName totalled ₹${_fmt(totalExpense)}, broadly in line with last month. ');
    }
    if (topCat != null && topCatShare > 25) {
      if (largeCount > 0) {
        sb.write('Most of it was driven by $largeCount large ${topCat.key.toLowerCase()} '
            'transaction${largeCount > 1 ? 's' : ''}, '
            'making up ${topCatShare.toStringAsFixed(0)}% of total spend. ');
      } else {
        sb.write('${topCat.key} was the biggest category at ${topCatShare.toStringAsFixed(0)}% of spend. ');
      }
    }
    if (totalIncome > 0) {
      if (savingsRate >= 30) {
        sb.write(isDisciplined
            ? 'Savings rate held at ${savingsRate.toStringAsFixed(0)}%. '
            : 'Good news: you saved ${savingsRate.toStringAsFixed(0)}% of your income. ');
      } else if (savingsRate > 0) {
        sb.write('Your savings rate this month was ${savingsRate.toStringAsFixed(0)}%. ');
      } else {
        sb.write('Expenses exceeded income this month. ');
      }
    }
    if (totalInvestments > 0) {
      sb.write('Investments stayed on track at ₹${_fmt(totalInvestments)}. ');
    }

    String headline;
    if (totalExpense == 0) {
      headline = 'No spend data';
    } else if (expenseDelta > 20) {
      headline = 'High-spend month — ${expenseDelta.toStringAsFixed(0)}% above last month';
    } else if (expenseDelta < -15) {
      headline = 'Lighter month — spending down ${(-expenseDelta).toStringAsFixed(0)}%';
    } else {
      headline = 'Steady month — on track';
    }

    String? highlight;
    if (totalInvestments > 0 && savingsRate >= 25) {
      highlight = 'Invested ₹${_fmt(totalInvestments)} while keeping savings at ${savingsRate.toStringAsFixed(0)}%.';
    } else if (savingsRate >= 30) {
      highlight = 'Saved ${savingsRate.toStringAsFixed(0)}% of income — great discipline.';
    }

    String? watchOut;
    if (topCat != null && topCatShare > 40) {
      watchOut = '${topCat.key} alone was ${topCatShare.toStringAsFixed(0)}% of spend — worth watching.';
    } else if (savingsRate < 0 && totalIncome > 0) {
      watchOut = 'Spending exceeded income this month.';
    }

    return MonthlyNarrative(
      year: year,
      month: month,
      paragraph: sb.toString().trim(),
      headline: headline,
      highlight: highlight,
      watchOut: watchOut,
      lens: NarrativeLens.cashflowHealthy,
    );
  }

  // ─── Helpers ────────────────────────────────────────────────────────────────

  static String _monthName(int m) {
    const names = [
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return names[m.clamp(1, 12)];
  }

  static String _fmt(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
    return v.toInt().toString();
  }
}
