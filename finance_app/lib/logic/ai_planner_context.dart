import 'dart:convert';
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

class AIPlannerContext {
  final PlanningFocus focus;
  final PlanningTimeline timeline;
  final double? targetAmount;
  final String? customFocusText; // for PlanningFocus.custom
  final String? notes; // user can add free-text notes/context
  final DateTime createdAt;

  const AIPlannerContext({
    required this.focus,
    required this.timeline,
    this.targetAmount,
    this.customFocusText,
    this.notes,
    required this.createdAt,
  });

  String get focusLabel {
    switch (focus) {
      case PlanningFocus.emergencyFund:
        return 'Emergency Fund';
      case PlanningFocus.homeDownPayment:
        return 'Home Down Payment';
      case PlanningFocus.debtPayoff:
        return 'Debt Payoff';
      case PlanningFocus.retirement:
        return 'Retirement Planning';
      case PlanningFocus.education:
        return 'Education Fund';
      case PlanningFocus.wedding:
        return 'Wedding Fund';
      case PlanningFocus.travel:
        return 'Travel Fund';
      case PlanningFocus.investment:
        return 'Grow Investments';
      case PlanningFocus.custom:
        return customFocusText ?? 'Custom Goal';
    }
  }

  String get timelineLabel {
    switch (timeline) {
      case PlanningTimeline.threeMonths:
        return '3 months';
      case PlanningTimeline.sixMonths:
        return '6 months';
      case PlanningTimeline.oneYear:
        return '1 year';
      case PlanningTimeline.threeYears:
        return '3 years';
      case PlanningTimeline.fiveYears:
        return '5 years';
      case PlanningTimeline.tenYears:
        return '10 years';
    }
  }

  int get timelineMonths {
    switch (timeline) {
      case PlanningTimeline.threeMonths:
        return 3;
      case PlanningTimeline.sixMonths:
        return 6;
      case PlanningTimeline.oneYear:
        return 12;
      case PlanningTimeline.threeYears:
        return 36;
      case PlanningTimeline.fiveYears:
        return 60;
      case PlanningTimeline.tenYears:
        return 120;
    }
  }

  Map<String, dynamic> toMap() => {
        'focus': focus.name,
        'timeline': timeline.name,
        'targetAmount': targetAmount,
        'customFocusText': customFocusText,
        'notes': notes,
        'createdAt': createdAt.toIso8601String(),
      };

  factory AIPlannerContext.fromMap(Map<String, dynamic> m) => AIPlannerContext(
        focus: PlanningFocus.values.firstWhere(
          (e) => e.name == m['focus'],
          orElse: () => PlanningFocus.emergencyFund,
        ),
        timeline: PlanningTimeline.values.firstWhere(
          (e) => e.name == m['timeline'],
          orElse: () => PlanningTimeline.oneYear,
        ),
        targetAmount: (m['targetAmount'] as num?)?.toDouble(),
        customFocusText: m['customFocusText'] as String?,
        notes: m['notes'] as String?,
        createdAt: DateTime.tryParse(m['createdAt'] as String? ?? '') ?? DateTime.now(),
      );

  static Future<AIPlannerContext?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString('ai_planner_context');
    if (json == null) return null;
    try {
      return AIPlannerContext.fromMap(jsonDecode(json) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ai_planner_context', jsonEncode(toMap()));
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('ai_planner_context');
  }
}
