import 'dart:math' as math;

/// Represents a single cash flow event for a bond
class BondCashFlow {
  final DateTime date;
  final double
      amount; // negative = outflow (purchase), positive = inflow (payment)
  final String
      description; // "Purchase", "Coupon Payment", "Principal Repayment", etc.

  BondCashFlow({
    required this.date,
    required this.amount,
    required this.description,
  });

  Map<String, dynamic> toMap() => {
        'date': date.toIso8601String(),
        'amount': amount,
        'description': description,
      };

  factory BondCashFlow.fromMap(Map<String, dynamic> map) => BondCashFlow(
        date: DateTime.parse(map['date']),
        amount: (map['amount'] as num).toDouble(),
        description: map['description'],
      );
}

/// Bond types - only affects how cash flows are GENERATED
enum BondType {
  fixedCoupon, // Regular coupon payments + principal at maturity
  zeroCoupon, // Single payment at maturity
  monthlyFixed, // Fixed coupon paid monthly
  amortizing, // Principal repaid gradually with interest
  floatingRate, // Coupon varies with reference rate
}

/// Represents the complete bond with its cash flow schedule
class Bond {
  final String id;
  final String name;
  final BondType type;

  // Metadata
  final double faceValue;
  final DateTime issueDate;
  final DateTime maturityDate;
  final DateTime purchaseDate;
  final double purchasePrice;

  // Rate information
  final double? fixedCouponRate; // For fixed/monthly bonds (annual %)
  final double? referenceRate; // For floating bonds (current reference rate %)
  final double? spread; // Spread over reference rate for floating bonds
  final int
      paymentsPerYear; // Coupon frequency (1=annual, 2=semi-annual, 12=monthly)

  // The CORE: Cash flow schedule
  final List<BondCashFlow> cashFlows; // Sorted by date

  // Calculated fields
  final double? yieldToMaturity; // IRR of all cash flows
  final DateTime createdDate;
  final String? notes;

  Bond({
    required this.id,
    required this.name,
    required this.type,
    required this.faceValue,
    required this.issueDate,
    required this.maturityDate,
    required this.purchaseDate,
    required this.purchasePrice,
    this.fixedCouponRate,
    this.referenceRate,
    this.spread,
    required this.paymentsPerYear,
    required this.cashFlows,
    this.yieldToMaturity,
    required this.createdDate,
    this.notes,
  });

  /// Calculate total invested (sum of negative cash flows)
  double get totalInvested {
    return cashFlows
        .where((cf) => cf.amount < 0)
        .fold(0.0, (sum, cf) => sum + cf.amount.abs());
  }

  /// Calculate total received (sum of positive cash flows)
  double get totalReceived {
    return cashFlows
        .where((cf) => cf.amount > 0)
        .fold(0.0, (sum, cf) => sum + cf.amount);
  }

  /// Total unrealized P&L
  double get gainLoss => totalReceived - totalInvested;

  /// Unrealized return %
  double get gainLossPercent =>
      totalInvested > 0 ? (gainLoss / totalInvested) * 100 : 0;

  /// Days to maturity
  int get daysToMaturity {
    return maturityDate.difference(DateTime.now()).inDays;
  }

  /// Is bond matured?
  bool get isMatured => DateTime.now().isAfter(maturityDate);

  String getBondTypeLabel() {
    switch (type) {
      case BondType.fixedCoupon:
        return 'Fixed Coupon Bond';
      case BondType.zeroCoupon:
        return 'Zero Coupon Bond';
      case BondType.monthlyFixed:
        return 'Monthly Fixed Bond';
      case BondType.amortizing:
        return 'Amortizing Bond';
      case BondType.floatingRate:
        return 'Floating Rate Bond';
    }
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'type': type.index,
        'faceValue': faceValue,
        'issueDate': issueDate.toIso8601String(),
        'maturityDate': maturityDate.toIso8601String(),
        'purchaseDate': purchaseDate.toIso8601String(),
        'purchasePrice': purchasePrice,
        'fixedCouponRate': fixedCouponRate,
        'referenceRate': referenceRate,
        'spread': spread,
        'paymentsPerYear': paymentsPerYear,
        'cashFlows': cashFlows.map((cf) => cf.toMap()).toList(),
        'yieldToMaturity': yieldToMaturity,
        'createdDate': createdDate.toIso8601String(),
        'notes': notes,
      };

