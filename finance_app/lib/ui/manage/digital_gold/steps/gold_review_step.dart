import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/ui/manage/digital_gold/digital_gold_wizard_controller.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/services/gold_price_service.dart';

class GoldReviewStep extends StatefulWidget {
  const GoldReviewStep({super.key});

  @override
  State<GoldReviewStep> createState() => _GoldReviewStepState();
}

class _GoldReviewStepState extends State<GoldReviewStep> {
  @override
  void initState() {
    super.initState();
    _fetchCurrentGoldPrice();
  }

  Future<void> _fetchCurrentGoldPrice() async {
    final controller =
        Provider.of<DigitalGoldWizardController>(context, listen: false);

    controller.setFetchingPrice(true);

    try {
      final price = await GoldPriceService.fetchCurrentGoldPrice();
      if (context.mounted) {
        controller.setCurrentGoldPrice(price);
      }
    } catch (e) {
      if (context.mounted) {
        controller.setPriceError('Failed to fetch current gold price: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<DigitalGoldWizardController>(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(Spacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Review Investment',
            style: AppStyles.titleStyle(context),
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            'Review your gold investment details',
            style: TextStyle(color: AppStyles.getSecondaryTextColor(context)),
          ),
          const SizedBox(height: 30),
          // Current Gold Price Card
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
                  'Current Gold Price',
                  style: TextStyle(
                    color: AppStyles.getSecondaryTextColor(context),
                    fontSize: TypeScale.footnote,
                  ),
                ),
                const SizedBox(height: Spacing.sm),
                if (controller.isFetchingPrice)
                  Row(
                    children: const [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CupertinoActivityIndicator(),
                      ),
                      SizedBox(width: Spacing.sm),
                      Text('Fetching current price...'),
                    ],
                  )
                else if (controller.priceError.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        controller.priceError,
                        style: const TextStyle(
                          color: CupertinoColors.systemRed,
                          fontSize: TypeScale.footnote,
                        ),
                      ),
                      const SizedBox(height: Spacing.md),
                      CupertinoButton(
                        color: CupertinoColors.systemBlue,
                        onPressed: _fetchCurrentGoldPrice,
                        child: const Text('Retry'),
                      ),
                    ],
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '₹${controller.currentGoldPrice?.toStringAsFixed(2) ?? '-'} per gram',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 24,
                              color: Color(0xFFFFB81C),
                            ),
                          ),
                          const SizedBox(height: Spacing.xs),
                          Text(
                            'As of now',
                            style: TextStyle(
                              color: AppStyles.getSecondaryTextColor(context),
                              fontSize: TypeScale.footnote,
                            ),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: _fetchCurrentGoldPrice,
                        child: Container(
                          padding: const EdgeInsets.all(Spacing.sm),
                          decoration: BoxDecoration(
                            color: CupertinoColors.systemGrey.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            CupertinoIcons.refresh,
                            size: 16,
                            color: AppStyles.getSecondaryTextColor(context),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: Spacing.xl),
          // Investment Summary
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
                  'Investment Summary',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: TypeScale.headline,
                    color: AppStyles.getTextColor(context),
                  ),
                ),
                const SizedBox(height: Spacing.lg),
                _buildDetailRow(
                    'Provider', controller.selectedCompany?.name ?? '-'),
                _buildDetailRow('Actual Gold Cost',
                    '₹${controller.actualAmount.toStringAsFixed(2)}'),
                _buildDetailRow(
                    'GST Rate', '${controller.gstRate.toStringAsFixed(1)}%'),
                _buildDetailRow(
                    'Investment Date', _formatDate(controller.investmentDate)),
                const Divider(height: 16),
                _buildDetailRow('Actual Gold Cost',
                    '₹${controller.actualAmount.toStringAsFixed(2)}',
                    isBold: true),
                _buildDetailRow('GST Amount (${controller.gstRate}%)',
                    '₹${controller.gstAmount.toStringAsFixed(2)}',
                    isBold: true),
                Container(
                  height: 1,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  color: CupertinoColors.systemGrey.withValues(alpha: 0.2),
                ),
                _buildDetailRow('Total Investment',
                    '₹${controller.investedAmount.toStringAsFixed(2)}',
                    isBold: true, isHighlight: true),
              ],
            ),
          ),
          const SizedBox(height: Spacing.xl),
          // Current Value (if price fetched)
          if (controller.currentGoldPrice != null &&
              controller.currentGoldPrice! > 0)
            Container(
              padding: const EdgeInsets.all(Spacing.lg),
              decoration: BoxDecoration(
                color: controller.gainLossPercent >= 0
                    ? CupertinoColors.systemGreen.withValues(alpha: 0.1)
                    : CupertinoColors.systemRed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: controller.gainLossPercent >= 0
                      ? CupertinoColors.systemGreen.withValues(alpha: 0.3)
                      : CupertinoColors.systemRed.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
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
                            '₹${controller.currentValue.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: TypeScale.headline,
                              color: controller.currentValue >=
                                      controller.investedAmount
                                  ? CupertinoColors.systemGreen
                                  : CupertinoColors.systemRed,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${controller.gainLossPercent >= 0 ? '+' : ''}${controller.gainLossPercent.toStringAsFixed(2)}%',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: TypeScale.headline,
                              color: controller.gainLossPercent >= 0
                                  ? CupertinoColors.systemGreen
                                  : CupertinoColors.systemRed,
                            ),
                          ),
                          const SizedBox(height: Spacing.xs),
                          Text(
                            '${controller.gainLoss >= 0 ? '+' : ''}₹${controller.gainLoss.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: AppStyles.getSecondaryTextColor(context),
                              fontSize: TypeScale.footnote,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    bool isBold = false,
    bool isHighlight = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: TypeScale.subhead,
              fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: TypeScale.subhead,
              color: isHighlight ? const Color(0xFFFFB81C) : null,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
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
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
