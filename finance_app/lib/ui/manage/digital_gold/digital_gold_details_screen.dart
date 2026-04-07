import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/investment_model.dart';
import 'package:vittara_fin_os/logic/investments_controller.dart';
import 'package:vittara_fin_os/services/gold_price_service.dart';
import 'package:vittara_fin_os/utils/date_formatter.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/widgets/toast_notification.dart';
import 'package:vittara_fin_os/utils/logger.dart';

class DigitalGoldDetailsScreen extends StatefulWidget {
  final Investment investment;

  const DigitalGoldDetailsScreen({super.key, required this.investment});

  @override
  State<DigitalGoldDetailsScreen> createState() =>
      _DigitalGoldDetailsScreenState();
}

class _DigitalGoldDetailsScreenState extends State<DigitalGoldDetailsScreen> {
  final AppLogger logger = AppLogger();
  late Investment _investment;
  double? currentGoldPrice;
  bool isFetchingPrice = false;
  DateTime? _goldPriceLastFetched;

  @override
  void initState() {
    super.initState();
    _investment = widget.investment;
    _fetchCurrentGoldPrice();
  }

  Future<void> _fetchCurrentGoldPrice() async {
    if (!mounted) return;
    setState(() {
      isFetchingPrice = true;
    });

    try {
      final price = await GoldPriceService.fetchCurrentGoldPrice();
      final lastFetched = await GoldPriceService.getLastFetchedTime();
      if (mounted) {
        setState(() {
          currentGoldPrice = price;
          _goldPriceLastFetched = lastFetched;
          isFetchingPrice = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isFetchingPrice = false;
        });
        logger.error('Failed to fetch gold price: $e',
            context: 'DigitalGoldDetails');
      }
    }
  }

