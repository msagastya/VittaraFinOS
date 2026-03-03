import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/account_model.dart';
import 'package:vittara_fin_os/ui/manage/mf/sip_wizard_controller.dart';
import 'package:vittara_fin_os/ui/manage/mf/steps/sip_amount_step.dart';
import 'package:vittara_fin_os/ui/manage/mf/steps/sip_frequency_deduction_step.dart';
import 'package:vittara_fin_os/ui/manage/mf/steps/sip_stepup_step.dart';
import 'package:vittara_fin_os/ui/manage/mf/steps/sip_review_step.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';

class SIPWizard extends StatelessWidget {
  final Map<String, dynamic>? initialData;
  final Account? initialAccount;

  const SIPWizard({
    super.key,
    this.initialData,
    this.initialAccount,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SIPWizardController(
        initialData: initialData,
        initialAccount: initialAccount,
      ),
      child: const _SIPWizardContent(),
    );
  }
}

class _SIPWizardContent extends StatelessWidget {
  const _SIPWizardContent();

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<SIPWizardController>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return CupertinoPageScaffold(
      backgroundColor: AppStyles.getBackground(context),
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          'Configure SIP',
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
                children: List.generate(4, (index) {
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
                children: const [
                  SIPAmountStep(),
                  SIPFrequencyDeductionStep(),
                  SIPStepUpStep(),
                  SIPReviewStep(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(Spacing.xl),
              child: SizedBox(
                width: double.infinity,
                child: CupertinoButton.filled(
                  onPressed: controller.canProceed()
                      ? () {
                          if (controller.currentStep == 3) {
                            // Return SIP data to parent
                            Navigator.of(context).pop(controller.getSIPData());
                          } else {
                            controller.nextPage();
                          }
                        }
                      : null,
                  child: Text(
                    controller.currentStep == 3 ? 'Confirm SIP' : 'Continue',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
