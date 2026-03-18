import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/budget_model.dart';
import 'package:vittara_fin_os/logic/budgets_controller.dart';
import 'package:vittara_fin_os/logic/fixed_deposit_model.dart';
import 'package:vittara_fin_os/logic/goal_model.dart';
import 'package:vittara_fin_os/logic/goals_controller.dart';
import 'package:vittara_fin_os/logic/investment_model.dart';
import 'package:vittara_fin_os/logic/investments_controller.dart';
import 'package:vittara_fin_os/logic/recurring_deposit_model.dart';
import 'package:vittara_fin_os/logic/recurring_template_model.dart';
import 'package:vittara_fin_os/logic/recurring_templates_controller.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/widgets/common_widgets.dart';
import 'package:vittara_fin_os/utils/date_formatter.dart';

// ── Event model ──────────────────────────────────────────────────────────────

enum CalendarEventType {
  fd,
  rd,
  sip,
  bill,
  goal,
  budgetReset,
}

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

// ── Screen ────────────────────────────────────────────────────────────────────

class FinancialCalendarScreen extends StatelessWidget {
  const FinancialCalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = AppStyles.isDarkMode(context);

    return CupertinoPageScaffold(
      backgroundColor: AppStyles.getBackground(context),
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          'Financial Calendar',
          style: TextStyle(color: AppStyles.getTextColor(context)),
        ),
        previousPageTitle: 'Back',
        backgroundColor: isDark ? Colors.black : Colors.white.withValues(alpha: 0.95),
        border: null,
      ),
      child: SafeArea(
        child: Consumer3<InvestmentsController, RecurringTemplatesController,
            GoalsController>(
          builder: (context, investmentsCtrl, templatesCtrl, goalsCtrl, _) {
            return Consumer<BudgetsController>(
              builder: (context, budgetsCtrl, _) {
                final events = _buildEvents(
                  investments: investmentsCtrl.investments,
                  templates: templatesCtrl.templates,
                  goals: goalsCtrl.activeGoals,
                  budgets: budgetsCtrl.activeBudgets,
                );

                if (events.isEmpty) {
                  return const Center(
                    child: EmptyStateView(
                      icon: CupertinoIcons.calendar_badge_plus,
                      title: 'No Upcoming Events',
                      subtitle:
                          'Add FDs, SIPs, goals, or bill reminders to see them here.',
                    ),
                  );
                }

                // Group by "YYYY-MM" key, sorted chronologically
                final grouped = <String, List<CalendarEvent>>{};
                for (final event in events) {
                  final key =
                      '${event.date.year}-${event.date.month.toString().padLeft(2, '0')}';
                  grouped.putIfAbsent(key, () => []).add(event);
                }
                final sortedKeys = grouped.keys.toList()..sort();

                return ListView.builder(
                  padding: const EdgeInsets.only(
                    left: Spacing.lg,
                    right: Spacing.lg,
                    top: Spacing.lg,
                    bottom: Spacing.massive,
                  ),
                  itemCount: sortedKeys.length,
                  itemBuilder: (context, idx) {
                    final key = sortedKeys[idx];
                    final parts = key.split('-');
                    final year = int.parse(parts[0]);
                    final month = int.parse(parts[1]);
                    final monthEvents = grouped[key]!
                      ..sort((a, b) => a.date.compareTo(b.date));

                    return _MonthSection(
                      month: month,
                      year: year,
                      events: monthEvents,
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  /// Aggregate all financial events for the next 12 months.
  List<CalendarEvent> _buildEvents({
    required List<Investment> investments,
    required List<RecurringTemplate> templates,
    required List<Goal> goals,
    required List<Budget> budgets,
  }) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final cutoff = DateTime(now.year + 1, now.month, now.day);
    final events = <CalendarEvent>[];

    // ── FD maturity ───────────────────────────────────────────────────────────
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
          // Fallback: plain maturityDate string stored directly
          final dateStr = meta['maturityDate'] as String?;
          if (dateStr != null) {
            final d = DateTime.tryParse(dateStr);
            if (d != null && !d.isBefore(today) && d.isBefore(cutoff)) {
              events.add(CalendarEvent(
                id: 'fd_${inv.id}',
                title: inv.name,
                subtitle: 'FD Maturity',
                date: d,
                type: CalendarEventType.fd,
                amount: (meta['estimatedAccruedValue'] as num?)?.toDouble() ??
                    inv.amount,
              ));
            }
          }
        }
      } catch (_) {}
    }

    // ── RD maturity ───────────────────────────────────────────────────────────
    for (final inv in investments) {
      if (inv.type != InvestmentType.recurringDeposit) continue;
      final meta = inv.metadata;
      if (meta == null) continue;

      try {
        if (meta.containsKey('rdData')) {
          final rd = RecurringDeposit.fromMap(
              Map<String, dynamic>.from(meta['rdData'] as Map));
          final d = rd.maturityDate;
          if (!d.isBefore(today) && d.isBefore(cutoff)) {
            events.add(CalendarEvent(
              id: 'rd_${inv.id}',
              title: rd.name,
              subtitle: rd.bankName?.isNotEmpty == true
                  ? 'RD Maturity · ${rd.bankName}'
                  : 'RD Maturity',
              date: d,
              type: CalendarEventType.rd,
              amount: rd.maturityValue,
            ));
          }
        } else if (meta.containsKey('maturityDate')) {
          final dateStr = meta['maturityDate'] as String?;
          if (dateStr != null) {
            final d = DateTime.tryParse(dateStr);
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
        }
      } catch (_) {}
    }

    // ── SIP due dates (next 12 occurrences for each active SIP) ──────────────
    for (final inv in investments) {
      final meta = inv.metadata ?? {};
      if (meta['sipActive'] != true) continue;

      // Determine next due date and frequency
      final DateTime? baseDue = _nextSipDate(meta, inv.type);
      if (baseDue == null) continue;

      final freqStr =
          ((meta['sipFrequency'] as String?) ?? 'monthly').toLowerCase();
      final freqLabel = _sipFrequencyLabel(freqStr);

      // Generate upcoming occurrences within 12 months
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
        current = _advanceByFrequency(current, freqStr);
        count++;
      }
    }

    // ── Bill reminders (recurring templates) ─────────────────────────────────
    for (final tmpl in templates) {
      if (tmpl.nextDueDate == null) continue;

      // Generate upcoming due occurrences within 12 months
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
        current = _advanceTemplateByFrequency(current, tmpl.frequency);
        count++;
      }
    }

    // ── Goal deadlines ────────────────────────────────────────────────────────
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

    // ── Budget period resets ──────────────────────────────────────────────────
    for (final budget in budgets) {
      // Walk forward from current end date, generating reset dates
      var resetDate = budget.getNextPeriodStart();
      int count = 0;
      while (!resetDate.isAfter(cutoff) && count < 13) {
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
        // Advance by the budget's own period
        resetDate = _advanceBudget(resetDate, budget.period);
        count++;
      }
    }

    return events;
  }

  // ── SIP helpers ─────────────────────────────────────────────────────────────

  DateTime? _nextSipDate(Map<String, dynamic> meta, InvestmentType type) {
    final freqStr =
        ((meta['sipFrequency'] as String?) ?? 'monthly').toLowerCase();

    final lastExec = meta['sipLastExecutionDate'] as String?;
    final startDate = meta['sipStartDate'] as String?;

    DateTime? base;
    if (lastExec != null) {
      base = DateTime.tryParse(lastExec);
    }
    base ??= startDate != null ? DateTime.tryParse(startDate) : null;
    if (base == null) return null;

    // Advance base by one period to get the *next* due date
    return _advanceByFrequency(base, freqStr);
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

  String _sipFrequencyLabel(String freq) {
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

  DateTime _advanceByFrequency(DateTime base, String freq) {
    switch (freq) {
      case 'daily':
        return base.add(const Duration(days: 1));
      case 'weekly':
        return base.add(const Duration(days: 7));
      case 'yearly':
        return DateTime(base.year + 1, base.month, base.day);
      default: // monthly
        return DateTime(base.year, base.month + 1, base.day);
    }
  }

  DateTime _advanceTemplateByFrequency(DateTime base, String freq) =>
      _advanceByFrequency(base, freq);

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

// ── Month section ─────────────────────────────────────────────────────────────

class _MonthSection extends StatelessWidget {
  final int month;
  final int year;
  final List<CalendarEvent> events;

  const _MonthSection({
    required this.month,
    required this.year,
    required this.events,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isCurrentMonth = month == now.month && year == now.year;
    final monthLabel = DateFormatter.getMonthName(month, short: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Month header
        Padding(
          padding: const EdgeInsets.only(
            bottom: Spacing.sm,
            top: Spacing.sm,
          ),
          child: Row(
            children: [
              Text(
                '$monthLabel $year',
                style: TextStyle(
                  fontSize: TypeScale.headline,
                  fontWeight: FontWeight.w700,
                  color: isCurrentMonth
                      ? AppStyles.aetherTeal
                      : AppStyles.getTextColor(context),
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(width: Spacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.sm,
                  vertical: Spacing.xxs,
                ),
                decoration: BoxDecoration(
                  color: AppStyles.aetherTeal.withValues(alpha: 0.12),
                  borderRadius: Radii.pillRadius,
                ),
                child: Text(
                  '${events.length}',
                  style: const TextStyle(
                    fontSize: TypeScale.caption,
                    fontWeight: FontWeight.w600,
                    color: AppStyles.aetherTeal,
                  ),
                ),
              ),
            ],
          ),
        ),
        ...events.map((event) => _EventCard(event: event)),
        const SizedBox(height: Spacing.lg),
      ],
    );
  }
}

// ── Event card ────────────────────────────────────────────────────────────────

class _EventCard extends StatelessWidget {
  final CalendarEvent event;

  const _EventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    final isDark = AppStyles.isDarkMode(context);
    final color = _eventColor(event.type);
    final icon = _eventIcon(event.type);
    final badge = _eventBadge(event.type);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final eventDay =
        DateTime(event.date.year, event.date.month, event.date.day);
    final daysUntil = eventDay.difference(today).inDays;

    String daysLabel;
    if (daysUntil == 0) {
      daysLabel = 'Today';
    } else if (daysUntil == 1) {
      daysLabel = 'Tomorrow';
    } else {
      daysLabel = 'In $daysUntil days';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: Spacing.sm),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(
          color: color.withValues(alpha: 0.18),
          width: 1,
        ),
        boxShadow: isDark ? Shadows.cardDark : Shadows.cardLight,
      ),
      child: Padding(
        padding: const EdgeInsets.all(Spacing.md),
        child: Row(
          children: [
            // Icon box
            Container(
              width: ComponentSizes.iconBoxSmall,
              height: ComponentSizes.iconBoxSmall,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(Radii.sm),
              ),
              child: Icon(icon, color: color, size: IconSizes.md),
            ),
            const SizedBox(width: Spacing.md),

            // Title + subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                  const SizedBox(height: Spacing.xxs),
                  Text(
                    event.subtitle,
                    style: TextStyle(
                      fontSize: TypeScale.footnote,
                      color: AppStyles.getSecondaryTextColor(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: Spacing.sm),

            // Right column: date + badge + days
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Type badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Spacing.sm,
                    vertical: Spacing.xxs,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: Radii.pillRadius,
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      fontSize: TypeScale.caption,
                      fontWeight: FontWeight.w700,
                      color: color,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                const SizedBox(height: Spacing.xxs + 2),
                Text(
                  _formatDate(event.date),
                  style: TextStyle(
                    fontSize: TypeScale.footnote,
                    fontWeight: FontWeight.w500,
                    color: AppStyles.getTextColor(context),
                  ),
                ),
                const SizedBox(height: Spacing.xxs),
                Text(
                  daysUntil <= 7
                      ? daysLabel
                      : event.amount != null
                          ? CurrencyFormatter.compact(event.amount!)
                          : daysLabel,
                  style: TextStyle(
                    fontSize: TypeScale.caption,
                    color: daysUntil <= 3
                        ? AppStyles.plasmaRed
                        : AppStyles.getSecondaryTextColor(context),
                    fontWeight:
                        daysUntil <= 3 ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _eventColor(CalendarEventType type) {
    switch (type) {
      case CalendarEventType.fd:
        return AppStyles.solarGold;
      case CalendarEventType.rd:
        return AppStyles.accentOrange;
      case CalendarEventType.sip:
        return AppStyles.aetherTeal;
      case CalendarEventType.bill:
        return AppStyles.plasmaRed;
      case CalendarEventType.goal:
        return AppStyles.novaPurple;
      case CalendarEventType.budgetReset:
        return AppStyles.bioGreen;
    }
  }

  IconData _eventIcon(CalendarEventType type) {
    switch (type) {
      case CalendarEventType.fd:
        return CupertinoIcons.lock_fill;
      case CalendarEventType.rd:
        return CupertinoIcons.arrow_2_circlepath;
      case CalendarEventType.sip:
        return CupertinoIcons.graph_circle_fill;
      case CalendarEventType.bill:
        return CupertinoIcons.doc_text_fill;
      case CalendarEventType.goal:
        return CupertinoIcons.flag_fill;
      case CalendarEventType.budgetReset:
        return CupertinoIcons.chart_bar_fill;
    }
  }

  String _eventBadge(CalendarEventType type) {
    switch (type) {
      case CalendarEventType.fd:
        return 'FD';
      case CalendarEventType.rd:
        return 'RD';
      case CalendarEventType.sip:
        return 'SIP';
      case CalendarEventType.bill:
        return 'Bill';
      case CalendarEventType.goal:
        return 'Goal';
      case CalendarEventType.budgetReset:
        return 'Budget';
    }
  }

  String _formatDate(DateTime date) {
    const months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month]}';
  }
}
