import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/recurring_deposit_model.dart';
import 'package:vittara_fin_os/ui/manage/rd/rd_wizard_controller.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';

class FrequencyStep extends StatelessWidget {
  const FrequencyStep({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<RDWizardController>(context);

    final options = [
      {
        'value': RDPaymentFrequency.monthly,
        'label': 'Monthly',
        'description': 'Installment every month',
      },
      {
        'value': RDPaymentFrequency.quarterly,
        'label': 'Quarterly',
        'description': 'Installment every 3 months',
      },
      {
        'value': RDPaymentFrequency.semiAnnual,
        'label': 'Semi-Annually',
        'description': 'Installment every 6 months',
      },
      {
        'value': RDPaymentFrequency.annual,
        'label': 'Annually',
        'description': 'Installment every year',
      },
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(Spacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Payment Frequency',
            style: AppStyles.titleStyle(context),
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            'How often should you deposit installments?',
            style: TextStyle(color: AppStyles.getSecondaryTextColor(context)),
          ),
          const SizedBox(height: 30),
          Column(
            children: options.map((option) {
              final isSelected = controller.paymentFrequency == option['value'];

              return GestureDetector(
                onTap: () => controller.updatePaymentFrequency(
                    option['value'] as RDPaymentFrequency),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(Spacing.lg),
                  decoration: BoxDecoration(
                    color: AppStyles.getCardColor(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? AppStyles.getPrimaryColor(context)
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? AppStyles.getPrimaryColor(context)
                                : AppStyles.getSecondaryTextColor(context),
                            width: 2,
                          ),
                        ),
                        child: isSelected
                            ? Center(
                                child: Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppStyles.getPrimaryColor(context),
                                  ),
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: Spacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              option['label'] as String,
                              style: TextStyle(
                                color: AppStyles.getTextColor(context),
                                fontWeight: FontWeight.bold,
                                fontSize: TypeScale.headline,
                              ),
                            ),
                            const SizedBox(height: Spacing.xs),
                            Text(
                              option['description'] as String,
                              style: TextStyle(
                                color: AppStyles.getSecondaryTextColor(context),
                                fontSize: TypeScale.subhead,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
