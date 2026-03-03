import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/accounts_controller.dart';
import 'package:vittara_fin_os/logic/bond_cashflow_model.dart';
import 'package:vittara_fin_os/ui/manage/bonds/bonds_wizard_controller_v2.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';

class BondTypeNameStep extends StatelessWidget {
  final BondsWizardControllerV2 ctrl;

  const BondTypeNameStep(this.ctrl, {super.key});

  void _showAccountPicker(
    BuildContext context,
    String title,
    Function(String, String) onSelect,
    String? currentAccountId,
  ) {
    final accountsController =
        Provider.of<AccountsController>(context, listen: false);

    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => Container(
        color: AppStyles.getBackground(context),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(Spacing.lg),
              decoration: BoxDecoration(
                color: AppStyles.getCardColor(context),
                border: Border(
                  bottom: BorderSide(color: CupertinoColors.systemGrey.withValues(alpha: 0.2)),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: TypeScale.headline,
                      fontWeight: FontWeight.bold,
                      color: AppStyles.getTextColor(context),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: const Icon(CupertinoIcons.xmark),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(Spacing.lg),
                children: [
                  ...accountsController.accounts.map((account) {
                    final isSelected = currentAccountId == account.id;
                    return GestureDetector(
                      onTap: () {
                        onSelect(account.id, account.name);
                        Navigator.pop(ctx);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF00A6CC).withValues(alpha: 0.1)
                              : AppStyles.getBackground(context),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF00A6CC)
                                : Colors.transparent,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    account.name,
                                    style: TextStyle(
                                      fontSize: TypeScale.body,
                                      fontWeight: FontWeight.w600,
                                      color: isSelected
                                          ? const Color(0xFF00A6CC)
                                          : AppStyles.getTextColor(context),
                                    ),
                                  ),
                                  Text(
                                    account.bankName,
                                    style: TextStyle(
                                      fontSize: TypeScale.footnote,
                                      color: AppStyles.getSecondaryTextColor(
                                          context),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected)
                              const Icon(CupertinoIcons.checkmark_alt,
                                  color: Color(0xFF00A6CC)),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(Spacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Bond Type', style: AppStyles.titleStyle(context)),
          const SizedBox(height: Spacing.xl),
          Column(
            children: BondType.values.map((type) {
              final isSelected = ctrl.selectedType == type;
              final details = {
                BondType.fixedCoupon: (
                  'Fixed Coupon Bond',
                  'Regular coupon + principal at maturity'
                ),
                BondType.zeroCoupon: (
                  'Zero Coupon Bond',
                  'Buy at discount, single maturity payment'
                ),
                BondType.monthlyFixed: (
                  'Monthly Fixed Bond',
                  'Fixed coupon paid monthly'
                ),
                BondType.amortizing: (
                  'Amortizing Bond',
                  'Principal repaid gradually with interest'
                ),
                BondType.floatingRate: (
                  'Floating Rate Bond',
                  'Coupon varies with reference rate'
                ),
              };
              final (title, desc) = details[type]!;

              return GestureDetector(
                onTap: () => ctrl.selectType(type),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(Spacing.lg),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF00A6CC).withValues(alpha: 0.1)
                        : AppStyles.getCardColor(context),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF00A6CC)
                          : CupertinoColors.systemGrey.withValues(alpha: 0.2),
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF00A6CC)
                                : CupertinoColors.systemGrey,
                          ),
                        ),
                        child: isSelected
                            ? Center(
                                child: Container(
                                  width: 10,
                                  height: 10,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF00A6CC),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: Spacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            Text(desc,
                                style: TextStyle(
                                    fontSize: TypeScale.footnote,
                                    color: AppStyles.getSecondaryTextColor(
                                        context))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: Spacing.xxl),
          Text('Bond Name',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: TypeScale.body)),
          const SizedBox(height: Spacing.md),
          CupertinoTextField(
            placeholder: 'e.g., RBI Bond 2028, Government Securities',
            padding: const EdgeInsets.all(Spacing.lg),
            decoration: BoxDecoration(
              color: AppStyles.getCardColor(context),
              borderRadius: BorderRadius.circular(12),
            ),
            onChanged: (v) => ctrl.updateBondName(v),
          ),
          const SizedBox(height: Spacing.xxl),
          // Purchase Account Section
          Text('Purchase Account (Optional)',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: TypeScale.body)),
          const SizedBox(height: Spacing.sm),
          Text(
            'Account to debit when purchasing this bond',
            style: TextStyle(
              fontSize: TypeScale.footnote,
              color: AppStyles.getSecondaryTextColor(context),
            ),
          ),
          const SizedBox(height: Spacing.md),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppStyles.getCardColor(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: CupertinoColors.systemGrey.withValues(alpha: 0.2)),
            ),
            child: CupertinoButton(
              onPressed: () {
                _showAccountPicker(
                  context,
                  'Select Purchase Account',
                  (id, name) => ctrl.updatePurchaseAccount(id, name),
                  ctrl.purchaseAccountId,
                );
              },
              padding: EdgeInsets.zero,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (ctrl.purchaseAccountId == null)
                    Text(
                      'No account selected',
                      style: TextStyle(
                        color: AppStyles.getSecondaryTextColor(context),
                      ),
                    )
                  else
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ctrl.purchaseAccountName ?? 'Unknown',
                            style: TextStyle(
                              color: AppStyles.getTextColor(context),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const Icon(CupertinoIcons.down_arrow),
                ],
              ),
            ),
          ),
          // Auto-debit toggle
          if (ctrl.purchaseAccountId != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Auto-debit from this account',
                    style: TextStyle(
                      fontSize: TypeScale.subhead,
                      color: AppStyles.getSecondaryTextColor(context),
                    ),
                  ),
                  CupertinoSwitch(
                    value: ctrl.autoDebitFromPurchaseAccount,
                    onChanged: ctrl.updateAutoDebit,
                  ),
                ],
              ),
            ),
          const SizedBox(height: Spacing.xxl),
          // Payment Account Section
          Text('Payment Account (Optional)',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: TypeScale.body)),
          const SizedBox(height: Spacing.sm),
          Text(
            'Account to receive coupon/maturity payments',
            style: TextStyle(
              fontSize: TypeScale.footnote,
              color: AppStyles.getSecondaryTextColor(context),
            ),
          ),
          const SizedBox(height: Spacing.md),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppStyles.getCardColor(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: CupertinoColors.systemGrey.withValues(alpha: 0.2)),
            ),
            child: CupertinoButton(
              onPressed: () {
                _showAccountPicker(
                  context,
                  'Select Payment Account',
                  (id, name) => ctrl.updatePaymentAccount(id, name),
                  ctrl.paymentAccountId,
                );
              },
              padding: EdgeInsets.zero,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (ctrl.paymentAccountId == null)
                    Text(
                      'No account selected',
                      style: TextStyle(
                        color: AppStyles.getSecondaryTextColor(context),
                      ),
                    )
                  else
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ctrl.paymentAccountName ?? 'Unknown',
                            style: TextStyle(
                              color: AppStyles.getTextColor(context),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const Icon(CupertinoIcons.down_arrow),
                ],
              ),
            ),
          ),
          // Auto-transfer toggle
          if (ctrl.paymentAccountId != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Auto-transfer payments to this account',
                    style: TextStyle(
                      fontSize: TypeScale.subhead,
                      color: AppStyles.getSecondaryTextColor(context),
                    ),
                  ),
                  CupertinoSwitch(
                    value: ctrl.autoTransferPayments,
                    onChanged: ctrl.updateAutoTransfer,
                  ),
                ],
              ),
            ),
          const SizedBox(height: Spacing.xl),
        ],
      ),
    );
  }
}
