import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/ui/manage/stocks/stocks_wizard_controller.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';

class DeductionStep extends StatefulWidget {
  const DeductionStep({super.key});

  @override
  State<DeductionStep> createState() => _DeductionStepState();
}

class _DeductionStepState extends State<DeductionStep> {
  late TextEditingController _chargesController;

  @override
  void initState() {
    super.initState();
    final controller =
        Provider.of<StocksWizardController>(context, listen: false);
    _chargesController = TextEditingController(
      text:
          controller.extraCharges > 0 ? controller.extraCharges.toString() : '',
    );
  }

  void _updateController(bool value) {
    final controller =
        Provider.of<StocksWizardController>(context, listen: false);
    final charges = double.tryParse(_chargesController.text) ?? 0;
    controller.updateDeduction(deduct: value, charges: charges);
  }

  void _onChargesChanged(String value) {
    final controller =
        Provider.of<StocksWizardController>(context, listen: false);
    final charges = double.tryParse(value) ?? 0;
    controller.updateDeduction(
        deduct: controller.deductFromAccount, charges: charges);
  }

  @override
  void dispose() {
    _chargesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<StocksWizardController>(context);
    final account = controller.selectedAccount;

    // Safety check - should have account by this step
    if (account == null) {
      return const Center(child: Text("Error: No account selected"));
    }

    final hasInsufficientBalance = controller.deductFromAccount &&
        account.balance < controller.totalDeduction;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Payment',
            style: AppStyles.titleStyle(context),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: AppStyles.cardDecoration(context),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Deduct from Demat Account?',
                            style: TextStyle(
                              color: AppStyles.getTextColor(context),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Balance: ₹${account.balance.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: AppStyles.getSecondaryTextColor(context),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    CupertinoSwitch(
                      value: controller.deductFromAccount,
                      activeTrackColor: SemanticColors.investments,
                      onChanged: (val) => _updateController(val),
                    ),
                  ],
                ),
                if (controller.deductFromAccount) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Divider(height: 1),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Extra Charges',
                          style:
                              TextStyle(color: AppStyles.getTextColor(context)),
                        ),
                      ),
                      SizedBox(
                        width: 100,
                        child: CupertinoTextField(
                          controller: _chargesController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          placeholder: '0.00',
                          padding: const EdgeInsets.symmetric(
                              vertical: 8, horizontal: 12),
                          decoration: BoxDecoration(
                            color: isDarkMode(context)
                                ? Colors.grey[800]
                                : Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          style:
                              TextStyle(color: AppStyles.getTextColor(context)),
                          onChanged: _onChargesChanged,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (controller.deductFromAccount) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: hasInsufficientBalance
                    ? Colors.red.withValues(alpha: 0.1)
                    : Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: hasInsufficientBalance ? Colors.red : Colors.green,
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Purchase Amount:'),
                      Text('₹${controller.totalAmount.toStringAsFixed(2)}'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Charges:'),
                      Text('₹${controller.extraCharges.toStringAsFixed(2)}'),
                    ],
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Deduction:',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(
                        '₹${controller.totalDeduction.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (hasInsufficientBalance)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Row(
                  children: [
                    const Icon(CupertinoIcons.exclamationmark_triangle_fill,
                        color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Insufficient balance in ${account.name}. Please add funds first.',
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  bool isDarkMode(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;
}
