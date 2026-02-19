import 'package:vittara_fin_os/logic/bond_payout_generator.dart';
import 'package:vittara_fin_os/logic/investment_model.dart';

class SipNotificationInfo {
  final Investment investment;
  final DateTime dueDate;
  final int daysUntil;
  final double amount;
  final String frequencyLabel;

  SipNotificationInfo({
    required this.investment,
    required this.dueDate,
    required this.daysUntil,
    required this.amount,
    required this.frequencyLabel,
  });
}

class BondPayoutNotificationInfo {
  final Investment investment;
  final BondPayoutSchedule schedule;
  final int daysUntil;

  BondPayoutNotificationInfo({
    required this.investment,
    required this.schedule,
    required this.daysUntil,
  });
}

/// Collect SIP notifications for investments that have an active SIP coming due within [daysAhead] days.
List<SipNotificationInfo> collectSipNotifications(List<Investment> investments,
    {int daysAhead = 5}) {
  final now = DateTime.now();
  final notifications = <SipNotificationInfo>[];

  for (final inv in investments) {
    final metadata = inv.metadata ?? {};
    if (metadata['sipActive'] != true) continue;

    final nextDue = _nextSipDueDate(inv);
    if (nextDue == null) continue;

    final daysUntil = nextDue.difference(now).inDays;
    if (daysUntil < 0 || daysUntil > daysAhead) continue;

    notifications.add(SipNotificationInfo(
      investment: inv,
      dueDate: nextDue,
      daysUntil: daysUntil,
      amount: _sipAmount(inv),
      frequencyLabel: _sipFrequencyLabel(inv),
    ));
  }

  return notifications;
}

/// Collect bond payouts that are due within [daysAhead] days and have not been recorded or skipped.
List<BondPayoutNotificationInfo> collectBondPayoutNotifications(
    List<Investment> investments,
    {int daysAhead = 5}) {
  final now = DateTime.now();
  final notifications = <BondPayoutNotificationInfo>[];

  for (final bond
      in investments.where((inv) => inv.type == InvestmentType.bonds)) {
    final metadata = bond.metadata ?? {};
    final scheduleList =
        (metadata['payoutSchedule'] as List?)?.cast<Map<String, dynamic>>();
    if (scheduleList == null) continue;

    final skipped = <int>{
      ...?((metadata['skippedPayouts'] as List?)?.map((e) => e as int)),
    };
    final recorded = <int>{
      ...?((metadata['pastPayouts'] as List?)
          ?.map<int?>((entry) =>
              (entry as Map<String, dynamic>)['payoutNumber'] as int?)
          .whereType<int>()),
    };

    for (final scheduleMap in scheduleList) {
      final schedule = BondPayoutSchedule.fromMap(scheduleMap);
      final payoutNumber = schedule.payoutNumber;
      if (skipped.contains(payoutNumber) || recorded.contains(payoutNumber)) {
        continue;
      }

      final daysUntil = schedule.payoutDate.difference(now).inDays;
      if (daysUntil >= 0 && daysUntil <= daysAhead) {
        notifications.add(BondPayoutNotificationInfo(
          investment: bond,
          schedule: schedule,
          daysUntil: daysUntil,
        ));
      }
    }
  }

  return notifications;
}

DateTime? _nextSipDueDate(Investment investment) {
  final metadata = investment.metadata ?? {};
  if (investment.type == InvestmentType.stocks) {
    return _nextSipDateFromStock(metadata);
  }
  return _nextSipDateFromMF(metadata);
}

DateTime? _nextSipDateFromStock(Map<String, dynamic> metadata) {
  final frequency =
      (metadata['sipFrequency'] as String?)?.toLowerCase() ?? 'monthly';
  final lastExecution = metadata['sipLastExecutionDate'] as String?;
  final startDate = metadata['sipStartDate'] as String?;
  DateTime base;
  if (lastExecution != null) {
    base = DateTime.tryParse(lastExecution) ?? DateTime.now();
  } else if (startDate != null) {
    base = DateTime.tryParse(startDate) ?? DateTime.now();
  } else {
    base = DateTime.now();
  }
  return _addFrequency(base, frequency, isStock: true);
}

DateTime? _nextSipDateFromMF(Map<String, dynamic> metadata) {
  final sipData = metadata['sipData'] as Map<String, dynamic>?;
  if (sipData == null) return null;
  final frequency = (sipData['frequency'] as String?) ?? 'monthly';
  final lastExecution = metadata['sipLastExecutionDate'] as String?;
  DateTime base = lastExecution != null
      ? (DateTime.tryParse(lastExecution) ?? DateTime.now())
      : DateTime.now();
  final monthDay = sipData['monthDay'] as int?;
  final weekday = sipData['weekday'] as int?;
  return _addFrequency(base, frequency, monthDay: monthDay, weekday: weekday);
}

