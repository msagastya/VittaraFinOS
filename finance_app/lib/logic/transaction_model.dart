import 'package:vittara_fin_os/utils/id_generator.dart';

enum TransactionType {
  transfer,
  cashback,
  lending,
  borrowing,
  investment,
  expense,
  income,
}

class Transaction {
  final String id;
  final TransactionType type;
  final String description;
  final DateTime dateTime;
  final double amount;

  // For transfers
  final String? sourceAccountId;
  final String? sourceAccountName;
  final String? destinationAccountId;
  final String? destinationAccountName;
  final double? charges; // Extra charges deducted but not credited anywhere
  final String? paymentAppName;
  final double? appWalletAmount; // How much used from app wallet

  // For cashback
  final double? cashbackAmount;
  final String? cashbackAccountId;
  final String? cashbackAccountName;

  // Metadata
  final Map<String, dynamic>? metadata;

  Transaction({
    required this.id,
    required this.type,
    required this.description,
    required this.dateTime,
    required this.amount,
    this.sourceAccountId,
    this.sourceAccountName,
    this.destinationAccountId,
    this.destinationAccountName,
    this.charges,
    this.paymentAppName,
    this.appWalletAmount,
    this.cashbackAmount,
    this.cashbackAccountId,
    this.cashbackAccountName,
    this.metadata,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.index,
      'description': description,
      'dateTime': dateTime.toIso8601String(),
      'amount': amount,
      'sourceAccountId': sourceAccountId,
      'sourceAccountName': sourceAccountName,
      'destinationAccountId': destinationAccountId,
      'destinationAccountName': destinationAccountName,
      'charges': charges,
      'paymentAppName': paymentAppName,
      'appWalletAmount': appWalletAmount,
      'cashbackAmount': cashbackAmount,
      'cashbackAccountId': cashbackAccountId,
      'cashbackAccountName': cashbackAccountName,
      'metadata': metadata,
    };
  }

  factory Transaction.fromMap(Map<String, dynamic> map) {
    final rawType = map['type'];
    final typeIndex = rawType is int ? rawType : int.tryParse('$rawType');
    final resolvedType = (typeIndex != null &&
            typeIndex >= 0 &&
            typeIndex < TransactionType.values.length)
        ? TransactionType.values[typeIndex]
        : TransactionType.expense;

    final rawAmount = map['amount'];
    final resolvedAmount = rawAmount is num
        ? rawAmount.toDouble()
        : double.tryParse('$rawAmount') ?? 0.0;

    final rawDate = map['dateTime'];
    final resolvedDate = rawDate is String
        ? DateTime.tryParse(rawDate)
        : rawDate is DateTime
            ? rawDate
            : null;

    return Transaction(
      id: (map['id']?.toString().trim().isNotEmpty ?? false)
          ? map['id'].toString()
          : IdGenerator.next(prefix: 'txn'),
      type: resolvedType,
      description: (map['description'] as String?)?.trim().isNotEmpty == true
          ? map['description'] as String
          : 'Transaction',
      dateTime: resolvedDate ?? DateTime.now(),
      amount: resolvedAmount,
      sourceAccountId: map['sourceAccountId'],
      sourceAccountName: map['sourceAccountName'],
      destinationAccountId: map['destinationAccountId'],
      destinationAccountName: map['destinationAccountName'],
      charges: (map['charges'] as num?)?.toDouble(),
      paymentAppName: map['paymentAppName'],
      appWalletAmount: (map['appWalletAmount'] as num?)?.toDouble(),
      cashbackAmount: (map['cashbackAmount'] as num?)?.toDouble(),
      cashbackAccountId: map['cashbackAccountId'],
      cashbackAccountName: map['cashbackAccountName'],
      metadata: map['metadata'] is Map
          ? Map<String, dynamic>.from(map['metadata'] as Map)
          : null,
    );
  }

  Transaction copyWith({
    String? id,
    TransactionType? type,
    String? description,
    DateTime? dateTime,
    double? amount,
    String? sourceAccountId,
    String? sourceAccountName,
    String? destinationAccountId,
    String? destinationAccountName,
    double? charges,
    String? paymentAppName,
    double? appWalletAmount,
    double? cashbackAmount,
    String? cashbackAccountId,
    String? cashbackAccountName,
    Map<String, dynamic>? metadata,
  }) {
    return Transaction(
      id: id ?? this.id,
      type: type ?? this.type,
      description: description ?? this.description,
      dateTime: dateTime ?? this.dateTime,
      amount: amount ?? this.amount,
      sourceAccountId: sourceAccountId ?? this.sourceAccountId,
      sourceAccountName: sourceAccountName ?? this.sourceAccountName,
      destinationAccountId: destinationAccountId ?? this.destinationAccountId,
      destinationAccountName:
          destinationAccountName ?? this.destinationAccountName,
      charges: charges ?? this.charges,
      paymentAppName: paymentAppName ?? this.paymentAppName,
      appWalletAmount: appWalletAmount ?? this.appWalletAmount,
      cashbackAmount: cashbackAmount ?? this.cashbackAmount,
      cashbackAccountId: cashbackAccountId ?? this.cashbackAccountId,
      cashbackAccountName: cashbackAccountName ?? this.cashbackAccountName,
      metadata: metadata ?? this.metadata,
    );
  }

  String getTypeLabel() {
    switch (type) {
      case TransactionType.transfer:
        return 'Transfer';
      case TransactionType.cashback:
        return 'Cashback';
      case TransactionType.lending:
        return 'Lending';
      case TransactionType.borrowing:
        return 'Borrowing';
      case TransactionType.investment:
        return 'Investment';
      case TransactionType.expense:
        return 'Expense';
      case TransactionType.income:
        return 'Income';
    }
  }

  String getSummary() {
    switch (type) {
      case TransactionType.transfer:
        final flowType = metadata?['transferFlowType'] as String?;
        final base = '$sourceAccountName → $destinationAccountName';
        if (flowType == 'cash_withdrawal') {
          return 'Cash Withdrawal ($base)';
        }
        if (flowType == 'cash_deposit') {
          return 'Cash Deposit ($base)';
        }
        if (flowType == 'cash_to_cash') {
          return 'Cash Transfer ($base)';
        }
        final walletUsed = appWalletAmount ?? 0.0;
        if (walletUsed > 0) {
          return '$base (Wallet ₹${walletUsed.toStringAsFixed(2)})';
        }
        return base;
      case TransactionType.cashback:
        return 'Cashback to $cashbackAccountName';
      case TransactionType.lending:
        return 'Lent money';
      case TransactionType.borrowing:
        return 'Borrowed money';
      case TransactionType.investment:
        return 'Investment transaction';
      case TransactionType.expense:
        return description;
      case TransactionType.income:
        return description;
    }
  }
}
