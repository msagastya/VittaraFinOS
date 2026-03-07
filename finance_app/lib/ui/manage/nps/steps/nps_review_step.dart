import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/ui/manage/nps/nps_wizard_controller.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';

class NPSReviewStep extends StatelessWidget {
  const NPSReviewStep({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Provider.of<NPSWizardController>(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(Spacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Review & Confirm', style: AppStyles.titleStyle(context)),
          const SizedBox(height: Spacing.sm),
          Text('Verify all details before saving',
              style:
                  TextStyle(color: AppStyles.getSecondaryTextColor(context))),
          const SizedBox(height: 30),
          _ReviewCard(
            title: 'Account Details',
            children: [
              _ReviewRow('Subscriber', ctrl.fullName ?? 'N/A'),
              _ReviewRow('PRN', ctrl.prnNumber ?? 'N/A'),
              _ReviewRow('NRN', ctrl.nrnNumber ?? 'N/A'),
              _ReviewRow('PAN', ctrl.panNumber ?? 'N/A'),
              _ReviewRow(
                  'Account Type', ctrl.accountType.toString().split('.').last),
              _ReviewRow('Tier', ctrl.selectedTier.toString().split('.').last),
              _ReviewRow('Manager', ctrl.selectedManager?.displayName ?? 'N/A'),
            ],
          ),
          const SizedBox(height: Spacing.xl),
          _ReviewCard(
            title: 'Contributions & Returns',
            children: [
              _ReviewRow('Total Contributed',
                  '₹${ctrl.totalContributed?.toStringAsFixed(2) ?? '0.00'}',
                  isBold: true),
              _ReviewRow('Current Value',
                  '₹${ctrl.currentValue?.toStringAsFixed(2) ?? '0.00'}'),
              _ReviewRow('Estimated Returns',
                  '₹${ctrl.estimatedReturns.toStringAsFixed(2)}'),
              _ReviewRow(
                  'Return %', '${ctrl.gainLossPercent.toStringAsFixed(2)}%',
                  isHighlight: true),
              _ReviewRow('Tax Benefit (80C)',
                  '₹${(((ctrl.totalContributed ?? 0) > 150000 ? 150000 : ctrl.totalContributed) ?? 0).toStringAsFixed(2)}'),
            ],
          ),
          const SizedBox(height: Spacing.xl),
          _ReviewCard(
            title: 'Retirement Planning',
            children: [
              if (ctrl.plannedRetirementDate != null) ...[
                _ReviewRow('Retirement Age (approx)',
                    '${DateTime.now().year + (ctrl.plannedRetirementDate!.year - DateTime.now().year)} (${ctrl.plannedRetirementDate!.year - DateTime.now().year} years)'),
              ],
              _ReviewRow('Withdrawal Strategy',
                  ctrl.withdrawalType.toString().split('.').last),
            ],
          ),
          const SizedBox(height: Spacing.xl),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _ReviewCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Spacing.lg),
      decoration: BoxDecoration(
        color: AppStyles.getCardColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: CupertinoColors.systemGrey.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  color: AppStyles.getTextColor(context),
                  fontWeight: FontWeight.bold,
                  fontSize: TypeScale.body)),
          const SizedBox(height: Spacing.lg),
          ...List.generate(
            children.length,
            (i) => Column(
              children: [
                children[i],
                if (i < children.length - 1) const SizedBox(height: Spacing.md),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;
  final bool isHighlight;

  const _ReviewRow(this.label, this.value,
      {this.isBold = false, this.isHighlight = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                color: AppStyles.getSecondaryTextColor(context),
                fontSize: TypeScale.subhead)),
        Text(value,
            style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
                fontSize: isHighlight ? 14 : 13,
                color: isHighlight
                    ? const Color(0xFF9B59B6)
                    : AppStyles.getTextColor(context))),
      ],
    );
  }
}
