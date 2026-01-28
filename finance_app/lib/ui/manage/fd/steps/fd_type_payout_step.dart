import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/fixed_deposit_model.dart';
import 'package:vittara_fin_os/ui/manage/fd/fd_wizard_controller.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';

class FDTypePayoutStep extends StatelessWidget {
  const FDTypePayoutStep({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<FDWizardController>(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // FD Type Selection
          Text(
            'FD Type',
            style: AppStyles.titleStyle(context),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose how your FD should work',
            style: TextStyle(color: AppStyles.getSecondaryTextColor(context)),
          ),
          const SizedBox(height: 20),
          _buildTypeCard(
            context: context,
            title: 'Cumulative',
            description:
                'Interest is compounded and reinvested. Receive lump sum at maturity.',
            isSelected: controller.isCumulative,
            onTap: () => controller.updateFDType(true),
          ),
          const SizedBox(height: 12),
          _buildTypeCard(
            context: context,
            title: 'Non-Cumulative',
            description: 'Receive interest payouts at regular intervals',
            isSelected: !controller.isCumulative,
            onTap: () => controller.updateFDType(false),
          ),
          // Payout Frequency (only for non-cumulative FDs)
          if (!controller.isCumulative) ...[
            const SizedBox(height: 40),
            Text(
              'Payout Frequency',
              style: AppStyles.titleStyle(context),
            ),
            const SizedBox(height: 8),
            Text(
              'How often should you receive interest payouts?',
              style: TextStyle(color: AppStyles.getSecondaryTextColor(context)),
            ),
            const SizedBox(height: 20),
            _buildPayoutOption(
              context: context,
              label: 'Monthly',
              description: 'Every month',
              isSelected: controller.payoutFrequency == FDPayoutFrequency.monthly,
              onTap: () => controller.updatePayoutFrequency(FDPayoutFrequency.monthly),
            ),
            const SizedBox(height: 10),
            _buildPayoutOption(
              context: context,
              label: 'Quarterly',
              description: 'Every 3 months',
              isSelected: controller.payoutFrequency == FDPayoutFrequency.quarterly,
              onTap: () => controller
                  .updatePayoutFrequency(FDPayoutFrequency.quarterly),
            ),
            const SizedBox(height: 10),
            _buildPayoutOption(
              context: context,
              label: 'Semi-Annually',
              description: 'Every 6 months',
              isSelected:
                  controller.payoutFrequency == FDPayoutFrequency.semiAnnual,
              onTap: () =>
                  controller.updatePayoutFrequency(FDPayoutFrequency.semiAnnual),
            ),
            const SizedBox(height: 10),
            _buildPayoutOption(
              context: context,
              label: 'Annually',
              description: 'Every year',
              isSelected: controller.payoutFrequency == FDPayoutFrequency.annual,
              onTap: () =>
                  controller.updatePayoutFrequency(FDPayoutFrequency.annual),
            ),
            const SizedBox(height: 10),
            _buildPayoutOption(
              context: context,
              label: 'At Maturity',
              description: 'Single payout at maturity',
              isSelected: controller.payoutFrequency == FDPayoutFrequency.atMaturity,
              onTap: () =>
                  controller.updatePayoutFrequency(FDPayoutFrequency.atMaturity),
            ),
          ] else
            Container(
              margin: const EdgeInsets.only(top: 40),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppStyles.getPrimaryColor(context).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    CupertinoIcons.info,
                    size: 16,
                    color: AppStyles.getPrimaryColor(context),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Cumulative FDs compound and pay at maturity',
                      style: TextStyle(
                        color: AppStyles.getPrimaryColor(context),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTypeCard({
    required BuildContext context,
    required String title,
    required String description,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
                    title,
                    style: TextStyle(
                      color: AppStyles.getTextColor(context),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
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
  }

  Widget _buildPayoutOption({
    required BuildContext context,
    required String label,
    required String description,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppStyles.getCardColor(context),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? AppStyles.getPrimaryColor(context)
                : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? AppStyles.getPrimaryColor(context)
                      : AppStyles.getSecondaryTextColor(context),
                  width: 1.5,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppStyles.getPrimaryColor(context),
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: AppStyles.getTextColor(context),
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    description,
                    style: TextStyle(
                      color: AppStyles.getSecondaryTextColor(context),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
