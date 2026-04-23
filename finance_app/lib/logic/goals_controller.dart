import 'package:flutter/foundation.dart';
import 'package:vittara_fin_os/logic/goal_model.dart';
import 'package:vittara_fin_os/services/database_service.dart';
import 'package:vittara_fin_os/utils/async_mutex.dart';
import 'package:vittara_fin_os/utils/safe_storage_mixin.dart';

/// Controller for managing financial goals
class GoalsController with ChangeNotifier, SafeStorageMixin {
  static final _writeMutex = AsyncMutex();

  List<Goal> _goals = [];
  bool _isInitialized = false;

  List<Goal> get goals => _goals;
  List<Goal> get activeGoals => _goals.where((g) => !g.isCompleted).toList();
  List<Goal> get completedGoals => _goals.where((g) => g.isCompleted).toList();

  /// Initialize and load goals from storage
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _loadGoalsFromStorage();
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading goals: $e');
    }
  }

  Future<void> reloadFromStorage() async {
    try {
      await _loadGoalsFromStorage();
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error reloading goals: $e');
    }
  }

  Future<void> _saveGoals() async {
    await safeWrite('save goals', () async {
      await _writeMutex.protect(() async {
        await DatabaseService.instance.upsertDataRowsBatch(
          'goals', _goals.map((g) => g.toMap()).toList());
      });
    });
  }

  Future<void> _upsertOne(Goal goal) async {
    await safeWrite('save goal', () async {
      await _writeMutex.protect(() async {
        await DatabaseService.instance.upsertDataRow(
            'goals', goal.id, goal.toMap());
      });
    });
  }

  Future<void> _deleteOne(String id) async {
    await safeWrite('delete goal', () async {
      await _writeMutex.protect(() async {
        await DatabaseService.instance.deleteRow('goals', id);
      });
    });
  }

  Future<void> _loadGoalsFromStorage() async {
    final rows = await DatabaseService.instance.getAllData('goals');
    _goals = rows.map((m) => Goal.fromMap(m)).toList();
  }

  Future<void> addGoal(Goal goal) async {
    _goals.add(goal);
    notifyListeners();
    await _upsertOne(goal);
  }

  Future<void> updateGoal(Goal goal) async {
    final index = _goals.indexWhere((g) => g.id == goal.id);
    if (index != -1) {
      _goals[index] = goal;
      notifyListeners();
      await _upsertOne(goal);
    }
  }

  Future<void> deleteGoal(String goalId) async {
    _goals.removeWhere((g) => g.id == goalId);
    notifyListeners();
    await _deleteOne(goalId);
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

      // Check if goal is completed (FP tolerance: within 0.005 of target)
      final isCompleted = newCurrentAmount >= goal.targetAmount - 0.005;

      _goals[index] = goal.copyWith(
        currentAmount: newCurrentAmount,
        contributions: updatedContributions,
        isCompleted: isCompleted,
        completedDate: isCompleted ? DateTime.now() : null,
      );

      notifyListeners();
      await _upsertOne(_goals[index]);
    }
  }

  Future<void> withdrawFromGoal(
    String goalId,
    double amount,
    String? notes,
  ) async {
    final index = _goals.indexWhere((g) => g.id == goalId);
    if (index != -1) {
      final goal = _goals[index];
      final newCurrentAmount =
          (goal.currentAmount - amount).clamp(0.0, double.infinity);

      _goals[index] = goal.copyWith(
        currentAmount: newCurrentAmount,
        isCompleted: false,
        completedDate: null,
      );

      notifyListeners();
      await _upsertOne(_goals[index]);
    }
  }

  Future<void> completeGoal(String goalId) async {
    final index = _goals.indexWhere((g) => g.id == goalId);
    if (index != -1) {
      _goals[index] = _goals[index].copyWith(
        isCompleted: true,
        completedDate: DateTime.now(),
      );
      notifyListeners();
      await _upsertOne(_goals[index]);
    }
  }

  Future<void> reopenGoal(String goalId) async {
    final index = _goals.indexWhere((g) => g.id == goalId);
    if (index != -1) {
      _goals[index] = _goals[index].copyWith(
        isCompleted: false,
        completedDate: null,
      );
      notifyListeners();
      await _upsertOne(_goals[index]);
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
    return activeGoals.where((g) => g.targetDate.isBefore(cutoffDate)).toList()
      ..sort((a, b) => a.targetDate.compareTo(b.targetDate));
  }

  /// Get goals behind schedule
  List<Goal> getGoalsBehindSchedule() {
    return activeGoals.where((g) => !g.isOnTrack).toList();
  }

  /// Get recommended monthly savings across all goals
  double get totalRecommendedMonthlySavings {
    return activeGoals.fold(
        0, (sum, goal) => sum + goal.recommendedMonthlySavings);
  }
}
