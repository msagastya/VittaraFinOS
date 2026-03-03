import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/ui/manage/rd/rd_wizard_controller.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';

class InstallmentsStep extends StatefulWidget {
  const InstallmentsStep({super.key});

  @override
  State<InstallmentsStep> createState() => _InstallmentsStepState();
}

class _InstallmentsStepState extends State<InstallmentsStep> {
  late TextEditingController _installmentsController;

  @override
  void initState() {
    super.initState();
    final controller = Provider.of<RDWizardController>(context, listen: false);
    _installmentsController =
        TextEditingController(text: controller.totalInstallments.toString());
  }

  @override
  void dispose() {
    _installmentsController.dispose();
    super.dispose();
  }

  void _updateInstallments() {
    final controller = Provider.of<RDWizardController>(context, listen: false);
    final count = int.tryParse(_installmentsController.text) ?? 12;
    controller.updateTotalInstallments(count);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(Spacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total Installments',
            style: AppStyles.titleStyle(context),
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            'How many installments will you deposit?',
            style: TextStyle(color: AppStyles.getSecondaryTextColor(context)),
          ),
          const SizedBox(height: 30),
          Text(
            'Number of Installments',
            style: TextStyle(
              color: AppStyles.getTextColor(context),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: Spacing.md),
          CupertinoTextField(
            controller: _installmentsController,
            keyboardType: TextInputType.number,
            placeholder: '12',
            padding: const EdgeInsets.all(Spacing.lg),
            decoration: BoxDecoration(
              color: AppStyles.getCardColor(context),
              borderRadius: BorderRadius.circular(12),
            ),
            style: TextStyle(color: AppStyles.getTextColor(context)),
            onChanged: (_) => _updateInstallments(),
          ),
          const SizedBox(height: 30),
          Consumer<RDWizardController>(
            builder: (context, controller, child) {
              final totalAmount =
                  controller.monthlyAmount * controller.totalInstallments;

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
                      'RD Duration',
                      style: TextStyle(
                        color: AppStyles.getSecondaryTextColor(context),
                        fontSize: TypeScale.footnote,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: Spacing.md),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Installments',
                          style: TextStyle(
                              color: AppStyles.getSecondaryTextColor(context)),
                        ),
                        Text(
                          '${controller.totalInstallments}',
                          style: TextStyle(
                            color: AppStyles.getTextColor(context),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Spacing.sm),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Maturity Date',
                          style: TextStyle(
                              color: AppStyles.getSecondaryTextColor(context)),
                        ),
                        Text(
                          '${controller.maturityDate.day}/${controller.maturityDate.month}/${controller.maturityDate.year}',
                          style: TextStyle(
                            color: AppStyles.getTextColor(context),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Spacing.md),
                    Container(
                      padding: const EdgeInsets.all(Spacing.sm),
                      decoration: BoxDecoration(
                        color: AppStyles.getPrimaryColor(context)
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total Investment',
                            style: TextStyle(
                              color: AppStyles.getTextColor(context),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '₹${totalAmount.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: AppStyles.getPrimaryColor(context),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
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
