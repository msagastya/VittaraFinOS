import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:vittara_fin_os/logic/fixed_deposit_model.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/utils/common_utils.dart';

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

  @override
  void initState() {
    super.initState();
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
    // Simplified calculation - typically banks deduct interest based on elapsed time
    // and may charge a penalty

    final elapsedFraction = widget.fd.elapsedFraction;

    // Calculate interest proportional to elapsed time
    final accruedInterest = widget.fd.totalInterestAtMaturity * elapsedFraction;

    // Assume 1% penalty on interest if withdrawn before 1 year
    final monthsElapsed = widget.fd.elapsedMonths;
    final penaltyPercentage = monthsElapsed < 12 ? 1.0 : 0.5;

    _penaltyAmount = (accruedInterest * penaltyPercentage) / 100;
    _calculatedAmount =
        widget.fd.principal + accruedInterest - _penaltyAmount;
    _netAmount = _calculatedAmount;
  }

  void _updateNetAmount(String value) {
    final amount = double.tryParse(value) ?? _calculatedAmount;
    setState(() {
      _netAmount = amount;
    });
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
            padding: const EdgeInsets.all(16),
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
                    fontSize: 16,
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
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Warning
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.orange.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          CupertinoIcons.exclamationmark_triangle_fill,
                          color: Colors.orange,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Early withdrawal may incur penalties and reduced interest.',
                            style: TextStyle(
                              color: Colors.orange,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Details
                  Text(
                    'Calculation Details',
                    style: TextStyle(
                      color: AppStyles.getTextColor(context),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildCalculationRow('Principal Amount',
                      '₹${widget.fd.principal.toStringAsFixed(2)}'),
                  _buildCalculationRow(
                    'Accrued Interest',
                    '₹${(widget.fd.totalInterestAtMaturity * widget.fd.elapsedFraction).toStringAsFixed(2)}',
                  ),
                  _buildCalculationRow(
                    'Penalty (${(widget.fd.elapsedMonths < 12 ? 1.0 : 0.5)}%)',
                    '-₹${_penaltyAmount.toStringAsFixed(2)}',
                    color: Colors.red,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppStyles.getPrimaryColor(context).withOpacity(0.1),
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
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Editable Net Amount
                  Text(
                    'Final Withdrawal Amount',
                    style: TextStyle(
                      color: AppStyles.getTextColor(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You can adjust the amount if agreed with the bank',
                    style: TextStyle(
                      color: AppStyles.getSecondaryTextColor(context),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  CupertinoTextField(
                    controller: _netAmountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    padding: const EdgeInsets.all(12),
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
                  const SizedBox(height: 20),
                  // Linked account info
                  Container(
                    padding: const EdgeInsets.all(12),
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
                            const SizedBox(width: 8),
                            Text(
                              'Withdrawal Account',
                              style: TextStyle(
                                color: AppStyles.getSecondaryTextColor(context),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.fd.linkedAccountName,
                          style: TextStyle(
                            color: AppStyles.getTextColor(context),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Amount will be credited to this account',
                          style: TextStyle(
                            color: AppStyles.getSecondaryTextColor(context),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          // Action buttons
          Container(
            padding: const EdgeInsets.all(16),
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
                        .withOpacity(0.3),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: AppStyles.getSecondaryTextColor(context),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CupertinoButton(
                    onPressed: () {
                      // TODO: Process withdrawal
                      Navigator.of(context).pop();
                      ShowToast.showSuccess('Withdrawal initiated');
                    },
                    color: Colors.orange,
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
              fontSize: 13,
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
