import 'package:shared_preferences/shared_preferences.dart';

/// Tracks whether first-time feature tips have been shown.
class FirstTimeTip {
  FirstTimeTip._();

  static Future<bool> shouldShow(String tipKey) async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool('tip_$tipKey') ?? false;
    if (!seen) {
      await prefs.setBool('tip_$tipKey', true);
      return true;
    }
    return false;
  }

  static Future<void> markSeen(String tipKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('tip_$tipKey', true);
  }

  static Future<void> resetAll() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('tip_')).toList();
    for (final k in keys) {
      await prefs.remove(k);
    }
  }
}
