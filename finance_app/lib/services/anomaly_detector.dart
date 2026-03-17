import 'dart:math' as math;
import 'package:vittara_fin_os/logic/transaction_model.dart';

/// Flags transactions that deviate ±2σ from merchant/type mean amount.
class AnomalyDetectorService {
  AnomalyDetectorService._();

  static Set<String> detectAnomalies(List<Transaction> transactions) {
    final Map<String, List<double>> groups = {};
    for (final tx in transactions) {
      final key = (tx.metadata?['merchant'] as String?) ?? tx.type.name;
      groups.putIfAbsent(key, () => []).add(tx.amount.abs());
    }

    final anomalies = <String>{};
    for (final tx in transactions) {
      final key = (tx.metadata?['merchant'] as String?) ?? tx.type.name;
      final amounts = groups[key]!;
      if (amounts.length < 3) continue;

      final mean = amounts.reduce((a, b) => a + b) / amounts.length;
      final variance = amounts
              .map((a) => math.pow(a - mean, 2))
              .reduce((a, b) => a + b) /
          amounts.length;
      final stdDev = math.sqrt(variance);

      if (stdDev > 0 && (tx.amount.abs() - mean).abs() > 2 * stdDev) {
        anomalies.add(tx.id);
      }
    }
    return anomalies;
  }
}