  factory Bond.fromMap(Map<String, dynamic> map) => Bond(
        id: map['id'],
        name: map['name'],
        type: BondType.values[map['type'] as int],
        faceValue: (map['faceValue'] as num).toDouble(),
        issueDate: DateTime.parse(map['issueDate']),
        maturityDate: DateTime.parse(map['maturityDate']),
        purchaseDate: DateTime.parse(map['purchaseDate']),
        purchasePrice: (map['purchasePrice'] as num).toDouble(),
        fixedCouponRate: map['fixedCouponRate'] as double?,
        referenceRate: map['referenceRate'] as double?,
        spread: map['spread'] as double?,
        paymentsPerYear: map['paymentsPerYear'] as int,
        cashFlows: (map['cashFlows'] as List)
            .map((cf) => BondCashFlow.fromMap(cf as Map<String, dynamic>))
            .toList(),
        yieldToMaturity: map['yieldToMaturity'] as double?,
        createdDate: DateTime.parse(map['createdDate']),
        notes: map['notes'] as String?,
      );
}

/// UNIVERSAL YIELD CALCULATOR
/// Works identically for ALL bond types
class BondYieldCalculator {
  /// Calculate IRR (Yield) from cash flow table
  /// IRR is the discount rate r that makes NPV = 0
  /// Σ [ CashFlow_t / (1 + r)^(time_t) ] = 0
  static double calculateYield(List<BondCashFlow> cashFlows) {
    if (cashFlows.isEmpty) return 0;

    // Sort by date
    final sorted = List<BondCashFlow>.from(cashFlows)
      ..sort((a, b) => a.date.compareTo(b.date));

    // Use Newton-Raphson method to find IRR
    double rate = 0.1; // Initial guess: 10%
    const double tolerance = 1e-6;
    const int maxIterations = 1000;

    for (int i = 0; i < maxIterations; i++) {
      // Calculate NPV and derivative (NPV')
      double npv = 0;
      double npvDerivative = 0;
      final baseDate = sorted.first.date;

      for (final cf in sorted) {
        final yearsFromStart = cf.date.difference(baseDate).inDays / 365.25;
        final discountFactor = math.pow(1 + rate, yearsFromStart);

        npv += cf.amount / discountFactor;
        npvDerivative -=
            (yearsFromStart * cf.amount) / (discountFactor * (1 + rate));
      }

      // Check convergence
      if (npv.abs() < tolerance) {
        return rate;
      }

      // Newton-Raphson step
      if (npvDerivative.abs() < 1e-10) {
        break; // Avoid division by near-zero
      }
      rate = rate - (npv / npvDerivative);

      // Prevent unrealistic rates
      if (rate < -0.99) rate = -0.99;
      if (rate > 1.0) rate = 1.0;
    }

    return rate;
  }

  /// Calculate NPV at a given discount rate
  static double calculateNPV(
      List<BondCashFlow> cashFlows, double discountRate) {
    if (cashFlows.isEmpty) return 0;

    double npv = 0;
    final baseDate = cashFlows.first.date;

    for (final cf in cashFlows) {
      final yearsFromStart = cf.date.difference(baseDate).inDays / 365.25;
      npv += cf.amount / math.pow(1 + discountRate, yearsFromStart);
    }

    return npv;
  }
}

/// CASH FLOW GENERATORS
/// Different bond types generate their cash flows differently
/// But the yield calculation is identical!

