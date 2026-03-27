import 'dart:math' as math;
import 'package:vittara_fin_os/logic/transaction_model.dart';

/// Flags transactions that deviate beyond σ threshold from a 90-day rolling
/// baseline per merchant/type group.
/// December and January use 3σ (seasonal spike tolerance); all other months 2σ.
class AnomalyDetectorService {
  AnomalyDetectorService._();

  static Set<String> detectAnomalies(List<Transaction> transactions) {
    final cutoff = DateTime.now().subtract(const Duration(days: 90));
    final window = transactions.where((t) => t.dateTime.isAfter(cutoff)).toList();

    final Map<String, List<double>> groups = {};
    for (final tx in window) {
      final key = (tx.metadata?['merchant'] as String?) ?? tx.type.name;
      groups.putIfAbsent(key, () => []).add(tx.amount.abs());
    }

    final anomalies = <String>{};
    for (final tx in window) {
      final key = (tx.metadata?['merchant'] as String?) ?? tx.type.name;
      final amounts = groups[key]!;
      if (amounts.length < 3) continue;

      final mean = amounts.reduce((a, b) => a + b) / amounts.length;
      final variance = amounts
              .map((a) => math.pow(a - mean, 2))
              .reduce((a, b) => a + b) /
          amounts.length;
      final stdDev = math.sqrt(variance);

      // Use 3σ in Dec/Jan to tolerate seasonal spending spikes.
      final month = tx.dateTime.month;
      final threshold = (month == 12 || month == 1) ? 3.0 : 2.0;

      if (stdDev > 0 && (tx.amount.abs() - mean).abs() > threshold * stdDev) {
        anomalies.add(tx.id);
      }
    }
    return anomalies;
  }
}
