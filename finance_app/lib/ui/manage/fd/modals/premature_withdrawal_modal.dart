import 'package:flutter/cupertino.dart';
import 'package:vittara_fin_os/logic/fixed_deposit_model.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/widgets/toast_notification.dart';

class PrematureWithdrawalModal extends StatefulWidget {
  final FixedDeposit fd;

  const PrematureWithdrawalModal({
    required this.fd,
    super.key,
  });

  @override
  State<PrematureWithdrawalModal> createState() =>
      _PrematureWithdrawalModalState();
}

class _PrematureWithdrawalModalState extends State<PrematureWithdrawalModal> {
  late double _calculatedAmount;
  late double _penaltyAmount;
  late double _netAmount;
  late TextEditingController _netAmountController;
  late DateTime _withdrawalDate;

  @override
  void initState() {
    super.initState();
    _withdrawalDate = DateTime.now();
    _calculateWithdrawalAmount();
    _netAmountController =
        TextEditingController(text: _netAmount.toStringAsFixed(2));
  }

  @override
  void dispose() {
    _netAmountController.dispose();
    super.dispose();
  }

  void _calculateWithdrawalAmount() {
    // Calculate interest based on withdrawal date
    final daysSinceInvestment =
        _withdrawalDate.difference(widget.fd.investmentDate).inDays;
    final totalDays =
        widget.fd.maturityDate.difference(widget.fd.investmentDate).inDays;

    // Ensure we don't go beyond maturity date
    final adjustedDays =
        daysSinceInvestment > totalDays ? totalDays : daysSinceInvestment;
    final elapsedFraction = adjustedDays / totalDays;

    // Calculate interest proportional to elapsed time
    final accruedInterest = widget.fd.totalInterestAtMaturity * elapsedFraction;

    // Determine penalty based on months elapsed
    final monthsElapsed = (adjustedDays / 30.44).toInt();
    final penaltyPercentage = monthsElapsed < 12 ? 1.0 : 0.5;

    _penaltyAmount = (accruedInterest * penaltyPercentage) / 100;
    _calculatedAmount = widget.fd.principal + accruedInterest - _penaltyAmount;
    _netAmount = _calculatedAmount;
  }

  void _updateNetAmount(String value) {
    final amount = double.tryParse(value) ?? _calculatedAmount;
    setState(() {
      _netAmount = amount;
    });
  }

  Future<void> _selectWithdrawalDate() async {
    final picked = await showCupertinoModalPopup<DateTime>(
      context: context,
      builder: (BuildContext context) {
        return Container(
          height: 216,
          padding: const EdgeInsets.only(top: 6.0),
          margin: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          color: CupertinoColors.systemBackground.resolveFrom(context),
          child: SafeArea(
            top: false,
            child: CupertinoDatePicker(
              initialDateTime: _withdrawalDate,
              mode: CupertinoDatePickerMode.date,
              minimumDate: widget.fd.investmentDate,
              maximumDate: DateTime.now(),
              onDateTimeChanged: (DateTime newDate) {
                setState(() {
                  _withdrawalDate = newDate;
                  _calculateWithdrawalAmount();
                  _netAmountController.text = _netAmount.toStringAsFixed(2);
                });
              },
            ),
          ),
        );
      },
    );

    if (picked != null && picked != _withdrawalDate) {
      setState(() {
        _withdrawalDate = picked;
        _calculateWithdrawalAmount();
        _netAmountController.text = _netAmount.toStringAsFixed(2);
      });
    }
  }

