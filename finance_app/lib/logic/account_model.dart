import 'package:flutter/material.dart';

// Keep new values appended to preserve backward compatibility for persisted
// enum indexes in local storage.
enum AccountType {
  savings,
  current,
  credit,
  payLater,
  wallet,
  investment,
  cash
}

class Account {
  final String id;
  final String name;
  final String bankName;
  final AccountType type;
  final double balance;
  final Color color;
  final String? creditCardNumber;
  final double? creditLimit; // For credit cards and pay later accounts
  final String currency;
  final String? institutionName;
  final DateTime createdDate;
  final Map<String, dynamic>? metadata;

  static const Object _unset = Object();

  Account({
    required this.id,
    required this.name,
    required this.bankName,
    required this.type,
    required this.balance,
    required this.color,
    this.creditCardNumber,
    this.creditLimit,
    this.currency = 'INR',
    String? institutionName,
    DateTime? createdDate,
    this.metadata,
  })  : institutionName = institutionName ?? bankName,
        createdDate = createdDate ?? DateTime.now();

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
      'currency': currency,
      'institutionName': institutionName,
      'createdDate': createdDate.toIso8601String(),
      'metadata': metadata,
    };
  }

  factory Account.fromMap(Map<String, dynamic> map) {
    final typeIndex = (map['type'] as num?)?.toInt() ?? 0;
    final safeTypeIndex =
        typeIndex >= 0 && typeIndex < AccountType.values.length ? typeIndex : 0;
    final rawCreatedDate = map['createdDate'];
    final parsedCreatedDate = rawCreatedDate is String
        ? DateTime.tryParse(rawCreatedDate) ?? DateTime.now()
        : rawCreatedDate is int
            ? DateTime.fromMillisecondsSinceEpoch(rawCreatedDate)
            : DateTime.now();
    final rawMetadata = map['metadata'];

    return Account(
      id: map['id'] as String,
      name: map['name'] as String,
      bankName: map['bankName'] as String,
      type: AccountType.values[safeTypeIndex],
      balance: (map['balance'] as num?)?.toDouble() ?? 0.0,
      color: Color((map['color'] as num?)?.toInt() ?? Colors.grey.toARGB32()),
      creditCardNumber: map['creditCardNumber'] as String?,
      creditLimit: (map['creditLimit'] as num?)?.toDouble(),
      currency: (map['currency'] as String?) ?? 'INR',
      institutionName: map['institutionName'] as String?,
      createdDate: parsedCreatedDate,
      metadata: rawMetadata is Map<String, dynamic>
          ? rawMetadata
          : rawMetadata is Map
              ? Map<String, dynamic>.from(rawMetadata)
              : null,
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
    String? currency,
    String? institutionName,
    DateTime? createdDate,
    Object? metadata = _unset,
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
      currency: currency ?? this.currency,
      institutionName: institutionName ?? this.institutionName,
      createdDate: createdDate ?? this.createdDate,
      metadata: identical(metadata, _unset)
          ? this.metadata
          : metadata as Map<String, dynamic>?,
    );
  }
}
