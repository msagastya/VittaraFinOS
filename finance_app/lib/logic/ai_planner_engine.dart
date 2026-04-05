import 'package:vittara_fin_os/logic/ai_planner_context.dart';
import 'package:vittara_fin_os/logic/ml_planner_engine.dart';
import 'package:vittara_fin_os/logic/transaction_model.dart';
import 'package:vittara_fin_os/logic/account_model.dart';
import 'package:vittara_fin_os/logic/investment_model.dart';
import 'package:vittara_fin_os/logic/budget_model.dart';
import 'package:vittara_fin_os/logic/goal_model.dart';

class PlannerRecommendation {
  final String title;
  final String detail;
  final String? actionLabel;
  final PlannerRecommendationType type;

  const PlannerRecommendation({
    required this.title,
    required this.detail,
    this.actionLabel,
    required this.type,
  });
}

enum PlannerRecommendationType { positive, warning, action, info }

// A single upcoming milestone on the path to the goal.
class PlannerMilestone {
  final double fraction;     // 0.25 / 0.50 / 0.75 / 1.0
  final double amount;       // absolute ₹ value at this milestone
  final DateTime? estDate;   // estimated date at current rate (null if no savings)
  final bool reached;        // already crossed (currentSaved >= amount)

  const PlannerMilestone({
    required this.fraction,
    required this.amount,
    required this.estDate,
    required this.reached,
  });

  String get label {
    if (fraction == 1.0) return 'Goal reached!';
    return '${(fraction * 100).toStringAsFixed(0)}%';
  }
}

class PlannerAnalysis {
  final FinancialPlan plan;
  final double monthlyIncome;
  final double monthlyExpenses;
  final double monthlySavings;           // 3-month average from transactions
  final double effectiveMonthlySavings;  // plan.monthlyContribution ?? monthlySavings
  final double savingsRate;
  final double requiredMonthlySavings;   // to hit target in timeline
  final double savingsGap;               // required − effective (negative = surplus)
  final int monthsToTarget;              // at effective savings rate
  final bool isOnTrack;
  final List<PlannerRecommendation> recommendations;
  final String summary;
  // ── Richer context ──────────────────────────────────────────────────────
  final double actualProgressFraction;      // currentSaved / targetAmount (0-1)
  final double projectedProgressFraction;   // projected by target date at current rate (0-1)
  final DateTime? projectedCompletionDate;  // at effective savings rate
  final int? monthsOffSchedule;             // negative=ahead, positive=behind
  final String thisMonthAction;
  final double? scenarioFasterSaveAmount;   // save this much more/month...
  final int? scenarioFasterGainMonths;      // ...to complete goal X months earlier
  final List<PlannerMilestone> milestones;  // 25/50/75/100% waypoints
  // ── ML fields (null when dataSufficient == false) ──────────────────────
  final MLAnalysis ml;

  const PlannerAnalysis({
    required this.plan,
    required this.monthlyIncome,
    required this.monthlyExpenses,
    required this.monthlySavings,
    required this.effectiveMonthlySavings,
    required this.savingsRate,
    required this.requiredMonthlySavings,
    required this.savingsGap,
    required this.monthsToTarget,
    required this.isOnTrack,
    required this.recommendations,
    required this.summary,
    required this.actualProgressFraction,
    required this.projectedProgressFraction,
    required this.projectedCompletionDate,
    required this.monthsOffSchedule,
    required this.thisMonthAction,
    required this.scenarioFasterSaveAmount,
    required this.scenarioFasterGainMonths,
    required this.milestones,
    required this.ml,
  });
}

class AIPlannerEngine {
  AIPlannerEngine._();

