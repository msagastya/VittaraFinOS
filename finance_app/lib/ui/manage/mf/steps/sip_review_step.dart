import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/ui/manage/mf/sip_wizard_controller.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';

class SIPReviewStep extends StatelessWidget {
  const SIPReviewStep({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<SIPWizardController>(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(Spacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: SemanticColors.investments.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(
                  CupertinoIcons.graph_circle,
                  size: 40,
                  color: SemanticColors.investments,
                ),
              ),
            ),
          ),
          const SizedBox(height: Spacing.lg),
          Center(
            child: Text(
              'SIP Configuration',
              style: AppStyles.titleStyle(context)
                  .copyWith(fontSize: TypeScale.title2),
            ),
          ),
          const SizedBox(height: Spacing.xxxl),
          _buildRow(context, 'SIP Amount',
              '₹${controller.sipAmount.toStringAsFixed(2)}/month'),
          _buildRow(context, 'Frequency', _getFrequencyLabel(controller)),
          _buildRow(context, 'Deduction Account',
              controller.deductionAccount?.name ?? 'Not selected'),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(),
          ),
          if (controller.stepUpEnabled) ...[
            _buildRow(
              context,
              'Step Up',
              '${controller.stepUpPercent.toStringAsFixed(1)}% every ${controller.stepUpDuration} ${controller.stepUpTenure == StepUpTenure.yearly ? 'year(s)' : 'month(s)'}',
            ),
            const SizedBox(height: Spacing.sm),
            Container(
              padding: const EdgeInsets.all(Spacing.md),
              decoration: BoxDecoration(
                color: CupertinoColors.systemGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Step Up Projection:',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppStyles.getTextColor(context),
                      fontSize: TypeScale.footnote,
                    ),
                  ),
                  const SizedBox(height: Spacing.sm),
                  _buildProjectionRow('Year 1', controller.sipAmount),
                  _buildProjectionRow(
                      'Year 2',
                      controller.sipAmount *
                          (1 + controller.stepUpPercent / 100)),
                  _buildProjectionRow(
                      'Year 3',
                      controller.sipAmount *
                          ((1 + controller.stepUpPercent / 100) *
                              (1 + controller.stepUpPercent / 100))),
                ],
              ),
            ),
          ] else ...[
            _buildRow(context, 'Step Up', 'Disabled'),
          ],
        ],
      ),
    );
  }

  Widget _buildRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppStyles.getSecondaryTextColor(context),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppStyles.getTextColor(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectionRow(String label, double value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: TypeScale.caption),
          ),
          Text(
            '₹${value.toStringAsFixed(2)}/month',
            style: const TextStyle(
              fontSize: TypeScale.caption,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _getFrequencyLabel(SIPWizardController controller) {
    switch (controller.frequency) {
      case SIPFrequency.daily:
        return 'Daily';
      case SIPFrequency.weekly:
        final days = [
          'Monday',
          'Tuesday',
          'Wednesday',
          'Thursday',
          'Friday',
          'Saturday',
          'Sunday'
        ];
        return 'Weekly (${days[controller.selectedWeekday ?? 0]})';
      case SIPFrequency.monthly:
        return 'Monthly (${controller.selectedMonthDay}${_getDaySuffix(controller.selectedMonthDay)})';
    }
  }

  String _getDaySuffix(int day) {
    if (day >= 11 && day <= 13) return 'th';
    switch (day % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }
}
