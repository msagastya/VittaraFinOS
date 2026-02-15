import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/accounts_controller.dart';
import 'package:vittara_fin_os/logic/bond_payout_generator.dart';
import 'package:vittara_fin_os/logic/investments_controller.dart';
import 'package:vittara_fin_os/logic/investment_model.dart';
import 'package:vittara_fin_os/logic/fixed_deposit_model.dart';
import 'package:vittara_fin_os/logic/notification_helpers.dart';
import 'package:vittara_fin_os/ui/dashboard/notification_widget.dart';
import 'package:vittara_fin_os/ui/manage/fd/modals/fd_renewal_modal.dart';
import 'package:vittara_fin_os/ui/manage/fd/modals/fd_withdrawal_modal.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/widgets/animations.dart';
import 'package:vittara_fin_os/ui/widgets/common_widgets.dart';
import 'package:vittara_fin_os/ui/widgets/toast_notification.dart' as toast_lib;
import 'package:vittara_fin_os/ui/manage/bonds/bond_payout_modal.dart';
import 'package:vittara_fin_os/ui/manage/bonds/bonds_details_screen.dart';
import 'package:vittara_fin_os/ui/manage/mf/mf_details_screen.dart';
import 'package:vittara_fin_os/ui/manage/stocks/stock_details_screen.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Notifications'),
        previousPageTitle: 'Back',
        backgroundColor: AppStyles.getBackground(context),
        border: null,
      ),
      child: SafeArea(
        child: Container(
          color:
              isDark ? Colors.black : CupertinoColors.systemGroupedBackground,
          child: Consumer<InvestmentsController>(
            builder: (context, investmentsController, child) {
              final investments = investmentsController.investments;

              // Find FDs near maturity
              final fdsNearMaturity = investments.where((inv) {
                if (inv.type.name != 'fixedDeposit') return false;
                final metadata = inv.metadata;
                if (metadata == null || !metadata.containsKey('maturityDate'))
                  return false;
                final maturityDate =
                    DateTime.parse(metadata['maturityDate'] as String);
                final daysUntil =
                    maturityDate.difference(DateTime.now()).inDays;
                return daysUntil <= 10 && daysUntil >= 0;
              }).toList();

              // Find FDs that have already matured
              final fdsMatured = investments.where((inv) {
                if (inv.type.name != 'fixedDeposit') return false;
                final metadata = inv.metadata;
                if (metadata == null || !metadata.containsKey('maturityDate'))
                  return false;
                final maturityDate =
                    DateTime.parse(metadata['maturityDate'] as String);
                final daysUntil =
                    maturityDate.difference(DateTime.now()).inDays;
                return daysUntil < 0;
              }).toList();

              // Find RDs with upcoming installments
              final rdsWithUpcomingInstallments = investments.where((inv) {
                if (inv.type.name != 'recurringDeposit') return false;
                return true;
              }).toList();

              final sipNotifications = collectSipNotifications(investments);
              final bondNotifications =
                  collectBondPayoutNotifications(investments);

              return SingleChildScrollView(
                child: Column(
                  children: [
                    // FD Maturity Notifications (upcoming)
                    if (fdsNearMaturity.isNotEmpty)
                      ...fdsNearMaturity.map((fd) {
                        final metadata = fd.metadata!;
                        final maturityDate =
                            DateTime.parse(metadata['maturityDate'] as String);
                        final daysUntil =
                            maturityDate.difference(DateTime.now()).inDays;
                        final maturityValue =
                            (metadata['estimatedAccruedValue'] as num?)
                                    ?.toDouble() ??
                                fd.amount;

                        return Container(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          child: NotificationWidget(
                            type: NotificationType.fdPayout,
                            title: fd.name,
                            subtitle:
                                'Maturity on ${_formatDashboardDate(maturityDate)}',
                            amount: '₹${maturityValue.toStringAsFixed(2)}',
                            timeInfo:
                                'In $daysUntil day${daysUntil > 1 ? 's' : ''}',
                            badgeColor:
                                daysUntil <= 3 ? Colors.red : Colors.orange,
                            icon: CupertinoIcons.bell_fill,
                            statusWidget: Container(
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
                                    color: AppStyles.getSecondaryTextColor(
                                        context),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Choose to renew or withdraw',
                                      style: TextStyle(
                                        color: AppStyles.getSecondaryTextColor(
                                            context),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),

                    // FD Maturity Confirmation (already matured)
                    if (fdsMatured.isNotEmpty)
                      ...fdsMatured.map((fd) {
                        final metadata = fd.metadata!;
                        final maturityDate =
                            DateTime.parse(metadata['maturityDate'] as String);
                        final maturityValue =
                            (metadata['estimatedAccruedValue'] as num?)
                                    ?.toDouble() ??
                                fd.amount;
                        final daysOverdue =
                            DateTime.now().difference(maturityDate).inDays;

                        return Container(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          child: NotificationWidget(
                            type: NotificationType.fdAutoRenew,
                            title: fd.name,
                            subtitle:
                                'MATURED on ${_formatDashboardDate(maturityDate)}',
                            amount: '₹${maturityValue.toStringAsFixed(2)}',
                            timeInfo:
                                '$daysOverdue day${daysOverdue > 1 ? 's' : ''} ago',
                            badgeColor: Colors.purple,
                            icon: CupertinoIcons.checkmark_alt_circle_fill,
                            statusWidget: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.purple.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    CupertinoIcons.exclamationmark_circle,
                                    size: 14,
                                    color: Colors.purple,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Confirm renewal or withdraw funds',
                                      style: TextStyle(
                                        color: Colors.purple,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            actionButtons: [
                              Expanded(
                                child: CupertinoButton(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 8, horizontal: 12),
                                  color: Colors.purple,
                                  onPressed: () async {
                                    try {
                                      // Construct FixedDeposit from Investment metadata
                                      final fdObj =
                                          _buildFixedDepositFromInvestment(fd);
                                      final investmentsController =
                                          Provider.of<InvestmentsController>(
                                              context,
                                              listen: false);
                                      if (!context.mounted) return;
                                      Navigator.of(context).push(
                                        CupertinoPageRoute(
                                          builder: (context) => FDRenewalModal(
                                            fd: fdObj,
                                            investmentController:
                                                investmentsController,
                                            originalInvestment: fd,
                                            onRenew: () async {
                                              // Renewal completed, go back
                                              if (context.mounted) {
                                                Navigator.of(context).pop();
                                              }
                                            },
                                          ),
                                        ),
                                      );
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(content: Text('Error: $e')),
                                        );
                                      }
                                    }
                                  },
                                  child: const Text(
                                    'Renew',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: CupertinoButton(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 8, horizontal: 12),
                                  color: Colors.grey,
                                  onPressed: () async {
                                    try {
                                      // Construct FixedDeposit from Investment metadata
                                      final fdObj =
                                          _buildFixedDepositFromInvestment(fd);
                                      final investmentsController =
                                          Provider.of<InvestmentsController>(
                                              context,
                                              listen: false);
                                      if (!context.mounted) return;
                                      Navigator.of(context).push(
                                        CupertinoPageRoute(
                                          builder: (context) =>
                                              FDWithdrawalModal(
                                            fd: fdObj,
                                            investmentController:
                                                investmentsController,
                                            originalInvestment: fd,
                                            onWithdraw: () async {
                                              // Withdrawal completed, go back
                                              if (context.mounted) {
                                                Navigator.of(context).pop();
                                              }
                                            },
                                          ),
                                        ),
                                      );
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(content: Text('Error: $e')),
                                        );
                                      }
                                    }
                                  },
                                  child: const Text(
                                    'Withdraw',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),

                    // RD Upcoming Installment Notifications
                    if (rdsWithUpcomingInstallments.isNotEmpty)
                      ...rdsWithUpcomingInstallments.map((rd) {
                        final metadata = rd.metadata;
                        final monthlyAmount =
                            (metadata?['monthlyAmount'] as num?)?.toDouble() ??
                                rd.amount;
                        final linkedAccountName =
                            metadata?['linkedAccountName'] as String? ??
                                'Account';

                        return Container(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          child: NotificationWidget.rdInstallment(
                            context: context,
                            rdName: rd.name,
                            accountName: linkedAccountName,
                            amount: monthlyAmount,
                            dueDate:
                                DateTime.now().add(const Duration(days: 5)),
                          ),
                        );
                      }),
                    if (rdsWithUpcomingInstallments.isNotEmpty &&
                        sipNotifications.isNotEmpty)
                      SizedBox(height: Spacing.md),

                    if (sipNotifications.isNotEmpty)
                      ...sipNotifications.map(
                        (entry) => _buildSipNotificationWidget(context, entry),
                      ),
                    if (sipNotifications.isNotEmpty &&
                        bondNotifications.isNotEmpty)
                      SizedBox(height: Spacing.md),
                    if (bondNotifications.isNotEmpty)
                      ...bondNotifications
                          .map((entry) => _buildBondNotificationWidget(
                                context,
                                entry,
                              ))
                          .toList(),

                    // Empty State
                    if (fdsNearMaturity.isEmpty &&
                        fdsMatured.isEmpty &&
                        rdsWithUpcomingInstallments.isEmpty &&
                        sipNotifications.isEmpty &&
                        bondNotifications.isEmpty)
                      Padding(
                        padding: EdgeInsets.only(top: Spacing.xxxl),
                        child: FadeInAnimation(
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                FloatingAnimation(
                                  child: Icon(
                                    CupertinoIcons.bell_slash,
                                    size: 80,
                                    color: isDark
                                        ? CupertinoColors.systemGrey
                                        : CupertinoColors.systemGrey,
                                  ),
                                ),
                                SizedBox(height: Spacing.lg),
                                Text(
                                  'No Notifications',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? Colors.white
                                        : CupertinoColors.label,
                                  ),
                                ),
                                SizedBox(height: Spacing.sm),
                                Text(
                                  'You\'re all caught up!',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppStyles.getSecondaryTextColor(
                                        context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    SizedBox(height: Spacing.lg),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSipNotificationWidget(
      BuildContext context, SipNotificationInfo entry) {
    final amountText =
        entry.amount > 0 ? '₹${entry.amount.toStringAsFixed(2)}' : '₹—';
    final timeInfo = entry.daysUntil == 0
        ? 'Due today'
        : 'In ${entry.daysUntil} day${entry.daysUntil > 1 ? 's' : ''}';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: NotificationWidget(
        type: NotificationType.stockSip,
        title: entry.investment.name,
        subtitle: entry.frequencyLabel,
        amount: amountText,
        timeInfo: timeInfo,
        badgeColor: Colors.blue,
        icon: CupertinoIcons.repeat,
        statusWidget: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppStyles.getCardColor(context),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'Due on ${_formatDashboardDate(entry.dueDate)}',
            style: TextStyle(
              color: AppStyles.getSecondaryTextColor(context),
              fontSize: 12,
            ),
          ),
        ),
        actionButtons: [
          Expanded(
            child: CupertinoButton(
              padding: const EdgeInsets.symmetric(vertical: 8),
              color: Colors.blue,
              onPressed: () =>
                  _openInvestmentDetails(context, entry.investment),
              child: const Text(
                'Edit SIP',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: CupertinoButton(
              padding: const EdgeInsets.symmetric(vertical: 8),
              color: Colors.grey,
              onPressed: () =>
                  _skipSip(context, entry.investment, entry.dueDate),
              child: const Text(
                'Skip SIP',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBondNotificationWidget(
    BuildContext context,
    BondPayoutNotificationInfo entry,
  ) {
    final timeInfo = entry.daysUntil == 0
        ? 'Due today'
        : 'In ${entry.daysUntil} day${entry.daysUntil > 1 ? 's' : ''}';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: NotificationWidget(
        type: NotificationType.bondPayout,
        title: entry.investment.name,
        subtitle: 'Payout #${entry.schedule.payoutNumber}',
        amount: '₹—',
        timeInfo: timeInfo,
        badgeColor: Colors.teal,
        icon: CupertinoIcons.money_dollar,
        statusWidget: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppStyles.getCardColor(context),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'Due on ${_formatDashboardDate(entry.schedule.payoutDate)}',
            style: TextStyle(
              color: AppStyles.getSecondaryTextColor(context),
              fontSize: 12,
            ),
          ),
        ),
        actionButtons: [
          Expanded(
            child: CupertinoButton(
              padding: const EdgeInsets.symmetric(vertical: 8),
              color: Colors.blue,
              onPressed: () => _showBondPayoutModal(context, entry),
              child: const Text(
                'Edit Payout',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: CupertinoButton(
              padding: const EdgeInsets.symmetric(vertical: 8),
              color: Colors.grey,
              onPressed: () => _skipBondPayout(context, entry),
              child: const Text(
                'Skip Payout',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openInvestmentDetails(BuildContext context, Investment investment) {
    Widget? destination;
    switch (investment.type) {
      case InvestmentType.stocks:
        destination = StockDetailsScreen(investment: investment);
        break;
      case InvestmentType.mutualFund:
        destination = MFDetailsScreen(investment: investment);
        break;
      case InvestmentType.bonds:
        destination = BondsDetailsScreen(investment: investment);
        break;
      default:
        destination = null;
    }
    final route = destination;
    if (route == null) return;
    Navigator.of(context).push(
      CupertinoPageRoute(builder: (_) => route),
    );
  }

  Future<void> _skipSip(
    BuildContext context,
    Investment investment,
    DateTime nextDue,
  ) async {
    final controller =
        Provider.of<InvestmentsController>(context, listen: false);
    final updatedMetadata =
        markSipAsExecuted(investment.metadata ?? {}, nextDue);
    final updatedInvestment = investment.copyWith(metadata: updatedMetadata);
    await controller.updateInvestment(updatedInvestment);
    if (context.mounted) {
      toast_lib.toast.showInfo('Skipped next SIP for ${investment.name}');
    }
  }

  Future<void> _skipBondPayout(
    BuildContext context,
    BondPayoutNotificationInfo entry,
  ) async {
    final controller =
        Provider.of<InvestmentsController>(context, listen: false);
    final metadata = Map<String, dynamic>.from(entry.investment.metadata ?? {});
    final skipped = (metadata['skippedPayouts'] as List?)?.cast<int>() ?? [];
    if (!skipped.contains(entry.schedule.payoutNumber)) {
      skipped.add(entry.schedule.payoutNumber);
      metadata['skippedPayouts'] = skipped;
      final updatedInvestment = entry.investment.copyWith(metadata: metadata);
      await controller.updateInvestment(updatedInvestment);
      if (context.mounted) {
        toast_lib.toast.showInfo(
            'Skipped payout #${entry.schedule.payoutNumber} for ${entry.investment.name}');
      }
    }
  }

  void _showBondPayoutModal(
      BuildContext context, BondPayoutNotificationInfo entry) {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => BondPayoutModal(
        bond: entry.investment,
        notification: entry,
      ),
    );
  }

  String _formatDashboardDate(DateTime date) {
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
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDay = DateTime(date.year, date.month, date.day);

    if (targetDay == today) {
      return 'Today';
    } else if (targetDay == today.add(const Duration(days: 1))) {
      return 'Tomorrow';
    } else {
      return '${date.day} ${months[date.month]}';
    }
  }

  FixedDeposit _buildFixedDepositFromInvestment(Investment investment) {
    final metadata = investment.metadata ?? {};

    // Get maturity value from metadata
    final maturityValue = (metadata['maturityValue'] as num?)?.toDouble() ??
        (metadata['estimatedAccruedValue'] as num?)?.toDouble() ??
        investment.amount;

    // Get principal (original investment amount)
    final principal = investment.amount;

    return FixedDeposit(
      id: investment.id,
      name: investment.name,
      principal: principal,
      interestRate: (metadata['interestRate'] as num?)?.toDouble() ?? 6.0,
      tenureMonths: (metadata['tenureMonths'] as num?)?.toInt() ?? 12,
      compoundingFrequency:
          _parseCompoundingFrequency(metadata['compoundingFrequency']),
      payoutFrequency: _parsePayoutFrequency(metadata['payoutFrequency']),
      isCumulative: (metadata['isCumulative'] as bool?) ?? true,
      linkedAccountId: metadata['linkedAccountId'] as String? ?? '',
      linkedAccountName: metadata['linkedAccountName'] as String? ?? 'Account',
      autoLinkEnabled: (metadata['autoLinkEnabled'] as bool?) ?? false,
      createdDate: _parseDate(metadata['createdDate']),
      investmentDate: _parseDate(metadata['investmentDate']),
      maturityDate: _parseDate(metadata['maturityDate']),
      status: FDStatus.active,
      pastPayouts: [],
      upcomingPayouts: [],
      maturityValue: maturityValue,
      totalInterestAtMaturity: maturityValue - principal,
      estimatedAccruedValue: maturityValue,
      realizedValue: maturityValue,
    );
  }

  FDCompoundingFrequency _parseCompoundingFrequency(dynamic value) {
    if (value == null) return FDCompoundingFrequency.quarterly;
    return FDCompoundingFrequency.values.firstWhere(
      (e) => e.toString() == value,
      orElse: () => FDCompoundingFrequency.quarterly,
    );
  }

  FDPayoutFrequency _parsePayoutFrequency(dynamic value) {
    if (value == null) return FDPayoutFrequency.atMaturity;
    return FDPayoutFrequency.values.firstWhere(
      (e) => e.toString() == value,
      orElse: () => FDPayoutFrequency.atMaturity,
    );
  }

  DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    if (value is String) return DateTime.parse(value);
    return DateTime.now();
  }
}
