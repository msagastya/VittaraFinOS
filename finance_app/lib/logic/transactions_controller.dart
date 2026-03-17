import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vittara_fin_os/logic/transaction_model.dart';
import 'package:vittara_fin_os/utils/id_generator.dart';

class TransactionsController with ChangeNotifier {
  late SharedPreferences _prefs;
  late List<Transaction> _transactions;
  static const String _storageKey = 'transactions';

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

  /// Adds multiple transactions at once and calls [notifyListeners] only once
  /// at the end, avoiding redundant rebuilds during SMS batch imports.
  Future<void> addTransactionsBatch(List<Transaction> transactions) async {
    for (final transaction in transactions) {
      var normalized = transaction;
      final id = transaction.id.trim();
      if (id.isEmpty || _transactions.any((item) => item.id == id)) {
        normalized = transaction.copyWith(id: IdGenerator.next(prefix: 'txn'));
      }
      _transactions.insert(0, normalized);
    }
    // Sort by date descending after bulk insert
    _transactions.sort((a, b) => b.dateTime.compareTo(a.dateTime));
    await _saveTransactions();
    notifyListeners(); // Single notify for entire batch
  }

  Future<void> _saveTransactions() async {
    final transactionsJson = _transactions
        .map((transaction) => jsonEncode(transaction.toMap()))
        .toList();
    await _prefs.setStringList(_storageKey, transactionsJson);
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
        .where((t) => t.dateTime.isAfter(start) && t.dateTime.isBefore(end))
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
