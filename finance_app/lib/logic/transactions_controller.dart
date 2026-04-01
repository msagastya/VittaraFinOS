import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vittara_fin_os/logic/accounts_controller.dart';
import 'package:vittara_fin_os/logic/payment_apps_controller.dart';
import 'package:vittara_fin_os/logic/transaction_account_adjuster.dart';
import 'package:vittara_fin_os/logic/transaction_model.dart';
import 'package:vittara_fin_os/utils/async_mutex.dart';
import 'package:vittara_fin_os/utils/id_generator.dart';

class TransactionsController with ChangeNotifier {
  late SharedPreferences _prefs;
  late List<Transaction> _transactions;
  static const String _storageKey = 'transactions';
  static final _writeMutex = AsyncMutex();

  List<Transaction> get transactions => _transactions;

  TransactionsController() {
    _transactions = [];
  }

  Future<void> loadTransactions() async {
    _prefs = await SharedPreferences.getInstance();
    final transactionsJson = _prefs.getStringList(_storageKey) ?? [];

    final parsedTransactions = <Transaction>[];
    final usedIds = <String>{};
    var dataChanged = false;

    for (final row in transactionsJson) {
      try {
        final decoded = jsonDecode(row) as Map<String, dynamic>;
        var transaction = Transaction.fromMap(decoded);
        final normalizedId = transaction.id.trim();
        if (normalizedId.isEmpty || usedIds.contains(normalizedId)) {
          transaction =
              transaction.copyWith(id: IdGenerator.next(prefix: 'txn'));
          dataChanged = true;
        }
        usedIds.add(transaction.id);
        parsedTransactions.add(transaction);
      } catch (_) {
        dataChanged = true;
      }
    }

    _transactions = parsedTransactions;

    // Sort by date descending (newest first)
    _transactions.sort((a, b) => b.dateTime.compareTo(a.dateTime));

    if (dataChanged) {
      await _saveTransactions();
    }

    notifyListeners();
  }

  Future<void> addTransaction(Transaction transaction) async {
    var normalized = transaction;
    final id = transaction.id.trim();
    if (id.isEmpty || _transactions.any((item) => item.id == id)) {
      normalized = transaction.copyWith(id: IdGenerator.next(prefix: 'txn'));
    }
    // Ensure createdAt is set to now if not already set
    if (normalized.createdAt == null) {
      normalized = normalized.copyWith(createdAt: DateTime.now());
    }
    _transactions.insert(0, normalized); // Add to beginning (newest first)
    await _saveTransactions();
    notifyListeners();
  }

  Future<void> removeTransaction(String transactionId) async {
    _transactions.removeWhere((t) => t.id == transactionId);
    await _saveTransactions();
    notifyListeners();
  }

  Future<void> updateTransaction(Transaction updated) async {
    final idx = _transactions.indexWhere((t) => t.id == updated.id);
    if (idx < 0) return;
    _transactions[idx] = updated;
    await _saveTransactions();
    notifyListeners();
  }

  /// Edit a transaction within 24 hours of creation, with cascade balance snapshot updates.
  /// Returns true if edit was successful, false if outside 24h window.
  Future<bool> editTransaction(
    Transaction updated,
    AccountsController accountsController,
    PaymentAppsController paymentAppsController,
  ) async {
    final idx = _transactions.indexWhere((t) => t.id == updated.id);
    if (idx < 0) return false;

    final oldTransaction = _transactions[idx];

    // Check 24h edit window
    final createdAt = oldTransaction.createdAt;
    if (createdAt == null) {
      // Fallback: if createdAt not set, disallow edit
      return false;
    }
    final now = DateTime.now();
    if (now.difference(createdAt).inHours > 24) {
      return false;
    }

    // Reverse old transaction effects and apply new effects
    await TransactionAccountAdjuster.reverseTransaction(
      accountsController,
      oldTransaction,
      paymentAppsController,
    );
    await TransactionAccountAdjuster.applyTransaction(
      accountsController,
      updated,
      paymentAppsController,
    );

    // Calculate delta for balance snapshot updates
    // This is used to update all subsequent transaction snapshots
    _updateBalanceSnapshotsCascade(idx, oldTransaction, updated);

    _transactions[idx] = updated;
    await _saveTransactions();
    notifyListeners();
    return true;
  }

