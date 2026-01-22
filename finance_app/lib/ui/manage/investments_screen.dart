import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/investment_model.dart';
import 'package:vittara_fin_os/logic/investments_controller.dart';
import 'package:vittara_fin_os/ui/manage/investment_type_selection.dart';
import 'package:vittara_fin_os/ui/manage/stocks/stocks_wizard.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/widgets/animations.dart';
import 'package:vittara_fin_os/ui/widgets/common_widgets.dart';
import 'package:vittara_fin_os/ui/widgets/toast_notification.dart';
import 'package:vittara_fin_os/utils/logger.dart';

class InvestmentsScreen extends StatefulWidget {
  const InvestmentsScreen({super.key});

  @override
  State<InvestmentsScreen> createState() => _InvestmentsScreenState();
}

class _InvestmentsScreenState extends State<InvestmentsScreen> {
  final AppLogger logger = AppLogger();

  void _showInvestmentTypeSelection(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (modalContext) => InvestmentTypeSelectionModal(
        onTypeSelected: (investmentType) {
          logger.info('Selected investment type: ${investmentType.name}', context: 'InvestmentsScreen');

          if (investmentType == InvestmentType.stocks) {
            Navigator.of(context).push(
              CupertinoPageRoute(builder: (context) => const StocksWizard()),
            );
          } else {
            toast.showInfo('Coming soon!');
          }
        },
      ),
    );
  }

  void _onReorder(int oldIndex, int newIndex) {
    final investmentsController = Provider.of<InvestmentsController>(context, listen: false);
    investmentsController.reorderInvestments(oldIndex, newIndex);
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppStyles.getBackground(context),
      navigationBar: CupertinoNavigationBar(
        middle: Text('Investments', style: TextStyle(color: AppStyles.getTextColor(context))),
        previousPageTitle: 'Manage',
        backgroundColor: AppStyles.getBackground(context),
        border: null,
      ),
      child: Consumer<InvestmentsController>(
        builder: (context, investmentsController, child) {
          final investments = investmentsController.investments;
          final totalAmount = investmentsController.getTotalInvestmentAmount();

          return Stack(
            children: [
              if (investments.isEmpty)
                EmptyStateView(
                  icon: CupertinoIcons.chart_pie_fill,
                  title: 'No Investments Added',
                  subtitle: 'Track your stocks, mutual funds, crypto and more',
                  actionLabel: 'Add Investment',
                  onAction: () => _showInvestmentTypeSelection(context),
                )
              else
                SafeArea(
                  child: Column(
                    children: [
                      // Total Investment Card with Animated Counter
                      Padding(
                        padding: EdgeInsets.all(Spacing.lg),
                        child: FadeInAnimation(
                          child: SummaryCard(
                            label: 'Total Invested',
                            value: totalAmount,
                            prefix: '₹',
                            decimals: 2,
                            subtitle: '${investments.length} investments across ${_getDistinctTypesCount(investments)} categories',
                            valueColor: SemanticColors.investments,
                            useGradientBorder: totalAmount > 100000,
                            gradientColors: const [
                              Color(0xFFFF9500),
                              Color(0xFFFF5E3A),
                              Color(0xFFFF2D55),
                            ],
                          ),
                        ),
                      ),
                      // Investments List with Staggered Animation
                      Expanded(
                        child: ReorderableListView.builder(
                          padding: EdgeInsets.fromLTRB(Spacing.lg, 0, Spacing.lg, 100),
                          itemCount: investments.length,
                          onReorder: (oldIndex, newIndex) {
                            Haptics.reorder();
                            _onReorder(oldIndex, newIndex);
                          },
                          proxyDecorator: (child, index, animation) {
                            return AnimatedBuilder(
                              animation: animation,
                              builder: (context, child) => Transform.scale(
                                scale: 1.02,
                                child: Container(
                                  decoration: AppStyles.cardDecoration(context),
                                  child: child,
                                ),
                              ),
                              child: child,
                            );
                          },
                          itemBuilder: (context, index) {
                            return StaggeredItem(
                              key: ValueKey(investments[index].id),
                              index: index,
                              child: _buildInvestmentCard(investments[index]),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              Positioned(
                right: Spacing.lg,
                bottom: Spacing.xxxl,
                child: FadingFAB(
                  onPressed: () => _showInvestmentTypeSelection(context),
                  color: SemanticColors.investments,
                  heroTag: 'investments_fab',
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  int _getDistinctTypesCount(List<Investment> investments) {
    return investments.map((inv) => inv.type).toSet().length;
  }

  Widget _buildInvestmentCard(Investment investment) {
    return Hero(
      tag: 'investment_${investment.id}',
      child: BouncyButton(
        onPressed: () {
          Haptics.light();
          toast.showInfo('Investment details coming soon!');
        },
        child: Container(
          margin: EdgeInsets.only(bottom: Spacing.lg),
          decoration: AppStyles.cardDecoration(context),
          child: Padding(
            padding: Spacing.cardPadding,
            child: Row(
              children: [
                IconBox(
                  icon: CupertinoIcons.chart_bar_square_fill,
                  color: investment.color,
                  showGlow: true,
                ),
                SizedBox(width: Spacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(investment.name, style: AppStyles.titleStyle(context)),
                      SizedBox(height: Spacing.xs),
                      Text(
                        investment.getTypeLabel(),
                        style: TextStyle(
                          fontSize: TypeScale.footnote,
                          color: AppStyles.getSecondaryTextColor(context),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    AnimatedCounter(
                      value: investment.amount,
                      prefix: '₹',
                      decimals: 2,
                      duration: AppDurations.counter,
                      style: AppStyles.titleStyle(context).copyWith(
                        color: investment.color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: Spacing.xs),
                    Icon(
                      CupertinoIcons.chevron_up,
                      size: IconSizes.xs,
                      color: AppStyles.getSecondaryTextColor(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

}

