import 'dart:math' as math;

enum FDCompoundingFrequency { annual, semiAnnual, quarterly, monthly }

enum FDPayoutFrequency { annual, semiAnnual, quarterly, monthly, atMaturity }

enum FDStatus { active, mature, prematurelyWithdrawn, completed }

/// Represents a completed or upcoming payout with its status
class PayoutRecord {
  final String id;
  final DateTime payoutDate;
  final double interestAmount;
  final double principalAmount; // Only for maturity/withdrawal
  final bool isProcessed; // true = already credited to account
  final DateTime? processedDate;
  final String payoutType; // 'interest', 'principal', 'both' (maturity/withdrawal)

  PayoutRecord({
    required this.id,
    required this.payoutDate,
    required this.interestAmount,
    required this.principalAmount,
    required this.isProcessed,
    this.processedDate,
    required this.payoutType,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'payoutDate': payoutDate.toIso8601String(),
      'interestAmount': interestAmount,
      'principalAmount': principalAmount,
      'isProcessed': isProcessed,
      'processedDate': processedDate?.toIso8601String(),
      'payoutType': payoutType,
    };
  }

  factory PayoutRecord.fromMap(Map<String, dynamic> map) {
    return PayoutRecord(
      id: map['id'],
      payoutDate: DateTime.parse(map['payoutDate']),
      interestAmount: (map['interestAmount'] as num).toDouble(),
      principalAmount: (map['principalAmount'] as num).toDouble(),
      isProcessed: map['isProcessed'] as bool,
      processedDate: map['processedDate'] != null
          ? DateTime.parse(map['processedDate'])
          : null,
      payoutType: map['payoutType'],
    );
  }

  PayoutRecord copyWith({
    String? id,
    DateTime? payoutDate,
    double? interestAmount,
    double? principalAmount,
    bool? isProcessed,
    DateTime? processedDate,
    String? payoutType,
  }) {
    return PayoutRecord(
      id: id ?? this.id,
      payoutDate: payoutDate ?? this.payoutDate,
      interestAmount: interestAmount ?? this.interestAmount,
      principalAmount: principalAmount ?? this.principalAmount,
      isProcessed: isProcessed ?? this.isProcessed,
      processedDate: processedDate ?? this.processedDate,
      payoutType: payoutType ?? this.payoutType,
    );
  }
}

/// Core Fixed Deposit model
class FixedDeposit {
  final String id;
  final String name;
  final double principal;
  final double interestRate; // Annual interest rate in percentage
  final int tenureMonths; // Total tenure in months
  final FDCompoundingFrequency compoundingFrequency;
  final FDPayoutFrequency payoutFrequency;
  final bool isCumulative;

  // Account linking (immutable)
  final String linkedAccountId; // Immutable reference
  final String linkedAccountName; // Display name

  // Auto-link settings
  final bool autoLinkEnabled; // Whether to auto-credit payouts

  // Timestamps
  final DateTime createdDate;
  final DateTime investmentDate; // When FD started
  final DateTime maturityDate; // Calculated

  // Status
  final FDStatus status;
  final DateTime? withdrawalDate; // If prematurely withdrawn
  final double? withdrawalAmount; // Net amount received on withdrawal
  final String? withdrawalReason;

  // Payout tracking
  final List<PayoutRecord> pastPayouts; // Already credited to account
  final List<PayoutRecord> upcomingPayouts; // Yet to be processed

  // Calculation cache
  final double maturityValue;
  final double totalInterestAtMaturity;
  final double estimatedAccruedValue; // Current mathematical value
  final double realizedValue; // Sum of credited payouts + accrued interest

  // Notes
  final String? notes;
  final String? bankName;
  final String? bankAccountNumber;
  final Map<String, dynamic>? metadata;

  FixedDeposit({
    required this.id,
    required this.name,
    required this.principal,
    required this.interestRate,
    required this.tenureMonths,
    required this.compoundingFrequency,
    required this.payoutFrequency,
    required this.isCumulative,
    required this.linkedAccountId,
    required this.linkedAccountName,
    required this.autoLinkEnabled,
    required this.createdDate,
    required this.investmentDate,
    required this.maturityDate,
    required this.status,
    this.withdrawalDate,
    this.withdrawalAmount,
    this.withdrawalReason,
    required this.pastPayouts,
    required this.upcomingPayouts,
    required this.maturityValue,
    required this.totalInterestAtMaturity,
    required this.estimatedAccruedValue,
    required this.realizedValue,
    this.notes,
    this.bankName,
    this.bankAccountNumber,
    this.metadata,
  });

