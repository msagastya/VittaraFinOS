import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/services/stock_api_service.dart';
import 'package:vittara_fin_os/ui/manage/stocks/stocks_wizard_controller.dart';
import 'package:vittara_fin_os/utils/date_formatter.dart';
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
      padding: const EdgeInsets.all(Spacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Transaction Details',
            style: AppStyles.titleStyle(context),
          ),
          const SizedBox(height: Spacing.sm),
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
          const SizedBox(height: Spacing.sm),
          CupertinoTextField(
            controller: _qtyController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            placeholder: '0',
            padding: const EdgeInsets.all(Spacing.lg),
            decoration: BoxDecoration(
              color: AppStyles.getCardColor(context),
              borderRadius: BorderRadius.circular(Radii.md),
            ),
            style: TextStyle(color: AppStyles.getTextColor(context)),
            onChanged: (_) => _updateController(),
          ),
          const SizedBox(height: Spacing.xl),

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
          const SizedBox(height: Spacing.sm),
          CupertinoTextField(
            controller: _priceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            placeholder: '0.00',
            padding: const EdgeInsets.all(Spacing.lg),
            decoration: BoxDecoration(
              color: AppStyles.getCardColor(context),
              borderRadius: BorderRadius.circular(Radii.md),
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
          const SizedBox(height: Spacing.sm),
          GestureDetector(
            onTap: _showDatePicker,
            child: Container(
              padding: const EdgeInsets.all(Spacing.lg),
              decoration: BoxDecoration(
                color: AppStyles.getCardColor(context),
                borderRadius: BorderRadius.circular(Radii.md),
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
          const SizedBox(height: Spacing.sm),
          Container(
            padding: const EdgeInsets.all(Spacing.lg),
            decoration: BoxDecoration(
              color: AppStyles.getBackground(context).withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(Radii.md),
              border: Border.all(
                color: AppStyles.bioGreen.withValues(alpha: 0.3),
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
                    const SizedBox(width: Spacing.sm),
                    Text(
                      'Auto-calculated (Read-only)',
                      style: TextStyle(
                        color: AppStyles.getSecondaryTextColor(context),
                        fontSize: TypeScale.footnote,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: Spacing.sm),
          Container(
            padding: const EdgeInsets.all(Spacing.lg),
            decoration: BoxDecoration(
              color: AppStyles.bioGreen.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(Radii.md),
              border: Border.all(
                color: AppStyles.bioGreen.withValues(alpha: 0.4),
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
                        fontSize: TypeScale.footnote,
                      ),
                    ),
                  ],
                ),
                Text(
                  '₹${(controller.qty * _currentMarketPrice).toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: TypeScale.headline,
                    color: AppStyles.bioGreen,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),

          // Summary
          Container(
            padding: const EdgeInsets.all(Spacing.xl),
            decoration: BoxDecoration(
              color: SemanticColors.investments.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(Radii.lg),
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
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: TypeScale.headline,
                        color: SemanticColors.investments,
                      ),
                    ),
                  ],
                ),
                if (controller.currentValue > 0) ...[
                  const SizedBox(height: Spacing.md),
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
                          fontSize: TypeScale.headline,
                          color:
                              controller.currentValue >= controller.totalAmount
                                  ? AppStyles.bioGreen
                                  : AppStyles.plasmaRed,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Spacing.md),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Gain/Loss (Initial)',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: TypeScale.subhead),
                      ),
                      Text(
                        '${controller.currentValue >= controller.totalAmount ? '+' : ''}₹${(controller.currentValue - controller.totalAmount).toStringAsFixed(2)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: TypeScale.body,
                          color:
                              controller.currentValue >= controller.totalAmount
                                  ? AppStyles.bioGreen
                                  : AppStyles.plasmaRed,
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
    return DateFormatter.getMonthName(month);
  }
}
