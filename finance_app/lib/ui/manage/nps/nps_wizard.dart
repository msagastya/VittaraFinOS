import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/investment_model.dart';
import 'package:vittara_fin_os/logic/investments_controller.dart';
import 'package:vittara_fin_os/logic/nps_model.dart';
import 'package:vittara_fin_os/ui/manage/nps/nps_wizard_controller.dart';
import 'package:vittara_fin_os/ui/manage/nps/steps/nps_account_step.dart';
import 'package:vittara_fin_os/ui/manage/nps/steps/nps_contribution_step.dart';
import 'package:vittara_fin_os/ui/manage/nps/steps/nps_planning_step.dart';
import 'package:vittara_fin_os/ui/manage/nps/steps/nps_review_step.dart';
import 'package:vittara_fin_os/ui/manage/nps/steps/nps_valuation_step.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/widgets/animations.dart';
import 'package:vittara_fin_os/ui/widgets/toast_notification.dart';

class NPSWizard extends StatelessWidget {
  const NPSWizard({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => NPSWizardController(),
      child: const _NPSWizardContent(),
    );
  }
}

class _NPSWizardContent extends StatefulWidget {
  const _NPSWizardContent();

  @override
  State<_NPSWizardContent> createState() => _NPSWizardContentState();
}

class _NPSWizardContentState extends State<_NPSWizardContent> {
  late PageController _pageController;
  int _previousStep = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _saveInvestment(
    BuildContext context,
    NPSWizardController ctrl,
  ) async {
    final investmentsController =
        Provider.of<InvestmentsController>(context, listen: false);

    try {
      final npsAccount = NPSAccount(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        prnNumber: ctrl.prnNumber!,
        name: ctrl.fullName!,
        nrn: ctrl.nrnNumber!,
        tier: ctrl.selectedTier,
        accountType: ctrl.accountType,
        npsManager: ctrl.selectedManager!,
        schemeType: ctrl.schemeType,
        panNumber: ctrl.panNumber!,
        totalContributed: ctrl.totalContributed!,
        currentValue: ctrl.currentValue!,
        contributions: [],
        estimatedReturns: ctrl.estimatedReturns,
        withdrawalType: ctrl.withdrawalType,
        plannedRetirementDate: ctrl.plannedRetirementDate,
        createdDate: DateTime.now(),
        lastUpdate: DateTime.now(),
        notes: ctrl.notes,
      );

      final investment = Investment(
        id: npsAccount.id,
        name: '${ctrl.fullName} - NPS',
        type: InvestmentType.nationalSavingsScheme,
        amount: ctrl.totalContributed!,
        color: const Color(0xFF9B59B6),
        metadata: {
          'npsData': npsAccount.toMap(),
          'currentValue': ctrl.currentValue,
          'estimatedReturns': ctrl.estimatedReturns,
        },
      );

      await investmentsController.addInvestment(investment);

      if (context.mounted) {
        Haptics.success();
        toast.showSuccess('NPS account added successfully!');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (context.mounted) {
        toast.showError('Failed to save investment: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = Provider.of<NPSWizardController>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Handle page navigation when currentStep changes
    if (ctrl.currentStep != _previousStep) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (ctrl.currentStep > _previousStep) {
          _pageController.nextPage(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        } else {
          _pageController.previousPage(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      });
      _previousStep = ctrl.currentStep;
    }

    return CupertinoPageScaffold(
      backgroundColor: AppStyles.getBackground(context),
      navigationBar: AppStyles.isLandscape(context) ? null : CupertinoNavigationBar(
        previousPageTitle: 'Back',
        middle: Text('Add NPS Account',
            style: TextStyle(color: AppStyles.getTextColor(context))),
        backgroundColor: AppStyles.getBackground(context),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.back),
          onPressed: () {
            if (ctrl.currentStep > 0) {
              ctrl.previousPage();
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: List.generate(5, (i) {
                  return Expanded(
                    child: Container(
                      height: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: i <= ctrl.currentStep
                            ? const Color(0xFF9B59B6)
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
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: const [
                  NPSAccountStep(),
                  NPSContributionStep(),
                  NPSValuationStep(),
                  NPSPlanningStep(),
                  NPSReviewStep(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(Spacing.xl),
              child: SizedBox(
                width: double.infinity,
                child: CupertinoButton.filled(
                  onPressed: ctrl.canProceed()
                      ? () async {
                          if (ctrl.currentStep < 4) {
                            ctrl.nextPage();
                          } else {
                            await _saveInvestment(context, ctrl);
                          }
                        }
                      : null,
                  child: Text(
                      ctrl.currentStep >= 4 ? 'Confirm & Save' : 'Continue'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
