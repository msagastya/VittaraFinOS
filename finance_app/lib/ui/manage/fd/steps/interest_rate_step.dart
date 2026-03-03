import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/ui/manage/fd/fd_wizard_controller.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';

class InterestRateStep extends StatefulWidget {
  const InterestRateStep({super.key});

  @override
  State<InterestRateStep> createState() => _InterestRateStepState();
}

class _InterestRateStepState extends State<InterestRateStep> {
  late TextEditingController _rateController;

  @override
  void initState() {
    super.initState();
    final controller = Provider.of<FDWizardController>(context, listen: false);
    _rateController = TextEditingController(
      text:
          controller.interestRate > 0 ? controller.interestRate.toString() : '',
    );
  }

  @override
  void dispose() {
    _rateController.dispose();
    super.dispose();
  }

  void _updateRate() {
    final controller = Provider.of<FDWizardController>(context, listen: false);
    final rate = double.tryParse(_rateController.text) ?? 0;
    controller.updateInterestRate(rate);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(Spacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Interest Rate',
            style: AppStyles.titleStyle(context),
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            'Enter the annual interest rate in percentage',
            style: TextStyle(color: AppStyles.getSecondaryTextColor(context)),
          ),
          const SizedBox(height: 30),
          Text(
            'Annual Interest Rate',
            style: TextStyle(
              color: AppStyles.getTextColor(context),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: Spacing.md),
          CupertinoTextField(
            controller: _rateController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            placeholder: '0.00',
            padding: const EdgeInsets.all(Spacing.lg),
            decoration: BoxDecoration(
              color: AppStyles.getCardColor(context),
              borderRadius: BorderRadius.circular(12),
            ),
            suffix: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                '%',
                style: TextStyle(color: AppStyles.getTextColor(context)),
              ),
            ),
            style: TextStyle(color: AppStyles.getTextColor(context)),
            onChanged: (_) => _updateRate(),
          ),
          const SizedBox(height: 30),
          Consumer<FDWizardController>(
            builder: (context, controller, child) {
              if (controller.interestRate <= 0 || controller.principal <= 0) {
                return const SizedBox.shrink();
              }

              final yearlyInterest =
                  (controller.principal * controller.interestRate) / 100;

              return Container(
                padding: const EdgeInsets.all(Spacing.lg),
                decoration: BoxDecoration(
                  color:
                      AppStyles.getBackground(context).withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppStyles.getPrimaryColor(context)
                        .withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Estimated Interest (per year)',
                      style: TextStyle(
                        color: AppStyles.getSecondaryTextColor(context),
                        fontSize: TypeScale.footnote,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: Spacing.sm),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Yearly Interest',
                          style: TextStyle(
                              color: AppStyles.getSecondaryTextColor(context)),
                        ),
                        Text(
                          '₹${yearlyInterest.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: AppStyles.getTextColor(context),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
