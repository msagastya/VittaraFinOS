import 'package:vittara_fin_os/logic/transaction_model.dart';
import 'package:vittara_fin_os/logic/transactions_controller.dart';
import 'package:vittara_fin_os/logic/accounts_controller.dart';

class IntegrityCheckService {
  /// Returns a list of human-readable issues found in the data.
  static List<String> check({
    required TransactionsController txCtrl,
    required AccountsController accCtrl,
  }) {
    final issues = <String>[];
    final accountIds = accCtrl.accounts.map((a) => a.id).toSet();

    int orphanedCount = 0;
    for (final tx in txCtrl.transactions) {
      final metaId = tx.metadata?['accountId'] as String?;
      if (metaId != null && !accountIds.contains(metaId)) {
        orphanedCount++;
      }
      final srcId = tx.sourceAccountId;
      if (srcId != null && !accountIds.contains(srcId)) {
        orphanedCount++;
      }
    }
    if (orphanedCount > 0) {
      issues.add('$orphanedCount transaction(s) linked to deleted accounts');
    }
    return issues;
  }

  /// Nulls out account references on transactions that point to deleted accounts.
  /// Returns the number of records cleaned up.
  static Future<int> cleanupOrphanedRecords({
    required TransactionsController txCtrl,
    required AccountsController accCtrl,
  }) async {
    final accountIds = accCtrl.accounts.map((a) => a.id).toSet();
    int cleaned = 0;
    for (final tx in List.of(txCtrl.transactions)) {
      final Map<String, dynamic>? meta =
          tx.metadata != null ? Map.of(tx.metadata!) : null;
      bool metaDirty = false;

      final metaId = meta?['accountId'] as String?;
      if (metaId != null && !accountIds.contains(metaId)) {
        meta!.remove('accountId');
        metaDirty = true;
      }

      final srcOrphaned =
          tx.sourceAccountId != null && !accountIds.contains(tx.sourceAccountId);
      final dstOrphaned = tx.destinationAccountId != null &&
          !accountIds.contains(tx.destinationAccountId);

      if (!metaDirty && !srcOrphaned && !dstOrphaned) continue;

      // copyWith can't set nullable fields to null, so construct directly.
      await txCtrl.updateTransaction(Transaction(
        id: tx.id,
        type: tx.type,
        description: tx.description,
        dateTime: tx.dateTime,
        amount: tx.amount,
        sourceAccountId: srcOrphaned ? null : tx.sourceAccountId,
        sourceAccountName: srcOrphaned ? null : tx.sourceAccountName,
        destinationAccountId: dstOrphaned ? null : tx.destinationAccountId,
        destinationAccountName: dstOrphaned ? null : tx.destinationAccountName,
        charges: tx.charges,
        paymentAppName: tx.paymentAppName,
        appWalletAmount: tx.appWalletAmount,
        cashbackAmount: tx.cashbackAmount,
        cashbackAccountId: tx.cashbackAccountId,
        cashbackAccountName: tx.cashbackAccountName,
        metadata: metaDirty ? meta : tx.metadata,
      ));
      cleaned++;
    }
    return cleaned;
  }
}
