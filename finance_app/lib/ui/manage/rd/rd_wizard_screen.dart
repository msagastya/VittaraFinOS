import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/investments_controller.dart';
import 'package:vittara_fin_os/logic/accounts_controller.dart';
import 'package:vittara_fin_os/logic/investment_model.dart';
import 'package:vittara_fin_os/ui/manage/rd/rd_wizard_controller.dart';
import 'package:vittara_fin_os/ui/manage/rd/steps/account_selection_step.dart';
import 'package:vittara_fin_os/ui/manage/rd/steps/start_date_step.dart';
import 'package:vittara_fin_os/ui/manage/rd/steps/amount_step.dart';
import 'package:vittara_fin_os/ui/manage/rd/steps/interest_rate_step.dart';
import 'package:vittara_fin_os/ui/manage/rd/steps/installments_step.dart';
import 'package:vittara_fin_os/ui/manage/rd/steps/frequency_step.dart';
import 'package:vittara_fin_os/ui/manage/rd/steps/review_step.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/widgets/toast_notification.dart';

class RDWizardScreen extends StatefulWidget {
  const RDWizardScreen({super.key});

  @override
  State<RDWizardScreen> createState() => _RDWizardScreenState();
}

class _RDWizardScreenState extends State<RDWizardScreen> {
  late RDWizardController _controller;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _controller = RDWizardController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildStepContent(int step) {
    switch (step) {
      case 0:
        return const AccountSelectionStep();
      case 1:
        return const StartDateStep();
      case 2:
        return const AmountStep();
      case 3:
        return const InterestRateStep();
      case 4:
        return const InstallmentsStep();
      case 5:
        return const FrequencyStep();
      case 6:
        return const ReviewStep();
      default:
        return const SizedBox.shrink();
    }
  }

  String _getStepTitle(int step) {
    switch (step) {
      case 0:
        return 'Select Account';
      case 1:
        return 'Start Date';
      case 2:
        return 'Installment Amount';
      case 3:
        return 'Interest Rate';
      case 4:
        return 'Total Installments';
      case 5:
        return 'Payment Frequency';
      case 6:
        return 'Review';
      default:
        return '';
    }
  }

  Future<void> _submitRD() async {
    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);

    try {
      final rd = _controller.buildRD();
      final investmentController =
          Provider.of<InvestmentsController>(context, listen: false);
      final accountsController =
          Provider.of<AccountsController>(context, listen: false);

      // Debit first installment from linked account if enabled
      if (_controller.debitFromAccount) {
        try {
          final account = accountsController.accounts.firstWhere(
            (a) => a.id == rd.linkedAccountId,
            orElse: () => throw Exception('Account not found'),
          );
          final updatedAccount = account.copyWith(
            balance: account.balance - rd.monthlyAmount,
          );
          await accountsController.updateAccount(updatedAccount);
        } catch (e) {
          if (mounted) {
            toast.showError('Failed to debit from account: $e');
          }
        }
      }

      // Save RD as Investment
      final investment = Investment(
        id: rd.id,
        name: rd.name,
        type: InvestmentType.recurringDeposit,
        amount: rd.totalInvestedAmount,
        color: const Color(0xFFD600CC), // RD color
        notes: rd.notes,
        broker: rd.bankName,
        metadata: {
          ...?rd.metadata,
          'rdData': rd.toMap(),
          'linkedAccountId': rd.linkedAccountId,
          'linkedAccountName': rd.linkedAccountName,
          'maturityDate': rd.maturityDate.toIso8601String(),
          'completedInstallments': rd.completedInstallments,
          'pendingInstallments': rd.pendingInstallments,
        },
      );

      await investmentController.addInvestment(investment);

      if (mounted) {
        toast.showSuccess('RD created successfully!');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        toast.showError('Error creating RD: $e');
      }
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _controller,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Create Recurring Deposit'),
          elevation: 0,
          backgroundColor: AppStyles.getBackground(context),
          foregroundColor: AppStyles.getTextColor(context),
        ),
        body: Column(
          children: [
            // Top Progress Bar (Like Stocks)
            Consumer<RDWizardController>(
              builder: (context, controller, child) {
                final progress = (controller.currentStep + 1) / 7;

                return Column(
                  children: [
                    // Linear Progress Bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 4,
                        backgroundColor:
                            AppStyles.getSecondaryTextColor(context)
                                .withValues(alpha: 0.1),
                        valueColor: AlwaysStoppedAnimation(
                            AppStyles.getPrimaryColor(context)),
                      ),
                    ),
                    // Step Title
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      color: AppStyles.getBackground(context),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getStepTitle(controller.currentStep),
                            style: TextStyle(
                              color: AppStyles.getTextColor(context),
                              fontSize: TypeScale.headline,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Step ${controller.currentStep + 1} of 7',
                            style: TextStyle(
                              color: AppStyles.getSecondaryTextColor(context),
                              fontSize: TypeScale.footnote,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
            // Step content
            Expanded(
              child: Consumer<RDWizardController>(
                builder: (context, controller, child) {
                  return _buildStepContent(controller.currentStep);
                },
              ),
            ),
            // Navigation buttons
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
              child: Consumer<RDWizardController>(
                builder: (context, controller, child) {
                  return Row(
                    children: [
                      // Back button
                      if (controller.currentStep > 0)
                        Expanded(
                          child: CupertinoButton(
                            onPressed: _isSubmitting
                                ? null
                                : () => controller.previousStep(),
                            color: AppStyles.getSecondaryTextColor(context)
                                .withValues(alpha: 0.15),
                            child: Text(
                              'Back',
                              style: TextStyle(
                                color: AppStyles.getSecondaryTextColor(context),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      if (controller.currentStep > 0) const SizedBox(width: 12),
                      // Next or Submit button
                      Expanded(
                        child: CupertinoButton(
                          onPressed:
                              _isSubmitting || !controller.canProceedToNextStep
                                  ? null
                                  : controller.currentStep == 6
                                      ? _submitRD
                                      : () => controller.nextStep(),
                          color: AppStyles.getPrimaryColor(context),
                          child: _isSubmitting
                              ? SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: const CupertinoActivityIndicator(
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  controller.currentStep == 6
                                      ? 'Create RD'
                                      : 'Next',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