  static PlannerAnalysis analyze({
    required FinancialPlan plan,
    required List<Transaction> transactions,
    required List<Account> accounts,
    required List<Investment> investments,
    required List<Budget> budgets,
    required List<Goal> goals,
  }) {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final threeMonthsAgo = DateTime(now.year, now.month, 1)
        .subtract(const Duration(days: 90));

    // ── Income & expenses (3-month average) ──────────────────────────────
    double totalIncome3m = 0;
    double totalExpenses3m = 0;
    for (final tx in transactions) {
      if (tx.dateTime.isBefore(threeMonthsAgo)) continue;
      if (tx.type == TransactionType.income ||
          tx.type == TransactionType.cashback) {
        totalIncome3m += tx.amount.abs();
      } else if (tx.type == TransactionType.expense ||
          tx.type == TransactionType.investment) {
        totalExpenses3m += tx.amount.abs();
      }
    }
    final monthlyIncome = totalIncome3m / 3;
    final monthlyExpenses = totalExpenses3m / 3;
    final monthlySavings =
        (monthlyIncome - monthlyExpenses).clamp(0.0, double.infinity);
    final savingsRate =
        monthlyIncome > 0 ? monthlySavings / monthlyIncome : 0.0;

    // ── Effective monthly savings for this plan ───────────────────────────
    // Use the user's dedicated contribution if specified, otherwise fall back
    // to the overall savings computed from transactions.
    final effectiveMonthlySavings =
        (plan.monthlyContribution != null && plan.monthlyContribution! > 0)
            ? plan.monthlyContribution!
            : monthlySavings;

    // ── Category spending (current month) ────────────────────────────────
    final Map<String, double> categorySpend = {};
    for (final tx in transactions) {
      if (tx.dateTime.isBefore(monthStart)) continue;
      if (tx.type == TransactionType.expense) {
        final cat =
            (tx.metadata?['categoryName'] as String?) ?? 'Other';
        categorySpend[cat] = (categorySpend[cat] ?? 0) + tx.amount.abs();
      }
    }
    final topCategories = categorySpend.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // ── Savings and investment totals ─────────────────────────────────────
    final totalSavings = accounts
        .where((a) =>
            a.type != AccountType.credit && a.type != AccountType.payLater)
        .fold(0.0, (s, a) => s + a.balance);
    final totalInvested = investments.fold(0.0, (s, i) => s + i.amount);

    // ── Target & gap calculations ─────────────────────────────────────────
    final target = plan.targetAmount;
    double requiredMonthlySavings = 0;
    double savingsGap = 0;
    int monthsToTarget = 0;
    bool isOnTrack = false;

    if (target != null && target > 0) {
      final remaining =
          (target - plan.currentSaved).clamp(0.0, double.infinity);
      requiredMonthlySavings =
          plan.timelineMonths > 0 ? remaining / plan.timelineMonths : remaining;
      savingsGap = requiredMonthlySavings - effectiveMonthlySavings;
      monthsToTarget = effectiveMonthlySavings > 0
          ? (remaining / effectiveMonthlySavings).ceil()
          : 9999;
      isOnTrack = savingsGap <= 0;
    } else {
      requiredMonthlySavings = _defaultRequiredSavings(
          plan.focus, monthlyIncome, totalSavings, totalInvested);
      savingsGap = requiredMonthlySavings - effectiveMonthlySavings;
      isOnTrack = savingsGap <= 0;
      monthsToTarget = requiredMonthlySavings > 0 && effectiveMonthlySavings > 0
          ? (_defaultTargetAmount(
                          plan.focus, monthlyIncome, totalSavings) /
                      effectiveMonthlySavings)
                  .ceil()
          : 0;
    }

    // ── Progress fractions ────────────────────────────────────────────────
    final double actualProgressFraction = (target != null && target > 0)
        ? (plan.currentSaved / target).clamp(0.0, 1.0)
        : 0.0;
    final double projectedProgressFraction = (target != null && target > 0)
        ? ((plan.currentSaved + effectiveMonthlySavings * plan.timelineMonths) /
                target)
            .clamp(0.0, 1.0)
        : 0.0;

    // ── Projected completion date ─────────────────────────────────────────
    DateTime? projectedCompletionDate;
    int? monthsOffSchedule;
    if (target != null && target > 0 && effectiveMonthlySavings > 0) {
      final remaining =
          (target - plan.currentSaved).clamp(0.0, double.infinity);
      final mths = (remaining / effectiveMonthlySavings).ceil();
      projectedCompletionDate = DateTime(now.year, now.month + mths);
      monthsOffSchedule = mths - plan.timelineMonths; // positive=behind
    }

    // ── Scenario: save 20% more → how many months gained? ────────────────
    double? scenarioFasterSaveAmount;
    int? scenarioFasterGainMonths;
    if (target != null && target > 0 && effectiveMonthlySavings > 0) {
      final remaining =
          (target - plan.currentSaved).clamp(0.0, double.infinity);
      final boost = effectiveMonthlySavings * 0.20;
      final boostedMonths = (remaining / (effectiveMonthlySavings + boost)).ceil();
      final currentMonths = (remaining / effectiveMonthlySavings).ceil();
      final gain = currentMonths - boostedMonths;
      if (gain > 0) {
        scenarioFasterSaveAmount = boost;
        scenarioFasterGainMonths = gain;
      }
    }

    // ── Milestones ────────────────────────────────────────────────────────
    final milestones = <PlannerMilestone>[];
    if (target != null && target > 0) {
      for (final frac in [0.25, 0.50, 0.75, 1.0]) {
        final amt = target * frac;
        final reached = plan.currentSaved >= amt;
        DateTime? estDate;
        if (!reached && effectiveMonthlySavings > 0) {
          final mRemaining = (amt - plan.currentSaved).clamp(0.0, double.infinity);
          final mths = (mRemaining / effectiveMonthlySavings).ceil();
          estDate = DateTime(now.year, now.month + mths);
        }
        milestones.add(PlannerMilestone(
          fraction: frac,
          amount: amt,
          estDate: estDate,
          reached: reached,
        ));
      }
    }

    // ── This month's action ───────────────────────────────────────────────
    final String thisMonthAction;
    if (monthlyIncome == 0) {
      thisMonthAction =
          'Log your income transactions to get a personalised monthly action.';
    } else if (target != null && isOnTrack) {
      thisMonthAction =
          'Keep your ₹${_fmt(effectiveMonthlySavings)}/month contribution — you\'re on schedule for ${plan.timelineLabel}.';
    } else if (target != null && savingsGap > 0) {
      thisMonthAction =
          'Save ₹${_fmt(savingsGap)} more this month (total ₹${_fmt(effectiveMonthlySavings + savingsGap)}) to stay on the ${plan.timelineLabel} track.';
    } else {
      final recommended = _defaultRequiredSavings(
          plan.focus, monthlyIncome, totalSavings, totalInvested);
      thisMonthAction = recommended > 0
          ? 'Aim to save ₹${_fmt(recommended)} this month toward your ${plan.focusLabel} goal.'
          : 'Keep tracking your transactions to see personalised advice here.';
    }

    // ── Build recommendations ─────────────────────────────────────────────
    final recs = <PlannerRecommendation>[];

    // Savings rate
    if (savingsRate >= 0.30) {
      recs.add(PlannerRecommendation(
        title: 'Excellent savings rate',
        detail:
            'You\'re saving ${(savingsRate * 100).toStringAsFixed(0)}% of income — well above the 20% benchmark.',
        type: PlannerRecommendationType.positive,
      ));
    } else if (savingsRate >= 0.20) {
      recs.add(PlannerRecommendation(
        title: 'Good savings rate',
        detail:
            'Saving ${(savingsRate * 100).toStringAsFixed(0)}% of income. Pushing to 30% would accelerate your ${plan.focusLabel} goal.',
        type: PlannerRecommendationType.info,
      ));
    } else if (monthlyIncome > 0) {
      final needed = monthlyIncome * 0.20 - monthlySavings;
      recs.add(PlannerRecommendation(
        title: 'Low savings rate — ${(savingsRate * 100).toStringAsFixed(0)}%',
        detail:
            'Below the 20% benchmark. Saving ₹${_fmt(needed)} more/month would put you on track.',
        type: PlannerRecommendationType.warning,
      ));
    }

    // Gap / on-track
    if (savingsGap > 0 && plan.targetAmount != null) {
      recs.add(PlannerRecommendation(
        title: 'Savings gap: ₹${_fmt(savingsGap)}/month',
        detail:
            'Need ₹${_fmt(requiredMonthlySavings)}/month; currently saving ₹${_fmt(effectiveMonthlySavings)}/month. '
            'At this rate: $monthsToTarget months vs your ${plan.timelineLabel} target.',
        actionLabel: 'Review Budgets',
        type: PlannerRecommendationType.warning,
      ));
    } else if (plan.targetAmount != null && isOnTrack) {
      recs.add(PlannerRecommendation(
        title: 'On track for ${plan.focusLabel}',
        detail:
            'At ₹${_fmt(effectiveMonthlySavings)}/month, you\'ll reach your goal in $monthsToTarget months — within your ${plan.timelineLabel} target.',
        type: PlannerRecommendationType.positive,
      ));
    }

    // Top spending category
    if (topCategories.isNotEmpty) {
      final top = topCategories.first;
      final budgetForCat = budgets
          .where((b) =>
              b.name.toLowerCase().contains(top.key.toLowerCase()))
          .firstOrNull;
      if (budgetForCat != null && top.value > budgetForCat.limitAmount) {
        recs.add(PlannerRecommendation(
          title: '${top.key} over budget',
          detail:
              'Spent ₹${_fmt(top.value)} on ${top.key} vs ₹${_fmt(budgetForCat.limitAmount)} budget. '
              'Cutting 20% frees ₹${_fmt(top.value * 0.20)}/month.',
          actionLabel: 'View Budgets',
          type: PlannerRecommendationType.warning,
        ));
      } else if (monthlyIncome > 0 && top.value / monthlyIncome > 0.25) {
        recs.add(PlannerRecommendation(
          title: '${top.key} is your biggest expense',
          detail:
              '₹${_fmt(top.value)} (${(top.value / monthlyIncome * 100).toStringAsFixed(0)}% of income) on ${top.key} this month. '
              'Consider if this aligns with your ${plan.focusLabel} priority.',
          type: PlannerRecommendationType.info,
        ));
      }
    }

    // Focus-specific advice
    recs.addAll(_focusSpecificRecs(plan, monthlyIncome, effectiveMonthlySavings,
        totalSavings, totalInvested, investments, budgets));

    // Investment diversity
    if (plan.focus == PlanningFocus.investment ||
        plan.focus == PlanningFocus.retirement) {
      final types = investments.map((i) => i.type).toSet().length;
      if (types < 3) {
        recs.add(PlannerRecommendation(
          title: 'Low investment diversity',
          detail:
              'You have $types investment type${types == 1 ? '' : 's'}. Spreading across 4+ types (MF, FD, Stocks, Gold) reduces risk.',
          actionLabel: 'View Investments',
          type: PlannerRecommendationType.info,
        ));
      }
    }

    // Budget adherence
    final exceededBudgets =
        budgets.where((b) => b.status == BudgetStatus.exceeded).length;
    if (exceededBudgets > 0) {
      recs.add(PlannerRecommendation(
        title: '$exceededBudgets budget${exceededBudgets > 1 ? 's' : ''} exceeded',
        detail:
            'Staying within budgets is critical for ${plan.focusLabel}. '
            'Review your spending to find quick cuts.',
        actionLabel: 'Review Budgets',
        type: PlannerRecommendationType.warning,
      ));
    }

    // Multiple high-priority plans note
    if (plan.priority == 1 && goal_conflictHint(goals, plan)) {
      recs.add(PlannerRecommendation(
        title: 'You have active savings goals',
        detail:
            'Make sure your monthly contributions across all plans are sustainable. '
            'Focus high-priority plans first.',
        type: PlannerRecommendationType.info,
      ));
    }

    // ── ML layer ──────────────────────────────────────────────────────────
    final ml = MLPlannerEngine.analyze(
      transactions: transactions,
      currentSaved: plan.currentSaved,
      targetAmount: plan.targetAmount,
      monthsRemaining: plan.targetAmount != null ? monthsToTarget : null,
    );

    // ── Summary ───────────────────────────────────────────────────────────
    final summary = _buildSummary(plan, isOnTrack, savingsRate, savingsGap,
        monthsToTarget, monthlyIncome, effectiveMonthlySavings,
        monthsOffSchedule);

    return PlannerAnalysis(
      plan: plan,
      monthlyIncome: monthlyIncome,
      monthlyExpenses: monthlyExpenses,
      monthlySavings: monthlySavings,
      effectiveMonthlySavings: effectiveMonthlySavings,
      savingsRate: savingsRate,
      requiredMonthlySavings: requiredMonthlySavings,
      savingsGap: savingsGap,
      monthsToTarget: monthsToTarget,
      isOnTrack: isOnTrack,
      recommendations: recs.take(5).toList(),
      summary: summary,
      actualProgressFraction: actualProgressFraction,
      projectedProgressFraction: projectedProgressFraction,
      projectedCompletionDate: projectedCompletionDate,
      monthsOffSchedule: monthsOffSchedule,
      thisMonthAction: thisMonthAction,
      scenarioFasterSaveAmount: scenarioFasterSaveAmount,
      scenarioFasterGainMonths: scenarioFasterGainMonths,
      milestones: milestones,
      ml: ml,
    );
  }

