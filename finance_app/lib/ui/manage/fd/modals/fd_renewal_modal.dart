import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/fixed_deposit_model.dart';
import 'package:vittara_fin_os/logic/investments_controller.dart';
import 'package:vittara_fin_os/logic/accounts_controller.dart';
import 'package:vittara_fin_os/logic/account_model.dart';
import 'package:vittara_fin_os/logic/fd_renewal_cycle.dart';
import 'package:vittara_fin_os/ui/manage/fd/fd_wizard_controller.dart';
import 'package:vittara_fin_os/utils/date_formatter.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/widgets/toast_notification.dart';

class FDRenewalModal extends StatefulWidget {
  final FixedDeposit fd;
  final VoidCallback onRenew;
  final dynamic investmentController; // InvestmentsController
  final dynamic originalInvestment; // Investment

  const FDRenewalModal({
    required this.fd,
    required this.onRenew,
    this.investmentController,
    this.originalInvestment,
    super.key,
  });

  @override
  State<FDRenewalModal> createState() => _FDRenewalModalState();
}

class _FDRenewalModalState extends State<FDRenewalModal> {
  late FDWizardController _controller;
  late TextEditingController _fdNameController;
  late TextEditingController _tenureDurationController;
  late TextEditingController _principalController;
  late TextEditingController _interestRateController;

  TenureUnit _selectedUnit = TenureUnit.months;
  int _tenureDuration = 12;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _controller = FDWizardController();

    // Pre-fill with maturity value as new principal
    _controller.selectedAccount = null; // User will select
    _controller.principal = widget.fd.maturityValue;
    _controller.interestRate = widget.fd.interestRate;
    _controller.tenureMonths = widget.fd.tenureMonths;
    _controller.tenureUnit = TenureUnit.months;
    _controller.tenureDuration = widget.fd.tenureMonths;
    _controller.compoundingFrequency = widget.fd.compoundingFrequency;
    _controller.isCumulative = widget.fd.isCumulative;
    _controller.payoutFrequency = widget.fd.payoutFrequency;
    _controller.investmentDate =
        DateTime.now(); // Start from today (renewal date)

    _fdNameController =
        TextEditingController(text: '${widget.fd.name} (Renewal)');
    _tenureDurationController =
        TextEditingController(text: widget.fd.tenureMonths.toString());
    _principalController =
        TextEditingController(text: widget.fd.maturityValue.toStringAsFixed(2));
    _interestRateController =
        TextEditingController(text: widget.fd.interestRate.toStringAsFixed(2));

