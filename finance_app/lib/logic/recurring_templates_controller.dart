import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vittara_fin_os/logic/recurring_template_model.dart';

class RecurringTemplatesController with ChangeNotifier {
  static const _prefsKey = 'recurring_templates_v1';

  List<RecurringTemplate> _templates = [];

  List<RecurringTemplate> get templates => List.unmodifiable(_templates);

  /// Templates with a due date in the next 3 days (or overdue).
  List<RecurringTemplate> get dueSoon => _templates
      .where((t) {
        final days = t.daysUntilDue();
        return days != null && days <= 3;
      })
      .toList();

  RecurringTemplatesController() {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null) return;
      final List<dynamic> list = jsonDecode(raw);
      _templates =
          list.map((e) => RecurringTemplate.fromMap(e as Map<String, dynamic>)).toList();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _prefsKey, jsonEncode(_templates.map((t) => t.toMap()).toList()));
    } catch (_) {}
  }

  void addTemplate(RecurringTemplate template) {
    _templates.add(template);
    notifyListeners();
    _save();
  }

  void deleteTemplate(String id) {
    _templates.removeWhere((t) => t.id == id);
    notifyListeners();
    _save();
  }

  /// After a recurring template is used, advance its due date.
  void markUsed(String id) {
    final idx = _templates.indexWhere((t) => t.id == id);
    if (idx < 0) return;
    _templates[idx] = _templates[idx].withAdvancedDueDate();
    notifyListeners();
    _save();
  }

  void updateTemplate(RecurringTemplate updated) {
    final idx = _templates.indexWhere((t) => t.id == updated.id);
    if (idx < 0) return;
    _templates[idx] = updated;
    notifyListeners();
    _save();
  }
}
