import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vittara_fin_os/logic/investment_model.dart';
import 'package:vittara_fin_os/services/investment_value_service.dart';
import 'package:vittara_fin_os/utils/logger.dart';

final _investmentsLogger = AppLogger();

class InvestmentsController with ChangeNotifier {
  late SharedPreferences _prefs;
  late List<Investment> _investments;
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
    _prefs = await SharedPreferences.getInstance();
    final investmentsJson = _prefs.getStringList(_storageKey) ?? [];

    final loaded = <Investment>[];
    int skipped = 0;
    for (final json in investmentsJson) {
      try {
        loaded.add(
            Investment.fromMap(jsonDecode(json) as Map<String, dynamic>));
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
    await _saveInvestments();
    _invalidateCache();
    notifyListeners();
  }

  Future<void> removeInvestment(String investmentId) async {
    _investments.removeWhere((inv) => inv.id == investmentId);
    await _saveInvestments();
    _invalidateCache();
    notifyListeners();
  }

  Future<void> deleteInvestment(String investmentId) async {
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
      await _saveInvestments();
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
    await _saveInvestments();
    _invalidateCache();
    notifyListeners();
  }

  Future<void> _saveInvestments() async {
    final investmentsJson = _investments
        .map((investment) => jsonEncode(investment.toMap()))
        .toList();
    await _prefs.setStringList(_storageKey, investmentsJson);
  }

  // Invalidates memoized caches when the investments list changes.
  // Called before every notifyListeners() that mutates the list.
  void _invalidateCache() {
    _totalAmountDirty = true;
    _cachedTotalAmount = null;
  }

  void reorderInvestments(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final investment = _investments.removeAt(oldIndex);
    _investments.insert(newIndex, investment);
    _saveInvestments();
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

    return updated;
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
