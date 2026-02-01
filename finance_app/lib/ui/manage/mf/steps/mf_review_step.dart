import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/ui/manage/mf/mf_wizard_controller.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';

class MFReviewStep extends StatelessWidget {
  const MFReviewStep({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<MFWizardController>(context);
    final mf = controller.selectedMF;
    final account = controller.selectedAccount;

    if (mf == null || account == null) return const SizedBox();

    final displayNAV = controller.selectedMFType == MFType.existing
        ? controller.averageNAV
        : controller.fetchedNAV ?? 0;

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
                color: SemanticColors.investments.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  mf.schemeName.isNotEmpty
                      ? mf.schemeName.substring(0, 1).toUpperCase()
                      : 'M',
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
              mf.schemeName,
              style: AppStyles.titleStyle(context).copyWith(fontSize: 18),
              textAlign: TextAlign.center,
            ),
          ),
          Center(
            child: Text(
              mf.fundHouse ?? 'Unknown Fund House',
              style: TextStyle(
                color: AppStyles.getSecondaryTextColor(context),
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 32),
          _buildRow(context, 'Scheme Type', mf.schemeType ?? 'N/A'),
          _buildRow(context, 'Scheme Code', mf.schemeCode),
          _buildRow(context, 'Account', account.name),
          _buildRow(context, 'Units', controller.calculatedUnits.toStringAsFixed(4)),
          _buildRow(context, 'NAV', '₹${displayNAV.toStringAsFixed(2)}'),
          _buildRow(
            context,
            'Investment Date',
            '${controller.investmentDate.day} ${_monthName(controller.investmentDate.month)} ${controller.investmentDate.year}',
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(),
          ),
          _buildRow(
            context,
            'Total Investment Amount',
            '₹${controller.totalAmount.toStringAsFixed(2)}',
            isBold: true,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: SemanticColors.investments.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: SemanticColors.investments.withOpacity(0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Investment Summary',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 12),
                _buildSummaryRow(
                  'Units',
                  controller.calculatedUnits.toStringAsFixed(4),
                ),
                _buildSummaryRow(
                  'NAV @ Purchase',
                  '₹${displayNAV.toStringAsFixed(2)}',
                ),
                _buildSummaryRow(
                  'Total Amount',
                  '₹${controller.totalAmount.toStringAsFixed(2)}',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(
    BuildContext context,
    String label,
    String value, {
    bool isBold = false,
    Color? color,
  }) {
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

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
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
