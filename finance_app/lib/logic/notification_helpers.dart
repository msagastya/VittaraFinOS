import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vittara_fin_os/logic/bond_payout_generator.dart';
import 'package:vittara_fin_os/logic/budget_model.dart';
import 'package:vittara_fin_os/logic/investment_model.dart';
import 'package:vittara_fin_os/logic/recurring_template_model.dart';

// ── Notification channel IDs ──────────────────────────────────────────────────

const _budgetChannelId = 'budget_alerts';
const _budgetChannelName = 'Budget Alerts';
const _maturityChannelId = 'maturity_alerts';
const _maturityChannelName = 'Maturity Alerts';
const _recurringChannelId = 'recurring_bill_alerts';
const _recurringChannelName = 'Recurring Bill Reminders';

// Notification ID ranges:
//   sms_auto_scan uses 9000–9001+n
//   budget alerts:    7000–7499
//   maturity alerts:  7500–7999
//   recurring bills:  8000–8499

final _notifPlugin = FlutterLocalNotificationsPlugin();
bool _alertNotifInitialized = false;

/// Ensure the shared FlutterLocalNotificationsPlugin is initialized and the
/// alert notification channels exist. Safe to call multiple times.
Future<void> _ensureAlertNotifInitialized() async {
  if (_alertNotifInitialized) return;
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  await _notifPlugin.initialize(
    const InitializationSettings(android: androidSettings),
  );
  final android = _notifPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
  await android?.createNotificationChannel(const AndroidNotificationChannel(
    _budgetChannelId,
    _budgetChannelName,
    description: 'Alerts when a budget reaches 80% or 100% usage',
    importance: Importance.high,
  ));
  await android?.createNotificationChannel(const AndroidNotificationChannel(
    _maturityChannelId,
    _maturityChannelName,
    description: 'Alerts when an FD or RD is about to mature',
    importance: Importance.high,
  ));
  await android?.createNotificationChannel(const AndroidNotificationChannel(
    _recurringChannelId,
    _recurringChannelName,
    description: 'Reminders for upcoming recurring bills',
    importance: Importance.defaultImportance,
  ));
  _alertNotifInitialized = true;
}

// ── #27 Budget alerts ─────────────────────────────────────────────────────────

/// Check all active budgets and fire a local notification when a budget first
/// crosses the 80% (warning) or 100% (exceeded) threshold.
///
/// Uses SharedPreferences keys `notified_budget_[id]_80` and
/// `notified_budget_[id]_100` to prevent repeat notifications on every app
/// open.  The keys are cleared when the budget is reset / deleted.
Future<void> checkAndNotifyBudgetAlerts(List<Budget> budgets) async {
  await _ensureAlertNotifInitialized();
  final prefs = await SharedPreferences.getInstance();

  int _budgetWarningNotifId(String budgetId) {
    return 7000 + (budgetId.hashCode.abs() % 500);
  }

  int _budgetExceededNotifId(String budgetId) {
    // Use second half of range for exceeded so warning and exceeded can
    // coexist simultaneously for different budgets.
    return 7250 + (budgetId.hashCode.abs() % 250);
  }

  for (final budget in budgets) {
    if (!budget.isActive) continue;
    if (budget.limitAmount <= 0) continue;

    final ratio = budget.spentAmount / budget.limitAmount;

    // ── 80% warning ───────────────────────────────────────────────────────
    final warningKey = 'notified_budget_${budget.id}_80';
    final alreadyWarnedAt80 = prefs.getBool(warningKey) ?? false;

    if (ratio >= 0.80 && ratio < 1.0 && !alreadyWarnedAt80) {
      final pct = (ratio * 100).toStringAsFixed(0);
      await _notifPlugin.show(
        _budgetWarningNotifId(budget.id),
        'Budget Warning: ${budget.name}',
        '${budget.name} is $pct% used (₹${budget.spentAmount.toStringAsFixed(0)} / ₹${budget.limitAmount.toStringAsFixed(0)})',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _budgetChannelId,
            _budgetChannelName,
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );
      await prefs.setBool(warningKey, true);
    } else if (ratio < 0.80 && alreadyWarnedAt80) {
      // Budget was reset; clear the flag so it can warn again next time.
      await prefs.remove(warningKey);
    }

    // ── 100% exceeded ─────────────────────────────────────────────────────
    final exceededKey = 'notified_budget_${budget.id}_100';
    final alreadyNotifiedExceeded = prefs.getBool(exceededKey) ?? false;

    if (ratio >= 1.0 && !alreadyNotifiedExceeded) {
      await _notifPlugin.show(
        _budgetExceededNotifId(budget.id),
        'Budget Exceeded: ${budget.name}',
        '${budget.name} is over limit — ₹${budget.spentAmount.toStringAsFixed(0)} spent of ₹${budget.limitAmount.toStringAsFixed(0)}',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _budgetChannelId,
            _budgetChannelName,
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );
      await prefs.setBool(exceededKey, true);
    } else if (ratio < 1.0 && alreadyNotifiedExceeded) {
      // Budget was reduced / reset; allow future exceeded notification.
      await prefs.remove(exceededKey);
    }
  }
}

