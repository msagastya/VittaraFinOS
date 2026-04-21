import 'package:vittara_fin_os/logic/transaction_model.dart';
import 'data_readiness.dart';

/// A habit opportunity derived from spending observation.
class HabitOpportunity {
  final String id;
  final String category;

  /// Short description of the opportunity.
  final String observation;

  /// Priority score 0–100. Higher = surface first.
  final double score;

  /// Monthly impact estimate if the habit is formed.
  final double monthlyImpact;

  /// Supporting numbers for question generation.
  final Map<String, dynamic> context;

  const HabitOpportunity({
    required this.id,
    required this.category,
    required this.observation,
    required this.score,
    required this.monthlyImpact,
    required this.context,
  });
}

/// Observes transactions silently and ranks habit opportunities.
/// Returns an empty list until data readiness is met (14+ days, 20+ transactions).
class HabitObservationEngine {
  HabitObservationEngine._();

  static List<HabitOpportunity> observe({
    required List<Transaction> transactions,
    required DataReadiness readiness,
  }) {
    if (!readiness.canBuildHabits) return [];

    final opportunities = <HabitOpportunity>[];
    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(days: 60));
    final recent =
        transactions.where((t) => t.dateTime.isAfter(cutoff)).toList();

    // Total income over period (for ratio calculations)
    final income = recent
        .where((t) => t.type == TransactionType.income)
        .fold(0.0, (s, t) => s + t.amount);
    final monthlyIncome = income / 2.0; // 2-month window

    // Build per-category spending data
    final catData = <String, _CatStats>{};
    for (final t in recent.where((t) => t.type == TransactionType.expense)) {
      final cat = (t.metadata?['categoryName'] as String?) ?? 'Other';
      catData.putIfAbsent(cat, () => _CatStats()).add(t);
    }

    for (final entry in catData.entries) {
      final cat = entry.key;
      final stats = entry.value;
      if (stats.txList.length < 3) continue;

      final monthlyAvg = stats.total / 2.0;
      final incomeShare = monthlyIncome > 0 ? monthlyAvg / monthlyIncome * 100 : 0.0;

      // High-variance category: some weeks nothing, some weeks a lot
      final weeklyAmounts = _groupByWeek(stats.txList, now);
      final weeklyAvg = weeklyAmounts.isEmpty
          ? 0.0
          : weeklyAmounts.fold(0.0, (s, v) => s + v) / weeklyAmounts.length;
      final weeklyVariance = weeklyAmounts.isEmpty
          ? 0.0
          : weeklyAmounts
                  .map((v) => (v - weeklyAvg) * (v - weeklyAvg))
                  .fold(0.0, (s, v) => s + v) /
              weeklyAmounts.length;
      final cv = weeklyAvg > 0 ? (weeklyVariance.abs() < 1e-6 ? 0.0 : (weeklyVariance / (weeklyAvg * weeklyAvg)).abs()) : 0.0;

      // High-share categories are prime habit candidates
      if (incomeShare > 15 && monthlyAvg > 2000) {
        final score = _score(incomeShare, stats.txList.length, cv);
        opportunities.add(HabitOpportunity(
          id: 'high_share_$cat',
          category: cat,
          observation: '$cat takes up ${incomeShare.toStringAsFixed(0)}% of your income.',
          score: score,
          monthlyImpact: monthlyAvg * 0.20, // 20% reduction potential
          context: {
            'monthlyAvg': monthlyAvg,
            'incomeShare': incomeShare,
            'txCount': stats.txList.length,
            'weeklyAvg': weeklyAvg,
          },
        ));
      }

      // High-variance: spend is erratic — good candidate for a weekly limit habit
      if (cv > 0.8 && stats.txList.length >= 4 && monthlyAvg > 1500) {
        final score = _score(incomeShare, stats.txList.length, cv) * 0.8;
        opportunities.add(HabitOpportunity(
          id: 'high_variance_$cat',
          category: cat,
          observation:
              '$cat spending varies a lot — sometimes ₹${(weeklyAvg * 0.3).toInt()}/week, sometimes ₹${(weeklyAvg * 2.2).toInt()}/week.',
          score: score,
          monthlyImpact: monthlyAvg * 0.15,
          context: {
            'monthlyAvg': monthlyAvg,
            'weeklyAvg': weeklyAvg,
            'variance': cv,
            'txCount': stats.txList.length,
          },
        ));
      }
    }

    // Investment gap check
    final totalExpense = catData.values.fold(0.0, (s, v) => s + v.total) / 2;
    final totalInvested = recent
        .where((t) => t.type == TransactionType.investment)
        .fold(0.0, (s, t) => s + t.amount.abs()) / 2;
    if (monthlyIncome > 0 && totalInvested / monthlyIncome < 0.10) {
      opportunities.add(HabitOpportunity(
        id: 'invest_habit',
        category: 'Investments',
        observation:
            'You\'re investing ${(totalInvested / monthlyIncome * 100).toStringAsFixed(0)}% of income — under the recommended 10%.',
        score: 60,
        monthlyImpact: monthlyIncome * 0.05,
        context: {
          'monthlyIncome': monthlyIncome,
          'currentInvested': totalInvested,
          'targetRate': 0.10,
        },
      ));
    }

    // Sort by score descending
    opportunities.sort((a, b) => b.score.compareTo(a.score));
    return opportunities.take(5).toList();
  }

  static double _score(double incomeShare, int txCount, double cv) {
    return (incomeShare * 2 + txCount * 1.5 + cv * 10).clamp(0, 100);
  }

  static List<double> _groupByWeek(List<Transaction> txList, DateTime now) {
    final weeks = <int, double>{};
    for (final t in txList) {
      final weekKey = now.difference(t.dateTime).inDays ~/ 7;
      weeks[weekKey] = (weeks[weekKey] ?? 0) + t.amount.abs();
    }
    return weeks.values.toList();
  }
}

class _CatStats {
  final List<Transaction> txList = [];
  double total = 0;
  void add(Transaction t) {
    txList.add(t);
    total += t.amount.abs();
  }
}
