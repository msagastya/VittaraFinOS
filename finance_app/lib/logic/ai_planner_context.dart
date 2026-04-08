import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum PlanningFocus {
  emergencyFund,
  homeDownPayment,
  debtPayoff,
  retirement,
  education,
  wedding,
  travel,
  investment,
  custom,
}

enum PlanningTimeline {
  threeMonths,
  sixMonths,
  oneYear,
  threeYears,
  fiveYears,
  tenYears,
}

enum RiskProfile { conservative, moderate, aggressive }
enum IncomeStability { stable, variable, freelance, business }

// ─────────────────────────────────────────────────────────────────────────────
// FinancialPlan — a single goal with context for the planner engine.
// Replaces the old single-context AIPlannerContext.
// ─────────────────────────────────────────────────────────────────────────────

class FinancialPlan {
  final String id;
  final String name;                  // user-given label e.g. "Dream Home"
  final PlanningFocus focus;
  final PlanningTimeline timeline;
  final double? targetAmount;         // ₹ goal amount
  final double? monthlyContribution;  // dedicated monthly savings for this goal
  final double currentSaved;          // already saved/invested toward this goal
  final int priority;                 // 1=high, 2=medium, 3=low
  final String? emoji;
  final String? notes;
  final DateTime createdAt;
  final RiskProfile riskProfile;
  final IncomeStability incomeStability;
  final int dependentsCount;          // 0, 1, 2, 3 (3 means 3 or more)

  const FinancialPlan({
    required this.id,
    required this.name,
    required this.focus,
    required this.timeline,
    this.targetAmount,
    this.monthlyContribution,
    this.currentSaved = 0,
    this.priority = 2,
    this.emoji,
    this.notes,
    required this.createdAt,
    this.riskProfile = RiskProfile.moderate,
    this.incomeStability = IncomeStability.stable,
    this.dependentsCount = 0,
  });

  String get focusLabel {
    switch (focus) {
      case PlanningFocus.emergencyFund:   return 'Emergency Fund';
      case PlanningFocus.homeDownPayment: return 'Home Down Payment';
      case PlanningFocus.debtPayoff:      return 'Debt Payoff';
      case PlanningFocus.retirement:      return 'Retirement';
      case PlanningFocus.education:       return 'Education Fund';
      case PlanningFocus.wedding:         return 'Wedding';
      case PlanningFocus.travel:          return 'Travel';
      case PlanningFocus.investment:      return 'Investments';
      case PlanningFocus.custom:          return name;
    }
  }

  String get timelineLabel {
    switch (timeline) {
      case PlanningTimeline.threeMonths: return '3 months';
      case PlanningTimeline.sixMonths:   return '6 months';
      case PlanningTimeline.oneYear:     return '1 year';
      case PlanningTimeline.threeYears:  return '3 years';
      case PlanningTimeline.fiveYears:   return '5 years';
      case PlanningTimeline.tenYears:    return '10 years';
    }
  }

  int get timelineMonths {
    switch (timeline) {
      case PlanningTimeline.threeMonths: return 3;
      case PlanningTimeline.sixMonths:   return 6;
      case PlanningTimeline.oneYear:     return 12;
      case PlanningTimeline.threeYears:  return 36;
      case PlanningTimeline.fiveYears:   return 60;
      case PlanningTimeline.tenYears:    return 120;
    }
  }

  String get priorityLabel {
    switch (priority) {
      case 1: return 'High';
      case 3: return 'Low';
      default: return 'Medium';
    }
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'focus': focus.name,
        'timeline': timeline.name,
        'targetAmount': targetAmount,
        'monthlyContribution': monthlyContribution,
        'currentSaved': currentSaved,
        'priority': priority,
        'emoji': emoji,
        'notes': notes,
        'createdAt': createdAt.toIso8601String(),
        'riskProfile': riskProfile.name,
        'incomeStability': incomeStability.name,
        'dependentsCount': dependentsCount,
      };

