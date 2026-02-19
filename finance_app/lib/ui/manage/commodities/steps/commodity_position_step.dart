import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:vittara_fin_os/logic/commodities_model.dart';
import 'package:vittara_fin_os/ui/manage/commodities/commodities_wizard_controller.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';

class CommodityPositionStep extends StatefulWidget {
  final CommoditiesWizardController ctrl;

  const CommodityPositionStep(this.ctrl, {super.key});

  @override
  State<CommodityPositionStep> createState() => _CommodityPositionStepState();
}

class _CommodityPositionStepState extends State<CommodityPositionStep> {
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
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Current Price & Position',
              style: AppStyles.titleStyle(context)),
          const SizedBox(height: 30),
          Text('Current Price Per ${widget.ctrl.unit ?? 'Unit'} (₹)',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 12),
          CupertinoTextField(
            controller: _currentPriceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            placeholder: '0.00',
            padding: const EdgeInsets.all(16),
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
              if (price > 0) widget.ctrl.updateCurrentPrice(price);
            },
          ),
          const SizedBox(height: 24),
          Text('Trade Position',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: AppStyles.getCardColor(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
            ),
            child: Column(
              children: [
                GestureDetector(
                  onTap: () => widget.ctrl.selectPosition(TradePosition.long),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: widget.ctrl.position == TradePosition.long
                          ? const Color(0xFF8B4513).withValues(alpha: 0.1)
                          : Colors.transparent,
                      border: Border(
                        bottom: BorderSide(
                            color: Colors.grey.withValues(alpha: 0.2)),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: widget.ctrl.position == TradePosition.long
                                  ? const Color(0xFF8B4513)
                                  : Colors.grey,
                            ),
                          ),
                          child: widget.ctrl.position == TradePosition.long
                              ? Center(
                                  child: Container(
                                    width: 10,
                                    height: 10,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF8B4513),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Long Position',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              Text('Profit if price increases',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: AppStyles.getSecondaryTextColor(
                                          context))),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => widget.ctrl.selectPosition(TradePosition.short),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    color: widget.ctrl.position == TradePosition.short
                        ? const Color(0xFF8B4513).withValues(alpha: 0.1)
                        : Colors.transparent,
                    child: Row(
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: widget.ctrl.position == TradePosition.short
                                  ? const Color(0xFF8B4513)
                                  : Colors.grey,
                            ),
                          ),
                          child: widget.ctrl.position == TradePosition.short
                              ? Center(
                                  child: Container(
                                    width: 10,
                                    height: 10,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF8B4513),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Short Position',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              Text('Profit if price decreases',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: AppStyles.getSecondaryTextColor(
                                          context))),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (widget.ctrl.buyPrice != null &&
              widget.ctrl.currentPrice != null &&
              widget.ctrl.quantity != null) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: (widget.ctrl.gainLoss >= 0 ? Colors.green : Colors.red)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color:
                        (widget.ctrl.gainLoss >= 0 ? Colors.green : Colors.red)
                            .withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  _Summary('Current Value',
                      '₹${widget.ctrl.currentValue.toStringAsFixed(2)}', true),
                  const SizedBox(height: 12),
                  _Summary(
                      'Gain/Loss',
                      '${widget.ctrl.gainLoss >= 0 ? '+' : ''}₹${widget.ctrl.gainLoss.toStringAsFixed(2)}',
                      widget.ctrl.gainLoss >= 0),
                  const SizedBox(height: 12),
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
                color: AppStyles.getSecondaryTextColor(context), fontSize: 13)),
        Text(value,
            style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
                fontSize: isBold ? 14 : 13,
                color: isPositive ? Colors.green : Colors.red)),
      ],
    );
  }
}
