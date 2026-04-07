import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/ui/manage/bonds/bonds_wizard_controller.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/styles/responsive_utils.dart';

class BondsPurchaseStep extends StatefulWidget {
  const BondsPurchaseStep({super.key});

  @override
  State<BondsPurchaseStep> createState() => _BondsPurchaseStepState();
}

class _BondsPurchaseStepState extends State<BondsPurchaseStep> {
  late TextEditingController _priceController;
  late TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    final controller =
        Provider.of<BondsWizardController>(context, listen: false);
    _priceController = TextEditingController(
      text: controller.purchasePrice != null
          ? controller.purchasePrice!.toString()
          : '',
    );
    _notesController = TextEditingController(text: controller.notes ?? '');
  }

  @override
  void dispose() {
    _priceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<BondsWizardController>(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(Spacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Purchase Information',
            style: AppStyles.titleStyle(context),
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            'Enter purchase date and price',
            style: TextStyle(color: AppStyles.getSecondaryTextColor(context)),
          ),
          const SizedBox(height: 30),
          // Purchase Date
          Text(
            'Purchase Date',
            style: TextStyle(
              color: AppStyles.getTextColor(context),
              fontWeight: FontWeight.w600,
              fontSize: TypeScale.body,
            ),
          ),
          const SizedBox(height: Spacing.md),
          GestureDetector(
            onTap: () async {
              final pickedDate = await showCupertinoModalPopup<DateTime>(
                context: context,
                builder: (BuildContext context) {
                  return RLayout.tabletConstrain(
                    context,
                    Container(
                    height: 300,
                    color: AppStyles.getBackground(context),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(Spacing.md),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              CupertinoButton(
                                padding: EdgeInsets.zero,
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancel'),
                              ),
                              CupertinoButton(
                                padding: EdgeInsets.zero,
                                onPressed: () => Navigator.pop(
                                    context, controller.purchaseDate),
                                child: const Text('Done'),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: CupertinoDatePicker(
                            initialDateTime: controller.purchaseDate,
                            maximumDate: DateTime.now(),
                            mode: CupertinoDatePickerMode.date,
                            onDateTimeChanged: (DateTime newDate) {
                              controller.updatePurchaseDate(newDate);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  );
                },
              );

              if (pickedDate != null) {
                controller.updatePurchaseDate(pickedDate);
              }
            },
            child: Container(
              padding: const EdgeInsets.all(Spacing.lg),
              decoration: BoxDecoration(
                color: AppStyles.getCardColor(context),
                borderRadius: BorderRadius.circular(Radii.md),
                border: Border.all(
                  color: CupertinoColors.systemGrey.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${controller.purchaseDate.day}/${controller.purchaseDate.month}/${controller.purchaseDate.year}',
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
          const SizedBox(height: Spacing.xxl),
          // Purchase Price per Bond
          Text(
            'Purchase Price per Bond (₹)',
            style: TextStyle(
              color: AppStyles.getTextColor(context),
              fontWeight: FontWeight.w600,
              fontSize: TypeScale.body,
            ),
          ),
          const SizedBox(height: Spacing.md),
          CupertinoTextField(
            controller: _priceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            placeholder: '1000',
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
            onChanged: (value) {
              final price = double.tryParse(value) ?? 0;
              if (price > 0) {
                controller.updatePurchasePrice(price);
              }
            },
          ),
          const SizedBox(height: Spacing.xxl),
          // Notes
          Text(
            'Notes (Optional)',
            style: TextStyle(
              color: AppStyles.getTextColor(context),
              fontWeight: FontWeight.w600,
              fontSize: TypeScale.body,
            ),
          ),
          const SizedBox(height: Spacing.md),
          CupertinoTextField(
            controller: _notesController,
            placeholder: 'Add any notes about this bond...',
            padding: const EdgeInsets.all(Spacing.lg),
            maxLines: 4,
            decoration: BoxDecoration(
              color: AppStyles.getCardColor(context),
              borderRadius: BorderRadius.circular(Radii.md),
            ),
            style: TextStyle(color: AppStyles.getTextColor(context)),
            onChanged: (value) {
              controller.updateNotes(value.isEmpty ? null : value);
            },
          ),
          const SizedBox(height: 30),
          // Summary
          Container(
            padding: const EdgeInsets.all(Spacing.lg),
            decoration: BoxDecoration(
              color: const Color(0xFF007AFF).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(Radii.md),
              border: Border.all(
                color: const Color(0xFF007AFF).withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Cost',
                      style: TextStyle(
                        color: AppStyles.getSecondaryTextColor(context),
                        fontSize: TypeScale.footnote,
                      ),
                    ),
                    Text(
                      '₹${controller.totalCost.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: TypeScale.headline,
                        color: Color(0xFF007AFF),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Spacing.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Maturity Value (Face Value)',
                      style: TextStyle(
                        color: AppStyles.getSecondaryTextColor(context),
                        fontSize: TypeScale.footnote,
                      ),
                    ),
                    Text(
                      '₹${controller.maturityValue.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: TypeScale.headline,
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
}
