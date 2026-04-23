import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vittara_fin_os/logic/account_model.dart';
import 'package:vittara_fin_os/services/database_service.dart';
import 'package:vittara_fin_os/utils/async_mutex.dart';
import 'package:vittara_fin_os/utils/id_generator.dart';
import 'package:vittara_fin_os/utils/logger.dart';
import 'package:vittara_fin_os/utils/safe_storage_mixin.dart';

final _accountsLogger = AppLogger();

class AccountsController with ChangeNotifier, SafeStorageMixin {
  late List<Account> _accounts;
  static const String _seededKey = 'accounts_seeded_v1';
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
    final rows = await DatabaseService.instance.getAllData('accounts');
    final loaded = <Account>[];
    int skipped = 0;
    for (final map in rows) {
      try {
        loaded.add(Account.fromMap(map));
      } catch (e) {
        skipped++;
        _accountsLogger.warning('Skipped corrupted account record', error: e);
      }
    }
    if (skipped > 0) {
      _accountsLogger.warning('Skipped $skipped corrupted account(s)');
    }
    _accounts = loaded;

    // First-install seed: every user gets "Cash in Hand" automatically.
    if (_accounts.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      if (!(prefs.getBool(_seededKey) ?? false)) {
        final cashAccount = Account(
          id: IdGenerator.next(prefix: 'acct'),
          name: 'Cash in Hand',
          bankName: 'Cash',
          type: AccountType.cash,
          balance: 0.0,
          color: const Color(0xFF00B890),
        );
        _accounts.add(cashAccount);
        await _saveAccounts();
        await prefs.setBool(_seededKey, true);
      }
    }

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
    await _upsertOne(account);
    notifyListeners();
  }

  Future<void> removeAccount(String accountId) async {
    _accounts.removeWhere((acc) => acc.id == accountId);
    await _deleteOne(accountId);
    notifyListeners();
  }

  Future<void> updateAccount(Account account) async {
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
      await _upsertOne(account);
      notifyListeners();
    }
  }

  Future<void> _saveAccounts() async {
    await safeWrite('save accounts', () async {
      await _writeMutex.protect(() async {
        await DatabaseService.instance.upsertDataRowsBatch(
          'accounts', _accounts.map((a) => a.toMap()).toList());
      });
    });
  }

  Future<void> _upsertOne(Account acc) async {
    await safeWrite('save account', () async {
      await _writeMutex.protect(() async {
        await DatabaseService.instance.upsertDataRow(
            'accounts', acc.id, acc.toMap());
      });
    });
  }

  Future<void> _deleteOne(String id) async {
    await safeWrite('delete account', () async {
      await _writeMutex.protect(() async {
        await DatabaseService.instance.deleteRow('accounts', id);
      });
    });
  }


  Future<void> hideAccount(String id) async {
    final index = _accounts.indexWhere((a) => a.id == id);
    if (index >= 0) {
      _accounts[index] = _accounts[index].copyWith(isHidden: true);
      await _upsertOne(_accounts[index]);
      notifyListeners();
    }
  }

  Future<void> unhideAccount(String id) async {
    final index = _accounts.indexWhere((a) => a.id == id);
    if (index >= 0) {
      _accounts[index] = _accounts[index].copyWith(isHidden: false);
      await _upsertOne(_accounts[index]);
      notifyListeners();
    }
  }

  Future<void> reorderAccounts(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) newIndex -= 1;
    final account = _accounts.removeAt(oldIndex);
    _accounts.insert(newIndex, account);
    // Reorder requires updating all rows (order is positional in memory; no
    // sort column in DB — full batch write is necessary here)
    await _saveAccounts();
    notifyListeners();
  }
}
