import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/budget_model.dart';
import 'package:vittara_fin_os/logic/budgets_controller.dart';
import 'package:vittara_fin_os/logic/fixed_deposit_model.dart';
import 'package:vittara_fin_os/logic/goal_model.dart';
import 'package:vittara_fin_os/logic/goals_controller.dart';
import 'package:vittara_fin_os/logic/insurance_controller.dart';
import 'package:vittara_fin_os/logic/insurance_model.dart';
import 'package:vittara_fin_os/logic/investment_model.dart';
import 'package:vittara_fin_os/logic/investments_controller.dart';
import 'package:vittara_fin_os/logic/loan_controller.dart';
import 'package:vittara_fin_os/logic/loan_model.dart';
import 'package:vittara_fin_os/logic/recurring_deposit_model.dart';
import 'package:vittara_fin_os/logic/recurring_template_model.dart';
import 'package:vittara_fin_os/logic/recurring_templates_controller.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/widgets/animations.dart';
import 'package:vittara_fin_os/ui/widgets/common_widgets.dart';
import 'package:vittara_fin_os/utils/date_formatter.dart';

// ─── Event type ───────────────────────────────────────────────────────────────

enum CalendarEventType {
  fd,
  rd,
  rdPayment,
  sip,
  bill,
  goal,
  budgetReset,
  insurance,
  loanEmi,
}

extension CalendarEventTypeX on CalendarEventType {
  String get label {
    switch (this) {
      case CalendarEventType.fd:
        return 'FD';
      case CalendarEventType.rd:
        return 'RD';
      case CalendarEventType.rdPayment:
        return 'RD Pay';
      case CalendarEventType.sip:
        return 'SIP';
      case CalendarEventType.bill:
        return 'Bill';
      case CalendarEventType.goal:
        return 'Goal';
      case CalendarEventType.budgetReset:
        return 'Budget';
      case CalendarEventType.insurance:
        return 'Insurance';
      case CalendarEventType.loanEmi:
        return 'Loan EMI';
    }
  }

  String get filterLabel {
    switch (this) {
      case CalendarEventType.rdPayment:
        return 'RD Pay';
      case CalendarEventType.budgetReset:
        return 'Budget';
      case CalendarEventType.loanEmi:
        return 'EMI';
      default:
        return label;
    }
  }

  Color colorFor(bool isDark) {
    switch (this) {
      case CalendarEventType.fd:
        return isDark ? AppStyles.solarGold : const Color(0xFF9A6800);
      case CalendarEventType.rd:
        return AppStyles.accentOrange;
      case CalendarEventType.rdPayment:
        return const Color(0xFFFF8C42);
      case CalendarEventType.sip:
        return isDark ? AppStyles.aetherTeal : const Color(0xFF007A6E);
      case CalendarEventType.bill:
        return isDark ? AppStyles.plasmaRed : const Color(0xFFCC1A35);
      case CalendarEventType.goal:
        return isDark ? AppStyles.novaPurple : const Color(0xFF5B3FCC);
      case CalendarEventType.budgetReset:
        return isDark ? AppStyles.bioGreen : const Color(0xFF00875A);
      case CalendarEventType.insurance:
        return AppStyles.accentBlue;
      case CalendarEventType.loanEmi:
        return const Color(0xFFFF6D00);
    }
  }

  // Keep for compatibility when isDark context is not available
  Color get color => colorFor(true);

  IconData get icon {
    switch (this) {
      case CalendarEventType.fd:
        return CupertinoIcons.lock_fill;
      case CalendarEventType.rd:
        return CupertinoIcons.arrow_2_circlepath;
      case CalendarEventType.rdPayment:
        return CupertinoIcons.arrow_up_circle_fill;
      case CalendarEventType.sip:
        return CupertinoIcons.graph_circle_fill;
      case CalendarEventType.bill:
        return CupertinoIcons.doc_text_fill;
      case CalendarEventType.goal:
        return CupertinoIcons.flag_fill;
      case CalendarEventType.budgetReset:
        return CupertinoIcons.chart_bar_fill;
      case CalendarEventType.insurance:
        return CupertinoIcons.shield_fill;
      case CalendarEventType.loanEmi:
        return CupertinoIcons.creditcard_fill;
    }
  }
}

// ─── Event model ──────────────────────────────────────────────────────────────

