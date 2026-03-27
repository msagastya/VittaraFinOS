import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:vittara_fin_os/logic/contact_model.dart';

class ContactsController with ChangeNotifier {
  List<Contact> _contacts = [];

  List<Contact> get contacts => _contacts;

  Future<void> loadContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('contacts');

    if (jsonString != null) {
      try {
        final List<dynamic> jsonList = jsonDecode(jsonString);
        _contacts = jsonList
            .map((item) => Contact.fromMap(Map<String, dynamic>.from(item)))
            .toList();
        // Sort by name
        _contacts.sort((a, b) => a.name.compareTo(b.name));
      } catch (e) {
        _contacts = [];
      }
    }
    notifyListeners();
  }

  Future<void> _saveContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(_contacts.map((c) => c.toMap()).toList());
    await prefs.setString('contacts', jsonString);
  }

  Future<void> addContact(Contact contact) async {
    // Check if contact already exists
    if (!_contacts
        .any((c) => c.name.toLowerCase() == contact.name.toLowerCase())) {
      _contacts.add(contact);
      _contacts.sort((a, b) => a.name.compareTo(b.name));
      await _saveContacts();
      notifyListeners();
    }
  }

  void addOrGetContact(String name, {String? phoneNumber}) {
    final alreadyExists =
        _contacts.any((c) => c.name.toLowerCase() == name.toLowerCase());
    if (!alreadyExists) {
      addContact(Contact(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        phoneNumber: phoneNumber,
        createdDate: DateTime.now(),
      ));
    }
  }

  Future<void> removeContact(String id) async {
    _contacts.removeWhere((c) => c.id == id);
    await _saveContacts();
    notifyListeners();
  }

  Future<void> updateContact(Contact updated) async {
    final index = _contacts.indexWhere((c) => c.id == updated.id);
    if (index != -1) {
      _contacts[index] = updated;
      _contacts.sort((a, b) => a.name.compareTo(b.name));
      await _saveContacts();
      notifyListeners();
    }
  }

  Contact? getContactByName(String name) {
    return _contacts
        .where((c) => c.name.toLowerCase() == name.toLowerCase())
        .firstOrNull;
  }
}
