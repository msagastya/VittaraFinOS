import 'package:shared_preferences/shared_preferences.dart';

/// Singleton that records screen tap counts and surfaces the most-used routes.
///
/// Usage:
///   UsageTrackerService.instance.record('/investments');
///   final top = await UsageTrackerService.instance.topRoutes(4);
class UsageTrackerService {
  UsageTrackerService._();
  static final UsageTrackerService instance = UsageTrackerService._();

  static const _keyPrefix = 'usage_tap_count_';
  static const _firstUseDateKey = 'usage_first_use_date';

  SharedPreferences? _prefs;

  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Record a visit to [routeName].
  Future<void> record(String routeName) async {
    final prefs = await _getPrefs();
    final key = '$_keyPrefix$routeName';
    final current = prefs.getInt(key) ?? 0;
    await prefs.setInt(key, current + 1);

    // Record first use date if not set
    if (!prefs.containsKey(_firstUseDateKey)) {
      await prefs.setString(
          _firstUseDateKey, DateTime.now().toIso8601String());
    }
  }

  /// Returns top [n] route names sorted by tap count descending.
  Future<List<String>> topRoutes(int n) async {
    final prefs = await _getPrefs();
    final entries = prefs
        .getKeys()
        .where((k) => k.startsWith(_keyPrefix))
        .map((k) => MapEntry(k.substring(_keyPrefix.length), prefs.getInt(k) ?? 0))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(n).map((e) => e.key).toList();
  }

  /// Returns the number of days since first recorded use. -1 if no data.
  Future<int> daysSinceFirstUse() async {
    final prefs = await _getPrefs();
    final raw = prefs.getString(_firstUseDateKey);
    if (raw == null) return -1;
    final first = DateTime.tryParse(raw);
    if (first == null) return -1;
    return DateTime.now().difference(first).inDays;
  }

  /// Returns tap count for a specific route.
  Future<int> countFor(String routeName) async {
    final prefs = await _getPrefs();
    return prefs.getInt('$_keyPrefix$routeName') ?? 0;
  }

  /// Returns all recorded routes with their tap counts.
  Future<Map<String, int>> allCounts() async {
    final prefs = await _getPrefs();
    return Map.fromEntries(
      prefs
          .getKeys()
          .where((k) => k.startsWith(_keyPrefix))
          .map((k) =>
              MapEntry(k.substring(_keyPrefix.length), prefs.getInt(k) ?? 0)),
    );
  }
}
