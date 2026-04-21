import 'package:vittara_fin_os/logic/goal_model.dart';
import 'package:vittara_fin_os/logic/transaction_model.dart';

/// ETA analysis for a single goal.
class GoalTimelineAnalysis {
  final String goalId;
  final String goalName;

  /// Predicted completion date based on current contribution rate.
  final DateTime? predictedCompletionDate;

  /// Monthly contribution rate observed over recent history.
  final double monthlyContributionRate;

  /// Months until completion at current rate (null if no contributions).
  final double? monthsToCompletion;

  /// Whether the goal ETA is slipping relative to the original target date.
  final bool isSlipping;

  /// How many months the current ETA overshoots the target date.
  /// Positive = behind schedule. Negative = ahead.
  final double targetOvershootMonths;

  /// Single highest-impact action: (description, months saved).
  final _WhatIfAction? topAction;

  const GoalTimelineAnalysis({
    required this.goalId,
    required this.goalName,
    this.predictedCompletionDate,
    required this.monthlyContributionRate,
    this.monthsToCompletion,
    required this.isSlipping,
    required this.targetOvershootMonths,
    this.topAction,
  });

  String get statusSummary {
    if (monthlyContributionRate <= 0) {
      return 'No contributions yet — set a monthly savings target to see your ETA.';
    }
    if (monthsToCompletion == null) return 'On track';
    if (targetOvershootMonths > 0) {
      final m = targetOvershootMonths.round();
      return 'Running $m month${m == 1 ? '' : 's'} behind target.';
    }
    final ahead = (-targetOvershootMonths).round();
    if (ahead == 0) return 'On track to hit your target date.';
    return 'On track — $ahead month${ahead == 1 ? '' : 's'} ahead of schedule.';
  }
}

class _WhatIfAction {
  final String description;
  final double monthsSaved;
  const _WhatIfAction(this.description, this.monthsSaved);
}

/// Ranked what-if scenario for the goal list view.
class GoalWhatIf {
  final String goalId;
  final String description; // "Reduce dining by ₹2,000/month"
  final double monthsSaved;
  const GoalWhatIf({
    required this.goalId,
    required this.description,
    required this.monthsSaved,
  });
}

class GoalTimeline {
  GoalTimeline._();

  /// Analyse all active goals and return ranked timeline analyses.
  static List<GoalTimelineAnalysis> analyse({
    required List<Goal> goals,
    required List<Transaction> transactions,
  }) {
    final activeGoals = goals.where((g) => !g.isCompleted).toList();
    final results = <GoalTimelineAnalysis>[];

    for (final goal in activeGoals) {
      results.add(_analyseGoal(goal, transactions));
    }

    // Sort by urgency: slipping goals first, then by target date
    results.sort((a, b) {
      if (a.isSlipping && !b.isSlipping) return -1;
      if (!a.isSlipping && b.isSlipping) return 1;
      return b.targetOvershootMonths.compareTo(a.targetOvershootMonths);
    });

    return results;
  }

  static GoalTimelineAnalysis _analyseGoal(
    Goal goal,
    List<Transaction> transactions,
  ) {
    final now = DateTime.now();

    // Use contribution history on the goal itself for the monthly rate.
    // Fall back to linked-account income transactions if no contributions recorded.
    double monthlyRate = _estimateMonthlyRate(goal, transactions, now);

    final remaining = goal.remainingAmount;

    double? monthsToCompletion;
    DateTime? predictedCompletion;
    if (monthlyRate > 0 && remaining > 0) {
      monthsToCompletion = remaining / monthlyRate;
      predictedCompletion = DateTime(
        now.year,
        now.month + monthsToCompletion.ceil(),
        now.day,
      );
    } else if (remaining <= 0) {
      monthsToCompletion = 0;
      predictedCompletion = now;
    }

    final targetMonthsRemaining = goal.monthsRemaining.toDouble();
    double overshoot = 0;
    bool slipping = false;
    if (monthsToCompletion != null) {
      overshoot = monthsToCompletion - targetMonthsRemaining;
      slipping = overshoot > 1.0;
    }

    // What-if: what if dining spend reduced by ₹2K/month?
    _WhatIfAction? topAction;
    if (monthlyRate > 0 && remaining > 0) {
      final diningSpend = _avgMonthlyCategorySpend(transactions, now, 'Dining') +
          _avgMonthlyCategorySpend(transactions, now, 'Food') +
          _avgMonthlyCategorySpend(transactions, now, 'Restaurants');
      if (diningSpend > 2000) {
        final boost = 2000.0;
        final newMonths = remaining / (monthlyRate + boost);
        final saved = monthsToCompletion! - newMonths;
        if (saved > 0.3) {
          topAction = _WhatIfAction(
            'Reduce dining by ₹2,000/month → goal ${saved.toStringAsFixed(1)} months earlier',
            saved,
          );
        }
      }
    }

    return GoalTimelineAnalysis(
      goalId: goal.id,
      goalName: goal.name,
      predictedCompletionDate: predictedCompletion,
      monthlyContributionRate: monthlyRate,
      monthsToCompletion: monthsToCompletion,
      isSlipping: slipping,
      targetOvershootMonths: overshoot,
      topAction: topAction != null
          ? topAction
          : null,
    );
  }

  static double _estimateMonthlyRate(
    Goal goal,
    List<Transaction> transactions,
    DateTime now,
  ) {
    // Use actual contributions if available
    if (goal.contributions.isNotEmpty) {
      final sorted = [...goal.contributions]
        ..sort((a, b) => b.date.compareTo(a.date));
      final recent = sorted
          .where((c) =>
              c.date.isAfter(now.subtract(const Duration(days: 90))))
          .toList();
      if (recent.isNotEmpty) {
        final total = recent.fold(0.0, (s, c) => s + c.amount);
        return total / 3; // 3-month average
      }
      // Use all contributions
      final total = goal.contributions.fold(0.0, (s, c) => s + c.amount);
      final months = now.difference(goal.createdDate).inDays / 30.0;
      if (months > 0) return total / months;
    }

    // Fallback: use average monthly savings from transactions
    final cutoff = now.subtract(const Duration(days: 90));
    final income = transactions
        .where((t) =>
            t.type == TransactionType.income && t.dateTime.isAfter(cutoff))
        .fold(0.0, (s, t) => s + t.amount);
    final expense = transactions
        .where((t) =>
            t.type == TransactionType.expense && t.dateTime.isAfter(cutoff))
        .fold(0.0, (s, t) => s + t.amount.abs());
    final monthlySavings = (income - expense) / 3;
    return monthlySavings > 0 ? monthlySavings * 0.3 : 0; // assume 30% allocated to goals
  }

  static double _avgMonthlyCategorySpend(
    List<Transaction> transactions,
    DateTime now,
    String categoryName,
  ) {
    final cutoff = now.subtract(const Duration(days: 90));
    final total = transactions
        .where((t) =>
            t.type == TransactionType.expense &&
            t.dateTime.isAfter(cutoff) &&
            ((t.metadata?['categoryName'] as String?) ?? '')
                .toLowerCase()
                .contains(categoryName.toLowerCase()))
        .fold(0.0, (s, t) => s + t.amount.abs());
    return total / 3;
  }
}
