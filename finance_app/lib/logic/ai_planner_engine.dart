import 'package:vittara_fin_os/logic/ai_planner_context.dart';
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

class PlannerAnalysis {
  final AIPlannerContext context;
  final double monthlyIncome;
  final double monthlyExpenses;
  final double monthlySavings;
  final double savingsRate; // 0.0 - 1.0
  final double requiredMonthlySavings; // to hit target in timeline
  final double savingsGap; // required - actual (negative = surplus)
  final int monthsToTarget; // at current savings rate
  final bool isOnTrack;
  final List<PlannerRecommendation> recommendations;
  final String summary; // 1-2 sentence overall assessment

  const PlannerAnalysis({
    required this.context,
    required this.monthlyIncome,
    required this.monthlyExpenses,
    required this.monthlySavings,
    required this.savingsRate,
    required this.requiredMonthlySavings,
    required this.savingsGap,
    required this.monthsToTarget,
    required this.isOnTrack,
    required this.recommendations,
    required this.summary,
  });
}

class AIPlannerEngine {
  AIPlannerEngine._();

  static PlannerAnalysis analyze({
    required AIPlannerContext context,
    required List<Transaction> transactions,
    required List<Account> accounts,
    required List<Investment> investments,
    required List<Budget> budgets,
    required List<Goal> goals,
  }) {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);

    // ── Income & expenses (last 3 months average for stability) ──────────
    double totalIncome3m = 0;
    double totalExpenses3m = 0;
    final threeMonthsAgo = DateTime(now.year, now.month, 1).subtract(const Duration(days: 90));

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

    // ── Category spending analysis ──────────────────────────────────────
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

    // ── Total current savings (all non-credit account balances) ──────────
    final totalSavings = accounts
        .where((a) =>
            a.type != AccountType.credit && a.type != AccountType.payLater)
        .fold(0.0, (s, a) => s + a.balance);

    // ── Investment value ──────────────────────────────────────────────
    final totalInvested = investments.fold(0.0, (s, i) => s + i.amount);

    // ── Required monthly savings & gap ───────────────────────────────
    final target = context.targetAmount;
    double requiredMonthlySavings = 0;
    double savingsGap = 0;
    int monthsToTarget = 0;
    bool isOnTrack = false;

    if (target != null && target > 0) {
      final alreadySaved = _relevantSavedAmount(
          context.focus, totalSavings, totalInvested, goals);
      final remaining =
          (target - alreadySaved).clamp(0.0, double.infinity);
      requiredMonthlySavings = remaining / context.timelineMonths;
      savingsGap = requiredMonthlySavings - monthlySavings;
      monthsToTarget = monthlySavings > 0
          ? (remaining / monthlySavings).ceil()
          : 9999;
      isOnTrack = savingsGap <= 0;
    } else {
      // No target amount — assess based on focus defaults
      requiredMonthlySavings = _defaultRequiredSavings(
          context.focus, monthlyIncome, totalSavings, totalInvested);
      savingsGap = requiredMonthlySavings - monthlySavings;
      isOnTrack = savingsGap <= 0;
      monthsToTarget = requiredMonthlySavings > 0 && monthlySavings > 0
          ? (_defaultTargetAmount(
                      context.focus, monthlyIncome, totalSavings) /
                  monthlySavings)
              .ceil()
          : 0;
    }

    // ── Build recommendations ─────────────────────────────────────────
    final recs = <PlannerRecommendation>[];

