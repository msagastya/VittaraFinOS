import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:vittara_fin_os/logic/accounts_controller.dart';
import 'package:vittara_fin_os/logic/finance/xirr_calculator.dart';
import 'package:vittara_fin_os/logic/investment_model.dart';
import 'package:vittara_fin_os/services/database_service.dart';
import 'package:vittara_fin_os/services/investment_value_service.dart';
import 'package:vittara_fin_os/utils/async_mutex.dart';
import 'package:vittara_fin_os/utils/logger.dart';
import 'package:vittara_fin_os/utils/safe_storage_mixin.dart';

final _investmentsLogger = AppLogger();

class InvestmentsController with ChangeNotifier, SafeStorageMixin {
  late List<Investment> _investments;
  static final _writeMutex = AsyncMutex();
  static const String _storageKey = 'investments';
  static const double _amountDeltaEpsilon = 0.01;

  bool _isLoaded = false;
  DateTime? _lastRefreshedAt;

  // AU6-01 — Memoized total investment amount
  double? _cachedTotalAmount;
  bool _totalAmountDirty = true;

  List<Investment> get investments => _investments;
  bool get isLoaded => _isLoaded;
  DateTime? get lastRefreshedAt => _lastRefreshedAt;

  InvestmentsController() {
    _investments = [];
  }

  Future<void> loadInvestments() async {
    final rows = await DatabaseService.instance.getAllData('investments');

    final loaded = <Investment>[];
    int skipped = 0;
    for (final map in rows) {
      try {
        loaded.add(Investment.fromMap(map));
      } catch (e) {
        skipped++;
        _investmentsLogger.warning(
            'Skipped corrupted investment record', error: e);
      }
    }
    if (skipped > 0) {
      _investmentsLogger.warning('Skipped $skipped corrupted investment(s)');
    }
    _investments = loaded;

    var migrated = false;
    for (var i = 0; i < _investments.length; i++) {
      final normalized = _ensureCreateActivityLog(_investments[i]);
      if (!identical(normalized, _investments[i])) {
        _investments[i] = normalized;
        migrated = true;
      }
    }
    if (migrated) {
      await _saveInvestments();
    }

    _isLoaded = true;
    _invalidateCache();
    notifyListeners();
  }

  Future<void> addInvestment(Investment investment) async {
    final normalized = _ensureCreateActivityLog(investment);
    _investments.add(normalized);
    await _upsertOne(normalized);
    _invalidateCache();
    notifyListeners();
  }

  Future<void> removeInvestment(String investmentId) async {
    _investments.removeWhere((inv) => inv.id == investmentId);
    await _deleteOne(investmentId);
    _invalidateCache();
    notifyListeners();
  }

  /// Deletes an investment. If [accountsController] is provided and the
  /// investment metadata records `debitedFromAccount: true`, the original
  /// debit amount is credited back to the linked account.
  Future<void> deleteInvestment(
    String investmentId, {
    AccountsController? accountsController,
  }) async {
    if (accountsController != null) {
      final inv =
          _investments.where((i) => i.id == investmentId).firstOrNull;
      if (inv != null && inv.metadata?['debitedFromAccount'] == true) {
        final accountId = inv.metadata?['linkedAccountId'] as String?;
        final debitAmount =
            (inv.metadata?['debitAmount'] as num?)?.toDouble();
        if (accountId != null && debitAmount != null && debitAmount > 0) {
          final account = accountsController.accounts
              .where((a) => a.id == accountId)
              .firstOrNull;
          if (account != null) {
            await accountsController.updateAccount(
              account.copyWith(balance: account.balance + debitAmount),
            );
          }
        }
      }
    }
    await removeInvestment(investmentId);
  }

  Future<void> updateInvestment(
    Investment investment, {
    bool trackDelta = true,
  }) async {
    final index = _investments.indexWhere((inv) => inv.id == investment.id);

    if (index >= 0) {
      final current = _investments[index];
      final normalized = trackDelta
          ? _appendDeltaActivityLog(current, investment)
          : _ensureCreateActivityLog(investment);
      _investments[index] = normalized;
      await _upsertOne(normalized);
      _invalidateCache();
      notifyListeners();
    }
  }

