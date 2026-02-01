import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/nps_model.dart';
import 'package:vittara_fin_os/ui/manage/nps/nps_wizard_controller.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';

class NPSPlanningStep extends StatelessWidget {
  const NPSPlanningStep({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Provider.of<NPSWizardController>(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Retirement Planning', style: AppStyles.titleStyle(context)),
          const SizedBox(height: 8),
          Text('Plan your NPS withdrawal strategy',
              style: TextStyle(color: AppStyles.getSecondaryTextColor(context))),
          const SizedBox(height: 30),
          Text('Planned Retirement Date',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () async {
              final date = await showCupertinoModalPopup<DateTime>(
                context: context,
                builder: (ctx) => Container(
                  height: 300,
                  color: AppStyles.getBackground(context),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          CupertinoButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Cancel')),
                          CupertinoButton(
                              onPressed: () => Navigator.pop(ctx, ctrl.plannedRetirementDate),
                              child: const Text('Done')),
                        ],
                      ),
                      Expanded(
                        child: CupertinoDatePicker(
                          mode: CupertinoDatePickerMode.date,
                          initialDateTime: ctrl.plannedRetirementDate ?? DateTime.now().add(const Duration(days: 365 * 30)),
                          minimumDate: DateTime.now().add(const Duration(days: 365)),
                          onDateTimeChanged: (d) => ctrl.updateRetirementDate(d),
                        ),
                      ),
                    ],
                  ),
                ),
              );
              if (date != null) ctrl.updateRetirementDate(date);
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppStyles.getCardColor(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    ctrl.plannedRetirementDate != null
                        ? '${ctrl.plannedRetirementDate!.day}/${ctrl.plannedRetirementDate!.month}/${ctrl.plannedRetirementDate!.year}'
                        : 'Not set',
                    style: TextStyle(color: AppStyles.getTextColor(context)),
                  ),
                  Icon(CupertinoIcons.calendar,
                      color: AppStyles.getSecondaryTextColor(context)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('Withdrawal Strategy',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 12),
          Column(
            children: NPSWithdrawalType.values.map((wtype) {
              final isSelected = ctrl.withdrawalType == wtype;
              final labels = {
                NPSWithdrawalType.immediate: 'Immediate Annuity',
                NPSWithdrawalType.staggered: 'Staggered Withdrawal',
                NPSWithdrawalType.none: 'No Withdrawal Planned',
              };
              final desc = {
                NPSWithdrawalType.immediate: 'Monthly pension for life',
                NPSWithdrawalType.staggered: 'Partial withdrawal + pension',
                NPSWithdrawalType.none: 'Continue investment',
              };
              return GestureDetector(
                onTap: () => ctrl.updateWithdrawalType(wtype),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF9B59B6).withOpacity(0.1)
                        : AppStyles.getCardColor(context),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF9B59B6)
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
                                ? const Color(0xFF9B59B6)
                                : Colors.grey,
                          ),
                        ),
                        child: isSelected
                            ? Center(
                                child: Container(
                                  width: 10,
                                  height: 10,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF9B59B6),
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
                            Text(labels[wtype] ?? '',
                                style:
                                    const TextStyle(fontWeight: FontWeight.bold)),
                            Text(desc[wtype] ?? '',
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
        ],
      ),
    );
  }
}
