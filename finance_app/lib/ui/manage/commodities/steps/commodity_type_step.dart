import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:vittara_fin_os/logic/commodities_model.dart';
import 'package:vittara_fin_os/ui/manage/commodities/commodities_wizard_controller.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';

class CommodityTypeStep extends StatelessWidget {
  final CommoditiesWizardController ctrl;

  const CommodityTypeStep(this.ctrl);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Select Commodity Type', style: AppStyles.titleStyle(context)),
          const SizedBox(height: 30),
          Column(
            children: CommodityType.values.map((type) {
              final isSelected = ctrl.selectedType == type;
              final details = {
                CommodityType.gold: ('Gold', 'Precious Metal'),
                CommodityType.silver: ('Silver', 'Precious Metal'),
                CommodityType.oil: ('Crude Oil', 'Energy'),
                CommodityType.gas: ('Natural Gas', 'Energy'),
                CommodityType.wheat: ('Wheat', 'Agricultural'),
                CommodityType.cotton: ('Cotton', 'Agricultural'),
              };
              final (title, desc) = details[type]!;

              return GestureDetector(
                onTap: () => ctrl.selectType(type),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF8B4513).withOpacity(0.1)
                        : AppStyles.getCardColor(context),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF8B4513)
                          : Colors.grey.withOpacity(0.2),
                    ),
                    borderRadius: BorderRadius.circular(12),
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
                                ? const Color(0xFF8B4513)
                                : Colors.grey,
                          ),
                        ),
                        child: isSelected
                            ? Center(
                                child: Container(
                                  width: 10,
                                  height: 10,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF8B4513),
                                    shape: BoxShape.circle,
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
                            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text(desc,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppStyles.getSecondaryTextColor(context))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          Text('Custom Commodity Name', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 12),
          CupertinoTextField(
            placeholder: 'e.g., Gold ETF, Oil Futures',
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppStyles.getCardColor(context),
              borderRadius: BorderRadius.circular(12),
            ),
            onChanged: (v) => ctrl.updateCommodityName(v),
          ),
        ],
      ),
    );
  }
}