  /// Get days until maturity
  int get daysUntilMaturity {
    if (status == FDStatus.mature ||
        status == FDStatus.prematurelyWithdrawn ||
        status == FDStatus.completed) {
      return 0;
    }
    return maturityDate.difference(DateTime.now()).inDays;
  }

  /// Get months remaining
  int get monthsRemaining {
    if (status == FDStatus.mature ||
        status == FDStatus.prematurelyWithdrawn ||
        status == FDStatus.completed) {
      return 0;
    }
    final now = DateTime.now();
    final months = (maturityDate.year - now.year) * 12 +
                   (maturityDate.month - now.month);
    return months > 0 ? months : 0;
  }

  /// Get elapsed time in months
  int get elapsedMonths {
    final now = DateTime.now();
    final months = (now.year - investmentDate.year) * 12 +
                   (now.month - investmentDate.month);
    return months > 0 ? months : 0;
  }

  /// Get elapsed time as fraction of total tenure
  double get elapsedFraction {
    return elapsedMonths / tenureMonths;
  }

  /// Total interest earned till date
  double get interestEarnedTillDate {
    return estimatedAccruedValue - principal;
  }

  /// Get next upcoming payout
  PayoutRecord? get nextPayout {
    final pending = upcomingPayouts
        .where((p) => p.payoutDate.isAfter(DateTime.now()))
        .toList();
    if (pending.isEmpty) return null;
    pending.sort((a, b) => a.payoutDate.compareTo(b.payoutDate));
    return pending.first;
  }

  /// Days until next payout
  int get daysUntilNextPayout {
    final next = nextPayout;
    if (next == null) return 0;
    final days = next.payoutDate.difference(DateTime.now()).inDays;
    return days > 0 ? days : 0;
  }

