import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/ui/manage/rd/rd_wizard_controller.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';

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
    final controller = Provider.of<RDWizardController>(context, listen: false);
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
    final controller = Provider.of<RDWizardController>(context, listen: false);
    final rate = double.tryParse(_rateController.text) ?? 0;
    controller.updateInterestRate(rate);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Interest Rate',
            style: AppStyles.titleStyle(context),
          ),
          const SizedBox(height: 8),
          Text(
            'Annual interest rate on your RD',
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
          const SizedBox(height: 12),
          CupertinoTextField(
            controller: _rateController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            placeholder: '0.00',
            padding: const EdgeInsets.all(16),
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
          Consumer<RDWizardController>(
            builder: (context, controller, child) {
              if (controller.interestRate <= 0 ||
                  controller.monthlyAmount <= 0) {
                return const SizedBox.shrink();
              }

              final estimatedMaturity =
                  controller.monthlyAmount * controller.totalInstallments +
                      controller.totalInterestAtMaturity;

              return Container(
                padding: const EdgeInsets.all(16),
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
                      'Estimated Returns',
                      style: TextStyle(
                        color: AppStyles.getSecondaryTextColor(context),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Interest Earned',
                          style: TextStyle(
                              color: AppStyles.getSecondaryTextColor(context)),
                        ),
                        Text(
                          '₹${controller.totalInterestAtMaturity.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: CupertinoColors.systemGreen,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Maturity Value',
                          style: TextStyle(
                            color: AppStyles.getTextColor(context),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '₹${estimatedMaturity.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: AppStyles.getPrimaryColor(context),
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