    // Initialize tenure from widget.fd
    _tenureDuration = widget.fd.tenureMonths;
    _selectedUnit = TenureUnit.months;
  }

  @override
  void dispose() {
    _controller.dispose();
    _fdNameController.dispose();
    _tenureDurationController.dispose();
    _principalController.dispose();
    _interestRateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _controller,
      child: SafeArea(
        child: Scaffold(
          backgroundColor: AppStyles.getBackground(context),
          appBar: CupertinoNavigationBar(
            middle: const Text('Renew FD'),
            previousPageTitle: 'Back',
            backgroundColor: AppStyles.getBackground(context),
            border: null,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(Spacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Principal (Auto-filled from maturity value)
                Text(
                  'Principal',
                  style: TextStyle(
                    color: AppStyles.getTextColor(context),
                    fontWeight: FontWeight.w600,
                    fontSize: TypeScale.body,
                  ),
                ),
                const SizedBox(height: Spacing.sm),
                CupertinoTextField(
                  controller: _principalController,
                  placeholder: 'Principal Amount',
                  placeholderStyle: TextStyle(
                      color: AppStyles.getSecondaryTextColor(context)),
                  padding: const EdgeInsets.all(Spacing.md),
                  decoration: BoxDecoration(
                    color: AppStyles.getCardColor(context),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  style: TextStyle(color: AppStyles.getTextColor(context)),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (value) {
                    _controller.updatePrincipal(
                        double.tryParse(value) ?? widget.fd.maturityValue);
                  },
                ),
                const SizedBox(height: Spacing.lg),

                // Investment Start Date (Editable - for date adjustments)
                Text(
                  'Investment Start Date',
                  style: TextStyle(
                    color: AppStyles.getTextColor(context),
                    fontWeight: FontWeight.w600,
                    fontSize: TypeScale.body,
                  ),
                ),
                const SizedBox(height: Spacing.sm),
                GestureDetector(
                  onTap: () => _showDatePicker(
                    context,
                    _controller.investmentDate,
                    (newDate) {
                      setState(() {
                        _controller.investmentDate = newDate;
                      });
                    },
                  ),
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
                          _formatDate(_controller.investmentDate),
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

                // Interest Rate (Editable)
                Text(
                  'Interest Rate',
                  style: TextStyle(
                    color: AppStyles.getTextColor(context),
                    fontWeight: FontWeight.w600,
                    fontSize: TypeScale.body,
                  ),
                ),
                const SizedBox(height: Spacing.sm),
                CupertinoTextField(
                  controller: _interestRateController,
                  placeholder: 'Annual Interest Rate (%)',
                  placeholderStyle: TextStyle(
                      color: AppStyles.getSecondaryTextColor(context)),
                  padding: const EdgeInsets.all(Spacing.md),
                  decoration: BoxDecoration(
                    color: AppStyles.getCardColor(context),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  style: TextStyle(color: AppStyles.getTextColor(context)),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (value) {
                    _controller.updateInterestRate(
                        double.tryParse(value) ?? widget.fd.interestRate);
                  },
                ),
                const SizedBox(height: Spacing.lg),

                // Tenure (Flexible - Days/Months/Years)
                Text(
                  'Tenure Duration',
                  style: TextStyle(
                    color: AppStyles.getTextColor(context),
                    fontWeight: FontWeight.w600,
                    fontSize: TypeScale.body,
                  ),
                ),
                const SizedBox(height: Spacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: CupertinoTextField(
                        controller: _tenureDurationController,
                        placeholder: 'Enter duration',
                        placeholderStyle: TextStyle(
                            color: AppStyles.getSecondaryTextColor(context)),
                        padding: const EdgeInsets.all(Spacing.md),
                        decoration: BoxDecoration(
                          color: AppStyles.getCardColor(context),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        style:
                            TextStyle(color: AppStyles.getTextColor(context)),
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          setState(() {
                            _tenureDuration = int.tryParse(value) ?? 12;
                            _updateTenureInController();
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: Spacing.md),
                    // Unit selector dropdown
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
                      decoration: BoxDecoration(
                        color: AppStyles.getCardColor(context),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppStyles.getDividerColor(context),
                          width: 1,
                        ),
                      ),
                      child: CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => _showUnitPicker(context),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _getUnitLabel(_selectedUnit),
                              style: TextStyle(
                                color: AppStyles.getTextColor(context),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: Spacing.sm),
                            Icon(
                              CupertinoIcons.chevron_down,
                              size: 16,
                              color: AppStyles.getPrimaryColor(context),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Spacing.lg),

                // FD Type
                Text(
                  'FD Type',
                  style: TextStyle(
                    color: AppStyles.getTextColor(context),
                    fontWeight: FontWeight.w600,
                    fontSize: TypeScale.body,
                  ),
                ),
                const SizedBox(height: Spacing.sm),
                Consumer<FDWizardController>(
                  builder: (context, controller, child) {
                    return Row(
                      children: [
                        Expanded(
                          child: _buildTypeOption(
                            context,
                            'Cumulative',
                            controller.isCumulative,
                            () => controller.updateFDType(true),
                          ),
                        ),
                        const SizedBox(width: Spacing.md),
                        Expanded(
                          child: _buildTypeOption(
                            context,
                            'Non-Cumulative',
                            !controller.isCumulative,
                            () => controller.updateFDType(false),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: Spacing.lg),

                // Maturity Value Display
                Consumer<FDWizardController>(
                  builder: (context, controller, child) {
                    return Container(
                      padding: const EdgeInsets.all(Spacing.lg),
                      decoration: BoxDecoration(
                        color: AppStyles.getCardColor(context),
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
                            'Estimated Maturity Value',
                            style: TextStyle(
                              color: AppStyles.getSecondaryTextColor(context),
                              fontSize: TypeScale.footnote,
                            ),
                          ),
                          const SizedBox(height: Spacing.sm),
                          Text(
                            '₹${controller.maturityValue.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: AppStyles.getPrimaryColor(context),
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: Spacing.sm),
                          Text(
                            'Interest: ₹${controller.totalInterestAtMaturity.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: AppStyles.getSecondaryTextColor(context),
                              fontSize: TypeScale.footnote,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: Spacing.lg),

                // Estimated Maturity Date
                Container(
                  padding: const EdgeInsets.all(Spacing.lg),
                  decoration: BoxDecoration(
                    color: AppStyles.getPrimaryColor(context)
                        .withValues(alpha: 0.1),
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
                        'Estimated Maturity Date',
                        style: TextStyle(
                          color: AppStyles.getSecondaryTextColor(context),
                          fontSize: TypeScale.footnote,
                        ),
                      ),
                      const SizedBox(height: Spacing.sm),
                      Text(
                        _formatDate(_calculateMaturityDate()),
                        style: TextStyle(
                          color: AppStyles.getPrimaryColor(context),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: Spacing.sm),
                      Text(
                        'Based on ${_controller.tenureMonths} months from ${_formatDate(_controller.investmentDate)}',
                        style: TextStyle(
                          color: AppStyles.getSecondaryTextColor(context),
                          fontSize: TypeScale.caption,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Spacing.lg),

                // FD Name
                Text(
                  'FD Name',
                  style: TextStyle(
                    color: AppStyles.getTextColor(context),
                    fontWeight: FontWeight.w600,
                    fontSize: TypeScale.body,
                  ),
                ),
                const SizedBox(height: Spacing.sm),
                CupertinoTextField(
                  controller: _fdNameController,
                  placeholder: 'e.g., My FD Renewal',
                  padding: const EdgeInsets.all(Spacing.md),
                  decoration: BoxDecoration(
                    color: AppStyles.getCardColor(context),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  style: TextStyle(color: AppStyles.getTextColor(context)),
                  onChanged: (value) => _controller.updateFDName(value),
                ),
                const SizedBox(height: Spacing.xxl),

                // Confirm Button
                SizedBox(
                  width: double.infinity,
                  child: CupertinoButton(
                    color: AppStyles.getPrimaryColor(context),
                    onPressed: _isSubmitting
                        ? null
                        : () async {
                            if (_isSubmitting) return;

                            setState(() => _isSubmitting = true);

                            try {
                              // Update controller with current values from text fields
                              _controller.updateFDName(_fdNameController.text);
                              final principal =
                                  double.tryParse(_principalController.text) ??
                                      widget.fd.maturityValue;
                              final interestRate = double.tryParse(
                                      _interestRateController.text) ??
                                  widget.fd.interestRate;

                              _controller.updatePrincipal(principal);
                              _controller.updateInterestRate(interestRate);

                              // Get accounts controller to find the original linked account
                              final accountsController =
                                  Provider.of<AccountsController>(context,
                                      listen: false);
                              Account? linkedAccount;
                              try {
                                linkedAccount =
                                    accountsController.accounts.firstWhere(
                                  (a) => a.id == widget.fd.linkedAccountId,
                                  orElse: () => throw Exception(
                                      'Linked account not found'),
                                );
                              } catch (e) {
                                if (context.mounted) {
                                  toast.showError('Linked account not found');
                                }
                                return;
                              }

                              _controller.selectedAccount = linkedAccount;

                              // Get investments controller
                              final investmentsController = widget
                                      .investmentController ??
                                  Provider.of<InvestmentsController>(context,
                                      listen: false);

                              // Build the renewed FD
                              final renewedFD = _controller.buildFD();

                              // Create a renewal cycle for this renewal
                              final renewalCycle = FDRenewalCycle(
                                cycleNumber: ((widget.originalInvestment
                                                    ?.metadata?['renewalCycles']
                                                as List?)
                                            ?.length ??
                                        0) +
                                    1,
                                investmentDate: renewedFD.investmentDate,
                                maturityDate: renewedFD.maturityDate,
                                principal: renewedFD.principal,
                                interestRate: renewedFD.interestRate,
                                tenureMonths: renewedFD.tenureMonths,
                                maturityValue: renewedFD.maturityValue,
                                isWithdrawn: false,
                                isCompleted: false,
                              );

                              // Get existing renewal cycles with safe casting
                              final existingCycles = <FDRenewalCycle>[];
                              final cyclesData = widget.originalInvestment
                                  ?.metadata?['renewalCycles'];
                              if (cyclesData is List) {
                                for (var c in cyclesData) {
                                  try {
                                    if (c is Map<String, dynamic>) {
                                      existingCycles
                                          .add(FDRenewalCycle.fromMap(c));
                                    } else if (c is Map) {
                                      final cycleMap =
                                          Map<String, dynamic>.from(c);
                                      existingCycles.add(
                                          FDRenewalCycle.fromMap(cycleMap));
                                    }
                                  } catch (e) {
                                    // Skip invalid renewal cycle data
                                  }
                                }
                              }

                              // Add new cycle to the list
                              existingCycles.add(renewalCycle);

                              // Update the original investment with new renewal cycle
                              final existingMetadata =
                                  widget.originalInvestment?.metadata ?? {};
                              final safeMetadata =
                                  Map<String, dynamic>.from(existingMetadata);

                              final updatedInvestment =
                                  widget.originalInvestment!.copyWith(
                                amount: widget.originalInvestment!
                                    .amount, // KEEP ORIGINAL PRINCIPAL
                                metadata: {
                                  ...safeMetadata,
                                  'renewalCycles': existingCycles
                                      .map((c) => c.toMap())
                                      .toList(),
                                  'currentCycleIndex':
                                      existingCycles.length - 1,
                                  'lastRenewalDate':
                                      DateTime.now().toIso8601String(),
                                  'interestRate': renewedFD
                                      .interestRate, // Update to current rate
                                  'maturityDate':
                                      renewedFD.maturityDate.toIso8601String(),
                                  'estimatedAccruedValue':
                                      renewedFD.estimatedAccruedValue,
                                  'linkedAccountId': linkedAccount.id,
                                  'linkedAccountName': linkedAccount.name,
                                },
                              );

                              // Update the investment (not create new one)
                              await investmentsController
                                  .updateInvestment(updatedInvestment);

                              if (context.mounted) {
                                toast.showSuccess('FD Renewed Successfully!');
                                Navigator.of(context).pop();
                                Navigator.of(context).pop();
                              }
                            } catch (e) {
                              if (context.mounted) {
                                toast.showError('Error: $e');
                              }
                            } finally {
                              if (mounted) {
                                setState(() => _isSubmitting = false);
                              }
                            }
                          },
                    child: Text(
                      _isSubmitting ? 'Processing...' : 'Confirm Renewal',
                      style: const TextStyle(
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
      ),
    );
  }

  void _showDatePicker(
    BuildContext context,
    DateTime selectedDate,
    Function(DateTime) onDateChanged,
  ) {
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
                initialDateTime: selectedDate,
                onDateTimeChanged: onDateChanged,
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

  DateTime _calculateMaturityDate() {
    // Use proper date arithmetic (handles leap years and varying month lengths)
    final DateTime result = _controller.investmentDate;

    switch (_selectedUnit) {
      case TenureUnit.days:
        // Add days directly
        return result.add(Duration(days: _tenureDuration));

      case TenureUnit.months:
        // Add months properly (date-to-date)
        var newMonth = result.month + _tenureDuration;
        var newYear = result.year;

        while (newMonth > 12) {
          newMonth -= 12;
          newYear++;
        }

        // Handle day overflow for months with fewer days
        final maxDayInMonth = DateTime(newYear, newMonth + 1, 0).day;
        final day = result.day > maxDayInMonth ? maxDayInMonth : result.day;

        return DateTime(newYear, newMonth, day);

      case TenureUnit.years:
        // Add years properly (date-to-date, handles leap years)
        return DateTime(
          result.year + _tenureDuration,
          result.month,
          result.day,
        );
    }
  }

  int _convertToDays(int duration, TenureUnit unit) {
    // Legacy method - kept for backward compatibility if needed
    // But _calculateMaturityDate() now uses proper date arithmetic
    switch (unit) {
      case TenureUnit.days:
        return duration;
      case TenureUnit.months:
        return (duration * 365 / 12).toInt();
      case TenureUnit.years:
        return duration * 365;
    }
  }

  void _updateTenureInController() {
    final int tenureInMonths = _convertToMonths(_tenureDuration, _selectedUnit);
    _controller.updateTenure(tenureInMonths);
  }

  int _convertToMonths(int duration, TenureUnit unit) {
    switch (unit) {
      case TenureUnit.days:
        // 1 day = 12/365 months
        return (duration * 12 / 365).toInt();
      case TenureUnit.months:
        return duration;
      case TenureUnit.years:
        // 1 year = 12 months
        return duration * 12;
    }
  }

  String _getUnitLabel(TenureUnit unit) {
    switch (unit) {
      case TenureUnit.days:
        return 'Days';
      case TenureUnit.months:
        return 'Months';
      case TenureUnit.years:
        return 'Years';
    }
  }

  void _showUnitPicker(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => Container(
        color: AppStyles.getBackground(context),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.lg, vertical: Spacing.md),
              decoration: BoxDecoration(
                color: AppStyles.getCardColor(context),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Select Unit',
                    style: TextStyle(
                      color: AppStyles.getTextColor(context),
                      fontSize: TypeScale.headline,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: const Text('Done'),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            ...TenureUnit.values.map((unit) {
              final isSelected = _selectedUnit == unit;
              return CupertinoButton(
                padding: const EdgeInsets.symmetric(
                    horizontal: Spacing.lg, vertical: Spacing.md),
                onPressed: () {
                  setState(() {
                    _selectedUnit = unit;
                    _updateTenureInController();
                  });
                  Navigator.of(context).pop();
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(Spacing.md),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppStyles.getPrimaryColor(context)
                            .withValues(alpha: 0.1)
                        : AppStyles.getCardColor(context),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? AppStyles.getPrimaryColor(context)
                          : AppStyles.getDividerColor(context),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Text(
                    _getUnitLabel(unit),
                    style: TextStyle(
                      color: isSelected
                          ? AppStyles.getPrimaryColor(context)
                          : AppStyles.getTextColor(context),
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w600,
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: Spacing.lg),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeOption(
    BuildContext context,
    String label,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(Spacing.md),
        decoration: BoxDecoration(
          color: isSelected
              ? AppStyles.getPrimaryColor(context).withValues(alpha: 0.15)
              : AppStyles.getCardColor(context),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? AppStyles.getPrimaryColor(context)
                : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: AppStyles.getTextColor(context),
              fontWeight: FontWeight.w600,
              fontSize: TypeScale.subhead,
            ),
          ),
        ),
      ),
    );
  }
}
