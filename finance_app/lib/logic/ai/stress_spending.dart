import 'package:vittara_fin_os/logic/transaction_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A detected stress-spending pattern.
/// Only surfaced when user has enabled "spending pattern insights" in settings.
class StressSpendingInsight {
  final String id;
  final String observation; // Non-judgmental wording
  final String timePattern; // "after 10 PM on workdays"
  final String category;
  final int occurrences;
  final double avgAmount;

  const StressSpendingInsight({
    required this.id,
    required this.observation,
    required this.timePattern,
    required this.category,
    required this.occurrences,
    required this.avgAmount,
  });
}

class StressSpendingDetector {
  StressSpendingDetector._();

  static const String _prefKey = 'ai_stress_last_shown';
  static const int _cooldownDays = 14;

  /// Detect stress patterns. Returns empty list if:
  /// - User has not enabled spending pattern insights
  /// - The same insight was shown within the last 14 days
  /// - Insufficient data (< 30 transactions)
  static Future<List<StressSpendingInsight>> detect({
    required List<Transaction> transactions,
    required bool insightsEnabled,
  }) async {
    if (!insightsEnabled) return [];
    if (transactions.length < 30) return [];

    final prefs = await SharedPreferences.getInstance();
    final lastShownMs = prefs.getInt(_prefKey) ?? 0;
    final lastShown = DateTime.fromMillisecondsSinceEpoch(lastShownMs);
    if (DateTime.now().difference(lastShown).inDays < _cooldownDays) return [];

    final insights = _analyse(transactions);
    return insights;
  }

  static List<StressSpendingInsight> _analyse(List<Transaction> transactions) {
    final insights = <StressSpendingInsight>[];
    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(days: 90));

    final recent = transactions
        .where((t) =>
            t.type == TransactionType.expense && t.dateTime.isAfter(cutoff))
        .toList();

    if (recent.isEmpty) return [];

    // Pattern: late-night purchases (22:00–03:00)
    final lateNight = recent.where((t) {
      final h = t.dateTime.hour;
      return (h >= 22 || h <= 3);
    }).toList();

    if (lateNight.length >= 4) {
      // Group by category
      final catCount = <String, List<Transaction>>{};
      for (final t in lateNight) {
        final cat = (t.metadata?['categoryName'] as String?) ?? 'Other';
        catCount.putIfAbsent(cat, () => []).add(t);
      }
      final topCat = catCount.entries.toList()
        ..sort((a, b) => b.value.length.compareTo(a.value.length));
      if (topCat.isNotEmpty && topCat.first.value.length >= 3) {
        final entry = topCat.first;
        final avg = entry.value.fold(0.0, (s, t) => s + t.amount.abs()) /
            entry.value.length;
        insights.add(StressSpendingInsight(
          id: 'late_night_${entry.key}',
          observation:
              'Worth noticing: ${entry.value.length} of your recent ${entry.key.toLowerCase()} '
              'purchases happened late at night.',
          timePattern: 'after 10 PM',
          category: entry.key,
          occurrences: entry.value.length,
          avgAmount: avg,
        ));
      }
    }

    // Pattern: end-of-month spike (days 25–31)
    final eom = recent.where((t) => t.dateTime.day >= 25).toList();
    final nonEom =
        recent.where((t) => t.dateTime.day < 25).toList();
    if (eom.isNotEmpty && nonEom.isNotEmpty) {
      final eomAvg =
          eom.fold(0.0, (s, t) => s + t.amount.abs()) / eom.length;
      final nonEomAvg =
          nonEom.fold(0.0, (s, t) => s + t.amount.abs()) / nonEom.length;
      if (eomAvg > nonEomAvg * 1.5 && eom.length >= 3) {
        insights.add(StressSpendingInsight(
          id: 'end_of_month_spike',
          observation:
              'Your average transaction in the last week of the month '
              '(₹${eomAvg.toInt()}) tends to run higher than the rest of the month '
              '(₹${nonEomAvg.toInt()}).',
          timePattern: 'last week of month',
          category: 'General',
          occurrences: eom.length,
          avgAmount: eomAvg,
        ));
      }
    }

    // Keep max 2 insights to avoid overwhelming the user
    return insights.take(2).toList();
  }

  /// Call after surfacing an insight to reset the cooldown.
  static Future<void> markShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
        _prefKey, DateTime.now().millisecondsSinceEpoch);
  }
}
