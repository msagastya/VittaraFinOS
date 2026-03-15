import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vittara_fin_os/utils/logger.dart';

final _brokersLogger = AppLogger();

class BrokersController with ChangeNotifier {
  static const _prefsKey = 'brokers_state_v1';
  late List<Map<String, dynamic>> _brokers;

  List<Map<String, dynamic>> get brokers => _brokers;

  BrokersController() {
    _brokers = _generateBrokersList();
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_prefsKey);
    if (json == null) return;
    try {
      final List<dynamic> stored = jsonDecode(json);
      final defaultIds = {for (final b in _brokers) b['id'] as String};
      final storedMap = <String, Map<String, dynamic>>{
        for (final b in stored.cast<Map<String, dynamic>>())
          b['id'] as String: b
      };
      // Append custom brokers not in default list
      for (final entry in storedMap.values) {
        final id = entry['id'] as String;
        if (!defaultIds.contains(id)) {
          _brokers.add({
            'id': id,
            'name': entry['name'] ?? 'Custom Broker',
            'color': Color(entry['colorValue'] as int? ?? 0xFF007AFF),
          });
        }
      }
      notifyListeners();
    } catch (e) {
      _brokersLogger.warning('Failed to load brokers from prefs', error: e);
    }
  }

  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final serialized = _brokers.map((b) {
      final color = b['color'];
      return {
        'id': b['id'],
        'name': b['name'],
        'colorValue': color is Color ? color.toARGB32() : 0xFF007AFF,
      };
    }).toList();
    await prefs.setString(_prefsKey, jsonEncode(serialized));
  }

  List<Map<String, dynamic>> _generateBrokersList() {
    final brokers = [
      {'name': 'Zerodha', 'color': const Color(0xFF387ED1)},
      {'name': 'Groww', 'color': const Color(0xFF00D09C)},
      {'name': 'Upstox', 'color': const Color(0xFF633092)},
      {'name': 'Angel One', 'color': const Color(0xFFF26722)},
      {'name': 'Shoonya', 'color': const Color(0xFFFF6B35)},
      {'name': 'Paytm Money', 'color': const Color(0xFF002E6E)},
      {'name': 'Alice Blue', 'color': const Color(0xFF1E3A5F)},
      {'name': 'Motilal Oswal', 'color': const Color(0xFF00A651)},
    ];

    return brokers.map((broker) {
      return {
        'id': (broker['name'] as String).replaceAll(' ', '_').toLowerCase(),
        'name': broker['name'],
        'color': broker['color'],
      };
    }).toList();
  }

  Map<String, dynamic>? getBrokerByName(String name) {
    return _brokers.where((broker) => broker['name'] == name).firstOrNull;
  }

  void addBroker(Map<String, dynamic> newBroker) {
    _brokers.add(newBroker);
    notifyListeners();
    _saveToPrefs();
  }

  void sortBrokers(bool ascending) {
    _brokers.sort((a, b) {
      final comparison = (a['name'] as String).compareTo(b['name'] as String);
      return ascending ? comparison : -comparison;
    });
    notifyListeners();
  }
}
