import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Budget period types
enum BudgetPeriod {
  daily,
  weekly,
  monthly,
  yearly,
}

/// Budget status
enum BudgetStatus {
  onTrack,
  warning,
  exceeded,
}

/// Budget model
class Budget {
  final String id;
  final String name;
  final String? categoryId;
  final String? categoryName;
  final double limitAmount;
  final double spentAmount;
  final BudgetPeriod period;
  final DateTime startDate;
  final DateTime endDate;
  final Color color;
  final bool isActive;
  final List<String> excludedAccountIds;
  final bool rollover; // Roll over unused budget to next period
  final double? warningThreshold; // Percentage (e.g., 80 for 80%)

  Budget({
    required this.id,
    required this.name,
    this.categoryId,
    this.categoryName,
    required this.limitAmount,
    required this.spentAmount,
    required this.period,
    required this.startDate,
    required this.endDate,
    required this.color,
    this.isActive = true,
    this.excludedAccountIds = const [],
    this.rollover = false,
    this.warningThreshold = 80.0,
  });

  /// Calculate usage percentage
  double get usagePercentage {
    if (limitAmount == 0) return 0;
    return (spentAmount / limitAmount * 100).clamp(0, double.infinity);
  }

  /// Calculate remaining amount
  double get remainingAmount {
    return (limitAmount - spentAmount).clamp(0, limitAmount);
  }

  /// Get budget status
  BudgetStatus get status {
    if (usagePercentage >= 100) return BudgetStatus.exceeded;
    if (warningThreshold != null && usagePercentage >= warningThreshold!) {
      return BudgetStatus.warning;
    }
    return BudgetStatus.onTrack;
  }

  /// Calculate days remaining in period
  int get daysRemaining {
    return endDate
        .difference(DateTime.now())
        .inDays
        .clamp(0, double.infinity.toInt());
  }

  /// Calculate daily budget remaining
  double get dailyBudgetRemaining {
    if (daysRemaining == 0) return remainingAmount;
    return remainingAmount / daysRemaining;
  }

  /// Get period label
  String getPeriodLabel() {
    switch (period) {
      case BudgetPeriod.daily:
        return 'Daily';
      case BudgetPeriod.weekly:
        return 'Weekly';
      case BudgetPeriod.monthly:
        return 'Monthly';
      case BudgetPeriod.yearly:
        return 'Yearly';
    }
  }

  /// Get period icon
  IconData getPeriodIcon() {
    switch (period) {
      case BudgetPeriod.daily:
        return Icons.today;
      case BudgetPeriod.weekly:
        return Icons.date_range;
      case BudgetPeriod.monthly:
        return Icons.calendar_month;
      case BudgetPeriod.yearly:
        return Icons.calendar_today;
    }
  }

  /// Get status color
  Color getStatusColor() {
    switch (status) {
      case BudgetStatus.onTrack:
        return CupertinoColors.systemGreen;
      case BudgetStatus.warning:
        return CupertinoColors.systemOrange;
      case BudgetStatus.exceeded:
        return CupertinoColors.systemRed;
    }
  }

  /// Calculate next period start date
  DateTime getNextPeriodStart() {
    switch (period) {
      case BudgetPeriod.daily:
        return DateTime(endDate.year, endDate.month, endDate.day + 1);
      case BudgetPeriod.weekly:
        return endDate.add(const Duration(days: 1));
      case BudgetPeriod.monthly:
        return DateTime(
          endDate.month == 12 ? endDate.year + 1 : endDate.year,
          endDate.month == 12 ? 1 : endDate.month + 1,
          1,
        );
      case BudgetPeriod.yearly:
        return DateTime(endDate.year + 1, 1, 1);
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'categoryId': categoryId,
      'categoryName': categoryName,
      'limitAmount': limitAmount,
      'spentAmount': spentAmount,
      'period': period.index,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'color': color.toARGB32(),
      'isActive': isActive,
      'excludedAccountIds': excludedAccountIds,
      'rollover': rollover,
      'warningThreshold': warningThreshold,
    };
  }

  factory Budget.fromMap(Map<String, dynamic> map) {
    return Budget(
      id: map['id'],
      name: map['name'],
      categoryId: map['categoryId'],
      categoryName: map['categoryName'],
      limitAmount: (map['limitAmount'] as num).toDouble(),
      spentAmount: (map['spentAmount'] as num).toDouble(),
      period: BudgetPeriod.values[((map['period'] as num?)?.toInt() ?? 0).clamp(0, BudgetPeriod.values.length - 1)],
      startDate: DateTime.parse(map['startDate']),
      endDate: DateTime.parse(map['endDate']),
      color: Color(map['color']),
      isActive: map['isActive'] ?? true,
      excludedAccountIds: List<String>.from(map['excludedAccountIds'] ?? []),
      rollover: map['rollover'] ?? false,
      warningThreshold: map['warningThreshold'] != null
          ? (map['warningThreshold'] as num).toDouble()
          : 80.0,
    );
  }

