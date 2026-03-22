import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/accounts_controller.dart';
import 'package:vittara_fin_os/logic/payment_apps_controller.dart';
import 'package:vittara_fin_os/logic/transaction_account_adjuster.dart';
import 'package:vittara_fin_os/logic/transactions_archive_controller.dart';
import 'package:vittara_fin_os/logic/transactions_controller.dart';
import 'package:vittara_fin_os/logic/transaction_model.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/styles/transaction_type_theme.dart';
import 'package:vittara_fin_os/ui/widgets/animations.dart';
import 'package:vittara_fin_os/ui/widgets/common_widgets.dart';
import 'package:vittara_fin_os/ui/widgets/transaction_details_content.dart';
import 'package:vittara_fin_os/ui/widgets/toast_notification.dart' as toast_lib;
import 'package:vittara_fin_os/utils/date_formatter.dart';

class TransactionsArchiveScreen extends StatefulWidget {
  const TransactionsArchiveScreen({super.key});

  @override
  State<TransactionsArchiveScreen> createState() =>
      _TransactionsArchiveScreenState();
}

class _TransactionsArchiveScreenState extends State<TransactionsArchiveScreen> {
  TransactionType? _filterType;

  void _showFilterSheet() {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Filter by Type'),
        actions: [
          _filterAction(ctx, null, 'All Types'),
          _filterAction(ctx, TransactionType.expense, 'Expense'),
          _filterAction(ctx, TransactionType.income, 'Income'),
          _filterAction(ctx, TransactionType.transfer, 'Transfer'),
          _filterAction(ctx, TransactionType.lending, 'Lending'),
          _filterAction(ctx, TransactionType.borrowing, 'Borrowing'),
          _filterAction(ctx, TransactionType.investment, 'Investment'),
          _filterAction(ctx, TransactionType.cashback, 'Cashback'),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  CupertinoActionSheetAction _filterAction(
      BuildContext ctx, TransactionType? type, String label) {
    final isActive = _filterType == type;
    return CupertinoActionSheetAction(
      onPressed: () {
        Navigator.pop(ctx);
        setState(() => _filterType = type);
      },
      child: Text('$label${isActive ? ' ✓' : ''}'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppStyles.getBackground(context),
      navigationBar: AppStyles.isLandscape(context) ? null : CupertinoNavigationBar(
        middle: Text('Archived Transactions',
            style: TextStyle(color: AppStyles.getTextColor(context))),
        previousPageTitle: 'Back',
        backgroundColor: AppStyles.getBackground(context),
        border: null,
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _showFilterSheet,
          child: Icon(
            _filterType != null
                ? CupertinoIcons.line_horizontal_3_decrease_circle_fill
                : CupertinoIcons.line_horizontal_3_decrease_circle,
            color: _filterType != null
                ? AppStyles.accentBlue
                : AppStyles.getPrimaryColor(context),
            size: 22,
          ),
        ),
      ),
      child: Consumer4<TransactionsArchiveController, TransactionsController,
          AccountsController, PaymentAppsController>(
        builder: (context, archiveController, transactionsController,
            accountsController, paymentAppsController, child) {
          final archived = archiveController.archived;

          if (archived.isEmpty) {
            return const Center(
              child: EmptyStateView(
                icon: CupertinoIcons.archivebox_fill,
                title: 'No Archived Transactions',
                subtitle:
                    'Deleted entries will appear once you archive a transaction',
                actionLabel: null,
              ),
            );
          }

          final filtered = _filterType == null
              ? archived
              : archived.where((t) => t.type == _filterType).toList();

          if (filtered.isEmpty) {
            return SafeArea(
              child: Center(
                child: EmptyStateView(
                  icon: CupertinoIcons.line_horizontal_3_decrease_circle,
                  title: 'No Matching Transactions',
                  subtitle:
                      'No archived ${_filterType!.name} transactions found',
                  actionLabel: 'Clear Filter',
                  onAction: () => setState(() => _filterType = null),
                ),
              ),
            );
          }

          // Build date-grouped list
          final groups = DateFormatter.groupByDate(filtered, (t) => t.dateTime);
          final listItems = <_ArchiveListItem>[];
          for (final entry in groups.entries) {
            listItems.add(_ArchiveListItem.header(entry.key));
            for (final t in entry.value) {
              listItems.add(_ArchiveListItem.transaction(t));
            }
          }

          return SafeArea(
            child: ListView.builder(
              physics: const SmoothScrollPhysics(),
              cacheExtent: 600,
              padding: const EdgeInsets.fromLTRB(
                  Spacing.lg, Spacing.lg, Spacing.lg, Spacing.xxxl),
              itemCount: listItems.length,
              itemBuilder: (context, index) {
                final item = listItems[index];
                if (item.isHeader) {
                  return Padding(
                    key: ValueKey('header_${item.header}'),
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
                final transaction = item.transaction!;
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

/// Groups archived transactions by date label (Today / Yesterday / "15 Jan 2024")
class _ArchiveListItem {
  final String? header;
  final Transaction? transaction;

  const _ArchiveListItem.header(this.header) : transaction = null;
  const _ArchiveListItem.transaction(this.transaction) : header = null;

  bool get isHeader => header != null;
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
    final eventType = transaction.metadata?['investmentEventType'] as String?;
    final isDividend = eventType == 'dividend';
    final isSell = eventType == 'sell' || eventType == 'decrease' || eventType == 'redeem';
    final typeColor = isDividend ? const Color(0xFFFFB800) : isSell ? AppStyles.gain(context) : transaction.type.typeColor(context);
    final typeIcon = isDividend ? CupertinoIcons.money_dollar_circle_fill : isSell ? CupertinoIcons.arrow_up_circle_fill : transaction.type.typeIcon;

    return BouncyButton(
      onPressed: () => _showDetailSheet(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: Spacing.lg),
        decoration: AppStyles.cardDecoration(context),
        child: Padding(
          padding: const EdgeInsets.all(Spacing.lg),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(Spacing.md),
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(typeIcon, color: typeColor, size: 24),
              ),
              const SizedBox(width: Spacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.getTypeLabel(),
                      style: AppStyles.titleStyle(context),
                    ),
                    const SizedBox(height: Spacing.xs),
                    Text(
                      _formatDate(transaction.dateTime),
                      style: TextStyle(
                        color: AppStyles.getSecondaryTextColor(context),
                        fontSize: TypeScale.caption,
                      ),
                    ),
                    const SizedBox(height: Spacing.xs),
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
        initialChildSize: 0.7,
        minChildSize: 0.4,
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
            child: Text('Permanently Delete',
                style: TextStyle(color: AppStyles.loss(context))),
          );

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

    return '${dateTime.day} ${DateFormatter.getMonthName(dateTime.month)}';
  }
}
