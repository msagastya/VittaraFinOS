import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:vittara_fin_os/logic/lending_borrowing_model.dart';

class LendingBorrowingController with ChangeNotifier {
  List<LendingBorrowing> _records = [];

  List<LendingBorrowing> get records => _records;

  Future<void> loadRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('lending_borrowing_records');

    if (jsonString != null) {
      try {
        final List<dynamic> jsonList = jsonDecode(jsonString);
        _records = jsonList
            .map((item) =>
                LendingBorrowing.fromMap(Map<String, dynamic>.from(item)))
            .toList();
        var migrated = false;
        _records = _records.map((record) {
          final normalized = _ensureHistorySeeded(record);
          if (!identical(normalized, record)) {
            migrated = true;
          }
          return normalized;
        }).toList();
        if (migrated) {
          await _saveRecords();
        }
      } catch (e) {
        _records = [];
      }
    }
    notifyListeners();
  }

  Future<void> _saveRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(_records.map((r) => r.toMap()).toList());
    await prefs.setString('lending_borrowing_records', jsonString);
  }

  Future<void> addRecord(LendingBorrowing record) async {
    final enriched = _appendHistory(
      _ensureHistorySeeded(record),
      type: LendingHistoryEventType.created,
      amountDelta: record.amount,
      note: 'Record created',
      eventTime: record.date,
      skipIfDuplicateCreate: true,
    );
    _records.add(enriched);
    await _saveRecords();
    notifyListeners();
  }

  Future<void> updateRecord(
    String id,
    LendingBorrowing updatedRecord, {
    LendingHistoryEventType eventType = LendingHistoryEventType.edited,
    String? note,
    double? amountDelta,
    DateTime? eventTime,
  }) async {
    final index = _records.indexWhere((r) => r.id == id);
    if (index != -1) {
      final previous = _records[index];
      final delta = amountDelta ?? (updatedRecord.amount - previous.amount);
      final previousWithHistory = _ensureHistorySeeded(previous);
      final mergedBase = updatedRecord.history.isEmpty
          ? updatedRecord.copyWith(history: previousWithHistory.history)
          : updatedRecord;
      final withHistory = _appendHistory(
        mergedBase,
        type: eventType,
        amountDelta: delta == 0 ? null : delta,
        note: note,
        eventTime: eventTime,
      );
      _records[index] = withHistory;
      await _saveRecords();
      notifyListeners();
    }
  }

  void adjustRecordAmount(String id, double delta, {required bool increase}) {
    final index = _records.indexWhere((r) => r.id == id);
    if (index == -1) return;

    final record = _records[index];
    final signed = increase ? delta : -delta;
    final nextAmount = (record.amount + signed).clamp(0.0, double.infinity);
    final adjusted = record.copyWith(amount: nextAmount);
    updateRecord(
      id,
      adjusted,
      eventType: increase
          ? LendingHistoryEventType.amountIncreased
          : LendingHistoryEventType.amountReduced,
      note: increase ? 'Amount increased' : 'Amount reduced',
      amountDelta: signed,
      eventTime: DateTime.now(),
    );
  }

  Future<void> removeRecord(String id) async {
    _records.removeWhere((r) => r.id == id);
    await _saveRecords();
    notifyListeners();
  }

  void settleRecord(String id) {
    final index = _records.indexWhere((r) => r.id == id);
    if (index != -1) {
      final now = DateTime.now();
      final updated = _records[index].copyWith(
        isSettled: true,
        settledDate: now.toIso8601String(),
      );
      updateRecord(
        id,
        updated,
        eventType: LendingHistoryEventType.settled,
        note: 'Marked as settled',
        amountDelta: 0,
        eventTime: now,
      );
    }
  }

  void reopenRecord(String id) {
    final index = _records.indexWhere((r) => r.id == id);
    if (index == -1) return;
    final now = DateTime.now();
    final updated = _records[index].copyWith(
      isSettled: false,
      settledDate: null,
    );
    updateRecord(
      id,
      updated,
      eventType: LendingHistoryEventType.reopened,
      note: 'Reopened as active',
      amountDelta: 0,
      eventTime: now,
    );
  }

  double getTotalLent() {
    return _records
        .where((r) => r.type == LendingType.lent && !r.isSettled)
        .fold(0, (sum, r) => sum + r.amount);
  }

  double getTotalBorrowed() {
    return _records
        .where((r) => r.type == LendingType.borrowed && !r.isSettled)
        .fold(0, (sum, r) => sum + r.amount);
  }

  List<LendingBorrowing> getLentRecords() {
    return _records.where((r) => r.type == LendingType.lent).toList();
  }

  List<LendingBorrowing> getBorrowedRecords() {
    return _records.where((r) => r.type == LendingType.borrowed).toList();
  }

  List<LendingBorrowing> getLentActiveRecords() {
    return _records
        .where((r) => r.type == LendingType.lent && !r.isSettled)
        .toList();
  }

  List<LendingBorrowing> getBorrowedActiveRecords() {
    return _records
        .where((r) => r.type == LendingType.borrowed && !r.isSettled)
        .toList();
  }

  List<LendingBorrowing> getSettledRecords() {
    final settled = _records.where((r) => r.isSettled).toList();
    settled.sort((a, b) {
      final aDate = DateTime.tryParse(a.settledDate ?? '') ?? a.date;
      final bDate = DateTime.tryParse(b.settledDate ?? '') ?? b.date;
      return bDate.compareTo(aDate);
    });
    return settled;
  }

  LendingBorrowing _ensureHistorySeeded(LendingBorrowing record) {
    if (record.history.isNotEmpty) return record;

    final seeded = <LendingHistoryEvent>[
      LendingHistoryEvent(
        id: '${record.id}_created',
        type: LendingHistoryEventType.created,
        timestamp: record.date,
        amountDelta: record.amount,
        resultingAmount: record.amount,
        note: 'Record created',
      ),
    ];
    if (record.isSettled) {
      final settledTime =
          DateTime.tryParse(record.settledDate ?? '') ?? DateTime.now();
      seeded.add(
        LendingHistoryEvent(
          id: '${record.id}_settled',
          type: LendingHistoryEventType.settled,
          timestamp: settledTime,
          amountDelta: 0,
          resultingAmount: record.amount,
          note: 'Marked as settled',
        ),
      );
    }
    return record.copyWith(history: seeded);
  }

  LendingBorrowing _appendHistory(
    LendingBorrowing record, {
    required LendingHistoryEventType type,
    double? amountDelta,
    String? note,
    DateTime? eventTime,
    bool skipIfDuplicateCreate = false,
  }) {
    final events = [...record.history];
    if (skipIfDuplicateCreate &&
        type == LendingHistoryEventType.created &&
        events.any((entry) => entry.type == LendingHistoryEventType.created)) {
      return record;
    }
    events.add(
      LendingHistoryEvent(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        type: type,
        timestamp: eventTime ?? DateTime.now(),
        amountDelta: amountDelta,
        resultingAmount: record.amount,
        note: note,
      ),
    );
    return record.copyWith(history: events);
  }
}
