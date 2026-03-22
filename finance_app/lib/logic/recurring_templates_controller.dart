import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vittara_fin_os/logic/recurring_template_model.dart';
import 'package:vittara_fin_os/logic/recurring_pattern_detector.dart';
import 'package:vittara_fin_os/logic/transaction_model.dart';
import 'package:vittara_fin_os/utils/logger.dart';

final _recurringLogger = AppLogger();

class RecurringTemplatesController with ChangeNotifier {
  static const _prefsKey = 'recurring_templates_v1';

  List<RecurringTemplate> _templates = [];

  List<RecurringTemplate> get templates => List.unmodifiable(_templates);

  /// Templates with a due date in the next 3 days (or overdue).
  List<RecurringTemplate> get dueSoon => _templates.where((t) {
        final days = t.daysUntilDue();
        return days != null && days <= 3;
      }).toList();

  RecurringTemplatesController() {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null) return;
      final List<dynamic> list = jsonDecode(raw);
      _templates = list
          .map((e) => RecurringTemplate.fromMap(e as Map<String, dynamic>))
          .toList();
      notifyListeners();
    } catch (e) {
      _recurringLogger.warning('Failed to load recurring templates', error: e);
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _prefsKey, jsonEncode(_templates.map((t) => t.toMap()).toList()));
    } catch (e) {
      _recurringLogger.warning('Failed to save recurring templates', error: e);
    }
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

  /// Records today as the payment date for the current month.
  void markBillAsPaid(String id) {
    final idx = _templates.indexWhere((t) => t.id == id);
    if (idx < 0) return;
    _templates[idx] = _templates[idx].withPaymentRecorded();
    notifyListeners();
    _save();
  }

  /// Analyses [transactions] and returns up to [limit] suggested patterns
  /// that aren't already tracked as recurring templates.
  List<RecurringPattern> detectSuggestions(
    List<Transaction> transactions, {
    int limit = 5,
  }) {
    return RecurringPatternDetector.detect(
      transactions,
      existing: _templates,
    ).take(limit).toList();
  }

  /// Removes the payment record for the current month (undo).
  void unmarkBillAsPaid(String id) {
    final idx = _templates.indexWhere((t) => t.id == id);
    if (idx < 0) return;
    final t = _templates[idx];
    final key = RecurringTemplate.monthKey(DateTime.now());
    final updated = Map<String, String>.from(t.paymentHistory)..remove(key);
    _templates[idx] = RecurringTemplate(
      id: t.id,
      name: t.name,
      branch: t.branch,
      amount: t.amount,
      categoryId: t.categoryId,
      categoryName: t.categoryName,
      accountId: t.accountId,
      accountName: t.accountName,
      paymentType: t.paymentType,
      paymentApp: t.paymentApp,
      merchant: t.merchant,
      description: t.description,
      tags: t.tags,
      frequency: t.frequency,
      nextDueDate: t.nextDueDate,
      createdAt: t.createdAt,
      paymentHistory: updated,
    );
    notifyListeners();
    _save();
  }
}
