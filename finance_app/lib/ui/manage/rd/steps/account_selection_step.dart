import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/account_model.dart';
import 'package:vittara_fin_os/logic/accounts_controller.dart';
import 'package:vittara_fin_os/ui/manage/account_wizard.dart';
import 'package:vittara_fin_os/ui/manage/rd/rd_wizard_controller.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/widgets/animations.dart';

class AccountSelectionStep extends StatefulWidget {
  const AccountSelectionStep({super.key});

  @override
  State<AccountSelectionStep> createState() => _AccountSelectionStepState();
}

class _AccountSelectionStepState extends State<AccountSelectionStep> {
  @override
  void initState() {
    super.initState();
    // Refresh accounts when entering this step
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) {
        await Provider.of<AccountsController>(context, listen: false).loadAccounts();
      }
    });
  }

  void _selectAccountAndProceed(Account account) {
    final wizardController = Provider.of<RDWizardController>(context, listen: false);
    wizardController.selectAccount(account);
    // Auto-proceed to next step
    Future.delayed(const Duration(milliseconds: 300), () {
      wizardController.nextStep();
    });
  }

  void _openAccountWizard() {
    final accountsController = Provider.of<AccountsController>(context, listen: false);
    final wizardCtrl = Provider.of<RDWizardController>(context, listen: false);

    Navigator.push<Account>(
      context,
      FadeScalePageRoute(
        page: const AccountWizard(isInvestment: false),
      ),
    ).then((result) {
      if (result != null) {
        // Save the newly created account
        accountsController.addAccount(result);
        // Auto-select the newly added account
        wizardCtrl.selectAccount(result);
        // Auto-proceed to next step
        Future.delayed(const Duration(milliseconds: 300), () {
          wizardCtrl.nextStep();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<RDWizardController>(context);

    return Consumer<AccountsController>(
      builder: (context, accountsController, child) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select Linked Account',
                    style: AppStyles.titleStyle(context),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Installments will be debited from this account',
                    style: TextStyle(color: AppStyles.getSecondaryTextColor(context)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: accountsController.accounts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(CupertinoIcons.money_dollar_circle, size: 48, color: Colors.grey),
                          const SizedBox(height: 16),
                          Text(
                            'No Accounts Found',
                            style: TextStyle(color: AppStyles.getSecondaryTextColor(context)),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: accountsController.accounts.length,
                      itemBuilder: (context, index) {
                        final account = accountsController.accounts[index];
                        final isSelected = controller.selectedAccount?.id == account.id;

                        return GestureDetector(
                          onTap: () => _selectAccountAndProceed(account),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppStyles.getPrimaryColor(context).withOpacity(0.1)
                                  : AppStyles.getCardColor(context),
                              border: isSelected
                                  ? Border.all(color: AppStyles.getPrimaryColor(context))
                                  : Border.all(color: Colors.transparent),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                if (!isSelected)
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected
                                          ? AppStyles.getPrimaryColor(context)
                                          : AppStyles.getSecondaryTextColor(context),
                                      width: 2,
                                    ),
                                  ),
                                  child: isSelected
                                      ? Center(
                                          child: Container(
                                            width: 8,
                                            height: 8,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: AppStyles.getPrimaryColor(context),
                                            ),
                                          ),
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        account.name,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                      Text(
                                        account.bankName ?? 'Bank Account',
                                        style: TextStyle(
                                          color: AppStyles.getSecondaryTextColor(context),
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '₹${account.balance.toStringAsFixed(2)}',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    if (isSelected)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Icon(
                                          CupertinoIcons.check_mark_circled_solid,
                                          color: AppStyles.getPrimaryColor(context),
                                          size: 20,
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: CupertinoButton(
                color: isDarkMode(context) ? Colors.grey[800] : Colors.grey[200],
                onPressed: _openAccountWizard,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(CupertinoIcons.add, color: AppStyles.getTextColor(context)),
                    const SizedBox(width: 8),
                    Text('Add Bank Account', style: TextStyle(color: AppStyles.getTextColor(context))),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  bool isDarkMode(BuildContext context) => Theme.of(context).brightness == Brightness.dark;
}
