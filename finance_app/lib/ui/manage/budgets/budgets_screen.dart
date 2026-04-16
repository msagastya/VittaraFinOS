import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/budgets_controller.dart';
import 'package:vittara_fin_os/logic/budget_model.dart';
import 'package:vittara_fin_os/logic/transactions_controller.dart';
import 'package:vittara_fin_os/logic/transaction_model.dart';
import 'package:vittara_fin_os/ui/manage/budgets/budget_details_screen.dart';
import 'package:vittara_fin_os/ui/manage/budgets/modals/add_budget_modal.dart';
import 'dart:math' as math;
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/styles/typography.dart';
import 'package:vittara_fin_os/ui/widgets/animations.dart';
import 'package:vittara_fin_os/ui/widgets/animated_counter.dart'
    as counter_widgets;
import 'package:vittara_fin_os/ui/widgets/common_widgets.dart';
import 'package:vittara_fin_os/ui/widgets/glass_card.dart';
import 'package:vittara_fin_os/ui/widgets/liquid_progress_indicators.dart';
import 'package:vittara_fin_os/ui/widgets/toast_notification.dart' as toast_lib;
import 'package:vittara_fin_os/ui/styles/responsive_utils.dart';

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
      // Restore filter period from PageStorage.
      final saved = PageStorage.of(context).readState(context,
          identifier: const ValueKey('budgets_filter_period')) as String?;
      if (saved != null) {
        final match = BudgetPeriod.values
            .where((p) => p.name == saved)
            .firstOrNull;
        if (match != null) setState(() => _filterPeriod = match);
      }
    });
  }

  void _showAddBudgetModal() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => RLayout.tabletConstrain(
        context,
        const AddBudgetModal(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape = AppStyles.isLandscape(context);

    return CupertinoPageScaffold(
      backgroundColor: AppStyles.getBackground(context),
      navigationBar: isLandscape
          ? null
          : CupertinoNavigationBar(
              middle: Text('Budgets',
                  style: TextStyle(color: AppStyles.getTextColor(context))),
              previousPageTitle: 'Back',
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
                    : Column(
                        children: [
                          if (isLandscape) _buildLandscapeNavBar(context),
                          Expanded(
                            child: CustomScrollView(
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
                          // Budget Health Overview
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                  Spacing.lg, Spacing.lg, Spacing.lg, 0),
                              child: _buildHealthSummary(
                                  controller.activeBudgets),
                            ),
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
                                            onTap: () {
                                              setState(() => _filterPeriod = null);
                                              PageStorage.of(context).writeState(
                                                  context, null,
                                                  identifier: const ValueKey(
                                                      'budgets_filter_period'));
                                            },
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
                              child: EmptyStateView(
                                icon: CupertinoIcons.search,
                                title: 'No budgets found',
                                subtitle: 'Try adjusting your filter.',
                                showPulse: false,
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
                            fontSize: RT.title2(context),
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

  Widget _buildHealthSummary(List<Budget> allBudgets) {
    if (allBudgets.isEmpty) return const SizedBox.shrink();

    final totalBudgeted =
        allBudgets.fold<double>(0, (sum, b) => sum + b.limitAmount);
    final totalSpent =
        allBudgets.fold<double>(0, (sum, b) => sum + b.spentAmount);
    final overallPct =
        totalBudgeted > 0 ? (totalSpent / totalBudgeted).clamp(0.0, 1.0) : 0.0;
    final onTrackCount =
        allBudgets.where((b) => b.status == BudgetStatus.onTrack).length;
    final exceededCount =
        allBudgets.where((b) => b.status == BudgetStatus.exceeded).length;
    final warningCount = allBudgets.length - onTrackCount - exceededCount;

    final barColor = exceededCount > 0
        ? SemanticColors.error
        : warningCount > 0
            ? SemanticColors.warning
            : SemanticColors.success;

    // Pace label for Mission Control status line
    final remaining = (totalBudgeted - totalSpent).clamp(0.0, double.infinity);
    final String paceLabel;
    final Color paceColor;
    if (exceededCount > 0) {
      paceLabel = 'Overpacing — $exceededCount budget${exceededCount > 1 ? 's' : ''} exceeded';
      paceColor = AppStyles.loss(context);
    } else if (warningCount > 0) {
      paceLabel = 'Watch out — $warningCount near limit';
      paceColor = AppStyles.warning(context);
    } else if (totalBudgeted > 0) {
      paceLabel = '${(remaining / totalBudgeted * 100).toStringAsFixed(0)}% headroom remaining';
      paceColor = AppStyles.gain(context);
    } else {
      paceLabel = 'No active budgets';
      paceColor = AppStyles.neutral(context);
    }

    return GlassCard(
      padding: const EdgeInsets.all(Spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bloomberg-style panel header
          Row(
            children: [
              Text(
                'MISSION CONTROL',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: barColor,
                  letterSpacing: 1.1,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: Spacing.md, vertical: Spacing.xxs),
                decoration: BoxDecoration(
                  color: barColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(Radii.full),
                ),
                child: Text(
                  exceededCount > 0
                      ? '$exceededCount over limit'
                      : warningCount > 0
                          ? '$warningCount near limit'
                          : 'All on track',
                  style: TextStyle(
                    fontSize: TypeScale.caption,
                    fontWeight: FontWeight.w600,
                    color: barColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.md),

          // Main content: radial arc gauge (left) + stats (right)
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Radial arc gauge
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: overallPct),
                duration: const Duration(milliseconds: 1000),
                curve: Curves.easeOutCubic,
                builder: (ctx, v, _) => SizedBox(
                  width: 100,
                  height: 100,
                  child: CustomPaint(
                    painter: _BudgetGaugePainter(
                      progress: v,
                      trackColor: AppStyles.getDividerColor(context),
                      fillColor: barColor,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${(v * 100).toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontSize: TypeScale.headline,
                              fontWeight: FontWeight.w800,
                              color: barColor,
                              height: 1.0,
                            ),
                          ),
                          Text(
                            'used',
                            style: TextStyle(
                              fontSize: 9,
                              color: AppStyles.getSecondaryTextColor(context),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: Spacing.lg),
              // Stats column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _missionStatRow('Budgeted', totalBudgeted,
                        AppStyles.getSecondaryTextColor(context)),
                    const SizedBox(height: Spacing.xs),
                    _missionStatRow('Spent', totalSpent, barColor),
                    const SizedBox(height: Spacing.xs),
                    _missionStatRow('Remaining', remaining,
                        AppStyles.gain(context)),
                    const Divider(height: Spacing.lg),
                    Row(
                      children: [
                        _compactBadge('$onTrackCount', 'OK',
                            AppStyles.gain(context)),
                        const SizedBox(width: Spacing.sm),
                        if (warningCount > 0) ...[
                          _compactBadge('$warningCount', '!',
                              AppStyles.warning(context)),
                          const SizedBox(width: Spacing.sm),
                        ],
                        _compactBadge('$exceededCount', '✕',
                            AppStyles.loss(context)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.sm),
          // Pace status line
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: paceColor,
                ),
              ),
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: Text(
                  paceLabel,
                  style: TextStyle(
                    fontSize: TypeScale.caption,
                    color: paceColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _missionStatRow(String label, double value, Color color) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: TypeScale.caption,
            color: AppStyles.getSecondaryTextColor(context),
          ),
        ),
        const Spacer(),
        counter_widgets.CurrencyCounter(
          value: value,
          textStyle: TextStyle(
            fontSize: TypeScale.footnote,
            fontWeight: FontWeight.w700,
            color: color,
          ),
          decimalPlaces: 0,
        ),
      ],
    );
  }

  Widget _compactBadge(String count, String icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon,
              style: TextStyle(
                  fontSize: 9, color: color, fontWeight: FontWeight.w800)),
          const SizedBox(width: 3),
          Text(count,
              style: TextStyle(
                  fontSize: TypeScale.caption,
                  color: color,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  /// Compact 40dp nav bar for landscape mode.
  Widget _buildLandscapeNavBar(BuildContext context) {
    final secondary = AppStyles.getSecondaryTextColor(context);
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
      decoration: BoxDecoration(
        color: AppStyles.getCardColor(context).withValues(alpha: 0.85),
        border: Border(
          bottom: BorderSide(
              color: AppStyles.getDividerColor(context), width: 0.5),
        ),
      ),
      child: Row(
        children: [
          BouncyButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(CupertinoIcons.chevron_back,
                    size: 16, color: AppStyles.getPrimaryColor(context)),
                const SizedBox(width: 4),
                Text('Back',
                    style: TextStyle(
                        fontSize: 14,
                        color: AppStyles.getPrimaryColor(context),
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          const Spacer(),
          Text('BUDGETS',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: secondary,
                  letterSpacing: 1.2)),
          const Spacer(),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => _showPeriodFilter(),
            child: Icon(CupertinoIcons.line_horizontal_3_decrease,
                size: 18, color: secondary),
          ),
          const SizedBox(width: 60),
        ],
      ),
    );
  }

  Widget _budgetStatCell({
    required String label,
    required double value,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        children: [
          counter_widgets.CurrencyCounter(
            value: value,
            textStyle: TextStyle(
              fontSize: TypeScale.footnote,
              fontWeight: FontWeight.w700,
              color: color,
            ),
            decimalPlaces: 0,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: TypeScale.caption,
              color: AppStyles.getSecondaryTextColor(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _budgetCountBadge(int count, String label, Color color) {
    return Column(
      children: [
        Text(
          '$count',
          style: TextStyle(
            fontSize: TypeScale.callout,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: TypeScale.caption,
            color: AppStyles.getSecondaryTextColor(context),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    // Find top spend category from transactions for personalisation
    return Consumer<TransactionsController>(
      builder: (context, txCtrl, _) {
        final catSpend = <String, double>{};
        for (final tx in txCtrl.transactions) {
          if (tx.type == TransactionType.expense) {
            final cat =
                tx.metadata?['categoryName'] as String? ?? 'General';
            catSpend[cat] = (catSpend[cat] ?? 0) + tx.amount;
          }
        }
        final topCat = catSpend.isEmpty
            ? 'Food & Dining'
            : (catSpend.entries.toList()
                  ..sort((a, b) => b.value.compareTo(a.value)))
                .first
                .key;
        final hasSpend = catSpend.isNotEmpty;

        // CTA pinned outside scroll view so it never hides behind the FAB.
        return Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                    Spacing.xxl, Spacing.xxl, Spacing.xxl, Spacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: Spacing.xxl),
                    Container(
                      padding: const EdgeInsets.all(Spacing.xxl),
                      decoration: BoxDecoration(
                          color: SemanticColors.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle),
                      child: const Icon(CupertinoIcons.chart_pie_fill,
                          size: IconSizes.emptyStateIcon,
                          color: SemanticColors.primary),
                    ),
                    const SizedBox(height: Spacing.xxl),
                    Text(
                      'Without a limit, there\'s no finish line',
                      style: AppTypography.title2(
                          color: AppStyles.getTextColor(context)),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: Spacing.md),
                    Text(
                      hasSpend
                          ? 'You spent most on $topCat. Set a budget and we\'ll tell you how you\'re doing in real time.'
                          : 'Set a budget for any spending category and track it automatically as you log transactions.',
                      textAlign: TextAlign.center,
                      style: AppTypography.callout(
                              color: AppStyles.getSecondaryTextColor(context))
                          .copyWith(height: 1.5),
                    ),
                    const SizedBox(height: Spacing.xl),
                  ],
                ),
              ),
            ),
            // Fixed CTA — always visible above the FAB
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  Spacing.xxl, 0, Spacing.xxl, 104),
              child: BouncyButton(
                onPressed: _showAddBudgetModal,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: Spacing.lg),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      SemanticColors.primary,
                      SemanticColors.primary.withValues(alpha: 0.8)
                    ]),
                    borderRadius: BorderRadius.circular(Radii.full),
                    boxShadow: [
                      BoxShadow(
                          color: SemanticColors.primary.withValues(alpha: 0.35),
                          blurRadius: 20,
                          offset: const Offset(0, 8))
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(CupertinoIcons.add,
                          color: Colors.white, size: IconSizes.lg),
                      const SizedBox(width: Spacing.sm),
                      Text(
                        hasSpend
                            ? 'Create Budget for $topCat'
                            : 'Create Your First Budget',
                        style: AppTypography.button(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showPeriodFilter() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => RLayout.tabletConstrain(
        context,
        CupertinoActionSheet(
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
                PageStorage.of(context).writeState(context, period.name,
                    identifier: const ValueKey('budgets_filter_period'));
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
                PageStorage.of(context).writeState(context, null,
                    identifier: const ValueKey('budgets_filter_period'));
                Navigator.pop(context);
              },
              isDestructiveAction: true,
              child: const Text('Clear Filter'),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      ),
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

// ─────────────────────────────────────────────────────────────────────────────
// Budget Gauge Painter — Bloomberg Mission Control arc gauge (BUD-01)
// ─────────────────────────────────────────────────────────────────────────────
class _BudgetGaugePainter extends CustomPainter {
  final double progress; // 0.0 → 1.0
  final Color trackColor;
  final Color fillColor;

  const _BudgetGaugePainter({
    required this.progress,
    required this.trackColor,
    required this.fillColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final strokeW = size.width * 0.12;
    final radius = (size.width - strokeW) / 2;
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Arc spans 240° (starts at 150°, ends at 30° clock-wise) — like a speedometer
    const startAngle = math.pi * 0.75; // 135°
    const sweepAngle = math.pi * 1.5;  // 270°

    // Track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, startAngle, sweepAngle, false, trackPaint);

    // Fill
    if (progress > 0) {
      final fillPaint = Paint()
        ..color = fillColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, startAngle, sweepAngle * progress.clamp(0, 1), false,
          fillPaint);
    }
  }

  @override
  bool shouldRepaint(_BudgetGaugePainter old) =>
      old.progress != progress ||
      old.trackColor != trackColor ||
      old.fillColor != fillColor;
}

