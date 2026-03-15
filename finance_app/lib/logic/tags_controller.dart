import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'tag_model.dart';

class TagsController extends ChangeNotifier {
  List<Tag> _tags = [];

  List<Tag> get tags => _tags;

  Future<void> loadTags() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('tags');

    if (jsonString != null) {
      try {
        final List<dynamic> jsonList = jsonDecode(jsonString);
        _tags = jsonList
            .map((item) => Tag.fromMap(Map<String, dynamic>.from(item)))
            .toList();
        // Sort by name
        _tags.sort((a, b) => a.name.compareTo(b.name));
      } catch (e) {
        _tags = [];
      }
    }
    notifyListeners();
  }

  Future<void> _saveTags() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(_tags.map((t) => t.toMap()).toList());
    await prefs.setString('tags', jsonString);
  }

  void addTag(Tag tag) {
    // Check if tag already exists
    if (!_tags.any((t) => t.name.toLowerCase() == tag.name.toLowerCase())) {
      _tags.add(tag);
      _tags.sort((a, b) => a.name.compareTo(b.name));
      _saveTags();
      notifyListeners();
    }
  }

  void updateTag(String id, String name) {
    final index = _tags.indexWhere((t) => t.id == id);
    if (index != -1) {
      _tags[index] = _tags[index].copyWith(name: name);
      _tags.sort((a, b) => a.name.compareTo(b.name));
      _saveTags();
      notifyListeners();
    }
  }

  void updateTagColor(String id, Color color) {
    final index = _tags.indexWhere((t) => t.id == id);
    if (index != -1) {
      _tags[index] = _tags[index].copyWith(color: color);
      _saveTags();
      notifyListeners();
    }
  }

  void removeTag(String id) {
    _tags.removeWhere((t) => t.id == id);
    _saveTags();
    notifyListeners();
  }

  Tag? getTagByName(String name) {
    return _tags
        .where((t) => t.name.toLowerCase() == name.toLowerCase())
        .firstOrNull;
  }

  Tag? getTagById(String id) {
    return _tags.where((t) => t.id == id).firstOrNull;
  }
}
