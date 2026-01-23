import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/investment_model.dart';
import 'package:vittara_fin_os/logic/investments_controller.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/widgets/animations.dart';
import 'package:vittara_fin_os/ui/widgets/common_widgets.dart';
import 'package:vittara_fin_os/ui/widgets/toast_notification.dart';
import 'package:vittara_fin_os/utils/logger.dart';

class StockDetailsScreen extends StatefulWidget {
  final Investment investment;

  const StockDetailsScreen({required this.investment, super.key});

  @override
  State<StockDetailsScreen> createState() => _StockDetailsScreenState();
}

class _StockDetailsScreenState extends State<StockDetailsScreen> {
  final AppLogger logger = AppLogger();
  late Investment _investment;

  @override
  void initState() {
    super.initState();
    _investment = widget.investment;
  }

  double get _investedAmount => _investment.amount;
  double get _currentValue => (_investment.metadata?['currentValue'] as num?)?.toDouble() ?? _investedAmount;
  double get _gainLoss => _currentValue - _investedAmount;
  double get _gainLossPercent => _investedAmount > 0 ? (_gainLoss / _investedAmount) * 100 : 0;
  bool get _isGain => _gainLoss >= 0;

  String get _symbol => _investment.metadata?['symbol'] ?? _investment.name;
  String get _stockName => _investment.metadata?['name'] ?? 'Stock';
  String get _exchange => _investment.metadata?['exchange'] ?? '';
  double get _qty => (_investment.metadata?['qty'] as num?)?.toDouble() ?? 0;
  double get _pricePerShare => (_investment.metadata?['pricePerShare'] as num?)?.toDouble() ?? 0;

