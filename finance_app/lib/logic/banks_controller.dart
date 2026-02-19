import 'package:flutter/material.dart';

class BanksController with ChangeNotifier {
  late List<Map<String, dynamic>> _banks;

  List<Map<String, dynamic>> get banks => _banks;

  List<Map<String, dynamic>> get enabledBanks =>
      _banks.where((bank) => bank['isEnabled'] == true).toList();

  List<Map<String, dynamic>> get disabledBanks =>
      _banks.where((bank) => bank['isEnabled'] == false).toList();

  BanksController() {
    _banks = _generateBankList();
  }

  List<Map<String, dynamic>> _generateBankList() {
    final banks = [
      {'name': 'State Bank of India (SBI)', 'color': const Color(0xFF007DCC)},
      {'name': 'HDFC Bank', 'color': const Color(0xFF004C8F)},
      {'name': 'ICICI Bank', 'color': const Color(0xFFF37E20)},
      {'name': 'Axis Bank', 'color': const Color(0xFF97144D)},
      {'name': 'Kotak Mahindra Bank', 'color': const Color(0xFFED1C24)},
      {'name': 'Punjab National Bank (PNB)', 'color': const Color(0xFFA20A3E)},
      {'name': 'Bank of Baroda', 'color': const Color(0xFFF26522)},
      {'name': 'Canara Bank', 'color': const Color(0xFFF37021)},
      {'name': 'Union Bank of India', 'color': const Color(0xFFE21F25)},
      {'name': 'IndusInd Bank', 'color': const Color(0xFF981C26)},
      {'name': 'IDBI Bank', 'color': const Color(0xFF007548)},
      {'name': 'Yes Bank', 'color': const Color(0xFF00539B)},
      {'name': 'IDFC First Bank', 'color': const Color(0xFF9D1D27)},
      {'name': 'Federal Bank', 'color': const Color(0xFFE87722)},
      {'name': 'Indian Bank', 'color': const Color(0xFF005494)},
      {'name': 'Bank of India', 'color': const Color(0xFFF68D2E)},
      {'name': 'Central Bank of India', 'color': const Color(0xFF005B98)},
      {'name': 'UCO Bank', 'color': const Color(0xFF005B9F)},
      {'name': 'Bank of Maharashtra', 'color': const Color(0xFFED1C24)},
      {'name': 'Paytm Payments Bank', 'color': const Color(0xFF002E6E)},
      {'name': 'Airtel Payments Bank', 'color': const Color(0xFFED1C24)},
      {'name': 'Google Pay', 'color': const Color(0xFF4285F4)},
      {'name': 'Amazon Pay', 'color': const Color(0xFFF4B400)},
      {'name': 'PhonePe', 'color': const Color(0xFF5F259F)},
      {'name': 'Cred', 'color': const Color(0xFF000000)},
    ];

    banks.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));

    return banks.map((bank) {
      return {
        'id': (bank['name'] as String).replaceAll(' ', '_').toLowerCase(),
        'name': bank['name'],
        'color': bank['color'],
        'isEnabled': false,
        'senderIds': <String>[],
      };
    }).toList();
  }

  void toggleBank(String bankId, bool value) {
    final index = _banks.indexWhere((bank) => bank['id'] == bankId);
    if (index != -1) {
      _banks[index]['isEnabled'] = value;
      notifyListeners();
    }
  }

  void deleteBank(String bankId) {
    _banks.removeWhere((bank) => bank['id'] == bankId);
    notifyListeners();
  }

  void reorderBanks(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) newIndex -= 1;
    final item = _banks.removeAt(oldIndex);
    _banks.insert(newIndex, item);
    notifyListeners();
  }

  void sortBanks(bool ascending) {
    _banks.sort((a, b) {
      final comparison = (a['name'] as String).compareTo(b['name'] as String);
      return ascending ? comparison : -comparison;
    });
    notifyListeners();
  }

  Map<String, dynamic>? getBankByName(String name) {
    try {
      return _banks.firstWhere((bank) => bank['name'] == name);
    } catch (e) {
      return null;
    }
  }

  void addBank(Map<String, dynamic> newBank) {
    _banks.add(newBank);
    notifyListeners();
  }
}
