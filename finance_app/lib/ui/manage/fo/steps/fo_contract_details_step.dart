import 'package:flutter/cupertino.dart';
import 'package:vittara_fin_os/ui/manage/fo/fo_wizard_controller.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';

class FOContractDetailsStep extends StatefulWidget {
  final FOWizardController ctrl;

  const FOContractDetailsStep(this.ctrl, {super.key});

  @override
  State<FOContractDetailsStep> createState() => _FOContractDetailsStepState();
}

class _FOContractDetailsStepState extends State<FOContractDetailsStep> {
  late TextEditingController _entryPriceController;
  late TextEditingController _quantityController;

  @override
  void initState() {
    super.initState();
    _entryPriceController = TextEditingController(
      text: widget.ctrl.entryPrice?.toString() ?? '',
    );
    _quantityController = TextEditingController(
      text: widget.ctrl.quantity?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _entryPriceController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Contract Details', style: AppStyles.titleStyle(context)),
          const SizedBox(height: 30),
          Text('Entry Price (₹)',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 12),
          CupertinoTextField(
            controller: _entryPriceController,
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
              if (price > 0) widget.ctrl.updateEntryPrice(price);
            },
          ),
          const SizedBox(height: 24),
          Text('Quantity / Lot Size',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 12),
          CupertinoTextField(
            controller: _quantityController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            placeholder: '0.00',
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppStyles.getCardColor(context),
              borderRadius: BorderRadius.circular(12),
            ),
            onChanged: (v) {
              final qty = double.tryParse(v) ?? 0;
              if (qty > 0) widget.ctrl.updateQuantity(qty);
            },
          ),
          if (widget.ctrl.entryPrice != null &&
              widget.ctrl.quantity != null) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1ABC9C).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFF1ABC9C).withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total Cost',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppStyles.getSecondaryTextColor(context))),
                      Text('₹${widget.ctrl.totalCost.toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1ABC9C))),
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
