enum StockTransactionType { buy, sell, dividend }

class StockTransaction {
  final String id;
  final String investmentId;
  final StockTransactionType type;
  final double qty; // For buy/sell
  final double pricePerShare;
  final DateTime transactionDate;
  final double totalAmount; // qty * pricePerShare
  final double? extraCharges; // For buy transactions
  final String? linkedAccountId; // Account linked to this transaction
  final String? linkedAccountName; // For display
  final double? dividendAmount; // For dividend transactions
  final Map<String, dynamic>? metadata;

  StockTransaction({
    required this.id,
    required this.investmentId,
    required this.type,
    required this.qty,
    required this.pricePerShare,
    required this.transactionDate,
    required this.totalAmount,
    this.extraCharges,
    this.linkedAccountId,
    this.linkedAccountName,
    this.dividendAmount,
    this.metadata,
  });

  double get netAmount {
    if (type == StockTransactionType.buy) {
      return totalAmount + (extraCharges ?? 0.0);
    }
    return totalAmount;
  }

  String getTransactionLabel() {
    switch (type) {
      case StockTransactionType.buy:
        return 'Bought $qty shares @ ₹$pricePerShare';
      case StockTransactionType.sell:
        return 'Sold $qty shares @ ₹$pricePerShare';
      case StockTransactionType.dividend:
        return 'Dividend Received';
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'investmentId': investmentId,
      'type': type.index,
      'qty': qty,
      'pricePerShare': pricePerShare,
      'transactionDate': transactionDate.toIso8601String(),
      'totalAmount': totalAmount,
      'extraCharges': extraCharges,
      'linkedAccountId': linkedAccountId,
      'linkedAccountName': linkedAccountName,
      'dividendAmount': dividendAmount,
      'metadata': metadata,
    };
  }

  factory StockTransaction.fromMap(Map<String, dynamic> map) {
    return StockTransaction(
      id: map['id'],
      investmentId: map['investmentId'],
      type: StockTransactionType.values[map['type'] as int],
      qty: map['qty'] as double,
      pricePerShare: map['pricePerShare'] as double,
      transactionDate: DateTime.parse(map['transactionDate'] as String),
      totalAmount: map['totalAmount'] as double,
      extraCharges: map['extraCharges'] as double?,
      linkedAccountId: map['linkedAccountId'] as String?,
      linkedAccountName: map['linkedAccountName'] as String?,
      dividendAmount: map['dividendAmount'] as double?,
      metadata: map['metadata'] as Map<String, dynamic>?,
    );
  }
}

class SIPRecord {
  final String id;
  final String investmentId;
  final double amountOrQty; // Amount in rupees or number of shares
  final bool isFixedAmount; // true = amount, false = qty
  final String frequency; // Weekly, Monthly, Quarterly, Yearly
  final DateTime startDate;
  final DateTime? endDate;
  final String? linkedAccountId;
  final String? linkedAccountName;
  final double? extraCharges; // Optional charges per SIP installment
  final bool isActive;
  final List<String> transactionIds; // IDs of SIP transactions executed
  final Map<String, dynamic>? metadata;

  SIPRecord({
    required this.id,
    required this.investmentId,
    required this.amountOrQty,
    required this.isFixedAmount,
    required this.frequency,
    required this.startDate,
    this.endDate,
    this.linkedAccountId,
    this.linkedAccountName,
    this.extraCharges,
    required this.isActive,
    required this.transactionIds,
    this.metadata,
  });

  int get totalExecutedTransactions => transactionIds.length;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'investmentId': investmentId,
      'amountOrQty': amountOrQty,
      'isFixedAmount': isFixedAmount,
      'frequency': frequency,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'linkedAccountId': linkedAccountId,
      'linkedAccountName': linkedAccountName,
      'extraCharges': extraCharges,
      'isActive': isActive,
      'transactionIds': transactionIds,
      'metadata': metadata,
    };
  }

  factory SIPRecord.fromMap(Map<String, dynamic> map) {
    return SIPRecord(
      id: map['id'],
      investmentId: map['investmentId'],
      amountOrQty: map['amountOrQty'] as double,
      isFixedAmount: map['isFixedAmount'] as bool,
      frequency: map['frequency'] as String,
      startDate: DateTime.parse(map['startDate'] as String),
      endDate: map['endDate'] != null
          ? DateTime.parse(map['endDate'] as String)
          : null,
      linkedAccountId: map['linkedAccountId'] as String?,
      linkedAccountName: map['linkedAccountName'] as String?,
      extraCharges: map['extraCharges'] as double?,
      isActive: map['isActive'] as bool,
      transactionIds: List<String>.from(map['transactionIds'] as List? ?? []),
      metadata: map['metadata'] as Map<String, dynamic>?,
    );
  }
}
