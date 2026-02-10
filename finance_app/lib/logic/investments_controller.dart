import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vittara_fin_os/logic/investment_model.dart';
import 'package:vittara_fin_os/services/investment_value_service.dart';

class InvestmentsController with ChangeNotifier {
  late SharedPreferences _prefs;
  late List<Investment> _investments;
  static const String _storageKey = 'investments';

  List<Investment> get investments => _investments;

  InvestmentsController() {
    _investments = [];
  }

  Future<void> loadInvestments() async {
    _prefs = await SharedPreferences.getInstance();
    final investmentsJson = _prefs.getStringList(_storageKey) ?? [];

    _investments = investmentsJson
        .map((json) => Investment.fromMap(jsonDecode(json) as Map<String, dynamic>))
        .toList();

    notifyListeners();
  }

  Future<void> addInvestment(Investment investment) async {
    _investments.add(investment);
    await _saveInvestments();
    notifyListeners();
  }

  Future<void> removeInvestment(String investmentId) async {
    _investments.removeWhere((inv) => inv.id == investmentId);
    await _saveInvestments();
    notifyListeners();
  }

  Future<void> deleteInvestment(String investmentId) async {
    await removeInvestment(investmentId);
  }

  Future<void> updateInvestment(Investment investment) async {
    final index = _investments.indexWhere((inv) => inv.id == investment.id);

    if (index >= 0) {
      _investments[index] = investment;
      await _saveInvestments();
      notifyListeners();
    }
  }

  Future<void> _saveInvestments() async {
    final investmentsJson = _investments
        .map((investment) => jsonEncode(investment.toMap()))
        .toList();
    await _prefs.setStringList(_storageKey, investmentsJson);
  }

  void reorderInvestments(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final investment = _investments.removeAt(oldIndex);
    _investments.insert(newIndex, investment);
    _saveInvestments();
    notifyListeners();
  }

  double getTotalInvestmentAmount() {
    return _investments.fold(0, (sum, inv) => sum + inv.amount);
  }

  double getInvestmentAmountByType(InvestmentType type) {
    return _investments
        .where((inv) => inv.type == type)
        .fold(0, (sum, inv) => sum + inv.amount);
  }

  List<Investment> getInvestmentsByType(InvestmentType type) {
    return _investments.where((inv) => inv.type == type).toList();
  }

  Future<bool> refreshCurrentValues(InvestmentValueService valueService) async {
    var updated = false;
    for (var i = 0; i < _investments.length; i++) {
      final investment = _investments[i];
      final newValue = await valueService.fetchCurrentValue(investment);
      if (newValue != null) {
        final metadata = Map<String, dynamic>.from(investment.metadata ?? {});
        final oldValue = _asDouble(metadata['currentValue']);
        metadata['currentValue'] = newValue;

        if (oldValue != newValue) {
          _investments[i] = investment.copyWith(metadata: metadata);
          updated = true;
        }
      }
    }

    if (updated) {
      await _saveInvestments();
      notifyListeners();
    }

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
}
