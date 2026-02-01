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
import 'package:vittara_fin_os/ui/widgets/toast_notification.dart';

class MFWizard extends StatelessWidget {
  const MFWizard({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => MFWizardController(),
      child: const _MFWizardContent(),
    );
  }
}

class _MFWizardContent extends StatelessWidget {
  const _MFWizardContent();

  Future<void> _saveInvestment(
    BuildContext context,
    MFWizardController controller,
  ) async {
    final investmentsController =
        Provider.of<InvestmentsController>(context, listen: false);

    try {
      // Calculate units based on path
      double units = 0;
      double nav = 0;

      if (controller.selectedMFType == MFType.existing) {
        units = controller.investmentAmount / controller.averageNAV;
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
          'deductedFromAccount':
              controller.deductFromAccount && controller.selectedMFType == MFType.newMF,
          'deductionAccountId':
              controller.deductFromAccount ? controller.deductionAccount?.id : null,
          'sipActive': controller.sipActive,
          'sipData': controller.sipData,
        },
      );

      await investmentsController.addInvestment(investment);

      if (context.mounted) {
        toast.showSuccess('Mutual Fund investment added successfully!');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (context.mounted) {
        toast.showError('Failed to save investment: $e');
      }
    }
  }

  Future<void> _openSIPWizard(BuildContext context) async {
    final controller = Provider.of<MFWizardController>(context, listen: false);

    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      CupertinoPageRoute(builder: (context) => const SIPWizard()),
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
    int totalSteps = 5; // Default for Existing MF (Search, Type, Account, Details, SIP/Review)
    if (controller.selectedMFType == MFType.newMF) {
      totalSteps = 6; // New MF has an extra step (different details)
    }

    return CupertinoPageScaffold(
      backgroundColor: AppStyles.getBackground(context),
      navigationBar: CupertinoNavigationBar(
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
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                child: CupertinoButton.filled(
                  onPressed: controller.canProceed()
                      ? () async {
                          // Step 4: SIP Active toggle
                          if (controller.currentStep == 4 &&
                              controller.selectedMFType != MFType.newMF) {
                            // For Existing MF, ask about SIP before review
                            _showSIPDialog(context);
                          } else if (controller.currentStep == 4) {
                            // For New MF (Step 4 is Review), save directly
                            await _saveInvestment(context, controller);
                          } else if (controller.currentStep == 5) {
                            // After SIP, save
                            await _saveInvestment(context, controller);
                          } else {
                            controller.nextPage();
                          }
                        }
                      : null,
                  child: Text(
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
                await _saveInvestment(context, controller);
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
