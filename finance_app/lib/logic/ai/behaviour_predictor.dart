import 'package:vittara_fin_os/logic/transaction_model.dart';

/// T-143: Predicts likely transaction context (category, merchant, amount)
/// from time-of-day + day-of-week patterns in the last 90 days.
class BehaviourPredictor {
  BehaviourPredictor._();

  static const _confidenceThreshold = 0.7;

  /// Predicts transaction context for [now] given [recentTransactions]
  /// (caller should pass the last 90 days' worth).
  ///
  /// Returns null if confidence < 0.7 — no pre-fill in that case.
  static PredictedContext? predictContext(
    DateTime now,
    List<Transaction> recentTransactions,
  ) {
    if (recentTransactions.isEmpty) return null;

    final bucket = _hourBucket(now.hour);
    final dow = now.weekday; // 1=Mon … 7=Sun

    // Group by (hourBucket, dayOfWeek) key
    final candidates = <String, List<Transaction>>{};
    for (final tx in recentTransactions) {
      if (tx.type != TransactionType.expense) continue;
      final bkt = _hourBucket(tx.dateTime.hour);
      final key = '${bkt}_${tx.dateTime.weekday}';
      (candidates[key] ??= []).add(tx);
    }

    final key = '${bucket}_$dow';
    final group = candidates[key];
    if (group == null || group.length < 3) return null;

    // Find most common (category, merchant) pair
    final pairCounts = <String, int>{};
    final pairData = <String, (String?, String?)>{};
    for (final tx in group) {
      final cat = (tx.metadata?['categoryId'] as String?) ?? '';
      final merchant = ((tx.metadata?['merchant'] as String?) ?? '').trim();
      final pKey = '$cat|$merchant';
      pairCounts[pKey] = (pairCounts[pKey] ?? 0) + 1;
      pairData[pKey] = (cat.isEmpty ? null : cat, merchant.isEmpty ? null : merchant);
    }

    final sorted = pairCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (sorted.isEmpty) return null;

    final topCount = sorted.first.value;
    final confidence = topCount / group.length;
    if (confidence < _confidenceThreshold) return null;

    final topKey = sorted.first.key;
    final (catId, merchant) = pairData[topKey]!;

    // Median amount for this pair
    final amounts = group
        .where((t) {
          final c = (t.metadata?['categoryId'] as String?) ?? '';
          final m = ((t.metadata?['merchant'] as String?) ?? '').trim();
          return '$c|$m' == topKey;
        })
        .map((t) => t.amount.abs())
        .toList()
      ..sort();
    final medianAmount = amounts.isEmpty ? null : amounts[amounts.length ~/ 2];

    return PredictedContext(
      categoryId: catId,
      merchant: merchant,
      amount: medianAmount,
      confidence: confidence,
    );
  }

  static int _hourBucket(int hour) {
    if (hour < 6) return 0; // midnight–6am
    if (hour < 9) return 1; // early morning
    if (hour < 12) return 2; // morning
    if (hour < 15) return 3; // early afternoon
    if (hour < 18) return 4; // afternoon
    if (hour < 21) return 5; // evening
    return 6; // night
  }
}

class PredictedContext {
  final String? categoryId;
  final String? merchant;
  final double? amount;
  final double confidence;

  const PredictedContext({
    this.categoryId,
    this.merchant,
    this.amount,
    required this.confidence,
  });
}
