import 'dart:math' as math;

enum RDPaymentFrequency { monthly, quarterly, semiAnnual, annual }

enum RDStatus { active, mature, completed }

/// Represents an RD installment
class RDInstallment {
  final String id;
  final int installmentNumber;
  final DateTime dueDate;
  final double amount;
  final double interestEarned; // Interest earned on this installment
  final bool isPaid; // Whether this installment has been paid
  final DateTime? paidDate;
  final String? linkedTransactionId; // Link to account debit transaction

  RDInstallment({
    required this.id,
    required this.installmentNumber,
    required this.dueDate,
    required this.amount,
    required this.interestEarned,
    required this.isPaid,
    this.paidDate,
    this.linkedTransactionId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'installmentNumber': installmentNumber,
      'dueDate': dueDate.toIso8601String(),
      'amount': amount,
      'interestEarned': interestEarned,
      'isPaid': isPaid,
      'paidDate': paidDate?.toIso8601String(),
      'linkedTransactionId': linkedTransactionId,
    };
  }

  factory RDInstallment.fromMap(Map<String, dynamic> map) {
    return RDInstallment(
      id: map['id'],
      installmentNumber: map['installmentNumber'] as int,
      dueDate: DateTime.parse(map['dueDate']),
      amount: (map['amount'] as num).toDouble(),
      interestEarned: (map['interestEarned'] as num).toDouble(),
      isPaid: map['isPaid'] as bool,
      paidDate:
          map['paidDate'] != null ? DateTime.parse(map['paidDate']) : null,
      linkedTransactionId: map['linkedTransactionId'] as String?,
    );
  }

  RDInstallment copyWith({
    String? id,
    int? installmentNumber,
    DateTime? dueDate,
    double? amount,
    double? interestEarned,
    bool? isPaid,
    DateTime? paidDate,
    String? linkedTransactionId,
  }) {
    return RDInstallment(
      id: id ?? this.id,
      installmentNumber: installmentNumber ?? this.installmentNumber,
      dueDate: dueDate ?? this.dueDate,
      amount: amount ?? this.amount,
      interestEarned: interestEarned ?? this.interestEarned,
      isPaid: isPaid ?? this.isPaid,
      paidDate: paidDate ?? this.paidDate,
      linkedTransactionId: linkedTransactionId ?? this.linkedTransactionId,
    );
  }
}

/// Core Recurring Deposit model
class RecurringDeposit {
  final String id;
  final String name;
  final double monthlyAmount; // Amount per installment
  final double interestRate; // Annual interest rate in percentage
  final int totalInstallments; // Total number of installments
  final RDPaymentFrequency paymentFrequency;

  // Account linking (immutable)
  final String linkedAccountId; // Immutable reference
  final String linkedAccountName; // Display name

  // Auto-payment settings
  final bool autoPaymentEnabled; // Whether to auto-debit from account

  // Timestamps
  final DateTime createdDate;
  final DateTime startDate; // When RD started
  final DateTime maturityDate; // Calculated

  // Status
  final RDStatus status;
  final DateTime? completionDate;

  // Installments tracking
  final List<RDInstallment> installments;

  // Calculation cache
  final double totalInvestedAmount; // Total of all installments
  final double totalInterestAtMaturity;
  final double maturityValue; // Total amount at maturity
  final double
      estimatedAccruedValue; // Current value based on paid installments
  final double realizedValue; // Sum of paid installments + accrued interest

  // Notes
  final String? notes;
  final String? bankName;
  final String? bankAccountNumber;
  final Map<String, dynamic>? metadata;

  RecurringDeposit({
    required this.id,
    required this.name,
    required this.monthlyAmount,
    required this.interestRate,
    required this.totalInstallments,
    required this.paymentFrequency,
    required this.linkedAccountId,
    required this.linkedAccountName,
    required this.autoPaymentEnabled,
    required this.createdDate,
    required this.startDate,
    required this.maturityDate,
    required this.status,
    this.completionDate,
    required this.installments,
    required this.totalInvestedAmount,
    required this.totalInterestAtMaturity,
    required this.maturityValue,
    required this.estimatedAccruedValue,
    required this.realizedValue,
    this.notes,
    this.bankName,
    this.bankAccountNumber,
    this.metadata,
  });

  /// Get completed installments count
  int get completedInstallments => installments.where((i) => i.isPaid).length;

  /// Get pending installments count
  int get pendingInstallments => installments.where((i) => !i.isPaid).length;

  /// Get days until maturity
  int get daysUntilMaturity {
    if (status == RDStatus.mature || status == RDStatus.completed) {
      return 0;
    }
    return maturityDate.difference(DateTime.now()).inDays;
  }

  /// Get next pending installment
  RDInstallment? get nextInstallment {
    return installments.where((i) => !i.isPaid).firstOrNull;
  }

