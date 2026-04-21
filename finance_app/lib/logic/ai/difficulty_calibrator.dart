import 'package:vittara_fin_os/logic/transaction_model.dart';
import 'habit_constructor.dart';

enum CalibrationSuggestion { easeTarget, changeApproach, keepGoing }

class CalibrationResult {
  final String habitId;
  final CalibrationSuggestion suggestion;

  /// Non-guilt framing message.
  final String message;

  /// New suggested target value (if suggestion == easeTarget).
  final double? suggestedTarget;

  const CalibrationResult({
    required this.habitId,
    required this.suggestion,
    required this.message,
    this.suggestedTarget,
  });
}

/// Monitors habit compliance for 14 days after creation and surfaces
/// a gentle recalibration offer if the user is struggling.
class DifficultyCalibrator {
  DifficultyCalibrator._();

  static const int _monitorDays = 14;
  static const int _failThreshold = 3; // breaks in 14 days → recalibrate

  /// Check if a recalibration offer should be shown for the given habit.
  /// Returns null if calibration is not needed.
  static CalibrationResult? evaluate({
    required HabitContract habit,
    required List<Transaction> transactions,
  }) {
    final now = DateTime.now();
    final since = habit.startDate;
    final daysSinceStart = now.difference(since).inDays;

    // Only evaluate after the monitoring window
    if (daysSinceStart < _monitorDays) return null;

    final breakCount = _countBreaches(habit, transactions, since, now);
    if (breakCount < _failThreshold) return null;

    // Suggest easing the target by 20%
    final easedTarget = habit.targetValue * 1.20;

    return CalibrationResult(
      habitId: habit.id,
      suggestion: CalibrationSuggestion.easeTarget,
      message:
          "This seems tough — you've gone over the limit $breakCount times in the last 2 weeks. "
          "That's completely normal when starting out. Want to ease the target a little, or try a different approach?",
      suggestedTarget: easedTarget,
    );
  }

  static int _countBreaches(
    HabitContract habit,
    List<Transaction> transactions,
    DateTime since,
    DateTime now,
  ) {
    if (habit.type != HabitType.limit) return 0;

    final relevant = transactions.where((t) =>
        t.type == TransactionType.expense &&
        t.dateTime.isAfter(since) &&
        t.dateTime.isBefore(now) &&
        ((t.metadata?['categoryName'] as String?) ?? '') == habit.category);

    // Group by period
    if (habit.period == HabitPeriod.weekly) {
      final weeklySpend = <int, double>{};
      for (final t in relevant) {
        final weekKey = t.dateTime.difference(since).inDays ~/ 7;
        weeklySpend[weekKey] = (weeklySpend[weekKey] ?? 0) + t.amount.abs();
      }
      return weeklySpend.values.where((v) => v > habit.targetValue).length;
    }

    if (habit.period == HabitPeriod.daily) {
      final dailySpend = <int, double>{};
      for (final t in relevant) {
        final dayKey = t.dateTime.difference(since).inDays;
        dailySpend[dayKey] = (dailySpend[dayKey] ?? 0) + t.amount.abs();
      }
      return dailySpend.values.where((v) => v > habit.targetValue).length;
    }

    // Monthly
    final monthSpend = <String, double>{};
    for (final t in relevant) {
      final key = '${t.dateTime.year}_${t.dateTime.month}';
      monthSpend[key] = (monthSpend[key] ?? 0) + t.amount.abs();
    }
    return monthSpend.values.where((v) => v > habit.targetValue).length;
  }
}
