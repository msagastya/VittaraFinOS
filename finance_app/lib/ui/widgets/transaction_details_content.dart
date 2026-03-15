import 'package:flutter/cupertino.dart';
import 'package:vittara_fin_os/logic/transaction_model.dart';
import 'package:vittara_fin_os/utils/date_formatter.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';

class TransactionDetailsContent extends StatelessWidget {
  final Transaction transaction;
  final List<Widget> actionButtons;

  const TransactionDetailsContent({
    super.key,
    required this.transaction,
    this.actionButtons = const [],
  });

  @override
  Widget build(BuildContext context) {
    final detailEntries = _buildDetailEntries(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: Spacing.lg),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(Spacing.lg),
            decoration: BoxDecoration(
              color: _getTransactionColor().withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  _getTransactionIcon(),
                  color: _getTransactionColor(),
                  size: 32,
                ),
                const SizedBox(height: Spacing.md),
                Text(
                  transaction.getTypeLabel(),
                  style: AppStyles.titleStyle(context)
                      .copyWith(fontSize: TypeScale.title2),
                ),
                const SizedBox(height: Spacing.xs),
                Text(
                  _formatDate(transaction.dateTime),
                  style: TextStyle(
                    color: AppStyles.getSecondaryTextColor(context),
                    fontSize: TypeScale.body,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Amount',
                  style: TextStyle(
                    color: AppStyles.getSecondaryTextColor(context),
                    fontSize: TypeScale.footnote,
                  ),
                ),
                const SizedBox(height: Spacing.xs),
                Text(
                  '₹${transaction.amount.toStringAsFixed(2)}',
                  style: AppStyles.titleStyle(context).copyWith(
                    fontSize: TypeScale.largeTitle,
                    color: _getTransactionColor(),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Spacing.xxl),
          ...detailEntries.map((entry) => _buildDetailRow(context, entry)),
          if (actionButtons.isNotEmpty) ...[
            const SizedBox(height: Spacing.xxxl),
            ...actionButtons.map(
              (child) => Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
                child: child,
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<_DetailEntry> _buildDetailEntries(BuildContext context) {
    final entries = <_DetailEntry>[];
    final metadata = transaction.metadata ?? {};

    void maybeAdd(String label, String? value, {Color? forceColor}) {
      if (value == null || value.trim().isEmpty) return;
      entries.add(
          _DetailEntry(label: label, value: value.trim(), color: forceColor));
    }

    if (transaction.sourceAccountName != null) {
      maybeAdd('From Account', transaction.sourceAccountName);
    }
    if (transaction.destinationAccountName != null) {
      maybeAdd('To Account', transaction.destinationAccountName);
    }

    if (transaction.type == TransactionType.transfer) {
      final appWallet = transaction.appWalletAmount ?? 0.0;
      if (appWallet > 0) {
        maybeAdd(
          'From App Wallet',
          '₹${appWallet.toStringAsFixed(2)}',
          forceColor: CupertinoColors.systemOrange,
        );
        maybeAdd(
          'From Source Account',
          '₹${(transaction.amount - appWallet).toStringAsFixed(2)}',
        );
      } else {
        maybeAdd(
            'From Source Account', '₹${transaction.amount.toStringAsFixed(2)}');
      }
    }

    maybeAdd('Description', transaction.description);
    maybeAdd('Category', metadata['categoryName'] as String?);
    maybeAdd('Investment', metadata['investmentName'] as String?);
    final merchant = metadata['merchant'] as String?;
    if (merchant != null && merchant.isNotEmpty) {
      maybeAdd('Merchant', merchant);
    }
    maybeAdd('Payment App', transaction.paymentAppName);
    final paymentApp = metadata['paymentApp'] as String?;
    if ((transaction.paymentAppName ?? '').isEmpty) {
      maybeAdd('Payment App', paymentApp);
    }
    final tags = metadata['tags'];
    if (tags is List && tags.isNotEmpty) {
      maybeAdd('Tags', tags.join(', '));
    }

    if (transaction.cashbackAmount != null && transaction.cashbackAmount! > 0) {
      maybeAdd('Cashback Amount',
          '₹${transaction.cashbackAmount!.toStringAsFixed(2)}',
          forceColor: AppStyles.bioGreen);
      maybeAdd('Cashback Flow',
          metadata['cashbackFlow'] as String? ?? 'Payment App');
      maybeAdd('Cashback Account', transaction.cashbackAccountName);
    }

    if (metadata.containsKey('paymentType')) {
      maybeAdd('Payment Type', metadata['paymentType'] as String?);
    }

    final transferFlowType = metadata['transferFlowType'] as String?;
    if (transferFlowType != null && transferFlowType != 'standard') {
      final flowLabel = transferFlowType == 'cash_withdrawal'
          ? 'Cash Withdrawal'
          : transferFlowType == 'cash_deposit'
              ? 'Cash Deposit'
              : transferFlowType == 'cash_to_cash'
                  ? 'Cash Transfer'
                  : transferFlowType;
      maybeAdd('Transfer Flow', flowLabel);
    }

    if (transaction.type == TransactionType.transfer &&
        transaction.charges != null &&
        transaction.charges! > 0) {
      maybeAdd('Charges', '₹${transaction.charges!.toStringAsFixed(2)}',
          forceColor: AppStyles.plasmaRed);
    }

    final transferRef = metadata['transferRef'] as String?;
    if (transferRef != null && transferRef.isNotEmpty) {
      maybeAdd('Transfer Ref', transferRef);
    }

    return entries;
  }

  Widget _buildDetailRow(BuildContext context, _DetailEntry entry) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              entry.label,
              style: TextStyle(
                color: AppStyles.getSecondaryTextColor(context),
                fontSize: TypeScale.subhead,
              ),
            ),
          ),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Text(
              entry.value,
              style: TextStyle(
                color: entry.color ?? AppStyles.getTextColor(context),
                fontSize: TypeScale.body,
                fontWeight: FontWeight.w600,
              ),
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getTransactionIcon() {
    switch (transaction.type) {
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

  Color _getTransactionColor() {
    switch (transaction.type) {
      case TransactionType.transfer:
        return CupertinoColors.systemBlue;
      case TransactionType.cashback:
        return AppStyles.bioGreen;
      case TransactionType.lending:
        return CupertinoColors.systemOrange;
      case TransactionType.borrowing:
        return CupertinoColors.systemPurple;
      case TransactionType.investment:
        return AppStyles.plasmaRed;
      case TransactionType.expense:
        return AppStyles.plasmaRed;
      case TransactionType.income:
        return AppStyles.bioGreen;
    }
  }

  String _formatDate(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final txnDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (txnDate == today) {
      return 'Today ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    }

    final yesterday = today.subtract(const Duration(days: 1));
    if (txnDate == yesterday) {
      return 'Yesterday';
    }

    return '${dateTime.day} ${DateFormatter.getMonthName(dateTime.month)}';
  }
}

class _DetailEntry {
  final String label;
  final String value;
  final Color? color;

  const _DetailEntry({required this.label, required this.value, this.color});
}
