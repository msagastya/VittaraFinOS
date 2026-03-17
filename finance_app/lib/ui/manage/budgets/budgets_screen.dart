import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/budgets_controller.dart';
import 'package:vittara_fin_os/logic/budget_model.dart';
import 'package:vittara_fin_os/ui/manage/budgets/budget_details_screen.dart';
import 'package:vittara_fin_os/ui/manage/budgets/modals/add_budget_modal.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/widgets/animations.dart';
import 'package:vittara_fin_os/ui/widgets/animated_counter.dart'
    as counter_widgets;
import 'package:vittara_fin_os/ui/widgets/common_widgets.dart';
import 'package:vittara_fin_os/ui/widgets/glass_card.dart';
import 'package:vittara_fin_os/ui/widgets/liquid_progress_indicators.dart';
import 'package:vittara_fin_os/ui/widgets/toast_notification.dart' as toast_lib;

class BudgetsScreen extends StatefulWidget {
  const BudgetsScreen({super.key});

  @override
  State<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends State<BudgetsScreen> {
  BudgetPeriod? _filterPeriod;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<BudgetsController>(context, listen: false).initialize();
    });
  }

  void _showAddBudgetModal() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => const AddBudgetModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppStyles.getBackground(context),
      navigationBar: CupertinoNavigationBar(
        middle: Text('Budgets',
            style: TextStyle(color: AppStyles.getTextColor(context))),
        previousPageTitle: 'Manage',
        backgroundColor: AppStyles.getBackground(context),
        border: null,
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => _showPeriodFilter(),
          child: const Icon(CupertinoIcons.line_horizontal_3_decrease,
              color: AppStyles.accentBlue),
        ),
      ),
      child: Consumer<BudgetsController>(
        builder: (context, controller, child) {
          final filteredBudgets = controller.activeBudgets.where((budget) {
            return _filterPeriod == null || budget.period == _filterPeriod;
          }).toList();

          final warningBudgets = controller.getBudgetsInWarning();
          final exceededBudgets = controller.getBudgetsExceedingLimit();

          return Stack(
            children: [
              SafeArea(
                child: filteredBudgets.isEmpty && _filterPeriod == null
                    ? _buildEmptyState()
                    : CustomScrollView(
                        slivers: [
                          // Pull-to-refresh
                          CupertinoSliverRefreshControl(
                            onRefresh: () async {
                              HapticFeedback.mediumImpact();
                              await Provider.of<BudgetsController>(context,
                                      listen: false)
                                  .reloadFromStorage();
                            },
                          ),
                          if (exceededBudgets.isNotEmpty)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.all(Spacing.lg),
                                child: _buildWarningBanner(
                                    exceededBudgets.length, true),
                              ),
                            ),
                          if (warningBudgets.isNotEmpty &&
                              exceededBudgets.isEmpty)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.all(Spacing.lg),
                                child: _buildWarningBanner(
                                    warningBudgets.length, false),
                              ),
                            ),
                          if (_filterPeriod != null)
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
                                            Budget(
                                              id: '',
                                              name: '',
                                              limitAmount: 0,
                                              spentAmount: 0,
                                              period: _filterPeriod!,
                                              startDate: DateTime.now(),
                                              endDate: DateTime.now(),
                                              color: AppStyles.aetherTeal,
                                            ).getPeriodLabel(),
                                            style: TextStyle(
                                                color:
                                                    SemanticColors.getPrimary(
                                                        context),
                                                fontSize: TypeScale.footnote,
                                                fontWeight: FontWeight.w600),
                                          ),
                                          const SizedBox(width: Spacing.sm),
                                          GestureDetector(
                                            onTap: () => setState(
                                                () => _filterPeriod = null),
                                            child: Icon(
                                                CupertinoIcons
                                                    .xmark_circle_fill,
                                                size: IconSizes.sm,
                                                color:
                                                    SemanticColors.getPrimary(
                                                        context)),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          if (filteredBudgets.isEmpty)
                            SliverFillRemaining(
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(CupertinoIcons.search,
                                        size: IconSizes.emptyStateIcon,
                                        color: AppStyles.getSecondaryTextColor(
                                            context)),
                                    const SizedBox(height: Spacing.lg),
                                    Text('No budgets found',
                                        style: TextStyle(
                                            fontSize: TypeScale.title3,
                                            fontWeight: FontWeight.w600,
                                            color: AppStyles.getTextColor(
                                                context))),
                                    const SizedBox(height: Spacing.sm),
                                    Text('Try adjusting your filter',
                                        style: TextStyle(
                                            fontSize: TypeScale.body,
                                            color:
                                                AppStyles.getSecondaryTextColor(
                                                    context))),
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
                                    final budget = filteredBudgets[index];
                                    return StaggeredItem(
                                      index: index,
                                      child: Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: Spacing.lg),
                                        child: _buildSlidableBudgetCard(budget),
                                      ),
                                    );
                                  },
                                  childCount: filteredBudgets.length,
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
                  onPressed: _showAddBudgetModal,
                  color: SemanticColors.primary,
                  heroTag: 'budgets_fab',
                  icon: CupertinoIcons.add,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildWarningBanner(int count, bool isExceeded) {
    return GlassCard(
      backgroundColor:
          (isExceeded ? SemanticColors.error : SemanticColors.warning)
              .withValues(alpha: 0.15),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(Spacing.md),
            decoration: BoxDecoration(
              color:
                  (isExceeded ? SemanticColors.error : SemanticColors.warning)
                      .withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(Radii.md),
            ),
            child: Icon(
              isExceeded
                  ? CupertinoIcons.exclamationmark_octagon_fill
                  : CupertinoIcons.exclamationmark_triangle_fill,
              color: isExceeded ? SemanticColors.error : SemanticColors.warning,
              size: IconSizes.lg,
            ),
          ),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isExceeded
                      ? '$count budget${count > 1 ? 's' : ''} exceeded'
                      : '$count budget${count > 1 ? 's' : ''} near limit',
                  style: TextStyle(
                      fontSize: TypeScale.callout,
                      fontWeight: FontWeight.w600,
                      color: AppStyles.getTextColor(context)),
                ),
                const SizedBox(height: Spacing.xxs),
                Text(
                  isExceeded ? 'Review your spending' : 'Monitor your expenses',
                  style: TextStyle(
                      fontSize: TypeScale.footnote,
                      color: AppStyles.getSecondaryTextColor(context)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlidableBudgetCard(Budget budget) {
    return Slidable(
      key: ValueKey(budget.id),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.22,
        children: [
          SlidableAction(
            onPressed: (_) => _deleteBudgetWithConfirmation(budget),
            backgroundColor: SemanticColors.error,
            foregroundColor: CupertinoColors.white,
            icon: CupertinoIcons.trash_fill,
            borderRadius: BorderRadius.circular(Radii.lg),
          ),
        ],
      ),
      child: _buildBudgetCard(budget),
    );
  }

  void _deleteBudgetWithConfirmation(Budget budget) {
    Haptics.warning();
    showCupertinoDialog<void>(
      context: context,
      builder: (dialogCtx) => CupertinoAlertDialog(
        title: const Text('Delete Budget'),
        content: Text('Delete "${budget.name}"? This cannot be undone.'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(dialogCtx),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Delete'),
            onPressed: () async {
              final ctrl =
                  Provider.of<BudgetsController>(context, listen: false);
              await ctrl.deleteBudget(budget.id);
              Navigator.pop(dialogCtx);
              Haptics.delete();
              toast_lib.toast.showSuccess(
                '"${budget.name}" deleted',
                actionLabel: 'Undo',
                onAction: () {
                  ctrl.addBudget(budget);
                  toast_lib.toast.showInfo('Budget restored');
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetCard(Budget budget) {
    final statusColor = budget.status == BudgetStatus.exceeded
        ? SemanticColors.error
        : budget.status == BudgetStatus.warning
            ? SemanticColors.warning
            : SemanticColors.success;

    return BouncyButton(
      onPressed: () {
        Navigator.of(context).push(
          FadeScalePageRoute(
              page: BudgetDetailsScreen(budgetId: budget.id)),
        );
      },
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconBox(
                  icon: budget.getPeriodIcon(),
                  color: budget.color,
                  showGlow: true,
                ),
                const SizedBox(width: Spacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(budget.name,
                          style: TextStyle(
                              fontSize: TypeScale.callout,
                              fontWeight: FontWeight.w600,
                              color: AppStyles.getTextColor(context)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: Spacing.xxs),
                      Text(budget.getPeriodLabel(),
                          style: TextStyle(
                              fontSize: TypeScale.footnote,
                              color: AppStyles.getSecondaryTextColor(context))),
                    ],
                  ),
                ),
                if (budget.status != BudgetStatus.onTrack)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: Spacing.sm, vertical: Spacing.xxs),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(Radii.xs),
                    ),
                    child: Text(
                      budget.status == BudgetStatus.exceeded
                          ? 'OVER'
                          : 'WARNING',
                      style: TextStyle(
                          fontSize: TypeScale.caption,
                          fontWeight: FontWeight.w700,
                          color: statusColor),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: Spacing.lg),
            _ShakingBudgetBar(
              progress: budget.usagePercentage / 100,
              color: statusColor,
              isExceeded: budget.status == BudgetStatus.exceeded,
            ),
            const SizedBox(height: Spacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Spent',
                        style: TextStyle(
                            fontSize: TypeScale.footnote,
                            color: AppStyles.getSecondaryTextColor(context))),
                    const SizedBox(height: Spacing.xxs),
                    counter_widgets.CurrencyCounter(
                        value: budget.spentAmount,
                        textStyle: TextStyle(
                            fontSize: TypeScale.callout,
                            fontWeight: FontWeight.w700,
                            color: statusColor),
                        decimalPlaces: 0),
                  ],
                ),
                Column(
                  children: [
                    counter_widgets.AnimatedCounter(
                        value: budget.usagePercentage,
                        suffix: '%',
                        decimalPlaces: 1,
                        textStyle: TextStyle(
                            fontSize: TypeScale.title2,
                            fontWeight: FontWeight.bold,
                            color: statusColor)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Limit',
                        style: TextStyle(
                            fontSize: TypeScale.footnote,
                            color: AppStyles.getSecondaryTextColor(context))),
                    const SizedBox(height: Spacing.xxs),
                    counter_widgets.CurrencyCounter(
                        value: budget.limitAmount,
                        textStyle: TextStyle(
                            fontSize: TypeScale.callout,
                            fontWeight: FontWeight.w700,
                            color: AppStyles.getTextColor(context)),
                        decimalPlaces: 0),
                  ],
                ),
              ],
            ),
            if (budget.daysRemaining > 0) ...[
              const SizedBox(height: Spacing.md),
              Row(
                children: [
                  Icon(CupertinoIcons.time,
                      size: IconSizes.sm,
                      color: AppStyles.getSecondaryTextColor(context)),
                  const SizedBox(width: Spacing.xs),
                  Text('${budget.daysRemaining} days remaining',
                      style: TextStyle(
                          fontSize: TypeScale.footnote,
                          color: AppStyles.getSecondaryTextColor(context))),
                ],
              ),
            ],
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
                  color: SemanticColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle),
              child: const Icon(CupertinoIcons.chart_pie_fill,
                  size: IconSizes.emptyStateIcon,
                  color: SemanticColors.primary),
            ),
            const SizedBox(height: Spacing.xxl),
            Text('No Budgets Yet',
                style: TextStyle(
                    fontSize: TypeScale.largeTitle,
                    fontWeight: FontWeight.bold,
                    color: AppStyles.getTextColor(context))),
            const SizedBox(height: Spacing.md),
            Text('Start tracking your spending by\ncreating your first budget',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: TypeScale.callout,
                    color: AppStyles.getSecondaryTextColor(context))),
            const SizedBox(height: Spacing.xxxl),
            BouncyButton(
              onPressed: _showAddBudgetModal,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: Spacing.xxl, vertical: Spacing.lg),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    SemanticColors.primary,
                    SemanticColors.primary.withValues(alpha: 0.8)
                  ]),
                  borderRadius: BorderRadius.circular(Radii.full),
                  boxShadow: [
                    BoxShadow(
                        color: SemanticColors.primary.withValues(alpha: 0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 8))
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.add,
                        color: Colors.white, size: IconSizes.lg),
                    SizedBox(width: Spacing.sm),
                    Text('Create Your First Budget',
                        style: TextStyle(
                            fontSize: TypeScale.callout,
                            fontWeight: FontWeight.w600,
                            color: Colors.white)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPeriodFilter() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Filter by Period'),
        actions: [
          ...BudgetPeriod.values.map((period) {
            final dummyBudget = Budget(
                id: '',
                name: '',
                limitAmount: 0,
                spentAmount: 0,
                period: period,
                startDate: DateTime.now(),
                endDate: DateTime.now(),
                color: AppStyles.aetherTeal);
            return CupertinoActionSheetAction(
              onPressed: () {
                setState(() => _filterPeriod = period);
                Navigator.pop(context);
              },
              child: Row(
                children: [
                  Icon(dummyBudget.getPeriodIcon(), size: IconSizes.md),
                  const SizedBox(width: Spacing.md),
                  Text(dummyBudget.getPeriodLabel()),
                ],
              ),
            );
          }),
          if (_filterPeriod != null)
            CupertinoActionSheetAction(
              onPressed: () {
                setState(() => _filterPeriod = null);
                Navigator.pop(context);
              },
              isDestructiveAction: true,
              child: const Text('Clear Filter'),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      ),
    );
  }
}

/// Budget progress bar that shakes when the budget is exceeded.
class _ShakingBudgetBar extends StatefulWidget {
  final double progress; // usagePercentage / 100
  final Color color;
  final bool isExceeded;

  const _ShakingBudgetBar({
    required this.progress,
    required this.color,
    required this.isExceeded,
  });

  @override
  State<_ShakingBudgetBar> createState() => _ShakingBudgetBarState();
}

class _ShakingBudgetBarState extends State<_ShakingBudgetBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _offset;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _offset = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 6.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 6.0, end: -6.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -6.0, end: 5.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 5.0, end: -5.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -5.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.linear));

    if (widget.isExceeded) {
      Future.delayed(const Duration(milliseconds: 350), () {
        if (mounted) _ctrl.forward();
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _offset,
      builder: (context, child) => Transform.translate(
        offset: Offset(_offset.value, 0),
        child: child,
      ),
      child: LiquidLinearProgress(
        progress: widget.progress.clamp(0.0, 1.0),
        height: 12,
        color: widget.color,
      ),
    );
  }
}
