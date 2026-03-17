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
}
