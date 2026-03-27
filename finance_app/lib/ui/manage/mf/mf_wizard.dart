import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/investments_controller.dart';
import 'package:vittara_fin_os/logic/investment_model.dart';
import 'package:vittara_fin_os/ui/manage/mf/mf_wizard_controller.dart';
import 'package:vittara_fin_os/ui/manage/mf/sip_wizard.dart';
import 'package:vittara_fin_os/ui/manage/mf/steps/mf_search_step.dart';
import 'package:vittara_fin_os/ui/manage/mf/steps/mf_type_selection_step.dart';
import 'package:vittara_fin_os/ui/manage/mf/steps/mf_account_selection_step.dart';
import 'package:vittara_fin_os/ui/manage/mf/steps/mf_transaction_details_step.dart';
import 'package:vittara_fin_os/ui/manage/mf/steps/mf_new_investment_details_step.dart';
import 'package:vittara_fin_os/ui/manage/mf/steps/mf_review_step.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/widgets/animations.dart';
import 'package:vittara_fin_os/ui/widgets/toast_notification.dart';

class MFWizard extends StatelessWidget {
  final MFWizardIntent? intent;

  const MFWizard({super.key, this.intent});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => MFWizardController(intent: intent),
      child: const _MFWizardContent(),
    );
  }
}

class _MFWizardContent extends StatefulWidget {
  const _MFWizardContent();

  @override
  State<_MFWizardContent> createState() => _MFWizardContentState();
}

class _MFWizardContentState extends State<_MFWizardContent> {
  bool _isSubmitting = false;

