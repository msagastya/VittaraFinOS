import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:vittara_fin_os/logic/fo_model.dart';
import 'package:vittara_fin_os/ui/manage/fo/fo_wizard_controller.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';

class FOTypeStep extends StatelessWidget {
  final FOWizardController ctrl;

  const FOTypeStep(this.ctrl, {super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Select F&O Type', style: AppStyles.titleStyle(context)),
          const SizedBox(height: 30),
          Column(
            children: FOType.values.map((type) {
              final isSelected = ctrl.selectedType == type;
              final details = {
                FOType.futures: (
                  'Futures',
                  'Obligation to buy/sell at fixed price'
                ),
                FOType.callOption: (
                  'Call Option',
                  'Right to buy at strike price'
                ),
                FOType.putOption: (
                  'Put Option',
                  'Right to sell at strike price'
                ),
              };
              final (title, desc) = details[type]!;

              return GestureDetector(
                onTap: () => ctrl.selectType(type),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF1ABC9C).withValues(alpha: 0.1)
                        : AppStyles.getCardColor(context),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF1ABC9C)
                          : Colors.grey.withValues(alpha: 0.2),
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
                                ? const Color(0xFF1ABC9C)
                                : Colors.grey,
                          ),
                        ),
                        child: isSelected
                            ? Center(
                                child: Container(
                                  width: 10,
                                  height: 10,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF1ABC9C),
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
                            Text(title,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            Text(desc,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppStyles.getSecondaryTextColor(
                                        context))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          Text('Symbol',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 12),
          CupertinoTextField(
            placeholder: 'e.g., NIFTY, BANKNIFTY, GOLD',
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppStyles.getCardColor(context),
              borderRadius: BorderRadius.circular(12),
            ),
            onChanged: (v) => ctrl.updateSymbol(v),
          ),
          const SizedBox(height: 20),
          Text('Contract Name',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 12),
          CupertinoTextField(
            placeholder: 'e.g., NIFTY 50 Index Futures',
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppStyles.getCardColor(context),
              borderRadius: BorderRadius.circular(12),
            ),
            onChanged: (v) => ctrl.updateContractName(v),
          ),
        ],
      ),
    );
  }
}