  factory FinancialPlan.fromMap(Map<String, dynamic> m) => FinancialPlan(
        id: m['id'] as String? ?? 'plan_unknown',
        name: m['name'] as String? ?? 'My Plan',
        focus: PlanningFocus.values.firstWhere(
          (e) => e.name == m['focus'],
          orElse: () => PlanningFocus.emergencyFund,
        ),
        timeline: PlanningTimeline.values.firstWhere(
          (e) => e.name == m['timeline'],
          orElse: () => PlanningTimeline.oneYear,
        ),
        targetAmount: (m['targetAmount'] as num?)?.toDouble(),
        monthlyContribution: (m['monthlyContribution'] as num?)?.toDouble(),
        currentSaved: (m['currentSaved'] as num?)?.toDouble() ?? 0,
        priority: (m['priority'] as int?) ?? 2,
        emoji: m['emoji'] as String?,
        notes: m['notes'] as String?,
        createdAt: DateTime.tryParse(m['createdAt'] as String? ?? '') ?? DateTime.now(),
        riskProfile: RiskProfile.values.firstWhere(
          (e) => e.name == (m['riskProfile'] as String? ?? ''),
          orElse: () => RiskProfile.moderate,
        ),
        incomeStability: IncomeStability.values.firstWhere(
          (e) => e.name == (m['incomeStability'] as String? ?? ''),
          orElse: () => IncomeStability.stable,
        ),
        dependentsCount: (m['dependentsCount'] as int?) ?? 0,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// FinancialPlansController — manages the list of plans.
// ─────────────────────────────────────────────────────────────────────────────

class FinancialPlansController with ChangeNotifier {
  static const _key = 'financial_plans_v1';
  static const _legacyKey = 'ai_planner_context';

  List<FinancialPlan> _plans = [];
  bool _loaded = false;

  List<FinancialPlan> get plans => List.unmodifiable(_plans);
  bool get loaded => _loaded;

  FinancialPlansController() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);

    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        _plans = list
            .map((e) => FinancialPlan.fromMap(e as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    } else {
      // One-time migration from the old single-context format
      final legacyJson = prefs.getString(_legacyKey);
      if (legacyJson != null) {
        try {
          final m = jsonDecode(legacyJson) as Map<String, dynamic>;
          final focus = PlanningFocus.values.firstWhere(
            (e) => e.name == (m['focus'] as String? ?? ''),
            orElse: () => PlanningFocus.emergencyFund,
          );
          final timeline = PlanningTimeline.values.firstWhere(
            (e) => e.name == (m['timeline'] as String? ?? ''),
            orElse: () => PlanningTimeline.oneYear,
          );
          _plans = [
            FinancialPlan(
              id: 'migrated_1',
              name: _defaultName(focus),
              focus: focus,
              timeline: timeline,
              targetAmount: (m['targetAmount'] as num?)?.toDouble(),
              notes: m['notes'] as String?,
              createdAt: DateTime.tryParse(m['createdAt'] as String? ?? '') ?? DateTime.now(),
            ),
          ];
          await _save();
        } catch (_) {}
      }
    }

    _loaded = true;
    notifyListeners();
  }

  static String _defaultName(PlanningFocus focus) {
    switch (focus) {
      case PlanningFocus.emergencyFund:   return 'Emergency Fund';
      case PlanningFocus.homeDownPayment: return 'Home Down Payment';
      case PlanningFocus.debtPayoff:      return 'Debt Payoff';
      case PlanningFocus.retirement:      return 'Retirement';
      case PlanningFocus.education:       return 'Education Fund';
      case PlanningFocus.wedding:         return 'Wedding';
      case PlanningFocus.travel:          return 'Travel';
      case PlanningFocus.investment:      return 'Investments';
      case PlanningFocus.custom:          return 'My Plan';
    }
  }

  Future<void> add(FinancialPlan plan) async {
    _plans.add(plan);
    _sortByPriority();
    await _save();
    notifyListeners();
  }

  Future<void> update(FinancialPlan plan) async {
    final idx = _plans.indexWhere((p) => p.id == plan.id);
    if (idx < 0) return;
    _plans[idx] = plan;
    _sortByPriority();
    await _save();
    notifyListeners();
  }

  Future<void> delete(String id) async {
    _plans.removeWhere((p) => p.id == id);
    await _save();
    notifyListeners();
  }

  void _sortByPriority() {
    _plans.sort((a, b) => a.priority.compareTo(b.priority));
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key, jsonEncode(_plans.map((p) => p.toMap()).toList()));
  }
}
