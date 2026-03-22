import 'dart:io';
import 'dart:math' show min;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show RefreshIndicator, VerticalDivider;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/investments_controller.dart';
import 'package:vittara_fin_os/logic/transaction_feed_builder.dart';
import 'package:vittara_fin_os/logic/transactions_archive_controller.dart';
import 'package:vittara_fin_os/logic/transactions_controller.dart';
import 'package:vittara_fin_os/logic/transaction_model.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/styles/transaction_type_theme.dart';
import 'package:vittara_fin_os/ui/widgets/animations.dart';
import 'package:vittara_fin_os/ui/widgets/common_widgets.dart';
import 'package:vittara_fin_os/ui/dashboard/transaction_wizard.dart';
import 'package:vittara_fin_os/ui/widgets/transaction_details_content.dart';
import 'package:vittara_fin_os/ui/widgets/toast_notification.dart' as toast_lib;
import 'package:vittara_fin_os/utils/date_formatter.dart';
import 'package:vittara_fin_os/utils/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vittara_fin_os/services/transaction_export_service.dart';
import 'package:vittara_fin_os/ui/widgets/animated_counter.dart' as counter_widgets;
import 'package:flutter_slidable/flutter_slidable.dart';

enum _DateRangeFilter {
  all,
  today,
  week,
  month,
  year;

  String get label {
    switch (this) {
      case _DateRangeFilter.all:   return 'All';
      case _DateRangeFilter.today: return 'Today';
      case _DateRangeFilter.week:  return 'Week';
      case _DateRangeFilter.month: return 'Month';
      case _DateRangeFilter.year:  return 'Year';
    }
  }

  DateTime cutoff(DateTime now) {
    switch (this) {
      case _DateRangeFilter.all:
        return DateTime(2000);
      case _DateRangeFilter.today:
        return DateTime(now.year, now.month, now.day);
      case _DateRangeFilter.week:
        return now.subtract(const Duration(days: 7));
      case _DateRangeFilter.month:
        return DateTime(now.year, now.month, 1);
      case _DateRangeFilter.year:
        return DateTime(now.year, 1, 1);
    }
  }
}

class TransactionHistoryScreen extends StatefulWidget {
  /// When [filterAccountId] is provided, only transactions linked to that
  /// account are shown and the title is set to [filterAccountName].
  const TransactionHistoryScreen({
    super.key,
    this.filterAccountId,
    this.filterAccountName,
  });

  final String? filterAccountId;
  final String? filterAccountName;

  @override
  State<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  final AppLogger logger = AppLogger();
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  double? _minAmount;
  double? _maxAmount;
  TransactionType? _typeFilter;
  _DateRangeFilter _dateFilter = _DateRangeFilter.all;
  bool _isExportingCsv = false;
  bool _isExportingPdf = false;
  bool _isExportingXlsx = false;
  final ScrollController _scrollController = ScrollController();
  bool _showScrollToTop = false;

  // Pagination: show at most _visibleCount transactions at a time.
  int _visibleCount = 50;
  static const int _pageSize = 50;

  static const _prefKeyTxType = 'tx_filter_type';

  @override
  void initState() {
    super.initState();
    _loadFilterPrefs();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    final show = _scrollController.offset > 400;
    if (show != _showScrollToTop) {
      setState(() => _showScrollToTop = show);
    }
  }

