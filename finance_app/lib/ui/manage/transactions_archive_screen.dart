import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/accounts_controller.dart';
import 'package:vittara_fin_os/logic/payment_apps_controller.dart';
import 'package:vittara_fin_os/logic/transaction_account_adjuster.dart';
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

class TransactionsArchiveScreen extends StatelessWidget {
  const TransactionsArchiveScreen({super.key});
  static const _loggerContext = 'TransactionsArchive';

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppStyles.getBackground(context),
      navigationBar: CupertinoNavigationBar(
        middle: Text('Archived Transactions',
            style: TextStyle(color: AppStyles.getTextColor(context))),
        previousPageTitle: 'Manage',
        backgroundColor: AppStyles.getBackground(context),
        border: null,
      ),
      child: Consumer4<TransactionsArchiveController, TransactionsController,
          AccountsController, PaymentAppsController>(
        builder: (context, archiveController, transactionsController,
            accountsController, paymentAppsController, child) {
          final archived = archiveController.archived;

          if (archived.isEmpty) {
            return Center(
              child: EmptyStateView(
                icon: CupertinoIcons.archivebox_fill,
                title: 'No Archived Transactions',
                subtitle:
                    'Deleted entries will appear once you archive a transaction',
                actionLabel: null,
              ),
            );
          }

          return SafeArea(
            child: ListView.builder(
              padding: EdgeInsets.fromLTRB(
                  Spacing.lg, Spacing.lg, Spacing.lg, Spacing.xxxl),
              itemCount: archived.length,
              itemBuilder: (context, index) {
                final transaction = archived[index];
                return StaggeredItem(
                  key: ValueKey(transaction.id),
                  index: index,
                  child: _ArchivedTransactionCard(
                    transaction: transaction,
                    accountsController: accountsController,
                    paymentAppsController: paymentAppsController,
                    archiveController: archiveController,
                    transactionsController: transactionsController,
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _ArchivedTransactionCard extends StatelessWidget {
  final Transaction transaction;
  final AccountsController accountsController;
  final PaymentAppsController paymentAppsController;
  final TransactionsArchiveController archiveController;
  final TransactionsController transactionsController;

  const _ArchivedTransactionCard({
    required this.transaction,
    required this.accountsController,
    required this.paymentAppsController,
    required this.archiveController,
    required this.transactionsController,
  });

  @override
  Widget build(BuildContext context) {
    final typeColor = _getTransactionTypeColor(transaction.type);
    final typeIcon = _getTransactionTypeIcon(transaction.type);

    return BouncyButton(
      onPressed: () => _showDetailSheet(context),
      child: Container(
        margin: EdgeInsets.only(bottom: Spacing.lg),
        decoration: AppStyles.cardDecoration(context),
        child: Padding(
          padding: EdgeInsets.all(Spacing.lg),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(typeIcon, color: typeColor, size: 24),
              ),
              const SizedBox(width: 16),
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
                      _formatDate(transaction.dateTime),
                      style: TextStyle(
                        color: AppStyles.getSecondaryTextColor(context),
                        fontSize: TypeScale.caption,
                      ),
                    ),
                    SizedBox(height: Spacing.xs),
                    Text(
                      transaction.getSummary(),
                      style: TextStyle(
                        fontSize: TypeScale.footnote,
                        color: AppStyles.getSecondaryTextColor(context)
                            .withValues(alpha: 0.8),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 110,
                child: Text(
                  '₹${transaction.amount.toStringAsFixed(2)}',
                  textAlign: TextAlign.end,
                  style: AppStyles.titleStyle(context).copyWith(
                    color: typeColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetailSheet(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (modalContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        minChildSize: 0.55,
        maxChildSize: 0.95,
        builder: (dragContext, scrollController) {
          final restoreButton = CupertinoButton.filled(
            onPressed: () async {
              await transactionsController.addTransaction(transaction);
              await archiveController.removeFromArchive(transaction.id);
              toast_lib.toast.showSuccess('Transaction restored');
              Haptics.success();
              Navigator.pop(modalContext);
            },
            child: const Text('Restore to History'),
          );

          final deleteButton = CupertinoButton(
            onPressed: () => _showPermanentDeleteOptions(context, modalContext),
            child: const Text('Permanently Delete',
                style: TextStyle(color: CupertinoColors.systemRed)),
          );

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
                    actionButtons: [restoreButton, deleteButton],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showPermanentDeleteOptions(
      BuildContext context, BuildContext modalContext) {
    showCupertinoModalPopup(
      context: context,
      builder: (actionContext) {
        return CupertinoActionSheet(
          title: const Text('Permanent delete options'),
          message: const Text(
              'Choose whether to keep account balances or reverse the amounts'),
          actions: [
            CupertinoActionSheetAction(
              child: const Text('Keep balances as-is'),
              onPressed: () async {
                await archiveController.removeFromArchive(transaction.id);
                toast_lib.toast.showSuccess('Transaction removed permanently');
                Haptics.success();
                Navigator.pop(actionContext);
                Navigator.pop(modalContext);
              },
            ),
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              child: const Text('Reverse balances'),
              onPressed: () async {
                await TransactionAccountAdjuster.reverseTransaction(
                  accountsController,
                  transaction,
                  paymentAppsController,
                );
                await archiveController.removeFromArchive(transaction.id);
                toast_lib.toast.showSuccess(
                    'Transaction reversed and removed permanently');
                Haptics.delete();
                Navigator.pop(actionContext);
                Navigator.pop(modalContext);
              },
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(actionContext),
          ),
        );
      },
    );
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
    final txnDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (txnDate == today) {
      return 'Today';
    }

    final yesterday = today.subtract(const Duration(days: 1));
    if (txnDate == yesterday) {
      return 'Yesterday';
    }

    return '${dateTime.day} ${_getMonthName(dateTime.month)}';
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
}
