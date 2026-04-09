import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/accounts_controller.dart';
import 'package:vittara_fin_os/logic/budgets_controller.dart';
import 'package:vittara_fin_os/logic/engagement_service.dart';
import 'package:vittara_fin_os/logic/goals_controller.dart';
import 'package:vittara_fin_os/logic/transactions_controller.dart';
import 'package:vittara_fin_os/logic/transaction_model.dart';
import 'package:vittara_fin_os/ui/manage/account_wizard.dart';
import 'package:vittara_fin_os/ui/manage/budgets/modals/add_budget_modal.dart';
import 'package:vittara_fin_os/ui/manage/goals/modals/add_goal_modal.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/widgets/animations.dart';

// ---------------------------------------------------------------------------
// 5-Step Setup Card — Endowed Progress Effect
// Step 1 (account) auto-completes when first account exists.
// Disappears when all 5 complete or manually dismissed.
// ---------------------------------------------------------------------------

class OnboardingCardWidget extends StatelessWidget {
  const OnboardingCardWidget({super.key});

  static const _steps = [
    _OnboardStep(
      id: 'account',
      title: 'Add a bank account',
      subtitle: 'Know where your money lives',
      icon: CupertinoIcons.building_2_fill,
    ),
    _OnboardStep(
      id: 'transaction',
      title: 'Log your first transaction',
      subtitle: 'Build the tracking habit',
      icon: CupertinoIcons.arrow_right_arrow_left_circle_fill,
    ),
    _OnboardStep(
      id: 'income',
      title: 'Record your income',
      subtitle: 'Unlock your savings rate',
      icon: CupertinoIcons.arrow_down_circle_fill,
    ),
    _OnboardStep(
      id: 'budget',
      title: 'Create a budget',
      subtitle: 'Spend with intention',
      icon: CupertinoIcons.chart_pie_fill,
    ),
    _OnboardStep(
      id: 'goal',
      title: 'Set a financial goal',
      subtitle: 'Give your savings a name',
      icon: CupertinoIcons.flag_fill,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Consumer5<EngagementService, AccountsController,
        TransactionsController, BudgetsController, GoalsController>(
      builder:
          (context, eng, accCtrl, txCtrl, budgetCtrl, goalCtrl, _) {
        // Auto-complete steps based on data
        _syncSteps(eng, accCtrl, txCtrl, budgetCtrl, goalCtrl);

        if (!eng.isOnboardingVisible) return const SizedBox.shrink();

        final doneFrac = eng.onboardingStepCount / _steps.length;
        final isDark = AppStyles.isDarkMode(context);

        return Padding(
          padding: const EdgeInsets.fromLTRB(
              Spacing.lg, Spacing.md, Spacing.lg, 0),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? AppStyles.darkCard : AppStyles.lightCard,
              borderRadius: BorderRadius.circular(Radii.xl),
              border: Border.all(
                color: AppStyles.aetherTeal.withValues(alpha: 0.25),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppStyles.aetherTeal.withValues(alpha: 0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      Spacing.lg, Spacing.lg, Spacing.lg, 0),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppStyles.aetherTeal.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(Radii.sm),
                        ),
                        child: const Icon(CupertinoIcons.checkmark_shield_fill,
                            color: AppStyles.aetherTeal, size: 18),
                      ),
                      const SizedBox(width: Spacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Set up VittaraFinOS',
                              style: TextStyle(
                                fontSize: TypeScale.callout,
                                fontWeight: FontWeight.w700,
                                color: AppStyles.getTextColor(context),
                              ),
                            ),
                            Text(
                              '${eng.onboardingStepCount}/5 complete',
                              style: TextStyle(
                                fontSize: TypeScale.caption,
                                color: AppStyles.getSecondaryTextColor(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        onPressed: () => eng.dismissOnboarding(),
                        child: Icon(
                          CupertinoIcons.xmark_circle,
                          size: 18,
                          color: AppStyles.getSecondaryTextColor(context)
                              .withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),

                // Progress bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      Spacing.lg, Spacing.sm, Spacing.lg, Spacing.md),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(Radii.full),
                    child: Stack(
                      children: [
                        Container(
                          height: 4,
                          color: AppStyles.getSecondaryTextColor(context)
                              .withValues(alpha: 0.12),
                        ),
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.0, end: doneFrac),
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeOutCubic,
                          builder: (_, val, __) => FractionallySizedBox(
                            widthFactor: val,
                            child: Container(
                              height: 4,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(colors: [
                                  AppStyles.aetherTeal,
                                  AppStyles.accentBlue,
                                ]),
                                borderRadius:
                                    BorderRadius.circular(Radii.full),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Steps list
                ...List.generate(_steps.length, (i) {
                  final step = _steps[i];
                  final isDone = eng.isOnboardingStepDone(step.id);
                  return _buildStepRow(context, eng, step, isDone);
                }),

                const SizedBox(height: Spacing.md),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStepRow(BuildContext context, EngagementService eng,
      _OnboardStep step, bool isDone) {
    final color = isDone ? AppStyles.aetherTeal : AppStyles.getSecondaryTextColor(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          Spacing.lg, 0, Spacing.lg, Spacing.sm),
      child: BouncyButton(
        onPressed: isDone ? () {} : () => _handleStep(context, eng, step),
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: Spacing.md, vertical: Spacing.sm),
          decoration: BoxDecoration(
            color: isDone
                ? AppStyles.aetherTeal.withValues(alpha: 0.07)
                : AppStyles.getSecondaryTextColor(context)
                    .withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(Radii.md),
          ),
          child: Row(
            children: [
              // Check circle
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDone
                      ? AppStyles.aetherTeal.withValues(alpha: 0.15)
                      : Colors.transparent,
                  border: isDone
                      ? null
                      : Border.all(
                          color: AppStyles.getSecondaryTextColor(context)
                              .withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                ),
                child: isDone
                    ? const Icon(CupertinoIcons.checkmark,
                        size: 12, color: AppStyles.aetherTeal)
                    : null,
              ),
              const SizedBox(width: Spacing.md),
              Icon(step.icon, size: 16, color: color),
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: Text(
                  step.title,
                  style: TextStyle(
                    fontSize: TypeScale.footnote,
                    fontWeight: FontWeight.w600,
                    color: isDone
                        ? AppStyles.getSecondaryTextColor(context)
                        : AppStyles.getTextColor(context),
                    decoration: isDone ? TextDecoration.lineThrough : null,
                    decorationColor:
                        AppStyles.getSecondaryTextColor(context),
                  ),
                ),
              ),
              if (!isDone)
                Icon(CupertinoIcons.chevron_right,
                    size: 12,
                    color: AppStyles.getSecondaryTextColor(context)
                        .withValues(alpha: 0.4)),
            ],
          ),
        ),
      ),
    );
  }

  void _handleStep(
      BuildContext context, EngagementService eng, _OnboardStep step) {
    switch (step.id) {
      case 'account':
        showCupertinoModalPopup(
          context: context,
          builder: (_) => AccountWizard(),
        );
        break;
      case 'transaction':
      case 'income':
        // Open quick-add via action sheet — mark step via parent
        // For now just mark done manually after they add
        break;
      case 'budget':
        showCupertinoModalPopup(
          context: context,
          builder: (_) => const AddBudgetModal(),
        );
        break;
      case 'goal':
        showCupertinoModalPopup(
          context: context,
          builder: (_) => const AddGoalModal(),
        );
        break;
    }
  }

  void _syncSteps(
    EngagementService eng,
    AccountsController accCtrl,
    TransactionsController txCtrl,
    BudgetsController budgetCtrl,
    GoalsController goalCtrl,
  ) {
    // Step 1: account
    if (accCtrl.accounts.isNotEmpty) {
      eng.markOnboardingStep('account');
    }

    // Step 2: transaction
    if (txCtrl.transactions.isNotEmpty) {
      eng.markOnboardingStep('transaction');
    }

    // Step 3: income
    if (txCtrl.transactions.any((tx) =>
        tx.type == TransactionType.income ||
        tx.type == TransactionType.cashback)) {
      eng.markOnboardingStep('income');
    }

    // Step 4: budget
    if (budgetCtrl.budgets.isNotEmpty) {
      eng.markOnboardingStep('budget');
    }

    // Step 5: goal
    if (goalCtrl.activeGoals.isNotEmpty) {
      eng.markOnboardingStep('goal');
    }
  }
}

class _OnboardStep {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;

  const _OnboardStep({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}
