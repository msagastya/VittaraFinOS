import 'dart:math' as math;
import 'package:vittara_fin_os/logic/transaction_model.dart';
import 'merchant_normalizer.dart';

class AnomalyAlert {
  final String id;
  final String transactionId;
  final AnomalyType type;
  final String title;
  final String explanation; // human-readable "why this is unusual"
  final double severity; // 0.0–1.0
  final DateTime detectedAt;
  final bool isDismissed;

  const AnomalyAlert({
    required this.id,
    required this.transactionId,
    required this.type,
    required this.title,
    required this.explanation,
    required this.severity,
    required this.detectedAt,
    this.isDismissed = false,
  });

  AnomalyAlert copyWith({bool? isDismissed}) => AnomalyAlert(
        id: id,
        transactionId: transactionId,
        type: type,
        title: title,
        explanation: explanation,
        severity: severity,
        detectedAt: detectedAt,
        isDismissed: isDismissed ?? this.isDismissed,
      );
}

enum AnomalyType {
  amountSpike,       // same merchant, much higher amount than usual
  unusualFrequency,  // category spent on more times than usual this period
  unusualCategory,   // spent in a category that has been silent for a long time
  lateNightSpend,    // large spend between midnight and 4 AM
  largeUnknown,      // large amount with no known merchant or category
}

class AnomalyDetector {
  AnomalyDetector._();

  /// Scan recent transactions for anomalies against the user's own baseline.
  /// [existingAlerts] — previously detected alerts (so we don't re-alert same tx).
  static List<AnomalyAlert> detect({
    required List<Transaction> transactions,
    required List<AnomalyAlert> existingAlerts,
  }) {
    if (transactions.length < 30) return existingAlerts;

    final now = DateTime.now();
    final existingTxIds = existingAlerts.map((a) => a.transactionId).toSet();

    // Only look at expenses from the last 7 days that haven't been alerted
    final recent = transactions
        .where((t) =>
            t.type == TransactionType.expense &&
            t.dateTime.isAfter(now.subtract(const Duration(days: 7))) &&
            !existingTxIds.contains(t.id))
        .toList();

    if (recent.isEmpty) return existingAlerts;

    // Build baseline from last 90 days (excluding last 7 to avoid contamination)
    final baseline = transactions
        .where((t) =>
            t.type == TransactionType.expense &&
            t.dateTime.isAfter(now.subtract(const Duration(days: 90))) &&
            t.dateTime.isBefore(now.subtract(const Duration(days: 7))))
        .toList();

    final newAlerts = <AnomalyAlert>[];

    for (final tx in recent) {
      final alert = _checkTransaction(tx, baseline, transactions, now);
      if (alert != null) newAlerts.add(alert);
    }

    // Combine existing (keeping dismissed) with new, newest first
    final combined = [...existingAlerts, ...newAlerts];
    combined.sort((a, b) => b.detectedAt.compareTo(a.detectedAt));

    // Keep max 50 alerts (prune oldest dismissed ones first)
    if (combined.length > 50) {
      combined.removeWhere((a) => a.isDismissed);
    }

    return combined.take(50).toList();
  }

