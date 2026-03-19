import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/accounts_controller.dart';
import 'package:vittara_fin_os/logic/investments_controller.dart';
import 'package:vittara_fin_os/logic/investment_model.dart';
import 'package:vittara_fin_os/ui/manage/stocks/stocks_wizard_controller.dart';
import 'package:vittara_fin_os/ui/manage/stocks/steps/stock_search_step.dart';
import 'package:vittara_fin_os/ui/manage/stocks/steps/account_selection_step.dart';
import 'package:vittara_fin_os/ui/manage/stocks/steps/transaction_details_step.dart';
import 'package:vittara_fin_os/ui/manage/stocks/steps/deduction_step.dart';
import 'package:vittara_fin_os/ui/manage/stocks/steps/stock_review_step.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/widgets/animations.dart';
import 'package:vittara_fin_os/ui/widgets/toast_notification.dart';

class StocksWizard extends StatelessWidget {
  const StocksWizard({super.key, this.existingInvestment});

  /// When set, the stock search step (step 0) is pre-filled and skipped.
  final Investment? existingInvestment;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) =>
          StocksWizardController(existingInvestment: existingInvestment),
      child: const _StocksWizardContent(),
    );
  }
}

class _StocksWizardContent extends StatelessWidget {
  const _StocksWizardContent();

  Future<void> _saveInvestment(
      BuildContext context, StocksWizardController controller) async {
    final investmentsController =
        Provider.of<InvestmentsController>(context, listen: false);
    final accountsController =
        Provider.of<AccountsController>(context, listen: false);

    controller.isSubmitting = true;
    controller.notifyListeners();
    try {
      // 1. Deduct from account if needed
      if (controller.deductFromAccount && controller.selectedAccount != null) {
        final account = controller.selectedAccount!;
        final newBalance = account.balance - controller.totalDeduction;

        final updatedAccount = account.copyWith(balance: newBalance);
        await accountsController.updateAccount(updatedAccount);
      }

      // 2. Create Investment
      final investment = Investment(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: controller.selectedStock!.symbol,
        type: InvestmentType.stocks,
        amount: controller.totalAmount,
        color: const Color(0xFF00B050), // Stock color
        broker: controller.selectedAccount?.bankName,
        metadata: {
          'symbol': controller.selectedStock!.symbol,
          'name': controller.selectedStock!.name,
          'exchange': controller.selectedStock!.exchange,
          'accountId': controller.selectedAccount?.id,
          'qty': controller.qty,
          'pricePerShare': controller.price,
          'extraCharges': controller.extraCharges,
          'deductedFromAccount': controller.deductFromAccount,
          'purchaseDate': controller.purchaseDate.toIso8601String(),
          'currentValue': controller.currentValue > 0
              ? controller.currentValue
              : controller.totalAmount,
        },
      );

      await investmentsController.addInvestment(investment);

      if (context.mounted) {
        Haptics.success();
        toast.showSuccess('Investment added successfully!');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (context.mounted) {
        toast.showError('Failed to save investment: $e');
      }
    } finally {
      controller.isSubmitting = false;
      controller.notifyListeners();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<StocksWizardController>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return CupertinoPageScaffold(
      backgroundColor: AppStyles.getBackground(context),
      navigationBar: CupertinoNavigationBar(
        previousPageTitle: 'Back',
        middle: Text(
            controller.existingInvestment != null
                ? 'Buy More — ${controller.selectedStock?.symbol ?? controller.existingInvestment!.name}'
                : 'Add Stock Investment',
            style: TextStyle(color: AppStyles.getTextColor(context))),
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
                children: List.generate(5, (index) {
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
                  StockSearchStep(),
                  AccountSelectionStep(),
                  TransactionDetailsStep(),
                  DeductionStep(),
                  StockReviewStep(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(Spacing.xl),
              child: SizedBox(
                width: double.infinity,
                child: CupertinoButton.filled(
                  onPressed: controller.canProceed() && !controller.isSubmitting
                      ? () async {
                          if (controller.currentStep == 4) {
                            await _saveInvestment(context, controller);
                          } else {
                            controller.nextPage();
                          }
                        }
                      : null,
                  child: controller.isSubmitting
                      ? const CupertinoActivityIndicator()
                      : Text(controller.currentStep == 4
                          ? 'Confirm & Save'
                          : 'Continue'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
