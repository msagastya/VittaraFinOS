import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/ui/manage/cryptocurrency/crypto_wizard_controller.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';

class CryptoPurchaseStep extends StatefulWidget {
  const CryptoPurchaseStep({super.key});

  @override
  State<CryptoPurchaseStep> createState() => _CryptoPurchaseStepState();
}

class _CryptoPurchaseStepState extends State<CryptoPurchaseStep> {
  late TextEditingController _quantityController;
  late TextEditingController _priceController;
  late TextEditingController _feeController;
  late TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    final controller =
        Provider.of<CryptoWizardController>(context, listen: false);
    _quantityController = TextEditingController(
      text: controller.quantity != null ? controller.quantity!.toString() : '',
    );
    _priceController = TextEditingController(
      text: controller.pricePerUnit != null
          ? controller.pricePerUnit!.toString()
          : '',
    );
    _feeController = TextEditingController(
      text: controller.transactionFee != null
          ? controller.transactionFee!.toString()
          : '',
    );
    _notesController = TextEditingController(text: controller.notes ?? '');
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _priceController.dispose();
    _feeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<CryptoWizardController>(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Purchase Details',
            style: AppStyles.titleStyle(context),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter your purchase information',
            style: TextStyle(color: AppStyles.getSecondaryTextColor(context)),
          ),
          const SizedBox(height: 30),
          // Purchase Date
          Text(
            'Purchase Date',
            style: TextStyle(
              color: AppStyles.getTextColor(context),
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () async {
              final pickedDate = await showCupertinoModalPopup<DateTime>(
                context: context,
                builder: (BuildContext context) {
                  return Container(
                    height: 300,
                    color: AppStyles.getBackground(context),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12),
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
                  );
                },
              );

              if (pickedDate != null) {
                controller.updatePurchaseDate(pickedDate);
              }
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppStyles.getCardColor(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.grey.withValues(alpha: 0.3),
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
          const SizedBox(height: 24),
          // Quantity
          Text(
            'Quantity (${controller.cryptoSymbol ?? "Coins"})',
            style: TextStyle(
              color: AppStyles.getTextColor(context),
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
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
            style: TextStyle(color: AppStyles.getTextColor(context)),
            onChanged: (value) {
              final qty = double.tryParse(value) ?? 0;
              if (qty > 0) {
                controller.updateQuantity(qty);
              }
            },
          ),
          const SizedBox(height: 24),
          // Price per Unit
          Text(
            'Price per ${controller.cryptoSymbol ?? "Coin"} (₹)',
            style: TextStyle(
              color: AppStyles.getTextColor(context),
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          CupertinoTextField(
            controller: _priceController,
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
            onChanged: (value) {
              final price = double.tryParse(value) ?? 0;
              if (price > 0) {
                controller.updatePricePerUnit(price);
              }
            },
          ),
          const SizedBox(height: 24),
          // Transaction Fee (Optional)
          Text(
            'Transaction Fee (₹) - Optional',
            style: TextStyle(
              color: AppStyles.getTextColor(context),
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          CupertinoTextField(
            controller: _feeController,
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
            onChanged: (value) {
              final fee = double.tryParse(value);
              controller.updateTransactionFee(fee);
            },
          ),
          const SizedBox(height: 24),
          // Notes
          Text(
            'Notes - Optional',
            style: TextStyle(
              color: AppStyles.getTextColor(context),
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          CupertinoTextField(
            controller: _notesController,
            placeholder: 'Add notes about this purchase...',
            padding: const EdgeInsets.all(16),
            maxLines: 3,
            decoration: BoxDecoration(
              color: AppStyles.getCardColor(context),
              borderRadius: BorderRadius.circular(12),
            ),
            style: TextStyle(color: AppStyles.getTextColor(context)),
            onChanged: (value) {
              controller.updateNotes(value.isEmpty ? null : value);
            },
          ),
          const SizedBox(height: 30),
          // Summary
          if (controller.quantity != null &&
              controller.quantity! > 0 &&
              controller.pricePerUnit != null &&
              controller.pricePerUnit! > 0) ...{
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF7931A).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFF7931A).withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                children: [
                  _SummaryRow(
                    label: 'Total Investment',
                    value: '₹${controller.totalInvested.toStringAsFixed(2)}',
                    isBold: true,
                  ),
                  const SizedBox(height: 12),
                  _SummaryRow(
                    label: 'Transaction Fee',
                    value:
                        '₹${(controller.transactionFee ?? 0).toStringAsFixed(2)}',
                  ),
                  const SizedBox(height: 12),
                  _SummaryRow(
                    label: 'Total Cost',
                    value: '₹${controller.totalWithFee.toStringAsFixed(2)}',
                    isBold: true,
                    isHighlight: true,
                  ),
                ],
              ),
            ),
          },
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;
  final bool isHighlight;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.isBold = false,
    this.isHighlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppStyles.getSecondaryTextColor(context),
            fontSize: 13,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: isHighlight
                ? const Color(0xFFF7931A)
                : AppStyles.getTextColor(context),
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            fontSize: isHighlight ? 14 : 13,
          ),
        ),
      ],
    );
  }
}
