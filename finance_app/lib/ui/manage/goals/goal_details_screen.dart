import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:vittara_fin_os/logic/goals_controller.dart';
import 'package:vittara_fin_os/logic/goal_model.dart';
import 'package:vittara_fin_os/ui/manage/goals/modals/add_contribution_modal.dart';
import 'package:vittara_fin_os/ui/manage/goals/modals/edit_goal_modal.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/widgets/animations.dart';
import 'package:vittara_fin_os/ui/widgets/animated_counter.dart' as counter_widgets;
import 'package:vittara_fin_os/ui/widgets/common_widgets.dart';
import 'package:vittara_fin_os/ui/widgets/glass_card.dart';
import 'package:vittara_fin_os/ui/widgets/neumorphic_glass_card.dart';
import 'package:vittara_fin_os/ui/widgets/liquid_progress_indicators.dart';
import 'package:vittara_fin_os/utils/alert_service.dart';

class GoalDetailsScreen extends StatelessWidget {
  final String goalId;

  const GoalDetailsScreen({super.key, required this.goalId});

  @override
  Widget build(BuildContext context) {
    return Consumer<GoalsController>(
      builder: (context, controller, child) {
        final goal = controller.goals.firstWhere(
          (g) => g.id == goalId,
          orElse: () => controller.goals.first,
        );

        return CupertinoPageScaffold(
          backgroundColor: AppStyles.getBackground(context),
          navigationBar: CupertinoNavigationBar(
            middle: Text('Goal Details', style: TextStyle(color: AppStyles.getTextColor(context))),
            previousPageTitle: 'Goals',
            backgroundColor: AppStyles.getBackground(context),
            border: null,
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => _showOptionsSheet(context, goal, controller),
              child: Icon(
                CupertinoIcons.ellipsis_circle,
                color: AppStyles.accentBlue,
              ),
            ),
          ),
          child: SafeArea(
            child: CustomScrollView(
              slivers: [
                // Progress Section
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
                                  color: goal.color.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(Radii.lg),
                                ),
                                child: Icon(
                                  goal.getTypeIcon(),
                                  color: goal.color,
                                  size: IconSizes.xl,
                                ),
                              ),
                              SizedBox(width: Spacing.lg),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      goal.name,
                                      style: TextStyle(
                                        fontSize: TypeScale.title2,
                                        fontWeight: FontWeight.bold,
                                        color: AppStyles.getTextColor(context),
                                      ),
                                    ),
                                    SizedBox(height: Spacing.xs),
                                    Text(
                                      goal.getTypeLabel(),
                                      style: TextStyle(
                                        fontSize: TypeScale.subhead,
                                        color: AppStyles.getSecondaryTextColor(context),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: Spacing.xxl),
                          LiquidCircularProgress(
                            progress: goal.progressPercentage / 100,
                            size: 180,
                            color: goal.color,
                            center: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                counter_widgets.AnimatedCounter(
                                  value: goal.progressPercentage,
                                  suffix: '%',
                                  decimalPlaces: 1,
                                  textStyle: TextStyle(
                                    fontSize: TypeScale.hero,
                                    fontWeight: FontWeight.bold,
                                    color: goal.color,
                                  ),
                                ),
                                SizedBox(height: Spacing.xs),
                                Text(
                                  'Complete',
                                  style: TextStyle(
                                    fontSize: TypeScale.footnote,
                                    color: AppStyles.getSecondaryTextColor(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: Spacing.xxl),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  children: [
                                    Text(
                                      'Current',
                                      style: TextStyle(
                                        fontSize: TypeScale.footnote,
                                        color: AppStyles.getSecondaryTextColor(context),
                                      ),
                                    ),
                                    SizedBox(height: Spacing.xs),
                                    counter_widgets.CurrencyCounter(
                                      value: goal.currentAmount,
                                      textStyle: TextStyle(
                                        fontSize: TypeScale.title1,
                                        fontWeight: FontWeight.bold,
                                        color: goal.color,
                                      ),
                                      decimalPlaces: 0,
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 40,
                                color: AppStyles.getSecondaryTextColor(context).withValues(alpha: 0.2),
                              ),
                              Expanded(
                                child: Column(
                                  children: [
                                    Text(
                                      'Target',
                                      style: TextStyle(
                                        fontSize: TypeScale.footnote,
                                        color: AppStyles.getSecondaryTextColor(context),
                                      ),
                                    ),
                                    SizedBox(height: Spacing.xs),
                                    counter_widgets.CurrencyCounter(
                                      value: goal.targetAmount,
                                      textStyle: TextStyle(
                                        fontSize: TypeScale.title1,
                                        fontWeight: FontWeight.bold,
                                        color: AppStyles.getTextColor(context),
                                      ),
                                      decimalPlaces: 0,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Stats Cards
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
                                Icon(
                                  CupertinoIcons.money_dollar_circle_fill,
                                  color: SemanticColors.success,
                                  size: IconSizes.lg,
                                ),
                                SizedBox(height: Spacing.md),
                                Text(
                                  'Remaining',
                                  style: TextStyle(
                                    fontSize: TypeScale.footnote,
                                    color: AppStyles.getSecondaryTextColor(context),
                                  ),
                                ),
                                SizedBox(height: Spacing.xs),
                                counter_widgets.CurrencyCounter(
                                  value: goal.remainingAmount,
                                  textStyle: TextStyle(
                                    fontSize: TypeScale.title3,
                                    fontWeight: FontWeight.bold,
                                    color: AppStyles.getTextColor(context),
                                  ),
                                  decimalPlaces: 0,
                                ),
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
                                Icon(
                                  CupertinoIcons.calendar,
                                  color: SemanticColors.info,
                                  size: IconSizes.lg,
                                ),
                                SizedBox(height: Spacing.md),
                                Text(
                                  'Days Left',
                                  style: TextStyle(
                                    fontSize: TypeScale.footnote,
                                    color: AppStyles.getSecondaryTextColor(context),
                                  ),
                                ),
                                SizedBox(height: Spacing.xs),
                                counter_widgets.AnimatedCounter(
                                  value: goal.daysRemaining.toDouble(),
                                  textStyle: TextStyle(
                                    fontSize: TypeScale.title3,
                                    fontWeight: FontWeight.bold,
                                    color: goal.daysRemaining < 0
                                        ? SemanticColors.error
                                        : goal.daysRemaining <= 30
                                            ? SemanticColors.warning
                                            : AppStyles.getTextColor(context),
                                  ),
                                  decimalPlaces: 0,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: Spacing.md).toSliverBox(),

                // Recommendation Card
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: Spacing.lg),
                    child: NeumorphicGlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                goal.isOnTrack ? CupertinoIcons.checkmark_seal_fill : CupertinoIcons.info_circle_fill,
                                color: goal.isOnTrack ? SemanticColors.success : SemanticColors.warning,
                                size: IconSizes.lg,
                              ),
                              SizedBox(width: Spacing.md),
                              Expanded(
                                child: Text(
                                  goal.isOnTrack ? 'On Track!' : 'Behind Schedule',
                                  style: TextStyle(
                                    fontSize: TypeScale.callout,
                                    fontWeight: FontWeight.w600,
                                    color: AppStyles.getTextColor(context),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: Spacing.lg),
                          Text(
                            'Recommended Monthly Savings',
                            style: TextStyle(
                              fontSize: TypeScale.footnote,
                              color: AppStyles.getSecondaryTextColor(context),
                            ),
                          ),
                          SizedBox(height: Spacing.xs),
                          counter_widgets.CurrencyCounter(
                            value: goal.recommendedMonthlySavings,
                            textStyle: TextStyle(
                              fontSize: TypeScale.title1,
                              fontWeight: FontWeight.bold,
                              color: goal.isOnTrack ? SemanticColors.success : SemanticColors.warning,
                            ),
                          ),
                          SizedBox(height: Spacing.sm),
                          Text(
                            goal.isOnTrack
                                ? 'Keep up the great work! You\'re on pace to reach your goal.'
                                : 'Save this amount monthly to reach your goal on time.',
                            style: TextStyle(
                              fontSize: TypeScale.footnote,
                              color: AppStyles.getSecondaryTextColor(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                SizedBox(height: Spacing.xl).toSliverBox(),

                // Contribution History Header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: Spacing.lg),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Contribution History',
                          style: TextStyle(
                            fontSize: TypeScale.title3,
                            fontWeight: FontWeight.bold,
                            color: AppStyles.getTextColor(context),
                          ),
                        ),
                        Text(
                          '${goal.contributions.length} entries',
                          style: TextStyle(
                            fontSize: TypeScale.footnote,
                            color: AppStyles.getSecondaryTextColor(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: Spacing.md).toSliverBox(),

                // Contribution List
                if (goal.contributions.isEmpty)
                  SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            CupertinoIcons.money_dollar_circle,
                            size: IconSizes.huge,
                            color: AppStyles.getSecondaryTextColor(context),
                          ),
                          SizedBox(height: Spacing.lg),
                          Text(
                            'No contributions yet',
                            style: TextStyle(
                              fontSize: TypeScale.title3,
                              fontWeight: FontWeight.w600,
                              color: AppStyles.getTextColor(context),
                            ),
                          ),
                          SizedBox(height: Spacing.sm),
                          Text(
                            'Add your first contribution\nto start tracking progress',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: TypeScale.body,
                              color: AppStyles.getSecondaryTextColor(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: EdgeInsets.symmetric(horizontal: Spacing.lg),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final sortedContributions = goal.contributions.toList()..sort((a, b) => b.date.compareTo(a.date));
                          final contribution = sortedContributions[index];
                          return StaggeredItem(
                            index: index,
                            child: Padding(
                              padding: EdgeInsets.only(bottom: Spacing.md),
                              child: GlassCard(
                                padding: EdgeInsets.all(Spacing.lg),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(Spacing.md),
                                      decoration: BoxDecoration(
                                        color: goal.color.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(Radii.md),
                                      ),
                                      child: Icon(
                                        CupertinoIcons.arrow_down_circle_fill,
                                        color: goal.color,
                                        size: IconSizes.lg,
                                      ),
                                    ),
                                    SizedBox(width: Spacing.md),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          counter_widgets.CurrencyCounter(
                                            value: contribution.amount,
                                            textStyle: TextStyle(
                                              fontSize: TypeScale.callout,
                                              fontWeight: FontWeight.bold,
                                              color: AppStyles.getTextColor(context),
                                            ),
                                            decimalPlaces: 2,
                                          ),
                                          SizedBox(height: Spacing.xxs),
                                          Text(
                                            DateFormat('MMM dd, yyyy').format(contribution.date),
                                            style: TextStyle(
                                              fontSize: TypeScale.footnote,
                                              color: AppStyles.getSecondaryTextColor(context),
                                            ),
                                          ),
                                          if (contribution.notes != null && contribution.notes!.isNotEmpty) ...[
                                            SizedBox(height: Spacing.xxs),
                                            Text(
                                              contribution.notes!,
                                              style: TextStyle(
                                                fontSize: TypeScale.footnote,
                                                color: AppStyles.getSecondaryTextColor(context),
                                                fontStyle: FontStyle.italic,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                        childCount: goal.contributions.length,
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

  void _showOptionsSheet(BuildContext context, Goal goal, GoalsController controller) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              showCupertinoModalPopup(
                context: context,
                builder: (context) => AddContributionModal(goal: goal),
              );
            },
            child: Row(
              children: [
                Icon(CupertinoIcons.add_circled_solid, color: SemanticColors.success),
                SizedBox(width: Spacing.md),
                Text('Add Contribution'),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              showCupertinoModalPopup(
                context: context,
                builder: (context) => EditGoalModal(goal: goal),
              );
            },
            child: Row(
              children: [
                Icon(CupertinoIcons.pencil),
                SizedBox(width: Spacing.md),
                Text('Edit Goal'),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.pop(context);
              final confirmed = await AlertService.showConfirmDialog(
                context,
                title: 'Delete Goal',
                message: 'Are you sure you want to delete "${goal.name}"? This action cannot be undone.',
                confirmText: 'Delete',
                isDestructive: true,
              );
              if (confirmed) {
                await controller.deleteGoal(goal.id);
                Navigator.of(context).pop();
                AlertService.showSuccess(context, 'Goal deleted');
              }
            },
            isDestructiveAction: true,
            child: Row(
              children: [
                Icon(CupertinoIcons.trash),
                SizedBox(width: Spacing.md),
                Text('Delete Goal'),
              ],
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
      ),
    );
  }
}

extension on Widget {
  Widget toSliverBox() => SliverToBoxAdapter(child: this);
}
