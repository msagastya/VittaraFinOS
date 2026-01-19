import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vittara_fin_os/logic/account_model.dart';

class AccountsController with ChangeNotifier {
  late SharedPreferences _prefs;
  late List<Account> _accounts;
  static const String _storageKey = 'accounts';

  List<Account> get accounts => _accounts;

  AccountsController() {
    _accounts = [];
  }

  Future<void> loadAccounts() async {
    _prefs = await SharedPreferences.getInstance();
    final accountsJson = _prefs.getStringList(_storageKey) ?? [];

    _accounts = accountsJson
        .map((json) => Account.fromMap(jsonDecode(json) as Map<String, dynamic>))
        .toList();

    notifyListeners();
  }

  Future<void> addAccount(Account account) async {
    _accounts.add(account);
    await _saveAccounts();
    notifyListeners();
  }

  Future<void> removeAccount(String accountId) async {
    _accounts.removeWhere((acc) => acc.id == accountId);
    await _saveAccounts();
    notifyListeners();
  }

  Future<void> updateAccount(Account account) async {
    final index = _accounts.indexWhere((acc) => acc.id == account.id);
    if (index >= 0) {
      _accounts[index] = account;
      await _saveAccounts();
      notifyListeners();
    }
  }

  Future<void> _saveAccounts() async {
    final accountsJson = _accounts
        .map((account) => jsonEncode(account.toMap()))
        .toList();
    await _prefs.setStringList(_storageKey, accountsJson);
  }

  void reorderAccounts(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final account = _accounts.removeAt(oldIndex);
    _accounts.insert(newIndex, account);
    _saveAccounts();
    notifyListeners();
  }
}