  Budget copyWith({
    String? id,
    String? name,
    String? categoryId,
    String? categoryName,
    double? limitAmount,
    double? spentAmount,
    BudgetPeriod? period,
    DateTime? startDate,
    DateTime? endDate,
    Color? color,
    bool? isActive,
    List<String>? excludedAccountIds,
    bool? rollover,
    double? warningThreshold,
  }) {
    return Budget(
      id: id ?? this.id,
      name: name ?? this.name,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      limitAmount: limitAmount ?? this.limitAmount,
      spentAmount: spentAmount ?? this.spentAmount,
      period: period ?? this.period,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      color: color ?? this.color,
      isActive: isActive ?? this.isActive,
      excludedAccountIds: excludedAccountIds ?? this.excludedAccountIds,
      rollover: rollover ?? this.rollover,
      warningThreshold: warningThreshold ?? this.warningThreshold,
    );
  }
}

/// Savings planner model
class SavingsPlanner {
  final String id;
  final String name;
  final double monthlyTarget;
  final double currentMonthSaved;
  final List<MonthlySavings> history;
  final DateTime createdDate;
  final bool autoSave;
  final String? linkedAccountId;

  SavingsPlanner({
    required this.id,
    required this.name,
    required this.monthlyTarget,
    required this.currentMonthSaved,
    this.history = const [],
    required this.createdDate,
    this.autoSave = false,
    this.linkedAccountId,
  });

  double get currentMonthPercentage {
    if (monthlyTarget == 0) return 0;
    return (currentMonthSaved / monthlyTarget * 100).clamp(0, 100);
  }

  double get totalSaved {
    return history.fold(0.0, (sum, month) => sum + month.amount) +
        currentMonthSaved;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'monthlyTarget': monthlyTarget,
      'currentMonthSaved': currentMonthSaved,
      'history': history.map((h) => h.toMap()).toList(),
      'createdDate': createdDate.toIso8601String(),
      'autoSave': autoSave,
      'linkedAccountId': linkedAccountId,
    };
  }

  factory SavingsPlanner.fromMap(Map<String, dynamic> map) {
    return SavingsPlanner(
      id: map['id'],
      name: map['name'],
      monthlyTarget: (map['monthlyTarget'] as num).toDouble(),
      currentMonthSaved: (map['currentMonthSaved'] as num).toDouble(),
      history: (map['history'] as List?)
              ?.map((h) => MonthlySavings.fromMap(h))
              .toList() ??
          [],
      createdDate: DateTime.parse(map['createdDate']),
      autoSave: map['autoSave'] ?? false,
      linkedAccountId: map['linkedAccountId'],
    );
  }

  SavingsPlanner copyWith({
    String? id,
    String? name,
    double? monthlyTarget,
    double? currentMonthSaved,
    List<MonthlySavings>? history,
    DateTime? createdDate,
    bool? autoSave,
    String? linkedAccountId,
  }) {
    return SavingsPlanner(
      id: id ?? this.id,
      name: name ?? this.name,
      monthlyTarget: monthlyTarget ?? this.monthlyTarget,
      currentMonthSaved: currentMonthSaved ?? this.currentMonthSaved,
      history: history ?? this.history,
      createdDate: createdDate ?? this.createdDate,
      autoSave: autoSave ?? this.autoSave,
      linkedAccountId: linkedAccountId ?? this.linkedAccountId,
    );
  }
}

/// Monthly savings record
class MonthlySavings {
  final DateTime month;
  final double amount;
  final double target;

  MonthlySavings({
    required this.month,
    required this.amount,
    required this.target,
  });

  double get percentage {
    if (target == 0) return 0;
    return (amount / target * 100).clamp(0, 100);
  }

  Map<String, dynamic> toMap() {
    return {
      'month': month.toIso8601String(),
      'amount': amount,
      'target': target,
    };
  }

  factory MonthlySavings.fromMap(Map<String, dynamic> map) {
    return MonthlySavings(
      month: DateTime.parse(map['month']),
      amount: (map['amount'] as num).toDouble(),
      target: (map['target'] as num).toDouble(),
    );
  }
}
