import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/services/stock_api_service.dart';
import 'package:vittara_fin_os/ui/manage/stocks/stocks_wizard_controller.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';

class TransactionDetailsStep extends StatefulWidget {
  const TransactionDetailsStep({super.key});

  @override
  State<TransactionDetailsStep> createState() => _TransactionDetailsStepState();
}

class _TransactionDetailsStepState extends State<TransactionDetailsStep> {
  late TextEditingController _qtyController;
  late TextEditingController _priceController;
  final StockApiService _apiService = StockApiService();
  bool _isLoadingPrice = false;
  double _currentMarketPrice =
      0; // Current market price (auto-fetched, read-only)

  @override
  void initState() {
    super.initState();
    final controller =
        Provider.of<StocksWizardController>(context, listen: false);
    _qtyController = TextEditingController(
        text: controller.qty > 0 ? controller.qty.toString() : '');
    _priceController = TextEditingController(
        text: controller.price > 0 ? controller.price.toString() : '');

    // Fetch current market price
    if (controller.selectedStock != null) {
      _fetchPrice(controller.selectedStock!.symbol);
    }
  }

  Future<void> _fetchPrice(String symbol) async {
    setState(() => _isLoadingPrice = true);
    final price = await _apiService.getStockPrice(symbol);
    if (price != null && mounted) {
      setState(() {
        _currentMarketPrice = price;
        // Pre-fill purchase price with current market price if not already set
        if (_priceController.text.isEmpty) {
          _priceController.text = price.toStringAsFixed(2);
          _updateController();
        }
      });
    }
    if (mounted) setState(() => _isLoadingPrice = false);
  }

  void _updateController() {
    final controller =
        Provider.of<StocksWizardController>(context, listen: false);
    final qty = double.tryParse(_qtyController.text) ?? 0;
    final price = double.tryParse(_priceController.text) ?? 0;
    final currentValue =
        qty * _currentMarketPrice; // Current value = qty × current market price
    controller.updateDetails(
      quantity: qty,
      pricePerShare: price,
      current: currentValue,
    );
  }

  void _showDatePicker() {
    final controller =
        Provider.of<StocksWizardController>(context, listen: false);
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
            initialDateTime: controller.purchaseDate,
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
    _qtyController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<StocksWizardController>(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Transaction Details',
            style: AppStyles.titleStyle(context),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter quantity and price for ${controller.selectedStock?.symbol ?? "Stock"}',
            style: TextStyle(color: AppStyles.getSecondaryTextColor(context)),
          ),
          const SizedBox(height: 30),

          // Quantity
          Text('Quantity',
              style: TextStyle(
                  color: AppStyles.getTextColor(context),
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          CupertinoTextField(
            controller: _qtyController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            placeholder: '0',
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppStyles.getCardColor(context),
              borderRadius: BorderRadius.circular(12),
            ),
            style: TextStyle(color: AppStyles.getTextColor(context)),
            onChanged: (_) => _updateController(),
          ),
          const SizedBox(height: 20),

          // Price
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Price per Share',
                  style: TextStyle(
                      color: AppStyles.getTextColor(context),
                      fontWeight: FontWeight.w600)),
              if (_isLoadingPrice) const CupertinoActivityIndicator(radius: 8),
            ],
          ),
          const SizedBox(height: 8),
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
              child: Text('₹',
                  style: TextStyle(color: AppStyles.getTextColor(context))),
            ),
            style: TextStyle(color: AppStyles.getTextColor(context)),
            onChanged: (_) => _updateController(),
          ),
          const SizedBox(height: 30),

          // Date of Purchase
          Text('Date of Purchase',
              style: TextStyle(
                  color: AppStyles.getTextColor(context),
                  fontWeight: FontWeight.w600)),
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
                    '${controller.purchaseDate.day} ${_monthName(controller.purchaseDate.month)} ${controller.purchaseDate.year}',
                    style: TextStyle(color: AppStyles.getTextColor(context)),
                  ),
                  Icon(CupertinoIcons.calendar,
                      color: AppStyles.getSecondaryTextColor(context)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 30),

          // Current Value (Read-only)
          Text('Current Market Value',
              style: TextStyle(
                  color: AppStyles.getTextColor(context),
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppStyles.getBackground(context).withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: CupertinoColors.systemGreen.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      CupertinoIcons.info,
                      size: 16,
                      color: AppStyles.getSecondaryTextColor(context),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Auto-calculated (Read-only)',
                      style: TextStyle(
                        color: AppStyles.getSecondaryTextColor(context),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: CupertinoColors.systemGreen.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: CupertinoColors.systemGreen.withValues(alpha: 0.4),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current Value @ ₹${_currentMarketPrice.toStringAsFixed(2)}/share',
                      style: TextStyle(
                        color: AppStyles.getSecondaryTextColor(context),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                Text(
                  '₹${(controller.qty * _currentMarketPrice).toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: CupertinoColors.systemGreen,
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
                  color: SemanticColors.investments.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Amount to Invest',
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
                if (controller.currentValue > 0) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Current Market Value',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '₹${controller.currentValue.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color:
                              controller.currentValue >= controller.totalAmount
                                  ? CupertinoColors.systemGreen
                                  : CupertinoColors.systemRed,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Gain/Loss (Initial)',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      Text(
                        '${controller.currentValue >= controller.totalAmount ? '+' : ''}₹${(controller.currentValue - controller.totalAmount).toStringAsFixed(2)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color:
                              controller.currentValue >= controller.totalAmount
                                  ? CupertinoColors.systemGreen
                                  : CupertinoColors.systemRed,
                        ),
                      ),
                    ],
                  ),
                ],
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
