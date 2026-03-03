import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/bonds_model.dart';
import 'package:vittara_fin_os/ui/manage/bonds/bonds_wizard_controller.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';

class BondsTypeIssuerStep extends StatefulWidget {
  const BondsTypeIssuerStep({super.key});

  @override
  State<BondsTypeIssuerStep> createState() => _BondsTypeIssuerStepState();
}

class _BondsTypeIssuerStepState extends State<BondsTypeIssuerStep> {
  late TextEditingController _issuerController;
  late TextEditingController _nameController;
  late TextEditingController _faceValueController;

  // Common bond issuers by type
  final governmentIssuers = [
    'Government of India',
    'State Development Loan (SDL)',
    'RBI Security Bonds',
    'Sovereign Gold Bond',
  ];

  final corporateIssuers = [
    'HDFC Bank',
    'ICICI Bank',
    'Axis Bank',
    'Infosys',
    'TCS',
    'Reliance Industries',
    'NTPC',
    'Power Finance Corporation',
  ];

  final municipalIssuers = [
    'Pune Municipal Corporation',
    'Delhi Municipal Corporation',
    'Mumbai Municipal Corporation',
    'Bengaluru Municipal Corporation',
  ];

  @override
  void initState() {
    super.initState();
    final controller =
        Provider.of<BondsWizardController>(context, listen: false);
    _issuerController =
        TextEditingController(text: controller.selectedIssuer ?? '');
    _nameController = TextEditingController(text: controller.bondName ?? '');
    _faceValueController = TextEditingController(
      text:
          controller.faceValue != null ? controller.faceValue!.toString() : '',
    );
  }

  @override
  void dispose() {
    _issuerController.dispose();
    _nameController.dispose();
    _faceValueController.dispose();
    super.dispose();
  }

  List<String> getIssuersForType(BondType type) {
    switch (type) {
      case BondType.government:
        return governmentIssuers;
      case BondType.corporate:
        return corporateIssuers;
      case BondType.municipal:
        return municipalIssuers;
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<BondsWizardController>(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bond Details',
            style: AppStyles.titleStyle(context),
          ),
          const SizedBox(height: 8),
          Text(
            'Select bond type and issuer details',
            style: TextStyle(color: AppStyles.getSecondaryTextColor(context)),
          ),
          const SizedBox(height: 30),
          // Bond Type Selection
          Text(
            'Bond Type',
            style: TextStyle(
              color: AppStyles.getTextColor(context),
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: BondType.values.map((type) {
              final isSelected = controller.selectedBondType == type;
              final label = type == BondType.government
                  ? 'Government'
                  : type == BondType.corporate
                      ? 'Corporate'
                      : 'Municipal';

              return GestureDetector(
                onTap: () {
                  controller.updateBondType(type);
                  _issuerController.clear();
                  setState(() {});
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF007AFF)
                        : AppStyles.getCardColor(context),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF007AFF)
                          : Colors.transparent,
                    ),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : AppStyles.getTextColor(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 30),
          // Issuer Selection
          if (controller.selectedBondType != null) ...[
            Text(
              'Issuer',
              style: TextStyle(
                color: AppStyles.getTextColor(context),
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            CupertinoTextField(
              controller: _issuerController,
              placeholder: 'Select or type issuer',
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppStyles.getCardColor(context),
                borderRadius: BorderRadius.circular(12),
              ),
              style: TextStyle(color: AppStyles.getTextColor(context)),
              onChanged: (value) {
                controller.updateIssuer(value);
              },
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount:
                    getIssuersForType(controller.selectedBondType!).length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final issuer =
                      getIssuersForType(controller.selectedBondType!)[index];
                  final isSelected = controller.selectedIssuer == issuer;

                  return GestureDetector(
                    onTap: () {
                      controller.updateIssuer(issuer);
                      _issuerController.text = issuer;
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF007AFF)
                            : AppStyles.getCardColor(context),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF007AFF)
                              : CupertinoColors.systemGrey.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        issuer,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : AppStyles.getTextColor(context),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 30),
            // Bond Name
            Text(
              'Bond Name',
              style: TextStyle(
                color: AppStyles.getTextColor(context),
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            CupertinoTextField(
              controller: _nameController,
              placeholder: 'e.g., Government Bond 7% 2030',
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppStyles.getCardColor(context),
                borderRadius: BorderRadius.circular(12),
              ),
              style: TextStyle(color: AppStyles.getTextColor(context)),
              onChanged: (value) {
                controller.updateBondName(value);
              },
            ),
            const SizedBox(height: 30),
            // Face Value
            Text(
              'Face Value (₹)',
              style: TextStyle(
                color: AppStyles.getTextColor(context),
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            CupertinoTextField(
              controller: _faceValueController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              placeholder: '1000',
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppStyles.getCardColor(context),
                borderRadius: BorderRadius.circular(12),
              ),
              prefix: Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Text(
                  '₹',
                  style: TextStyle(color: AppStyles.getTextColor(context)),
                ),
              ),
              style: TextStyle(color: AppStyles.getTextColor(context)),
              onChanged: (value) {
                final faceValue = double.tryParse(value) ?? 0;
                if (faceValue > 0) {
                  controller.updateFaceValue(faceValue);
                }
              },
            ),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
