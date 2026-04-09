import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/accounts_controller.dart';
import 'package:vittara_fin_os/logic/budgets_controller.dart';
import 'package:vittara_fin_os/logic/budget_model.dart';
import 'package:vittara_fin_os/logic/goals_controller.dart';
import 'package:vittara_fin_os/logic/goal_model.dart';
import 'package:vittara_fin_os/logic/investments_controller.dart';
import 'package:vittara_fin_os/logic/transactions_controller.dart';
import 'package:vittara_fin_os/logic/transaction_model.dart';
import 'package:vittara_fin_os/ui/manage/account_wizard.dart';
import 'package:vittara_fin_os/ui/manage/budgets/modals/add_budget_modal.dart';
import 'package:vittara_fin_os/ui/manage/goals/modals/add_goal_modal.dart';
import 'package:vittara_fin_os/ui/manage/investments_screen.dart';
import 'package:vittara_fin_os/ui/manage/ai_planner/ai_monthly_planner_screen.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/widgets/animations.dart';
import 'package:vittara_fin_os/utils/date_formatter.dart';

// ---------------------------------------------------------------------------
// Next Move — priority-based intelligence card
// ---------------------------------------------------------------------------

class _NextMoveItem {
  final String title;
  final String body;
  final IconData icon;
  final Color color;
  final VoidCallback onAction;

  const _NextMoveItem({
    required this.title,
    required this.body,
    required this.icon,
    required this.color,
    required this.onAction,
  });
}

_NextMoveItem? _computeNextMove({
  required BuildContext context,
  required List accounts,
  required List budgets,
  required List goals,
  required List investments,
  required List transactions,
}) {
  final hasAccounts = accounts.isNotEmpty;
  final hasIncome = transactions.any((tx) =>
      tx is Transaction &&
      (tx.type == TransactionType.income ||
          tx.type == TransactionType.cashback));

  // Rule 1 — No accounts
  if (!hasAccounts) {
    return _NextMoveItem(
      title: 'Add your first account',
      body: 'Link a bank account to see your real financial picture.',
      icon: CupertinoIcons.building_2_fill,
      color: AppStyles.accentBlue,
      onAction: () => showCupertinoModalPopup(
        context: context,
        builder: (_) => const AccountWizard(),
      ),
    );
  }

  // Rule 2 — No budgets
  if (budgets.isEmpty) {
    // Find top spend category
    final catSpend = <String, double>{};
    for (final tx in transactions) {
      if (tx is Transaction && tx.type == TransactionType.expense) {
        final cat = tx.metadata?['categoryName'] as String? ?? 'General';
        catSpend[cat] = (catSpend[cat] ?? 0) + tx.amount;
      }
    }
    final topCat = catSpend.entries.isEmpty
        ? 'Food & Dining'
        : (catSpend.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value)))
            .first
            .key;
    return _NextMoveItem(
      title: 'Create your first budget',
      body: 'No spending limit set. You spent most on $topCat — start there.',
      icon: CupertinoIcons.chart_pie_fill,
      color: SemanticColors.primary,
      onAction: () => showCupertinoModalPopup(
        context: context,
        builder: (_) => const AddBudgetModal(),
      ),
    );
  }

  // Rule 3 — No goals
  if (goals.isEmpty) {
    return _NextMoveItem(
      title: 'Set your first financial goal',
      body: 'People with written goals save 2.4× more than those without.',
      icon: CupertinoIcons.flag_fill,
      color: SemanticColors.success,
      onAction: () => showCupertinoModalPopup(
        context: context,
        builder: (_) => const AddGoalModal(),
      ),
    );
  }

  // Rule 4 — No investments
  if (investments.isEmpty) {
    return _NextMoveItem(
      title: 'Start investing',
      body: 'Even ₹500 in an FD beats cash sitting idle. Your money can work.',
      icon: CupertinoIcons.graph_circle_fill,
      color: SemanticColors.investments,
      onAction: () => Navigator.of(context)
          .push(FadeScalePageRoute(page: const InvestmentsScreen())),
    );
  }

  // Rule 5 — No emergency fund
  final hasEmergencyGoal =
      (goals as List<Goal>).any((g) => g.type == GoalType.emergency);
  if (!hasEmergencyGoal) {
    return _NextMoveItem(
      title: 'Create an Emergency Fund',
      body: 'No safety net yet. Financial advisors recommend 6 months of expenses.',
      icon: CupertinoIcons.shield_fill,
      color: AppStyles.accentOrange,
      onAction: () => showCupertinoModalPopup(
        context: context,
        builder: (_) => const AddGoalModal(),
      ),
    );
  }

  // Rule 6 — No income logged (can't compute savings rate)
  if (!hasIncome) {
    return _NextMoveItem(
      title: 'Log your income',
      body: 'Without income data, we can\'t compute your savings rate or health score.',
      icon: CupertinoIcons.arrow_down_circle_fill,
      color: AppStyles.accentGreen,
      onAction: () {}, // handled by parent quick-add
    );
  }

  // Rule 7 — A budget is exceeded
  final exceededBudgets =
      (budgets as List<Budget>).where((b) => b.status == BudgetStatus.exceeded);
  if (exceededBudgets.isNotEmpty) {
    final b = exceededBudgets.first;
    final overBy = b.spentAmount - b.limitAmount;
    return _NextMoveItem(
      title: 'Budget exceeded: ${b.name}',
      body:
          '${CurrencyFormatter.format(overBy, decimals: 0)} over limit. Review your spending or adjust the budget.',
      icon: CupertinoIcons.exclamationmark_triangle_fill,
      color: SemanticColors.error,
      onAction: () => showCupertinoModalPopup(
        context: context,
        builder: (_) => const AddBudgetModal(),
      ),
    );
  }

  // Rule 8 — A goal is behind schedule
  final offTrackGoals =
      (goals as List<Goal>).where((g) => !g.isOnTrack && !g.isCompleted);
  if (offTrackGoals.isNotEmpty) {
    final g = offTrackGoals.first;
    return _NextMoveItem(
      title: 'Goal "${g.name}" is off-track',
      body:
          '${CurrencyFormatter.format(g.remainingAmount, decimals: 0)} remaining. A quick contribution keeps you on schedule.',
      icon: CupertinoIcons.time_solid,
      color: SemanticColors.warning,
      onAction: () => showCupertinoModalPopup(
        context: context,
        builder: (_) => const AddGoalModal(),
      ),
    );
  }

  // Rule 9 — No AI plan
  return _NextMoveItem(
    title: 'Build your financial plan',
    body: 'AI analysis turns your goals into a concrete monthly savings action.',
    icon: CupertinoIcons.wand_stars,
    color: AppStyles.novaPurple,
    onAction: () => Navigator.of(context).push(
      FadeScalePageRoute(page: const AIMonthlyPlannerScreen()),
    ),
  );
}

