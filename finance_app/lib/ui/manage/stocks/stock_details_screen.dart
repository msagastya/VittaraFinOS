import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/account_model.dart';
import 'package:vittara_fin_os/logic/accounts_controller.dart';
import 'package:vittara_fin_os/logic/investment_model.dart';
import 'package:vittara_fin_os/logic/investments_controller.dart';
import 'package:vittara_fin_os/logic/stock_transaction_model.dart';
import 'package:vittara_fin_os/services/stock_api_service.dart';
import 'package:vittara_fin_os/ui/manage/account_wizard.dart';
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

// Buy More Modal - Detailed multi-step flow
class _BuyMoreModal extends StatefulWidget {
  final Investment investment;
  const _BuyMoreModal({required this.investment});

  @override
  State<_BuyMoreModal> createState() => _BuyMoreModalState();
}

class _BuyMoreModalState extends State<_BuyMoreModal> {
  int _step = 0; // 0: Details, 1: Account, 2: Charges, 3: Review
  late TextEditingController _qtyController;
  late TextEditingController _priceController;
  late TextEditingController _chargesController;
  late TextEditingController _dateController;
  DateTime _transactionDate = DateTime.now();
  Account? _selectedAccount;
  bool _linkAccount = false;

  @override
  void initState() {
    super.initState();
    _qtyController = TextEditingController();
    _priceController = TextEditingController();
    _chargesController = TextEditingController();
    _dateController = TextEditingController(text: _formatDate(_transactionDate));
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _priceController.dispose();
    _chargesController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  double get _qty => double.tryParse(_qtyController.text) ?? 0;
  double get _price => double.tryParse(_priceController.text) ?? 0;
  double get _charges => double.tryParse(_chargesController.text) ?? 0;
  double get _totalCost => (_qty * _price) + _charges;

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
            initialDateTime: _transactionDate,
            mode: CupertinoDatePickerMode.date,
            maximumDate: DateTime.now(),
            onDateTimeChanged: (DateTime newDate) {
              setState(() {
                _transactionDate = newDate;
                _dateController.text = _formatDate(newDate);
              });
            },
          ),
        ),
      ),
    );
  }

  void _showAccountSelector() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => _AccountSelector(
        accountType: AccountType.investment,
        onSelected: (account) {
          setState(() => _selectedAccount = account);
          Navigator.pop(context);
        },
      ),
    );
  }

  Future<void> _saveBuyTransaction() async {
    try {
      // Get current invested amount and quantity
      final currentInvested = widget.investment.amount;
      final currentQty = (widget.investment.metadata?['qty'] as num?)?.toDouble() ?? 0;

      // Calculate new totals
      final newInvested = currentInvested + _totalCost;
      final newQty = currentQty + _qty;

      // Fetch current market price to recalculate current value for all shares
      final symbol = (widget.investment.metadata?['symbol'] as String?) ?? '';
      final apiService = StockApiService();
      double currentMarketPrice = _price; // Default to buy price if fetch fails

      if (symbol.isNotEmpty) {
        final fetchedPrice = await apiService.getStockPrice(symbol);
        if (fetchedPrice != null) {
          currentMarketPrice = fetchedPrice;
        }
      }
      if (!mounted) return;

      // Calculate average cost basis (for all shares combined)
      final averageCostBasis = newQty > 0 ? newInvested / newQty : 0;

      // Calculate new current value for ALL shares
      final newCurrentValue = newQty * currentMarketPrice;

      // Update account if linked
      if (_linkAccount && _selectedAccount != null) {
        final accountsController = Provider.of<AccountsController>(context, listen: false);
        final newBalance = _selectedAccount!.balance - _totalCost;
        accountsController.updateAccount(
          _selectedAccount!.copyWith(balance: newBalance),
        );
      }

      // Update investment with new quantities, average price, and recalculated current value
      final investmentsController = Provider.of<InvestmentsController>(context, listen: false);
      final updatedMetadata = {...?widget.investment.metadata};
      updatedMetadata['qty'] = newQty;
      updatedMetadata['pricePerShare'] = averageCostBasis; // Average cost basis
      updatedMetadata['currentValue'] = newCurrentValue; // Recalculated for all shares

      final updatedInvestment = widget.investment.copyWith(
        amount: newInvested,
        metadata: updatedMetadata,
      );

      investmentsController.updateInvestment(updatedInvestment);
      if (!mounted) return;

      toast.showSuccess('Added $_qty shares!\nTotal: $newQty shares @ ₹${averageCostBasis.toStringAsFixed(2)} avg\nInvested: ₹${newInvested.toStringAsFixed(2)}\nCurrent: ₹${newCurrentValue.toStringAsFixed(2)}');
      Navigator.pop(context);
    } catch (e) {
      toast.showError('Error saving transaction: $e');
    }
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
                // Progress
                Row(
                  children: List.generate(4, (index) {
                    return Expanded(
                      child: Container(
                        height: 4,
                        margin: EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: index <= _step
                              ? SemanticColors.investments
                              : (Theme.of(context).brightness == Brightness.dark
                                  ? Colors.grey[800]
                                  : Colors.grey[300]),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    );
                  }),
                ),
                SizedBox(height: Spacing.lg),
                Text(
                  _step == 0
                      ? 'Buy More Shares'
                      : _step == 1
                          ? 'Link Account (Optional)'
                          : _step == 2
                              ? 'Extra Charges (Optional)'
                              : 'Review & Confirm',
                  style: AppStyles.titleStyle(context).copyWith(fontSize: 22),
                ),
                SizedBox(height: Spacing.sm),
                Text(
                  _step == 0
                      ? 'Enter quantity, price, and date'
                      : _step == 1
                          ? 'Link to account for auto-debit'
                          : _step == 2
                              ? 'Add any extra charges'
                              : 'Confirm your purchase',
                  style: TextStyle(
                    color: AppStyles.getSecondaryTextColor(context),
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: Spacing.xxxl),
                // Step content
                if (_step == 0) ...[
                  _buildStepDetails(),
                ] else if (_step == 1) ...[
                  _buildStepAccountSelection(),
                ] else if (_step == 2) ...[
                  _buildStepCharges(),
                ] else ...[
                  _buildStepReview(),
                ],
                SizedBox(height: Spacing.xl),
                // Navigation buttons
                Row(
                  children: [
                    if (_step > 0)
                      Expanded(
                        child: CupertinoButton(
                          onPressed: () => setState(() => _step--),
                          child: const Text('Back'),
                        ),
                      ),
                    if (_step > 0) SizedBox(width: Spacing.md),
                    Expanded(
                      child: CupertinoButton.filled(
                        onPressed: _step < 3
                            ? () => setState(() => _step++)
                            : (_qty > 0 && _price > 0 ? () => _saveBuyTransaction() : null),
                        child: Text(_step < 3 ? 'Next' : 'Confirm Purchase'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Transaction Input Card
        Container(
          padding: EdgeInsets.all(Spacing.lg),
          decoration: BoxDecoration(
            color: AppStyles.getCardColor(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: SemanticColors.investments.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              // Quantity Field
              _buildInputField(
                icon: CupertinoIcons.cube,
                label: 'Quantity',
                controller: _qtyController,
                placeholder: '0',
                keyboardType: TextInputType.numberWithOptions(decimal: true),
              ),
              SizedBox(height: Spacing.lg),
              // Price per Share Field
              _buildInputField(
                icon: CupertinoIcons.money_dollar_circle,
                label: 'Price per Share',
                controller: _priceController,
                placeholder: '0.00',
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                prefix: '₹',
              ),
              SizedBox(height: Spacing.lg),
              // Date Field
              _buildDateField(
                icon: CupertinoIcons.calendar,
                label: 'Date of Purchase',
                onTap: _showDatePicker,
              ),
            ],
          ),
        ),
        SizedBox(height: Spacing.xl),
        // Cost Summary Card
        Container(
          padding: EdgeInsets.all(Spacing.lg),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                SemanticColors.investments.withValues(alpha: 0.15),
                SemanticColors.investments.withValues(alpha: 0.08),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: SemanticColors.investments.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(Spacing.sm),
                        decoration: BoxDecoration(
                          color: SemanticColors.investments.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          CupertinoIcons.bag,
                          size: 20,
                          color: SemanticColors.investments,
                        ),
                      ),
                      SizedBox(width: Spacing.md),
                      Text(
                        'Base Cost',
                        style: TextStyle(
                          color: AppStyles.getSecondaryTextColor(context),
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '₹${(_qty * _price).toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: AppStyles.getTextColor(context),
                    ),
                  ),
                ],
              ),
              SizedBox(height: Spacing.md),
              Divider(
                color: SemanticColors.investments.withValues(alpha: 0.2),
                height: 1,
              ),
              SizedBox(height: Spacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(Spacing.sm),
                        decoration: BoxDecoration(
                          color: SemanticColors.investments.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          CupertinoIcons.money_yen_circle,
                          size: 20,
                          color: SemanticColors.investments,
                        ),
                      ),
                      SizedBox(width: Spacing.md),
                      Text(
                        'Total Cost',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: AppStyles.getTextColor(context),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '₹${(_qty * _price).toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: SemanticColors.investments,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInputField({
    required IconData icon,
    required String label,
    required TextEditingController controller,
    required String placeholder,
    required TextInputType keyboardType,
    String? prefix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: SemanticColors.investments),
            SizedBox(width: Spacing.sm),
            Text(
              label,
              style: TextStyle(
                color: AppStyles.getTextColor(context),
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
        SizedBox(height: Spacing.md),
        CupertinoTextField(
          controller: controller,
          keyboardType: keyboardType,
          placeholder: placeholder,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            color: AppStyles.getBackground(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppStyles.getSecondaryTextColor(context).withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          prefix: prefix != null
              ? Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Text(prefix, style: TextStyle(color: AppStyles.getSecondaryTextColor(context))),
                )
              : null,
          style: TextStyle(color: AppStyles.getTextColor(context)),
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  Widget _buildDateField({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: SemanticColors.investments),
            SizedBox(width: Spacing.sm),
            Text(
              label,
              style: TextStyle(
                color: AppStyles.getTextColor(context),
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
        SizedBox(height: Spacing.md),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: BoxDecoration(
              color: AppStyles.getBackground(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppStyles.getSecondaryTextColor(context).withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _dateController.text,
                  style: TextStyle(
                    color: AppStyles.getTextColor(context),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Icon(
                  CupertinoIcons.calendar,
                  color: SemanticColors.investments,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStepAccountSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Link Account Toggle
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Link to Account', style: TextStyle(color: AppStyles.getTextColor(context), fontWeight: FontWeight.w600)),
                SizedBox(height: Spacing.xs),
                Text(
                  'Auto-debit the purchase amount',
                  style: TextStyle(color: AppStyles.getSecondaryTextColor(context), fontSize: 12),
                ),
              ],
            ),
            CupertinoSwitch(
              value: _linkAccount,
              onChanged: (value) => setState(() => _linkAccount = value),
            ),
          ],
        ),
        SizedBox(height: Spacing.lg),
        if (_linkAccount) ...[
          if (_selectedAccount != null)
            Container(
              padding: EdgeInsets.all(Spacing.md),
              decoration: BoxDecoration(
                color: SemanticColors.investments.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Selected Account',
                    style: TextStyle(color: AppStyles.getSecondaryTextColor(context), fontSize: 12),
                  ),
                  SizedBox(height: Spacing.sm),
                  Text(
                    _selectedAccount!.name,
                    style: AppStyles.titleStyle(context).copyWith(fontSize: 16),
                  ),
                  SizedBox(height: Spacing.xs),
                  Text(
                    'Balance: ₹${_selectedAccount!.balance.toStringAsFixed(2)}',
                    style: TextStyle(color: AppStyles.getSecondaryTextColor(context)),
                  ),
                ],
              ),
            ),
          SizedBox(height: Spacing.md),
          CupertinoButton.filled(
            onPressed: _showAccountSelector,
            child: Text(_selectedAccount != null ? 'Change Account' : 'Select Account'),
          ),
        ],
      ],
    );
  }

  Widget _buildStepCharges() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Charges Input Card
        Container(
          padding: EdgeInsets.all(Spacing.lg),
          decoration: BoxDecoration(
            color: AppStyles.getCardColor(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: SemanticColors.investments.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(CupertinoIcons.plus_circle, size: 18, color: CupertinoColors.systemOrange),
                  SizedBox(width: Spacing.sm),
                  Text(
                    'Extra Charges (Optional)',
                    style: TextStyle(
                      color: AppStyles.getTextColor(context),
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              SizedBox(height: Spacing.sm),
              Text(
                'Brokerage fees, commissions, or taxes',
                style: TextStyle(
                  color: AppStyles.getSecondaryTextColor(context),
                  fontSize: 12,
                ),
              ),
              SizedBox(height: Spacing.lg),
              CupertinoTextField(
                controller: _chargesController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                placeholder: '0.00',
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                decoration: BoxDecoration(
                  color: AppStyles.getBackground(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppStyles.getSecondaryTextColor(context).withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                prefix: Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Text('₹', style: TextStyle(color: AppStyles.getSecondaryTextColor(context))),
                ),
                style: TextStyle(color: AppStyles.getTextColor(context)),
                onChanged: (_) => setState(() {}),
              ),
            ],
          ),
        ),
        SizedBox(height: Spacing.xl),
        // Breakdown Card
        Container(
          padding: EdgeInsets.all(Spacing.lg),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                SemanticColors.investments.withValues(alpha: 0.15),
                SemanticColors.investments.withValues(alpha: 0.08),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: SemanticColors.investments.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Purchase Cost', style: TextStyle(fontWeight: FontWeight.w600)),
                  Text('₹${(_qty * _price).toStringAsFixed(2)}'),
                ],
              ),
              SizedBox(height: Spacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Extra Charges', style: TextStyle(fontWeight: FontWeight.w600)),
                  Text('₹${_charges.toStringAsFixed(2)}'),
                ],
              ),
              Divider(height: Spacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Amount', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(
                    '₹${_totalCost.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: SemanticColors.investments),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStepReview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.all(Spacing.lg),
          decoration: BoxDecoration(
            color: AppStyles.getBackground(context),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              _reviewRow('Quantity', '$_qty shares'),
              _reviewRow('Price per Share', '₹${_price.toStringAsFixed(2)}'),
              _reviewRow('Purchase Cost', '₹${(_qty * _price).toStringAsFixed(2)}'),
              if (_charges > 0) _reviewRow('Extra Charges', '₹${_charges.toStringAsFixed(2)}'),
              _reviewRow('Date', _dateController.text),
              if (_linkAccount && _selectedAccount != null) ...[
                SizedBox(height: Spacing.md),
                Divider(),
                SizedBox(height: Spacing.md),
                _reviewRow('Linked Account', _selectedAccount!.name),
                _reviewRow('Account Balance', '₹${_selectedAccount!.balance.toStringAsFixed(2)}'),
                _reviewRow(
                  'Balance After Purchase',
                  '₹${(_selectedAccount!.balance - _totalCost).toStringAsFixed(2)}',
                  isHighlight: true,
                ),
              ],
              SizedBox(height: Spacing.md),
              Divider(),
              SizedBox(height: Spacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Amount', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(
                    '₹${_totalCost.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: SemanticColors.investments),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _reviewRow(String label, String value, {bool isHighlight = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: Spacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: AppStyles.getSecondaryTextColor(context))),
          Text(
            value,
            style: TextStyle(
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.w500,
              color: isHighlight ? SemanticColors.investments : null,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

// Sell Modal - Similar detailed flow
class _SellModal extends StatefulWidget {
  final Investment investment;
  final double currentQty;
  const _SellModal({required this.investment, required this.currentQty});

  @override
  State<_SellModal> createState() => _SellModalState();
}

class _SellModalState extends State<_SellModal> {
  int _step = 0;
  late TextEditingController _qtyController;
  late TextEditingController _priceController;
  late TextEditingController _chargesController;
  late TextEditingController _dateController;
  DateTime _transactionDate = DateTime.now();
  Account? _selectedAccount;
  bool _linkAccount = false;

  @override
  void initState() {
    super.initState();
    _qtyController = TextEditingController();
    _priceController = TextEditingController();
    _chargesController = TextEditingController();
    _dateController = TextEditingController(text: _formatDate(_transactionDate));
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _priceController.dispose();
    _chargesController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  double get _qty => double.tryParse(_qtyController.text) ?? 0;
  double get _price => double.tryParse(_priceController.text) ?? 0;
  double get _charges => double.tryParse(_chargesController.text) ?? 0;
  double get _grossProceeds => _qty * _price;
  double get _netProceeds => _grossProceeds - _charges;

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
            initialDateTime: _transactionDate,
            mode: CupertinoDatePickerMode.date,
            maximumDate: DateTime.now(),
            onDateTimeChanged: (DateTime newDate) {
              setState(() {
                _transactionDate = newDate;
                _dateController.text = _formatDate(newDate);
              });
            },
          ),
        ),
      ),
    );
  }

  void _showAccountSelector() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => _AccountSelector(
        accountType: AccountType.savings,
        onSelected: (account) {
          setState(() => _selectedAccount = account);
          Navigator.pop(context);
        },
      ),
    );
  }

  Future<void> _saveSellTransaction() async {
    try {
      // Get current invested amount and quantity
      final currentInvested = widget.investment.amount;
      final currentQty = (widget.currentQty);

      // Calculate cost per share (average cost basis)
      final costPerShare = currentQty > 0 ? currentInvested / currentQty : 0;

      // Calculate reduction in invested amount (proportional)
      final investmentReduction = _qty * costPerShare;
      final newInvested = currentInvested - investmentReduction;
      final newQty = currentQty - _qty;

      // Fetch current market price to recalculate current value for remaining shares
      final symbol = (widget.investment.metadata?['symbol'] as String?) ?? '';
      final apiService = StockApiService();
      double currentMarketPrice = _price; // Default to sell price if fetch fails

      if (symbol.isNotEmpty) {
        final fetchedPrice = await apiService.getStockPrice(symbol);
        if (fetchedPrice != null) {
          currentMarketPrice = fetchedPrice;
        }
      }
      if (!mounted) return;

      // Calculate new average cost basis for remaining shares
      final newAverageCostBasis = newQty > 0 ? newInvested / newQty : 0;

      // Calculate new current value for remaining shares
      final newCurrentValue = newQty * currentMarketPrice;

      // Update account if linked (credit proceeds)
      if (_linkAccount && _selectedAccount != null) {
        final accountsController = Provider.of<AccountsController>(context, listen: false);
        final newBalance = _selectedAccount!.balance + _netProceeds;
        accountsController.updateAccount(
          _selectedAccount!.copyWith(balance: newBalance),
        );
      }

      // Update investment with new quantities, average price, and recalculated current value
      final investmentsController = Provider.of<InvestmentsController>(context, listen: false);
      final updatedMetadata = {...?widget.investment.metadata};
      updatedMetadata['qty'] = newQty;
      updatedMetadata['pricePerShare'] = newAverageCostBasis; // Average cost basis for remaining
      updatedMetadata['currentValue'] = newCurrentValue; // Recalculated for remaining shares

      final updatedInvestment = widget.investment.copyWith(
        amount: newInvested > 0 ? newInvested : 0,
        metadata: updatedMetadata,
      );

      investmentsController.updateInvestment(updatedInvestment);
      if (!mounted) return;

      toast.showSuccess('Sold $_qty shares!\nRemaining: $newQty shares @ ₹${newAverageCostBasis.toStringAsFixed(2)} avg\nProceeds: ₹${_netProceeds.toStringAsFixed(2)}\nCurrent: ₹${newCurrentValue.toStringAsFixed(2)}');
      Navigator.pop(context);
    } catch (e) {
      toast.showError('Error saving transaction: $e');
    }
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
                Row(
                  children: List.generate(4, (index) {
                    return Expanded(
                      child: Container(
                        height: 4,
                        margin: EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: index <= _step
                              ? CupertinoColors.systemRed
                              : (Theme.of(context).brightness == Brightness.dark
                                  ? Colors.grey[800]
                                  : Colors.grey[300]),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    );
                  }),
                ),
                SizedBox(height: Spacing.lg),
                Text(
                  _step == 0
                      ? 'Sell Shares'
                      : _step == 1
                          ? 'Link Account (Optional)'
                          : _step == 2
                              ? 'Extra Charges (Optional)'
                              : 'Review & Confirm',
                  style: AppStyles.titleStyle(context).copyWith(fontSize: 22),
                ),
                SizedBox(height: Spacing.sm),
                Text(
                  _step == 0
                      ? 'Available: ${widget.currentQty} shares'
                      : _step == 1
                          ? 'Credit proceeds to account'
                          : _step == 2
                              ? 'Deduct any broker charges'
                              : 'Confirm your sale',
                  style: TextStyle(
                    color: AppStyles.getSecondaryTextColor(context),
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: Spacing.xxxl),
                if (_step == 0) ...[
                  _buildStepDetails(),
                ] else if (_step == 1) ...[
                  _buildStepAccountSelection(),
                ] else if (_step == 2) ...[
                  _buildStepCharges(),
                ] else ...[
                  _buildStepReview(),
                ],
                SizedBox(height: Spacing.xl),
                Row(
                  children: [
                    if (_step > 0)
                      Expanded(
                        child: CupertinoButton(
                          onPressed: () => setState(() => _step--),
                          child: const Text('Back'),
                        ),
                      ),
                    if (_step > 0) SizedBox(width: Spacing.md),
                    Expanded(
                      child: CupertinoButton.filled(
                        onPressed: _step < 3
                            ? () => setState(() => _step++)
                            : (_qty > 0 && _qty <= widget.currentQty && _price > 0
                                ? () => _saveSellTransaction()
                                : null),
                        child: Text(_step < 3 ? 'Next' : 'Confirm Sale'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
        Text('Date of Sale', style: TextStyle(color: AppStyles.getTextColor(context), fontWeight: FontWeight.w600)),
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
              const Text('Gross Proceeds', style: TextStyle(fontWeight: FontWeight.w600)),
              Text(
                '₹${_grossProceeds.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: CupertinoColors.systemGreen,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStepAccountSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Link to Account', style: TextStyle(color: AppStyles.getTextColor(context), fontWeight: FontWeight.w600)),
                SizedBox(height: Spacing.xs),
                Text(
                  'Auto-credit the sale proceeds',
                  style: TextStyle(color: AppStyles.getSecondaryTextColor(context), fontSize: 12),
                ),
              ],
            ),
            CupertinoSwitch(
              value: _linkAccount,
              onChanged: (value) => setState(() => _linkAccount = value),
            ),
          ],
        ),
        SizedBox(height: Spacing.lg),
        if (_linkAccount) ...[
          if (_selectedAccount != null)
            Container(
              padding: EdgeInsets.all(Spacing.md),
              decoration: BoxDecoration(
                color: CupertinoColors.systemGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Selected Account',
                    style: TextStyle(color: AppStyles.getSecondaryTextColor(context), fontSize: 12),
                  ),
                  SizedBox(height: Spacing.sm),
                  Text(
                    _selectedAccount!.name,
                    style: AppStyles.titleStyle(context).copyWith(fontSize: 16),
                  ),
                  SizedBox(height: Spacing.xs),
                  Text(
                    'Current Balance: ₹${_selectedAccount!.balance.toStringAsFixed(2)}',
                    style: TextStyle(color: AppStyles.getSecondaryTextColor(context)),
                  ),
                ],
              ),
            ),
          SizedBox(height: Spacing.md),
          CupertinoButton.filled(
            onPressed: _showAccountSelector,
            child: Text(_selectedAccount != null ? 'Change Account' : 'Select Account'),
          ),
        ],
      ],
    );
  }

  Widget _buildStepCharges() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Extra Charges (Optional)', style: TextStyle(color: AppStyles.getTextColor(context), fontWeight: FontWeight.w600)),
        SizedBox(height: Spacing.sm),
        Text(
          'Brokerage fees, taxes, or other charges',
          style: TextStyle(color: AppStyles.getSecondaryTextColor(context), fontSize: 12),
        ),
        SizedBox(height: Spacing.md),
        CupertinoTextField(
          controller: _chargesController,
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
            color: AppStyles.getBackground(context),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Gross Proceeds', style: TextStyle(fontWeight: FontWeight.w600)),
                  Text('₹${_grossProceeds.toStringAsFixed(2)}'),
                ],
              ),
              SizedBox(height: Spacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Extra Charges', style: TextStyle(fontWeight: FontWeight.w600)),
                  Text('- ₹${_charges.toStringAsFixed(2)}'),
                ],
              ),
              Divider(height: Spacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Net Proceeds', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(
                    '₹${_netProceeds.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: CupertinoColors.systemGreen),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStepReview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.all(Spacing.lg),
          decoration: BoxDecoration(
            color: AppStyles.getBackground(context),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              _reviewRow('Quantity', '$_qty shares'),
              _reviewRow('Selling Price', '₹${_price.toStringAsFixed(2)}'),
              _reviewRow('Gross Proceeds', '₹${_grossProceeds.toStringAsFixed(2)}'),
              if (_charges > 0) _reviewRow('Charges', '- ₹${_charges.toStringAsFixed(2)}'),
              _reviewRow('Date', _dateController.text),
              if (_linkAccount && _selectedAccount != null) ...[
                SizedBox(height: Spacing.md),
                Divider(),
                SizedBox(height: Spacing.md),
                _reviewRow('Credit to Account', _selectedAccount!.name),
                _reviewRow('Current Balance', '₹${_selectedAccount!.balance.toStringAsFixed(2)}'),
                _reviewRow(
                  'Balance After Sale',
                  '₹${(_selectedAccount!.balance + _netProceeds).toStringAsFixed(2)}',
                  isHighlight: true,
                ),
              ],
              SizedBox(height: Spacing.md),
              Divider(),
              SizedBox(height: Spacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Net Proceeds', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(
                    '₹${_netProceeds.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: CupertinoColors.systemGreen),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _reviewRow(String label, String value, {bool isHighlight = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: Spacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: AppStyles.getSecondaryTextColor(context))),
          Text(
            value,
            style: TextStyle(
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.w500,
              color: isHighlight ? CupertinoColors.systemGreen : null,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

// SIP Modal - Detailed setup with account selection
class _SIPModal extends StatefulWidget {
  final Investment investment;
  const _SIPModal({required this.investment});

  @override
  State<_SIPModal> createState() => _SIPModalState();
}

class _SIPModalState extends State<_SIPModal> {
  int _step = 0; // 0: Start Date, 1: Type, 2: Amount, 3: Frequency, 4: Account, 5: Review
  late TextEditingController _amountController;
  late TextEditingController _qtyController;
  late TextEditingController _chargesController;
  late TextEditingController _dateController;
  bool _isFixedAmount = true;
  String _frequency = 'Monthly';
  final List<String> frequencies = ['Weekly', 'Monthly', 'Quarterly', 'Yearly'];
  Account? _selectedAccount;
  bool _linkAccount = false;
  DateTime _sipStartDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController();
    _qtyController = TextEditingController();
    _chargesController = TextEditingController();
    _dateController = TextEditingController(text: _formatDate(DateTime.now()));
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
            initialDateTime: _sipStartDate,
            mode: CupertinoDatePickerMode.date,
            onDateTimeChanged: (DateTime newDate) {
              setState(() {
                _sipStartDate = newDate;
                _dateController.text = _formatDate(newDate);
              });
            },
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  @override
  void dispose() {
    _amountController.dispose();
    _qtyController.dispose();
    _chargesController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  double get _amount => double.tryParse(_amountController.text) ?? 0;
  double get _qty => double.tryParse(_qtyController.text) ?? 0;
  double get _charges => double.tryParse(_chargesController.text) ?? 0;

  void _showAccountSelector() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => _AccountSelector(
        accountType: AccountType.savings,
        onSelected: (account) {
          setState(() => _selectedAccount = account);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _saveSIP() {
    try {
      // Get current state of investment
      final currentInvested = widget.investment.amount;
      final currentQty = (widget.investment.metadata?['qty'] as num?)?.toDouble() ?? 0;
      final currentPrice = (widget.investment.metadata?['pricePerShare'] as num?)?.toDouble() ?? 0;

      // Fetch current market price for calculation
      // For now, use current price or default to price from metadata
      final marketPrice = currentPrice > 0 ? currentPrice : 1;

      // Calculate first execution values
      double firstTransactionQty = 0;
      double firstTransactionAmount = 0;

      if (_isFixedAmount) {
        // Fixed amount: calculate qty = amount / marketPrice
        firstTransactionAmount = _amount;
        firstTransactionQty = _amount > 0 ? _amount / marketPrice : 0;
      } else {
        // Fixed quantity: amount = qty * marketPrice
        firstTransactionQty = _qty;
        firstTransactionAmount = _qty * marketPrice;
      }

      // Update account if linked (debit for first transaction)
      if (_linkAccount && _selectedAccount != null) {
        final accountsController = Provider.of<AccountsController>(context, listen: false);
        final newBalance = _selectedAccount!.balance - firstTransactionAmount;
        accountsController.updateAccount(
          _selectedAccount!.copyWith(balance: newBalance),
        );
      }

      // Update investment with first SIP execution added to current holdings
      final investmentsController = Provider.of<InvestmentsController>(context, listen: false);
      final newTotalInvested = currentInvested + firstTransactionAmount;
      final newTotalQty = currentQty + firstTransactionQty;

      final updatedMetadata = {...?widget.investment.metadata};
      updatedMetadata['qty'] = newTotalQty;
      updatedMetadata['pricePerShare'] = marketPrice;
      updatedMetadata['sipActive'] = true;
      updatedMetadata['sipStartDate'] = _sipStartDate.toIso8601String();
      updatedMetadata['sipType'] = _isFixedAmount ? 'amount' : 'quantity';
      updatedMetadata['sipAmount'] = _isFixedAmount ? _amount : null;
      updatedMetadata['sipQty'] = !_isFixedAmount ? _qty : null;
      updatedMetadata['sipFrequency'] = _frequency;
      updatedMetadata['sipLinkedAccount'] = _linkAccount ? _selectedAccount?.id : null;
      updatedMetadata['sipLastExecutionDate'] = _sipStartDate.toIso8601String();
      updatedMetadata['sipExecutionLog'] = [
        {
          'date': _sipStartDate.toIso8601String(),
          'type': _isFixedAmount ? 'amount' : 'quantity',
          'value': _isFixedAmount ? _amount : _qty,
          'qty': firstTransactionQty,
          'amount': firstTransactionAmount,
          'price': marketPrice,
        }
      ];

      final updatedInvestment = widget.investment.copyWith(
        amount: newTotalInvested,
        metadata: updatedMetadata,
      );

      investmentsController.updateInvestment(updatedInvestment);

      toast.showSuccess(
        'SIP started successfully!\n'
        '${_isFixedAmount ? '₹${_amount.toStringAsFixed(2)}/month' : '${_qty.toStringAsFixed(2)} shares/month'}\n'
        'First execution: ${firstTransactionQty.toStringAsFixed(2)} shares @ ₹${marketPrice.toStringAsFixed(2)}',
      );
      Navigator.pop(context);
    } catch (e) {
      toast.showError('Error setting up SIP: $e');
    }
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
                Row(
                  children: List.generate(6, (index) {
                    return Expanded(
                      child: Container(
                        height: 4,
                        margin: EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: index <= _step
                              ? CupertinoColors.systemBlue
                              : (Theme.of(context).brightness == Brightness.dark
                                  ? Colors.grey[800]
                                  : Colors.grey[300]),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    );
                  }),
                ),
                SizedBox(height: Spacing.lg),
                Text(
                  _step == 0
                      ? 'Start Date'
                      : _step == 1
                          ? 'Investment Type'
                          : _step == 2
                              ? 'Investment Amount'
                              : _step == 3
                                  ? 'Frequency'
                                  : _step == 4
                                      ? 'Link Account'
                                      : 'Review & Confirm',
                  style: AppStyles.titleStyle(context).copyWith(fontSize: 22),
                ),
                SizedBox(height: Spacing.sm),
                Text(
                  _step == 0
                      ? 'When should your SIP start?'
                      : _step == 1
                          ? 'Fixed amount or fixed quantity?'
                          : _step == 2
                              ? 'How much per SIP installment?'
                              : _step == 3
                                  ? 'How often to invest?'
                                  : _step == 4
                                      ? 'Link debit account (optional)'
                                      : 'Confirm your SIP setup',
                  style: TextStyle(
                    color: AppStyles.getSecondaryTextColor(context),
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: Spacing.xxxl),
                if (_step == 0) ...[
                  _buildStepStartDate(),
                ] else if (_step == 1) ...[
                  _buildStepType(),
                ] else if (_step == 2) ...[
                  _buildStepAmount(),
                ] else if (_step == 3) ...[
                  _buildStepFrequency(),
                ] else if (_step == 4) ...[
                  _buildStepAccount(),
                ] else ...[
                  _buildStepReview(),
                ],
                SizedBox(height: Spacing.xl),
                Row(
                  children: [
                    if (_step > 0)
                      Expanded(
                        child: CupertinoButton(
                          onPressed: () => setState(() => _step--),
                          child: const Text('Back'),
                        ),
                      ),
                    if (_step > 0) SizedBox(width: Spacing.md),
                    Expanded(
                      child: CupertinoButton.filled(
                        onPressed: _step < 5
                            ? () => setState(() => _step++)
                            : (_isFixedAmount ? _amount > 0 : _qty > 0) ? _saveSIP : null,
                        child: Text(_step < 5 ? 'Next' : 'Setup SIP'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepStartDate() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SIP Start Date',
          style: TextStyle(
            color: AppStyles.getTextColor(context),
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        SizedBox(height: Spacing.md),
        GestureDetector(
          onTap: _showDatePicker,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: BoxDecoration(
              color: AppStyles.getBackground(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppStyles.getSecondaryTextColor(context).withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _dateController.text,
                  style: TextStyle(
                    color: AppStyles.getTextColor(context),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Icon(
                  CupertinoIcons.calendar,
                  color: CupertinoColors.systemBlue,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: Spacing.lg),
        Container(
          padding: EdgeInsets.all(Spacing.md),
          decoration: BoxDecoration(
            color: CupertinoColors.systemBlue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    CupertinoIcons.info,
                    size: 16,
                    color: CupertinoColors.systemBlue,
                  ),
                  SizedBox(width: Spacing.sm),
                  Expanded(
                    child: Text(
                      'SIP will start on the selected date. First transaction will be processed immediately.',
                      style: TextStyle(
                        color: AppStyles.getSecondaryTextColor(context),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStepType() {
    return Column(
      children: [
        _buildTypeCard(
          'Fixed Amount',
          'Invest the same amount each time',
          _isFixedAmount,
          () => setState(() => _isFixedAmount = true),
        ),
        SizedBox(height: Spacing.lg),
        _buildTypeCard(
          'Fixed Quantity',
          'Buy the same number of shares each time',
          !_isFixedAmount,
          () => setState(() => _isFixedAmount = false),
        ),
      ],
    );
  }

  Widget _buildTypeCard(String title, String subtitle, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(Spacing.lg),
        decoration: BoxDecoration(
          color: isSelected ? SemanticColors.investments.withValues(alpha: 0.1) : AppStyles.getBackground(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? SemanticColors.investments : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? SemanticColors.investments : AppStyles.getSecondaryTextColor(context),
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: SemanticColors.investments,
                        ),
                      ),
                    )
                  : null,
            ),
            SizedBox(width: Spacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppStyles.getTextColor(context),
                    ),
                  ),
                  SizedBox(height: Spacing.xs),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppStyles.getSecondaryTextColor(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepAmount() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _isFixedAmount ? 'Amount per SIP' : 'Shares per SIP',
          style: TextStyle(color: AppStyles.getTextColor(context), fontWeight: FontWeight.w600),
        ),
        SizedBox(height: Spacing.md),
        CupertinoTextField(
          controller: _isFixedAmount ? _amountController : _qtyController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          placeholder: '0.00',
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppStyles.getBackground(context),
            borderRadius: BorderRadius.circular(12),
          ),
          prefix: Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Text(_isFixedAmount ? '₹' : 'Qty', style: TextStyle(color: AppStyles.getTextColor(context))),
          ),
          style: TextStyle(color: AppStyles.getTextColor(context)),
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  Widget _buildStepFrequency() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Select Frequency', style: TextStyle(color: AppStyles.getTextColor(context), fontWeight: FontWeight.w600)),
        SizedBox(height: Spacing.lg),
        Wrap(
          spacing: Spacing.md,
          runSpacing: Spacing.md,
          children: frequencies.map((freq) {
            return GestureDetector(
              onTap: () => setState(() => _frequency = freq),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.md),
                decoration: BoxDecoration(
                  color: _frequency == freq
                      ? CupertinoColors.systemBlue.withValues(alpha: 0.1)
                      : AppStyles.getBackground(context),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _frequency == freq
                        ? CupertinoColors.systemBlue
                        : Colors.transparent,
                  ),
                ),
                child: Text(
                  freq,
                  style: TextStyle(
                    fontWeight: _frequency == freq ? FontWeight.bold : FontWeight.w500,
                    color: AppStyles.getTextColor(context),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildStepAccount() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Link to Account', style: TextStyle(color: AppStyles.getTextColor(context), fontWeight: FontWeight.w600)),
                SizedBox(height: Spacing.xs),
                Text(
                  'Auto-debit each SIP installment',
                  style: TextStyle(color: AppStyles.getSecondaryTextColor(context), fontSize: 12),
                ),
              ],
            ),
            CupertinoSwitch(
              value: _linkAccount,
              onChanged: (value) => setState(() => _linkAccount = value),
            ),
          ],
        ),
        SizedBox(height: Spacing.lg),
        if (_linkAccount) ...[
          if (_selectedAccount != null)
            Container(
              padding: EdgeInsets.all(Spacing.md),
              decoration: BoxDecoration(
                color: CupertinoColors.systemBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Selected Account',
                    style: TextStyle(color: AppStyles.getSecondaryTextColor(context), fontSize: 12),
                  ),
                  SizedBox(height: Spacing.sm),
                  Text(
                    _selectedAccount!.name,
                    style: AppStyles.titleStyle(context).copyWith(fontSize: 16),
                  ),
                  SizedBox(height: Spacing.xs),
                  Text(
                    'Balance: ₹${_selectedAccount!.balance.toStringAsFixed(2)}',
                    style: TextStyle(color: AppStyles.getSecondaryTextColor(context)),
                  ),
                ],
              ),
            ),
          SizedBox(height: Spacing.md),
          CupertinoButton.filled(
            onPressed: _showAccountSelector,
            child: Text(_selectedAccount != null ? 'Change Account' : 'Select Account'),
          ),
        ],
      ],
    );
  }

  Widget _buildStepReview() {
    return Container(
      padding: EdgeInsets.all(Spacing.lg),
      decoration: BoxDecoration(
        color: AppStyles.getBackground(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _reviewRow('Type', _isFixedAmount ? 'Fixed Amount' : 'Fixed Quantity'),
          _reviewRow(
            _isFixedAmount ? 'Amount per SIP' : 'Shares per SIP',
            _isFixedAmount ? '₹${_amount.toStringAsFixed(2)}' : '$_qty shares',
          ),
          _reviewRow('Frequency', _frequency),
          if (_linkAccount && _selectedAccount != null) ...[
            SizedBox(height: Spacing.md),
            Divider(),
            SizedBox(height: Spacing.md),
            _reviewRow('Debit Account', _selectedAccount!.name),
            _reviewRow('Account Balance', '₹${_selectedAccount!.balance.toStringAsFixed(2)}'),
          ],
        ],
      ),
    );
  }

  Widget _reviewRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: Spacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: AppStyles.getSecondaryTextColor(context))),
          Text(value, style: TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// Placeholder modals for Edit and Dividend - can be expanded later
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
                SizedBox(height: Spacing.xxxl),
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
  Account? _selectedAccount;
  bool _linkAccount = true; // Default to linking account

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

  void _showAccountSelector() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => _AccountSelector(
        accountType: AccountType.savings,
        onSelected: (account) {
          setState(() => _selectedAccount = account);
          Navigator.pop(context);
        },
      ),
    );
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
                  'Total dividend amount received',
                  style: TextStyle(
                    color: AppStyles.getSecondaryTextColor(context),
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: Spacing.xxxl),
                // Input Card
                Container(
                  padding: EdgeInsets.all(Spacing.lg),
                  decoration: BoxDecoration(
                    color: AppStyles.getCardColor(context),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: CupertinoColors.systemBrown.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Dividend Amount
                      Row(
                        children: [
                          Icon(CupertinoIcons.money_dollar_circle, size: 18, color: CupertinoColors.systemBrown),
                          SizedBox(width: Spacing.sm),
                          Text(
                            'Dividend Amount',
                            style: TextStyle(
                              color: AppStyles.getTextColor(context),
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: Spacing.md),
                      CupertinoTextField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        placeholder: '0.00',
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                        decoration: BoxDecoration(
                          color: AppStyles.getBackground(context),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppStyles.getSecondaryTextColor(context).withValues(alpha: 0.2),
                            width: 1,
                          ),
                        ),
                        prefix: Padding(
                          padding: const EdgeInsets.only(left: 16),
                          child: Text('₹', style: TextStyle(color: AppStyles.getSecondaryTextColor(context))),
                        ),
                        style: TextStyle(color: AppStyles.getTextColor(context)),
                        onChanged: (_) => setState(() {}),
                      ),
                      SizedBox(height: Spacing.lg),
                      // Dividend Date
                      Row(
                        children: [
                          Icon(CupertinoIcons.calendar, size: 18, color: CupertinoColors.systemBrown),
                          SizedBox(width: Spacing.sm),
                          Text(
                            'Dividend Date',
                            style: TextStyle(
                              color: AppStyles.getTextColor(context),
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: Spacing.md),
                      GestureDetector(
                        onTap: _showDatePicker,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                          decoration: BoxDecoration(
                            color: AppStyles.getBackground(context),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppStyles.getSecondaryTextColor(context).withValues(alpha: 0.2),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _dateController.text,
                                style: TextStyle(
                                  color: AppStyles.getTextColor(context),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Icon(CupertinoIcons.calendar, color: CupertinoColors.systemBrown, size: 18),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: Spacing.xl),
                // Account Selection Card
                Container(
                  padding: EdgeInsets.all(Spacing.lg),
                  decoration: BoxDecoration(
                    color: AppStyles.getCardColor(context),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: CupertinoColors.systemBrown.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(CupertinoIcons.building_2_fill, size: 18, color: CupertinoColors.systemBrown),
                              SizedBox(width: Spacing.sm),
                              Text(
                                'Credit to Account',
                                style: TextStyle(
                                  color: AppStyles.getTextColor(context),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            'Required',
                            style: TextStyle(
                              color: CupertinoColors.systemRed,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: Spacing.lg),
                      if (_selectedAccount != null) ...[
                        Container(
                          padding: EdgeInsets.all(Spacing.md),
                          decoration: BoxDecoration(
                            color: CupertinoColors.systemBrown.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedAccount!.name,
                                style: TextStyle(
                                  color: AppStyles.getTextColor(context),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              SizedBox(height: Spacing.xs),
                              Text(
                                'Balance: ₹${_selectedAccount!.balance.toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: AppStyles.getSecondaryTextColor(context),
                                  fontSize: 12,
                                ),
                              ),
                              if (amount > 0) ...[
                                SizedBox(height: Spacing.xs),
                                Text(
                                  'After credit: ₹${(_selectedAccount!.balance + amount).toStringAsFixed(2)}',
                                  style: TextStyle(
                                    color: CupertinoColors.systemGreen,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        SizedBox(height: Spacing.md),
                      ],
                      SizedBox(
                        width: double.infinity,
                        child: CupertinoButton(
                          onPressed: _showAccountSelector,
                          child: Text(_selectedAccount != null ? 'Change Account' : 'Select Account'),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: Spacing.xl),
                SizedBox(
                  width: double.infinity,
                  child: CupertinoButton.filled(
                    onPressed: amount > 0 && _selectedAccount != null
                        ? () {
                            final accountsController = Provider.of<AccountsController>(context, listen: false);
                            final newBalance = _selectedAccount!.balance + amount;
                            accountsController.updateAccount(
                              _selectedAccount!.copyWith(balance: newBalance),
                            );
                            toast.showSuccess('Dividend recorded: ₹${amount.toStringAsFixed(2)} credited to ${_selectedAccount!.name}');
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

// Account Selector Widget
class _AccountSelector extends StatelessWidget {
  final AccountType accountType;
  final Function(Account) onSelected;

  const _AccountSelector({
    required this.accountType,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppStyles.getCardColor(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Consumer<AccountsController>(
        builder: (context, controller, _) {
          final accounts = controller.accounts.where((a) => a.type == accountType).toList();

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const ModalHandle(),
                    SizedBox(height: Spacing.lg),
                    Text(
                      'Select Account',
                      style: AppStyles.titleStyle(context).copyWith(fontSize: 22),
                    ),
                    SizedBox(height: Spacing.xxxl),
                    if (accounts.isEmpty)
                      Center(
                        child: Text(
                          'No accounts found',
                          style: TextStyle(color: AppStyles.getSecondaryTextColor(context)),
                        ),
                      )
                    else
                      ...accounts.map((account) {
                        return GestureDetector(
                          onTap: () => onSelected(account),
                          child: Container(
                            margin: EdgeInsets.only(bottom: Spacing.lg),
                            padding: EdgeInsets.all(Spacing.lg),
                            decoration: BoxDecoration(
                              color: AppStyles.getBackground(context),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  account.name,
                                  style: AppStyles.titleStyle(context),
                                ),
                                SizedBox(height: Spacing.xs),
                                Text(
                                  account.bankName,
                                  style: TextStyle(
                                    color: AppStyles.getSecondaryTextColor(context),
                                    fontSize: 12,
                                  ),
                                ),
                                SizedBox(height: Spacing.sm),
                                Text(
                                  '₹${account.balance.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: account.color,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
