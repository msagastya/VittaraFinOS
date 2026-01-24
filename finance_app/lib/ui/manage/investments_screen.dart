import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/investment_model.dart';
import 'package:vittara_fin_os/logic/investments_controller.dart';
import 'package:vittara_fin_os/ui/manage/investment_type_selection.dart';
import 'package:vittara_fin_os/ui/manage/stocks/stocks_wizard.dart';
import 'package:vittara_fin_os/ui/manage/stocks/stock_details_screen.dart';
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
  bool _isSummaryExpanded = true;
  InvestmentType? _selectedFilter; // null = All investments

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

          // Filter investments based on selected type
          final filteredInvestments = _selectedFilter == null
              ? investments
              : investments.where((inv) => inv.type == _selectedFilter).toList();

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
                      // Filter Bar
                      _buildFilterBar(context, investments),
                      SizedBox(height: Spacing.md),
                      // Investment Type-wise Summary Cards
                      if (filteredInvestments.isNotEmpty)
                        Padding(
                          padding: EdgeInsets.only(top: Spacing.lg),
                          child: _buildInvestmentTypeSummaryCards(context, filteredInvestments),
                        ),
                      SizedBox(height: Spacing.lg),
                      // Investments List with Staggered Animation
                      if (filteredInvestments.isEmpty)
                        Expanded(
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  CupertinoIcons.search,
                                  size: 48,
                                  color: AppStyles.getSecondaryTextColor(context).withOpacity(0.5),
                                ),
                                SizedBox(height: Spacing.md),
                                Text(
                                  'No investments found',
                                  style: TextStyle(
                                    color: AppStyles.getSecondaryTextColor(context),
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        Expanded(
                          child: ReorderableListView.builder(
                            padding: EdgeInsets.fromLTRB(Spacing.lg, 0, Spacing.lg, 100),
                            itemCount: filteredInvestments.length,
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
                                key: ValueKey(filteredInvestments[index].id),
                                index: index,
                                child: _buildInvestmentCard(filteredInvestments[index]),
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

  Widget _buildFilterBar(BuildContext context, List<Investment> investments) {
    // Get all unique types present in investments
    final investmentTypes = InvestmentType.values;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.md),
          child: Text(
            'Filter by Type',
            style: TextStyle(
              color: AppStyles.getTextColor(context),
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: Spacing.lg),
          child: Row(
            children: [
              // "All" option
              GestureDetector(
                onTap: () => setState(() => _selectedFilter = null),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.sm),
                  decoration: BoxDecoration(
                    color: _selectedFilter == null
                        ? SemanticColors.investments
                        : AppStyles.getCardColor(context),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _selectedFilter == null
                          ? SemanticColors.investments
                          : AppStyles.getSecondaryTextColor(context).withOpacity(0.2),
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    'All',
                    style: TextStyle(
                      color: _selectedFilter == null
                          ? Colors.white
                          : AppStyles.getTextColor(context),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              SizedBox(width: Spacing.md),
              // Investment type filters
              ...investmentTypes.map((type) {
                final count = investments.where((inv) => inv.type == type).length;
                final isSelected = _selectedFilter == type;

                return Padding(
                  padding: EdgeInsets.only(right: Spacing.md),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedFilter = type),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.sm),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? SemanticColors.investments
                            : AppStyles.getCardColor(context),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? SemanticColors.investments
                              : AppStyles.getSecondaryTextColor(context).withOpacity(0.2),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _getInvestmentTypeLabel(type),
                            style: TextStyle(
                              color: isSelected ? Colors.white : AppStyles.getTextColor(context),
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          if (count > 0)
                            Text(
                              '($count)',
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white.withOpacity(0.8)
                                    : AppStyles.getSecondaryTextColor(context),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  int _getDistinctTypesCount(List<Investment> investments) {
    return investments.map((inv) => inv.type).toSet().length;
  }

  List<Investment> _getInvestmentsByType(List<Investment> investments, InvestmentType type) {
    return investments.where((inv) => inv.type == type).toList();
  }

  double _getTotalByType(List<Investment> investments, InvestmentType type) {
    return _getInvestmentsByType(investments, type)
        .fold(0.0, (sum, inv) => sum + inv.amount);
  }

  double _getCurrentValueByType(List<Investment> investments, InvestmentType type) {
    return _getInvestmentsByType(investments, type).fold(0.0, (sum, inv) {
      // Try to get current value from metadata, otherwise use invested amount
      final metadata = inv.metadata;
      if (metadata != null && metadata.containsKey('currentValue')) {
        return sum + (metadata['currentValue'] as num).toDouble();
      }
      return sum + inv.amount;
    });
  }

  bool _hasInvestmentType(List<Investment> investments, InvestmentType type) {
    return investments.any((inv) => inv.type == type);
  }

  Color _getInvestmentTypeColor(InvestmentType type) {
    switch (type) {
      case InvestmentType.stocks:
        return const Color(0xFF00B050);
      case InvestmentType.mutualFund:
        return const Color(0xFF0066CC);
      case InvestmentType.fixedDeposit:
        return const Color(0xFFFF6B00);
      case InvestmentType.recurringDeposit:
        return const Color(0xFFD600CC);
      case InvestmentType.bonds:
        return const Color(0xFF00A6CC);
      case InvestmentType.nationalSavingsScheme:
        return const Color(0xFFEC6100);
      case InvestmentType.digitalGold:
        return const Color(0xFFFFB81C);
      case InvestmentType.pensionSchemes:
        return const Color(0xFF9B59B6);
      case InvestmentType.cryptocurrency:
        return const Color(0xFFF7931A);
      case InvestmentType.futuresOptions:
        return const Color(0xFF1ABC9C);
      case InvestmentType.forexCurrency:
        return const Color(0xFF34495E);
      case InvestmentType.commodities:
        return const Color(0xFF8B4513);
    }
  }

  String _getInvestmentTypeLabel(InvestmentType type) {
    switch (type) {
      case InvestmentType.stocks:
        return 'Stocks';
      case InvestmentType.mutualFund:
        return 'Mutual Fund';
      case InvestmentType.fixedDeposit:
        return 'Fixed Deposit (FD)';
      case InvestmentType.recurringDeposit:
        return 'Recurring Deposit (RD)';
      case InvestmentType.bonds:
        return 'Bonds';
      case InvestmentType.nationalSavingsScheme:
        return 'National Savings Scheme';
      case InvestmentType.digitalGold:
        return 'Digital Gold';
      case InvestmentType.pensionSchemes:
        return 'Pension Schemes';
      case InvestmentType.cryptocurrency:
        return 'Cryptocurrency';
      case InvestmentType.futuresOptions:
        return 'Futures and Options';
      case InvestmentType.forexCurrency:
        return 'Forex/Currency';
      case InvestmentType.commodities:
        return 'Commodities';
    }
  }

  Widget _buildInvestmentTypeSummaryCards(BuildContext context, List<Investment> investments) {
    final typesToShow = [
      InvestmentType.stocks,
      InvestmentType.mutualFund,
      InvestmentType.fixedDeposit,
      InvestmentType.bonds,
      InvestmentType.digitalGold,
      InvestmentType.cryptocurrency,
      InvestmentType.recurringDeposit,
      InvestmentType.nationalSavingsScheme,
      InvestmentType.pensionSchemes,
      InvestmentType.futuresOptions,
      InvestmentType.forexCurrency,
      InvestmentType.commodities,
    ];

    final availableTypes = typesToShow.where((type) => _hasInvestmentType(investments, type)).toList();

    if (availableTypes.isEmpty) {
      return SizedBox.shrink();
    }

    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: Container(
        decoration: AppStyles.cardDecoration(context),
        margin: EdgeInsets.symmetric(horizontal: Spacing.lg),
        child: Column(
          children: [
            // Header with expand/collapse button
            Padding(
              padding: EdgeInsets.all(Spacing.lg),
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _isSummaryExpanded = !_isSummaryExpanded;
                  });
                },
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Investment Summary',
                            style: AppStyles.titleStyle(context),
                          ),
                          SizedBox(height: Spacing.xs),
                          Text(
                            '${investments.length} investments across ${_getDistinctTypesCount(investments)} categories',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppStyles.getSecondaryTextColor(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      _isSummaryExpanded
                          ? CupertinoIcons.chevron_up
                          : CupertinoIcons.chevron_down,
                      size: 20,
                      color: AppStyles.getSecondaryTextColor(context),
                    ),
                  ],
                ),
              ),
            ),
            // Expandable content
            if (_isSummaryExpanded)
              Padding(
                padding: EdgeInsets.only(bottom: Spacing.lg),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: Spacing.lg),
                  child: Row(
                    children: [
                      for (int i = 0; i < availableTypes.length; i++) ...[
                        _buildInvestmentTypeSummaryCard(
                          context,
                          availableTypes[i],
                          investments,
                        ),
                        if (i < availableTypes.length - 1) SizedBox(width: Spacing.lg),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvestmentTypeSummaryCard(
    BuildContext context,
    InvestmentType type,
    List<Investment> investments,
  ) {
    final color = _getInvestmentTypeColor(type);
    final typeLabel = _getInvestmentTypeLabel(type);
    final investmentsList = _getInvestmentsByType(investments, type);
    final count = investmentsList.length;
    final invested = _getTotalByType(investments, type);
    final currentValue = _getCurrentValueByType(investments, type);
    final gainLoss = currentValue - invested;
    final gainLossPercent = invested > 0 ? (gainLoss / invested) * 100 : 0;
    final isPositive = gainLoss >= 0;

    return Container(
      width: 240,
      decoration: AppStyles.cardDecoration(context),
      child: Padding(
        padding: EdgeInsets.all(Spacing.lg),
        child: FadeInAnimation(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with icon and type label
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      CupertinoIcons.chart_bar_square_fill,
                      size: 18,
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          typeLabel,
                          style: AppStyles.titleStyle(context).copyWith(fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '$count ${count == 1 ? 'investment' : 'investments'}',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppStyles.getSecondaryTextColor(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: Spacing.lg),

              // Invested Amount
              Text(
                'Invested',
                style: TextStyle(
                  fontSize: 12,
                  color: AppStyles.getSecondaryTextColor(context),
                ),
              ),
              const SizedBox(height: 2),
              AnimatedCounter(
                value: invested,
                prefix: '₹',
                decimals: 2,
                duration: AppDurations.counter,
                style: TextStyle(
                  fontSize: 16,
                  color: AppStyles.getTextColor(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: Spacing.md),

              // Current Value
              Text(
                'Current Value',
                style: TextStyle(
                  fontSize: 12,
                  color: AppStyles.getSecondaryTextColor(context),
                ),
              ),
              const SizedBox(height: 2),
              AnimatedCounter(
                value: currentValue,
                prefix: '₹',
                decimals: 2,
                duration: AppDurations.counter,
                style: TextStyle(
                  fontSize: 16,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: Spacing.md),

              // Gain/Loss
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: Spacing.md,
                  vertical: Spacing.sm,
                ),
                decoration: BoxDecoration(
                  color: isPositive
                      ? CupertinoColors.systemGreen.withValues(alpha: 0.1)
                      : CupertinoColors.systemRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isPositive ? 'Gain' : 'Loss',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppStyles.getSecondaryTextColor(context),
                          ),
                        ),
                        const SizedBox(height: 2),
                        AnimatedCounter(
                          value: gainLoss.abs(),
                          prefix: isPositive ? '+₹' : '-₹',
                          decimals: 2,
                          duration: AppDurations.counter,
                          style: TextStyle(
                            fontSize: 13,
                            color: isPositive
                                ? CupertinoColors.systemGreen
                                : CupertinoColors.systemRed,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppStyles.getSecondaryTextColor(context),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${gainLossPercent.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 13,
                            color: isPositive
                                ? CupertinoColors.systemGreen
                                : CupertinoColors.systemRed,
                            fontWeight: FontWeight.w600,
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
    );
  }

  Widget _buildInvestmentCard(Investment investment) {
    // Calculate values
    final investedAmount = investment.amount;
    final currentValue = _calculateCurrentValue(investment);
    final gainLoss = currentValue - investedAmount;
    final gainLossPercent = investedAmount > 0 ? (gainLoss / investedAmount) * 100 : 0;
    final isProfit = gainLoss >= 0;

    return Hero(
      tag: 'investment_${investment.id}',
      child: BouncyButton(
        onPressed: () {
          Haptics.light();
          // Navigate to stock details screen if it's a stock investment
          if (investment.type == InvestmentType.stocks) {
            Navigator.of(context).push(
              CupertinoPageRoute(
                builder: (context) => StockDetailsScreen(investment: investment),
              ),
            );
          } else {
            toast.showInfo('Details for ${investment.getTypeLabel()} coming soon!');
          }
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
                      SizedBox(height: Spacing.sm),
                      // Investment metrics
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Invested',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppStyles.getSecondaryTextColor(context),
                                  ),
                                ),
                                Text(
                                  '₹${investedAmount.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppStyles.getTextColor(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: Spacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Current',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppStyles.getSecondaryTextColor(context),
                                  ),
                                ),
                                Text(
                                  '₹${currentValue.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppStyles.getTextColor(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.xs),
                      decoration: BoxDecoration(
                        color: isProfit
                            ? CupertinoColors.systemGreen.withOpacity(0.15)
                            : CupertinoColors.systemRed.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${isProfit ? '+' : ''}${gainLossPercent.toStringAsFixed(2)}%',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isProfit
                              ? CupertinoColors.systemGreen
                              : CupertinoColors.systemRed,
                        ),
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

  double _calculateCurrentValue(Investment investment) {
    final metadata = investment.metadata;
    if (metadata != null && metadata.containsKey('currentValue')) {
      return (metadata['currentValue'] as num).toDouble();
    }
    return investment.amount;
  }

}

