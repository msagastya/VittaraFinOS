import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/ui/manage/mf/mf_wizard_controller.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';

class MFTypeSelectionStep extends StatelessWidget {
  const MFTypeSelectionStep({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<MFWizardController>(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Investment Type',
                style: AppStyles.titleStyle(context),
              ),
              const SizedBox(height: 8),
              Text(
                'Is this your first time adding this mutual fund?',
                style: TextStyle(
                  color: AppStyles.getSecondaryTextColor(context),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Existing MF Option
                GestureDetector(
                  onTap: () {
                    controller.selectMFType(MFType.existing);
                    Future.delayed(const Duration(milliseconds: 300), () {
                      controller.nextPage();
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: controller.selectedMFType == MFType.existing
                          ? SemanticColors.investments.withValues(alpha: 0.1)
                          : AppStyles.getCardColor(context),
                      border: controller.selectedMFType == MFType.existing
                          ? Border.all(
                              color: SemanticColors.investments, width: 2)
                          : Border.all(
                              color: Colors.grey.withValues(alpha: 0.3),
                              width: 1,
                            ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        if (controller.selectedMFType != MFType.existing)
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: SemanticColors.investments
                                .withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Icon(
                              CupertinoIcons.plus_circle,
                              size: 28,
                              color: SemanticColors.investments,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Existing MF',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: AppStyles.getTextColor(context),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Adding more units to existing investment',
                                style: TextStyle(
                                  color:
                                      AppStyles.getSecondaryTextColor(context),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (controller.selectedMFType == MFType.existing)
                          const Icon(
                            CupertinoIcons.check_mark_circled_solid,
                            color: SemanticColors.investments,
                            size: 24,
                          ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // New MF Option
                GestureDetector(
                  onTap: () {
                    controller.selectMFType(MFType.newMF);
                    Future.delayed(const Duration(milliseconds: 300), () {
                      controller.nextPage();
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: controller.selectedMFType == MFType.newMF
                          ? SemanticColors.investments.withValues(alpha: 0.1)
                          : AppStyles.getCardColor(context),
                      border: controller.selectedMFType == MFType.newMF
                          ? Border.all(
                              color: SemanticColors.investments, width: 2)
                          : Border.all(
                              color: Colors.grey.withValues(alpha: 0.3),
                              width: 1,
                            ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        if (controller.selectedMFType != MFType.newMF)
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Icon(
                              CupertinoIcons.star_circle,
                              size: 28,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'New MF',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: AppStyles.getTextColor(context),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Starting a new mutual fund investment',
                                style: TextStyle(
                                  color:
                                      AppStyles.getSecondaryTextColor(context),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (controller.selectedMFType == MFType.newMF)
                          const Icon(
                            CupertinoIcons.check_mark_circled_solid,
                            color: SemanticColors.investments,
                            size: 24,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
