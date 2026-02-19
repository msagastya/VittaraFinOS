import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vittara_fin_os/logic/budgets_controller.dart';
import 'package:vittara_fin_os/logic/goals_controller.dart';
import 'package:vittara_fin_os/logic/transaction_model.dart';
import 'package:vittara_fin_os/logic/transactions_controller.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/widgets/animations.dart';
import 'package:vittara_fin_os/ui/widgets/animated_counter.dart'
    as counter_widgets;
import 'package:vittara_fin_os/ui/widgets/glass_card.dart';
import 'package:vittara_fin_os/ui/widgets/liquid_progress_indicators.dart';
import 'package:vittara_fin_os/ui/widgets/neumorphic_glass_card.dart';
import 'package:vittara_fin_os/utils/alert_service.dart';

class _PlannerRecommendation {
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  const _PlannerRecommendation({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}

class _CategoryInsight {
  final String name;
  final double spent;
  final double budget;
  final double progress;

  const _CategoryInsight({
    required this.name,
    required this.spent,
    required this.budget,
    required this.progress,
  });
}

class AIMonthlyPlannerScreen extends StatefulWidget {
  const AIMonthlyPlannerScreen({super.key});

  @override
  State<AIMonthlyPlannerScreen> createState() => _AIMonthlyPlannerScreenState();
}

class _AIMonthlyPlannerScreenState extends State<AIMonthlyPlannerScreen> {
  static const String _incomeKey = 'ai_planner_monthly_income';
  static const String _mustSaveKey = 'ai_planner_must_save';

  bool _isGenerating = false;
  bool _isInitializing = true;
  bool _hasGenerated = false;
  double? _monthlyIncome;
  double? _mustSaveAmount;

  @override
  void initState() {
    super.initState();
    _loadPlannerInputs();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<BudgetsController>(context, listen: false).initialize();
      Provider.of<GoalsController>(context, listen: false).initialize();
      Provider.of<TransactionsController>(context, listen: false)
          .loadTransactions();
    });
  }

  Future<void> _loadPlannerInputs() async {
    final prefs = await SharedPreferences.getInstance();
    final savedIncome = prefs.getDouble(_incomeKey);
    final savedMustSave = prefs.getDouble(_mustSaveKey);
    if (!mounted) return;
    setState(() {
      _monthlyIncome = savedIncome;
      _mustSaveAmount = savedMustSave;
      _hasGenerated = (savedIncome ?? 0) > 0;
      _isInitializing = false;
    });
  }

  Future<void> _savePlannerInputs() async {
    final prefs = await SharedPreferences.getInstance();

    if (_monthlyIncome != null && _monthlyIncome! > 0) {
      await prefs.setDouble(_incomeKey, _monthlyIncome!);
    } else {
      await prefs.remove(_incomeKey);
    }

    if (_mustSaveAmount != null && _mustSaveAmount! > 0) {
      await prefs.setDouble(_mustSaveKey, _mustSaveAmount!);
    } else {
      await prefs.remove(_mustSaveKey);
    }
  }

