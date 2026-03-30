import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/ui/manage/digital_gold/digital_gold_wizard_controller.dart';
import 'package:vittara_fin_os/utils/date_formatter.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/widgets/app_date_picker.dart';

class GoldInvestmentDateStep extends StatelessWidget {
  const GoldInvestmentDateStep({super.key});

  Future<void> _showDatePicker(
      BuildContext context, DigitalGoldWizardController controller) async {
    final picked = await showAppDatePicker(
      context: context,
      initialDate: controller.investmentDate,
      maximumDate: DateTime.now(),
    );
    if (picked != null) {
      controller.updateInvestmentDate(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<DigitalGoldWizardController>(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(Spacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Investment Date',
            style: AppStyles.titleStyle(context),
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            'Select the date when you invested in this gold',
            style: TextStyle(color: AppStyles.getSecondaryTextColor(context)),
          ),
          const SizedBox(height: 30),
          Text(
            'Date of Investment',
            style: TextStyle(
              color: AppStyles.getTextColor(context),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: Spacing.sm),
          GestureDetector(
            onTap: () => _showDatePicker(context, controller),
            child: Container(
              padding: const EdgeInsets.all(Spacing.lg),
              decoration: BoxDecoration(
                color: AppStyles.getCardColor(context),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDate(controller.investmentDate),
                    style: TextStyle(color: AppStyles.getTextColor(context)),
                  ),
                  Icon(
                    CupertinoIcons.calendar,
                    color: AppStyles.getSecondaryTextColor(context),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 30),
          // Summary
          Container(
            padding: const EdgeInsets.all(Spacing.lg),
            decoration: BoxDecoration(
              color: const Color(0xFFFFB81C).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFFFB81C).withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Investment Summary',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppStyles.getTextColor(context),
                  ),
                ),
                const SizedBox(height: Spacing.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Provider',
                      style: TextStyle(
                        color: AppStyles.getSecondaryTextColor(context),
                        fontSize: TypeScale.footnote,
                      ),
                    ),
                    Text(
                      controller.selectedCompany?.name ?? '-',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: TypeScale.footnote,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Spacing.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Actual Gold Cost',
                      style: TextStyle(
                        color: AppStyles.getSecondaryTextColor(context),
                        fontSize: TypeScale.footnote,
                      ),
                    ),
                    Text(
                      '₹${controller.actualAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: TypeScale.footnote,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Spacing.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'GST (${controller.gstRate}%)',
                      style: TextStyle(
                        color: AppStyles.getSecondaryTextColor(context),
                        fontSize: TypeScale.footnote,
                      ),
                    ),
                    Text(
                      '₹${controller.gstAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: TypeScale.footnote,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total Invested',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: TypeScale.footnote,
                      ),
                    ),
                    Text(
                      '₹${controller.investedAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: TypeScale.body,
                        color: Color(0xFFFFB81C),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: Spacing.xl),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) => DateFormatter.format(date);
}