    // Savings rate assessment
    if (savingsRate >= 0.30) {
      recs.add(PlannerRecommendation(
        title: 'Excellent savings rate',
        detail:
            'You\'re saving ${(savingsRate * 100).toStringAsFixed(0)}% of your income — well above the 20% benchmark.',
        type: PlannerRecommendationType.positive,
      ));
    } else if (savingsRate >= 0.20) {
      recs.add(PlannerRecommendation(
        title: 'Good savings rate',
        detail:
            'You\'re saving ${(savingsRate * 100).toStringAsFixed(0)}% of income. Increasing to 30% would accelerate your ${context.focusLabel} goal.',
        type: PlannerRecommendationType.info,
      ));
    } else if (monthlyIncome > 0) {
      final needed =
          (monthlyIncome * 0.20 - monthlySavings).toStringAsFixed(0);
      recs.add(PlannerRecommendation(
        title: 'Low savings rate',
        detail:
            'Currently saving ${(savingsRate * 100).toStringAsFixed(0)}% — below the 20% benchmark. Saving ₹$needed more/month would put you on track.',
        type: PlannerRecommendationType.warning,
      ));
    }

    // Gap analysis
    if (savingsGap > 0 && context.targetAmount != null) {
      recs.add(PlannerRecommendation(
        title:
            'Savings gap: ₹${savingsGap.toStringAsFixed(0)}/month',
        detail:
            'You need ₹${requiredMonthlySavings.toStringAsFixed(0)}/month but currently saving ₹${monthlySavings.toStringAsFixed(0)}/month. '
            'At this rate, your ${context.focusLabel} goal will take $monthsToTarget months instead of ${context.timelineMonths}.',
        actionLabel: 'Review Budgets',
        type: PlannerRecommendationType.warning,
      ));
    } else if (context.targetAmount != null && isOnTrack) {
      recs.add(PlannerRecommendation(
        title: 'On track for ${context.focusLabel}',
        detail:
            'At ₹${monthlySavings.toStringAsFixed(0)}/month, you\'ll reach your goal in $monthsToTarget months — within your ${context.timelineLabel} target.',
        type: PlannerRecommendationType.positive,
      ));
    }

