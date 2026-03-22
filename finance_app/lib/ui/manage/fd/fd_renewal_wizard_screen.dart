import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/investments_controller.dart';
import 'package:vittara_fin_os/logic/fixed_deposit_model.dart';
import 'package:vittara_fin_os/logic/investment_model.dart';
import 'package:vittara_fin_os/logic/fd_renewal_cycle.dart';
import 'package:vittara_fin_os/ui/manage/fd/fd_renewal_wizard_controller.dart';
import 'package:vittara_fin_os/ui/manage/fd/steps/interest_rate_step.dart';
import 'package:vittara_fin_os/ui/manage/fd/steps/tenure_step.dart';
import 'package:vittara_fin_os/ui/manage/fd/steps/compounding_step.dart';
import 'package:vittara_fin_os/ui/manage/fd/steps/fd_type_payout_step.dart';
import 'package:vittara_fin_os/ui/manage/fd/steps/debit_and_review_step.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/widgets/toast_notification.dart';

class FDRenewalWizardScreen extends StatefulWidget {
  final FixedDeposit fd;
  final Investment? originalInvestment;

  const FDRenewalWizardScreen({
    required this.fd,
    this.originalInvestment,
    super.key,
  });

  @override
  State<FDRenewalWizardScreen> createState() => _FDRenewalWizardScreenState();
}

class _FDRenewalWizardScreenState extends State<FDRenewalWizardScreen> {
  late FDRenewalWizardController _controller;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _controller = FDRenewalWizardController(existingFD: widget.fd);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildStepContent(int step) {
    switch (step) {
      case 0:
        return const InterestRateStep();
      case 1:
        return const TenureStep();
      case 2:
        return const CompoundingStep();
      case 3:
        return const FDTypePayoutStep();
      case 4:
        return const DebitAndReviewStep();
      default:
        return const SizedBox.shrink();
    }
  }

  String _getStepTitle(int step) {
    const titles = [
      'Interest Rate',
      'Duration',
      'Compounding',
      'Type & Payout',
      'Review'
    ];
    return titles[step];
  }

  Future<void> _submitRenewal() async {
    if (_isSubmitting) return;
    _isSubmitting = true;

    try {
      final investmentsController =
          Provider.of<InvestmentsController>(context, listen: false);

      // Create renewed FD using copyWith
      final renewedFD = widget.fd.copyWith(
        name: _controller.fdName,
        principal: _controller.principal,
        interestRate: _controller.interestRate,
        tenureMonths: _controller.tenureMonths,
        investmentDate: _controller.renewalDate,
        maturityDate: _controller.maturityDate,
        maturityValue: _controller.maturityValue,
        compoundingFrequency: _controller.compoundingFrequency,
        isCumulative: _controller.isCumulative,
        payoutFrequency: _controller.payoutFrequency,
        notes: _controller.fdNotes,
        autoLinkEnabled: _controller.autoLinkEnabled,
      );

      // Create renewal cycle for tracking
      final renewalCycle = FDRenewalCycle(
        cycleNumber: (widget.fd.metadata?['renewalCycle'] != null
                ? (widget.fd.metadata!['renewalCycle'] as Map)['cycleNumber']
                    as int
                : 1) +
            1,
        investmentDate: _controller.renewalDate,
        maturityDate: _controller.maturityDate,
        principal: _controller.principal,
        interestRate: _controller.interestRate,
        tenureMonths: _controller.tenureMonths,
        maturityValue: _controller.maturityValue,
        isWithdrawn: false,
        isCompleted: false,
      );

      // Update the investment with renewed FD data and renewal cycle
      await investmentsController.updateInvestment(
        widget.originalInvestment!.copyWith(
          amount: _controller.principal,
          metadata: {
            ...widget.originalInvestment?.metadata ?? {},
            'fdData': renewedFD.toMap(),
            'maturityDate': _controller.maturityDate.toIso8601String(),
            'renewalCycle': renewalCycle.toMap(),
          },
        ),
      );

      if (mounted) {
        toast.showSuccess('FD renewed successfully!');
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        toast.showError('Failed to renew FD: $e');
      }
    } finally {
      _isSubmitting = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _controller,
      child: CupertinoPageScaffold(
        backgroundColor: AppStyles.getBackground(context),
        navigationBar: CupertinoNavigationBar(
          middle: Consumer<FDRenewalWizardController>(
            builder: (context, controller, _) {
              return Text('Renew FD - Step ${controller.currentStep + 1}/5');
            },
          ),
          previousPageTitle: 'Back',
          backgroundColor: AppStyles.getBackground(context),
          border: null,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Progress Indicator
              Consumer<FDRenewalWizardController>(
                builder: (context, controller, child) {
                  return Padding(
                    padding: const EdgeInsets.all(Spacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getStepTitle(controller.currentStep),
                          style: AppStyles.titleStyle(context),
                        ),
                        const SizedBox(height: Spacing.md),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: (controller.currentStep + 1) / 5,
                            minHeight: 4,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              // Step Content
              Expanded(
                child: Consumer<FDRenewalWizardController>(
                  builder: (context, controller, _) {
                    return _buildStepContent(controller.currentStep);
                  },
                ),
              ),
              // Navigation Buttons
              Consumer<FDRenewalWizardController>(
                builder: (context, controller, child) {
                  return Padding(
                    padding: const EdgeInsets.all(Spacing.lg),
                    child: Row(
                      children: [
                        if (controller.currentStep > 0)
                          Expanded(
                            child: CupertinoButton(
                              color: AppStyles.getCardColor(context),
                              onPressed: () => controller.previousStep(),
                              child: Text(
                                'Previous',
                                style: TextStyle(
                                    color: AppStyles.getTextColor(context)),
                              ),
                            ),
                          ),
                        if (controller.currentStep > 0)
                          const SizedBox(width: Spacing.md),
                        Expanded(
                          child: CupertinoButton(
                            color: controller.canProceedToNextStep
                                ? AppStyles.teal(context)
                                : CupertinoColors.inactiveGray,
                            onPressed: controller.canProceedToNextStep
                                ? (controller.currentStep == 4
                                    ? (_isSubmitting ? null : _submitRenewal)
                                    : () => controller.nextStep())
                                : null,
                            child: Text(
                              controller.currentStep == 4
                                  ? 'Complete Renewal'
                                  : 'Next',
                              style:
                                  const TextStyle(color: CupertinoColors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
