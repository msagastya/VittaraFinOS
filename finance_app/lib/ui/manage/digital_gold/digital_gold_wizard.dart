import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/investments_controller.dart';
import 'package:vittara_fin_os/logic/investment_model.dart';
import 'package:vittara_fin_os/ui/manage/digital_gold/digital_gold_wizard_controller.dart';
import 'package:vittara_fin_os/ui/manage/digital_gold/steps/gold_company_step.dart';
import 'package:vittara_fin_os/ui/manage/digital_gold/steps/gold_invested_amount_step.dart';
import 'package:vittara_fin_os/ui/manage/digital_gold/steps/gold_rate_step.dart';
import 'package:vittara_fin_os/ui/manage/digital_gold/steps/gold_gst_step.dart';
import 'package:vittara_fin_os/ui/manage/digital_gold/steps/gold_investment_date_step.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/widgets/toast_notification.dart';

class DigitalGoldWizard extends StatelessWidget {
  const DigitalGoldWizard({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => DigitalGoldWizardController(),
      child: const _DigitalGoldWizardContent(),
    );
  }
}

class _DigitalGoldWizardContent extends StatelessWidget {
  const _DigitalGoldWizardContent();

  Future<void> _saveInvestment(
    BuildContext context,
    DigitalGoldWizardController controller,
  ) async {
    final investmentsController =
        Provider.of<InvestmentsController>(context, listen: false);

    try {
      final investment = Investment(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: controller.selectedCompany!.name,
        type: InvestmentType.digitalGold,
        amount: controller.investedAmount,
        color: const Color(0xFFFFB81C),
        broker: null,
        metadata: {
          'company': controller.selectedCompany!.name,
          'investmentRate': controller.investmentRate,
          'gstRate': controller.gstRate,
          'investmentDate': controller.investmentDate.toIso8601String(),
          'investedAmount': controller.investedAmount,
          'actualGoldCost': controller.actualAmount,
          'gstAmount': controller.gstAmount,
          'weightInGrams': controller.weightInGrams,
          'currentRate':
              0.0, // Will be fetched and updated when viewing details
          'currentValue': 0.0, // Will be calculated when viewing details
          'lastUpdated': DateTime.now().toIso8601String(),
        },
      );

      await investmentsController.addInvestment(investment);

      if (context.mounted) {
        toast.showSuccess('Digital Gold investment added successfully!');
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
    final controller = Provider.of<DigitalGoldWizardController>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    const int totalSteps = 5; // Company, Amount, Rate, GST, Date

    return CupertinoPageScaffold(
      backgroundColor: AppStyles.getBackground(context),
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          'Add Digital Gold',
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
                            ? const Color(0xFFFFB81C)
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
                  // Step 0: Company Selection
                  GoldCompanyStep(),
                  // Step 1: Invested Amount
                  GoldInvestedAmountStep(),
                  // Step 2: Investment Rate
                  GoldRateStep(),
                  // Step 3: GST Rate
                  GoldGSTStep(),
                  // Step 4: Investment Date
                  GoldInvestmentDateStep(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(Spacing.xl),
              child: SizedBox(
                width: double.infinity,
                child: CupertinoButton.filled(
                  onPressed: controller.canProceed()
                      ? () async {
                          if (controller.currentStep < 4) {
                            controller.nextPage();
                          } else {
                            // Step 4: Save investment
                            await _saveInvestment(context, controller);
                          }
                        }
                      : null,
                  child: Text(
                    controller.currentStep >= 4 ? 'Confirm & Save' : 'Continue',
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
