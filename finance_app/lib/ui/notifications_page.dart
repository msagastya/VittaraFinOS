import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/account_model.dart';
import 'package:vittara_fin_os/logic/settings_controller.dart';
import 'package:vittara_fin_os/logic/accounts_controller.dart';
import 'package:vittara_fin_os/logic/investments_controller.dart';
import 'package:vittara_fin_os/logic/investment_model.dart';
import 'package:vittara_fin_os/logic/fixed_deposit_model.dart';
import 'package:vittara_fin_os/logic/notification_helpers.dart';
import 'package:vittara_fin_os/ui/dashboard/notification_widget.dart';
import 'package:vittara_fin_os/ui/manage/fd/modals/fd_renewal_modal.dart';
import 'package:vittara_fin_os/ui/manage/fd/modals/fd_withdrawal_modal.dart';
import 'package:vittara_fin_os/utils/date_formatter.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/widgets/animations.dart';
import 'package:vittara_fin_os/ui/widgets/toast_notification.dart' as toast_lib;
import 'package:vittara_fin_os/ui/manage/bonds/bond_payout_modal.dart';
import 'package:vittara_fin_os/ui/manage/bonds/bonds_details_screen.dart';
import 'package:vittara_fin_os/ui/manage/mf/mf_details_screen.dart';
import 'package:vittara_fin_os/ui/manage/stocks/stock_details_screen.dart';
import 'package:vittara_fin_os/logic/budget_model.dart';
import 'package:vittara_fin_os/logic/budgets_controller.dart';
import 'package:vittara_fin_os/logic/recurring_templates_controller.dart';
import 'package:vittara_fin_os/logic/transactions_controller.dart';
import 'package:vittara_fin_os/logic/transaction_model.dart';
import 'package:vittara_fin_os/ui/dashboard/transaction_wizard.dart';
import 'package:vittara_fin_os/logic/categories_controller.dart';
import 'package:vittara_fin_os/logic/category_model.dart';
import 'package:vittara_fin_os/services/sms_auto_scan_service.dart';
import 'package:vittara_fin_os/services/sms_service.dart';

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
          child: Consumer4<InvestmentsController, RecurringTemplatesController,
              TransactionsController, BudgetsController>(
            builder: (context, investmentsController, templatesController,
                txController, budgetsController, child) {
              final investments = investmentsController.investments;
              final dueTemplates = templatesController.templates.where((t) {
                final days = t.daysUntilDue();
                return days != null && days <= 3;
              }).toList()
                ..sort((a, b) =>
                    (a.daysUntilDue() ?? 99).compareTo(b.daysUntilDue() ?? 99));

              // Budget alerts
              final exceededBudgets =
                  budgetsController.getBudgetsExceedingLimit();
              final warningBudgets = budgetsController.getBudgetsInWarning();

              // Spending insights: categories that exceed last month by ≥20%
              final now = DateTime.now();
              final thisMonthStart = DateTime(now.year, now.month, 1);
              final lastMonthStart = DateTime(now.year, now.month - 1, 1);
              final lastMonthEnd =
                  thisMonthStart.subtract(const Duration(seconds: 1));

              Map<String, double> sumByCategory(List<Transaction> txs) {
                final map = <String, double>{};
                for (final tx in txs) {
                  if (tx.type != TransactionType.expense) continue;
                  final cat = tx.metadata?['categoryName'] as String? ??
                      'Uncategorized';
                  map[cat] = (map[cat] ?? 0) + tx.amount;
                }
                return map;
              }

              final allTx = txController.transactions;
              final thisMonthSpend = sumByCategory(allTx
                  .where((t) =>
                      !t.dateTime.isBefore(thisMonthStart) &&
                      !t.dateTime.isAfter(now))
                  .toList());
              final lastMonthSpend = sumByCategory(allTx
                  .where((t) =>
                      !t.dateTime.isBefore(lastMonthStart) &&
                      !t.dateTime.isAfter(lastMonthEnd))
                  .toList());

              // Only surface if current month is at least half over (day >= 10)
              final spendingInsights =
                  <({String category, double current, double last})>[];
              if (now.day >= 10) {
                for (final entry in thisMonthSpend.entries) {
                  final current = entry.value;
                  final last = lastMonthSpend[entry.key] ?? 0;
                  if (last > 0 && current >= last * 1.2 && current >= 500) {
                    spendingInsights.add(
                        (category: entry.key, current: current, last: last));
                  }
                }
                spendingInsights.sort((a, b) =>
                    (b.current - b.last).compareTo(a.current - a.last));
              }

              // Find FDs near maturity
              final fdsNearMaturity = investments.where((inv) {
                if (inv.type.name != 'fixedDeposit') return false;
                final metadata = inv.metadata;
                if (metadata == null || !metadata.containsKey('maturityDate')) {
                  return false;
                }
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
                if (metadata == null || !metadata.containsKey('maturityDate')) {
                  return false;
                }
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
                            badgeColor: daysUntil <= 3
                                ? AppStyles.plasmaRed
                                : CupertinoColors.systemOrange,
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
                                  const SizedBox(width: Spacing.sm),
                                  Expanded(
                                    child: Text(
                                      'Choose to renew or withdraw',
                                      style: TextStyle(
                                        color: AppStyles.getSecondaryTextColor(
                                            context),
                                        fontSize: TypeScale.footnote,
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
                                color: Colors.purple.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    CupertinoIcons.exclamationmark_circle,
                                    size: 14,
                                    color: Colors.purple,
                                  ),
                                  const SizedBox(width: Spacing.sm),
                                  Expanded(
                                    child: Text(
                                      'Confirm renewal or withdraw funds',
                                      style: TextStyle(
                                        color: Colors.purple,
                                        fontSize: TypeScale.footnote,
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
                                        FadeScalePageRoute(
                                          page: FDRenewalModal(
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
                                      fontSize: TypeScale.footnote,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: Spacing.sm),
                              Expanded(
                                child: CupertinoButton(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 8, horizontal: 12),
                                  color: CupertinoColors.systemGrey,
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
                                        FadeScalePageRoute(
                                          page: FDWithdrawalModal(
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
                                      fontSize: TypeScale.footnote,
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
                              )),

                    // Recurring Template Due Reminders
                    if (dueTemplates.isNotEmpty) ...[
                      if (bondNotifications.isNotEmpty ||
                          sipNotifications.isNotEmpty ||
                          rdsWithUpcomingInstallments.isNotEmpty)
                        SizedBox(height: Spacing.md),
                      ...dueTemplates.map((t) {
                        final days = t.daysUntilDue()!;
                        final isOverdue = days < 0;
                        final color = t.branch == 'income'
                            ? AppStyles.bioGreen
                            : AppStyles.plasmaRed;
                        final timeInfo = isOverdue
                            ? 'Overdue by ${days.abs()} day${days.abs() > 1 ? 's' : ''}'
                            : days == 0
                                ? 'Due today'
                                : 'Due in $days day${days > 1 ? 's' : ''}';
                        final isPaid =
                            t.isPaidForMonth(DateTime.now());
                        return Container(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          child: NotificationWidget(
                            type: NotificationType.fdPayout,
                            title: t.name,
                            subtitle:
                                '${t.branch[0].toUpperCase()}${t.branch.substring(1)} • ${t.frequency}',
                            amount:
                                '₹${t.amount % 1 == 0 ? t.amount.toStringAsFixed(0) : t.amount.toStringAsFixed(2)}',
                            timeInfo: isPaid ? 'Paid this month' : timeInfo,
                            badgeColor: isPaid
                                ? AppStyles.bioGreen
                                : isOverdue || days == 0
                                    ? AppStyles.plasmaRed
                                    : color,
                            icon: isPaid
                                ? CupertinoIcons.checkmark_circle_fill
                                : CupertinoIcons.repeat,
                            statusWidget: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppStyles.getCardColor(context),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  if (!isPaid) ...[
                                    CupertinoButton(
                                      padding: EdgeInsets.zero,
                                      minimumSize: Size.zero,
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          FadeScalePageRoute(
                                            page: const TransactionWizard(),
                                          ),
                                        );
                                      },
                                      child: Text(
                                        'Use Template',
                                        style: TextStyle(
                                          fontSize: TypeScale.footnote,
                                          color: AppStyles.accentBlue,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: Spacing.md),
                                    CupertinoButton(
                                      padding: EdgeInsets.zero,
                                      minimumSize: Size.zero,
                                      onPressed: () {
                                        templatesController
                                            .markBillAsPaid(t.id);
                                      },
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            CupertinoIcons
                                                .checkmark_circle_fill,
                                            size: 14,
                                            color: AppStyles.bioGreen,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Mark Paid',
                                            style: TextStyle(
                                              fontSize: TypeScale.footnote,
                                              color: AppStyles.bioGreen,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ] else ...[
                                    Icon(
                                      CupertinoIcons.checkmark_circle_fill,
                                      size: 14,
                                      color: AppStyles.bioGreen,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Paid this month',
                                      style: TextStyle(
                                        fontSize: TypeScale.footnote,
                                        color: AppStyles.bioGreen,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(width: Spacing.md),
                                    CupertinoButton(
                                      padding: EdgeInsets.zero,
                                      minimumSize: Size.zero,
                                      onPressed: () {
                                        templatesController
                                            .unmarkBillAsPaid(t.id);
                                      },
                                      child: Text(
                                        'Undo',
                                        style: TextStyle(
                                          fontSize: TypeScale.caption,
                                          color: AppStyles
                                              .getSecondaryTextColor(context),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ],

                    // All Bills — payment tracker
                    _buildAllBillsSection(context, templatesController),

                    // Budget Alerts
                    if (exceededBudgets.isNotEmpty ||
                        warningBudgets.isNotEmpty) ...[
                      Container(
                        margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                        child: Row(
                          children: [
                            const Icon(
                                CupertinoIcons.exclamationmark_circle_fill,
                                size: 14,
                                color: AppStyles.plasmaRed),
                            const SizedBox(width: Spacing.sm),
                            Text(
                              'Budget Alerts',
                              style: TextStyle(
                                fontSize: TypeScale.footnote,
                                fontWeight: FontWeight.w600,
                                color: AppStyles.plasmaRed,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ...exceededBudgets.map((b) =>
                          _buildBudgetAlertCard(context, b, exceeded: true)),
                      ...warningBudgets.map((b) =>
                          _buildBudgetAlertCard(context, b, exceeded: false)),
                    ],

                    // Spending Insights
                    if (spendingInsights.isNotEmpty) ...[
                      Container(
                        margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                        child: Row(
                          children: [
                            const Icon(CupertinoIcons.chart_bar_alt_fill,
                                size: 14, color: CupertinoColors.systemOrange),
                            const SizedBox(width: Spacing.sm),
                            Text(
                              'Spending Insights',
                              style: TextStyle(
                                fontSize: TypeScale.footnote,
                                fontWeight: FontWeight.w600,
                                color: CupertinoColors.systemOrange,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ...spendingInsights.take(3).map((insight) {
                        final pct = ((insight.current - insight.last) /
                                insight.last *
                                100)
                            .round();
                        return Container(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 6),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppStyles.getCardColor(context),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: CupertinoColors.systemOrange
                                  .withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: CupertinoColors.systemOrange
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  CupertinoIcons.arrow_up_circle_fill,
                                  size: 20,
                                  color: CupertinoColors.systemOrange,
                                ),
                              ),
                              const SizedBox(width: Spacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      insight.category,
                                      style: TextStyle(
                                        fontSize: TypeScale.subhead,
                                        fontWeight: FontWeight.w600,
                                        color: AppStyles.getTextColor(context),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Up $pct% vs last month',
                                      style: TextStyle(
                                        fontSize: TypeScale.footnote,
                                        color: CupertinoColors.systemOrange,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    CurrencyFormatter.compact(insight.current),
                                    style: TextStyle(
                                      fontSize: TypeScale.subhead,
                                      fontWeight: FontWeight.w700,
                                      color: AppStyles.getTextColor(context),
                                    ),
                                  ),
                                  Text(
                                    'was ${CurrencyFormatter.compact(insight.last)}',
                                    style: TextStyle(
                                      fontSize: TypeScale.caption,
                                      color: AppStyles.getSecondaryTextColor(
                                          context),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                    ],

                    // SMS — Unreviewed Transactions (last 7 days, only if SMS enabled)
                    Consumer<SettingsController>(
                      builder: (_, settings, __) {
                        if (!settings.isSmsEnabled) return const SizedBox.shrink();
                        return const _SmsSectionWidget();
                      },
                    ),

                    // Empty State
                    if (fdsNearMaturity.isEmpty &&
                        fdsMatured.isEmpty &&
                        rdsWithUpcomingInstallments.isEmpty &&
                        sipNotifications.isEmpty &&
                        bondNotifications.isEmpty &&
                        dueTemplates.isEmpty &&
                        exceededBudgets.isEmpty &&
                        warningBudgets.isEmpty &&
                        spendingInsights.isEmpty &&
                        (SmsAutoScanService.instance.pendingResults?.isEmpty ??
                            true))
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
                                    fontSize: TypeScale.body,
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
    final timeInfo = entry.daysUntil < 0
        ? 'Overdue by ${entry.daysUntil.abs()} day${entry.daysUntil.abs() > 1 ? 's' : ''}'
        : entry.daysUntil == 0
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
        badgeColor: AppStyles.aetherTeal,
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
              fontSize: TypeScale.footnote,
            ),
          ),
        ),
        actionButtons: [
          Expanded(
            child: CupertinoButton(
              padding: const EdgeInsets.symmetric(vertical: 8),
              color: AppStyles.aetherTeal,
              onPressed: () =>
                  _openInvestmentDetails(context, entry.investment),
              child: const Text(
                'Edit SIP',
                style: TextStyle(
                    color: Colors.white, fontSize: TypeScale.footnote),
              ),
            ),
          ),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: CupertinoButton(
              padding: const EdgeInsets.symmetric(vertical: 8),
              color: AppStyles.bioGreen,
              onPressed: () => _showSipExecutionModal(context, entry),
              child: const Text(
                'Execute SIP',
                style:
                    TextStyle(color: Colors.white, fontSize: TypeScale.caption),
              ),
            ),
          ),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: CupertinoButton(
              padding: const EdgeInsets.symmetric(vertical: 8),
              color: CupertinoColors.systemGrey,
              onPressed: () =>
                  _skipSip(context, entry.investment, entry.dueDate),
              child: const Text(
                'Skip SIP',
                style: TextStyle(
                    color: Colors.white, fontSize: TypeScale.footnote),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSipExecutionModal(BuildContext context, SipNotificationInfo entry) {
    showCupertinoModalPopup(
      context: context,
      builder: (_) => _SipExecutionModal(
        investment: entry.investment,
        dueDate: entry.dueDate,
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
        badgeColor: AppStyles.aetherTeal,
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
              fontSize: TypeScale.footnote,
            ),
          ),
        ),
        actionButtons: [
          Expanded(
            child: CupertinoButton(
              padding: const EdgeInsets.symmetric(vertical: 8),
              color: AppStyles.aetherTeal,
              onPressed: () => _showBondPayoutModal(context, entry),
              child: const Text(
                'Edit Payout',
                style: TextStyle(
                    color: Colors.white, fontSize: TypeScale.footnote),
              ),
            ),
          ),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: CupertinoButton(
              padding: const EdgeInsets.symmetric(vertical: 8),
              color: CupertinoColors.systemGrey,
              onPressed: () => _skipBondPayout(context, entry),
              child: const Text(
                'Skip Payout',
                style: TextStyle(
                    color: Colors.white, fontSize: TypeScale.footnote),
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
      FadeScalePageRoute(page: route),
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

  Widget _buildBudgetAlertCard(BuildContext context, Budget budget,
      {required bool exceeded}) {
    final pct = budget.usagePercentage.round();
    final color =
        exceeded ? AppStyles.plasmaRed : CupertinoColors.systemOrange;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppStyles.getCardColor(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              exceeded
                  ? CupertinoIcons.xmark_circle_fill
                  : CupertinoIcons.exclamationmark_triangle_fill,
              size: 20,
              color: color,
            ),
          ),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  budget.name,
                  style: TextStyle(
                    fontSize: TypeScale.subhead,
                    fontWeight: FontWeight.w600,
                    color: AppStyles.getTextColor(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  exceeded
                      ? 'Budget exceeded ($pct% used)'
                      : 'Approaching limit ($pct% used)',
                  style: TextStyle(
                    fontSize: TypeScale.footnote,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                CurrencyFormatter.compact(budget.spentAmount),
                style: TextStyle(
                  fontSize: TypeScale.subhead,
                  fontWeight: FontWeight.w700,
                  color: AppStyles.getTextColor(context),
                ),
              ),
              Text(
                'of ${CurrencyFormatter.compact(budget.limitAmount)}',
                style: TextStyle(
                  fontSize: TypeScale.caption,
                  color: AppStyles.getSecondaryTextColor(context),
                ),
              ),
            ],
          ),
        ],
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
      return '${date.day} ${DateFormatter.getMonthName(date.month)}';
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

  Widget _buildAllBillsSection(
    BuildContext context,
    RecurringTemplatesController templatesController,
  ) {
    final all = templatesController.templates;
    if (all.isEmpty) return const SizedBox.shrink();
    final now = DateTime.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Row(
            children: [
              const Icon(CupertinoIcons.calendar_badge_plus,
                  size: 14, color: AppStyles.accentTeal),
              const SizedBox(width: Spacing.sm),
              Text(
                'All Bills — ${_billsMonthYearLabel(now)}',
                style: const TextStyle(
                  fontSize: TypeScale.footnote,
                  fontWeight: FontWeight.w600,
                  color: AppStyles.accentTeal,
                ),
              ),
            ],
          ),
        ),
        ...all.map((t) {
          final isPaid = t.isPaidForMonth(now);
          final amountStr =
              '₹${t.amount % 1 == 0 ? t.amount.toStringAsFixed(0) : t.amount.toStringAsFixed(2)}';
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppStyles.getCardColor(context),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isPaid
                    ? AppStyles.bioGreen.withValues(alpha: 0.4)
                    : AppStyles.getDividerColor(context),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isPaid
                        ? AppStyles.bioGreen.withValues(alpha: 0.15)
                        : (t.branch == 'income'
                                ? AppStyles.bioGreen
                                : AppStyles.plasmaRed)
                            .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    isPaid
                        ? CupertinoIcons.checkmark_circle_fill
                        : CupertinoIcons.repeat,
                    size: 18,
                    color: isPaid
                        ? AppStyles.bioGreen
                        : (t.branch == 'income'
                            ? AppStyles.bioGreen
                            : AppStyles.plasmaRed),
                  ),
                ),
                const SizedBox(width: Spacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.name,
                        style: TextStyle(
                          fontSize: TypeScale.callout,
                          fontWeight: FontWeight.w600,
                          color: AppStyles.getTextColor(context),
                        ),
                      ),
                      Text(
                        '${t.frequency} • $amountStr',
                        style: TextStyle(
                          fontSize: TypeScale.caption,
                          color: AppStyles.getSecondaryTextColor(context),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isPaid)
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    onPressed: () =>
                        templatesController.unmarkBillAsPaid(t.id),
                    child: Text(
                      'Undo',
                      style: TextStyle(
                        fontSize: TypeScale.caption,
                        color: AppStyles.getSecondaryTextColor(context),
                      ),
                    ),
                  )
                else
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    color: AppStyles.bioGreen,
                    borderRadius: BorderRadius.circular(10),
                    minimumSize: Size.zero,
                    onPressed: () =>
                        templatesController.markBillAsPaid(t.id),
                    child: const Text(
                      'Mark Paid',
                      style: TextStyle(
                        fontSize: TypeScale.caption,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          );
        }),
        const SizedBox(height: Spacing.md),
      ],
    );
  }

  String _billsMonthYearLabel(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.year}';
  }
}

class _SipExecutionModal extends StatefulWidget {
  final Investment investment;
  final DateTime dueDate;

  const _SipExecutionModal({
    required this.investment,
    required this.dueDate,
  });

  @override
  State<_SipExecutionModal> createState() => _SipExecutionModalState();
}

class _SipExecutionModalState extends State<_SipExecutionModal> {
  late final bool _isStock;
  late DateTime _executionDate;
  late TextEditingController _amountController;
  late TextEditingController _auxController;
  late TextEditingController _dateController;
  Account? _selectedAccount;

  @override
  void initState() {
    super.initState();
    _isStock = widget.investment.type == InvestmentType.stocks;
    _executionDate = widget.dueDate;

    final metadata =
        Map<String, dynamic>.from(widget.investment.metadata ?? {});
    final amount = _defaultAmount(metadata);
    final aux =
        _isStock ? _defaultUnits(metadata, amount) : _defaultNav(metadata);

    _amountController = TextEditingController(
      text: amount > 0 ? amount.toStringAsFixed(2) : '',
    );
    _auxController = TextEditingController(
      text: aux > 0 ? aux.toStringAsFixed(_isStock ? 4 : 2) : '',
    );
    _dateController = TextEditingController(text: _formatDate(_executionDate));

    final accountsController =
        Provider.of<AccountsController>(context, listen: false);
    final accountId = _resolveDefaultAccountId(metadata);
    if (accountId != null) {
      final index =
          accountsController.accounts.indexWhere((acc) => acc.id == accountId);
      if (index >= 0) {
        _selectedAccount = accountsController.accounts[index];
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _auxController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  double _defaultAmount(Map<String, dynamic> metadata) {
    if (_isStock) {
      final sipType = (metadata['sipType'] as String?)?.toLowerCase();
      if (sipType == 'quantity') {
        final qty = _asDouble(metadata['sipQty']) ?? 0;
        final price = _asDouble(metadata['pricePerShare']) ?? 0;
        if (qty > 0 && price > 0) return qty * price;
      }
      return _asDouble(metadata['sipAmount']) ?? 0;
    }

    final sipData = metadata['sipData'];
    if (sipData is Map<String, dynamic>) {
      final amount = _asDouble(sipData['sipAmount']);
      if (amount != null && amount > 0) return amount;
    }
    return _asDouble(metadata['sipAmount']) ?? 0;
  }

  double _defaultUnits(Map<String, dynamic> metadata, double amount) {
    final sipType = (metadata['sipType'] as String?)?.toLowerCase();
    if (sipType == 'quantity') {
      return _asDouble(metadata['sipQty']) ?? 0;
    }
    final price = _asDouble(metadata['pricePerShare']) ?? 0;
    if (price <= 0 || amount <= 0) return 0;
    return amount / price;
  }

  double _defaultNav(Map<String, dynamic> metadata) {
    return _asDouble(metadata['currentNAV']) ??
        _asDouble(metadata['investmentNAV']) ??
        0;
  }

  String? _resolveDefaultAccountId(Map<String, dynamic> metadata) {
    if (_isStock) {
      return (metadata['sipLinkedAccount'] as String?) ??
          (metadata['accountId'] as String?);
    }
    final sipData = metadata['sipData'];
    if (sipData is Map<String, dynamic>) {
      return sipData['deductionAccountId'] as String?;
    }
    return (metadata['deductionAccountId'] as String?) ??
        (metadata['sipLinkedAccount'] as String?) ??
        (metadata['accountId'] as String?);
  }

  String? _resolveDefaultAccountName(Map<String, dynamic> metadata) {
    if (_isStock) {
      return (metadata['sipLinkedAccountName'] as String?) ??
          (metadata['accountName'] as String?);
    }
    final sipData = metadata['sipData'];
    if (sipData is Map<String, dynamic>) {
      return sipData['deductionAccountName'] as String?;
    }
    return (metadata['deductionAccountName'] as String?) ??
        (metadata['sipLinkedAccountName'] as String?) ??
        (metadata['accountName'] as String?);
  }

  void _showDatePicker() {
    showCupertinoModalPopup(
      context: context,
      builder: (_) => Container(
        height: 216,
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: SafeArea(
          top: false,
          child: CupertinoDatePicker(
            mode: CupertinoDatePickerMode.date,
            initialDateTime: _executionDate,
            onDateTimeChanged: (value) {
              setState(() {
                _executionDate = value;
                _dateController.text = _formatDate(value);
              });
            },
          ),
        ),
      ),
    );
  }

  void _showAccountPicker() {
    showCupertinoModalPopup(
      context: context,
      builder: (_) => Consumer<AccountsController>(
        builder: (context, controller, __) {
          final accounts = controller.accounts;
          return Container(
            decoration: BoxDecoration(
              color: AppStyles.getCardColor(context),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(Spacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Select Debit Account',
                      style: TextStyle(
                        color: AppStyles.getTextColor(context),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: Spacing.md),
                    if (accounts.isEmpty)
                      Text(
                        'No accounts available',
                        style: TextStyle(
                          color: AppStyles.getSecondaryTextColor(context),
                        ),
                      )
                    else
                      ...accounts.map((account) {
                        return CupertinoButton(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          onPressed: () {
                            setState(() => _selectedAccount = account);
                            Navigator.of(context).pop();
                          },
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  account.name,
                                  style: TextStyle(
                                    color: AppStyles.getTextColor(context),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Text(
                                '₹${account.balance.toStringAsFixed(2)}',
                                style: TextStyle(
                                  color:
                                      AppStyles.getSecondaryTextColor(context),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    const SizedBox(height: Spacing.sm),
                    CupertinoButton(
                      child: const Text('Cancel'),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    if (amount <= 0) {
      toast_lib.toast.showError('Enter a valid SIP amount');
      return;
    }

    final investmentsController =
        Provider.of<InvestmentsController>(context, listen: false);
    final accountsController =
        Provider.of<AccountsController>(context, listen: false);

    final metadata =
        Map<String, dynamic>.from(widget.investment.metadata ?? {});
    final defaultAccountId = _resolveDefaultAccountId(metadata);
    final defaultAccountName = _resolveDefaultAccountName(metadata);
    final selectedAccount = _selectedAccount;
    final debitAccountId = selectedAccount?.id ?? defaultAccountId;
    final debitAccountName = selectedAccount?.name ?? defaultAccountName;

    if (selectedAccount != null) {
      if (selectedAccount.balance < amount) {
        toast_lib.toast
            .showError('Insufficient balance in ${selectedAccount.name}');
        return;
      }
      await accountsController.updateAccount(
        selectedAccount.copyWith(balance: selectedAccount.balance - amount),
      );
    } else if (debitAccountId != null) {
      final index = accountsController.accounts
          .indexWhere((acc) => acc.id == debitAccountId);
      if (index >= 0) {
        final account = accountsController.accounts[index];
        if (account.balance < amount) {
          toast_lib.toast.showError('Insufficient balance in ${account.name}');
          return;
        }
        await accountsController.updateAccount(
          account.copyWith(balance: account.balance - amount),
        );
      }
    }

    final auxValue = double.tryParse(_auxController.text.trim()) ?? 0;
    if (_isStock) {
      var qtyDelta = auxValue;
      if (qtyDelta <= 0) {
        final price = _asDouble(metadata['pricePerShare']) ?? 0;
        if (price > 0) {
          qtyDelta = amount / price;
        }
      }
      if (qtyDelta <= 0) {
        toast_lib.toast.showError('Enter valid units for stock SIP');
        return;
      }
      final currentQty = _asDouble(metadata['qty']) ?? 0;
      metadata['qty'] = currentQty + qtyDelta;
    } else {
      var nav = auxValue;
      if (nav <= 0) {
        nav = _asDouble(metadata['currentNAV']) ??
            _asDouble(metadata['investmentNAV']) ??
            0;
      }
      if (nav <= 0) {
        toast_lib.toast.showError('Enter valid NAV for MF SIP');
        return;
      }
      final currentUnits = _asDouble(metadata['units']) ?? 0;
      metadata['units'] = currentUnits + (amount / nav);
      metadata['investmentNAV'] = nav;
      final currentInvestmentAmount =
          _asDouble(metadata['investmentAmount']) ?? widget.investment.amount;
      metadata['investmentAmount'] = currentInvestmentAmount + amount;
    }

    final updatedMetadata =
        markSipAsExecuted(metadata, _executionDate, action: 'manual_execute');
    final updatedInvestment = widget.investment.copyWith(
      amount: widget.investment.amount + amount,
      metadata: updatedMetadata,
    );

    await investmentsController.updateInvestment(
      updatedInvestment,
      trackDelta: false,
    );
    await investmentsController.recordInvestmentActivity(
      investmentId: widget.investment.id,
      type: 'sip',
      amount: amount,
      description: 'SIP executed for ${widget.investment.name}',
      dateTime: _executionDate,
      accountId: debitAccountId,
      accountName: debitAccountName,
    );

    if (!mounted) return;
    toast_lib.toast.showSuccess(
      'SIP executed for ${widget.investment.name} (₹${amount.toStringAsFixed(2)})',
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final auxLabel = _isStock ? 'Units' : 'NAV';
    final dueText = _formatDate(widget.dueDate);

    return Container(
      decoration: BoxDecoration(
        color: AppStyles.getCardColor(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemGrey3,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: Spacing.lg),
              Text(
                'Execute SIP',
                style: TextStyle(
                  color: AppStyles.getTextColor(context),
                  fontSize: TypeScale.title1,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: Spacing.xs),
              Text(
                'Due date: $dueText. You can execute now or later by changing date.',
                style: TextStyle(
                  color: AppStyles.getSecondaryTextColor(context),
                  fontSize: TypeScale.footnote,
                ),
              ),
              const SizedBox(height: Spacing.xl),
              _buildInputField(
                context: context,
                label: 'Amount',
                controller: _amountController,
                prefix: '₹',
              ),
              const SizedBox(height: Spacing.md),
              _buildInputField(
                context: context,
                label: auxLabel,
                controller: _auxController,
              ),
              const SizedBox(height: Spacing.md),
              GestureDetector(
                onTap: _showDatePicker,
                child: _buildPickerTile(
                  context: context,
                  label: 'Execution Date',
                  value: _dateController.text,
                ),
              ),
              const SizedBox(height: Spacing.md),
              GestureDetector(
                onTap: _showAccountPicker,
                child: _buildPickerTile(
                  context: context,
                  label: 'Debit Account',
                  value: _selectedAccount?.name ?? 'Select account',
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: CupertinoButton(
                      color: CupertinoColors.systemGrey,
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: CupertinoButton.filled(
                      onPressed: _submit,
                      child: const Text('Save Execution'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required BuildContext context,
    required String label,
    required TextEditingController controller,
    String? prefix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppStyles.getTextColor(context),
            fontWeight: FontWeight.w600,
            fontSize: TypeScale.subhead,
          ),
        ),
        const SizedBox(height: 6),
        CupertinoTextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: AppStyles.getBackground(context),
            borderRadius: BorderRadius.circular(10),
          ),
          prefix: prefix == null
              ? null
              : Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Text(
                    prefix,
                    style: TextStyle(
                        color: AppStyles.getSecondaryTextColor(context)),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildPickerTile({
    required BuildContext context,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppStyles.getBackground(context),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: AppStyles.getTextColor(context),
                fontWeight: FontWeight.w600,
                fontSize: TypeScale.subhead,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: AppStyles.getSecondaryTextColor(context),
              fontSize: TypeScale.footnote,
            ),
          ),
          const SizedBox(width: 6),
          const Icon(CupertinoIcons.chevron_down, size: 14),
        ],
      ),
    );
  }

  double? _asDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  String _formatDate(DateTime date) {
    return '${date.day} ${DateFormatter.getMonthName(date.month)} ${date.year}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SMS Unreviewed Transactions Section
// ─────────────────────────────────────────────────────────────────────────────

class _SmsSectionWidget extends StatefulWidget {
  const _SmsSectionWidget();

  @override
  State<_SmsSectionWidget> createState() => _SmsSectionWidgetState();
}

class _SmsSectionWidgetState extends State<_SmsSectionWidget> {
  final List<SmsParseResult> _items = [];

  @override
  void initState() {
    super.initState();
    final pending = SmsAutoScanService.instance.pendingResults;
    if (pending != null) _items.addAll(pending);
  }

  // ── Dismiss handler ────────────────────────────────────────────────────────

  void _dismiss(SmsParseResult item) {
    final idx = _items.indexOf(item);
    final fp = SmsAutoScanService.instance.fingerprint(item);

    setState(() => _items.remove(item));
    SmsAutoScanService.instance.pendingResults?.remove(item);
    SmsAutoScanService.instance.markSeen(fp);

    toast_lib.toast.showInfo(
      'Transaction dismissed',
      actionLabel: 'Undo',
      onAction: () {
        if (!mounted) return;
        setState(() => _items.insert(idx.clamp(0, _items.length), item));
        SmsAutoScanService.instance.pendingResults
            ?.insert(idx.clamp(0, SmsAutoScanService.instance.pendingResults!.length), item);
      },
    );
  }

  // ── Open smart SMS review sheet ─────────────────────────────────────────

  void _openSmsReview(SmsParseResult item) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetCtx) => _SmsQuickConfirmSheet(
        item: item,
        onSaved: () {
          if (!mounted) return;
          final fp = SmsAutoScanService.instance.fingerprint(item);
          setState(() => _items.remove(item));
          SmsAutoScanService.instance.pendingResults?.remove(item);
          SmsAutoScanService.instance.markSeen(fp);
        },
        onOpenWizard: () {
          // Open full wizard — item stays in list, mark seen only after save
          Navigator.of(context).push(
            FadeScalePageRoute(
              page: TransactionWizard(prefillFromSms: item),
            ),
          ).then((_) {
            // If the wizard was completed (transaction added), remove from list.
            // We detect this by checking if the transaction count increased.
            if (!mounted) return;
            final fp = SmsAutoScanService.instance.fingerprint(item);
            setState(() => _items.remove(item));
            SmsAutoScanService.instance.pendingResults?.remove(item);
            SmsAutoScanService.instance.markSeen(fp);
          });
        },
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  bool _hasDuplicate(SmsParseResult item, List<Transaction> txns) {
    final p = item.parsed;
    for (final t in txns) {
      if ((t.amount - p.amount).abs() > 1.0) continue;
      if (t.dateTime.difference(p.date).inDays.abs() > 1) continue;
      return true;
    }
    return false;
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final txns = context.watch<TransactionsController>().transactions;
    final cardBg =
        isDark ? const Color(0xFF0D1520) : CupertinoColors.systemBackground;
    final borderColor =
        isDark ? const Color(0xFF1C2A3A) : const Color(0xFFE5E5EA);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Section Header ──────────────────────────────────────────────────
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: Color(0xFF34C759),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'SMS Transactions (${_items.length})',
                style: const TextStyle(
                  fontSize: TypeScale.footnote,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF34C759),
                ),
              ),
              const Spacer(),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () {
                  for (final item in List.of(_items)) {
                    SmsAutoScanService.instance
                        .markSeen(SmsAutoScanService.instance.fingerprint(item));
                  }
                  setState(() {
                    SmsAutoScanService.instance.pendingResults?.clear();
                    _items.clear();
                  });
                  toast_lib.toast.showInfo('All SMS transactions cleared');
                },
                child: const Text(
                  'Clear all',
                  style: TextStyle(
                    fontSize: TypeScale.caption,
                    color: AppStyles.plasmaRed,
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Cards ──────────────────────────────────────────────────────────
        ..._items.map((item) {
          final p = item.parsed;
          final isExpense = p.type == 'expense';
          final accentColor = isExpense
              ? const Color(0xFFFF3B30)
              : const Color(0xFF34C759);
          final hasDup = _hasDuplicate(item, txns);

          return Dismissible(
            key: ValueKey(SmsAutoScanService.instance.fingerprint(item)),
            direction: DismissDirection.endToStart,
            background: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: AppStyles.plasmaRed.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(Radii.md),
              ),
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(CupertinoIcons.xmark_circle_fill,
                      color: AppStyles.plasmaRed, size: 22),
                  const SizedBox(height: 4),
                  const Text(
                    'Dismiss',
                    style: TextStyle(
                      color: AppStyles.plasmaRed,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            onDismissed: (_) => _dismiss(item),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _openSmsReview(item),
              child: Container(
                margin:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(Radii.md),
                  border: Border.all(color: borderColor, width: 0.5),
                ),
                child: Row(
                  children: [
                    // Left accent bar
                    Container(
                      width: 4,
                      height: 72,
                      decoration: BoxDecoration(
                        color: accentColor,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          bottomLeft: Radius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Amount + date
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  '${isExpense ? '−' : '+'}'
                                  '${CurrencyFormatter.compact(p.amount)}',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: accentColor,
                                  ),
                                ),
                                if (hasDup) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: CupertinoColors.systemOrange
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'Possible duplicate',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: CupertinoColors.systemOrange,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                if (p.merchant != null) ...[
                                  Text(
                                    p.merchant!,
                                    style: TextStyle(
                                      fontSize: TypeScale.footnote,
                                      fontWeight: FontWeight.w500,
                                      color: AppStyles.getTextColor(context),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text('·',
                                      style: TextStyle(
                                          color: AppStyles.getSecondaryTextColor(
                                              context))),
                                  const SizedBox(width: 6),
                                ],
                                Text(
                                  '${p.date.day} ${DateFormatter.getMonthName(p.date.month)}',
                                  style: TextStyle(
                                    fontSize: TypeScale.footnote,
                                    color: AppStyles.getSecondaryTextColor(
                                        context),
                                  ),
                                ),
                                if (item.matchedAccount != null) ...[
                                  const SizedBox(width: 6),
                                  Text('·',
                                      style: TextStyle(
                                          color: AppStyles.getSecondaryTextColor(
                                              context))),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      item.matchedAccount!.bankName,
                                      style: TextStyle(
                                        fontSize: TypeScale.footnote,
                                        color: AppStyles.getSecondaryTextColor(
                                            context),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Tap hint
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Column(
                        children: [
                          Icon(
                            CupertinoIcons.add_circled,
                            size: 22,
                            color: accentColor.withValues(alpha: 0.8),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Add',
                            style: TextStyle(
                              fontSize: 10,
                              color: accentColor.withValues(alpha: 0.8),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),

        // ── Hint row ───────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 2, 20, 8),
          child: Text(
            'Tap to review · Swipe left to dismiss',
            style: TextStyle(
              fontSize: TypeScale.caption,
              color: AppStyles.getSecondaryTextColor(context)
                  .withValues(alpha: 0.6),
            ),
          ),
        ),
      ],
    );
  }
}

// ── SMS Quick Confirm Sheet ──────────────────────────────────────────────────

class _SmsQuickConfirmSheet extends StatefulWidget {
  final SmsParseResult item;
  final VoidCallback onSaved;
  final VoidCallback onOpenWizard;

  const _SmsQuickConfirmSheet({
    required this.item,
    required this.onSaved,
    required this.onOpenWizard,
  });

  @override
  State<_SmsQuickConfirmSheet> createState() => _SmsQuickConfirmSheetState();
}

class _SmsQuickConfirmSheetState extends State<_SmsQuickConfirmSheet> {
  late bool _isExpense; // true = expense/income; false = transfer
  late bool _isCreditSms; // true if SMS type was 'income'
  Category? _selectedCategory;
  Account? _selectedAccount;

  @override
  void initState() {
    super.initState();
    _isCreditSms = widget.item.parsed.type == 'income';
    _isExpense = true; // default: use SMS-detected type (expense or income)
    _selectedAccount = widget.item.matchedAccount;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Pre-select the first category if none selected
    if (_selectedCategory == null && !_isCreditSms) {
      final cats =
          context.read<CategoriesController>().categories;
      if (cats.isNotEmpty) _selectedCategory = cats.first;
    }
  }

  void _save() async {
    if (_isExpense) {
      final txCtrl = context.read<TransactionsController>();
      final p = widget.item.parsed;
      final meta = <String, dynamic>{
        if (_selectedCategory != null) 'categoryId': _selectedCategory!.id,
        if (_selectedCategory != null)
          'categoryName': _selectedCategory!.name,
        if (p.merchant != null) 'merchant': p.merchant,
        if (p.upiId != null) 'upiId': p.upiId,
        'fromSms': true,
      };
      if (_selectedAccount != null) {
        meta['accountId'] = _selectedAccount!.id;
        meta['accountName'] = _selectedAccount!.name;
      }
      final tx = Transaction(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: _isCreditSms ? TransactionType.income : TransactionType.expense,
        description: p.merchant ?? p.upiId ?? 'SMS Transaction',
        dateTime: p.date,
        amount: p.amount,
        metadata: meta,
      );
      await txCtrl.addTransaction(tx);
      if (!mounted) return;
      // Update account balance if account matched
      if (_selectedAccount != null) {
        final acctCtrl = context.read<AccountsController>();
        final fresh = acctCtrl.accounts
            .where((a) => a.id == _selectedAccount!.id)
            .firstOrNull;
        if (fresh != null) {
          final delta = _isCreditSms ? p.amount : -p.amount;
          await acctCtrl.updateAccount(
              fresh.copyWith(balance: fresh.balance + delta));
        }
      }
      Navigator.pop(context);
      widget.onSaved();
      toast_lib.toast.showSuccess(
        '${_isCreditSms ? 'Income' : 'Expense'} saved — ${CurrencyFormatter.compact(p.amount)}',
      );
    } else {
      // Transfer path — open TransferWizard
      Navigator.pop(context);
      widget.onOpenWizard();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppStyles.isDarkMode(context);
    final p = widget.item.parsed;
    final sheetBg = isDark ? const Color(0xFF0A0A0F) : Colors.white;
    final accentColor = _isCreditSms
        ? const Color(0xFF34C759)
        : const Color(0xFFFF3B30);

    // Type option labels
    final smsLabel = _isCreditSms ? 'Income' : 'Expense';
    final smsIcon = _isCreditSms
        ? CupertinoIcons.arrow_down_circle_fill
        : CupertinoIcons.arrow_up_circle_fill;

    return Container(
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Handle ──────────────────────────────────────────────────────
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppStyles.getDividerColor(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            // ── Amount hero ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: accentColor.withValues(alpha: 0.3),
                          width: 0.8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: accentColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'SMS',
                          style: TextStyle(
                            fontSize: TypeScale.caption,
                            fontWeight: FontWeight.w700,
                            color: accentColor,
                          ),
                        ),
                        if (widget.item.matchedAccount != null) ...[
                          const SizedBox(width: 4),
                          Text(
                            '· ${widget.item.matchedAccount!.bankName}',
                            style: TextStyle(
                              fontSize: TypeScale.caption,
                              color: accentColor.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_isCreditSms ? '+' : '−'}${CurrencyFormatter.compact(p.amount)}',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: accentColor,
                      letterSpacing: -1.0,
                    ),
                  ),
                ],
              ),
            ),

            // ── Confirmed details row ────────────────────────────────────────
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  _confirmedChip(
                    context,
                    icon: CupertinoIcons.calendar,
                    label:
                        '${p.date.day} ${DateFormatter.getMonthName(p.date.month)} ${p.date.year}',
                  ),
                  if (p.merchant != null) ...[
                    const SizedBox(width: 8),
                    _confirmedChip(
                      context,
                      icon: CupertinoIcons.building_2_fill,
                      label: p.merchant!,
                    ),
                  ] else if (p.upiId != null) ...[
                    const SizedBox(width: 8),
                    _confirmedChip(
                      context,
                      icon: CupertinoIcons.link,
                      label: p.upiId!.length > 20
                          ? '${p.upiId!.substring(0, 20)}…'
                          : p.upiId!,
                    ),
                  ],
                ],
              ),
            ),

            // ── Type selector ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'What is this?',
                    style: TextStyle(
                      fontSize: TypeScale.caption,
                      fontWeight: FontWeight.w600,
                      color: AppStyles.getSecondaryTextColor(context),
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _typeButton(
                        context,
                        label: smsLabel,
                        icon: smsIcon,
                        color: accentColor,
                        selected: _isExpense,
                        onTap: () => setState(() => _isExpense = true),
                      ),
                      const SizedBox(width: 10),
                      _typeButton(
                        context,
                        label: 'Transfer',
                        icon: CupertinoIcons.arrow_right_arrow_left,
                        color: AppStyles.accentBlue,
                        selected: !_isExpense,
                        onTap: () => setState(() => _isExpense = false),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Category (only for expense path) ────────────────────────────
            if (_isExpense && !_isCreditSms) ...[
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.only(left: 20, right: 20, bottom: 4),
                child: Row(
                  children: [
                    Text(
                      'Category',
                      style: TextStyle(
                        fontSize: TypeScale.caption,
                        fontWeight: FontWeight.w600,
                        color: AppStyles.getSecondaryTextColor(context),
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 42,
                child: Consumer<CategoriesController>(
                  builder: (ctx, catCtrl, _) {
                    final cats = catCtrl.categories;
                    return ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: cats.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (ctx, i) {
                        final cat = cats[i];
                        final sel = _selectedCategory?.id == cat.id;
                        return GestureDetector(
                          onTap: () =>
                              setState(() => _selectedCategory = cat),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: sel
                                  ? cat.color.withValues(alpha: 0.18)
                                  : AppStyles.getBackground(context),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: sel
                                    ? cat.color
                                    : AppStyles.getDividerColor(context),
                                width: sel ? 1.5 : 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(cat.icon,
                                    size: 13,
                                    color: sel
                                        ? cat.color
                                        : AppStyles.getSecondaryTextColor(
                                            context)),
                                const SizedBox(width: 5),
                                Text(
                                  cat.name,
                                  style: TextStyle(
                                    fontSize: TypeScale.caption,
                                    fontWeight: sel
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: sel
                                        ? cat.color
                                        : AppStyles.getTextColor(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],

            // ── Account row ──────────────────────────────────────────────────
            if (_selectedAccount != null && _isExpense) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Icon(CupertinoIcons.creditcard,
                        size: 13,
                        color: AppStyles.getSecondaryTextColor(context)),
                    const SizedBox(width: 6),
                    Text(
                      _selectedAccount!.name,
                      style: TextStyle(
                        fontSize: TypeScale.footnote,
                        color: AppStyles.getSecondaryTextColor(context),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      CupertinoIcons.checkmark_circle_fill,
                      size: 12,
                      color: const Color(0xFF34C759),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            // ── Action buttons ───────────────────────────────────────────────
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  // Full wizard option
                  Expanded(
                    flex: 2,
                    child: CupertinoButton(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      color: AppStyles.getBackground(context),
                      borderRadius: BorderRadius.circular(Radii.md),
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onOpenWizard();
                      },
                      child: Text(
                        'Customize',
                        style: TextStyle(
                          fontSize: TypeScale.footnote,
                          fontWeight: FontWeight.w600,
                          color: AppStyles.getSecondaryTextColor(context),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Primary save
                  Expanded(
                    flex: 3,
                    child: CupertinoButton(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      color: _isExpense ? accentColor : AppStyles.accentBlue,
                      borderRadius: BorderRadius.circular(Radii.md),
                      onPressed: _save,
                      child: Text(
                        _isExpense
                            ? 'Save ${_isCreditSms ? 'Income' : 'Expense'}'
                            : 'Open Transfer',
                        style: const TextStyle(
                          fontSize: TypeScale.callout,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _confirmedChip(BuildContext context,
      {required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppStyles.getBackground(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppStyles.getDividerColor(context),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 11,
              color: AppStyles.getSecondaryTextColor(context)),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: TypeScale.caption,
              color: AppStyles.getSecondaryTextColor(context),
            ),
          ),
          const SizedBox(width: 4),
          const Icon(CupertinoIcons.checkmark_alt,
              size: 10, color: Color(0xFF34C759)),
        ],
      ),
    );
  }

  Widget _typeButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required Color color,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.15)
                : AppStyles.getBackground(context),
            borderRadius: BorderRadius.circular(Radii.md),
            border: Border.all(
              color: selected ? color : AppStyles.getDividerColor(context),
              width: selected ? 1.5 : 0.8,
            ),
          ),
          child: Column(
            children: [
              Icon(icon,
                  size: 22,
                  color: selected
                      ? color
                      : AppStyles.getSecondaryTextColor(context)),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: TypeScale.footnote,
                  fontWeight:
                      selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? color
                      : AppStyles.getSecondaryTextColor(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}
