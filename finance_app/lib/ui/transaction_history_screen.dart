import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show RefreshIndicator;
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

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool get _hasActiveFilter =>
      _minAmount != null || _maxAmount != null || _typeFilter != null;

  List<Transaction> _filterBySearch(List<Transaction> txns) {
    var result = txns;
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
            decoration: BoxDecoration(
              color: AppStyles.getCardColor(ctx),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
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
                        final label =
                            type == null ? 'All' : type.name[0].toUpperCase() + type.name.substring(1);
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
                            style: TextStyle(
                                color: AppStyles.getTextColor(ctx)),
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
                            style: TextStyle(
                                color: AppStyles.getTextColor(ctx)),
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
                              });
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
        middle: Text('Transaction History',
            style: TextStyle(color: AppStyles.getTextColor(context))),
        previousPageTitle: 'Dashboard',
        backgroundColor: AppStyles.getBackground(context),
        border: null,
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
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
            return EmptyStateView(
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
                  padding: EdgeInsets.fromLTRB(
                      Spacing.lg, Spacing.lg, Spacing.lg, Spacing.sm),
                  child: CupertinoSearchTextField(
                    controller: _searchController,
                    placeholder: 'Search transactions',
                    onChanged: (v) => setState(() => _searchQuery = v),
                    onSubmitted: (v) => setState(() => _searchQuery = v),
                  ),
                ),
                if (_hasActiveFilter)
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                        Spacing.lg, 0, Spacing.lg, Spacing.sm),
                    child: Row(
                      children: [
                        Icon(
                            CupertinoIcons.line_horizontal_3_decrease_circle_fill,
                            size: 14,
                            color: AppStyles.getPrimaryColor(context)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            [
                              if (_typeFilter != null)
                                _typeFilter!.name[0].toUpperCase() +
                                    _typeFilter!.name.substring(1),
                              if (_minAmount != null) '≥₹${_minAmount!.toStringAsFixed(0)}',
                              if (_maxAmount != null) '≤₹${_maxAmount!.toStringAsFixed(0)}',
                            ].join(' · '),
                            style: TextStyle(
                              fontSize: TypeScale.caption,
                              color: AppStyles.getPrimaryColor(context),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => setState(() {
                            _minAmount = null;
                            _maxAmount = null;
                            _typeFilter = null;
                          }),
                          child: Icon(
                            CupertinoIcons.xmark_circle_fill,
                            size: 16,
                            color: AppStyles.getSecondaryTextColor(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (transactions.isEmpty)
                  Expanded(
                    child: Center(
                      child: Text(
                          _hasActiveFilter || _searchQuery.isNotEmpty
                              ? 'No transactions match the current filter'
                              : 'No transactions found',
                          style: TextStyle(
                              color: AppStyles.getSecondaryTextColor(context))),
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

  Widget _buildGroupedList(
    BuildContext context,
    List<Transaction> transactions,
    TransactionsController controller,
  ) {
    final groups = DateFormatter.groupByDate(transactions, (t) => t.dateTime);
    final listItems = <_TxnListItem>[];
    for (final entry in groups.entries) {
      listItems.add(_TxnListItem.header(entry.key));
      for (final t in entry.value) {
        listItems.add(_TxnListItem.transaction(t));
      }
    }

    return RefreshIndicator(
      onRefresh: () async {
        // Trigger a UI refresh
        if (mounted) setState(() {});
      },
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
            Spacing.lg, Spacing.sm, Spacing.lg, Spacing.xxxl),
        itemCount: listItems.length,
        itemBuilder: (context, index) {
          final item = listItems[index];
          if (item.isHeader) {
            return Padding(
              key: ValueKey('h_${item.header}'),
              padding: EdgeInsets.only(
                  top: index == 0 ? 0 : Spacing.lg, bottom: Spacing.sm),
              child: Text(
                item.header!,
                style: TextStyle(
                  fontSize: TypeScale.footnote,
                  fontWeight: FontWeight.w600,
                  color: AppStyles.getSecondaryTextColor(context),
                  letterSpacing: 0.5,
                ),
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
    );
  }

  Widget _buildTransactionCard(
    BuildContext context,
    Transaction transaction,
    TransactionsController controller,
  ) {
    final typeColor = transaction.type.typeColor;
    final typeIcon = transaction.type.typeIcon;

    return BouncyButton(
      onPressed: () => _showTransactionDetails(
        context,
        transaction,
        controller,
        allowArchive: !TransactionFeedBuilder.isDerivedInvestmentEvent(
          transaction,
        ),
      ),
      child: Container(
        margin: EdgeInsets.only(bottom: Spacing.lg),
        decoration: AppStyles.cardDecoration(context),
        child: Padding(
          padding: EdgeInsets.all(Spacing.lg),
          child: Row(
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(Spacing.md),
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  typeIcon,
                  color: typeColor,
                  size: 24,
                ),
              ),
              SizedBox(width: Spacing.lg),

              // Transaction info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.getTypeLabel(),
                      style: AppStyles.titleStyle(context),
                    ),
                    SizedBox(height: Spacing.xs),
                    Text(
                      transaction.getSummary(),
                      style: TextStyle(
                        fontSize: TypeScale.footnote,
                        color: AppStyles.getSecondaryTextColor(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: Spacing.xs),
                    Text(
                      _formatDate(transaction.dateTime),
                      style: TextStyle(
                        fontSize: TypeScale.caption,
                        color: AppStyles.getSecondaryTextColor(context)
                            .withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),

              // Amount
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  AnimatedCounter(
                    value: transaction.amount,
                    prefix: '₹',
                    decimals: 2,
                    duration: AppDurations.counter,
                    style: AppStyles.titleStyle(context).copyWith(
                      color: typeColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: Spacing.xs),
                  Icon(
                    CupertinoIcons.chevron_right,
                    size: IconSizes.xs,
                    color: AppStyles.getSecondaryTextColor(context),
                  ),
                ],
              ),
            ],
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
          minChildSize: 0.5,
          maxChildSize: 0.9,
          builder: (dragContext, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: AppStyles.getCardColor(dragContext),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                controller: scrollController,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemGrey3,
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                    TransactionDetailsContent(
                      transaction: transaction,
                      actionButtons: [
                        CupertinoButton(
                          onPressed: () {
                            Navigator.pop(modalContext);
                            Navigator.push(
                              context,
                              CupertinoPageRoute(
                                builder: (_) => TransactionWizard(
                                    cloneFrom: transaction),
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
          color: CupertinoColors.systemRed.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.trash,
              size: 16,
              color: CupertinoColors.systemRed,
            ),
            const SizedBox(width: 6),
            Text(
              'Delete Transaction',
              style: TextStyle(
                color: CupertinoColors.systemRed,
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
    toast_lib.toast.showSuccess('Transaction archived');
    logger.info('Archived transaction: ${transaction.id}',
        context: 'TransactionHistory');
  }
}

class _TxnListItem {
  final String? header;
  final Transaction? transaction;

  const _TxnListItem.header(this.header) : transaction = null;
  const _TxnListItem.transaction(this.transaction) : header = null;

  bool get isHeader => header != null;
}