  Future<void> _showConfirmationDialog() async {
    final confirm = await showCupertinoDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: const Text('Confirm Withdrawal'),
          content: Column(
            children: [
              const SizedBox(height: Spacing.sm),
              Text(
                'Amount: ₹${_netAmount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: TypeScale.headline,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: Spacing.sm),
              Text(
                'Date: ${_withdrawalDate.toString().split(' ')[0]}',
                style: TextStyle(
                  fontSize: TypeScale.body,
                  color: AppStyles.getSecondaryTextColor(context),
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
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('No'),
            ),
            CupertinoDialogAction(
              isDestructiveAction: false,
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Yes, Credit Account'),
            ),
          ],
        );
      },
    );

    if (confirm == true && mounted) {
      Navigator.of(context).pop({
        'amount': _netAmount,
        'date': _withdrawalDate,
        'creditAccount': true,
      });
      toast.showSuccess('Withdrawal initiated');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppStyles.getBackground(context),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
              padding: const EdgeInsets.only(
                  top: 32, left: 20, right: 20, bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Warning
                  Container(
                    padding: const EdgeInsets.all(Spacing.md),
                    decoration: BoxDecoration(
                      color:
                          CupertinoColors.systemOrange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color:
                            CupertinoColors.systemOrange.withValues(alpha: 0.3),
                        width: 1,
                      ),
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
                  // Details
                  Text(
                    'Calculation Details',
                    style: TextStyle(
                      color: AppStyles.getTextColor(context),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: Spacing.md),
                  _buildCalculationRow('Principal Amount',
                      '₹${widget.fd.principal.toStringAsFixed(2)}'),
                  _buildCalculationRow(
                    'Accrued Interest',
                    '₹${(widget.fd.totalInterestAtMaturity * widget.fd.elapsedFraction).toStringAsFixed(2)}',
                  ),
                  _buildCalculationRow(
                    'Penalty (${(widget.fd.elapsedMonths < 12 ? 1.0 : 0.5)}%)',
                    '-₹${_penaltyAmount.toStringAsFixed(2)}',
                    color: AppStyles.plasmaRed,
                  ),
                  const SizedBox(height: Spacing.md),
                  Container(
                    padding: const EdgeInsets.all(Spacing.md),
                    decoration: BoxDecoration(
                      color: AppStyles.getPrimaryColor(context)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Calculated Net Amount',
                          style: TextStyle(
                            color: AppStyles.getTextColor(context),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '₹${_calculatedAmount.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: AppStyles.getPrimaryColor(context),
                            fontWeight: FontWeight.bold,
                            fontSize: TypeScale.headline,
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
                  Text(
                    'Select the date you withdrew the amount',
                    style: TextStyle(
                      color: AppStyles.getSecondaryTextColor(context),
                      fontSize: TypeScale.footnote,
                    ),
                  ),
                  const SizedBox(height: Spacing.sm),
                  GestureDetector(
                    onTap: _selectWithdrawalDate,
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
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _withdrawalDate.toString().split(' ')[0],
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
                  // Editable Net Amount
                  Text(
                    'Final Withdrawal Amount',
                    style: TextStyle(
                      color: AppStyles.getTextColor(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: Spacing.sm),
                  Text(
                    'You can adjust the amount if agreed with the bank',
                    style: TextStyle(
                      color: AppStyles.getSecondaryTextColor(context),
                      fontSize: TypeScale.footnote,
                    ),
                  ),
                  const SizedBox(height: Spacing.sm),
                  CupertinoTextField(
                    controller: _netAmountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
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
                        ),
                      ),
                    ),
                    style: TextStyle(color: AppStyles.getTextColor(context)),
                    onChanged: _updateNetAmount,
                  ),
                  const SizedBox(height: Spacing.xl),
                  // Linked account info
                  Container(
                    padding: const EdgeInsets.all(Spacing.md),
                    decoration: BoxDecoration(
                      color: AppStyles.getCardColor(context),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              CupertinoIcons.info,
                              size: 14,
                              color: AppStyles.getSecondaryTextColor(context),
                            ),
                            const SizedBox(width: Spacing.sm),
                            Text(
                              'Withdrawal Account',
                              style: TextStyle(
                                color: AppStyles.getSecondaryTextColor(context),
                                fontSize: TypeScale.footnote,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: Spacing.sm),
                        Text(
                          widget.fd.linkedAccountName,
                          style: TextStyle(
                            color: AppStyles.getTextColor(context),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: Spacing.xs),
                        Text(
                          'Amount will be credited to this account',
                          style: TextStyle(
                            color: AppStyles.getSecondaryTextColor(context),
                            fontSize: TypeScale.caption,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Spacing.xl),
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
                    onPressed: _showConfirmationDialog,
                    color: CupertinoColors.systemOrange,
                    child: const Text('Withdraw'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalculationRow(
    String label,
    String value, {
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
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
              color: color ?? AppStyles.getTextColor(context),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
