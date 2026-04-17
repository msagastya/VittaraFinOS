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
import 'package:vittara_fin_os/ui/styles/responsive_utils.dart';

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

  // Calendar collapse on scroll
  bool _calendarCollapsed = false;
  final ScrollController _eventsScrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedMonth = DateTime(now.year, now.month, 1);
    _selectedDay = DateTime(now.year, now.month, now.day);
    _eventsScrollCtrl.addListener(_onEventsScroll);
  }

  @override
  void dispose() {
    _eventsScrollCtrl.dispose();
    super.dispose();
  }

  void _onEventsScroll() {
    // Collapse when scrolling down on events list.
    if (!_calendarCollapsed && _eventsScrollCtrl.offset > 20) {
      setState(() => _calendarCollapsed = true);
    }
  }

  void _prevMonth() {
    HapticFeedback.selectionClick();
    if (_eventsScrollCtrl.hasClients) _eventsScrollCtrl.jumpTo(0);
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1, 1);
      _selectedDay = null;
      _calendarCollapsed = false;
    });
  }

  void _nextMonth() {
    HapticFeedback.selectionClick();
    if (_eventsScrollCtrl.hasClients) _eventsScrollCtrl.jumpTo(0);
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 1);
      _selectedDay = null;
      _calendarCollapsed = false;
    });
  }

  void _selectDay(DateTime day) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedDay != null &&
          _selectedDay!.year == day.year &&
          _selectedDay!.month == day.month &&
          _selectedDay!.day == day.day) {
        _selectedDay = null;
        _calendarCollapsed = false; // deselecting day always expands
      } else {
        _selectedDay = day;
        // Don't change _calendarCollapsed — keep user's current state
      }
    });
    // Reset scroll to top when changing day
    if (_eventsScrollCtrl.hasClients) {
      _eventsScrollCtrl.jumpTo(0);
    }
  }

  void _navigateDay(int delta) {
    if (_selectedDay == null) return;
    HapticFeedback.selectionClick();
    final newDay = _selectedDay!.add(Duration(days: delta));
    setState(() {
      _selectedDay = newDay;
      // Sync focused month if we crossed a month boundary
      if (newDay.year != _focusedMonth.year ||
          newDay.month != _focusedMonth.month) {
        _focusedMonth = DateTime(newDay.year, newDay.month, 1);
        // Keep collapsed state as-is when navigating days
      }
    });
    // Reset scroll to top for the new day's events
    if (_eventsScrollCtrl.hasClients) {
      _eventsScrollCtrl.jumpTo(0);
    }
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
      navigationBar: AppStyles.isLandscape(context) ? null : CupertinoNavigationBar(
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
            if (AppStyles.isLandscape(context))
              _buildLandscapeNavBar(context),
            // ── Upcoming 7-day strip ───────────────────────────────────────
            _buildUpcomingStrip(context, eventsMap),
            // ── Calendar card ──────────────────────────────────────────────
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanEnd: (details) {
                final vx = details.velocity.pixelsPerSecond.dx;
                final vy = details.velocity.pixelsPerSecond.dy;
                // Only fire if clearly horizontal (vx dominates by 50%)
                final isHorizontal = vx.abs() > vy.abs() * 1.5 && vx.abs() > 300;
                // Only fire if clearly vertical (vy dominates by 50%)
                final isVertical = vy.abs() > vx.abs() * 1.5 && vy.abs() > 200;

                if (isHorizontal) {
                  if (_calendarCollapsed && _selectedDay != null) {
                    if (vx < 0) _navigateDay(1);
                    else _navigateDay(-1);
                  } else {
                    if (vx < 0) _nextMonth();
                    else _prevMonth();
                  }
                } else if (isVertical) {
                  if (vy < 0) {
                    // Swipe up → collapse
                    if (!_calendarCollapsed) {
                      if (_eventsScrollCtrl.hasClients) _eventsScrollCtrl.jumpTo(0);
                      setState(() => _calendarCollapsed = true);
                    }
                  } else {
                    // Swipe down → expand
                    if (_calendarCollapsed) {
                      if (_eventsScrollCtrl.hasClients) _eventsScrollCtrl.jumpTo(0);
                      setState(() => _calendarCollapsed = false);
                    }
                  }
                }
              },
              child: Container(
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
                  AnimatedSize(
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeInOutCubic,
                    child: _calendarCollapsed
                        ? _buildCollapsedDateChip(context)
                        : Column(
                            children: [
                              _buildWeekdayRow(context),
                              _buildCalendarGrid(context, eventsMap),
                              const SizedBox(height: Spacing.sm),
                            ],
                          ),
                  ),
                  if (_calendarCollapsed) const SizedBox(height: Spacing.xs),
                ],
              ),
            ),
            ), // end GestureDetector (calendar card)

            const SizedBox(height: Spacing.md),

            // ── Filter chips ───────────────────────────────────────────────
            _buildFilterRow(context, allEvents),

            const SizedBox(height: Spacing.sm),

            // ── Event section ──────────────────────────────────────────────
            Expanded(
              child: NotificationListener<OverscrollNotification>(
                onNotification: (n) {
                  // Pull down past top while collapsed → expand calendar
                  if (n.overscroll < 0 &&
                      _calendarCollapsed &&
                      _selectedDay != null) {
                    if (_eventsScrollCtrl.hasClients) {
                      _eventsScrollCtrl.jumpTo(0);
                    }
                    setState(() => _calendarCollapsed = false);
                  }
                  return false;
                },
                child: _buildEventSection(context, filteredEvents, isDark),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Landscape nav bar ───────────────────────────────────────────────────

  Widget _buildLandscapeNavBar(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
      child: Row(
        children: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            onPressed: () => Navigator.maybePop(context),
            child: Icon(CupertinoIcons.chevron_left, size: 20,
                color: AppStyles.getPrimaryColor(context)),
          ),
          const SizedBox(width: 8),
          Text(
            'FINANCIAL CALENDAR',
            style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700,
              color: AppStyles.getTextColor(context), letterSpacing: 1.1,
            ),
          ),
          const Spacer(),
          Text(
            '${DateFormatter.getMonthName(_focusedMonth.month, short: true)} ${_focusedMonth.year}',
            style: TextStyle(
              fontSize: TypeScale.footnote,
              color: AppStyles.getSecondaryTextColor(context),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Upcoming 7-day strip ────────────────────────────────────────────────

  Widget _buildUpcomingStrip(
      BuildContext context, Map<String, List<CalendarEvent>> eventsMap) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = List.generate(7, (i) => today.add(Duration(days: i)));
    final isDark = AppStyles.isDarkMode(context);

    return SizedBox(
      height: 56,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
        itemCount: 7,
        itemBuilder: (ctx, i) {
          final day = days[i];
          final key = _dateKey(day);
          final events = eventsMap[key] ?? [];
          final isSelected = _selectedDay != null &&
              _selectedDay!.year == day.year &&
              _selectedDay!.month == day.month &&
              _selectedDay!.day == day.day;
          final dayLabel = i == 0
              ? 'Today'
              : i == 1
                  ? 'Tmrw'
                  : DateFormatter.getMonthName(day.month, short: true).substring(0, 3);
          final accent = AppStyles.teal(context);

          return GestureDetector(
            onTap: () => _selectDay(day),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              margin: const EdgeInsets.only(right: 8, top: 4, bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected
                    ? accent
                    : isDark ? const Color(0xFF111111) : const Color(0xFFF2F2F7),
                borderRadius: BorderRadius.circular(Radii.lg),
                border: Border.all(
                  color: isSelected ? accent : AppStyles.getDividerColor(context),
                  width: 0.8,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${day.day}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: isSelected ? Colors.white : AppStyles.getTextColor(context),
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    dayLabel,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.8)
                          : AppStyles.getSecondaryTextColor(context),
                    ),
                  ),
                  if (events.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white.withValues(alpha: 0.25)
                            : accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${events.length}',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? Colors.white : accent,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          const cols = 7;
          const spacing = 0.0;
          final itemW = (constraints.maxWidth - (cols - 1) * spacing) / cols;
          return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          mainAxisSpacing: 4,
          crossAxisSpacing: spacing,
          childAspectRatio: itemW / (itemW / 0.78),
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
          );
        },
      ),
    );
  }

  // ─── Collapsed date chip — tapping expands calendar back ────────────────

  Widget _buildCollapsedDateChip(BuildContext context) {
    final refDay = _selectedDay ?? DateTime.now();
    final dayName =
        ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'][refDay.weekday - 1];
    final monthName = [
      'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
      'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'
    ][refDay.month - 1];
    final secondary = AppStyles.getSecondaryTextColor(context);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (_eventsScrollCtrl.hasClients) {
          _eventsScrollCtrl.jumpTo(0);
        }
        setState(() => _calendarCollapsed = false);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: Spacing.lg, vertical: Spacing.md),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              dayName,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: secondary,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 1,
              height: 18,
              color: secondary.withValues(alpha: 0.3),
            ),
            const SizedBox(width: 10),
            Text(
              '${refDay.day}',
              style: TextStyle(
                fontSize: RT.largeTitle(context),
                fontWeight: FontWeight.w700,
                color: AppStyles.aetherTeal,
                height: 1.0,
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 1,
              height: 18,
              color: secondary.withValues(alpha: 0.3),
            ),
            const SizedBox(width: 10),
            Text(
              monthName,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: secondary,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(width: Spacing.lg),
            Icon(
              CupertinoIcons.chevron_down,
              size: 13,
              color: secondary.withValues(alpha: 0.5),
            ),
          ],
        ),
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
                  onPressed: () {
                    setState(() {
                      _selectedDay = null;
                      _calendarCollapsed = false;
                    });
                    if (_eventsScrollCtrl.hasClients) {
                      _eventsScrollCtrl.animateTo(
                        0,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                    }
                  },
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
              ? CustomScrollView(
                  controller: _eventsScrollCtrl,
                  physics: const ClampingScrollPhysics(),
                  slivers: [
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildEmptyEvents(context),
                    ),
                  ],
                )
              : ListView.builder(
                  controller: _eventsScrollCtrl,
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
            subtitle: '${_sipTypeLabel(inv.type)} SIP · $freqLabel',
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

  /// Returns the next due date for a SIP investment.
  /// Handles both stock SIPs (top-level meta keys) and MF SIPs (nested
  /// sipData map with monthDay / weekday).
  DateTime? _nextSipDate(Map<String, dynamic> meta) {
    final sipData = meta['sipData'] as Map<String, dynamic>?;

    // Frequency: top-level (stocks) OR nested sipData (MF)
    final freqStr = ((meta['sipFrequency'] as String?) ??
            (sipData?['frequency'] as String?) ??
            'monthly')
        .toLowerCase();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Monthly MF SIP: use the explicit day-of-month stored in sipData
    if (freqStr == 'monthly') {
      final monthDay = (sipData?['monthDay'] as int?) ??
          (meta['sipMonthDay'] as int?);
      if (monthDay != null && monthDay >= 1 && monthDay <= 31) {
        // Clamp to 28 to avoid month-overflow issues
        final safeDay = monthDay.clamp(1, 28);
        var candidate = DateTime(today.year, today.month, safeDay);
        if (!candidate.isAfter(today)) {
          candidate = DateTime(today.year, today.month + 1, safeDay);
        }
        return candidate;
      }
    }

    // Weekly MF SIP: use the explicit weekday stored in sipData
    // App convention: 0 = Monday … 6 = Sunday
    // DateTime convention: 1 = Monday … 7 = Sunday
    if (freqStr == 'weekly') {
      final weekdayIdx = (sipData?['weekday'] as int?) ??
          (meta['sipWeekday'] as int?);
      if (weekdayIdx != null) {
        final target = weekdayIdx + 1; // convert to DateTime weekday
        var daysAhead = (target - today.weekday + 7) % 7;
        if (daysAhead == 0) daysAhead = 7;
        return today.add(Duration(days: daysAhead));
      }
    }

    // Fallback: advance from lastExecutionDate or sipStartDate (stock SIPs)
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

  /// Human-readable investment type prefix for SIP event subtitles.
  String _sipTypeLabel(InvestmentType type) {
    switch (type) {
      case InvestmentType.mutualFund:
        return 'MF';
      case InvestmentType.stocks:
        return 'Stock';
      case InvestmentType.cryptocurrency:
        return 'Crypto';
      case InvestmentType.digitalGold:
        return 'Gold';
      default:
        return 'SIP';
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

  String _formatDate(DateTime date) => DateFormatter.format(date);
}