  static bool goal_conflictHint(List<Goal> goals, FinancialPlan plan) {
    return goals.isNotEmpty;
  }

  static String _fmt(double v) =>
      v >= 1e5 ? '${(v / 1e5).toStringAsFixed(1)}L' : v.toStringAsFixed(0);

  static double _relevantSavedAmount(PlanningFocus focus, double savings,
      double invested, List<Goal> goals) {
    switch (focus) {
      case PlanningFocus.emergencyFund:
        return savings;
      case PlanningFocus.investment:
      case PlanningFocus.retirement:
        return invested;
      default:
        return savings;
    }
  }

  static double _defaultRequiredSavings(PlanningFocus focus, double income,
      double savings, double invested) {
    switch (focus) {
      case PlanningFocus.emergencyFund:
        return (income * 6 - savings).clamp(0.0, double.infinity) / 12;
      case PlanningFocus.retirement:
        return income * 0.15;
      case PlanningFocus.investment:
        return income * 0.20;
      default:
        return income * 0.20;
    }
  }

  static double _defaultTargetAmount(
      PlanningFocus focus, double income, double savings) {
    switch (focus) {
      case PlanningFocus.emergencyFund:
        return (income * 6 - savings).clamp(0.0, double.infinity);
      case PlanningFocus.retirement:
        return income * 12 * 25;
      default:
        return income * 12;
    }
  }

