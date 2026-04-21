import 'package:vittara_fin_os/logic/transaction_model.dart';

class BudgetPrediction {
  final String budgetId;
  final String budgetName;
  final String? categoryId;
  final double budgetAmount;
  final double spentSoFar;
  final double remainingAmount;
  final int? daysUntilExhaustion; // null = won't exhaust this period
  final DateTime? predictedExhaustionDate;
  final double dailySpendRate;
  final int daysRemainingInPeriod;

  const BudgetPrediction({
    required this.budgetId,
    required this.budgetName,
    required this.categoryId,
    required this.budgetAmount,
    required this.spentSoFar,
    required this.remainingAmount,
    this.daysUntilExhaustion,
    this.predictedExhaustionDate,
    required this.dailySpendRate,
    required this.daysRemainingInPeriod,
  });

  double get spendPercent =>
      budgetAmount > 0 ? (spentSoFar / budgetAmount).clamp(0.0, 1.0) : 0.0;

  /// Whether the exhaustion warning is actionable (5+ days remain to act).
  bool get isActionable =>
      daysUntilExhaustion != null && daysUntilExhaustion! >= 1;

  String get exhaustionSummary {
    if (daysUntilExhaustion == null) return 'On track';
    if (daysUntilExhaustion! <= 0) return 'Budget already exhausted';
    if (daysUntilExhaustion! == 1) return 'Exhausts tomorrow';
    return 'Exhausts in $daysUntilExhaustion days';
  }
}

class BudgetExhaustionPredictor {
  BudgetExhaustionPredictor._();

  /// Predict exhaustion dates for all active budgets.
  ///
  /// [budgets] — raw budget maps from BudgetsController.
  /// [transactions] — all transactions (used to compute spend rate).
  static List<BudgetPrediction> predict({
    required List<Transaction> transactions,
    required List<Map<String, dynamic>> budgets,
  }) {
    final now = DateTime.now();
    final results = <BudgetPrediction>[];

    for (final budget in budgets) {
      try {
        final id = budget['id'] as String? ?? '';
        final name = budget['name'] as String? ?? 'Budget';
        final categoryId = budget['categoryId'] as String?;
        final budgetAmount = (budget['amount'] as num?)?.toDouble() ?? 0;
        final periodStr = budget['period'] as String? ?? 'monthly';
        if (budgetAmount <= 0) continue;

        // Determine period start/end
        final periodDates = _getPeriodDates(now, periodStr, budget);
        final periodStart = periodDates.$1;
        final periodEnd = periodDates.$2;
        final totalDays = periodEnd.difference(periodStart).inDays + 1;
        final daysElapsed = now.difference(periodStart).inDays + 1;
        final daysRemaining = periodEnd.difference(now).inDays + 1;

        // Sum transactions in this period for this category
        final periodTxs = transactions.where((tx) {
          if (tx.type != TransactionType.expense) return false;
          if (!tx.dateTime.isAfter(periodStart.subtract(const Duration(seconds: 1)))) return false;
          if (!tx.dateTime.isBefore(periodEnd.add(const Duration(days: 1)))) return false;
          if (categoryId != null) {
            return (tx.metadata?['categoryId'] as String?) == categoryId;
          }
          return true;
        }).toList();

        final spent = periodTxs.fold(0.0, (sum, tx) => sum + tx.amount);
        final remaining = (budgetAmount - spent).clamp(0.0, budgetAmount);

        // Daily spend rate (from days elapsed)
        final dailyRate =
            daysElapsed > 0 ? spent / daysElapsed : 0.0;

        // Predict exhaustion
        int? daysUntil;
        DateTime? exhaustionDate;
        if (dailyRate > 0 && remaining > 0) {
          final daysToExhaust = (remaining / dailyRate).ceil();
          if (daysToExhaust < daysRemaining) {
            daysUntil = daysToExhaust;
            exhaustionDate =
                now.add(Duration(days: daysToExhaust));
          }
        } else if (remaining <= 0) {
          daysUntil = 0;
          exhaustionDate = now;
        }

        results.add(BudgetPrediction(
          budgetId: id,
          budgetName: name,
          categoryId: categoryId,
          budgetAmount: budgetAmount,
          spentSoFar: spent,
          remainingAmount: remaining,
          daysUntilExhaustion: daysUntil,
          predictedExhaustionDate: exhaustionDate,
          dailySpendRate: dailyRate,
          daysRemainingInPeriod: daysRemaining.clamp(0, totalDays),
        ));
      } catch (_) {
        continue;
      }
    }

    // Sort: most urgent first
    results.sort((a, b) {
      final aD = a.daysUntilExhaustion ?? 9999;
      final bD = b.daysUntilExhaustion ?? 9999;
      return aD.compareTo(bD);
    });

    return results;
  }

  static (DateTime, DateTime) _getPeriodDates(
      DateTime now, String period, Map<String, dynamic> budget) {
    switch (period) {
      case 'weekly':
        final startOfWeek =
            now.subtract(Duration(days: now.weekday - 1));
        final s = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
        return (s, s.add(const Duration(days: 6)));
      case 'quarterly':
        final q = ((now.month - 1) ~/ 3);
        final s = DateTime(now.year, q * 3 + 1, 1);
        final e = DateTime(now.year, q * 3 + 4, 0);
        return (s, e);
      case 'yearly':
        return (DateTime(now.year, 1, 1), DateTime(now.year, 12, 31));
      case 'monthly':
      default:
        final s = DateTime(now.year, now.month, 1);
        final e = DateTime(now.year, now.month + 1, 0);
        return (s, e);
    }
  }
}