  Future<void> recordInvestmentActivity({
    required String investmentId,
    required String type,
    required double amount,
    String? description,
    DateTime? dateTime,
    String? accountId,
    String? accountName,
  }) async {
    if (amount <= 0) return;

    final index = _investments.indexWhere((inv) => inv.id == investmentId);
    if (index < 0) return;

    final current = _investments[index];
    final metadata = Map<String, dynamic>.from(current.metadata ?? {});
    final activityLog = _readActivityLog(metadata);
    activityLog.add(
      _buildActivityEntry(
        type: type,
        amount: amount,
        description: description,
        dateTime: dateTime ?? DateTime.now(),
        accountId: accountId,
        accountName: accountName,
      ),
    );
    metadata['activityLog'] = activityLog;
    metadata['lastActivityAt'] = (dateTime ?? DateTime.now()).toIso8601String();

    _investments[index] = current.copyWith(metadata: metadata);
    await _upsertOne(_investments[index]);
    _invalidateCache();
    notifyListeners();
  }

  Future<void> _saveInvestments() async {
    await safeWrite('save investments', () async {
      await _writeMutex.protect(() async {
        await DatabaseService.instance.upsertDataRowsBatch(
          'investments', _investments.map((i) => i.toMap()).toList());
      });
    });
  }

  Future<void> _upsertOne(Investment inv) async {
    await safeWrite('save investment', () async {
      await _writeMutex.protect(() async {
        await DatabaseService.instance.upsertDataRow(
            'investments', inv.id, inv.toMap());
      });
    });
  }

  Future<void> _deleteOne(String id) async {
    await safeWrite('delete investment', () async {
      await _writeMutex.protect(() async {
        await DatabaseService.instance.deleteRow('investments', id);
      });
    });
  }

  // Invalidates memoized caches when the investments list changes.
  // Called before every notifyListeners() that mutates the list.
  void _invalidateCache() {
    _totalAmountDirty = true;
    _cachedTotalAmount = null;
  }

  Future<void> reorderInvestments(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final investment = _investments.removeAt(oldIndex);
    _investments.insert(newIndex, investment);
    await _saveInvestments();
    _invalidateCache();
    notifyListeners();
  }

  // AU6-01 — Memoized: recomputes only when list mutates
  double getTotalInvestmentAmount() {
    if (!_totalAmountDirty && _cachedTotalAmount != null) {
      return _cachedTotalAmount!;
    }
    _cachedTotalAmount =
        _investments.fold<double>(0.0, (sum, inv) => sum + inv.amount);
    _totalAmountDirty = false;
    return _cachedTotalAmount!;
  }

  double getInvestmentAmountByType(InvestmentType type) {
    return _investments
        .where((inv) => inv.type == type)
        .fold(0, (sum, inv) => sum + inv.amount);
  }

  List<Investment> getInvestmentsByType(InvestmentType type) {
    return _investments.where((inv) => inv.type == type).toList();
  }

  Future<bool> refreshCurrentValues(
    InvestmentValueService valueService, {
    bool forceRefresh = false,
  }) async {
    var updated = false;
    final refreshedAt = DateTime.now().toIso8601String();

    for (var i = 0; i < _investments.length; i++) {
      final investment = _investments[i];
      final result = await valueService.fetchCurrentValue(
        investment,
        forceRefresh: forceRefresh,
      );
      if (result != null &&
          (result.currentValue != null || result.currentNAV != null)) {
        final metadata = Map<String, dynamic>.from(investment.metadata ?? {});
        final oldValue = _asDouble(metadata['currentValue']);
        final oldNav = _asDouble(metadata['currentNAV']);
        final newValue = result.currentValue ?? oldValue ?? investment.amount;
        metadata['currentValue'] = newValue;
        if (result.currentNAV != null) {
          metadata['currentNAV'] = result.currentNAV;
        }
        metadata['lastRefreshedAt'] = refreshedAt;

        final newNav = _asDouble(metadata['currentNAV']);
        if (oldValue != newValue || oldNav != newNav || forceRefresh) {
          _investments[i] = investment.copyWith(metadata: metadata);
          updated = true;
        }
      }
    }

    _lastRefreshedAt = DateTime.now();
    if (updated) {
      await _saveInvestments();
      _invalidateCache();
    }
    notifyListeners();

    // T-123: Recompute XIRR for all investments after prices refresh
    if (updated) computeAllXirr().ignore();

    return updated;
  }

