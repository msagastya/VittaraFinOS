import 'package:flutter/material.dart';
import 'package:vittara_fin_os/logic/transaction_model.dart';
import 'package:vittara_fin_os/services/database_service.dart';
import 'package:vittara_fin_os/utils/async_mutex.dart';
import 'package:vittara_fin_os/utils/safe_storage_mixin.dart';

/// Archive controller — thin wrapper over the [DatabaseService] transactions
/// table using the [is_archived] flag.
///
/// No separate storage key. Archived and live transactions share one table,
/// so there is no drift between the two collections.
class TransactionsArchiveController with ChangeNotifier, SafeStorageMixin {
  static final _writeMutex = AsyncMutex();

  List<Transaction> _archived = [];
  bool _isLoaded = false;

  List<Transaction> get archived => List.unmodifiable(_archived);
  bool get isLoaded => _isLoaded;

  TransactionsArchiveController() {
    _load();
  }

  Future<void> reloadFromStorage() => _load();

  Future<void> _load() async {
    final rows =
        await DatabaseService.instance.getTransactions(archived: true);
    _archived = rows.map(Transaction.fromMap).toList();
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> addToArchive(Transaction txn) async {
    _archived.insert(0, txn);
    notifyListeners();
    await safeWrite('archive transaction', () async {
      await _writeMutex.protect(() async {
        await DatabaseService.instance.upsertTransaction(
          txn.toMap(),
          archived: true,
        );
      });
    });
  }

  Future<void> removeFromArchive(String txnId) async {
    _archived.removeWhere((txn) => txn.id == txnId);
    notifyListeners();
    await safeWrite('remove from archive', () async {
      await _writeMutex.protect(() async {
        await DatabaseService.instance.deleteRow('transactions', txnId);
      });
    });
  }
}
