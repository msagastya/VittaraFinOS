import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/ui/manage/cryptocurrency/crypto_wizard_controller.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';

class CryptoReviewStep extends StatelessWidget {
  const CryptoReviewStep({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<CryptoWizardController>(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(Spacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Review & Confirm',
            style: AppStyles.titleStyle(context),
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            'Verify all details before saving',
            style: TextStyle(color: AppStyles.getSecondaryTextColor(context)),
          ),
          const SizedBox(height: 30),
          // Cryptocurrency Card
          Container(
            padding: const EdgeInsets.all(Spacing.lg),
            decoration: BoxDecoration(
              color: AppStyles.getCardColor(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: CupertinoColors.systemGrey.withValues(alpha: 0.2),
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
                    fontSize: TypeScale.body,
                  ),
                ),
                const SizedBox(height: Spacing.lg),
                _ReviewRow(
                  label: 'Name',
                  value: controller.cryptoName ?? 'N/A',
                ),
                const SizedBox(height: Spacing.md),
                _ReviewRow(
                  label: 'Symbol',
                  value: controller.cryptoSymbol ?? 'N/A',
                ),
              ],
            ),
          ),
          const SizedBox(height: Spacing.xl),
          // Wallet & Storage Card
          Container(
            padding: const EdgeInsets.all(Spacing.lg),
            decoration: BoxDecoration(
              color: AppStyles.getCardColor(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: CupertinoColors.systemGrey.withValues(alpha: 0.2),
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
                    fontSize: TypeScale.body,
                  ),
                ),
                const SizedBox(height: Spacing.lg),
                _ReviewRow(
                  label: 'Storage Type',
                  value: controller.walletType.toString().split('.').last,
                ),
                const SizedBox(height: Spacing.md),
                if (controller.selectedExchange != null) ...[
                  _ReviewRow(
                    label: 'Exchange',
                    value:
                        controller.selectedExchange.toString().split('.').last,
                  ),
                  const SizedBox(height: Spacing.md),
                ],
                _ReviewRow(
                  label: 'Address/Account',
                  value: controller.walletAddress ?? 'N/A',
                ),
              ],
            ),
          ),
          const SizedBox(height: Spacing.xl),
          // Purchase Details Card
          Container(
            padding: const EdgeInsets.all(Spacing.lg),
            decoration: BoxDecoration(
              color: AppStyles.getCardColor(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: CupertinoColors.systemGrey.withValues(alpha: 0.2),
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
                    fontSize: TypeScale.body,
                  ),
                ),
                const SizedBox(height: Spacing.lg),
                _ReviewRow(
                  label: 'Date',
                  value:
                      '${controller.purchaseDate.day}/${controller.purchaseDate.month}/${controller.purchaseDate.year}',
                ),
                const SizedBox(height: Spacing.md),
                _ReviewRow(
                  label: 'Quantity',
                  value:
                      '${controller.quantity?.toStringAsFixed(8) ?? '0'} ${controller.cryptoSymbol ?? 'coins'}',
                ),
                const SizedBox(height: Spacing.md),
                _ReviewRow(
                  label: 'Price per Unit',
                  value:
                      '₹${controller.pricePerUnit?.toStringAsFixed(2) ?? '0.00'}',
                ),
                const SizedBox(height: Spacing.md),
                _ReviewRow(
                  label: 'Total Investment',
                  value: '₹${controller.totalInvested.toStringAsFixed(2)}',
                  isHighlight: true,
                ),
                if (controller.transactionFee != null &&
                    controller.transactionFee! > 0) ...[
                  const SizedBox(height: Spacing.md),
                  _ReviewRow(
                    label: 'Transaction Fee',
                    value:
                        '₹${controller.transactionFee?.toStringAsFixed(2) ?? '0.00'}',
                  ),
                  const SizedBox(height: Spacing.md),
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
            const SizedBox(height: Spacing.xl),
            Container(
              padding: const EdgeInsets.all(Spacing.lg),
              decoration: BoxDecoration(
                color: AppStyles.getCardColor(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: CupertinoColors.systemGrey.withValues(alpha: 0.2),
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
                      fontSize: TypeScale.body,
                    ),
                  ),
                  const SizedBox(height: Spacing.md),
                  Text(
                    controller.notes!,
                    style: TextStyle(
                      color: AppStyles.getSecondaryTextColor(context),
                      fontSize: TypeScale.subhead,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: Spacing.xl),
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
            fontSize: TypeScale.subhead,
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
