import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vittara_fin_os/logic/goal_model.dart';

/// Controller for managing financial goals
class GoalsController extends ChangeNotifier {
  static const String _storageKey = 'goals';

  List<Goal> _goals = [];
  bool _isInitialized = false;

  List<Goal> get goals => _goals;
  List<Goal> get activeGoals => _goals.where((g) => !g.isCompleted).toList();
  List<Goal> get completedGoals => _goals.where((g) => g.isCompleted).toList();

  /// Initialize and load goals from storage
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final String? goalsJson = prefs.getString(_storageKey);

      if (goalsJson != null && goalsJson.isNotEmpty) {
        final List<dynamic> decodedList = json.decode(goalsJson);
        _goals = decodedList.map((item) => Goal.fromMap(item)).toList();
      }

      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading goals: $e');
    }
  }

  /// Save goals to storage
  Future<void> _saveGoals() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String goalsJson = json.encode(_goals.map((g) => g.toMap()).toList());
      await prefs.setString(_storageKey, goalsJson);
    } catch (e) {
      debugPrint('Error saving goals: $e');
    }
  }

  /// Add a new goal
  Future<void> addGoal(Goal goal) async {
    _goals.add(goal);
    notifyListeners();
    await _saveGoals();
  }

  /// Update an existing goal
  Future<void> updateGoal(Goal goal) async {
    final index = _goals.indexWhere((g) => g.id == goal.id);
    if (index != -1) {
      _goals[index] = goal;
      notifyListeners();
      await _saveGoals();
    }
  }

  /// Delete a goal
  Future<void> deleteGoal(String goalId) async {
    _goals.removeWhere((g) => g.id == goalId);
    notifyListeners();
    await _saveGoals();
  }

  /// Add contribution to a goal
  Future<void> addContribution(
    String goalId,
    GoalContribution contribution,
  ) async {
    final index = _goals.indexWhere((g) => g.id == goalId);
    if (index != -1) {
      final goal = _goals[index];
      final updatedContributions = [...goal.contributions, contribution];
      final newCurrentAmount = goal.currentAmount + contribution.amount;

      // Check if goal is completed
      final isCompleted = newCurrentAmount >= goal.targetAmount;

      _goals[index] = goal.copyWith(
        currentAmount: newCurrentAmount,
        contributions: updatedContributions,
        isCompleted: isCompleted,
        completedDate: isCompleted ? DateTime.now() : null,
      );

      notifyListeners();
      await _saveGoals();
    }
  }

  /// Withdraw from a goal
  Future<void> withdrawFromGoal(
    String goalId,
    double amount,
    String? notes,
  ) async {
    final index = _goals.indexWhere((g) => g.id == goalId);
    if (index != -1) {
      final goal = _goals[index];
      final newCurrentAmount = ((goal.currentAmount - amount).clamp(0, goal.targetAmount) as num).toDouble();

      _goals[index] = goal.copyWith(
        currentAmount: newCurrentAmount,
        isCompleted: false,
        completedDate: null,
      );

      notifyListeners();
      await _saveGoals();
    }
  }

  /// Mark goal as completed
  Future<void> completeGoal(String goalId) async {
    final index = _goals.indexWhere((g) => g.id == goalId);
    if (index != -1) {
      _goals[index] = _goals[index].copyWith(
        isCompleted: true,
        completedDate: DateTime.now(),
      );
      notifyListeners();
      await _saveGoals();
    }
  }

  /// Reopen a completed goal
  Future<void> reopenGoal(String goalId) async {
    final index = _goals.indexWhere((g) => g.id == goalId);
    if (index != -1) {
      _goals[index] = _goals[index].copyWith(
        isCompleted: false,
        completedDate: null,
      );
      notifyListeners();
      await _saveGoals();
    }
  }

  /// Get total target amount across all active goals
  double get totalTargetAmount {
    return activeGoals.fold(0, (sum, goal) => sum + goal.targetAmount);
  }

  /// Get total saved amount across all active goals
  double get totalSavedAmount {
    return activeGoals.fold(0, (sum, goal) => sum + goal.currentAmount);
  }

  /// Get overall progress percentage
  double get overallProgress {
    if (totalTargetAmount == 0) return 0;
    return (totalSavedAmount / totalTargetAmount * 100).clamp(0, 100);
  }

  /// Get goals by type
  List<Goal> getGoalsByType(GoalType type) {
    return _goals.where((g) => g.type == type).toList();
  }

  /// Get goals expiring soon (within days)
  List<Goal> getGoalsExpiringSoon({int days = 30}) {
    final cutoffDate = DateTime.now().add(Duration(days: days));
    return activeGoals
        .where((g) => g.targetDate.isBefore(cutoffDate))
        .toList()
      ..sort((a, b) => a.targetDate.compareTo(b.targetDate));
  }

  /// Get goals behind schedule
  List<Goal> getGoalsBehindSchedule() {
    return activeGoals.where((g) => !g.isOnTrack).toList();
  }

  /// Get recommended monthly savings across all goals
  double get totalRecommendedMonthlySavings {
    return activeGoals.fold(0, (sum, goal) => sum + goal.recommendedMonthlySavings);
  }
}
