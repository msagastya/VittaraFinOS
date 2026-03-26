import 'dart:math' as math;

enum BondType { government, corporate, municipal }

enum CouponFrequency { annual, semiAnnual, quarterly, monthly }

enum BondStatus { active, matured, redeemed, defaulted }

/// Represents a coupon payment record
class CouponPayment {
  final String id;
  final DateTime paymentDate;
  final double couponAmount;
  final bool isPaid;
  final DateTime? paidDate;

  CouponPayment({
    required this.id,
    required this.paymentDate,
    required this.couponAmount,
    required this.isPaid,
    this.paidDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'paymentDate': paymentDate.toIso8601String(),
      'couponAmount': couponAmount,
      'isPaid': isPaid,
      'paidDate': paidDate?.toIso8601String(),
    };
  }

  factory CouponPayment.fromMap(Map<String, dynamic> map) {
    return CouponPayment(
      id: map['id'],
      paymentDate: DateTime.parse(map['paymentDate']),
      couponAmount: (map['couponAmount'] as num).toDouble(),
      isPaid: map['isPaid'] as bool,
      paidDate:
          map['paidDate'] != null ? DateTime.parse(map['paidDate']) : null,
    );
  }

  CouponPayment copyWith({
    String? id,
    DateTime? paymentDate,
    double? couponAmount,
    bool? isPaid,
    DateTime? paidDate,
  }) {
    return CouponPayment(
      id: id ?? this.id,
      paymentDate: paymentDate ?? this.paymentDate,
      couponAmount: couponAmount ?? this.couponAmount,
      isPaid: isPaid ?? this.isPaid,
      paidDate: paidDate ?? this.paidDate,
    );
  }
}

/// Core Bond model
class Bond {
  final String id;
  final String name;
  final String issuer; // Government of India, HDFC, etc.
  final BondType bondType;
  final double faceValue; // Par value
  final double couponRate; // Annual coupon rate in percentage
  final CouponFrequency couponFrequency;
  final int purchaseQuantity; // Number of bonds purchased
  final double purchasePrice; // Price per bond (may differ from face value)

  // Account linking
  final String linkedAccountId;
  final String linkedAccountName;

  // Timestamps
  final DateTime createdDate;
  final DateTime purchaseDate;
  final DateTime maturityDate;

  // Current status
  final BondStatus status;
  final DateTime? redemptionDate;
  final double? redemptionPrice;

  // Coupon tracking
  final List<CouponPayment> paidCoupons;
  final List<CouponPayment> upcomingCoupons;

  // Calculation cache
  final double totalCost; // purchaseQuantity × purchasePrice
  final double maturityValue; // purchaseQuantity × faceValue
  final double totalCouponAtMaturity; // Sum of all coupons
  final double currentMarketValue; // Current market price estimate
  final double yieldToMaturity; // YTM percentage
  final double estimatedAccruedValue; // Current mathematical value
  final double realizedValue; // Sum of received coupons + current value

  // Notes
  final String? notes;
  final String? creditRating; // AAA, AA, A, BBB, etc.
  final Map<String, dynamic>? metadata;

  Bond({
    required this.id,
    required this.name,
    required this.issuer,
    required this.bondType,
    required this.faceValue,
    required this.couponRate,
    required this.couponFrequency,
    required this.purchaseQuantity,
    required this.purchasePrice,
    required this.linkedAccountId,
    required this.linkedAccountName,
    required this.createdDate,
    required this.purchaseDate,
    required this.maturityDate,
    required this.status,
    this.redemptionDate,
    this.redemptionPrice,
    required this.paidCoupons,
    required this.upcomingCoupons,
    required this.totalCost,
    required this.maturityValue,
    required this.totalCouponAtMaturity,
    required this.currentMarketValue,
    required this.yieldToMaturity,
    required this.estimatedAccruedValue,
    required this.realizedValue,
    this.notes,
    this.creditRating,
    this.metadata,
  });

  /// Get days until maturity
  int get daysUntilMaturity {
    if (status != BondStatus.active) return 0;
    return maturityDate.difference(DateTime.now()).inDays;
  }

  /// Get years until maturity
  double get yearsUntilMaturity {
    return daysUntilMaturity / 365.25;
  }

  /// Get months until maturity
  int get monthsUntilMaturity {
    final now = DateTime.now();
    final months =
        (maturityDate.year - now.year) * 12 + (maturityDate.month - now.month);
    return months > 0 ? months : 0;
  }

  /// Get next coupon payment
  CouponPayment? get nextCoupon {
    final pending = upcomingCoupons
        .where((c) => c.paymentDate.isAfter(DateTime.now()))
        .toList();
    if (pending.isEmpty) return null;
    pending.sort((a, b) => a.paymentDate.compareTo(b.paymentDate));
    return pending.first;
  }

