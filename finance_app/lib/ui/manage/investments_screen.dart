import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:vittara_fin_os/ui/manage/mf/mf_wizard_controller.dart';
import 'package:vittara_fin_os/models/mutual_fund_model.dart';
import 'package:vittara_fin_os/ui/manage/mf/mf_details_screen.dart';
import 'package:vittara_fin_os/ui/manage/fd/fd_details_screen.dart';
import 'package:vittara_fin_os/ui/manage/rd/rd_details_screen.dart';
import 'package:vittara_fin_os/ui/manage/bonds/bonds_details_screen.dart';
import 'package:vittara_fin_os/ui/manage/cryptocurrency/crypto_details_screen.dart';
import 'package:vittara_fin_os/ui/manage/digital_gold/digital_gold_wizard.dart';
import 'package:vittara_fin_os/ui/manage/digital_gold/digital_gold_details_screen.dart';
import 'package:vittara_fin_os/ui/manage/nps/nps_details_screen.dart';
import 'package:vittara_fin_os/ui/manage/pension/pension_details_screen.dart';
import 'package:vittara_fin_os/ui/manage/pension/pension_wizard.dart';
import 'package:vittara_fin_os/ui/manage/commodities/commodities_details_screen.dart';
import 'package:vittara_fin_os/ui/manage/commodities/commodities_wizard.dart';
import 'package:vittara_fin_os/ui/manage/fo/fo_details_screen.dart';
import 'package:vittara_fin_os/ui/manage/fo/fo_wizard.dart';
import 'package:vittara_fin_os/ui/manage/fd/fd_wizard_screen.dart';
import 'package:vittara_fin_os/ui/manage/rd/rd_wizard_screen.dart';
import 'package:vittara_fin_os/ui/manage/cryptocurrency/crypto_wizard.dart';
import 'package:vittara_fin_os/ui/manage/investments/simple_investment_details_screen.dart';
import 'package:vittara_fin_os/ui/manage/simple_investment_entry_wizard.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/widgets/animations.dart';
import 'package:vittara_fin_os/ui/widgets/common_widgets.dart';
import 'package:vittara_fin_os/ui/widgets/landscape_split_view.dart';
import 'package:vittara_fin_os/ui/widgets/toast_notification.dart';
import 'package:vittara_fin_os/utils/logger.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:vittara_fin_os/services/investment_value_service.dart';
import 'package:vittara_fin_os/utils/date_formatter.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  // AU1-05 — persist search across navigation
  static String _persistedSearchQuery = '';

  static const List<InvestmentType> _supportedInvestmentTypes = [
    InvestmentType.stocks,
    InvestmentType.mutualFund,
    InvestmentType.fixedDeposit,
    InvestmentType.recurringDeposit,
    InvestmentType.digitalGold,
    InvestmentType.nationalSavingsScheme,
    InvestmentType.bonds,
    InvestmentType.pensionSchemes,
    InvestmentType.cryptocurrency,
    InvestmentType.futuresOptions,
    InvestmentType.commodities,
    InvestmentType.forexCurrency,
  ];

  final AppLogger logger = AppLogger();
  bool _isSummaryExpanded = true;
  bool _isPnLExpanded = false; // P&L row collapsed by default to save space
  bool _isAllocationExpanded = false; // Allocation collapsed by default
  InvestmentType? _selectedFilter; // null = All investments
  // initialPage is set in initState using _selectedCategoryIndex so a rebuild
  // after an orientation change restores the correct tab, not tab 0.
  late PageController _categoryPageController;
  int _selectedCategoryIndex = 0;

  // Sort options
  SortBy _sortBy = SortBy.currentAmount;
  bool _sortAscending = false; // true = ascending, false = descending

  // Memoized filter+sort cache — avoids redundant work on every build
  final Map<String, List<Investment>> _filterSortCache = {};
  String _lastFilterSortKey = '';

  // Search — AU1-05: persisted across navigation via static field
  String _searchQuery = '';
  late final TextEditingController _searchController;

  final InvestmentValueService _valueService = InvestmentValueService();
  bool _isRefreshingCurrentValues = false;

  // Cache for current gold price (shared across all digital gold cards)
  double? _cachedGoldPrice;
  Future<double?>? _goldPriceFuture;

  // Scroll-to-top FAB
  final ScrollController _scrollController = ScrollController();
  bool _showScrollToTop = false;

  // Category tab strip scroll controller — used to keep active tab visible.
  // Tab positions (measured via GlobalKeys) are stored in _tabPositions so
  // the strip can track the PageView continuously during drag, not just on snap.
  final ScrollController _tabStripController = ScrollController();
  final List<GlobalKey> _tabKeys = [];
  final List<double> _tabOffsets = []; // scroll offset for each tab to be centred

  static const _prefKeySortBy = 'inv_sort';
  static const _prefKeySortAsc = 'inv_sort_asc';

  // AU4-02 — Cached prefs instance; avoids repeated getInstance() calls
  SharedPreferences? _prefs;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Attach listener once — clear cache whenever InvestmentsController notifies
    // (handles middle-item edits where first/last IDs don't change)
    final ctrl =
        Provider.of<InvestmentsController>(context, listen: false);
    ctrl.removeListener(_onInvestmentsChanged); // guard against double-attach
    ctrl.addListener(_onInvestmentsChanged);
  }

  void _onInvestmentsChanged() {
    if (mounted) setState(() => _filterSortCache.clear());
  }

  @override
  void initState() {
    super.initState();
    _searchQuery = _persistedSearchQuery;
    _searchController = TextEditingController(text: _persistedSearchQuery);
    _categoryPageController = PageController(initialPage: _selectedCategoryIndex);
    // Continuously sync header strip while user drags the PageView.
    // .page is a double (e.g. 1.4) during drag — interpolating between
    // adjacent tab offsets gives frame-synchronous header tracking.
    _categoryPageController.addListener(_syncTabStripOnDrag);
    _loadSortPrefs();
    _scrollController.addListener(_onScroll);
    // Initialise once so FutureBuilder always gets the same Future instance
    // (creating a new Future on every build resets FutureBuilder to loading)
    _goldPriceFuture = _getCurrentGoldPrice();
    // Silent background refresh — no spinner, no toast. The controller's
    // notifyListeners() will update the UI when values arrive.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctrl = Provider.of<InvestmentsController>(context, listen: false);
      ctrl.refreshCurrentValues(_valueService).ignore();
    });
  }

  void _onScroll() {
    final show = _scrollController.offset > 400;
    if (show != _showScrollToTop) {
      setState(() => _showScrollToTop = show);
    }
  }

  Future<void> _loadSortPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _sortBy = SortBy.values.firstWhere(
        (e) => e.name == (_prefs!.getString(_prefKeySortBy) ?? ''),
        orElse: () => SortBy.currentAmount,
      );
      _sortAscending = _prefs!.getBool(_prefKeySortAsc) ?? false;
    });
  }

  Future<void> _saveSortPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setString(_prefKeySortBy, _sortBy.name);
    await _prefs!.setBool(_prefKeySortAsc, _sortAscending);
  }

  @override
  void dispose() {
    final ctrl = Provider.of<InvestmentsController>(context, listen: false);
    ctrl.removeListener(_onInvestmentsChanged);
    _categoryPageController.removeListener(_syncTabStripOnDrag);
    _categoryPageController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    _tabStripController.dispose();
    super.dispose();
  }

  // ── Tab strip continuous sync ─────────────────────────────────────────────

  /// Called every frame while the PageView is being dragged.
  /// Interpolates between measured tab offsets so the header strip tracks
  /// content in real-time rather than only jumping at page snap boundaries.
  void _syncTabStripOnDrag() {
    if (!_categoryPageController.hasClients) return;
    if (!_tabStripController.hasClients) return;
    if (_tabOffsets.isEmpty) return;

    final page = _categoryPageController.page ?? _selectedCategoryIndex.toDouble();
    final lo = page.floor().clamp(0, _tabOffsets.length - 1);
    final hi = page.ceil().clamp(0, _tabOffsets.length - 1);
    final t = page - page.floor(); // fractional part [0.0, 1.0]

    final offset = lo == hi
        ? _tabOffsets[lo]
        : _tabOffsets[lo] + (_tabOffsets[hi] - _tabOffsets[lo]) * t;

    _tabStripController.jumpTo(
      offset.clamp(0.0, _tabStripController.position.maxScrollExtent),
    );
  }

  /// Measures each tab pill's rendered position and computes the scroll offset
  /// that centres that tab in the strip viewport.
  /// Called once after the first build when tabs are rendered.
  void _measureTabOffsets() {
    if (!_tabStripController.hasClients) return;
    final stripWidth = _tabStripController.position.viewportDimension;
    _tabOffsets.clear();
    for (final key in _tabKeys) {
      final ctx = key.currentContext;
      if (ctx == null) {
        _tabOffsets.add(0);
        continue;
      }
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null) {
        _tabOffsets.add(0);
        continue;
      }
      // Position of the tab relative to the strip's scroll content
      final tabStart = box.localToGlobal(Offset.zero).dx +
          _tabStripController.position.pixels -
          // Adjust for the strip's own screen position
          (_tabStripController.position.viewportDimension > 0
              ? 0
              : 0);
      final tabWidth = box.size.width;
      final centred = tabStart - (stripWidth / 2) + (tabWidth / 2);
      _tabOffsets.add(centred.clamp(
        0.0,
        _tabStripController.position.maxScrollExtent,
      ));
    }
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

  /// Returns filtered + sorted investments for the given category tab.
  /// Memoized: recomputes only when source list, filters, or sort settings change.
  List<Investment> _getFilteredSorted(
      List<Investment> all, InvestmentType? categoryType) {
    final key = [
      all.length,
      all.isEmpty ? '' : all.first.id,
      all.isEmpty ? '' : all.last.id,
      categoryType?.index ?? -1,
      _searchQuery,
      _sortBy.index,
      _sortAscending ? 1 : 0,
    ].join('|');

    if (_filterSortCache.containsKey(key)) return _filterSortCache[key]!;

    // Evict stale entries when source list changes (different first/last key prefix)
    if (_lastFilterSortKey != key) {
      _filterSortCache.clear();
      _lastFilterSortKey = key;
    }

    final active = all.where((inv) {
      if (inv.type != InvestmentType.fixedDeposit) return true;
      final fdData = inv.metadata?['fdData'];
      if (fdData is! Map) return true;
      final statusIndex = (fdData['status'] as num?)?.toInt() ?? 0;
      return statusIndex != FDStatus.prematurelyWithdrawn.index &&
          statusIndex != FDStatus.completed.index;
    }).toList();
    final filtered = _filterBySearch(_filterByCategory(active, categoryType));
    final sorted = List<Investment>.from(filtered)
      ..sort((a, b) {
        int comparison = 0;
        switch (_sortBy) {
          case SortBy.currentAmount:
            comparison =
                _calculateCurrentValue(a).compareTo(_calculateCurrentValue(b));
            break;
          case SortBy.investedAmount:
            comparison = a.amount.compareTo(b.amount);
            break;
          case SortBy.gainPercent:
            comparison = _calculateGainLossPercent(a)
                .compareTo(_calculateGainLossPercent(b));
            break;
          case SortBy.gainAmount:
            comparison = (_calculateCurrentValue(a) - a.amount)
                .compareTo(_calculateCurrentValue(b) - b.amount);
            break;
          case SortBy.name:
            comparison = a.name.compareTo(b.name);
            break;
          case SortBy.type:
            comparison = a.type.index.compareTo(b.type.index);
            break;
          case SortBy.dateAdded:
            comparison = a.id.compareTo(b.id);
            break;
        }
        return _sortAscending ? comparison : -comparison;
      });

    _filterSortCache[key] = sorted;
    return sorted;
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
                return (metadata['maturityValue'] as num?)?.toDouble() ??
                    investment.amount;
              }
              if (metadata.containsKey('estimatedAccruedValue')) {
                return (metadata['estimatedAccruedValue'] as num?)?.toDouble() ??
                    investment.amount;
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
          return (metadata['estimatedAccruedValue'] as num?)?.toDouble() ??
              investment.amount;
        }
      }

      // Check for estimatedAccruedValue (stocks, other investments)
      if (!isFdOrRd &&
          metadata.containsKey('currentValue') &&
          metadata['currentValue'] != 0) {
        return (metadata['currentValue'] as num?)?.toDouble() ??
            investment.amount;
      }

      if (metadata.containsKey('estimatedAccruedValue')) {
        return (metadata['estimatedAccruedValue'] as num?)?.toDouble() ??
            investment.amount;
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
        onTypeSelected: (investmentType) async {
          logger.info('Selected investment type: ${investmentType.name}',
              context: 'InvestmentsScreen');

          if (investmentType == InvestmentType.stocks) {
            await Navigator.of(context).push(
              FadeScalePageRoute(page: const StocksWizard()),
            );
          } else if (investmentType == InvestmentType.mutualFund) {
            await Navigator.of(context).push(
              FadeScalePageRoute(page: const MFWizard()),
            );
          } else if (investmentType == InvestmentType.fixedDeposit) {
            await Navigator.of(context).push(
              FadeScalePageRoute(page: const FDWizardScreen()),
            );
          } else if (investmentType == InvestmentType.recurringDeposit) {
            await Navigator.of(context).push(
              FadeScalePageRoute(page: const RDWizardScreen()),
            );
          } else if (investmentType == InvestmentType.digitalGold) {
            await Navigator.of(context).push(
              FadeScalePageRoute(page: const DigitalGoldWizard()),
            );
          } else if (investmentType == InvestmentType.nationalSavingsScheme) {
            await Navigator.of(context).push(
              FadeScalePageRoute(
                page: const SimpleInvestmentEntryWizard(
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
            await Navigator.of(context).push(
              FadeScalePageRoute(
                page: const SimpleInvestmentEntryWizard(
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
          } else if (investmentType == InvestmentType.pensionSchemes) {
            await Navigator.of(context).push(
              FadeScalePageRoute(page: const PensionWizard()),
            );
          } else if (investmentType == InvestmentType.cryptocurrency) {
            await Navigator.of(context).push(
              FadeScalePageRoute(page: const CryptoWizard()),
            );
          } else if (investmentType == InvestmentType.futuresOptions) {
            await Navigator.of(context).push(
              FadeScalePageRoute(page: const FOWizard()),
            );
          } else if (investmentType == InvestmentType.commodities) {
            await Navigator.of(context).push(
              FadeScalePageRoute(page: const CommoditiesWizard()),
            );
          } else if (investmentType == InvestmentType.forexCurrency) {
            await Navigator.of(context).push(
              FadeScalePageRoute(
                page: const SimpleInvestmentEntryWizard(
                  type: InvestmentType.forexCurrency,
                  title: 'Add Forex',
                  subtitle: 'Track foreign currency positions.',
                  color: Color(0xFF34495E),
                  defaultName: 'Forex Position',
                ),
              ),
            );
          }
          // Reload list after any wizard completes
          if (mounted) {
            await context.read<InvestmentsController>().loadInvestments();
            setState(() => _filterSortCache.clear());
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

  // F9/J10 — FD Maturity Calendar
  void _showMaturityCalendar(
      BuildContext context, List<Investment> investments) {
    // Collect FDs and RDs with their maturity dates
    final entries = <({
      String name,
      String bank,
      DateTime maturityDate,
      double maturityValue,
      String type
    })>[];

    for (final inv in investments) {
      final meta = inv.metadata;
      if (meta == null) continue;
      if (inv.type == InvestmentType.fixedDeposit &&
          meta.containsKey('fdData')) {
        try {
          final fd = FixedDeposit.fromMap(
              Map<String, dynamic>.from(meta['fdData'] as Map));
          if (fd.status != FDStatus.prematurelyWithdrawn) {
            entries.add((
              name: fd.name,
              bank: fd.bankName ?? '',
              maturityDate: fd.maturityDate,
              maturityValue: fd.maturityValue,
              type: 'FD',
            ));
          }
        } catch (e) {
          logger.warning('Failed to parse FD data for maturity calendar',
              error: e);
        }
      } else if (inv.type == InvestmentType.recurringDeposit &&
          meta.containsKey('rdData')) {
        try {
          final rd = RecurringDeposit.fromMap(
              Map<String, dynamic>.from(meta['rdData'] as Map));
          entries.add((
            name: rd.name,
            bank: rd.bankName ?? '',
            maturityDate: rd.maturityDate,
            maturityValue: rd.maturityValue,
            type: 'RD',
          ));
        } catch (e) {
          logger.warning('Failed to parse RD data for maturity calendar',
              error: e);
        }
      }
    }
    entries.sort((a, b) => a.maturityDate.compareTo(b.maturityDate));

    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (drag, scrollController) {
          return Container(
            decoration: AppStyles.bottomSheetDecoration(drag),
            child: Column(
              children: [
                const ModalHandle(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Row(
                    children: [
                      const Icon(CupertinoIcons.calendar,
                          size: 20, color: CupertinoColors.systemOrange),
                      const SizedBox(width: 8),
                      Text('Maturity Calendar',
                          style: AppStyles.titleStyle(context)
                              .copyWith(fontSize: TypeScale.title3)),
                    ],
                  ),
                ),
                Expanded(
                  child: entries.isEmpty
                      ? const Center(
                          child: EmptyStateView(
                            icon: CupertinoIcons.calendar_badge_plus,
                            title: 'No FDs or RDs',
                            subtitle:
                                'Add Fixed Deposits or Recurring Deposits to see maturity dates here',
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                          itemCount: entries.length,
                          itemBuilder: (ctx2, i) {
                            final e = entries[i];
                            final now = DateTime.now();
                            final today =
                                DateTime(now.year, now.month, now.day);
                            final matDay = DateTime(e.maturityDate.year,
                                e.maturityDate.month, e.maturityDate.day);
                            final daysLeft = matDay.difference(today).inDays;
                            final isOverdue = daysLeft < 0;
                            final isToday = daysLeft == 0;
                            final statusColor = isOverdue
                                ? AppStyles.loss(context)
                                : isToday
                                    ? CupertinoColors.systemOrange
                                    : daysLeft <= 30
                                        ? CupertinoColors.systemYellow
                                        : AppStyles.gain(context);
                            final statusText = isOverdue
                                ? 'Matured ${(-daysLeft)} day${(-daysLeft) == 1 ? '' : 's'} ago'
                                : isToday
                                    ? 'Matures today!'
                                    : 'In $daysLeft day${daysLeft == 1 ? '' : 's'}';
                            return StaggeredItem(
                              index: i,
                              itemDelay: const Duration(milliseconds: 40),
                              child: Container(
                              margin: const EdgeInsets.only(bottom: Spacing.md),
                              decoration: AppStyles.accentCardDecoration(
                                  context, statusColor),
                              child: ClipRRect(
                                borderRadius:
                                    BorderRadius.circular(Radii.xxl),
                                child: IntrinsicHeight(
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Container(
                                        width: 3,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [
                                              statusColor,
                                              statusColor.withValues(
                                                  alpha: 0.35),
                                            ],
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Padding(
                                          padding:
                                              const EdgeInsets.all(Spacing.lg),
                                          child: Row(
                                            children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: AppStyles.iconBoxDecoration(
                                        context, statusColor),
                                    child: Center(
                                      child: Text(
                                        e.type,
                                        style: TextStyle(
                                          color: statusColor,
                                          fontWeight: FontWeight.w700,
                                          fontSize: TypeScale.footnote,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: Spacing.lg),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(e.name,
                                            style:
                                                AppStyles.titleStyle(context)),
                                        const SizedBox(height: 2),
                                        Text(
                                          e.bank,
                                          style: TextStyle(
                                            fontSize: TypeScale.footnote,
                                            color:
                                                AppStyles.getSecondaryTextColor(
                                                    context),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          statusText,
                                          style: TextStyle(
                                            fontSize: TypeScale.caption,
                                            color: statusColor,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        DateFormatter.format(e.maturityDate),
                                        style: TextStyle(
                                          fontSize: TypeScale.caption,
                                          color:
                                              AppStyles.getSecondaryTextColor(
                                                  context),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        CurrencyFormatter.compact(
                                            e.maturityValue),
                                        style: AppStyles.titleStyle(context)
                                            .copyWith(
                                          color: AppStyles.gain(context),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ));
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
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
      padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
      child: CupertinoSearchTextField(
        controller: _searchController,
        placeholder: 'Search investments',
        backgroundColor: AppStyles.getCardColor(context),
        style: TextStyle(color: AppStyles.getTextColor(context)),
        placeholderStyle: TextStyle(
            color: AppStyles.getSecondaryTextColor(context),
            fontSize: TypeScale.body),
        onChanged: (v) => setState(() { _searchQuery = v; _persistedSearchQuery = v; }),
      ),
    );
  }

  Widget _buildNoSearchResults() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            CupertinoIcons.search,
            size: 48,
            color: AppStyles.getSecondaryTextColor(context).withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            'No results for "$_searchQuery"',
            style: AppStyles.titleStyle(context)
                .copyWith(fontSize: TypeScale.headline),
          ),
          const SizedBox(height: 8),
          Text(
            'Try a different search term',
            style: TextStyle(
              fontSize: TypeScale.body,
              color: AppStyles.getSecondaryTextColor(context),
            ),
          ),
          const SizedBox(height: 16),
          CupertinoButton(
            onPressed: () => setState(() {
              _searchController.clear();
              _searchQuery = '';
              _persistedSearchQuery = '';
            }),
            child: const Text('Clear Search'),
          ),
        ],
      ),
    );
  }

  Widget _buildInvestmentsEmptyState(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(Spacing.xxl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: Spacing.xxl),
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  SemanticColors.investments.withValues(alpha: 0.2),
                  AppStyles.solarGold.withValues(alpha: 0.15),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(CupertinoIcons.chart_bar_fill,
                size: 40, color: SemanticColors.investments),
          ),
          const SizedBox(height: Spacing.xl),
          Text(
            'Your money isn\'t working yet',
            style: TextStyle(
              fontSize: TypeScale.title1,
              fontWeight: FontWeight.w800,
              color: AppStyles.getTextColor(context),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Spacing.md),
          Text(
            '₹10,000 at 12% p.a. grows to ₹93,000 in 20 years.\nThe same amount in savings: barely keeps pace with inflation.',
            style: TextStyle(
              fontSize: TypeScale.callout,
              color: AppStyles.getSecondaryTextColor(context),
              height: 1.55,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Spacing.xxl),
          Text(
            'Start anywhere. Even FD counts.',
            style: TextStyle(
              fontSize: TypeScale.footnote,
              fontWeight: FontWeight.w600,
              color: AppStyles.getSecondaryTextColor(context),
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: Spacing.md),
          Wrap(
            spacing: Spacing.sm,
            runSpacing: Spacing.sm,
            alignment: WrapAlignment.center,
            children: [
              _invTypeChip(context, 'Stocks', CupertinoIcons.graph_circle_fill,
                  SemanticColors.investments, InvestmentType.stocks),
              _invTypeChip(context, 'Mutual Funds', CupertinoIcons.chart_pie_fill,
                  AppStyles.accentBlue, InvestmentType.mutualFund),
              _invTypeChip(context, 'FD / RD', CupertinoIcons.lock_shield_fill,
                  AppStyles.accentTeal, InvestmentType.fixedDeposit),
              _invTypeChip(context, 'Digital Gold', CupertinoIcons.star_fill,
                  AppStyles.solarGold, InvestmentType.digitalGold),
            ],
          ),
          const SizedBox(height: Spacing.xl),
          SizedBox(
            width: double.infinity,
            child: CupertinoButton.filled(
              borderRadius: BorderRadius.circular(Radii.lg),
              onPressed: () => _showInvestmentTypeSelection(context),
              child: const Text('Add Investment',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: Spacing.xxl),
        ],
      ),
    );
  }

  Widget _invTypeChip(BuildContext context, String label, IconData icon,
      Color color, InvestmentType type) {
    return GestureDetector(
      onTap: () => _showInvestmentTypeSelection(context),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: Spacing.md, vertical: Spacing.sm),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(Radii.full),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 0.8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    fontSize: TypeScale.caption,
                    fontWeight: FontWeight.w600,
                    color: color)),
          ],
        ),
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
    // Ensure we have one GlobalKey per tab. Re-measure offsets after the first
    // frame so _syncTabStripOnDrag uses real positions, not approximations.
    if (_tabKeys.length != categories.length) {
      _tabKeys
        ..clear()
        ..addAll(List.generate(categories.length, (_) => GlobalKey()));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _measureTabOffsets();
      });
    }

    return SizedBox(
      height: 60,
      child: ListView.separated(
        controller: _tabStripController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: Spacing.xs),
        itemBuilder: (context, index) {
          final type = categories[index];
          final isSelected = index == _selectedCategoryIndex;
          final label = _getCategoryLabel(type);
          final total = _getCategoryTotalCurrentValue(investments, type);
          final color = type == null
              ? SemanticColors.investments
              : _getInvestmentTypeColor(type);
          return BouncyButton(
            key: _tabKeys[index],
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
              // Scroll tab strip so selected tab is centred using measured offset.
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!_tabStripController.hasClients) return;
                if (_tabOffsets.length > index) {
                  _tabStripController.animateTo(
                    _tabOffsets[index],
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                  );
                  return;
                }
                // Fallback to approximation if offsets not yet measured.
                final tabWidth = 90.0;
                final stripWidth = _tabStripController.position.viewportDimension;
                final target = (index * tabWidth) - (stripWidth / 2) + (tabWidth / 2);
                _tabStripController.animateTo(
                  target.clamp(0.0, _tabStripController.position.maxScrollExtent),
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                );
              });
            },
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? color.withValues(alpha: 0.15)
                    : AppStyles.getCardColor(context),
                borderRadius: BorderRadius.circular(10),
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
                    style: TextStyle(
                      fontSize: TypeScale.footnote,
                      fontWeight: FontWeight.w600,
                      color:
                          isSelected ? color : AppStyles.getTextColor(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    CurrencyFormatter.compact(total),
                    style: TextStyle(
                      fontSize: TypeScale.caption,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? color
                          : AppStyles.getSecondaryTextColor(context),
                    ),
                  ),
                ],
              ),
            ), // AnimatedContainer
            ), // ConstrainedBox
          );
        },
      ),
    );
  }

  /// A compact chip showing the currently active sort — tappable to change it.
  Widget _buildActiveSortChip(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
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
                  const Icon(CupertinoIcons.arrow_up_arrow_down,
                      size: 11, color: SemanticColors.investments),
                  const SizedBox(width: 5),
                  Text(
                    _getSortLabel(_sortBy),
                    style: const TextStyle(
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
          const Spacer(),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                CupertinoIcons.arrow_down,
                size: 10,
                color: AppStyles.getSecondaryTextColor(context).withValues(alpha: 0.55),
              ),
              const SizedBox(width: 3),
              Text(
                'scroll to refresh',
                style: TextStyle(
                  fontSize: 10,
                  color: AppStyles.getSecondaryTextColor(context).withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
        ],
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
        middle: Text('Investments',
            style: TextStyle(color: AppStyles.getTextColor(context))),
        previousPageTitle: 'Back',
        backgroundColor: AppStyles.getBackground(context),
        border: null,
        trailing: Semantics(
          label: 'Maturity calendar',
          child: CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
            onPressed: () => _showMaturityCalendar(
                context,
                Provider.of<InvestmentsController>(context, listen: false)
                    .investments),
            child: const Icon(
              CupertinoIcons.calendar,
              size: 20,
              color: SemanticColors.investments,
            ),
          ),
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
                  child: isLandscape
                    ? LandscapeSplitView(
                        leftFlex: 2,
                        rightFlex: 3,
                        leftPanel: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLandscapeInvestmentsNavBar(context),
                            Expanded(
                              child: SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildCompactSummary(context, investments),
                                    _buildAllocationChart(context, investments),
                                    _buildCategoryTabs(context, investments, categories),
                                    const SizedBox(height: Spacing.lg),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        rightPanel: Column(
                          children: [
                            const SizedBox(height: Spacing.sm),
                            _buildSearchBar(context),
                            const SizedBox(height: Spacing.xs),
                            _buildActiveSortChip(context),
                            const SizedBox(height: Spacing.sm),
                            _buildInvestmentPageView(context, investments, categories),
                          ],
                        ),
                      )
                    : Column(
                        children: [
                          // Compact Summary Section
                          _buildCompactSummary(context, investments),
                          // Asset Allocation Donut Chart
                          _buildAllocationChart(context, investments),
                          _buildCategoryTabs(context, investments, categories),
                          const SizedBox(height: Spacing.xs),
                          // Search bar
                          _buildSearchBar(context),
                          const SizedBox(height: Spacing.xs),
                          // Active sort indicator chip
                          _buildActiveSortChip(context),
                          const SizedBox(height: Spacing.sm),
                          // Investments List with Staggered Animation
                          _buildInvestmentPageView(context, investments, categories),
                        ],
                      ),
                ),
              Positioned(
                right: Spacing.lg,
                bottom: Spacing.xxxl,
                child: Semantics(
                  label: 'Add investment',
                  button: true,
                  child: FadingFAB(
                    onPressed: () => _showInvestmentTypeSelection(context),
                    color: SemanticColors.investments,
                    heroTag: 'investments_fab',
                  ),
                ),
              ),
              if (_showScrollToTop)
                Positioned(
                  bottom: 80,
                  left: 16,
                  child: AnimatedOpacity(
                    opacity: _showScrollToTop ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Semantics(
                      label: 'Scroll to top',
                      button: true,
                      child: BouncyButton(
                        onPressed: () => _scrollController.animateTo(
                          0,
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeOutCubic,
                        ),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppStyles.teal(context).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: AppStyles.teal(context)
                                    .withValues(alpha: 0.5)),
                          ),
                          child: Icon(
                            CupertinoIcons.arrow_up,
                            size: 18,
                            color: AppStyles.teal(context),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  /// Compact 40dp nav bar shown in landscape (replaces CupertinoNavigationBar).
  Widget _buildLandscapeInvestmentsNavBar(BuildContext context) {
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
          Text(
            'INVESTMENTS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: secondary,
              letterSpacing: 1.2,
            ),
          ),
          const Spacer(),
          // Maturity calendar only
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => _showMaturityCalendar(
                context,
                Provider.of<InvestmentsController>(context, listen: false)
                    .investments),
            child: Icon(CupertinoIcons.calendar, size: 18, color: secondary),
          ),
        ],
      ),
    );
  }

  /// Extracted PageView list — used in both portrait Column and landscape right panel.
  Widget _buildInvestmentPageView(
      BuildContext context,
      List<Investment> investments,
      List<InvestmentType?> categories) {
    return Expanded(
      child: PageView.builder(
        controller: _categoryPageController,
        itemCount: categories.length,
        onPageChanged: (index) {
          setState(() {
            _selectedCategoryIndex = index;
            _selectedFilter = categories[index];
          });
          // Keep the active tab visible in the tab strip — use measured offsets.
          // The continuous drag listener (_syncTabStripOnDrag) already tracks
          // mid-swipe; this ensures the final snap position is also correct.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!_tabStripController.hasClients) return;
            if (_tabOffsets.length > index) {
              _tabStripController.animateTo(
                _tabOffsets[index],
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
              );
            }
          });
        },
        itemBuilder: (context, pageIndex) {
          final categoryType = categories[pageIndex];
          final pageInvestments = _getFilteredSorted(investments, categoryType);

          if (pageInvestments.isEmpty) {
            if (_searchQuery.isNotEmpty) {
              return _buildNoSearchResults();
            }
            if (categoryType == null) {
              return _buildInvestmentsEmptyState(context);
            }
            return EmptyStateView(
              icon: CupertinoIcons.chart_bar_square,
              title: 'No ${categoryType.name} investments',
              subtitle: 'Add your first ${categoryType.name} investment.',
              showPulse: false,
            );
          }

          final canReorder =
              categoryType == null && _sortBy == SortBy.dateAdded;

          if (canReorder) {
            return ReorderableListView.builder(
              padding: const EdgeInsets.fromLTRB(Spacing.lg, 0, Spacing.lg, 100),
              itemCount: pageInvestments.length,
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
                  key: ValueKey(pageInvestments[index].id),
                  index: index,
                  child: Container(
                    margin: const EdgeInsets.only(top: Spacing.lg),
                    child: _buildSlidableInvestmentCard(pageInvestments[index]),
                  ),
                );
              },
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              Haptics.medium();
              await _refreshCurrentValues(context);
            },
            color: AppStyles.getPrimaryColor(context),
            child: ListView.builder(
              key: PageStorageKey('investments_list_$pageIndex'),
              controller:
                  pageIndex == _selectedCategoryIndex ? _scrollController : null,
              physics: const SmoothScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              cacheExtent: 600,
              padding: const EdgeInsets.fromLTRB(Spacing.lg, 0, Spacing.lg, 100),
              itemCount: pageInvestments.length,
              itemBuilder: (context, index) {
                return StaggeredItem(
                  key: ValueKey(
                      '${categoryType?.name ?? 'all'}_${pageInvestments[index].id}'),
                  index: index,
                  child: Container(
                    margin: const EdgeInsets.only(top: Spacing.lg),
                    child: _buildSlidableInvestmentCard(pageInvestments[index]),
                  ),
                );
              },
            ),
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
          const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.xs),
      child: RepaintBoundary(
        child: Container(
        decoration: AppStyles.cardDecoration(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () => setState(
                  () => _isAllocationExpanded = !_isAllocationExpanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: Spacing.lg, vertical: Spacing.md),
                child: Row(
                  children: [
                    const Icon(CupertinoIcons.chart_pie_fill,
                        size: 13, color: SemanticColors.investments),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Asset Allocation',
                        style: TextStyle(
                          fontSize: TypeScale.footnote,
                          fontWeight: FontWeight.w600,
                          color: AppStyles.getTextColor(context),
                        ),
                      ),
                    ),
                    Icon(
                      _isAllocationExpanded
                          ? CupertinoIcons.chevron_up
                          : CupertinoIcons.chevron_down,
                      size: 13,
                      color: AppStyles.getSecondaryTextColor(context),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              child: _isAllocationExpanded
                  ? Padding(
                      padding: const EdgeInsets.only(
                          left: Spacing.lg,
                          right: Spacing.lg,
                          bottom: Spacing.lg),
                      child: Row(
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
                          const SizedBox(width: Spacing.lg),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: entries.take(5).map((e) {
                                final pct = (e.value / total * 100);
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: Spacing.xs),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: _getInvestmentTypeColor(e.key),
                                          borderRadius:
                                              BorderRadius.circular(2),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          _getInvestmentTypeLabel(e.key),
                                          style: TextStyle(
                                            fontSize: TypeScale.caption,
                                            color:
                                                AppStyles.getSecondaryTextColor(
                                                    context),
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
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
      ), // RepaintBoundary
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

    // Calculate portfolio P&L
    double totalInvested = 0;
    double totalCurrentValue = 0;
    DateTime? earliestDate;
    for (final inv in investments) {
      final meta = inv.metadata;
      final invested =
          (meta?['investmentAmount'] as num?)?.toDouble() ?? inv.amount;
      final current = _calculateCurrentValue(inv);
      totalInvested += invested;
      totalCurrentValue += current;
      // Track earliest investment date for CAGR
      final dateStr = meta?['investmentDate'] as String? ??
          meta?['purchaseDate'] as String? ??
          meta?['startDate'] as String?;
      if (dateStr != null) {
        try {
          final d = DateTime.parse(dateStr);
          if (earliestDate == null || d.isBefore(earliestDate)) {
            earliestDate = d;
          }
        } catch (e) {
          logger.warning('Failed to parse investment date for P&L',
              error: e);
        }
      }
    }
    final gainLoss = totalCurrentValue - totalInvested;
    final gainPercent =
        totalInvested > 0 ? (gainLoss / totalInvested) * 100 : 0.0;
    final isGain = gainLoss >= 0;
    final gainColor =
        isGain ? AppStyles.gain(context) : AppStyles.loss(context);
    // Portfolio CAGR
    String? cagrText;
    if (earliestDate != null && totalInvested > 0 && totalCurrentValue > 0) {
      final yearsElapsed =
          DateTime.now().difference(earliestDate).inDays / 365.25;
      if (yearsElapsed > 0.05) {
        final cagr =
            (pow(totalCurrentValue / totalInvested, 1 / yearsElapsed) - 1) *
                100;
        cagrText = '${cagr >= 0 ? '+' : ''}${cagr.toStringAsFixed(1)}%';
      }
    }

    return GestureDetector(
      onTap: () => setState(() => _isPnLExpanded = !_isPnLExpanded),
      child: Container(
        decoration: BoxDecoration(
          color: AppStyles.getCardColor(context),
          border: Border(
            bottom: BorderSide(
              color: AppStyles.getDividerColor(context),
              width: 0.5,
            ),
          ),
        ),
        padding:
            const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row — always visible
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        '${investments.length} Investment${investments.length == 1 ? '' : 's'}',
                        style: TextStyle(
                          fontSize: TypeScale.subhead,
                          fontWeight: FontWeight.bold,
                          color: AppStyles.getTextColor(context),
                        ),
                      ),
                      const SizedBox(width: Spacing.md),
                      // Compact gain pill
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: Spacing.sm, vertical: 2),
                        decoration: BoxDecoration(
                          color: gainColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${isGain ? '+' : ''}${gainPercent.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: TypeScale.caption,
                            fontWeight: FontWeight.w700,
                            color: gainColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  _isPnLExpanded
                      ? CupertinoIcons.chevron_up
                      : CupertinoIcons.chevron_down,
                  size: 14,
                  color: AppStyles.getSecondaryTextColor(context),
                ),
              ],
            ),
            // Expandable P&L details
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              child: _isPnLExpanded
                  ? Padding(
                      padding: const EdgeInsets.only(top: Spacing.sm),
                      child: Container(
                        padding: const EdgeInsets.all(Spacing.md),
                        decoration: BoxDecoration(
                          color: AppStyles.getBackground(context),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppStyles.getDividerColor(context)
                                .withValues(alpha: 0.5),
                            width: 0.8,
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _buildPnLColumn(
                                      context,
                                      'Invested',
                                      '₹${totalInvested.toStringAsFixed(0)}',
                                      AppStyles.getTextColor(context)),
                                ),
                                Container(
                                  width: 1,
                                  height: 28,
                                  color:
                                      AppStyles.getSecondaryTextColor(context)
                                          .withValues(alpha: 0.2),
                                ),
                                Expanded(
                                  child: _buildPnLColumn(
                                      context,
                                      'Current',
                                      '₹${totalCurrentValue.toStringAsFixed(0)}',
                                      gainColor),
                                ),
                                Container(
                                  width: 1,
                                  height: 28,
                                  color:
                                      AppStyles.getSecondaryTextColor(context)
                                          .withValues(alpha: 0.2),
                                ),
                                Expanded(
                                  child: _buildPnLColumn(
                                    context,
                                    'Gain / Loss',
                                    '${isGain ? '+' : ''}₹${gainLoss.abs().toStringAsFixed(0)}',
                                    gainColor,
                                  ),
                                ),
                              ],
                            ),
                            if (cagrText != null) ...[
                              const SizedBox(height: Spacing.sm),
                              Container(
                                height: 1,
                                color: AppStyles.getSecondaryTextColor(context)
                                    .withValues(alpha: 0.12),
                              ),
                              const SizedBox(height: Spacing.sm),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Portfolio CAGR',
                                    style: TextStyle(
                                      fontSize: TypeScale.caption,
                                      color: AppStyles.getSecondaryTextColor(
                                          context),
                                    ),
                                  ),
                                  const SizedBox(width: 3),
                                  const JargonTooltip.cagr(),
                                  const SizedBox(width: 6),
                                  Text(
                                    cagrText,
                                    style: TextStyle(
                                      fontSize: TypeScale.caption,
                                      fontWeight: FontWeight.w700,
                                      color: gainColor,
                                    ),
                                  ),
                                  Text(
                                    '  p.a.',
                                    style: TextStyle(
                                      fontSize: TypeScale.caption,
                                      color: AppStyles.getSecondaryTextColor(
                                          context),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPnLColumn(
      BuildContext context, String label, String value, Color valueColor) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: TypeScale.caption,
            color: AppStyles.getSecondaryTextColor(context),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: TypeScale.footnote,
            fontWeight: FontWeight.w700,
            color: valueColor,
          ),
          textAlign: TextAlign.center,
        ),
      ],
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
            const SizedBox(height: Spacing.xxxl + Spacing.xxl),
            // Header
            Container(
              padding: const EdgeInsets.all(Spacing.lg),
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
                padding: const EdgeInsets.all(Spacing.lg),
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
                    const SizedBox(height: Spacing.md),
                    // Type options
                    ..._availableSupportedTypes(investments).map((type) {
                      final count =
                          investments.where((inv) => inv.type == type).length;
                      if (count == 0) return const SizedBox.shrink();

                      final isSelected = _selectedFilter == type;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: Spacing.md),
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
            const SizedBox(height: Spacing.lg),
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
        padding: const EdgeInsets.all(Spacing.lg),
        decoration: BoxDecoration(
          color: isSelected
              ? SemanticColors.investments.withValues(alpha: 0.15)
              : AppStyles.getCardColor(context),
          borderRadius: BorderRadius.circular(Radii.md),
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
              const Icon(
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
            const SizedBox(height: Spacing.xxxl + Spacing.xxl),
            // Header
            Container(
              padding: const EdgeInsets.all(Spacing.lg),
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
                padding: const EdgeInsets.all(Spacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ...SortBy.values.map((sort) {
                      final isSelected = _sortBy == sort;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: Spacing.md),
                        child: _buildSortOptionCard(
                          context,
                          _getSortLabel(sort),
                          isSelected,
                          () {
                            setState(() => _sortBy = sort);
                            _saveSortPrefs();
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
            const SizedBox(height: Spacing.lg),
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
        padding: const EdgeInsets.all(Spacing.lg),
        decoration: BoxDecoration(
          color: isSelected
              ? SemanticColors.investments.withValues(alpha: 0.15)
              : AppStyles.getCardColor(context),
          borderRadius: BorderRadius.circular(Radii.md),
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
              const Icon(
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
      padding: const EdgeInsets.all(Spacing.lg),
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
                  const SizedBox(height: Spacing.xs),
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
                  padding: const EdgeInsets.symmetric(
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
                      const SizedBox(width: Spacing.xs),
                      Text(
                        _sortAscending ? 'Ascending' : 'Descending',
                        style: const TextStyle(
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
          const SizedBox(height: Spacing.lg),
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
              const SizedBox(height: Spacing.sm),
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: Spacing.md, vertical: Spacing.sm),
                        margin: const EdgeInsets.only(right: Spacing.md),
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
                      if (count == 0) return const SizedBox.shrink();

                      final isSelected = _selectedFilter == type;
                      return GestureDetector(
                        onTap: () {
                          Haptics.selection();
                          setState(() => _selectedFilter = type);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: Spacing.md, vertical: Spacing.sm),
                          margin: const EdgeInsets.only(right: Spacing.md),
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
                              const SizedBox(width: Spacing.xs),
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
          const SizedBox(height: Spacing.lg),
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
              const SizedBox(height: Spacing.sm),
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
                          padding: const EdgeInsets.symmetric(
                              horizontal: Spacing.md, vertical: Spacing.sm),
                          margin: const EdgeInsets.only(right: Spacing.md),
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
    const investmentTypes = InvestmentType.values;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
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
          padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
          child: Row(
            children: [
              // "All" option
              GestureDetector(
                onTap: () => setState(() => _selectedFilter = null),
                child: Container(
                  padding: const EdgeInsets.symmetric(
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
              const SizedBox(width: Spacing.md),
              // Investment type filters
              ...investmentTypes.map((type) {
                final count =
                    investments.where((inv) => inv.type == type).length;
                final isSelected = _selectedFilter == type;

                return Padding(
                  padding: const EdgeInsets.only(right: Spacing.md),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedFilter = type),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
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
          padding: const EdgeInsets.symmetric(
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
                  padding: const EdgeInsets.symmetric(
                      horizontal: Spacing.md, vertical: Spacing.xs),
                  decoration: BoxDecoration(
                    color: AppStyles.getCardColor(context),
                    borderRadius: BorderRadius.circular(Radii.lg),
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
                      const SizedBox(width: Spacing.xs),
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
          padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
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
        padding: const EdgeInsets.only(right: Spacing.md),
        child: GestureDetector(
          onTap: () {
            setState(() => _sortBy = sort);
            _saveSortPrefs();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(
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
        return sum +
            ((metadata['currentValue'] as num?)?.toDouble() ?? inv.amount);
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
      return const SizedBox.shrink();
    }

    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: Container(
        decoration: AppStyles.cardDecoration(context),
        margin: const EdgeInsets.symmetric(horizontal: Spacing.lg),
        child: Column(
          children: [
            // Header with expand/collapse button
            Padding(
              padding: const EdgeInsets.all(Spacing.lg),
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
                          const SizedBox(height: Spacing.xs),
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
                padding: const EdgeInsets.only(bottom: Spacing.lg),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
                  child: Row(
                    children: [
                      for (int i = 0; i < availableTypes.length; i++) ...[
                        _buildInvestmentTypeSummaryCard(
                          context,
                          availableTypes[i],
                          investments,
                        ),
                        if (i < availableTypes.length - 1)
                          const SizedBox(width: Spacing.lg),
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
        padding: const EdgeInsets.all(Spacing.lg),
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
              const SizedBox(height: Spacing.lg),

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
              const SizedBox(height: Spacing.md),

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
              const SizedBox(height: Spacing.md),

              // Gain/Loss
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.md,
                  vertical: Spacing.sm,
                ),
                decoration: BoxDecoration(
                  color: isPositive
                      ? AppStyles.gain(context).withValues(alpha: 0.1)
                      : AppStyles.loss(context).withValues(alpha: 0.1),
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
                                ? AppStyles.gain(context)
                                : AppStyles.loss(context),
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
                                ? AppStyles.gain(context)
                                : AppStyles.loss(context),
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
      future: _goldPriceFuture,
      builder: (context, snapshot) {
        double currentValue = 0;
        double currentRate = 0;

        if (snapshot.hasData && snapshot.data != null) {
          currentRate = snapshot.data!;
          currentValue = weightInGrams * currentRate;
        } else {
          // While loading or on error, use stored value so card never shows ₹0
          currentValue =
              (metadata['currentValue'] as num?)?.toDouble() ?? investedAmount;
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
                FadeScalePageRoute(
                  page: DigitalGoldDetailsScreen(investment: investment),
                ),
              );
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: Spacing.lg),
              decoration:
                  AppStyles.accentCardDecoration(context, investment.color),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(Radii.xxl),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        width: 4,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              investment.color,
                              investment.color.withValues(alpha: 0.35),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: Spacing.cardPadding,
                          child: Row(
                            children: [
                              IconBox(
                                icon: CupertinoIcons.chart_bar_square_fill,
                                color: investment.color,
                                showGlow: true,
                              ),
                              const SizedBox(width: Spacing.lg),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(investment.name,
                                        style: AppStyles.titleStyle(context)),
                                    const SizedBox(height: Spacing.xs),
                                    Text(
                                      investment.getTypeLabel(),
                                      style: TextStyle(
                                        fontSize: TypeScale.footnote,
                                        color: investment.color
                                            .withValues(alpha: 0.75),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: Spacing.sm),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Invested',
                                                style: TextStyle(
                                                  fontSize: TypeScale.caption,
                                                  color: AppStyles
                                                      .getSecondaryTextColor(
                                                          context),
                                                ),
                                              ),
                                              Text(
                                                CurrencyFormatter.compact(
                                                    investedAmount),
                                                style: TextStyle(
                                                  fontSize: TypeScale.subhead,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppStyles.getTextColor(
                                                      context),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: Spacing.md),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Current',
                                                style: TextStyle(
                                                  fontSize: TypeScale.caption,
                                                  color: AppStyles
                                                      .getSecondaryTextColor(
                                                          context),
                                                ),
                                              ),
                                              if (snapshot.connectionState ==
                                                  ConnectionState.waiting)
                                                Text(
                                                  'Fetching…',
                                                  style: TextStyle(
                                                    fontSize: TypeScale.subhead,
                                                    fontWeight: FontWeight.w600,
                                                    color: AppStyles
                                                        .getSecondaryTextColor(
                                                            context),
                                                  ),
                                                )
                                              else
                                                Text(
                                                  CurrencyFormatter.compact(
                                                      currentValue),
                                                  style: TextStyle(
                                                    fontSize: TypeScale.subhead,
                                                    fontWeight: FontWeight.w700,
                                                    color: isProfit
                                                        ? CupertinoColors
                                                            .systemGreen
                                                        : CupertinoColors
                                                            .systemRed,
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
                              const SizedBox(width: Spacing.sm),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: Spacing.sm,
                                        vertical: Spacing.xs),
                                    decoration: BoxDecoration(
                                      color: isProfit
                                          ? AppStyles.gain(context)
                                              .withValues(alpha: 0.15)
                                          : AppStyles.loss(context)
                                              .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isProfit
                                            ? AppStyles.gain(context)
                                                .withValues(alpha: 0.35)
                                            : AppStyles.loss(context)
                                                .withValues(alpha: 0.35),
                                        width: 0.8,
                                      ),
                                    ),
                                    child: Text(
                                      '${isProfit ? '+' : ''}${gainLossPercent.toStringAsFixed(1)}%',
                                      style: TextStyle(
                                        fontSize: TypeScale.footnote,
                                        fontWeight: FontWeight.w800,
                                        color: isProfit
                                            ? AppStyles.gain(context)
                                            : AppStyles.loss(context),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: Spacing.xs),
                                  Icon(
                                    CupertinoIcons.chevron_right,
                                    size: IconSizes.xs,
                                    color:
                                        AppStyles.getSecondaryTextColor(context),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
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
            backgroundColor: AppStyles.loss(context),
            foregroundColor: Colors.white,
            icon: CupertinoIcons.delete,
            label: 'Delete',
            borderRadius: BorderRadius.circular(Radii.md),
          ),
        ],
      ),
      child: _buildInvestmentCard(investment),
    );
  }

  // ── Investment quick-action sheet ──────────────────────────────────────────

  void _showInvestmentQuickActions(Investment investment) {
    final supportsAddSell = investment.type != InvestmentType.fixedDeposit &&
        investment.type != InvestmentType.recurringDeposit &&
        investment.type != InvestmentType.pensionSchemes;

    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(investment.name),
        message: Text(_investmentTypeLabel(investment.type)),
        actions: [
          if (supportsAddSell) ...[
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.of(context).push(
                  FadeScalePageRoute(
                      page: _addWizardFor(investment)),
                );
              },
              child: const Text('Add / Buy More'),
            ),
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () {
                Navigator.pop(ctx);
                _navigateToDetails(investment);
              },
              child: const Text('Sell / Redeem'),
            ),
          ],
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _navigateToDetails(investment);
            },
            child: const Text('View Details'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  String _investmentTypeLabel(InvestmentType type) {
    switch (type) {
      case InvestmentType.stocks: return 'Stocks & ETFs';
      case InvestmentType.mutualFund: return 'Mutual Fund';
      case InvestmentType.fixedDeposit: return 'Fixed Deposit';
      case InvestmentType.recurringDeposit: return 'Recurring Deposit';
      case InvestmentType.bonds: return 'Bonds';
      case InvestmentType.nationalSavingsScheme: return 'NPS';
      case InvestmentType.digitalGold: return 'Digital Gold';
      case InvestmentType.pensionSchemes: return 'Pension';
      case InvestmentType.cryptocurrency: return 'Cryptocurrency';
      case InvestmentType.futuresOptions: return 'Futures & Options';
      case InvestmentType.forexCurrency: return 'Forex / Currency';
      case InvestmentType.commodities: return 'Commodities';
    }
  }

  Widget _addWizardFor(Investment investment) {
    switch (investment.type) {
      case InvestmentType.stocks:
        return StocksWizard(existingInvestment: investment);
      case InvestmentType.mutualFund:
        return _buildMFBuyMoreWizard(investment);
      case InvestmentType.digitalGold:
        return DigitalGoldWizard(existingInvestment: investment);
      default:
        return SimpleInvestmentEntryWizard(
          type: investment.type,
          title: 'Add ${_investmentTypeLabel(investment.type)}',
          subtitle: 'Add more to your existing position.',
          color: _getInvestmentTypeColor(investment.type),
          defaultName: investment.name,
          existingInvestment: investment,
        );
    }
  }

  Widget _buildMFBuyMoreWizard(Investment investment) {
    final meta = investment.metadata ?? {};
    final schemeCode =
        (meta['schemeCode'] as String?) ?? investment.id;
    final schemeName =
        (meta['schemeName'] as String?) ?? investment.name;
    final nav = (meta['currentNAV'] as num?)?.toDouble() ?? 0.0;

    final intent = MFWizardIntent(
      mode: MFWizardMode.buyMore,
      mutualFund: MutualFund(
        schemeCode: schemeCode,
        schemeName: schemeName,
        schemeType: meta['schemeType'] as String?,
        fundHouse: meta['fundHouse'] as String?,
      ),
      transactionAmount: 0,
      transactionNav: nav,
      transactionDate: DateTime.now(),
      targetInvestment: investment,
      initialStep: 3,
      sipActive: meta['sipActive'] == true,
    );

    return MFWizard(intent: intent);
  }

  Future<void> _navigateToDetails(Investment investment) async {
    final ctrl = context.read<InvestmentsController>();
    switch (investment.type) {
      case InvestmentType.stocks:
        await Navigator.of(context).push(FadeScalePageRoute(
            page: StockDetailsScreen(investment: investment)));
      case InvestmentType.mutualFund:
        await Navigator.of(context).push(FadeScalePageRoute(
            page: MFDetailsScreen(investment: investment)));
      case InvestmentType.fixedDeposit:
        if (investment.metadata?.containsKey('fdData') == true) {
          try {
            final fd = FixedDeposit.fromMap(
                Map<String, dynamic>.from(investment.metadata!['fdData'] as Map));
            await Navigator.of(context)
                .push(FadeScalePageRoute(page: FDDetailsScreen(fd: fd)));
          } catch (_) {
            toast.showError('Error loading FD details');
          }
        }
      case InvestmentType.recurringDeposit:
        if (investment.metadata?.containsKey('rdData') == true) {
          try {
            final rd = RecurringDeposit.fromMap(
                Map<String, dynamic>.from(investment.metadata!['rdData'] as Map));
            await Navigator.of(context)
                .push(FadeScalePageRoute(page: RDDetailsScreen(rd: rd)));
          } catch (_) {
            toast.showError('Error loading RD details');
          }
        }
      case InvestmentType.bonds:
        await Navigator.of(context).push(FadeScalePageRoute(
            page: BondsDetailsScreen(investment: investment)));
      case InvestmentType.cryptocurrency:
        await Navigator.of(context).push(FadeScalePageRoute(
            page: CryptoDetailsScreen(investment: investment)));
      case InvestmentType.digitalGold:
        await Navigator.of(context).push(FadeScalePageRoute(
            page: DigitalGoldDetailsScreen(investment: investment)));
      case InvestmentType.nationalSavingsScheme:
        await Navigator.of(context).push(FadeScalePageRoute(
            page: NPSDetailsScreen(investment: investment)));
      case InvestmentType.pensionSchemes:
        await Navigator.of(context).push(FadeScalePageRoute(
            page: PensionDetailsScreen(investment: investment)));
      case InvestmentType.commodities:
        await Navigator.of(context).push(FadeScalePageRoute(
            page: CommoditiesDetailsScreen(investment: investment)));
      case InvestmentType.futuresOptions:
        await Navigator.of(context).push(FadeScalePageRoute(
            page: FODetailsScreen(investment: investment)));
      default:
        await Navigator.of(context).push(FadeScalePageRoute(
            page: SimpleInvestmentDetailsScreen(investment: investment)));
    }
    // Reload after returning from any detail screen so edits/deletions reflect immediately
    if (mounted) {
      await ctrl.loadInvestments();
      setState(() => _filterSortCache.clear());
    }
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

    return GestureDetector(
      // AU8-05 — Long-press copies current value to clipboard
      onLongPress: () {
        Haptics.medium();
        final amount = _calculateCurrentValue(investment);
        Clipboard.setData(ClipboardData(text: amount.toStringAsFixed(2)));
        ToastController().showSuccess('Amount ₹${amount.toStringAsFixed(2)} copied');
      },
      child: Hero(
      tag: 'investment_${investment.id}',
      child: BouncyButton(
        onPressed: () {
          Haptics.light();
          _showInvestmentQuickActions(investment);
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: Spacing.lg),
          decoration:
              AppStyles.accentCardDecoration(context, investment.color),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(Radii.xxl),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Left accent bar
                  Container(
                    width: 4,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          investment.color,
                          investment.color.withValues(alpha: 0.35),
                        ],
                      ),
                    ),
                  ),
                  // Card content
                  Expanded(
                    child: Padding(
                      padding: Spacing.cardPadding,
                      child: Row(
                        children: [
                          IconBox(
                            icon: CupertinoIcons.chart_bar_square_fill,
                            color: investment.color,
                            showGlow: true,
                          ),
                          const SizedBox(width: Spacing.lg),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(investment.name,
                                    style: AppStyles.titleStyle(context),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                                const SizedBox(height: Spacing.xs),
                                Text(
                                  investment.getTypeLabel(),
                                  style: TextStyle(
                                    fontSize: TypeScale.footnote,
                                    color: investment.color
                                        .withValues(alpha: 0.75),
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: Spacing.sm),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Invested',
                                            style: TextStyle(
                                              fontSize: TypeScale.caption,
                                              color: AppStyles
                                                  .getSecondaryTextColor(
                                                      context),
                                            ),
                                          ),
                                          Text(
                                            CurrencyFormatter.compact(
                                                investedAmount),
                                            style: TextStyle(
                                              fontSize: TypeScale.subhead,
                                              fontWeight: FontWeight.w700,
                                              color:
                                                  AppStyles.getTextColor(context),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: Spacing.md),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Current',
                                            style: TextStyle(
                                              fontSize: TypeScale.caption,
                                              color: AppStyles
                                                  .getSecondaryTextColor(
                                                      context),
                                            ),
                                          ),
                                          Text(
                                            CurrencyFormatter.compact(
                                                currentValue),
                                            style: TextStyle(
                                              fontSize: TypeScale.subhead,
                                              fontWeight: FontWeight.w700,
                                              color: isProfit
                                                  ? AppStyles.gain(context)
                                                  : AppStyles.loss(context),
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
                          const SizedBox(width: Spacing.sm),
                          // AU13-01 — P&L badge: coloured pill with % + absolute amount
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: Spacing.sm,
                                    vertical: Spacing.xs),
                                decoration: BoxDecoration(
                                  color: isProfit
                                      ? AppStyles.gain(context)
                                          .withValues(alpha: 0.15)
                                      : AppStyles.loss(context)
                                          .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isProfit
                                        ? AppStyles.gain(context)
                                            .withValues(alpha: 0.35)
                                        : AppStyles.loss(context)
                                            .withValues(alpha: 0.35),
                                    width: 0.8,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${isProfit ? '+' : ''}${gainLossPercent.toStringAsFixed(1)}%',
                                      style: TextStyle(
                                        fontSize: TypeScale.footnote,
                                        fontWeight: FontWeight.w800,
                                        color: isProfit
                                            ? AppStyles.gain(context)
                                            : AppStyles.loss(context),
                                      ),
                                    ),
                                    Text(
                                      '${isProfit ? '+' : '-'}${CurrencyFormatter.compact(gainLoss.abs())}',
                                      style: TextStyle(
                                        fontSize: 9.0,
                                        fontWeight: FontWeight.w600,
                                        color: isProfit
                                            ? AppStyles.gain(context)
                                                .withValues(alpha: 0.75)
                                            : AppStyles.loss(context)
                                                .withValues(alpha: 0.75),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: Spacing.xs),
                              Icon(
                                CupertinoIcons.chevron_right,
                                size: IconSizes.xs,
                                color:
                                    AppStyles.getSecondaryTextColor(context),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      ), // Hero
    ); // GestureDetector
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
