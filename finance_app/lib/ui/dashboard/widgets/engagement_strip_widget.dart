import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/accounts_controller.dart';
import 'package:vittara_fin_os/logic/budgets_controller.dart';
import 'package:vittara_fin_os/logic/engagement_service.dart';
import 'package:vittara_fin_os/logic/goals_controller.dart';
import 'package:vittara_fin_os/logic/investments_controller.dart';
import 'package:vittara_fin_os/logic/transactions_controller.dart';
import 'package:vittara_fin_os/logic/transaction_model.dart';
import 'package:vittara_fin_os/logic/budget_model.dart';
import 'package:vittara_fin_os/logic/goal_model.dart';
import 'package:vittara_fin_os/ui/manage/account_wizard.dart';
import 'package:vittara_fin_os/ui/manage/budgets/modals/add_budget_modal.dart';
import 'package:vittara_fin_os/ui/manage/goals/modals/add_goal_modal.dart';
import 'package:vittara_fin_os/ui/manage/investments_screen.dart';
import 'package:vittara_fin_os/ui/manage/ai_planner/ai_monthly_planner_screen.dart';
import 'package:vittara_fin_os/ui/manage_screen.dart';
import 'package:vittara_fin_os/ui/settings_screen.dart';
import 'package:vittara_fin_os/ui/manage/reports_analysis_screen.dart';
import 'package:vittara_fin_os/ui/financial_calendar_screen.dart';
import 'package:vittara_fin_os/ui/settings/csv_import_screen.dart';
import 'package:vittara_fin_os/ui/engagement/achievements_screen.dart';
import 'package:vittara_fin_os/ui/widgets/monthly_statement_sheet.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/widgets/animations.dart';
import 'package:vittara_fin_os/utils/date_formatter.dart';
import 'package:vittara_fin_os/services/usage_tracker_service.dart';
import 'package:vittara_fin_os/ui/transaction_history_screen.dart';
import 'package:vittara_fin_os/ui/manage/budgets/budgets_screen.dart';

// ---------------------------------------------------------------------------
// EngagementStripWidget — single compact row replacing the two tall cards.
// Left pill = onboarding progress (taps → bottom sheet with steps).
// Right pill = next-move action (taps → action directly).
// When nothing to show → zero height.
// ---------------------------------------------------------------------------

