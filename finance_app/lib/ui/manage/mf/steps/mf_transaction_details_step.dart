import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/ui/manage/mf/mf_wizard_controller.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';

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

  void _showDatePicker() {
    final controller = Provider.of<MFWizardController>(context, listen: false);
    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        height: 216,
        padding: const EdgeInsets.only(top: 6.0),
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: SafeArea(
          top: false,
          child: CupertinoDatePicker(
            initialDateTime: controller.investmentDate,
            mode: CupertinoDatePickerMode.date,
            maximumDate: DateTime.now(),
            onDateTimeChanged: (DateTime newDate) {
              controller.updatePurchaseDate(newDate);
            },
          ),
        ),
      ),
    );
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
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Investment Details',
            style: AppStyles.titleStyle(context),
          ),
          const SizedBox(height: 8),
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
          const SizedBox(height: 8),
          CupertinoTextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            placeholder: '0.00',
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppStyles.getCardColor(context),
              borderRadius: BorderRadius.circular(12),
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
          const SizedBox(height: 20),
          // Average NAV
          Text(
            'Average NAV',
            style: TextStyle(
              color: AppStyles.getTextColor(context),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          CupertinoTextField(
            controller: _navController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            placeholder: '0.00',
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppStyles.getCardColor(context),
              borderRadius: BorderRadius.circular(12),
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
          const SizedBox(height: 20),
          // Date of Purchase
          Text(
            'Date of Investment',
            style: TextStyle(
              color: AppStyles.getTextColor(context),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _showDatePicker,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppStyles.getCardColor(context),
                borderRadius: BorderRadius.circular(12),
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
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppStyles.getBackground(context).withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
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
                    fontSize: 16,
                    color: AppStyles.getTextColor(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          // Summary
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: SemanticColors.investments.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
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
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
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
