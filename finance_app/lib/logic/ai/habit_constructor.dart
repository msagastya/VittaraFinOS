import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'habit_observation_engine.dart';

enum HabitType { limit, streak, reduction, frequency }

enum HabitPeriod { daily, weekly, monthly }

enum DifficultyLevel { easy, moderate, challenging }

enum BehavioralNudgeStyle { streak, gain, loss, identity, none }

/// A fully constructed habit contract built from conversational answers.
class HabitContract {
  final String id;
  final String title;
  final String category;
  final HabitType type;
  final double targetValue;
  final HabitPeriod period;
  final DifficultyLevel difficulty;
  final DateTime startDate;
  final BehavioralNudgeStyle nudgeStyle;
  final bool isActive;
  final DateTime? pausedUntil;
  /// T-103: Timestamp when the user confirmed tracking this habit.
  final DateTime? confirmedAt;
  /// T-103: Weekly frequency target derived from the habit's pattern.
  final int weeklyTarget;

  const HabitContract({
    required this.id,
    required this.title,
    required this.category,
    required this.type,
    required this.targetValue,
    required this.period,
    required this.difficulty,
    required this.startDate,
    required this.nudgeStyle,
    this.isActive = true,
    this.pausedUntil,
    this.confirmedAt,
    this.weeklyTarget = 1,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'category': category,
        'type': type.index,
        'targetValue': targetValue,
        'period': period.index,
        'difficulty': difficulty.index,
        'startDate': startDate.toIso8601String(),
        'nudgeStyle': nudgeStyle.index,
        'isActive': isActive,
        'pausedUntil': pausedUntil?.toIso8601String(),
        'confirmedAt': confirmedAt?.toIso8601String(),
        'weeklyTarget': weeklyTarget,
      };

  factory HabitContract.fromMap(Map<String, dynamic> m) => HabitContract(
        id: m['id'] as String,
        title: m['title'] as String,
        category: m['category'] as String,
        type: HabitType.values[(m['type'] as int).clamp(0, HabitType.values.length - 1)],
        targetValue: (m['targetValue'] as num).toDouble(),
        period: HabitPeriod.values[(m['period'] as int).clamp(0, HabitPeriod.values.length - 1)],
        difficulty: DifficultyLevel.values[
            (m['difficulty'] as int).clamp(0, DifficultyLevel.values.length - 1)],
        startDate: DateTime.parse(m['startDate'] as String),
        nudgeStyle: BehavioralNudgeStyle.values[
            (m['nudgeStyle'] as int).clamp(0, BehavioralNudgeStyle.values.length - 1)],
        isActive: m['isActive'] as bool? ?? true,
        pausedUntil: m['pausedUntil'] != null
            ? DateTime.tryParse(m['pausedUntil'] as String)
            : null,
        confirmedAt: m['confirmedAt'] != null
            ? DateTime.tryParse(m['confirmedAt'] as String)
            : null,
        weeklyTarget: (m['weeklyTarget'] as int?) ?? 1,
      );

  /// Create a confirmed copy with the given timestamp and weeklyTarget.
  HabitContract confirm({required DateTime at, required int weeklyTarget}) =>
      HabitContract(
        id: id, title: title, category: category, type: type,
        targetValue: targetValue, period: period, difficulty: difficulty,
        startDate: startDate, nudgeStyle: nudgeStyle, isActive: isActive,
        pausedUntil: pausedUntil,
        confirmedAt: at,
        weeklyTarget: weeklyTarget,
      );
}

class HabitConstructor {
  HabitConstructor._();

  static const String _prefKey = 'ai_habit_contracts';

  /// Build a HabitContract from the collected conversation answers.
  static HabitContract build({
    required HabitOpportunity opportunity,
    required List<Map<String, dynamic>> answers,
  }) {
    final approach = _find(answers, 'approach') as String? ?? 'track';
    final limit = (_find(answers, 'limit') as num?)?.toDouble();
    final difficulty = _parseDifficulty(_find(answers, 'difficulty') as String?);
    final nudge = _parseNudge(_find(answers, 'nudge') as String?);
    final checkIn = _find(answers, 'checkInFrequency') as String?;

    final type = approach == 'limit' ? HabitType.limit : HabitType.streak;
    final period = checkIn == 'daily' ? HabitPeriod.daily : HabitPeriod.weekly;

    final target = limit ??
        (opportunity.context['monthlyAvg'] as num?)?.toDouble() ??
        0.0;

    final title = approach == 'limit'
        ? 'Keep ${opportunity.category} under ₹${_fmt(target)} / ${period == HabitPeriod.weekly ? 'week' : 'month'}'
        : 'Track ${opportunity.category} ${period == HabitPeriod.daily ? 'daily' : 'weekly'}';

    return HabitContract(
      id: 'habit_${opportunity.id}_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      category: opportunity.category,
      type: type,
      targetValue: target,
      period: period,
      difficulty: difficulty,
      startDate: DateTime.now(),
      nudgeStyle: nudge,
    );
  }

  /// Persist a habit contract to SharedPreferences.
  static Future<void> save(HabitContract contract) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(_prefKey) ?? [];
    existing.add(jsonEncode(contract.toMap()));
    await prefs.setStringList(_prefKey, existing);
  }

  /// Load all saved habits.
  static Future<List<HabitContract>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_prefKey) ?? [];
    return raw.map((s) => HabitContract.fromMap(jsonDecode(s) as Map<String, dynamic>)).toList();
  }

  /// Update (replace) an existing habit by id.
  static Future<void> update(HabitContract updated) async {
    final all = await loadAll();
    final idx = all.indexWhere((h) => h.id == updated.id);
    if (idx < 0) return;
    all[idx] = updated;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        _prefKey, all.map((h) => jsonEncode(h.toMap())).toList());
  }

  static dynamic _find(List<Map<String, dynamic>> answers, String key) {
    for (final a in answers.reversed) {
      if (a.containsKey(key)) return a[key];
    }
    return null;
  }

  static DifficultyLevel _parseDifficulty(String? s) {
    switch (s) {
      case 'easy': return DifficultyLevel.easy;
      case 'challenging': return DifficultyLevel.challenging;
      default: return DifficultyLevel.moderate;
    }
  }

  static BehavioralNudgeStyle _parseNudge(String? s) {
    switch (s) {
      case 'streak': return BehavioralNudgeStyle.streak;
      case 'gain': return BehavioralNudgeStyle.gain;
      case 'loss': return BehavioralNudgeStyle.loss;
      case 'identity': return BehavioralNudgeStyle.identity;
      default: return BehavioralNudgeStyle.none;
    }
  }

  static String _fmt(double v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
    return v.toInt().toString();
  }
}
