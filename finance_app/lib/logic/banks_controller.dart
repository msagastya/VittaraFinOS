import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BanksController with ChangeNotifier {
  static const _prefsKey = 'banks_state_v1';

  late List<Map<String, dynamic>> _banks;

  List<Map<String, dynamic>> get banks => _banks;

  List<Map<String, dynamic>> get enabledBanks =>
      _banks.where((bank) => bank['isEnabled'] == true).toList();

  List<Map<String, dynamic>> get disabledBanks =>
      _banks.where((bank) => bank['isEnabled'] == false).toList();

  BanksController() {
    _banks = _generateBankList();
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_prefsKey);
    if (json == null) return;
    try {
      final List<dynamic> stored = jsonDecode(json);
      // Merge: start with full default list, then apply stored isEnabled/senderIds
      // and append any custom banks not in the default list
      final defaultIds = {for (final b in _banks) b['id'] as String};
      final storedMap = <String, Map<String, dynamic>>{
        for (final b in stored.cast<Map<String, dynamic>>())
          b['id'] as String: b
      };

      // Update defaults with stored state
      for (int i = 0; i < _banks.length; i++) {
        final id = _banks[i]['id'] as String;
        if (storedMap.containsKey(id)) {
          _banks[i] = {
            ..._banks[i],
            'isEnabled': storedMap[id]!['isEnabled'] ?? false,
            'senderIds': (storedMap[id]!['senderIds'] as List?)
                    ?.cast<String>() ??
                <String>[],
            if (storedMap[id]!['name'] != null) 'name': storedMap[id]!['name'],
          };
        }
      }

      // Append custom banks (not in default list)
      for (final stored in storedMap.values) {
        final id = stored['id'] as String;
        if (!defaultIds.contains(id)) {
          _banks.add({
            'id': id,
            'name': stored['name'] ?? 'Custom Bank',
            'color': Color(stored['colorValue'] as int? ?? 0xFF007AFF),
            'isEnabled': stored['isEnabled'] ?? true,
            'senderIds': (stored['senderIds'] as List?)?.cast<String>() ?? [],
          });
        }
      }

      notifyListeners();
    } catch (_) {}
  }

  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final serialized = _banks.map((b) {
      final color = b['color'];
      return {
        'id': b['id'],
        'name': b['name'],
        'colorValue': color is Color ? color.toARGB32() : 0xFF007AFF,
        'isEnabled': b['isEnabled'] ?? false,
        'senderIds': b['senderIds'] ?? [],
      };
    }).toList();
    await prefs.setString(_prefsKey, jsonEncode(serialized));
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
      _saveToPrefs();
    }
  }

  void deleteBank(String bankId) {
    _banks.removeWhere((bank) => bank['id'] == bankId);
    notifyListeners();
    _saveToPrefs();
  }

  void reorderBanks(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) newIndex -= 1;
    final item = _banks.removeAt(oldIndex);
    _banks.insert(newIndex, item);
    notifyListeners();
    _saveToPrefs();
  }

  void sortBanks(bool ascending) {
    _banks.sort((a, b) {
      final comparison = (a['name'] as String).compareTo(b['name'] as String);
      return ascending ? comparison : -comparison;
    });
    notifyListeners();
    _saveToPrefs();
  }

  Map<String, dynamic>? getBankByName(String name) {
    try {
      return _banks.firstWhere((bank) => bank['name'] == name);
    } catch (e) {
      return null;
    }
  }

  bool bankNameExists(String name) {
    final normalized = _normalizeName(name);
    return _banks.any((b) => _normalizeName(b['name']?.toString() ?? '') == normalized);
  }

  void addBank(Map<String, dynamic> newBank) {
    _banks.add(newBank);
    notifyListeners();
    _saveToPrefs();
  }

  void updateBank(Map<String, dynamic> updatedBank) {
    final index = _banks.indexWhere((b) => b['id'] == updatedBank['id']);
    if (index != -1) {
      _banks[index] = updatedBank;
      notifyListeners();
      _saveToPrefs();
    }
  }

  /// Returns null on success, or an error message on failure.
  String? addNewBank(String name, List<String> senderIds) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'Bank name cannot be empty';
    if (bankNameExists(trimmed)) return 'A bank with this name already exists';

    var id = _slugify(trimmed);
    var suffix = 2;
    while (_banks.any((bank) => bank['id'] == id)) {
      id = '${_slugify(trimmed)}_$suffix';
      suffix++;
    }

    _banks.add({
      'id': id,
      'name': trimmed,
      'color': const Color(0xFF007AFF),
      'isEnabled': true,
      'senderIds': senderIds,
    });
    notifyListeners();
    _saveToPrefs();
    return null;
  }

  void ensureBankEnabledByName(String bankName, {Color? color}) {
    final trimmedName = bankName.trim();
    if (trimmedName.isEmpty) return;

    final normalizedTarget = _normalizeName(trimmedName);
    final existingIndex = _banks.indexWhere(
      (bank) =>
          _normalizeName(bank['name']?.toString() ?? '') == normalizedTarget,
    );

    if (existingIndex >= 0) {
      if (_banks[existingIndex]['isEnabled'] != true) {
        _banks[existingIndex]['isEnabled'] = true;
        notifyListeners();
      }
      return;
    }

    var id = _slugify(trimmedName);
    var suffix = 2;
    while (_banks.any((bank) => bank['id'] == id)) {
      id = '${_slugify(trimmedName)}_$suffix';
      suffix += 1;
    }

    _banks.add({
      'id': id,
      'name': trimmedName,
      'color': color ?? const Color(0xFF007AFF),
      'isEnabled': true,
      'senderIds': <String>[],
    });
    notifyListeners();
    _saveToPrefs();
  }

  String _normalizeName(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  String _slugify(String value) {
    final normalized = value.trim().toLowerCase();
    final slug = normalized
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return slug.isEmpty ? 'bank' : slug;
  }
}
