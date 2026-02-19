import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/fixed_deposit_model.dart';
import 'package:vittara_fin_os/ui/manage/fd/fd_wizard_controller.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';

class CompoundingStep extends StatelessWidget {
  const CompoundingStep({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<FDWizardController>(context);

    final options = [
      {
        'value': FDCompoundingFrequency.annual,
        'label': 'Annually',
        'description': 'Interest calculated yearly',
      },
      {
        'value': FDCompoundingFrequency.semiAnnual,
        'label': 'Semi-Annually',
        'description': 'Interest calculated twice a year',
      },
      {
        'value': FDCompoundingFrequency.quarterly,
        'label': 'Quarterly',
        'description': 'Interest calculated every 3 months',
      },
      {
        'value': FDCompoundingFrequency.monthly,
        'label': 'Monthly',
        'description': 'Interest calculated every month',
      },
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Compounding Frequency',
            style: AppStyles.titleStyle(context),
          ),
          const SizedBox(height: 8),
          Text(
            'How often should interest be compounded?',
            style: TextStyle(color: AppStyles.getSecondaryTextColor(context)),
          ),
          const SizedBox(height: 30),
          Column(
            children: options.map((option) {
              final isSelected =
                  controller.compoundingFrequency == option['value'];

              return GestureDetector(
                onTap: () => controller.updateCompoundingFrequency(
                    option['value'] as FDCompoundingFrequency),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
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
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              option['label'] as String,
                              style: TextStyle(
                                color: AppStyles.getTextColor(context),
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              option['description'] as String,
                              style: TextStyle(
                                color: AppStyles.getSecondaryTextColor(context),
                                fontSize: 13,
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