  /// Update balance snapshots for all transactions after the edited one.
  /// When a transaction is edited, the delta affects all subsequent transactions
  /// that touch the same account(s).
  void _updateBalanceSnapshotsCascade(
    int editedIndex,
    Transaction oldTx,
    Transaction newTx,
  ) {
    // Get affected account IDs
    final affectedAccounts = <String>{};
    if (oldTx.sourceAccountId != null) affectedAccounts.add(oldTx.sourceAccountId!);
    if (oldTx.destinationAccountId != null) {
      affectedAccounts.add(oldTx.destinationAccountId!);
    }
    if (oldTx.cashbackAccountId != null) affectedAccounts.add(oldTx.cashbackAccountId!);
    if (newTx.sourceAccountId != null) affectedAccounts.add(newTx.sourceAccountId!);
    if (newTx.destinationAccountId != null) {
      affectedAccounts.add(newTx.destinationAccountId!);
    }
    if (newTx.cashbackAccountId != null) affectedAccounts.add(newTx.cashbackAccountId!);

    // For each account, calculate the delta
    for (final accountId in affectedAccounts) {
      _updateAccountSnapshotsDelta(editedIndex, accountId, oldTx, newTx);
    }
  }

  /// For a specific account, update balance snapshots in all subsequent transactions.
  void _updateAccountSnapshotsDelta(
    int editedIndex,
    String accountId,
    Transaction oldTx,
    Transaction newTx,
  ) {
    // Calculate the delta impact on this account
    final oldDelta = _getAccountDelta(oldTx, accountId);
    final newDelta = _getAccountDelta(newTx, accountId);
    final snapDelta = newDelta - oldDelta;

    if (snapDelta == 0) return; // No change, skip

    // Update all subsequent transactions' snapshots
    for (int i = editedIndex + 1; i < _transactions.length; i++) {
      final tx = _transactions[i];
      final metadata = Map<String, dynamic>.from(tx.metadata ?? {});

      // Update source balance snapshot if this account is the source
      if (tx.sourceAccountId == accountId) {
        final sourceBalanceAfter =
            (metadata['sourceBalanceAfter'] as num?)?.toDouble() ?? 0.0;
        metadata['sourceBalanceAfter'] = sourceBalanceAfter + snapDelta;
      }

      // Update destination balance snapshot if this account is the destination
      if (tx.destinationAccountId == accountId) {
        final destBalanceAfter =
            (metadata['destBalanceAfter'] as num?)?.toDouble() ?? 0.0;
        metadata['destBalanceAfter'] = destBalanceAfter + snapDelta;
      }

      // Update cashback account snapshot if this account is the cashback dest
      if (tx.cashbackAccountId == accountId) {
        final cashbackBalanceAfter =
            (metadata['cashbackBalanceAfter'] as num?)?.toDouble() ?? 0.0;
        metadata['cashbackBalanceAfter'] = cashbackBalanceAfter + snapDelta;
      }

      _transactions[i] = tx.copyWith(metadata: metadata);
    }
  }

  /// Get the net balance delta for an account from a transaction.
  double _getAccountDelta(Transaction tx, String accountId) {
    final amount = tx.amount;
    final appWalletAmount =
        tx.appWalletAmount ?? (tx.metadata?['appWalletAmount'] as num?)?.toDouble() ?? 0.0;
    final cashbackAmount = tx.cashbackAmount ?? 0.0;
    final charges = tx.charges ?? 0.0;
    final cashbackFlow = tx.metadata?['cashbackFlow'] as String? ?? 'bank';

    double delta = 0;

    switch (tx.type) {
      case TransactionType.expense:
        if (tx.sourceAccountId == accountId) {
          delta = -(amount - appWalletAmount);
        }
        if (cashbackFlow != 'paymentApp' && tx.cashbackAccountId == accountId) {
          delta += cashbackAmount;
        }
        break;
      case TransactionType.income:
        if (tx.sourceAccountId == accountId) {
          delta = amount;
        }
        if (cashbackFlow != 'paymentApp' && tx.cashbackAccountId == accountId) {
          delta += cashbackAmount;
        }
        break;
      case TransactionType.transfer:
        if (tx.sourceAccountId == accountId) {
          delta = -(amount - appWalletAmount + charges);
        }
        if (tx.destinationAccountId == accountId) {
          delta = amount;
        }
        if (cashbackFlow != 'paymentApp' && tx.cashbackAccountId == accountId) {
          delta += cashbackAmount;
        }
        break;
      default:
        break;
    }

    return delta;
  }

