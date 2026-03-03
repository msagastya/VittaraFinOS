import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/goals_controller.dart';
import 'package:vittara_fin_os/logic/goal_model.dart';
import 'package:vittara_fin_os/ui/manage/goals/goal_details_screen.dart';
import 'package:vittara_fin_os/ui/manage/goals/modals/add_goal_modal.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/widgets/animations.dart';
import 'package:vittara_fin_os/ui/widgets/animated_counter.dart'
    as counter_widgets;
import 'package:vittara_fin_os/ui/widgets/common_widgets.dart';
import 'package:vittara_fin_os/ui/widgets/glass_card.dart';
import 'package:vittara_fin_os/ui/widgets/liquid_progress_indicators.dart';
import 'package:vittara_fin_os/ui/widgets/toast_notification.dart' as toast_lib;
import 'package:vittara_fin_os/utils/logger.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  final AppLogger logger = AppLogger();
  GoalType? _filterType;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<GoalsController>(context, listen: false).initialize();
    });
  }

  void _showAddGoalModal() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => const AddGoalModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppStyles.getBackground(context),
      navigationBar: CupertinoNavigationBar(
        middle: Text('Goals',
            style: TextStyle(color: AppStyles.getTextColor(context))),
        previousPageTitle: 'Manage',
        backgroundColor: AppStyles.getBackground(context),
        border: null,
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => _showFilterSheet(),
          child: Icon(
            CupertinoIcons.line_horizontal_3_decrease,
            color: AppStyles.accentBlue,
          ),
        ),
      ),
      child: Consumer<GoalsController>(
        builder: (context, controller, child) {
          final filteredGoals = controller.activeGoals.where((goal) {
            final matchesSearch =
                goal.name.toLowerCase().contains(_searchQuery.toLowerCase());
            final matchesFilter =
                _filterType == null || goal.type == _filterType;
            return matchesSearch && matchesFilter;
          }).toList();

          final expiringGoals = controller.getGoalsExpiringSoon(days: 30);

          return Stack(
            children: [
              SafeArea(
                child: filteredGoals.isEmpty &&
                        _searchQuery.isEmpty &&
                        _filterType == null
                    ? _buildEmptyState()
                    : CustomScrollView(
                        slivers: [
                          // Stats Header
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.all(Spacing.lg),
                              child: _buildStatsSection(controller),
                            ),
                          ),

                          // Search Bar
                          SliverToBoxAdapter(
                            child: Padding(
                              padding:
                                  EdgeInsets.symmetric(horizontal: Spacing.lg),
                              child: GlassCard(
                                padding: EdgeInsets.zero,
                                child: CupertinoSearchTextField(
                                  backgroundColor: Colors.transparent,
                                  style: TextStyle(
                                      color: AppStyles.getTextColor(context)),
                                  placeholder: 'Search Goals',
                                  placeholderStyle: TextStyle(
                                      color: AppStyles.getSecondaryTextColor(
                                          context)),
                                  onChanged: (value) =>
                                      setState(() => _searchQuery = value),
                                ),
                              ),
                            ),
                          ),

                          // Expiring Soon Banner
                          if (expiringGoals.isNotEmpty)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: EdgeInsets.all(Spacing.lg),
                                child: _buildExpiringSoonBanner(expiringGoals),
                              ),
                            ),

                          // Active Filter Chip
                          if (_filterType != null)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                    horizontal: Spacing.lg,
                                    vertical: Spacing.sm),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: Spacing.md,
                                          vertical: Spacing.sm),
                                      decoration: BoxDecoration(
                                        color:
                                            SemanticColors.getPrimary(context)
                                                .withValues(alpha: 0.1),
                                        borderRadius:
                                            BorderRadius.circular(Radii.full),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            Goal(
                                              id: '',
                                              name: '',
                                              type: _filterType!,
                                              targetAmount: 0,
                                              currentAmount: 0,
                                              createdDate: DateTime.now(),
                                              targetDate: DateTime.now(),
                                              color: CupertinoColors.activeBlue,
                                            ).getTypeLabel(),
                                            style: TextStyle(
                                              color: SemanticColors.getPrimary(
                                                  context),
                                              fontSize: TypeScale.footnote,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          SizedBox(width: Spacing.sm),
                                          GestureDetector(
                                            onTap: () => setState(
                                                () => _filterType = null),
                                            child: Icon(
                                              CupertinoIcons.xmark_circle_fill,
                                              size: IconSizes.sm,
                                              color: SemanticColors.getPrimary(
                                                  context),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                          // Goals List
                          if (filteredGoals.isEmpty)
                            SliverFillRemaining(
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      CupertinoIcons.search,
                                      size: IconSizes.emptyStateIcon,
                                      color: AppStyles.getSecondaryTextColor(
                                          context),
                                    ),
                                    SizedBox(height: Spacing.lg),
                                    Text(
                                      'No goals found',
                                      style: TextStyle(
                                        fontSize: TypeScale.title3,
                                        fontWeight: FontWeight.w600,
                                        color: AppStyles.getTextColor(context),
                                      ),
                                    ),
                                    SizedBox(height: Spacing.sm),
                                    Text(
                                      'Try adjusting your search or filter',
                                      style: TextStyle(
                                        fontSize: TypeScale.body,
                                        color: AppStyles.getSecondaryTextColor(
                                            context),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            SliverPadding(
                              padding: EdgeInsets.all(Spacing.lg),
                              sliver: SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    final goal = filteredGoals[index];
                                    return StaggeredItem(
                                      index: index,
                                      child: Padding(
                                        padding:
                                            EdgeInsets.only(bottom: Spacing.lg),
                                        child: _buildSlidableGoalCard(goal),
                                      ),
                                    );
                                  },
                                  childCount: filteredGoals.length,
                                ),
                              ),
                            ),

                          SliverToBoxAdapter(child: SizedBox(height: 80)),
                        ],
                      ),
              ),
              Positioned(
                right: Spacing.lg,
                bottom: Spacing.xxxl,
                child: FadingFAB(
                  onPressed: _showAddGoalModal,
                  color: SemanticColors.success,
                  heroTag: 'goals_fab',
                  icon: CupertinoIcons.add,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatsSection(GoalsController controller) {
    return GlassCard(
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                CupertinoIcons.flag_fill,
                color: SemanticColors.success,
                size: IconSizes.lg,
              ),
              SizedBox(width: Spacing.md),
              Text(
                'Overall Progress',
                style: TextStyle(
                  fontSize: TypeScale.title3,
                  fontWeight: FontWeight.w600,
                  color: AppStyles.getTextColor(context),
                ),
              ),
            ],
          ),
          SizedBox(height: Spacing.lg),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Target',
                      style: TextStyle(
                        fontSize: TypeScale.footnote,
                        color: AppStyles.getSecondaryTextColor(context),
                      ),
                    ),
                    SizedBox(height: Spacing.xs),
                    counter_widgets.CurrencyCounter(
                      value: controller.totalTargetAmount,
                      textStyle: TextStyle(
                        fontSize: TypeScale.title2,
                        fontWeight: FontWeight.bold,
                        color: AppStyles.getTextColor(context),
                      ),
                      decimalPlaces: 0,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Saved',
                      style: TextStyle(
                        fontSize: TypeScale.footnote,
                        color: AppStyles.getSecondaryTextColor(context),
                      ),
                    ),
                    SizedBox(height: Spacing.xs),
                    counter_widgets.CurrencyCounter(
                      value: controller.totalSavedAmount,
                      textStyle: TextStyle(
                        fontSize: TypeScale.title2,
                        fontWeight: FontWeight.bold,
                        color: SemanticColors.success,
                      ),
                      decimalPlaces: 0,
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: Spacing.lg),
          LiquidLinearProgress(
            progress: controller.overallProgress / 100,
            height: 16,
            color: SemanticColors.success,
          ),
          SizedBox(height: Spacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${controller.activeGoals.length} active goals',
                style: TextStyle(
                  fontSize: TypeScale.footnote,
                  color: AppStyles.getSecondaryTextColor(context),
                ),
              ),
              counter_widgets.AnimatedCounter(
                value: controller.overallProgress,
                suffix: '%',
                decimalPlaces: 1,
                textStyle: TextStyle(
                  fontSize: TypeScale.footnote,
                  fontWeight: FontWeight.w600,
                  color: SemanticColors.success,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExpiringSoonBanner(List<Goal> goals) {
    return BouncyButton(
      onPressed: () {},
      child: GlassCard(
        backgroundColor: SemanticColors.warning.withValues(alpha: 0.15),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(Spacing.md),
              decoration: BoxDecoration(
                color: SemanticColors.warning.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(Radii.md),
              ),
              child: Icon(
                CupertinoIcons.time,
                color: SemanticColors.warning,
                size: IconSizes.lg,
              ),
            ),
            SizedBox(width: Spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${goals.length} goal${goals.length > 1 ? 's' : ''} expiring soon',
                    style: TextStyle(
                      fontSize: TypeScale.callout,
                      fontWeight: FontWeight.w600,
                      color: AppStyles.getTextColor(context),
                    ),
                  ),
                  SizedBox(height: Spacing.xxs),
                  Text(
                    'Within next 30 days',
                    style: TextStyle(
                      fontSize: TypeScale.footnote,
                      color: AppStyles.getSecondaryTextColor(context),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              CupertinoIcons.chevron_right,
              size: IconSizes.sm,
              color: AppStyles.getSecondaryTextColor(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlidableGoalCard(Goal goal) {
    return Slidable(
      key: ValueKey(goal.id),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.22,
        children: [
          SlidableAction(
            onPressed: (_) => _deleteGoalWithConfirmation(goal),
            backgroundColor: SemanticColors.error,
            foregroundColor: CupertinoColors.white,
            icon: CupertinoIcons.trash_fill,
            borderRadius: BorderRadius.circular(Radii.lg),
          ),
        ],
      ),
      child: _buildGoalCard(goal),
    );
  }

  void _deleteGoalWithConfirmation(Goal goal) {
    Haptics.warning();
    showCupertinoDialog<void>(
      context: context,
      builder: (dialogCtx) => CupertinoAlertDialog(
        title: const Text('Delete Goal'),
        content: Text('Delete "${goal.name}"? This cannot be undone.'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(dialogCtx),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Delete'),
            onPressed: () async {
              final ctrl = Provider.of<GoalsController>(context, listen: false);
              await ctrl.deleteGoal(goal.id);
              Navigator.pop(dialogCtx);
              toast_lib.toast.showSuccess('"${goal.name}" deleted');
              Haptics.delete();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildGoalCard(Goal goal) {
    final daysRemaining = goal.daysRemaining;
    final isExpiringSoon = daysRemaining <= 30 && daysRemaining > 0;
    final isOverdue = daysRemaining < 0;

    return BouncyButton(
      onPressed: () {
        Navigator.of(context).push(
          CupertinoPageRoute(
            builder: (context) => GoalDetailsScreen(goalId: goal.id),
          ),
        );
      },
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(Spacing.md),
                  decoration: BoxDecoration(
                    color: goal.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(Radii.md),
                  ),
                  child: Icon(
                    goal.getTypeIcon(),
                    color: goal.color,
                    size: IconSizes.lg,
                  ),
                ),
                SizedBox(width: Spacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        goal.name,
                        style: TextStyle(
                          fontSize: TypeScale.callout,
                          fontWeight: FontWeight.w600,
                          color: AppStyles.getTextColor(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: Spacing.xxs),
                      Text(
                        goal.getTypeLabel(),
                        style: TextStyle(
                          fontSize: TypeScale.footnote,
                          color: AppStyles.getSecondaryTextColor(context),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isOverdue)
                  Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: Spacing.sm, vertical: Spacing.xxs),
                    decoration: BoxDecoration(
                      color: SemanticColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(Radii.xs),
                    ),
                    child: Text(
                      'OVERDUE',
                      style: TextStyle(
                        fontSize: TypeScale.caption,
                        fontWeight: FontWeight.w700,
                        color: SemanticColors.error,
                      ),
                    ),
                  )
                else if (isExpiringSoon)
                  Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: Spacing.sm, vertical: Spacing.xxs),
                    decoration: BoxDecoration(
                      color: SemanticColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(Radii.xs),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          CupertinoIcons.time,
                          size: IconSizes.xs,
                          color: SemanticColors.warning,
                        ),
                        SizedBox(width: Spacing.xxs),
                        Text(
                          '${daysRemaining}d',
                          style: TextStyle(
                            fontSize: TypeScale.caption,
                            fontWeight: FontWeight.w700,
                            color: SemanticColors.warning,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            SizedBox(height: Spacing.lg),
            LiquidLinearProgress(
              progress: goal.progressPercentage / 100,
              height: 12,
              color: goal.color,
            ),
            SizedBox(height: Spacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Saved',
                      style: TextStyle(
                        fontSize: TypeScale.footnote,
                        color: AppStyles.getSecondaryTextColor(context),
                      ),
                    ),
                    SizedBox(height: Spacing.xxs),
                    counter_widgets.CurrencyCounter(
                      value: goal.currentAmount,
                      textStyle: TextStyle(
                        fontSize: TypeScale.callout,
                        fontWeight: FontWeight.w700,
                        color: goal.color,
                      ),
                      decimalPlaces: 0,
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    counter_widgets.AnimatedCounter(
                      value: goal.progressPercentage,
                      suffix: '%',
                      decimalPlaces: 1,
                      textStyle: TextStyle(
                        fontSize: TypeScale.title2,
                        fontWeight: FontWeight.bold,
                        color: goal.color,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Target',
                      style: TextStyle(
                        fontSize: TypeScale.footnote,
                        color: AppStyles.getSecondaryTextColor(context),
                      ),
                    ),
                    SizedBox(height: Spacing.xxs),
                    counter_widgets.CurrencyCounter(
                      value: goal.targetAmount,
                      textStyle: TextStyle(
                        fontSize: TypeScale.callout,
                        fontWeight: FontWeight.w700,
                        color: AppStyles.getTextColor(context),
                      ),
                      decimalPlaces: 0,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(Spacing.xxxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(Spacing.xxxl),
              decoration: BoxDecoration(
                color: SemanticColors.success.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                CupertinoIcons.flag_fill,
                size: IconSizes.emptyStateIcon,
                color: SemanticColors.success,
              ),
            ),
            SizedBox(height: Spacing.xxl),
            Text(
              'No Goals Yet',
              style: TextStyle(
                fontSize: TypeScale.largeTitle,
                fontWeight: FontWeight.bold,
                color: AppStyles.getTextColor(context),
              ),
            ),
            SizedBox(height: Spacing.md),
            Text(
              'Start planning your financial future by\nsetting your first goal',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: TypeScale.callout,
                color: AppStyles.getSecondaryTextColor(context),
              ),
            ),
            SizedBox(height: Spacing.xxxl),
            BouncyButton(
              onPressed: _showAddGoalModal,
              child: Container(
                padding: EdgeInsets.symmetric(
                    horizontal: Spacing.xxl, vertical: Spacing.lg),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      SemanticColors.success,
                      SemanticColors.success.withValues(alpha: 0.8)
                    ],
                  ),
                  borderRadius: BorderRadius.circular(Radii.full),
                  boxShadow: [
                    BoxShadow(
                      color: SemanticColors.success.withValues(alpha: 0.4),
                      blurRadius: 20,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.add,
                        color: Colors.white, size: IconSizes.lg),
                    SizedBox(width: Spacing.sm),
                    Text(
                      'Create Your First Goal',
                      style: TextStyle(
                        fontSize: TypeScale.callout,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFilterSheet() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text('Filter by Goal Type'),
        actions: [
          ...GoalType.values.map((type) {
            final dummyGoal = Goal(
              id: '',
              name: '',
              type: type,
              targetAmount: 0,
              currentAmount: 0,
              createdDate: DateTime.now(),
              targetDate: DateTime.now(),
              color: CupertinoColors.activeBlue,
            );
            return CupertinoActionSheetAction(
              onPressed: () {
                setState(() => _filterType = type);
                Navigator.pop(context);
              },
              child: Row(
                children: [
                  Icon(dummyGoal.getTypeIcon(), size: IconSizes.md),
                  SizedBox(width: Spacing.md),
                  Text(dummyGoal.getTypeLabel()),
                ],
              ),
            );
          }),
          if (_filterType != null)
            CupertinoActionSheetAction(
              onPressed: () {
                setState(() => _filterType = null);
                Navigator.pop(context);
              },
              isDestructiveAction: true,
              child: Text('Clear Filter'),
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
