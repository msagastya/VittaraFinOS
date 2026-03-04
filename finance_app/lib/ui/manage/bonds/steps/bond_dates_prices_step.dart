import 'package:flutter/cupertino.dart';
import 'package:vittara_fin_os/ui/manage/bonds/bonds_wizard_controller_v2.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';

class BondDatesPricesStep extends StatefulWidget {
  final BondsWizardControllerV2 ctrl;

  const BondDatesPricesStep(this.ctrl, {super.key});

  @override
  State<BondDatesPricesStep> createState() => _BondDatesPricesStepState();
}

class _BondDatesPricesStepState extends State<BondDatesPricesStep> {
  late TextEditingController _purchasePriceController;
  late TextEditingController _faceValueController;

  @override
  void initState() {
    super.initState();
    _purchasePriceController = TextEditingController(
      text: widget.ctrl.purchasePrice > 0
          ? widget.ctrl.purchasePrice.toString()
          : '',
    );
    _faceValueController = TextEditingController(
      text:
          widget.ctrl.faceValue > 0 ? widget.ctrl.faceValue.toString() : '1000',
    );
  }

  @override
  void dispose() {
    _purchasePriceController.dispose();
    _faceValueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(Spacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Bond Dates & Prices', style: AppStyles.titleStyle(context)),
          const SizedBox(height: 30),
          Text('Purchase Date',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: TypeScale.body)),
          const SizedBox(height: Spacing.md),
          GestureDetector(
            onTap: () {
              showCupertinoModalPopup(
                context: context,
                builder: (ctx) => Container(
                  height: 300,
                  color: AppStyles.getBackground(context),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(Spacing.lg),
                        decoration: BoxDecoration(
                          color: AppStyles.getCardColor(context),
                          border: Border(
                            bottom: BorderSide(
                                color: CupertinoColors.systemGrey.withValues(alpha: 0.2)),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Select Date',
                                style: const TextStyle(
                                    fontSize: TypeScale.headline, fontWeight: FontWeight.bold)),
                            GestureDetector(
                              onTap: () => Navigator.pop(ctx),
                              child: const Icon(CupertinoIcons.xmark),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: CupertinoDatePicker(
                          mode: CupertinoDatePickerMode.date,
                          initialDateTime: widget.ctrl.purchaseDate,
                          minimumDate: DateTime.now().subtract(const Duration(days: 365 * 30)),
                          maximumDate: DateTime.now(),
                          onDateTimeChanged: (date) {
                            widget.ctrl.updatePurchaseDate(date);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(Spacing.lg),
              decoration: BoxDecoration(
                color: AppStyles.getCardColor(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: CupertinoColors.systemGrey.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${widget.ctrl.purchaseDate.day}/${widget.ctrl.purchaseDate.month}/${widget.ctrl.purchaseDate.year}',
                    style: TextStyle(color: AppStyles.getTextColor(context)),
                  ),
                  const Icon(CupertinoIcons.calendar),
                ],
              ),
            ),
          ),
          const SizedBox(height: Spacing.xxl),
          Text('Maturity Date',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: TypeScale.body)),
          const SizedBox(height: Spacing.md),
          GestureDetector(
            onTap: () {
              showCupertinoModalPopup(
                context: context,
                builder: (ctx) => Container(
                  height: 300,
                  color: AppStyles.getBackground(context),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(Spacing.lg),
                        decoration: BoxDecoration(
                          color: AppStyles.getCardColor(context),
                          border: Border(
                            bottom: BorderSide(
                                color: CupertinoColors.systemGrey.withValues(alpha: 0.2)),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Select Date',
                                style: const TextStyle(
                                    fontSize: TypeScale.headline, fontWeight: FontWeight.bold)),
                            GestureDetector(
                              onTap: () => Navigator.pop(ctx),
                              child: const Icon(CupertinoIcons.xmark),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: CupertinoDatePicker(
                          mode: CupertinoDatePickerMode.date,
                          initialDateTime: widget.ctrl.maturityDate,
                          onDateTimeChanged: (date) {
                            widget.ctrl.updateMaturityDate(date);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(Spacing.lg),
              decoration: BoxDecoration(
                color: AppStyles.getCardColor(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: CupertinoColors.systemGrey.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${widget.ctrl.maturityDate.day}/${widget.ctrl.maturityDate.month}/${widget.ctrl.maturityDate.year}',
                    style: TextStyle(color: AppStyles.getTextColor(context)),
                  ),
                  const Icon(CupertinoIcons.calendar),
                ],
              ),
            ),
          ),
          const SizedBox(height: Spacing.xxl),
          Text('Purchase Price (₹)',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: TypeScale.body)),
          const SizedBox(height: Spacing.md),
          CupertinoTextField(
            controller: _purchasePriceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            placeholder: '0.00',
            padding: const EdgeInsets.all(Spacing.lg),
            decoration: BoxDecoration(
              color: AppStyles.getCardColor(context),
              borderRadius: BorderRadius.circular(12),
            ),
            prefix: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: const Text('₹'),
            ),
            onChanged: (v) {
              final price = double.tryParse(v) ?? 0;
              if (price > 0) widget.ctrl.updatePurchasePrice(price);
            },
          ),
          const SizedBox(height: Spacing.xxl),
          Text('Face Value (₹)',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: TypeScale.body)),
          const SizedBox(height: Spacing.md),
          CupertinoTextField(
            controller: _faceValueController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            placeholder: '1000',
            padding: const EdgeInsets.all(Spacing.lg),
            decoration: BoxDecoration(
              color: AppStyles.getCardColor(context),
              borderRadius: BorderRadius.circular(12),
            ),
            prefix: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: const Text('₹'),
            ),
            onChanged: (v) {
              final value = double.tryParse(v) ?? 1000;
              if (value > 0) widget.ctrl.updateFaceValue(value);
            },
          ),
          const SizedBox(height: Spacing.xxl),
          Text('Payment Frequency',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: TypeScale.body)),
          const SizedBox(height: Spacing.md),
          Row(
            children: [
              Expanded(
                child: _FrequencyButton(
                  label: 'Annual',
                  isSelected: widget.ctrl.paymentsPerYear == 1,
                  onTap: () => widget.ctrl.updatePaymentsPerYear(1),
                ),
              ),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: _FrequencyButton(
                  label: 'Semi-Annual',
                  isSelected: widget.ctrl.paymentsPerYear == 2,
                  onTap: () => widget.ctrl.updatePaymentsPerYear(2),
                ),
              ),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: _FrequencyButton(
                  label: 'Monthly',
                  isSelected: widget.ctrl.paymentsPerYear == 12,
                  onTap: () => widget.ctrl.updatePaymentsPerYear(12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FrequencyButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FrequencyButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(Spacing.md),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF00A6CC).withValues(alpha: 0.1)
              : AppStyles.getCardColor(context),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF00A6CC)
                : CupertinoColors.systemGrey.withValues(alpha: 0.2),
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: TypeScale.footnote,
              fontWeight: FontWeight.w600,
              color: isSelected
                  ? const Color(0xFF00A6CC)
                  : AppStyles.getTextColor(context),
            ),
          ),
        ),
      ),
    );
  }
}
