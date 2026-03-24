import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vittara_fin_os/logic/dashboard_widget_model.dart';
import 'dart:convert';

class DashboardController with ChangeNotifier {
  late DashboardConfig _config;
  late SharedPreferences _prefs;
  bool _isInitialized = false;

  // AU6-02 — Cached visible widgets list; invalidated on config change
  List<DashboardWidgetConfig>? _cachedVisibleWidgets;

  static const int gridColumns = 3;

  DashboardConfig get config => _config;
  bool get isInitialized => _isInitialized;

  /// Returns visible widgets sorted by position. Result is cached and
  /// invalidated automatically whenever the config changes.
  List<DashboardWidgetConfig> get visibleWidgets {
    return _cachedVisibleWidgets ??= _config.getVisibleWidgets();
  }

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadConfig();
    _isInitialized = true;
    _cachedVisibleWidgets = null; // invalidate after load
    notifyListeners();
  }

  Future<void> _loadConfig() async {
    final configJson = _prefs.getString('dashboard_config');
    if (configJson != null) {
      try {
        final map = jsonDecode(configJson) as Map<String, dynamic>;
        _config = DashboardConfig.fromMap(map);

        bool changed = _ensureOptionalWidgetsExist();

        // v2 migration: enable health_score + spending_insights for existing users
        if (_config.configVersion < 2) {
          changed = _migrateToV2() || changed;
        }

        // v3 migration: health_score merged into net_worth widget — hide it
        if (_config.configVersion < 3) {
          changed = _migrateToV3() || changed;
        }

        // v4 migration: hide widgets merged into others
        if (_config.configVersion < 4) {
          changed = _migrateToV4() || changed;
        }

        // v5 migration: ai_planner now hosts AI Planner + Savings Planners — make it visible
        if (_config.configVersion < 5) {
          changed = _migrateToV5() || changed;
        }

        // v6 migration: remove obsolete merged widgets from stored config
        if (_config.configVersion < 6) {
          changed = _migrateToV6() || changed;
        }

        if (changed) {
          await saveConfig();
          return;
        }

        // Ensure at least some widgets are visible, otherwise reset
        if (_config.getVisibleWidgets().isEmpty) {
          _config = _getDefaultConfig();
          await saveConfig();
        }
      } catch (e) {
        _config = _getDefaultConfig();
      }
    } else {
      _config = _getDefaultConfig();
    }
  }

  /// Enables health_score and spending_insights and bumps configVersion to 2.
  bool _migrateToV2() {
    final updatedWidgets = _config.widgets.map((w) {
      if (w.id == 'health_score' && !w.isVisible) {
        // Place after the last currently-visible widget
        final lastRow = _config.getVisibleWidgets().fold<int>(
            0, (max, v) => v.gridRow + v.rowSpan - 1 > max ? v.gridRow + v.rowSpan - 1 : max);
        return w.copyWith(isVisible: true, gridRow: lastRow + 1);
      }
      return w;
    }).toList();

    // Place spending_insights after health_score
    final withSpending = updatedWidgets.map((w) {
      if (w.id == 'spending_insights' && !w.isVisible) {
        final hsRow = updatedWidgets.firstWhere((x) => x.id == 'health_score').gridRow;
        final hsSpan = updatedWidgets.firstWhere((x) => x.id == 'health_score').rowSpan;
        return w.copyWith(isVisible: true, gridRow: hsRow + hsSpan);
      }
      return w;
    }).toList();

    _config = _config.copyWith(widgets: withSpending, configVersion: 2);
    return true;
  }

  /// v4: hide widgets whose content was merged into sibling widgets.
  /// notifications_and_actions → transaction_history
  /// monthly_summary (cash flow) → budgets_overview
  /// savings_planners → goals_overview
  /// ai_planner → sip_tracker
  bool _migrateToV4() {
    const hiddenIds = {
      'notifications_and_actions',
      'monthly_summary',
      'savings_planners',
      'ai_planner',
    };
    final updatedWidgets = _config.widgets.map((w) {
      if (hiddenIds.contains(w.id) && w.isVisible) {
        return w.copyWith(isVisible: false);
      }
      return w;
    }).toList();
    _config = _config.copyWith(widgets: updatedWidgets, configVersion: 4);
    return true;
  }

  /// v6: remove obsolete widget entries that were merged into other widgets.
  bool _migrateToV6() {
    const removedIds = {
      'goals_overview',
      'monthly_summary',
      'health_score',
      'notifications_and_actions',
      'savings_planners',
    };
    final updatedWidgets = _config.widgets
        .where((w) => !removedIds.contains(w.id))
        .toList();
    _config = _config.copyWith(widgets: updatedWidgets, configVersion: 6);
    return true;
  }

  /// v5: ai_planner now hosts AI Monthly Planner + Savings Planners — make it visible.
  bool _migrateToV5() {
    final updatedWidgets = _config.widgets.map((w) {
      if (w.id == 'ai_planner' && !w.isVisible) {
        final lastRow = _config.getVisibleWidgets().fold<int>(
            0, (max, v) => v.gridRow + v.rowSpan - 1 > max ? v.gridRow + v.rowSpan - 1 : max);
        return w.copyWith(isVisible: true, gridRow: lastRow + 1);
      }
      return w;
    }).toList();
    _config = _config.copyWith(widgets: updatedWidgets, configVersion: 5);
    return true;
  }

  /// v3: health_score content merged into net_worth widget — hide it.
  bool _migrateToV3() {
    final updatedWidgets = _config.widgets.map((w) {
      if (w.id == 'health_score' && w.isVisible) {
        return w.copyWith(isVisible: false);
      }
      return w;
    }).toList();
    _config = _config.copyWith(widgets: updatedWidgets, configVersion: 3);
    return true;
  }

  DashboardConfig _getDefaultConfig() {
    return DashboardConfig(
      widgets: [
        DashboardWidgetConfig(
          id: 'net_worth',
          type: DashboardWidgetType.netWorth,
          title: 'Net Worth',
          isVisible: true,
          gridRow: 1,
          gridColumn: 1,
          columnSpan: 3,
          rowSpan: 2,
        ),
        DashboardWidgetConfig(
          id: 'transaction_history',
          type: DashboardWidgetType.transactionHistory,
          title: 'Transaction History',
          isVisible: true,
          gridRow: 3,
          gridColumn: 1,
          columnSpan: 3,
          rowSpan: 2,
        ),
        DashboardWidgetConfig(
          id: 'budgets_overview',
          type: DashboardWidgetType.budgetsOverview,
          title: 'Budgets',
          isVisible: false,
          gridRow: 10,
          gridColumn: 1,
          columnSpan: 3,
          rowSpan: 1,
        ),
        DashboardWidgetConfig(
          id: 'ai_planner',
          type: DashboardWidgetType.aiPlanner,
          title: 'AI Planner · Savings',
          isVisible: true,
          gridRow: 6,
          gridColumn: 1,
          columnSpan: 3,
          rowSpan: 1,
        ),
        DashboardWidgetConfig(
          id: 'sip_tracker',
          type: DashboardWidgetType.sipTracker,
          title: 'SIP Tracker',
          isVisible: false,
          gridRow: 14,
          gridColumn: 1,
          columnSpan: 3,
          rowSpan: 1,
        ),
        DashboardWidgetConfig(
          id: 'spending_insights',
          type: DashboardWidgetType.spendingInsights,
          title: 'Spending Insights',
          isVisible: true,
          gridRow: 8,
          gridColumn: 1,
          columnSpan: 3,
          rowSpan: 1,
        ),
      ],
    );
  }

  bool _ensureOptionalWidgetsExist() {
    bool changed = false;
    final existingIds = _config.widgets.map((w) => w.id).toSet();
    final updatedWidgets = [..._config.widgets];
    final defaults = _getDefaultConfig().widgets.where((w) =>
        w.id == 'budgets_overview' ||
        w.id == 'ai_planner' ||
        w.id == 'sip_tracker' ||
        w.id == 'spending_insights');

    for (final optional in defaults) {
      if (!existingIds.contains(optional.id)) {
        updatedWidgets.add(optional.copyWith(isVisible: false));
        changed = true;
      }
    }

    if (changed) {
      _config = _config.copyWith(widgets: updatedWidgets);
    }
    return changed;
  }

  Future<void> saveConfig() async {
    _config = _config.copyWith(lastModified: DateTime.now());
    _cachedVisibleWidgets = null; // invalidate cache
    final configJson = jsonEncode(_config.toMap());
    await _prefs.setString('dashboard_config', configJson);
    notifyListeners();
  }

  void updateWidget(DashboardWidgetConfig widget) {
    final index = _config.widgets.indexWhere((w) => w.id == widget.id);
    if (index != -1) {
      final updatedWidgets = [..._config.widgets];
      updatedWidgets[index] = widget;
      _config = _config.copyWith(widgets: updatedWidgets);
      _cachedVisibleWidgets = null; // invalidate cache
      notifyListeners();
    }
  }

  // Move widget to new position
  void moveWidget(String widgetId, int newRow, int newColumn) {
    final widget = _config.widgets.firstWhere(
      (w) => w.id == widgetId,
      orElse: () => throw Exception('Widget not found: $widgetId'),
    );

    // Clamp to valid grid boundaries
    int clampedColumn = newColumn;
    int clampedRow = newRow;

    // Ensure widget doesn't go off right edge
    if (widget.columnSpan + clampedColumn - 1 > gridColumns) {
      clampedColumn = gridColumns - widget.columnSpan + 1;
    }

    // Ensure minimum position
    if (clampedColumn < 1) clampedColumn = 1;
    if (clampedRow < 1) clampedRow = 1;

    final newWidget = widget.copyWith(
      gridRow: clampedRow,
      gridColumn: clampedColumn,
    );

    updateWidget(newWidget);
  }

  // Resize widget (change column and row span)
  void resizeWidget(String widgetId, int newColumnSpan, int newRowSpan) {
    final widget = _config.widgets.firstWhere(
      (w) => w.id == widgetId,
      orElse: () => throw Exception('Widget not found: $widgetId'),
    );

    // Clamp spans
    final int clampedColSpan = newColumnSpan.clamp(1, gridColumns);
    final int clampedRowSpan = newRowSpan.clamp(1, 10);

    // Adjust position if widget would go off-grid
    int newCol = widget.gridColumn;
    if (widget.gridColumn + clampedColSpan - 1 > gridColumns) {
      newCol = gridColumns - clampedColSpan + 1;
    }

    final newWidget = widget.copyWith(
      gridColumn: newCol,
      columnSpan: clampedColSpan,
      rowSpan: clampedRowSpan,
    );

    updateWidget(newWidget);
  }

  void toggleWidgetVisibility(String widgetId) {
    final widget = _config.widgets.firstWhere(
      (w) => w.id == widgetId,
      orElse: () => throw Exception('Widget not found: $widgetId'),
    );
    updateWidget(widget.copyWith(isVisible: !widget.isVisible));
  }

  Future<void> resetToDefault() async {
    _config = _getDefaultConfig();
    await saveConfig();
  }

  // Get grid cell info
  bool isCellOccupied(int row, int column, {String? excludeWidgetId}) {
    for (var widget in _config.widgets) {
      if (!widget.isVisible || widget.id == excludeWidgetId) continue;

      if (row >= widget.gridRow &&
          row <= widget.endRow &&
          column >= widget.gridColumn &&
          column <= widget.endColumn) {
        return true;
      }
    }
    return false;
  }

  // Get all occupied cells for a position
  List<(int, int)> getOccupiedCells(
    int row,
    int column,
    int columnSpan,
    int rowSpan, {
    String? excludeWidgetId,
  }) {
    final List<(int, int)> occupied = [];
    for (var widget in _config.widgets) {
      if (!widget.isVisible || widget.id == excludeWidgetId) continue;

      for (int r = widget.gridRow; r <= widget.endRow; r++) {
        for (int c = widget.gridColumn; c <= widget.endColumn; c++) {
          occupied.add((r, c));
        }
      }
    }
    return occupied;
  }

  // Find next available position (for adding new widgets)
  (int, int) findNextAvailablePosition(int columnSpan, int rowSpan) {
    for (int row = 1; row <= 20; row++) {
      for (int col = 1; col <= gridColumns; col++) {
        if (col + columnSpan - 1 <= gridColumns) {
          bool canPlace = true;
          for (int r = row; r < row + rowSpan; r++) {
            for (int c = col; c < col + columnSpan; c++) {
              if (isCellOccupied(r, c, excludeWidgetId: '')) {
                canPlace = false;
                break;
              }
            }
            if (!canPlace) break;
          }
          if (canPlace) return (row, col);
        }
      }
    }
    return (1, 1);
  }
}
