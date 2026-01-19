import 'package:flutter/material.dart';

enum AccountType { savings, current, credit, payLater, wallet, investment }

class Account {
  final String id;
  final String name;
  final String bankName;
  final AccountType type;
  final double balance;
  final Color color;

  Account({
    required this.id,
    required this.name,
    required this.bankName,
    required this.type,
    required this.balance,
    required this.color,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'bankName': bankName,
      'type': type.index,
      'balance': balance,
      'color': color.toARGB32(),
    };
  }

  factory Account.fromMap(Map<String, dynamic> map) {
    return Account(
      id: map['id'],
      name: map['name'],
      bankName: map['bankName'],
      type: AccountType.values[map['type']],
      balance: map['balance'],
      color: Color(map['color']),
    );
  }
}
