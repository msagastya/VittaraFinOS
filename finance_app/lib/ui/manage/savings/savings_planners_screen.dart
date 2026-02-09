import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/budgets_controller.dart';
import 'package:vittara_fin_os/logic/budget_model.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/widgets/animations.dart';
import 'package:vittara_fin_os/ui/widgets/animated_counter.dart' as counter_widgets;
import 'package:vittara_fin_os/ui/widgets/common_widgets.dart';
import 'package:vittara_fin_os/ui/widgets/glass_card.dart';
import 'package:vittara_fin_os/ui/widgets/liquid_progress_indicators.dart';
import 'package:vittara_fin_os/utils/alert_service.dart';

class SavingsPlannersScreen extends StatefulWidget {
  const SavingsPlannersScreen({super.key});

  @override
  State<SavingsPlannersScreen> createState() => _SavingsPlannersScreenState();
}

class _SavingsPlannersScreenState extends State<SavingsPlannersScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<BudgetsController>(context, listen: false).initialize();
    });
  }

  void _showAddPlannerModal() {
    final nameController = TextEditingController();
    final targetController = TextEditingController();

    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        decoration: BoxDecoration(color: AppStyles.getCardColor(context), borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xxl))),
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + Spacing.xxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(margin: EdgeInsets.only(top: Spacing.md), width: 40, height: 5, decoration: BoxDecoration(color: CupertinoColors.systemGrey3, borderRadius: BorderRadius.circular(2.5))),
                SizedBox(height: Spacing.xl),
                Text('Create Savings Planner', style: TextStyle(fontSize: TypeScale.title2, fontWeight: FontWeight.bold, color: AppStyles.getTextColor(context))),
                SizedBox(height: Spacing.xxl),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: Spacing.xxl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Planner Name', style: TextStyle(fontSize: TypeScale.subhead, fontWeight: FontWeight.w600)),
                      SizedBox(height: Spacing.sm),
                      CupertinoTextField(controller: nameController, placeholder: 'e.g., Monthly Savings', padding: EdgeInsets.all(Spacing.lg), decoration: BoxDecoration(color: AppStyles.getBackground(context), borderRadius: BorderRadius.circular(Radii.md))),
                      SizedBox(height: Spacing.xl),
                      Text('Monthly Target', style: TextStyle(fontSize: TypeScale.subhead, fontWeight: FontWeight.w600)),
                      SizedBox(height: Spacing.sm),
                      CupertinoTextField(controller: targetController, placeholder: '5000', keyboardType: TextInputType.numberWithOptions(decimal: true), prefix: Padding(padding: EdgeInsets.only(left: Spacing.lg), child: Text('₹')), padding: EdgeInsets.all(Spacing.lg), decoration: BoxDecoration(color: AppStyles.getBackground(context), borderRadius: BorderRadius.circular(Radii.md))),
                      SizedBox(height: Spacing.xxxl),
                      Row(
                        children: [
                          Expanded(child: CupertinoButton(color: CupertinoColors.systemGrey3, onPressed: () => Navigator.pop(context), child: Text('Cancel', style: TextStyle(color: AppStyles.getTextColor(context))))),
                          SizedBox(width: Spacing.md),
                          Expanded(
                            child: CupertinoButton(
                              color: SemanticColors.success,
                              onPressed: () async {
                                if (nameController.text.trim().isEmpty) {
                                  AlertService.showError(context, 'Please enter a name');
                                  return;
                                }
                                final target = double.tryParse(targetController.text.trim());
                                if (target == null || target <= 0) {
                                  AlertService.showError(context, 'Please enter a valid target');
                                  return;
                                }
                                final planner = SavingsPlanner(id: 'planner_${DateTime.now().millisecondsSinceEpoch}', name: nameController.text.trim(), monthlyTarget: target, currentMonthSaved: 0, createdDate: DateTime.now());
                                await Provider.of<BudgetsController>(context, listen: false).addSavingsPlanner(planner);
                                Navigator.pop(context);
                                AlertService.showSuccess(context, 'Planner created!');
                              },
                              child: Text('Create', style: TextStyle(color: Colors.white)),
                            ),
                          ),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppStyles.getBackground(context),
      navigationBar: CupertinoNavigationBar(
        middle: Text('Savings Planners', style: TextStyle(color: AppStyles.getTextColor(context))),
        previousPageTitle: 'Manage',
        backgroundColor: AppStyles.getBackground(context),
        border: null,
      ),
      child: Consumer<BudgetsController>(
        builder: (context, controller, child) {
          final planners = controller.savingsplanners;

          return Stack(
            children: [
              SafeArea(
                child: planners.isEmpty
                    ? _buildEmptyState()
                    : CustomScrollView(
                        slivers: [
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.all(Spacing.lg),
                              child: GlassCard(
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Icon(CupertinoIcons.money_dollar_circle_fill, color: SemanticColors.success, size: IconSizes.lg),
                                        SizedBox(width: Spacing.md),
                                        Text('Total Monthly Target', style: TextStyle(fontSize: TypeScale.title3, fontWeight: FontWeight.w600, color: AppStyles.getTextColor(context))),
                                      ],
                                    ),
                                    SizedBox(height: Spacing.lg),
                                    counter_widgets.CurrencyCounter(value: controller.totalMonthlySavingsTarget, textStyle: TextStyle(fontSize: TypeScale.largeTitle, fontWeight: FontWeight.bold, color: SemanticColors.success), decimalPlaces: 0),
                                    SizedBox(height: Spacing.sm),
                                    Text('${planners.length} active planner${planners.length > 1 ? 's' : ''}', style: TextStyle(fontSize: TypeScale.footnote, color: AppStyles.getSecondaryTextColor(context))),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          SliverPadding(
                            padding: EdgeInsets.all(Spacing.lg),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final planner = planners[index];
                                  return StaggeredItem(
                                    index: index,
                                    child: Padding(
                                      padding: EdgeInsets.only(bottom: Spacing.lg),
                                      child: GlassCard(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(child: Text(planner.name, style: TextStyle(fontSize: TypeScale.callout, fontWeight: FontWeight.w600, color: AppStyles.getTextColor(context)), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                                if (planner.autoSave)
                                                  Container(
                                                    padding: EdgeInsets.symmetric(horizontal: Spacing.sm, vertical: Spacing.xxs),
                                                    decoration: BoxDecoration(color: SemanticColors.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(Radii.xs)),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Icon(CupertinoIcons.checkmark_seal_fill, size: IconSizes.xs, color: SemanticColors.success),
                                                        SizedBox(width: Spacing.xxs),
                                                        Text('AUTO', style: TextStyle(fontSize: TypeScale.caption, fontWeight: FontWeight.w700, color: SemanticColors.success)),
                                                      ],
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            SizedBox(height: Spacing.lg),
                                            LiquidCircularProgress(progress: planner.currentMonthPercentage / 100, size: 100, color: SemanticColors.success, center: counter_widgets.AnimatedCounter(value: planner.currentMonthPercentage, suffix: '%', decimalPlaces: 1, textStyle: TextStyle(fontSize: TypeScale.title3, fontWeight: FontWeight.bold, color: SemanticColors.success))),
                                            SizedBox(height: Spacing.lg),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text('Saved This Month', style: TextStyle(fontSize: TypeScale.footnote, color: AppStyles.getSecondaryTextColor(context))),
                                                    SizedBox(height: Spacing.xxs),
                                                    counter_widgets.CurrencyCounter(value: planner.currentMonthSaved, textStyle: TextStyle(fontSize: TypeScale.callout, fontWeight: FontWeight.w700, color: SemanticColors.success), decimalPlaces: 0),
                                                  ],
                                                ),
                                                Column(
                                                  crossAxisAlignment: CrossAxisAlignment.end,
                                                  children: [
                                                    Text('Monthly Target', style: TextStyle(fontSize: TypeScale.footnote, color: AppStyles.getSecondaryTextColor(context))),
                                                    SizedBox(height: Spacing.xxs),
                                                    counter_widgets.CurrencyCounter(value: planner.monthlyTarget, textStyle: TextStyle(fontSize: TypeScale.callout, fontWeight: FontWeight.w700, color: AppStyles.getTextColor(context)), decimalPlaces: 0),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                                childCount: planners.length,
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
                child: FadingFAB(onPressed: _showAddPlannerModal, color: SemanticColors.success, heroTag: 'savings_fab', icon: CupertinoIcons.add),
              ),
            ],
          );
        },
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
              decoration: BoxDecoration(color: SemanticColors.success.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(CupertinoIcons.money_dollar_circle_fill, size: IconSizes.emptyStateIcon, color: SemanticColors.success),
            ),
            SizedBox(height: Spacing.xxl),
            Text('No Savings Planners', style: TextStyle(fontSize: TypeScale.largeTitle, fontWeight: FontWeight.bold, color: AppStyles.getTextColor(context))),
            SizedBox(height: Spacing.md),
            Text('Create a planner to track your\nmonthly savings progress', textAlign: TextAlign.center, style: TextStyle(fontSize: TypeScale.callout, color: AppStyles.getSecondaryTextColor(context))),
            SizedBox(height: Spacing.xxxl),
            BouncyButton(
              onPressed: _showAddPlannerModal,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: Spacing.xxl, vertical: Spacing.lg),
                decoration: BoxDecoration(gradient: LinearGradient(colors: [SemanticColors.success, SemanticColors.success.withValues(alpha: 0.8)]), borderRadius: BorderRadius.circular(Radii.full), boxShadow: [BoxShadow(color: SemanticColors.success.withValues(alpha: 0.4), blurRadius: 20, offset: Offset(0, 8))]),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.add, color: Colors.white, size: IconSizes.lg),
                    SizedBox(width: Spacing.sm),
                    Text('Create Your First Planner', style: TextStyle(fontSize: TypeScale.callout, fontWeight: FontWeight.w600, color: Colors.white)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
