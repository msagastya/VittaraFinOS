import 'package:shared_preferences/shared_preferences.dart';

/// T-145: Records app-open hour histogram (24 buckets) to find peak usage hours.
/// Used by [NotificationHelpers] to schedule notifications at the best time.
class UsageTimingService {
  UsageTimingService._();
  static final UsageTimingService instance = UsageTimingService._();

  static const _histogramKey = 'app_open_hour_histogram';

  /// Records an app-open event for the current hour.
  Future<void> recordAppOpen() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_histogramKey);
    final buckets = raw != null
        ? raw.map(int.parse).toList()
        : List<int>.filled(24, 0);
    if (buckets.length != 24) {
      buckets.addAll(List<int>.filled(24 - buckets.length, 0));
    }
    final hour = DateTime.now().hour;
    buckets[hour] = (buckets[hour]) + 1;
    await prefs.setStringList(_histogramKey, buckets.map((e) => '$e').toList());
  }

  /// Returns top-2 hours by frequency. Falls back to [10, 20] if no data.
  Future<List<int>> peakHours() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_histogramKey);
    if (raw == null || raw.length != 24) return [10, 20];
    final buckets = raw.map(int.parse).toList();
    final indexed = List.generate(24, (i) => (i, buckets[i]));
    indexed.sort((a, b) => b.$2.compareTo(a.$2));
    return indexed.take(2).map((e) => e.$1).toList();
  }
}