  static List<PlannerRecommendation> _focusSpecificRecs(
    FinancialPlan plan,
    double income,
    double savings,
    double totalSavings,
    double totalInvested,
    List<Investment> investments,
    List<Budget> budgets,
  ) {
    final recs = <PlannerRecommendation>[];
    switch (plan.focus) {
      case PlanningFocus.emergencyFund:
        final months = income > 0 ? totalSavings / income : 0;
        if (months < 3) {
          recs.add(PlannerRecommendation(
            title: 'Emergency fund: ${months.toStringAsFixed(1)} months',
            detail:
                '${months.toStringAsFixed(1)}x monthly income saved. Target: 6x. '
                'Priority: build this before other goals.',
            type: PlannerRecommendationType.warning,
          ));
        } else if (months < 6) {
          recs.add(PlannerRecommendation(
            title: 'Emergency fund: almost there',
            detail:
                '${months.toStringAsFixed(1)} months saved. Need ${(6 - months).toStringAsFixed(1)} more to hit the 6-month safety net.',
            type: PlannerRecommendationType.info,
          ));
        } else {
          recs.add(PlannerRecommendation(
            title: 'Emergency fund complete ✓',
            detail:
                '${months.toStringAsFixed(1)} months of expenses secured. Consider moving surplus to higher-yield investments.',
            type: PlannerRecommendationType.positive,
          ));
        }
        break;
      case PlanningFocus.debtPayoff:
        recs.add(PlannerRecommendation(
          title: 'Use the avalanche method',
          detail:
              'Pay minimum on all debts, then throw every extra rupee at your highest-interest debt first. Once cleared, redirect that amount to the next.',
          type: PlannerRecommendationType.action,
        ));
        break;
      case PlanningFocus.retirement:
        final coverage = income > 0 ? totalInvested / (income * 12) : 0;
        recs.add(PlannerRecommendation(
          title: 'Retirement corpus: ${coverage.toStringAsFixed(1)}x annual income',
          detail:
              'The 25x rule: need 25x annual income to retire. You\'re at ${coverage.toStringAsFixed(1)}x. '
              'NPS + ELSS give tax benefits on top of growth.',
          type: coverage >= 5
              ? PlannerRecommendationType.info
              : PlannerRecommendationType.warning,
        ));
        break;
      case PlanningFocus.homeDownPayment:
        recs.add(PlannerRecommendation(
          title: 'Keep down payment savings liquid',
          detail:
              'Store in FD or liquid MF — not equity. Money needed within 3 years shouldn\'t be in volatile assets.',
          type: PlannerRecommendationType.info,
        ));
        break;
      case PlanningFocus.education:
        recs.add(PlannerRecommendation(
          title: 'Lock in returns early',
          detail:
              'Starting an education SIP early lets compounding do the heavy lifting. '
              'Even ₹2,000/month over 10 years at 12% CAGR grows to ~₹4.7L.',
          type: PlannerRecommendationType.info,
        ));
        break;
      case PlanningFocus.wedding:
        recs.add(PlannerRecommendation(
          title: 'Short-horizon: stay liquid',
          detail:
              'Wedding fund with a 1–3 year horizon: use RD or liquid MF for safety and easy access.',
          type: PlannerRecommendationType.info,
        ));
        break;
      case PlanningFocus.travel:
        recs.add(PlannerRecommendation(
          title: 'Create a dedicated travel account',
          detail:
              'Keeping your travel fund in a separate account prevents accidental spending and makes progress visible.',
          type: PlannerRecommendationType.action,
        ));
        break;
      default:
        break;
    }
    return recs;
  }

  static String _buildSummary(
    FinancialPlan plan,
    bool onTrack,
    double savingsRate,
    double gap,
    int months,
    double income,
    double savings,
    int? monthsOffSchedule,
  ) {
    if (income == 0) {
      return 'Add income transactions to get personalised ${plan.focusLabel} advice.';
    }
    if (onTrack && plan.targetAmount != null) {
      return 'You\'re on track for ${plan.focusLabel} in ${plan.timelineLabel}. '
          'Saving ${(savingsRate * 100).toStringAsFixed(0)}% of income — keep it up.';
    } else if (gap > 0 && plan.targetAmount != null) {
      final behind = monthsOffSchedule != null && monthsOffSchedule > 0
          ? ' (${monthsOffSchedule}mo behind schedule)'
          : '';
      return 'To reach ${plan.focusLabel} in ${plan.timelineLabel}, save ₹${_fmt(gap)}/month more$behind.';
    }
    return 'Your ${plan.focusLabel} plan is in good shape. Review recommendations for optimisations.';
  }
}
