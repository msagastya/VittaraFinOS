import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/account_model.dart';
import 'package:vittara_fin_os/logic/accounts_controller.dart';
import 'package:vittara_fin_os/ui/manage/account_wizard.dart';
import 'package:vittara_fin_os/ui/manage/stocks/stocks_wizard_controller.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
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
        await Provider.of<AccountsController>(context, listen: false)
            .loadAccounts();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final wizardController = Provider.of<StocksWizardController>(context);

    return Consumer<AccountsController>(
      builder: (context, accountsController, child) {
        // Filter for Investment or generic accounts if needed.
        // User said "Demat account", assuming Investment type accounts are Demat.
        final accounts = accountsController.accounts
            .where((acc) => acc.type == AccountType.investment)
            .toList();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Select Demat Account',
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
                              size: 48, color: CupertinoColors.systemGrey),
                          const SizedBox(height: 16),
                          Text(
                            'No Investment Accounts Found',
                            style: TextStyle(
                                color:
                                    AppStyles.getSecondaryTextColor(context)),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: accounts.length,
                      itemBuilder: (context, index) {
                        final account = accounts[index];
                        final isSelected =
                            wizardController.selectedAccount?.id == account.id;

                        return GestureDetector(
                          onTap: () {
                            wizardController.selectAccount(account);
                            // Auto-proceed to next step
                            Future.delayed(const Duration(milliseconds: 300),
                                () {
                              wizardController.nextPage();
                            });
                          },
                          child: Container(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? SemanticColors.investments
                                      .withValues(alpha: 0.1)
                                  : AppStyles.getCardColor(context),
                              border: isSelected
                                  ? Border.all(
                                      color: SemanticColors.investments)
                                  : Border.all(color: Colors.transparent),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                if (!isSelected)
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
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
                                    color: account.color.withValues(alpha: 0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(CupertinoIcons.briefcase_fill,
                                      color: account.color),
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
                                            fontSize: TypeScale.headline),
                                      ),
                                      Text(
                                        account.bankName,
                                        style: TextStyle(
                                          color:
                                              AppStyles.getSecondaryTextColor(
                                                  context),
                                          fontSize: TypeScale.subhead,
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
                                          fontWeight: FontWeight.bold),
                                    ),
                                    if (isSelected)
                                      const Padding(
                                        padding: EdgeInsets.only(top: 4),
                                        child: Icon(
                                            CupertinoIcons
                                                .check_mark_circled_solid,
                                            color: SemanticColors.investments,
                                            size: 20),
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
                color:
                    isDarkMode(context) ? Colors.grey[800] : Colors.grey[200],
                onPressed: () {
                  final accountsController =
                      Provider.of<AccountsController>(context, listen: false);
                  final wizardCtrl = Provider.of<StocksWizardController>(
                      context,
                      listen: false);

                  Navigator.push<Account>(
                    context,
                    FadeScalePageRoute(
                      page: const AccountWizard(isInvestment: true),
                    ),
                  ).then((result) {
                    if (result != null) {
                      // Save the newly created account
                      accountsController.addAccount(result);
                      // Auto-select the newly added account
                      wizardCtrl.selectAccount(result);
                      // Auto-proceed to next step
                      Future.delayed(const Duration(milliseconds: 300), () {
                        wizardCtrl.nextPage();
                      });
                    }
                  });
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(CupertinoIcons.add,
                        color: AppStyles.getTextColor(context)),
                    const SizedBox(width: 8),
                    Text('Add Demat Account',
                        style:
                            TextStyle(color: AppStyles.getTextColor(context))),
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
