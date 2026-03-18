import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/ui/manage/fd/fd_wizard_controller.dart';
import 'package:vittara_fin_os/utils/date_formatter.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/widgets/app_date_picker.dart';

class InvestmentDateStep extends StatelessWidget {
  const InvestmentDateStep({super.key});

  Future<void> _showDatePicker(
      BuildContext context, FDWizardController controller) async {
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
    final controller = Provider.of<FDWizardController>(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(Spacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'When did you invest?',
            style: AppStyles.titleStyle(context),
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            'Select the date when you started this FD',
            style: TextStyle(color: AppStyles.getSecondaryTextColor(context)),
          ),
          const SizedBox(height: 30),
          GestureDetector(
            onTap: () => _showDatePicker(context, controller),
            child: Container(
              padding: const EdgeInsets.all(Spacing.lg),
              decoration: BoxDecoration(
                color: AppStyles.getCardColor(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color:
                      AppStyles.getPrimaryColor(context).withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Investment Date',
                        style: TextStyle(
                          color: AppStyles.getSecondaryTextColor(context),
                          fontSize: TypeScale.footnote,
                        ),
                      ),
                      const SizedBox(height: Spacing.sm),
                      Text(
                        '${controller.investmentDate.day} ${_monthName(controller.investmentDate.month)} ${controller.investmentDate.year}',
                        style: TextStyle(
                          color: AppStyles.getTextColor(context),
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                  Icon(
                    CupertinoIcons.calendar,
                    color: AppStyles.getPrimaryColor(context),
                    size: 24,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 30),
          Container(
            padding: const EdgeInsets.all(Spacing.md),
            decoration: BoxDecoration(
              color: AppStyles.getPrimaryColor(context).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  CupertinoIcons.info,
                  size: 16,
                  color: AppStyles.getPrimaryColor(context),
                ),
                const SizedBox(width: Spacing.sm),
                Expanded(
                  child: Text(
                    'Use today\'s date if you just created this FD',
                    style: TextStyle(
                      color: AppStyles.getPrimaryColor(context),
                      fontSize: TypeScale.footnote,
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

  String _monthName(int month) {
    return DateFormatter.getMonthName(month);
  }
}
