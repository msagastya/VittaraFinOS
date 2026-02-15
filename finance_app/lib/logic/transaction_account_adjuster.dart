import 'package:vittara_fin_os/logic/accounts_controller.dart';
import 'package:vittara_fin_os/logic/payment_apps_controller.dart';
import 'package:vittara_fin_os/logic/transaction_model.dart';

class TransactionAccountAdjuster {
  const TransactionAccountAdjuster._();

  static Future<void> reverseTransaction(
    AccountsController accountsController,
    Transaction transaction,
    PaymentAppsController paymentAppsController,
  ) async {
    final amount = transaction.amount;
    final metadata = transaction.metadata ?? {};
    final appWalletAmount = transaction.appWalletAmount ??
        (metadata['appWalletAmount'] as num?)?.toDouble() ??
        0.0;
    final cashbackAmount = transaction.cashbackAmount ?? 0.0;
    final cashbackFlow = metadata['cashbackFlow'] as String? ?? 'bank';

    switch (transaction.type) {
      case TransactionType.expense:
        await _adjustAccount(
          accountsController,
          transaction.sourceAccountId,
          amount - appWalletAmount,
        );
        if (appWalletAmount > 0 && transaction.paymentAppName != null) {
          await paymentAppsController.adjustWalletBalanceByName(
            transaction.paymentAppName!,
            appWalletAmount,
          );
        }
        if (cashbackAmount > 0) {
          if (cashbackFlow == 'paymentApp' &&
              transaction.paymentAppName != null) {
            await paymentAppsController.adjustWalletBalanceByName(
              transaction.paymentAppName!,
              -cashbackAmount,
            );
          } else {
            await _adjustAccount(
              accountsController,
              transaction.cashbackAccountId ?? transaction.sourceAccountId,
              -cashbackAmount,
            );
          }
        }
        break;
      case TransactionType.income:
        await _adjustAccount(
            accountsController, transaction.sourceAccountId, -amount);
        if (cashbackAmount > 0) {
          if (cashbackFlow == 'paymentApp' &&
              transaction.paymentAppName != null) {
            await paymentAppsController.adjustWalletBalanceByName(
              transaction.paymentAppName!,
              -cashbackAmount,
            );
          } else {
            await _adjustAccount(
              accountsController,
              transaction.cashbackAccountId ?? transaction.sourceAccountId,
              -cashbackAmount,
            );
          }
        }
        break;
      case TransactionType.transfer:
        await _adjustAccount(
          accountsController,
          transaction.sourceAccountId,
          (amount - appWalletAmount) + (transaction.charges ?? 0.0),
        );
        await _adjustAccount(
            accountsController, transaction.destinationAccountId, -amount);
        if (appWalletAmount > 0 && transaction.paymentAppName != null) {
          await paymentAppsController.adjustWalletBalanceByName(
            transaction.paymentAppName!,
            appWalletAmount,
          );
        }
        if (cashbackAmount > 0) {
          if (cashbackFlow == 'paymentApp' &&
              transaction.paymentAppName != null) {
            await paymentAppsController.adjustWalletBalanceByName(
              transaction.paymentAppName!,
              -cashbackAmount,
            );
          } else {
            await _adjustAccount(
              accountsController,
              transaction.cashbackAccountId ?? transaction.sourceAccountId,
              -cashbackAmount,
            );
          }
        }
        break;
      default:
        // No balance impact
        break;
    }
  }

  static Future<void> _adjustAccount(
    AccountsController accountsController,
    String? accountId,
    double delta,
  ) async {
    if (accountId == null) return;

    final index =
        accountsController.accounts.indexWhere((acc) => acc.id == accountId);
    if (index == -1) return;

    final account = accountsController.accounts[index];
    final updatedAccount = account.copyWith(
      balance: account.balance + delta,
    );
    await accountsController.updateAccount(updatedAccount);
  }
}
