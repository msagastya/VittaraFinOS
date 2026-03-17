import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:vittara_fin_os/logic/budgets_controller.dart';
import 'package:vittara_fin_os/logic/budget_model.dart';
import 'package:vittara_fin_os/logic/transactions_controller.dart';
import 'package:vittara_fin_os/logic/transaction_model.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/widgets/animated_counter.dart';
import 'package:vittara_fin_os/ui/widgets/glass_card.dart';
import 'package:vittara_fin_os/ui/widgets/neumorphic_glass_card.dart';
import 'package:vittara_fin_os/ui/widgets/common_widgets.dart';
import 'package:vittara_fin_os/ui/widgets/liquid_progress_indicators.dart';

class BudgetDetailsScreen extends StatelessWidget {
  final String budgetId;

  const BudgetDetailsScreen({super.key, required this.budgetId});

  @override
  Widget build(BuildContext context) {
    return Consumer<BudgetsController>(
      builder: (context, controller, child) {
        final budgetIdx =
            controller.budgets.indexWhere((b) => b.id == budgetId);
        if (budgetIdx < 0) {
          return CupertinoPageScaffold(
            backgroundColor: AppStyles.getBackground(context),
            navigationBar: CupertinoNavigationBar(
              middle: Text('Budget Details',
                  style: TextStyle(color: AppStyles.getTextColor(context))),
              previousPageTitle: 'Budgets',
              backgroundColor: AppStyles.getBackground(context),
              border: null,
            ),
            child: const SafeArea(
              child: EmptyStateView(
                icon: CupertinoIcons.graph_circle,
                title: 'Budget Not Found',
                subtitle: 'This budget may have been deleted.',
                actionLabel: null,
              ),
            ),
          );
        }
        final budget = controller.budgets[budgetIdx];
        final statusColor = budget.status == BudgetStatus.exceeded
            ? SemanticColors.error
            : budget.status == BudgetStatus.warning
                ? SemanticColors.warning
                : SemanticColors.success;

        return CupertinoPageScaffold(
          backgroundColor: AppStyles.getBackground(context),
          navigationBar: CupertinoNavigationBar(
            middle: Text('Budget Details',
                style: TextStyle(color: AppStyles.getTextColor(context))),
            previousPageTitle: 'Budgets',
            backgroundColor: AppStyles.getBackground(context),
            border: null,
          ),
          child: SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(Spacing.lg),
                    child: NeumorphicGlassCard(
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(Spacing.lg),
                                decoration: BoxDecoration(
                                    color: budget.color.withValues(alpha: 0.15),
                                    borderRadius:
                                        BorderRadius.circular(Radii.lg)),
                                child: Icon(budget.getPeriodIcon(),
                                    color: budget.color, size: IconSizes.xl),
                              ),
                              const SizedBox(width: Spacing.lg),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(budget.name,
                                        style: TextStyle(
                                            fontSize: TypeScale.title2,
                                            fontWeight: FontWeight.bold,
                                            color: AppStyles.getTextColor(
                                                context))),
                                    const SizedBox(height: Spacing.xs),
                                    Text(budget.getPeriodLabel(),
                                        style: TextStyle(
                                            fontSize: TypeScale.subhead,
                                            color:
                                                AppStyles.getSecondaryTextColor(
                                                    context))),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: Spacing.xxl),
                          LiquidCircularProgress(
                            progress:
                                (budget.usagePercentage / 100).clamp(0, 1),
                            size: 180,
                            color: statusColor,
                            center: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                AnimatedCounter(
                                    value: budget.usagePercentage,
                                    suffix: '%',
                                    decimalPlaces: 1,
                                    textStyle: TextStyle(
                                        fontSize: TypeScale.hero,
                                        fontWeight: FontWeight.bold,
                                        color: statusColor)),
                                const SizedBox(height: Spacing.xs),
                                Text('Used',
                                    style: TextStyle(
                                        fontSize: TypeScale.footnote,
                                        color: AppStyles.getSecondaryTextColor(
                                            context))),
                              ],
                            ),
                          ),
                          const SizedBox(height: Spacing.xxl),
                          Row(
                            children: [
                              Expanded(
                                  child: Column(children: [
                                Text('Spent',
                                    style: TextStyle(
                                        fontSize: TypeScale.footnote,
                                        color: AppStyles.getSecondaryTextColor(
                                            context))),
                                const SizedBox(height: Spacing.xs),
                                CurrencyCounter(
                                    value: budget.spentAmount,
                                    textStyle: TextStyle(
                                        fontSize: TypeScale.title1,
                                        fontWeight: FontWeight.bold,
                                        color: statusColor),
                                    decimalPlaces: 0)
                              ])),
                              Container(
                                  width: 1,
                                  height: 40,
                                  color:
                                      AppStyles.getSecondaryTextColor(context)
                                          .withValues(alpha: 0.2)),
                              Expanded(
                                  child: Column(children: [
                                Text('Remaining',
                                    style: TextStyle(
                                        fontSize: TypeScale.footnote,
                                        color: AppStyles.getSecondaryTextColor(
                                            context))),
                                const SizedBox(height: Spacing.xs),
                                CurrencyCounter(
                                    value: budget.remainingAmount,
                                    textStyle: TextStyle(
                                        fontSize: TypeScale.title1,
                                        fontWeight: FontWeight.bold,
                                        color: AppStyles.getTextColor(context)),
                                    decimalPlaces: 0)
                              ])),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
                    child: Row(
                      children: [
                        Expanded(
                          child: GlassCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(CupertinoIcons.money_dollar_circle_fill,
                                    color: SemanticColors.info,
                                    size: IconSizes.lg),
                                const SizedBox(height: Spacing.md),
                                Text('Daily Budget',
                                    style: TextStyle(
                                        fontSize: TypeScale.footnote,
                                        color: AppStyles.getSecondaryTextColor(
                                            context))),
                                const SizedBox(height: Spacing.xs),
                                CurrencyCounter(
                                    value: budget.dailyBudgetRemaining,
                                    textStyle: TextStyle(
                                        fontSize: TypeScale.title3,
                                        fontWeight: FontWeight.bold,
                                        color: AppStyles.getTextColor(context)),
                                    decimalPlaces: 0),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: Spacing.md),
                        Expanded(
                          child: GlassCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(CupertinoIcons.calendar,
                                    color: SemanticColors.warning,
                                    size: IconSizes.lg),
                                const SizedBox(height: Spacing.md),
                                Text('Days Left',
                                    style: TextStyle(
                                        fontSize: TypeScale.footnote,
                                        color: AppStyles.getSecondaryTextColor(
                                            context))),
                                const SizedBox(height: Spacing.xs),
                                AnimatedCounter(
                                    value: budget.daysRemaining.toDouble(),
                                    textStyle: TextStyle(
                                        fontSize: TypeScale.title3,
                                        fontWeight: FontWeight.bold,
                                        color: AppStyles.getTextColor(context)),
                                    decimalPlaces: 0),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: Spacing.lg)),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
                    child: NeumorphicGlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(CupertinoIcons.info_circle_fill,
                                  color: statusColor, size: IconSizes.lg),
                              const SizedBox(width: Spacing.md),
                              Expanded(
                                  child: Text(
                                      budget.status == BudgetStatus.onTrack
                                          ? 'On Track!'
                                          : budget.status ==
                                                  BudgetStatus.warning
                                              ? 'Approaching Limit'
                                              : 'Budget Exceeded',
                                      style: TextStyle(
                                          fontSize: TypeScale.callout,
                                          fontWeight: FontWeight.w600,
                                          color: AppStyles.getTextColor(
                                              context)))),
                            ],
                          ),
                          const SizedBox(height: Spacing.lg),
                          Text(
                              'Period: ${DateFormat('MMM dd').format(budget.startDate)} - ${DateFormat('MMM dd, yyyy').format(budget.endDate)}',
                              style: TextStyle(
                                  fontSize: TypeScale.footnote,
                                  color: AppStyles.getSecondaryTextColor(
                                      context))),
                        ],
                      ),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: Spacing.lg)),
                _buildCategoryBreakdown(context, budget),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCategoryBreakdown(BuildContext context, Budget budget) {
    return SliverToBoxAdapter(
      child: Consumer<TransactionsController>(
        builder: (context, txController, _) {
          final periodTxs = txController.transactions.where((tx) {
            if (tx.type != TransactionType.expense) return false;
            return !tx.dateTime.isBefore(budget.startDate) &&
                !tx.dateTime.isAfter(budget.endDate);
          }).toList();

          if (periodTxs.isEmpty) return const SizedBox.shrink();

          // Group by category
          final Map<String, double> categoryTotals = {};
          for (final tx in periodTxs) {
            final cat = (tx.metadata?['categoryName'] as String?)?.trim();
            final key = (cat == null || cat.isEmpty) ? 'Uncategorized' : cat;
            categoryTotals[key] = (categoryTotals[key] ?? 0) + tx.amount;
          }

          final sorted = categoryTotals.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));

          final total = sorted.fold(0.0, (s, e) => s + e.value);

          return Padding(
            padding: const EdgeInsets.fromLTRB(Spacing.lg, 0, Spacing.lg, Spacing.md),
            child: NeumorphicGlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(CupertinoIcons.chart_bar_square,
                          color: budget.color, size: IconSizes.lg),
                      const SizedBox(width: Spacing.md),
                      Text(
                        'Spending Breakdown',
                        style: TextStyle(
                          fontSize: TypeScale.callout,
                          fontWeight: FontWeight.w600,
                          color: AppStyles.getTextColor(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Spacing.xl),
                  ...sorted.map((entry) {
                    final pct = total > 0 ? entry.value / total : 0.0;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: Spacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  entry.key,
                                  style: TextStyle(
                                    fontSize: TypeScale.subhead,
                                    fontWeight: FontWeight.w500,
                                    color: AppStyles.getTextColor(context),
                                  ),
                                ),
                              ),
                              Text(
                                '₹${entry.value.toStringAsFixed(0)}',
                                style: TextStyle(
                                  fontSize: TypeScale.subhead,
                                  fontWeight: FontWeight.w700,
                                  color: AppStyles.getTextColor(context),
                                ),
                              ),
                              const SizedBox(width: Spacing.sm),
                              Text(
                                '${(pct * 100).toStringAsFixed(0)}%',
                                style: TextStyle(
                                  fontSize: TypeScale.footnote,
                                  color:
                                      AppStyles.getSecondaryTextColor(context),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: Spacing.xs),
                          Container(
                            height: 6,
                            decoration: BoxDecoration(
                              color: budget.color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: pct.clamp(0.0, 1.0),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: budget.color,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
