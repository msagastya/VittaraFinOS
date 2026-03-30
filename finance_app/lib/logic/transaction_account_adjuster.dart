import 'package:vittara_fin_os/logic/accounts_controller.dart';
import 'package:vittara_fin_os/logic/payment_apps_controller.dart';
import 'package:vittara_fin_os/logic/transaction_model.dart';

class TransactionAccountAdjuster {
  const TransactionAccountAdjuster._();

  /// Apply the balance effect of a transaction (forward direction).
  /// Mirrors reverseTransaction exactly, but with signs flipped.
  static Future<void> applyTransaction(
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

    final effectiveSourceId =
        transaction.sourceAccountId ?? metadata['accountId'] as String?;
    final effectivePaymentApp =
        transaction.paymentAppName ?? metadata['paymentApp'] as String?;

    switch (transaction.type) {
      case TransactionType.expense:
        await _adjustAccount(
          accountsController,
          effectiveSourceId,
          -(amount - appWalletAmount),
        );
        if (appWalletAmount > 0 && effectivePaymentApp != null) {
          await paymentAppsController.adjustWalletBalanceByName(
            effectivePaymentApp,
            -appWalletAmount,
          );
        }
        if (cashbackAmount > 0) {
          if (cashbackFlow == 'paymentApp' && effectivePaymentApp != null) {
            await paymentAppsController.adjustWalletBalanceByName(
              effectivePaymentApp,
              cashbackAmount,
            );
          } else {
            await _adjustAccount(
              accountsController,
              transaction.cashbackAccountId ?? effectiveSourceId,
              cashbackAmount,
            );
          }
        }
        break;
      case TransactionType.income:
        await _adjustAccount(accountsController, effectiveSourceId, amount);
        if (cashbackAmount > 0) {
          if (cashbackFlow == 'paymentApp' && effectivePaymentApp != null) {
            await paymentAppsController.adjustWalletBalanceByName(
              effectivePaymentApp,
              cashbackAmount,
            );
          } else {
            await _adjustAccount(
              accountsController,
              transaction.cashbackAccountId ?? effectiveSourceId,
              cashbackAmount,
            );
          }
        }
        break;
      case TransactionType.transfer:
        await _adjustAccount(
          accountsController,
          effectiveSourceId,
          -(amount - appWalletAmount + (transaction.charges ?? 0.0)),
        );
        await _adjustAccount(
            accountsController, transaction.destinationAccountId, amount);
        if (appWalletAmount > 0 && effectivePaymentApp != null) {
          await paymentAppsController.adjustWalletBalanceByName(
            effectivePaymentApp,
            -appWalletAmount,
          );
        }
        if (cashbackAmount > 0) {
          if (cashbackFlow == 'paymentApp' && effectivePaymentApp != null) {
            await paymentAppsController.adjustWalletBalanceByName(
              effectivePaymentApp,
              cashbackAmount,
            );
          } else {
            await _adjustAccount(
              accountsController,
              transaction.cashbackAccountId ?? effectiveSourceId,
              cashbackAmount,
            );
          }
        }
        break;
      default:
        break;
    }
  }

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

    // Normalise account IDs: prefer the top-level fields, fall back to
    // metadata so any creation path that stores accountId in metadata
    // (CSV import, SMS save, future screens) also gets balance reversal.
    final effectiveSourceId =
        transaction.sourceAccountId ?? metadata['accountId'] as String?;
    final effectivePaymentApp =
        transaction.paymentAppName ?? metadata['paymentApp'] as String?;

    switch (transaction.type) {
      case TransactionType.expense:
        await _adjustAccount(
          accountsController,
          effectiveSourceId,
          amount - appWalletAmount,
        );
        if (appWalletAmount > 0 && effectivePaymentApp != null) {
          await paymentAppsController.adjustWalletBalanceByName(
            effectivePaymentApp,
            appWalletAmount,
          );
        }
        if (cashbackAmount > 0) {
          if (cashbackFlow == 'paymentApp' && effectivePaymentApp != null) {
            await paymentAppsController.adjustWalletBalanceByName(
              effectivePaymentApp,
              -cashbackAmount,
            );
          } else {
            await _adjustAccount(
              accountsController,
              transaction.cashbackAccountId ?? effectiveSourceId,
              -cashbackAmount,
            );
          }
        }
        break;
      case TransactionType.income:
        await _adjustAccount(
            accountsController, effectiveSourceId, -amount);
        if (cashbackAmount > 0) {
          if (cashbackFlow == 'paymentApp' && effectivePaymentApp != null) {
            await paymentAppsController.adjustWalletBalanceByName(
              effectivePaymentApp,
              -cashbackAmount,
            );
          } else {
            await _adjustAccount(
              accountsController,
              transaction.cashbackAccountId ?? effectiveSourceId,
              -cashbackAmount,
            );
          }
        }
        break;
      case TransactionType.transfer:
        await _adjustAccount(
          accountsController,
          effectiveSourceId,
          (amount - appWalletAmount) + (transaction.charges ?? 0.0),
        );
        await _adjustAccount(
            accountsController, transaction.destinationAccountId, -amount);
        if (appWalletAmount > 0 && effectivePaymentApp != null) {
          await paymentAppsController.adjustWalletBalanceByName(
            effectivePaymentApp,
            appWalletAmount,
          );
        }
        if (cashbackAmount > 0) {
          if (cashbackFlow == 'paymentApp' && effectivePaymentApp != null) {
            await paymentAppsController.adjustWalletBalanceByName(
              effectivePaymentApp,
              -cashbackAmount,
            );
          } else {
            await _adjustAccount(
              accountsController,
              transaction.cashbackAccountId ?? effectiveSourceId,
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
