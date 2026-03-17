import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/account_model.dart';
import 'package:vittara_fin_os/logic/accounts_controller.dart';
import 'package:vittara_fin_os/logic/transaction_model.dart';
import 'package:vittara_fin_os/logic/transactions_controller.dart';
import 'package:vittara_fin_os/ui/manage/transfer_wizard.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/widgets/animations.dart';
import 'package:vittara_fin_os/ui/widgets/common_widgets.dart';
import 'package:vittara_fin_os/ui/widgets/toast_notification.dart';

class CashScreen extends StatelessWidget {
  const CashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppStyles.getBackground(context),
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          'Cash',
          style: TextStyle(color: AppStyles.getTextColor(context)),
        ),
        previousPageTitle: 'Manage',
        backgroundColor: AppStyles.getBackground(context),
        border: null,
      ),
      child: Consumer<AccountsController>(
        builder: (context, accountsController, child) {
          final cashAccounts = accountsController.accounts
              .where((account) => account.type == AccountType.cash)
              .toList()
            ..sort((a, b) => b.balance.compareTo(a.balance));
          final totalCash = cashAccounts.fold<double>(
            0.0,
            (sum, account) => sum + account.balance,
          );

          return Stack(
            children: [
              SafeArea(
                child: cashAccounts.isEmpty
                    ? EmptyStateView(
                        icon: CupertinoIcons.money_dollar_circle,
                        title: 'No Cash Account Yet',
                        subtitle:
                            'Create Cash in Hand to track all your cash flow',
                        actionLabel: 'Create Cash Account',
                        onAction: () => _showCreateCashAccountSheet(
                            context, accountsController),
                      )
                    : Column(
                        children: [
                          Container(
                            margin: const EdgeInsets.fromLTRB(
                              Spacing.lg,
                              Spacing.md,
                              Spacing.lg,
                              Spacing.md,
                            ),
                            padding: const EdgeInsets.all(Spacing.lg),
                            decoration: BoxDecoration(
                              color: AppStyles.bioGreen
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(Radii.md),
                              border: Border.all(
                                color: AppStyles.bioGreen
                                    .withValues(alpha: 0.35),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  CupertinoIcons.money_dollar_circle_fill,
                                  color: AppStyles.bioGreen,
                                  size: 24,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Total Cash in Hand',
                                    style: TextStyle(
                                      color: AppStyles.getTextColor(context),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Text(
                                  '₹${totalCash.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    color: AppStyles.bioGreen,
                                    fontWeight: FontWeight.bold,
                                    fontSize: TypeScale.headline,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: Spacing.lg),
                            child: Row(
                              children: [
                                Expanded(
                                  child: BouncyButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        FadeScalePageRoute(
                                          page: const TransferWizard(),
                                        ),
                                      );
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: CupertinoColors.systemBlue
                                            .withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(Radii.md),
                                        border: Border.all(
                                          color: CupertinoColors.systemBlue
                                              .withValues(alpha: 0.4),
                                        ),
                                      ),
                                      child: const Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            CupertinoIcons
                                                .arrow_right_arrow_left,
                                            color: CupertinoColors.systemBlue,
                                            size: 18,
                                          ),
                                          SizedBox(width: Spacing.sm),
                                          Text(
                                            'Withdraw / Deposit',
                                            style: TextStyle(
                                              color: CupertinoColors.systemBlue,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: Spacing.md),
                          Expanded(
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(
                                Spacing.lg,
                                0,
                                Spacing.lg,
                                110,
                              ),
                              itemCount: cashAccounts.length,
                              itemBuilder: (context, index) {
                                final account = cashAccounts[index];
                                return _CashAccountCard(
                                  account: account,
                                  onAdjust: () =>
                                      _showAdjustCashSheet(context, account),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
              ),
              Positioned(
                right: Spacing.lg,
                bottom: Spacing.xxxl,
                child: FadingFAB(
                  onPressed: () =>
                      _showCreateCashAccountSheet(context, accountsController),
                  color: AppStyles.bioGreen,
                  heroTag: 'cash_fab',
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showCreateCashAccountSheet(
      BuildContext context, AccountsController controller) {
    final nameController = TextEditingController(text: 'Cash in Hand');
    final balanceController = TextEditingController();

    showCupertinoModalPopup(
      context: context,
      builder: (sheetContext) {
        return Container(
          decoration: BoxDecoration(
            color: AppStyles.getCardColor(sheetContext),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: 24 + MediaQuery.of(sheetContext).viewInsets.bottom,
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const ModalHandle(),
                    const SizedBox(height: Spacing.lg),
                    Text(
                      'Create Cash Account',
                      style: AppStyles.titleStyle(sheetContext).copyWith(
                        fontSize: TypeScale.title1,
                      ),
                    ),
                    const SizedBox(height: Spacing.md),
                    CupertinoTextField(
                      controller: nameController,
                      placeholder: 'Name',
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppStyles.getBackground(sheetContext),
                        borderRadius: BorderRadius.circular(Radii.md),
                      ),
                    ),
                    const SizedBox(height: Spacing.md),
                    CupertinoTextField(
                      controller: balanceController,
                      placeholder: 'Opening cash balance',
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppStyles.getBackground(sheetContext),
                        borderRadius: BorderRadius.circular(Radii.md),
                      ),
                    ),
                    const SizedBox(height: Spacing.lg),
                    SizedBox(
                      width: double.infinity,
                      child: CupertinoButton.filled(
                        onPressed: () async {
                          final name = nameController.text.trim();
                          final balance =
                              double.tryParse(balanceController.text.trim()) ??
                                  0.0;
                          if (name.isEmpty) {
                            toast.showError('Please enter a name');
                            return;
                          }
                          if (balance < 0) {
                            toast.showError('Balance cannot be negative');
                            return;
                          }
                          final account = Account(
                            id: DateTime.now()
                                .millisecondsSinceEpoch
                                .toString(),
                            name: name,
                            bankName: 'Cash',
                            type: AccountType.cash,
                            balance: balance,
                            color: AppStyles.bioGreen,
                          );
                          await controller.addAccount(account);
                          if (!context.mounted) return;
                          Navigator.pop(sheetContext);
                          toast.showSuccess('Cash account created');
                        },
                        child: const Text('Create'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ).whenComplete(() {
      nameController.dispose();
      balanceController.dispose();
    });
  }

  void _showAdjustCashSheet(BuildContext context, Account account) {
    final amountController = TextEditingController();
    bool isAdding = true;

    showCupertinoModalPopup(
      context: context,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: BoxDecoration(
                color: AppStyles.getCardColor(context),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: 24,
                    right: 24,
                    top: 24,
                    bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
                  ),
                  child: SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const ModalHandle(),
                        const SizedBox(height: Spacing.lg),
                        Text(
                          'Adjust Cash',
                          style: AppStyles.titleStyle(context).copyWith(
                            fontSize: TypeScale.title1,
                          ),
                        ),
                        const SizedBox(height: Spacing.sm),
                        Text(
                          account.name,
                          style: TextStyle(
                            color: AppStyles.getSecondaryTextColor(context),
                          ),
                        ),
                        const SizedBox(height: Spacing.md),
                        Container(
                          decoration: BoxDecoration(
                            color: AppStyles.getBackground(context),
                            borderRadius: BorderRadius.circular(Radii.md),
                          ),
                          padding: const EdgeInsets.all(Spacing.xs),
                          child: Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () =>
                                      setModalState(() => isAdding = true),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isAdding
                                          ? AppStyles.bioGreen
                                          : CupertinoColors.transparent,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      'Add',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: isAdding
                                            ? CupertinoColors.white
                                            : AppStyles.getSecondaryTextColor(
                                                context),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () =>
                                      setModalState(() => isAdding = false),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: !isAdding
                                          ? AppStyles.plasmaRed
                                          : CupertinoColors.transparent,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      'Spend',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: !isAdding
                                            ? CupertinoColors.white
                                            : AppStyles.getSecondaryTextColor(
                                                context),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: Spacing.lg),
                        CupertinoTextField(
                          controller: amountController,
                          placeholder: 'Amount',
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppStyles.getBackground(context),
                            borderRadius: BorderRadius.circular(Radii.md),
                          ),
                        ),
                        const SizedBox(height: Spacing.lg),
                        SizedBox(
                          width: double.infinity,
                          child: CupertinoButton.filled(
                            onPressed: () async {
                              final amount = double.tryParse(
                                      amountController.text.trim()) ??
                                  0.0;
                              if (amount <= 0) {
                                toast.showError('Enter a valid amount');
                                return;
                              }
                              if (!isAdding && amount > account.balance) {
                                toast.showError(
                                    'Cash account does not have enough balance');
                                return;
                              }

                              final accountsController =
                                  Provider.of<AccountsController>(
                                context,
                                listen: false,
                              );
                              final transactionsController =
                                  Provider.of<TransactionsController>(
                                context,
                                listen: false,
                              );

                              final updated = account.copyWith(
                                balance: isAdding
                                    ? account.balance + amount
                                    : account.balance - amount,
                              );
                              await accountsController.updateAccount(updated);

                              await transactionsController.addTransaction(
                                Transaction(
                                  id: DateTime.now()
                                      .millisecondsSinceEpoch
                                      .toString(),
                                  type: isAdding
                                      ? TransactionType.income
                                      : TransactionType.expense,
                                  description: isAdding
                                      ? 'Cash added manually'
                                      : 'Cash spent manually',
                                  dateTime: DateTime.now(),
                                  amount: amount,
                                  sourceAccountId: updated.id,
                                  sourceAccountName: updated.name,
                                  metadata: {
                                    'paymentType': 'cash',
                                    'cashFlowType': 'manual_adjustment',
                                    'adjustmentType':
                                        isAdding ? 'credit' : 'debit',
                                  },
                                ),
                              );

                              if (!context.mounted) return;
                              Navigator.pop(sheetContext);
                              toast.showSuccess(
                                isAdding
                                    ? 'Cash balance increased'
                                    : 'Cash balance reduced',
                              );
                            },
                            child: const Text('Apply'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(amountController.dispose);
  }
}

class _CashAccountCard extends StatelessWidget {
  const _CashAccountCard({
    required this.account,
    required this.onAdjust,
  });

  final Account account;
  final VoidCallback onAdjust;

  @override
  Widget build(BuildContext context) {
    return BouncyButton(
      onPressed: onAdjust,
      child: Container(
        margin: const EdgeInsets.only(bottom: Spacing.md),
        decoration: AppStyles.cardDecoration(context).copyWith(
          border: Border.all(
            color: AppStyles.bioGreen.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        padding: const EdgeInsets.all(Spacing.lg),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppStyles.bioGreen.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                CupertinoIcons.money_dollar_circle_fill,
                color: AppStyles.bioGreen,
                size: 24,
              ),
            ),
            const SizedBox(width: Spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    account.name,
                    style: AppStyles.titleStyle(context)
                        .copyWith(fontSize: TypeScale.headline),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Tap to adjust cash',
                    style: TextStyle(
                      color: AppStyles.getSecondaryTextColor(context),
                      fontSize: TypeScale.footnote,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '₹${account.balance.toStringAsFixed(2)}',
              style: const TextStyle(
                color: AppStyles.bioGreen,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
