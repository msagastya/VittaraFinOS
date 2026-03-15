import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/fixed_deposit_model.dart';
import 'package:vittara_fin_os/logic/investments_controller.dart';
import 'package:vittara_fin_os/logic/fd_renewal_cycle.dart';
import 'package:vittara_fin_os/logic/fd_calculations.dart';
import 'package:vittara_fin_os/logic/accounts_controller.dart';
import 'package:vittara_fin_os/utils/date_formatter.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/widgets/animations.dart';
import 'package:vittara_fin_os/ui/widgets/toast_notification.dart';
import 'package:vittara_fin_os/ui/manage/fd/fd_renewal_wizard_screen.dart';
import 'package:vittara_fin_os/ui/manage/fd/modals/fd_withdrawal_modal.dart';

class FDDetailsScreen extends StatefulWidget {
  final FixedDeposit fd;

  const FDDetailsScreen({
    required this.fd,
    super.key,
  });

  @override
  State<FDDetailsScreen> createState() => _FDDetailsScreenState();
}

class _FDDetailsScreenState extends State<FDDetailsScreen> {
  bool _isFDNearMaturity() {
    final alertEnabled =
        widget.fd.metadata?['maturityAlertEnabled'] as bool? ?? true;
    if (!alertEnabled) return false;
    final daysUntil = widget.fd.maturityDate.difference(DateTime.now()).inDays;
    return daysUntil <= 10 && daysUntil >= 0;
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppStyles.getBackground(context),
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          'FD Details',
          style: TextStyle(color: AppStyles.getTextColor(context)),
        ),
        previousPageTitle: 'Investments',
        backgroundColor: AppStyles.getBackground(context),
        border: null,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Maturity Alert (if within 10 days)
              if (_isFDNearMaturity()) _buildMaturityAlert(context),

