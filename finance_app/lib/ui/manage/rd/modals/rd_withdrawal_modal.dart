import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/recurring_deposit_model.dart';
import 'package:vittara_fin_os/logic/investments_controller.dart';
import 'package:vittara_fin_os/logic/investment_model.dart';
import 'package:vittara_fin_os/logic/accounts_controller.dart';
import 'package:vittara_fin_os/utils/date_formatter.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/widgets/toast_notification.dart';

class RDWithdrawalModal extends StatefulWidget {
  final RecurringDeposit rd;
  final VoidCallback onWithdraw;
  final InvestmentsController? investmentController;
  final Investment? originalInvestment;

  const RDWithdrawalModal({
    required this.rd,
    required this.onWithdraw,
    this.investmentController,
    this.originalInvestment,
    super.key,
  });

  @override
  State<RDWithdrawalModal> createState() => _RDWithdrawalModalState();
}

class _RDWithdrawalModalState extends State<RDWithdrawalModal> {
  late DateTime _withdrawalDate;
  late double _withdrawalValue;
  late TextEditingController _withdrawalAmountController;

  @override
  void initState() {
    super.initState();
    _withdrawalDate = widget.rd.maturityDate;
    _withdrawalValue = _calculateWithdrawalValue(_withdrawalDate);
    _withdrawalAmountController = TextEditingController(
      text: _withdrawalValue.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _withdrawalAmountController.dispose();
    super.dispose();
  }

  double _calculateWithdrawalValue(DateTime date) {
    // If withdrawal date is on or after maturity date, return maturity value
    if (date.isAtSameMomentAs(widget.rd.maturityDate) ||
        date.isAfter(widget.rd.maturityDate)) {
      return widget.rd.maturityValue;
    }

    // If withdrawal date is before maturity, calculate current value
    return widget.rd.currentValue;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: AppStyles.getBackground(context),
        appBar: CupertinoNavigationBar(
          middle: Text('Withdraw RD'),
          previousPageTitle: 'Back',
          backgroundColor: AppStyles.getBackground(context),
          border: null,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(Spacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // RD Details Summary
              Container(
                padding: const EdgeInsets.all(Spacing.lg),
                decoration: BoxDecoration(
                  color: AppStyles.getCardColor(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppStyles.getDividerColor(context),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.rd.name,
                      style: TextStyle(
                        color: AppStyles.getTextColor(context),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: Spacing.md),
                    _buildDetailRow(context, 'Total Invested',
                        '₹${widget.rd.amountInvestedSoFar.toStringAsFixed(2)}'),
                    _buildDetailRow(context, 'Maturity Date',
                        _formatDate(widget.rd.maturityDate)),
                    _buildDetailRow(context, 'Maturity Value',
                        '₹${widget.rd.maturityValue.toStringAsFixed(2)}'),
                  ],
                ),
              ),
              const SizedBox(height: Spacing.lg),

              // Withdrawal Date Selection
              Text(
                'Withdrawal Date',
                style: TextStyle(
                  color: AppStyles.getTextColor(context),
                  fontWeight: FontWeight.w600,
                  fontSize: TypeScale.body,
                ),
              ),
              const SizedBox(height: Spacing.sm),
              GestureDetector(
                onTap: () => _showDatePicker(context),
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
                        _formatDate(_withdrawalDate),
                        style: TextStyle(
                          color: AppStyles.getTextColor(context),
                          fontSize: TypeScale.headline,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Icon(
                        CupertinoIcons.calendar,
                        color: AppStyles.getPrimaryColor(context),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: Spacing.lg),

              // Withdrawal Value Info
              Container(
                padding: const EdgeInsets.all(Spacing.lg),
                decoration: BoxDecoration(
                  color:
                      AppStyles.getPrimaryColor(context).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppStyles.getPrimaryColor(context)
                        .withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Withdrawal Value',
                      style: TextStyle(
                        color: AppStyles.getSecondaryTextColor(context),
                        fontSize: TypeScale.footnote,
                      ),
                    ),
                    const SizedBox(height: Spacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: CupertinoTextField(
                            controller: _withdrawalAmountController,
                            placeholder: '0.00',
                            prefix: Padding(
                              padding: const EdgeInsets.only(left: Spacing.md),
                              child: Text(
                                '₹',
                                style: TextStyle(
                                  fontSize: TypeScale.largeTitle,
                                  fontWeight: FontWeight.bold,
                                  color: AppStyles.getPrimaryColor(context),
                                ),
                              ),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            style: TextStyle(
                              color: AppStyles.getPrimaryColor(context),
                              fontSize: TypeScale.largeTitle,
                              fontWeight: FontWeight.bold,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: AppStyles.getDividerColor(context),
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: Spacing.md,
                              vertical: Spacing.md,
                            ),
                            onChanged: (value) {
                              setState(() {
                                _withdrawalValue =
                                    double.tryParse(value) ?? _withdrawalValue;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Spacing.md),
                    Row(
                      children: [
                        Icon(
                          CupertinoIcons.check_mark_circled_solid,
                          size: 16,
                          color: AppStyles.gain(context),
                        ),
                        SizedBox(width: Spacing.sm),
                        Expanded(
                          child: Text(
                            'Maturity value includes principal + interest',
                            style: TextStyle(
                              color: AppStyles.gain(context),
                              fontSize: TypeScale.footnote,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Spacing.xxl),

              // Confirm Withdrawal Button
              SizedBox(
                width: double.infinity,
                child: CupertinoButton(
                  color: AppStyles.gain(context),
                  onPressed: () async {
                    // If we have the investment controller, persist the withdrawal
                    if (widget.investmentController != null &&
                        widget.originalInvestment != null) {
                      try {
                        // Read the user-entered withdrawal amount from text field
                        final userEnteredAmount =
                            double.tryParse(_withdrawalAmountController.text) ??
                                _withdrawalValue;
                        final withdrawalAmount = userEnteredAmount;

                        final originalInvestment = widget.originalInvestment!;
                        final investmentsController =
                            widget.investmentController!;

                        // Update the investment with withdrawal information
                        final existingMetadata =
                            originalInvestment.metadata ?? {};
                        final safeMetadata =
                            Map<String, dynamic>.from(existingMetadata);

                        final updatedInvestment = originalInvestment.copyWith(
                          metadata: {
                            ...safeMetadata,
                            'withdrawalDate': _withdrawalDate.toIso8601String(),
                            'withdrawalAmount': withdrawalAmount,
                            'withdrawalReason': 'Withdrawal from notification',
                            'status': 'withdrawn',
                          },
                        );

                        // Update the investment
                        await investmentsController
                            .updateInvestment(updatedInvestment);
                        if (!mounted) return;

                        // Credit the linked account
                        final linkedAccountId = widget.rd.linkedAccountId;
                        if (linkedAccountId.isNotEmpty) {
                          try {
                            if (!mounted) return;
                            final accountsController =
                                Provider.of<AccountsController>(context,
                                    listen: false);
                            try {
                              final linkedAccount =
                                  accountsController.accounts.firstWhere(
                                (acc) => acc.id == linkedAccountId,
                                orElse: () => throw Exception(
                                    'Linked account not found'),
                              );
                              final updatedAccount = linkedAccount.copyWith(
                                balance:
                                    linkedAccount.balance + withdrawalAmount,
                              );
                              await accountsController
                                  .updateAccount(updatedAccount);
                              if (!mounted) return;
                            } catch (e) {
                              // Account not found — credit skipped
                            }
                          } catch (e) {
                            // Continue even if account credit fails
                          }
                        }

                        if (mounted) {
                          toast.showSuccess(
                            'Withdrawal confirmed for ${_formatDate(_withdrawalDate)}. Amount: ₹${withdrawalAmount.toStringAsFixed(2)}',
                          );
                          widget.onWithdraw();
                          Navigator.of(context).pop();
                        }
                      } catch (e) {
                        toast.showError('Error processing withdrawal: $e');
                      }
                    } else {
                      // Fallback to old behavior if controller not provided
                      toast.showSuccess(
                        'Withdrawal confirmed for ${_formatDate(_withdrawalDate)}',
                      );
                      widget.onWithdraw();
                      Navigator.of(context).pop();
                    }
                  },
                  child: const Text(
                    'Confirm Withdrawal',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: Spacing.lg),
            ],
          ),
        ),
      ),
    );
  }

  void _showDatePicker(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => Container(
        height: 300,
        color: AppStyles.getBackground(context),
        child: Column(
          children: [
            SizedBox(
              height: 200,
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: _withdrawalDate,
                minimumDate: widget.rd.startDate,
                maximumDate: DateTime.now(),
                onDateTimeChanged: (DateTime newDate) {
                  setState(() {
                    _withdrawalDate = newDate;
                    _withdrawalValue = _calculateWithdrawalValue(newDate);
                    // Update the text field with new calculated value
                    _withdrawalAmountController.text =
                        _withdrawalValue.toStringAsFixed(2);
                  });
                },
              ),
            ),
            CupertinoButton(
              child: const Text('Done'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppStyles.getSecondaryTextColor(context),
              fontSize: TypeScale.footnote,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: AppStyles.getTextColor(context),
              fontWeight: FontWeight.w600,
              fontSize: TypeScale.footnote,
            ),
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
