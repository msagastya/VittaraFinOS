import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/ui/manage/rd/rd_wizard_controller.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';

class AmountStep extends StatefulWidget {
  const AmountStep({super.key});

  @override
  State<AmountStep> createState() => _AmountStepState();
}

class _AmountStepState extends State<AmountStep> {
  late TextEditingController _amountController;

  @override
  void initState() {
    super.initState();
    final controller = Provider.of<RDWizardController>(context, listen: false);
    _amountController = TextEditingController(
      text: controller.monthlyAmount > 0
          ? controller.monthlyAmount.toString()
          : '',
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _updateAmount() {
    final controller = Provider.of<RDWizardController>(context, listen: false);
    final amount = double.tryParse(_amountController.text) ?? 0;
    controller.updateMonthlyAmount(amount);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(Spacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Installment Amount',
            style: AppStyles.titleStyle(context),
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            'Amount to be deposited for each installment',
            style: TextStyle(color: AppStyles.getSecondaryTextColor(context)),
          ),
          const SizedBox(height: 30),
          Text(
            'Amount per Installment',
            style: TextStyle(
              color: AppStyles.getTextColor(context),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: Spacing.md),
          CupertinoTextField(
            controller: _amountController,
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
            style: TextStyle(color: AppStyles.getTextColor(context)),
            onChanged: (_) => _updateAmount(),
          ),
          const SizedBox(height: 30),
          Consumer<RDWizardController>(
            builder: (context, controller, child) {
              if (controller.monthlyAmount <= 0) return const SizedBox.shrink();

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
                      'Summary',
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
                          'Per Installment',
                          style: TextStyle(
                              color: AppStyles.getSecondaryTextColor(context)),
                        ),
                        Text(
                          '₹${controller.monthlyAmount.toStringAsFixed(2)}',
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
                          'Total Installments',
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
