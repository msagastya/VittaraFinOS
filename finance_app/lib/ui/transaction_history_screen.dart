import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/transactions_controller.dart';
import 'package:vittara_fin_os/logic/transaction_model.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/widgets/animations.dart';
import 'package:vittara_fin_os/ui/widgets/common_widgets.dart';
import 'package:vittara_fin_os/utils/logger.dart';

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  State<TransactionHistoryScreen> createState() => _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  final AppLogger logger = AppLogger();

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
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppStyles.getBackground(context),
      navigationBar: CupertinoNavigationBar(
        middle: Text('Transaction History', style: TextStyle(color: AppStyles.getTextColor(context))),
        previousPageTitle: 'Dashboard',
        backgroundColor: AppStyles.getBackground(context),
        border: null,
      ),
      child: Consumer<TransactionsController>(
        builder: (context, transactionsController, child) {
          final transactions = transactionsController.transactions;

          if (transactions.isEmpty) {
            return EmptyStateView(
              icon: CupertinoIcons.doc_text,
              title: 'No Transactions Yet',
              subtitle: 'Transfers and other transactions will appear here',
              actionLabel: null,
            );
          }

          return SafeArea(
            child: ListView.builder(
              padding: EdgeInsets.fromLTRB(Spacing.lg, Spacing.lg, Spacing.lg, Spacing.xxxl),
              itemCount: transactions.length,
              itemBuilder: (context, index) {
                return StaggeredItem(
                  key: ValueKey(transactions[index].id),
                  index: index,
                  child: _buildTransactionCard(context, transactions[index], transactionsController),
                );
              },
            ),
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
      onPressed: () => _showTransactionDetails(context, transaction, controller),
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
                        color: AppStyles.getSecondaryTextColor(context).withValues(alpha: 0.7),
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
    TransactionsController controller,
  ) {
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
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                    const SizedBox(height: 20),

                    // Header with icon and type
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: _getTransactionTypeColor(transaction.type).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              _getTransactionTypeIcon(transaction.type),
                              color: _getTransactionTypeColor(transaction.type),
                              size: 32,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            transaction.getTypeLabel(),
                            style: AppStyles.titleStyle(dragContext).copyWith(fontSize: 20),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatDate(transaction.dateTime),
                            style: TextStyle(
                              color: AppStyles.getSecondaryTextColor(dragContext),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Amount display
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Amount',
                            style: TextStyle(
                              color: AppStyles.getSecondaryTextColor(dragContext),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '₹${transaction.amount.toStringAsFixed(2)}',
                            style: AppStyles.titleStyle(dragContext).copyWith(
                              fontSize: 28,
                              color: _getTransactionTypeColor(transaction.type),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Transaction details based on type
                    if (transaction.type == TransactionType.transfer) ...[
                      _buildDetailRow(dragContext, 'From Account', transaction.sourceAccountName ?? 'Unknown'),
                      _buildDetailRow(dragContext, 'To Account', transaction.destinationAccountName ?? 'Unknown'),
                      _buildDetailRow(dragContext, 'Description', transaction.description),
                      if (transaction.paymentAppName != null)
                        _buildDetailRow(dragContext, 'Payment App', transaction.paymentAppName!),
                      if (transaction.appWalletAmount != null && transaction.appWalletAmount! > 0)
                        _buildDetailRow(
                          dragContext,
                          'Amount from App Wallet',
                          '₹${transaction.appWalletAmount!.toStringAsFixed(2)}',
                        ),
                      if (transaction.charges != null && transaction.charges! > 0)
                        _buildDetailRow(
                          dragContext,
                          'Extra Charges',
                          '₹${transaction.charges!.toStringAsFixed(2)}',
                          isNegative: true,
                        ),
                      if (transaction.cashbackAmount != null && transaction.cashbackAmount! > 0) ...[
                        _buildDetailRow(
                          dragContext,
                          'Cashback Amount',
                          '₹${transaction.cashbackAmount!.toStringAsFixed(2)}',
                          isPositive: true,
                        ),
                        _buildDetailRow(dragContext, 'Cashback to', transaction.cashbackAccountName ?? 'Unknown'),
                      ],
                    ] else if (transaction.type == TransactionType.cashback) ...[
                      _buildDetailRow(dragContext, 'From', transaction.description),
                      _buildDetailRow(dragContext, 'To Account', transaction.cashbackAccountName ?? 'Unknown'),
                    ],

                    const SizedBox(height: 32),

                    // Delete button
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: BouncyButton(
                        onPressed: () {
                          Navigator.pop(modalContext);
                          _showDeleteConfirmation(context, transaction, controller);
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
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        );
      },
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
              fontSize: 14,
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
              fontSize: 14,
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
  ) {
    showCupertinoDialog(
      context: context,
      builder: (dialogContext) {
        return CupertinoAlertDialog(
          title: const Text('Delete Transaction'),
          content: const Text('Are you sure you want to delete this transaction? This action cannot be undone.'),
          actions: [
            CupertinoDialogAction(
              child: const Text('Cancel'),
              onPressed: () => Navigator.pop(dialogContext),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              child: const Text('Delete'),
              onPressed: () {
                Haptics.delete();
                controller.removeTransaction(transaction.id);
                Navigator.pop(dialogContext);
                logger.info('Deleted transaction: ${transaction.id}', context: 'TransactionHistory');
              },
            ),
          ],
        );
      },
    );
  }
}
