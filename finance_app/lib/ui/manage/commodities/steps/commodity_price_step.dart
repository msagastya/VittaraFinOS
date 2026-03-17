import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:vittara_fin_os/ui/manage/commodities/commodities_wizard_controller.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';

class CommodityPriceStep extends StatefulWidget {
  final CommoditiesWizardController ctrl;

  const CommodityPriceStep(this.ctrl, {super.key});

  @override
  State<CommodityPriceStep> createState() => _CommodityPriceStepState();
}

class _CommodityPriceStepState extends State<CommodityPriceStep> {
  late TextEditingController _priceController;

  @override
  void initState() {
    super.initState();
    _priceController = TextEditingController(
      text: widget.ctrl.buyPrice?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final exchanges = [
      'MCX (India)',
      'NCDEX (India)',
      'COMEX (US)',
      'LME (London)',
      'TOCOM (Japan)',
      'Other'
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(Spacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Purchase Price & Exchange',
              style: AppStyles.titleStyle(context)),
          const SizedBox(height: 30),
          Text('Price Per ${widget.ctrl.unit ?? 'Unit'} (₹)',
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: TypeScale.body)),
          const SizedBox(height: Spacing.md),
          CupertinoTextField(
            controller: _priceController,
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
              if (price > 0) widget.ctrl.updateBuyPrice(price);
            },
          ),
          const SizedBox(height: Spacing.xxl),
          const Text('Purchase Date',
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
                          initialDateTime: widget.ctrl.purchaseDate,
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
                borderRadius: BorderRadius.circular(Radii.md),
                border: Border.all(
                    color: CupertinoColors.systemGrey.withValues(alpha: 0.2)),
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
          const Text('Exchange',
              style: TextStyle(
                  fontWeight: FontWeight.w600, fontSize: TypeScale.body)),
          const SizedBox(height: Spacing.md),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppStyles.getCardColor(context),
              borderRadius: BorderRadius.circular(Radii.md),
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
                                      .withValues(alpha: 0.2)),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Select Exchange',
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
                            itemCount: exchanges.length,
                            itemBuilder: (context, index) {
                              final exchange = exchanges[index];
                              return GestureDetector(
                                onTap: () {
                                  widget.ctrl.updateExchange(exchange);
                                  Navigator.pop(ctx);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  margin: const EdgeInsets.only(bottom: 8),
                                  decoration: BoxDecoration(
                                    color: widget.ctrl.exchange == exchange
                                        ? const Color(0xFF8B4513)
                                            .withValues(alpha: 0.1)
                                        : AppStyles.getBackground(context),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: widget.ctrl.exchange == exchange
                                          ? const Color(0xFF8B4513)
                                          : Colors.transparent,
                                    ),
                                  ),
                                  child: Text(
                                    exchange,
                                    style: TextStyle(
                                      fontSize: TypeScale.body,
                                      color: widget.ctrl.exchange == exchange
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
                    widget.ctrl.exchange ?? 'Select exchange',
                    style: TextStyle(
                      color: widget.ctrl.exchange != null
                          ? AppStyles.getTextColor(context)
                          : AppStyles.getSecondaryTextColor(context),
                    ),
                  ),
                  const Icon(CupertinoIcons.down_arrow),
                ],
              ),
            ),
          ),
          if (widget.ctrl.buyPrice != null && widget.ctrl.quantity != null) ...[
            const SizedBox(height: Spacing.xxl),
            Container(
              padding: const EdgeInsets.all(Spacing.lg),
              decoration: BoxDecoration(
                color: const Color(0xFF8B4513).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(Radii.md),
                border: Border.all(
                    color: const Color(0xFF8B4513).withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Total Cost',
                          style: TextStyle(
                              fontSize: TypeScale.footnote,
                              color: AppStyles.getSecondaryTextColor(context))),
                      const SizedBox(height: Spacing.xs),
                      Text('₹${widget.ctrl.totalCost.toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontSize: TypeScale.headline,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF8B4513))),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