  Future<bool> _collectPlannerInputs({required bool isEditing}) async {
    final incomeController = TextEditingController(
      text: _monthlyIncome == null ? '' : _monthlyIncome!.toStringAsFixed(0),
    );
    final saveController = TextEditingController(
      text: _mustSaveAmount == null ? '' : _mustSaveAmount!.toStringAsFixed(0),
    );

    final shouldGenerate = await showCupertinoModalPopup<bool>(
          context: context,
          builder: (ctx) => Container(
            decoration: BoxDecoration(
              color: AppStyles.getCardColor(ctx),
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(Radii.xxl)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.only(
                  left: Spacing.xxl,
                  right: Spacing.xxl,
                  top: Spacing.xl,
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + Spacing.xl,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(
                          color: CupertinoColors.systemGrey3,
                          borderRadius: BorderRadius.circular(2.5),
                        ),
                      ),
                    ),
                    SizedBox(height: Spacing.xl),
                    Text(
                      isEditing ? 'Edit Planner Inputs' : 'Planner Inputs',
                      style: TextStyle(
                        fontSize: TypeScale.title2,
                        fontWeight: FontWeight.bold,
                        color: AppStyles.getTextColor(ctx),
                      ),
                    ),
                    SizedBox(height: Spacing.sm),
                    Text(
                      'These values are saved and reused for future analysis.',
                      style: TextStyle(
                        fontSize: TypeScale.footnote,
                        color: AppStyles.getSecondaryTextColor(ctx),
                      ),
                    ),
                    SizedBox(height: Spacing.lg),
                    Text(
                      'Monthly Income',
                      style: TextStyle(
                        fontSize: TypeScale.subhead,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: Spacing.sm),
                    CupertinoTextField(
                      controller: incomeController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      prefix: Padding(
                        padding: EdgeInsets.only(left: Spacing.md),
                        child: Text('₹',
                            style: TextStyle(fontSize: TypeScale.callout)),
                      ),
                      padding: EdgeInsets.all(Spacing.lg),
                      decoration: BoxDecoration(
                        color: AppStyles.getBackground(ctx),
                        borderRadius: BorderRadius.circular(Radii.md),
                      ),
                    ),
                    SizedBox(height: Spacing.lg),
                    Text(
                      'Must-Save This Month (optional)',
                      style: TextStyle(
                        fontSize: TypeScale.subhead,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: Spacing.sm),
                    CupertinoTextField(
                      controller: saveController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      prefix: Padding(
                        padding: EdgeInsets.only(left: Spacing.md),
                        child: Text('₹',
                            style: TextStyle(fontSize: TypeScale.callout)),
                      ),
                      padding: EdgeInsets.all(Spacing.lg),
                      decoration: BoxDecoration(
                        color: AppStyles.getBackground(ctx),
                        borderRadius: BorderRadius.circular(Radii.md),
                      ),
                    ),
                    SizedBox(height: Spacing.xl),
                    Row(
                      children: [
                        Expanded(
                          child: CupertinoButton(
                            color: CupertinoColors.systemGrey4,
                            onPressed: () => Navigator.pop(ctx, false),
                            child: Text('Cancel',
                                style: TextStyle(
                                    color: AppStyles.getTextColor(ctx))),
                          ),
                        ),
                        SizedBox(width: Spacing.md),
                        Expanded(
                          child: CupertinoButton(
                            color: SemanticColors.info,
                            onPressed: () {
                              final incomeRaw = incomeController.text.trim();
                              final saveRaw = saveController.text.trim();
                              final income = double.tryParse(incomeRaw);
                              final mustSave = saveRaw.isEmpty
                                  ? null
                                  : double.tryParse(saveRaw);
                              if (income == null || income <= 0) {
                                AlertService.showError(
                                    ctx, 'Please enter valid monthly income');
                                return;
                              }

                              if (saveRaw.isNotEmpty &&
                                  (mustSave == null || mustSave < 0)) {
                                AlertService.showError(
                                    ctx, 'Please enter valid must-save amount');
                                return;
                              }

                              if (mustSave != null && mustSave > income) {
                                AlertService.showError(ctx,
                                    'Must-save cannot exceed monthly income');
                                return;
                              }

                              setState(() {
                                _monthlyIncome = income;
                                _mustSaveAmount =
                                    mustSave == null || mustSave <= 0
                                        ? null
                                        : mustSave;
                              });
                              Navigator.pop(ctx, true);
                            },
                            child: Text(isEditing ? 'Save' : 'Continue',
                                style: const TextStyle(color: Colors.white)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ) ??
        false;

    incomeController.dispose();
    saveController.dispose();

    if (shouldGenerate) {
      await _savePlannerInputs();
    }

    return shouldGenerate;
  }

  Future<void> _generateRecommendations({bool forceEditInputs = false}) async {
    if (forceEditInputs || _monthlyIncome == null || _monthlyIncome! <= 0) {
      final shouldGenerate =
          await _collectPlannerInputs(isEditing: forceEditInputs);
      if (!shouldGenerate) return;
    }

    final hadGeneratedBefore = _hasGenerated;

    setState(() {
      _isGenerating = true;
    });

    await Future.delayed(const Duration(milliseconds: 850));

    if (!mounted) return;
    setState(() {
      _isGenerating = false;
      _hasGenerated = true;
    });

    AlertService.showSuccess(
      context,
      forceEditInputs
          ? 'Planner updated and analysis refreshed!'
          : hadGeneratedBefore
              ? 'Analysis refreshed with latest entries!'
              : 'Recommendations generated!',
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppStyles.getBackground(context),
      navigationBar: CupertinoNavigationBar(
        middle: Text('AI Monthly Planner',
            style: TextStyle(color: AppStyles.getTextColor(context))),
        previousPageTitle: 'Manage',
        backgroundColor: AppStyles.getBackground(context),
        border: null,
      ),
      child:
          Consumer3<BudgetsController, GoalsController, TransactionsController>(
        builder: (context, budgetsController, goalsController,
            transactionsController, child) {
          final totalBudgetLimit = budgetsController.activeBudgets
              .fold(0.0, (sum, b) => sum + b.limitAmount);
          final totalGoalTarget =
              goalsController.totalRecommendedMonthlySavings;
          final monthStart =
              DateTime(DateTime.now().year, DateTime.now().month, 1);
          final thisMonthExpenses =
              transactionsController.transactions.where((tx) {
            return tx.type == TransactionType.expense &&
                !tx.dateTime.isBefore(monthStart);
          }).toList();
          final totalSpent =
              thisMonthExpenses.fold(0.0, (sum, tx) => sum + tx.amount);

          final categorySpent = <String, double>{};
          for (final tx in thisMonthExpenses) {
            final metadata = tx.metadata ?? {};
            final categoryName = (metadata['categoryName'] as String?)?.trim();
            final key = (categoryName == null || categoryName.isEmpty)
                ? 'Uncategorized'
                : categoryName;
            categorySpent.update(key, (value) => value + tx.amount,
                ifAbsent: () => tx.amount);
          }

          final budgetByCategory = <String, double>{};
          for (final budget in budgetsController.activeBudgets) {
            final key = budget.categoryName?.trim();
            if (key != null && key.isNotEmpty) {
              budgetByCategory.update(
                  key, (value) => value + budget.limitAmount,
                  ifAbsent: () => budget.limitAmount);
            }
          }

          final recommendations = _buildRecommendations(
            totalSpent: totalSpent,
            totalGoalTarget: totalGoalTarget,
            totalBudgetLimit: totalBudgetLimit,
            categorySpent: categorySpent,
            categoryBudgets: budgetByCategory,
          );
          final categoryInsights =
              _buildCategoryInsights(categorySpent, budgetByCategory);
          final projectedSavings = (_monthlyIncome ?? 0) - totalSpent;
          final healthScore = _computeHealthScore(
              totalSpent, totalGoalTarget, totalBudgetLimit);

          return SafeArea(
            child: _isInitializing
                ? _buildInitializingState()
                : _isGenerating
                    ? _buildGeneratingState()
                    : !_hasGenerated
                        ? _buildInitialState(
                            totalBudgetLimit, totalGoalTarget, totalSpent)
                        : _buildRecommendationsState(
                            projectedSavings: projectedSavings,
                            goalTarget: totalGoalTarget,
                            healthScore: healthScore,
                            recommendations: recommendations,
                            categoryInsights: categoryInsights,
                          ),
          );
        },
      ),
    );
  }

  Widget _buildInitializingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CupertinoActivityIndicator(radius: 16),
          SizedBox(height: Spacing.lg),
          Text(
            'Loading planner profile...',
            style: TextStyle(
              fontSize: TypeScale.callout,
              color: AppStyles.getSecondaryTextColor(context),
            ),
          ),
        ],
      ),
    );
  }

  List<_PlannerRecommendation> _buildRecommendations({
    required double totalSpent,
    required double totalGoalTarget,
    required double totalBudgetLimit,
    required Map<String, double> categorySpent,
    required Map<String, double> categoryBudgets,
  }) {
    final list = <_PlannerRecommendation>[];

    if (_monthlyIncome != null && _monthlyIncome! > 0) {
      final ratio = totalSpent / _monthlyIncome!;
      if (ratio > 0.85) {
        list.add(
          _PlannerRecommendation(
            title: 'High Spend Ratio',
            description:
                'You used ${(ratio * 100).toStringAsFixed(0)}% of income this month. Cut one discretionary category.',
            icon: CupertinoIcons.exclamationmark_triangle_fill,
            color: SemanticColors.warning,
          ),
        );
      } else {
        list.add(
          _PlannerRecommendation(
            title: 'Spending In Control',
            description:
                'You used ${(ratio * 100).toStringAsFixed(0)}% of income this month. Keep this pace.',
            icon: CupertinoIcons.check_mark_circled_solid,
            color: SemanticColors.success,
          ),
        );
      }

      final now = DateTime.now();
      final daysElapsed = now.day.toDouble().clamp(1, 31);
      final daysInMonth = DateTime(now.year, now.month + 1, 0).day.toDouble();
      final projectedMonthSpend = (totalSpent / daysElapsed) * daysInMonth;
      final projectionGap = projectedMonthSpend - _monthlyIncome!;

      if (projectionGap > 0) {
        list.add(
          _PlannerRecommendation(
            title: 'Month-End Overspend Risk',
            description:
                'At current pace, spending may exceed income by ₹${projectionGap.toStringAsFixed(0)} this month.',
            icon: CupertinoIcons.waveform_path_ecg,
            color: SemanticColors.error,
          ),
        );
      } else if (daysElapsed >= 7 && projectionGap < -(_monthlyIncome! * 0.1)) {
        list.add(
          _PlannerRecommendation(
            title: 'Pace Looks Healthy',
            description:
                'Current run-rate suggests ₹${(-projectionGap).toStringAsFixed(0)} buffer by month-end.',
            icon: CupertinoIcons.speedometer,
            color: SemanticColors.success,
          ),
        );
      }
    }

    final topCategoryEntry = categorySpent.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (topCategoryEntry.isNotEmpty) {
      final top = topCategoryEntry.first;
      list.add(
        _PlannerRecommendation(
          title: 'Top Spend: ${top.key}',
          description:
              'This month spending is ₹${top.value.toStringAsFixed(0)} in ${top.key}. Review repeat spends here first.',
          icon: CupertinoIcons.chart_bar_fill,
          color: SemanticColors.info,
        ),
      );
    }

    for (final entry in categorySpent.entries) {
      final budget = categoryBudgets[entry.key];
      if (budget != null && budget > 0) {
        final progress = entry.value / budget;
        if (progress >= 0.9) {
          list.add(
            _PlannerRecommendation(
              title: '${entry.key} Near Limit',
              description:
                  '₹${entry.value.toStringAsFixed(0)} spent of ₹${budget.toStringAsFixed(0)} budget.',
              icon: CupertinoIcons.bell_fill,
              color: SemanticColors.error,
            ),
          );
        }
      }
    }

    if (_mustSaveAmount != null &&
        _mustSaveAmount! > 0 &&
        _monthlyIncome != null) {
      final left = _monthlyIncome! - totalSpent;
      if (left < _mustSaveAmount!) {
        list.add(
          _PlannerRecommendation(
            title: 'Savings Gap',
            description:
                'Need ₹${(_mustSaveAmount! - left).toStringAsFixed(0)} more to hit your must-save target.',
            icon: CupertinoIcons.arrow_up_circle_fill,
            color: SemanticColors.warning,
          ),
        );
      }
    }

    if (totalGoalTarget > 0) {
      list.add(
        _PlannerRecommendation(
          title: 'Goal Contribution',
          description:
              'Recommended monthly goal contribution is ₹${totalGoalTarget.toStringAsFixed(0)}.',
          icon: CupertinoIcons.flag_fill,
          color: SemanticColors.info,
        ),
      );
    }

    if (list.isEmpty) {
      list.add(
        const _PlannerRecommendation(
          title: 'Need More Data',
          description:
              'Add budgets/categories and transactions to generate stronger monthly recommendations.',
          icon: CupertinoIcons.info_circle_fill,
          color: SemanticColors.info,
        ),
      );
    }

    return list;
  }

  List<_CategoryInsight> _buildCategoryInsights(
    Map<String, double> categorySpent,
    Map<String, double> categoryBudgets,
  ) {
    final names = <String>{...categorySpent.keys, ...categoryBudgets.keys};
    final insights = names.map((name) {
      final spent = categorySpent[name] ?? 0;
      final budget = categoryBudgets[name] ?? 0;
      final progress = budget > 0 ? (spent / budget).clamp(0.0, 1.5) : 0.0;
      return _CategoryInsight(
        name: name,
        spent: spent,
        budget: budget,
        progress: progress,
      );
    }).toList();

    insights.sort((a, b) => b.spent.compareTo(a.spent));
    return insights.take(6).toList();
  }

  double _computeHealthScore(
      double totalSpent, double goalTarget, double budgetLimit) {
    final income = _monthlyIncome ?? 0;
    if (income <= 0) return 0;
    final spendRatio = (totalSpent / income).clamp(0.0, 1.0);
    final goalRatio = goalTarget <= 0
        ? 1.0
        : ((income - totalSpent) / goalTarget).clamp(0.0, 1.0);
    final budgetRatio = budgetLimit <= 0
        ? 1.0
        : (1 - (totalSpent / budgetLimit).clamp(0.0, 1.0));
    final raw =
        (goalRatio * 0.4) + ((1 - spendRatio) * 0.4) + (budgetRatio * 0.2);
    return (raw * 100).clamp(0.0, 100.0);
  }

  Widget _buildGeneratingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SpinningArcProgress(
              size: 80, color: SemanticColors.info, strokeWidth: 6),
          SizedBox(height: Spacing.xxl),
          Text(
            'Analyzing Your Finances...',
            style: TextStyle(
                fontSize: TypeScale.title2,
                fontWeight: FontWeight.bold,
                color: AppStyles.getTextColor(context)),
          ),
          SizedBox(height: Spacing.md),
          Text(
            'Generating personalized recommendations',
            style: TextStyle(
                fontSize: TypeScale.callout,
                color: AppStyles.getSecondaryTextColor(context)),
          ),
        ],
      ),
    );
  }

