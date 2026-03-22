// ─────────────────────────────────────────────────────────────────────────────
// RecurringPatternDetector — UTL-02
// Analyses transaction history and surfaces likely recurring patterns.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:vittara_fin_os/logic/transaction_model.dart';
import 'package:vittara_fin_os/logic/recurring_template_model.dart';

class RecurringPattern {
  final String payee;
  final double avgAmount;
  final double amountVariancePct; // 0–100
  final String suggestedFrequency; // 'daily' | 'weekly' | 'monthly' | 'yearly'
  final int avgIntervalDays;
  final int occurrences;
  final DateTime latestDate;
  final List<Transaction> matchingTransactions;

  const RecurringPattern({
    required this.payee,
    required this.avgAmount,
    required this.amountVariancePct,
    required this.suggestedFrequency,
    required this.avgIntervalDays,
    required this.occurrences,
    required this.latestDate,
    required this.matchingTransactions,
  });

  /// Estimated next due date based on latest occurrence + average interval.
  DateTime get estimatedNextDue =>
      latestDate.add(Duration(days: avgIntervalDays));
}

class RecurringPatternDetector {
  /// Returns a list of detected recurring patterns.
  /// [existing] — already-tracked recurring templates (excluded from suggestions).
  static List<RecurringPattern> detect(
    List<Transaction> transactions, {
    List<RecurringTemplate> existing = const [],
    int minOccurrences = 3,
  }) {
    if (transactions.isEmpty) return [];

    // Existing template names/merchants (lowercase) to skip
    final existingKeys = existing
        .map((t) => _normalize(t.name))
        .toSet()
      ..addAll(existing
          .where((t) => t.merchant != null)
          .map((t) => _normalize(t.merchant!)));

    // Group transactions by normalized payee
    final Map<String, List<Transaction>> groups = {};
    for (final tx in transactions) {
      if (tx.type == TransactionType.income ||
          tx.type == TransactionType.cashback) continue; // focus on expenses
      final key = _normalize(tx.description);
      if (key.isEmpty || key.length < 3) continue;
      groups.putIfAbsent(key, () => []).add(tx);
    }

    final patterns = <RecurringPattern>[];

    for (final entry in groups.entries) {
      final key = entry.key;
      final txs = entry.value;

      // Already tracked — skip
      if (existingKeys.any((ek) => ek.contains(key) || key.contains(ek))) {
        continue;
      }

      if (txs.length < minOccurrences) continue;

      // Sort by date ascending
      txs.sort((a, b) => a.dateTime.compareTo(b.dateTime));

      // Calculate intervals between consecutive occurrences
      final intervals = <int>[];
      for (var i = 1; i < txs.length; i++) {
        intervals.add(txs[i].dateTime.difference(txs[i - 1].dateTime).inDays);
      }
      if (intervals.isEmpty) continue;

      final avgInterval =
          intervals.reduce((a, b) => a + b) / intervals.length;

      // Determine frequency
      String? freq;
      if (avgInterval >= 0.8 && avgInterval <= 1.5) {
        freq = 'daily';
      } else if (avgInterval >= 5 && avgInterval <= 9) {
        freq = 'weekly';
      } else if (avgInterval >= 25 && avgInterval <= 36) {
        freq = 'monthly';
      } else if (avgInterval >= 350 && avgInterval <= 380) {
        freq = 'yearly';
      }
      if (freq == null) continue; // no recognizable cadence

      // Amount consistency check
      final amounts = txs.map((t) => t.amount).toList();
      final avgAmt = amounts.reduce((a, b) => a + b) / amounts.length;
      if (avgAmt <= 0) continue;
      final maxDeviation = amounts.map((a) => (a - avgAmt).abs()).reduce(
              (a, b) => a > b ? a : b);
      final variancePct = (maxDeviation / avgAmt) * 100;

      // Skip if amount variance > 30% (too inconsistent)
      if (variancePct > 30) continue;

      patterns.add(RecurringPattern(
        payee: _titleCase(key),
        avgAmount: avgAmt,
        amountVariancePct: variancePct,
        suggestedFrequency: freq,
        avgIntervalDays: avgInterval.round(),
        occurrences: txs.length,
        latestDate: txs.last.dateTime,
        matchingTransactions: txs,
      ));
    }

    // Sort by occurrences descending (most confident first)
    patterns.sort((a, b) => b.occurrences.compareTo(a.occurrences));
    return patterns;
  }

  /// Normalise a description for grouping:
  /// lowercase, remove amounts/dates/IDs, collapse whitespace.
  static String _normalize(String desc) {
    var s = desc.toLowerCase();
    // Remove common suffixes: UPI IDs, ref numbers, trailing digits
    s = s.replaceAll(RegExp(r'\b\d+\b'), '');
    s = s.replaceAll(RegExp(r'[/@#\-_]'), ' ');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    // Remove very short tokens
    final tokens = s.split(' ').where((t) => t.length >= 3).toList();
    return tokens.take(3).join(' '); // use first 3 meaningful tokens
  }

  static String _titleCase(String s) {
    return s.split(' ').map((w) {
      if (w.isEmpty) return w;
      return w[0].toUpperCase() + w.substring(1);
    }).join(' ');
  }
}
