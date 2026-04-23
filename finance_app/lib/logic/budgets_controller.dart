import 'package:flutter/foundation.dart';
import 'package:vittara_fin_os/logic/budget_model.dart';
import 'package:vittara_fin_os/logic/notification_helpers.dart';
import 'package:vittara_fin_os/services/database_service.dart';
import 'package:vittara_fin_os/utils/async_mutex.dart';
import 'package:vittara_fin_os/utils/safe_storage_mixin.dart';

/// Controller for managing budgets and savings planners
class BudgetsController with ChangeNotifier, SafeStorageMixin {
  List<Budget> _budgets = [];
  List<SavingsPlanner> _planners = [];
  bool _isInitialized = false;
  // Static mutex — shared across all instances to prevent concurrent writes
  static final _writeMutex = AsyncMutex();

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

  Future<void> _saveBudgets() async {
    await safeWrite('save budgets', () async {
      await _writeMutex.protect(() async {
        await DatabaseService.instance.upsertDataRowsBatch(
          'budgets', _budgets.map((b) => b.toMap()).toList());
      });
    });
  }

  Future<void> _upsertBudget(Budget b) async {
    await safeWrite('save budget', () async {
      await _writeMutex.protect(() async {
        await DatabaseService.instance.upsertDataRow('budgets', b.id, b.toMap());
      });
    });
  }

  Future<void> _deleteBudget(String id) async {
    await safeWrite('delete budget', () async {
      await _writeMutex.protect(() async {
        await DatabaseService.instance.deleteRow('budgets', id);
      });
    });
  }

  Future<void> _savePlanners() async {
    await safeWrite('save planners', () async {
      await _writeMutex.protect(() async {
        await DatabaseService.instance.upsertDataRowsBatch(
          'savings_planners', _planners.map((p) => p.toMap()).toList());
      });
    });
  }

  Future<void> _upsertPlanner(SavingsPlanner p) async {
    await safeWrite('save planner', () async {
      await _writeMutex.protect(() async {
        await DatabaseService.instance.upsertDataRow(
            'savings_planners', p.id, p.toMap());
      });
    });
  }

  Future<void> _deletePlanner(String id) async {
    await safeWrite('delete planner', () async {
      await _writeMutex.protect(() async {
        await DatabaseService.instance.deleteRow('savings_planners', id);
      });
    });
  }

  Future<void> _loadFromStorage() async {
    final budgetRows = await DatabaseService.instance.getAllData('budgets');
    _budgets = budgetRows.map((m) => Budget.fromMap(m)).toList();

    final plannerRows =
        await DatabaseService.instance.getAllData('savings_planners');
    _planners = plannerRows.map((m) => SavingsPlanner.fromMap(m)).toList();
  }

  Future<void> addBudget(Budget budget) async {
    _budgets.add(budget);
    notifyListeners();
    await _upsertBudget(budget);
  }

  Future<void> updateBudget(Budget budget) async {
    final index = _budgets.indexWhere((b) => b.id == budget.id);
    if (index != -1) {
      _budgets[index] = budget;
      notifyListeners();
      await _upsertBudget(budget);
    }
  }

  Future<void> deleteBudget(String budgetId) async {
    _budgets.removeWhere((b) => b.id == budgetId);
    await _deleteBudget(budgetId);
    notifyListeners();
  }

  Future<void> updateBudgetSpending(String budgetId, double amount) async {
    await _writeMutex.protect(() async {
      final index = _budgets.indexWhere((b) => b.id == budgetId);
      if (index != -1) {
        _budgets[index] = _budgets[index].copyWith(
          spentAmount: _budgets[index].spentAmount + amount,
        );
        await DatabaseService.instance.upsertDataRow(
            'budgets', _budgets[index].id, _budgets[index].toMap());
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
    await _upsertPlanner(planner);
  }

  Future<void> updateSavingsPlanner(SavingsPlanner planner) async {
    final index = _planners.indexWhere((p) => p.id == planner.id);
    if (index != -1) {
      _planners[index] = planner;
      notifyListeners();
      await _upsertPlanner(planner);
    }
  }

  Future<void> deleteSavingsPlanner(String plannerId) async {
    _planners.removeWhere((p) => p.id == plannerId);
    notifyListeners();
    await _deletePlanner(plannerId);
  }

  Future<void> addSavingsContribution(String plannerId, double amount) async {
    final index = _planners.indexWhere((p) => p.id == plannerId);
    if (index != -1) {
      _planners[index] = _planners[index].copyWith(
        currentMonthSaved: _planners[index].currentMonthSaved + amount,
      );
      notifyListeners();
      await _upsertPlanner(_planners[index]);
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
