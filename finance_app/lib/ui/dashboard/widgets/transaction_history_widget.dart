import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/dashboard_widget_model.dart';
import 'package:vittara_fin_os/logic/transactions_controller.dart';
import 'package:vittara_fin_os/ui/dashboard/base_dashboard_widget.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';

class TransactionHistoryWidget extends BaseDashboardWidget {
  const TransactionHistoryWidget({
    required DashboardWidgetConfig config,
    VoidCallback? onTap,
    super.key,
  }) : super(config: config, onTap: onTap);

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

    return Consumer<TransactionsController>(
      builder: (context, transactionController, child) {
        final transactions = transactionController.transactions.take(txCount).toList();

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
          children: transactions
              .asMap()
              .entries
              .map((entry) {
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
              })
              .toList(),
        );
      },
    );
  }

  Widget _buildTransactionItem(
    BuildContext context,
    dynamic transaction, {
    bool compact = false,
  }) {
    final amount = transaction.amount ?? 0;
    final description = transaction.description ?? 'Transaction';
    final category = transaction.category?.name ?? 'Other';
    final isExpense = amount < 0;
    final displayAmount = amount.abs();

    // Get category color
    Color getCategoryColor(String categoryName) {
      switch (categoryName.toLowerCase()) {
        case 'groceries':
        case 'food':
          return Colors.green;
        case 'transport':
        case 'fuel':
          return Colors.orange;
        case 'entertainment':
          return Colors.purple;
        case 'shopping':
          return Colors.pink;
        case 'utilities':
          return Colors.blue;
        case 'salary':
        case 'income':
          return Colors.green;
        default:
          return Colors.grey;
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
                    color: categoryColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    isExpense ? CupertinoIcons.arrow_up : CupertinoIcons.arrow_down,
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
                  '${isExpense ? '-' : '+'}₹${displayAmount.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isExpense ? Colors.red : Colors.green,
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
          color: categoryColor.withOpacity(0.1),
        ),
      ),
      child: Row(
        children: [
          // Category Icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: categoryColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isExpense ? CupertinoIcons.arrow_up : CupertinoIcons.arrow_down,
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
                        color: categoryColor.withOpacity(0.15),
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
            '${isExpense ? '-' : '+'}₹${displayAmount.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isExpense ? Colors.red : Colors.green,
            ),
          ),
        ],
      ),
    );
  }
}
