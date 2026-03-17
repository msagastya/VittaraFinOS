import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vittara_fin_os/logic/loan_model.dart';

const String _kLoansKey = 'loans';

class LoanController with ChangeNotifier {
  List<Loan> _loans = [];

  List<Loan> get loans => List.unmodifiable(_loans);

  List<Loan> get activeLoans => _loans.where((l) => l.isActive).toList();

  double get totalOutstanding => activeLoans.fold(0.0, (sum, l) => sum + l.currentOutstanding);

  double get monthlyEMITotal => activeLoans.fold(0.0, (sum, l) => sum + l.emiAmount);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_kLoansKey);
    if (jsonString != null) {
      try {
        final List<dynamic> jsonList = jsonDecode(jsonString) as List<dynamic>;
        _loans = jsonList
            .map((item) => Loan.fromMap(Map<String, dynamic>.from(item as Map)))
            .toList();
      } catch (_) {
        _loans = [];
      }
    }
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(_loans.map((l) => l.toMap()).toList());
    await prefs.setString(_kLoansKey, jsonString);
  }

  Future<void> addLoan(Loan loan) async {
    _loans.add(loan);
    await _save();
    notifyListeners();
  }

  Future<void> updateLoan(Loan loan) async {
    final index = _loans.indexWhere((l) => l.id == loan.id);
    if (index != -1) {
      _loans[index] = loan;
      await _save();
      notifyListeners();
    }
  }

  Future<void> deleteLoan(String id) async {
    _loans.removeWhere((l) => l.id == id);
    await _save();
    notifyListeners();
  }

  Loan? getLoanById(String id) {
    try {
      return _loans.firstWhere((l) => l.id == id);
    } catch (_) {
      return null;
    }
  }
}
