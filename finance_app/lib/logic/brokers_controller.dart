import 'package:flutter/material.dart';

class BrokersController with ChangeNotifier {
  late List<Map<String, dynamic>> _brokers;

  List<Map<String, dynamic>> get brokers => _brokers;

  BrokersController() {
    _brokers = _generateBrokersList();
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
    try {
      return _brokers.firstWhere((broker) => broker['name'] == name);
    } catch (e) {
      return null;
    }
  }

  void addBroker(Map<String, dynamic> newBroker) {
    _brokers.add(newBroker);
    notifyListeners();
  }

  void sortBrokers(bool ascending) {
    _brokers.sort((a, b) {
      final comparison =
          (a['name'] as String).compareTo(b['name'] as String);
      return ascending ? comparison : -comparison;
    });
    notifyListeners();
  }
}
