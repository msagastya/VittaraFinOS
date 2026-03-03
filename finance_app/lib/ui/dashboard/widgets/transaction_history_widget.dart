import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/investments_controller.dart';
import 'package:vittara_fin_os/logic/transaction_model.dart';
import 'package:vittara_fin_os/logic/transaction_feed_builder.dart';
import 'package:vittara_fin_os/logic/transactions_controller.dart';
import 'package:vittara_fin_os/ui/dashboard/base_dashboard_widget.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';

class TransactionHistoryWidget extends BaseDashboardWidget {
  const TransactionHistoryWidget({
    required super.config,
    super.onTap,
    super.key,
  });

  @override
  Widget buildHeader(BuildContext context, {bool compact = false}) {
    return Row(
      children: [
        Icon(
          CupertinoIcons.doc_text_fill,
          size: compact ? 16 : 18,
          color: AppStyles.getPrimaryColor(context),
        ),
        SizedBox(width: Spacing.sm),
        Expanded(
          child: Text(
            config.title,
            style: TextStyle(
              fontSize: compact ? 14 : 16,
              fontWeight: FontWeight.bold,
              color: AppStyles.getTextColor(context),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  @override
  Widget buildContent(
    BuildContext context, {
    required int columnSpan,
    required int rowSpan,
    required double width,
    required double height,
  }) {
    // Determine how many transactions to show based on space
    // Compact (1 col, 1 row): 1 transaction
    // Compact (1 col, 2+ rows): 2-3 transactions
    // Medium (2 cols, 1 row): 2 transactions
    // Medium (2 cols, 2+ rows): 4 transactions
    // Full (3 cols, 1 row): 3 transactions
    // Full (3 cols, 2+ rows): 5-6 transactions

    int txCount = 2;
    if (columnSpan == 1 && rowSpan == 1) txCount = 1;
    if (columnSpan == 1 && rowSpan >= 2) txCount = 2;
    if (columnSpan == 2 && rowSpan == 1) txCount = 2;
    if (columnSpan == 2 && rowSpan >= 2) txCount = 4;
    if (columnSpan == 3 && rowSpan == 1) txCount = 3;
    if (columnSpan == 3 && rowSpan >= 2) txCount = 5;

    return Consumer2<TransactionsController, InvestmentsController>(
      builder: (context, transactionController, investmentsController, child) {
        final transactions = TransactionFeedBuilder.buildUnifiedFeed(
          transactions: transactionController.transactions,
          investments: investmentsController.investments,
        ).take(txCount).toList();

        if (transactions.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  CupertinoIcons.doc_text,
                  size: columnSpan == 1 ? 28 : 40,
                  color: AppStyles.getSecondaryTextColor(context),
                ),
                SizedBox(height: Spacing.sm),
                Text(
                  'No transactions',
                  style: TextStyle(
                    fontSize: columnSpan == 1 ? 11 : 13,
                    color: AppStyles.getSecondaryTextColor(context),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: transactions.asMap().entries.map((entry) {
            final isLast = entry.key == transactions.length - 1;
            return Column(
              children: [
                _buildTransactionItem(
                  context,
                  entry.value,
                  compact: columnSpan == 1,
                ),
                if (!isLast) Divider(height: 12),
              ],
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildTransactionItem(
    BuildContext context,
    Transaction transaction, {
    bool compact = false,
  }) {
    final amount = transaction.amount;
    final description = transaction.description;
    final metadata = transaction.metadata ?? const <String, dynamic>{};
    final category =
        (metadata['categoryName'] as String?) ?? transaction.getTypeLabel();
    final type = transaction.type;
    final amountColor = _getAmountColor(type);
    final displayAmount = amount.abs();
    final amountPrefix = _getAmountPrefix(type);
    final leadingIcon = _getTransactionIcon(type);

    // Get category color
    Color getCategoryColor(String categoryName) {
      switch (categoryName.toLowerCase()) {
        case 'groceries':
        case 'food':
          return CupertinoColors.systemGreen;
        case 'transport':
        case 'fuel':
          return CupertinoColors.systemOrange;
        case 'entertainment':
          return Colors.purple;
        case 'shopping':
          return Colors.pink;
        case 'utilities':
          return CupertinoColors.activeBlue;
        case 'salary':
        case 'income':
          return CupertinoColors.systemGreen;
        default:
          return CupertinoColors.systemGrey;
      }
    }

    final categoryColor = getCategoryColor(category);

    if (compact) {
      // Vertical compact layout
      return Container(
        padding: EdgeInsets.all(Spacing.sm),
        decoration: BoxDecoration(
          color: AppStyles.getCardColor(context),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: categoryColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    leadingIcon,
                    size: 12,
                    color: categoryColor,
                  ),
                ),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    description,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppStyles.getTextColor(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Just now',
                  style: TextStyle(
                    fontSize: 9,
                    color: AppStyles.getSecondaryTextColor(context),
                  ),
                ),
                Text(
                  '$amountPrefix₹${displayAmount.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: amountColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Horizontal layout - Enhanced
    return Container(
      padding: EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: AppStyles.getCardColor(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: categoryColor.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          // Category Icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: categoryColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              leadingIcon,
              size: 18,
              color: categoryColor,
            ),
          ),
          SizedBox(width: Spacing.md),

          // Description and Category
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppStyles.getTextColor(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: categoryColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        category,
                        style: TextStyle(
                          fontSize: 9,
                          color: categoryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Just now',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppStyles.getSecondaryTextColor(context),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Amount
          Text(
            '$amountPrefix₹${displayAmount.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: amountColor,
            ),
          ),
        ],
      ),
    );
  }

  Color _getAmountColor(TransactionType type) {
    switch (type) {
      case TransactionType.expense:
        return CupertinoColors.systemRed;
      case TransactionType.income:
        return CupertinoColors.systemGreen;
      case TransactionType.transfer:
        return CupertinoColors.systemBlue;
      case TransactionType.cashback:
        return CupertinoColors.systemGreen;
      case TransactionType.lending:
        return CupertinoColors.systemOrange;
      case TransactionType.borrowing:
        return CupertinoColors.systemPurple;
      case TransactionType.investment:
        return CupertinoColors.systemIndigo;
    }
  }

  String _getAmountPrefix(TransactionType type) {
    switch (type) {
      case TransactionType.expense:
      case TransactionType.investment:
      case TransactionType.lending:
        return '-';
      case TransactionType.income:
      case TransactionType.cashback:
      case TransactionType.borrowing:
        return '+';
      case TransactionType.transfer:
        return '';
    }
  }

  IconData _getTransactionIcon(TransactionType type) {
    switch (type) {
      case TransactionType.transfer:
        return CupertinoIcons.arrow_right_arrow_left;
      case TransactionType.expense:
        return CupertinoIcons.arrow_down_circle_fill;
      case TransactionType.income:
        return CupertinoIcons.arrow_up_circle_fill;
      case TransactionType.cashback:
        return CupertinoIcons.gift_fill;
      case TransactionType.lending:
        return CupertinoIcons.arrow_up_circle;
      case TransactionType.borrowing:
        return CupertinoIcons.arrow_down_circle;
      case TransactionType.investment:
        return CupertinoIcons.chart_bar_square_fill;
    }
  }
}
