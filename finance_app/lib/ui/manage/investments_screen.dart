import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/investment_model.dart';
import 'package:vittara_fin_os/logic/fixed_deposit_model.dart';
import 'package:vittara_fin_os/logic/recurring_deposit_model.dart';
import 'package:vittara_fin_os/logic/investments_controller.dart';
import 'package:vittara_fin_os/services/gold_price_service.dart';
import 'package:vittara_fin_os/ui/manage/investment_type_selection.dart';
import 'package:vittara_fin_os/ui/manage/stocks/stocks_wizard.dart';
import 'package:vittara_fin_os/ui/manage/stocks/stock_details_screen.dart';
import 'package:vittara_fin_os/ui/manage/mf/mf_wizard.dart';
import 'package:vittara_fin_os/ui/manage/mf/mf_details_screen.dart';
import 'package:vittara_fin_os/ui/manage/fd/fd_details_screen.dart';
import 'package:vittara_fin_os/ui/manage/rd/rd_details_screen.dart';
import 'package:vittara_fin_os/ui/manage/bonds/bonds_details_screen.dart';
import 'package:vittara_fin_os/ui/manage/cryptocurrency/crypto_details_screen.dart';
import 'package:vittara_fin_os/ui/manage/digital_gold/digital_gold_wizard.dart';
import 'package:vittara_fin_os/ui/manage/digital_gold/digital_gold_details_screen.dart';
import 'package:vittara_fin_os/ui/manage/nps/nps_details_screen.dart';
import 'package:vittara_fin_os/ui/manage/pension/pension_details_screen.dart';
import 'package:vittara_fin_os/ui/manage/commodities/commodities_details_screen.dart';
import 'package:vittara_fin_os/ui/manage/fo/fo_details_screen.dart';
import 'package:vittara_fin_os/ui/manage/simple_investment_entry_wizard.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/widgets/animations.dart';
import 'package:vittara_fin_os/ui/widgets/common_widgets.dart';
import 'package:vittara_fin_os/ui/widgets/toast_notification.dart';
import 'package:vittara_fin_os/utils/logger.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:vittara_fin_os/services/investment_value_service.dart';
import 'package:vittara_fin_os/utils/date_formatter.dart';

enum SortBy {
  currentAmount,
  investedAmount,
  gainPercent,
  gainAmount,
  name,
  type,
  dateAdded
}

class InvestmentsScreen extends StatefulWidget {
  const InvestmentsScreen({super.key});

  @override
  State<InvestmentsScreen> createState() => _InvestmentsScreenState();
}

class _InvestmentsScreenState extends State<InvestmentsScreen> {
  static const List<InvestmentType> _supportedInvestmentTypes = [
    InvestmentType.stocks,
    InvestmentType.mutualFund,
    InvestmentType.digitalGold,
    InvestmentType.nationalSavingsScheme,
    InvestmentType.bonds,
  ];

  final AppLogger logger = AppLogger();
  bool _isSummaryExpanded = true;
  InvestmentType? _selectedFilter; // null = All investments
  final PageController _categoryPageController = PageController();
  int _selectedCategoryIndex = 0;

  // Sort options
  SortBy _sortBy = SortBy.currentAmount;
  bool _sortAscending = false; // true = ascending, false = descending

  // Memoized sort cache — avoids O(n log n) sort on every build
  List<Investment> _cachedSortedList = [];
  List<Investment>? _lastSortedSource;
  SortBy _lastSortBy = SortBy.currentAmount;
  bool _lastSortAscending = false;

  // Search
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  final InvestmentValueService _valueService = InvestmentValueService();
  bool _isRefreshingCurrentValues = false;

  // Cache for current gold price (shared across all digital gold cards)
  double? _cachedGoldPrice;
  Future<double?>? _goldPriceFuture;

