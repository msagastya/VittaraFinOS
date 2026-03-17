import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/nps_model.dart';
import 'package:vittara_fin_os/ui/manage/nps/nps_wizard_controller.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';

class NPSContributionStep extends StatefulWidget {
  const NPSContributionStep({super.key});

  @override
  State<NPSContributionStep> createState() => _NPSContributionStepState();
}

class _NPSContributionStepState extends State<NPSContributionStep> {
  late TextEditingController _contributedController;

  @override
  void initState() {
    super.initState();
    final ctrl = Provider.of<NPSWizardController>(context, listen: false);
    _contributedController = TextEditingController(
      text: ctrl.totalContributed != null
          ? ctrl.totalContributed!.toString()
          : '',
    );
  }

  @override
  void dispose() {
    _contributedController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = Provider.of<NPSWizardController>(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(Spacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Contribution Summary', style: AppStyles.titleStyle(context)),
          const SizedBox(height: Spacing.sm),
          Text('Enter total contribution till date',
              style:
                  TextStyle(color: AppStyles.getSecondaryTextColor(context))),
          const SizedBox(height: 30),
          // Total Contributed
          const Text('Total Contributed (₹)',
              style: TextStyle(
                  fontWeight: FontWeight.w600, fontSize: TypeScale.body)),
          const SizedBox(height: Spacing.md),
          CupertinoTextField(
            controller: _contributedController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            placeholder: '0.00',
            padding: const EdgeInsets.all(Spacing.lg),
            decoration: BoxDecoration(
              color: AppStyles.getCardColor(context),
              borderRadius: BorderRadius.circular(12),
            ),
            prefix: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Text('₹',
                  style: TextStyle(color: AppStyles.getTextColor(context))),
            ),
            onChanged: (v) {
              final amt = double.tryParse(v) ?? 0;
              if (amt > 0) ctrl.updateTotalContributed(amt);
            },
          ),
          const SizedBox(height: Spacing.xxl),
          // Scheme Type
          const Text('Investment Scheme',
              style: TextStyle(
                  fontWeight: FontWeight.w600, fontSize: TypeScale.body)),
          const SizedBox(height: Spacing.md),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: NPSSchemeType.values.map((scheme) {
              final isSelected = ctrl.schemeType == scheme;
              final label = scheme == NPSSchemeType.equity
                  ? 'Equity (E)'
                  : scheme == NPSSchemeType.debt
                      ? 'Debt (D)'
                      : scheme == NPSSchemeType.alternative
                          ? 'Alternative (A)'
                          : 'Gold (G)';
              return GestureDetector(
                onTap: () => ctrl.updateSchemeType(scheme),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF9B59B6)
                        : AppStyles.getCardColor(context),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF9B59B6)
                          : CupertinoColors.systemGrey.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(label,
                      style: TextStyle(
                          color: isSelected ? Colors.white : null,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.w500,
                          fontSize: TypeScale.footnote)),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: Spacing.xxl),
          // NPS Manager
          const Text('NPS Manager',
              style: TextStyle(
                  fontWeight: FontWeight.w600, fontSize: TypeScale.body)),
          const SizedBox(height: Spacing.md),
          CupertinoButton(
            onPressed: () {
              showCupertinoModalPopup(
                context: context,
                builder: (ctx) => Container(
                  color: AppStyles.getBackground(context),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          CupertinoButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancel'),
                          ),
                          CupertinoButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Done'),
                          ),
                        ],
                      ),
                      Expanded(
                        child: CupertinoPicker(
                          itemExtent: 32,
                          onSelectedItemChanged: (idx) {
                            ctrl.updateManager(NPSManager.values[idx]);
                          },
                          children: NPSManager.values
                              .map((m) => Text(m.displayName))
                              .toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(Spacing.lg),
              decoration: BoxDecoration(
                color: AppStyles.getCardColor(context),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    ctrl.selectedManager?.displayName ?? 'Select Manager',
                    style: TextStyle(color: AppStyles.getTextColor(context)),
                  ),
                  Icon(CupertinoIcons.chevron_down,
                      color: AppStyles.getSecondaryTextColor(context)),
                ],
              ),
            ),
          ),
          const SizedBox(height: Spacing.xxl),
          if (ctrl.totalContributed != null && ctrl.totalContributed! > 0) ...{
            Container(
              padding: const EdgeInsets.all(Spacing.lg),
              decoration: BoxDecoration(
                color: const Color(0xFF9B59B6).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFF9B59B6).withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  _SummaryRow(
                    'Total Contribution',
                    '₹${ctrl.totalContributed!.toStringAsFixed(2)}',
                    isBold: true,
                  ),
                  const SizedBox(height: Spacing.md),
                  _SummaryRow(
                    'Tax Benefit (80C)',
                    '₹${(ctrl.totalContributed! > 150000 ? 150000 : ctrl.totalContributed!).toStringAsFixed(2)}',
                  ),
                  const SizedBox(height: Spacing.md),
                  _SummaryRow(
                    'Extra 80CCD',
                    '₹${((ctrl.totalContributed! - 150000).clamp(0, 50000)).toStringAsFixed(2)}',
                  ),
                  if (ctrl.totalContributed! > 200000) ...[
                    const SizedBox(height: Spacing.md),
                    Container(
                      padding: const EdgeInsets.all(Spacing.md),
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemOrange
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(CupertinoIcons.exclamationmark_circle,
                              size: 16, color: CupertinoColors.systemOrange),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Contribution exceeds ₹2L limit. Amounts above ₹2,00,000 (₹1.5L 80C + ₹50K 80CCD) do not attract additional tax deduction.',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: CupertinoColors.systemOrange),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          },
          const SizedBox(height: Spacing.xl),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;

  const _SummaryRow(this.label, this.value, {this.isBold = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: TypeScale.subhead,
                color: AppStyles.getSecondaryTextColor(context))),
        Text(value,
            style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
                fontSize: isBold ? 14 : 13,
                color: const Color(0xFF9B59B6))),
      ],
    );
  }
}
