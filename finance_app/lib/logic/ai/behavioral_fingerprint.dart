import 'dart:convert';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vittara_fin_os/logic/transaction_model.dart';

/// The user's spending personality — a set of profile scores (0–100 each).
/// Multiple profiles can be partially true simultaneously.
///
/// Used by: habit question generator, insight tone calibration, tip personalization.
class BehavioralFingerprint {
  /// High-frequency, small, irregular purchases — often late at night.
  final int impulseScore; // 0–100

  /// Low variance, steady categories, front-loaded month spending.
  final int disciplinedScore; // 0–100

  /// Overspend one week/period then drastically undercut the next.
  final int bingeRecoveryScore; // 0–100

  /// Spikes around paydays, festivals, or specific calendar periods.
  final int seasonalScore; // 0–100

  /// Actively moves money, uses multiple accounts, optimizes allocations.
  final int optimizerScore; // 0–100

  final DateTime computedAt;
  final int transactionCount; // sample size this was computed on

  const BehavioralFingerprint({
    required this.impulseScore,
    required this.disciplinedScore,
    required this.bingeRecoveryScore,
    required this.seasonalScore,
    required this.optimizerScore,
    required this.computedAt,
    required this.transactionCount,
  });

  /// Returns the dominant profile name (highest score).
  String get dominantProfile {
    final scores = {
      'Impulse Spender': impulseScore,
      'Disciplined Saver': disciplinedScore,
      'Binge-Recovery': bingeRecoveryScore,
      'Seasonal Spender': seasonalScore,
      'Optimizer': optimizerScore,
    };
    return scores.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;
  }

  /// Returns profiles above a threshold (meaningful signals).
  List<String> get activeProfiles {
    final profiles = <String>[];
    if (impulseScore >= 40) profiles.add('impulse');
    if (disciplinedScore >= 40) profiles.add('disciplined');
    if (bingeRecoveryScore >= 40) profiles.add('bingeRecovery');
    if (seasonalScore >= 40) profiles.add('seasonal');
    if (optimizerScore >= 40) profiles.add('optimizer');
    return profiles;
  }

  Map<String, dynamic> toJson() => {
    'impulse': impulseScore,
    'disciplined': disciplinedScore,
    'bingeRecovery': bingeRecoveryScore,
    'seasonal': seasonalScore,
    'optimizer': optimizerScore,
    'computedAt': computedAt.toIso8601String(),
    'sampleSize': transactionCount,
  };

  factory BehavioralFingerprint.fromJson(Map<String, dynamic> j) =>
      BehavioralFingerprint(
        impulseScore: j['impulse'] as int,
        disciplinedScore: j['disciplined'] as int,
        bingeRecoveryScore: j['bingeRecovery'] as int,
        seasonalScore: j['seasonal'] as int,
        optimizerScore: j['optimizer'] as int,
        computedAt: DateTime.parse(j['computedAt'] as String),
        transactionCount: j['sampleSize'] as int,
      );

  /// Neutral fingerprint returned when there isn't enough data yet.
  static BehavioralFingerprint get neutral => BehavioralFingerprint(
        impulseScore: 0,
        disciplinedScore: 0,
        bingeRecoveryScore: 0,
        seasonalScore: 0,
        optimizerScore: 0,
        computedAt: DateTime.now(),
        transactionCount: 0,
      );
}

// ── Builder ───────────────────────────────────────────────────────────────────

class BehavioralFingerprintBuilder {
  BehavioralFingerprintBuilder._();

  static const _prefKey = 'ai_behavioral_fingerprint_v1';
  static BehavioralFingerprint? _cached;

  /// Compute the fingerprint from transaction history.
  /// Cached for 7 days; pass [force] = true to recompute.
  static Future<BehavioralFingerprint> compute(
    List<Transaction> transactions, {
    bool force = false,
  }) async {
    if (!force && _cached != null) {
      final age = DateTime.now().difference(_cached!.computedAt);
      if (age.inDays < 7) return _cached!;
    }

    final fingerprint = _build(transactions);
    _cached = fingerprint;
    await _persist(fingerprint);
    return fingerprint;
  }

