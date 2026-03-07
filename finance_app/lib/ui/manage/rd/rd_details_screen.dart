import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/recurring_deposit_model.dart';
import 'package:vittara_fin_os/logic/investments_controller.dart';
import 'package:vittara_fin_os/utils/date_formatter.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/widgets/toast_notification.dart';

class RDDetailsScreen extends StatefulWidget {
  final RecurringDeposit rd;

  const RDDetailsScreen({
    required this.rd,
    super.key,
  });

  @override
  State<RDDetailsScreen> createState() => _RDDetailsScreenState();
}

class _RDDetailsScreenState extends State<RDDetailsScreen> {
  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppStyles.getBackground(context),
      navigationBar: CupertinoNavigationBar(
        middle: Text('RD Details',
            style: TextStyle(color: AppStyles.getTextColor(context))),
        previousPageTitle: 'Investments',
        backgroundColor: AppStyles.getBackground(context),
        border: null,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Header Card
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
                    // RD Name and Status
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.rd.name,
                                style: TextStyle(
                                  color: AppStyles.getTextColor(context),
                                  fontSize: TypeScale.title2,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: Spacing.xs),
                              Text(
                                'Linked: ${widget.rd.linkedAccountName}',
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
                            color: _getStatusColor(widget.rd.status)
                                .withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            widget.rd.getStatusLabel(),
                            style: TextStyle(
                              color: _getStatusColor(widget.rd.status),
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
                          'Per Installment',
                          '₹${widget.rd.monthlyAmount.toStringAsFixed(0)}',
                          AppStyles.getSecondaryTextColor(context),
                        ),
                        _buildMetric(
                          context,
                          'Total Invested',
                          '₹${widget.rd.totalInvestedAmount.toStringAsFixed(0)}',
                          AppStyles.getPrimaryColor(context),
                        ),
                        _buildMetric(
                          context,
                          'Est. Maturity',
                          '₹${widget.rd.maturityValue.toStringAsFixed(0)}',
                          CupertinoColors.systemGreen,
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
                      'Started',
                      _formatDate(widget.rd.startDate),
                      CupertinoIcons.checkmark_circle,
                    ),
                    _buildTimelineItem(
                      context,
                      'Maturity',
                      _formatDate(widget.rd.maturityDate),
                      widget.rd.daysUntilMaturity <= 0
                          ? CupertinoIcons.checkmark_circle
                          : CupertinoIcons.clock,
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
                    _buildDetailRow('Monthly Amount',
                        '₹${widget.rd.monthlyAmount.toStringAsFixed(2)}'),
                    _buildDetailRow(
                        'Total Installments', '${widget.rd.totalInstallments}'),
                    _buildDetailRow(
                        'Completed', '${widget.rd.completedInstallments}'),
                    _buildDetailRow(
                        'Pending', '${widget.rd.pendingInstallments}'),
                    _buildDetailRow(
                        'Interest Rate', '${widget.rd.interestRate}% p.a.'),
                    _buildDetailRow(
                        'Payment Frequency', widget.rd.paymentFrequency.name),
                    _buildDetailRow(
                      'Total Interest',
                      '₹${widget.rd.totalInterestAtMaturity.toStringAsFixed(2)}',
                      isHighlight: true,
                    ),
                    _buildDetailRow(
                      'Maturity Value',
                      '₹${widget.rd.maturityValue.toStringAsFixed(2)}',
                      isHighlight: true,
                    ),
                    const SizedBox(height: Spacing.xl),
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
          _buildActionButton(
            context,
            'Installment Schedule',
            'View all installments',
            CupertinoIcons.calendar,
            AppStyles.getPrimaryColor(context),
            () => _showInstallmentScheduleModal(context),
          ),
          const SizedBox(height: Spacing.md),
          _buildActionButton(
            context,
            'Edit Settings',
            'Modify auto-payment settings',
            CupertinoIcons.pencil,
            Colors.purple,
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
            'Remove this RD',
            CupertinoIcons.trash,
            CupertinoColors.systemRed,
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
          borderRadius: BorderRadius.circular(12),
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

  void _showInstallmentScheduleModal(BuildContext context) {
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
                    'Installment Schedule',
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
            // Schedule list
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(Spacing.lg),
                child: Column(
                  children: [
                    if (widget.rd.completedInstallments > 0) ...[
                      Text(
                        'Completed',
                        style: TextStyle(
                          color: AppStyles.getTextColor(context),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: Spacing.md),
                      ...List.generate(widget.rd.completedInstallments,
                          (index) {
                        return _buildInstallmentItem(
                          context,
                          'Installment ${index + 1}',
                          '₹${widget.rd.monthlyAmount.toStringAsFixed(2)}',
                          'Completed',
                          CupertinoColors.systemGreen,
                        );
                      }),
                      const SizedBox(height: Spacing.xl),
                    ],
                    if (widget.rd.pendingInstallments > 0) ...[
                      Text(
                        'Pending',
                        style: TextStyle(
                          color: AppStyles.getTextColor(context),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: Spacing.md),
                      ...List.generate(widget.rd.pendingInstallments, (index) {
                        return _buildInstallmentItem(
                          context,
                          'Installment ${widget.rd.completedInstallments + index + 1}',
                          '₹${widget.rd.monthlyAmount.toStringAsFixed(2)}',
                          'Upcoming',
                          AppStyles.getPrimaryColor(context),
                        );
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

  Widget _buildInstallmentItem(
    BuildContext context,
    String title,
    String amount,
    String status,
    Color color,
  ) {
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
                  title,
                  style: TextStyle(
                    color: AppStyles.getTextColor(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: Spacing.xs),
                Text(
                  status,
                  style: TextStyle(
                    color: color,
                    fontSize: TypeScale.footnote,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: TypeScale.body,
            ),
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
                      'Edit RD Settings',
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
                        'Auto-Payment Settings',
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
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Auto-Payment',
                                    style: TextStyle(
                                      color: AppStyles.getTextColor(context),
                                      fontWeight: FontWeight.w600,
                                      fontSize: TypeScale.body,
                                    ),
                                  ),
                                  const SizedBox(height: Spacing.xs),
                                  Text(
                                    'Auto-debit future installments',
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
                              value: widget.rd.autoPaymentEnabled,
                              onChanged: (value) {
                                Navigator.of(context).pop();
                                toast.showSuccess(
                                    'Auto-payment setting updated');
                              },
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
                      'RD Timeline',
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
                      _buildHistoryItem(
                        context,
                        'Started',
                        _formatDate(widget.rd.startDate),
                        'RD account created',
                        CupertinoIcons.checkmark_circle,
                      ),
                      _buildHistoryItem(
                        context,
                        'Active',
                        '${widget.rd.completedInstallments} of ${widget.rd.totalInstallments} completed',
                        'Currently running',
                        CupertinoIcons.clock,
                      ),
                      _buildHistoryItem(
                        context,
                        'Maturity Date',
                        _formatDate(widget.rd.maturityDate),
                        widget.rd.daysUntilMaturity <= 0
                            ? 'RD matured'
                            : '${widget.rd.daysUntilMaturity} days remaining',
                        widget.rd.daysUntilMaturity <= 0
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
        title: const Text('Delete RD?'),
        content: const Text(
          'Are you sure you want to delete this RD? This action cannot be undone.',
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
              // Delete RD from investments controller
              final investmentsController =
                  Provider.of<InvestmentsController>(context, listen: false);
              await investmentsController.deleteInvestment(widget.rd.id);

              if (mounted) {
                // Close dialog
                Navigator.of(context).pop();
                // Go back to investments list
                Navigator.of(context).pop();

                toast.showSuccess('RD deleted successfully');
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(RDStatus status) {
    switch (status) {
      case RDStatus.active:
        return CupertinoColors.systemGreen;
      case RDStatus.mature:
        return CupertinoColors.systemOrange;
      case RDStatus.completed:
        return CupertinoColors.systemGrey;
    }
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
