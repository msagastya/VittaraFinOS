import 'package:flutter/material.dart';

/// Financial goal types
enum GoalType {
  emergency,
  retirement,
  education,
  home,
  car,
  vacation,
  wedding,
  business,
  custom,
}

/// Financial goal model
class Goal {
  final String id;
  final String name;
  final GoalType type;
  final double targetAmount;
  final double currentAmount;
  final DateTime createdDate;
  final DateTime targetDate;
  final Color color;
  final String? notes;
  final String? linkedAccountId;
  final List<GoalContribution> contributions;
  final bool isCompleted;
  final DateTime? completedDate;

  Goal({
    required this.id,
    required this.name,
    required this.type,
    required this.targetAmount,
    required this.currentAmount,
    required this.createdDate,
    required this.targetDate,
    required this.color,
    this.notes,
    this.linkedAccountId,
    this.contributions = const [],
    this.isCompleted = false,
    this.completedDate,
  });

  /// Calculate progress percentage
  double get progressPercentage {
    if (targetAmount == 0) return 0;
    return (currentAmount / targetAmount * 100).clamp(0, 100);
  }

  /// Calculate remaining amount
  double get remainingAmount {
    return (targetAmount - currentAmount).clamp(0, targetAmount);
  }

  /// Calculate days remaining
  int get daysRemaining {
    return targetDate.difference(DateTime.now()).inDays;
  }

  /// Calculate months remaining
  int get monthsRemaining {
    final now = DateTime.now();
    return (targetDate.year - now.year) * 12 + (targetDate.month - now.month);
  }

  /// Calculate recommended monthly savings
  double get recommendedMonthlySavings {
    if (monthsRemaining <= 0) return remainingAmount;
    return remainingAmount / monthsRemaining;
  }

  /// Check if goal is on track
  bool get isOnTrack {
    if (daysRemaining <= 0) return currentAmount >= targetAmount;
    final totalDays = targetDate.difference(createdDate).inDays;
    final daysPassed = DateTime.now().difference(createdDate).inDays;
    if (totalDays == 0) return false;
    final expectedProgress = (daysPassed / totalDays) * 100;
    return progressPercentage >= expectedProgress - 5; // 5% tolerance
  }

  /// Get goal type label
  String getTypeLabel() {
    switch (type) {
      case GoalType.emergency:
        return 'Emergency Fund';
      case GoalType.retirement:
        return 'Retirement';
      case GoalType.education:
        return 'Education';
      case GoalType.home:
        return 'Home Purchase';
      case GoalType.car:
        return 'Car Purchase';
      case GoalType.vacation:
        return 'Vacation';
      case GoalType.wedding:
        return 'Wedding';
      case GoalType.business:
        return 'Business';
      case GoalType.custom:
        return 'Custom Goal';
    }
  }

  /// Get goal type icon
  IconData getTypeIcon() {
    switch (type) {
      case GoalType.emergency:
        return Icons.health_and_safety;
      case GoalType.retirement:
        return Icons.elderly;
      case GoalType.education:
        return Icons.school;
      case GoalType.home:
        return Icons.home;
      case GoalType.car:
        return Icons.directions_car;
      case GoalType.vacation:
        return Icons.flight;
      case GoalType.wedding:
        return Icons.favorite;
      case GoalType.business:
        return Icons.business;
      case GoalType.custom:
        return Icons.flag;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type.index,
      'targetAmount': targetAmount,
      'currentAmount': currentAmount,
      'createdDate': createdDate.toIso8601String(),
      'targetDate': targetDate.toIso8601String(),
      'color': color.toARGB32(),
      'notes': notes,
      'linkedAccountId': linkedAccountId,
      'contributions': contributions.map((c) => c.toMap()).toList(),
      'isCompleted': isCompleted,
      'completedDate': completedDate?.toIso8601String(),
    };
  }

  factory Goal.fromMap(Map<String, dynamic> map) {
    return Goal(
      id: map['id'],
      name: map['name'],
      type: GoalType.values[((map['type'] as num?)?.toInt() ?? 0).clamp(0, GoalType.values.length - 1)],
      targetAmount: (map['targetAmount'] as num).toDouble(),
      currentAmount: (map['currentAmount'] as num).toDouble(),
      createdDate: DateTime.tryParse(map['createdDate']?.toString() ?? '') ?? DateTime.now(),
      targetDate: DateTime.tryParse(map['targetDate']?.toString() ?? '') ?? DateTime.now().add(const Duration(days: 365)),
      color: Color(map['color']),
      notes: map['notes'],
      linkedAccountId: map['linkedAccountId'],
      contributions: (map['contributions'] as List?)
              ?.map((c) => GoalContribution.fromMap(c))
              .toList() ??
          [],
      isCompleted: map['isCompleted'] ?? false,
      completedDate: map['completedDate'] != null
          ? DateTime.tryParse(map['completedDate'].toString())
          : null,
    );
  }

  Goal copyWith({
    String? id,
    String? name,
    GoalType? type,
    double? targetAmount,
    double? currentAmount,
    DateTime? createdDate,
    DateTime? targetDate,
    Color? color,
    String? notes,
    String? linkedAccountId,
    List<GoalContribution>? contributions,
    bool? isCompleted,
    DateTime? completedDate,
  }) {
    return Goal(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      targetAmount: targetAmount ?? this.targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      createdDate: createdDate ?? this.createdDate,
      targetDate: targetDate ?? this.targetDate,
      color: color ?? this.color,
      notes: notes ?? this.notes,
      linkedAccountId: linkedAccountId ?? this.linkedAccountId,
      contributions: contributions ?? this.contributions,
      isCompleted: isCompleted ?? this.isCompleted,
      completedDate: completedDate ?? this.completedDate,
    );
  }
}

/// Goal contribution record
class GoalContribution {
  final String id;
  final double amount;
  final DateTime date;
  final String? notes;
  final String? sourceAccountId;

  GoalContribution({
    required this.id,
    required this.amount,
    required this.date,
    this.notes,
    this.sourceAccountId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'date': date.toIso8601String(),
      'notes': notes,
      'sourceAccountId': sourceAccountId,
    };
  }

  factory GoalContribution.fromMap(Map<String, dynamic> map) {
    return GoalContribution(
      id: map['id'],
      amount: (map['amount'] as num).toDouble(),
      date: DateTime.parse(map['date']),
      notes: map['notes'],
      sourceAccountId: map['sourceAccountId'],
    );
  }
}
