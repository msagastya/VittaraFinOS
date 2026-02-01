import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/investment_model.dart';
import 'package:vittara_fin_os/logic/investments_controller.dart';
import 'package:vittara_fin_os/logic/commodities_model.dart';
import 'package:vittara_fin_os/ui/manage/commodities/commodities_wizard_controller.dart';
import 'package:vittara_fin_os/ui/manage/commodities/steps/commodity_type_step.dart';
import 'package:vittara_fin_os/ui/manage/commodities/steps/commodity_quantity_step.dart';
import 'package:vittara_fin_os/ui/manage/commodities/steps/commodity_price_step.dart';
import 'package:vittara_fin_os/ui/manage/commodities/steps/commodity_position_step.dart';
import 'package:vittara_fin_os/ui/manage/commodities/steps/commodity_review_step.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/widgets/toast_notification.dart';

class CommoditiesWizard extends StatelessWidget {
  const CommoditiesWizard({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CommoditiesWizardController(),
      child: const _CommoditiesWizardContent(),
    );
  }
}

class _CommoditiesWizardContent extends StatefulWidget {
  const _CommoditiesWizardContent();

  @override
  State<_CommoditiesWizardContent> createState() =>
      _CommoditiesWizardContentState();
}

class _CommoditiesWizardContentState extends State<_CommoditiesWizardContent> {
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
    CommoditiesWizardController ctrl,
  ) async {
    final investmentsController =
        Provider.of<InvestmentsController>(context, listen: false);

    try {
      final commodity = Commodity(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: ctrl.commodityName,
        type: ctrl.selectedType,
        quantity: ctrl.quantity!,
        unit: ctrl.unit!,
        buyPrice: ctrl.buyPrice!,
        currentPrice: ctrl.currentPrice!,
        position: ctrl.position,
        purchaseDate: ctrl.purchaseDate,
        exchange: ctrl.exchange!,
        createdDate: DateTime.now(),
        notes: ctrl.notes,
      );

      final investment = Investment(
        id: commodity.id,
        name: commodity.name,
        type: InvestmentType.commodities,
        amount: ctrl.totalCost,
        color: const Color(0xFF8B4513),
        metadata: {
          'commodityData': commodity.toMap(),
          'currentValue': ctrl.currentValue,
        },
      );

      await investmentsController.addInvestment(investment);

      if (context.mounted) {
        toast.showSuccess('Commodity investment added successfully!');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (context.mounted) {
        toast.showError('Failed to save: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = Provider.of<CommoditiesWizardController>(context);
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
      navigationBar: CupertinoNavigationBar(
        middle: Text('Add Commodity',
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
                            ? const Color(0xFF8B4513)
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
                children: [
                  CommodityTypeStep(ctrl),
                  CommodityQuantityStep(ctrl),
                  CommodityPriceStep(ctrl),
                  CommodityPositionStep(ctrl),
                  CommodityReviewStep(ctrl),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
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
                  child: Text(ctrl.currentStep >= 4 ? 'Confirm & Save' : 'Continue'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
