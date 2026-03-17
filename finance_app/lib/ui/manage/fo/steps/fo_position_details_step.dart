import 'package:flutter/cupertino.dart';
import 'package:vittara_fin_os/ui/manage/fo/fo_wizard_controller.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';

class FOPositionDetailsStep extends StatefulWidget {
  final FOWizardController ctrl;

  const FOPositionDetailsStep(this.ctrl, {super.key});

  @override
  State<FOPositionDetailsStep> createState() => _FOPositionDetailsStepState();
}

class _FOPositionDetailsStepState extends State<FOPositionDetailsStep> {
  late TextEditingController _currentPriceController;

  @override
  void initState() {
    super.initState();
    _currentPriceController = TextEditingController(
      text: widget.ctrl.currentPrice?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _currentPriceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(Spacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Position Details', style: AppStyles.titleStyle(context)),
          const SizedBox(height: 30),
          const Text('Current Price (₹)',
              style: TextStyle(
                  fontWeight: FontWeight.w600, fontSize: TypeScale.body)),
          const SizedBox(height: Spacing.md),
          CupertinoTextField(
            controller: _currentPriceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            placeholder: '0.00',
            padding: const EdgeInsets.all(Spacing.lg),
            decoration: BoxDecoration(
              color: AppStyles.getCardColor(context),
              borderRadius: BorderRadius.circular(Radii.md),
            ),
            prefix: const Padding(
              padding: EdgeInsets.only(left: 16),
              child: Text('₹'),
            ),
            onChanged: (v) {
              final price = double.tryParse(v) ?? 0;
              if (price > 0) widget.ctrl.updateCurrentPrice(price);
            },
          ),
          const SizedBox(height: Spacing.xxl),
          const Text('Entry Date',
              style: TextStyle(
                  fontWeight: FontWeight.w600, fontSize: TypeScale.body)),
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
                                color: CupertinoColors.systemGrey
                                    .withValues(alpha: 0.2)),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Select Date',
                                style: TextStyle(
                                    fontSize: TypeScale.headline,
                                    fontWeight: FontWeight.bold)),
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
                          initialDateTime: widget.ctrl.entryDate,
                          maximumDate: DateTime.now(),
                          onDateTimeChanged: (date) {
                            widget.ctrl.updateEntryDate(date);
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
                borderRadius: BorderRadius.circular(Radii.md),
                border: Border.all(
                    color: CupertinoColors.systemGrey.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${widget.ctrl.entryDate.day}/${widget.ctrl.entryDate.month}/${widget.ctrl.entryDate.year}',
                    style: TextStyle(color: AppStyles.getTextColor(context)),
                  ),
                  const Icon(CupertinoIcons.calendar),
                ],
              ),
            ),
          ),
          const SizedBox(height: Spacing.xxl),
          const Text('Expiry Date',
              style: TextStyle(
                  fontWeight: FontWeight.w600, fontSize: TypeScale.body)),
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
                                color: CupertinoColors.systemGrey
                                    .withValues(alpha: 0.2)),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Select Date',
                                style: TextStyle(
                                    fontSize: TypeScale.headline,
                                    fontWeight: FontWeight.bold)),
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
                          initialDateTime: widget.ctrl.expiryDate,
                          onDateTimeChanged: (date) {
                            widget.ctrl.updateExpiryDate(date);
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
                borderRadius: BorderRadius.circular(Radii.md),
                border: Border.all(
                    color: CupertinoColors.systemGrey.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${widget.ctrl.expiryDate.day}/${widget.ctrl.expiryDate.month}/${widget.ctrl.expiryDate.year}',
                    style: TextStyle(color: AppStyles.getTextColor(context)),
                  ),
                  const Icon(CupertinoIcons.calendar),
                ],
              ),
            ),
          ),
          if (widget.ctrl.entryPrice != null &&
              widget.ctrl.currentPrice != null) ...[
            const SizedBox(height: Spacing.xxl),
            Container(
              padding: const EdgeInsets.all(Spacing.lg),
              decoration: BoxDecoration(
                color: (widget.ctrl.gainLoss >= 0
                        ? AppStyles.bioGreen
                        : AppStyles.plasmaRed)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(Radii.md),
                border: Border.all(
                    color: (widget.ctrl.gainLoss >= 0
                            ? AppStyles.bioGreen
                            : AppStyles.plasmaRed)
                        .withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  _Summary('Current Value',
                      '₹${widget.ctrl.currentValue.toStringAsFixed(2)}', true),
                  const SizedBox(height: Spacing.md),
                  _Summary(
                      'Gain/Loss',
                      '${widget.ctrl.gainLoss >= 0 ? '+' : ''}₹${widget.ctrl.gainLoss.toStringAsFixed(2)}',
                      widget.ctrl.gainLoss >= 0),
                  const SizedBox(height: Spacing.md),
                  _Summary(
                      'Return %',
                      '${widget.ctrl.gainLossPercent >= 0 ? '+' : ''}${widget.ctrl.gainLossPercent.toStringAsFixed(2)}%',
                      widget.ctrl.gainLossPercent >= 0,
                      isBold: true),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  final String label;
  final String value;
  final bool isPositive;
  final bool isBold;

  const _Summary(this.label, this.value, this.isPositive,
      {this.isBold = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                color: AppStyles.getSecondaryTextColor(context),
                fontSize: TypeScale.subhead)),
        Text(value,
            style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
                fontSize: isBold ? 14 : 13,
                color: isPositive
                    ? AppStyles.bioGreen
                    : AppStyles.plasmaRed)),
      ],
    );
  }
}
