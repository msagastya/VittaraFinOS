import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/accounts_controller.dart';
import 'package:vittara_fin_os/logic/ai_planner_context.dart';
import 'package:vittara_fin_os/logic/ai_planner_engine.dart';
import 'package:vittara_fin_os/logic/budgets_controller.dart';
import 'package:vittara_fin_os/logic/goals_controller.dart';
import 'package:vittara_fin_os/logic/investments_controller.dart';
import 'package:vittara_fin_os/logic/ml_planner_engine.dart';
import 'package:vittara_fin_os/logic/transactions_controller.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/utils/date_formatter.dart';
import 'package:vittara_fin_os/utils/id_generator.dart';
import 'package:vittara_fin_os/ui/styles/responsive_utils.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

Color _planColor(PlanningFocus focus) {
  switch (focus) {
    case PlanningFocus.emergencyFund:   return AppStyles.accentGreen;
    case PlanningFocus.homeDownPayment: return AppStyles.accentBlue;
    case PlanningFocus.debtPayoff:      return AppStyles.accentOrange;
    case PlanningFocus.retirement:      return AppStyles.accentPurple;
    case PlanningFocus.education:       return AppStyles.aetherTeal;
    case PlanningFocus.wedding:         return AppStyles.accentCoral;
    case PlanningFocus.travel:          return AppStyles.accentAmber;
    case PlanningFocus.investment:      return AppStyles.aetherTeal;
    case PlanningFocus.custom:          return AppStyles.accentOrange;
  }
}

IconData _planIcon(PlanningFocus focus) {
  switch (focus) {
    case PlanningFocus.emergencyFund:   return CupertinoIcons.shield_fill;
    case PlanningFocus.homeDownPayment: return CupertinoIcons.house_fill;
    case PlanningFocus.debtPayoff:      return CupertinoIcons.creditcard_fill;
    case PlanningFocus.retirement:      return CupertinoIcons.person_fill;
    case PlanningFocus.education:       return CupertinoIcons.book_fill;
    case PlanningFocus.wedding:         return CupertinoIcons.heart_fill;
    case PlanningFocus.travel:          return CupertinoIcons.airplane;
    case PlanningFocus.investment:      return CupertinoIcons.chart_bar_alt_fill;
    case PlanningFocus.custom:          return CupertinoIcons.star_fill;
  }
}

String _monthName(int month) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return months[(month - 1).clamp(0, 11)];
}

// ─────────────────────────────────────────────────────────────────────────────
// Progress ring painter
// ─────────────────────────────────────────────────────────────────────────────