  void _showBuyMoreModal() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => _BuyMoreModal(investment: _investment),
    );
  }

  void _showSellModal() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => _SellModal(investment: _investment, currentQty: _qty),
    );
  }

  void _showSIPModal() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => _SIPModal(investment: _investment),
    );
  }

  void _showEditModal() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => _EditModal(investment: _investment),
    );
  }

  void _showDividendModal() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => _DividendModal(investment: _investment),
    );
  }

  void _showDeleteConfirmation() {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Delete Investment'),
        content: const Text('Are you sure you want to delete this investment? This action cannot be undone.'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Delete'),
            onPressed: () {
              final controller = Provider.of<InvestmentsController>(context, listen: false);
              controller.removeInvestment(_investment.id);
              Navigator.pop(context);
              Navigator.pop(context);
              toast.showSuccess('Investment deleted');
              logger.info('Deleted investment: ${_investment.id}', context: 'StockDetails');
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return CupertinoPageScaffold(
      backgroundColor: AppStyles.getBackground(context),
      navigationBar: CupertinoNavigationBar(
        middle: Text(_symbol, style: TextStyle(color: AppStyles.getTextColor(context))),
        backgroundColor: AppStyles.getBackground(context),
        border: null,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(Spacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Stock Header
              Container(
                padding: EdgeInsets.all(Spacing.lg),
                decoration: AppStyles.cardDecoration(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _investment.color.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            CupertinoIcons.chart_bar_square_fill,
                            size: 32,
                            color: _investment.color,
                          ),
                        ),
                        SizedBox(width: Spacing.lg),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _symbol,
                                style: AppStyles.titleStyle(context).copyWith(fontSize: 24),
                              ),
                              Text(
                                _stockName,
                                style: TextStyle(
                                  color: AppStyles.getSecondaryTextColor(context),
                                  fontSize: 14,
                                ),
                              ),
                              if (_exchange.isNotEmpty)
                                Text(
                                  _exchange,
                                  style: TextStyle(
                                    color: AppStyles.getSecondaryTextColor(context),
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: Spacing.xl),
                    // Values
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Invested',
                              style: TextStyle(
                                color: AppStyles.getSecondaryTextColor(context),
                                fontSize: 12,
                              ),
                            ),
                            SizedBox(height: Spacing.xs),
                            Text(
                              '₹${_investedAmount.toStringAsFixed(2)}',
                              style: AppStyles.titleStyle(context).copyWith(fontSize: 20),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Current Value',
                              style: TextStyle(
                                color: AppStyles.getSecondaryTextColor(context),
                                fontSize: 12,
                              ),
                            ),
                            SizedBox(height: Spacing.xs),
                            Text(
                              '₹${_currentValue.toStringAsFixed(2)}',
                              style: AppStyles.titleStyle(context).copyWith(
                                fontSize: 20,
                                color: _investment.color,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    SizedBox(height: Spacing.lg),
                    // Gain/Loss
                    Container(
                      padding: EdgeInsets.all(Spacing.md),
                      decoration: BoxDecoration(
                        color: _isGain
                            ? CupertinoColors.systemGreen.withValues(alpha: 0.1)
                            : CupertinoColors.systemRed.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _isGain ? 'Gain' : 'Loss',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: _isGain
                                  ? CupertinoColors.systemGreen
                                  : CupertinoColors.systemRed,
                            ),
                          ),
                          Text(
                            '${_isGain ? '+' : ''}₹${_gainLoss.toStringAsFixed(2)} (${_gainLossPercent.toStringAsFixed(2)}%)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _isGain
                                  ? CupertinoColors.systemGreen
                                  : CupertinoColors.systemRed,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: Spacing.xl),

              // Investment Details
              Text(
                'Details',
                style: AppStyles.titleStyle(context).copyWith(fontSize: 18),
              ),
              SizedBox(height: Spacing.lg),
              _buildDetailRow(context, 'Quantity', '$_qty shares'),
              _buildDetailRow(context, 'Price per Share', '₹${_pricePerShare.toStringAsFixed(2)}'),
              if (_investment.metadata?['purchaseDate'] != null)
                _buildDetailRow(
                  context,
                  'Purchase Date',
                  _formatDate(DateTime.parse(_investment.metadata!['purchaseDate'] as String)),
                ),
              if (_investment.metadata?['extraCharges'] != null && (_investment.metadata!['extraCharges'] as num) > 0)
                _buildDetailRow(
                  context,
                  'Extra Charges',
                  '₹${((_investment.metadata!['extraCharges'] as num).toDouble()).toStringAsFixed(2)}',
                ),
              if (_investment.broker != null)
                _buildDetailRow(context, 'Broker', _investment.broker!),
              SizedBox(height: Spacing.xl),

              // Action Buttons
              Text(
                'Actions',
                style: AppStyles.titleStyle(context).copyWith(fontSize: 18),
              ),
              SizedBox(height: Spacing.lg),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: Spacing.lg,
                crossAxisSpacing: Spacing.lg,
                children: [
                  _buildActionButton(
                    context,
                    icon: CupertinoIcons.plus_circle_fill,
                    label: 'Buy More',
                    color: CupertinoColors.systemGreen,
                    onTap: _showBuyMoreModal,
                  ),
                  _buildActionButton(
                    context,
                    icon: CupertinoIcons.minus_circle_fill,
                    label: 'Sell',
                    color: CupertinoColors.systemRed,
                    onTap: _showSellModal,
                  ),
                  _buildActionButton(
                    context,
                    icon: CupertinoIcons.repeat,
                    label: 'SIP',
                    color: CupertinoColors.systemBlue,
                    onTap: _showSIPModal,
                  ),
                  _buildActionButton(
                    context,
                    icon: CupertinoIcons.pencil_circle_fill,
                    label: 'Edit',
                    color: CupertinoColors.systemOrange,
                    onTap: _showEditModal,
                  ),
                  _buildActionButton(
                    context,
                    icon: CupertinoIcons.money_dollar_circle_fill,
                    label: 'Dividend',
                    color: CupertinoColors.systemBrown,
                    onTap: _showDividendModal,
                  ),
                  _buildActionButton(
                    context,
                    icon: CupertinoIcons.trash_circle_fill,
                    label: 'Delete',
                    color: CupertinoColors.systemRed,
                    onTap: _showDeleteConfirmation,
                  ),
                ],
              ),
              SizedBox(height: Spacing.xl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: Spacing.md),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppStyles.getSecondaryTextColor(context),
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: AppStyles.getTextColor(context),
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: AppStyles.cardDecoration(context),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: color),
            ),
            SizedBox(height: Spacing.md),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: AppStyles.getTextColor(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

// Buy More Modal
class _BuyMoreModal extends StatefulWidget {
  final Investment investment;
  const _BuyMoreModal({required this.investment});

  @override
  State<_BuyMoreModal> createState() => _BuyMoreModalState();
}

class _BuyMoreModalState extends State<_BuyMoreModal> {
  late TextEditingController _qtyController;
  late TextEditingController _priceController;

  @override
  void initState() {
    super.initState();
    _qtyController = TextEditingController();
    _priceController = TextEditingController();
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final qty = double.tryParse(_qtyController.text) ?? 0;
    final price = double.tryParse(_priceController.text) ?? 0;
    final total = qty * price;

    return Container(
      decoration: BoxDecoration(
        color: AppStyles.getCardColor(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ModalHandle(),
                SizedBox(height: Spacing.lg),
                Text(
                  'Buy More Shares',
                  style: AppStyles.titleStyle(context).copyWith(fontSize: 22),
                ),
                SizedBox(height: Spacing.sm),
                Text(
                  'Add more shares to your investment',
                  style: TextStyle(
                    color: AppStyles.getSecondaryTextColor(context),
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: Spacing.xxxl),
                // Quantity
                Text('Additional Shares', style: TextStyle(color: AppStyles.getTextColor(context), fontWeight: FontWeight.w600)),
                SizedBox(height: Spacing.md),
                CupertinoTextField(
                  controller: _qtyController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  placeholder: '0',
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppStyles.getBackground(context),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  style: TextStyle(color: AppStyles.getTextColor(context)),
                  onChanged: (_) => setState(() {}),
                ),
                SizedBox(height: Spacing.lg),
                // Price
                Text('Price per Share', style: TextStyle(color: AppStyles.getTextColor(context), fontWeight: FontWeight.w600)),
                SizedBox(height: Spacing.md),
                CupertinoTextField(
                  controller: _priceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  placeholder: '0.00',
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppStyles.getBackground(context),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefix: Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Text('₹', style: TextStyle(color: AppStyles.getTextColor(context))),
                  ),
                  style: TextStyle(color: AppStyles.getTextColor(context)),
                  onChanged: (_) => setState(() {}),
                ),
                SizedBox(height: Spacing.lg),
                Container(
                  padding: EdgeInsets.all(Spacing.md),
                  decoration: BoxDecoration(
                    color: SemanticColors.investments.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Cost', style: TextStyle(fontWeight: FontWeight.w600)),
                      Text(
                        '₹${total.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: SemanticColors.investments,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: Spacing.xl),
                SizedBox(
                  width: double.infinity,
                  child: CupertinoButton.filled(
                    onPressed: qty > 0 && price > 0
                        ? () {
                            toast.showSuccess('Added $qty shares at ₹$price');
                            Navigator.pop(context);
                          }
                        : null,
                    child: const Text('Confirm Purchase'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Sell Modal
class _SellModal extends StatefulWidget {
  final Investment investment;
  final double currentQty;
  const _SellModal({required this.investment, required this.currentQty});

  @override
  State<_SellModal> createState() => _SellModalState();
}

class _SellModalState extends State<_SellModal> {
  late TextEditingController _qtyController;
  late TextEditingController _priceController;

  @override
  void initState() {
    super.initState();
    _qtyController = TextEditingController();
    _priceController = TextEditingController();
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final qty = double.tryParse(_qtyController.text) ?? 0;
    final price = double.tryParse(_priceController.text) ?? 0;
    final proceeds = qty * price;

    return Container(
      decoration: BoxDecoration(
        color: AppStyles.getCardColor(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ModalHandle(),
                SizedBox(height: Spacing.lg),
                Text(
                  'Sell Shares',
                  style: AppStyles.titleStyle(context).copyWith(fontSize: 22),
                ),
                SizedBox(height: Spacing.sm),
                Text(
                  'Available: ${widget.currentQty} shares',
                  style: TextStyle(
                    color: AppStyles.getSecondaryTextColor(context),
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: Spacing.xxxl),
                // Quantity
                Text('Shares to Sell', style: TextStyle(color: AppStyles.getTextColor(context), fontWeight: FontWeight.w600)),
                SizedBox(height: Spacing.md),
                CupertinoTextField(
                  controller: _qtyController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  placeholder: '0',
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppStyles.getBackground(context),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  style: TextStyle(color: AppStyles.getTextColor(context)),
                  onChanged: (_) => setState(() {}),
                ),
                SizedBox(height: Spacing.lg),
                // Price
                Text('Selling Price per Share', style: TextStyle(color: AppStyles.getTextColor(context), fontWeight: FontWeight.w600)),
                SizedBox(height: Spacing.md),
                CupertinoTextField(
                  controller: _priceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  placeholder: '0.00',
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppStyles.getBackground(context),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefix: Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Text('₹', style: TextStyle(color: AppStyles.getTextColor(context))),
                  ),
                  style: TextStyle(color: AppStyles.getTextColor(context)),
                  onChanged: (_) => setState(() {}),
                ),
                SizedBox(height: Spacing.lg),
                Container(
                  padding: EdgeInsets.all(Spacing.md),
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Sale Proceeds', style: TextStyle(fontWeight: FontWeight.w600)),
                      Text(
                        '₹${proceeds.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: CupertinoColors.systemGreen,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: Spacing.xl),
                SizedBox(
                  width: double.infinity,
                  child: CupertinoButton.filled(
                    onPressed: qty > 0 && qty <= widget.currentQty && price > 0
                        ? () {
                            toast.showSuccess('Sold $qty shares at ₹$price');
                            Navigator.pop(context);
                          }
                        : null,
                    child: const Text('Confirm Sale'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// SIP Modal
class _SIPModal extends StatefulWidget {
  final Investment investment;
  const _SIPModal({required this.investment});

  @override
  State<_SIPModal> createState() => _SIPModalState();
}

class _SIPModalState extends State<_SIPModal> {
  late TextEditingController _amountController;
  String _frequency = 'Monthly';
  final List<String> frequencies = ['Weekly', 'Monthly', 'Quarterly', 'Yearly'];

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final amount = double.tryParse(_amountController.text) ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: AppStyles.getCardColor(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ModalHandle(),
                SizedBox(height: Spacing.lg),
                Text(
                  'Setup SIP',
                  style: AppStyles.titleStyle(context).copyWith(fontSize: 22),
                ),
                SizedBox(height: Spacing.sm),
                Text(
                  'Set up regular investments',
                  style: TextStyle(
                    color: AppStyles.getSecondaryTextColor(context),
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: Spacing.xxxl),
                // Amount
                Text('Investment Amount', style: TextStyle(color: AppStyles.getTextColor(context), fontWeight: FontWeight.w600)),
                SizedBox(height: Spacing.md),
                CupertinoTextField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  placeholder: '0.00',
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppStyles.getBackground(context),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefix: Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Text('₹', style: TextStyle(color: AppStyles.getTextColor(context))),
                  ),
                  style: TextStyle(color: AppStyles.getTextColor(context)),
                  onChanged: (_) => setState(() {}),
                ),
                SizedBox(height: Spacing.lg),
                // Frequency
                Text('Frequency', style: TextStyle(color: AppStyles.getTextColor(context), fontWeight: FontWeight.w600)),
                SizedBox(height: Spacing.md),
                Container(
                  decoration: BoxDecoration(
                    color: AppStyles.getBackground(context),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: CupertinoSegmentedControl<String>(
                    children: {
                      for (var freq in frequencies) freq: Text(freq),
                    },
                    groupValue: _frequency,
                    onValueChanged: (value) => setState(() => _frequency = value),
                  ),
                ),
                SizedBox(height: Spacing.xl),
                SizedBox(
                  width: double.infinity,
                  child: CupertinoButton.filled(
                    onPressed: amount > 0
                        ? () {
                            toast.showSuccess('SIP setup: ₹$amount $_frequency');
                            Navigator.pop(context);
                          }
                        : null,
                    child: const Text('Setup SIP'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Edit Modal
class _EditModal extends StatefulWidget {
  final Investment investment;
  const _EditModal({required this.investment});

  @override
  State<_EditModal> createState() => _EditModalState();
}

class _EditModalState extends State<_EditModal> {
  late TextEditingController _nameController;
  late TextEditingController _currentValueController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.investment.name);
    _currentValueController = TextEditingController(
      text: (widget.investment.metadata?['currentValue'] as num?)?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _currentValueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppStyles.getCardColor(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ModalHandle(),
                SizedBox(height: Spacing.lg),
                Text(
                  'Edit Investment',
                  style: AppStyles.titleStyle(context).copyWith(fontSize: 22),
                ),
                SizedBox(height: Spacing.sm),
                Text(
                  'Update investment details',
                  style: TextStyle(
                    color: AppStyles.getSecondaryTextColor(context),
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: Spacing.xxxl),
                // Name
                Text('Investment Name', style: TextStyle(color: AppStyles.getTextColor(context), fontWeight: FontWeight.w600)),
                SizedBox(height: Spacing.md),
                CupertinoTextField(
                  controller: _nameController,
                  placeholder: 'Stock name',
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppStyles.getBackground(context),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  style: TextStyle(color: AppStyles.getTextColor(context)),
                ),
                SizedBox(height: Spacing.lg),
                // Current Value
                Text('Current Value', style: TextStyle(color: AppStyles.getTextColor(context), fontWeight: FontWeight.w600)),
                SizedBox(height: Spacing.md),
                CupertinoTextField(
                  controller: _currentValueController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  placeholder: '0.00',
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppStyles.getBackground(context),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefix: Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Text('₹', style: TextStyle(color: AppStyles.getTextColor(context))),
                  ),
                  style: TextStyle(color: AppStyles.getTextColor(context)),
                ),
                SizedBox(height: Spacing.xl),
                SizedBox(
                  width: double.infinity,
                  child: CupertinoButton.filled(
                    onPressed: () {
                      toast.showSuccess('Investment updated');
                      Navigator.pop(context);
                    },
                    child: const Text('Save Changes'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Dividend Modal
class _DividendModal extends StatefulWidget {
  final Investment investment;
  const _DividendModal({required this.investment});

  @override
  State<_DividendModal> createState() => _DividendModalState();
}

class _DividendModalState extends State<_DividendModal> {
  late TextEditingController _amountController;
  late TextEditingController _dateController;
  DateTime _dividendDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController();
    _dateController = TextEditingController(text: _formatDate(_dividendDate));
  }

  @override
  void dispose() {
    _amountController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  void _showDatePicker() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        height: 216,
        padding: const EdgeInsets.only(top: 6.0),
        margin: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: SafeArea(
          top: false,
          child: CupertinoDatePicker(
            initialDateTime: _dividendDate,
            mode: CupertinoDatePickerMode.date,
            onDateTimeChanged: (DateTime newDate) {
              setState(() {
                _dividendDate = newDate;
                _dateController.text = _formatDate(newDate);
              });
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final amount = double.tryParse(_amountController.text) ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: AppStyles.getCardColor(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ModalHandle(),
                SizedBox(height: Spacing.lg),
                Text(
                  'Record Dividend',
                  style: AppStyles.titleStyle(context).copyWith(fontSize: 22),
                ),
                SizedBox(height: Spacing.sm),
                Text(
                  'Add dividend received',
                  style: TextStyle(
                    color: AppStyles.getSecondaryTextColor(context),
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: Spacing.xxxl),
                // Amount
                Text('Dividend Amount', style: TextStyle(color: AppStyles.getTextColor(context), fontWeight: FontWeight.w600)),
                SizedBox(height: Spacing.md),
                CupertinoTextField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  placeholder: '0.00',
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppStyles.getBackground(context),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefix: Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Text('₹', style: TextStyle(color: AppStyles.getTextColor(context))),
                  ),
                  style: TextStyle(color: AppStyles.getTextColor(context)),
                ),
                SizedBox(height: Spacing.lg),
                // Date
                Text('Dividend Date', style: TextStyle(color: AppStyles.getTextColor(context), fontWeight: FontWeight.w600)),
                SizedBox(height: Spacing.md),
                GestureDetector(
                  onTap: _showDatePicker,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppStyles.getBackground(context),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _dateController.text,
                          style: TextStyle(color: AppStyles.getTextColor(context)),
                        ),
                        Icon(CupertinoIcons.calendar, color: AppStyles.getSecondaryTextColor(context)),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: Spacing.xl),
                SizedBox(
                  width: double.infinity,
                  child: CupertinoButton.filled(
                    onPressed: amount > 0
                        ? () {
                            toast.showSuccess('Dividend recorded: ₹$amount');
                            Navigator.pop(context);
                          }
                        : null,
                    child: const Text('Record Dividend'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