// ── #28a FD/RD maturity alerts ────────────────────────────────────────────────

/// Fire a local notification for each FD or RD whose maturity date falls
/// within [daysAhead] days from today.
///
/// Uses SharedPreferences key `notified_maturity_[id]` to avoid duplicates.
Future<void> checkAndNotifyMaturityAlerts(
  List<Investment> investments, {
  int daysAhead = 7,
}) async {
  await _ensureAlertNotifInitialized();
  final prefs = await SharedPreferences.getInstance();
  final today = DateTime.now();
  final dateFmt = DateFormat('d MMM yyyy');

  const maturityTypes = {
    InvestmentType.fixedDeposit,
    InvestmentType.recurringDeposit,
  };

  int _maturityNotifId(String investmentId) {
    return 7500 + (investmentId.hashCode.abs() % 500);
  }

  for (final inv in investments) {
    if (!maturityTypes.contains(inv.type)) continue;

    final metadata = inv.metadata ?? {};
    final maturityDateStr = metadata['maturityDate'] as String?;
    if (maturityDateStr == null) continue;

    final maturityDate = DateTime.tryParse(maturityDateStr);
    if (maturityDate == null) continue;

    final daysUntil = maturityDate.difference(today).inDays;
    if (daysUntil < 0 || daysUntil > daysAhead) continue;

    final notifKey = 'notified_maturity_${inv.id}';
    final alreadyNotified = prefs.getBool(notifKey) ?? false;
    if (alreadyNotified) continue;

    final typeLabel = inv.type == InvestmentType.fixedDeposit ? 'FD' : 'RD';
    final dueDateLabel = daysUntil == 0
        ? 'today'
        : daysUntil == 1
            ? 'tomorrow'
            : 'on ${dateFmt.format(maturityDate)}';

    await _notifPlugin.show(
      _maturityNotifId(inv.id),
      '$typeLabel Maturing Soon: ${inv.name}',
      '${inv.name} matures $dueDateLabel (${dateFmt.format(maturityDate)})',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _maturityChannelId,
          _maturityChannelName,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
    await prefs.setBool(notifKey, true);
  }
}

// ── #28b Recurring bill reminders ────────────────────────────────────────────

/// Fire a local notification for each recurring template whose next due date
/// is within [daysAhead] days.
///
/// Uses SharedPreferences key `notified_recurring_[id]_[dueDate]` to avoid
/// sending a reminder more than once per billing cycle.
Future<void> checkAndNotifyRecurringBillAlerts(
  List<RecurringTemplate> templates, {
  int daysAhead = 3,
}) async {
  await _ensureAlertNotifInitialized();
  final prefs = await SharedPreferences.getInstance();
  final today = DateTime.now();
  final dateFmt = DateFormat('d MMM');

  int _recurringNotifId(String templateId) {
    return 8000 + (templateId.hashCode.abs() % 500);
  }

  for (final tmpl in templates) {
    final nextDue = tmpl.nextDueDate;
    if (nextDue == null) continue;

    final daysUntil = nextDue.difference(today).inDays;
    if (daysUntil < 0 || daysUntil > daysAhead) continue;

    // Key includes the due date so notification resets each billing cycle.
    final dueDateKey = '${nextDue.year}_${nextDue.month}_${nextDue.day}';
    final notifKey = 'notified_recurring_${tmpl.id}_$dueDateKey';
    final alreadyNotified = prefs.getBool(notifKey) ?? false;
    if (alreadyNotified) continue;

    final dueDateLabel = daysUntil == 0
        ? 'today'
        : daysUntil == 1
            ? 'tomorrow'
            : 'on ${dateFmt.format(nextDue)}';
    final amountStr =
        '₹${tmpl.amount % 1 == 0 ? tmpl.amount.toStringAsFixed(0) : tmpl.amount.toStringAsFixed(2)}';

    await _notifPlugin.show(
      _recurringNotifId(tmpl.id),
      'Bill Due ${daysUntil == 0 ? 'Today' : daysUntil == 1 ? 'Tomorrow' : 'Soon'}: ${tmpl.name}',
      '${tmpl.name} ($amountStr) is due $dueDateLabel',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _recurringChannelId,
          _recurringChannelName,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
    );
    await prefs.setBool(notifKey, true);
  }
}

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
    if (daysUntil > daysAhead) continue;

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