class _RingPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color progressColor;
  final double strokeWidth;

  const _RingPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
    this.strokeWidth = 5,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawArc(
      rect, 0, math.pi * 2, false,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );
    if (progress > 0) {
      canvas.drawArc(
        rect, -math.pi / 2, progress.clamp(0, 1) * math.pi * 2, false,
        Paint()
          ..color = progressColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.progressColor != progressColor;
}

// ─────────────────────────────────────────────────────────────────────────────
// Main screen — plans list
// ─────────────────────────────────────────────────────────────────────────────

class AIMonthlyPlannerScreen extends StatelessWidget {
  const AIMonthlyPlannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: AppStyles.isLandscape(context)
          ? null
          : CupertinoNavigationBar(
              middle: const Text('Financial Plans'),
              previousPageTitle: 'Back',
              backgroundColor: AppStyles.getBackground(context),
              border: null,
              trailing: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => _openWizard(context, existing: null),
                child: const Icon(CupertinoIcons.add, size: 22,
                    color: AppStyles.aetherTeal),
              ),
            ),
      child: SafeArea(
        child: Consumer<FinancialPlansController>(
          builder: (context, ctrl, _) {
            if (!ctrl.loaded) {
              return const Center(child: CupertinoActivityIndicator());
            }
            if (ctrl.plans.isEmpty) {
              return _EmptyState(
                  onTap: () => _openWizard(context, existing: null));
            }
            return _PlansList(
              plans: ctrl.plans,
              onAdd: () => _openWizard(context, existing: null),
              onAddWithFocus: (focus) =>
                  _openWizard(context, existing: null, initialFocus: focus),
            );
          },
        ),
      ),
    );
  }

  void _openWizard(BuildContext context,
      {required FinancialPlan? existing, PlanningFocus? initialFocus}) {
    final ctrl = context.read<FinancialPlansController>();
    final txCtrl = context.read<TransactionsController>();
    final mlAnalysis = MLPlannerEngine.analyze(transactions: txCtrl.transactions, currentSaved: 0);
    showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => RLayout.tabletConstrain(
        _,
        _PlanWizardSheet(
          existing: existing,
          mlAnalysis: mlAnalysis,
          initialFocus: initialFocus,
          onSaved: (plan) {
            if (existing == null) {
              ctrl.add(plan);
            } else {
              ctrl.update(plan);
            }
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty state — onboarding for first-time users
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onTap;
  const _EmptyState({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(Spacing.xl),
      children: [
        const SizedBox(height: Spacing.xl),
        Center(
          child: Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppStyles.aetherTeal.withValues(alpha: 0.20),
                  AppStyles.accentPurple.withValues(alpha: 0.15),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(CupertinoIcons.chart_bar_fill,
                size: 40, color: AppStyles.aetherTeal),
          ),
        ),
        const SizedBox(height: Spacing.xl),
        Text(
          'Your Financial Plans',
          style: TextStyle(
            fontSize: RT.title1(context),
            fontWeight: FontWeight.w800,
            color: AppStyles.getTextColor(context),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: Spacing.md),
        Text(
          'Know exactly where you stand on every financial goal — not just one.',
          style: TextStyle(
            fontSize: TypeScale.body,
            color: AppStyles.getSecondaryTextColor(context),
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: Spacing.xl),
        // Feature bullets
        ..._features(context),
        const SizedBox(height: Spacing.xl),
        SizedBox(
          width: double.infinity,
          child: CupertinoButton.filled(
            borderRadius: BorderRadius.circular(Radii.lg),
            onPressed: onTap,
            child: const Text('Create Your First Plan',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }

  List<Widget> _features(BuildContext context) {
    final items = [
      (CupertinoIcons.flag_fill, AppStyles.aetherTeal,
          'Track multiple goals at once',
          'Emergency fund, home, retirement, travel — each with its own timeline and target.'),
      (CupertinoIcons.chart_bar_alt_fill, AppStyles.accentBlue,
          'See exactly if you\'re on track',
          'The planner checks your actual savings rate and tells you if you\'ll hit each goal on time.'),
      (CupertinoIcons.lightbulb_fill, AppStyles.accentOrange,
          'Get a concrete action every month',
          'No vague advice — you\'ll see exactly how much more to save this month.'),
    ];

    return items.map((item) {
      final (icon, color, title, body) = item;
      return Padding(
        padding: const EdgeInsets.only(bottom: Spacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: Spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                        fontSize: TypeScale.callout,
                        fontWeight: FontWeight.w700,
                        color: AppStyles.getTextColor(context),
                      )),
                  const SizedBox(height: 2),
                  Text(body,
                      style: TextStyle(
                        fontSize: TypeScale.footnote,
                        color: AppStyles.getSecondaryTextColor(context),
                        height: 1.4,
                      )),
                ],
              ),
            ),
          ],
        ),
      );
    }).toList();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Plans list
// ─────────────────────────────────────────────────────────────────────────────

class _PlansList extends StatelessWidget {
  final List<FinancialPlan> plans;
  final VoidCallback onAdd;
  final void Function(PlanningFocus) onAddWithFocus;

  const _PlansList({
    required this.plans,
    required this.onAdd,
    required this.onAddWithFocus,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer5<TransactionsController, AccountsController,
        InvestmentsController, BudgetsController, GoalsController>(
      builder: (ctx, txCtrl, accCtrl, invCtrl, budCtrl, goalCtrl, _) {
        final mlAnalysis = MLPlannerEngine.analyze(transactions: txCtrl.transactions, currentSaved: 0);
        final suggestions = _computeSuggestions(plans, mlAnalysis);

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(
              Spacing.lg, Spacing.md, Spacing.lg, 100),
          itemCount: plans.length + 2, // +1 suggestions header, +1 Add Plan footer
          itemBuilder: (context, i) {
            // Index 0: Suggested Plans section
            if (i == 0) {
              if (suggestions.isEmpty) return const SizedBox.shrink();
              return _buildSuggestionsSection(context, suggestions);
            }

            final planIndex = i - 1;

            // Last item: Add Plan button
            if (planIndex == plans.length) {
              return Padding(
                padding: const EdgeInsets.only(top: Spacing.md),
                child: CupertinoButton(
                  padding: const EdgeInsets.symmetric(vertical: Spacing.md),
                  color: AppStyles.getCardColor(context),
                  borderRadius: BorderRadius.circular(Radii.lg),
                  onPressed: onAdd,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(CupertinoIcons.add,
                          size: 16, color: AppStyles.aetherTeal),
                      const SizedBox(width: Spacing.sm),
                      const Text('Add Plan',
                          style: TextStyle(
                              color: AppStyles.aetherTeal,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              );
            }

            final plan = plans[planIndex];
            final analysis = AIPlannerEngine.analyze(
              plan: plan,
              transactions: txCtrl.transactions,
              accounts: accCtrl.accounts,
              investments: invCtrl.investments,
              budgets: budCtrl.activeBudgets,
              goals: goalCtrl.activeGoals,
            );

            return Padding(
              padding: const EdgeInsets.only(bottom: Spacing.md),
              child: _PlanCard(
                plan: plan,
                analysis: analysis,
                onTap: () => Navigator.of(context).push(
                  CupertinoPageRoute(
                    builder: (_) => _PlanDetailScreen(planId: plan.id),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Build 2–3 suggested plans the user hasn't created yet.
  List<(PlanningFocus, String, String, Color, IconData)> _computeSuggestions(
      List<FinancialPlan> existing, MLAnalysis ml) {
    final existingFocuses = existing.map((p) => p.focus).toSet();
    final candidates = <(PlanningFocus, String, String, Color, IconData)>[
      (
        PlanningFocus.emergencyFund,
        'Build an Emergency Fund',
        ml.dataSufficient && ml.predictedExpenses != null
            ? '6-month cushion ≈ ${CurrencyFormatter.compact((ml.predictedExpenses! * 6))}'
            : 'A 3–6 month safety net is step one',
        AppStyles.accentGreen,
        CupertinoIcons.shield_fill,
      ),
      (
        PlanningFocus.retirement,
        'Start a Retirement Fund',
        'The earlier you start, the less you need to save each month',
        AppStyles.accentPurple,
        CupertinoIcons.person_fill,
      ),
      (
        PlanningFocus.investment,
        'Grow Your Money',
        ml.dataSufficient && (ml.predictedSavings ?? 0) > 0
            ? 'You save ~${CurrencyFormatter.compact(ml.predictedSavings!)} /mo — put it to work'
            : 'Invest your monthly surplus to beat inflation',
        AppStyles.aetherTeal,
        CupertinoIcons.chart_bar_alt_fill,
      ),
      (
        PlanningFocus.homeDownPayment,
        'Save for a Home',
        'Start building your down payment fund',
        AppStyles.accentBlue,
        CupertinoIcons.house_fill,
      ),
      (
        PlanningFocus.debtPayoff,
        'Pay Off Debt Faster',
        'Every extra rupee towards debt saves you interest',
        AppStyles.accentOrange,
        CupertinoIcons.creditcard_fill,
      ),
    ];

    return candidates
        .where((c) => !existingFocuses.contains(c.$1))
        .take(3)
        .toList();
  }

  Widget _buildSuggestionsSection(BuildContext context,
      List<(PlanningFocus, String, String, Color, IconData)> suggestions) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(CupertinoIcons.sparkles, size: 14,
                  color: AppStyles.aetherTeal),
              const SizedBox(width: 6),
              Text(
                'Suggested for you',
                style: TextStyle(
                  fontSize: TypeScale.footnote,
                  fontWeight: FontWeight.w700,
                  color: AppStyles.aetherTeal,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.sm),
          SizedBox(
            height: 108,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: suggestions.length,
              separatorBuilder: (_, __) => const SizedBox(width: Spacing.sm),
              itemBuilder: (context, i) {
                final (focus, title, desc, color, icon) = suggestions[i];
                return GestureDetector(
                  onTap: () => onAddWithFocus(focus),
                  child: Container(
                    width: 200,
                    padding: const EdgeInsets.all(Spacing.md),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(Radii.lg),
                      border: Border.all(
                          color: color.withValues(alpha: 0.25), width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(icon, size: 14, color: color),
                            ),
                            const SizedBox(width: Spacing.sm),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text('+ Start',
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: color)),
                            ),
                          ],
                        ),
                        const SizedBox(height: Spacing.sm),
                        Text(title,
                            style: TextStyle(
                              fontSize: TypeScale.caption,
                              fontWeight: FontWeight.w700,
                              color: AppStyles.getTextColor(context),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text(desc,
                            style: TextStyle(
                              fontSize: 10,
                              color: AppStyles.getSecondaryTextColor(context),
                              height: 1.35,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: Spacing.md),
          Divider(
            color: AppStyles.getSecondaryTextColor(context).withValues(alpha: 0.12),
            height: 1,
          ),
          const SizedBox(height: Spacing.md),
          Text(
            'Your plans',
            style: TextStyle(
              fontSize: TypeScale.footnote,
              fontWeight: FontWeight.w700,
              color: AppStyles.getSecondaryTextColor(context),
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: Spacing.sm),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Plan card (list item)
// ─────────────────────────────────────────────────────────────────────────────

class _PlanCard extends StatelessWidget {
  final FinancialPlan plan;
  final PlannerAnalysis analysis;
  final VoidCallback onTap;

  const _PlanCard(
      {required this.plan, required this.analysis, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = _planColor(plan.focus);
    final onTrack = analysis.isOnTrack;
    final statusColor = onTrack ? AppStyles.accentGreen : AppStyles.accentOrange;
    final hasTarget = plan.targetAmount != null && plan.targetAmount! > 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(Spacing.md),
        decoration: BoxDecoration(
          color: AppStyles.getCardColor(context),
          borderRadius: BorderRadius.circular(Radii.lg),
          border: Border.all(
              color: color.withValues(alpha: 0.15), width: 1),
        ),
        child: Row(
          children: [
            // Progress ring with icon
            SizedBox(
              width: 56,
              height: 56,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(56, 56),
                    painter: _RingPainter(
                      progress: analysis.actualProgressFraction,
                      trackColor: color.withValues(alpha: 0.12),
                      progressColor: color,
                      strokeWidth: 4,
                    ),
                  ),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: plan.emoji != null
                          ? Text(plan.emoji!,
                              style: const TextStyle(fontSize: 18))
                          : Icon(_planIcon(plan.focus),
                              size: 16, color: color),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Spacing.md),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(plan.name,
                            style: TextStyle(
                              fontSize: TypeScale.callout,
                              fontWeight: FontWeight.w700,
                              color: AppStyles.getTextColor(context),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: Spacing.sm),
                      // Priority dot
                      if (plan.priority == 1)
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                              color: AppStyles.accentOrange,
                              shape: BoxShape.circle),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      _chip(plan.focusLabel, color, context),
                      const SizedBox(width: 6),
                      _chip(plan.timelineLabel, AppStyles.getSecondaryTextColor(context), context),
                    ],
                  ),
                  const SizedBox(height: Spacing.sm),
                  // Progress bar (only if target set)
                  if (hasTarget) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: analysis.actualProgressFraction,
                        minHeight: 4,
                        backgroundColor:
                            color.withValues(alpha: 0.12),
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          CurrencyFormatter.compact(plan.currentSaved) +
                              ' of ' +
                              CurrencyFormatter.compact(plan.targetAmount!),
                          style: TextStyle(
                            fontSize: TypeScale.caption,
                            color: AppStyles.getSecondaryTextColor(context),
                          ),
                        ),
                        Text(
                          '${(analysis.actualProgressFraction * 100).toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: TypeScale.caption,
                            fontWeight: FontWeight.w700,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    // No target — show savings rate
                    Text(
                      analysis.monthlyIncome > 0
                          ? 'Saving ${(analysis.savingsRate * 100).toStringAsFixed(0)}% of income'
                          : 'No income data yet',
                      style: TextStyle(
                        fontSize: TypeScale.caption,
                        color: AppStyles.getSecondaryTextColor(context),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: Spacing.sm),
            // Status + chevron
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    onTrack ? 'On track' : 'Behind',
                    style: TextStyle(
                      fontSize: TypeScale.caption,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ),
                const SizedBox(height: Spacing.sm),
                Icon(CupertinoIcons.chevron_right,
                    size: 14,
                    color: AppStyles.getSecondaryTextColor(context)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, Color color, BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: TextStyle(
            fontSize: TypeScale.caption,
            color: color,
            fontWeight: FontWeight.w600,
          )),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Plan detail screen
// ─────────────────────────────────────────────────────────────────────────────

class _PlanDetailScreen extends StatelessWidget {
  final String planId;
  const _PlanDetailScreen({required this.planId});

  @override
  Widget build(BuildContext context) {
    return Consumer<FinancialPlansController>(
      builder: (context, plansCtrl, _) {
        final plan =
            plansCtrl.plans.where((p) => p.id == planId).firstOrNull;
        if (plan == null) {
          // Plan was deleted
          WidgetsBinding.instance
              .addPostFrameCallback((_) => Navigator.of(context).pop());
          return const SizedBox.shrink();
        }

        return CupertinoPageScaffold(
          navigationBar: AppStyles.isLandscape(context)
              ? null
              : CupertinoNavigationBar(
                  middle: Text(plan.name),
                  previousPageTitle: 'Plans',
                  backgroundColor: AppStyles.getBackground(context),
                  border: null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => _confirmDelete(context, plan, plansCtrl),
                        child: const Icon(CupertinoIcons.trash,
                            size: 18, color: AppStyles.plasmaRed),
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => _openWizard(context, plan, plansCtrl),
                        child: const Text('Edit',
                            style: TextStyle(color: AppStyles.aetherTeal)),
                      ),
                    ],
                  ),
                ),
          child: SafeArea(
            child: Consumer5<TransactionsController, AccountsController,
                InvestmentsController, BudgetsController, GoalsController>(
              builder: (ctx, txCtrl, accCtrl, invCtrl, budCtrl, goalCtrl, _) {
                final analysis = AIPlannerEngine.analyze(
                  plan: plan,
                  transactions: txCtrl.transactions,
                  accounts: accCtrl.accounts,
                  investments: invCtrl.investments,
                  budgets: budCtrl.activeBudgets,
                  goals: goalCtrl.activeGoals,
                );
                return _DetailBody(plan: plan, analysis: analysis);
              },
            ),
          ),
        );
      },
    );
  }

  void _openWizard(BuildContext context, FinancialPlan plan,
      FinancialPlansController ctrl) {
    final txCtrl = context.read<TransactionsController>();
    final mlAnalysis = MLPlannerEngine.analyze(transactions: txCtrl.transactions, currentSaved: 0);
    showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => RLayout.tabletConstrain(
        _,
        _PlanWizardSheet(
        existing: plan,
        mlAnalysis: mlAnalysis,
        onSaved: (updated) => ctrl.update(updated),
      ),
      ),
    );
  }

  void _confirmDelete(
      BuildContext context, FinancialPlan plan, FinancialPlansController ctrl) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text('Delete "${plan.name}"?'),
        content: const Text('This plan and all its data will be removed.'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.of(context).pop();
              ctrl.delete(plan.id);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Detail body — all the analysis sections
// ─────────────────────────────────────────────────────────────────────────────

class _DetailBody extends StatelessWidget {
  final FinancialPlan plan;
  final PlannerAnalysis analysis;

  const _DetailBody({required this.plan, required this.analysis});

  @override
  Widget build(BuildContext context) {
    final color = _planColor(plan.focus);
    final hasTarget = plan.targetAmount != null && plan.targetAmount! > 0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          Spacing.lg, Spacing.md, Spacing.lg, Spacing.xl),
      children: [
        _buildHeader(context, color),
        const SizedBox(height: Spacing.lg),
        _buildSummaryCard(context),
        const SizedBox(height: Spacing.lg),
        _buildMetricsRow(context, color),
        const SizedBox(height: Spacing.lg),
        _buildGapBanner(context),
        if (hasTarget) ...[
          const SizedBox(height: Spacing.lg),
          _buildProgressCard(context, color),
          const SizedBox(height: Spacing.lg),
          _buildMilestones(context, color),
        ],
        if (analysis.scenarioFasterSaveAmount != null) ...[
          const SizedBox(height: Spacing.lg),
          _buildScenarioCard(context),
        ],
        const SizedBox(height: Spacing.lg),
        _buildThisMonthCard(context),
        const SizedBox(height: Spacing.lg),
        _buildMLIntelligence(context),
        const SizedBox(height: Spacing.lg),
        _buildRecommendations(context),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, Color color) {
    return Container(
      padding: const EdgeInsets.all(Spacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.18),
            color.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          // Big icon / emoji
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: plan.emoji != null
                  ? Text(plan.emoji!, style: TextStyle(fontSize: RT.title1(context)))
                  : Icon(_planIcon(plan.focus), size: 26, color: color),
            ),
          ),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(plan.name,
                    style: TextStyle(
                      fontSize: RT.title2(context),
                      fontWeight: FontWeight.w800,
                      color: AppStyles.getTextColor(context),
                    )),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _chip(plan.focusLabel, color),
                    _chip(plan.timelineLabel, AppStyles.accentBlue),
                    if (plan.targetAmount != null && plan.targetAmount! > 0)
                      _chip(
                        CurrencyFormatter.compact(plan.targetAmount!) +
                            ' target',
                        AppStyles.accentAmber,
                      ),
                    _chip(
                      plan.priority == 1
                          ? '🔴 High priority'
                          : plan.priority == 3
                              ? '🟢 Low priority'
                              : '🟡 Medium priority',
                      AppStyles.getSecondaryTextColor(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(label,
          style: TextStyle(
            fontSize: TypeScale.caption,
            color: color,
            fontWeight: FontWeight.w600,
          )),
    );
  }

  Widget _buildSummaryCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Spacing.lg),
      decoration: BoxDecoration(
        color: AppStyles.getCardColor(context),
        borderRadius: BorderRadius.circular(Radii.lg),
      ),
      child: Text(analysis.summary,
          style: TextStyle(
            fontSize: TypeScale.callout,
            fontWeight: FontWeight.w500,
            color: AppStyles.getTextColor(context),
            height: 1.5,
          )),
    );
  }

  Widget _buildMetricsRow(BuildContext context, Color planColor) {
    return Row(
      children: [
        Expanded(
            child: _metricTile(context, 'Monthly Income',
                CurrencyFormatter.compact(analysis.monthlyIncome),
                AppStyles.accentGreen)),
        const SizedBox(width: Spacing.sm),
        Expanded(
            child: _metricTile(
                context,
                plan.monthlyContribution != null
                    ? 'Dedicated/mo'
                    : 'Avg Savings/mo',
                CurrencyFormatter.compact(analysis.effectiveMonthlySavings),
                planColor)),
        const SizedBox(width: Spacing.sm),
        Expanded(
            child: _metricTile(
                context,
                'Savings Rate',
                '${(analysis.savingsRate * 100).toStringAsFixed(0)}%',
                analysis.savingsRate >= 0.20
                    ? AppStyles.accentGreen
                    : AppStyles.accentOrange)),
      ],
    );
  }

  Widget _metricTile(
      BuildContext context, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: Spacing.sm, vertical: Spacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: TypeScale.subhead,
                  fontWeight: FontWeight.w800,
                  color: color)),
          const SizedBox(height: 3),
          Text(label,
              style: TextStyle(
                  fontSize: TypeScale.caption,
                  color: AppStyles.getSecondaryTextColor(context)),
              textAlign: TextAlign.center,
              maxLines: 2),
        ],
      ),
    );
  }

  Widget _buildGapBanner(BuildContext context) {
    final onTrack = analysis.isOnTrack;
    final color = onTrack ? AppStyles.accentGreen : AppStyles.accentOrange;
    final offSchedule = analysis.monthsOffSchedule;
    String label;
    if (onTrack) {
      label = 'On track ✓';
    } else if (analysis.savingsGap > 0) {
      label = '₹${_fmt(analysis.savingsGap)}/month more needed';
    } else {
      label = 'Review your plan';
    }
    String? subtitle;
    if (!onTrack && offSchedule != null && offSchedule > 0) {
      subtitle = '$offSchedule month${offSchedule == 1 ? '' : 's'} behind schedule';
    } else if (onTrack && offSchedule != null && offSchedule < 0) {
      subtitle = '${(-offSchedule)} month${(-offSchedule) == 1 ? '' : 's'} ahead of schedule';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
          horizontal: Spacing.lg, vertical: Spacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                onTrack
                    ? CupertinoIcons.checkmark_seal_fill
                    : CupertinoIcons.exclamationmark_circle_fill,
                size: 18,
                color: color,
              ),
              const SizedBox(width: Spacing.sm),
              Text(label,
                  style: TextStyle(
                    fontSize: TypeScale.callout,
                    fontWeight: FontWeight.w700,
                    color: color,
                  )),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 3),
            Text(subtitle,
                style: TextStyle(
                  fontSize: TypeScale.caption,
                  color: color.withValues(alpha: 0.80),
                )),
          ],
        ],
      ),
    );
  }

  Widget _buildProgressCard(BuildContext context, Color color) {
    final target = plan.targetAmount!;
    final saved = plan.currentSaved;
    final actual = analysis.actualProgressFraction;
    final projected = analysis.projectedProgressFraction;
    final completion = analysis.projectedCompletionDate;

    return Container(
      padding: const EdgeInsets.all(Spacing.lg),
      decoration: BoxDecoration(
        color: AppStyles.getCardColor(context),
        borderRadius: BorderRadius.circular(Radii.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Progress',
                  style: TextStyle(
                    fontSize: TypeScale.headline,
                    fontWeight: FontWeight.w700,
                    color: AppStyles.getTextColor(context),
                  )),
              if (completion != null)
                Text(
                  'Est. ${_monthName(completion.month)} ${completion.year}',
                  style: TextStyle(
                    fontSize: TypeScale.footnote,
                    color: AppStyles.getSecondaryTextColor(context),
                  ),
                ),
            ],
          ),
          const SizedBox(height: Spacing.md),
          // Dual progress bar: actual + projected
          Stack(
            children: [
              // Track
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: 1.0,
                  minHeight: 10,
                  backgroundColor:
                      color.withValues(alpha: 0.10),
                  valueColor: AlwaysStoppedAnimation<Color>(
                      color.withValues(alpha: 0.10)),
                ),
              ),
              // Projected (ghost)
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: projected,
                  minHeight: 10,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(
                      color.withValues(alpha: 0.25)),
                ),
              ),
              // Actual
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: actual,
                  minHeight: 10,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(CurrencyFormatter.compact(saved),
                      style: TextStyle(
                        fontSize: TypeScale.subhead,
                        fontWeight: FontWeight.w800,
                        color: color,
                      )),
                  Text('saved so far',
                      style: TextStyle(
                        fontSize: TypeScale.caption,
                        color: AppStyles.getSecondaryTextColor(context),
                      )),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(CurrencyFormatter.compact(target),
                      style: TextStyle(
                        fontSize: TypeScale.subhead,
                        fontWeight: FontWeight.w800,
                        color: AppStyles.getSecondaryTextColor(context),
                      )),
                  Text('target',
                      style: TextStyle(
                        fontSize: TypeScale.caption,
                        color: AppStyles.getSecondaryTextColor(context),
                      )),
                ],
              ),
            ],
          ),
          if (projected > actual) ...[
            const SizedBox(height: Spacing.sm),
            Row(
              children: [
                Container(
                    width: 10,
                    height: 4,
                    color: color.withValues(alpha: 0.25)),
                const SizedBox(width: 4),
                Text(
                  'Light bar = projected by ${plan.timelineLabel}',
                  style: TextStyle(
                    fontSize: TypeScale.caption,
                    color: AppStyles.getSecondaryTextColor(context),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMilestones(BuildContext context, Color color) {
    final upcoming = analysis.milestones.where((m) => !m.reached).toList();
    final reached = analysis.milestones.where((m) => m.reached).toList();
    if (analysis.milestones.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(Spacing.lg),
      decoration: BoxDecoration(
        color: AppStyles.getCardColor(context),
        borderRadius: BorderRadius.circular(Radii.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Milestones',
              style: TextStyle(
                fontSize: TypeScale.headline,
                fontWeight: FontWeight.w700,
                color: AppStyles.getTextColor(context),
              )),
          const SizedBox(height: Spacing.md),
          ...analysis.milestones.map((m) {
            final done = m.reached;
            final tileColor = done ? color : AppStyles.getSecondaryTextColor(context);
            return Padding(
              padding: const EdgeInsets.only(bottom: Spacing.sm),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: done
                          ? color.withValues(alpha: 0.15)
                          : AppStyles.getSecondaryTextColor(context)
                              .withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      done
                          ? CupertinoIcons.checkmark
                          : CupertinoIcons.flag,
                      size: 13,
                      color: tileColor,
                    ),
                  ),
                  const SizedBox(width: Spacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${m.label} — ${CurrencyFormatter.compact(m.amount)}',
                          style: TextStyle(
                            fontSize: TypeScale.footnote,
                            fontWeight: FontWeight.w600,
                            color: done
                                ? AppStyles.getTextColor(context)
                                : AppStyles.getSecondaryTextColor(context),
                            decoration: done
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        if (!done && m.estDate != null)
                          Text(
                            'Est. ${_monthName(m.estDate!.month)} ${m.estDate!.year}',
                            style: TextStyle(
                              fontSize: TypeScale.caption,
                              color: AppStyles.getSecondaryTextColor(context),
                            ),
                          ),
                        if (done)
                          Text('Reached ✓',
                              style: TextStyle(
                                fontSize: TypeScale.caption,
                                color: color,
                              )),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildScenarioCard(BuildContext context) {
    final saveMore = analysis.scenarioFasterSaveAmount!;
    final gainMonths = analysis.scenarioFasterGainMonths!;

    return Container(
      padding: const EdgeInsets.all(Spacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppStyles.accentPurple.withValues(alpha: 0.12),
            AppStyles.accentBlue.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(
            color: AppStyles.accentPurple.withValues(alpha: 0.20)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppStyles.accentPurple.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(CupertinoIcons.lightbulb_fill,
                size: 18, color: AppStyles.accentPurple),
          ),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('What if you saved more?',
                    style: TextStyle(
                      fontSize: TypeScale.footnote,
                      fontWeight: FontWeight.w700,
                      color: AppStyles.accentPurple,
                    )),
                const SizedBox(height: 3),
                Text(
                  'Saving ₹${_fmt(saveMore)} more/month '
                  '(+20%) would complete this plan '
                  '$gainMonths month${gainMonths == 1 ? '' : 's'} earlier.',
                  style: TextStyle(
                    fontSize: TypeScale.footnote,
                    color: AppStyles.getTextColor(context),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThisMonthCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Spacing.lg),
      decoration: BoxDecoration(
        color: AppStyles.aetherTeal.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(
            color: AppStyles.aetherTeal.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(CupertinoIcons.calendar_today,
              size: 18, color: AppStyles.aetherTeal),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('This Month\'s Action',
                    style: TextStyle(
                      fontSize: TypeScale.footnote,
                      fontWeight: FontWeight.w700,
                      color: AppStyles.aetherTeal,
                    )),
                const SizedBox(height: 3),
                Builder(
                  builder: (ctx) => Text(analysis.thisMonthAction,
                      style: TextStyle(
                        fontSize: TypeScale.callout,
                        color: AppStyles.getTextColor(ctx),
                        height: 1.4,
                      )),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── ML Intelligence section ───────────────────────────────────────────────

  Widget _buildMLIntelligence(BuildContext context) {
    final ml = analysis.ml;
    const headerColor = AppStyles.novaPurple;

    return Container(
      padding: const EdgeInsets.all(Spacing.lg),
      decoration: BoxDecoration(
        color: AppStyles.getCardColor(context),
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: headerColor.withValues(alpha: 0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: headerColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(CupertinoIcons.sparkles,
                    size: 15, color: headerColor),
              ),
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('ML Intelligence',
                        style: TextStyle(
                          fontSize: TypeScale.callout,
                          fontWeight: FontWeight.w700,
                          color: headerColor,
                        )),
                    Text(
                      ml.dataSufficient
                          ? 'Based on ${ml.dataMonths} months of your data'
                          : 'Learns from your transaction history',
                      style: TextStyle(
                        fontSize: TypeScale.caption,
                        color: AppStyles.getSecondaryTextColor(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (!ml.dataSufficient) ...[
            const SizedBox(height: Spacing.lg),
            _mlLockedState(context),
          ] else ...[
            const SizedBox(height: Spacing.lg),
            // Predicted savings
            if (ml.predictedSavings != null)
              _mlRow(
                context,
                icon: CupertinoIcons.arrow_right_circle_fill,
                color: AppStyles.accentBlue,
                label: 'Predicted next-month savings',
                value: CurrencyFormatter.compact(ml.predictedSavings!),
                detail: ml.predictedSavings! > analysis.monthlySavings
                    ? '↑ above your recent average'
                    : ml.predictedSavings! < analysis.monthlySavings
                        ? '↓ below your recent average'
                        : '≈ in line with your average',
              ),

            // Trend
            if (ml.trendInsight != null) ...[
              const SizedBox(height: Spacing.md),
              _mlRow(
                context,
                icon: ml.trendSlope != null && ml.trendSlope! >= 0
                    ? CupertinoIcons.arrow_up_right
                    : CupertinoIcons.arrow_down_right,
                color: ml.trendSlope != null && ml.trendSlope! >= 0
                    ? AppStyles.accentGreen
                    : AppStyles.accentOrange,
                label: 'Savings trend',
                value: ml.trendRSquared != null
                    ? 'R²=${ml.trendRSquared!.toStringAsFixed(2)}'
                    : '',
                detail: ml.trendInsight!,
              ),
            ],

            // Goal probability
            if (ml.goalCompletionProbability != null) ...[
              const SizedBox(height: Spacing.md),
              _mlProbabilityRow(context, ml.goalCompletionProbability!,
                  ml.completionMonthsRange),
            ],

            // Seasonal warning
            if (ml.seasonalWarning != null) ...[
              const SizedBox(height: Spacing.md),
              _mlRow(
                context,
                icon: CupertinoIcons.calendar_badge_minus,
                color: AppStyles.accentAmber,
                label: 'Seasonal pattern detected',
                value: '',
                detail: ml.seasonalWarning!,
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _mlLockedState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: AppStyles.novaPurple.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      child: Row(
        children: [
          const Icon(CupertinoIcons.lock_fill,
              size: 16, color: AppStyles.novaPurple),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Unlocks with more data',
                    style: TextStyle(
                      fontSize: TypeScale.footnote,
                      fontWeight: FontWeight.w600,
                      color: AppStyles.novaPurple,
                    )),
                const SizedBox(height: 2),
                Text(
                  'ML predictions activate after 3 months of transactions. '
                  'You currently have ${analysis.ml.dataMonths} month${analysis.ml.dataMonths == 1 ? '' : 's'}.',
                  style: TextStyle(
                    fontSize: TypeScale.caption,
                    color: AppStyles.getSecondaryTextColor(context),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _mlRow(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String label,
    required String value,
    required String detail,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 12, color: color),
        ),
        const SizedBox(width: Spacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(label,
                      style: TextStyle(
                        fontSize: TypeScale.footnote,
                        fontWeight: FontWeight.w600,
                        color: AppStyles.getTextColor(context),
                      )),
                  if (value.isNotEmpty)
                    Text(value,
                        style: TextStyle(
                          fontSize: TypeScale.footnote,
                          fontWeight: FontWeight.w700,
                          color: color,
                        )),
                ],
              ),
              const SizedBox(height: 2),
              Text(detail,
                  style: TextStyle(
                    fontSize: TypeScale.caption,
                    color: AppStyles.getSecondaryTextColor(context),
                    height: 1.4,
                  )),
            ],
          ),
        ),
      ],
    );
  }

  Widget _mlProbabilityRow(
    BuildContext context,
    double probability,
    ({int low, int mid, int high})? range,
  ) {
    final pct = (probability * 100).round();
    final Color probColor;
    if (pct >= 75) probColor = AppStyles.accentGreen;
    else if (pct >= 50) probColor = AppStyles.accentAmber;
    else probColor = AppStyles.accentOrange;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: probColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(CupertinoIcons.gauge,
                      size: 12, color: probColor),
                ),
                const SizedBox(width: Spacing.sm),
                Text('On-time probability',
                    style: TextStyle(
                      fontSize: TypeScale.footnote,
                      fontWeight: FontWeight.w600,
                      color: AppStyles.getTextColor(context),
                    )),
              ],
            ),
            Text('$pct%',
                style: TextStyle(
                  fontSize: TypeScale.subhead,
                  fontWeight: FontWeight.w800,
                  color: probColor,
                )),
          ],
        ),
        const SizedBox(height: Spacing.sm),
        // Probability bar
        Padding(
          padding: const EdgeInsets.only(left: 34),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: probability,
                  minHeight: 6,
                  backgroundColor:
                      probColor.withValues(alpha: 0.12),
                  valueColor: AlwaysStoppedAnimation<Color>(probColor),
                ),
              ),
              if (range != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Expected: ${range.mid} months  '
                  '(best: ${range.low} mo · worst: ${range.high} mo)',
                  style: TextStyle(
                    fontSize: TypeScale.caption,
                    color: AppStyles.getSecondaryTextColor(context),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRecommendations(BuildContext context) {
    if (analysis.recommendations.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Recommendations',
            style: TextStyle(
              fontSize: RT.title2(context),
              fontWeight: FontWeight.w700,
              color: AppStyles.getTextColor(context),
            )),
        const SizedBox(height: Spacing.md),
        ...analysis.recommendations.map((rec) => _recCard(context, rec)),
      ],
    );
  }

  Widget _recCard(BuildContext context, PlannerRecommendation rec) {
    final Color color;
    final IconData icon;
    switch (rec.type) {
      case PlannerRecommendationType.positive:
        color = AppStyles.accentGreen;
        icon = CupertinoIcons.checkmark_seal_fill;
        break;
      case PlannerRecommendationType.warning:
        color = AppStyles.accentOrange;
        icon = CupertinoIcons.exclamationmark_triangle_fill;
        break;
      case PlannerRecommendationType.action:
        color = AppStyles.accentBlue;
        icon = CupertinoIcons.bolt_fill;
        break;
      case PlannerRecommendationType.info:
        color = AppStyles.aetherTeal;
        icon = CupertinoIcons.info_circle_fill;
        break;
    }
    return Container(
      margin: const EdgeInsets.only(bottom: Spacing.md),
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: AppStyles.getCardColor(context),
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: Text(rec.title,
                    style: TextStyle(
                      fontSize: TypeScale.subhead,
                      fontWeight: FontWeight.w700,
                      color: AppStyles.getTextColor(context),
                    )),
              ),
            ],
          ),
          const SizedBox(height: Spacing.xs),
          Padding(
            padding: const EdgeInsets.only(left: 22),
            child: Text(rec.detail,
                style: TextStyle(
                  fontSize: TypeScale.footnote,
                  color: AppStyles.getSecondaryTextColor(context),
                  height: 1.5,
                )),
          ),
        ],
      ),
    );
  }

  String _fmt(double v) =>
      v >= 1e5 ? '${(v / 1e5).toStringAsFixed(1)}L' : v.toStringAsFixed(0);
}

// ─────────────────────────────────────────────────────────────────────────────
// Plan Wizard — bottom sheet, 5 steps
// ─────────────────────────────────────────────────────────────────────────────

class _PlanWizardSheet extends StatefulWidget {
  final FinancialPlan? existing;
  final void Function(FinancialPlan) onSaved;
  final MLAnalysis? mlAnalysis;
  final PlanningFocus? initialFocus;

  const _PlanWizardSheet({
    required this.existing,
    required this.onSaved,
    this.mlAnalysis,
    this.initialFocus,
  });

  @override
  State<_PlanWizardSheet> createState() => _PlanWizardSheetState();
}

class _PlanWizardSheetState extends State<_PlanWizardSheet> {
  int _step = 0;
  PlanningFocus _focus = PlanningFocus.emergencyFund;
  PlanningTimeline _timeline = PlanningTimeline.oneYear;
  int _priority = 2;
  String _emoji = '';
  RiskProfile _riskProfile = RiskProfile.moderate;
  IncomeStability _incomeStability = IncomeStability.stable;
  int _dependentsCount = 0;
  final _nameCtrl = TextEditingController();
  final _targetCtrl = TextEditingController();
  final _contributionCtrl = TextEditingController();
  final _savedCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  static const _totalSteps = 6;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _focus = e.focus;
      _timeline = e.timeline;
      _priority = e.priority;
      _emoji = e.emoji ?? '';
      _riskProfile = e.riskProfile;
      _incomeStability = e.incomeStability;
      _dependentsCount = e.dependentsCount;
      _nameCtrl.text = e.name;
      if (e.targetAmount != null && e.targetAmount! > 0)
        _targetCtrl.text = e.targetAmount!.toStringAsFixed(0);
      if (e.monthlyContribution != null && e.monthlyContribution! > 0)
        _contributionCtrl.text = e.monthlyContribution!.toStringAsFixed(0);
      if (e.currentSaved > 0)
        _savedCtrl.text = e.currentSaved.toStringAsFixed(0);
      if (e.notes != null) _notesCtrl.text = e.notes!;
    } else {
      // Pre-select focus from suggestion card if provided
      if (widget.initialFocus != null) {
        _focus = widget.initialFocus!;
        _nameCtrl.text = _defaultPlanName(widget.initialFocus!);
      } else {
        _nameCtrl.text = '';
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _targetCtrl.dispose();
    _contributionCtrl.dispose();
    _savedCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  bool get _canProceed {
    switch (_step) {
      case 0:
        return true; // focus is always pre-selected — Custom name handled in step 1
      case 1:
        return _nameCtrl.text.trim().isNotEmpty;
      default:
        return true;
    }
  }

  void _next() {
    if (!_canProceed) return;
    if (_step < _totalSteps - 1) {
      // Auto-fill name from focus on step 0→1 if blank
      if (_step == 0 && _nameCtrl.text.trim().isEmpty) {
        _nameCtrl.text = _defaultPlanName(_focus);
      }
      setState(() => _step++);
    } else {
      _save();
    }
  }

  String _defaultPlanName(PlanningFocus f) {
    switch (f) {
      case PlanningFocus.emergencyFund:   return 'Emergency Fund';
      case PlanningFocus.homeDownPayment: return 'Home Down Payment';
      case PlanningFocus.debtPayoff:      return 'Debt Payoff';
      case PlanningFocus.retirement:      return 'Retirement';
      case PlanningFocus.education:       return 'Education Fund';
      case PlanningFocus.wedding:         return 'Wedding';
      case PlanningFocus.travel:          return 'Travel';
      case PlanningFocus.investment:      return 'Investments';
      case PlanningFocus.custom:          return '';
    }
  }

  void _save() {
    final target = double.tryParse(_targetCtrl.text.replaceAll(',', ''));
    final contribution =
        double.tryParse(_contributionCtrl.text.replaceAll(',', ''));
    final saved = double.tryParse(_savedCtrl.text.replaceAll(',', ''));
    final name = _nameCtrl.text.trim().isNotEmpty
        ? _nameCtrl.text.trim()
        : _defaultPlanName(_focus);

    final plan = FinancialPlan(
      id: widget.existing?.id ?? IdGenerator.next(prefix: 'fp'),
      name: name,
      focus: _focus,
      timeline: _timeline,
      targetAmount: target,
      monthlyContribution: contribution,
      currentSaved: saved ?? 0,
      priority: _priority,
      emoji: _emoji.trim().isNotEmpty ? _emoji.trim() : null,
      notes:
          _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
      riskProfile: _riskProfile,
      incomeStability: _incomeStability,
      dependentsCount: _dependentsCount,
    );
    widget.onSaved(plan);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppStyles.sheetMaxHeight(context),
      decoration: BoxDecoration(
        color: AppStyles.getBackground(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppStyles.getSecondaryTextColor(context)
                      .withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.lg, vertical: Spacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _stepTitle(),
                          style: TextStyle(
                            fontSize: RT.title2(context),
                            fontWeight: FontWeight.w800,
                            color: AppStyles.getTextColor(context),
                          ),
                        ),
                      ),
                      Text(
                        'Step ${_step + 1} of $_totalSteps',
                        style: TextStyle(
                          fontSize: TypeScale.caption,
                          color: AppStyles.getSecondaryTextColor(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Spacing.sm),
                  // Progress dots
                  Row(
                    children: List.generate(_totalSteps, (i) {
                      final active = i <= _step;
                      return Expanded(
                        child: Container(
                          margin: EdgeInsets.only(right: i < _totalSteps - 1 ? 4 : 0),
                          height: 3,
                          decoration: BoxDecoration(
                            color: active
                                ? AppStyles.aetherTeal
                                : AppStyles.getSecondaryTextColor(context)
                                    .withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
            // Step content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
                child: _buildStep(),
              ),
            ),
            // Navigation buttons
            Padding(
              padding: const EdgeInsets.all(Spacing.lg),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: CupertinoButton.filled(
                      borderRadius: BorderRadius.circular(Radii.lg),
                      onPressed: _canProceed ? _next : null,
                      child: Text(
                        _step < _totalSteps - 1 ? 'Continue' : 'Save Plan',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  if (_step > 0) ...[
                    const SizedBox(height: Spacing.sm),
                    SizedBox(
                      width: double.infinity,
                      child: CupertinoButton(
                        onPressed: () => setState(() => _step--),
                        child: Text('Back',
                            style: TextStyle(
                                color: AppStyles.getSecondaryTextColor(
                                    context))),
                      ),
                    ),
                  ],
                  if (_step >= 2) ...[
                    SizedBox(
                      width: double.infinity,
                      child: CupertinoButton(
                        onPressed: _next,
                        child: Text('Skip',
                            style: TextStyle(
                              color: AppStyles.getSecondaryTextColor(context),
                              fontSize: TypeScale.footnote,
                            )),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _stepTitle() {
    switch (_step) {
      case 0: return 'What are you saving for?';
      case 1: return 'Name your plan';
      case 2: return 'Set a target';
      case 3: return 'Your contribution';
      case 4: return 'A little about you';
      case 5: return 'Any extra context?';
      default: return '';
    }
  }

  Widget _buildStep() {
    switch (_step) {
      case 0: return _buildFocusStep();
      case 1: return _buildNameStep();
      case 2: return _buildTargetStep();
      case 3: return _buildContributionStep();
      case 4: return _buildContextStep();
      case 5: return _buildNotesStep();
      default: return const SizedBox.shrink();
    }
  }

  // Step 0 — Focus picker
  Widget _buildFocusStep() {
    final options = [
      (PlanningFocus.emergencyFund,   CupertinoIcons.shield_fill,       'Emergency Fund',    AppStyles.accentGreen,   'Build a 3–6 month safety net'),
      (PlanningFocus.homeDownPayment, CupertinoIcons.house_fill,         'Home',              AppStyles.accentBlue,    'Save for a down payment'),
      (PlanningFocus.debtPayoff,      CupertinoIcons.creditcard_fill,    'Debt Payoff',       AppStyles.accentOrange,  'Become debt-free faster'),
      (PlanningFocus.retirement,      CupertinoIcons.person_fill,        'Retirement',        AppStyles.accentPurple,  'Build long-term wealth'),
      (PlanningFocus.education,       CupertinoIcons.book_fill,          'Education',         AppStyles.aetherTeal,    'Fund a course or degree'),
      (PlanningFocus.wedding,         CupertinoIcons.heart_fill,         'Wedding',           AppStyles.accentCoral,   'Plan your big day'),
      (PlanningFocus.travel,          CupertinoIcons.airplane,           'Travel',            AppStyles.accentAmber,   'Fund your dream trip'),
      (PlanningFocus.investment,      CupertinoIcons.chart_bar_alt_fill, 'Investments',       AppStyles.aetherTeal,    'Grow your portfolio'),
      (PlanningFocus.custom,          CupertinoIcons.star_fill,          'Custom',            AppStyles.accentOrange,  'Any other financial goal'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: Spacing.sm),
        Container(
          padding: const EdgeInsets.all(Spacing.md),
          decoration: BoxDecoration(
            color: AppStyles.aetherTeal.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(Radii.md),
          ),
          child: Row(
            children: [
              const Icon(CupertinoIcons.lightbulb_fill,
                  size: 16, color: AppStyles.aetherTeal),
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: Text(
                  'Pick your goal type — the planner will use your actual spending history to build a personalised roadmap.',
                  style: TextStyle(
                    fontSize: TypeScale.caption,
                    color: AppStyles.aetherTeal,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Spacing.md),
        LayoutBuilder(
          builder: (context, constraints) {
            const cols = 3;
            const spacing = Spacing.sm;
            final itemW = (constraints.maxWidth - (cols - 1) * spacing) / cols;
            return GridView.count(
          crossAxisCount: cols,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: spacing,
          mainAxisSpacing: spacing,
          childAspectRatio: itemW / (itemW / 0.9),
          children: options.map((opt) {
            final (focus, icon, label, color, subtitle) = opt;
            final selected = _focus == focus;
            return GestureDetector(
              onTap: () {
                setState(() {
                  final oldDefault = _defaultPlanName(_focus); // capture before update
                  _focus = focus;
                  // Auto-update name only if it was still the old auto-filled default
                  if (_nameCtrl.text.isEmpty || _nameCtrl.text == oldDefault) {
                    _nameCtrl.text = _defaultPlanName(focus);
                  }
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                decoration: BoxDecoration(
                  color: selected
                      ? color.withValues(alpha: 0.12)
                      : AppStyles.getCardColor(context),
                  borderRadius: BorderRadius.circular(Radii.md),
                  border: Border.all(
                    color: selected
                        ? color
                        : AppStyles.getSecondaryTextColor(context)
                            .withValues(alpha: 0.15),
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 22,
                        color: selected
                            ? color
                            : AppStyles.getSecondaryTextColor(context)),
                    const SizedBox(height: 5),
                    Text(label,
                        style: TextStyle(
                          fontSize: TypeScale.caption,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: selected
                              ? color
                              : AppStyles.getTextColor(context),
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    if (selected) ...[
                      const SizedBox(height: 3),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(subtitle,
                            style: TextStyle(
                              fontSize: 8,
                              color: color.withValues(alpha: 0.80),
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
            );
          },
        ),
        const SizedBox(height: Spacing.lg),
      ],
    );
  }

  // Step 1 — Name + emoji + priority
  Widget _buildNameStep() {
    final emojis = ['🏠', '🚗', '✈️', '🎓', '💍', '🏦', '🛡️', '📈', '🌴', '⭐'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: Spacing.md),
        if (_focus == PlanningFocus.custom) ...[
          Container(
            padding: const EdgeInsets.all(Spacing.md),
            decoration: BoxDecoration(
              color: AppStyles.accentOrange.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(Radii.md),
            ),
            child: Row(
              children: [
                const Icon(CupertinoIcons.star_fill,
                    size: 14, color: AppStyles.accentOrange),
                const SizedBox(width: Spacing.sm),
                Expanded(
                  child: Text(
                    'You chose Custom — give your goal a meaningful name so you can track it easily.',
                    style: TextStyle(
                      fontSize: TypeScale.caption,
                      color: AppStyles.accentOrange,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Spacing.md),
        ],
        Text('Give it a personal name',
            style: TextStyle(
              fontSize: TypeScale.footnote,
              color: AppStyles.getSecondaryTextColor(context),
            )),
        const SizedBox(height: Spacing.sm),
        CupertinoTextField(
          controller: _nameCtrl,
          placeholder: 'e.g. Dream Home 2028',
          style: TextStyle(
              color: AppStyles.getTextColor(context),
              fontWeight: FontWeight.w600),
          decoration: BoxDecoration(
            color: AppStyles.getCardColor(context),
            borderRadius: BorderRadius.circular(Radii.md),
          ),
          padding: const EdgeInsets.all(Spacing.md),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: Spacing.lg),
        Text('Pick an emoji (optional)',
            style: TextStyle(
              fontSize: TypeScale.footnote,
              color: AppStyles.getSecondaryTextColor(context),
            )),
        const SizedBox(height: Spacing.sm),
        Wrap(
          spacing: Spacing.sm,
          runSpacing: Spacing.sm,
          children: emojis.map((e) {
            final selected = _emoji == e;
            return GestureDetector(
              onTap: () => setState(() => _emoji = selected ? '' : e),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: selected
                      ? AppStyles.aetherTeal.withValues(alpha: 0.15)
                      : AppStyles.getCardColor(context),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected
                        ? AppStyles.aetherTeal
                        : AppStyles.getSecondaryTextColor(context)
                            .withValues(alpha: 0.2),
                  ),
                ),
                child: Center(
                    child: Text(e, style: TextStyle(fontSize: RT.title1(context)))),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: Spacing.lg),
        Text('Priority',
            style: TextStyle(
              fontSize: TypeScale.footnote,
              color: AppStyles.getSecondaryTextColor(context),
            )),
        const SizedBox(height: Spacing.sm),
        Row(
          children: [
            _priorityChip(1, '🔴 High', AppStyles.accentOrange),
            const SizedBox(width: Spacing.sm),
            _priorityChip(2, '🟡 Medium', AppStyles.accentAmber),
            const SizedBox(width: Spacing.sm),
            _priorityChip(3, '🟢 Low', AppStyles.accentGreen),
          ],
        ),
        const SizedBox(height: Spacing.lg),
      ],
    );
  }

  Widget _priorityChip(int value, String label, Color color) {
    final selected = _priority == value;
    return GestureDetector(
      onTap: () => setState(() => _priority = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.15)
              : AppStyles.getCardColor(context),
          borderRadius: BorderRadius.circular(Radii.xl),
          border: Border.all(
            color: selected
                ? color
                : AppStyles.getSecondaryTextColor(context).withValues(alpha: 0.2),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: TypeScale.footnote,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? color : AppStyles.getTextColor(context),
            )),
      ),
    );
  }

  // Step 2 — Target amount + timeline
  Widget _buildTargetStep() {
    final timelines = [
      (PlanningTimeline.threeMonths, '3 mo'),
      (PlanningTimeline.sixMonths,   '6 mo'),
      (PlanningTimeline.oneYear,     '1 yr'),
      (PlanningTimeline.threeYears,  '3 yr'),
      (PlanningTimeline.fiveYears,   '5 yr'),
      (PlanningTimeline.tenYears,    '10 yr'),
    ];

    // ML-powered target suggestion based on focus + spending history
    final ml = widget.mlAnalysis;
    String? targetHint;
    if (ml != null && ml.dataSufficient && ml.predictedExpenses != null) {
      switch (_focus) {
        case PlanningFocus.emergencyFund:
          targetHint =
              'Suggested: ${CurrencyFormatter.compact(ml.predictedExpenses! * 6)} (6 months of your ₹${CurrencyFormatter.compact(ml.predictedExpenses!)} avg monthly expenses)';
          break;
        case PlanningFocus.retirement:
          if (ml.predictedExpenses! > 0) {
            targetHint =
                'Rule of thumb: 25× your annual expenses = ${CurrencyFormatter.compact(ml.predictedExpenses! * 12 * 25)}';
          }
          break;
        default:
          break;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: Spacing.md),
        if (targetHint != null) ...[
          Container(
            padding: const EdgeInsets.all(Spacing.md),
            decoration: BoxDecoration(
              color: AppStyles.accentBlue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(Radii.md),
              border: Border.all(
                  color: AppStyles.accentBlue.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(CupertinoIcons.sparkles,
                    size: 14, color: AppStyles.accentBlue),
                const SizedBox(width: Spacing.sm),
                Expanded(
                  child: Text(targetHint,
                      style: TextStyle(
                        fontSize: TypeScale.caption,
                        color: AppStyles.accentBlue,
                        height: 1.4,
                      )),
                ),
              ],
            ),
          ),
          const SizedBox(height: Spacing.md),
        ],
        Text('Target amount (optional)',
            style: TextStyle(
              fontSize: TypeScale.footnote,
              color: AppStyles.getSecondaryTextColor(context),
            )),
        const SizedBox(height: 3),
        Text(
          'How much do you need in total? You can leave this blank and track progress by savings rate instead.',
          style: TextStyle(
            fontSize: TypeScale.caption,
            color: AppStyles.getSecondaryTextColor(context),
            height: 1.4,
          ),
        ),
        const SizedBox(height: Spacing.sm),
        CupertinoTextField(
          controller: _targetCtrl,
          placeholder: '₹ How much do you need?',
          keyboardType: TextInputType.number,
          style: TextStyle(color: AppStyles.getTextColor(context)),
          decoration: BoxDecoration(
            color: AppStyles.getCardColor(context),
            borderRadius: BorderRadius.circular(Radii.md),
          ),
          padding: const EdgeInsets.all(Spacing.md),
        ),
        const SizedBox(height: Spacing.lg),
        Text('Timeline',
            style: TextStyle(
              fontSize: TypeScale.footnote,
              color: AppStyles.getSecondaryTextColor(context),
            )),
        const SizedBox(height: Spacing.sm),
        Wrap(
          spacing: Spacing.sm,
          runSpacing: Spacing.sm,
          children: timelines.map((opt) {
            final (tl, label) = opt;
            final selected = _timeline == tl;
            return GestureDetector(
              onTap: () => setState(() => _timeline = tl),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                padding: const EdgeInsets.symmetric(
                    horizontal: Spacing.lg, vertical: Spacing.md),
                decoration: BoxDecoration(
                  color: selected
                      ? AppStyles.accentBlue.withValues(alpha: 0.15)
                      : AppStyles.getCardColor(context),
                  borderRadius: BorderRadius.circular(Radii.xl),
                  border: Border.all(
                    color: selected
                        ? AppStyles.accentBlue
                        : AppStyles.getSecondaryTextColor(context)
                            .withValues(alpha: 0.2),
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Text(label,
                    style: TextStyle(
                      fontSize: TypeScale.subhead,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected
                          ? AppStyles.accentBlue
                          : AppStyles.getTextColor(context),
                    )),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: Spacing.lg),
      ],
    );
  }

  // Step 3 — Monthly contribution + current head start
  Widget _buildContributionStep() {
    final ml = widget.mlAnalysis;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: Spacing.md),
        // ML insight banner
        if (ml != null && ml.dataSufficient && (ml.predictedSavings ?? 0) > 0) ...[
          Container(
            padding: const EdgeInsets.all(Spacing.md),
            decoration: BoxDecoration(
              color: AppStyles.accentGreen.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(Radii.md),
              border: Border.all(
                  color: AppStyles.accentGreen.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(CupertinoIcons.chart_bar_fill,
                    size: 14, color: AppStyles.accentGreen),
                const SizedBox(width: Spacing.sm),
                Expanded(
                  child: Text(
                    'Based on your last ${ml.dataMonths} months, you save about ${CurrencyFormatter.compact(ml.predictedSavings!)} per month on average.',
                    style: TextStyle(
                      fontSize: TypeScale.caption,
                      color: AppStyles.accentGreen,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Spacing.md),
        ] else if (ml != null && !ml.dataSufficient) ...[
          Container(
            padding: const EdgeInsets.all(Spacing.md),
            decoration: BoxDecoration(
              color: AppStyles.getCardColor(context),
              borderRadius: BorderRadius.circular(Radii.md),
            ),
            child: Row(
              children: [
                Icon(CupertinoIcons.info_circle,
                    size: 14,
                    color: AppStyles.getSecondaryTextColor(context)),
                const SizedBox(width: Spacing.sm),
                Expanded(
                  child: Text(
                    'Record ${3 - ml.dataMonths} more month${3 - ml.dataMonths == 1 ? '' : 's'} of transactions to unlock ML-powered savings predictions.',
                    style: TextStyle(
                      fontSize: TypeScale.caption,
                      color: AppStyles.getSecondaryTextColor(context),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Spacing.md),
        ],
        Text('Monthly contribution (optional)',
            style: TextStyle(
              fontSize: TypeScale.footnote,
              color: AppStyles.getSecondaryTextColor(context),
            )),
        const SizedBox(height: 3),
        Text(
          'How much do you plan to dedicate specifically to this goal each month? '
          'Leave blank to use your overall savings from transactions.',
          style: TextStyle(
            fontSize: TypeScale.caption,
            color: AppStyles.getSecondaryTextColor(context),
            height: 1.4,
          ),
        ),
        const SizedBox(height: Spacing.sm),
        CupertinoTextField(
          controller: _contributionCtrl,
          placeholder: '₹ e.g. 5000',
          keyboardType: TextInputType.number,
          style: TextStyle(color: AppStyles.getTextColor(context)),
          decoration: BoxDecoration(
            color: AppStyles.getCardColor(context),
            borderRadius: BorderRadius.circular(Radii.md),
          ),
          padding: const EdgeInsets.all(Spacing.md),
        ),
        const SizedBox(height: Spacing.xl),
        Text('Already saved toward this goal (optional)',
            style: TextStyle(
              fontSize: TypeScale.footnote,
              color: AppStyles.getSecondaryTextColor(context),
            )),
        const SizedBox(height: 3),
        Text(
          'If you\'ve already set money aside for this goal, enter it here. '
          'The planner will show your real progress.',
          style: TextStyle(
            fontSize: TypeScale.caption,
            color: AppStyles.getSecondaryTextColor(context),
            height: 1.4,
          ),
        ),
        const SizedBox(height: Spacing.sm),
        CupertinoTextField(
          controller: _savedCtrl,
          placeholder: '₹ How much have you saved so far?',
          keyboardType: TextInputType.number,
          style: TextStyle(color: AppStyles.getTextColor(context)),
          decoration: BoxDecoration(
            color: AppStyles.getCardColor(context),
            borderRadius: BorderRadius.circular(Radii.md),
          ),
          padding: const EdgeInsets.all(Spacing.md),
        ),
        const SizedBox(height: Spacing.lg),
      ],
    );
  }

  // Step 4 — ML context questions (income type, dependents, risk profile)
  Widget _buildContextStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: Spacing.sm),
        Container(
          padding: const EdgeInsets.all(Spacing.md),
          decoration: BoxDecoration(
            color: AppStyles.accentPurple.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(Radii.md),
          ),
          child: Row(
            children: [
              const Icon(CupertinoIcons.sparkles,
                  size: 14, color: AppStyles.accentPurple),
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: Text(
                  'These 3 questions help the ML model tailor projections to your real financial situation.',
                  style: TextStyle(
                    fontSize: TypeScale.caption,
                    color: AppStyles.accentPurple,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Spacing.lg),

        // — Income type —
        Text('How stable is your income?',
            style: TextStyle(
              fontSize: TypeScale.subhead,
              fontWeight: FontWeight.w700,
              color: AppStyles.getTextColor(context),
            )),
        const SizedBox(height: 4),
        Text(
          'Helps predict how reliable your monthly savings will be.',
          style: TextStyle(
            fontSize: TypeScale.caption,
            color: AppStyles.getSecondaryTextColor(context),
          ),
        ),
        const SizedBox(height: Spacing.sm),
        Wrap(
          spacing: Spacing.sm,
          runSpacing: Spacing.sm,
          children: [
            _contextChip('💼  Stable salary', IncomeStability.stable,
                _incomeStability == IncomeStability.stable,
                () => setState(() => _incomeStability = IncomeStability.stable)),
            _contextChip('📊  Variable pay', IncomeStability.variable,
                _incomeStability == IncomeStability.variable,
                () => setState(() => _incomeStability = IncomeStability.variable)),
            _contextChip('🖥️  Freelance', IncomeStability.freelance,
                _incomeStability == IncomeStability.freelance,
                () => setState(() => _incomeStability = IncomeStability.freelance)),
            _contextChip('🏢  Own business', IncomeStability.business,
                _incomeStability == IncomeStability.business,
                () => setState(() => _incomeStability = IncomeStability.business)),
          ],
        ),
        const SizedBox(height: Spacing.lg),

        // — Dependents —
        Text('How many dependents do you have?',
            style: TextStyle(
              fontSize: TypeScale.subhead,
              fontWeight: FontWeight.w700,
              color: AppStyles.getTextColor(context),
            )),
        const SizedBox(height: 4),
        Text(
          'Family responsibilities affect how aggressive you can be with saving.',
          style: TextStyle(
            fontSize: TypeScale.caption,
            color: AppStyles.getSecondaryTextColor(context),
          ),
        ),
        const SizedBox(height: Spacing.sm),
        Row(
          children: [
            for (final (val, label) in [(0, 'Just me'), (1, '1'), (2, '2'), (3, '3+')])
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: val < 3 ? Spacing.sm : 0),
                  child: GestureDetector(
                    onTap: () => setState(() => _dependentsCount = val),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _dependentsCount == val
                            ? AppStyles.aetherTeal.withValues(alpha: 0.15)
                            : AppStyles.getCardColor(context),
                        borderRadius: BorderRadius.circular(Radii.md),
                        border: Border.all(
                          color: _dependentsCount == val
                              ? AppStyles.aetherTeal
                              : AppStyles.getSecondaryTextColor(context)
                                  .withValues(alpha: 0.2),
                          width: _dependentsCount == val ? 1.5 : 1,
                        ),
                      ),
                      child: Text(label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: TypeScale.footnote,
                            fontWeight: _dependentsCount == val
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: _dependentsCount == val
                                ? AppStyles.aetherTeal
                                : AppStyles.getTextColor(context),
                          )),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: Spacing.lg),

        // — Risk tolerance —
        Text('What\'s your risk appetite?',
            style: TextStyle(
              fontSize: TypeScale.subhead,
              fontWeight: FontWeight.w700,
              color: AppStyles.getTextColor(context),
            )),
        const SizedBox(height: 4),
        Text(
          'Affects how the planner weighs growth vs safety in its advice.',
          style: TextStyle(
            fontSize: TypeScale.caption,
            color: AppStyles.getSecondaryTextColor(context),
          ),
        ),
        const SizedBox(height: Spacing.sm),
        ...RiskProfile.values.map((rp) {
          final (icon, label, desc, color) = switch (rp) {
            RiskProfile.conservative => ('🛡️', 'Conservative',
                'Safety first — steady growth, low volatility', AppStyles.accentGreen),
            RiskProfile.moderate => ('⚖️', 'Moderate',
                'Balance of safety and growth', AppStyles.accentBlue),
            RiskProfile.aggressive => ('📈', 'Aggressive',
                'Comfortable with ups and downs for higher returns', AppStyles.accentOrange),
          };
          final selected = _riskProfile == rp;
          return Padding(
            padding: const EdgeInsets.only(bottom: Spacing.sm),
            child: GestureDetector(
              onTap: () => setState(() => _riskProfile = rp),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                padding: const EdgeInsets.all(Spacing.md),
                decoration: BoxDecoration(
                  color: selected
                      ? color.withValues(alpha: 0.10)
                      : AppStyles.getCardColor(context),
                  borderRadius: BorderRadius.circular(Radii.md),
                  border: Border.all(
                    color: selected
                        ? color
                        : AppStyles.getSecondaryTextColor(context)
                            .withValues(alpha: 0.15),
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Text(icon, style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: Spacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(label,
                              style: TextStyle(
                                fontSize: TypeScale.callout,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                color: selected
                                    ? color
                                    : AppStyles.getTextColor(context),
                              )),
                          Text(desc,
                              style: TextStyle(
                                fontSize: TypeScale.caption,
                                color: selected
                                    ? color.withValues(alpha: 0.80)
                                    : AppStyles.getSecondaryTextColor(context),
                                height: 1.3,
                              )),
                        ],
                      ),
                    ),
                    if (selected)
                      Icon(CupertinoIcons.checkmark_circle_fill,
                          size: 18, color: color),
                  ],
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: Spacing.lg),
      ],
    );
  }

  Widget _contextChip<T>(String label, T value, bool selected, VoidCallback onTap) {
    final color = selected ? AppStyles.aetherTeal : AppStyles.getSecondaryTextColor(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(
            horizontal: Spacing.md, vertical: Spacing.sm),
        decoration: BoxDecoration(
          color: selected
              ? AppStyles.aetherTeal.withValues(alpha: 0.12)
              : AppStyles.getCardColor(context),
          borderRadius: BorderRadius.circular(Radii.xl),
          border: Border.all(
            color: selected
                ? AppStyles.aetherTeal
                : AppStyles.getSecondaryTextColor(context)
                    .withValues(alpha: 0.2),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: TypeScale.footnote,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: color,
            )),
      ),
    );
  }

  // Step 5 — Notes
  Widget _buildNotesStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: Spacing.md),
        Text(
          'Any context or reminders for this plan? (optional)',
          style: TextStyle(
            fontSize: TypeScale.footnote,
            color: AppStyles.getSecondaryTextColor(context),
          ),
        ),
        const SizedBox(height: Spacing.sm),
        CupertinoTextField(
          controller: _notesCtrl,
          placeholder:
              'e.g. "Need ₹20L for flat in Pune by end of 2027. Salary hike expected in April."',
          maxLines: 5,
          style: TextStyle(color: AppStyles.getTextColor(context)),
          decoration: BoxDecoration(
            color: AppStyles.getCardColor(context),
            borderRadius: BorderRadius.circular(Radii.md),
          ),
          padding: const EdgeInsets.all(Spacing.md),
        ),
        const SizedBox(height: Spacing.lg),
      ],
    );
  }
}
