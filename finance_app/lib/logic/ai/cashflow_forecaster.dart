import 'dart:math' as math;
import 'package:vittara_fin_os/logic/transaction_model.dart';
import 'pattern_detector.dart';

class CashflowPoint {
  final DateTime date;
  final double predictedBalance;
  final double lowerBound;
  final double upperBound;
  final String? triggerLabel; // e.g. "Salary expected", "EMI due"

  const CashflowPoint({
    required this.date,
    required this.predictedBalance,
    required this.lowerBound,
    required this.upperBound,
    this.triggerLabel,
  });
}

class CashflowWarning {
  final String accountId;
  final String accountName;
  final DateTime expectedDate;
  final double predictedBalance;
  final double threshold;
  final String message;

  const CashflowWarning({
    required this.accountId,
    required this.accountName,
    required this.expectedDate,
    required this.predictedBalance,
    required this.threshold,
    required this.message,
  });
}

class CashflowForecast {
  final List<CashflowPoint> points30; // 30-day daily points
  final List<CashflowPoint> points60; // 60-day weekly points
  final List<CashflowPoint> points90; // 90-day weekly points
  final List<CashflowWarning> warnings;
  final DateTime computedAt;

  const CashflowForecast({
    required this.points30,
    required this.points60,
    required this.points90,
    required this.warnings,
    required this.computedAt,
  });
}

class CashflowForecaster {
  CashflowForecaster._();

  static const double _lowBalanceThreshold = 5000.0; // ₹5,000 warning threshold

  static CashflowForecast forecast({
    required List<Transaction> transactions,
    required SpendingPatterns patterns,
    required Map<String, double> accountBalances,
  }) {
    final now = DateTime.now();
    final totalBalance = accountBalances.values.fold(0.0, (s, v) => s + v);

    // Compute average daily net cashflow over last 30 days
    final recentTxs = transactions.where((t) =>
        t.dateTime.isAfter(now.subtract(const Duration(days: 30)))).toList();

    final dailyNet = _computeDailyNetFlow(recentTxs);
    final avgDailyNet = dailyNet.isEmpty
        ? 0.0
        : dailyNet.values.fold(0.0, (s, v) => s + v) / dailyNet.length;
    final dailyStd = _stdDev(dailyNet.values.toList());

    // Build upcoming expected events (salary, recurring bills, etc.)
    final upcomingEvents = _buildUpcomingEvents(patterns, now);

    // Generate forecast points
    final points30 = <CashflowPoint>[];
    final points60 = <CashflowPoint>[];
    final points90 = <CashflowPoint>[];
    final warnings = <CashflowWarning>[];

    double balance = totalBalance;

    for (int day = 1; day <= 90; day++) {
      final date = now.add(Duration(days: day));

      // Apply average daily drift
      balance += avgDailyNet;

      // Apply any expected events on this date
      String? trigger;
      for (final event in upcomingEvents) {
        if (_sameDay(event.date, date)) {
          balance += event.amount;
          trigger = event.label;
        }
      }

      final lower = balance - dailyStd * 1.5;
      final upper = balance + dailyStd * 1.5;

      final point = CashflowPoint(
        date: date,
        predictedBalance: balance,
        lowerBound: lower,
        upperBound: upper,
        triggerLabel: trigger,
      );

      if (day <= 30) points30.add(point);
      if (day <= 60 && day % 7 == 0) points60.add(point);
      if (day % 7 == 0) points90.add(point);

      // Warn if balance could drop below threshold in next 14 days
      if (day <= 14 && lower < _lowBalanceThreshold && balance > 0) {
        warnings.add(CashflowWarning(
          accountId: '',
          accountName: 'Total balance',
          expectedDate: date,
          predictedBalance: balance,
          threshold: _lowBalanceThreshold,
          message: 'Balance may drop near ₹${_lowBalanceThreshold.toInt()} '
              'around ${_formatDate(date)}',
        ));
        break; // one warning is enough
      }
    }

    return CashflowForecast(
      points30: points30,
      points60: points60,
      points90: points90,
      warnings: warnings,
      computedAt: now,
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static Map<String, double> _computeDailyNetFlow(
      List<Transaction> transactions) {
    final Map<String, double> byDay = {};
    for (final tx in transactions) {
      final key =
          '${tx.dateTime.year}-${tx.dateTime.month}-${tx.dateTime.day}';
      final delta = _txNetDelta(tx);
      byDay[key] = (byDay[key] ?? 0) + delta;
    }
    return byDay;
  }

  static double _txNetDelta(Transaction tx) {
    switch (tx.type) {
      case TransactionType.income:
        return tx.amount;
      case TransactionType.expense:
        return -tx.amount;
      default:
        return 0;
    }
  }

  static List<_ExpectedEvent> _buildUpcomingEvents(
      SpendingPatterns patterns, DateTime now) {
    final events = <_ExpectedEvent>[];

    // Salary
    if (patterns.salary != null) {
      final salary = patterns.salary!;
      // Next salary date
      for (int month = 0; month <= 3; month++) {
        final candidate = DateTime(
          now.year,
          now.month + month,
          salary.typicalDayOfMonth.clamp(1, 28),
        );
        if (candidate.isAfter(now)) {
          events.add(_ExpectedEvent(
            date: candidate,
            amount: salary.typicalAmount,
            label: 'Salary expected',
          ));
        }
      }
    }

    // Recurring expenses (bills, EMIs, subscriptions)
    for (final rec in patterns.recurring) {
      if (rec.type != TransactionType.expense) continue;
      if (rec.confidence < 0.5) continue;

      // Next occurrence based on interval
      var nextDate = rec.lastSeen.add(Duration(days: rec.intervalDays));
      int safety = 0;
      while (nextDate.isBefore(now) && safety < 12) {
        nextDate = nextDate.add(Duration(days: rec.intervalDays));
        safety++;
      }

      if (nextDate.isAfter(now) &&
          nextDate.isBefore(now.add(const Duration(days: 90)))) {
        events.add(_ExpectedEvent(
          date: nextDate,
          amount: -rec.typicalAmount,
          label: '${rec.merchantNormalized} due',
        ));
      }
    }

    return events;
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${d.day} ${months[d.month - 1]}';
  }

  static double _stdDev(List<double> values) {
    if (values.length < 2) return 0;
    final mean = values.reduce((a, b) => a + b) / values.length;
    final variance = values
            .map((v) => math.pow(v - mean, 2).toDouble())
            .reduce((a, b) => a + b) /
        values.length;
    return math.sqrt(variance);
  }
}

class _ExpectedEvent {
  final DateTime date;
  final double amount;
  final String label;
  const _ExpectedEvent({
    required this.date,
    required this.amount,
    required this.label,
  });
}
