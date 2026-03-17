import 'package:vittara_fin_os/ui/manage/bonds/bonds_wizard_controller_v2.dart';

/// Represents a scheduled bond payout
class BondPayoutSchedule {
  final DateTime payoutDate;
  final int payoutNumber;

  BondPayoutSchedule({
    required this.payoutDate,
    required this.payoutNumber,
  });

  Map<String, dynamic> toMap() => {
        'payoutDate': payoutDate.toIso8601String(),
        'payoutNumber': payoutNumber,
      };

  factory BondPayoutSchedule.fromMap(Map<String, dynamic> map) =>
      BondPayoutSchedule(
        payoutDate: DateTime.parse(map['payoutDate']),
        payoutNumber: map['payoutNumber'] as int,
      );
}

/// Represents a bond payout record with user-entered data
class BondPayoutRecord {
  final int payoutNumber;
  final DateTime scheduledPayoutDate;
  final double payoutAmount;
  final DateTime actualPayoutDate;
  final String? creditAccountId;
  final String? creditAccountName;
  final DateTime recordedDate;

  BondPayoutRecord({
    required this.payoutNumber,
    required this.scheduledPayoutDate,
    required this.payoutAmount,
    required this.actualPayoutDate,
    this.creditAccountId,
    this.creditAccountName,
    required this.recordedDate,
  });

  Map<String, dynamic> toMap() => {
        'payoutNumber': payoutNumber,
        'scheduledPayoutDate': scheduledPayoutDate.toIso8601String(),
        'payoutAmount': payoutAmount,
        'actualPayoutDate': actualPayoutDate.toIso8601String(),
        'creditAccountId': creditAccountId,
        'creditAccountName': creditAccountName,
        'recordedDate': recordedDate.toIso8601String(),
      };

  factory BondPayoutRecord.fromMap(Map<String, dynamic> map) =>
      BondPayoutRecord(
        payoutNumber: map['payoutNumber'] as int,
        scheduledPayoutDate: DateTime.parse(map['scheduledPayoutDate']),
        payoutAmount: (map['payoutAmount'] as num).toDouble(),
        actualPayoutDate: DateTime.parse(map['actualPayoutDate']),
        creditAccountId: map['creditAccountId'] as String?,
        creditAccountName: map['creditAccountName'] as String?,
        recordedDate: DateTime.parse(map['recordedDate']),
      );
}

/// Generates bond payout schedules based on frequency and first payout date
class BondPayoutGenerator {
  /// Generate all payout dates from first payout to maturity
  static List<BondPayoutSchedule> generatePayoutSchedule({
    required PayoutFrequency frequency,
    required DateTime maturityDate,
    required int firstPayoutMonth, // 1-12
    required int firstPayoutDay, // 1-31
    DateTime? purchaseDate,
  }) {
    final payouts = <BondPayoutSchedule>[];

    if (frequency == PayoutFrequency.atMaturity) {
      // Single payout at maturity
      payouts.add(BondPayoutSchedule(
        payoutDate: maturityDate,
        payoutNumber: 1,
      ));
    } else {
      // Calculate months between payouts
      final monthsPerPeriod = _monthsPerPeriod(frequency);

      // Find the first payout date
      // Use current year to start, unless it's before today
      final int year = DateTime.now().year;
      DateTime firstPayout = DateTime(year, firstPayoutMonth, 1);

      // Adjust day to be valid for the month
      final lastDayOfMonth = _daysInMonth(firstPayout.year, firstPayout.month);
      final actualDay =
          firstPayoutDay > lastDayOfMonth ? lastDayOfMonth : firstPayoutDay;
      firstPayout = DateTime(year, firstPayoutMonth, actualDay);

      // If first payout is in the past, move to next cycle
      if (firstPayout.isBefore(DateTime.now())) {
        firstPayout = _addMonths(firstPayout, monthsPerPeriod);
      }

      // Generate all payouts until maturity
      DateTime currentPayout = firstPayout;
      int payoutNumber = 1;

      while (currentPayout.isBefore(maturityDate) ||
          currentPayout.isAtSameMomentAs(maturityDate)) {
        payouts.add(BondPayoutSchedule(
          payoutDate: currentPayout,
          payoutNumber: payoutNumber,
        ));

        currentPayout = _addMonths(currentPayout, monthsPerPeriod);
        payoutNumber++;
      }
    }

    return payouts;
  }

  /// Get payout notifications (2 days before actual payout date)
  static List<BondPayoutNotification> getUpcomingPayoutNotifications(
    List<BondPayoutSchedule> payouts,
  ) {
    final now = DateTime.now();
    final notifications = <BondPayoutNotification>[];

    for (final payout in payouts) {
      final notificationDate =
          payout.payoutDate.subtract(const Duration(days: 2));

      // Check if notification should be shown (within 10 days before payout)
      final daysUntil = payout.payoutDate.difference(now).inDays;

      if (daysUntil >= -7 && daysUntil <= 10) {
        // Show up to 7 days after for overdue
        notifications.add(BondPayoutNotification(
          payoutNumber: payout.payoutNumber,
          payoutDate: payout.payoutDate,
          notificationDate: notificationDate,
          daysUntil: daysUntil,
          isOverdue: daysUntil < 0,
        ));
      }
    }

    return notifications;
  }

  /// Helper: Add months while maintaining day of month
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

  /// Helper: Get months per period based on frequency
  static int _monthsPerPeriod(PayoutFrequency frequency) {
    switch (frequency) {
      case PayoutFrequency.monthly:
        return 1;
      case PayoutFrequency.quarterly:
        return 3;
      case PayoutFrequency.semiAnnual:
        return 6;
      case PayoutFrequency.annual:
        return 12;
      case PayoutFrequency.atMaturity:
        return 0; // Not used for at-maturity
    }
  }
}

/// Notification details for upcoming bond payout
class BondPayoutNotification {
  final int payoutNumber;
  final DateTime payoutDate;
  final DateTime notificationDate;
  final int daysUntil;
  final bool isOverdue;

  BondPayoutNotification({
    required this.payoutNumber,
    required this.payoutDate,
    required this.notificationDate,
    required this.daysUntil,
    required this.isOverdue,
  });
}
