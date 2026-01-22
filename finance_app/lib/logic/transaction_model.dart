enum TransactionType { transfer, cashback, lending, borrowing, investment }

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
    return Transaction(
      id: map['id'],
      type: TransactionType.values[map['type']],
      description: map['description'],
      dateTime: DateTime.parse(map['dateTime']),
      amount: map['amount'],
      sourceAccountId: map['sourceAccountId'],
      sourceAccountName: map['sourceAccountName'],
      destinationAccountId: map['destinationAccountId'],
      destinationAccountName: map['destinationAccountName'],
      charges: map['charges'],
      paymentAppName: map['paymentAppName'],
      appWalletAmount: map['appWalletAmount'],
      cashbackAmount: map['cashbackAmount'],
      cashbackAccountId: map['cashbackAccountId'],
      cashbackAccountName: map['cashbackAccountName'],
      metadata: map['metadata'],
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
    }
  }

  String getSummary() {
    switch (type) {
      case TransactionType.transfer:
        return '$sourceAccountName → $destinationAccountName';
      case TransactionType.cashback:
        return 'Cashback to $cashbackAccountName';
      case TransactionType.lending:
        return 'Lent money';
      case TransactionType.borrowing:
        return 'Borrowed money';
      case TransactionType.investment:
        return 'Investment transaction';
    }
  }
}
