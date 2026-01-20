import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vittara_fin_os/logic/category_model.dart';

class CategoriesController with ChangeNotifier {
  late SharedPreferences _prefs;
  late List<Category> _categories;
  static const String _storageKey = 'categories';

  List<Category> get categories => _categories;
  List<Category> get defaultCats => _categories.where((cat) => !cat.isCustom).toList();
  List<Category> get customCats => _categories.where((cat) => cat.isCustom).toList();

  CategoriesController() {
    _categories = List.from(defaultCategories);
  }

  Future<void> loadCategories() async {
    _prefs = await SharedPreferences.getInstance();
    final customCategoriesJson = _prefs.getStringList(_storageKey) ?? [];

    // Start with default categories
    _categories = List.from(defaultCategories);

    // Add saved custom categories
    final customCategories = customCategoriesJson
        .map((json) => Category.fromMap(jsonDecode(json) as Map<String, dynamic>))
        .toList();

    _categories.addAll(customCategories);
    notifyListeners();
  }

  Future<void> addCategory(Category category) async {
    _categories.add(category);
    await _saveCustomCategories();
    notifyListeners();
  }

  Future<void> removeCategory(String categoryId) async {
    _categories.removeWhere((cat) => cat.id == categoryId);
    await _saveCustomCategories();
    notifyListeners();
  }

  Future<void> updateCategory(Category category) async {
    final index = _categories.indexWhere((cat) => cat.id == category.id);
    if (index >= 0) {
      _categories[index] = category;
      await _saveCustomCategories();
      notifyListeners();
    }
  }

  Future<void> _saveCustomCategories() async {
    final customCats = _categories.where((cat) => cat.isCustom).toList();
    final customCategoriesJson =
        customCats.map((category) => jsonEncode(category.toMap())).toList();
    await _prefs.setStringList(_storageKey, customCategoriesJson);
  }

  void reorderCategories(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final category = _categories.removeAt(oldIndex);
    _categories.insert(newIndex, category);
    notifyListeners();
  }

  Category? getCategoryById(String categoryId) {
    try {
      return _categories.firstWhere((cat) => cat.id == categoryId);
    } catch (e) {
      return null;
    }
  }
}
