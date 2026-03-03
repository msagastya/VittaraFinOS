import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/ui/manage/fd/fd_wizard_controller.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';

class TenureStep extends StatefulWidget {
  const TenureStep({super.key});

  @override
  State<TenureStep> createState() => _TenureStepState();
}

class _TenureStepState extends State<TenureStep> {
  late TextEditingController _yearsController;
  late TextEditingController _monthsController;
  late TextEditingController _daysController;

  @override
  void initState() {
    super.initState();
    final controller = Provider.of<FDWizardController>(context, listen: false);
    _yearsController = TextEditingController(
      text: controller.tenureYearsInput > 0
          ? controller.tenureYearsInput.toString()
          : '',
    );
    _monthsController = TextEditingController(
      text: controller.tenureMonthsInput > 0
          ? controller.tenureMonthsInput.toString()
          : '',
    );
    _daysController = TextEditingController(
      text: controller.tenureDaysInput > 0
          ? controller.tenureDaysInput.toString()
          : '',
    );
  }

  @override
  void dispose() {
    _yearsController.dispose();
    _monthsController.dispose();
    _daysController.dispose();
    super.dispose();
  }

  void _updateTenure() {
    final controller = Provider.of<FDWizardController>(context, listen: false);
    final years = int.tryParse(_yearsController.text) ?? 0;
    final months = int.tryParse(_monthsController.text) ?? 0;
    final days = int.tryParse(_daysController.text) ?? 0;

    if (years > 0 || months > 0 || days > 0) {
      controller.updateTenureWithMultipleUnits(years, months, days);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(Spacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tenure Duration',
            style: AppStyles.titleStyle(context),
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            'Enter tenure as Years, Months, and/or Days. All fields are optional, but at least one must be filled.',
            style: TextStyle(color: AppStyles.getSecondaryTextColor(context)),
          ),
          const SizedBox(height: 30),
          Text(
            'Tenure',
            style: TextStyle(
              color: AppStyles.getTextColor(context),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: Spacing.md),
          // Three input fields in a row
          Row(
            children: [
              // Years field
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Years',
                      style: TextStyle(
                        fontSize: TypeScale.footnote,
                        color: AppStyles.getSecondaryTextColor(context),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    CupertinoTextField(
                      controller: _yearsController,
                      keyboardType: TextInputType.number,
                      placeholder: '0',
                      padding: const EdgeInsets.all(Spacing.md),
                      decoration: BoxDecoration(
                        color: AppStyles.getCardColor(context),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      style: TextStyle(color: AppStyles.getTextColor(context)),
                      onChanged: (_) => _updateTenure(),
                    ),
                  ],
                ),
              ),
              SizedBox(width: Spacing.md),
              // Months field
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Months',
                      style: TextStyle(
                        fontSize: TypeScale.footnote,
                        color: AppStyles.getSecondaryTextColor(context),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    CupertinoTextField(
                      controller: _monthsController,
                      keyboardType: TextInputType.number,
                      placeholder: '0',
                      padding: const EdgeInsets.all(Spacing.md),
                      decoration: BoxDecoration(
                        color: AppStyles.getCardColor(context),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      style: TextStyle(color: AppStyles.getTextColor(context)),
                      onChanged: (_) => _updateTenure(),
                    ),
                  ],
                ),
              ),
              SizedBox(width: Spacing.md),
              // Days field
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Days',
                      style: TextStyle(
                        fontSize: TypeScale.footnote,
                        color: AppStyles.getSecondaryTextColor(context),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    CupertinoTextField(
                      controller: _daysController,
                      keyboardType: TextInputType.number,
                      placeholder: '0',
                      padding: const EdgeInsets.all(Spacing.md),
                      decoration: BoxDecoration(
                        color: AppStyles.getCardColor(context),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      style: TextStyle(color: AppStyles.getTextColor(context)),
                      onChanged: (_) => _updateTenure(),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
          Consumer<FDWizardController>(
            builder: (context, controller, child) {
              final maturityDate = controller.maturityDate;
              final years = controller.tenureYearsInput;
              final months = controller.tenureMonthsInput;
              final days = controller.tenureDaysInput;
              final totalMonths = controller.tenureMonths;

              // Build duration breakdown string
              List<String> parts = [];
              if (years > 0) parts.add('$years year${years > 1 ? 's' : ''}');
              if (months > 0) {
                parts.add('$months month${months > 1 ? 's' : ''}');
              }
              if (days > 0) parts.add('$days day${days > 1 ? 's' : ''}');

              String durationText =
                  parts.isNotEmpty ? parts.join(', ') : 'No tenure entered';

              return Container(
                padding: const EdgeInsets.all(Spacing.lg),
                decoration: BoxDecoration(
                  color:
                      AppStyles.getBackground(context).withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppStyles.getPrimaryColor(context)
                        .withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Maturity Details',
                      style: TextStyle(
                        color: AppStyles.getSecondaryTextColor(context),
                        fontSize: TypeScale.footnote,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: Spacing.md),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Duration',
                          style: TextStyle(
                              color: AppStyles.getSecondaryTextColor(context)),
                        ),
                        Text(
                          durationText,
                          style: TextStyle(
                            color: AppStyles.getTextColor(context),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Spacing.sm),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total Months',
                          style: TextStyle(
                              color: AppStyles.getSecondaryTextColor(context)),
                        ),
                        Text(
                          '$totalMonths month${totalMonths > 1 ? 's' : ''}',
                          style: TextStyle(
                            color: AppStyles.getPrimaryColor(context),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Spacing.md),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Maturity Date',
                          style: TextStyle(
                              color: AppStyles.getSecondaryTextColor(context)),
                        ),
                        Text(
                          '${maturityDate.day} ${_monthName(maturityDate.month)} ${maturityDate.year}',
                          style: TextStyle(
                            color: AppStyles.getTextColor(context),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  String _monthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return months[month - 1];
  }
}