class CalendarEvent {
  final String id;
  final String title;
  final String subtitle;
  final DateTime date;
  final CalendarEventType type;
  final double? amount;

  const CalendarEvent({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.date,
    required this.type,
    this.amount,
  });
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class FinancialCalendarScreen extends StatefulWidget {
  const FinancialCalendarScreen({super.key});

  @override
  State<FinancialCalendarScreen> createState() =>
      _FinancialCalendarScreenState();
}

class _FinancialCalendarScreenState extends State<FinancialCalendarScreen> {
  late DateTime _focusedMonth;
  DateTime? _selectedDay;
  CalendarEventType? _filterType; // null = show all

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedMonth = DateTime(now.year, now.month, 1);
    _selectedDay = DateTime(now.year, now.month, now.day);
  }

  void _prevMonth() {
    HapticFeedback.selectionClick();
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1, 1);
      _selectedDay = null;
    });
  }

  void _nextMonth() {
    HapticFeedback.selectionClick();
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 1);
      _selectedDay = null;
    });
  }

  void _selectDay(DateTime day) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedDay != null &&
          _selectedDay!.year == day.year &&
          _selectedDay!.month == day.month &&
          _selectedDay!.day == day.day) {
        _selectedDay = null; // tap again to deselect
      } else {
        _selectedDay = day;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppStyles.isDarkMode(context);

    // Watch all controllers for live updates
    final invCtrl = context.watch<InvestmentsController>();
    final tmplCtrl = context.watch<RecurringTemplatesController>();
    final goalsCtrl = context.watch<GoalsController>();
    final budgetsCtrl = context.watch<BudgetsController>();
    final insuranceCtrl = context.watch<InsuranceController>();
    final loanCtrl = context.watch<LoanController>();

    final allEvents = _buildAllEvents(
      investments: invCtrl.investments,
      templates: tmplCtrl.templates,
      goals: goalsCtrl.activeGoals,
      budgets: budgetsCtrl.activeBudgets,
      policies: insuranceCtrl.activePolicies,
      loans: loanCtrl.activeLoans,
    );

    // Group events by date key (yyyy-MM-dd)
    final eventsMap = <String, List<CalendarEvent>>{};
    for (final e in allEvents) {
      final k = _dateKey(e.date);
      eventsMap.putIfAbsent(k, () => []).add(e);
    }

    // Events to display below calendar
    final List<CalendarEvent> displayEvents;
    if (_selectedDay != null) {
      final key = _dateKey(_selectedDay!);
      displayEvents = (eventsMap[key] ?? []);
    } else {
      // All events in the focused month
      displayEvents = allEvents.where((e) {
        return e.date.year == _focusedMonth.year &&
            e.date.month == _focusedMonth.month;
      }).toList()
        ..sort((a, b) => a.date.compareTo(b.date));
    }

    // Apply type filter
    final filteredEvents = _filterType == null
        ? displayEvents
        : displayEvents.where((e) => e.type == _filterType).toList();

    return CupertinoPageScaffold(
      backgroundColor: AppStyles.getBackground(context),
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          'Financial Calendar',
          style: TextStyle(color: AppStyles.getTextColor(context)),
        ),
        previousPageTitle: 'Back',
        backgroundColor:
            isDark ? Colors.black : Colors.white.withValues(alpha: 0.95),
        border: null,
      ),
      child: SafeArea(
        child: Column(
          children: [
            // ── Calendar card ──────────────────────────────────────────────
            Container(
              margin: const EdgeInsets.fromLTRB(
                  Spacing.lg, Spacing.md, Spacing.lg, 0),
              decoration: BoxDecoration(
                color: AppStyles.getCardColor(context),
                borderRadius: BorderRadius.circular(Radii.xxl),
                border: Border.all(
                  color: AppStyles.getDividerColor(context),
                  width: 0.8,
                ),
                boxShadow:
                    isDark ? Shadows.cardDark : Shadows.cardLight,
              ),
              child: Column(
                children: [
                  _buildMonthHeader(context),
                  _buildWeekdayRow(context),
                  _buildCalendarGrid(context, eventsMap),
                  const SizedBox(height: Spacing.sm),
                ],
              ),
            ),

            const SizedBox(height: Spacing.md),

            // ── Filter chips ───────────────────────────────────────────────
            _buildFilterRow(context, allEvents),

            const SizedBox(height: Spacing.sm),

            // ── Event section ──────────────────────────────────────────────
            Expanded(
              child: _buildEventSection(
                  context, filteredEvents, isDark),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Month header ────────────────────────────────────────────────────────

  Widget _buildMonthHeader(BuildContext context) {
    final monthName = DateFormatter.getMonthName(_focusedMonth.month,
        short: false);
    final year = _focusedMonth.year;
    final now = DateTime.now();
    final isCurrentMonth =
        _focusedMonth.year == now.year && _focusedMonth.month == now.month;

    return Padding(
      padding:
          const EdgeInsets.fromLTRB(Spacing.lg, Spacing.md, Spacing.md, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$monthName $year',
                  style: TextStyle(
                    fontFamily: 'SpaceGrotesk',
                    fontSize: TypeScale.title3,
                    fontWeight: FontWeight.w800,
                    color: AppStyles.getTextColor(context),
                    letterSpacing: -0.5,
                  ),
                ),
                if (isCurrentMonth)
                  Text(
                    'This Month',
                    style: TextStyle(
                      fontSize: TypeScale.caption,
                      color: AppStyles.teal(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          // Today button
          if (!isCurrentMonth)
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () {
                HapticFeedback.selectionClick();
                final now = DateTime.now();
                setState(() {
                  _focusedMonth = DateTime(now.year, now.month, 1);
                  _selectedDay =
                      DateTime(now.year, now.month, now.day);
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: Spacing.sm, vertical: 4),
                decoration: BoxDecoration(
                  color: AppStyles.teal(context).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(Radii.full),
                  border: Border.all(
                    color: AppStyles.teal(context).withValues(alpha: 0.3),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  'Today',
                  style: TextStyle(
                    fontSize: TypeScale.caption,
                    fontWeight: FontWeight.w700,
                    color: AppStyles.teal(context),
                  ),
                ),
              ),
            ),
          // Prev
          CupertinoButton(
            padding: const EdgeInsets.all(8),
            onPressed: _prevMonth,
            child: Icon(
              CupertinoIcons.chevron_left,
              size: 18,
              color: AppStyles.getPrimaryColor(context),
            ),
          ),
          // Next
          CupertinoButton(
            padding: const EdgeInsets.all(8),
            onPressed: _nextMonth,
            child: Icon(
              CupertinoIcons.chevron_right,
              size: 18,
              color: AppStyles.getPrimaryColor(context),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Weekday labels ──────────────────────────────────────────────────────

  Widget _buildWeekdayRow(BuildContext context) {
    const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    const sunColor = Color(0xFFFF3B30);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          Spacing.md, Spacing.sm, Spacing.md, Spacing.xs),
      child: Row(
        children: days.asMap().entries.map((entry) {
          final isSun = entry.key == 6;
          return Expanded(
            child: Center(
              child: Text(
                entry.value,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isSun
                      ? sunColor.withValues(alpha: 0.7)
                      : AppStyles.getSecondaryTextColor(context),
                  letterSpacing: 0.3,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── Calendar grid ───────────────────────────────────────────────────────

  Widget _buildCalendarGrid(
      BuildContext context, Map<String, List<CalendarEvent>> eventsMap) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Days in month
    final daysInMonth =
        DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0).day;

    // Leading offset: Monday=0, ..., Sunday=6
    // DateTime weekday: 1=Mon, 7=Sun
    final firstWeekday = _focusedMonth.weekday; // 1..7
    final leadingBlanks = firstWeekday - 1; // 0..6

    // Total cells = blanks + days, rounded up to multiple of 7
    final totalCells =
        (leadingBlanks + daysInMonth + 6) ~/ 7 * 7;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7,
          mainAxisSpacing: 4,
          crossAxisSpacing: 0,
          childAspectRatio: 0.78,
        ),
        itemCount: totalCells,
        itemBuilder: (ctx, index) {
          if (index < leadingBlanks ||
              index >= leadingBlanks + daysInMonth) {
            return const SizedBox.shrink();
          }
          final day = index - leadingBlanks + 1;
          final date =
              DateTime(_focusedMonth.year, _focusedMonth.month, day);
          final key = _dateKey(date);
          final dayEvents = eventsMap[key] ?? [];

          final isToday = date == today;
          final isSelected = _selectedDay != null &&
              _selectedDay!.year == date.year &&
              _selectedDay!.month == date.month &&
              _selectedDay!.day == date.day;
          final isSunday = date.weekday == 7;

          return _DayCell(
            day: day,
            events: dayEvents,
            isToday: isToday,
            isSelected: isSelected,
            isSunday: isSunday,
            onTap: () => _selectDay(date),
          );
        },
      ),
    );
  }

  // ─── Filter row ──────────────────────────────────────────────────────────

  Widget _buildFilterRow(
      BuildContext context, List<CalendarEvent> allEvents) {
    // Only show types that have events
    final presentTypes = allEvents.map((e) => e.type).toSet().toList()
      ..sort((a, b) => a.index.compareTo(b.index));

    if (presentTypes.length < 2) return const SizedBox.shrink();

    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding:
            const EdgeInsets.symmetric(horizontal: Spacing.lg),
        children: [
          // "All" chip
          _FilterChip(
            label: 'All',
            color: AppStyles.teal(context),
            isSelected: _filterType == null,
            onTap: () => setState(() => _filterType = null),
          ),
          ...presentTypes.map((type) => Padding(
                padding: const EdgeInsets.only(left: Spacing.sm),
                child: _FilterChip(
                  label: type.filterLabel,
                  color: type.colorFor(AppStyles.isDarkMode(context)),
                  isSelected: _filterType == type,
                  onTap: () => setState(() {
                    _filterType =
                        _filterType == type ? null : type;
                  }),
                ),
              )),
        ],
      ),
    );
  }

  // ─── Event section ───────────────────────────────────────────────────────

  Widget _buildEventSection(
    BuildContext context,
    List<CalendarEvent> events,
    bool isDark,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    String sectionTitle;
    if (_selectedDay != null) {
      final d = _selectedDay!;
      if (d == today) {
        sectionTitle = "Today's Events";
      } else {
        sectionTitle =
            '${d.day} ${DateFormatter.getMonthName(d.month, short: true)}';
      }
    } else {
      sectionTitle =
          '${DateFormatter.getMonthName(_focusedMonth.month, short: false)} Overview';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              Spacing.lg, 0, Spacing.lg, Spacing.sm),
          child: Row(
            children: [
              Text(
                sectionTitle,
                style: TextStyle(
                  fontSize: TypeScale.headline,
                  fontWeight: FontWeight.w700,
                  color: AppStyles.getTextColor(context),
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(width: Spacing.sm),
              if (events.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: Spacing.sm, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppStyles.teal(context).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(Radii.full),
                  ),
                  child: Text(
                    '${events.length}',
                    style: TextStyle(
                      fontSize: TypeScale.caption,
                      fontWeight: FontWeight.w700,
                      color: AppStyles.teal(context),
                    ),
                  ),
                ),
              if (_selectedDay != null) ...[
                const Spacer(),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () =>
                      setState(() => _selectedDay = null),
                  child: Text(
                    'Show month',
                    style: TextStyle(
                      fontSize: TypeScale.caption,
                      color: AppStyles.getPrimaryColor(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: events.isEmpty
              ? _buildEmptyEvents(context)
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                    Spacing.lg,
                    0,
                    Spacing.lg,
                    Spacing.massive,
                  ),
                  itemCount: events.length,
                  itemBuilder: (ctx, i) =>
                      _EventTile(event: events[i]),
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyEvents(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            CupertinoIcons.calendar,
            size: 48,
            color: AppStyles.getSecondaryTextColor(context)
                .withValues(alpha: 0.3),
          ),
          const SizedBox(height: Spacing.md),
          Text(
            _selectedDay != null
                ? 'No events on this day'
                : 'No events this month',
            style: TextStyle(
              fontSize: TypeScale.body,
              color: AppStyles.getSecondaryTextColor(context),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Date key helper ─────────────────────────────────────────────────────

  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // ─── Event builder ───────────────────────────────────────────────────────

  List<CalendarEvent> _buildAllEvents({
    required List<Investment> investments,
    required List<RecurringTemplate> templates,
    required List<Goal> goals,
    required List<Budget> budgets,
    required List<InsurancePolicy> policies,
    required List<Loan> loans,
  }) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // Show 18 months ahead
    final cutoff = DateTime(now.year + 1, now.month + 6, now.day);
    final events = <CalendarEvent>[];

    // ── FD maturity ─────────────────────────────────────────────────────────
    for (final inv in investments) {
      if (inv.type != InvestmentType.fixedDeposit) continue;
      final meta = inv.metadata;
      if (meta == null) continue;
      try {
        if (meta.containsKey('fdData')) {
          final fd = FixedDeposit.fromMap(
              Map<String, dynamic>.from(meta['fdData'] as Map));
          if (fd.status == FDStatus.prematurelyWithdrawn) continue;
          final d = fd.maturityDate;
          if (!d.isBefore(today) && d.isBefore(cutoff)) {
            events.add(CalendarEvent(
              id: 'fd_${inv.id}',
              title: fd.name,
              subtitle: fd.bankName?.isNotEmpty == true
                  ? 'FD Maturity · ${fd.bankName}'
                  : 'FD Maturity',
              date: d,
              type: CalendarEventType.fd,
              amount: fd.maturityValue,
            ));
          }
        } else if (meta.containsKey('maturityDate')) {
          final d = DateTime.tryParse(
              (meta['maturityDate'] as String?) ?? '');
          if (d != null && !d.isBefore(today) && d.isBefore(cutoff)) {
            events.add(CalendarEvent(
              id: 'fd_${inv.id}',
              title: inv.name,
              subtitle: 'FD Maturity',
              date: d,
              type: CalendarEventType.fd,
              amount:
                  (meta['estimatedAccruedValue'] as num?)?.toDouble() ??
                      inv.amount,
            ));
          }
        }
      } catch (_) {}
    }

    // ── RD maturity + installment payments ──────────────────────────────────
    for (final inv in investments) {
      if (inv.type != InvestmentType.recurringDeposit) continue;
      final meta = inv.metadata;
      if (meta == null) continue;
      try {
        if (meta.containsKey('rdData')) {
          final rd = RecurringDeposit.fromMap(
              Map<String, dynamic>.from(meta['rdData'] as Map));

          // Maturity
          final mat = rd.maturityDate;
          if (!mat.isBefore(today) && mat.isBefore(cutoff)) {
            events.add(CalendarEvent(
              id: 'rd_${inv.id}',
              title: rd.name,
              subtitle: rd.bankName?.isNotEmpty == true
                  ? 'RD Maturity · ${rd.bankName}'
                  : 'RD Maturity',
              date: mat,
              type: CalendarEventType.rd,
              amount: rd.maturityValue,
            ));
          }

          // Upcoming installment payments
          for (final inst in rd.installments) {
            if (inst.isPaid) continue;
            final d = DateTime(inst.dueDate.year, inst.dueDate.month,
                inst.dueDate.day);
            if (!d.isBefore(today) && d.isBefore(cutoff)) {
              events.add(CalendarEvent(
                id: 'rdpay_${inv.id}_${inst.id}',
                title: rd.name,
                subtitle:
                    'RD Payment #${inst.installmentNumber} · ${rd.bankName ?? ''}',
                date: d,
                type: CalendarEventType.rdPayment,
                amount: inst.amount,
              ));
            }
          }
        } else if (meta.containsKey('maturityDate')) {
          final d = DateTime.tryParse(
              (meta['maturityDate'] as String?) ?? '');
          if (d != null && !d.isBefore(today) && d.isBefore(cutoff)) {
            events.add(CalendarEvent(
              id: 'rd_${inv.id}',
              title: inv.name,
              subtitle: 'RD Maturity',
              date: d,
              type: CalendarEventType.rd,
              amount: inv.amount,
            ));
          }
        }
      } catch (_) {}
    }

    // ── SIP due dates ────────────────────────────────────────────────────────
    for (final inv in investments) {
      final meta = inv.metadata ?? {};
      if (meta['sipActive'] != true) continue;

      final DateTime? baseDue = _nextSipDate(meta);
      if (baseDue == null) continue;

      final freqStr =
          ((meta['sipFrequency'] as String?) ?? 'monthly').toLowerCase();
      final freqLabel = _freqLabel(freqStr);

      var current = baseDue;
      int count = 0;
      while (!current.isAfter(cutoff) && count < 24) {
        if (!current.isBefore(today)) {
          events.add(CalendarEvent(
            id: 'sip_${inv.id}_${current.toIso8601String()}',
            title: inv.name,
            subtitle: 'SIP Due · $freqLabel',
            date: current,
            type: CalendarEventType.sip,
            amount: _sipAmount(meta),
          ));
        }
        current = _advanceFreq(current, freqStr);
        count++;
      }
    }

    // ── Bill reminders ───────────────────────────────────────────────────────
    for (final tmpl in templates) {
      if (tmpl.nextDueDate == null) continue;
      var current = tmpl.nextDueDate!;
      int count = 0;
      while (!current.isAfter(cutoff) && count < 24) {
        if (!current.isBefore(today)) {
          events.add(CalendarEvent(
            id: 'bill_${tmpl.id}_${current.toIso8601String()}',
            title: tmpl.name,
            subtitle: tmpl.categoryName?.isNotEmpty == true
                ? 'Bill Due · ${tmpl.categoryName}'
                : 'Bill Due',
            date: current,
            type: CalendarEventType.bill,
            amount: tmpl.amount,
          ));
        }
        current = _advanceFreq(current, tmpl.frequency);
        count++;
      }
    }

    // ── Goal deadlines ───────────────────────────────────────────────────────
    for (final goal in goals) {
      final d = goal.targetDate;
      if (!d.isBefore(today) && d.isBefore(cutoff)) {
        events.add(CalendarEvent(
          id: 'goal_${goal.id}',
          title: goal.name,
          subtitle: 'Goal Deadline · ${goal.getTypeLabel()}',
          date: d,
          type: CalendarEventType.goal,
          amount: goal.remainingAmount > 0 ? goal.remainingAmount : null,
        ));
      }
    }

    // ── Budget period resets ─────────────────────────────────────────────────
    for (final budget in budgets) {
      var resetDate = budget.getNextPeriodStart();
      int count = 0;
      while (!resetDate.isAfter(cutoff) && count < 20) {
        if (!resetDate.isBefore(today)) {
          events.add(CalendarEvent(
            id: 'budget_${budget.id}_${resetDate.toIso8601String()}',
            title: budget.name,
            subtitle: 'Budget Reset · ${budget.getPeriodLabel()}',
            date: resetDate,
            type: CalendarEventType.budgetReset,
            amount: budget.limitAmount,
          ));
        }
        resetDate = _advanceBudget(resetDate, budget.period);
        count++;
      }
    }

    // ── Insurance renewal / maturity / trip end ──────────────────────────────
    for (final policy in policies) {
      final effectiveDate = _insuranceEffectiveDate(policy);
      if (effectiveDate == null) continue;
      final d = DateTime(
          effectiveDate.year, effectiveDate.month, effectiveDate.day);
      if (!d.isBefore(today) && d.isBefore(cutoff)) {
        final concept = policy.type.dateConcept; // 'Renewal', 'Maturity', 'Trip End'
        events.add(CalendarEvent(
          id: 'ins_${policy.id}',
          title: policy.name,
          subtitle: '$concept · ${policy.insurer} · ${policy.type.displayName}',
          date: d,
          type: CalendarEventType.insurance,
          amount: policy.premiumAmount,
        ));
      }

      // For health/vehicle/home/other: also generate annual renewal occurrences
      if (!policy.type.usesMaturityDate &&
          policy.type != InsuranceType.travel) {
        var nextRenewal = _nextAnnualRenewal(effectiveDate);
        int count = 0;
        while (!nextRenewal.isAfter(cutoff) && count < 3) {
          if (!nextRenewal.isBefore(today)) {
            events.add(CalendarEvent(
              id: 'ins_${policy.id}_r${count}',
              title: policy.name,
              subtitle: 'Renewal · ${policy.insurer}',
              date: nextRenewal,
              type: CalendarEventType.insurance,
              amount: policy.premiumAmount,
            ));
          }
          nextRenewal = DateTime(nextRenewal.year + 1, nextRenewal.month,
              nextRenewal.day);
          count++;
        }
      }
    }

    // ── Loan EMI due dates ───────────────────────────────────────────────────
    for (final loan in loans) {
      var current = loan.nextDueDate;
      int count = 0;
      while (!current.isAfter(cutoff) && count < 18) {
        final d = DateTime(current.year, current.month, current.day);
        if (!d.isBefore(today)) {
          events.add(CalendarEvent(
            id: 'emi_${loan.id}_${current.toIso8601String()}',
            title: loan.name,
            subtitle: loan.bankName?.isNotEmpty == true
                    ? 'Loan EMI · ${loan.bankName}'
                    : 'Loan EMI',
            date: d,
            type: CalendarEventType.loanEmi,
            amount: loan.emiAmount,
          ));
        }
        current = DateTime(current.year, current.month + 1, current.day);
        count++;
      }
    }

    return events;
  }

  // ─── Insurance helpers ───────────────────────────────────────────────────

  DateTime? _insuranceEffectiveDate(InsurancePolicy policy) {
    if (policy.type.usesMaturityDate) {
      return policy.maturityDate ?? policy.renewalDate;
    }
    return policy.renewalDate;
  }

  DateTime _nextAnnualRenewal(DateTime base) {
    final now = DateTime.now();
    var next = DateTime(now.year, base.month, base.day);
    if (!next.isAfter(now)) {
      next = DateTime(now.year + 1, base.month, base.day);
    }
    return next;
  }

  // ─── SIP helpers ────────────────────────────────────────────────────────

  DateTime? _nextSipDate(Map<String, dynamic> meta) {
    final freqStr =
        ((meta['sipFrequency'] as String?) ?? 'monthly').toLowerCase();
    final lastExec = meta['sipLastExecutionDate'] as String?;
    final startDate = meta['sipStartDate'] as String?;
    DateTime? base;
    if (lastExec != null) base = DateTime.tryParse(lastExec);
    base ??= startDate != null ? DateTime.tryParse(startDate) : null;
    if (base == null) return null;
    return _advanceFreq(base, freqStr);
  }

  double? _sipAmount(Map<String, dynamic> meta) {
    final sipType = (meta['sipType'] as String?)?.toLowerCase();
    if (sipType == 'quantity') {
      return (meta['sipQty'] as num?)?.toDouble();
    }
    final amount = (meta['sipAmount'] as num?)?.toDouble();
    if (amount != null) return amount;
    final sipData = meta['sipData'];
    if (sipData is Map<String, dynamic>) {
      return (sipData['sipAmount'] as num?)?.toDouble();
    }
    return null;
  }

  String _freqLabel(String freq) {
    switch (freq) {
      case 'daily':
        return 'Daily';
      case 'weekly':
        return 'Weekly';
      case 'yearly':
        return 'Yearly';
      default:
        return 'Monthly';
    }
  }

  DateTime _advanceFreq(DateTime base, String freq) {
    switch (freq) {
      case 'daily':
        return base.add(const Duration(days: 1));
      case 'weekly':
        return base.add(const Duration(days: 7));
      case 'yearly':
        return DateTime(base.year + 1, base.month, base.day);
      default:
        return DateTime(base.year, base.month + 1, base.day);
    }
  }

  DateTime _advanceBudget(DateTime base, BudgetPeriod period) {
    switch (period) {
      case BudgetPeriod.daily:
        return base.add(const Duration(days: 1));
      case BudgetPeriod.weekly:
        return base.add(const Duration(days: 7));
      case BudgetPeriod.monthly:
        return DateTime(
          base.month == 12 ? base.year + 1 : base.year,
          base.month == 12 ? 1 : base.month + 1,
          base.day,
        );
      case BudgetPeriod.yearly:
        return DateTime(base.year + 1, base.month, base.day);
    }
  }
}

// ─── Day cell ─────────────────────────────────────────────────────────────────

class _DayCell extends StatelessWidget {
  final int day;
  final List<CalendarEvent> events;
  final bool isToday;
  final bool isSelected;
  final bool isSunday;
  final VoidCallback onTap;

  const _DayCell({
    required this.day,
    required this.events,
    required this.isToday,
    required this.isSelected,
    required this.isSunday,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Collect distinct type colors (max 3)
    final isDark = AppStyles.isDarkMode(context);
    final typeColors = events
        .map((e) => e.type.colorFor(isDark))
        .toSet()
        .take(3)
        .toList();
    final hasMore = events.map((e) => e.type).toSet().length > 3;

    Color numberColor;
    if (isSelected) {
      numberColor = Colors.white;
    } else if (isToday) {
      numberColor = AppStyles.teal(context);
    } else if (isSunday) {
      numberColor = const Color(0xFFFF3B30).withValues(alpha: 0.7);
    } else {
      numberColor = AppStyles.getTextColor(context);
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Day number circle
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected
                  ? AppStyles.teal(context)
                  : isToday
                      ? AppStyles.teal(context).withValues(alpha: 0.15)
                      : Colors.transparent,
            ),
            child: Center(
              child: Text(
                '$day',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isToday || isSelected
                      ? FontWeight.w800
                      : FontWeight.w500,
                  color: numberColor,
                  height: 1,
                ),
              ),
            ),
          ),
          const SizedBox(height: 3),
          // Event dots
          if (events.isNotEmpty)
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ...typeColors.map((c) => Container(
                      width: 4,
                      height: 4,
                      margin:
                          const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white.withValues(alpha: 0.9)
                            : c,
                        shape: BoxShape.circle,
                      ),
                    )),
                if (hasMore)
                  Container(
                    width: 4,
                    height: 4,
                    margin:
                        const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.5)
                          : AppStyles.getSecondaryTextColor(context)
                              .withValues(alpha: 0.4),
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            )
          else
            const SizedBox(height: 7), // placeholder to keep row height
        ],
      ),
    );
  }
}

// ─── Filter chip ──────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BouncyButton(
      onPressed: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding:
            const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.18)
              : AppStyles.getCardColor(context),
          borderRadius: BorderRadius.circular(Radii.full),
          border: Border.all(
            color: isSelected
                ? color.withValues(alpha: 0.6)
                : AppStyles.getDividerColor(context),
            width: isSelected ? 1.2 : 0.8,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: TypeScale.caption,
            fontWeight:
                isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? color
                : AppStyles.getSecondaryTextColor(context),
          ),
        ),
      ),
    );
  }
}

// ─── Event tile ───────────────────────────────────────────────────────────────

class _EventTile extends StatelessWidget {
  final CalendarEvent event;

  const _EventTile({required this.event});

  @override
  Widget build(BuildContext context) {
    final isDark = AppStyles.isDarkMode(context);
    final color = event.type.colorFor(isDark);
    final icon = event.type.icon;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final eventDay =
        DateTime(event.date.year, event.date.month, event.date.day);
    final daysUntil = eventDay.difference(today).inDays;

    final String daysLabel;
    final Color daysColor;
    if (daysUntil == 0) {
      daysLabel = 'Today';
      daysColor = AppStyles.loss(context);
    } else if (daysUntil == 1) {
      daysLabel = 'Tomorrow';
      daysColor = AppStyles.accentOrange;
    } else if (daysUntil <= 7) {
      daysLabel = 'In ${daysUntil}d';
      daysColor = AppStyles.accentOrange;
    } else {
      daysLabel = 'In ${daysUntil}d';
      daysColor = AppStyles.getSecondaryTextColor(context);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: Spacing.sm),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.white,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.2 : 0.15),
          width: 1,
        ),
        boxShadow: isDark ? Shadows.cardDark : Shadows.cardLight,
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // Left accent bar
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(Radii.lg),
                  bottomLeft: Radius.circular(Radii.lg),
                ),
              ),
            ),
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(Spacing.md),
                child: Row(
                  children: [
                    // Icon
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(Radii.sm),
                      ),
                      child: Icon(icon, color: color, size: 18),
                    ),
                    const SizedBox(width: Spacing.md),
                    // Text
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            event.title,
                            style: TextStyle(
                              fontSize: TypeScale.callout,
                              fontWeight: FontWeight.w600,
                              color: AppStyles.getTextColor(context),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            event.subtitle,
                            style: TextStyle(
                              fontSize: TypeScale.footnote,
                              color:
                                  AppStyles.getSecondaryTextColor(context),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: Spacing.sm),
                    // Right: date + amount + days
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Type badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: Spacing.sm, vertical: 3),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.15),
                            borderRadius:
                                BorderRadius.circular(Radii.full),
                          ),
                          child: Text(
                            event.type.label,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: color,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDate(event.date),
                          style: TextStyle(
                            fontSize: TypeScale.footnote,
                            fontWeight: FontWeight.w600,
                            color: AppStyles.getTextColor(context),
                          ),
                        ),
                        const SizedBox(height: 2),
                        if (event.amount != null)
                          Text(
                            CurrencyFormatter.compact(event.amount!),
                            style: TextStyle(
                              fontSize: TypeScale.caption,
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                          ),
                        const SizedBox(height: 2),
                        Text(
                          daysLabel,
                          style: TextStyle(
                            fontSize: TypeScale.caption,
                            fontWeight: daysUntil <= 7
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: daysColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      '',
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day} ${months[date.month]}';
  }
}
