import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/ui/manage/mf/mf_wizard_controller.dart';
import 'package:vittara_fin_os/utils/date_formatter.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/widgets/app_date_picker.dart';

class MFTransactionDetailsStep extends StatefulWidget {
  const MFTransactionDetailsStep({super.key});

  @override
  State<MFTransactionDetailsStep> createState() =>
      _MFTransactionDetailsStepState();
}

class _MFTransactionDetailsStepState extends State<MFTransactionDetailsStep> {
  late TextEditingController _amountController;
  late TextEditingController _navController;

  @override
  void initState() {
    super.initState();
    final controller = Provider.of<MFWizardController>(context, listen: false);
    _amountController = TextEditingController(
      text: controller.investmentAmount > 0
          ? controller.investmentAmount.toString()
          : '',
    );
    _navController = TextEditingController(
      text: controller.averageNAV > 0
          ? controller.averageNAV.toStringAsFixed(2)
          : '',
    );
  }

  void _updateController() {
    final controller = Provider.of<MFWizardController>(context, listen: false);
    final amount = double.tryParse(_amountController.text) ?? 0;
    final nav = double.tryParse(_navController.text) ?? 0;
    controller.updateExistingMFDetails(
      amount: amount,
      nav: nav,
    );
  }

  Future<void> _showDatePicker() async {
    final controller = Provider.of<MFWizardController>(context, listen: false);
    final picked = await showAppDatePicker(
      context: context,
      initialDate: controller.investmentDate,
      minimumDate: DateTime.now().subtract(const Duration(days: 365 * 30)),
      maximumDate: DateTime.now(),
    );
    if (picked != null) {
      controller.updatePurchaseDate(picked);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _navController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<MFWizardController>(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(Spacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Investment Details',
            style: AppStyles.titleStyle(context),
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            'Enter amount and NAV for ${controller.selectedMF?.schemeName ?? "Mutual Fund"}',
            style: TextStyle(color: AppStyles.getSecondaryTextColor(context)),
          ),
          const SizedBox(height: 30),
          // Amount
          Text(
            'Investment Amount',
            style: TextStyle(
              color: AppStyles.getTextColor(context),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: Spacing.sm),
          CupertinoTextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            placeholder: '0.00',
            padding: const EdgeInsets.all(Spacing.lg),
            decoration: BoxDecoration(
              color: AppStyles.getCardColor(context),
              borderRadius: BorderRadius.circular(Radii.md),
            ),
            prefix: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Text(
                '₹',
                style: TextStyle(color: AppStyles.getTextColor(context)),
              ),
            ),
            style: TextStyle(color: AppStyles.getTextColor(context)),
            onChanged: (_) => _updateController(),
          ),
          const SizedBox(height: Spacing.xl),
          // Average NAV
          Text(
            'Average NAV',
            style: TextStyle(
              color: AppStyles.getTextColor(context),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: Spacing.sm),
          CupertinoTextField(
            controller: _navController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            placeholder: '0.00',
            padding: const EdgeInsets.all(Spacing.lg),
            decoration: BoxDecoration(
              color: AppStyles.getCardColor(context),
              borderRadius: BorderRadius.circular(Radii.md),
            ),
            prefix: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Text(
                '₹',
                style: TextStyle(color: AppStyles.getTextColor(context)),
              ),
            ),
            style: TextStyle(color: AppStyles.getTextColor(context)),
            onChanged: (_) => _updateController(),
          ),
          const SizedBox(height: Spacing.xl),
          // Date of Purchase
          Text(
            'Date of Investment',
            style: TextStyle(
              color: AppStyles.getTextColor(context),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: Spacing.sm),
          GestureDetector(
            onTap: _showDatePicker,
            child: Container(
              padding: const EdgeInsets.all(Spacing.lg),
              decoration: BoxDecoration(
                color: AppStyles.getCardColor(context),
                borderRadius: BorderRadius.circular(Radii.md),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${controller.investmentDate.day} ${_monthName(controller.investmentDate.month)} ${controller.investmentDate.year}',
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
          // Units Auto Calculated
          Text(
            'Units (Auto-calculated)',
            style: TextStyle(
              color: AppStyles.getTextColor(context),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: Spacing.sm),
          Container(
            padding: const EdgeInsets.all(Spacing.lg),
            decoration: BoxDecoration(
              color: AppStyles.getBackground(context).withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(Radii.md),
              border: Border.all(
                color: CupertinoColors.systemGrey.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Units',
                  style: TextStyle(
                    color: AppStyles.getSecondaryTextColor(context),
                  ),
                ),
                Text(
                  controller.calculatedUnits.toStringAsFixed(4),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: TypeScale.headline,
                    color: AppStyles.getTextColor(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          // Summary
          Container(
            padding: const EdgeInsets.all(Spacing.xl),
            decoration: BoxDecoration(
              color: SemanticColors.investments.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(Radii.lg),
              border: Border.all(
                color: SemanticColors.investments.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total Investment',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '₹${controller.totalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: TypeScale.headline,
                        color: SemanticColors.investments,
                      ),
                    ),
                  ],
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
