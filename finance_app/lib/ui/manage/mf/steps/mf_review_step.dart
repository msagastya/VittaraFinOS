import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/ui/manage/mf/mf_wizard_controller.dart';
import 'package:vittara_fin_os/utils/date_formatter.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';

class MFReviewStep extends StatelessWidget {
  const MFReviewStep({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<MFWizardController>(context);
    final mf = controller.selectedMF;

    if (mf == null) return const SizedBox();

    final account = controller.selectedAccount;

    final displayNAV = controller.selectedMFType == MFType.existing
        ? controller.averageNAV
        : controller.fetchedNAV ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(Spacing.xl),
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
                  mf.schemeName.isNotEmpty
                      ? mf.schemeName.substring(0, 1).toUpperCase()
                      : 'M',
                  style: const TextStyle(
                    fontSize: TypeScale.display,
                    fontWeight: FontWeight.bold,
                    color: SemanticColors.investments,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: Spacing.lg),
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
                fontSize: TypeScale.footnote,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: Spacing.xxxl),
          _buildRow(context, 'Scheme Type', mf.schemeType ?? 'N/A'),
          _buildRow(context, 'Scheme Code', mf.schemeCode),
          _buildRow(context, 'Account', account?.name ?? 'Not linked'),
          _buildRow(
              context, 'Units', controller.calculatedUnits.toStringAsFixed(4)),
          _buildRow(context, 'NAV', '₹${displayNAV.toStringAsFixed(2)}'),
          _buildRow(
            context,
            'Investment Date',
            '${controller.investmentDate.day} ${_monthName(controller.investmentDate.month)} ${controller.investmentDate.year}',
          ),
          if (controller.sipActive && controller.sipData != null) ...[
            _buildRow(
              context,
              'SIP Amount',
              '₹${((controller.sipData!['sipAmount'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}/month',
            ),
            _buildRow(
              context,
              'SIP Frequency',
              (controller.sipData!['frequency'] as String? ?? 'monthly').toLowerCase() == 'monthly'
                  ? 'Monthly'
                  : (controller.sipData!['frequency'] as String? ?? ''),
            ),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(),
          ),
          if (controller.extraCharges > 0)
            _buildRow(
              context,
              'Transaction Charges',
              '₹${controller.extraCharges.toStringAsFixed(2)}',
            ),
          if (controller.extraCharges > 0)
            _buildRow(
              context,
              'Net Invested',
              '₹${controller.netInvestmentAmount.toStringAsFixed(2)}',
            ),
          _buildRow(
            context,
            'Account Deduction',
            '₹${controller.totalAmount.toStringAsFixed(2)}',
            isBold: true,
          ),
          const SizedBox(height: Spacing.lg),
          Container(
            padding: const EdgeInsets.all(Spacing.lg),
            decoration: BoxDecoration(
              color: SemanticColors.investments.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: SemanticColors.investments.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Investment Summary',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: TypeScale.body,
                  ),
                ),
                const SizedBox(height: Spacing.md),
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
            style: const TextStyle(fontSize: TypeScale.footnote),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: TypeScale.footnote,
              fontWeight: FontWeight.w600,
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
