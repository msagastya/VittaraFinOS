import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vittara_fin_os/logic/investment_model.dart';

class InvestmentTypePreferencesController with ChangeNotifier {
  late SharedPreferences _prefs;
  late List<InvestmentType> _preferredTypes;

  static const String _storageKey = 'investment_type_preferences';

  // All investment types in order
  static const List<InvestmentType> allTypes = [
    InvestmentType.stocks,
    InvestmentType.mutualFund,
    InvestmentType.fixedDeposit,
    InvestmentType.recurringDeposit,
    InvestmentType.bonds,
    InvestmentType.nationalSavingsScheme,
    InvestmentType.digitalGold,
    InvestmentType.pensionSchemes,
    InvestmentType.cryptocurrency,
    InvestmentType.futuresOptions,
    InvestmentType.forexCurrency,
    InvestmentType.commodities,
  ];

  List<InvestmentType> get preferredTypes => _preferredTypes;

  List<InvestmentType> get hiddenTypes {
    return allTypes.where((type) => !_preferredTypes.contains(type)).toList();
  }

  InvestmentTypePreferencesController() {
    _preferredTypes = [
      InvestmentType.stocks,
      InvestmentType.mutualFund,
      InvestmentType.fixedDeposit,
      InvestmentType.recurringDeposit,
      InvestmentType.bonds,
    ];
  }

  Future<void> loadPreferences() async {
    _prefs = await SharedPreferences.getInstance();
    final savedPreferences = _prefs.getStringList(_storageKey);

    if (savedPreferences != null && savedPreferences.isNotEmpty) {
      _preferredTypes = savedPreferences
          .map((typeIndex) => InvestmentType.values[int.parse(typeIndex)])
          .toList();
    }

    notifyListeners();
  }

  Future<void> savePreferences(List<InvestmentType> types) async {
    // Maximum 6 types allowed
    if (types.length > 6) {
      return;
    }

    _preferredTypes = types;
    final typeIndices = types.map((type) => type.index.toString()).toList();
    await _prefs.setStringList(_storageKey, typeIndices);
    notifyListeners();
  }

  void toggleTypePreference(InvestmentType type) {
    if (_preferredTypes.contains(type)) {
      // Remove if already selected (no minimum limit)
      _preferredTypes.remove(type);
    } else {
      // Add if not selected and under 6 limit
      if (_preferredTypes.length < 6) {
        _preferredTypes.add(type);
      }
    }
    notifyListeners();
  }

  bool isTypePreferred(InvestmentType type) {
    return _preferredTypes.contains(type);
  }

  bool canAddMore() {
    return _preferredTypes.length < 6;
  }

  int getRemainingSlots() {
    return 6 - _preferredTypes.length;
  }

  String getTypeLabel(InvestmentType type) {
    final investment = _getDummyInvestment(type);
    return investment.getTypeLabel();
  }

  Investment _getDummyInvestment(InvestmentType type) {
    return Investment(
      id: '',
      name: '',
      type: type,
      amount: 0,
      color: Colors.grey,
    );
  }
}
