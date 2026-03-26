import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vittara_fin_os/logic/account_model.dart';
import 'package:vittara_fin_os/utils/async_mutex.dart';
import 'package:vittara_fin_os/utils/logger.dart';

final _accountsLogger = AppLogger();

class AccountsController with ChangeNotifier {
  late SharedPreferences _prefs;
  late List<Account> _accounts;
  static const String _storageKey = 'accounts';
  static final _writeMutex = AsyncMutex();

  bool _isLoaded = false;

  List<Account> get accounts => _accounts;
  bool get isLoaded => _isLoaded;

  /// Returns the account with [id], or null if not found.
  Account? getAccountById(String id) =>
      _accounts.where((a) => a.id == id).cast<Account?>().firstOrNull;

  AccountsController() {
    _accounts = [];
  }

  Future<void> loadAccounts() async {
    _prefs = await SharedPreferences.getInstance();
    final accountsJson = _prefs.getStringList(_storageKey) ?? [];

    final loaded = <Account>[];
    int skipped = 0;
    for (final json in accountsJson) {
      try {
        loaded.add(Account.fromMap(jsonDecode(json) as Map<String, dynamic>));
      } catch (e) {
        skipped++;
        _accountsLogger.warning('Skipped corrupted account record', error: e);
      }
    }
    if (skipped > 0) {
      _accountsLogger.warning('Skipped $skipped corrupted account(s)');
    }
    _accounts = loaded;

    _isLoaded = true;
    notifyListeners();
  }

  Future<void> addAccount(Account account) async {
    // Validate credit card balance doesn't exceed limit
    if ((account.type == AccountType.credit ||
            account.type == AccountType.payLater) &&
        account.creditLimit != null &&
        account.balance > account.creditLimit!) {
      throw Exception(
          'Credit card balance (₹${account.balance.toStringAsFixed(2)}) '
          'cannot exceed credit limit (₹${account.creditLimit!.toStringAsFixed(2)})');
    }

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
    // Validate credit card balance doesn't exceed limit
    if ((account.type == AccountType.credit ||
            account.type == AccountType.payLater) &&
        account.creditLimit != null &&
        account.balance > account.creditLimit!) {
      throw Exception(
          'Credit card balance (₹${account.balance.toStringAsFixed(2)}) '
          'cannot exceed credit limit (₹${account.creditLimit!.toStringAsFixed(2)})');
    }

    final index = _accounts.indexWhere((acc) => acc.id == account.id);
    if (index >= 0) {
      _accounts[index] = account;
      await _saveAccounts();
      notifyListeners();
    }
  }

  Future<void> _saveAccounts() async {
    await _writeMutex.protect(() async {
      final accountsJson =
          _accounts.map((account) => jsonEncode(account.toMap())).toList();
      await _prefs.setStringList(_storageKey, accountsJson);
    });
  }

  Future<void> hideAccount(String id) async {
    final index = _accounts.indexWhere((a) => a.id == id);
    if (index >= 0) {
      _accounts[index] = _accounts[index].copyWith(isHidden: true);
      await _saveAccounts();
      notifyListeners();
    }
  }

  Future<void> unhideAccount(String id) async {
    final index = _accounts.indexWhere((a) => a.id == id);
    if (index >= 0) {
      _accounts[index] = _accounts[index].copyWith(isHidden: false);
      await _saveAccounts();
      notifyListeners();
    }
  }

  Future<void> reorderAccounts(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final account = _accounts.removeAt(oldIndex);
    _accounts.insert(newIndex, account);
    await _saveAccounts();
    notifyListeners();
  }
}