// ---------------------------------------------------------------------------
// Widget
// ---------------------------------------------------------------------------

class NextMoveWidget extends StatelessWidget {
  const NextMoveWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer5<TransactionsController, AccountsController,
        BudgetsController, GoalsController, InvestmentsController>(
      builder: (context, txCtrl, accCtrl, budgetCtrl, goalCtrl, invCtrl, _) {
        final move = _computeNextMove(
          context: context,
          accounts: accCtrl.accounts,
          budgets: budgetCtrl.budgets,
          goals: goalCtrl.activeGoals,
          investments: invCtrl.investments,
          transactions: txCtrl.transactions,
        );

        if (move == null) return const SizedBox.shrink();

        final isDark = AppStyles.isDarkMode(context);

        return Padding(
          padding: const EdgeInsets.fromLTRB(
              Spacing.lg, Spacing.md, Spacing.lg, 0),
          child: BouncyButton(
            onPressed: move.onAction,
            child: Container(
              padding: const EdgeInsets.all(Spacing.lg),
              decoration: BoxDecoration(
                color: isDark
                    ? AppStyles.darkCard
                    : AppStyles.lightCard,
                borderRadius: BorderRadius.circular(Radii.xl),
                border: Border.all(
                  color: move.color.withValues(alpha: 0.3),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: move.color.withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: move.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(Radii.md),
                    ),
                    child:
                        Icon(move.icon, color: move.color, size: 22),
                  ),
                  const SizedBox(width: Spacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: move.color.withValues(alpha: 0.12),
                                borderRadius:
                                    BorderRadius.circular(Radii.xs),
                              ),
                              child: Text(
                                'YOUR NEXT MOVE',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: move.color,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          move.title,
                          style: TextStyle(
                            fontSize: TypeScale.callout,
                            fontWeight: FontWeight.w700,
                            color: AppStyles.getTextColor(context),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          move.body,
                          style: TextStyle(
                            fontSize: TypeScale.footnote,
                            color: AppStyles.getSecondaryTextColor(context),
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: Spacing.sm),
                  Icon(
                    CupertinoIcons.chevron_right,
                    size: 14,
                    color: move.color.withValues(alpha: 0.6),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
