import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/models/digital_gold_model.dart';
import 'package:vittara_fin_os/ui/manage/digital_gold/digital_gold_wizard_controller.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';

class GoldCompanyStep extends StatelessWidget {
  const GoldCompanyStep({super.key});

  static final List<DigitalGoldCompany> goldCompanies = [
    DigitalGoldCompany(id: 'paytm', name: 'Paytm Gold'),
    DigitalGoldCompany(id: 'safegold', name: 'SafeGold'),
    DigitalGoldCompany(id: 'cred', name: 'Cred Gold'),
    DigitalGoldCompany(id: 'googlepay', name: 'Google Pay Gold'),
    DigitalGoldCompany(id: 'flipkart', name: 'Flipkart Gold'),
    DigitalGoldCompany(id: 'ibjawards', name: 'IBJa Awards'),
    DigitalGoldCompany(id: 'muila', name: 'Muila'),
    DigitalGoldCompany(id: 'bajajallianz', name: 'Bajaj Allianz Gold'),
  ];

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<DigitalGoldWizardController>(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Gold Provider',
            style: AppStyles.titleStyle(context),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose a digital gold provider to invest with',
            style: TextStyle(color: AppStyles.getSecondaryTextColor(context)),
          ),
          const SizedBox(height: 30),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: goldCompanies.length,
            itemBuilder: (context, index) {
              final company = goldCompanies[index];
              final isSelected = controller.selectedCompany?.id == company.id;

              return GestureDetector(
                onTap: () {
                  controller.selectCompany(company);
                  // Auto-proceed to next step
                  Future.delayed(const Duration(milliseconds: 300), () {
                    if (context.mounted) {
                      controller.nextPage();
                    }
                  });
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? SemanticColors.investments.withOpacity(0.1)
                        : AppStyles.getCardColor(context),
                    border: isSelected
                        ? Border.all(color: SemanticColors.investments, width: 2)
                        : Border.all(
                            color: AppStyles.getSecondaryTextColor(context)
                                .withOpacity(0.1),
                          ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFB81C).withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          CupertinoIcons.star_circle_fill,
                          color: Color(0xFFFFB81C),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              company.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Digital Gold Provider',
                              style: TextStyle(
                                color: AppStyles.getSecondaryTextColor(context),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        const Icon(
                          CupertinoIcons.check_mark_circled_solid,
                          color: SemanticColors.investments,
                          size: 24,
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