  /// Check if notification needed (3-5 days before payout)
  bool get shouldNotifyForNextPayout {
    final next = nextPayout;
    if (next == null) return false;
    final days = daysUntilNextPayout;
    return days > 0 && days <= 5 && !autoLinkEnabled;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'principal': principal,
      'interestRate': interestRate,
      'tenureMonths': tenureMonths,
      'compoundingFrequency': compoundingFrequency.index,
      'payoutFrequency': payoutFrequency.index,
      'isCumulative': isCumulative,
      'linkedAccountId': linkedAccountId,
      'linkedAccountName': linkedAccountName,
      'autoLinkEnabled': autoLinkEnabled,
      'createdDate': createdDate.toIso8601String(),
      'investmentDate': investmentDate.toIso8601String(),
      'maturityDate': maturityDate.toIso8601String(),
      'status': status.index,
      'withdrawalDate': withdrawalDate?.toIso8601String(),
      'withdrawalAmount': withdrawalAmount,
      'withdrawalReason': withdrawalReason,
      'pastPayouts': pastPayouts.map((p) => p.toMap()).toList(),
      'upcomingPayouts': upcomingPayouts.map((p) => p.toMap()).toList(),
      'maturityValue': maturityValue,
      'totalInterestAtMaturity': totalInterestAtMaturity,
      'estimatedAccruedValue': estimatedAccruedValue,
      'realizedValue': realizedValue,
      'notes': notes,
      'bankName': bankName,
      'bankAccountNumber': bankAccountNumber,
      'metadata': metadata,
    };
  }

  factory FixedDeposit.fromMap(Map<String, dynamic> map) {
    return FixedDeposit(
      id: map['id'],
      name: map['name'],
      principal: (map['principal'] as num).toDouble(),
      interestRate: (map['interestRate'] as num).toDouble(),
      tenureMonths: map['tenureMonths'] as int,
      compoundingFrequency: FDCompoundingFrequency
          .values[map['compoundingFrequency'] as int],
      payoutFrequency:
          FDPayoutFrequency.values[map['payoutFrequency'] as int],
      isCumulative: map['isCumulative'] as bool,
      linkedAccountId: map['linkedAccountId'],
      linkedAccountName: map['linkedAccountName'],
      autoLinkEnabled: map['autoLinkEnabled'] as bool,
      createdDate: DateTime.parse(map['createdDate']),
      investmentDate: DateTime.parse(map['investmentDate']),
      maturityDate: DateTime.parse(map['maturityDate']),
      status: FDStatus.values[map['status'] as int],
      withdrawalDate: map['withdrawalDate'] != null
          ? DateTime.parse(map['withdrawalDate'])
          : null,
      withdrawalAmount: map['withdrawalAmount'] as double?,
      withdrawalReason: map['withdrawalReason'] as String?,
      pastPayouts: (map['pastPayouts'] as List?)
              ?.map((p) => PayoutRecord.fromMap(p as Map<String, dynamic>))
              .toList() ??
          [],
      upcomingPayouts: (map['upcomingPayouts'] as List?)
              ?.map((p) => PayoutRecord.fromMap(p as Map<String, dynamic>))
              .toList() ??
          [],
      maturityValue: (map['maturityValue'] as num).toDouble(),
      totalInterestAtMaturity:
          (map['totalInterestAtMaturity'] as num).toDouble(),
      estimatedAccruedValue:
          (map['estimatedAccruedValue'] as num).toDouble(),
      realizedValue: (map['realizedValue'] as num).toDouble(),
      notes: map['notes'] as String?,
      bankName: map['bankName'] as String?,
      bankAccountNumber: map['bankAccountNumber'] as String?,
      metadata: map['metadata'] as Map<String, dynamic>?,
    );
  }

  FixedDeposit copyWith({
    String? id,
    String? name,
    double? principal,
    double? interestRate,
    int? tenureMonths,
    FDCompoundingFrequency? compoundingFrequency,
    FDPayoutFrequency? payoutFrequency,
    bool? isCumulative,
    String? linkedAccountId,
    String? linkedAccountName,
    bool? autoLinkEnabled,
    DateTime? createdDate,
    DateTime? investmentDate,
    DateTime? maturityDate,
    FDStatus? status,
    DateTime? withdrawalDate,
    double? withdrawalAmount,
    String? withdrawalReason,
    List<PayoutRecord>? pastPayouts,
    List<PayoutRecord>? upcomingPayouts,
    double? maturityValue,
    double? totalInterestAtMaturity,
    double? estimatedAccruedValue,
    double? realizedValue,
    String? notes,
    String? bankName,
    String? bankAccountNumber,
    Map<String, dynamic>? metadata,
  }) {
    return FixedDeposit(
      id: id ?? this.id,
      name: name ?? this.name,
      principal: principal ?? this.principal,
      interestRate: interestRate ?? this.interestRate,
      tenureMonths: tenureMonths ?? this.tenureMonths,
      compoundingFrequency:
          compoundingFrequency ?? this.compoundingFrequency,
      payoutFrequency: payoutFrequency ?? this.payoutFrequency,
      isCumulative: isCumulative ?? this.isCumulative,
      linkedAccountId: linkedAccountId ?? this.linkedAccountId,
      linkedAccountName: linkedAccountName ?? this.linkedAccountName,
      autoLinkEnabled: autoLinkEnabled ?? this.autoLinkEnabled,
      createdDate: createdDate ?? this.createdDate,
      investmentDate: investmentDate ?? this.investmentDate,
      maturityDate: maturityDate ?? this.maturityDate,
      status: status ?? this.status,
      withdrawalDate: withdrawalDate ?? this.withdrawalDate,
      withdrawalAmount: withdrawalAmount ?? this.withdrawalAmount,
      withdrawalReason: withdrawalReason ?? this.withdrawalReason,
      pastPayouts: pastPayouts ?? this.pastPayouts,
      upcomingPayouts: upcomingPayouts ?? this.upcomingPayouts,
      maturityValue: maturityValue ?? this.maturityValue,
      totalInterestAtMaturity:
          totalInterestAtMaturity ?? this.totalInterestAtMaturity,
      estimatedAccruedValue:
          estimatedAccruedValue ?? this.estimatedAccruedValue,
      realizedValue: realizedValue ?? this.realizedValue,
      notes: notes ?? this.notes,
      bankName: bankName ?? this.bankName,
      bankAccountNumber: bankAccountNumber ?? this.bankAccountNumber,
      metadata: metadata ?? this.metadata,
    );
  }

  String getCompoundingLabel() {
    switch (compoundingFrequency) {
      case FDCompoundingFrequency.annual:
        return 'Annually';
      case FDCompoundingFrequency.semiAnnual:
        return 'Semi-Annually';
      case FDCompoundingFrequency.quarterly:
        return 'Quarterly';
      case FDCompoundingFrequency.monthly:
        return 'Monthly';
    }
  }

  String getPayoutLabel() {
    switch (payoutFrequency) {
      case FDPayoutFrequency.annual:
        return 'Annually';
      case FDPayoutFrequency.semiAnnual:
        return 'Semi-Annually';
      case FDPayoutFrequency.quarterly:
        return 'Quarterly';
      case FDPayoutFrequency.monthly:
        return 'Monthly';
      case FDPayoutFrequency.atMaturity:
        return 'At Maturity';
    }
  }

  String getStatusLabel() {
    switch (status) {
      case FDStatus.active:
        return 'Active';
      case FDStatus.mature:
        return 'Mature';
      case FDStatus.prematurelyWithdrawn:
        return 'Withdrawn';
      case FDStatus.completed:
        return 'Completed';
    }
  }
}