  Future<void> _loadFilterPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final typeName = prefs.getString(_prefKeyTxType);
    if (typeName != null) {
      final match = TransactionType.values.where((e) => e.name == typeName).firstOrNull;
      if (match != null) setState(() => _typeFilter = match);
    }
  }

  Future<void> _saveFilterPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (_typeFilter != null) {
      await prefs.setString(_prefKeyTxType, _typeFilter!.name);
    } else {
      await prefs.remove(_prefKeyTxType);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool get _hasActiveFilter =>
      _minAmount != null ||
      _maxAmount != null ||
      _typeFilter != null ||
      _dateFilter != _DateRangeFilter.all;

  List<Transaction> _filterBySearch(List<Transaction> txns) {
    var result = txns;
    // Account-scoped view: keep only transactions linked to this account.
    if (widget.filterAccountId != null) {
      final id = widget.filterAccountId!;
      result = result.where((t) {
        final metaId = t.metadata?['accountId'] as String?;
        return metaId == id ||
            t.sourceAccountId == id ||
            t.destinationAccountId == id;
      }).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result.where((t) {
        return t.getTypeLabel().toLowerCase().contains(q) ||
            t.getSummary().toLowerCase().contains(q) ||
            t.amount.toString().contains(q);
      }).toList();
    }
    if (_typeFilter != null) {
      result = result.where((t) => t.type == _typeFilter).toList();
    }
    if (_minAmount != null) {
      result = result.where((t) => t.amount >= _minAmount!).toList();
    }
    if (_maxAmount != null) {
      result = result.where((t) => t.amount <= _maxAmount!).toList();
    }
    if (_dateFilter != _DateRangeFilter.all) {
      final now = DateTime.now();
      final cutoff = _dateFilter.cutoff(now);
      result = result.where((t) => t.dateTime.isAfter(cutoff)).toList();
    }
    return result;
  }

  void _showFilterSheet(BuildContext context) {
    final minCtrl =
        TextEditingController(text: _minAmount?.toStringAsFixed(0) ?? '');
    final maxCtrl =
        TextEditingController(text: _maxAmount?.toStringAsFixed(0) ?? '');
    TransactionType? tempType = _typeFilter;

    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          return Container(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
            decoration: AppStyles.bottomSheetDecoration(ctx),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 16),
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemGrey3,
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text('Filter Transactions',
                        style: AppStyles.titleStyle(ctx)
                            .copyWith(fontSize: TypeScale.title3)),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text('Type',
                        style: TextStyle(
                          color: AppStyles.getSecondaryTextColor(ctx),
                          fontWeight: FontWeight.w600,
                          fontSize: TypeScale.footnote,
                        )),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 36,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      children: [
                        null,
                        ...TransactionType.values,
                      ].map((type) {
                        final isSelected = tempType == type;
                        final label = type == null
                            ? 'All'
                            : type.name[0].toUpperCase() +
                                type.name.substring(1);
                        return GestureDetector(
                          onTap: () => setSheet(() => tempType = type),
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppStyles.getPrimaryColor(ctx)
                                  : AppStyles.getCardColor(ctx),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected
                                    ? AppStyles.getPrimaryColor(ctx)
                                    : AppStyles.getDividerColor(ctx),
                              ),
                            ),
                            child: Text(
                              label,
                              style: TextStyle(
                                color: isSelected
                                    ? CupertinoColors.white
                                    : AppStyles.getTextColor(ctx),
                                fontSize: TypeScale.footnote,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text('Amount Range',
                        style: TextStyle(
                          color: AppStyles.getSecondaryTextColor(ctx),
                          fontWeight: FontWeight.w600,
                          fontSize: TypeScale.footnote,
                        )),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: CupertinoTextField(
                            controller: minCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            placeholder: 'Min ₹',
                            prefix: const Padding(
                              padding: EdgeInsets.only(left: 12),
                              child: Text('₹'),
                            ),
                            style:
                                TextStyle(color: AppStyles.getTextColor(ctx)),
                            decoration: BoxDecoration(
                              color: AppStyles.getBackground(ctx),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: CupertinoTextField(
                            controller: maxCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            placeholder: 'Max ₹',
                            prefix: const Padding(
                              padding: EdgeInsets.only(left: 12),
                              child: Text('₹'),
                            ),
                            style:
                                TextStyle(color: AppStyles.getTextColor(ctx)),
                            decoration: BoxDecoration(
                              color: AppStyles.getBackground(ctx),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: CupertinoButton(
                            color: CupertinoColors.systemGrey5,
                            onPressed: () {
                              setState(() {
                                _minAmount = null;
                                _maxAmount = null;
                                _typeFilter = null;
                                _dateFilter = _DateRangeFilter.all;
                              });
                              _saveFilterPrefs();
                              Navigator.pop(ctx);
                            },
                            child: Text('Clear',
                                style: TextStyle(
                                    color: AppStyles.getTextColor(ctx))),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: CupertinoButton.filled(
                            onPressed: () {
                              setState(() {
                                _minAmount = double.tryParse(minCtrl.text);
                                _maxAmount = double.tryParse(maxCtrl.text);
                                _typeFilter = tempType;
                              });
                              _saveFilterPrefs();
                              Navigator.pop(ctx);
                            },
                            child: const Text('Apply'),
                          ),
                        ),
                      ],
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

  Future<void> _exportCsv(List<Transaction> transactions) async {
    if (_isExportingCsv) return;
    setState(() => _isExportingCsv = true);
    try {
      final buffer = StringBuffer();
      // Header
      buffer.writeln(
          'Date,Type,Summary,Amount,Account,Merchant,Description,Category,Tags');
      for (final t in transactions) {
        final meta = t.metadata ?? {};
        final row = [
          DateFormatter.formatWithTime(t.dateTime),
          t.getTypeLabel(),
          _escapeCsv(t.getSummary()),
          t.amount.toStringAsFixed(2),
          _escapeCsv(
              (meta['accountName'] ?? t.sourceAccountName ?? '').toString()),
          _escapeCsv((meta['merchant'] ?? '').toString()),
          _escapeCsv((meta['description'] ?? t.description).toString()),
          _escapeCsv((meta['categoryName'] ?? '').toString()),
          _escapeCsv((meta['tags'] as List?)?.join('; ') ?? ''),
        ].join(',');
        buffer.writeln(row);
      }
      final dir = await getApplicationDocumentsDirectory();
      final reportsDir = Directory('${dir.path}/reports')
        ..createSync(recursive: true);
      final ts = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .substring(0, 19);
      final file = File('${reportsDir.path}/transactions_$ts.csv');
      await file.writeAsString(buffer.toString());
      if (!mounted) return;
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/csv')],
        subject: 'Transactions Export',
      );
      // Clean up temp file after sharing
      try { await file.delete(); } catch (_) {}
    } catch (e) {
      if (mounted) toast_lib.toast.showError('Export failed: $e');
    } finally {
      if (mounted) setState(() => _isExportingCsv = false);
    }
  }

  Future<void> _exportPdf(List<Transaction> transactions) async {
    if (_isExportingPdf) return;
    setState(() => _isExportingPdf = true);
    try {
      final file = await TransactionExportService.buildPdf(
        transactions,
        title: widget.filterAccountName ?? 'Transaction History',
        accountName: widget.filterAccountName,
      );
      if (!mounted) return;
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/pdf')],
        subject: '${widget.filterAccountName ?? 'Transactions'} — PDF Export',
      );
      try { await file.delete(); } catch (_) {}
    } catch (e) {
      if (mounted) toast_lib.toast.showError('PDF export failed: $e');
    } finally {
      if (mounted) setState(() => _isExportingPdf = false);
    }
  }

  Future<void> _exportXlsx(List<Transaction> transactions) async {
    if (_isExportingXlsx) return;
    setState(() => _isExportingXlsx = true);
    try {
      final file = await TransactionExportService.buildXlsx(
        transactions,
        title: widget.filterAccountName ?? 'Transaction History',
        accountName: widget.filterAccountName,
      );
      if (!mounted) return;
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')],
        subject: '${widget.filterAccountName ?? 'Transactions'} — Excel Export',
      );
      try { await file.delete(); } catch (_) {}
    } catch (e) {
      if (mounted) toast_lib.toast.showError('Excel export failed: $e');
    } finally {
      if (mounted) setState(() => _isExportingXlsx = false);
    }
  }

  void _showExportSheet(BuildContext context, List<Transaction> transactions) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Export Transactions'),
        message: Text('${transactions.length} transaction${transactions.length == 1 ? '' : 's'} will be exported'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _exportPdf(transactions);
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.doc_richtext, color: CupertinoColors.systemRed),
                SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Export as PDF', style: TextStyle(fontWeight: FontWeight.w600)),
                    Text('Styled report with logo & summary', style: TextStyle(fontSize: 12, color: CupertinoColors.systemGrey)),
                  ],
                ),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _exportXlsx(transactions);
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.square_grid_2x2, color: CupertinoColors.systemGreen),
                SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Export as Excel (.xlsx)', style: TextStyle(fontWeight: FontWeight.w600)),
                    Text('Spreadsheet with colour coding', style: TextStyle(fontSize: 12, color: CupertinoColors.systemGrey)),
                  ],
                ),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _exportCsv(transactions);
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.doc_plaintext, color: CupertinoColors.systemBlue),
                SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Export as CSV', style: TextStyle(fontWeight: FontWeight.w600)),
                    Text('Plain comma-separated values', style: TextStyle(fontSize: 12, color: CupertinoColors.systemGrey)),
                  ],
                ),
              ],
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          isDefaultAction: true,
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  String _escapeCsv(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  String _formatDate(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final txnDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (txnDate == today) {
      return 'Today ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (txnDate == yesterday) {
      return 'Yesterday';
    } else {
      return '${dateTime.day} ${DateFormatter.getMonthName(dateTime.month)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppStyles.getBackground(context),
      navigationBar: CupertinoNavigationBar(
        middle: Text(
            widget.filterAccountName ?? 'Transaction History',
            style: TextStyle(color: AppStyles.getTextColor(context))),
        previousPageTitle: 'Back',
        backgroundColor: AppStyles.getBackground(context),
        border: null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              onPressed: () => _showFilterSheet(context),
              child: Icon(
                _hasActiveFilter
                    ? CupertinoIcons.line_horizontal_3_decrease_circle_fill
                    : CupertinoIcons.line_horizontal_3_decrease_circle,
                size: 22,
                color: _hasActiveFilter
                    ? AppStyles.getPrimaryColor(context)
                    : AppStyles.getSecondaryTextColor(context),
              ),
            ),
            // F22: CSV Export
            Consumer2<TransactionsController, InvestmentsController>(
              builder: (ctx, txCtrl, invCtrl, _) {
                final all = TransactionFeedBuilder.buildUnifiedFeed(
                  transactions: txCtrl.transactions,
                  investments: invCtrl.investments,
                );
                final filtered = _filterBySearch(all);
                return CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  onPressed: (_isExportingCsv || _isExportingPdf || _isExportingXlsx) || filtered.isEmpty
                      ? null
                      : () => _showExportSheet(context, filtered),
                  child: _isExportingCsv || _isExportingPdf || _isExportingXlsx
                      ? const CupertinoActivityIndicator(radius: 10)
                      : Icon(
                          CupertinoIcons.share,
                          size: 20,
                          color: AppStyles.getSecondaryTextColor(ctx),
                        ),
                );
              },
            ),
          ],
        ),
      ),
      child: Consumer2<TransactionsController, InvestmentsController>(
        builder:
            (context, transactionsController, investmentsController, child) {
          final allTransactions = TransactionFeedBuilder.buildUnifiedFeed(
            transactions: transactionsController.transactions,
            investments: investmentsController.investments,
          );
          final transactions = _filterBySearch(allTransactions);

          if (allTransactions.isEmpty) {
            return const EmptyStateView(
              icon: CupertinoIcons.doc_text,
              title: 'No Transactions Yet',
              subtitle: 'Transfers and other transactions will appear here',
              actionLabel: null,
            );
          }

          return SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      Spacing.lg, Spacing.lg, Spacing.lg, Spacing.sm),
                  child: CupertinoSearchTextField(
                    controller: _searchController,
                    placeholder: 'Search transactions',
                    onChanged: (v) => setState(() {
                      _searchQuery = v;
                      _visibleCount = _pageSize;
                    }),
                    onSubmitted: (v) => setState(() {
                      _searchQuery = v;
                      _visibleCount = _pageSize;
                    }),
                  ),
                ),
                _buildDateChips(),
                if (_hasActiveFilter)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                        Spacing.lg, 0, Spacing.lg, Spacing.sm),
                    child: Row(
                      children: [
                        Icon(
                            CupertinoIcons
                                .line_horizontal_3_decrease_circle_fill,
                            size: 14,
                            color: AppStyles.getPrimaryColor(context)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            [
                              if (_typeFilter != null)
                                _typeFilter!.name[0].toUpperCase() +
                                    _typeFilter!.name.substring(1),
                              if (_minAmount != null)
                                '≥₹${_minAmount!.toStringAsFixed(0)}',
                              if (_maxAmount != null)
                                '≤₹${_maxAmount!.toStringAsFixed(0)}',
                            ].join(' · '),
                            style: TextStyle(
                              fontSize: TypeScale.caption,
                              color: AppStyles.getPrimaryColor(context),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _minAmount = null;
                              _maxAmount = null;
                              _typeFilter = null;
                              _dateFilter = _DateRangeFilter.all;
                            });
                            _saveFilterPrefs();
                          },
                          child: Icon(
                            CupertinoIcons.xmark_circle_fill,
                            size: 16,
                            color: AppStyles.getSecondaryTextColor(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (transactions.isNotEmpty)
                  _buildSummaryStrip(transactions),
                if (transactions.isEmpty)
                  Expanded(
                    child: _searchQuery.isNotEmpty
                        ? _buildNoSearchResults()
                        : Center(
                            child: Text(
                              _hasActiveFilter
                                  ? 'No transactions match the current filter'
                                  : 'No transactions found',
                              style: TextStyle(
                                  color: AppStyles.getSecondaryTextColor(
                                      context)),
                            ),
                          ),
                  )
                else
                  Expanded(
                    child: _buildGroupedList(
                        context, transactions, transactionsController),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDateChips() {
    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
        children: _DateRangeFilter.values.map((filter) {
          final selected = _dateFilter == filter;
          return GestureDetector(
            onTap: () => setState(() {
              _dateFilter = filter;
              _visibleCount = _pageSize;
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(right: 8, bottom: 4),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: selected
                    ? AppStyles.getPrimaryColor(context)
                    : AppStyles.getCardColor(context),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected
                      ? AppStyles.getPrimaryColor(context)
                      : AppStyles.getDividerColor(context),
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: AppStyles.getPrimaryColor(context)
                              .withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Text(
                filter.label,
                style: TextStyle(
                  color: selected
                      ? CupertinoColors.white
                      : AppStyles.getSecondaryTextColor(context),
                  fontSize: TypeScale.footnote,
                  fontWeight:
                      selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSummaryStrip(List<Transaction> transactions) {
    double totalIncome = 0;
    double totalExpense = 0;
    for (final t in transactions) {
      final eventType = t.metadata?['investmentEventType'] as String?;
      final isSellOrDividend =
          eventType == 'dividend' || eventType == 'sell' || eventType == 'decrease' || eventType == 'redeem';
      if (t.type == TransactionType.income || isSellOrDividend) {
        totalIncome += t.amount;
      } else if (t.type == TransactionType.expense) {
        totalExpense += t.amount;
      }
    }
    final net = totalIncome - totalExpense;
    final netPositive = net >= 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.lg, 0, Spacing.lg, Spacing.md),
      child: Container(
        decoration: BoxDecoration(
          color: AppStyles.getCardColor(context),
          borderRadius: BorderRadius.circular(Radii.xl),
          border: Border.all(color: AppStyles.getDividerColor(context)),
        ),
        padding: const EdgeInsets.symmetric(vertical: Spacing.md),
        child: IntrinsicHeight(
          child: Row(
            children: [
              _buildStatCell(
                label: 'Income',
                value: totalIncome,
                color: AppStyles.gain(context),
                icon: CupertinoIcons.arrow_down_circle_fill,
              ),
              VerticalDivider(
                width: 1,
                thickness: 1,
                color: AppStyles.getDividerColor(context),
              ),
              _buildStatCell(
                label: 'Expenses',
                value: totalExpense,
                color: CupertinoColors.systemRed,
                icon: CupertinoIcons.arrow_up_circle_fill,
              ),
              VerticalDivider(
                width: 1,
                thickness: 1,
                color: AppStyles.getDividerColor(context),
              ),
              _buildStatCell(
                label: 'Net',
                value: net.abs(),
                color: netPositive ? AppStyles.gain(context) : CupertinoColors.systemRed,
                icon: netPositive
                    ? CupertinoIcons.chart_bar_alt_fill
                    : CupertinoIcons.arrow_down_right_circle_fill,
                prefix: netPositive ? '+₹' : '-₹',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCell({
    required String label,
    required double value,
    required Color color,
    required IconData icon,
    String? prefix,
  }) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color.withValues(alpha: 0.8)),
          const SizedBox(height: 4),
          counter_widgets.AnimatedCounter(
            value: value,
            prefix: prefix ?? '₹',
            decimalPlaces: 0,
            textStyle: TextStyle(
              fontSize: TypeScale.footnote,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: TypeScale.caption,
              color: AppStyles.getSecondaryTextColor(context),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
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
            }),
            child: const Text('Clear Search'),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupedList(
    BuildContext context,
    List<Transaction> transactions,
    TransactionsController controller,
  ) {
    // Build a flat list of headers + transactions (all items, for grouping).
    final groups = DateFormatter.groupByDate(transactions, (t) => t.dateTime);
    // Compute per-group totals for the date headers.
    final Map<String, ({int count, double expense, double income})> groupStats = {};
    for (final entry in groups.entries) {
      double exp = 0;
      double inc = 0;
      for (final t in entry.value) {
        final evtType = t.metadata?['investmentEventType'] as String?;
        final isInflow = t.type == TransactionType.income ||
            evtType == 'dividend' || evtType == 'sell' ||
            evtType == 'decrease' || evtType == 'redeem';
        if (isInflow) {
          inc += t.amount;
        } else if (t.type == TransactionType.expense) {
          exp += t.amount;
        }
      }
      groupStats[entry.key] = (count: entry.value.length, expense: exp, income: inc);
    }
    final allItems = <_TxnListItem>[];
    for (final entry in groups.entries) {
      allItems.add(_TxnListItem.header(entry.key));
      for (final t in entry.value) {
        allItems.add(_TxnListItem.transaction(t));
      }
    }

    // Pagination: show only the first _visibleCount *transaction* rows.
    // Walk through allItems keeping a transaction counter so headers for
    // visible transactions are included but we stop after _visibleCount txns.
    int txnCount = 0;
    int cutoff = allItems.length;
    for (int i = 0; i < allItems.length; i++) {
      if (!allItems[i].isHeader) {
        txnCount++;
        if (txnCount == _visibleCount) {
          cutoff = i + 1;
          break;
        }
      }
    }
    final listItems = allItems.sublist(0, cutoff);
    final hasMore = transactions.length > _visibleCount;
    final remaining = transactions.length - _visibleCount;

    return Stack(
      children: [
        RefreshIndicator(
      onRefresh: () async {
        // Trigger a UI refresh
        if (mounted) setState(() {});
      },
      child: ListView.builder(
        controller: _scrollController,
        physics: const SmoothScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        cacheExtent: 600,
        padding: const EdgeInsets.fromLTRB(
            Spacing.lg, Spacing.sm, Spacing.lg, Spacing.xxxl),
        itemCount: listItems.length + (hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          // "Load More" button appended after the last visible item
          if (hasMore && index == listItems.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: CupertinoButton(
                onPressed: () =>
                    setState(() => _visibleCount += _pageSize),
                child: Text(
                  'Load ${min(_pageSize, remaining)} more',
                  style: TextStyle(
                    color: AppStyles.getPrimaryColor(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          }
          final item = listItems[index];
          if (item.isHeader) {
            final stats = groupStats[item.header!];
            final dayExpense = stats?.expense ?? 0;
            final dayIncome = stats?.income ?? 0;
            final dayCount = stats?.count ?? 0;
            return Padding(
              key: ValueKey('h_${item.header}'),
              padding: EdgeInsets.only(
                  top: index == 0 ? 0 : Spacing.lg, bottom: Spacing.sm),
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 13,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [AppStyles.accentBlue, AppStyles.teal(context)],
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    item.header!,
                    style: TextStyle(
                      fontSize: TypeScale.caption,
                      fontWeight: FontWeight.w700,
                      color: AppStyles.getSecondaryTextColor(context),
                      letterSpacing: 0.7,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '· $dayCount',
                    style: TextStyle(
                      fontSize: TypeScale.caption,
                      color: AppStyles.getSecondaryTextColor(context)
                          .withValues(alpha: 0.5),
                    ),
                  ),
                  const Spacer(),
                  if (dayIncome > 0)
                    Text(
                      '+₹${dayIncome.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: TypeScale.caption,
                        fontWeight: FontWeight.w600,
                        color: AppStyles.gain(context).withValues(alpha: 0.8),
                      ),
                    ),
                  if (dayIncome > 0 && dayExpense > 0)
                    Text(
                      '  ',
                      style: TextStyle(
                        fontSize: TypeScale.caption,
                        color: AppStyles.getDividerColor(context),
                      ),
                    ),
                  if (dayExpense > 0)
                    Text(
                      '-₹${dayExpense.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: TypeScale.caption,
                        fontWeight: FontWeight.w600,
                        color: CupertinoColors.systemRed
                            .withValues(alpha: 0.75),
                      ),
                    ),
                ],
              ),
            );
          }
          final txn = item.transaction!;
          return StaggeredItem(
            key: ValueKey(txn.id),
            index: index,
            child: _buildTransactionCard(context, txn, controller),
          );
        },
      ),
        ),
        if (_showScrollToTop)
          Positioned(
            bottom: 80,
            left: 16,
            child: AnimatedOpacity(
              opacity: _showScrollToTop ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
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
                        color: AppStyles.teal(context).withValues(alpha: 0.5)),
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
      ],
    );
  }

  Widget _buildTransactionCard(
    BuildContext context,
    Transaction transaction,
    TransactionsController controller,
  ) {
    final eventType = transaction.metadata?['investmentEventType'] as String?;
    final isDividend = eventType == 'dividend';
    final isSell = eventType == 'sell' || eventType == 'decrease' || eventType == 'redeem';
    final typeColor = isDividend
        ? const Color(0xFFFFB800) // amber for dividends
        : isSell
            ? AppStyles.gain(context)
            : transaction.type.typeColor;
    final typeIcon = isDividend
        ? CupertinoIcons.money_dollar_circle_fill
        : isSell
            ? CupertinoIcons.arrow_up_circle_fill
            : transaction.type.typeIcon;

    final isDerived = TransactionFeedBuilder.isDerivedInvestmentEvent(transaction);
    final archiveCtrl = Provider.of<TransactionsArchiveController>(context, listen: false);

    return Slidable(
      key: ValueKey('slide_${transaction.id}'),
      endActionPane: isDerived
          ? null
          : ActionPane(
              motion: const DrawerMotion(),
              extentRatio: 0.22,
              children: [
                SlidableAction(
                  onPressed: (_) =>
                      _archiveTransaction(transaction, controller, archiveCtrl),
                  backgroundColor: AppStyles.teal(context),
                  foregroundColor: CupertinoColors.white,
                  icon: CupertinoIcons.archivebox_fill,
                  borderRadius: BorderRadius.circular(Radii.lg),
                ),
              ],
            ),
      child: BouncyButton(
        onPressed: () => _showTransactionDetails(
          context,
          transaction,
          controller,
          allowArchive: !isDerived,
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: Spacing.md),
        decoration: AppStyles.accentCardDecoration(context, typeColor),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(Radii.xxl),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left accent bar
                Container(
                  width: 3,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [typeColor, typeColor.withValues(alpha: 0.40)],
                    ),
                  ),
                ),
                // Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: Spacing.md, vertical: Spacing.md),
                    child: Row(
                      children: [
                        // Icon
                        Container(
                          width: 44,
                          height: 44,
                          decoration:
                              AppStyles.iconBoxDecoration(context, typeColor),
                          child: Icon(typeIcon, color: typeColor, size: 20),
                        ),
                        const SizedBox(width: Spacing.md),

                        // Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                transaction.getTypeLabel(),
                                style: TextStyle(
                                  fontSize: TypeScale.callout,
                                  fontWeight: FontWeight.w700,
                                  color: AppStyles.getTextColor(context),
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                transaction.getSummary(),
                                style: TextStyle(
                                  fontSize: TypeScale.footnote,
                                  color:
                                      AppStyles.getSecondaryTextColor(context),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (transaction.type == TransactionType.transfer &&
                                  (transaction.metadata?['transferRef'] as String?)?.isNotEmpty == true) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppStyles.teal(context)
                                            .withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: AppStyles.teal(context)
                                              .withValues(alpha: 0.35),
                                          width: 0.5,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            CupertinoIcons.arrow_right_arrow_left,
                                            size: 9,
                                            color: AppStyles.teal(context),
                                          ),
                                          const SizedBox(width: 3),
                                          Text(
                                            'Transfer',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: AppStyles.teal(context),
                                              letterSpacing: 0.2,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 2),
                              Text(
                                _formatDate(transaction.dateTime),
                                style: TextStyle(
                                  fontSize: TypeScale.caption,
                                  color: AppStyles.getSecondaryTextColor(
                                          context)
                                      .withValues(alpha: 0.60),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Amount
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${transaction.type == TransactionType.expense ? '−' : '+'}${CurrencyFormatter.compact(transaction.amount)}',
                              style: TextStyle(
                                fontSize: TypeScale.title3,
                                fontWeight: FontWeight.w800,
                                color: typeColor,
                                letterSpacing: -0.4,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Icon(
                              CupertinoIcons.chevron_right,
                              size: 11,
                              color: AppStyles.getSecondaryTextColor(context)
                                  .withValues(alpha: 0.50),
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
  }

  void _showTransactionDetails(
    BuildContext context,
    Transaction transaction,
    TransactionsController controller, {
    required bool allowArchive,
  }) {
    final archiveController =
        Provider.of<TransactionsArchiveController>(context, listen: false);

    showCupertinoModalPopup(
      context: context,
      builder: (modalContext) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          builder: (dragContext, scrollController) {
            return Container(
              decoration: AppStyles.bottomSheetDecoration(dragContext),
              child: SingleChildScrollView(
                controller: scrollController,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const ModalHandle(),
                    TransactionDetailsContent(
                      transaction: transaction,
                      actionButtons: [
                        CupertinoButton(
                          onPressed: () {
                            Navigator.pop(modalContext);
                            Navigator.push(
                              context,
                              FadeScalePageRoute(
                                page: TransactionWizard(cloneFrom: transaction),
                              ),
                            );
                          },
                          child: const Text('Clone Transaction'),
                        ),
                        if (allowArchive)
                          _buildDeleteAction(
                            context,
                            modalContext,
                            transaction,
                            controller,
                            archiveController,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDeleteAction(
    BuildContext context,
    BuildContext modalContext,
    Transaction transaction,
    TransactionsController controller,
    TransactionsArchiveController archiveController,
  ) {
    return BouncyButton(
      onPressed: () {
        Navigator.pop(modalContext);
        _showDeleteConfirmation(
            context, transaction, controller, archiveController);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppStyles.loss(context).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.trash,
              size: 16,
              color: AppStyles.loss(context),
            ),
            const SizedBox(width: 6),
            Text(
              'Delete Transaction',
              style: TextStyle(
                color: AppStyles.loss(context),
                fontSize: TypeScale.body,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(
    BuildContext context,
    Transaction transaction,
    TransactionsController controller,
    TransactionsArchiveController archiveController,
  ) {
    showCupertinoDialog(
      context: context,
      builder: (dialogContext) {
        return CupertinoAlertDialog(
          title: const Text('Delete Transaction'),
          content: const Text(
              'This will move the transaction to Archived. Continue?'),
          actions: [
            CupertinoDialogAction(
              child: const Text('Cancel'),
              onPressed: () => Navigator.pop(dialogContext),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              child: const Text('Archive'),
              onPressed: () async {
                Haptics.delete();
                await _archiveTransaction(
                    transaction, controller, archiveController);
                Navigator.pop(dialogContext);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _archiveTransaction(
    Transaction transaction,
    TransactionsController controller,
    TransactionsArchiveController archiveController,
  ) async {
    await archiveController.addToArchive(transaction);
    await controller.removeTransaction(transaction.id);
    logger.info('Archived transaction: ${transaction.id}',
        context: 'TransactionHistory');
    toast_lib.toast.show(toast_lib.ToastData(
      message: 'Transaction archived',
      type: toast_lib.ToastType.success,
      actionLabel: 'Undo',
      duration: const Duration(seconds: 4),
      onAction: () async {
        await archiveController.removeFromArchive(transaction.id);
        await controller.addTransaction(transaction);
        toast_lib.toast.showInfo('Restored');
      },
    ));
  }
}

class _TxnListItem {
  final String? header;
  final Transaction? transaction;

  const _TxnListItem.header(this.header) : transaction = null;
  const _TxnListItem.transaction(this.transaction) : header = null;

  bool get isHeader => header != null;
}