  static AnomalyAlert? _checkTransaction(
    Transaction tx,
    List<Transaction> baseline,
    List<Transaction> allTransactions,
    DateTime now,
  ) {
    final merchant = MerchantNormalizer.normalize(
        tx.metadata?['merchant'] as String? ?? tx.description);
    final categoryId = tx.metadata?['categoryId'] as String?;

    // Check 1: Amount spike for same merchant
    final sameVendorTxs = baseline
        .where((t) =>
            MerchantNormalizer.normalize(
                t.metadata?['merchant'] as String? ?? t.description) ==
            merchant)
        .toList();

    if (sameVendorTxs.length >= 3) {
      final amounts = sameVendorTxs.map((t) => t.amount).toList();
      final mean = _mean(amounts);
      final std = _stdDev(amounts);
      final zScore = std > 0 ? (tx.amount - mean) / std : 0.0;

      if (zScore > 2.5 && tx.amount > mean * 2) {
        final severity = math.min(1.0, zScore / 5.0);
        final multiplier = (tx.amount / mean).toStringAsFixed(1);
        return AnomalyAlert(
          id: 'anomaly_amt_${tx.id}',
          transactionId: tx.id,
          type: AnomalyType.amountSpike,
          title: 'Unusual amount at $merchant',
          explanation:
              'This ₹${tx.amount.toInt()} $merchant transaction is ${multiplier}x '
              'your average $merchant spend (₹${mean.toInt()}).',
          severity: severity,
          detectedAt: now,
        );
      }
    }

    // Check 2: Unusual frequency in category this week
    if (categoryId != null) {
      final thisWeekCount = allTransactions
          .where((t) =>
              t.type == TransactionType.expense &&
              t.dateTime.isAfter(now.subtract(const Duration(days: 7))) &&
              (t.metadata?['categoryId'] as String?) == categoryId)
          .length;

      // Compute typical weekly count from baseline
      final weeksInBaseline = 12.0; // ~90 days / 7
      final totalInBaseline = baseline
          .where((t) =>
              (t.metadata?['categoryId'] as String?) == categoryId)
          .length;
      final avgWeeklyCount = totalInBaseline / weeksInBaseline;

      if (avgWeeklyCount > 1 && thisWeekCount > avgWeeklyCount * 2.5) {
        return AnomalyAlert(
          id: 'anomaly_freq_${categoryId}_${now.day}',
          transactionId: tx.id,
          type: AnomalyType.unusualFrequency,
          title: 'High activity in ${_categoryName(categoryId)}',
          explanation:
              'You\'ve had $thisWeekCount transactions in '
              '${_categoryName(categoryId)} this week — '
              '${(thisWeekCount / avgWeeklyCount).toStringAsFixed(1)}x your usual rate of '
              '${avgWeeklyCount.toStringAsFixed(1)}/week.',
          severity: math.min(1.0, thisWeekCount / (avgWeeklyCount * 3)),
          detectedAt: now,
        );
      }
    }

    // Check 3: Late night large spend (midnight to 4 AM, amount > ₹1,000)
    final hour = tx.dateTime.hour;
    if ((hour >= 0 && hour <= 4) && tx.amount >= 1000) {
      return AnomalyAlert(
        id: 'anomaly_late_${tx.id}',
        transactionId: tx.id,
        type: AnomalyType.lateNightSpend,
        title: 'Late-night purchase',
        explanation:
            'A ₹${tx.amount.toInt()} transaction at $merchant was made at '
            '${_formatTime(tx.dateTime)}. Worth double-checking.',
        severity: math.min(1.0, tx.amount / 5000),
        detectedAt: now,
      );
    }

    // Check 4: Large unknown (no merchant, no category, amount > ₹5,000)
    final hasCategory = categoryId != null && categoryId.isNotEmpty;
    final hasMerchant = (tx.metadata?['merchant'] as String?)?.isNotEmpty == true;
    if (!hasCategory && !hasMerchant && tx.amount >= 5000) {
      return AnomalyAlert(
        id: 'anomaly_unknown_${tx.id}',
        transactionId: tx.id,
        type: AnomalyType.largeUnknown,
        title: 'Uncategorized large expense',
        explanation:
            '₹${tx.amount.toInt()} was recorded without a category or merchant. '
            'Tagging it will improve your spending insights.',
        severity: math.min(1.0, tx.amount / 20000),
        detectedAt: now,
      );
    }

    return null;
  }

  static String _categoryName(String categoryId) {
    // Basic fallback — ideally injected from CategoriesController
    return categoryId
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  static String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  static double _mean(List<double> v) =>
      v.isEmpty ? 0 : v.reduce((a, b) => a + b) / v.length;

  static double _stdDev(List<double> values) {
    if (values.length < 2) return 0;
    final m = _mean(values);
    final variance = values
            .map((v) => math.pow(v - m, 2).toDouble())
            .reduce((a, b) => a + b) /
        values.length;
    return math.sqrt(variance);
  }
}