  /// Get days until next installment
  int get daysUntilNextInstallment {
    final next = nextInstallment;
    if (next == null) return 0;
    final days = next.dueDate.difference(DateTime.now()).inDays;
    return days > 0 ? days : 0;
  }

  /// Total amount invested so far (paid installments)
  double get amountInvestedSoFar {
    return installments
        .where((i) => i.isPaid)
        .fold(0.0, (sum, i) => sum + i.amount);
  }

  /// Interest earned till date
  double get interestEarnedTillDate {
    return installments
        .where((i) => i.isPaid)
        .fold(0.0, (sum, i) => sum + i.interestEarned);
  }

  /// Current value (invested + earned interest)
  double get currentValue => amountInvestedSoFar + interestEarnedTillDate;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'monthlyAmount': monthlyAmount,
      'interestRate': interestRate,
      'totalInstallments': totalInstallments,
      'paymentFrequency': paymentFrequency.index,
      'linkedAccountId': linkedAccountId,
      'linkedAccountName': linkedAccountName,
      'autoPaymentEnabled': autoPaymentEnabled,
      'createdDate': createdDate.toIso8601String(),
      'startDate': startDate.toIso8601String(),
      'maturityDate': maturityDate.toIso8601String(),
      'status': status.index,
      'completionDate': completionDate?.toIso8601String(),
      'installments': installments.map((i) => i.toMap()).toList(),
      'totalInvestedAmount': totalInvestedAmount,
      'totalInterestAtMaturity': totalInterestAtMaturity,
      'maturityValue': maturityValue,
      'estimatedAccruedValue': estimatedAccruedValue,
      'realizedValue': realizedValue,
      'notes': notes,
      'bankName': bankName,
      'bankAccountNumber': bankAccountNumber,
      'metadata': metadata,
    };
  }

  factory RecurringDeposit.fromMap(Map<String, dynamic> map) {
    return RecurringDeposit(
      id: map['id'],
      name: map['name'],
      monthlyAmount: (map['monthlyAmount'] as num).toDouble(),
      interestRate: (map['interestRate'] as num).toDouble(),
      totalInstallments: map['totalInstallments'] as int,
      paymentFrequency:
          RDPaymentFrequency.values[map['paymentFrequency'] as int],
      linkedAccountId: map['linkedAccountId'],
      linkedAccountName: map['linkedAccountName'],
      autoPaymentEnabled: map['autoPaymentEnabled'] as bool,
      createdDate: DateTime.parse(map['createdDate']),
      startDate: DateTime.parse(map['startDate']),
      maturityDate: DateTime.parse(map['maturityDate']),
      status: RDStatus.values[map['status'] as int],
      completionDate: map['completionDate'] != null
          ? DateTime.parse(map['completionDate'])
          : null,
      installments: (map['installments'] as List?)
              ?.map((i) => RDInstallment.fromMap(i as Map<String, dynamic>))
              .toList() ??
          [],
      totalInvestedAmount: (map['totalInvestedAmount'] as num).toDouble(),
      totalInterestAtMaturity:
          (map['totalInterestAtMaturity'] as num).toDouble(),
      maturityValue: (map['maturityValue'] as num).toDouble(),
      estimatedAccruedValue: (map['estimatedAccruedValue'] as num).toDouble(),
      realizedValue: (map['realizedValue'] as num).toDouble(),
      notes: map['notes'] as String?,
      bankName: map['bankName'] as String?,
      bankAccountNumber: map['bankAccountNumber'] as String?,
      metadata: map['metadata'] as Map<String, dynamic>?,
    );
  }

  RecurringDeposit copyWith({
    String? id,
    String? name,
    double? monthlyAmount,
    double? interestRate,
    int? totalInstallments,
    RDPaymentFrequency? paymentFrequency,
    String? linkedAccountId,
    String? linkedAccountName,
    bool? autoPaymentEnabled,
    DateTime? createdDate,
    DateTime? startDate,
    DateTime? maturityDate,
    RDStatus? status,
    DateTime? completionDate,
    List<RDInstallment>? installments,
    double? totalInvestedAmount,
    double? totalInterestAtMaturity,
    double? maturityValue,
    double? estimatedAccruedValue,
    double? realizedValue,
    String? notes,
    String? bankName,
    String? bankAccountNumber,
    Map<String, dynamic>? metadata,
  }) {
    return RecurringDeposit(
      id: id ?? this.id,
      name: name ?? this.name,
      monthlyAmount: monthlyAmount ?? this.monthlyAmount,
      interestRate: interestRate ?? this.interestRate,
      totalInstallments: totalInstallments ?? this.totalInstallments,
      paymentFrequency: paymentFrequency ?? this.paymentFrequency,
      linkedAccountId: linkedAccountId ?? this.linkedAccountId,
      linkedAccountName: linkedAccountName ?? this.linkedAccountName,
      autoPaymentEnabled: autoPaymentEnabled ?? this.autoPaymentEnabled,
      createdDate: createdDate ?? this.createdDate,
      startDate: startDate ?? this.startDate,
      maturityDate: maturityDate ?? this.maturityDate,
      status: status ?? this.status,
      completionDate: completionDate ?? this.completionDate,
      installments: installments ?? this.installments,
      totalInvestedAmount: totalInvestedAmount ?? this.totalInvestedAmount,
      totalInterestAtMaturity:
          totalInterestAtMaturity ?? this.totalInterestAtMaturity,
      maturityValue: maturityValue ?? this.maturityValue,
      estimatedAccruedValue:
          estimatedAccruedValue ?? this.estimatedAccruedValue,
      realizedValue: realizedValue ?? this.realizedValue,
      notes: notes ?? this.notes,
      bankName: bankName ?? this.bankName,
      bankAccountNumber: bankAccountNumber ?? this.bankAccountNumber,
      metadata: metadata ?? this.metadata,
    );
  }

  String getPaymentFrequencyLabel() {
    switch (paymentFrequency) {
      case RDPaymentFrequency.monthly:
        return 'Monthly';
      case RDPaymentFrequency.quarterly:
        return 'Quarterly';
      case RDPaymentFrequency.semiAnnual:
        return 'Semi-Annually';
      case RDPaymentFrequency.annual:
        return 'Annually';
    }
  }

  String getStatusLabel() {
    switch (status) {
      case RDStatus.active:
        return 'Active';
      case RDStatus.mature:
        return 'Mature';
      case RDStatus.completed:
        return 'Completed';
    }
  }
}

