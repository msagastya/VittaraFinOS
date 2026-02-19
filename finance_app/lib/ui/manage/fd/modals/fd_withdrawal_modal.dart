import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/fixed_deposit_model.dart';
import 'package:vittara_fin_os/logic/investments_controller.dart';
import 'package:vittara_fin_os/logic/investment_model.dart';
import 'package:vittara_fin_os/logic/fd_renewal_cycle.dart';
import 'package:vittara_fin_os/logic/accounts_controller.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/widgets/toast_notification.dart';

class FDWithdrawalModal extends StatefulWidget {
  final FixedDeposit fd;
  final VoidCallback onWithdraw;
  final InvestmentsController? investmentController;
  final Investment? originalInvestment;

  const FDWithdrawalModal({
    required this.fd,
    required this.onWithdraw,
    this.investmentController,
    this.originalInvestment,
    super.key,
  });

  @override
  State<FDWithdrawalModal> createState() => _FDWithdrawalModalState();
}

class _FDWithdrawalModalState extends State<FDWithdrawalModal> {
  late DateTime _withdrawalDate;
  late double _withdrawalValue;
  late TextEditingController _withdrawalAmountController;

  @override
  void initState() {
    super.initState();
    _withdrawalDate = widget.fd.maturityDate;
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
    if (date.isAtSameMomentAs(widget.fd.maturityDate) ||
        date.isAfter(widget.fd.maturityDate)) {
      return widget.fd.maturityValue;
    }

    // If withdrawal date is before maturity, calculate pro-rata interest
    final daysInvested = date.difference(widget.fd.investmentDate).inDays;
    final totalDays =
        widget.fd.maturityDate.difference(widget.fd.investmentDate).inDays;

    if (totalDays == 0) return widget.fd.principal;

    final proportionOfTenure = daysInvested / totalDays;
    final proportionOfInterest =
        widget.fd.totalInterestAtMaturity * proportionOfTenure;

    return widget.fd.principal + proportionOfInterest;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: AppStyles.getBackground(context),
        appBar: CupertinoNavigationBar(
          middle: const Text('Withdraw FD'),
          previousPageTitle: 'Back',
          backgroundColor: AppStyles.getBackground(context),
          border: null,
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.all(Spacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // FD Details Summary
              Container(
                padding: EdgeInsets.all(Spacing.lg),
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
                      widget.fd.name,
                      style: TextStyle(
                        color: AppStyles.getTextColor(context),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: Spacing.md),
                    _buildDetailRow(context, 'Principal',
                        '₹${widget.fd.principal.toStringAsFixed(2)}'),
                    _buildDetailRow(context, 'Maturity Date',
                        _formatDate(widget.fd.maturityDate)),
                    _buildDetailRow(context, 'Maturity Value',
                        '₹${widget.fd.maturityValue.toStringAsFixed(2)}'),
                  ],
                ),
              ),
              SizedBox(height: Spacing.lg),

              // Withdrawal Date Selection
              Text(
                'Withdrawal Date',
                style: TextStyle(
                  color: AppStyles.getTextColor(context),
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              SizedBox(height: Spacing.sm),
              GestureDetector(
                onTap: () => _showDatePicker(context),
                child: Container(
                  padding: EdgeInsets.all(Spacing.md),
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
                          fontSize: 16,
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
              SizedBox(height: Spacing.lg),

              // Withdrawal Value Info
              Container(
                padding: EdgeInsets.all(Spacing.lg),
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
                        fontSize: 12,
                      ),
                    ),
                    SizedBox(height: Spacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: CupertinoTextField(
                            controller: _withdrawalAmountController,
                            placeholder: '0.00',
                            prefix: Padding(
                              padding: EdgeInsets.only(left: Spacing.md),
                              child: Text(
                                '₹',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: AppStyles.getPrimaryColor(context),
                                ),
                              ),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            style: TextStyle(
                              color: AppStyles.getPrimaryColor(context),
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: AppStyles.getDividerColor(context),
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: EdgeInsets.symmetric(
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
                    SizedBox(height: Spacing.md),
                    if (_withdrawalDate.isBefore(widget.fd.maturityDate))
                      Row(
                        children: [
                          Icon(
                            CupertinoIcons.info,
                            size: 16,
                            color: AppStyles.getSecondaryTextColor(context),
                          ),
                          SizedBox(width: Spacing.sm),
                          Expanded(
                            child: Text(
                              'Early withdrawal: Pro-rata interest calculated',
                              style: TextStyle(
                                color: AppStyles.getSecondaryTextColor(context),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      Row(
                        children: [
                          Icon(
                            CupertinoIcons.check_mark_circled_solid,
                            size: 16,
                            color: Colors.green,
                          ),
                          SizedBox(width: Spacing.sm),
                          Expanded(
                            child: Text(
                              'At maturity: Full interest earned',
                              style: TextStyle(
                                color: Colors.green,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              SizedBox(height: Spacing.xxl),

              // Confirm Withdrawal Button
              SizedBox(
                width: double.infinity,
                child: CupertinoButton(
                  color: Colors.green,
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

                        // Get existing renewal cycles with safe casting
                        final existingCycles = <FDRenewalCycle>[];
                        final cyclesData =
                            originalInvestment.metadata?['renewalCycles'];
                        if (cyclesData is List) {
                          for (var c in cyclesData) {
                            try {
                              if (c is Map<String, dynamic>) {
                                existingCycles.add(FDRenewalCycle.fromMap(c));
                              } else if (c is Map) {
                                final cycleMap = Map<String, dynamic>.from(c);
                                existingCycles
                                    .add(FDRenewalCycle.fromMap(cycleMap));
                              }
                            } catch (e) {
                              // Skip invalid renewal cycle data
                            }
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
                            withdrawalDate: _withdrawalDate,
                            withdrawalAmount: withdrawalAmount,
                            withdrawalReason: 'Withdrawal from notification',
                          );
                        }

                        // Update the investment with withdrawal cycle
                        final existingMetadata =
                            originalInvestment.metadata ?? {};
                        final safeMetadata =
                            Map<String, dynamic>.from(existingMetadata);

                        final updatedInvestment = originalInvestment.copyWith(
                          metadata: {
                            ...safeMetadata,
                            'renewalCycles':
                                existingCycles.map((c) => c.toMap()).toList(),
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
                        final linkedAccountId = widget.fd.linkedAccountId;
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
                              );
                              final updatedAccount = linkedAccount.copyWith(
                                balance:
                                    linkedAccount.balance + withdrawalAmount,
                              );
                              await accountsController
                                  .updateAccount(updatedAccount);
                              if (!mounted) return;
                            } catch (e) {
                              // Account not found
                            }
                          } catch (e) {
                            // Continue even if account credit fails
                          }
                        }

                        if (mounted) {
                          toast.showSuccess(
                            'Withdrawal confirmed for ${_formatDate(_withdrawalDate)}. Amount: ₹${_withdrawalValue.toStringAsFixed(2)}',
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
              SizedBox(height: Spacing.lg),
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
                minimumDate: widget.fd.investmentDate,
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
      padding: EdgeInsets.only(bottom: Spacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppStyles.getSecondaryTextColor(context),
              fontSize: 12,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: AppStyles.getTextColor(context),
              fontWeight: FontWeight.w600,
              fontSize: 12,
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
    return '${date.day} ${months[date.month]} ${date.year}';
  }
}