  Widget _buildInitialState(
      double budgetLimit, double goalTarget, double spent) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(Spacing.xxxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(Spacing.xxxl),
              decoration: BoxDecoration(
                  color: SemanticColors.info.withValues(alpha: 0.1),
                  shape: BoxShape.circle),
              child: Icon(CupertinoIcons.sparkles,
                  size: IconSizes.emptyStateIcon, color: SemanticColors.info),
            ),
            SizedBox(height: Spacing.xxl),
            Text(
              'AI Financial Planner',
              style: TextStyle(
                  fontSize: TypeScale.largeTitle,
                  fontWeight: FontWeight.bold,
                  color: AppStyles.getTextColor(context)),
            ),
            SizedBox(height: Spacing.md),
            Text(
              'Uses your real budgets, categories, and transactions.\nNo preset templates.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: TypeScale.callout,
                  color: AppStyles.getSecondaryTextColor(context)),
            ),
            SizedBox(height: Spacing.lg),
            Text(
              'Spent this month: ₹${spent.toStringAsFixed(0)}',
              style: TextStyle(
                  fontSize: TypeScale.subhead,
                  color: AppStyles.getSecondaryTextColor(context)),
            ),
            SizedBox(height: Spacing.xxxl),
            BouncyButton(
              onPressed: () => _generateRecommendations(forceEditInputs: true),
              child: Container(
                padding: EdgeInsets.symmetric(
                    horizontal: Spacing.xxl, vertical: Spacing.lg),
                decoration: BoxDecoration(
                  gradient: GradientSchemes.cosmicViolet,
                  borderRadius: BorderRadius.circular(Radii.full),
                  boxShadow: [
                    BoxShadow(
                      color: SemanticColors.info.withValues(alpha: 0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.sparkles,
                        color: Colors.white, size: IconSizes.lg),
                    SizedBox(width: Spacing.sm),
                    Text(
                      'Set Up & Analyze',
                      style: TextStyle(
                          fontSize: TypeScale.callout,
                          fontWeight: FontWeight.w600,
                          color: Colors.white),
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

  Widget _buildRecommendationsState({
    required double projectedSavings,
    required double goalTarget,
    required double healthScore,
    required List<_PlannerRecommendation> recommendations,
    required List<_CategoryInsight> categoryInsights,
  }) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(Spacing.lg),
            child: NeumorphicGlassCard(
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(CupertinoIcons.sparkles,
                          color: SemanticColors.info, size: IconSizes.lg),
                      SizedBox(width: Spacing.md),
                      Expanded(
                        child: Text(
                          'Monthly Financial Plan',
                          style: TextStyle(
                              fontSize: TypeScale.title2,
                              fontWeight: FontWeight.bold,
                              color: AppStyles.getTextColor(context)),
                        ),
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => _generateRecommendations(),
                        child: const Icon(CupertinoIcons.refresh),
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () =>
                            _generateRecommendations(forceEditInputs: true),
                        child: const Icon(CupertinoIcons.slider_horizontal_3),
                      ),
                    ],
                  ),
                  SizedBox(height: Spacing.lg),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(Spacing.md),
                    decoration: BoxDecoration(
                      color: SemanticColors.info.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(Radii.md),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Saved Inputs',
                          style: TextStyle(
                            fontSize: TypeScale.footnote,
                            fontWeight: FontWeight.w600,
                            color: AppStyles.getSecondaryTextColor(context),
                          ),
                        ),
                        SizedBox(height: Spacing.xs),
                        Text(
                          'Income: ₹${(_monthlyIncome ?? 0).toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: TypeScale.callout,
                            color: AppStyles.getTextColor(context),
                          ),
                        ),
                        Text(
                          _mustSaveAmount != null && _mustSaveAmount! > 0
                              ? 'Must-Save: ₹${_mustSaveAmount!.toStringAsFixed(0)}'
                              : 'Must-Save: Not set',
                          style: TextStyle(
                            fontSize: TypeScale.callout,
                            color: AppStyles.getTextColor(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: Spacing.xxl),
                  LiquidCircularProgress(
                    progress: (healthScore / 100).clamp(0, 1),
                    size: 160,
                    color: healthScore >= 75
                        ? SemanticColors.success
                        : healthScore >= 50
                            ? SemanticColors.warning
                            : SemanticColors.error,
                    center: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('${healthScore.toStringAsFixed(0)}%',
                            style: TextStyle(
                                fontSize: TypeScale.hero,
                                fontWeight: FontWeight.bold,
                                color: AppStyles.getTextColor(context))),
                        SizedBox(height: Spacing.xs),
                        Text('Health Score',
                            style: TextStyle(
                                fontSize: TypeScale.footnote,
                                color:
                                    AppStyles.getSecondaryTextColor(context))),
                      ],
                    ),
                  ),
                  SizedBox(height: Spacing.xxl),
                  Container(
                    padding: EdgeInsets.all(Spacing.lg),
                    decoration: BoxDecoration(
                        color: SemanticColors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(Radii.md)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            Text('Projected Savings',
                                style: TextStyle(
                                    fontSize: TypeScale.footnote,
                                    color: AppStyles.getSecondaryTextColor(
                                        context))),
                            SizedBox(height: Spacing.xs),
                            counter_widgets.CurrencyCounter(
                                value: projectedSavings,
                                textStyle: TextStyle(
                                    fontSize: TypeScale.title3,
                                    fontWeight: FontWeight.bold,
                                    color: projectedSavings >= 0
                                        ? SemanticColors.success
                                        : SemanticColors.error),
                                decimalPlaces: 0),
                          ],
                        ),
                        Container(
                            width: 1,
                            height: 40,
                            color: AppStyles.getSecondaryTextColor(context)
                                .withValues(alpha: 0.2)),
                        Column(
                          children: [
                            Text('Goal Target',
                                style: TextStyle(
                                    fontSize: TypeScale.footnote,
                                    color: AppStyles.getSecondaryTextColor(
                                        context))),
                            SizedBox(height: Spacing.xs),
                            counter_widgets.CurrencyCounter(
                                value: goalTarget,
                                textStyle: TextStyle(
                                    fontSize: TypeScale.title3,
                                    fontWeight: FontWeight.bold,
                                    color: AppStyles.getTextColor(context)),
                                decimalPlaces: 0),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: Spacing.lg),
            child: Text('Recommendations',
                style: TextStyle(
                    fontSize: TypeScale.title3,
                    fontWeight: FontWeight.bold,
                    color: AppStyles.getTextColor(context))),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.all(Spacing.lg),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final item = recommendations[index];
                return Padding(
                  padding: EdgeInsets.only(bottom: Spacing.md),
                  child: _buildRecommendationCard(item, index),
                );
              },
              childCount: recommendations.length,
            ),
          ),
        ),
        SliverToBoxAdapter(child: SizedBox(height: Spacing.lg)),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: Spacing.lg),
            child: Text('Category Breakdown',
                style: TextStyle(
                    fontSize: TypeScale.title3,
                    fontWeight: FontWeight.bold,
                    color: AppStyles.getTextColor(context))),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.all(Spacing.lg),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final insight = categoryInsights[index];
                return Padding(
                  padding: EdgeInsets.only(bottom: Spacing.md),
                  child: _buildCategoryCard(insight),
                );
              },
              childCount: categoryInsights.length,
            ),
          ),
        ),
        SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }

  Widget _buildRecommendationCard(_PlannerRecommendation item, int index) {
    return StaggeredItem(
      index: index,
      child: GlassCard(
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(Spacing.md),
              decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(Radii.md)),
              child: Icon(item.icon, color: item.color, size: IconSizes.lg),
            ),
            SizedBox(width: Spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title,
                      style: TextStyle(
                          fontSize: TypeScale.callout,
                          fontWeight: FontWeight.w600,
                          color: AppStyles.getTextColor(context))),
                  SizedBox(height: Spacing.xxs),
                  Text(item.description,
                      style: TextStyle(
                          fontSize: TypeScale.footnote,
                          color: AppStyles.getSecondaryTextColor(context))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard(_CategoryInsight insight) {
    final progress = insight.budget > 0 ? insight.progress : 0.0;
    final color = progress >= 0.9
        ? SemanticColors.error
        : progress >= 0.75
            ? SemanticColors.warning
            : SemanticColors.success;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  insight.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: TypeScale.callout,
                      fontWeight: FontWeight.w600,
                      color: AppStyles.getTextColor(context)),
                ),
              ),
              if (insight.budget > 0)
                counter_widgets.AnimatedCounter(
                  value: progress * 100,
                  suffix: '%',
                  decimalPlaces: 0,
                  textStyle: TextStyle(
                      fontSize: TypeScale.callout,
                      fontWeight: FontWeight.bold,
                      color: color),
                ),
            ],
          ),
          SizedBox(height: Spacing.md),
          if (insight.budget > 0)
            LiquidLinearProgress(
                progress: progress.clamp(0.0, 1.0), height: 8, color: color),
          if (insight.budget > 0) SizedBox(height: Spacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('₹${insight.spent.toStringAsFixed(0)} spent',
                  style: TextStyle(
                      fontSize: TypeScale.footnote,
                      color: AppStyles.getSecondaryTextColor(context))),
              Text(
                insight.budget > 0
                    ? '₹${insight.budget.toStringAsFixed(0)} budget'
                    : 'No category budget',
                style: TextStyle(
                    fontSize: TypeScale.footnote,
                    color: AppStyles.getSecondaryTextColor(context)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
