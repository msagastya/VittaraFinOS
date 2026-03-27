import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchTextController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<GoalsController>(context, listen: false).initialize();
      // Restore search query from PageStorage.
      final saved = PageStorage.of(context).readState(context,
          identifier: const ValueKey('goals_search')) as String?;
      if (saved != null && saved.isNotEmpty) {
        setState(() {
          _searchQuery = saved;
          _searchTextController.text = saved;
        });
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchTextController.dispose();
    super.dispose();
  }

  Future<void> _showAddGoalModal() async {
    await showCupertinoModalPopup(
      context: context,
      builder: (context) => const AddGoalModal(),
    );
    // Refresh controller after modal closes to pick up any new goals.
    if (mounted) {
      Provider.of<GoalsController>(context, listen: false).initialize();
    }
  }

  void _scrollToExpiringSoon() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppStyles.getBackground(context),
      navigationBar: AppStyles.isLandscape(context) ? null : CupertinoNavigationBar(
        middle: Text('Goals',
            style: TextStyle(color: AppStyles.getTextColor(context))),
        previousPageTitle: 'Back',
        backgroundColor: AppStyles.getBackground(context),
        border: null,
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => _showFilterSheet(),
          child: const Icon(
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
                        key: const PageStorageKey('goals_list'),
                        controller: _scrollController,
                        slivers: [
                          if (AppStyles.isLandscape(context))
                            SliverToBoxAdapter(
                              child: _buildLandscapeNavBar(context, controller),
                            ),
                          // Pull-to-refresh
                          CupertinoSliverRefreshControl(
                            onRefresh: () async {
                              HapticFeedback.mediumImpact();
                              await Provider.of<GoalsController>(context,
                                      listen: false)
                                  .reloadFromStorage();
                            },
                          ),
                          // Stats Header
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.all(Spacing.lg),
                              child: _buildStatsSection(controller),
                            ),
                          ),

                          // Search Bar
                          SliverToBoxAdapter(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: Spacing.lg),
                              child: GlassCard(
                                padding: EdgeInsets.zero,
                                child: CupertinoSearchTextField(
                                  controller: _searchTextController,
                                  backgroundColor: Colors.transparent,
                                  style: TextStyle(
                                      color: AppStyles.getTextColor(context)),
                                  placeholder: 'Search Goals',
                                  placeholderStyle: TextStyle(
                                      color: AppStyles.getSecondaryTextColor(
                                          context)),
                                  onChanged: (value) {
                                    setState(() => _searchQuery = value);
                                    PageStorage.of(context).writeState(context,
                                        value,
                                        identifier: const ValueKey('goals_search'));
                                  },
                                ),
                              ),
                            ),
                          ),

                          // Expiring Soon Banner
                          if (expiringGoals.isNotEmpty)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.all(Spacing.lg),
                                child: _buildExpiringSoonBanner(expiringGoals),
                              ),
                            ),

                          // Active Filter Chip
                          if (_filterType != null)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: Spacing.lg,
                                    vertical: Spacing.sm),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
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
                                              color: AppStyles.aetherTeal,
                                            ).getTypeLabel(),
                                            style: TextStyle(
                                              color: SemanticColors.getPrimary(
                                                  context),
                                              fontSize: TypeScale.footnote,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(width: Spacing.sm),
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
                                    const SizedBox(height: Spacing.lg),
                                    Text(
                                      'No goals found',
                                      style: TextStyle(
                                        fontSize: TypeScale.title3,
                                        fontWeight: FontWeight.w600,
                                        color: AppStyles.getTextColor(context),
                                      ),
                                    ),
                                    const SizedBox(height: Spacing.sm),
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
                              padding: const EdgeInsets.all(Spacing.lg),
                              sliver: SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    final goal = filteredGoals[index];
                                    return StaggeredItem(
                                      index: index,
                                      child: Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: Spacing.lg),
                                        child: _buildSlidableGoalCard(goal),
                                      ),
                                    );
                                  },
                                  childCount: filteredGoals.length,
                                ),
                              ),
                            ),

                          const SliverToBoxAdapter(child: SizedBox(height: 80)),
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

  Widget _buildLandscapeNavBar(BuildContext context, GoalsController controller) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
      child: Row(
        children: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            onPressed: () => Navigator.maybePop(context),
            child: Icon(CupertinoIcons.chevron_left, size: 20,
                color: AppStyles.getPrimaryColor(context)),
          ),
          const SizedBox(width: 8),
          Text('GOALS',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                  color: AppStyles.getTextColor(context), letterSpacing: 1.1)),
          const Spacer(),
          Text(
            '${controller.activeGoals.length} active',
            style: TextStyle(fontSize: TypeScale.footnote,
                color: AppStyles.getSecondaryTextColor(context)),
          ),
          const SizedBox(width: 8),
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            onPressed: _showFilterSheet,
            child: Icon(CupertinoIcons.line_horizontal_3_decrease, size: 18,
                color: AppStyles.getPrimaryColor(context)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection(GoalsController controller) {
    return GlassCard(
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                CupertinoIcons.flag_fill,
                color: SemanticColors.success,
                size: IconSizes.lg,
              ),
              const SizedBox(width: Spacing.md),
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
          const SizedBox(height: Spacing.lg),
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
                    const SizedBox(height: Spacing.xs),
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
                    const SizedBox(height: Spacing.xs),
                    counter_widgets.CurrencyCounter(
                      value: controller.totalSavedAmount,
                      textStyle: const TextStyle(
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
          const SizedBox(height: Spacing.lg),
          LiquidLinearProgress(
            progress: controller.overallProgress / 100,
            height: 16,
            color: SemanticColors.success,
          ),
          const SizedBox(height: Spacing.sm),
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
                textStyle: const TextStyle(
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
      onPressed: () {
        if (goals.isNotEmpty) {
          // Scroll to the top of the list where expiring goals appear.
          _scrollToExpiringSoon();
        }
      },
      child: GlassCard(
        backgroundColor: SemanticColors.warning.withValues(alpha: 0.15),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(Spacing.md),
              decoration: BoxDecoration(
                color: SemanticColors.warning.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(Radii.md),
              ),
              child: const Icon(
                CupertinoIcons.time,
                color: SemanticColors.warning,
                size: IconSizes.lg,
              ),
            ),
            const SizedBox(width: Spacing.md),
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
                  const SizedBox(height: Spacing.xxs),
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
              Haptics.delete();
              toast_lib.toast.showSuccess(
                '"${goal.name}" deleted',
                actionLabel: 'Undo',
                onAction: () {
                  ctrl.addGoal(goal);
                  toast_lib.toast.showInfo('Goal restored');
                },
              );
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
          FadeScalePageRoute(
            page: GoalDetailsScreen(goalId: goal.id),
          ),
        );
      },
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconBox(
                  icon: goal.getTypeIcon(),
                  color: goal.color,
                  showGlow: true,
                ),
                const SizedBox(width: Spacing.md),
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
                      const SizedBox(height: Spacing.xxs),
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: Spacing.sm, vertical: Spacing.xxs),
                    decoration: BoxDecoration(
                      color: SemanticColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(Radii.xs),
                    ),
                    child: const Text(
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: Spacing.sm, vertical: Spacing.xxs),
                    decoration: BoxDecoration(
                      color: SemanticColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(Radii.xs),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          CupertinoIcons.time,
                          size: IconSizes.xs,
                          color: SemanticColors.warning,
                        ),
                        const SizedBox(width: Spacing.xxs),
                        Text(
                          '${daysRemaining}d',
                          style: const TextStyle(
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
            const SizedBox(height: Spacing.lg),
            LiquidLinearProgress(
              progress: goal.progressPercentage / 100,
              height: 12,
              color: goal.color,
            ),
            const SizedBox(height: Spacing.md),
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
                    const SizedBox(height: Spacing.xxs),
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
                _GoalArcProgress(
                  progress: goal.progressPercentage / 100,
                  color: goal.color,
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
                    const SizedBox(height: Spacing.xxs),
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
        padding: const EdgeInsets.all(Spacing.xxxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(Spacing.xxxl),
              decoration: BoxDecoration(
                color: SemanticColors.success.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                CupertinoIcons.flag_fill,
                size: IconSizes.emptyStateIcon,
                color: SemanticColors.success,
              ),
            ),
            const SizedBox(height: Spacing.xxl),
            Text(
              'No Goals Yet',
              style: TextStyle(
                fontSize: TypeScale.largeTitle,
                fontWeight: FontWeight.bold,
                color: AppStyles.getTextColor(context),
              ),
            ),
            const SizedBox(height: Spacing.md),
            Text(
              'Start planning your financial future by\nsetting your first goal',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: TypeScale.callout,
                color: AppStyles.getSecondaryTextColor(context),
              ),
            ),
            const SizedBox(height: Spacing.xxxl),
            BouncyButton(
              onPressed: _showAddGoalModal,
              child: Container(
                padding: const EdgeInsets.symmetric(
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
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Row(
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
        title: const Text('Filter by Goal Type'),
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
              color: AppStyles.aetherTeal,
            );
            return CupertinoActionSheetAction(
              onPressed: () {
                setState(() => _filterType = type);
                Navigator.pop(context);
              },
              child: Row(
                children: [
                  Icon(dummyGoal.getTypeIcon(), size: IconSizes.md),
                  const SizedBox(width: Spacing.md),
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
              child: const Text('Clear Filter'),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }
}

/// Animated circular arc showing goal progress percentage.
class _GoalArcProgress extends StatelessWidget {
  final double progress; // 0.0 to 1.0+
  final Color color;

  const _GoalArcProgress({required this.progress, required this.color});

  @override
  Widget build(BuildContext context) {
    final clamped = progress.clamp(0.0, 1.0);
    final label = '${(progress * 100).toStringAsFixed(0)}%';
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: clamped),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return SizedBox(
          width: 56,
          height: 56,
          child: CustomPaint(
            painter: _ArcPainter(
              progress: value,
              color: color,
              trackColor: AppStyles.getDividerColor(context),
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: progress >= 1.0
                      ? AppStyles.gain(context)
                      : color,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ArcPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color trackColor;

  const _ArcPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 5.0;
    final rect = Rect.fromLTWH(
        strokeWidth / 2, strokeWidth / 2,
        size.width - strokeWidth, size.height - strokeWidth);

    // Track
    canvas.drawArc(
      rect, -1.5707963, 6.2831853, false,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );

    if (progress > 0) {
      // Progress arc
      canvas.drawArc(
        rect, -1.5707963, 6.2831853 * progress, false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.progress != progress || old.color != color;
}