  Future<void> _saveInvestment(
    BuildContext context,
    MFWizardController controller,
  ) async {
    setState(() => _isSubmitting = true);
    final investmentsController =
        Provider.of<InvestmentsController>(context, listen: false);

    try {
      // Calculate units based on path
      double units = 0;
      double nav = 0;

      if (controller.selectedMFType == MFType.existing) {
        units = controller.averageNAV > 0
            ? controller.investmentAmount / controller.averageNAV
            : 0;
        nav = controller.averageNAV;
      } else {
        units = controller.calculatedUnits;
        nav = controller.fetchedNAV ?? 0;
      }

      // Create Investment with MF metadata
      final investment = Investment(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: controller.selectedMF!.schemeName,
        type: InvestmentType.mutualFund,
        amount: controller.investmentAmount,
        color: const Color(0xFF0066CC), // MF blue color
        broker: controller.selectedAccount?.bankName,
        metadata: {
          'schemeCode': controller.selectedMF!.schemeCode,
          'schemeName': controller.selectedMF!.schemeName,
          'schemeType': controller.selectedMF!.schemeType,
          'fundHouse': controller.selectedMF!.fundHouse,
          'accountId': controller.selectedAccount?.id,
          'units': units,
          'investmentNAV': nav,
          'investmentAmount': controller.investmentAmount,
          'investmentDate': controller.investmentDate.toIso8601String(),
          'currentNAV': controller.selectedMF!.nav,
          'currentValue': (controller.selectedMF!.nav ?? 0) * units,
          'investmentType': controller.selectedMFType?.name,
          'deductedFromAccount': controller.deductFromAccount &&
              controller.selectedMFType == MFType.newMF,
          'deductionAccountId': controller.deductFromAccount
              ? controller.deductionAccount?.id
              : null,
          'sipActive': controller.sipActive,
          'sipData': controller.sipData,
        },
      );

      await investmentsController.addInvestment(investment);

      if (context.mounted) {
        Haptics.success();
        toast.showSuccess('Mutual Fund investment added successfully!');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (context.mounted) {
        toast.showError('Failed to save investment: $e');
      }
    } finally {
      if (context.mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _saveOrUpdateInvestment(
    BuildContext context,
    MFWizardController controller,
  ) async {
    if (controller.mode != MFWizardMode.add &&
        controller.targetInvestment != null) {
      await _updateInvestment(context, controller);
      return;
    }
    await _saveInvestment(context, controller);
  }

  Future<void> _updateInvestment(
    BuildContext context,
    MFWizardController controller,
  ) async {
    final investmentsController =
        Provider.of<InvestmentsController>(context, listen: false);

    final target = controller.targetInvestment!;
    final metadata = Map<String, dynamic>.from(target.metadata ?? {});
    final currentUnits = (metadata['units'] as num?)?.toDouble() ?? 0;
    final currentAmount =
        (metadata['investmentAmount'] as num?)?.toDouble() ?? target.amount;

    final transactionAmount = controller.investmentAmount;
    final transactionUnits = controller.selectedMFType == MFType.existing &&
            controller.averageNAV > 0
        ? transactionAmount / controller.averageNAV
        : controller.calculatedUnits;

    final sign = controller.mode == MFWizardMode.sell ? -1 : 1;
    final unitsDelta = sign * transactionUnits;
    final amountDelta = sign * transactionAmount;

    final freshUnits = (currentUnits + unitsDelta).clamp(0.0, double.infinity);
    final freshAmount =
        (currentAmount + amountDelta).clamp(0.0, double.infinity);
    final avgNav =
        freshUnits > 0 ? freshAmount / freshUnits : controller.averageNAV;
    final currentMarketNav =
        controller.selectedMF?.nav ?? controller.averageNAV;

    metadata['units'] = freshUnits;
    metadata['investmentAmount'] = freshAmount;
    metadata['investmentNAV'] = avgNav;
    metadata['currentNAV'] = currentMarketNav;
    metadata['currentValue'] = currentMarketNav * freshUnits;
    if (controller.mode == MFWizardMode.sip) {
      metadata['sipActive'] = true;
    }

    setState(() => _isSubmitting = true);
    try {
      if (controller.mode == MFWizardMode.sell && freshUnits <= 0) {
        // All units redeemed — remove investment entirely
        await investmentsController.removeInvestment(target.id);
        if (context.mounted) {
          Haptics.success();
          toast.showSuccess('All units redeemed. Investment removed.');
          Navigator.of(context).pop();
        }
      } else {
        final updatedInvestment =
            target.copyWith(amount: freshAmount, metadata: metadata);
        await investmentsController.updateInvestment(updatedInvestment);
        if (context.mounted) {
          Haptics.success();
          toast.showSuccess('Mutual Fund investment updated!');
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (context.mounted) {
        toast.showError('Failed to update investment: $e');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _openSIPWizard(BuildContext context) async {
    final controller = Provider.of<MFWizardController>(context, listen: false);

    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      FadeScalePageRoute(page: const SIPWizard()),
    );

    if (result != null && context.mounted) {
      controller.setSIPData(result);
      // Save investment with SIP data
      await _saveInvestment(context, controller);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<MFWizardController>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Determine progress steps based on MF type
    int totalSteps =
        5; // Default for Existing MF (Search, Type, Account, Details, SIP/Review)
    if (controller.selectedMFType == MFType.newMF) {
      totalSteps = 6; // New MF has an extra step (different details)
    }

    return CupertinoPageScaffold(
      backgroundColor: AppStyles.getBackground(context),
      navigationBar: AppStyles.isLandscape(context) ? null : CupertinoNavigationBar(
        previousPageTitle: 'Back',
        middle: Text(
          'Add Mutual Fund',
          style: TextStyle(color: AppStyles.getTextColor(context)),
        ),
        backgroundColor: AppStyles.getBackground(context),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.back),
          onPressed: () {
            if (controller.currentStep > 0) {
              controller.previousPage();
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
        border: null,
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Progress Indicator
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: List.generate(totalSteps, (index) {
                  return Expanded(
                    child: Container(
                      height: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: index <= controller.currentStep
                            ? SemanticColors.investments
                            : (isDark ? Colors.grey[800] : Colors.grey[300]),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
            ),
            Expanded(
              child: PageView(
                controller: controller.pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  // Step 0: Search
                  const MFSearchStep(),
                  // Step 1: Type Selection
                  const MFTypeSelectionStep(),
                  // Step 2: Account Selection
                  const MFAccountSelectionStep(),
                  // Step 3: Investment Details (Dynamic based on type)
                  if (controller.selectedMFType == MFType.existing)
                    const MFTransactionDetailsStep()
                  else
                    const MFNewInvestmentDetailsStep(),
                  // Step 4: SIP or Review
                  const MFReviewStep(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(Spacing.xl),
              child: SizedBox(
                width: double.infinity,
                child: CupertinoButton.filled(
                  onPressed: controller.canProceed() && !_isSubmitting
                      ? () async {
                          // Step 4: SIP Active toggle
                          if (controller.currentStep == 4 &&
                              controller.selectedMFType != MFType.newMF) {
                            // For Existing MF, ask about SIP before review
                            _showSIPDialog(context);
                          } else if (controller.currentStep == 4) {
                            // For New MF (Step 4 is Review), save directly
                            await _saveOrUpdateInvestment(context, controller);
                          } else if (controller.currentStep == 5) {
                            // After SIP, save
                            await _saveOrUpdateInvestment(context, controller);
                          } else {
                            controller.nextPage();
                          }
                        }
                      : null,
                  child: _isSubmitting
                      ? const CupertinoActivityIndicator(
                          color: CupertinoColors.white)
                      : Text(
                          controller.currentStep >= 4
                              ? (controller.sipActive
                                  ? 'Configure SIP'
                                  : 'Confirm & Save')
                              : 'Continue',
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSIPDialog(BuildContext context) {
    final controller = Provider.of<MFWizardController>(context, listen: false);

    showCupertinoDialog(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('Add SIP?'),
        content: const Text(
          'Do you want to set up a Systematic Investment Plan (SIP) for this mutual fund?',
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('No'),
            onPressed: () async {
              Navigator.pop(dialogContext); // Close dialog
              controller.setSIPData(null); // No SIP
              // Save investment without SIP (use main context)
              if (context.mounted) {
                await _saveOrUpdateInvestment(context, controller);
              }
            },
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('Yes'),
            onPressed: () {
              Navigator.pop(dialogContext); // Close dialog
              // Open SIP Wizard (use main context, not dialog context)
              _openSIPWizard(context);
            },
          ),
        ],
      ),
    );
  }
}