  String _formatLastUpdated(DateTime? dt) {
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  void _showEditModal() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => _EditModal(investment: _investment),
    );
  }

  void _showDeleteConfirmation() {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Delete Investment'),
        content: const Text(
            'Are you sure you want to delete this investment? This action cannot be undone.'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Delete'),
            onPressed: () {
              final controller =
                  Provider.of<InvestmentsController>(context, listen: false);
              controller.deleteInvestment(_investment.id);
              Navigator.pop(context);
              Navigator.pop(context);
              toast.showSuccess('Investment deleted');
              logger.info('Deleted investment: ${_investment.id}',
                  context: 'DigitalGoldDetails');
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Keep investment in sync with controller for real-time updates
    _investment = context.watch<InvestmentsController>().investments
        .firstWhere((i) => i.id == _investment.id, orElse: () => _investment);

    final investment = _investment;
    final metadata = investment.metadata ?? {};
    final investedAmount =
        (metadata['investedAmount'] as num?)?.toDouble() ?? investment.amount;
    final gstRate = (metadata['gstRate'] as num?)?.toDouble() ?? 3.0;
    final actualGoldCost = investedAmount / (1 + (gstRate / 100));
    final gstAmount = investedAmount - actualGoldCost;

    // Use fetched current price if available
    final currentRate =
        currentGoldPrice ?? (metadata['currentRate'] as num?)?.toDouble() ?? 0;
    final weightInGrams = (metadata['weightInGrams'] as num?)?.toDouble() ?? 0;
    final currentValue =
        currentRate > 0 && weightInGrams > 0 ? weightInGrams * currentRate : 0;
    final gainLoss = currentValue - investedAmount;
    final gainPercent =
        investedAmount > 0 ? (gainLoss / investedAmount) * 100 : 0;

    return CupertinoPageScaffold(
      backgroundColor: AppStyles.getBackground(context),
      navigationBar: AppStyles.isLandscape(context) ? null : CupertinoNavigationBar(
        middle: Text(
          metadata['company'] as String? ?? investment.name,
          style: TextStyle(color: AppStyles.getTextColor(context)),
          overflow: TextOverflow.ellipsis,
        ),
        previousPageTitle: 'Back',
        backgroundColor: AppStyles.getBackground(context),
        border: null,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Spacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Investment Summary Card
              Container(
                padding: const EdgeInsets.all(Spacing.xl),
                decoration: BoxDecoration(
                  color: AppStyles.getCardColor(context),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      metadata['company'] as String? ?? investment.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: Spacing.xs),
                    Text(
                      'Digital Gold Investment',
                      style: TextStyle(
                        color: AppStyles.getSecondaryTextColor(context),
                        fontSize: TypeScale.footnote,
                      ),
                    ),
                    const SizedBox(height: Spacing.xl),
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
                                fontSize: TypeScale.footnote,
                              ),
                            ),
                            const SizedBox(height: Spacing.xs),
                            Text(
                              '₹${investedAmount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: TypeScale.headline,
                              ),
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
                                fontSize: TypeScale.footnote,
                              ),
                            ),
                            const SizedBox(height: Spacing.xs),
                            Text(
                              '₹${currentValue.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: TypeScale.headline,
                                color: currentValue >= investedAmount
                                    ? AppStyles.gain(context)
                                    : AppStyles.loss(context),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Spacing.xl),

              // Gain/Loss Card
              Container(
                padding: const EdgeInsets.all(Spacing.lg),
                decoration: BoxDecoration(
                  color: gainPercent >= 0
                      ? AppStyles.gain(context).withValues(alpha: 0.1)
                      : AppStyles.loss(context).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: gainPercent >= 0
                        ? AppStyles.gain(context).withValues(alpha: 0.3)
                        : AppStyles.loss(context).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Gain/Loss',
                          style: TextStyle(
                            color: AppStyles.getSecondaryTextColor(context),
                            fontSize: TypeScale.footnote,
                          ),
                        ),
                        const SizedBox(height: Spacing.xs),
                        Text(
                          '${gainLoss >= 0 ? '+' : ''}₹${gainLoss.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: TypeScale.headline,
                            color: gainLoss >= 0
                                ? AppStyles.gain(context)
                                : AppStyles.loss(context),
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Return %',
                          style: TextStyle(
                            color: AppStyles.getSecondaryTextColor(context),
                            fontSize: TypeScale.footnote,
                          ),
                        ),
                        const SizedBox(height: Spacing.xs),
                        Text(
                          '${gainPercent >= 0 ? '+' : ''}${gainPercent.toStringAsFixed(2)}%',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: TypeScale.headline,
                            color: gainPercent >= 0
                                ? AppStyles.gain(context)
                                : AppStyles.loss(context),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Spacing.xl),

              // Details Section
              Text(
                'Investment Details',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: TypeScale.headline,
                  color: AppStyles.getTextColor(context),
                ),
              ),
              const SizedBox(height: Spacing.md),
              _buildDetailRow(
                  'Provider', metadata['company'] as String? ?? '-'),
              _buildDetailRow(
                  'Weight', '${weightInGrams.toStringAsFixed(4)} g'),
              _buildDetailRow('Investment Rate',
                  '₹${(metadata['investmentRate'] as num?)?.toDouble().toStringAsFixed(2) ?? '-'}/g'),
              _buildDetailRow(
                  'Actual Gold Cost', '₹${actualGoldCost.toStringAsFixed(2)}'),
              _buildDetailRow('GST Rate', '${gstRate.toStringAsFixed(1)}%'),
              _buildDetailRow('GST Amount', '₹${gstAmount.toStringAsFixed(2)}'),
              _buildDetailRow(
                'Investment Date',
                _formatDate(metadata['investmentDate'] as String?),
              ),
              if (isFetchingPrice)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CupertinoActivityIndicator(),
                      ),
                      SizedBox(width: Spacing.sm),
                      Text('Fetching current price...'),
                    ],
                  ),
                )
              else if (currentGoldPrice == null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Current Rate: Unable to fetch (check internet connection)',
                    style: TextStyle(
                        color: AppStyles.getSecondaryTextColor(context),
                        fontSize: TypeScale.footnote),
                  ),
                )
              else ...[
                _buildDetailRow(
                  'Current Rate',
                  '₹${currentRate.toStringAsFixed(2)}/g',
                ),
                if (_goldPriceLastFetched != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'Last updated: ${_formatLastUpdated(_goldPriceLastFetched)}',
                        style: TextStyle(
                          color: AppStyles.getSecondaryTextColor(context),
                          fontSize: TypeScale.caption,
                        ),
                      ),
                    ),
                  ),
              ],

              const SizedBox(height: 30),

              // Action Buttons (Edit & Delete)
              LayoutBuilder(
                builder: (context, constraints) {
                  const cols = 2;
                  const spacing = 12.0;
                  final itemW = (constraints.maxWidth - (cols - 1) * spacing) / cols;
                  return GridView.count(
                crossAxisCount: cols,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: spacing,
                mainAxisSpacing: 12,
                childAspectRatio: itemW / (itemW * 1.2),
                children: [
                  _buildActionButton(
                    context,
                    icon: CupertinoIcons.pencil_circle_fill,
                    label: 'Edit',
                    color: CupertinoColors.systemOrange,
                    onTap: _showEditModal,
                  ),
                  _buildActionButton(
                    context,
                    icon: CupertinoIcons.trash_circle_fill,
                    label: 'Delete',
                    color: AppStyles.loss(context),
                    onTap: _showDeleteConfirmation,
                  ),
                ],
                  );
                },
              ),

              const SizedBox(height: Spacing.xl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: TypeScale.subhead),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: TypeScale.subhead,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? isoDate) {
    if (isoDate == null) return '-';
    final date = DateTime.tryParse(isoDate);
    return date != null ? DateFormatter.format(date) : isoDate;
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
              padding: const EdgeInsets.all(Spacing.lg),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: color),
            ),
            const SizedBox(height: Spacing.md),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: TypeScale.subhead,
                color: AppStyles.getTextColor(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Modal for editing digital gold investment
class _EditModal extends StatefulWidget {
  final Investment investment;

  const _EditModal({required this.investment});

  @override
  State<_EditModal> createState() => _EditModalState();
}

class _EditModalState extends State<_EditModal> {
  late TextEditingController _investedAmountController;
  late TextEditingController _investmentRateController;
  late TextEditingController _gstRateController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final metadata = widget.investment.metadata ?? {};
    _investedAmountController = TextEditingController(
      text: widget.investment.amount.toStringAsFixed(2),
    );
    _investmentRateController = TextEditingController(
      text: ((metadata['investmentRate'] as num?)?.toDouble() ?? 0)
          .toStringAsFixed(2),
    );
    _gstRateController = TextEditingController(
      text:
          ((metadata['gstRate'] as num?)?.toDouble() ?? 3.0).toStringAsFixed(1),
    );
  }

  @override
  void dispose() {
    _investedAmountController.dispose();
    _investmentRateController.dispose();
    _gstRateController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    final newAmount = double.tryParse(_investedAmountController.text) ?? 0;
    final newRate = double.tryParse(_investmentRateController.text) ?? 0;
    final newGstRate = double.tryParse(_gstRateController.text) ?? 3.0;

    if (newAmount <= 0 || newRate <= 0) {
      if (mounted) {
        toast.showError('Please enter valid amounts');
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Recalculate values
      final actualAmount = newAmount / (1 + (newGstRate / 100));
      final gstAmount = newAmount - actualAmount;
      final weightInGrams = actualAmount / newRate;

      final metadata = widget.investment.metadata ?? {};
      final updatedMetadata = {
        ...metadata,
        'investedAmount': newAmount,
        'investmentRate': newRate,
        'gstRate': newGstRate,
        'actualGoldCost': actualAmount,
        'gstAmount': gstAmount,
        'weightInGrams': weightInGrams,
        'lastUpdated': DateTime.now().toIso8601String(),
      };

      final updatedInvestment = widget.investment.copyWith(
        amount: newAmount,
        metadata: updatedMetadata,
      );

      final investmentsController =
          Provider.of<InvestmentsController>(context, listen: false);
      await investmentsController.updateInvestment(updatedInvestment);

      if (mounted) {
        toast.showSuccess('Investment updated successfully');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        toast.showError('Error updating investment: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoActionSheetAction(
      onPressed: () {},
      child: SingleChildScrollView(
        child: SafeArea(
          child: Container(
            color: AppStyles.getBackground(context),
            padding: const EdgeInsets.all(Spacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Edit Investment',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppStyles.getTextColor(context),
                  ),
                ),
                const SizedBox(height: Spacing.xxl),
                Text(
                  'Total Invested Amount (₹)',
                  style: TextStyle(
                    fontSize: TypeScale.subhead,
                    fontWeight: FontWeight.w600,
                    color: AppStyles.getTextColor(context),
                  ),
                ),
                const SizedBox(height: Spacing.sm),
                CupertinoTextField(
                  controller: _investedAmountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  placeholder: '0.00',
                  padding: const EdgeInsets.all(Spacing.md),
                  decoration: BoxDecoration(
                    color: AppStyles.getCardColor(context),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefix: const Padding(
                    padding: EdgeInsets.only(left: 12),
                    child: Text('₹'),
                  ),
                ),
                const SizedBox(height: Spacing.lg),
                Text(
                  'Investment Rate (₹/gram)',
                  style: TextStyle(
                    fontSize: TypeScale.subhead,
                    fontWeight: FontWeight.w600,
                    color: AppStyles.getTextColor(context),
                  ),
                ),
                const SizedBox(height: Spacing.sm),
                CupertinoTextField(
                  controller: _investmentRateController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  placeholder: '0.00',
                  padding: const EdgeInsets.all(Spacing.md),
                  decoration: BoxDecoration(
                    color: AppStyles.getCardColor(context),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefix: const Padding(
                    padding: EdgeInsets.only(left: 12),
                    child: Text('₹'),
                  ),
                  suffix: const Padding(
                    padding: EdgeInsets.only(right: 12),
                    child: Text('/g'),
                  ),
                ),
                const SizedBox(height: Spacing.lg),
                Text(
                  'GST Rate (%)',
                  style: TextStyle(
                    fontSize: TypeScale.subhead,
                    fontWeight: FontWeight.w600,
                    color: AppStyles.getTextColor(context),
                  ),
                ),
                const SizedBox(height: Spacing.sm),
                CupertinoTextField(
                  controller: _gstRateController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  placeholder: '3.0',
                  padding: const EdgeInsets.all(Spacing.md),
                  decoration: BoxDecoration(
                    color: AppStyles.getCardColor(context),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  suffix: const Padding(
                    padding: EdgeInsets.only(right: 12),
                    child: Text('%'),
                  ),
                ),
                const SizedBox(height: Spacing.xxl),
                Row(
                  children: [
                    Expanded(
                      child: CupertinoButton(
                        color: CupertinoColors.systemGrey4,
                        onPressed:
                            _isLoading ? null : () => Navigator.pop(context),
                        child: const Text('Cancel',
                            style: TextStyle(
                                color: CupertinoColors.destructiveRed)),
                      ),
                    ),
                    const SizedBox(width: Spacing.md),
                    Expanded(
                      child: CupertinoButton.filled(
                        onPressed: _isLoading ? null : _saveChanges,
                        child: _isLoading
                            ? const CupertinoActivityIndicator(
                                color: CupertinoColors.white)
                            : const Text('Save'),
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
}
