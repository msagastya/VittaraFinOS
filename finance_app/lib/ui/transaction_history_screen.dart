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
import 'package:vittara_fin_os/ui/widgets/animations.dart';
import 'package:vittara_fin_os/ui/widgets/common_widgets.dart';
import 'package:vittara_fin_os/ui/widgets/transaction_details_content.dart';
import 'package:vittara_fin_os/ui/widgets/toast_notification.dart' as toast_lib;
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Transaction> _filterBySearch(List<Transaction> txns) {
    if (_searchQuery.isEmpty) return txns;
    final q = _searchQuery.toLowerCase();
    return txns.where((t) {
      return t.getTypeLabel().toLowerCase().contains(q) ||
          t.getSummary().toLowerCase().contains(q) ||
          t.amount.toString().contains(q);
    }).toList();
  }

  Color _getTransactionTypeColor(TransactionType type) {
    switch (type) {
      case TransactionType.transfer:
        return CupertinoColors.systemBlue;
      case TransactionType.cashback:
        return CupertinoColors.systemGreen;
      case TransactionType.lending:
        return CupertinoColors.systemOrange;
      case TransactionType.borrowing:
        return CupertinoColors.systemPurple;
      case TransactionType.investment:
        return CupertinoColors.systemRed;
      case TransactionType.expense:
        return CupertinoColors.systemRed;
      case TransactionType.income:
        return CupertinoColors.systemGreen;
    }
  }

  IconData _getTransactionTypeIcon(TransactionType type) {
    switch (type) {
      case TransactionType.transfer:
        return CupertinoIcons.arrow_right_arrow_left;
      case TransactionType.cashback:
        return CupertinoIcons.gift_fill;
      case TransactionType.lending:
        return CupertinoIcons.arrow_up_circle_fill;
      case TransactionType.borrowing:
        return CupertinoIcons.arrow_down_circle_fill;
      case TransactionType.investment:
        return CupertinoIcons.chart_bar_square_fill;
      case TransactionType.expense:
        return CupertinoIcons.arrow_down_circle_fill;
      case TransactionType.income:
        return CupertinoIcons.arrow_up_circle_fill;
    }
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
      return '${dateTime.day} ${_getMonthName(dateTime.month)}';
    }
  }

  String _getMonthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return months[month - 1];
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
                if (transactions.isEmpty)
                  Expanded(
                    child: Center(
                      child: Text('No transactions match "$_searchQuery"',
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

  Map<String, List<Transaction>> _groupByDate(List<Transaction> txns) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final result = <String, List<Transaction>>{};
    for (final t in txns) {
      final d = DateTime(t.dateTime.year, t.dateTime.month, t.dateTime.day);
      final String label;
      if (d == today) {
        label = 'Today';
      } else if (d == yesterday) {
        label = 'Yesterday';
      } else {
        label =
            '${t.dateTime.day} ${months[t.dateTime.month - 1]} ${t.dateTime.year}';
      }
      result.putIfAbsent(label, () => []).add(t);
    }
    return result;
  }

  Widget _buildGroupedList(
    BuildContext context,
    List<Transaction> transactions,
    TransactionsController controller,
  ) {
    final groups = _groupByDate(transactions);
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
    final typeColor = _getTransactionTypeColor(transaction.type);
    final typeIcon = _getTransactionTypeIcon(transaction.type);

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
                padding: const EdgeInsets.all(12),
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
                      actionButtons: allowArchive
                          ? [
                              _buildDeleteAction(
                                context,
                                modalContext,
                                transaction,
                                controller,
                                archiveController,
                              ),
                            ]
                          : const [],
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

  Widget _buildDetailRow(
    BuildContext context,
    String label,
    String value, {
    bool isPositive = false,
    bool isNegative = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppStyles.getSecondaryTextColor(context),
              fontSize: TypeScale.body,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: isPositive
                  ? CupertinoColors.systemGreen
                  : isNegative
                      ? CupertinoColors.systemRed
                      : AppStyles.getTextColor(context),
              fontSize: TypeScale.body,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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