  /// Adds multiple transactions at once and calls [notifyListeners] only once
  /// at the end, avoiding redundant rebuilds during SMS batch imports.
  Future<void> addTransactionsBatch(List<Transaction> transactions) async {
    for (final transaction in transactions) {
      var normalized = transaction;
      final id = transaction.id.trim();
      if (id.isEmpty || _transactions.any((item) => item.id == id)) {
        normalized = transaction.copyWith(id: IdGenerator.next(prefix: 'txn'));
      }
      // Ensure createdAt is set to now if not already set
      if (normalized.createdAt == null) {
        normalized = normalized.copyWith(createdAt: DateTime.now());
      }
      _transactions.insert(0, normalized);
    }
    // Sort by date descending after bulk insert
    _transactions.sort((a, b) => b.dateTime.compareTo(a.dateTime));
    await _saveTransactions();
    notifyListeners(); // Single notify for entire batch
  }

  Future<void> _saveTransactions() async {
    await _writeMutex.protect(() async {
      final transactionsJson = _transactions
          .map((transaction) => jsonEncode(transaction.toMap()))
          .toList();
      await _prefs.setStringList(_storageKey, transactionsJson);
    });
  }

  List<Transaction> getTransactionsByAccount(String accountId) {
    return _transactions
        .where((t) =>
            t.sourceAccountId == accountId ||
            t.destinationAccountId == accountId ||
            t.cashbackAccountId == accountId)
        .toList();
  }

  List<Transaction> getTransactionsByType(TransactionType type) {
    return _transactions.where((t) => t.type == type).toList();
  }

  List<Transaction> getTransactionsInDateRange(DateTime start, DateTime end) {
    return _transactions
        .where((t) => !t.dateTime.isBefore(start) && !t.dateTime.isAfter(end))
        .toList();
  }

  double getTotalTransferred() {
    return _transactions
        .where((t) => t.type == TransactionType.transfer)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  double getTotalCashback() {
    return _transactions
        .where((t) => t.type == TransactionType.cashback)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  /// Returns the number of consecutive days ending today (or yesterday)
  /// on which at least one transaction was logged.
  int get loggingStreakDays {
    if (_transactions.isEmpty) return 0;

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    // Collect unique calendar dates that have transactions
    final dates = _transactions
        .map((t) => DateTime(t.dateTime.year, t.dateTime.month, t.dateTime.day))
        .toSet();

    // Streak must end today or yesterday; anything older resets to 0
    DateTime cursor;
    if (dates.contains(todayDate)) {
      cursor = todayDate;
    } else if (dates.contains(todayDate.subtract(const Duration(days: 1)))) {
      cursor = todayDate.subtract(const Duration(days: 1));
    } else {
      return 0;
    }

    int streak = 0;
    while (dates.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  double getTotalCharges() {
    return _transactions
        .where((t) => t.type == TransactionType.transfer && t.charges != null)
        .fold(0.0, (sum, t) => sum + (t.charges ?? 0.0));
  }

  /// Unified filter — future NL query and advanced search integration point.
  List<Transaction> filter({
    DateTimeRange? dateRange,
    String? categoryId,
    double? minAmount,
    double? maxAmount,
    String? merchant,
    TransactionType? type,
  }) {
    return _transactions.where((t) {
      if (dateRange != null &&
          (t.dateTime.isBefore(dateRange.start) ||
              t.dateTime.isAfter(dateRange.end))) {
        return false;
      }
      if (categoryId != null &&
          (t.metadata?['categoryId'] as String?) != categoryId) {
        return false;
      }
      if (minAmount != null && t.amount.abs() < minAmount) { return false; }
      if (maxAmount != null && t.amount.abs() > maxAmount) { return false; }
      if (merchant != null) {
        final m = (t.metadata?['merchant'] as String?) ?? '';
        if (!m.toLowerCase().contains(merchant.toLowerCase())) return false;
      }
      if (type != null && t.type != type) return false;
      return true;
    }).toList();
  }
}
