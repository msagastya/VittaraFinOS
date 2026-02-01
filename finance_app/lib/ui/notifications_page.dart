import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/accounts_controller.dart';
import 'package:vittara_fin_os/logic/bond_payout_generator.dart';
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

              // Find Bonds with upcoming payouts
              final bondsWithUpcomingPayouts = <Investment>[];
              final bondPayoutMap = <String, List<BondPayoutNotification>>{};

              for (final inv in investments) {
                if (inv.type.name != 'bonds') continue;
                final metadata = inv.metadata;
                if (metadata == null || !metadata.containsKey('payoutSchedule')) continue;

                try {
                  final payoutList = metadata['payoutSchedule'] as List?;
                  if (payoutList == null) continue;

                  final schedules = payoutList
                      .cast<Map<String, dynamic>>()
                      .map((p) => BondPayoutSchedule.fromMap(p))
                      .toList();

                  final notifications = BondPayoutGenerator.getUpcomingPayoutNotifications(schedules);

                  if (notifications.isNotEmpty) {
                    bondsWithUpcomingPayouts.add(inv);
                    bondPayoutMap[inv.id] = notifications;
                  }
                } catch (e) {
                  // Skip bonds with invalid payout data
                  continue;
                }
              }

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
                                  onPressed: () async {
                                    try {
                                      // Construct FixedDeposit from Investment metadata
                                      final fdObj = _buildFixedDepositFromInvestment(fd);
                                      final investmentsController =
                                          Provider.of<InvestmentsController>(context, listen: false);
                                      if (!context.mounted) return;
                                      Navigator.of(context).push(
                                        CupertinoPageRoute(
                                          builder: (context) =>
                                              FDRenewalModal(
                                                fd: fdObj,
                                                investmentController: investmentsController,
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
                                        ScaffoldMessenger.of(context).showSnackBar(
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
                                      final fdObj = _buildFixedDepositFromInvestment(fd);
                                      final investmentsController =
                                          Provider.of<InvestmentsController>(context, listen: false);
                                      if (!context.mounted) return;
                                      Navigator.of(context).push(
                                        CupertinoPageRoute(
                                          builder: (context) =>
                                              FDWithdrawalModal(
                                                fd: fdObj,
                                                investmentController: investmentsController,
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
                                        ScaffoldMessenger.of(context).showSnackBar(
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

                    // Bond Payout Notifications
                    if (bondsWithUpcomingPayouts.isNotEmpty)
                      ...bondsWithUpcomingPayouts.expand((bond) {
                        final notifications = bondPayoutMap[bond.id] ?? [];
                        return notifications.map((notif) {
                          final daysUntil = notif.daysUntil;
                          final badgeColor = daysUntil <= 3
                              ? Colors.red
                              : (daysUntil < 0 ? Colors.purple : Colors.orange);

                          return Container(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            child: NotificationWidget(
                              type: NotificationType.fdPayout,
                              title: bond.name,
                              subtitle: 'Payout #${notif.payoutNumber} on ${_formatDashboardDate(notif.payoutDate)}',
                              amount: '₹—', // Will be entered by user
                              timeInfo: daysUntil < 0
                                  ? '${daysUntil.abs()} day${daysUntil.abs() > 1 ? 's' : ''} overdue'
                                  : 'In $daysUntil day${daysUntil > 1 ? 's' : ''}',
                              badgeColor: badgeColor,
                              icon: CupertinoIcons.money_dollar,
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
                                      color: AppStyles
                                          .getSecondaryTextColor(context),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Enter amount, date & account to confirm',
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
                              actionButtons: [
                                Expanded(
                                  child: CupertinoButton(
                                    color: Colors.blue,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 8, horizontal: 12),
                                    onPressed: () {
                                      _showBondPayoutModal(
                                        context,
                                        bond,
                                        notif,
                                      );
                                    },
                                    child: const Text(
                                      'Record Payout',
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
                        });
                      }),

                    // Empty State
                    if (fdsNearMaturity.isEmpty &&
                        fdsMatured.isEmpty &&
                        rdsWithUpcomingInstallments.isEmpty &&
                        bondsWithUpcomingPayouts.isEmpty)
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

  void _showBondPayoutModal(
    BuildContext context,
    Investment bond,
    BondPayoutNotification notification,
  ) {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => _BondPayoutModal(
        bond: bond,
        notification: notification,
      ),
    );
  }
}

// Bond Payout Entry Modal
class _BondPayoutModal extends StatefulWidget {
  final Investment bond;
  final BondPayoutNotification notification;

  const _BondPayoutModal({
    required this.bond,
    required this.notification,
  });

  @override
  State<_BondPayoutModal> createState() => _BondPayoutModalState();
}

class _BondPayoutModalState extends State<_BondPayoutModal> {
  late TextEditingController _amountController;
  late DateTime _selectedDate;
  String? _selectedAccountId;
  String? _selectedAccountName;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController();
    _selectedDate = widget.notification.payoutDate;
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Record Bond Payout'),
        previousPageTitle: 'Back',
        backgroundColor: AppStyles.getBackground(context),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Payout Details
              Text(
                'Payout Details',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppStyles.getTextColor(context),
                ),
              ),
              const SizedBox(height: 20),

              // Bond Name
              Text(
                'Bond',
                style: TextStyle(
                  fontSize: 13,
                  color: AppStyles.getSecondaryTextColor(context),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppStyles.getCardColor(context),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.withOpacity(0.2)),
                ),
                child: Text(
                  widget.bond.name,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppStyles.getTextColor(context),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Payout Amount
              Text(
                'Payout Amount',
                style: TextStyle(
                  fontSize: 13,
                  color: AppStyles.getSecondaryTextColor(context),
                ),
              ),
              const SizedBox(height: 8),
              CupertinoTextField(
                controller: _amountController,
                placeholder: '0.00',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppStyles.getCardColor(context),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.withOpacity(0.2)),
                ),
                prefix: Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: const Text('₹'),
                ),
              ),
              const SizedBox(height: 20),

              // Payout Date
              Text(
                'Payout Date',
                style: TextStyle(
                  fontSize: 13,
                  color: AppStyles.getSecondaryTextColor(context),
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () {
                  showCupertinoModalPopup(
                    context: context,
                    builder: (ctx) => Container(
                      height: 300,
                      color: AppStyles.getBackground(context),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppStyles.getCardColor(context),
                              border: Border(
                                bottom: BorderSide(color: Colors.grey.withOpacity(0.2)),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Select Date',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => Navigator.pop(ctx),
                                  child: const Icon(CupertinoIcons.xmark),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: CupertinoDatePicker(
                              mode: CupertinoDatePickerMode.date,
                              initialDateTime: _selectedDate,
                              onDateTimeChanged: (newDate) {
                                setState(() {
                                  _selectedDate = newDate;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppStyles.getCardColor(context),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                        style: TextStyle(color: AppStyles.getTextColor(context)),
                      ),
                      const Icon(CupertinoIcons.calendar),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Credit Account Selection
              Text(
                'Credit Account',
                style: TextStyle(
                  fontSize: 13,
                  color: AppStyles.getSecondaryTextColor(context),
                ),
              ),
              const SizedBox(height: 8),
              Consumer<AccountsController>(
                builder: (context, accountsController, child) {
                  return Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: AppStyles.getCardColor(context),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.withOpacity(0.2)),
                        ),
                        child: CupertinoButton(
                          onPressed: () {
                            showCupertinoModalPopup(
                              context: context,
                              builder: (ctx) => Container(
                                height: 400,
                                decoration: BoxDecoration(
                                  color: AppStyles.getCardColor(context),
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(12),
                                    topRight: Radius.circular(12),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        border: Border(
                                          bottom: BorderSide(color: Colors.grey.withOpacity(0.2)),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text(
                                            'Select Account',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          GestureDetector(
                                            onTap: () => Navigator.pop(ctx),
                                            child: const Icon(CupertinoIcons.xmark),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      child: ListView.builder(
                                        itemCount: accountsController.accounts.length,
                                        itemBuilder: (context, index) {
                                          final account = accountsController.accounts[index];
                                          final isSelected = _selectedAccountId == account.id;

                                          return GestureDetector(
                                            onTap: () {
                                              setState(() {
                                                _selectedAccountId = account.id;
                                                _selectedAccountName = account.name;
                                              });
                                              Navigator.pop(ctx);
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.all(12),
                                              margin: const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 8,
                                              ),
                                              decoration: BoxDecoration(
                                                color: isSelected
                                                    ? Colors.blue.withOpacity(0.1)
                                                    : AppStyles.getBackground(context),
                                                border: Border.all(
                                                  color: isSelected
                                                      ? Colors.blue
                                                      : Colors.transparent,
                                                ),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Row(
                                                children: [
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(
                                                          account.name,
                                                          style: const TextStyle(
                                                            fontWeight: FontWeight.w600,
                                                            fontSize: 14,
                                                          ),
                                                        ),
                                                        Text(
                                                          account.bankName,
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            color: AppStyles.getSecondaryTextColor(
                                                              context,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  if (isSelected)
                                                    const Icon(
                                                      CupertinoIcons.checkmark_alt_circle_fill,
                                                      color: Colors.blue,
                                                    ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                          padding: EdgeInsets.zero,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              if (_selectedAccountId == null)
                                Text(
                                  'Select account',
                                  style: TextStyle(
                                    color: AppStyles.getSecondaryTextColor(context),
                                  ),
                                )
                              else
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _selectedAccountName ?? 'Unknown',
                                        style: TextStyle(
                                          color: AppStyles.getTextColor(context),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              const Icon(CupertinoIcons.down_arrow),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 40),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: CupertinoButton.filled(
                  onPressed: _selectedAccountId == null || _amountController.text.isEmpty
                      ? null
                      : () async {
                          final investmentsController =
                              Provider.of<InvestmentsController>(context, listen: false);

                          try {
                            // Create payout record
                            final payoutRecord = BondPayoutRecord(
                              payoutNumber: widget.notification.payoutNumber,
                              scheduledPayoutDate: widget.notification.payoutDate,
                              payoutAmount: double.parse(_amountController.text),
                              actualPayoutDate: _selectedDate,
                              creditAccountId: _selectedAccountId,
                              creditAccountName: _selectedAccountName,
                              recordedDate: DateTime.now(),
                            );

                            // Update bond metadata with payout record
                            final updatedMetadata = Map<String, dynamic>.from(widget.bond.metadata ?? {});
                            final pastPayouts = (updatedMetadata['pastPayouts'] as List?)?.cast<Map<String, dynamic>>() ?? [];
                            pastPayouts.add(payoutRecord.toMap());
                            updatedMetadata['pastPayouts'] = pastPayouts;

                            final updatedBond = widget.bond.copyWith(metadata: updatedMetadata);
                            await investmentsController.updateInvestment(updatedBond);

                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Payout recorded successfully!')),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e')),
                              );
                            }
                          }
                        },
                  child: const Text('Save Payout'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
