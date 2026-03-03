import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/ui/manage/stocks/stocks_wizard_controller.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';

class StockReviewStep extends StatelessWidget {
  const StockReviewStep({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<StocksWizardController>(context);
    final stock = controller.selectedStock;
    final account = controller.selectedAccount;

    if (stock == null || account == null) return const SizedBox();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: SemanticColors.investments.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  stock.symbol.substring(0, 1),
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: SemanticColors.investments,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              stock.symbol,
              style: AppStyles.titleStyle(context).copyWith(fontSize: 24),
            ),
          ),
          Center(
            child: Text(
              stock.name,
              style: TextStyle(color: AppStyles.getSecondaryTextColor(context)),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 32),
          _buildRow(context, 'Exchange', stock.exchange),
          _buildRow(context, 'Demat Account', account.name),
          _buildRow(context, 'Quantity', controller.qty.toString()),
          _buildRow(context, 'Price per Share',
              '₹${controller.price.toStringAsFixed(2)}'),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(),
          ),
          _buildRow(context, 'Total Amount',
              '₹${controller.totalAmount.toStringAsFixed(2)}',
              isBold: true),
          if (controller.deductFromAccount) ...[
            const SizedBox(height: 8),
            _buildRow(context, 'Deducted from Balance', 'Yes',
                color: CupertinoColors.systemOrange),
            if (controller.extraCharges > 0)
              _buildRow(context, 'Extra Charges',
                  '₹${controller.extraCharges.toStringAsFixed(2)}'),
            const SizedBox(height: 8),
            _buildRow(
              context,
              'Total Deducted',
              '₹${controller.totalDeduction.toStringAsFixed(2)}',
              isBold: true,
              color: CupertinoColors.systemRed,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRow(BuildContext context, String label, String value,
      {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppStyles.getSecondaryTextColor(context),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: color ?? AppStyles.getTextColor(context),
            ),
          ),
        ],
      ),
    );
  }
}
