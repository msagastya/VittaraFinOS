import 'package:vittara_fin_os/logic/transaction_model.dart';
import 'habit_constructor.dart';

/// A nudge to show the user when they're approaching or over their habit limit.
class HabitNudge {
  final String habitId;
  final String message;
  final BehavioralNudgeStyle style;

  /// Whether the limit has been breached (true) or is just approaching (false).
  final bool isBreached;

  /// Current period spend vs target.
  final double currentSpend;
  final double targetSpend;

  const HabitNudge({
    required this.habitId,
    required this.message,
    required this.style,
    required this.isBreached,
    required this.currentSpend,
    required this.targetSpend,
  });

  double get usagePct =>
      targetSpend > 0 ? (currentSpend / targetSpend).clamp(0, 2) : 0;
}

/// Generates nudge messages for active habits based on current spend.
/// Fires max once per day per habit, only when spend is ≥70% of limit.
class BehavioralNudgeEngine {
  BehavioralNudgeEngine._();

  static const double _nudgeThreshold = 0.70;

  /// Compute nudges for all active habits.
  static List<HabitNudge> compute({
    required List<HabitContract> habits,
    required List<Transaction> transactions,
    required int currentStreakDays,
  }) {
    final nudges = <HabitNudge>[];
    final now = DateTime.now();

    for (final habit in habits.where((h) => h.isActive)) {
      if (habit.type != HabitType.limit) continue;

      final spend = _currentPeriodSpend(habit, transactions, now);
      final ratio = habit.targetValue > 0 ? spend / habit.targetValue : 0.0;

      if (ratio < _nudgeThreshold) continue;

      final isBreached = ratio > 1.0;
      final message = _buildMessage(
        habit: habit,
        ratio: ratio,
        isBreached: isBreached,
        streakDays: currentStreakDays,
      );

      nudges.add(HabitNudge(
        habitId: habit.id,
        message: message,
        style: habit.nudgeStyle,
        isBreached: isBreached,
        currentSpend: spend,
        targetSpend: habit.targetValue,
      ));
    }

    return nudges;
  }

  static String _buildMessage({
    required HabitContract habit,
    required double ratio,
    required bool isBreached,
    required int streakDays,
  }) {
    final cat = habit.category;
    final remaining = (habit.targetValue - habit.targetValue * ratio).abs();
    final periodLabel =
        habit.period == HabitPeriod.weekly ? 'weekly' : 'monthly';

    switch (habit.nudgeStyle) {
      case BehavioralNudgeStyle.streak:
        if (streakDays > 0 && !isBreached) {
          return 'You\'re on a $streakDays-day streak — '
              'only ₹${remaining.toInt()} left in your $cat $periodLabel limit.';
        }
        if (isBreached) {
          return 'You\'ve gone over your $cat $periodLabel limit. '
              'Keep tomorrow in check to get your streak back.';
        }
        return 'Getting close to your $cat $periodLabel limit.';

      case BehavioralNudgeStyle.gain:
        if (!isBreached) {
          return '₹${remaining.toInt()} left in your $cat $periodLabel budget — '
              'you\'re ${((1 - ratio) * 100).toStringAsFixed(0)}% away from staying on track.';
        }
        return 'You\'ve exceeded your $cat $periodLabel limit this period.';

      case BehavioralNudgeStyle.loss:
        if (!isBreached) {
          return 'Heads up: ₹${remaining.toInt()} left before you hit your $cat $periodLabel limit.';
        }
        return '$cat spending is over your $periodLabel limit — worth pausing before the next purchase.';

      case BehavioralNudgeStyle.identity:
        if (!isBreached) {
          return 'You\'ve been tracking $cat consistently. '
              'Stay within your limit and keep that momentum going.';
        }
        return 'One over-limit week doesn\'t define you — reset tomorrow.';

      case BehavioralNudgeStyle.none:
        return '';
    }
  }

  static double _currentPeriodSpend(
    HabitContract habit,
    List<Transaction> transactions,
    DateTime now,
  ) {
    DateTime periodStart;
    switch (habit.period) {
      case HabitPeriod.daily:
        periodStart = DateTime(now.year, now.month, now.day);
        break;
      case HabitPeriod.weekly:
        // Start of current week (Monday)
        final weekday = now.weekday;
        periodStart = now.subtract(Duration(days: weekday - 1));
        periodStart = DateTime(periodStart.year, periodStart.month, periodStart.day);
        break;
      case HabitPeriod.monthly:
        periodStart = DateTime(now.year, now.month, 1);
        break;
    }

    return transactions
        .where((t) =>
            t.type == TransactionType.expense &&
            t.dateTime.isAfter(periodStart) &&
            t.dateTime.isBefore(now) &&
            ((t.metadata?['categoryName'] as String?) ?? '') == habit.category)
        .fold(0.0, (s, t) => s + t.amount.abs());
  }
}
