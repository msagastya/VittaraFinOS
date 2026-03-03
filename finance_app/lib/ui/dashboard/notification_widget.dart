import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:vittara_fin_os/logic/fixed_deposit_model.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';

enum NotificationType {
  fdPayout, // Fixed Deposit payout
  rdInstallment, // Recurring Deposit installment
  fdAutoRenew, // FD auto-renew
  rdAutoPayment, // RD auto-payment
  stockSip, // Stock SIP
  bondPayout, // Bond payout reminder
}

class NotificationWidget extends StatelessWidget {
  final NotificationType type;
  final String title;
  final String subtitle;
  final String amount;
  final String timeInfo;
  final Color badgeColor;
  final IconData icon;
  final Widget statusWidget;
  final List<Widget>? actionButtons;

  const NotificationWidget({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.timeInfo,
    required this.badgeColor,
    required this.icon,
    required this.statusWidget,
    this.actionButtons,
    super.key,
  });

  // Factory for FD Payout
  factory NotificationWidget.fdPayout({
    required BuildContext context,
    required FixedDeposit fd,
    required PayoutRecord record,
    required int daysUntil,
  }) {
    return NotificationWidget(
      type: NotificationType.fdPayout,
      title: fd.name,
      subtitle: 'Payout on ${_formatDate(record.payoutDate)}',
      amount:
          '₹${(record.interestAmount + record.principalAmount).toStringAsFixed(2)}',
      timeInfo: 'In $daysUntil day${daysUntil > 1 ? 's' : ''}',
      badgeColor: daysUntil <= 3 ? CupertinoColors.systemRed : CupertinoColors.systemOrange,
      icon: CupertinoIcons.bell_fill,
      statusWidget: fd.autoLinkEnabled
          ? _buildAutoLinkEnabled(context, fd)
          : _buildAutoLinkDisabled(context),
    );
  }

  // Factory for RD Installment
  factory NotificationWidget.rdInstallment({
    required BuildContext context,
    required String rdName,
    required String accountName,
    required double amount,
    required DateTime dueDate,
  }) {
    final daysUntil = dueDate.difference(DateTime.now()).inDays;

    return NotificationWidget(
      type: NotificationType.rdInstallment,
      title: rdName,
      subtitle: 'Next installment due on ${_formatDate(dueDate)}',
      amount: '₹${amount.toStringAsFixed(2)}',
      timeInfo: 'In $daysUntil day${daysUntil > 1 ? 's' : ''}',
      badgeColor: daysUntil <= 3 ? CupertinoColors.systemRed : CupertinoColors.activeBlue,
      icon: CupertinoIcons.money_dollar_circle_fill,
      statusWidget: _buildRDInstallmentInfo(context, accountName),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(Spacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            badgeColor.withValues(alpha: 0.15),
            badgeColor.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: badgeColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with notification badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      color: Colors.white,
                      size: 12,
                    ),
                    const SizedBox(width: Spacing.xs),
                    Text(
                      _getNotificationLabel(type),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: TypeScale.caption,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  timeInfo,
                  style: TextStyle(
                    color: badgeColor,
                    fontSize: TypeScale.caption,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.md),
          // Title and Amount
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: AppStyles.getTextColor(context),
                        fontWeight: FontWeight.bold,
                        fontSize: TypeScale.headline,
                      ),
                    ),
                    const SizedBox(height: Spacing.xs),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: AppStyles.getSecondaryTextColor(context),
                        fontSize: TypeScale.footnote,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    amount,
                    style: TextStyle(
                      color: badgeColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    _getAmountLabel(type),
                    style: TextStyle(
                      color: AppStyles.getSecondaryTextColor(context),
                      fontSize: TypeScale.caption,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: Spacing.md),
          // Status Widget
          statusWidget,
          if (actionButtons != null) ...[
            const SizedBox(height: Spacing.md),
            Row(
              children: actionButtons!,
            ),
          ],
        ],
      ),
    );
  }

  static Widget _buildAutoLinkEnabled(BuildContext context, FixedDeposit fd) {
    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGreen.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(
            CupertinoIcons.checkmark_circle_fill,
            size: 16,
            color: CupertinoColors.systemGreen,
          ),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: Text(
              'Auto-link enabled. Payout will be credited to ${fd.linkedAccountName}',
              style: const TextStyle(
                color: CupertinoColors.systemGreen,
                fontSize: TypeScale.footnote,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildAutoLinkDisabled(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppStyles.getCardColor(context),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            CupertinoIcons.info,
            size: 14,
            color: AppStyles.getSecondaryTextColor(context),
          ),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: Text(
              'Auto-link is disabled. Enable to auto-credit this payout.',
              style: TextStyle(
                color: AppStyles.getSecondaryTextColor(context),
                fontSize: TypeScale.footnote,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildRDInstallmentInfo(
      BuildContext context, String accountName) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppStyles.getCardColor(context),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            CupertinoIcons.info,
            size: 14,
            color: AppStyles.getSecondaryTextColor(context),
          ),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: Text(
              'Will be debited from $accountName',
              style: TextStyle(
                color: AppStyles.getSecondaryTextColor(context),
                fontSize: TypeScale.footnote,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _getNotificationLabel(NotificationType type) {
    switch (type) {
      case NotificationType.fdPayout:
        return 'FD Payout';
      case NotificationType.rdInstallment:
        return 'RD Installment';
      case NotificationType.fdAutoRenew:
        return 'FD Auto-Renew';
      case NotificationType.rdAutoPayment:
        return 'RD Auto-Payment';
      case NotificationType.stockSip:
        return 'Stock SIP';
      case NotificationType.bondPayout:
        return 'Bond Payout';
    }
  }

  static String _getAmountLabel(NotificationType type) {
    switch (type) {
      case NotificationType.fdPayout:
        return 'Interest + Principal';
      case NotificationType.rdInstallment:
        return 'Monthly Installment';
      case NotificationType.fdAutoRenew:
        return 'Renewal Amount';
      case NotificationType.rdAutoPayment:
        return 'Payment Amount';
      case NotificationType.stockSip:
        return 'SIP Amount';
      case NotificationType.bondPayout:
        return 'Payout Amount';
    }
  }

  static String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDay = DateTime(date.year, date.month, date.day);

    if (targetDay == today) {
      return 'Today';
    } else if (targetDay == today.add(const Duration(days: 1))) {
      return 'Tomorrow';
    } else {
      final months = [
        '',
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
      return '${date.day} ${months[date.month]}';
    }
  }
}