/// Utility class for FD calculations
class FDCalculator {
  /// Calculate maturity value for cumulative FD
  /// Formula: A = P(1 + r/100n)^(nt)
  /// where P = principal, r = annual rate, n = compounding frequency per year, t = tenure in years
  static double calculateMaturityValueCumulative({
    required double principal,
    required double annualRate,
    required int tenureMonths,
    required FDCompoundingFrequency frequency,
  }) {
    final t = tenureMonths / 12.0; // Convert to years
    final r = annualRate / 100.0;

    int n = 1; // compounding frequency per year
    switch (frequency) {
      case FDCompoundingFrequency.annual:
        n = 1;
        break;
      case FDCompoundingFrequency.semiAnnual:
        n = 2;
        break;
      case FDCompoundingFrequency.quarterly:
        n = 4;
        break;
      case FDCompoundingFrequency.monthly:
        n = 12;
        break;
    }

    return principal * math.pow(1 + (r / n), n * t);
  }

  /// Calculate maturity value for non-cumulative FD (simple interest)
  /// Formula: A = P + (P × r × t)
  /// where P = principal, r = annual rate, t = tenure in years
  static double calculateMaturityValueNonCumulative({
    required double principal,
    required double annualRate,
    required int tenureMonths,
  }) {
    final t = tenureMonths / 12.0; // Convert to years
    final r = annualRate / 100.0;
    final interest = principal * r * t;
    return principal + interest;
  }

  /// Calculate accrued value at a specific date
  static double calculateAccruedValue({
    required double principal,
    required double annualRate,
    required DateTime investmentDate,
    required DateTime targetDate,
    required FDCompoundingFrequency compoundingFrequency,
    required bool isCumulative,
  }) {
    final elapsedMonths = _getMonthsBetween(investmentDate, targetDate);

    if (isCumulative) {
      return calculateMaturityValueCumulative(
        principal: principal,
        annualRate: annualRate,
        tenureMonths: elapsedMonths,
        frequency: compoundingFrequency,
      );
    } else {
      return calculateMaturityValueNonCumulative(
        principal: principal,
        annualRate: annualRate,
        tenureMonths: elapsedMonths,
      );
    }
  }