    // Top overspending category
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
              'Spent ₹${top.value.toStringAsFixed(0)} on ${top.key} this month vs ₹${budgetForCat.limitAmount.toStringAsFixed(0)} budget. '
              'Cutting this by 20% would free ₹${(top.value * 0.20).toStringAsFixed(0)}/month.',
          actionLabel: 'View Budgets',
          type: PlannerRecommendationType.warning,
        ));
      } else if (monthlyIncome > 0 &&
          top.value / monthlyIncome > 0.25) {
        recs.add(PlannerRecommendation(
          title: '${top.key} is your biggest expense',
          detail:
              '₹${top.value.toStringAsFixed(0)} (${(top.value / monthlyIncome * 100).toStringAsFixed(0)}% of income) on ${top.key} this month. '
              'Consider if this aligns with your ${context.focusLabel} priority.',
          type: PlannerRecommendationType.info,
        ));
      }
    }

    // Focus-specific advice
    recs.addAll(_focusSpecificRecs(context, monthlyIncome, monthlySavings,
        totalSavings, totalInvested, investments, budgets));

    // Investment diversity (if focus is investment/retirement)
    if (context.focus == PlanningFocus.investment ||
        context.focus == PlanningFocus.retirement) {
      final types = investments.map((i) => i.type).toSet().length;
      if (types < 3) {
        recs.add(PlannerRecommendation(
          title: 'Low investment diversity',
          detail:
              'You have $types investment type${types == 1 ? '' : 's'}. Spreading across 4+ types (MF, FD, Stocks, Gold) reduces risk for long-term goals.',
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
        title:
            '$exceededBudgets budget${exceededBudgets > 1 ? 's' : ''} exceeded',
        detail:
            'Staying within budgets is critical for your ${context.focusLabel} goal. '
            'Review your spending to find quick cuts.',
        actionLabel: 'Review Budgets',
        type: PlannerRecommendationType.warning,
      ));
    }

    // ── Summary ────────────────────────────────────────────────────────
    final summary = _buildSummary(context, isOnTrack, savingsRate,
        savingsGap, monthsToTarget, monthlyIncome, monthlySavings);

    return PlannerAnalysis(
      context: context,
      monthlyIncome: monthlyIncome,
      monthlyExpenses: monthlyExpenses,
      monthlySavings: monthlySavings,
      savingsRate: savingsRate,
      requiredMonthlySavings: requiredMonthlySavings,
      savingsGap: savingsGap,
      monthsToTarget: monthsToTarget,
      isOnTrack: isOnTrack,
      recommendations: recs.take(5).toList(), // cap at 5 for readability
      summary: summary,
    );
  }

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
        return income * 12 * 25; // 25x rule
      default:
        return income * 12;
    }
  }

  static List<PlannerRecommendation> _focusSpecificRecs(
    AIPlannerContext ctx,
    double income,
    double savings,
    double totalSavings,
    double totalInvested,
    List<Investment> investments,
    List<Budget> budgets,
  ) {
    final recs = <PlannerRecommendation>[];
    switch (ctx.focus) {
      case PlanningFocus.emergencyFund:
        final months = income > 0 ? totalSavings / income : 0;
        if (months < 3) {
          recs.add(PlannerRecommendation(
            title:
                'Emergency fund: ${months.toStringAsFixed(1)} months',
            detail:
                'You have ${months.toStringAsFixed(1)}x monthly income saved. '
                'Financial advisors recommend 6x. Priority: build this before other goals.',
            type: PlannerRecommendationType.warning,
          ));
        } else if (months < 6) {
          recs.add(PlannerRecommendation(
            title:
                'Emergency fund: ${months.toStringAsFixed(1)} months (almost there)',
            detail:
                'You need ${(6 - months).toStringAsFixed(1)} more months of expenses in savings to reach the 6-month safety net.',
            type: PlannerRecommendationType.info,
          ));
        } else {
          recs.add(PlannerRecommendation(
            title: 'Emergency fund complete',
            detail:
                '${months.toStringAsFixed(1)} months of expenses saved. Consider moving surplus to higher-yield investments.',
            type: PlannerRecommendationType.positive,
          ));
        }
        break;
      case PlanningFocus.debtPayoff:
        recs.add(PlannerRecommendation(
          title: 'Debt payoff strategy',
          detail:
              'Focus extra savings on your highest-interest debt first (avalanche method). '
              'Once paid, redirect that amount to savings.',
          type: PlannerRecommendationType.action,
        ));
        break;
      case PlanningFocus.retirement:
        final coverage =
            income > 0 ? totalInvested / (income * 12) : 0;
        recs.add(PlannerRecommendation(
          title:
              'Retirement corpus: ${coverage.toStringAsFixed(1)}x annual income',
          detail:
              'The 25x rule suggests needing 25x annual income for retirement. '
              'At current investments: ${coverage.toStringAsFixed(1)}x. '
              'Diversify with NPS + ELSS for tax benefits.',
          type: coverage >= 5
              ? PlannerRecommendationType.info
              : PlannerRecommendationType.warning,
        ));
        break;
      case PlanningFocus.homeDownPayment:
        recs.add(PlannerRecommendation(
          title: 'Down payment tip',
          detail:
              'Keep your down payment savings in liquid instruments (FD or liquid MF). '
              'Avoid equity for money needed within 3 years.',
          type: PlannerRecommendationType.info,
        ));
        break;
      default:
        break;
    }
    return recs;
  }

  static String _buildSummary(
    AIPlannerContext ctx,
    bool onTrack,
    double savingsRate,
    double gap,
    int months,
    double income,
    double savings,
  ) {
    if (income == 0) {
      return 'Add your income transactions to get personalized ${ctx.focusLabel} planning advice.';
    }
    if (onTrack) {
      return 'You\'re on track for ${ctx.focusLabel} in ${ctx.timelineLabel}. '
          'Saving ${(savingsRate * 100).toStringAsFixed(0)}% of income — keep it up.';
    } else if (gap > 0) {
      return 'To reach ${ctx.focusLabel} in ${ctx.timelineLabel}, save ₹${gap.toStringAsFixed(0)}/month more. '
          'At current rate, it\'ll take $months months.';
    }
    return 'Your ${ctx.focusLabel} plan is in good shape. Review recommendations below for optimizations.';
  }
}