  static Future<BehavioralFingerprint> loadCached() async {
    if (_cached != null) return _cached!;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefKey);
      if (raw != null) {
        _cached = BehavioralFingerprint.fromJson(
            Map<String, dynamic>.from(jsonDecode(raw) as Map));
        return _cached!;
      }
    } catch (_) {}
    return BehavioralFingerprint.neutral;
  }

  // ── Core scoring ──────────────────────────────────────────────────────────

  static BehavioralFingerprint _build(List<Transaction> transactions) {
    final expenses = transactions
        .where((t) => t.type == TransactionType.expense)
        .toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

    if (expenses.length < 20) return BehavioralFingerprint.neutral;

    return BehavioralFingerprint(
      impulseScore: _scoreImpulse(expenses),
      disciplinedScore: _scoreDisciplined(expenses),
      bingeRecoveryScore: _scoreBingeRecovery(expenses),
      seasonalScore: _scoreSeasonal(expenses),
      optimizerScore: _scoreOptimizer(transactions),
      computedAt: DateTime.now(),
      transactionCount: transactions.length,
    );
  }

  // ── Impulse: small, frequent, irregular, late-night ──────────────────────

  static int _scoreImpulse(List<Transaction> expenses) {
    if (expenses.isEmpty) return 0;

    // Signal 1: % of transactions under ₹500
    final smallTxPct =
        expenses.where((t) => t.amount < 500).length / expenses.length;

    // Signal 2: % of transactions between 9 PM and midnight
    final lateNight = expenses
        .where((t) => t.dateTime.hour >= 21 || t.dateTime.hour <= 1)
        .length / expenses.length;

    // Signal 3: how many unique merchant categories appear?
    // More unique = more impulse browsing
    final uniqueCategories = expenses
        .map((t) => t.metadata?['categoryId'] as String? ?? 'unknown')
        .toSet()
        .length;
    final categoryDiversity = math.min(1.0, uniqueCategories / 10.0);

    // Signal 4: high daily transaction count variance
    final dailyCounts = _dailyTransactionCounts(expenses);
    final dailyStd = _stdDev(dailyCounts.map((c) => c.toDouble()).toList());
    final dailyMean = _mean(dailyCounts.map((c) => c.toDouble()).toList());
    final dailyVariance = dailyMean > 0 ? math.min(1.0, dailyStd / dailyMean) : 0.0;

    final score = (smallTxPct * 30) +
        (lateNight * 25) +
        (categoryDiversity * 25) +
        (dailyVariance * 20);

    return score.round().clamp(0, 100);
  }

  // ── Disciplined: low variance, predictable, front-loaded ────────────────

  static int _scoreDisciplined(List<Transaction> expenses) {
    if (expenses.isEmpty) return 0;

    // Signal 1: low month-to-month spend variance
    final monthlyTotals = _monthlyTotals(expenses);
    if (monthlyTotals.length < 2) return 0;
    final monthMean = _mean(monthlyTotals);
    final monthStd = _stdDev(monthlyTotals);
    final lowMonthlyVariance = monthMean > 0
        ? math.max(0.0, 1.0 - (monthStd / monthMean))
        : 0.0;

    // Signal 2: few impulsive large spikes (amounts within 2x of mean)
    final amounts = expenses.map((t) => t.amount).toList();
    final amtMean = _mean(amounts);
    final spikeCount =
        amounts.where((a) => a > amtMean * 3).length / amounts.length;
    final lowSpikes = math.max(0.0, 1.0 - spikeCount * 5);

    // Signal 3: consistent category distribution month to month
    final categoryConsistency = _computeCategoryConsistency(expenses);

    final score = (lowMonthlyVariance * 40) +
        (lowSpikes * 35) +
        (categoryConsistency * 25);

    return score.round().clamp(0, 100);
  }

  // ── Binge-Recovery: alternating high/low periods ─────────────────────────

  static int _scoreBingeRecovery(List<Transaction> expenses) {
    final monthlyTotals = _monthlyTotals(expenses);
    if (monthlyTotals.length < 4) return 0;

    // Detect alternating above/below mean pattern
    final mean = _mean(monthlyTotals);
    int alternations = 0;
    bool? prevAbove;
    for (final total in monthlyTotals) {
      final above = total > mean;
      if (prevAbove != null && above != prevAbove) alternations++;
      prevAbove = above;
    }

    // Alternation rate: perfect binge-recovery = alternates every month
    final alternationRate = alternations / (monthlyTotals.length - 1);

    // Also check magnitude: binge months should be significantly higher
    final aboveMonths =
        monthlyTotals.where((t) => t > mean).toList();
    final belowMonths =
        monthlyTotals.where((t) => t <= mean).toList();
    if (aboveMonths.isEmpty || belowMonths.isEmpty) return 0;

    final aboveMean = _mean(aboveMonths);
    final belowMean = _mean(belowMonths);
    final magnitude =
        belowMean > 0 ? math.min(1.0, (aboveMean - belowMean) / belowMean) : 0.0;

    final score = (alternationRate * 60) + (magnitude * 40);
    return score.round().clamp(0, 100);
  }

  // ── Seasonal: spikes around specific months ───────────────────────────────

  static int _scoreSeasonal(List<Transaction> expenses) {
    final monthlyTotals = _monthlyTotals(expenses);
    if (monthlyTotals.length < 6) return 0;

    final mean = _mean(monthlyTotals);
    final std = _stdDev(monthlyTotals);
    if (mean <= 0) return 0;

    // Count months with spend > 1.5x mean (spike months)
    final spikePct =
        monthlyTotals.where((t) => t > mean * 1.5).length /
            monthlyTotals.length;

    // High coefficient of variation = seasonal spikes
    final cv = std / mean;

    final score = (spikePct * 50) + (math.min(1.0, cv) * 50);
    return score.round().clamp(0, 100);
  }

  // ── Optimizer: transfers, multiple accounts, active money management ─────

  static int _scoreOptimizer(List<Transaction> transactions) {
    if (transactions.isEmpty) return 0;

    // Signal 1: high % of transfer transactions
    final transferPct =
        transactions.where((t) => t.type == TransactionType.transfer).length /
            transactions.length;

    // Signal 2: uses multiple source accounts
    final accounts = transactions
        .map((t) => t.sourceAccountId ?? t.metadata?['accountId'] as String?)
        .whereType<String>()
        .toSet();
    final accountDiversity = math.min(1.0, accounts.length / 4.0);

    // Signal 3: consistent investment transactions
    final investmentPct =
        transactions.where((t) => t.type == TransactionType.investment).length /
            transactions.length;

    final score = (transferPct * 35) +
        (accountDiversity * 35) +
        (investmentPct * 30);

    return (score * 100).round().clamp(0, 100);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static List<double> _monthlyTotals(List<Transaction> expenses) {
    final Map<String, double> byMonth = {};
    for (final tx in expenses) {
      final key =
          '${tx.dateTime.year}-${tx.dateTime.month.toString().padLeft(2, '0')}';
      byMonth[key] = (byMonth[key] ?? 0) + tx.amount;
    }
    return byMonth.values.toList();
  }

  static List<int> _dailyTransactionCounts(List<Transaction> expenses) {
    final Map<String, int> byDay = {};
    for (final tx in expenses) {
      final key =
          '${tx.dateTime.year}-${tx.dateTime.month}-${tx.dateTime.day}';
      byDay[key] = (byDay[key] ?? 0) + 1;
    }
    return byDay.values.toList();
  }

  static double _computeCategoryConsistency(List<Transaction> expenses) {
    // Group by month → category distribution
    final Map<String, Map<String, double>> monthCatTotals = {};
    for (final tx in expenses) {
      final month =
          '${tx.dateTime.year}-${tx.dateTime.month.toString().padLeft(2, '0')}';
      final cat = tx.metadata?['categoryId'] as String? ?? 'unknown';
      monthCatTotals.putIfAbsent(month, () => {})[cat] =
          (monthCatTotals[month]![cat] ?? 0) + tx.amount;
    }

    if (monthCatTotals.length < 2) return 0.5;

    // Compare category distributions across months using cosine similarity
    final months = monthCatTotals.keys.toList()..sort();
    double totalSimilarity = 0;
    int comparisons = 0;

    for (var i = 0; i < months.length - 1; i++) {
      final a = monthCatTotals[months[i]]!;
      final b = monthCatTotals[months[i + 1]]!;
      totalSimilarity += _cosineSimilarity(a, b);
      comparisons++;
    }

    return comparisons > 0 ? totalSimilarity / comparisons : 0.5;
  }

  static double _cosineSimilarity(
      Map<String, double> a, Map<String, double> b) {
    final allKeys = {...a.keys, ...b.keys};
    double dot = 0, normA = 0, normB = 0;
    for (final k in allKeys) {
      final va = a[k] ?? 0;
      final vb = b[k] ?? 0;
      dot += va * vb;
      normA += va * va;
      normB += vb * vb;
    }
    if (normA <= 0 || normB <= 0) return 0;
    return dot / (math.sqrt(normA) * math.sqrt(normB));
  }

  static double _mean(List<double> values) {
    if (values.isEmpty) return 0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  static double _stdDev(List<double> values) {
    if (values.length < 2) return 0;
    final m = _mean(values);
    final variance = values
            .map((v) => math.pow(v - m, 2).toDouble())
            .reduce((a, b) => a + b) /
        values.length;
    return math.sqrt(variance);
  }

  static Future<void> _persist(BehavioralFingerprint fp) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, jsonEncode(fp.toJson()));
    } catch (_) {}
  }
}
