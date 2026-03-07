import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/investments_controller.dart';
import 'package:vittara_fin_os/logic/accounts_controller.dart';
import 'package:vittara_fin_os/logic/investment_model.dart';
import 'package:vittara_fin_os/ui/manage/fd/fd_wizard_controller.dart';
import 'package:vittara_fin_os/ui/manage/fd/steps/account_selection_step.dart';
import 'package:vittara_fin_os/ui/manage/fd/steps/investment_date_step.dart';
import 'package:vittara_fin_os/ui/manage/fd/steps/principal_step.dart';
import 'package:vittara_fin_os/ui/manage/fd/steps/interest_rate_step.dart';
import 'package:vittara_fin_os/ui/manage/fd/steps/tenure_step.dart';
import 'package:vittara_fin_os/ui/manage/fd/steps/compounding_step.dart';
import 'package:vittara_fin_os/ui/manage/fd/steps/fd_type_payout_step.dart';
import 'package:vittara_fin_os/ui/manage/fd/steps/debit_and_review_step.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/widgets/animations.dart';
import 'package:vittara_fin_os/ui/widgets/toast_notification.dart';

class FDWizardScreen extends StatefulWidget {
  const FDWizardScreen({super.key});

  @override
  State<FDWizardScreen> createState() => _FDWizardScreenState();
}

class _FDWizardScreenState extends State<FDWizardScreen> {
  late FDWizardController _controller;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _controller = FDWizardController();
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
        return const InvestmentDateStep();
      case 2:
        return const PrincipalStep();
      case 3:
        return const InterestRateStep();
      case 4:
        return const TenureStep();
      case 5:
        return const CompoundingStep();
      case 6:
        return const FDTypePayoutStep();
      case 7:
        return const DebitAndReviewStep();
      default:
        return const SizedBox.shrink();
    }
  }

  String _getStepTitle(int step) {
    const titles = [
      'Select Account',
      'Investment Date',
      'Principal',
      'Interest Rate',
      'Duration',
      'Compounding',
      'Type & Payout',
      'Review'
    ];
    return titles[step];
  }

  Future<void> _submitFD() async {
    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);

    try {
      final fd = _controller.buildFD();
      final investmentController =
          Provider.of<InvestmentsController>(context, listen: false);
      final accountsController =
          Provider.of<AccountsController>(context, listen: false);

      // Debit principal from linked account if enabled.
      // If debit fails, abort — do not create FD with inconsistent state.
      if (_controller.debitFromAccount) {
        final account = accountsController.accounts.firstWhere(
          (a) => a.id == fd.linkedAccountId,
          orElse: () => throw Exception('Linked account not found'),
        );
        final updatedAccount = account.copyWith(
          balance: account.balance - fd.principal,
        );
        await accountsController.updateAccount(updatedAccount);
      }

      // Save FD as Investment
      final investment = Investment(
        id: fd.id,
        name: fd.name,
        type: InvestmentType.fixedDeposit,
        amount: fd.principal,
        color: const Color(0xFFFF6B00), // FD color
        notes: fd.notes,
        broker: fd.bankName,
        metadata: {
          ...?fd.metadata,
          'fdData': fd.toMap(),
          'linkedAccountId': fd.linkedAccountId,
          'linkedAccountName': fd.linkedAccountName,
          'maturityDate': fd.maturityDate.toIso8601String(),
          'investmentDate': fd.investmentDate.toIso8601String(),
          'createdDate': fd.createdDate.toIso8601String(),
          'estimatedAccruedValue': fd.maturityValue,
          'maturityValue': fd.maturityValue,
          'realizedValue': fd.realizedValue,
          'interestRate': fd.interestRate,
          'tenureMonths': fd.tenureMonths,
          'compoundingFrequency': fd.compoundingFrequency.toString(),
          'payoutFrequency': fd.payoutFrequency.toString(),
          'isCumulative': fd.isCumulative,
          'originalPrincipal':
              fd.principal, // Store original principal for display on renewal
          'debitedFromAccount': _controller.debitFromAccount,
        },
      );

      await investmentController.addInvestment(investment);

      if (mounted) {
        Haptics.success();
        toast.showSuccess('FD created successfully!');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        toast.showError('Error creating FD: $e');
      }
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _controller,
      child: CupertinoPageScaffold(
        backgroundColor: AppStyles.getBackground(context),
        navigationBar: CupertinoNavigationBar(
          middle: Text('Create Fixed Deposit',
              style: TextStyle(color: AppStyles.getTextColor(context))),
          previousPageTitle: 'Back',
          backgroundColor: AppStyles.getBackground(context),
          border: null,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top Progress Bar (Like Stocks)
              Consumer<FDWizardController>(
                builder: (context, controller, child) {
                  final progress = (controller.currentStep + 1) / 8;

                  return Column(
                    children: [
                      // Linear Progress Bar
                      Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppStyles.getSecondaryTextColor(context)
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: progress,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppStyles.getPrimaryColor(context),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
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
                            const SizedBox(height: Spacing.xs),
                            Text(
                              'Step ${controller.currentStep + 1} of 8',
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
                child: Consumer<FDWizardController>(
                  builder: (context, controller, child) {
                    return _buildStepContent(controller.currentStep);
                  },
                ),
              ),
              // Navigation buttons
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
                child: Consumer<FDWizardController>(
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
                                  color:
                                      AppStyles.getSecondaryTextColor(context),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        if (controller.currentStep > 0)
                          const SizedBox(width: Spacing.md),
                        // Next or Submit button
                        Expanded(
                          child: CupertinoButton(
                            onPressed: _isSubmitting ||
                                    !controller.canProceedToNextStep
                                ? null
                                : controller.currentStep == 7
                                    ? _submitFD
                                    : () => controller.nextStep(),
                            color: AppStyles.getPrimaryColor(context),
                            child: _isSubmitting
                                ? SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: const CupertinoActivityIndicator(
                                      color: CupertinoColors.white,
                                    ),
                                  )
                                : Text(
                                    controller.currentStep == 7
                                        ? 'Create FD'
                                        : 'Next',
                                    style: const TextStyle(
                                      color: CupertinoColors.white,
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
      ),
    );
  }
}