  @override
  void dispose() {
    _categoryPageController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String _getSortLabel(SortBy sort) {
    switch (sort) {
      case SortBy.currentAmount:
        return 'Current Amount';
      case SortBy.investedAmount:
        return 'Invested Amount';
      case SortBy.gainPercent:
        return 'Gain %';
      case SortBy.gainAmount:
        return 'Gain Amount';
      case SortBy.name:
        return 'Name';
      case SortBy.type:
        return 'Type';
      case SortBy.dateAdded:
        return 'Date Added';
    }
  }

  List<Investment> _sortInvestments(List<Investment> investments) {
    // Return cached result when nothing has changed
    if (identical(investments, _lastSortedSource) &&
        _lastSortBy == _sortBy &&
        _lastSortAscending == _sortAscending) {
      return _cachedSortedList;
    }

    final sorted = List<Investment>.from(investments);

    sorted.sort((a, b) {
      int comparison = 0;

      switch (_sortBy) {
        case SortBy.currentAmount:
          final aValue = _calculateCurrentValue(a);
          final bValue = _calculateCurrentValue(b);
          comparison = aValue.compareTo(bValue);
          break;

        case SortBy.investedAmount:
          comparison = a.amount.compareTo(b.amount);
          break;

        case SortBy.gainPercent:
          final aGainPercent = _calculateGainLossPercent(a);
          final bGainPercent = _calculateGainLossPercent(b);
          comparison = aGainPercent.compareTo(bGainPercent);
          break;

        case SortBy.gainAmount:
          final aGain = _calculateCurrentValue(a) - a.amount;
          final bGain = _calculateCurrentValue(b) - b.amount;
          comparison = aGain.compareTo(bGain);
          break;

        case SortBy.name:
          comparison = a.name.compareTo(b.name);
          break;

        case SortBy.type:
          comparison = a.type.index.compareTo(b.type.index);
          break;

        case SortBy.dateAdded:
          comparison = a.id.compareTo(b.id); // ID as proxy for date added
          break;
      }

      return _sortAscending ? comparison : -comparison;
    });

    // Update cache
    _cachedSortedList = sorted;
    _lastSortedSource = investments;
    _lastSortBy = _sortBy;
    _lastSortAscending = _sortAscending;

    return _cachedSortedList;
  }

  // Fetch current gold price with caching
  Future<double?> _getCurrentGoldPrice() async {
    // Use cached price if available
    if (_cachedGoldPrice != null) {
      return _cachedGoldPrice;
    }

    // Fetch fresh price
    final price = await GoldPriceService.fetchCurrentGoldPrice();
    if (price != null) {
      _cachedGoldPrice = price;
    }
    return price;
  }

  Future<void> _refreshCurrentValues(BuildContext context) async {
    if (_isRefreshingCurrentValues) return;
    setState(() => _isRefreshingCurrentValues = true);

    try {
      final controller =
          Provider.of<InvestmentsController>(context, listen: false);
      final updated = await controller.refreshCurrentValues(
        _valueService,
        forceRefresh: true,
      );

      if (!mounted) return;

      if (updated) {
        toast.showSuccess('Current values refreshed');
      } else {
        toast.showInfo('Current values already up to date');
      }
    } catch (error, stackTrace) {
      toast.showError('Failed to refresh current values');
      logger.warning('Refresh current values failed',
          error: error, stackTrace: stackTrace);
    } finally {
      if (mounted) {
        setState(() => _isRefreshingCurrentValues = false);
      }
    }
  }

  double _calculateCurrentValue(Investment investment) {
    final metadata = investment.metadata;
    if (metadata != null) {
      final isFdOrRd = investment.type == InvestmentType.fixedDeposit ||
          investment.type == InvestmentType.recurringDeposit;

      // For FDs - check if maturity freeze should apply
      if (investment.type == InvestmentType.fixedDeposit) {
        final maturityDateStr = metadata['maturityDate'] as String?;

        if (maturityDateStr != null) {
          try {
            final maturityDate = DateTime.parse(maturityDateStr);
            final today = DateTime.now();
            final daysUntilMaturity = maturityDate.difference(today).inDays;

            // If within 10 days of maturity or already matured, freeze the value at maturity value
            if (daysUntilMaturity <= 10) {
              if (metadata.containsKey('maturityValue')) {
                return (metadata['maturityValue'] as num).toDouble();
              }
              if (metadata.containsKey('estimatedAccruedValue')) {
                return (metadata['estimatedAccruedValue'] as num).toDouble();
              }
            }
          } catch (e) {
            // Continue to normal calculation if date parsing fails
          }
        }
      }

      // For FDs and RDs - calculate current accrued value based on time elapsed
      if (investment.type == InvestmentType.fixedDeposit ||
          investment.type == InvestmentType.recurringDeposit) {
        final interestRate = (metadata['interestRate'] as num?)?.toDouble();
        final investmentDateStr = metadata['investmentDate'] as String?;
        final compoundingFreqStr = metadata['compoundingFrequency'] as String?;
        final isCumulative = (metadata['isCumulative'] as bool?) ?? true;

        if (interestRate != null && investmentDateStr != null && isCumulative) {
          try {
            final investmentDate = DateTime.parse(investmentDateStr);
            final today = DateTime.now();
            final daysElapsed = today.difference(investmentDate).inDays;

            if (daysElapsed > 0) {
              // Calculate current accrued value based on days elapsed
              final principal = investment.amount;
              double currentValue = principal;

              // Determine compounding frequency
              int compoundsPerYear = 4; // default quarterly
              if (compoundingFreqStr != null) {
                if (compoundingFreqStr.contains('annually')) {
                  compoundsPerYear = 1;
                } else if (compoundingFreqStr.contains('semi')) {
                  compoundsPerYear = 2;
                } else if (compoundingFreqStr.contains('quarterly')) {
                  compoundsPerYear = 4;
                } else if (compoundingFreqStr.contains('monthly')) {
                  compoundsPerYear = 12;
                } else if (compoundingFreqStr.contains('daily')) {
                  compoundsPerYear = 365;
                }
              }

              // Calculate number of compounding periods elapsed
              final daysPerCompound = 365 / compoundsPerYear;
              final compoundsElapsed = daysElapsed / daysPerCompound;

              // Compound interest formula: A = P(1 + r/(100*k))^(n*k*t)
              // where k = compounds per year, t = years
              final rate = interestRate / 100.0;
              final ratePerCompound = rate / compoundsPerYear;
              currentValue = principal *
                  pow(1 + ratePerCompound, compoundsElapsed).toDouble();

              return currentValue;
            }
          } catch (e) {
            // If calculation fails, fall back to invested amount
          }
        }

        // Fallback to estimatedAccruedValue if calculation not possible
        if (metadata.containsKey('estimatedAccruedValue')) {
          return (metadata['estimatedAccruedValue'] as num).toDouble();
        }
      }

      // Check for estimatedAccruedValue (stocks, other investments)
      if (!isFdOrRd &&
          metadata.containsKey('currentValue') &&
          metadata['currentValue'] != 0) {
        return (metadata['currentValue'] as num).toDouble();
      }

      if (metadata.containsKey('estimatedAccruedValue')) {
        return (metadata['estimatedAccruedValue'] as num).toDouble();
      }
    }
    return investment.amount;
  }

  double _calculateGainLossPercent(Investment investment) {
    final investedAmount = investment.amount;
    final currentValue = _calculateCurrentValue(investment);
    if (investedAmount > 0) {
      return ((currentValue - investedAmount) / investedAmount) * 100;
    }
    return 0;
  }

  List<InvestmentType> _availableSupportedTypes(List<Investment> investments) {
    return _supportedInvestmentTypes
        .where((type) => investments.any((inv) => inv.type == type))
        .toList();
  }

  void _showInvestmentTypeSelection(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (modalContext) => InvestmentTypeSelectionModal(
        onTypeSelected: (investmentType) {
          logger.info('Selected investment type: ${investmentType.name}',
              context: 'InvestmentsScreen');

          if (investmentType == InvestmentType.stocks) {
            Navigator.of(context).push(
              CupertinoPageRoute(builder: (context) => const StocksWizard()),
            );
          } else if (investmentType == InvestmentType.mutualFund) {
            Navigator.of(context).push(
              CupertinoPageRoute(builder: (context) => const MFWizard()),
            );
          } else if (investmentType == InvestmentType.digitalGold) {
            Navigator.of(context).push(
              CupertinoPageRoute(
                  builder: (context) => const DigitalGoldWizard()),
            );
          } else if (investmentType == InvestmentType.nationalSavingsScheme) {
            Navigator.of(context).push(
              CupertinoPageRoute(
                builder: (context) => const SimpleInvestmentEntryWizard(
                  type: InvestmentType.nationalSavingsScheme,
                  title: 'Add NPS',
                  subtitle:
                      'NPS tracker for account-wise contribution and history.',
                  color: Color(0xFFEC6100),
                  defaultName: 'NPS Account',
                  referenceLabel: 'PRAN / Account ID (Optional)',
                  referenceHint: 'Enter PRAN or account reference',
                ),
              ),
            );
          } else if (investmentType == InvestmentType.bonds) {
            Navigator.of(context).push(
              CupertinoPageRoute(
                builder: (context) => const SimpleInvestmentEntryWizard(
                  type: InvestmentType.bonds,
                  title: 'Add Bond',
                  subtitle:
                      'Simple bond tracking with account linkage and transaction visibility.',
                  color: Color(0xFF00A6CC),
                  defaultName: 'Bond Holding',
                  referenceLabel: 'Issuer / ISIN (Optional)',
                  referenceHint: 'Enter issuer or ISIN',
                ),
              ),
            );
          } else {
            toast.showInfo(
              'This investment type is intentionally disabled for focused professional tracking.',
            );
          }
        },
      ),
    );
  }

