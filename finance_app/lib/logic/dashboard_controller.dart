import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vittara_fin_os/logic/dashboard_widget_model.dart';
import 'dart:convert';

class DashboardController extends ChangeNotifier {
  late DashboardConfig _config;
  late SharedPreferences _prefs;
  bool _isInitialized = false;

  static const int gridColumns = 3;

  DashboardConfig get config => _config;
  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadConfig();
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> _loadConfig() async {
    final configJson = _prefs.getString('dashboard_config');
    if (configJson != null) {
      try {
        final map = jsonDecode(configJson) as Map<String, dynamic>;
        _config = DashboardConfig.fromMap(map);
        final changed = _ensureOptionalWidgetsExist();
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
          id: 'notifications_and_actions',
          type: DashboardWidgetType.notificationsAndActions,
          title: 'Notifications and Actions',
          isVisible: true,
          gridRow: 5,
          gridColumn: 1,
          columnSpan: 3,
          rowSpan: 1,
        ),
        DashboardWidgetConfig(
          id: 'goals_overview',
          type: DashboardWidgetType.goalsOverview,
          title: 'Goals',
          isVisible: false,
          gridRow: 6,
          gridColumn: 1,
          columnSpan: 3,
          rowSpan: 1,
        ),
        DashboardWidgetConfig(
          id: 'budgets_overview',
          type: DashboardWidgetType.budgetsOverview,
          title: 'Budgets',
          isVisible: false,
          gridRow: 7,
          gridColumn: 1,
          columnSpan: 3,
          rowSpan: 1,
        ),
        DashboardWidgetConfig(
          id: 'savings_planners',
          type: DashboardWidgetType.savingsPlanners,
          title: 'Savings Planners',
          isVisible: false,
          gridRow: 8,
          gridColumn: 1,
          columnSpan: 3,
          rowSpan: 1,
        ),
        DashboardWidgetConfig(
          id: 'ai_planner',
          type: DashboardWidgetType.aiPlanner,
          title: 'AI Monthly Planner',
          isVisible: false,
          gridRow: 9,
          gridColumn: 1,
          columnSpan: 3,
          rowSpan: 1,
        ),
        DashboardWidgetConfig(
          id: 'monthly_summary',
          type: DashboardWidgetType.monthlySummary,
          title: 'Monthly Summary',
          isVisible: false,
          gridRow: 10,
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
        w.id == 'goals_overview' ||
        w.id == 'budgets_overview' ||
        w.id == 'savings_planners' ||
        w.id == 'ai_planner' ||
        w.id == 'monthly_summary');

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
    int clampedColSpan = newColumnSpan.clamp(1, gridColumns);
    int clampedRowSpan = newRowSpan.clamp(1, 10);

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
    List<(int, int)> occupied = [];
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
