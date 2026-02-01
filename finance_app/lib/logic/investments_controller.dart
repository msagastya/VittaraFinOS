import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vittara_fin_os/logic/investment_model.dart';

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
    print('\n📥 InvestmentsController.updateInvestment called');
    print('   Investment ID: ${investment.id}');
    print('   Investment Name: ${investment.name}');
    print('   Investment Amount: ${investment.amount}');
    print('   Investment Type: ${investment.type}');
    if (investment.metadata != null) {
      print('   Metadata keys: ${investment.metadata!.keys.toList()}');
      print('   - renewalCycles exists: ${investment.metadata!.containsKey('renewalCycles')}');
      if (investment.metadata!.containsKey('renewalCycles')) {
        print('   - renewalCycles length: ${(investment.metadata!['renewalCycles'] as List?)?.length ?? 0}');
      }
    }

    final index = _investments.indexWhere((inv) => inv.id == investment.id);
    print('   Found at index: $index');

    if (index >= 0) {
      _investments[index] = investment;
      print('   ✅ Investment updated in list');
      await _saveInvestments();
      print('   ✅ Saved to SharedPreferences');
      notifyListeners();
    } else {
      print('   ❌ Investment not found in list!');
    }
  }

  Future<void> _saveInvestments() async {
    print('\n💾 Saving ${_investments.length} investments to SharedPreferences');
    final investmentsJson = _investments
        .map((investment) {
          print('   - Saving: ${investment.name} (ID: ${investment.id}, Amount: ${investment.amount})');
          return jsonEncode(investment.toMap());
        })
        .toList();
    await _prefs.setStringList(_storageKey, investmentsJson);
    print('   ✅ Saved successfully');
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
}