  void _onReorder(int oldIndex, int newIndex) {
    final investmentsController =
        Provider.of<InvestmentsController>(context, listen: false);
    investmentsController.reorderInvestments(oldIndex, newIndex);
  }

  List<InvestmentType?> _buildCategoryFilters(List<Investment> investments) {
    final availableTypes = _availableSupportedTypes(investments);
    availableTypes.sort((a, b) => _getCurrentValueByType(investments, b)
        .compareTo(_getCurrentValueByType(investments, a)));
    return [null, ...availableTypes];
  }

  String _getCategoryLabel(InvestmentType? type) {
    if (type == null) return 'All';
    return _getInvestmentTypeLabel(type);
  }

  double _getCategoryTotalCurrentValue(
      List<Investment> investments, InvestmentType? type) {
    if (type == null) {
      return investments.fold(
          0.0, (sum, inv) => sum + _calculateCurrentValue(inv));
    }
    return _getCurrentValueByType(investments, type);
  }

  List<Investment> _filterByCategory(
      List<Investment> investments, InvestmentType? type) {
    if (type == null) return investments;
    return investments.where((inv) => inv.type == type).toList();
  }

  List<Investment> _filterBySearch(List<Investment> investments) {
    if (_searchQuery.isEmpty) return investments;
    final q = _searchQuery.toLowerCase();
    return investments
        .where((inv) =>
            inv.name.toLowerCase().contains(q) ||
            _getInvestmentTypeLabel(inv.type).toLowerCase().contains(q))
        .toList();
  }

