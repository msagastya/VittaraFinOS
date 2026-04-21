import 'dart:convert';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vittara_fin_os/logic/transaction_model.dart';
import 'merchant_normalizer.dart';

// ── Models ────────────────────────────────────────────────────────────────────

class RecurringTransaction {
  final String merchantNormalized;
  final double typicalAmount;
  final double amountVariance; // std dev as % of mean
  final int intervalDays; // 7=weekly, 14=biweekly, 30=monthly, etc.
  final int intervalVarianceDays;
  final TransactionType type;
  final String? categoryId;
  final DateTime lastSeen;
  final int occurrenceCount;
  final double confidence; // 0.0–1.0

  const RecurringTransaction({
    required this.merchantNormalized,
    required this.typicalAmount,
    required this.amountVariance,
    required this.intervalDays,
    required this.intervalVarianceDays,
    required this.type,
    required this.categoryId,
    required this.lastSeen,
    required this.occurrenceCount,
    required this.confidence,
  });

  Map<String, dynamic> toJson() => {
    'merchant': merchantNormalized,
    'amount': typicalAmount,
    'amountVariance': amountVariance,
    'intervalDays': intervalDays,
    'intervalVarianceDays': intervalVarianceDays,
    'type': type.index,
    'categoryId': categoryId,
    'lastSeen': lastSeen.toIso8601String(),
    'count': occurrenceCount,
    'confidence': confidence,
  };

  factory RecurringTransaction.fromJson(Map<String, dynamic> j) =>
      RecurringTransaction(
        merchantNormalized: j['merchant'] as String,
        typicalAmount: (j['amount'] as num).toDouble(),
        amountVariance: (j['amountVariance'] as num).toDouble(),
        intervalDays: j['intervalDays'] as int,
        intervalVarianceDays: j['intervalVarianceDays'] as int,
        type: TransactionType.values[j['type'] as int],
        categoryId: j['categoryId'] as String?,
        lastSeen: DateTime.parse(j['lastSeen'] as String),
        occurrenceCount: j['count'] as int,
        confidence: (j['confidence'] as num).toDouble(),
      );
}

class DayOfWeekPattern {
  final int dayOfWeek; // 1=Mon … 7=Sun
  final String categoryId;
  final double multiplier; // avg spend this day vs overall daily avg
  final int sampleSize;

  const DayOfWeekPattern({
    required this.dayOfWeek,
    required this.categoryId,
    required this.multiplier,
    required this.sampleSize,
  });
}

class SeasonalPattern {
  final int monthOfYear; // 1–12
  final String categoryId;
  final double multiplier; // avg spend this month vs overall monthly avg
  final int sampleSize;

  const SeasonalPattern({
    required this.monthOfYear,
    required this.categoryId,
    required this.multiplier,
    required this.sampleSize,
  });
}

class SalaryPattern {
  final double typicalAmount;
  final int typicalDayOfMonth; // 1–31
  final int dayVariance;
  final String? accountId;
  final double confidence;

  const SalaryPattern({
    required this.typicalAmount,
    required this.typicalDayOfMonth,
    required this.dayVariance,
    required this.accountId,
    required this.confidence,
  });
}

class SpendingPatterns {
  final List<RecurringTransaction> recurring;
  final SalaryPattern? salary;
  final List<DayOfWeekPattern> dayOfWeekPatterns;
  final List<SeasonalPattern> seasonalPatterns;
  final Map<String, double> avgDailySpendByCategory; // categoryId → avg daily ₹
  final DateTime computedAt;

  const SpendingPatterns({
    required this.recurring,
    this.salary,
    required this.dayOfWeekPatterns,
    required this.seasonalPatterns,
    required this.avgDailySpendByCategory,
    required this.computedAt,
  });

  Map<String, dynamic> toJson() => {
    'recurring': recurring.map((r) => r.toJson()).toList(),
    'salary': salary == null
        ? null
        : {
            'amount': salary!.typicalAmount,
            'day': salary!.typicalDayOfMonth,
            'dayVariance': salary!.dayVariance,
            'accountId': salary!.accountId,
            'confidence': salary!.confidence,
          },
    'computedAt': computedAt.toIso8601String(),
    'avgDailySpend': avgDailySpendByCategory,
  };
}

// ── Detector ──────────────────────────────────────────────────────────────────

class PatternDetector {
  PatternDetector._();

  static const _prefKey = 'ai_spending_patterns_v1';