DateTime _addFrequency(DateTime base, String frequency,
    {bool isStock = false, int? monthDay, int? weekday}) {
  final lower = frequency.toLowerCase();
  final trimmedBase = DateTime(base.year, base.month, base.day);

  switch (lower) {
    case 'daily':
      return trimmedBase.add(const Duration(days: 1));
    case 'weekly':
      return _nextWeeklyDate(trimmedBase, weekday);
    case 'monthly':
      return _nextMonthlyDate(trimmedBase, monthDay);
    case 'quarterly':
      return _nextMonthlyDate(trimmedBase, monthDay, monthsToAdd: 3);
    case 'yearly':
    case 'annual':
      return _nextMonthlyDate(trimmedBase, monthDay, monthsToAdd: 12);
    case 'monthlyauto':
    case 'dailyauto':
      return trimmedBase.add(const Duration(days: 1));
    default:
      if (isStock) {
        return _nextMonthlyDate(trimmedBase, monthDay);
      }
      return trimmedBase.add(const Duration(days: 30));
  }
}

DateTime _nextMonthlyDate(DateTime base, int? day, {int monthsToAdd = 1}) {
  final targetDay = day != null && day >= 1 && day <= 28
      ? day
      : (day != null && day > 28 ? day : base.day);
  final candidate = DateTime(base.year, base.month, targetDay);
  var next =
      candidate.isAfter(base) ? candidate : _addMonths(candidate, monthsToAdd);
  while (!next.isAfter(base)) {
    next = _addMonths(next, monthsToAdd);
  }
  return next;
}

DateTime _nextWeeklyDate(DateTime base, int? weekday) {
  final targetWeekday = (weekday ?? base.weekday - 1) + 1;
  final offset = (targetWeekday - base.weekday + 7) % 7;
  final daysToAdd = offset == 0 ? 7 : offset;
  return base.add(Duration(days: daysToAdd));
}

DateTime _addMonths(DateTime date, int months) {
  var newMonth = date.month + months;
  var newYear = date.year + (newMonth - 1) ~/ 12;
  newMonth = ((newMonth - 1) % 12) + 1;
  final day = date.day;
  final lastDayOfMonth = _daysInMonth(newYear, newMonth);
  final targetDay = day > lastDayOfMonth ? lastDayOfMonth : day;
  return DateTime(newYear, newMonth, targetDay);
}

int _daysInMonth(int year, int month) {
  if (month == 2) {
    return (year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)) ? 29 : 28;
  }
  const monthDays = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
  return monthDays[month - 1];
}

Map<String, dynamic> markSipAsExecuted(
  Map<String, dynamic> metadata,
  DateTime executionDate, {
  String action = 'skip',
}) {
  final updatedMetadata = Map<String, dynamic>.from(metadata);
  final log = <Map<String, dynamic>>[
    ...?((updatedMetadata['sipExecutionLog'] as List?)
        ?.cast<Map<String, dynamic>>()),
  ];
  log.add({
    'action': action,
    'date': DateTime.now().toIso8601String(),
    'effectiveDate': executionDate.toIso8601String(),
  });
  updatedMetadata['sipExecutionLog'] = log;
  updatedMetadata['sipLastExecutionDate'] = executionDate.toIso8601String();
  updatedMetadata['sipStartDate'] =
      updatedMetadata['sipStartDate'] ?? executionDate.toIso8601String();
  return updatedMetadata;
}

String _sipFrequencyLabel(Investment investment) {
  final metadata = investment.metadata ?? {};
  final labelSource = metadata['sipFrequency'] as String? ??
      (metadata['sipData'] as Map<String, dynamic>?)?['frequency'] as String? ??
      'sip';
  final normalized = labelSource.isEmpty
      ? 'SIP'
      : labelSource[0].toUpperCase() + labelSource.substring(1);
  return '$normalized SIP';
}

double _sipAmount(Investment investment) {
  final metadata = investment.metadata ?? {};
  if (investment.type == InvestmentType.stocks) {
    final amount = (metadata['sipAmount'] as num?)?.toDouble();
    if (amount != null && amount > 0) return amount;
    final qty = (metadata['sipQty'] as num?)?.toDouble();
    final price = (metadata['pricePerShare'] as num?)?.toDouble();
    if (qty != null && price != null) return qty * price;
    return 0;
  }
  final sipData = metadata['sipData'] as Map<String, dynamic>?;
  final amount = (sipData?['sipAmount'] as num?)?.toDouble();
  return amount ?? 0;
}