  Widget _buildSearchBar(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: Spacing.lg),
      child: CupertinoSearchTextField(
        controller: _searchController,
        placeholder: 'Search investments',
        backgroundColor: AppStyles.getCardColor(context),
        style: TextStyle(color: AppStyles.getTextColor(context)),
        placeholderStyle: TextStyle(
            color: AppStyles.getSecondaryTextColor(context), fontSize: TypeScale.body),
        onChanged: (v) => setState(() => _searchQuery = v),
      ),
    );
  }

  void _syncSelectedCategory(List<InvestmentType?> categories) {
    final selected = _selectedFilter;
    if (!categories.contains(selected)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _selectedFilter = null;
          _selectedCategoryIndex = 0;
        });
        _categoryPageController.jumpToPage(0);
      });
      return;
    }

    final targetIndex = categories.indexOf(selected);
    if (targetIndex != _selectedCategoryIndex && targetIndex >= 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _selectedCategoryIndex = targetIndex);
        _categoryPageController.jumpToPage(targetIndex);
      });
    }
  }

  Widget _buildCategoryTabs(
    BuildContext context,
    List<Investment> investments,
    List<InvestmentType?> categories,
  ) {
    return SizedBox(
      height: 86,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: Spacing.lg),
        itemCount: categories.length,
        separatorBuilder: (_, __) => SizedBox(width: Spacing.sm),
        itemBuilder: (context, index) {
          final type = categories[index];
          final isSelected = index == _selectedCategoryIndex;
          final label = _getCategoryLabel(type);
          final total = _getCategoryTotalCurrentValue(investments, type);
          final color = type == null
              ? SemanticColors.investments
              : _getInvestmentTypeColor(type);
          return BouncyButton(
            onPressed: () {
              setState(() {
                _selectedCategoryIndex = index;
                _selectedFilter = type;
              });
              _categoryPageController.animateToPage(
                index,
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
              );
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected
                    ? color.withValues(alpha: 0.16)
                    : AppStyles.getCardColor(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? color
                      : AppStyles.getDividerColor(context)
                          .withValues(alpha: 0.4),
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: AppStyles.titleStyle(context).copyWith(fontSize: TypeScale.subhead),
                  ),
                  const SizedBox(height: Spacing.xs),
                  Text(
                    CurrencyFormatter.compact(total),
                    style: TextStyle(
                      fontSize: TypeScale.footnote,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? color
                          : AppStyles.getSecondaryTextColor(context),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// A compact chip showing the currently active sort — tappable to change it.
  Widget _buildActiveSortChip(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: Spacing.lg),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _showSortModal(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: SemanticColors.investments.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: SemanticColors.investments.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(CupertinoIcons.arrow_up_arrow_down,
                      size: 11, color: SemanticColors.investments),
                  const SizedBox(width: 5),
                  Text(
                    _getSortLabel(_sortBy),
                    style: TextStyle(
                      fontSize: TypeScale.caption,
                      fontWeight: FontWeight.w600,
                      color: SemanticColors.investments,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: Spacing.sm),
          GestureDetector(
            onTap: () => setState(() => _sortAscending = !_sortAscending),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: AppStyles.getCardColor(context),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppStyles.getDividerColor(context),
                ),
              ),
              child: Icon(
                _sortAscending
                    ? CupertinoIcons.arrow_up
                    : CupertinoIcons.arrow_down,
                size: 11,
                color: AppStyles.getSecondaryTextColor(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppStyles.getBackground(context),
      navigationBar: CupertinoNavigationBar(
        middle: Text('Investments',
            style: TextStyle(color: AppStyles.getTextColor(context))),
        previousPageTitle: 'Manage',
        backgroundColor: AppStyles.getBackground(context),
        border: null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Sort Icon
            CupertinoButton(
              padding: EdgeInsets.symmetric(horizontal: Spacing.md),
              onPressed: () => _showSortModal(context),
              child: Icon(
                CupertinoIcons.arrow_up_arrow_down,
                size: 20,
                color: SemanticColors.investments,
              ),
            ),
            // Refresh Icon
            CupertinoButton(
              padding: EdgeInsets.symmetric(horizontal: Spacing.md),
              onPressed: _isRefreshingCurrentValues
                  ? null
                  : () => _refreshCurrentValues(context),
              child: _isRefreshingCurrentValues
                  ? CupertinoActivityIndicator(
                      radius: 10, color: SemanticColors.investments)
                  : Icon(
                      CupertinoIcons.arrow_clockwise,
                      size: 20,
                      color: SemanticColors.investments,
                    ),
            ),
            // Ascending/Descending Icon
            CupertinoButton(
              padding: EdgeInsets.symmetric(horizontal: Spacing.md),
              onPressed: () {
                Haptics.light();
                setState(() => _sortAscending = !_sortAscending);
              },
              child: Icon(
                _sortAscending
                    ? CupertinoIcons.arrow_up
                    : CupertinoIcons.arrow_down,
                size: 20,
                color: SemanticColors.investments,
              ),
            ),
          ],
        ),
      ),
      child: Consumer<InvestmentsController>(
        builder: (context, investmentsController, child) {
          final investments = investmentsController.investments;
          final categories = _buildCategoryFilters(investments);
          _syncSelectedCategory(categories);

          // Show skeleton on initial data load
          if (!investmentsController.isLoaded) {
            return const SkeletonListView(itemCount: 6);
          }

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
                      // Compact Summary Section
                      _buildCompactSummary(context, investments),
                      // Asset Allocation Donut Chart
                      _buildAllocationChart(context, investments),
                      _buildCategoryTabs(context, investments, categories),
                      SizedBox(height: Spacing.xs),
                      // Search bar
                      _buildSearchBar(context),
                      SizedBox(height: Spacing.xs),
                      // Active sort indicator chip
                      _buildActiveSortChip(context),
                      SizedBox(height: Spacing.sm),
                      // Investments List with Staggered Animation
                      Expanded(
                        child: PageView.builder(
                          controller: _categoryPageController,
                          itemCount: categories.length,
                          onPageChanged: (index) {
                            setState(() {
                              _selectedCategoryIndex = index;
                              _selectedFilter = categories[index];
                            });
                          },
                          itemBuilder: (context, pageIndex) {
                            final categoryType = categories[pageIndex];
                            final pageInvestments = _sortInvestments(
                                _filterBySearch(_filterByCategory(
                                    investments, categoryType)));

                            if (pageInvestments.isEmpty) {
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      CupertinoIcons.search,
                                      size: 48,
                                      color: AppStyles.getSecondaryTextColor(
                                              context)
                                          .withValues(alpha: 0.5),
                                    ),
                                    SizedBox(height: Spacing.md),
                                    Text(
                                      'No investments found',
                                      style: TextStyle(
                                        color: AppStyles.getSecondaryTextColor(
                                            context),
                                        fontSize: TypeScale.headline,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            final canReorder = categoryType == null &&
                                _sortBy == SortBy.dateAdded;

                            if (canReorder) {
                              return ReorderableListView.builder(
                                padding: EdgeInsets.fromLTRB(
                                    Spacing.lg, 0, Spacing.lg, 100),
                                itemCount: pageInvestments.length,
                                onReorder: (oldIndex, newIndex) {
                                  Haptics.reorder();
                                  _onReorder(oldIndex, newIndex);
                                },
                                proxyDecorator: (child, index, animation) {
                                  return AnimatedBuilder(
                                    animation: animation,
                                    builder: (context, child) =>
                                        Transform.scale(
                                      scale: 1.02,
                                      child: Container(
                                        decoration:
                                            AppStyles.cardDecoration(context),
                                        child: child,
                                      ),
                                    ),
                                    child: child,
                                  );
                                },
                                itemBuilder: (context, index) {
                                  return StaggeredItem(
                                    key: ValueKey(pageInvestments[index].id),
                                    index: index,
                                    child: Container(
                                      margin: EdgeInsets.only(top: Spacing.lg),
                                      child: _buildSlidableInvestmentCard(
                                          pageInvestments[index]),
                                    ),
                                  );
                                },
                              );
                            }

                            return RefreshIndicator(
                              onRefresh: () => _refreshCurrentValues(context),
                              color: SemanticColors.investments,
                              child: ListView.builder(
                                padding: EdgeInsets.fromLTRB(
                                    Spacing.lg, 0, Spacing.lg, 100),
                                itemCount: pageInvestments.length,
                                itemBuilder: (context, index) {
                                  return StaggeredItem(
                                    key: ValueKey(
                                        '${categoryType?.name ?? 'all'}_${pageInvestments[index].id}'),
                                    index: index,
                                    child: Container(
                                      margin: EdgeInsets.only(top: Spacing.lg),
                                      child: _buildSlidableInvestmentCard(
                                          pageInvestments[index]),
                                    ),
                                  );
                                },
                              ),
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

  /// Build a mini allocation donut chart with legend
  Widget _buildAllocationChart(
      BuildContext context, List<Investment> investments) {
    // Aggregate current value by type
    final Map<InvestmentType, double> byType = {};
    for (final inv in investments) {
      final val = _calculateCurrentValue(inv);
      byType[inv.type] = (byType[inv.type] ?? 0) + val;
    }
    final total = byType.values.fold(0.0, (sum, v) => sum + v);
    if (total <= 0) return const SizedBox.shrink();

    final entries = byType.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Padding(
      padding:
          EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.sm),
      child: Container(
        decoration: AppStyles.cardDecoration(context),
        padding: Spacing.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(CupertinoIcons.chart_pie_fill,
                    size: 14, color: SemanticColors.investments),
                const SizedBox(width: 6),
                Text(
                  'Allocation',
                  style: TextStyle(
                    fontSize: TypeScale.footnote,
                    fontWeight: FontWeight.w600,
                    color: AppStyles.getTextColor(context),
                  ),
                ),
              ],
            ),
            SizedBox(height: Spacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 80,
                  height: 80,
                  child: CustomPaint(
                    painter: _DonutChartPainter(
                      slices: entries
                          .map((e) => _DonutSlice(
                                value: e.value / total,
                                color: _getInvestmentTypeColor(e.key),
                              ))
                          .toList(),
                      holeColor: AppStyles.getCardColor(context),
                    ),
                  ),
                ),
                SizedBox(width: Spacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: entries.take(5).map((e) {
                      final pct = (e.value / total * 100);
                      return Padding(
                        padding: EdgeInsets.only(bottom: Spacing.xs),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: _getInvestmentTypeColor(e.key),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _getInvestmentTypeLabel(e.key),
                                style: TextStyle(
                                  fontSize: TypeScale.caption,
                                  color:
                                      AppStyles.getSecondaryTextColor(context),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '${pct.toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontSize: TypeScale.caption,
                                fontWeight: FontWeight.w600,
                                color: _getInvestmentTypeColor(e.key),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactSummary(
      BuildContext context, List<Investment> investments) {
    final ctrl = Provider.of<InvestmentsController>(context, listen: false);
    final lastRefresh = ctrl.lastRefreshedAt;
    String refreshLabel = 'Pull down to refresh';
    if (lastRefresh != null) {
      final diffMins = DateTime.now().difference(lastRefresh).inMinutes;
      refreshLabel =
          diffMins == 0 ? 'Refreshed just now' : 'Refreshed ${diffMins}m ago';
    }

    return Container(
      color: AppStyles.getCardColor(context),
      padding:
          EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.md),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${investments.length} Investment${investments.length == 1 ? '' : 's'}',
                style: TextStyle(
                  fontSize: TypeScale.headline,
                  fontWeight: FontWeight.bold,
                  color: AppStyles.getTextColor(context),
                ),
              ),
              SizedBox(height: Spacing.xs),
              Text(
                refreshLabel,
                style: TextStyle(
                  fontSize: TypeScale.caption,
                  color: AppStyles.getSecondaryTextColor(context),
                ),
              ),
            ],
          ),
          // Current sort indicator
          Container(
            padding: EdgeInsets.symmetric(
                horizontal: Spacing.md, vertical: Spacing.sm),
            decoration: BoxDecoration(
              color: AppStyles.getBackground(context),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _getSortLabel(_sortBy),
              style: TextStyle(
                fontSize: TypeScale.footnote,
                fontWeight: FontWeight.w600,
                color: SemanticColors.investments,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showFilterModal(BuildContext context) {
    final investments =
        Provider.of<InvestmentsController>(context, listen: false).investments;

    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        color: AppStyles.getBackground(context),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top padding to avoid notification panel
            SizedBox(height: Spacing.xxxl + Spacing.xxl),
            // Header
            Container(
              padding: EdgeInsets.all(Spacing.lg),
              decoration: BoxDecoration(
                color: AppStyles.getCardColor(context),
                border: Border(
                  bottom: BorderSide(
                    color: AppStyles.getDividerColor(context),
                    width: 0.5,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Filter by Type',
                    style: TextStyle(
                      fontSize: TypeScale.headline,
                      fontWeight: FontWeight.bold,
                      color: AppStyles.getTextColor(context),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Icon(
                      CupertinoIcons.xmark_circle_fill,
                      color: AppStyles.getSecondaryTextColor(context),
                    ),
                  ),
                ],
              ),
            ),
            // Filter Options
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(Spacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // All option
                    _buildFilterOptionCard(
                      context,
                      'All Investments',
                      _selectedFilter == null,
                      () {
                        setState(() => _selectedFilter = null);
                        Navigator.of(context).pop();
                      },
                    ),
                    SizedBox(height: Spacing.md),
                    // Type options
                    ..._availableSupportedTypes(investments).map((type) {
                      final count =
                          investments.where((inv) => inv.type == type).length;
                      if (count == 0) return SizedBox.shrink();

                      final isSelected = _selectedFilter == type;
                      return Padding(
                        padding: EdgeInsets.only(bottom: Spacing.md),
                        child: _buildFilterOptionCard(
                          context,
                          '${_getInvestmentTypeLabel(type)} ($count)',
                          isSelected,
                          () {
                            setState(() => _selectedFilter = type);
                            Navigator.of(context).pop();
                          },
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            // Bottom padding for safe area
            SizedBox(height: Spacing.lg),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterOptionCard(
    BuildContext context,
    String label,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(Spacing.lg),
        decoration: BoxDecoration(
          color: isSelected
              ? SemanticColors.investments.withValues(alpha: 0.15)
              : AppStyles.getCardColor(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? SemanticColors.investments
                : AppStyles.getDividerColor(context),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: TypeScale.callout,
                fontWeight: FontWeight.w600,
                color: AppStyles.getTextColor(context),
              ),
            ),
            if (isSelected)
              Icon(
                CupertinoIcons.check_mark,
                color: SemanticColors.investments,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  void _showSortModal(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        color: AppStyles.getBackground(context),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top padding to avoid notification panel
            SizedBox(height: Spacing.xxxl + Spacing.xxl),
            // Header
            Container(
              padding: EdgeInsets.all(Spacing.lg),
              decoration: BoxDecoration(
                color: AppStyles.getCardColor(context),
                border: Border(
                  bottom: BorderSide(
                    color: AppStyles.getDividerColor(context),
                    width: 0.5,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Sort By',
                    style: TextStyle(
                      fontSize: TypeScale.headline,
                      fontWeight: FontWeight.bold,
                      color: AppStyles.getTextColor(context),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Icon(
                      CupertinoIcons.xmark_circle_fill,
                      color: AppStyles.getSecondaryTextColor(context),
                    ),
                  ),
                ],
              ),
            ),
            // Sort Options
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(Spacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ...SortBy.values.map((sort) {
                      final isSelected = _sortBy == sort;
                      return Padding(
                        padding: EdgeInsets.only(bottom: Spacing.md),
                        child: _buildSortOptionCard(
                          context,
                          _getSortLabel(sort),
                          isSelected,
                          () {
                            setState(() => _sortBy = sort);
                            Navigator.of(context).pop();
                          },
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            // Bottom padding for safe area
            SizedBox(height: Spacing.lg),
          ],
        ),
      ),
    );
  }

  Widget _buildSortOptionCard(
    BuildContext context,
    String label,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(Spacing.lg),
        decoration: BoxDecoration(
          color: isSelected
              ? SemanticColors.investments.withValues(alpha: 0.15)
              : AppStyles.getCardColor(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? SemanticColors.investments
                : AppStyles.getDividerColor(context),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: TypeScale.callout,
                fontWeight: FontWeight.w600,
                color: AppStyles.getTextColor(context),
              ),
            ),
            if (isSelected)
              Icon(
                CupertinoIcons.check_mark,
                color: SemanticColors.investments,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfessionalHeader(BuildContext context,
      List<Investment> investments, List<Investment> sortedInvestments) {
    return Container(
      color: AppStyles.getCardColor(context),
      padding: EdgeInsets.all(Spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary Row with Order Toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${investments.length} Investments',
                    style: TextStyle(
                      fontSize: TypeScale.headline,
                      fontWeight: FontWeight.bold,
                      color: AppStyles.getTextColor(context),
                    ),
                  ),
                  SizedBox(height: Spacing.xs),
                  Text(
                    '${_getDistinctTypesCount(investments)} categories',
                    style: TextStyle(
                      fontSize: TypeScale.subhead,
                      color: AppStyles.getSecondaryTextColor(context),
                    ),
                  ),
                ],
              ),
              // Order Toggle Button (More Visible)
              GestureDetector(
                onTap: () {
                  Haptics.light();
                  setState(() => _sortAscending = !_sortAscending);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: EdgeInsets.symmetric(
                      horizontal: Spacing.md, vertical: Spacing.sm),
                  decoration: BoxDecoration(
                    color: AppStyles.getBackground(context),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: SemanticColors.investments.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _sortAscending
                            ? CupertinoIcons.arrow_up
                            : CupertinoIcons.arrow_down,
                        size: 14,
                        color: SemanticColors.investments,
                      ),
                      SizedBox(width: Spacing.xs),
                      Text(
                        _sortAscending ? 'Ascending' : 'Descending',
                        style: TextStyle(
                          fontSize: TypeScale.footnote,
                          fontWeight: FontWeight.bold,
                          color: SemanticColors.investments,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: Spacing.lg),
          // Filter Chips
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Filter',
                style: TextStyle(
                  fontSize: TypeScale.footnote,
                  fontWeight: FontWeight.w600,
                  color: AppStyles.getSecondaryTextColor(context),
                  letterSpacing: 0.5,
                ),
              ),
              SizedBox(height: Spacing.sm),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.zero,
                child: Row(
                  children: [
                    // All chip
                    GestureDetector(
                      onTap: () {
                        Haptics.selection();
                        setState(() => _selectedFilter = null);
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: Spacing.md, vertical: Spacing.sm),
                        margin: EdgeInsets.only(right: Spacing.md),
                        decoration: BoxDecoration(
                          color: _selectedFilter == null
                              ? SemanticColors.investments
                              : AppStyles.getBackground(context),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _selectedFilter == null
                                ? SemanticColors.investments
                                : AppStyles.getSecondaryTextColor(context)
                                    .withValues(alpha: 0.2),
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          'All',
                          style: TextStyle(
                            fontSize: TypeScale.subhead,
                            fontWeight: FontWeight.w600,
                            color: _selectedFilter == null
                                ? Colors.white
                                : AppStyles.getTextColor(context),
                          ),
                        ),
                      ),
                    ),
                    // Type chips
                    ..._availableSupportedTypes(investments).map((type) {
                      final count =
                          investments.where((inv) => inv.type == type).length;
                      if (count == 0) return SizedBox.shrink();

                      final isSelected = _selectedFilter == type;
                      return GestureDetector(
                        onTap: () {
                          Haptics.selection();
                          setState(() => _selectedFilter = type);
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: Spacing.md, vertical: Spacing.sm),
                          margin: EdgeInsets.only(right: Spacing.md),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? SemanticColors.investments
                                : AppStyles.getBackground(context),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected
                                  ? SemanticColors.investments
                                  : AppStyles.getSecondaryTextColor(context)
                                      .withValues(alpha: 0.2),
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              Text(
                                _getInvestmentTypeLabel(type),
                                style: TextStyle(
                                  fontSize: TypeScale.subhead,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected
                                      ? Colors.white
                                      : AppStyles.getTextColor(context),
                                ),
                              ),
                              SizedBox(width: Spacing.xs),
                              Text(
                                '($count)',
                                style: TextStyle(
                                  fontSize: TypeScale.footnote,
                                  fontWeight: FontWeight.w500,
                                  color: isSelected
                                      ? Colors.white.withValues(alpha: 0.8)
                                      : AppStyles.getSecondaryTextColor(
                                          context),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: Spacing.lg),
          // Sort Options
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sort By',
                style: TextStyle(
                  fontSize: TypeScale.footnote,
                  fontWeight: FontWeight.w600,
                  color: AppStyles.getSecondaryTextColor(context),
                  letterSpacing: 0.5,
                ),
              ),
              SizedBox(height: Spacing.sm),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.zero,
                child: Row(
                  children: [
                    ...SortBy.values.map((sort) {
                      final isSelected = _sortBy == sort;
                      return GestureDetector(
                        onTap: () {
                          Haptics.selection();
                          setState(() => _sortBy = sort);
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: Spacing.md, vertical: Spacing.sm),
                          margin: EdgeInsets.only(right: Spacing.md),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? SemanticColors.investments
                                    .withValues(alpha: 0.15)
                                : AppStyles.getBackground(context),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected
                                  ? SemanticColors.investments
                                  : AppStyles.getSecondaryTextColor(context)
                                      .withValues(alpha: 0.2),
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            _getSortLabel(sort),
                            style: TextStyle(
                              fontSize: TypeScale.subhead,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? SemanticColors.investments
                                  : AppStyles.getSecondaryTextColor(context),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        ],
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
          padding: EdgeInsets.symmetric(
              horizontal: Spacing.lg, vertical: Spacing.md),
          child: Text(
            'Filter by Type',
            style: TextStyle(
              color: AppStyles.getTextColor(context),
              fontWeight: FontWeight.w600,
              fontSize: TypeScale.body,
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
                  padding: EdgeInsets.symmetric(
                      horizontal: Spacing.lg, vertical: Spacing.sm),
                  decoration: BoxDecoration(
                    color: _selectedFilter == null
                        ? SemanticColors.investments
                        : AppStyles.getCardColor(context),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _selectedFilter == null
                          ? SemanticColors.investments
                          : AppStyles.getSecondaryTextColor(context)
                              .withValues(alpha: 0.2),
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
                      fontSize: TypeScale.subhead,
                    ),
                  ),
                ),
              ),
              SizedBox(width: Spacing.md),
              // Investment type filters
              ...investmentTypes.map((type) {
                final count =
                    investments.where((inv) => inv.type == type).length;
                final isSelected = _selectedFilter == type;

                return Padding(
                  padding: EdgeInsets.only(right: Spacing.md),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedFilter = type),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: Spacing.lg, vertical: Spacing.sm),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? SemanticColors.investments
                            : AppStyles.getCardColor(context),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? SemanticColors.investments
                              : AppStyles.getSecondaryTextColor(context)
                                  .withValues(alpha: 0.2),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _getInvestmentTypeLabel(type),
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : AppStyles.getTextColor(context),
                              fontWeight: FontWeight.w600,
                              fontSize: TypeScale.subhead,
                            ),
                          ),
                          if (count > 0)
                            Text(
                              '($count)',
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white.withValues(alpha: 0.8)
                                    : AppStyles.getSecondaryTextColor(context),
                                fontSize: TypeScale.caption,
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

  Widget _buildSortBar(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
              horizontal: Spacing.lg, vertical: Spacing.md),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Sort By',
                style: TextStyle(
                  color: AppStyles.getTextColor(context),
                  fontWeight: FontWeight.w600,
                  fontSize: TypeScale.body,
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _sortAscending = !_sortAscending),
                child: Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: Spacing.md, vertical: Spacing.xs),
                  decoration: BoxDecoration(
                    color: AppStyles.getCardColor(context),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppStyles.getSecondaryTextColor(context)
                          .withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _sortAscending
                            ? CupertinoIcons.arrow_up
                            : CupertinoIcons.arrow_down,
                        size: 14,
                        color: AppStyles.getSecondaryTextColor(context),
                      ),
                      SizedBox(width: Spacing.xs),
                      Text(
                        _sortAscending ? 'Ascending' : 'Descending',
                        style: TextStyle(
                          color: AppStyles.getSecondaryTextColor(context),
                          fontSize: TypeScale.footnote,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: Spacing.lg),
          child: Row(
            children: [
              ..._buildSortOptions(context),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildSortOptions(BuildContext context) {
    return SortBy.values.map((sort) {
      final isSelected = _sortBy == sort;
      return Padding(
        padding: EdgeInsets.only(right: Spacing.md),
        child: GestureDetector(
          onTap: () => setState(() => _sortBy = sort),
          child: Container(
            padding: EdgeInsets.symmetric(
                horizontal: Spacing.lg, vertical: Spacing.sm),
            decoration: BoxDecoration(
              color: isSelected
                  ? SemanticColors.investments
                  : AppStyles.getCardColor(context),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? SemanticColors.investments
                    : AppStyles.getSecondaryTextColor(context)
                        .withValues(alpha: 0.2),
                width: 1.5,
              ),
            ),
            child: Text(
              _getSortLabel(sort),
              style: TextStyle(
                color:
                    isSelected ? Colors.white : AppStyles.getTextColor(context),
                fontWeight: FontWeight.w600,
                fontSize: TypeScale.subhead,
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  int _getDistinctTypesCount(List<Investment> investments) {
    return investments.map((inv) => inv.type).toSet().length;
  }

  List<Investment> _getInvestmentsByType(
      List<Investment> investments, InvestmentType type) {
    return investments.where((inv) => inv.type == type).toList();
  }

  double _getTotalByType(List<Investment> investments, InvestmentType type) {
    return _getInvestmentsByType(investments, type)
        .fold(0.0, (sum, inv) => sum + inv.amount);
  }

  double _getCurrentValueByType(
      List<Investment> investments, InvestmentType type) {
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

  Widget _buildInvestmentTypeSummaryCards(
      BuildContext context, List<Investment> investments) {
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

    final availableTypes = typesToShow
        .where((type) => _hasInvestmentType(investments, type))
        .toList();

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
                              fontSize: TypeScale.footnote,
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
                        if (i < availableTypes.length - 1)
                          SizedBox(width: Spacing.lg),
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
                    padding: const EdgeInsets.all(Spacing.sm),
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
                  const SizedBox(width: Spacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          typeLabel,
                          style: AppStyles.titleStyle(context)
                              .copyWith(fontSize: TypeScale.body),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '$count ${count == 1 ? 'investment' : 'investments'}',
                          style: TextStyle(
                            fontSize: TypeScale.footnote,
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
                  fontSize: TypeScale.footnote,
                  color: AppStyles.getSecondaryTextColor(context),
                ),
              ),
              const SizedBox(height: Spacing.xxs),
              AnimatedCounter(
                value: invested,
                prefix: '₹',
                decimals: 2,
                duration: AppDurations.counter,
                style: TextStyle(
                  fontSize: TypeScale.headline,
                  color: AppStyles.getTextColor(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: Spacing.md),

              // Current Value
              Text(
                'Current Value',
                style: TextStyle(
                  fontSize: TypeScale.footnote,
                  color: AppStyles.getSecondaryTextColor(context),
                ),
              ),
              const SizedBox(height: Spacing.xxs),
              AnimatedCounter(
                value: currentValue,
                prefix: '₹',
                decimals: 2,
                duration: AppDurations.counter,
                style: TextStyle(
                  fontSize: TypeScale.headline,
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
                            fontSize: TypeScale.caption,
                            color: AppStyles.getSecondaryTextColor(context),
                          ),
                        ),
                        const SizedBox(height: Spacing.xxs),
                        AnimatedCounter(
                          value: gainLoss.abs(),
                          prefix: isPositive ? '+₹' : '-₹',
                          decimals: 2,
                          duration: AppDurations.counter,
                          style: TextStyle(
                            fontSize: TypeScale.subhead,
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
                            fontSize: TypeScale.caption,
                            color: AppStyles.getSecondaryTextColor(context),
                          ),
                        ),
                        const SizedBox(height: Spacing.xxs),
                        Text(
                          '${gainLossPercent.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: TypeScale.subhead,
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

  /// Build investment card for digital gold with real-time price fetching
  Widget _buildDigitalGoldInvestmentCard(Investment investment) {
    final investedAmount = investment.amount;
    final metadata = investment.metadata ?? {};
    final weightInGrams = (metadata['weightInGrams'] as num?)?.toDouble() ?? 0;

    return FutureBuilder<double?>(
      future: _getCurrentGoldPrice(),
      builder: (context, snapshot) {
        double currentValue = 0;
        double currentRate = 0;

        if (snapshot.hasData && snapshot.data != null) {
          currentRate = snapshot.data!;
          currentValue = weightInGrams * currentRate;
        } else if (snapshot.hasError) {
          // Use stored value as fallback
          currentValue = (metadata['currentValue'] as num?)?.toDouble() ?? 0;
          currentRate = (metadata['currentRate'] as num?)?.toDouble() ?? 0;
        }

        final gainLoss = currentValue - investedAmount;
        final gainLossPercent =
            investedAmount > 0 ? (gainLoss / investedAmount) * 100 : 0;
        final isProfit = gainLoss >= 0;

        return Hero(
          tag: 'investment_${investment.id}',
          child: BouncyButton(
            onPressed: () {
              Haptics.light();
              Navigator.of(context).push(
                CupertinoPageRoute(
                  builder: (context) =>
                      DigitalGoldDetailsScreen(investment: investment),
                ),
              );
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
                          Text(investment.name,
                              style: AppStyles.titleStyle(context)),
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
                                        fontSize: TypeScale.caption,
                                        color: AppStyles.getSecondaryTextColor(
                                            context),
                                      ),
                                    ),
                                    Text(
                                      '₹${investedAmount.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: TypeScale.subhead,
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
                                        fontSize: TypeScale.caption,
                                        color: AppStyles.getSecondaryTextColor(
                                            context),
                                      ),
                                    ),
                                    if (snapshot.connectionState ==
                                        ConnectionState.waiting)
                                      Text(
                                        'Fetching...',
                                        style: TextStyle(
                                          fontSize: TypeScale.subhead,
                                          fontWeight: FontWeight.w600,
                                          color:
                                              AppStyles.getSecondaryTextColor(
                                                  context),
                                        ),
                                      )
                                    else
                                      Text(
                                        '₹${currentValue.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontSize: TypeScale.subhead,
                                          fontWeight: FontWeight.w600,
                                          color:
                                              AppStyles.getTextColor(context),
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
                          padding: EdgeInsets.symmetric(
                              horizontal: Spacing.md, vertical: Spacing.xs),
                          decoration: BoxDecoration(
                            color: isProfit
                                ? CupertinoColors.systemGreen
                                    .withValues(alpha: 0.15)
                                : CupertinoColors.systemRed
                                    .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${isProfit ? '+' : ''}${gainLossPercent.toStringAsFixed(2)}%',
                            style: TextStyle(
                              fontSize: TypeScale.subhead,
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
      },
    );
  }

  void _deleteInvestmentWithConfirmation(Investment investment) {
    Haptics.warning();
    showCupertinoDialog<void>(
      context: context,
      builder: (dialogCtx) => CupertinoAlertDialog(
        title: const Text('Delete Investment'),
        content:
            Text('Delete "${investment.name}"? This action cannot be undone.'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(dialogCtx),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Delete'),
            onPressed: () {
              Haptics.delete();
              final ctrl =
                  Provider.of<InvestmentsController>(context, listen: false);
              ctrl.removeInvestment(investment.id);
              Navigator.pop(dialogCtx);
              toast.showSuccess(
                '"${investment.name}" deleted',
                actionLabel: 'Undo',
                onAction: () {
                  ctrl.addInvestment(investment);
                  toast.showInfo('Investment restored');
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSlidableInvestmentCard(Investment investment) {
    return Slidable(
      key: ValueKey('slidable_${investment.id}'),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.22,
        children: [
          SlidableAction(
            onPressed: (_) => _deleteInvestmentWithConfirmation(investment),
            backgroundColor: CupertinoColors.systemRed,
            foregroundColor: Colors.white,
            icon: CupertinoIcons.delete,
            label: 'Delete',
            borderRadius: BorderRadius.circular(12),
          ),
        ],
      ),
      child: _buildInvestmentCard(investment),
    );
  }

  Widget _buildInvestmentCard(Investment investment) {
    // For digital gold, use async fetching with FutureBuilder
    if (investment.type == InvestmentType.digitalGold) {
      return _buildDigitalGoldInvestmentCard(investment);
    }

    // Calculate values for other types
    final investedAmount = investment.amount;
    final currentValue = _calculateCurrentValue(investment);
    final gainLoss = currentValue - investedAmount;
    final gainLossPercent =
        investedAmount > 0 ? (gainLoss / investedAmount) * 100 : 0;
    final isProfit = gainLoss >= 0;

    return Hero(
      tag: 'investment_${investment.id}',
      child: BouncyButton(
        onPressed: () {
          Haptics.light();
          // Navigate to details screen based on investment type
          if (investment.type == InvestmentType.stocks) {
            Navigator.of(context).push(
              CupertinoPageRoute(
                builder: (context) =>
                    StockDetailsScreen(investment: investment),
              ),
            );
          } else if (investment.type == InvestmentType.mutualFund) {
            Navigator.of(context).push(
              CupertinoPageRoute(
                builder: (context) => MFDetailsScreen(investment: investment),
              ),
            );
          } else if (investment.type == InvestmentType.fixedDeposit) {
            // Reconstruct FD from investment metadata
            if (investment.metadata != null &&
                investment.metadata!.containsKey('fdData')) {
              try {
                final fdData =
                    investment.metadata!['fdData'] as Map<String, dynamic>;
                final fd = FixedDeposit.fromMap(fdData);
                Navigator.of(context).push(
                  CupertinoPageRoute(
                    builder: (context) => FDDetailsScreen(fd: fd),
                  ),
                );
              } catch (e) {
                toast.showError('Error loading FD details');
              }
            } else {
              toast.showInfo('FD data not available');
            }
          } else if (investment.type == InvestmentType.recurringDeposit) {
            // Reconstruct RD from investment metadata
            if (investment.metadata != null &&
                investment.metadata!.containsKey('rdData')) {
              try {
                final rdData =
                    investment.metadata!['rdData'] as Map<String, dynamic>;
                final rd = RecurringDeposit.fromMap(rdData);
                Navigator.of(context).push(
                  CupertinoPageRoute(
                    builder: (context) => RDDetailsScreen(rd: rd),
                  ),
                );
              } catch (e) {
                toast.showError('Error loading RD details');
              }
            } else {
              toast.showInfo('RD data not available');
            }
          } else if (investment.type == InvestmentType.bonds) {
            Navigator.of(context).push(
              CupertinoPageRoute(
                builder: (context) =>
                    BondsDetailsScreen(investment: investment),
              ),
            );
          } else if (investment.type == InvestmentType.cryptocurrency) {
            Navigator.of(context).push(
              CupertinoPageRoute(
                builder: (context) =>
                    CryptoDetailsScreen(investment: investment),
              ),
            );
          } else if (investment.type == InvestmentType.digitalGold) {
            Navigator.of(context).push(
              CupertinoPageRoute(
                builder: (context) =>
                    DigitalGoldDetailsScreen(investment: investment),
              ),
            );
          } else if (investment.type == InvestmentType.nationalSavingsScheme) {
            Navigator.of(context).push(
              CupertinoPageRoute(
                builder: (context) => NPSDetailsScreen(investment: investment),
              ),
            );
          } else if (investment.type == InvestmentType.pensionSchemes) {
            Navigator.of(context).push(
              CupertinoPageRoute(
                builder: (context) =>
                    PensionDetailsScreen(investment: investment),
              ),
            );
          } else if (investment.type == InvestmentType.commodities) {
            Navigator.of(context).push(
              CupertinoPageRoute(
                builder: (context) =>
                    CommoditiesDetailsScreen(investment: investment),
              ),
            );
          } else if (investment.type == InvestmentType.futuresOptions) {
            Navigator.of(context).push(
              CupertinoPageRoute(
                builder: (context) => FODetailsScreen(investment: investment),
              ),
            );
          } else {
            toast.showInfo(
                'Details for ${investment.getTypeLabel()} coming soon!');
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
                      Text(investment.name,
                          style: AppStyles.titleStyle(context)),
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
                                    fontSize: TypeScale.caption,
                                    color: AppStyles.getSecondaryTextColor(
                                        context),
                                  ),
                                ),
                                Text(
                                  '₹${investedAmount.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: TypeScale.subhead,
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
                                    fontSize: TypeScale.caption,
                                    color: AppStyles.getSecondaryTextColor(
                                        context),
                                  ),
                                ),
                                Text(
                                  '₹${currentValue.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: TypeScale.subhead,
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
                      padding: EdgeInsets.symmetric(
                          horizontal: Spacing.md, vertical: Spacing.xs),
                      decoration: BoxDecoration(
                        color: isProfit
                            ? CupertinoColors.systemGreen
                                .withValues(alpha: 0.15)
                            : CupertinoColors.systemRed.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${isProfit ? '+' : ''}${gainLossPercent.toStringAsFixed(2)}%',
                        style: TextStyle(
                          fontSize: TypeScale.subhead,
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
}

// ── Donut chart helpers ──────────────────────────────────────────────────────

class _DonutSlice {
  final double value; // 0.0–1.0 fraction
  final Color color;
  const _DonutSlice({required this.value, required this.color});
}

class _DonutChartPainter extends CustomPainter {
  final List<_DonutSlice> slices;
  final Color holeColor;
  _DonutChartPainter({required this.slices, this.holeColor = Colors.black});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2;
    const holeRatio = 0.55;
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    double startAngle = -pi / 2;
    for (final slice in slices) {
      final sweepAngle = slice.value * 2 * pi;
      paint.color = slice.color;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        paint,
      );
      startAngle += sweepAngle;
    }

    // Draw hole
    paint.color = slices.isEmpty ? Colors.transparent : holeColor;
    canvas.drawCircle(center, radius * holeRatio, paint);
  }

  @override
  bool shouldRepaint(_DonutChartPainter oldDelegate) =>
      oldDelegate.slices != slices || oldDelegate.holeColor != holeColor;
}
