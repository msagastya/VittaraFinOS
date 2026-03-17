import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/investment_model.dart';
import 'package:vittara_fin_os/logic/investments_controller.dart';
import 'package:vittara_fin_os/models/cryptocurrency_model.dart';
import 'package:vittara_fin_os/ui/manage/cryptocurrency/crypto_wizard_controller.dart';
import 'package:vittara_fin_os/ui/manage/cryptocurrency/steps/crypto_purchase_step.dart';
import 'package:vittara_fin_os/ui/manage/cryptocurrency/steps/crypto_review_step.dart';
import 'package:vittara_fin_os/ui/manage/cryptocurrency/steps/crypto_selection_step.dart';
import 'package:vittara_fin_os/ui/manage/cryptocurrency/steps/crypto_wallet_step.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/widgets/animations.dart';
import 'package:vittara_fin_os/ui/widgets/toast_notification.dart';

class CryptoWizard extends StatelessWidget {
  const CryptoWizard({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CryptoWizardController(),
      child: const _CryptoWizardContent(),
    );
  }
}

class _CryptoWizardContent extends StatelessWidget {
  const _CryptoWizardContent();

  Future<void> _saveInvestment(
    BuildContext context,
    CryptoWizardController controller,
  ) async {
    final investmentsController =
        Provider.of<InvestmentsController>(context, listen: false);

    try {
      // Create transaction record
      final transaction = CryptoTransaction(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: CryptoTransactionType.buy,
        date: controller.purchaseDate,
        quantity: controller.quantity!,
        pricePerUnit: controller.pricePerUnit!,
        totalValue: controller.totalInvested,
        exchangeName: controller.selectedExchange?.toString(),
        walletAddress: controller.walletAddress,
        transactionFee: controller.transactionFee,
        notes: controller.notes,
      );

      // Create Investment object
      final investment = Investment(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: '${controller.cryptoName} (${controller.cryptoSymbol})',
        type: InvestmentType.cryptocurrency,
        amount: controller.totalWithFee,
        color: const Color(0xFFF7931A), // Crypto orange color
        broker: controller.selectedExchange?.toString().split('.').last,
        metadata: {
          'cryptoType': controller.selectedCrypto?.toString() ?? '',
          'name': controller.cryptoName,
          'symbol': controller.cryptoSymbol,
          'quantity': controller.quantity,
          'averageBuyPrice': controller.pricePerUnit,
          'totalInvested': controller.totalInvested,
          'transactionFee': controller.transactionFee,
          'currentPrice': controller.pricePerUnit, // Initially same as purchase
          'currentValue': controller.totalInvested,
          'walletType': controller.walletType.toString(),
          'walletAddress': controller.walletAddress,
          'exchange': controller.selectedExchange?.toString(),
          'transactions': [transaction.toMap()],
          'linkedAccountId': controller.linkedAccountId,
          'linkedAccountName': controller.linkedAccountName,
          'notes': controller.notes,
          'lastUpdated': DateTime.now().toIso8601String(),
        },
      );

      await investmentsController.addInvestment(investment);

      if (context.mounted) {
        Haptics.success();
        toast.showSuccess('Cryptocurrency investment added successfully!');
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
    final controller = Provider.of<CryptoWizardController>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    const int totalSteps = 4; // Selection, Wallet, Purchase, Review

    return CupertinoPageScaffold(
      backgroundColor: AppStyles.getBackground(context),
      navigationBar: CupertinoNavigationBar(
        previousPageTitle: 'Back',
        middle: Text(
          'Add Cryptocurrency',
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
                            ? const Color(0xFFF7931A)
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
                physics: const NeverScrollableScrollPhysics(),
                children: const [
                  // Step 0: Cryptocurrency Selection
                  CryptoSelectionStep(),
                  // Step 1: Wallet & Storage
                  CryptoWalletStep(),
                  // Step 2: Purchase Details
                  CryptoPurchaseStep(),
                  // Step 3: Review & Confirm
                  CryptoReviewStep(),
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
                          if (controller.currentStep < 3) {
                            controller.nextPage();
                          } else {
                            // Step 3: Save investment
                            await _saveInvestment(context, controller);
                          }
                        }
                      : null,
                  child: Text(
                    controller.currentStep >= 3 ? 'Confirm & Save' : 'Continue',
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