  /// Generate payout schedule with calendar-accurate dates
  static List<PayoutRecord> generatePayoutSchedule({
    required String fdId,
    required double principal,
    required double annualRate,
    required DateTime investmentDate,
    required int tenureMonths,
    required FDPayoutFrequency payoutFrequency,
    required FDCompoundingFrequency compoundingFrequency,
    required bool isCumulative,
    required DateTime maturityDate,
  }) {
    final payouts = <PayoutRecord>[];

    if (payoutFrequency == FDPayoutFrequency.atMaturity) {
      // Single payout at maturity
      final maturityValue = isCumulative
          ? calculateMaturityValueCumulative(
              principal: principal,
              annualRate: annualRate,
              tenureMonths: tenureMonths,
              frequency: compoundingFrequency,
            )
          : calculateMaturityValueNonCumulative(
              principal: principal,
              annualRate: annualRate,
              tenureMonths: tenureMonths,
            );

      payouts.add(PayoutRecord(
        id: '${fdId}_payout_maturity',
        payoutDate: maturityDate,
        interestAmount: maturityValue - principal,
        principalAmount: principal,
        isProcessed: false,
        payoutType: 'both',
      ));
      return payouts;
    }

    // Calculate payout interval in months
    int payoutIntervalMonths = 12;
    switch (payoutFrequency) {
      case FDPayoutFrequency.annual:
        payoutIntervalMonths = 12;
        break;
      case FDPayoutFrequency.semiAnnual:
        payoutIntervalMonths = 6;
        break;
      case FDPayoutFrequency.quarterly:
        payoutIntervalMonths = 3;
        break;
      case FDPayoutFrequency.monthly:
        payoutIntervalMonths = 1;
        break;
      case FDPayoutFrequency.atMaturity:
        // Handled above
        break;
    }

    // Generate payouts at each interval
    var currentPayoutDate = _addMonths(investmentDate, payoutIntervalMonths);
    int payoutNumber = 0;

    while (currentPayoutDate.isBefore(maturityDate) ||
        currentPayoutDate.isAtSameMomentAs(maturityDate)) {
      payoutNumber++;

      // Calculate interest for this payout
      final prevPayoutDate = payoutNumber == 1
          ? investmentDate
          : _addMonths(investmentDate, (payoutNumber - 1) * payoutIntervalMonths);

      final prevAccruedValue = calculateAccruedValue(
        principal: principal,
        annualRate: annualRate,
        investmentDate: investmentDate,
        targetDate: prevPayoutDate,
        compoundingFrequency: compoundingFrequency,
        isCumulative: isCumulative,
      );

      final currentAccruedValue = calculateAccruedValue(
        principal: principal,
        annualRate: annualRate,
        investmentDate: investmentDate,
        targetDate: currentPayoutDate,
        compoundingFrequency: compoundingFrequency,
        isCumulative: isCumulative,
      );

      final interestAmount = currentAccruedValue - prevAccruedValue;

      // Last payout includes principal
      final isLastPayout = currentPayoutDate.isAtSameMomentAs(maturityDate);

      payouts.add(PayoutRecord(
        id: '${fdId}_payout_${payoutNumber}',
        payoutDate: currentPayoutDate,
        interestAmount: interestAmount,
        principalAmount: isLastPayout ? principal : 0,
        isProcessed: currentPayoutDate.isBefore(DateTime.now()),
        processedDate: currentPayoutDate.isBefore(DateTime.now())
            ? currentPayoutDate
            : null,
        payoutType: isLastPayout ? 'both' : 'interest',
      ));

      currentPayoutDate = _addMonths(currentPayoutDate, payoutIntervalMonths);
    }

    return payouts;
  }

  /// Add months to a date (calendar-accurate)
  static DateTime _addMonths(DateTime date, int months) {
    var newMonth = date.month + months;
    var newYear = date.year;

    while (newMonth > 12) {
      newMonth -= 12;
      newYear++;
    }

    // Handle day overflow (e.g., Jan 31 + 1 month = Feb 28/29)
    final lastDayOfMonth = DateTime(newYear, newMonth + 1, 0).day;
    final newDay = date.day > lastDayOfMonth ? lastDayOfMonth : date.day;

    return DateTime(newYear, newMonth, newDay);
  }

  /// Get months between two dates
  static int _getMonthsBetween(DateTime from, DateTime to) {
    return (to.year - from.year) * 12 + (to.month - from.month);
  }

  /// Calculate realized value (sum of credited payouts + accrued interest on remaining principal)
  static double calculateRealizedValue({
    required FixedDeposit fd,
  }) {
    // Sum of all processed payouts
    double processedPayouts = fd.pastPayouts
        .where((p) => p.isProcessed)
        .fold(0.0, (sum, p) => sum + p.interestAmount + p.principalAmount);

    // For active FDs, add accrued interest on principal still in FD
    double accruedOnRemaining = 0;
    if (fd.status == FDStatus.active) {
      final now = DateTime.now();
      if (now.isBefore(fd.maturityDate)) {
        final accruedValue = calculateAccruedValue(
          principal: fd.principal,
          annualRate: fd.interestRate,
          investmentDate: fd.investmentDate,
          targetDate: now,
          compoundingFrequency: fd.compoundingFrequency,
          isCumulative: fd.isCumulative,
        );
        accruedOnRemaining = accruedValue - fd.principal;
      }
    }

    return processedPayouts + accruedOnRemaining;
  }
}