  /// Days until next coupon
  int get daysUntilNextCoupon {
    final next = nextCoupon;
    if (next == null) return 0;
    final days = next.paymentDate.difference(DateTime.now()).inDays;
    return days > 0 ? days : 0;
  }

  /// Total accrued coupon (earned but not yet paid)
  double get accruedCoupon {
    final now = DateTime.now();
    final last =
        paidCoupons.isNotEmpty ? paidCoupons.last.paymentDate : purchaseDate;

    if (last.isAfter(now)) return 0;

    final next = nextCoupon;
    if (next == null) return 0;

    final days = now.difference(last).inDays;
    final totalDays = next.paymentDate.difference(last).inDays;

    if (totalDays == 0) return 0;
    return (next.couponAmount * days) / totalDays;
  }

  /// Gain/Loss from purchase
  double get gainLoss {
    return (currentMarketValue - totalCost) * purchaseQuantity;
  }

  /// Current value including accrued coupon
  double get currentValue {
    return currentMarketValue + accruedCoupon;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'issuer': issuer,
      'bondType': bondType.index,
      'faceValue': faceValue,
      'couponRate': couponRate,
      'couponFrequency': couponFrequency.index,
      'purchaseQuantity': purchaseQuantity,
      'purchasePrice': purchasePrice,
      'linkedAccountId': linkedAccountId,
      'linkedAccountName': linkedAccountName,
      'createdDate': createdDate.toIso8601String(),
      'purchaseDate': purchaseDate.toIso8601String(),
      'maturityDate': maturityDate.toIso8601String(),
      'status': status.index,
      'redemptionDate': redemptionDate?.toIso8601String(),
      'redemptionPrice': redemptionPrice,
      'paidCoupons': paidCoupons.map((c) => c.toMap()).toList(),
      'upcomingCoupons': upcomingCoupons.map((c) => c.toMap()).toList(),
      'totalCost': totalCost,
      'maturityValue': maturityValue,
      'totalCouponAtMaturity': totalCouponAtMaturity,
      'currentMarketValue': currentMarketValue,
      'yieldToMaturity': yieldToMaturity,
      'estimatedAccruedValue': estimatedAccruedValue,
      'realizedValue': realizedValue,
      'notes': notes,
      'creditRating': creditRating,
      'metadata': metadata,
    };
  }

  factory Bond.fromMap(Map<String, dynamic> map) {
    return Bond(
      id: map['id'],
      name: map['name'],
      issuer: map['issuer'],
      bondType: BondType.values[((map['bondType'] as num?)?.toInt() ?? 0).clamp(0, BondType.values.length - 1)],
      faceValue: (map['faceValue'] as num).toDouble(),
      couponRate: (map['couponRate'] as num).toDouble(),
      couponFrequency: CouponFrequency.values[((map['couponFrequency'] as num?)?.toInt() ?? 0).clamp(0, CouponFrequency.values.length - 1)],
      purchaseQuantity: map['purchaseQuantity'] as int,
      purchasePrice: (map['purchasePrice'] as num).toDouble(),
      linkedAccountId: map['linkedAccountId'],
      linkedAccountName: map['linkedAccountName'],
      createdDate: DateTime.parse(map['createdDate']),
      purchaseDate: DateTime.parse(map['purchaseDate']),
      maturityDate: DateTime.parse(map['maturityDate']),
      status: BondStatus.values[((map['status'] as num?)?.toInt() ?? 0).clamp(0, BondStatus.values.length - 1)],
      redemptionDate: map['redemptionDate'] != null
          ? DateTime.parse(map['redemptionDate'])
          : null,
      redemptionPrice: (map['redemptionPrice'] as num?)?.toDouble(),
      paidCoupons: (map['paidCoupons'] as List?)
              ?.map((c) => CouponPayment.fromMap(c as Map<String, dynamic>))
              .toList() ??
          [],
      upcomingCoupons: (map['upcomingCoupons'] as List?)
              ?.map((c) => CouponPayment.fromMap(c as Map<String, dynamic>))
              .toList() ??
          [],
      totalCost: (map['totalCost'] as num).toDouble(),
      maturityValue: (map['maturityValue'] as num).toDouble(),
      totalCouponAtMaturity: (map['totalCouponAtMaturity'] as num).toDouble(),
      currentMarketValue: (map['currentMarketValue'] as num).toDouble(),
      yieldToMaturity: (map['yieldToMaturity'] as num).toDouble(),
      estimatedAccruedValue: (map['estimatedAccruedValue'] as num).toDouble(),
      realizedValue: (map['realizedValue'] as num).toDouble(),
      notes: map['notes'] as String?,
      creditRating: map['creditRating'] as String?,
      metadata: map['metadata'] as Map<String, dynamic>?,
    );
  }

  Bond copyWith({
    String? id,
    String? name,
    String? issuer,
    BondType? bondType,
    double? faceValue,
    double? couponRate,
    CouponFrequency? couponFrequency,
    int? purchaseQuantity,
    double? purchasePrice,
    String? linkedAccountId,
    String? linkedAccountName,
    DateTime? createdDate,
    DateTime? purchaseDate,
    DateTime? maturityDate,
    BondStatus? status,
    DateTime? redemptionDate,
    double? redemptionPrice,
    List<CouponPayment>? paidCoupons,
    List<CouponPayment>? upcomingCoupons,
    double? totalCost,
    double? maturityValue,
    double? totalCouponAtMaturity,
    double? currentMarketValue,
    double? yieldToMaturity,
    double? estimatedAccruedValue,
    double? realizedValue,
    String? notes,
    String? creditRating,
    Map<String, dynamic>? metadata,
  }) {
    return Bond(
      id: id ?? this.id,
      name: name ?? this.name,
      issuer: issuer ?? this.issuer,
      bondType: bondType ?? this.bondType,
      faceValue: faceValue ?? this.faceValue,
      couponRate: couponRate ?? this.couponRate,
      couponFrequency: couponFrequency ?? this.couponFrequency,
      purchaseQuantity: purchaseQuantity ?? this.purchaseQuantity,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      linkedAccountId: linkedAccountId ?? this.linkedAccountId,
      linkedAccountName: linkedAccountName ?? this.linkedAccountName,
      createdDate: createdDate ?? this.createdDate,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      maturityDate: maturityDate ?? this.maturityDate,
      status: status ?? this.status,
      redemptionDate: redemptionDate ?? this.redemptionDate,
      redemptionPrice: redemptionPrice ?? this.redemptionPrice,
      paidCoupons: paidCoupons ?? this.paidCoupons,
      upcomingCoupons: upcomingCoupons ?? this.upcomingCoupons,
      totalCost: totalCost ?? this.totalCost,
      maturityValue: maturityValue ?? this.maturityValue,
      totalCouponAtMaturity:
          totalCouponAtMaturity ?? this.totalCouponAtMaturity,
      currentMarketValue: currentMarketValue ?? this.currentMarketValue,
      yieldToMaturity: yieldToMaturity ?? this.yieldToMaturity,
      estimatedAccruedValue:
          estimatedAccruedValue ?? this.estimatedAccruedValue,
      realizedValue: realizedValue ?? this.realizedValue,
      notes: notes ?? this.notes,
      creditRating: creditRating ?? this.creditRating,
      metadata: metadata ?? this.metadata,
    );
  }

  String getBondTypeLabel() {
    switch (bondType) {
      case BondType.government:
        return 'Government';
      case BondType.corporate:
        return 'Corporate';
      case BondType.municipal:
        return 'Municipal';
    }
  }

  String getCouponFrequencyLabel() {
    switch (couponFrequency) {
      case CouponFrequency.annual:
        return 'Annually';
      case CouponFrequency.semiAnnual:
        return 'Semi-Annually';
      case CouponFrequency.quarterly:
        return 'Quarterly';
      case CouponFrequency.monthly:
        return 'Monthly';
    }
  }

  String getStatusLabel() {
    switch (status) {
      case BondStatus.active:
        return 'Active';
      case BondStatus.matured:
        return 'Matured';
      case BondStatus.redeemed:
        return 'Redeemed';
      case BondStatus.defaulted:
        return 'Defaulted';
    }
  }
}

