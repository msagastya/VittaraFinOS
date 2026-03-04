import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/account_model.dart';
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
                            badgeColor:
                                daysUntil <= 3 ? CupertinoColors.systemRed : CupertinoColors.systemOrange,
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
        badgeColor: CupertinoColors.activeBlue,
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
              color: CupertinoColors.activeBlue,
              onPressed: () =>
                  _openInvestmentDetails(context, entry.investment),
              child: const Text(
                'Edit SIP',
                style: TextStyle(color: Colors.white, fontSize: TypeScale.footnote),
              ),
            ),
          ),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: CupertinoButton(
              padding: const EdgeInsets.symmetric(vertical: 8),
              color: CupertinoColors.systemGreen,
              onPressed: () => _showSipExecutionModal(context, entry),
              child: const Text(
                'Execute SIP',
                style: TextStyle(color: Colors.white, fontSize: TypeScale.caption),
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
                style: TextStyle(color: Colors.white, fontSize: TypeScale.footnote),
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
              fontSize: TypeScale.footnote,
            ),
          ),
        ),
        actionButtons: [
          Expanded(
            child: CupertinoButton(
              padding: const EdgeInsets.symmetric(vertical: 8),
              color: CupertinoColors.activeBlue,
              onPressed: () => _showBondPayoutModal(context, entry),
              child: const Text(
                'Edit Payout',
                style: TextStyle(color: Colors.white, fontSize: TypeScale.footnote),
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
                style: TextStyle(color: Colors.white, fontSize: TypeScale.footnote),
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

  String _formatDate(DateTime date) {return '${date.day} ${DateFormatter.getMonthName(date.month)} ${date.year}';
  }
}
