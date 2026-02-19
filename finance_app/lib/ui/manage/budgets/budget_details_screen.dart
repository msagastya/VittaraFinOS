import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:vittara_fin_os/logic/budgets_controller.dart';
import 'package:vittara_fin_os/logic/budget_model.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/widgets/animated_counter.dart';
import 'package:vittara_fin_os/ui/widgets/glass_card.dart';
import 'package:vittara_fin_os/ui/widgets/neumorphic_glass_card.dart';
import 'package:vittara_fin_os/ui/widgets/liquid_progress_indicators.dart';

class BudgetDetailsScreen extends StatelessWidget {
  final String budgetId;

  const BudgetDetailsScreen({super.key, required this.budgetId});

  @override
  Widget build(BuildContext context) {
    return Consumer<BudgetsController>(
      builder: (context, controller, child) {
        final budget = controller.budgets.firstWhere((b) => b.id == budgetId,
            orElse: () => controller.budgets.first);
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
                    padding: EdgeInsets.all(Spacing.lg),
                    child: NeumorphicGlassCard(
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(Spacing.lg),
                                decoration: BoxDecoration(
                                    color: budget.color.withValues(alpha: 0.15),
                                    borderRadius:
                                        BorderRadius.circular(Radii.lg)),
                                child: Icon(budget.getPeriodIcon(),
                                    color: budget.color, size: IconSizes.xl),
                              ),
                              SizedBox(width: Spacing.lg),
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
                                    SizedBox(height: Spacing.xs),
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
                          SizedBox(height: Spacing.xxl),
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
                                SizedBox(height: Spacing.xs),
                                Text('Used',
                                    style: TextStyle(
                                        fontSize: TypeScale.footnote,
                                        color: AppStyles.getSecondaryTextColor(
                                            context))),
                              ],
                            ),
                          ),
                          SizedBox(height: Spacing.xxl),
                          Row(
                            children: [
                              Expanded(
                                  child: Column(children: [
                                Text('Spent',
                                    style: TextStyle(
                                        fontSize: TypeScale.footnote,
                                        color: AppStyles.getSecondaryTextColor(
                                            context))),
                                SizedBox(height: Spacing.xs),
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
                                SizedBox(height: Spacing.xs),
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
                    padding: EdgeInsets.symmetric(horizontal: Spacing.lg),
                    child: Row(
                      children: [
                        Expanded(
                          child: GlassCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(CupertinoIcons.money_dollar_circle_fill,
                                    color: SemanticColors.info,
                                    size: IconSizes.lg),
                                SizedBox(height: Spacing.md),
                                Text('Daily Budget',
                                    style: TextStyle(
                                        fontSize: TypeScale.footnote,
                                        color: AppStyles.getSecondaryTextColor(
                                            context))),
                                SizedBox(height: Spacing.xs),
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
                        SizedBox(width: Spacing.md),
                        Expanded(
                          child: GlassCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(CupertinoIcons.calendar,
                                    color: SemanticColors.warning,
                                    size: IconSizes.lg),
                                SizedBox(height: Spacing.md),
                                Text('Days Left',
                                    style: TextStyle(
                                        fontSize: TypeScale.footnote,
                                        color: AppStyles.getSecondaryTextColor(
                                            context))),
                                SizedBox(height: Spacing.xs),
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
                SliverToBoxAdapter(child: SizedBox(height: Spacing.lg)),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: Spacing.lg),
                    child: NeumorphicGlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(CupertinoIcons.info_circle_fill,
                                  color: statusColor, size: IconSizes.lg),
                              SizedBox(width: Spacing.md),
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
                          SizedBox(height: Spacing.lg),
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
                SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          ),
        );
      },
    );
  }
}
