import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/budgets_controller.dart';
import 'package:vittara_fin_os/logic/goals_controller.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/widgets/animations.dart';
import 'package:vittara_fin_os/ui/widgets/animated_counter.dart' as counter_widgets;
import 'package:vittara_fin_os/ui/widgets/glass_card.dart';
import 'package:vittara_fin_os/ui/widgets/neumorphic_glass_card.dart';
import 'package:vittara_fin_os/ui/widgets/liquid_progress_indicators.dart';
import 'package:vittara_fin_os/utils/alert_service.dart';

class AIMonthlyPlannerScreen extends StatefulWidget {
  const AIMonthlyPlannerScreen({super.key});

  @override
  State<AIMonthlyPlannerScreen> createState() => _AIMonthlyPlannerScreenState();
}

class _AIMonthlyPlannerScreenState extends State<AIMonthlyPlannerScreen> {
  bool _isGenerating = false;
  bool _hasGenerated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<BudgetsController>(context, listen: false).initialize();
      Provider.of<GoalsController>(context, listen: false).initialize();
    });
  }

  void _generateRecommendations() {
    setState(() {
      _isGenerating = true;
    });

    Future.delayed(Duration(seconds: 2), () {
      setState(() {
        _isGenerating = false;
        _hasGenerated = true;
      });
      AlertService.showSuccess(context, 'Recommendations generated!');
    });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppStyles.getBackground(context),
      navigationBar: CupertinoNavigationBar(
        middle: Text('AI Monthly Planner', style: TextStyle(color: AppStyles.getTextColor(context))),
        previousPageTitle: 'Manage',
        backgroundColor: AppStyles.getBackground(context),
        border: null,
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () {
            AlertService.showInfo(context, 'Export feature coming soon!');
          },
          child: Icon(CupertinoIcons.share, color: AppStyles.accentBlue),
        ),
      ),
      child: Consumer2<BudgetsController, GoalsController>(
        builder: (context, budgetsController, goalsController, child) {
          final totalBudgetLimit = budgetsController.activeBudgets.fold(0.0, (sum, b) => sum + b.limitAmount);
          final totalGoalTarget = goalsController.totalRecommendedMonthlySavings;
          final projectedSavings = totalBudgetLimit * 0.2;

          return SafeArea(
            child: _isGenerating
                ? _buildGeneratingState()
                : !_hasGenerated
                    ? _buildInitialState(totalBudgetLimit, totalGoalTarget, projectedSavings)
                    : _buildRecommendationsState(totalBudgetLimit, totalGoalTarget, projectedSavings),
          );
        },
      ),
    );
  }

  Widget _buildGeneratingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SpinningArcProgress(size: 80, color: SemanticColors.info, strokeWidth: 6),
          SizedBox(height: Spacing.xxl),
          Text('Analyzing Your Finances...', style: TextStyle(fontSize: TypeScale.title2, fontWeight: FontWeight.bold, color: AppStyles.getTextColor(context))),
          SizedBox(height: Spacing.md),
          Text('Generating personalized recommendations', style: TextStyle(fontSize: TypeScale.callout, color: AppStyles.getSecondaryTextColor(context))),
        ],
      ),
    );
  }

  Widget _buildInitialState(double budgetLimit, double goalTarget, double projectedSavings) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(Spacing.xxxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(Spacing.xxxl),
              decoration: BoxDecoration(color: SemanticColors.info.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(CupertinoIcons.sparkles, size: IconSizes.emptyStateIcon, color: SemanticColors.info),
            ),
            SizedBox(height: Spacing.xxl),
            Text('AI Financial Planner', style: TextStyle(fontSize: TypeScale.largeTitle, fontWeight: FontWeight.bold, color: AppStyles.getTextColor(context))),
            SizedBox(height: Spacing.md),
            Text('Get personalized recommendations\nbased on your spending patterns', textAlign: TextAlign.center, style: TextStyle(fontSize: TypeScale.callout, color: AppStyles.getSecondaryTextColor(context))),
            SizedBox(height: Spacing.xxxl),
            BouncyButton(
              onPressed: _generateRecommendations,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: Spacing.xxl, vertical: Spacing.lg),
                decoration: BoxDecoration(gradient: GradientSchemes.cosmicViolet, borderRadius: BorderRadius.circular(Radii.full), boxShadow: [BoxShadow(color: SemanticColors.info.withValues(alpha: 0.4), blurRadius: 20, offset: Offset(0, 8))]),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.sparkles, color: Colors.white, size: IconSizes.lg),
                    SizedBox(width: Spacing.sm),
                    Text('Generate Recommendations', style: TextStyle(fontSize: TypeScale.callout, fontWeight: FontWeight.w600, color: Colors.white)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationsState(double budgetLimit, double goalTarget, double projectedSavings) {
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
                      Icon(CupertinoIcons.sparkles, color: SemanticColors.info, size: IconSizes.lg),
                      SizedBox(width: Spacing.md),
                      Expanded(child: Text('Monthly Financial Plan', style: TextStyle(fontSize: TypeScale.title2, fontWeight: FontWeight.bold, color: AppStyles.getTextColor(context)))),
                    ],
                  ),
                  SizedBox(height: Spacing.xxl),
                  LiquidCircularProgress(
                    progress: 0.75,
                    size: 160,
                    color: SemanticColors.success,
                    center: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('75%', style: TextStyle(fontSize: TypeScale.hero, fontWeight: FontWeight.bold, color: SemanticColors.success)),
                        SizedBox(height: Spacing.xs),
                        Text('Health Score', style: TextStyle(fontSize: TypeScale.footnote, color: AppStyles.getSecondaryTextColor(context))),
                      ],
                    ),
                  ),
                  SizedBox(height: Spacing.xxl),
                  Container(
                    padding: EdgeInsets.all(Spacing.lg),
                    decoration: BoxDecoration(color: SemanticColors.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(Radii.md)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            Text('Projected Savings', style: TextStyle(fontSize: TypeScale.footnote, color: AppStyles.getSecondaryTextColor(context))),
                            SizedBox(height: Spacing.xs),
                            counter_widgets.CurrencyCounter(value: projectedSavings, textStyle: TextStyle(fontSize: TypeScale.title3, fontWeight: FontWeight.bold, color: SemanticColors.success), decimalPlaces: 0),
                          ],
                        ),
                        Container(width: 1, height: 40, color: AppStyles.getSecondaryTextColor(context).withValues(alpha: 0.2)),
                        Column(
                          children: [
                            Text('Goal Target', style: TextStyle(fontSize: TypeScale.footnote, color: AppStyles.getSecondaryTextColor(context))),
                            SizedBox(height: Spacing.xs),
                            counter_widgets.CurrencyCounter(value: goalTarget, textStyle: TextStyle(fontSize: TypeScale.title3, fontWeight: FontWeight.bold, color: AppStyles.getTextColor(context)), decimalPlaces: 0),
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
            child: Text('Recommendations', style: TextStyle(fontSize: TypeScale.title3, fontWeight: FontWeight.bold, color: AppStyles.getTextColor(context))),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.all(Spacing.lg),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _buildRecommendationCard('Reduce Dining Out', 'Save \u{20B9}3,000 by cooking at home', CupertinoIcons.house_fill, SemanticColors.success, 0),
              SizedBox(height: Spacing.md),
              _buildRecommendationCard('Optimize Subscriptions', 'Cancel unused services to save \u{20B9}1,500', CupertinoIcons.layers_alt_fill, SemanticColors.warning, 1),
              SizedBox(height: Spacing.md),
              _buildRecommendationCard('Emergency Fund Priority', 'Allocate \u{20B9}5,000 to emergency savings', CupertinoIcons.shield_fill, SemanticColors.info, 2),
              SizedBox(height: Spacing.md),
              _buildRecommendationCard('Entertainment Budget', 'Reduce spending by 20% to stay on track', CupertinoIcons.film_fill, SemanticColors.error, 3),
            ]),
          ),
        ),
        SliverToBoxAdapter(child: SizedBox(height: Spacing.lg)),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: Spacing.lg),
            child: Text('Category Breakdown', style: TextStyle(fontSize: TypeScale.title3, fontWeight: FontWeight.bold, color: AppStyles.getTextColor(context))),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.all(Spacing.lg),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _buildCategoryCard('Food & Dining', 15000, 20000, 0.75),
              SizedBox(height: Spacing.md),
              _buildCategoryCard('Transportation', 8000, 10000, 0.80),
              SizedBox(height: Spacing.md),
              _buildCategoryCard('Entertainment', 5000, 5000, 1.0),
              SizedBox(height: Spacing.md),
              _buildCategoryCard('Shopping', 12000, 15000, 0.80),
            ]),
          ),
        ),
        SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }

  Widget _buildRecommendationCard(String title, String description, IconData icon, Color color, int index) {
    return StaggeredItem(
      index: index,
      child: GlassCard(
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(Spacing.md),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(Radii.md)),
              child: Icon(icon, color: color, size: IconSizes.lg),
            ),
            SizedBox(width: Spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: TypeScale.callout, fontWeight: FontWeight.w600, color: AppStyles.getTextColor(context))),
                  SizedBox(height: Spacing.xxs),
                  Text(description, style: TextStyle(fontSize: TypeScale.footnote, color: AppStyles.getSecondaryTextColor(context))),
                ],
              ),
            ),
            Icon(CupertinoIcons.chevron_right, size: IconSizes.sm, color: AppStyles.getSecondaryTextColor(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard(String category, double spent, double budget, double progress) {
    final color = progress >= 0.9 ? SemanticColors.error : progress >= 0.75 ? SemanticColors.warning : SemanticColors.success;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(category, style: TextStyle(fontSize: TypeScale.callout, fontWeight: FontWeight.w600, color: AppStyles.getTextColor(context))),
              counter_widgets.AnimatedCounter(value: progress * 100, suffix: '%', decimalPlaces: 0, textStyle: TextStyle(fontSize: TypeScale.callout, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
          SizedBox(height: Spacing.md),
          LiquidLinearProgress(progress: progress, height: 8, color: color),
          SizedBox(height: Spacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('\u{20B9}${spent.toStringAsFixed(0)} spent', style: TextStyle(fontSize: TypeScale.footnote, color: AppStyles.getSecondaryTextColor(context))),
              Text('\u{20B9}${budget.toStringAsFixed(0)} budget', style: TextStyle(fontSize: TypeScale.footnote, color: AppStyles.getSecondaryTextColor(context))),
            ],
          ),
        ],
      ),
    );
  }
}
