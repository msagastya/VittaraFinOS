import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'lending_borrowing_model.dart';

class LendingBorrowingController extends ChangeNotifier {
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

  void addRecord(LendingBorrowing record) {
    _records.add(record);
    _saveRecords();
    notifyListeners();
  }

  void updateRecord(String id, LendingBorrowing updatedRecord) {
    final index = _records.indexWhere((r) => r.id == id);
    if (index != -1) {
      _records[index] = updatedRecord;
      _saveRecords();
      notifyListeners();
    }
  }

  void removeRecord(String id) {
    _records.removeWhere((r) => r.id == id);
    _saveRecords();
    notifyListeners();
  }

  void settleRecord(String id) {
    final index = _records.indexWhere((r) => r.id == id);
    if (index != -1) {
      _records[index] = _records[index].copyWith(
        isSettled: true,
        settledDate: DateTime.now().toString(),
      );
      _saveRecords();
      notifyListeners();
    }
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
}
