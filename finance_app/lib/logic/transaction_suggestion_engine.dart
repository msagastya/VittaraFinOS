// ─────────────────────────────────────────────────────────────────────────────
// TransactionSuggestionEngine — pure Dart, on-device frequency analysis.
//
// No ML library. No internet. No model files.
// Algorithms: frequency counting, fuzzy substring matching.
//
// Used to power smart defaults in Quick Entry and Transaction Wizard:
//   • Merchant chips sorted by how often a merchant appears
//   • Categories sorted by usage frequency
//   • Auto-suggest category based on merchant name history
// ─────────────────────────────────────────────────────────────────────────────

import 'package:vittara_fin_os/logic/category_model.dart';
import 'package:vittara_fin_os/logic/transaction_model.dart';

class TransactionSuggestionEngine {
  const TransactionSuggestionEngine._();

  // ── Merchant ranking ────────────────────────────────────────────────────────

  /// Returns merchant strings sorted by appearance frequency across
  /// [transactions], most-used first, up to [limit] entries.
  /// Deduplicates case-insensitively, preserving the original casing of the
  /// first occurrence.
  static List<String> rankedMerchants(
    List<Transaction> transactions, {
    int limit = 20,
  }) {
    final counts = <String, int>{};
    final canonical = <String, String>{}; // lowercase key → first-seen display string
    for (final tx in transactions) {
      final raw = (tx.metadata?['merchant'] as String?)?.trim();
      if (raw == null || raw.isEmpty) continue;
      final key = raw.toLowerCase();
      canonical.putIfAbsent(key, () => raw);
      counts[key] = (counts[key] ?? 0) + 1;
    }
    final sorted = counts.keys.toList()
      ..sort((a, b) => counts[b]!.compareTo(counts[a]!));
    return sorted.take(limit).map((k) => canonical[k]!).toList();
  }

  // ── Category ranking ────────────────────────────────────────────────────────

  /// Returns [categories] sorted by how many times each appears in
  /// [transactions], most-used first. Optionally filter by [type].
  static List<Category> rankedCategories(
    List<Transaction> transactions,
    List<Category> categories, {
    TransactionType? type,
  }) {
    final counts = <String, int>{};
    for (final tx in transactions) {
      if (type != null && tx.type != type) continue;
      final catId = tx.metadata?['categoryId'] as String?;
      if (catId != null) counts[catId] = (counts[catId] ?? 0) + 1;
    }
    final sorted = List<Category>.from(categories);
    sorted.sort((a, b) => (counts[b.id] ?? 0).compareTo(counts[a.id] ?? 0));
    return sorted;
  }

  // ── Merchant → category suggestion ─────────────────────────────────────────

  /// Looks at past transactions where the stored merchant fuzzy-matches
  /// [merchant] (either string is a substring of the other), and returns the
  /// category that appeared most often with those transactions.
  ///
  /// Returns null when [merchant] is empty or no history exists.
  static Category? suggestCategoryForMerchant(
    List<Transaction> transactions,
    String merchant,
    List<Category> categories,
  ) {
    final q = merchant.trim().toLowerCase();
    if (q.isEmpty || q.length < 2) return null;

    final counts = <String, int>{};
    for (final tx in transactions) {
      final m = (tx.metadata?['merchant'] as String?)?.toLowerCase().trim();
      if (m == null || m.isEmpty) continue;
      if (m.contains(q) || q.contains(m)) {
        final catId = tx.metadata?['categoryId'] as String?;
        if (catId != null) counts[catId] = (counts[catId] ?? 0) + 1;
      }
    }
    if (counts.isEmpty) return null;

    final topId =
        counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    try {
      return categories.firstWhere((c) => c.id == topId);
    } catch (_) {
      return null;
    }
  }

  /// Returns the most-used category for transactions whose [amount] falls
  /// within ±30% of the given value. Returns null if no data.
  static Category? suggestCategoryForAmount(
    List<Transaction> transactions,
    double amount,
    List<Category> categories, {
    TransactionType type = TransactionType.expense,
  }) {
    if (amount <= 0) return null;
    final low = amount * 0.7;
    final high = amount * 1.3;
    final counts = <String, int>{};
    for (final tx in transactions) {
      if (tx.type != type) continue;
      if (tx.amount < low || tx.amount > high) continue;
      final catId = tx.metadata?['categoryId'] as String?;
      if (catId != null) counts[catId] = (counts[catId] ?? 0) + 1;
    }
    if (counts.isEmpty) return null;
    final topId =
        counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    try {
      return categories.firstWhere((c) => c.id == topId);
    } catch (_) {
      return null;
    }
  }
}