/// Utility class for RD calculations
class RDCalculator {
  /// Calculate RD maturity value using compound interest
  /// Formula: M = P * (((1 + r/n)^(n*t) - 1) / (1 - (1 + r/n)^(-1/n)))
  /// Simplified: Calculate each installment's future value and sum
  static double calculateMaturityValue({
    required double monthlyAmount,
    required double annualRate,
    required int totalInstallments,
    required RDPaymentFrequency frequency,
  }) {
    double totalMaturityValue = 0;

    // Get months per installment
    final monthsPerInstallment = _getMonthsForFrequency(frequency);

    // Calculate future value of each installment
    for (int i = 1; i <= totalInstallments; i++) {
      // Number of periods remaining after this installment
      final periodsRemaining =
          (totalInstallments - i) * monthsPerInstallment / 12;

      // Compound interest for this installment
      final monthlyRate = annualRate / 100 / 12;
      final periodRate = monthlyRate * monthsPerInstallment;

      final futureValue =
          monthlyAmount * math.pow(1 + periodRate, periodsRemaining);

      totalMaturityValue += futureValue.toDouble();
    }

    return totalMaturityValue;
  }

  /// Generate RD installment schedule
  static List<RDInstallment> generateInstallmentSchedule({
    required String rdId,
    required double monthlyAmount,
    required DateTime startDate,
    required int totalInstallments,
    required RDPaymentFrequency frequency,
    required double annualRate,
  }) {
    final installments = <RDInstallment>[];
    final monthsPerInstallment = _getMonthsForFrequency(frequency);
    final monthlyRate = annualRate / 100 / 12;
    final periodRate = monthlyRate * monthsPerInstallment;

    for (int i = 1; i <= totalInstallments; i++) {
      final dueDate = _addMonths(startDate, (i - 1) * monthsPerInstallment);

      // Interest earned on this installment
      final periodsRemaining =
          (totalInstallments - i) * monthsPerInstallment / 12;
      final interestEarned =
          (monthlyAmount * math.pow(1 + periodRate, periodsRemaining)) -
              monthlyAmount;

      final installment = RDInstallment(
        id: '${rdId}_inst_$i',
        installmentNumber: i,
        dueDate: dueDate,
        amount: monthlyAmount,
        interestEarned: interestEarned.toDouble(),
        isPaid: dueDate.isBefore(DateTime.now()),
        paidDate: dueDate.isBefore(DateTime.now()) ? dueDate : null,
      );

      installments.add(installment);
    }

    return installments;
  }

  /// Add months to a date (calendar-accurate)
  static DateTime _addMonths(DateTime date, int months) {
    var newMonth = date.month + months;
    var newYear = date.year;

    while (newMonth > 12) {
      newMonth -= 12;
      newYear++;
    }

    final lastDayOfMonth = DateTime(newYear, newMonth + 1, 0).day;
    final newDay = date.day > lastDayOfMonth ? lastDayOfMonth : date.day;

    return DateTime(newYear, newMonth, newDay);
  }

  /// Get months for frequency
  static int _getMonthsForFrequency(RDPaymentFrequency frequency) {
    switch (frequency) {
      case RDPaymentFrequency.monthly:
        return 1;
      case RDPaymentFrequency.quarterly:
        return 3;
      case RDPaymentFrequency.semiAnnual:
        return 6;
      case RDPaymentFrequency.annual:
        return 12;
    }
  }
}
