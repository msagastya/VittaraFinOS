import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vittara_fin_os/logic/transaction_model.dart';

class TransactionsArchiveController with ChangeNotifier {
  static const String _storageKey = 'archived_transactions';
  late SharedPreferences _prefs;
  late List<Transaction> _archived;
  bool _isLoaded = false;

  List<Transaction> get archived => List.unmodifiable(_archived);
  bool get isLoaded => _isLoaded;

  TransactionsArchiveController() {
    _archived = [];
    _loadArchivedTransactions();
  }

  Future<void> reloadFromStorage() async {
    await _loadArchivedTransactions();
  }

  Future<void> _loadArchivedTransactions() async {
    _prefs = await SharedPreferences.getInstance();
    final stored = _prefs.getStringList(_storageKey) ?? [];
    _archived = stored
        .map((item) =>
            Transaction.fromMap(jsonDecode(item) as Map<String, dynamic>))
        .toList();
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> addToArchive(Transaction txn) async {
    _archived.insert(0, txn);
    await _persist();
  }

  Future<void> removeFromArchive(String txnId) async {
    _archived.removeWhere((txn) => txn.id == txnId);
    await _persist();
  }

  Future<void> _persist() async {
    final encoded = _archived.map((txn) => jsonEncode(txn.toMap())).toList();
    await _prefs.setStringList(_storageKey, encoded);
    notifyListeners();
  }
}