  // ── T-123: XIRR computation ───────────────────────────────────────────────

  /// Compute XIRR for each investment that has a known purchase date and
  /// current value. Stores result in `metadata['xirrAnnualised']`.
  /// Runs in a Flutter `compute` isolate to avoid blocking the UI thread.
  Future<void> computeAllXirr() async {
    bool anyUpdated = false;
    final updated = <Investment>[];

    for (final inv in _investments) {
      final xirr = await _computeXirrForInvestment(inv);
      if (xirr != null) {
        final metadata = Map<String, dynamic>.from(inv.metadata ?? {});
        metadata['xirrAnnualised'] = xirr;
        updated.add(inv.copyWith(metadata: metadata));
        anyUpdated = true;
      } else {
        updated.add(inv);
      }
    }

    if (anyUpdated) {
      _investments = updated;
      _invalidateCache();
      await _saveInvestments();
      notifyListeners();
    }
  }

  /// Build cashflows for an investment from its activity log and compute XIRR.
  Future<double?> _computeXirrForInvestment(Investment inv) async {
    final metadata = inv.metadata ?? {};
    final log = _readActivityLog(metadata);
    if (log.isEmpty) return null;

    final cashflows = <(DateTime, double)>[];
    for (final entry in log) {
      final dateStr = entry['date'] as String?;
      final amount = _asDouble(entry['amount']) ??
          _asDouble(entry['investedAmount']);
      if (dateStr == null || amount == null) continue;
      final date = DateTime.tryParse(dateStr);
      if (date == null) continue;
      // Outflows are negative (buy/invest), inflows positive (sell/redeem)
      final type = _normalizedEventType(entry['type'] as String? ?? '');
      final cf = (type == 'sell' || type == 'redeem' || type == 'withdraw')
          ? amount.abs()
          : -amount.abs();
      cashflows.add((date, cf));
    }

    // Add current value as final inflow at today
    final currentValue = inv.currentValue;
    if (currentValue > 0 && cashflows.isNotEmpty) {
      cashflows.add((DateTime.now(), currentValue));
    }

    if (cashflows.length < 2) return null;

    return compute(
      _xirrIsolate,
      cashflows.map((c) => [c.$1.millisecondsSinceEpoch, c.$2]).toList(),
    );
  }

  /// Top-level function for isolate: XirrCalculator.compute over serializable data.
  static double? _xirrIsolate(List<List<double>> data) {
    final cfs = data
        .map((d) => (
              DateTime.fromMillisecondsSinceEpoch(d[0].toInt()),
              d[1],
            ))
        .toList();
    return XirrCalculator.compute(cfs);
  }

  double? _asDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  Investment _ensureCreateActivityLog(Investment investment) {
    final metadata = Map<String, dynamic>.from(investment.metadata ?? {});
    final activityLog = _readActivityLog(metadata);
    final hasCreateEvent = activityLog.any(
      (entry) => _normalizedEventType(entry['type']) == 'create',
    );
    if (hasCreateEvent) {
      return investment;
    }

    final amount = _asDouble(metadata['investmentAmount']) ?? investment.amount;
    if (amount <= 0) {
      return investment;
    }

    final createdAt = _resolveActivityDate(metadata) ?? DateTime.now();
    activityLog.insert(
      0,
      _buildActivityEntry(
        type: 'create',
        amount: amount,
        description: '${investment.getTypeLabel()} added: ${investment.name}',
        dateTime: createdAt,
        accountId: _resolveLinkedAccountId(metadata),
        accountName: _resolveLinkedAccountName(metadata),
      ),
    );
    metadata['activityLog'] = activityLog;
    metadata['createdAt'] =
        metadata['createdAt'] ?? createdAt.toIso8601String();

    return investment.copyWith(metadata: metadata);
  }

