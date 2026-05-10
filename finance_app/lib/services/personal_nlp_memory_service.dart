import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class PersonalNlpMemoryService {
  PersonalNlpMemoryService._();

  static const _interactionsKey = 'personal_nlp_interactions_v1';
  static const _preferencesKey = 'personal_nlp_preferences_v1';
  static const _merchantCategoryKey = 'personal_nlp_merchant_category_v1';
  static const int maxBytes = 10 * 1024 * 1024;

  static Future<void> recordInteraction({
    required String source,
    required String utterance,
    required String intent,
    required bool executed,
    double? confidence,
    Map<String, dynamic> fields = const {},
  }) async {
    final cleanUtterance = utterance.trim();
    if (cleanUtterance.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final entries = prefs.getStringList(_interactionsKey) ?? <String>[];
    entries.add(jsonEncode({
      'source': source,
      'utterance': cleanUtterance,
      'intent': intent,
      'executed': executed,
      'confidence': confidence,
      'fields': _safeFields(fields),
      'createdAt': DateTime.now().toIso8601String(),
    }));

    await prefs.setStringList(_interactionsKey, _trimToBudget(entries));
  }

  static Future<Map<String, dynamic>> preferences() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_preferencesKey);
    if (raw == null) return _defaultPreferences();
    try {
      return {
        ..._defaultPreferences(),
        ...Map<String, dynamic>.from(jsonDecode(raw) as Map),
      };
    } catch (_) {
      return _defaultPreferences();
    }
  }

  static Future<void> setPreference(String key, Object value) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await preferences();
    current[key] = value;
    await prefs.setString(_preferencesKey, jsonEncode(current));
  }

  static Future<void> learnMerchantCategory({
    required String merchant,
    required String category,
  }) async {
    final cleanMerchant = merchant.trim().toLowerCase();
    final cleanCategory = category.trim();
    if (cleanMerchant.isEmpty || cleanCategory.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_merchantCategoryKey);
    final map = raw == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(jsonDecode(raw) as Map);
    map[cleanMerchant] = cleanCategory;
    await prefs.setString(_merchantCategoryKey, jsonEncode(map));
  }

  static Map<String, dynamic> _defaultPreferences() => {
        'askBeforeExecute': true,
        'minimumAutoExecuteConfidence': 0.92,
        'defaultRecurringFrequency': 'monthly',
        'offlineOnly': true,
      };

  static Map<String, dynamic> _safeFields(Map<String, dynamic> fields) {
    final allowed = <String, dynamic>{};
    for (final key in const [
      'amount',
      'category',
      'merchant',
      'account',
      'toAccount',
      'date',
      'investmentType',
      'nlpConfidence',
      'nlpInterpretation',
    ]) {
      final value = fields[key];
      if (value == null) continue;
      allowed[key] = value is DateTime ? value.toIso8601String() : value;
    }
    return allowed;
  }

  static List<String> _trimToBudget(List<String> entries) {
    var total = utf8.encode(entries.join()).length;
    while (entries.length > 1 && total > maxBytes) {
      total -= utf8.encode(entries.removeAt(0)).length;
    }
    return entries;
  }
}
