import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/investments_controller.dart';
import 'package:vittara_fin_os/logic/investment_model.dart';
import 'package:vittara_fin_os/logic/fixed_deposit_model.dart';
import 'package:vittara_fin_os/ui/dashboard/notification_widget.dart';
import 'package:vittara_fin_os/ui/manage/fd/modals/fd_renewal_modal.dart';
import 'package:vittara_fin_os/ui/manage/fd/modals/fd_withdrawal_modal.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/widgets/animations.dart';
import 'package:vittara_fin_os/ui/widgets/common_widgets.dart';

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
          color: isDark ? Colors.black : CupertinoColors.systemGroupedBackground,
          child: Consumer<InvestmentsController>(
            builder: (context, investmentsController, child) {
              final investments = investmentsController.investments;

              // Find FDs near maturity
              final fdsNearMaturity = investments.where((inv) {
                if (inv.type.name != 'fixedDeposit') return false;
                final metadata = inv.metadata;
                if (metadata == null || !metadata.containsKey('maturityDate')) return false;
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
                if (metadata == null || !metadata.containsKey('maturityDate')) return false;
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
                            badgeColor: daysUntil <= 3
                                ? Colors.red
                                : Colors.orange,
                            icon: CupertinoIcons.bell_fill,
                            statusWidget: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color:
                                    AppStyles.getCardColor(context),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    CupertinoIcons.info,
                                    size: 14,
                                    color: AppStyles
                                        .getSecondaryTextColor(context),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Choose to renew or withdraw',
                                      style: TextStyle(
                                        color: AppStyles
                                            .getSecondaryTextColor(context),
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
                                  onPressed: () {
                                    // Construct FixedDeposit from Investment metadata
                                    final fdObj = _buildFixedDepositFromInvestment(fd);
                                    final investmentsController =
                                        Provider.of<InvestmentsController>(context, listen: false);
                                    Navigator.of(context).push(
                                      CupertinoPageRoute(
                                        builder: (context) =>
                                            FDRenewalModal(
                                              fd: fdObj,
                                              investmentController: investmentsController,
                                              originalInvestment: fd,
                                              onRenew: () async {
                                                // Delete the old matured FD
                                                await investmentsController.deleteInvestment(fd.id);
                                                if (context.mounted) {
                                                  Navigator.of(context).pop();
                                                }
                                              },
                                            ),
                                      ),
                                    );
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
                                  onPressed: () {
                                    // Construct FixedDeposit from Investment metadata
                                    final fdObj = _buildFixedDepositFromInvestment(fd);
                                    Navigator.of(context).push(
                                      CupertinoPageRoute(
                                        builder: (context) =>
                                            FDWithdrawalModal(
                                              fd: fdObj,
                                              onWithdraw: () {},
                                            ),
                                      ),
                                    );
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
                            (metadata?['monthlyAmount'] as num?)
                                    ?.toDouble() ??
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
                            dueDate: DateTime.now()
                                .add(const Duration(days: 5)),
                          ),
                        );
                      }),

                    // Empty State
                    if (fdsNearMaturity.isEmpty &&
                        fdsMatured.isEmpty &&
                        rdsWithUpcomingInstallments.isEmpty)
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
                                    color: AppStyles
                                        .getSecondaryTextColor(context),
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
      compoundingFrequency: _parseCompoundingFrequency(metadata['compoundingFrequency']),
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