  // Cached result — refreshed weekly or on-demand
  static SpendingPatterns? _cached;
  static DateTime? _lastComputed;

  /// Analyse transactions and return detected patterns.
  /// Results are cached for 7 days; pass [force] = true to recompute.
  static Future<SpendingPatterns> analyse(
    List<Transaction> transactions, {
    bool force = false,
  }) async {
    if (!force && _cached != null && _lastComputed != null) {
      final age = DateTime.now().difference(_lastComputed!);
      if (age.inDays < 7) return _cached!;
    }

    final patterns = _compute(transactions);
    _cached = patterns;
    _lastComputed = DateTime.now();
    await _persist(patterns);
    return patterns;
  }

  /// Load previously persisted patterns (fast, no computation).
  static Future<SpendingPatterns?> loadCached() async {
    if (_cached != null) return _cached;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefKey);
      if (raw == null) return null;
      final j = jsonDecode(raw) as Map<String, dynamic>;
      _lastComputed = DateTime.parse(j['computedAt'] as String);
      // Rebuild minimal cached object from stored data
      _cached = SpendingPatterns(
        recurring: (j['recurring'] as List)
            .map((e) => RecurringTransaction.fromJson(
                Map<String, dynamic>.from(e as Map)))
            .toList(),
        salary: j['salary'] == null
            ? null
            : SalaryPattern(
                typicalAmount:
                    (j['salary']['amount'] as num).toDouble(),
                typicalDayOfMonth: j['salary']['day'] as int,
                dayVariance: j['salary']['dayVariance'] as int,
                accountId: j['salary']['accountId'] as String?,
                confidence: (j['salary']['confidence'] as num).toDouble(),
              ),
        dayOfWeekPatterns: const [],
        seasonalPatterns: const [],
        avgDailySpendByCategory: Map<String, double>.from(
          (j['avgDailySpend'] as Map? ?? {})
              .map((k, v) => MapEntry(k.toString(), (v as num).toDouble())),
        ),
        computedAt: _lastComputed!,
      );
      return _cached;
    } catch (_) {
      return null;
    }
  }

  // ── Core computation ───────────────────────────────────────────────────────

  static SpendingPatterns _compute(List<Transaction> transactions) {
    if (transactions.isEmpty) {
      return SpendingPatterns(
        recurring: [],
        dayOfWeekPatterns: [],
        seasonalPatterns: [],
        avgDailySpendByCategory: {},
        computedAt: DateTime.now(),
      );
    }

    final recurring = _detectRecurring(transactions);
    final salary = _detectSalary(transactions);
    final dowPatterns = _detectDayOfWeekPatterns(transactions);
    final seasonalPatterns = _detectSeasonalPatterns(transactions);
    final avgDaily = _computeAvgDailyByCategory(transactions);

    return SpendingPatterns(
      recurring: recurring,
      salary: salary,
      dayOfWeekPatterns: dowPatterns,
      seasonalPatterns: seasonalPatterns,
      avgDailySpendByCategory: avgDaily,
      computedAt: DateTime.now(),
    );
  }

  // ── Recurring detection ───────────────────────────────────────────────────

  static List<RecurringTransaction> _detectRecurring(
      List<Transaction> transactions) {
    // Group by normalized merchant
    final Map<String, List<Transaction>> byMerchant = {};
    for (final tx in transactions) {
      if (tx.type == TransactionType.transfer) continue;
      final merchant = MerchantNormalizer.normalize(
          tx.metadata?['merchant'] as String? ?? tx.description);
      byMerchant.putIfAbsent(merchant, () => []).add(tx);
    }

    final result = <RecurringTransaction>[];

    for (final entry in byMerchant.entries) {
      final merchant = entry.key;
      final txs = entry.value..sort((a, b) => a.dateTime.compareTo(b.dateTime));
      if (txs.length < 3) continue; // need at least 3 occurrences

      // Compute interval between consecutive transactions
      final intervals = <int>[];
      for (var i = 1; i < txs.length; i++) {
        intervals.add(txs[i].dateTime.difference(txs[i - 1].dateTime).inDays);
      }

      final avgInterval = _mean(intervals.map((e) => e.toDouble()).toList());
      final intervalStd = _stdDev(intervals.map((e) => e.toDouble()).toList());

      // Only consider as recurring if interval std dev is < 30% of mean
      if (avgInterval <= 0 || intervalStd / avgInterval > 0.3) continue;

      // Compute amount stats
      final amounts = txs.map((t) => t.amount).toList();
      final avgAmount = _mean(amounts);
      final amtStd = _stdDev(amounts);
      final amtVariancePct = avgAmount > 0 ? amtStd / avgAmount : 0.0;

      // Normalize interval to nearest standard period
      final normalizedInterval = _normalizeInterval(avgInterval.round());

      // Confidence: higher with more occurrences + lower variance
      final confidence = math.min(
        1.0,
        (txs.length / 12.0) * (1.0 - amtVariancePct * 0.5),
      );

      if (confidence < 0.3) continue;

      result.add(RecurringTransaction(
        merchantNormalized: merchant,
        typicalAmount: avgAmount,
        amountVariance: amtVariancePct,
        intervalDays: normalizedInterval,
        intervalVarianceDays: intervalStd.round(),
        type: txs.last.type,
        categoryId: txs.last.metadata?['categoryId'] as String?,
        lastSeen: txs.last.dateTime,
        occurrenceCount: txs.length,
        confidence: confidence,
      ));
    }

    // Sort by confidence descending
    result.sort((a, b) => b.confidence.compareTo(a.confidence));
    return result;
  }

  static int _normalizeInterval(int days) {
    if (days <= 1) return 1;
    if (days <= 8) return 7; // weekly
    if (days <= 10) return 7;
    if (days <= 16) return 14; // biweekly
    if (days <= 20) return 14;
    if (days <= 35) return 30; // monthly
    if (days <= 50) return 45;
    if (days <= 70) return 60; // bimonthly
    if (days <= 100) return 90; // quarterly
    return 365; // annual
  }

  // ── Salary detection ──────────────────────────────────────────────────────

  static SalaryPattern? _detectSalary(List<Transaction> transactions) {
    // Salary = income transaction, regular, largest regular income
    final incomes = transactions
        .where((t) =>
            t.type == TransactionType.income &&
            (t.description.toLowerCase().contains('salary') ||
                t.description.toLowerCase().contains('sal ') ||
                t.description.toLowerCase().contains(' sal') ||
                (t.amount > 10000 && t.metadata?['categoryId'] == 'income')))
        .toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

    if (incomes.length < 2) return null;

    // Group by month and take largest per month
    final Map<String, Transaction> monthlyMax = {};
    for (final tx in incomes) {
      final key =
          '${tx.dateTime.year}-${tx.dateTime.month.toString().padLeft(2, '0')}';
      if (!monthlyMax.containsKey(key) ||
          tx.amount > monthlyMax[key]!.amount) {
        monthlyMax[key] = tx;
      }
    }

    if (monthlyMax.length < 2) return null;

    final salaryTxs = monthlyMax.values.toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

    final amounts = salaryTxs.map((t) => t.amount).toList();
    final avgAmount = _mean(amounts);
    final amtStd = _stdDev(amounts);

    // Reject if amount varies wildly (not a salary)
    if (amtStd / avgAmount > 0.25) return null;

    final days = salaryTxs.map((t) => t.dateTime.day).toList();
    final avgDay = _mean(days.map((d) => d.toDouble()).toList()).round();
    final dayStd = _stdDev(days.map((d) => d.toDouble()).toList()).round();

    final confidence = math.min(
      1.0,
      (salaryTxs.length / 6.0) * (1.0 - amtStd / avgAmount),
    );

    return SalaryPattern(
      typicalAmount: avgAmount,
      typicalDayOfMonth: avgDay,
      dayVariance: dayStd,
      accountId: salaryTxs.last.metadata?['accountId'] as String?,
      confidence: confidence,
    );
  }

  // ── Day-of-week patterns ──────────────────────────────────────────────────

  static List<DayOfWeekPattern> _detectDayOfWeekPatterns(
      List<Transaction> transactions) {
    final expenses = transactions
        .where((t) => t.type == TransactionType.expense)
        .toList();
    if (expenses.length < 30) return [];

    // Group by (categoryId, dayOfWeek) → sum amounts
    final Map<String, Map<int, double>> catDaySum = {};
    final Map<String, Map<int, int>> catDayCount = {};

    for (final tx in expenses) {
      final cat = tx.metadata?['categoryId'] as String? ?? 'unknown';
      final dow = tx.dateTime.weekday; // 1=Mon, 7=Sun
      catDaySum.putIfAbsent(cat, () => {})[dow] =
          (catDaySum[cat]![dow] ?? 0) + tx.amount;
      catDayCount.putIfAbsent(cat, () => {})[dow] =
          (catDayCount[cat]![dow] ?? 0) + 1;
    }

    final result = <DayOfWeekPattern>[];

    for (final cat in catDaySum.keys) {
      final dayAvgs = <int, double>{};
      for (final dow in catDaySum[cat]!.keys) {
        final count = catDayCount[cat]![dow] ?? 1;
        dayAvgs[dow] = catDaySum[cat]![dow]! / count;
      }

      final overallAvg = _mean(dayAvgs.values.toList());
      if (overallAvg <= 0) continue;

      for (final dow in dayAvgs.keys) {
        final multiplier = dayAvgs[dow]! / overallAvg;
        final sampleSize = catDayCount[cat]![dow] ?? 0;
        // Only flag days with 1.5x+ multiplier and decent sample
        if (multiplier >= 1.5 && sampleSize >= 3) {
          result.add(DayOfWeekPattern(
            dayOfWeek: dow,
            categoryId: cat,
            multiplier: multiplier,
            sampleSize: sampleSize,
          ));
        }
      }
    }

    return result;
  }

  // ── Seasonal patterns ────────────────────────────────────────────────────

  static List<SeasonalPattern> _detectSeasonalPatterns(
      List<Transaction> transactions) {
    final expenses = transactions
        .where((t) => t.type == TransactionType.expense)
        .toList();
    if (expenses.length < 50) return [];

    // Group by (categoryId, month) → sum amounts
    final Map<String, Map<int, double>> catMonthSum = {};
    final Map<String, Map<int, int>> catMonthCount = {};

    for (final tx in expenses) {
      final cat = tx.metadata?['categoryId'] as String? ?? 'unknown';
      final month = tx.dateTime.month;
      catMonthSum.putIfAbsent(cat, () => {})[month] =
          (catMonthSum[cat]![month] ?? 0) + tx.amount;
      catMonthCount.putIfAbsent(cat, () => {})[month] =
          (catMonthCount[cat]![month] ?? 0) + 1;
    }

    final result = <SeasonalPattern>[];

    for (final cat in catMonthSum.keys) {
      final monthAvgs = <int, double>{};
      for (final month in catMonthSum[cat]!.keys) {
        final count = catMonthCount[cat]![month] ?? 1;
        monthAvgs[month] = catMonthSum[cat]![month]! / count;
      }

      final overallAvg = _mean(monthAvgs.values.toList());
      if (overallAvg <= 0) continue;

      for (final month in monthAvgs.keys) {
        final multiplier = monthAvgs[month]! / overallAvg;
        final sampleSize = catMonthCount[cat]![month] ?? 0;
        if (multiplier >= 1.4 && sampleSize >= 2) {
          result.add(SeasonalPattern(
            monthOfYear: month,
            categoryId: cat,
            multiplier: multiplier,
            sampleSize: sampleSize,
          ));
        }
      }
    }

    return result;
  }

  // ── Average daily spend by category ──────────────────────────────────────

  static Map<String, double> _computeAvgDailyByCategory(
      List<Transaction> transactions) {
    if (transactions.isEmpty) return {};

    final expenses =
        transactions.where((t) => t.type == TransactionType.expense).toList();
    if (expenses.isEmpty) return {};

    final earliest = expenses
        .map((t) => t.dateTime)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    final daySpan = DateTime.now().difference(earliest).inDays;
    if (daySpan <= 0) return {};

    final Map<String, double> totalByCategory = {};
    for (final tx in expenses) {
      final cat = tx.metadata?['categoryId'] as String? ?? 'unknown';
      totalByCategory[cat] = (totalByCategory[cat] ?? 0) + tx.amount;
    }

    return totalByCategory
        .map((k, v) => MapEntry(k, v / daySpan));
  }

  // ── Math helpers ──────────────────────────────────────────────────────────

  static double _mean(List<double> values) {
    if (values.isEmpty) return 0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  static double _stdDev(List<double> values) {
    if (values.length < 2) return 0;
    final m = _mean(values);
    final variance =
        values.map((v) => math.pow(v - m, 2).toDouble()).reduce((a, b) => a + b) /
            values.length;
    return math.sqrt(variance);
  }

  // ── Persistence ───────────────────────────────────────────────────────────

  static Future<void> _persist(SpendingPatterns patterns) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, jsonEncode(patterns.toJson()));
    } catch (_) {}
  }
}
