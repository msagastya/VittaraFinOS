/// Represents a single renewal cycle of an FD
class FDRenewalCycle {
  final int cycleNumber; // 1 for first cycle, 2 for first renewal, etc.
  final DateTime investmentDate; // Start date of this cycle
  final DateTime maturityDate; // Expected maturity date
  final double principal; // Principal for this cycle
  final double
      interestRate; // Annual rate for this cycle (can differ from previous)
  final int tenureMonths; // Duration in months
  final double maturityValue; // Expected value at maturity
  final DateTime? withdrawalDate; // If withdrawn before maturity
  final double? withdrawalAmount; // Amount withdrawn
  final String? withdrawalReason; // Reason for withdrawal
  final bool isWithdrawn; // true if prematurely withdrawn
  final bool isCompleted; // true if maturity reached

  FDRenewalCycle({
    required this.cycleNumber,
    required this.investmentDate,
    required this.maturityDate,
    required this.principal,
    required this.interestRate,
    required this.tenureMonths,
    required this.maturityValue,
    this.withdrawalDate,
    this.withdrawalAmount,
    this.withdrawalReason,
    required this.isWithdrawn,
    required this.isCompleted,
  });

  /// Calculate accrued value as of a given date
  double getAccruedValue(DateTime asOfDate) {
    if (isWithdrawn) return withdrawalAmount ?? principal;
    if (asOfDate.isBefore(investmentDate)) return principal;
    if (asOfDate.isAfter(maturityDate)) return maturityValue;

    // Pro-rata calculation
    final daysSinceInvestment = asOfDate.difference(investmentDate).inDays;
    final totalDays = maturityDate.difference(investmentDate).inDays;
    final fraction = daysSinceInvestment / totalDays;

    return principal + ((maturityValue - principal) * fraction);
  }

  /// Interest earned in this cycle as of a given date
  double getInterestEarned(DateTime asOfDate) {
    return getAccruedValue(asOfDate) - principal;
  }

  Map<String, dynamic> toMap() {
    return {
      'cycleNumber': cycleNumber,
      'investmentDate': investmentDate.toIso8601String(),
      'maturityDate': maturityDate.toIso8601String(),
      'principal': principal,
      'interestRate': interestRate,
      'tenureMonths': tenureMonths,
      'maturityValue': maturityValue,
      'withdrawalDate': withdrawalDate?.toIso8601String(),
      'withdrawalAmount': withdrawalAmount,
      'withdrawalReason': withdrawalReason,
      'isWithdrawn': isWithdrawn,
      'isCompleted': isCompleted,
    };
  }

  factory FDRenewalCycle.fromMap(Map<String, dynamic> map) {
    return FDRenewalCycle(
      cycleNumber: map['cycleNumber'] as int,
      investmentDate: DateTime.parse(map['investmentDate'] as String),
      maturityDate: DateTime.parse(map['maturityDate'] as String),
      principal: (map['principal'] as num).toDouble(),
      interestRate: (map['interestRate'] as num).toDouble(),
      tenureMonths: map['tenureMonths'] as int,
      maturityValue: (map['maturityValue'] as num).toDouble(),
      withdrawalDate: map['withdrawalDate'] != null
          ? DateTime.parse(map['withdrawalDate'] as String)
          : null,
      withdrawalAmount: map['withdrawalAmount'] != null
          ? (map['withdrawalAmount'] as num).toDouble()
          : null,
      withdrawalReason: map['withdrawalReason'] as String?,
      isWithdrawn: map['isWithdrawn'] as bool? ?? false,
      isCompleted: map['isCompleted'] as bool? ?? false,
    );
  }

  FDRenewalCycle copyWith({
    int? cycleNumber,
    DateTime? investmentDate,
    DateTime? maturityDate,
    double? principal,
    double? interestRate,
    int? tenureMonths,
    double? maturityValue,
    DateTime? withdrawalDate,
    double? withdrawalAmount,
    String? withdrawalReason,
    bool? isWithdrawn,
    bool? isCompleted,
  }) {
    return FDRenewalCycle(
      cycleNumber: cycleNumber ?? this.cycleNumber,
      investmentDate: investmentDate ?? this.investmentDate,
      maturityDate: maturityDate ?? this.maturityDate,
      principal: principal ?? this.principal,
      interestRate: interestRate ?? this.interestRate,
      tenureMonths: tenureMonths ?? this.tenureMonths,
      maturityValue: maturityValue ?? this.maturityValue,
      withdrawalDate: withdrawalDate ?? this.withdrawalDate,
      withdrawalAmount: withdrawalAmount ?? this.withdrawalAmount,
      withdrawalReason: withdrawalReason ?? this.withdrawalReason,
      isWithdrawn: isWithdrawn ?? this.isWithdrawn,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}
