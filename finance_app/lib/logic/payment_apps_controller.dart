import 'package:flutter/material.dart';

class PaymentAppsController with ChangeNotifier {
  late List<Map<String, dynamic>> _paymentApps;

  List<Map<String, dynamic>> get paymentApps => _paymentApps;

  List<Map<String, dynamic>> get enabledApps =>
      _paymentApps.where((app) => app['isEnabled'] == true).toList();

  List<Map<String, dynamic>> get disabledApps =>
      _paymentApps.where((app) => app['isEnabled'] == false).toList();

  PaymentAppsController() {
    _paymentApps = _generatePaymentAppsList();
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

    return apps.map((app) {
      return {
        'id': (app['name'] as String).replaceAll(' ', '_').toLowerCase(),
        'name': app['name'],
        'color': app['color'],
        'isEnabled': false,
      };
    }).toList();
  }

  void toggleApp(String appId, bool value) {
    final index = _paymentApps.indexWhere((app) => app['id'] == appId);
    if (index != -1) {
      _paymentApps[index]['isEnabled'] = value;
      notifyListeners();
    }
  }

  void deleteApp(String appId) {
    _paymentApps.removeWhere((app) => app['id'] == appId);
    notifyListeners();
  }

  void reorderApps(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) newIndex -= 1;
    final item = _paymentApps.removeAt(oldIndex);
    _paymentApps.insert(newIndex, item);
    notifyListeners();
  }

  void sortApps(bool ascending) {
    _paymentApps.sort((a, b) {
      final comparison =
          (a['name'] as String).compareTo(b['name'] as String);
      return ascending ? comparison : -comparison;
    });
    notifyListeners();
  }

  Map<String, dynamic>? getAppByName(String name) {
    try {
      return _paymentApps.firstWhere((app) => app['name'] == name);
    } catch (e) {
      return null;
    }
  }

  void addApp(Map<String, dynamic> newApp) {
    _paymentApps.add(newApp);
    notifyListeners();
  }
}
