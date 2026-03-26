import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PaymentAppsController with ChangeNotifier {
  static const String _storageKey = 'payment_apps';
  late List<Map<String, dynamic>> _paymentApps;

  List<Map<String, dynamic>> get paymentApps => _paymentApps;

  List<Map<String, dynamic>> get enabledApps =>
      _paymentApps.where((app) => app['isEnabled'] == true).toList();

  List<Map<String, dynamic>> get disabledApps =>
      _paymentApps.where((app) => app['isEnabled'] == false).toList();

  PaymentAppsController() {
    _paymentApps = _generatePaymentAppsList();
  }

  Future<void> loadApps() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      await _saveApps();
      return;
    }

    try {
      final decoded = (jsonDecode(raw) as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
      _paymentApps = decoded.map((item) {
        return {
          'id': item['id'],
          'name': item['name'],
          'color': Color(item['color'] as int),
          'isEnabled': item['isEnabled'] ?? false,
          'hasWallet': item['hasWallet'] ?? false,
          'walletBalance': (item['walletBalance'] as num?)?.toDouble() ?? 0.0,
        };
      }).toList();
      notifyListeners();
    } catch (_) {
      _paymentApps = _generatePaymentAppsList();
      await _saveApps();
      notifyListeners();
    }
  }

  Future<void> _saveApps() async {
    final prefs = await SharedPreferences.getInstance();
    final serializable = _paymentApps
        .map((app) => {
              'id': app['id'],
              'name': app['name'],
              'color': (app['color'] as Color).toARGB32(),
              'isEnabled': app['isEnabled'] ?? false,
              'hasWallet': app['hasWallet'] ?? false,
              'walletBalance':
                  (app['walletBalance'] as num?)?.toDouble() ?? 0.0,
            })
        .toList();
    await prefs.setString(_storageKey, jsonEncode(serializable));
  }

  List<Map<String, dynamic>> _generatePaymentAppsList() {
    final apps = [
      {'name': 'PhonePe', 'color': const Color(0xFF5F259F)},
      {'name': 'Google Pay', 'color': const Color(0xFF4285F4)},
      {'name': 'Paytm', 'color': const Color(0xFF002E6E)},
      {'name': 'WhatsApp Pay', 'color': const Color(0xFF25D366)},
      {'name': 'Amazon Pay', 'color': const Color(0xFFF4B400)},
      {'name': 'Apple Pay', 'color': const Color(0xFF000000)},
      {'name': 'Airtel Pay', 'color': const Color(0xFFED1C24)},
      {'name': 'BHIM', 'color': const Color(0xFF0066CC)},
      {'name': 'iMobile Pay', 'color': const Color(0xFF007DCC)},
      {'name': 'MobiKwik', 'color': const Color(0xFFE94D29)},
      {'name': 'Freecharge', 'color': const Color(0xFF00A699)},
      {'name': 'OneCard', 'color': const Color(0xFF5B21B6)},
      {'name': 'Cred', 'color': const Color(0xFF000000)},
      {'name': 'Slice', 'color': const Color(0xFF6366F1)},
      {'name': 'Razorpay', 'color': const Color(0xFF02042B)},
      {'name': 'Stripe', 'color': const Color(0xFF5469D4)},
      {'name': 'PayPal', 'color': const Color(0xFF003087)},
      {'name': 'Skrill', 'color': const Color(0xFF00A4EF)},
      {'name': 'Wise', 'color': const Color(0xFF0066B2)},
      {'name': 'Bitcoin', 'color': const Color(0xFFF7931A)},
    ];

    apps.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));

    return apps
        .map((app) => {
              'id': (app['name'] as String).replaceAll(' ', '_').toLowerCase(),
              'name': app['name'],
              'color': app['color'],
              'isEnabled': false,
              'hasWallet': false,
              'walletBalance': 0.0,
            })
        .toList();
  }

  Future<void> toggleApp(String appId, bool value) async {
    final index = _paymentApps.indexWhere((app) => app['id'] == appId);
    if (index != -1) {
      _paymentApps[index]['isEnabled'] = value;
      notifyListeners();
      await _saveApps();
    }
  }

  Future<void> deleteApp(String appId) async {
    _paymentApps.removeWhere((app) => app['id'] == appId);
    notifyListeners();
    await _saveApps();
  }

  Future<void> reorderApps(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) newIndex -= 1;
    final item = _paymentApps.removeAt(oldIndex);
    _paymentApps.insert(newIndex, item);
    notifyListeners();
    await _saveApps();
  }

  Future<void> sortApps(bool ascending) async {
    _paymentApps.sort((a, b) {
      final comparison = (a['name'] as String).compareTo(b['name'] as String);
      return ascending ? comparison : -comparison;
    });
    notifyListeners();
    await _saveApps();
  }

  Map<String, dynamic>? getAppByName(String name) {
    return _paymentApps.where((app) => app['name'] == name).firstOrNull;
  }

  Future<void> addApp(Map<String, dynamic> newApp) async {
    _paymentApps.add({
      'id': newApp['id'],
      'name': newApp['name'],
      'color': newApp['color'] ?? CupertinoColors.activeBlue,
      'isEnabled': newApp['isEnabled'] ?? true,
      'hasWallet': newApp['hasWallet'] ?? false,
      'walletBalance': (newApp['walletBalance'] as num?)?.toDouble() ?? 0.0,
    });
    notifyListeners();
    await _saveApps();
  }

  Future<void> setWalletBalance(String appId, double balance) async {
    final index = _paymentApps.indexWhere((app) => app['id'] == appId);
    if (index == -1) return;
    _paymentApps[index]['walletBalance'] = balance < 0 ? 0.0 : balance;
    notifyListeners();
    await _saveApps();
  }

  Future<void> setWalletSupport(
    String appId,
    bool hasWallet, {
    double? openingBalance,
  }) async {
    final index = _paymentApps.indexWhere((app) => app['id'] == appId);
    if (index == -1) return;
    _paymentApps[index]['hasWallet'] = hasWallet;
    if (!hasWallet) {
      _paymentApps[index]['walletBalance'] = 0.0;
    } else if (openingBalance != null) {
      _paymentApps[index]['walletBalance'] =
          openingBalance < 0 ? 0.0 : openingBalance;
    } else {
      _paymentApps[index]['walletBalance'] =
          (_paymentApps[index]['walletBalance'] as num?)?.toDouble() ?? 0.0;
    }
    notifyListeners();
    await _saveApps();
  }

  Future<void> adjustWalletBalanceByName(String appName, double delta) async {
    final index = _paymentApps.indexWhere((app) => app['name'] == appName);
    if (index == -1) return;
    final current =
        (_paymentApps[index]['walletBalance'] as num?)?.toDouble() ?? 0.0;
    _paymentApps[index]['walletBalance'] =
        (current + delta).clamp(0.0, double.infinity);
    await _saveApps();
    notifyListeners();
  }
}