  Investment _appendDeltaActivityLog(Investment current, Investment updated) {
    final metadata = Map<String, dynamic>.from(
      updated.metadata ?? current.metadata ?? const <String, dynamic>{},
    );

    final existingLog = _readActivityLog(Map<String, dynamic>.from(
      current.metadata ?? const <String, dynamic>{},
    ));
    var nextLog = _readActivityLog(metadata);
    if (nextLog.isEmpty && existingLog.isNotEmpty) {
      nextLog = [...existingLog];
    }

    final delta = updated.amount - current.amount;
    if (delta.abs() >= _amountDeltaEpsilon) {
      final isIncrease = delta > 0;
      final eventType = isIncrease ? 'increase' : 'decrease';
      nextLog.add(
        _buildActivityEntry(
          type: eventType,
          amount: delta.abs(),
          description: isIncrease
              ? 'Invested more in ${updated.name}'
              : 'Reduced ${updated.name} investment',
          dateTime: DateTime.now(),
          accountId: _resolveLinkedAccountId(metadata),
          accountName: _resolveLinkedAccountName(metadata),
        ),
      );
      metadata['lastActivityAt'] = DateTime.now().toIso8601String();
    }

    if (nextLog.isNotEmpty) {
      metadata['activityLog'] = nextLog;
    }

    return _ensureCreateActivityLog(updated.copyWith(metadata: metadata));
  }

  List<Map<String, dynamic>> _readActivityLog(Map<String, dynamic> metadata) {
    final raw = metadata['activityLog'];
    if (raw is! List) return <Map<String, dynamic>>[];
    final entries = <Map<String, dynamic>>[];
    for (final entry in raw) {
      if (entry is Map) {
        entries.add(entry.map((key, value) => MapEntry('$key', value)));
      }
    }
    return entries;
  }

  Map<String, dynamic> _buildActivityEntry({
    required String type,
    required double amount,
    String? description,
    required DateTime dateTime,
    String? accountId,
    String? accountName,
  }) {
    return {
      'id': dateTime.microsecondsSinceEpoch.toString(),
      'type': _normalizedEventType(type),
      'amount': amount,
      'description': description,
      'date': dateTime.toIso8601String(),
      'accountId': accountId,
      'accountName': accountName,
    };
  }

  DateTime? _resolveActivityDate(Map<String, dynamic> metadata) {
    const keys = [
      'investmentDate',
      'purchaseDate',
      'startDate',
      'createdAt',
      'openedAt',
      'date',
    ];
    for (final key in keys) {
      final parsed = _parseDate(metadata[key]);
      if (parsed != null) return parsed;
    }
    return null;
  }

  String _normalizedEventType(String? value) =>
      (value ?? 'activity').trim().toLowerCase();

  DateTime? _parseDate(dynamic value) {
    if (value is DateTime) return value;
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  String? _asString(dynamic value) {
    if (value == null) return null;
    final text = value.toString();
    return text.trim().isEmpty ? null : text;
  }

  String? _resolveLinkedAccountId(Map<String, dynamic> metadata) {
    final sipData = metadata['sipData'];
    if (sipData is Map<String, dynamic>) {
      final fromSip = _asString(sipData['deductionAccountId']);
      if (fromSip != null) return fromSip;
    }
    return _asString(
      metadata['accountId'] ??
          metadata['deductionAccountId'] ??
          metadata['sipLinkedAccount'],
    );
  }

  String? _resolveLinkedAccountName(Map<String, dynamic> metadata) {
    final sipData = metadata['sipData'];
    if (sipData is Map<String, dynamic>) {
      final fromSip = _asString(sipData['deductionAccountName']);
      if (fromSip != null) return fromSip;
    }
    return _asString(
      metadata['accountName'] ??
          metadata['deductionAccountName'] ??
          metadata['sipLinkedAccountName'],
    );
  }
}