class EngagementStripWidget extends StatelessWidget {
  const EngagementStripWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer6<
        EngagementService,
        AccountsController,
        TransactionsController,
        BudgetsController,
        GoalsController,
        InvestmentsController>(
      builder: (context, eng, accCtrl, txCtrl, budgetCtrl, goalCtrl,
          invCtrl, _) {
        final showOnboarding = eng.isOnboardingVisible;
        final move = _computeNextMove(
          context: context,
          accounts: accCtrl.accounts,
          budgets: budgetCtrl.budgets,
          goals: goalCtrl.activeGoals,
          investments: invCtrl.investments,
          transactions: txCtrl.transactions,
        );
        final showNextMove = move != null;

        return Padding(
          padding: const EdgeInsets.fromLTRB(
              Spacing.lg, Spacing.sm, Spacing.lg, 0),
          child: Row(
            children: [
              if (showOnboarding) ...[
                Expanded(
                  child: _OnboardingPill(eng: eng, txCtrl: txCtrl,
                      budgetCtrl: budgetCtrl, goalCtrl: goalCtrl,
                      accCtrl: accCtrl),
                ),
                const SizedBox(width: Spacing.sm),
              ],
              if (showNextMove) ...[
                Expanded(
                  child: _NextMovePill(move: move),
                ),
                const SizedBox(width: Spacing.sm),
              ],
              Expanded(
                child: const _QuickAccessPill(),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Onboarding pill
// ---------------------------------------------------------------------------

class _OnboardingPill extends StatelessWidget {
  final EngagementService eng;
  final TransactionsController txCtrl;
  final BudgetsController budgetCtrl;
  final GoalsController goalCtrl;
  final AccountsController accCtrl;

  const _OnboardingPill({
    required this.eng,
    required this.txCtrl,
    required this.budgetCtrl,
    required this.goalCtrl,
    required this.accCtrl,
  });

  @override
  Widget build(BuildContext context) {
    final done = eng.onboardingStepCount;
    const total = 5;
    final frac = done / total;

    return BouncyButton(
      onPressed: () => _showSetupSheet(context),
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(
            horizontal: Spacing.md, vertical: 0),
        decoration: BoxDecoration(
          color: AppStyles.aetherTeal.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(Radii.full),
          border: Border.all(
              color: AppStyles.aetherTeal.withValues(alpha: 0.22),
              width: 0.8),
        ),
        child: Row(
          children: [
            Icon(CupertinoIcons.checkmark_shield_fill,
                size: 13, color: AppStyles.aetherTeal),
            const SizedBox(width: 5),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Setup $done/$total',
                    style: TextStyle(
                      fontSize: TypeScale.caption,
                      fontWeight: FontWeight.w700,
                      color: AppStyles.aetherTeal,
                    ),
                  ),
                  const SizedBox(height: 2),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(Radii.full),
                    child: Stack(
                      children: [
                        Container(
                          height: 3,
                          color: AppStyles.aetherTeal.withValues(alpha: 0.15),
                        ),
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.0, end: frac),
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.easeOutCubic,
                          builder: (_, v, __) => FractionallySizedBox(
                            widthFactor: v,
                            child: Container(
                              height: 3,
                              decoration: BoxDecoration(
                                color: AppStyles.aetherTeal,
                                borderRadius:
                                    BorderRadius.circular(Radii.full),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Icon(CupertinoIcons.chevron_right,
                size: 10,
                color: AppStyles.aetherTeal.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }

  void _showSetupSheet(BuildContext context) {
    // Sync steps before showing
    if (accCtrl.accounts.isNotEmpty) eng.markOnboardingStep('account');
    if (txCtrl.transactions.isNotEmpty) eng.markOnboardingStep('transaction');
    if (txCtrl.transactions.any((tx) =>
        tx.type == TransactionType.income ||
        tx.type == TransactionType.cashback)) {
      eng.markOnboardingStep('income');
    }
    if (budgetCtrl.budgets.isNotEmpty) eng.markOnboardingStep('budget');
    if (goalCtrl.activeGoals.isNotEmpty) eng.markOnboardingStep('goal');

    showCupertinoModalPopup(
      context: context,
      builder: (_) => _SetupSheet(eng: eng, parentContext: context),
    );
  }
}

// ---------------------------------------------------------------------------
// Setup bottom sheet (full checklist)
// ---------------------------------------------------------------------------

class _SetupSheet extends StatelessWidget {
  final EngagementService eng;
  final BuildContext parentContext;

  static const _steps = [
    _StepDef('account', 'Add a bank account',
        CupertinoIcons.building_2_fill),
    _StepDef('transaction', 'Log your first transaction',
        CupertinoIcons.arrow_right_arrow_left_circle_fill),
    _StepDef('income', 'Record your income',
        CupertinoIcons.arrow_down_circle_fill),
    _StepDef('budget', 'Create a budget',
        CupertinoIcons.chart_pie_fill),
    _StepDef('goal', 'Set a financial goal',
        CupertinoIcons.flag_fill),
  ];

  const _SetupSheet({required this.eng, required this.parentContext});

  @override
  Widget build(BuildContext context) {
    final done = eng.onboardingStepCount;
    final frac = done / 5.0;

    return Container(
      decoration: BoxDecoration(
        color: AppStyles.getBackground(context),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(Radii.xxl),
          topRight: Radius.circular(Radii.xxl),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(Spacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppStyles.getSecondaryTextColor(context)
                        .withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(Radii.full),
                  ),
                ),
              ),
              const SizedBox(height: Spacing.lg),
              Row(
                children: [
                  Text(
                    'Set up VittaraFinOS',
                    style: TextStyle(
                      fontSize: TypeScale.headline,
                      fontWeight: FontWeight.w800,
                      color: AppStyles.getTextColor(context),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '$done/5',
                    style: const TextStyle(
                      fontSize: TypeScale.headline,
                      fontWeight: FontWeight.w800,
                      color: AppStyles.aetherTeal,
                    ),
                  ),
                  const SizedBox(width: Spacing.sm),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    onPressed: () {
                      Navigator.pop(context);
                      eng.dismissOnboarding();
                    },
                    child: Icon(
                      CupertinoIcons.xmark_circle,
                      size: 20,
                      color: AppStyles.getSecondaryTextColor(context)
                          .withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Spacing.sm),
              ClipRRect(
                borderRadius: BorderRadius.circular(Radii.full),
                child: Stack(
                  children: [
                    Container(
                        height: 5,
                        color: AppStyles.aetherTeal
                            .withValues(alpha: 0.12)),
                    FractionallySizedBox(
                      widthFactor: frac,
                      child: Container(
                        height: 5,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [
                            AppStyles.aetherTeal,
                            AppStyles.accentBlue,
                          ]),
                          borderRadius: BorderRadius.circular(Radii.full),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Spacing.lg),
              ..._steps.map((step) {
                final isDone = eng.isOnboardingStepDone(step.id);
                return _buildRow(context, step, isDone);
              }),
              const SizedBox(height: Spacing.md),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow(BuildContext context, _StepDef step, bool isDone) {
    final color = isDone
        ? AppStyles.aetherTeal
        : AppStyles.getSecondaryTextColor(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.sm),
      child: BouncyButton(
        onPressed: isDone
            ? () {}
            : () {
                Navigator.pop(context);
                _handleStep(parentContext, step);
              },
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
              Icon(step.icon, size: 15, color: color),
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
                    decorationColor: AppStyles.getSecondaryTextColor(context),
                  ),
                ),
              ),
              if (!isDone)
                Icon(CupertinoIcons.chevron_right,
                    size: 11,
                    color: AppStyles.getSecondaryTextColor(context)
                        .withValues(alpha: 0.4)),
            ],
          ),
        ),
      ),
    );
  }

  void _handleStep(BuildContext ctx, _StepDef step) {
    switch (step.id) {
      case 'account':
        showCupertinoModalPopup(
            context: ctx, builder: (_) => AccountWizard());
        break;
      case 'budget':
        showCupertinoModalPopup(
            context: ctx, builder: (_) => const AddBudgetModal());
        break;
      case 'goal':
        showCupertinoModalPopup(
            context: ctx, builder: (_) => const AddGoalModal());
        break;
      default:
        break;
    }
  }
}

class _StepDef {
  final String id;
  final String title;
  final IconData icon;
  const _StepDef(this.id, this.title, this.icon);
}

// ---------------------------------------------------------------------------
// Quick Access pill + sheet
// ---------------------------------------------------------------------------

class _QuickAccessPill extends StatelessWidget {
  const _QuickAccessPill();

  @override
  Widget build(BuildContext context) {
    return BouncyButton(
      onPressed: () => _showQuickAccessSheet(context),
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
        decoration: BoxDecoration(
          color: AppStyles.novaPurple.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(Radii.full),
          border: Border.all(
              color: AppStyles.novaPurple.withValues(alpha: 0.22), width: 0.8),
        ),
        child: Row(
          children: [
            Icon(CupertinoIcons.bolt_fill,
                size: 13, color: AppStyles.novaPurple),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                'Quick Access',
                style: TextStyle(
                  fontSize: TypeScale.caption,
                  fontWeight: FontWeight.w700,
                  color: AppStyles.novaPurple,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(CupertinoIcons.chevron_right,
                size: 10,
                color: AppStyles.novaPurple.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }

  void _showQuickAccessSheet(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    if (isLandscape) {
      // In landscape, a bottom sheet is too short — use a centered dialog instead
      showCupertinoDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (_) => _QuickAccessSheet(
          parentContext: context,
          isLandscapeDialog: true,
        ),
      );
    } else {
      showCupertinoModalPopup<void>(
        context: context,
        builder: (_) => _QuickAccessSheet(parentContext: context),
      );
    }
  }
}

class _QuickAccessSheet extends StatefulWidget {
  final BuildContext parentContext;
  final bool isLandscapeDialog;
  const _QuickAccessSheet({
    required this.parentContext,
    this.isLandscapeDialog = false,
  });

  @override
  State<_QuickAccessSheet> createState() => _QuickAccessSheetState();
}

class _QuickAccessSheetState extends State<_QuickAccessSheet> {
  static const _defaultRoutes = [
    '/transactions', '/budgets', '/calendar', '/investments'
  ];

  List<_QAItem> _allItems(BuildContext context) => [
    _QAItem('Transactions', CupertinoIcons.arrow_right_arrow_left_circle_fill, SemanticColors.info,
        () => Navigator.of(widget.parentContext).push(FadeScalePageRoute(page: const TransactionHistoryScreen()))),
    _QAItem('Budgets', CupertinoIcons.chart_bar_fill, AppStyles.novaPurple,
        () => Navigator.of(widget.parentContext).push(FadeScalePageRoute(page: const BudgetsScreen()))),
    _QAItem('Calendar', CupertinoIcons.calendar_badge_plus, AppStyles.aetherTeal,
        () => Navigator.of(widget.parentContext).push(FadeScalePageRoute(page: const FinancialCalendarScreen()))),
    _QAItem('Investments', CupertinoIcons.graph_square_fill, SemanticColors.investments,
        () => Navigator.of(widget.parentContext).push(FadeScalePageRoute(page: const InvestmentsScreen()))),
    _QAItem('Manage', CupertinoIcons.square_grid_2x2_fill, SemanticColors.accounts,
        () => Navigator.of(widget.parentContext).push(FadeScalePageRoute(page: const ManageScreen()))),
    _QAItem('Settings', CupertinoIcons.settings_solid, SemanticColors.tags,
        () => Navigator.of(widget.parentContext).push(FadeScalePageRoute(page: const SettingsScreen()))),
    _QAItem('Reports', CupertinoIcons.chart_bar_square_fill, SemanticColors.info,
        () => Navigator.of(widget.parentContext).push(FadeScalePageRoute(page: const ReportsAnalysisScreen()))),
    _QAItem('Statement', CupertinoIcons.doc_text_fill, SemanticColors.primary,
        () => showMonthlyStatementSheet(widget.parentContext)),
    _QAItem('Import', CupertinoIcons.arrow_down_doc_fill, AppStyles.accentTeal,
        () => Navigator.of(widget.parentContext).push(FadeScalePageRoute(page: const CsvImportScreen()))),
    _QAItem('Achievements', CupertinoIcons.star_fill, AppStyles.solarGold,
        () => Navigator.of(widget.parentContext).push(FadeScalePageRoute(page: const AchievementsScreen()))),
  ];

  static const _labelToRoute = {
    'Transactions': '/transactions',
    'Budgets': '/budgets',
    'Calendar': '/calendar',
    'Investments': '/investments',
    'Manage': '/manage',
    'Settings': '/settings',
    'Reports': '/reports',
    'Statement': '/statement',
    'Import': '/import',
    'Achievements': '/achievements',
  };

  @override
  Widget build(BuildContext context) {
    final isDark = AppStyles.isDarkMode(context);

    return FutureBuilder<_QuickItemResult>(
      future: _resolveItems(context),
      builder: (context, snap) {
        final items = snap.data?.items ?? _fallbackItems(context);
        final isDynamic = snap.data?.isDynamic ?? false;
        return _buildSheet(context, isDark, items, isDynamic);
      },
    );
  }

  Future<_QuickItemResult> _resolveItems(BuildContext context) async {
    final days = await UsageTrackerService.instance.daysSinceFirstUse();
    if (days < 7) {
      return _QuickItemResult(items: _fallbackItems(context), isDynamic: false);
    }
    final topRoutes = await UsageTrackerService.instance.topRoutes(4);
    final all = _allItems(context);
    final routeToItem = {
      for (final item in all)
        _labelToRoute[item.label] ?? '': item,
    };
    final dynamic = topRoutes
        .map((r) => routeToItem[r])
        .whereType<_QAItem>()
        .toList();
    if (dynamic.length < 4) {
      // pad with defaults not already included
      for (final item in _fallbackItems(context)) {
        if (!dynamic.any((i) => i.label == item.label)) dynamic.add(item);
        if (dynamic.length >= 4) break;
      }
    }
    return _QuickItemResult(items: dynamic.take(4).toList(), isDynamic: true);
  }

  List<_QAItem> _fallbackItems(BuildContext context) {
    final all = _allItems(context);
    return all.where((i) => _defaultRoutes.contains(_labelToRoute[i.label])).toList();
  }

  Widget _buildSheet(BuildContext context, bool isDark, List<_QAItem> items, bool isDynamic) {

    Widget sheetContent = Padding(
      padding: const EdgeInsets.all(Spacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle (portrait only)
          if (!widget.isLandscapeDialog)
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: Spacing.lg),
                decoration: BoxDecoration(
                  color: AppStyles.getSecondaryTextColor(context)
                      .withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(Radii.full),
                ),
              ),
            ),
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppStyles.novaPurple.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(CupertinoIcons.bolt_fill,
                    size: 15, color: AppStyles.novaPurple),
              ),
              const SizedBox(width: Spacing.md),
              Text(
                'Quick Access',
                style: TextStyle(
                  fontSize: TypeScale.headline,
                  fontWeight: FontWeight.w800,
                  color: AppStyles.getTextColor(context),
                ),
              ),
              const Spacer(),
              CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                onPressed: () => Navigator.pop(context),
                child: Icon(
                  CupertinoIcons.xmark_circle,
                  size: 20,
                  color: AppStyles.getSecondaryTextColor(context)
                      .withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.xl),
          // Landscape: single row; portrait: 4-column grid
          if (widget.isLandscapeDialog)
            Row(
              children: items.map((item) {
                return Expanded(
                  child: BouncyButton(
                    onPressed: () {
                      Navigator.pop(context);
                      item.onTap();
                    },
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: item.color
                                .withValues(alpha: isDark ? 0.15 : 0.10),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: item.color
                                  .withValues(alpha: isDark ? 0.25 : 0.18),
                              width: 1,
                            ),
                          ),
                          child: Icon(item.icon, color: item.color, size: 20),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          item.label,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppStyles.getTextColor(context),
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            )
          else
            GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: Spacing.md,
                crossAxisSpacing: Spacing.md,
                childAspectRatio: 0.88,
              ),
              itemCount: items.length,
              itemBuilder: (ctx, i) {
                final item = items[i];
                return BouncyButton(
                  onPressed: () {
                    Navigator.pop(context);
                    item.onTap();
                  },
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: item.color
                              .withValues(alpha: isDark ? 0.15 : 0.10),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: item.color
                                .withValues(alpha: isDark ? 0.25 : 0.18),
                            width: 1,
                          ),
                        ),
                        child: Icon(item.icon, color: item.color, size: 22),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: TypeScale.caption,
                          fontWeight: FontWeight.w600,
                          color: AppStyles.getTextColor(context),
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                );
              },
            ),
          const SizedBox(height: Spacing.md),
        ],
      ),
    );

    if (widget.isLandscapeDialog) {
      // Centered card dialog for landscape
      return Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 560,
            margin: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: AppStyles.getBackground(context),
              borderRadius: BorderRadius.circular(Radii.xxl),
              border: Border.all(
                color: AppStyles.novaPurple.withValues(alpha: 0.15),
                width: 1,
              ),
            ),
            child: sheetContent,
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppStyles.getBackground(context),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(Radii.xxl),
          topRight: Radius.circular(Radii.xxl),
        ),
      ),
      child: SafeArea(top: false, child: sheetContent),
    );
  }
}

class _QuickItemResult {
  final List<_QAItem> items;
  final bool isDynamic;
  const _QuickItemResult({required this.items, required this.isDynamic});
}

class _QAItem {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _QAItem(this.label, this.icon, this.color, this.onTap);
}

// ---------------------------------------------------------------------------
// Next-move pill
// ---------------------------------------------------------------------------

class _NextMovePill extends StatelessWidget {
  final _NextMoveItem move;
  const _NextMovePill({required this.move});

  @override
  Widget build(BuildContext context) {
    return BouncyButton(
      onPressed: move.onAction,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(
            horizontal: Spacing.md, vertical: 0),
        decoration: BoxDecoration(
          color: move.color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(Radii.full),
          border: Border.all(
              color: move.color.withValues(alpha: 0.22), width: 0.8),
        ),
        child: Row(
          children: [
            Icon(move.icon, size: 13, color: move.color),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                move.shortTitle,
                style: TextStyle(
                  fontSize: TypeScale.caption,
                  fontWeight: FontWeight.w700,
                  color: move.color,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(CupertinoIcons.chevron_right,
                size: 10,
                color: move.color.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Next-move computation (shared logic — same rules as next_move_widget.dart
// but returns null when nothing to show)
// ---------------------------------------------------------------------------

class _NextMoveItem {
  final String shortTitle; // compact label for pill
  final String title;
  final String body;
  final IconData icon;
  final Color color;
  final VoidCallback onAction;

  const _NextMoveItem({
    required this.shortTitle,
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

  if (!hasAccounts) {
    return _NextMoveItem(
      shortTitle: 'Add bank account',
      title: 'Add your first account',
      body: 'Link a bank account to see your real financial picture.',
      icon: CupertinoIcons.building_2_fill,
      color: AppStyles.accentBlue,
      onAction: () => showCupertinoModalPopup(
        context: context,
        builder: (_) => AccountWizard(),
      ),
    );
  }

  if (budgets.isEmpty) {
    final catSpend = <String, double>{};
    for (final tx in transactions) {
      if (tx is Transaction && tx.type == TransactionType.expense) {
        final cat = tx.metadata?['categoryName'] as String? ?? 'General';
        catSpend[cat] = (catSpend[cat] ?? 0) + tx.amount;
      }
    }
    final topCat = catSpend.isEmpty
        ? 'Food & Dining'
        : (catSpend.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value)))
            .first
            .key;
    return _NextMoveItem(
      shortTitle: 'Create budget',
      title: 'Create your first budget',
      body: 'No spending limit set. Start with $topCat.',
      icon: CupertinoIcons.chart_pie_fill,
      color: SemanticColors.primary,
      onAction: () => showCupertinoModalPopup(
        context: context,
        builder: (_) => const AddBudgetModal(),
      ),
    );
  }

  if (goals.isEmpty) {
    return _NextMoveItem(
      shortTitle: 'Set a goal',
      title: 'Set your first financial goal',
      body: 'People with written goals save 2.4× more.',
      icon: CupertinoIcons.flag_fill,
      color: SemanticColors.success,
      onAction: () => showCupertinoModalPopup(
        context: context,
        builder: (_) => const AddGoalModal(),
      ),
    );
  }

  if (investments.isEmpty) {
    return _NextMoveItem(
      shortTitle: 'Start investing',
      title: 'Start investing',
      body: 'Even ₹500 in an FD beats cash sitting idle.',
      icon: CupertinoIcons.graph_circle_fill,
      color: SemanticColors.investments,
      onAction: () => Navigator.of(context)
          .push(FadeScalePageRoute(page: const InvestmentsScreen())),
    );
  }

  final hasEmergencyGoal =
      (goals as List<Goal>).any((g) => g.type == GoalType.emergency);
  if (!hasEmergencyGoal) {
    return _NextMoveItem(
      shortTitle: 'Emergency fund',
      title: 'Create an Emergency Fund',
      body: 'No safety net yet. Advisors recommend 6 months of expenses.',
      icon: CupertinoIcons.shield_fill,
      color: AppStyles.accentOrange,
      onAction: () => showCupertinoModalPopup(
        context: context,
        builder: (_) => const AddGoalModal(),
      ),
    );
  }

  if (!hasIncome) {
    return _NextMoveItem(
      shortTitle: 'Log income',
      title: 'Log your income',
      body: 'Without income data, savings rate can\'t be computed.',
      icon: CupertinoIcons.arrow_down_circle_fill,
      color: AppStyles.accentGreen,
      onAction: () {},
    );
  }

  final exceededBudgets = (budgets as List<Budget>)
      .where((b) => b.status == BudgetStatus.exceeded);
  if (exceededBudgets.isNotEmpty) {
    final b = exceededBudgets.first;
    final overBy = b.spentAmount - b.limitAmount;
    return _NextMoveItem(
      shortTitle: '${b.name} exceeded',
      title: 'Budget exceeded: ${b.name}',
      body: '${CurrencyFormatter.format(overBy, decimals: 0)} over limit.',
      icon: CupertinoIcons.exclamationmark_triangle_fill,
      color: SemanticColors.error,
      onAction: () {},
    );
  }

  final offTrackGoals = (goals as List<Goal>)
      .where((g) => !g.isOnTrack && !g.isCompleted);
  if (offTrackGoals.isNotEmpty) {
    final g = offTrackGoals.first;
    return _NextMoveItem(
      shortTitle: '"${g.name}" off-track',
      title: 'Goal "${g.name}" is off-track',
      body: '${CurrencyFormatter.format(g.remainingAmount, decimals: 0)} remaining.',
      icon: CupertinoIcons.time_solid,
      color: SemanticColors.warning,
      onAction: () {},
    );
  }

  // Default: build AI plan
  return _NextMoveItem(
    shortTitle: 'Build AI plan',
    title: 'Build your financial plan',
    body: 'AI turns your goals into a monthly savings action.',
    icon: CupertinoIcons.wand_stars,
    color: AppStyles.novaPurple,
    onAction: () => Navigator.of(context).push(
      FadeScalePageRoute(page: const AIMonthlyPlannerScreen()),
    ),
  );
}