/// Utility class for bond calculations
class BondCalculator {
  /// Calculate Yield to Maturity (YTM) using Newton-Raphson method
  /// YTM is the discount rate that equates bond price to present value of future cash flows
  static double calculateYieldToMaturity({
    required double currentPrice,
    required double faceValue,
    required double annualCoupon,
    required int yearsToMaturity,
    int maxIterations = 100,
    double tolerance = 0.0001,
  }) {
    if (yearsToMaturity == 0) {
      return (faceValue - currentPrice) / currentPrice * 100;
    }

    // Initial guess: use current yield as starting point
    double ytm = (annualCoupon / currentPrice) * 100;
    ytm = ytm / 100; // Convert to decimal

    for (int i = 0; i < maxIterations; i++) {
      // Calculate bond price at current YTM estimate
      double price = 0;
      for (int t = 1; t <= yearsToMaturity; t++) {
        price += annualCoupon / math.pow(1 + ytm, t);
      }
      price += faceValue / math.pow(1 + ytm, yearsToMaturity);

      // Calculate first derivative (modified duration)
      double derivative = 0;
      for (int t = 1; t <= yearsToMaturity; t++) {
        derivative -= t * annualCoupon / math.pow(1 + ytm, t + 1);
      }
      derivative -=
          yearsToMaturity * faceValue / math.pow(1 + ytm, yearsToMaturity + 1);

      // Newton-Raphson iteration
      final priceError = price - currentPrice;
      if (priceError.abs() < tolerance) {
        return ytm * 100; // Convert back to percentage
      }

      ytm = ytm - (priceError / derivative);

      if (ytm < -0.99) ytm = -0.99; // Prevent unrealistic negative yields
    }

    return ytm * 100; // Convert back to percentage
  }

