import 'package:flutter/material.dart';

enum InvestmentType {
  stocks,
  mutualFund,
  fixedDeposit,
  recurringDeposit,
  bonds,
  nationalSavingsScheme,
  digitalGold,
  pensionSchemes,
  cryptocurrency,
  futuresOptions,
  forexCurrency,
  commodities,
}

class Investment {
  final String id;
  final String name;
  final InvestmentType type;
  final double amount;
  final Color color;
  final String? notes;
  final String? broker;
  final Map<String, dynamic>? metadata;

  Investment({
    required this.id,
    required this.name,
    required this.type,
    required this.amount,
    required this.color,
    this.notes,
    this.broker,
    this.metadata,
  });

  String getTypeLabel() {
    switch (type) {
      case InvestmentType.stocks:
        return 'Stocks';
      case InvestmentType.mutualFund:
        return 'Mutual Fund';
      case InvestmentType.fixedDeposit:
        return 'Fixed Deposit (FD)';
      case InvestmentType.recurringDeposit:
        return 'Recurring Deposit (RD)';
      case InvestmentType.bonds:
        return 'Bonds';
      case InvestmentType.nationalSavingsScheme:
        return 'National Savings Scheme';
      case InvestmentType.digitalGold:
        return 'Digital Gold';
      case InvestmentType.pensionSchemes:
        return 'Pension Schemes';
      case InvestmentType.cryptocurrency:
        return 'Cryptocurrency';
      case InvestmentType.futuresOptions:
        return 'Futures and Options';
      case InvestmentType.forexCurrency:
        return 'Forex/Currency';
      case InvestmentType.commodities:
        return 'Commodities';
    }
  }

  Color getTypeColor() {
    switch (type) {
      case InvestmentType.stocks:
        return const Color(0xFF00B050);
      case InvestmentType.mutualFund:
        return const Color(0xFF0066CC);
      case InvestmentType.fixedDeposit:
        return const Color(0xFFFF6B00);
      case InvestmentType.recurringDeposit:
        return const Color(0xFFD600CC);
      case InvestmentType.bonds:
        return const Color(0xFF00A6CC);
      case InvestmentType.nationalSavingsScheme:
        return const Color(0xFFEC6100);
      case InvestmentType.digitalGold:
        return const Color(0xFFFFB81C);
      case InvestmentType.pensionSchemes:
        return const Color(0xFF9B59B6);
      case InvestmentType.cryptocurrency:
        return const Color(0xFFF7931A);
      case InvestmentType.futuresOptions:
        return const Color(0xFF1ABC9C);
      case InvestmentType.forexCurrency:
        return const Color(0xFF34495E);
      case InvestmentType.commodities:
        return const Color(0xFF8B4513);
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type.index,
      'amount': amount,
      'color': color.toARGB32(),
      'notes': notes,
      'broker': broker,
      'metadata': metadata,
    };
  }

  factory Investment.fromMap(Map<String, dynamic> map) {
    return Investment(
      id: map['id'],
      name: map['name'],
      type: InvestmentType.values[map['type']],
      amount: map['amount'],
      color: Color(map['color']),
      notes: map['notes'],
      broker: map['broker'],
      metadata: map['metadata'] != null ? Map<String, dynamic>.from(map['metadata']) : null,
    );
  }
}
