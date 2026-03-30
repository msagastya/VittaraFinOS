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
    final meta = transaction.metadata ?? {};

    final sourceBalanceAfter = (meta['sourceBalanceAfter'] as num?)?.toDouble();
    final sourceCreditLimit = (meta['sourceCreditLimit'] as num?)?.toDouble();
    final destBalanceAfter = (meta['destBalanceAfter'] as num?)?.toDouble();
    final destCreditLimit = (meta['destCreditLimit'] as num?)?.toDouble();

    final hasSourceBalance = sourceBalanceAfter != null;
    final hasDestBalance = destBalanceAfter != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: Spacing.lg),

          // ── Header card ──────────────────────────────────────────────
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(Spacing.lg),
            decoration: BoxDecoration(
              color: _getTransactionColor(context).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(_getTransactionIcon(),
                    color: _getTransactionColor(context), size: 32),
                const SizedBox(height: Spacing.md),
                Text(
                  transaction.getTypeLabel(),
                  style: AppStyles.titleStyle(context)
                      .copyWith(fontSize: TypeScale.title2),
                ),
                const SizedBox(height: Spacing.xs),
                Text(
                  DateFormatter.formatWithTime(transaction.dateTime),
                  style: TextStyle(
                    color: AppStyles.getSecondaryTextColor(context),
                    fontSize: TypeScale.body,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // ── Amount ───────────────────────────────────────────────────
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
                    color: _getTransactionColor(context),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Spacing.xxl),

          // ── Detail rows ──────────────────────────────────────────────
          ...detailEntries.map((e) => _buildDetailRow(context, e)),

          // ── Balance snapshot section ─────────────────────────────────
          if (hasSourceBalance || hasDestBalance) ...[
            const SizedBox(height: Spacing.xl),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'BALANCE AT TIME OF TRANSACTION',
                        style: TextStyle(
                          fontSize: TypeScale.caption,
                          fontWeight: FontWeight.w700,
                          color: AppStyles.getSecondaryTextColor(context),
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppStyles.accentBlue.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'snapshot',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: AppStyles.accentBlue,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Spacing.md),
                  if (hasSourceBalance)
                    _BalanceSnapshotCard(
                      accountName: transaction.sourceAccountName ??
                          (meta['accountName'] as String?) ??
                          'Account',
                      label: transaction.type == TransactionType.transfer
                          ? 'Source Account'
                          : 'Account',
                      balanceAfter: sourceBalanceAfter,
                      creditLimit: sourceCreditLimit,
                      context: context,
                    ),
                  if (hasDestBalance) ...[
                    const SizedBox(height: Spacing.md),
                    _BalanceSnapshotCard(
                      accountName:
                          transaction.destinationAccountName ?? 'Destination',
                      label: 'Destination Account',
                      balanceAfter: destBalanceAfter,
                      creditLimit: destCreditLimit,
                      context: context,
                    ),
                  ],
                ],
              ),
            ),
          ],

          // ── Action buttons ───────────────────────────────────────────
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

  // ── Detail rows ──────────────────────────────────────────────────────────

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
        maybeAdd('From App Wallet', '₹${appWallet.toStringAsFixed(2)}',
            forceColor: CupertinoColors.systemOrange);
        maybeAdd('From Source Account',
            '₹${(transaction.amount - appWallet).toStringAsFixed(2)}');
      } else {
        maybeAdd('From Source Account',
            '₹${transaction.amount.toStringAsFixed(2)}');
      }
    }

    maybeAdd('Description', transaction.description);
    maybeAdd('Category', metadata['categoryName'] as String?);
    maybeAdd('Investment', metadata['investmentName'] as String?);

    // ── Investment-specific fields ────────────────────────────────────────
    final showInvestmentFields =
        metadata['isDerivedInvestmentEvent'] == true ||
            transaction.type == TransactionType.investment;
    if (showInvestmentFields) {
      // Event type
      final rawEventType = metadata['investmentEventType'] as String?;
      if (rawEventType != null) {
        final prettyEventType = _prettifyEventType(rawEventType);
        maybeAdd('Event Type', prettyEventType);
      }

      // Quantity / Units
      final rawQty = metadata['quantity'] ?? metadata['units'];
      final qty = rawQty is num ? rawQty.toDouble() : null;
      if (qty != null) {
        final qtyStr = qty == qty.truncateToDouble()
            ? qty.toStringAsFixed(0)
            : qty.toStringAsFixed(4).replaceAll(RegExp(r'0+$'), '');
        maybeAdd('Quantity / Units', qtyStr);
      }

      // Price / NAV per unit
      final rawPrice = metadata['pricePerUnit'] ??
          metadata['navValue'] ??
          metadata['purchaseNav'];
      final price = rawPrice is num ? rawPrice.toDouble() : null;
      if (price != null) {
        maybeAdd('Price / NAV', '₹${price.toStringAsFixed(4)}');
      }

      // Current Value in Demat
      final rawCv = metadata['currentValue'];
      final cv = rawCv is num ? rawCv.toDouble() : null;
      if (cv != null && cv > 0) {
        maybeAdd('Current Value', '₹${cv.toStringAsFixed(2)}',
            forceColor: CupertinoColors.systemIndigo);
      }

      // Current NAV
      final rawCnav = metadata['currentNAV'];
      final cnav = rawCnav is num ? rawCnav.toDouble() : null;
      if (cnav != null) {
        maybeAdd('Current NAV', '₹${cnav.toStringAsFixed(4)}');
      }

      // FD / RD specific
      final rawRate = metadata['interestRate'];
      final rate = rawRate is num ? rawRate.toDouble() : null;
      if (rate != null && rate > 0) {
        maybeAdd('Interest Rate', '${rate.toStringAsFixed(2)}% p.a.');
      }
      final tenure = metadata['tenure'];
      if (tenure != null) {
        maybeAdd('Tenure', '$tenure months');
      }
      final maturityDate = metadata['maturityDate'] as String?;
      if (maturityDate != null && maturityDate.isNotEmpty) {
        final parsed = DateTime.tryParse(maturityDate);
        if (parsed != null) {
          final months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
              'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
          maybeAdd('Maturity Date',
              '${parsed.day} ${months[parsed.month]} ${parsed.year}');
        }
      }
      final rawMv = metadata['maturityValue'];
      final mv = rawMv is num ? rawMv.toDouble() : null;
      if (mv != null && mv > 0) {
        maybeAdd('Est. Maturity Value', '₹${mv.toStringAsFixed(2)}',
            forceColor: CupertinoColors.systemGreen);
      }
    }

    final merchant = metadata['merchant'] as String?;
    if (merchant != null && merchant.isNotEmpty) maybeAdd('Merchant', merchant);
    maybeAdd('Payment App', transaction.paymentAppName);
    final paymentApp = metadata['paymentApp'] as String?;
    if ((transaction.paymentAppName ?? '').isEmpty) {
      maybeAdd('Payment App', paymentApp);
    }
    final tags = metadata['tags'];
    if (tags is List && tags.isNotEmpty) maybeAdd('Tags', tags.join(', '));

    if (transaction.cashbackAmount != null && transaction.cashbackAmount! > 0) {
      maybeAdd('Cashback Amount',
          '₹${transaction.cashbackAmount!.toStringAsFixed(2)}',
          forceColor: AppStyles.gain(context));
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

    // Metadata charges (investment events)
    final rawMetaCharges = metadata['charges'];
    final metaCharges = rawMetaCharges is num ? rawMetaCharges.toDouble() : null;
    if (metaCharges != null && metaCharges > 0) {
      maybeAdd('Charges', '₹${metaCharges.toStringAsFixed(2)}',
          forceColor: AppStyles.loss(context));
    } else if (transaction.charges != null && transaction.charges! > 0) {
      maybeAdd('Charges', '₹${transaction.charges!.toStringAsFixed(2)}',
          forceColor: AppStyles.loss(context));
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

  // ── Helpers ──────────────────────────────────────────────────────────────

  String _prettifyEventType(String raw) {
    switch (raw.toLowerCase().trim()) {
      case 'sip':
        return 'SIP';
      case 'nav':
        return 'NAV';
      case 'create':
        return 'Purchase';
      case 'buy':
        return 'Buy';
      case 'sell':
        return 'Sell';
      case 'dividend':
        return 'Dividend';
      case 'redeem':
        return 'Redeem';
      case 'maturity':
        return 'Maturity';
      default:
        if (raw.isEmpty) return raw;
        return raw[0].toUpperCase() + raw.substring(1);
    }
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

  Color _getTransactionColor(BuildContext context) {
    switch (transaction.type) {
      case TransactionType.transfer:
        return CupertinoColors.systemBlue;
      case TransactionType.cashback:
        return AppStyles.gain(context);
      case TransactionType.lending:
        return CupertinoColors.systemOrange;
      case TransactionType.borrowing:
        return CupertinoColors.systemPurple;
      case TransactionType.investment:
        return CupertinoColors.systemIndigo;
      case TransactionType.expense:
        return AppStyles.loss(context);
      case TransactionType.income:
        return AppStyles.gain(context);
    }
  }

}

// ── Balance snapshot card ─────────────────────────────────────────────────────

class _BalanceSnapshotCard extends StatelessWidget {
  final String accountName;
  final String label;
  final double? balanceAfter;
  final double? creditLimit;
  final BuildContext context;

  const _BalanceSnapshotCard({
    required this.accountName,
    required this.label,
    required this.balanceAfter,
    required this.context,
    this.creditLimit,
  });

  @override
  Widget build(BuildContext ctx) {
    if (creditLimit != null) {
      return _buildCreditCard(ctx);
    }
    return _buildRegularCard(ctx);
  }

  Widget _buildRegularCard(BuildContext ctx) {
    final b = balanceAfter ?? 0;
    final isNegative = b < 0;
    final color = isNegative ? AppStyles.loss(ctx) : AppStyles.gain(ctx);

    return Container(
      padding: const EdgeInsets.all(Spacing.lg),
      decoration: BoxDecoration(
        color: AppStyles.getCardColor(ctx),
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: AppStyles.getDividerColor(ctx)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                      fontSize: TypeScale.caption,
                      color: AppStyles.getSecondaryTextColor(ctx),
                    )),
                const SizedBox(height: 2),
                Text(accountName,
                    style: TextStyle(
                      fontSize: TypeScale.footnote,
                      fontWeight: FontWeight.w600,
                      color: AppStyles.getTextColor(ctx),
                    )),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹${b.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: TypeScale.title3,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              Text(
                isNegative ? 'overdrawn' : 'after transaction',
                style: TextStyle(
                  fontSize: TypeScale.caption,
                  color: color.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCreditCard(BuildContext ctx) {
    final limit = creditLimit!;
    // For credit accounts: balance = available credit remaining
    // Used = limit - available
    final available = (balanceAfter ?? 0).clamp(0.0, limit);
    final used = (limit - available).clamp(0.0, limit);
    final usedRatio = limit > 0 ? (used / limit).clamp(0.0, 1.0) : 0.0;

    final barColor = usedRatio < 0.3
        ? AppStyles.gain(ctx)
        : usedRatio < 0.7
            ? CupertinoColors.systemOrange
            : AppStyles.loss(ctx);

    return Container(
      padding: const EdgeInsets.all(Spacing.lg),
      decoration: BoxDecoration(
        color: AppStyles.getCardColor(ctx),
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: AppStyles.getDividerColor(ctx)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: TextStyle(
                          fontSize: TypeScale.caption,
                          color: AppStyles.getSecondaryTextColor(ctx),
                        )),
                    const SizedBox(height: 2),
                    Text(accountName,
                        style: TextStyle(
                          fontSize: TypeScale.footnote,
                          fontWeight: FontWeight.w600,
                          color: AppStyles.getTextColor(ctx),
                        )),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: barColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${(usedRatio * 100).toStringAsFixed(0)}% used',
                  style: TextStyle(
                    fontSize: TypeScale.caption,
                    fontWeight: FontWeight.w700,
                    color: barColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.md),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 6,
              child: Stack(
                children: [
                  Container(
                      width: double.infinity,
                      color: AppStyles.getDividerColor(ctx)),
                  FractionallySizedBox(
                    widthFactor: usedRatio,
                    child: Container(color: barColor),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Spacing.md),
          Row(
            children: [
              _stat(ctx, 'Used', '₹${used.toStringAsFixed(0)}',
                  AppStyles.loss(ctx)),
              const SizedBox(width: Spacing.lg),
              _stat(ctx, 'Limit', '₹${limit.toStringAsFixed(0)}',
                  AppStyles.getSecondaryTextColor(ctx)),
              const Spacer(),
              _stat(ctx, 'Available', '₹${available.toStringAsFixed(0)}',
                  AppStyles.gain(ctx)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(BuildContext ctx, String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
              fontSize: TypeScale.caption,
              color: AppStyles.getSecondaryTextColor(ctx),
            )),
        Text(value,
            style: TextStyle(
              fontSize: TypeScale.footnote,
              fontWeight: FontWeight.w700,
              color: color,
            )),
      ],
    );
  }
}

class _DetailEntry {
  final String label;
  final String value;
  final Color? color;
  const _DetailEntry({required this.label, required this.value, this.color});
}
