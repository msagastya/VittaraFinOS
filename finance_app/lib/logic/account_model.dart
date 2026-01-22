import 'package:flutter/material.dart';

enum AccountType { savings, current, credit, payLater, wallet, investment }

class Account {
  final String id;
  final String name;
  final String bankName;
  final AccountType type;
  final double balance;
  final Color color;
  final String? creditCardNumber;
  final double? creditLimit; // For credit cards and pay later accounts

  Account({
    required this.id,
    required this.name,
    required this.bankName,
    required this.type,
    required this.balance,
    required this.color,
    this.creditCardNumber,
    this.creditLimit,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'bankName': bankName,
      'type': type.index,
      'balance': balance,
      'color': color.toARGB32(),
      'creditCardNumber': creditCardNumber,
      'creditLimit': creditLimit,
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
      creditCardNumber: map['creditCardNumber'],
      creditLimit: map['creditLimit'],
    );
  }

  Account copyWith({
    String? id,
    String? name,
    String? bankName,
    AccountType? type,
    double? balance,
    Color? color,
    String? creditCardNumber,
    double? creditLimit,
  }) {
    return Account(
      id: id ?? this.id,
      name: name ?? this.name,
      bankName: bankName ?? this.bankName,
      type: type ?? this.type,
      balance: balance ?? this.balance,
      color: color ?? this.color,
      creditCardNumber: creditCardNumber ?? this.creditCardNumber,
      creditLimit: creditLimit ?? this.creditLimit,
    );
  }
}
