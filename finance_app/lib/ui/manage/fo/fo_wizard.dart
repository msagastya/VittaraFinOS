import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/investment_model.dart';
import 'package:vittara_fin_os/logic/investments_controller.dart';
import 'package:vittara_fin_os/logic/fo_model.dart';
import 'package:vittara_fin_os/ui/manage/fo/fo_wizard_controller.dart';
import 'package:vittara_fin_os/ui/manage/fo/steps/fo_type_step.dart';
import 'package:vittara_fin_os/ui/manage/fo/steps/fo_contract_details_step.dart';
import 'package:vittara_fin_os/ui/manage/fo/steps/fo_position_details_step.dart';
import 'package:vittara_fin_os/ui/manage/fo/steps/fo_greeks_step.dart';
import 'package:vittara_fin_os/ui/manage/fo/steps/fo_risk_analysis_step.dart';
import 'package:vittara_fin_os/ui/manage/fo/steps/fo_review_step.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/widgets/toast_notification.dart';

class FOWizard extends StatelessWidget {
  const FOWizard({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => FOWizardController(),
      child: const _FOWizardContent(),
    );
  }
}

class _FOWizardContent extends StatefulWidget {
  const _FOWizardContent();

  @override
  State<_FOWizardContent> createState() => _FOWizardContentState();
}

class _FOWizardContentState extends State<_FOWizardContent> {
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
    FOWizardController ctrl,
  ) async {
    final investmentsController =
        Provider.of<InvestmentsController>(context, listen: false);

    try {
      // Calculate Greeks if options and not already calculated
      OptionsGreeks? greeks = ctrl.greeks;
      if (ctrl.selectedType != FOType.futures && greeks == null) {
        final timeToExpiry =
            ctrl.expiryDate.difference(DateTime.now()).inDays / 365.0;
        if (timeToExpiry > 0) {
          greeks = FuturesOptions.calculateGreeks(
            spotPrice: ctrl.currentPrice ?? ctrl.entryPrice ?? 0,
            strikePrice: ctrl.strikePrice ?? 0,
            riskFreeRate: ctrl.riskFreeRate ?? 6.0,
            volatility: ctrl.volatility ?? 20.0,
            timeToExpiry: timeToExpiry,
            isCall: ctrl.selectedType == FOType.callOption,
          );
        }
      }

      final fo = FuturesOptions(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        symbol: ctrl.symbol,
        name: ctrl.contractName,
        type: ctrl.selectedType,
        entryPrice: ctrl.entryPrice!,
        currentPrice: ctrl.currentPrice!,
        quantity: ctrl.quantity!,
        strikePrice: ctrl.strikePrice,
        expiryDate: ctrl.expiryDate,
        entryDate: ctrl.entryDate,
        volatility: ctrl.volatility,
        riskFreeRate: ctrl.riskFreeRate,
        greeks: greeks,
        createdDate: DateTime.now(),
        notes: ctrl.notes,
      );

      final investment = Investment(
        id: fo.id,
        name: fo.name,
        type: InvestmentType.futuresOptions,
        amount: ctrl.totalCost,
        color: const Color(0xFF1ABC9C),
        metadata: {
          'foData': fo.toMap(),
          'currentValue': ctrl.currentValue,
        },
      );

      await investmentsController.addInvestment(investment);

      if (context.mounted) {
        toast.showSuccess('F&O investment added successfully!');
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
    final ctrl = Provider.of<FOWizardController>(context);
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
        middle: Text('Add F&O Investment',
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
                children: List.generate(6, (i) {
                  return Expanded(
                    child: Container(
                      height: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: i <= ctrl.currentStep
                            ? const Color(0xFF1ABC9C)
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
                  FOTypeStep(ctrl),
                  FOContractDetailsStep(ctrl),
                  FOPositionDetailsStep(ctrl),
                  FOGreeksStep(ctrl),
                  FORiskAnalysisStep(ctrl),
                  FOReviewStep(ctrl),
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
                          if (ctrl.currentStep < 5) {
                            ctrl.nextPage();
                          } else {
                            await _saveInvestment(context, ctrl);
                          }
                        }
                      : null,
                  child: Text(ctrl.currentStep >= 5 ? 'Confirm & Save' : 'Continue'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
