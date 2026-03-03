import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/nps_model.dart';
import 'package:vittara_fin_os/ui/manage/nps/nps_wizard_controller.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';

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
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('NPS Account Details', style: AppStyles.titleStyle(context)),
          const SizedBox(height: 8),
          Text('Enter your NPS account information',
              style:
                  TextStyle(color: AppStyles.getSecondaryTextColor(context))),
          const SizedBox(height: 30),
          // PRN
          Text('Permanent Retirement Number (PRN)',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 12),
          CupertinoTextField(
            controller: _prnController,
            placeholder: 'e.g., PRANXXXXXXXX',
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppStyles.getCardColor(context),
              borderRadius: BorderRadius.circular(12),
            ),
            onChanged: (v) => ctrl.updatePRN(v),
          ),
          const SizedBox(height: 24),
          // NRN
          Text('National Registration Number (NRN)',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 12),
          CupertinoTextField(
            controller: _nrnController,
            placeholder: 'e.g., NRNXXXXXXXX',
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppStyles.getCardColor(context),
              borderRadius: BorderRadius.circular(12),
            ),
            onChanged: (v) => ctrl.updateNRN(v),
          ),
          const SizedBox(height: 24),
          // Name
          Text('Subscriber Name',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 12),
          CupertinoTextField(
            controller: _nameController,
            placeholder: 'Full name',
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppStyles.getCardColor(context),
              borderRadius: BorderRadius.circular(12),
            ),
            onChanged: (v) => ctrl.updateName(v),
          ),
          const SizedBox(height: 24),
          // PAN
          Text('PAN Number',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 12),
          CupertinoTextField(
            controller: _panController,
            placeholder: 'XXXXXXXXXX',
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppStyles.getCardColor(context),
              borderRadius: BorderRadius.circular(12),
            ),
            onChanged: (v) => ctrl.updatePAN(v.toUpperCase()),
          ),
          const SizedBox(height: 24),
          // Account Type
          Text('Account Type',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 12),
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
                          fontSize: 12)),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          // Tier
          Text('NPS Tier',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 12),
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
                            fontSize: 12)),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
