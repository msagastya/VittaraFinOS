import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:vittara_fin_os/ui/manage/commodities/commodities_wizard_controller.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';

class CommodityQuantityStep extends StatefulWidget {
  final CommoditiesWizardController ctrl;

  const CommodityQuantityStep(this.ctrl, {super.key});

  @override
  State<CommodityQuantityStep> createState() => _CommodityQuantityStepState();
}

class _CommodityQuantityStepState extends State<CommodityQuantityStep> {
  late TextEditingController _quantityController;
  late TextEditingController _unitController;

  @override
  void initState() {
    super.initState();
    _quantityController = TextEditingController(
      text: widget.ctrl.quantity?.toString() ?? '',
    );
    _unitController = TextEditingController(
      text: widget.ctrl.unit ?? '',
    );
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final defaultUnits = [
      'Grams',
      'Kg',
      'Tonnes',
      'Ounces',
      'Barrels',
      'Liters',
      'Units'
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(Spacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Quantity & Unit', style: AppStyles.titleStyle(context)),
          const SizedBox(height: 30),
          Text('Quantity',
              style: TextStyle(
                  fontWeight: FontWeight.w600, fontSize: TypeScale.body)),
          const SizedBox(height: Spacing.md),
          CupertinoTextField(
            controller: _quantityController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            placeholder: '0.00',
            padding: const EdgeInsets.all(Spacing.lg),
            decoration: BoxDecoration(
              color: AppStyles.getCardColor(context),
              borderRadius: BorderRadius.circular(12),
            ),
            onChanged: (v) {
              final qty = double.tryParse(v) ?? 0;
              if (qty > 0) widget.ctrl.updateQuantity(qty);
            },
          ),
          const SizedBox(height: Spacing.xxl),
          Text('Unit of Measurement',
              style: TextStyle(
                  fontWeight: FontWeight.w600, fontSize: TypeScale.body)),
          const SizedBox(height: Spacing.md),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppStyles.getCardColor(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: CupertinoColors.systemGrey.withValues(alpha: 0.2)),
            ),
            child: CupertinoButton(
              onPressed: () {
                showCupertinoModalPopup(
                  context: context,
                  builder: (ctx) => Container(
                    color: AppStyles.getBackground(context),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(Spacing.lg),
                          decoration: BoxDecoration(
                            color: AppStyles.getCardColor(context),
                            border: Border(
                              bottom: BorderSide(
                                color: CupertinoColors.systemGrey
                                    .withValues(alpha: 0.2),
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Select Unit',
                                style: TextStyle(
                                  fontSize: TypeScale.headline,
                                  fontWeight: FontWeight.bold,
                                  color: AppStyles.getTextColor(context),
                                ),
                              ),
                              GestureDetector(
                                onTap: () => Navigator.pop(ctx),
                                child: const Icon(CupertinoIcons.xmark),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.all(Spacing.lg),
                            itemCount: defaultUnits.length,
                            itemBuilder: (context, index) {
                              final unit = defaultUnits[index];
                              return GestureDetector(
                                onTap: () {
                                  widget.ctrl.updateUnit(unit);
                                  _unitController.text = unit;
                                  Navigator.pop(ctx);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  margin: const EdgeInsets.only(bottom: 8),
                                  decoration: BoxDecoration(
                                    color: widget.ctrl.unit == unit
                                        ? const Color(0xFF8B4513)
                                            .withValues(alpha: 0.1)
                                        : AppStyles.getBackground(context),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: widget.ctrl.unit == unit
                                          ? const Color(0xFF8B4513)
                                          : Colors.transparent,
                                    ),
                                  ),
                                  child: Text(
                                    unit,
                                    style: TextStyle(
                                      fontSize: TypeScale.body,
                                      color: widget.ctrl.unit == unit
                                          ? const Color(0xFF8B4513)
                                          : AppStyles.getTextColor(context),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
              padding: EdgeInsets.zero,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.ctrl.unit ?? 'Select unit',
                    style: TextStyle(
                      color: widget.ctrl.unit != null
                          ? AppStyles.getTextColor(context)
                          : AppStyles.getSecondaryTextColor(context),
                    ),
                  ),
                  const Icon(CupertinoIcons.down_arrow),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
