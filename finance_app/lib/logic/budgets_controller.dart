import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vittara_fin_os/logic/budget_model.dart';
import 'package:vittara_fin_os/logic/notification_helpers.dart';
import 'package:vittara_fin_os/utils/async_mutex.dart';

/// Controller for managing budgets and savings planners
class BudgetsController with ChangeNotifier {
  static const String _budgetsKey = 'budgets';
  static const String _plannersKey = 'savings_planners';

  List<Budget> _budgets = [];
  List<SavingsPlanner> _planners = [];
  bool _isInitialized = false;
  final _spendingMutex = AsyncMutex();

  List<Budget> get budgets => _budgets;
  List<Budget> get activeBudgets => _budgets.where((b) => b.isActive).toList();
  List<SavingsPlanner> get savingsplanners => _planners;

  /// Initialize and load data from storage
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _loadFromStorage();
      _isInitialized = true;
      notifyListeners();
      // Fire budget threshold notifications on first load.
      checkAndNotifyBudgetAlerts(_budgets).catchError((e) {
        debugPrint('Budget notification error: $e');
      });
    } catch (e) {
      debugPrint('Error loading budgets/planners: $e');
    }
  }

  Future<void> reloadFromStorage() async {
    try {
      await _loadFromStorage();
      _isInitialized = true;
      notifyListeners();
      // Fire budget threshold notifications after data is refreshed.
      checkAndNotifyBudgetAlerts(_budgets).catchError((e) {
        debugPrint('Budget notification error: $e');
      });
    } catch (e) {
      debugPrint('Error reloading budgets/planners: $e');
    }
  }

  /// Save budgets to storage
  Future<void> _saveBudgets() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String json = jsonEncode(_budgets.map((b) => b.toMap()).toList());
      await prefs.setString(_budgetsKey, json);
    } catch (e) {
      debugPrint('Error saving budgets: $e');
    }
  }

  /// Save savings planners to storage
  Future<void> _savePlanners() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String json = jsonEncode(_planners.map((p) => p.toMap()).toList());
      await prefs.setString(_plannersKey, json);
    } catch (e) {
      debugPrint('Error saving planners: $e');
    }
  }

  Future<void> _loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();

    final String? budgetsJson = prefs.getString(_budgetsKey);
    if (budgetsJson != null && budgetsJson.isNotEmpty) {
      final List<dynamic> decodedList = json.decode(budgetsJson);
      _budgets = decodedList.map((item) => Budget.fromMap(item)).toList();
    } else {
      _budgets = [];
    }

    final String? plannersJson = prefs.getString(_plannersKey);
    if (plannersJson != null && plannersJson.isNotEmpty) {
      final List<dynamic> decodedList = json.decode(plannersJson);
      _planners =
          decodedList.map((item) => SavingsPlanner.fromMap(item)).toList();
    } else {
      _planners = [];
    }
  }

  // Budget operations
  Future<void> addBudget(Budget budget) async {
    _budgets.add(budget);
    notifyListeners();
    await _saveBudgets();
  }

  Future<void> updateBudget(Budget budget) async {
    final index = _budgets.indexWhere((b) => b.id == budget.id);
    if (index != -1) {
      _budgets[index] = budget;
      notifyListeners();
      await _saveBudgets();
    }
  }

  Future<void> deleteBudget(String budgetId) async {
    _budgets.removeWhere((b) => b.id == budgetId);
    await _saveBudgets();
    notifyListeners();
  }

  Future<void> updateBudgetSpending(String budgetId, double amount) async {
    await _spendingMutex.protect(() async {
      final index = _budgets.indexWhere((b) => b.id == budgetId);
      if (index != -1) {
        _budgets[index] = _budgets[index].copyWith(
          spentAmount: _budgets[index].spentAmount + amount,
        );
        await _saveBudgets();
        notifyListeners();
      }
    });
  }

  List<Budget> getBudgetsExceedingLimit() {
    return activeBudgets
        .where((b) => b.status == BudgetStatus.exceeded)
        .toList();
  }

  List<Budget> getBudgetsInWarning() {
    return activeBudgets
        .where((b) => b.status == BudgetStatus.warning)
        .toList();
  }

  // Savings Planner operations
  Future<void> addSavingsPlanner(SavingsPlanner planner) async {
    _planners.add(planner);
    notifyListeners();
    await _savePlanners();
  }

  Future<void> updateSavingsPlanner(SavingsPlanner planner) async {
    final index = _planners.indexWhere((p) => p.id == planner.id);
    if (index != -1) {
      _planners[index] = planner;
      notifyListeners();
      await _savePlanners();
    }
  }

  Future<void> deleteSavingsPlanner(String plannerId) async {
    _planners.removeWhere((p) => p.id == plannerId);
    notifyListeners();
    await _savePlanners();
  }

  Future<void> addSavingsContribution(String plannerId, double amount) async {
    final index = _planners.indexWhere((p) => p.id == plannerId);
    if (index != -1) {
      _planners[index] = _planners[index].copyWith(
        currentMonthSaved: _planners[index].currentMonthSaved + amount,
      );
      notifyListeners();
      await _savePlanners();
    }
  }

  /// Reassign all budgets that reference [oldCategoryName] to 'Other'.
  /// Called before deleting a category that budgets depend on.
  Future<void> reassignCategoryInBudgets(String oldCategoryName) async {
    bool changed = false;
    for (int i = 0; i < _budgets.length; i++) {
      if (_budgets[i].categoryName == oldCategoryName) {
        _budgets[i] = Budget(
          id: _budgets[i].id,
          name: _budgets[i].name,
          categoryId: null,
          categoryName: 'Other',
          limitAmount: _budgets[i].limitAmount,
          spentAmount: _budgets[i].spentAmount,
          period: _budgets[i].period,
          startDate: _budgets[i].startDate,
          endDate: _budgets[i].endDate,
          color: _budgets[i].color,
          isActive: _budgets[i].isActive,
          excludedAccountIds: _budgets[i].excludedAccountIds,
          rollover: _budgets[i].rollover,
          warningThreshold: _budgets[i].warningThreshold,
        );
        changed = true;
      }
    }
    if (changed) {
      await _saveBudgets();
      notifyListeners();
    }
  }

  double get totalMonthlySavingsTarget {
    return _planners.fold(0, (sum, planner) => sum + planner.monthlyTarget);
  }

  double get totalMonthlySaved {
    return _planners.fold(0, (sum, planner) => sum + planner.currentMonthSaved);
  }
}
