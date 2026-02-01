import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/account_model.dart';
import 'package:vittara_fin_os/logic/accounts_controller.dart';
import 'package:vittara_fin_os/ui/manage/account_wizard.dart';
import 'package:vittara_fin_os/ui/manage/bonds/bonds_wizard_controller.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/widgets/animations.dart';

class BondsAccountStep extends StatefulWidget {
  const BondsAccountStep({super.key});

  @override
  State<BondsAccountStep> createState() => _BondsAccountStepState();
}

class _BondsAccountStepState extends State<BondsAccountStep> {
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

  @override
  Widget build(BuildContext context) {
    final wizardController = Provider.of<BondsWizardController>(context);

    return Consumer<AccountsController>(
      builder: (context, accountsController, child) {
        // Filter for savings accounts where bonds can be linked
        final accounts = accountsController.accounts
            .where((acc) => acc.type == AccountType.savings)
            .toList();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Select Linked Account',
                style: AppStyles.titleStyle(context),
              ),
            ),
            Expanded(
              child: accounts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(CupertinoIcons.chart_pie,
                              size: 48, color: Colors.grey),
                          const SizedBox(height: 16),
                          Text(
                            'No Savings Accounts Found',
                            style: TextStyle(
                              color: AppStyles.getSecondaryTextColor(context),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: accounts.length,
                      itemBuilder: (context, index) {
                        final account = accounts[index];
                        final isSelected =
                            wizardController.selectedAccountId == account.id;

                        return GestureDetector(
                          onTap: () {
                            wizardController.updateAccountSelection(
                              account.id,
                              account.name,
                            );
                          },
                          child: Container(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF007AFF).withValues(alpha: 0.1)
                                  : AppStyles.getCardColor(context),
                              border: isSelected
                                  ? Border.all(
                                      color: const Color(0xFF007AFF),
                                    )
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
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: account.color.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    CupertinoIcons.creditcard,
                                    color: account.color,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        account.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      Text(
                                        account.bankName,
                                        style: TextStyle(
                                          color: AppStyles
                                              .getSecondaryTextColor(context),
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
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (isSelected)
                                      const Padding(
                                        padding: EdgeInsets.only(top: 4),
                                        child: Icon(
                                          CupertinoIcons
                                              .check_mark_circled_solid,
                                          color: Color(0xFF007AFF),
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
                onPressed: () {
                  final accountsController =
                      Provider.of<AccountsController>(context, listen: false);
                  final wizardCtrl =
                      Provider.of<BondsWizardController>(context, listen: false);

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
                      wizardCtrl.updateAccountSelection(result.id, result.name);
                    }
                  });
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(CupertinoIcons.add,
                        color: AppStyles.getTextColor(context)),
                    const SizedBox(width: 8),
                    Text(
                      'Add Savings Account',
                      style: TextStyle(
                        color: AppStyles.getTextColor(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  bool isDarkMode(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;
}
