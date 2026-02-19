import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'contact_model.dart';

class ContactsController extends ChangeNotifier {
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

  void addContact(Contact contact) {
    // Check if contact already exists
    if (!_contacts
        .any((c) => c.name.toLowerCase() == contact.name.toLowerCase())) {
      _contacts.add(contact);
      _contacts.sort((a, b) => a.name.compareTo(b.name));
      _saveContacts();
      notifyListeners();
    }
  }

  void addOrGetContact(String name, {String? phoneNumber}) {
    final existing = _contacts.firstWhere(
      (c) => c.name.toLowerCase() == name.toLowerCase(),
      orElse: () => Contact(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        phoneNumber: phoneNumber,
        createdDate: DateTime.now(),
      ),
    );

    if (!_contacts.contains(existing)) {
      addContact(existing);
    }
  }

  void removeContact(String id) {
    _contacts.removeWhere((c) => c.id == id);
    _saveContacts();
    notifyListeners();
  }

  Contact? getContactByName(String name) {
    try {
      return _contacts
          .firstWhere((c) => c.name.toLowerCase() == name.toLowerCase());
    } catch (e) {
      return null;
    }
  }
}
