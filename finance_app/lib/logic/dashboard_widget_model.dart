enum DashboardWidgetType {
  transactionHistory,
  netWorth,
  goalsOverview,
  budgetsOverview,
  savingsPlanners,
  aiPlanner,
  notificationsAndActions,
  monthlySummary,
  sipTracker,
  healthScore,
  spendingInsights,
}

class DashboardWidgetConfig {
  final String id;
  final DashboardWidgetType type;
  final String title;
  final bool isVisible;

  // Grid positioning (3-column grid)
  final int gridRow; // Starting row (1-indexed)
  final int gridColumn; // Starting column (1-3)
  final int columnSpan; // Width: 1-3 columns
  final int rowSpan; // Height: 1+ rows

  DashboardWidgetConfig({
    required this.id,
    required this.type,
    required this.title,
    this.isVisible = true,
    this.gridRow = 1,
    this.gridColumn = 1,
    this.columnSpan = 1,
    this.rowSpan = 1,
  });

  DashboardWidgetConfig copyWith({
    String? id,
    DashboardWidgetType? type,
    String? title,
    bool? isVisible,
    int? gridRow,
    int? gridColumn,
    int? columnSpan,
    int? rowSpan,
  }) {
    return DashboardWidgetConfig(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      isVisible: isVisible ?? this.isVisible,
      gridRow: gridRow ?? this.gridRow,
      gridColumn: gridColumn ?? this.gridColumn,
      columnSpan: columnSpan ?? this.columnSpan,
      rowSpan: rowSpan ?? this.rowSpan,
    );
  }

  // Get widget ending position
  int get endColumn => gridColumn + columnSpan - 1;
  int get endRow => gridRow + rowSpan - 1;

  // Check if this widget overlaps with another
  bool overlaps(DashboardWidgetConfig other) {
    return !(endColumn < other.gridColumn ||
        gridColumn > other.endColumn ||
        endRow < other.gridRow ||
        gridRow > other.endRow);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.toString(),
      'title': title,
      'isVisible': isVisible,
      'gridRow': gridRow,
      'gridColumn': gridColumn,
      'columnSpan': columnSpan,
      'rowSpan': rowSpan,
    };
  }

  factory DashboardWidgetConfig.fromMap(Map<String, dynamic> map) {
    return DashboardWidgetConfig(
      id: map['id'] ?? '',
      type: _parseWidgetType(map['type']),
      title: map['title'] ?? '',
      isVisible: map['isVisible'] ?? true,
      gridRow: map['gridRow'] ?? 1,
      gridColumn: map['gridColumn'] ?? 1,
      columnSpan: map['columnSpan'] ?? 1,
      rowSpan: map['rowSpan'] ?? 1,
    );
  }

  static DashboardWidgetType _parseWidgetType(String? type) {
    if (type == null) return DashboardWidgetType.transactionHistory;
    return DashboardWidgetType.values.firstWhere(
      (e) => e.toString() == type,
      orElse: () => DashboardWidgetType.transactionHistory,
    );
  }
}

class DashboardConfig {
  final List<DashboardWidgetConfig> widgets;
  final DateTime lastModified;
  final int configVersion;

  DashboardConfig({
    required this.widgets,
    DateTime? lastModified,
    this.configVersion = 5,
  }) : lastModified = lastModified ?? DateTime.now();

  DashboardConfig copyWith({
    List<DashboardWidgetConfig>? widgets,
    DateTime? lastModified,
    int? configVersion,
  }) {
    return DashboardConfig(
      widgets: widgets ?? this.widgets,
      lastModified: lastModified ?? this.lastModified,
      configVersion: configVersion ?? this.configVersion,
    );
  }

  // Get widgets in order (top-left to bottom-right)
  List<DashboardWidgetConfig> getVisibleWidgets() {
    final visible = widgets.where((w) => w.isVisible).toList();
    visible.sort((a, b) {
      if (a.gridRow != b.gridRow) return a.gridRow.compareTo(b.gridRow);
      return a.gridColumn.compareTo(b.gridColumn);
    });
    return visible;
  }

  // Get total rows needed for layout
  int getTotalRows() {
    if (widgets.isEmpty) return 1;
    return widgets.fold<int>(0, (max, widget) {
      if (!widget.isVisible) return max;
      final endRow = widget.gridRow + widget.rowSpan - 1;
      return endRow > max ? endRow : max;
    });
  }

  Map<String, dynamic> toMap() {
    return {
      'widgets': widgets.map((w) => w.toMap()).toList(),
      'lastModified': lastModified.toIso8601String(),
      'configVersion': configVersion,
    };
  }

  factory DashboardConfig.fromMap(Map<String, dynamic> map) {
    return DashboardConfig(
      widgets: (map['widgets'] as List?)
              ?.map((w) =>
                  DashboardWidgetConfig.fromMap(w as Map<String, dynamic>))
              .toList() ??
          [],
      lastModified: map['lastModified'] != null
          ? DateTime.parse(map['lastModified'])
          : DateTime.now(),
      configVersion: (map['configVersion'] as int?) ?? 1,
    );
  }
}
