import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vittara_fin_os/logic/transaction_model.dart';
import 'habit_constructor.dart';

/// T-104: Weekly habit progress check.
///
/// For each confirmed habit, counts matching transactions in the past 7 days
/// and produces a [HabitWeeklyProgress] record.
/// Designed to run on app start or on Sunday — not a scheduled job.
class HabitWeeklyChecker {
  HabitWeeklyChecker._();

  static const String _progressKey = 'habit_weekly_progress';
  static const String _weekCountKey = 'habit_week_counts';

  /// Run the weekly check for all confirmed habits.
  /// Returns a list of progress records (one per active habit).
  static Future<List<HabitWeeklyProgress>> check({
    required List<Transaction> transactions,
  }) async {
    final contracts = await HabitConstructor.loadAll();
    final confirmed = contracts.where((h) => h.confirmedAt != null && h.isActive).toList();

    final results = <HabitWeeklyProgress>[];
    final now = DateTime.now();
    final weekStart = now.subtract(const Duration(days: 7));

    for (final habit in confirmed) {
      final matchingTx = transactions.where((t) {
        if (t.dateTime.isBefore(weekStart)) return false;
        final cat = (t.metadata?['categoryName'] as String?) ?? '';
        final merchant = (t.metadata?['merchant'] as String?) ?? t.description;
        return cat.toLowerCase() == habit.category.toLowerCase() ||
            merchant.toLowerCase().contains(habit.category.toLowerCase());
      }).toList();

      final actualCount = matchingTx.length;
      final actualSpend = matchingTx.fold(0.0, (s, t) => s + t.amount.abs());

      // Load stored week count for streak calculation
      final prefs = await SharedPreferences.getInstance();
      final weekCountsRaw = prefs.getString('${_weekCountKey}_${habit.id}');
      final weekCounts = weekCountsRaw != null
          ? (jsonDecode(weekCountsRaw) as List).cast<int>()
          : <int>[];

      results.add(HabitWeeklyProgress(
        habit: habit,
        actualCount: actualCount,
        actualSpend: actualSpend,
        weeklyTarget: habit.weeklyTarget,
        typicalSpend: habit.targetValue,
        weekHistory: weekCounts,
      ));
    }

    // Persist progress
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(results.map((r) => r.toMap()).toList());
    await prefs.setString(_progressKey, encoded);

    return results;
  }

  /// Record completion of the current week for a habit (call on week boundary).
  /// T-107: After 4 consecutive logged weeks, returns true to trigger celebration.
  static Future<bool> recordWeek(HabitContract habit, int actualCount) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '${_weekCountKey}_${habit.id}';
    final existing = prefs.getString(key);
    final counts = existing != null
        ? (jsonDecode(existing) as List).cast<int>()
        : <int>[];
    counts.add(actualCount);
    if (counts.length > 12) counts.removeAt(0); // keep last 12 weeks
    await prefs.setString(key, jsonEncode(counts));

    // T-107: Check for 4-week streak milestone
    if (counts.length >= 4) {
      final last4 = counts.sublist(counts.length - 4);
      final allHit = last4.every((c) => c >= habit.weeklyTarget);
      final celebrationKey = 'habit_celebrated_4w_${habit.id}';
      final alreadyCelebrated = prefs.getBool(celebrationKey) ?? false;
      if (allHit && !alreadyCelebrated) {
        await prefs.setBool(celebrationKey, true);
        return true; // caller should show celebration
      }
    }
    return false;
  }

  /// Load the last persisted progress list (for display without re-running).
  static Future<List<HabitWeeklyProgress>> loadLast() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_progressKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    final contracts = await HabitConstructor.loadAll();
    final contractMap = {for (final c in contracts) c.id: c};

    final results = <HabitWeeklyProgress>[];
    for (final item in list) {
      final m = item as Map<String, dynamic>;
      final habitId = m['habitId'] as String?;
      if (habitId == null || !contractMap.containsKey(habitId)) continue;
      results.add(HabitWeeklyProgress.fromMap(m, contractMap[habitId]!));
    }
    return results;
  }
}

/// T-104: Progress of a single habit for the current week.
class HabitWeeklyProgress {
  final HabitContract habit;
  final int actualCount;
  final double actualSpend;
  final int weeklyTarget;
  final double typicalSpend;
  /// Last N weeks' actual counts (oldest first). Used for sparkline.
  final List<int> weekHistory;

  const HabitWeeklyProgress({
    required this.habit,
    required this.actualCount,
    required this.actualSpend,
    required this.weeklyTarget,
    required this.typicalSpend,
    this.weekHistory = const [],
  });

  bool get isOnTrack => actualCount >= weeklyTarget;

  /// T-107: Number of consecutive weeks this habit was hit.
  int get streakWeeks {
    if (weekHistory.isEmpty) return 0;
    int streak = 0;
    for (int i = weekHistory.length - 1; i >= 0; i--) {
      if (weekHistory[i] >= weeklyTarget) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  int get bestWeek =>
      weekHistory.isEmpty ? actualCount : weekHistory.reduce((a, b) => a > b ? a : b);

  Map<String, dynamic> toMap() => {
        'habitId': habit.id,
        'actualCount': actualCount,
        'actualSpend': actualSpend,
        'weeklyTarget': weeklyTarget,
        'typicalSpend': typicalSpend,
        'weekHistory': weekHistory,
      };

  factory HabitWeeklyProgress.fromMap(
      Map<String, dynamic> m, HabitContract habit) =>
      HabitWeeklyProgress(
        habit: habit,
        actualCount: (m['actualCount'] as int?) ?? 0,
        actualSpend: (m['actualSpend'] as num?)?.toDouble() ?? 0,
        weeklyTarget: (m['weeklyTarget'] as int?) ?? 1,
        typicalSpend: (m['typicalSpend'] as num?)?.toDouble() ?? 0,
        weekHistory: (m['weekHistory'] as List?)?.cast<int>() ?? [],
      );
}