              // Header Card with Key Information
              Container(
                padding: const EdgeInsets.all(Spacing.xl),
                decoration: BoxDecoration(
                  color: AppStyles.getCardColor(context),
                  border: Border(
                    bottom: BorderSide(
                      color: AppStyles.getDividerColor(context),
                      width: 0.5,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // FD Name and Status
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.fd.name,
                                style: TextStyle(
                                  color: AppStyles.getTextColor(context),
                                  fontSize: TypeScale.title2,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: Spacing.xs),
                              Text(
                                'Linked: ${widget.fd.linkedAccountName}',
                                style: TextStyle(
                                  color:
                                      AppStyles.getSecondaryTextColor(context),
                                  fontSize: TypeScale.subhead,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _getStatusColor(widget.fd.status)
                                .withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            widget.fd.getStatusLabel(),
                            style: TextStyle(
                              color: _getStatusColor(widget.fd.status),
                              fontSize: TypeScale.footnote,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Spacing.xl),
                    // Key Metrics
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildMetric(
                          context,
                          'Principal',
                          '₹${widget.fd.principal.toStringAsFixed(0)}',
                          AppStyles.getSecondaryTextColor(context),
                        ),
                        _buildMetric(
                          context,
                          'Current Value',
                          '₹${_getCurrentValue().toStringAsFixed(0)}',
                          AppStyles.getPrimaryColor(context),
                        ),
                        _buildMetric(
                          context,
                          'CAGR',
                          '${_calculateCAGR(widget.fd).toStringAsFixed(2)}%',
                          AppStyles.bioGreen,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Detailed Information
              Container(
                padding: const EdgeInsets.all(Spacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Timeline Section
                    Text(
                      'Timeline',
                      style: TextStyle(
                        color: AppStyles.getTextColor(context),
                        fontWeight: FontWeight.bold,
                        fontSize: TypeScale.headline,
                      ),
                    ),
                    const SizedBox(height: Spacing.lg),
                    _buildTimelineItem(
                      context,
                      'Created',
                      _formatDate(widget.fd.createdDate),
                      CupertinoIcons.checkmark_circle,
                    ),
                    _buildTimelineItem(
                      context,
                      'Investment Date',
                      _formatDate(widget.fd.investmentDate),
                      CupertinoIcons.checkmark_circle,
                    ),
                    _buildTimelineItem(
                      context,
                      'Maturity Date',
                      _formatDate(_getMaturityDate()),
                      widget.fd.daysUntilMaturity <= 0
                          ? CupertinoIcons.checkmark_circle
                          : CupertinoIcons.clock,
                    ),
                    if (_hasBeenRenewed())
                      _buildTimelineItem(
                        context,
                        'Renewed',
                        _formatDate(_getRenewalDate() ?? DateTime.now()),
                        CupertinoIcons.checkmark_circle,
                      ),
                    const SizedBox(height: Spacing.xl),
                    // Details Grid
                    Text(
                      'Details',
                      style: TextStyle(
                        color: AppStyles.getTextColor(context),
                        fontWeight: FontWeight.bold,
                        fontSize: TypeScale.headline,
                      ),
                    ),
                    const SizedBox(height: Spacing.lg),
                    _buildDetailRow(
                      'Interest Rate',
                      '${_getLatestRenewalCycle()?.interestRate ?? widget.fd.interestRate}% p.a.',
                    ),
                    _buildDetailRow(
                      'Tenure',
                      '${_getLatestRenewalCycle()?.tenureMonths ?? widget.fd.tenureMonths} months',
                    ),
                    _buildDetailRow(
                      'Elapsed',
                      '${_getElapsed()['elapsed']} of ${_getElapsed()['total']} months',
                    ),
                    _buildDetailRow(
                        'Compounding', widget.fd.getCompoundingLabel()),
                    _buildDetailRow(
                        'Payout Frequency', widget.fd.getPayoutLabel()),
                    _buildDetailRow(
                        'FD Type',
                        widget.fd.isCumulative
                            ? 'Cumulative'
                            : 'Non-Cumulative'),
                    _buildDetailRow(
                      'Maturity Value',
                      '₹${(_getLatestRenewalCycle()?.maturityValue ?? widget.fd.maturityValue).toStringAsFixed(2)}',
                      isHighlight: true,
                    ),
                    _buildDetailRow(
                      'Total Interest',
                      '₹${_getTotalInterest().toStringAsFixed(2)}',
                    ),
                    const SizedBox(height: Spacing.xl),
                    _buildTdsSection(context),
                    const SizedBox(height: Spacing.xl),
                    // Status-specific info
                    if (widget.fd.status == FDStatus.prematurelyWithdrawn)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Withdrawal Details',
                            style: TextStyle(
                              color: AppStyles.getTextColor(context),
                              fontWeight: FontWeight.bold,
                              fontSize: TypeScale.body,
                            ),
                          ),
                          const SizedBox(height: Spacing.md),
                          _buildDetailRow(
                            'Withdrawal Date',
                            _formatDate(
                                widget.fd.withdrawalDate ?? DateTime.now()),
                          ),
                          _buildDetailRow(
                            'Withdrawal Amount',
                            '₹${(widget.fd.withdrawalAmount ?? 0).toStringAsFixed(2)}',
                          ),
                          if (widget.fd.withdrawalReason != null)
                            _buildDetailRow(
                              'Reason',
                              widget.fd.withdrawalReason ?? 'N/A',
                            ),
                        ],
                      ),
                  ],
                ),
              ),
              // Action Buttons
              _buildActionButtons(context),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetric(
    BuildContext context,
    String label,
    String value,
    Color color,
  ) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppStyles.getSecondaryTextColor(context),
            fontSize: TypeScale.footnote,
          ),
        ),
        const SizedBox(height: Spacing.sm),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineItem(
    BuildContext context,
    String title,
    String date,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppStyles.getPrimaryColor(context)),
          const SizedBox(width: Spacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: AppStyles.getSecondaryTextColor(context),
                    fontSize: TypeScale.footnote,
                  ),
                ),
                const SizedBox(height: Spacing.xs),
                Text(
                  date,
                  style: TextStyle(
                    color: AppStyles.getTextColor(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    bool isHighlight = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppStyles.getSecondaryTextColor(context),
              fontSize: TypeScale.subhead,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: AppStyles.getTextColor(context),
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.w600,
              fontSize: isHighlight ? 14 : 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.fd.status == FDStatus.active) ...[
            _buildActionButton(
              context,
              'Premature Withdrawal',
              'Withdraw before maturity',
              CupertinoIcons.money_dollar_circle,
              CupertinoColors.systemOrange,
              () => _showPrematureWithdrawalModal(context),
            ),
            const SizedBox(height: Spacing.md),
          ],
          _buildActionButton(
            context,
            'Payout Schedule',
            'View all payouts',
            CupertinoIcons.calendar,
            AppStyles.getPrimaryColor(context),
            () => _showPayoutScheduleModal(context),
          ),
          const SizedBox(height: Spacing.md),
          _buildActionButton(
            context,
            'Edit Details',
            'Modify auto-link settings',
            CupertinoIcons.pencil,
            CupertinoColors.systemPurple,
            () => _showEditModal(context),
          ),
          const SizedBox(height: Spacing.md),
          _buildActionButton(
            context,
            'View History',
            'See all transactions',
            CupertinoIcons.clock,
            AppStyles.getSecondaryTextColor(context),
            () => _showHistoryModal(context),
          ),
          const SizedBox(height: Spacing.md),
          _buildActionButton(
            context,
            'Delete',
            'Remove this FD',
            CupertinoIcons.trash,
            AppStyles.plasmaRed,
            () => _showDeleteConfirmation(context),
            isDangerous: true,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    String title,
    String description,
    IconData icon,
    Color color,
    VoidCallback onTap, {
    bool isDangerous = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(Spacing.lg),
        decoration: BoxDecoration(
          color: AppStyles.getCardColor(context),
          borderRadius: BorderRadius.circular(Radii.md),
          border: isDangerous
              ? Border.all(color: color.withValues(alpha: 0.3), width: 1)
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: Spacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: AppStyles.getTextColor(context),
                      fontWeight: FontWeight.bold,
                      fontSize: TypeScale.callout,
                    ),
                  ),
                  Text(
                    description,
                    style: TextStyle(
                      color: AppStyles.getSecondaryTextColor(context),
                      fontSize: TypeScale.footnote,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              CupertinoIcons.chevron_right,
              color: AppStyles.getSecondaryTextColor(context),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  void _showReinvestModal(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        color: AppStyles.getBackground(context),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(Spacing.lg),
                decoration: BoxDecoration(
                  color: AppStyles.getCardColor(context),
                  border: Border(
                    bottom: BorderSide(
                      color: AppStyles.getDividerColor(context),
                      width: 0.5,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Reinvest FD',
                      style: TextStyle(
                        color: AppStyles.getTextColor(context),
                        fontSize: TypeScale.headline,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Icon(
                        CupertinoIcons.xmark_circle_fill,
                        color: AppStyles.getSecondaryTextColor(context),
                      ),
                    ),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(Spacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Maturity Value',
                        style: TextStyle(
                          color: AppStyles.getSecondaryTextColor(context),
                          fontSize: TypeScale.footnote,
                        ),
                      ),
                      const SizedBox(height: Spacing.sm),
                      Text(
                        '₹${widget.fd.maturityValue.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: AppStyles.bioGreen,
                          fontSize: TypeScale.title2,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: Spacing.xxl),
                      Text(
                        'Options',
                        style: TextStyle(
                          color: AppStyles.getTextColor(context),
                          fontSize: TypeScale.body,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: Spacing.md),
                      _buildReinvestOption(
                        context,
                        'Create New FD',
                        'Invest maturity amount in a new FD',
                        () {
                          Navigator.of(context).pop();
                          toast.showSuccess(
                              'Create new FD with ₹${widget.fd.maturityValue.toStringAsFixed(0)}');
                        },
                      ),
                      const SizedBox(height: Spacing.md),
                      _buildReinvestOption(
                        context,
                        'Transfer to Account',
                        'Move maturity amount to linked account',
                        () {
                          Navigator.of(context).pop();
                          toast.showSuccess('Amount transferred to account');
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReinvestOption(
    BuildContext context,
    String title,
    String description,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(Spacing.lg),
        decoration: BoxDecoration(
          color: AppStyles.getCardColor(context),
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(
            color: AppStyles.getPrimaryColor(context).withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color:
                    AppStyles.getPrimaryColor(context).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                CupertinoIcons.plus,
                color: AppStyles.getPrimaryColor(context),
              ),
            ),
            const SizedBox(width: Spacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: AppStyles.getTextColor(context),
                      fontWeight: FontWeight.w600,
                      fontSize: TypeScale.body,
                    ),
                  ),
                  const SizedBox(height: Spacing.xs),
                  Text(
                    description,
                    style: TextStyle(
                      color: AppStyles.getSecondaryTextColor(context),
                      fontSize: TypeScale.footnote,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              CupertinoIcons.chevron_right,
              color: AppStyles.getSecondaryTextColor(context),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  void _showPrematureWithdrawalModal(BuildContext context) {
    DateTime withdrawalDate = DateTime.now();
    late TextEditingController withdrawalAmountController;

    double calculateWithdrawalAmount(DateTime selectedDate) {
      final daysSinceInvestment =
          selectedDate.difference(widget.fd.investmentDate).inDays;
      final totalDays =
          widget.fd.maturityDate.difference(widget.fd.investmentDate).inDays;
      final adjustedDays =
          daysSinceInvestment > totalDays ? totalDays : daysSinceInvestment;
      final elapsedFraction = adjustedDays / totalDays;
      final accruedInterest =
          widget.fd.totalInterestAtMaturity * elapsedFraction;
      final monthsElapsed = (adjustedDays / 30.44).toInt();
      final penaltyPercentage = monthsElapsed < 12 ? 1.0 : 0.5;
      final penaltyAmount = (accruedInterest * penaltyPercentage) / 100;
      return widget.fd.principal + accruedInterest - penaltyAmount;
    }

    showCupertinoModalPopup(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final initialAmount = calculateWithdrawalAmount(withdrawalDate);
          withdrawalAmountController = TextEditingController(
            text: initialAmount.toStringAsFixed(2),
          );

          return Container(
            color: AppStyles.getBackground(context),
            child: SafeArea(
              top: true,
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(Spacing.lg),
                    decoration: BoxDecoration(
                      color: AppStyles.getCardColor(context),
                      border: Border(
                        bottom: BorderSide(
                          color: AppStyles.getDividerColor(context),
                          width: 0.5,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Premature Withdrawal',
                          style: TextStyle(
                            color: AppStyles.getTextColor(context),
                            fontSize: TypeScale.headline,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Icon(
                            CupertinoIcons.xmark_circle_fill,
                            color: AppStyles.getSecondaryTextColor(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(Spacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(Spacing.md),
                            decoration: BoxDecoration(
                              color: CupertinoColors.systemOrange
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  CupertinoIcons.exclamationmark_triangle_fill,
                                  color: CupertinoColors.systemOrange,
                                  size: 16,
                                ),
                                const SizedBox(width: Spacing.sm),
                                Expanded(
                                  child: Text(
                                    'Early withdrawal may incur penalties and reduced interest.',
                                    style: TextStyle(
                                      color: CupertinoColors.systemOrange,
                                      fontSize: TypeScale.footnote,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: Spacing.xl),
                          // Withdrawal Date
                          Text(
                            'Withdrawal Date',
                            style: TextStyle(
                              color: AppStyles.getTextColor(context),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: Spacing.sm),
                          GestureDetector(
                            onTap: () async {
                              final picked =
                                  await showCupertinoModalPopup<DateTime>(
                                context: context,
                                builder: (BuildContext context) {
                                  return Container(
                                    height: 216,
                                    padding: const EdgeInsets.only(top: 6.0),
                                    margin: EdgeInsets.only(
                                      bottom: MediaQuery.of(context)
                                          .viewInsets
                                          .bottom,
                                    ),
                                    color: CupertinoColors.systemBackground
                                        .resolveFrom(context),
                                    child: SafeArea(
                                      top: false,
                                      child: CupertinoDatePicker(
                                        initialDateTime: withdrawalDate,
                                        mode: CupertinoDatePickerMode.date,
                                        minimumDate: widget.fd.investmentDate,
                                        maximumDate: DateTime.now(),
                                        onDateTimeChanged: (DateTime newDate) {
                                          setState(() {
                                            withdrawalDate = newDate;
                                          });
                                        },
                                      ),
                                    ),
                                  );
                                },
                              );
                              if (picked != null) {
                                setState(() {
                                  withdrawalDate = picked;
                                });
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(Spacing.md),
                              decoration: BoxDecoration(
                                color: AppStyles.getCardColor(context),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppStyles.getDividerColor(context),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    withdrawalDate.toString().split(' ')[0],
                                    style: TextStyle(
                                      color: AppStyles.getTextColor(context),
                                      fontSize: TypeScale.body,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Icon(
                                    CupertinoIcons.calendar,
                                    color: AppStyles.getPrimaryColor(context),
                                    size: 18,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: Spacing.xl),
                          Text(
                            'Withdrawal Amount',
                            style: TextStyle(
                              color: AppStyles.getTextColor(context),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: Spacing.sm),
                          Text(
                            'Expected amount (you can adjust if agreed with bank)',
                            style: TextStyle(
                              color: AppStyles.getSecondaryTextColor(context),
                              fontSize: TypeScale.footnote,
                            ),
                          ),
                          const SizedBox(height: Spacing.sm),
                          CupertinoTextField(
                            controller: withdrawalAmountController,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            padding: const EdgeInsets.all(Spacing.md),
                            decoration: BoxDecoration(
                              color: AppStyles.getCardColor(context),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            prefix: Padding(
                              padding: const EdgeInsets.only(left: 12),
                              child: Text(
                                '₹',
                                style: TextStyle(
                                  color: AppStyles.getTextColor(context),
                                  fontWeight: FontWeight.bold,
                                  fontSize: TypeScale.headline,
                                ),
                              ),
                            ),
                            style: TextStyle(
                              color: AppStyles.getTextColor(context),
                              fontSize: TypeScale.headline,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: Spacing.xxl),
                          Text(
                            'Linked Account',
                            style: TextStyle(
                              color: AppStyles.getSecondaryTextColor(context),
                              fontSize: TypeScale.footnote,
                            ),
                          ),
                          const SizedBox(height: Spacing.sm),
                          Text(
                            widget.fd.linkedAccountName,
                            style: TextStyle(
                              color: AppStyles.getTextColor(context),
                              fontSize: TypeScale.body,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: Spacing.xxl),
                        ],
                      ),
                    ),
                  ),
                  // Action buttons
                  Container(
                    padding: const EdgeInsets.all(Spacing.lg),
                    decoration: BoxDecoration(
                      color: AppStyles.getCardColor(context),
                      border: Border(
                        top: BorderSide(
                          color: AppStyles.getDividerColor(context),
                          width: 0.5,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: CupertinoButton(
                            onPressed: () => Navigator.of(context).pop(),
                            color: AppStyles.getSecondaryTextColor(context)
                                .withValues(alpha: 0.3),
                            child: Text(
                              'Cancel',
                              style: TextStyle(
                                color: AppStyles.getSecondaryTextColor(context),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: Spacing.md),
                        Expanded(
                          child: CupertinoButton(
                            onPressed: () async {
                              final amount = double.tryParse(
                                      withdrawalAmountController.text) ??
                                  calculateWithdrawalAmount(withdrawalDate);
                              final confirmed = await showCupertinoDialog<bool>(
                                context: context,
                                builder: (BuildContext context) {
                                  return CupertinoAlertDialog(
                                    title: const Text('Confirm Withdrawal'),
                                    content: Column(
                                      children: [
                                        const SizedBox(height: Spacing.sm),
                                        Text(
                                          'Amount: ₹${amount.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            fontSize: TypeScale.headline,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: Spacing.sm),
                                        Text(
                                          'Date: ${withdrawalDate.toString().split(' ')[0]}',
                                          style: TextStyle(
                                            fontSize: TypeScale.body,
                                            color:
                                                AppStyles.getSecondaryTextColor(
                                                    context),
                                          ),
                                        ),
                                        const SizedBox(height: Spacing.md),
                                        const Text(
                                          'Do you want to credit this amount to your linked account?',
                                        ),
                                      ],
                                    ),
                                    actions: [
                                      CupertinoDialogAction(
                                        onPressed: () =>
                                            Navigator.of(context).pop(false),
                                        child: const Text('No'),
                                      ),
                                      CupertinoDialogAction(
                                        isDestructiveAction: false,
                                        onPressed: () =>
                                            Navigator.of(context).pop(true),
                                        child:
                                            const Text('Yes, Credit Account'),
                                      ),
                                    ],
                                  );
                                },
                              );

                              if (confirmed == true && mounted) {
                                try {
                                  // Get the investments controller
                                  final investmentsController =
                                      Provider.of<InvestmentsController>(
                                          context,
                                          listen: false);

                                  // Find the original investment from the controller
                                  final originalInvestment =
                                      investmentsController.investments
                                          .firstWhere(
                                    (inv) => inv.id == widget.fd.id,
                                    orElse: () =>
                                        throw Exception('Investment not found'),
                                  );

                                  // Get existing renewal cycles
                                  final existingCycles = <FDRenewalCycle>[];
                                  final cyclesData = originalInvestment
                                      .metadata?['renewalCycles'] as List?;
                                  if (cyclesData != null) {
                                    for (var c in cyclesData) {
                                      final cycleMap =
                                          Map<String, dynamic>.from(c as Map);
                                      existingCycles.add(
                                          FDRenewalCycle.fromMap(cycleMap));
                                    }
                                  }

                                  // If no cycles exist, create the first one from the FD
                                  if (existingCycles.isEmpty) {
                                    existingCycles.add(FDRenewalCycle(
                                      cycleNumber: 1,
                                      investmentDate: widget.fd.investmentDate,
                                      maturityDate: widget.fd.maturityDate,
                                      principal: widget.fd.principal,
                                      interestRate: widget.fd.interestRate,
                                      tenureMonths: widget.fd.tenureMonths,
                                      maturityValue: widget.fd.maturityValue,
                                      isWithdrawn: false,
                                      isCompleted: false,
                                    ));
                                  }

                                  // Mark the last cycle as withdrawn
                                  if (existingCycles.isNotEmpty) {
                                    final lastCycle = existingCycles.last;
                                    existingCycles[existingCycles.length - 1] =
                                        lastCycle.copyWith(
                                      isWithdrawn: true,
                                      withdrawalDate: withdrawalDate,
                                      withdrawalAmount: amount,
                                      withdrawalReason: 'Premature withdrawal',
                                    );
                                  }

                                  // Update the investment with withdrawal cycle
                                  final existingMetadata =
                                      originalInvestment.metadata ?? {};
                                  final safeMetadata =
                                      Map<String, dynamic>.from(
                                          existingMetadata);

                                  final updatedInvestment =
                                      originalInvestment.copyWith(
                                    metadata: {
                                      ...safeMetadata,
                                      'renewalCycles': existingCycles
                                          .map((c) => c.toMap())
                                          .toList(),
                                      'withdrawalDate':
                                          withdrawalDate.toIso8601String(),
                                      'withdrawalAmount': amount,
                                      'withdrawalReason':
                                          'Premature withdrawal',
                                      'status': 'withdrawn',
                                    },
                                  );

                                  // Update the investment
                                  await investmentsController
                                      .updateInvestment(updatedInvestment);

                                  if (!mounted) return;
                                  // Credit the linked account
                                  final linkedAccountId =
                                      widget.fd.linkedAccountId;
                                  if (linkedAccountId.isNotEmpty && mounted) {
                                    try {
                                      final accountsController =
                                          Provider.of<AccountsController>(
                                              context,
                                              listen: false);
                                      try {
                                        final linkedAccount = accountsController
                                            .accounts
                                            .firstWhere(
                                          (acc) => acc.id == linkedAccountId,
                                          orElse: () => throw Exception(
                                              'Account not found'),
                                        );
                                        final updatedAccount =
                                            linkedAccount.copyWith(
                                          balance:
                                              linkedAccount.balance + amount,
                                        );
                                        await accountsController
                                            .updateAccount(updatedAccount);
                                      } catch (e) {
                                        // Account not found
                                      }
                                    } catch (e) {
                                      // Continue even if account credit fails
                                    }
                                  }

                                  if (mounted) {
                                    Navigator.of(context).pop();
                                    toast.showSuccess(
                                        'Withdrawal completed. Amount: ₹${amount.toStringAsFixed(2)}');
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    toast.showError(
                                        'Error processing withdrawal: $e');
                                  }
                                }
                              }
                            },
                            color: CupertinoColors.systemOrange,
                            child: const Text('Withdraw'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showPayoutScheduleModal(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        color: AppStyles.getBackground(context),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(Spacing.lg),
              decoration: BoxDecoration(
                color: AppStyles.getCardColor(context),
                border: Border(
                  bottom: BorderSide(
                    color: AppStyles.getDividerColor(context),
                    width: 0.5,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Payout Schedule',
                    style: TextStyle(
                      color: AppStyles.getTextColor(context),
                      fontSize: TypeScale.headline,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Icon(
                      CupertinoIcons.xmark_circle_fill,
                      color: AppStyles.getSecondaryTextColor(context),
                    ),
                  ),
                ],
              ),
            ),
            // Payout list
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(
                    top: 32, left: 16, right: 16, bottom: 16),
                child: Column(
                  children: [
                    // Past payouts
                    if (widget.fd.pastPayouts.isNotEmpty) ...[
                      Text(
                        'Past Payouts',
                        style: TextStyle(
                          color: AppStyles.getTextColor(context),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: Spacing.md),
                      ...widget.fd.pastPayouts.map((payout) {
                        return _buildPayoutItem(context, payout, isPast: true);
                      }),
                      const SizedBox(height: Spacing.xl),
                    ],
                    // Upcoming payouts
                    if (widget.fd.upcomingPayouts.isNotEmpty) ...[
                      Text(
                        'Upcoming Payouts',
                        style: TextStyle(
                          color: AppStyles.getTextColor(context),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: Spacing.md),
                      ...widget.fd.upcomingPayouts.map((payout) {
                        return _buildPayoutItem(context, payout, isPast: false);
                      }),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPayoutItem(BuildContext context, PayoutRecord payout,
      {required bool isPast}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: AppStyles.getCardColor(context),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatDate(payout.payoutDate),
                  style: TextStyle(
                    color: AppStyles.getTextColor(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: Spacing.xs),
                Text(
                  payout.payoutType == 'interest'
                      ? 'Interest'
                      : payout.payoutType == 'principal'
                          ? 'Principal'
                          : 'Interest + Principal',
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
                '₹${(payout.interestAmount + payout.principalAmount).toStringAsFixed(2)}',
                style: TextStyle(
                  color: isPast
                      ? AppStyles.bioGreen
                      : AppStyles.getPrimaryColor(context),
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (isPast)
                Text(
                  'Credited',
                  style: TextStyle(
                    color: AppStyles.bioGreen,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _showEditModal(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        color: AppStyles.getBackground(context),
        child: SafeArea(
          top: true,
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(Spacing.lg),
                decoration: BoxDecoration(
                  color: AppStyles.getCardColor(context),
                  border: Border(
                    bottom: BorderSide(
                      color: AppStyles.getDividerColor(context),
                      width: 0.5,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Edit FD Settings',
                      style: TextStyle(
                        color: AppStyles.getTextColor(context),
                        fontSize: TypeScale.headline,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Icon(
                        CupertinoIcons.xmark_circle_fill,
                        color: AppStyles.getSecondaryTextColor(context),
                      ),
                    ),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(
                      top: 32, left: 16, right: 16, bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Auto-Link Settings',
                        style: TextStyle(
                          color: AppStyles.getTextColor(context),
                          fontSize: TypeScale.body,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: Spacing.lg),
                      Container(
                        padding: const EdgeInsets.all(Spacing.lg),
                        decoration: BoxDecoration(
                          color: AppStyles.getCardColor(context),
                          borderRadius: BorderRadius.circular(Radii.md),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Auto-Link Payouts',
                                    style: TextStyle(
                                      color: AppStyles.getTextColor(context),
                                      fontWeight: FontWeight.w600,
                                      fontSize: TypeScale.body,
                                    ),
                                  ),
                                  const SizedBox(height: Spacing.xs),
                                  Text(
                                    'Auto-credit payouts to linked account',
                                    style: TextStyle(
                                      color: AppStyles.getSecondaryTextColor(
                                          context),
                                      fontSize: TypeScale.footnote,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            CupertinoSwitch(
                              value: widget.fd.autoLinkEnabled,
                              onChanged: (value) async {
                                try {
                                  if (!mounted) return;
                                  final investmentsController =
                                      Provider.of<InvestmentsController>(
                                          context,
                                          listen: false);

                                  // Create updated FD with new autoLinkEnabled value
                                  final updatedFD = widget.fd.copyWith(
                                    autoLinkEnabled: value,
                                  );

                                  // Create updated Investment with new FD data
                                  final currentInvestment =
                                      investmentsController.investments
                                          .firstWhere(
                                    (inv) => inv.id == widget.fd.id,
                                    orElse: () =>
                                        throw Exception('Investment not found'),
                                  );

                                  final updatedInvestment =
                                      currentInvestment.copyWith(
                                    metadata: {
                                      ...?currentInvestment.metadata,
                                      'fdData': updatedFD.toMap(),
                                      'autoLink': value,
                                    },
                                  );

                                  // Update the investment
                                  await investmentsController
                                      .updateInvestment(updatedInvestment);
                                  if (!mounted) return;

                                  Navigator.of(context).pop();
                                  toast.showSuccess(
                                    'Auto-link ${value ? 'enabled' : 'disabled'}',
                                  );
                                } catch (e) {
                                  if (mounted) {
                                    toast.showError('Failed to update setting');
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: Spacing.md),
                      // Maturity Alert Toggle
                      Container(
                        padding: const EdgeInsets.all(Spacing.lg),
                        decoration: BoxDecoration(
                          color: AppStyles.getCardColor(context),
                          borderRadius: BorderRadius.circular(Radii.md),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Maturity Alert',
                                    style: TextStyle(
                                      color: AppStyles.getTextColor(context),
                                      fontWeight: FontWeight.w600,
                                      fontSize: TypeScale.body,
                                    ),
                                  ),
                                  const SizedBox(height: Spacing.xs),
                                  Text(
                                    'Show alert when FD is within 10 days of maturity',
                                    style: TextStyle(
                                      color: AppStyles.getSecondaryTextColor(
                                          context),
                                      fontSize: TypeScale.footnote,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            CupertinoSwitch(
                              value: widget.fd.metadata?['maturityAlertEnabled']
                                      as bool? ??
                                  true,
                              onChanged: (value) async {
                                try {
                                  if (!mounted) return;
                                  final investmentsController =
                                      Provider.of<InvestmentsController>(
                                          context,
                                          listen: false);
                                  final currentInvestment =
                                      investmentsController.investments
                                          .firstWhere(
                                    (inv) => inv.id == widget.fd.id,
                                    orElse: () =>
                                        throw Exception('Investment not found'),
                                  );
                                  final updatedFD = widget.fd.copyWith(
                                    metadata: {
                                      ...?widget.fd.metadata,
                                      'maturityAlertEnabled': value,
                                    },
                                  );
                                  final updatedInvestment =
                                      currentInvestment.copyWith(
                                    metadata: {
                                      ...?currentInvestment.metadata,
                                      'fdData': updatedFD.toMap(),
                                    },
                                  );
                                  await investmentsController
                                      .updateInvestment(updatedInvestment);
                                  if (!mounted) return;
                                  Navigator.of(context).pop();
                                  toast.showSuccess(
                                    'Maturity alert ${value ? 'enabled' : 'disabled'}',
                                  );
                                } catch (e) {
                                  if (mounted) {
                                    toast.showError('Failed to update setting');
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: Spacing.xxl),
                      Text(
                        'Bank Account',
                        style: TextStyle(
                          color: AppStyles.getTextColor(context),
                          fontSize: TypeScale.body,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: Spacing.md),
                      Container(
                        padding: const EdgeInsets.all(Spacing.md),
                        decoration: BoxDecoration(
                          color: AppStyles.getCardColor(context),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.fd.linkedAccountName,
                              style: TextStyle(
                                color: AppStyles.getTextColor(context),
                                fontWeight: FontWeight.w600,
                                fontSize: TypeScale.body,
                              ),
                            ),
                            const SizedBox(height: Spacing.xs),
                            Text(
                              widget.fd.bankName ?? 'Bank Account',
                              style: TextStyle(
                                color: AppStyles.getSecondaryTextColor(context),
                                fontSize: TypeScale.footnote,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showHistoryModal(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        color: AppStyles.getBackground(context),
        child: SafeArea(
          top: true,
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(Spacing.lg),
                decoration: BoxDecoration(
                  color: AppStyles.getCardColor(context),
                  border: Border(
                    bottom: BorderSide(
                      color: AppStyles.getDividerColor(context),
                      width: 0.5,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'FD Timeline',
                      style: TextStyle(
                        color: AppStyles.getTextColor(context),
                        fontSize: TypeScale.headline,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Icon(
                        CupertinoIcons.xmark_circle_fill,
                        color: AppStyles.getSecondaryTextColor(context),
                      ),
                    ),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(
                      top: 32, left: 16, right: 16, bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHistoryItem(
                        context,
                        'Created',
                        _formatDate(widget.fd.createdDate),
                        'FD account opened',
                        CupertinoIcons.checkmark_circle,
                      ),
                      _buildHistoryItem(
                        context,
                        'Investment',
                        _formatDate(widget.fd.investmentDate),
                        'Initial amount invested',
                        CupertinoIcons.checkmark_circle,
                      ),
                      if (widget.fd.elapsedMonths > 0)
                        _buildHistoryItem(
                          context,
                          'Active',
                          '${widget.fd.elapsedMonths} months invested',
                          'Currently earning interest',
                          CupertinoIcons.clock,
                        ),
                      _buildHistoryItem(
                        context,
                        'Maturity Date',
                        _formatDate(widget.fd.maturityDate),
                        widget.fd.daysUntilMaturity <= 0
                            ? 'FD matured'
                            : '${widget.fd.daysUntilMaturity} days remaining',
                        widget.fd.daysUntilMaturity <= 0
                            ? CupertinoIcons.checkmark_circle
                            : CupertinoIcons.clock,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryItem(
    BuildContext context,
    String title,
    String date,
    String description,
    IconData icon,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppStyles.getPrimaryColor(context).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child:
                Icon(icon, color: AppStyles.getPrimaryColor(context), size: 20),
          ),
          const SizedBox(width: Spacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: AppStyles.getTextColor(context),
                    fontWeight: FontWeight.bold,
                    fontSize: TypeScale.body,
                  ),
                ),
                const SizedBox(height: Spacing.xs),
                Text(
                  date,
                  style: TextStyle(
                    color: AppStyles.getSecondaryTextColor(context),
                    fontSize: TypeScale.subhead,
                  ),
                ),
                const SizedBox(height: Spacing.xxs),
                Text(
                  description,
                  style: TextStyle(
                    color: AppStyles.getSecondaryTextColor(context),
                    fontSize: TypeScale.caption,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Delete FD?'),
        content: const Text(
          'Are you sure you want to delete this FD? This action cannot be undone.',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              if (!mounted) return;
              // Delete FD from investments controller
              final investmentsController =
                  Provider.of<InvestmentsController>(context, listen: false);
              await investmentsController.deleteInvestment(widget.fd.id);

              if (mounted) {
                // Close dialog
                Navigator.of(context).pop();
                // Go back to investments list
                Navigator.of(context).pop();

                toast.showSuccess('FD deleted successfully');
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(FDStatus status) {
    switch (status) {
      case FDStatus.active:
        return AppStyles.bioGreen;
      case FDStatus.mature:
        return CupertinoColors.systemOrange;
      case FDStatus.prematurelyWithdrawn:
        return AppStyles.plasmaRed;
      case FDStatus.completed:
        return CupertinoColors.systemGrey;
    }
  }

  /// Get the latest renewal cycle from metadata
  FDRenewalCycle? _getLatestRenewalCycle() {
    try {
      final investmentsController =
          Provider.of<InvestmentsController>(context, listen: false);
      final investments = investmentsController.investments
          .where((inv) => inv.name == widget.fd.name)
          .toList();

      if (investments.isEmpty) return null;

      final investment = investments.first;
      final cyclesData = investment.metadata?['renewalCycles'] as List?;
      if (cyclesData == null || cyclesData.isEmpty) return null;

      // Get the last (latest) cycle
      final lastCycleMap = Map<String, dynamic>.from(cyclesData.last as Map);
      return FDRenewalCycle.fromMap(lastCycleMap);
    } catch (e) {
      return null;
    }
  }

  /// Check if FD has been renewed (has multiple cycles)
  bool _hasBeenRenewed() {
    try {
      final investmentsController =
          Provider.of<InvestmentsController>(context, listen: false);
      final investments = investmentsController.investments
          .where((inv) => inv.name == widget.fd.name)
          .toList();

      if (investments.isEmpty) return false;

      final investment = investments.first;
      final cyclesData = investment.metadata?['renewalCycles'] as List?;
      return cyclesData != null && cyclesData.length > 1;
    } catch (e) {
      return false;
    }
  }

  /// Get renewal date from metadata
  DateTime? _getRenewalDate() {
    try {
      final investmentsController =
          Provider.of<InvestmentsController>(context, listen: false);
      final investments = investmentsController.investments
          .where((inv) => inv.name == widget.fd.name)
          .toList();

      if (investments.isEmpty) return null;

      final investment = investments.first;
      final renewalDateStr = investment.metadata?['lastRenewalDate'] as String?;
      if (renewalDateStr != null) {
        return DateTime.parse(renewalDateStr);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get current accrued value based on latest cycle
  double _getCurrentValue() {
    final latestCycle = _getLatestRenewalCycle();
    if (latestCycle != null) {
      return latestCycle.getAccruedValue(DateTime.now());
    }
    return widget.fd.estimatedAccruedValue;
  }

  /// Get maturity date from latest cycle or original FD
  DateTime _getMaturityDate() {
    final latestCycle = _getLatestRenewalCycle();
    if (latestCycle != null) {
      return latestCycle.maturityDate;
    }
    return widget.fd.maturityDate;
  }

  /// Get total interest earned
  double _getTotalInterest() {
    final currentValue = _getCurrentValue();
    return currentValue - widget.fd.principal;
  }

  /// Build TDS (Tax Deducted at Source) summary card — H28/J15
  Widget _buildTdsSection(BuildContext context) {
    final totalInterest = _getTotalInterest();
    final tenureMonths =
        _getLatestRenewalCycle()?.tenureMonths ?? widget.fd.tenureMonths;
    final tenureYears = tenureMonths / 12.0;
    final annualInterest =
        tenureYears > 0 ? totalInterest / tenureYears : totalInterest;

    const tdsThreshold = 40000.0; // ₹40,000/yr standard threshold
    const tdsRate = 0.10; // 10% with PAN
    final tdsApplicable = annualInterest >= tdsThreshold;
    final estimatedTds = tdsApplicable ? totalInterest * tdsRate : 0.0;
    final netInterest = totalInterest - estimatedTds;

    return Container(
      padding: const EdgeInsets.all(Spacing.lg),
      decoration: BoxDecoration(
        color: tdsApplicable
            ? CupertinoColors.systemOrange.withValues(alpha: 0.08)
            : AppStyles.bioGreen.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(
          color: tdsApplicable
              ? CupertinoColors.systemOrange.withValues(alpha: 0.25)
              : AppStyles.bioGreen.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                tdsApplicable
                    ? CupertinoIcons.exclamationmark_triangle
                    : CupertinoIcons.checkmark_shield,
                size: 16,
                color: tdsApplicable
                    ? CupertinoColors.systemOrange
                    : AppStyles.bioGreen,
              ),
              const SizedBox(width: Spacing.sm),
              Text(
                'Tax (TDS) — ${tdsApplicable ? 'Applicable' : 'Not Applicable'}',
                style: TextStyle(
                  fontSize: TypeScale.subhead,
                  fontWeight: FontWeight.w700,
                  color: tdsApplicable
                      ? CupertinoColors.systemOrange
                      : AppStyles.bioGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.md),
          _buildDetailRow(
            'Avg. Annual Interest',
            '₹${annualInterest.toStringAsFixed(0)}',
          ),
          _buildDetailRow(
            'TDS Threshold',
            '₹${tdsThreshold.toStringAsFixed(0)}/yr',
          ),
          if (tdsApplicable) ...[
            _buildDetailRow(
              'Est. TDS (10% of interest)',
              '−₹${estimatedTds.toStringAsFixed(2)}',
            ),
            _buildDetailRow(
              'Net Interest After TDS',
              '₹${netInterest.toStringAsFixed(2)}',
              isHighlight: true,
            ),
          ],
          const SizedBox(height: Spacing.sm),
          Text(
            tdsApplicable
                ? 'Bank may deduct 10% TDS when annual interest exceeds ₹40,000. Ensure PAN is submitted to avoid 20% deduction.'
                : 'Annual interest is below ₹40,000. No TDS should be deducted. Submit Form 15G/H if applicable.',
            style: TextStyle(
              fontSize: TypeScale.caption,
              color: AppStyles.getSecondaryTextColor(context),
            ),
          ),
        ],
      ),
    );
  }

  /// Get elapsed days and months
  Map<String, int> _getElapsed() {
    final latestCycle = _getLatestRenewalCycle();
    final investmentDate =
        latestCycle?.investmentDate ?? widget.fd.investmentDate;
    final maturityDate = latestCycle?.maturityDate ?? widget.fd.maturityDate;

    final now = DateTime.now();
    final daysElapsed = now.difference(investmentDate).inDays;
    final totalDays = maturityDate.difference(investmentDate).inDays;
    final monthsElapsed = (daysElapsed / 30.44).round();
    final totalMonths = latestCycle?.tenureMonths ?? widget.fd.tenureMonths;

    return {
      'elapsed': monthsElapsed,
      'total': totalMonths,
    };
  }

  /// Calculate CAGR for the FD based on current state
  double _calculateCAGR(FixedDeposit fd) {
    final principal = fd.principal;
    final currentValue = _getCurrentValue();
    final investDate = fd.investmentDate;
    final today = DateTime.now();
    final daysElapsed = today.difference(investDate).inDays;
    final yearsElapsed = daysElapsed / 365.25;

    final cagr = FDCalculations.calculateCAGR(
      principal,
      currentValue,
      investDate,
      today,
    );
    return cagr;
  }

  Widget _buildMaturityAlert(BuildContext context) {
    final daysUntil = widget.fd.maturityDate.difference(DateTime.now()).inDays;

    return Container(
      margin: const EdgeInsets.all(Spacing.lg),
      padding: const EdgeInsets.all(Spacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            CupertinoColors.systemOrange.withValues(alpha: 0.15),
            CupertinoColors.systemOrange.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(
          color: CupertinoColors.systemOrange.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemOrange,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      CupertinoIcons.bell_fill,
                      color: CupertinoColors.white,
                      size: 12,
                    ),
                    SizedBox(width: Spacing.xs),
                    Text(
                      'FD Maturity',
                      style: TextStyle(
                        color: CupertinoColors.white,
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
                  color: CupertinoColors.systemOrange.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'In $daysUntil day${daysUntil > 1 ? 's' : ''}',
                  style: const TextStyle(
                    color: CupertinoColors.systemOrange,
                    fontSize: TypeScale.caption,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.lg),
          Text(
            'Your FD matures on ${_formatDate(widget.fd.maturityDate)}',
            style: TextStyle(
              color: AppStyles.getTextColor(context),
              fontWeight: FontWeight.w600,
              fontSize: TypeScale.body,
            ),
          ),
          const SizedBox(height: Spacing.xs),
          Text(
            'Choose to renew or withdraw your investment',
            style: TextStyle(
              color: AppStyles.getSecondaryTextColor(context),
              fontSize: TypeScale.footnote,
            ),
          ),
          const SizedBox(height: Spacing.lg),
          Row(
            children: [
              Expanded(
                child: CupertinoButton(
                  color: AppStyles.getPrimaryColor(context),
                  onPressed: () {
                    final daysLeft = widget.fd.maturityDate
                        .difference(DateTime.now())
                        .inDays;
                    if (daysLeft > 0) {
                      toast.showError(
                          'FD matures in $daysLeft day${daysLeft == 1 ? '' : 's'} — renewal available after maturity');
                      return;
                    }
                    final investmentsController =
                        Provider.of<InvestmentsController>(context,
                            listen: false);
                    try {
                      final originalInvestment =
                          investmentsController.investments.firstWhere(
                        (inv) => inv.id == widget.fd.id,
                        orElse: () => throw Exception('Investment not found'),
                      );

                      Navigator.of(context)
                          .push(
                        FadeScalePageRoute(
                          page: FDRenewalWizardScreen(
                            fd: widget.fd,
                            originalInvestment: originalInvestment,
                          ),
                        ),
                      )
                          .then((renewed) {
                        if (!mounted) return;
                        if (renewed == true) {
                          Navigator.of(context).pop();
                        }
                      });
                    } catch (e) {
                      if (mounted) {
                        toast.showError('Failed to open renewal: $e');
                      }
                    }
                  },
                  child: const Text(
                    'Renew',
                    style: TextStyle(
                      color: CupertinoColors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: TypeScale.body,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: CupertinoButton(
                  color: AppStyles.bioGreen,
                  onPressed: () {
                    final investmentsController =
                        Provider.of<InvestmentsController>(context,
                            listen: false);
                    try {
                      final originalInvestment =
                          investmentsController.investments.firstWhere(
                        (inv) => inv.id == widget.fd.id,
                        orElse: () => throw Exception('Investment not found'),
                      );

                      Navigator.of(context)
                          .push(
                        FadeScalePageRoute(
                          page: FDWithdrawalModal(
                            fd: widget.fd,
                            investmentController: investmentsController,
                            onWithdraw: () {
                              // Withdrawal handled by modal, pop back to investments list
                              if (mounted) {
                                Navigator.of(context).pop();
                              }
                            },
                          ),
                        ),
                      )
                          .then((withdrawn) {
                        if (!mounted) return;
                        if (withdrawn == true) {
                          Navigator.of(context).pop();
                        }
                      });
                    } catch (e) {
                      if (mounted) {
                        toast.showError('Failed to open withdrawal: $e');
                      }
                    }
                  },
                  child: const Text(
                    'Withdraw',
                    style: TextStyle(
                      color: CupertinoColors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: TypeScale.body,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
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
    return '${date.day} ${DateFormatter.getMonthName(date.month)} ${date.year}';
  }
}
