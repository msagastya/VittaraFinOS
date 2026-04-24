import 'package:shared_preferences/shared_preferences.dart';

/// Tracks which feature-discovery tooltips have been shown.
///
/// Each tooltip has a numeric [id]:
///   1 = Search coach mark (session 2)
///   2 = Voice mic coach mark (session 3)
///   3 = Calendar coach mark (session 4)
///   4 = Voice navigation banner (session 5)
class TooltipService {
  TooltipService._();
  static final TooltipService instance = TooltipService._();

  static const _keyPrefix = 'tooltip_shown_';
  static const _sessionCountKey = 'app_session_count';

  SharedPreferences? _prefs;

  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Returns true if this tooltip should be shown (not yet shown).
  Future<bool> shouldShow(int id) async {
    final prefs = await _getPrefs();
    return prefs.getBool('$_keyPrefix$id') != true;
  }

  /// Marks a tooltip as shown so it is never shown again.
  Future<void> markShown(int id) async {
    final prefs = await _getPrefs();
    await prefs.setBool('$_keyPrefix$id', true);
  }

  /// Returns the current session count (incremented once per app start).
  Future<int> sessionCount() async {
    final prefs = await _getPrefs();
    return prefs.getInt(_sessionCountKey) ?? 1;
  }

  /// Increments the session count. Call once per app cold-start from SplashScreen.
  Future<void> incrementSession() async {
    final prefs = await _getPrefs();
    final current = prefs.getInt(_sessionCountKey) ?? 0;
    await prefs.setInt(_sessionCountKey, current + 1);
  }
}
