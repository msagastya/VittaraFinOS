import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vittara_fin_os/logic/category_model.dart';

class CategoriesController with ChangeNotifier {
  late SharedPreferences _prefs;
  late List<Category> _categories;
  static const String _customCategoriesStorageKey = 'categories';
  static const String _hiddenDefaultCategoryIdsStorageKey =
      'categories_hidden_default_ids';
  static const String _defaultCategoryOverridesStorageKey =
      'categories_default_overrides';

  List<Category> get categories => _categories;
  List<Category> get defaultCats =>
      _categories.where((cat) => !cat.isCustom).toList();
  List<Category> get customCats =>
      _categories.where((cat) => cat.isCustom).toList();

  /// Returns the category with [id], or null if not found.
  Category? getCategoryById(String id) =>
      _categories.where((c) => c.id == id).cast<Category?>().firstOrNull;

  CategoriesController() {
    _categories = List.from(defaultCategories);
  }

  Future<void> loadCategories() async {
    _prefs = await SharedPreferences.getInstance();
    final hiddenDefaultIds =
        (_prefs.getStringList(_hiddenDefaultCategoryIdsStorageKey) ?? [])
            .toSet();
    final defaultOverrides = _loadDefaultCategoryOverrides();

    _categories = [];
    for (final defaultCategory in defaultCategories) {
      if (hiddenDefaultIds.contains(defaultCategory.id)) continue;
      _categories.add(defaultOverrides[defaultCategory.id] ?? defaultCategory);
    }

    final customCategoriesJson =
        _prefs.getStringList(_customCategoriesStorageKey) ?? [];
    final customCategories = customCategoriesJson
        .map((json) =>
            Category.fromMap(jsonDecode(json) as Map<String, dynamic>))
        .toList();

    _categories.addAll(customCategories.where((cat) => cat.isCustom));
    notifyListeners();
  }

  Future<void> addCategory(Category category) async {
    final existingIndex =
        _categories.indexWhere((cat) => cat.id == category.id);
    if (existingIndex >= 0) {
      _categories[existingIndex] = category;
    } else {
      _categories.add(category);
    }

    if (category.isCustom) {
      await _saveCustomCategories();
    } else {
      await _persistDefaultCategoryChange(category);
    }
    notifyListeners();
  }

  Future<void> removeCategory(String categoryId) async {
    final removeIndex = _categories.indexWhere((cat) => cat.id == categoryId);
    if (removeIndex < 0) return;

    final removed = _categories.removeAt(removeIndex);
    if (removed.isCustom) {
      await _saveCustomCategories();
    } else {
      final hiddenDefaultIds =
          (_prefs.getStringList(_hiddenDefaultCategoryIdsStorageKey) ?? [])
              .toSet();
      hiddenDefaultIds.add(categoryId);
      await _prefs.setStringList(
        _hiddenDefaultCategoryIdsStorageKey,
        hiddenDefaultIds.toList(),
      );

      final defaultOverrides = _loadDefaultCategoryOverrides();
      defaultOverrides.remove(categoryId);
      await _saveDefaultCategoryOverrides(defaultOverrides);
    }
    notifyListeners();
  }

  Future<void> updateCategory(Category category) async {
    final index = _categories.indexWhere((cat) => cat.id == category.id);
    if (index >= 0) {
      _categories[index] = category;

      if (category.isCustom) {
        await _saveCustomCategories();
      } else {
        await _persistDefaultCategoryChange(category);
      }

      notifyListeners();
    }
  }

  Future<void> _saveCustomCategories() async {
    final customCats = _categories.where((cat) => cat.isCustom).toList();
    final customCategoriesJson =
        customCats.map((category) => jsonEncode(category.toMap())).toList();
    await _prefs.setStringList(
      _customCategoriesStorageKey,
      customCategoriesJson,
    );
  }

  Map<String, Category> _loadDefaultCategoryOverrides() {
    final overridesJson =
        _prefs.getStringList(_defaultCategoryOverridesStorageKey) ?? [];
    final map = <String, Category>{};

    for (final rawJson in overridesJson) {
      try {
        final rawMap = jsonDecode(rawJson);
        if (rawMap is Map) {
          final category = Category.fromMap(Map<String, dynamic>.from(rawMap));
          map[category.id] = Category(
            id: category.id,
            name: category.name,
            color: category.color,
            icon: category.icon,
            isCustom: false,
            description: category.description,
          );
        }
      } catch (_) {
        // Ignore malformed override rows and continue loading remaining data.
      }
    }

    return map;
  }

  Future<void> _saveDefaultCategoryOverrides(
      Map<String, Category> overrides) async {
    final overridesJson = overrides.values
        .map((category) => jsonEncode(category.toMap()))
        .toList();
    await _prefs.setStringList(
        _defaultCategoryOverridesStorageKey, overridesJson);
  }

  Future<void> _persistDefaultCategoryChange(Category category) async {
    final hiddenDefaultIds =
        (_prefs.getStringList(_hiddenDefaultCategoryIdsStorageKey) ?? [])
            .toSet();
    hiddenDefaultIds.remove(category.id);
    await _prefs.setStringList(
      _hiddenDefaultCategoryIdsStorageKey,
      hiddenDefaultIds.toList(),
    );

    final defaultCategory = _getDefaultCategoryById(category.id);
    if (defaultCategory == null) return;

    final defaultOverrides = _loadDefaultCategoryOverrides();
    if (_matchesDefaultCategory(category, defaultCategory)) {
      defaultOverrides.remove(category.id);
    } else {
      defaultOverrides[category.id] = Category(
        id: category.id,
        name: category.name,
        color: category.color,
        icon: category.icon,
        isCustom: false,
        description: category.description,
      );
    }

    await _saveDefaultCategoryOverrides(defaultOverrides);
  }

  Category? _getDefaultCategoryById(String id) {
    return defaultCategories.where((cat) => cat.id == id).firstOrNull;
  }

  bool _matchesDefaultCategory(Category current, Category originalDefault) {
    return current.id == originalDefault.id &&
        current.name == originalDefault.name &&
        current.color.toARGB32() == originalDefault.color.toARGB32() &&
        current.icon.codePoint == originalDefault.icon.codePoint &&
        current.description == originalDefault.description;
  }

  void reorderCategories(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final category = _categories.removeAt(oldIndex);
    _categories.insert(newIndex, category);
    notifyListeners();
  }

}
