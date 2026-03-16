import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/nps_model.dart';
import 'package:vittara_fin_os/ui/manage/nps/nps_wizard_controller.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/widgets/common_widgets.dart';

class NPSAccountStep extends StatefulWidget {
  const NPSAccountStep({super.key});

  @override
  State<NPSAccountStep> createState() => _NPSAccountStepState();
}

class _NPSAccountStepState extends State<NPSAccountStep> {
  late TextEditingController _prnController;
  late TextEditingController _nrnController;
  late TextEditingController _nameController;
  late TextEditingController _panController;

  @override
  void initState() {
    super.initState();
    final ctrl = Provider.of<NPSWizardController>(context, listen: false);
    _prnController = TextEditingController(text: ctrl.prnNumber ?? '');
    _nrnController = TextEditingController(text: ctrl.nrnNumber ?? '');
    _nameController = TextEditingController(text: ctrl.fullName ?? '');
    _panController = TextEditingController(text: ctrl.panNumber ?? '');
  }

  @override
  void dispose() {
    _prnController.dispose();
    _nrnController.dispose();
    _nameController.dispose();
    _panController.dispose();
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
          Text('NPS Account Details', style: AppStyles.titleStyle(context)),
          const SizedBox(height: Spacing.sm),
          Text('Enter your NPS account information',
              style:
                  TextStyle(color: AppStyles.getSecondaryTextColor(context))),
          const SizedBox(height: 30),
          // PRAN
          Row(children: [
            Text('Permanent Retirement Number (PRAN)',
                style: TextStyle(
                    fontWeight: FontWeight.w600, fontSize: TypeScale.body)),
            const SizedBox(width: 4),
            const JargonTooltip.pran(),
          ]),
          const SizedBox(height: Spacing.md),
          CupertinoTextField(
            controller: _prnController,
            placeholder: 'e.g., PRANXXXXXXXX',
            padding: const EdgeInsets.all(Spacing.lg),
            decoration: BoxDecoration(
              color: AppStyles.getCardColor(context),
              borderRadius: BorderRadius.circular(Radii.md),
            ),
            onChanged: (v) => ctrl.updatePRN(v),
          ),
          const SizedBox(height: Spacing.xxl),
          // NRN
          Text('National Registration Number (NRN)',
              style: TextStyle(
                  fontWeight: FontWeight.w600, fontSize: TypeScale.body)),
          const SizedBox(height: Spacing.md),
          CupertinoTextField(
            controller: _nrnController,
            placeholder: 'e.g., NRNXXXXXXXX',
            padding: const EdgeInsets.all(Spacing.lg),
            decoration: BoxDecoration(
              color: AppStyles.getCardColor(context),
              borderRadius: BorderRadius.circular(Radii.md),
            ),
            onChanged: (v) => ctrl.updateNRN(v),
          ),
          const SizedBox(height: Spacing.xxl),
          // Name
          Text('Subscriber Name',
              style: TextStyle(
                  fontWeight: FontWeight.w600, fontSize: TypeScale.body)),
          const SizedBox(height: Spacing.md),
          CupertinoTextField(
            controller: _nameController,
            placeholder: 'Full name',
            padding: const EdgeInsets.all(Spacing.lg),
            decoration: BoxDecoration(
              color: AppStyles.getCardColor(context),
              borderRadius: BorderRadius.circular(Radii.md),
            ),
            onChanged: (v) => ctrl.updateName(v),
          ),
          const SizedBox(height: Spacing.xxl),
          // PAN
          Text('PAN Number',
              style: TextStyle(
                  fontWeight: FontWeight.w600, fontSize: TypeScale.body)),
          const SizedBox(height: Spacing.md),
          CupertinoTextField(
            controller: _panController,
            placeholder: 'XXXXXXXXXX',
            padding: const EdgeInsets.all(Spacing.lg),
            decoration: BoxDecoration(
              color: AppStyles.getCardColor(context),
              borderRadius: BorderRadius.circular(Radii.md),
            ),
            onChanged: (v) => ctrl.updatePAN(v.toUpperCase()),
          ),
          const SizedBox(height: Spacing.xxl),
          // Account Type
          Text('Account Type',
              style: TextStyle(
                  fontWeight: FontWeight.w600, fontSize: TypeScale.body)),
          const SizedBox(height: Spacing.md),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: NPSAccountType.values.map((type) {
              final isSelected = ctrl.accountType == type;
              final label = type == NPSAccountType.individual
                  ? 'Individual'
                  : type == NPSAccountType.nri
                      ? 'NRI'
                      : type == NPSAccountType.minor
                          ? 'Minor'
                          : 'HUF';
              return GestureDetector(
                onTap: () => ctrl.updateAccountType(type),
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
          // Tier
          Text('NPS Tier',
              style: TextStyle(
                  fontWeight: FontWeight.w600, fontSize: TypeScale.body)),
          const SizedBox(height: Spacing.md),
          Row(
            children: NPSTier.values.map((tier) {
              final isSelected = ctrl.selectedTier == tier;
              final label = tier == NPSTier.tier1
                  ? 'Tier 1 (Locked)'
                  : 'Tier 2 (Flexible)';
              return Expanded(
                child: GestureDetector(
                  onTap: () => ctrl.updateTier(tier),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
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
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: isSelected ? Colors.white : null,
                            fontWeight: isSelected ? FontWeight.bold : null,
                            fontSize: TypeScale.footnote)),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: Spacing.xl),
        ],
      ),
    );
  }
}