  /// Calculate bond price given YTM
  static double calculateBondPrice({
    required double faceValue,
    required double couponRate,
    required double yieldToMaturity,
    required int yearsToMaturity,
  }) {
    final r = yieldToMaturity / 100;
    final c = (couponRate / 100) * faceValue;

    double price = 0;
    for (int t = 1; t <= yearsToMaturity; t++) {
      price += c / math.pow(1 + r, t);
    }
    price += faceValue / math.pow(1 + r, yearsToMaturity);

    return price;
  }

  /// Calculate coupon payment
  static double calculateCouponPayment({
    required double faceValue,
    required double couponRate,
    required CouponFrequency frequency,
  }) {
    final annualCoupon = (couponRate / 100) * faceValue;
    final payments = _getPaymentsPerYear(frequency);
    return annualCoupon / payments;
  }

  /// Generate coupon payment schedule
  static List<CouponPayment> generateCouponSchedule({
    required String bondId,
    required DateTime purchaseDate,
    required DateTime maturityDate,
    required double faceValue,
    required double couponRate,
    required CouponFrequency frequency,
  }) {
    final payments = <CouponPayment>[];
    final couponAmount = calculateCouponPayment(
      faceValue: faceValue,
      couponRate: couponRate,
      frequency: frequency,
    );

    final monthsInterval = _getMonthsInterval(frequency);
    var currentDate = _addMonths(purchaseDate, monthsInterval);
    int paymentNumber = 0;

    while (currentDate.isBefore(maturityDate) ||
        currentDate.isAtSameMomentAs(maturityDate)) {
      paymentNumber++;
      final isPaid = currentDate.isBefore(DateTime.now());

      payments.add(CouponPayment(
        id: '${bondId}_coupon_$paymentNumber',
        paymentDate: currentDate,
        couponAmount: couponAmount,
        isPaid: isPaid,
        paidDate: isPaid ? currentDate : null,
      ));

      currentDate = _addMonths(currentDate, monthsInterval);
    }

    return payments;
  }

  /// Get number of coupon payments per year
  static int _getPaymentsPerYear(CouponFrequency frequency) {
    switch (frequency) {
      case CouponFrequency.annual:
        return 1;
      case CouponFrequency.semiAnnual:
        return 2;
      case CouponFrequency.quarterly:
        return 4;
      case CouponFrequency.monthly:
        return 12;
    }
  }

  /// Get months interval between coupon payments
  static int _getMonthsInterval(CouponFrequency frequency) {
    switch (frequency) {
      case CouponFrequency.annual:
        return 12;
      case CouponFrequency.semiAnnual:
        return 6;
      case CouponFrequency.quarterly:
        return 3;
      case CouponFrequency.monthly:
        return 1;
    }
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

  /// Calculate modified duration (bond price sensitivity to yield changes)
  static double calculateModifiedDuration({
    required double bondPrice,
    required double faceValue,
    required double couponRate,
    required double yieldToMaturity,
    required int yearsToMaturity,
  }) {
    final r = yieldToMaturity / 100;
    final c = (couponRate / 100) * faceValue;

    double weightedCashFlow = 0;
    for (int t = 1; t <= yearsToMaturity; t++) {
      weightedCashFlow += (t * c) / math.pow(1 + r, t);
    }
    weightedCashFlow +=
        (yearsToMaturity * faceValue) / math.pow(1 + r, yearsToMaturity);

    return (weightedCashFlow / bondPrice) / (1 + r);
  }

  /// Calculate accrued interest
  static double calculateAccruedInterest({
    required double couponPayment,
    required DateTime lastCouponDate,
    required DateTime nextCouponDate,
  }) {
    final now = DateTime.now();
    if (now.isBefore(lastCouponDate) || now.isAfter(nextCouponDate)) {
      return 0;
    }

    final daysSinceLastCoupon = now.difference(lastCouponDate).inDays;
    final daysBetweenCoupons = nextCouponDate.difference(lastCouponDate).inDays;

    if (daysBetweenCoupons == 0) return 0;
    return (couponPayment * daysSinceLastCoupon) / daysBetweenCoupons;
  }
}
