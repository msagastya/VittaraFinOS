import 'package:vittara_fin_os/logic/transaction_model.dart';
import 'pattern_detector.dart';

enum PredictionConfidence { high, medium, low }

/// A single predicted future transaction.
class PredictedTransaction {
  final String id;
  final DateTime expectedDate;

  /// ±days range for the expected date.
  final int dateVarianceDays;

  final String merchantName;
  final TransactionType type;
  final double typicalAmount;
  final double amountVariance; // ±amount
  final PredictionConfidence confidence;
  final String source; // 'salary', 'recurring', 'bill', 'subscription'

  const PredictedTransaction({
    required this.id,
    required this.expectedDate,
    required this.dateVarianceDays,
    required this.merchantName,
    required this.type,
    required this.typicalAmount,
    required this.amountVariance,
    required this.confidence,
    required this.source,
  });

  DateTime get earliestDate =>
      expectedDate.subtract(Duration(days: dateVarianceDays));
  DateTime get latestDate =>
      expectedDate.add(Duration(days: dateVarianceDays));
}

/// Builds a calendar of predicted future transactions for the next 90 days.
class PredictedCalendar {
  PredictedCalendar._();

  static List<PredictedTransaction> build({
    required SpendingPatterns patterns,
    required DateTime from,
    int daysAhead = 90,
  }) {
    final to = from.add(Duration(days: daysAhead));
    final predictions = <PredictedTransaction>[];

    // 1. Salary
    if (patterns.salary != null) {
      final sal = patterns.salary!;
      predictions.addAll(_predictSalary(sal, from, to));
    }

    // 2. Recurring transactions
    for (final r in patterns.recurring) {
      if (r.confidence < 0.5) continue;
      predictions.addAll(_predictRecurring(r, from, to));
    }

    // Deduplicate by merchant + date proximity (within 3 days)
    return _deduplicate(predictions);
  }

  static List<PredictedTransaction> _predictSalary(
    SalaryPattern sal,
    DateTime from,
    DateTime to,
  ) {
    final results = <PredictedTransaction>[];
    var cursor = from;
    while (cursor.isBefore(to)) {
      final expectedDay = sal.typicalDayOfMonth.clamp(1, 28);
      final candidate = DateTime(cursor.year, cursor.month, expectedDay);
      if (candidate.isAfter(from) && candidate.isBefore(to)) {
        results.add(PredictedTransaction(
          id: 'salary_${candidate.year}_${candidate.month}',
          expectedDate: candidate,
          dateVarianceDays: sal.dayVariance.ceil().clamp(1, 5),
          merchantName: 'Salary',
          type: TransactionType.income,
          typicalAmount: sal.typicalAmount,
          amountVariance: sal.typicalAmount * 0.05,
          confidence: sal.confidence > 0.8
              ? PredictionConfidence.high
              : PredictionConfidence.medium,
          source: 'salary',
        ));
      }
      // advance 1 month
      cursor = DateTime(cursor.year, cursor.month + 1, 1);
    }
    return results;
  }

  static List<PredictedTransaction> _predictRecurring(
    RecurringTransaction r,
    DateTime from,
    DateTime to,
  ) {
    final results = <PredictedTransaction>[];
    // Start from lastSeen + one interval
    var next = r.lastSeen.add(Duration(days: r.intervalDays));
    int safety = 0;
    while (next.isBefore(to) && safety < 50) {
      safety++;
      if (next.isAfter(from)) {
        final conf = r.confidence > 0.8
            ? PredictionConfidence.high
            : r.confidence > 0.6
                ? PredictionConfidence.medium
                : PredictionConfidence.low;
        results.add(PredictedTransaction(
          id: 'rec_${r.merchantNormalized}_${next.year}_${next.month}_${next.day}',
          expectedDate: next,
          dateVarianceDays: (r.intervalVarianceDays ~/ 2).clamp(1, 7),
          merchantName: r.merchantNormalized,
          type: r.type,
          typicalAmount: r.typicalAmount,
          amountVariance: r.typicalAmount * 0.1,
          confidence: conf,
          source: r.intervalDays <= 35 ? 'subscription' : 'recurring',
        ));
      }
      next = next.add(Duration(days: r.intervalDays));
    }
    return results;
  }

  static List<PredictedTransaction> _deduplicate(
    List<PredictedTransaction> items,
  ) {
    final seen = <String>{};
    final out = <PredictedTransaction>[];
    for (final item in items) {
      final key =
          '${item.merchantName}_${item.expectedDate.year}_${item.expectedDate.month}';
      if (seen.contains(key)) continue;
      seen.add(key);
      out.add(item);
    }
    out.sort((a, b) => a.expectedDate.compareTo(b.expectedDate));
    return out;
  }
}
