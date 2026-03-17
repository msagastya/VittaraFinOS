import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/ui/manage/fd/fd_wizard_controller.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';

class PrincipalStep extends StatefulWidget {
  const PrincipalStep({super.key});

  @override
  State<PrincipalStep> createState() => _PrincipalStepState();
}

class _PrincipalStepState extends State<PrincipalStep> {
  late TextEditingController _principalController;

  @override
  void initState() {
    super.initState();
    final controller = Provider.of<FDWizardController>(context, listen: false);
    _principalController = TextEditingController(
      text: controller.principal > 0 ? controller.principal.toString() : '',
    );
  }

  @override
  void dispose() {
    _principalController.dispose();
    super.dispose();
  }

  void _updatePrincipal() {
    final controller = Provider.of<FDWizardController>(context, listen: false);
    final amount = double.tryParse(_principalController.text) ?? 0;
    controller.updatePrincipal(amount);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(Spacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Principal Amount',
            style: AppStyles.titleStyle(context),
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            'Enter the amount to invest in this FD',
            style: TextStyle(color: AppStyles.getSecondaryTextColor(context)),
          ),
          const SizedBox(height: 30),
          Text(
            'Amount',
            style: TextStyle(
              color: AppStyles.getTextColor(context),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: Spacing.md),
          CupertinoTextField(
            controller: _principalController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            placeholder: 'e.g., 50,000',
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
            style: TextStyle(color: AppStyles.getTextColor(context)),
            onChanged: (_) => _updatePrincipal(),
          ),
          const SizedBox(height: 30),
          Consumer<FDWizardController>(
            builder: (context, controller, child) {
              if (controller.principal <= 0) return const SizedBox.shrink();

              return Container(
                padding: const EdgeInsets.all(Spacing.lg),
                decoration: BoxDecoration(
                  color:
                      AppStyles.getBackground(context).withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppStyles.getPrimaryColor(context)
                        .withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Summary',
                      style: TextStyle(
                        color: AppStyles.getSecondaryTextColor(context),
                        fontSize: TypeScale.footnote,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: Spacing.sm),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Principal',
                          style: TextStyle(
                              color: AppStyles.getSecondaryTextColor(context)),
                        ),
                        Text(
                          '₹${controller.principal.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: AppStyles.getTextColor(context),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
