import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/ui/manage/cryptocurrency/crypto_wizard_controller.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';

class CryptoReviewStep extends StatelessWidget {
  const CryptoReviewStep({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<CryptoWizardController>(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Review & Confirm',
            style: AppStyles.titleStyle(context),
          ),
          const SizedBox(height: 8),
          Text(
            'Verify all details before saving',
            style: TextStyle(color: AppStyles.getSecondaryTextColor(context)),
          ),
          const SizedBox(height: 30),
          // Cryptocurrency Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppStyles.getCardColor(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.grey.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cryptocurrency',
                  style: TextStyle(
                    color: AppStyles.getTextColor(context),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                _ReviewRow(
                  label: 'Name',
                  value: controller.cryptoName ?? 'N/A',
                ),
                const SizedBox(height: 12),
                _ReviewRow(
                  label: 'Symbol',
                  value: controller.cryptoSymbol ?? 'N/A',
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Wallet & Storage Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppStyles.getCardColor(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.grey.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Wallet & Storage',
                  style: TextStyle(
                    color: AppStyles.getTextColor(context),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                _ReviewRow(
                  label: 'Storage Type',
                  value: controller.walletType.toString().split('.').last,
                ),
                const SizedBox(height: 12),
                if (controller.selectedExchange != null) ...[
                  _ReviewRow(
                    label: 'Exchange',
                    value:
                        controller.selectedExchange.toString().split('.').last,
                  ),
                  const SizedBox(height: 12),
                ],
                _ReviewRow(
                  label: 'Address/Account',
                  value: controller.walletAddress ?? 'N/A',
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Purchase Details Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppStyles.getCardColor(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.grey.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Purchase Details',
                  style: TextStyle(
                    color: AppStyles.getTextColor(context),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                _ReviewRow(
                  label: 'Date',
                  value:
                      '${controller.purchaseDate.day}/${controller.purchaseDate.month}/${controller.purchaseDate.year}',
                ),
                const SizedBox(height: 12),
                _ReviewRow(
                  label: 'Quantity',
                  value:
                      '${controller.quantity?.toStringAsFixed(8) ?? '0'} ${controller.cryptoSymbol ?? 'coins'}',
                ),
                const SizedBox(height: 12),
                _ReviewRow(
                  label: 'Price per Unit',
                  value:
                      '₹${controller.pricePerUnit?.toStringAsFixed(2) ?? '0.00'}',
                ),
                const SizedBox(height: 12),
                _ReviewRow(
                  label: 'Total Investment',
                  value: '₹${controller.totalInvested.toStringAsFixed(2)}',
                  isHighlight: true,
                ),
                if (controller.transactionFee != null &&
                    controller.transactionFee! > 0) ...[
                  const SizedBox(height: 12),
                  _ReviewRow(
                    label: 'Transaction Fee',
                    value:
                        '₹${controller.transactionFee?.toStringAsFixed(2) ?? '0.00'}',
                  ),
                  const SizedBox(height: 12),
                  _ReviewRow(
                    label: 'Total Cost',
                    value: '₹${controller.totalWithFee.toStringAsFixed(2)}',
                    isHighlight: true,
                  ),
                ],
              ],
            ),
          ),
          if (controller.notes != null && controller.notes!.isNotEmpty) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppStyles.getCardColor(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.grey.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Notes',
                    style: TextStyle(
                      color: AppStyles.getTextColor(context),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    controller.notes!,
                    style: TextStyle(
                      color: AppStyles.getSecondaryTextColor(context),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isHighlight;

  const _ReviewRow({
    required this.label,
    required this.value,
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
            fontWeight: isHighlight ? FontWeight.bold : FontWeight.w500,
            fontSize: isHighlight ? 14 : 13,
          ),
          textAlign: TextAlign.end,
        ),
      ],
    );
  }
}
