import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vittara_fin_os/logic/transaction_model.dart';

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

    _transactions = transactionsJson
        .map((json) =>
            Transaction.fromMap(jsonDecode(json) as Map<String, dynamic>))
        .toList();

    // Sort by date descending (newest first)
    _transactions.sort((a, b) => b.dateTime.compareTo(a.dateTime));

    notifyListeners();
  }

  Future<void> addTransaction(Transaction transaction) async {
    _transactions.insert(0, transaction); // Add to beginning (newest first)
    await _saveTransactions();
    notifyListeners();
  }

  Future<void> removeTransaction(String transactionId) async {
    _transactions.removeWhere((t) => t.id == transactionId);
    await _saveTransactions();
    notifyListeners();
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

  double getTotalCharges() {
    return _transactions
        .where((t) => t.type == TransactionType.transfer && t.charges != null)
        .fold(0.0, (sum, t) => sum + (t.charges ?? 0.0));
  }
}