class CashFlowGenerator {
  /// Generate cash flows for Fixed Coupon Bond
  static List<BondCashFlow> generateFixedCouponCashFlows({
    required DateTime purchaseDate,
    required double purchasePrice,
    required DateTime maturityDate,
    required double faceValue,
    required double annualCouponRate,
    required int paymentsPerYear,
  }) {
    final flows = <BondCashFlow>[];

    // Purchase
    flows.add(BondCashFlow(
      date: purchaseDate,
      amount: -purchasePrice,
      description: 'Bond Purchase',
    ));

    // Generate coupon payment dates
    final couponAmount = (faceValue * annualCouponRate) / paymentsPerYear;

    // Calculate months between payments based on frequency
    final monthsPerPeriod = 12 ~/
        paymentsPerYear; // 12 for annual, 6 for semi-annual, 1 for monthly

    DateTime currentDate = _addMonths(purchaseDate, monthsPerPeriod);

    while (currentDate.isBefore(maturityDate)) {
      flows.add(BondCashFlow(
        date: currentDate,
        amount: couponAmount,
        description: 'Coupon Payment',
      ));
      currentDate = _addMonths(currentDate, monthsPerPeriod);
    }

    // Final payment: coupon + principal
    flows.add(BondCashFlow(
      date: maturityDate,
      amount: couponAmount + faceValue,
      description: 'Final Coupon + Principal Repayment',
    ));

    return flows;
  }

  /// Helper: Add months while maintaining the same day of month
  /// E.g., Jan 31 + 1 month = Feb 28/29 (last day of Feb)
  static DateTime _addMonths(DateTime date, int months) {
    int newMonth = date.month + months;
    int newYear = date.year;

    // Handle year overflow
    while (newMonth > 12) {
      newMonth -= 12;
      newYear++;
    }

    // Get the last day of the target month
    final int lastDayOfMonth = _daysInMonth(newYear, newMonth);
    final int newDay = date.day > lastDayOfMonth ? lastDayOfMonth : date.day;

    return DateTime(newYear, newMonth, newDay);
  }

  /// Helper: Get number of days in a given month
  static int _daysInMonth(int year, int month) {
    if (month == 2) {
      // February: check for leap year
      return (year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)) ? 29 : 28;
    }
    const monthDays = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    return monthDays[month - 1];
  }

  /// Generate cash flows for Zero Coupon Bond
  static List<BondCashFlow> generateZeroCouponCashFlows({
    required DateTime purchaseDate,
    required double purchasePrice,
    required DateTime maturityDate,
    required double maturityValue,
  }) {
    return [
      BondCashFlow(
        date: purchaseDate,
        amount: -purchasePrice,
        description: 'Zero Coupon Bond Purchase',
      ),
      BondCashFlow(
        date: maturityDate,
        amount: maturityValue,
        description: 'Principal Repayment at Maturity',
      ),
    ];
  }

  /// Generate cash flows for Amortizing Bond
  /// Equal principal repayment each period
  static List<BondCashFlow> generateAmortizingCashFlows({
    required DateTime purchaseDate,
    required double purchasePrice,
    required DateTime maturityDate,
    required double faceValue,
    required double annualInterestRate,
    required int paymentsPerYear,
  }) {
    final flows = <BondCashFlow>[];

    // Purchase
    flows.add(BondCashFlow(
      date: purchaseDate,
      amount: -purchasePrice,
      description: 'Bond Purchase',
    ));

    // Calculate payment schedule
    final monthsPerPeriod = 12 ~/ paymentsPerYear;
    final totalMonths = maturityDate.difference(purchaseDate).inDays ~/ 30;
    final totalPeriods = (totalMonths / (monthsPerPeriod)).ceil();
    final principalPerPeriod = faceValue / totalPeriods;
    final interestRatePerPeriod = annualInterestRate / paymentsPerYear;

    double outstandingBalance = faceValue;
    DateTime currentDate = _addMonths(purchaseDate, monthsPerPeriod);

    for (int i = 0; i < totalPeriods; i++) {
      if (currentDate.isAfter(maturityDate)) break;

      final interestPayment = outstandingBalance * interestRatePerPeriod;
      final totalPayment = interestPayment + principalPerPeriod;

      flows.add(BondCashFlow(
        date: currentDate,
        amount: totalPayment,
        description:
            'Payment ${i + 1} - Interest: ${interestPayment.toStringAsFixed(2)}, Principal: ${principalPerPeriod.toStringAsFixed(2)}',
      ));

      outstandingBalance -= principalPerPeriod;
      currentDate = _addMonths(currentDate, monthsPerPeriod);
    }

    return flows;
  }
}
