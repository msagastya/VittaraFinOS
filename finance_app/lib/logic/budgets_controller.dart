import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vittara_fin_os/logic/budget_model.dart';

/// Controller for managing budgets and savings planners
class BudgetsController extends ChangeNotifier {
  static const String _budgetsKey = 'budgets';
  static const String _plannersKey = 'savings_planners';

  List<Budget> _budgets = [];
  List<SavingsPlanner> _planners = [];
  bool _isInitialized = false;

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
    } catch (e) {
      debugPrint('Error loading budgets/planners: $e');
    }
  }

  Future<void> reloadFromStorage() async {
    try {
      await _loadFromStorage();
      _isInitialized = true;
      notifyListeners();
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
    notifyListeners();
    await _saveBudgets();
  }

  Future<void> updateBudgetSpending(String budgetId, double amount) async {
    final index = _budgets.indexWhere((b) => b.id == budgetId);
    if (index != -1) {
      _budgets[index] = _budgets[index].copyWith(
        spentAmount: _budgets[index].spentAmount + amount,
      );
      notifyListeners();
      await _saveBudgets();
    }
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

  double get totalMonthlySavingsTarget {
    return _planners.fold(0, (sum, planner) => sum + planner.monthlyTarget);
  }

  double get totalMonthlySaved {
    return _planners.fold(0, (sum, planner) => sum + planner.currentMonthSaved);
  }
}
