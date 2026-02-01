enum CryptoCurrency {
  bitcoin,
  ethereum,
  cardano,
  solana,
  ripple,
  litecoin,
  dogecoin,
  polkadot,
  uniswap,
  chainlink,
}

enum CryptoExchange {
  coinbase,
  kraken,
  binance,
  kucoin,
  huobi,
  wazirx,
  coinswitch,
  zebpay,
}

enum CryptoWalletType {
  exchange,
  hardware,
  softwareHot,
  softwareCold,
}

enum CryptoTransactionType { buy, sell, transfer }

/// Represents a cryptocurrency transaction
class CryptoTransaction {
  final String id;
  final CryptoTransactionType type;
  final DateTime date;
  final double quantity;
  final double pricePerUnit; // In INR
  final double totalValue; // In INR
  final String? exchangeName;
  final String? walletAddress;
  final double? transactionFee;
  final String? notes;

  CryptoTransaction({
    required this.id,
    required this.type,
    required this.date,
    required this.quantity,
    required this.pricePerUnit,
    required this.totalValue,
    this.exchangeName,
    this.walletAddress,
    this.transactionFee,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.index,
      'date': date.toIso8601String(),
      'quantity': quantity,
      'pricePerUnit': pricePerUnit,
      'totalValue': totalValue,
      'exchangeName': exchangeName,
      'walletAddress': walletAddress,
      'transactionFee': transactionFee,
      'notes': notes,
    };
  }

  factory CryptoTransaction.fromMap(Map<String, dynamic> map) {
    return CryptoTransaction(
      id: map['id'],
      type: CryptoTransactionType.values[map['type'] as int],
      date: DateTime.parse(map['date']),
      quantity: (map['quantity'] as num).toDouble(),
      pricePerUnit: (map['pricePerUnit'] as num).toDouble(),
      totalValue: (map['totalValue'] as num).toDouble(),
      exchangeName: map['exchangeName'] as String?,
      walletAddress: map['walletAddress'] as String?,
      transactionFee: map['transactionFee'] as double?,
      notes: map['notes'] as String?,
    );
  }
}

/// Core Cryptocurrency model
class Cryptocurrency {
  final String id;
  final String name; // e.g., "Bitcoin", "Ethereum"
  final CryptoCurrency cryptoType;
  final String symbol; // e.g., "BTC", "ETH"
  final String? iconUrl; // URL to crypto icon

  // Holding details
  final double totalQuantity; // Total coins/tokens held
  final double averageBuyPrice; // Weighted average in INR
  final double totalInvested; // Total INR invested
  final double currentPrice; // Current price per coin in INR
  final DateTime lastPriceUpdate;

  // Transaction history
  final List<CryptoTransaction> transactions;

  // Wallet information
  final CryptoWalletType walletType;
  final String walletAddress; // Public address or exchange account
  final CryptoExchange? exchange; // If held on exchange
  final String? exchangeAccount; // Account ID on exchange

  // Account linking (optional)
  final String? linkedAccountId;
  final String? linkedAccountName;

  // Metadata
  final DateTime createdDate;
  final String? notes;
  final Map<String, dynamic>? metadata;

  Cryptocurrency({
    required this.id,
    required this.name,
    required this.cryptoType,
    required this.symbol,
    this.iconUrl,
    required this.totalQuantity,
    required this.averageBuyPrice,
    required this.totalInvested,
    required this.currentPrice,
    required this.lastPriceUpdate,
    required this.transactions,
    required this.walletType,
    required this.walletAddress,
    this.exchange,
    this.exchangeAccount,
    this.linkedAccountId,
    this.linkedAccountName,
    required this.createdDate,
    this.notes,
    this.metadata,
  });

  /// Current market value of holdings
  double get currentValue => totalQuantity * currentPrice;

  /// Gain/Loss in INR
  double get gainLoss => currentValue - totalInvested;

  /// Gain/Loss percentage
  double get gainLossPercent =>
      totalInvested > 0 ? (gainLoss / totalInvested) * 100 : 0;

  /// Price change since average buy price
  double get priceChangeFromBuy => currentPrice - averageBuyPrice;

  /// Price change percentage from average buy
  double get priceChangePercent =>
      averageBuyPrice > 0 ? (priceChangeFromBuy / averageBuyPrice) * 100 : 0;

  /// Buy transactions only
  List<CryptoTransaction> get buyTransactions =>
      transactions.where((t) => t.type == CryptoTransactionType.buy).toList();

  /// Sell transactions only
  List<CryptoTransaction> get sellTransactions =>
      transactions.where((t) => t.type == CryptoTransactionType.sell).toList();

  /// Last buy transaction
  CryptoTransaction? get lastBuyTransaction {
    final buys = buyTransactions;
    if (buys.isEmpty) return null;
    buys.sort((a, b) => b.date.compareTo(a.date));
    return buys.first;
  }

  /// Total fees paid
  double get totalFeesPaid =>
      transactions.fold(0.0, (sum, t) => sum + (t.transactionFee ?? 0));

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'cryptoType': cryptoType.index,
      'symbol': symbol,
      'iconUrl': iconUrl,
      'totalQuantity': totalQuantity,
      'averageBuyPrice': averageBuyPrice,
      'totalInvested': totalInvested,
      'currentPrice': currentPrice,
      'lastPriceUpdate': lastPriceUpdate.toIso8601String(),
      'transactions': transactions.map((t) => t.toMap()).toList(),
      'walletType': walletType.index,
      'walletAddress': walletAddress,
      'exchange': exchange?.index,
      'exchangeAccount': exchangeAccount,
      'linkedAccountId': linkedAccountId,
      'linkedAccountName': linkedAccountName,
      'createdDate': createdDate.toIso8601String(),
      'notes': notes,
      'metadata': metadata,
    };
  }

  factory Cryptocurrency.fromMap(Map<String, dynamic> map) {
    return Cryptocurrency(
      id: map['id'],
      name: map['name'],
      cryptoType: CryptoCurrency.values[map['cryptoType'] as int],
      symbol: map['symbol'],
      iconUrl: map['iconUrl'] as String?,
      totalQuantity: (map['totalQuantity'] as num).toDouble(),
      averageBuyPrice: (map['averageBuyPrice'] as num).toDouble(),
      totalInvested: (map['totalInvested'] as num).toDouble(),
      currentPrice: (map['currentPrice'] as num).toDouble(),
      lastPriceUpdate: DateTime.parse(map['lastPriceUpdate']),
      transactions: (map['transactions'] as List?)
              ?.map((t) => CryptoTransaction.fromMap(t as Map<String, dynamic>))
              .toList() ??
          [],
      walletType: CryptoWalletType.values[map['walletType'] as int],
      walletAddress: map['walletAddress'],
      exchange: map['exchange'] != null
          ? CryptoExchange.values[map['exchange'] as int]
          : null,
      exchangeAccount: map['exchangeAccount'] as String?,
      linkedAccountId: map['linkedAccountId'] as String?,
      linkedAccountName: map['linkedAccountName'] as String?,
      createdDate: DateTime.parse(map['createdDate']),
      notes: map['notes'] as String?,
      metadata: map['metadata'] as Map<String, dynamic>?,
    );
  }

  Cryptocurrency copyWith({
    String? id,
    String? name,
    CryptoCurrency? cryptoType,
    String? symbol,
    String? iconUrl,
    double? totalQuantity,
    double? averageBuyPrice,
    double? totalInvested,
    double? currentPrice,
    DateTime? lastPriceUpdate,
    List<CryptoTransaction>? transactions,
    CryptoWalletType? walletType,
    String? walletAddress,
    CryptoExchange? exchange,
    String? exchangeAccount,
    String? linkedAccountId,
    String? linkedAccountName,
    DateTime? createdDate,
    String? notes,
    Map<String, dynamic>? metadata,
  }) {
    return Cryptocurrency(
      id: id ?? this.id,
      name: name ?? this.name,
      cryptoType: cryptoType ?? this.cryptoType,
      symbol: symbol ?? this.symbol,
      iconUrl: iconUrl ?? this.iconUrl,
      totalQuantity: totalQuantity ?? this.totalQuantity,
      averageBuyPrice: averageBuyPrice ?? this.averageBuyPrice,
      totalInvested: totalInvested ?? this.totalInvested,
      currentPrice: currentPrice ?? this.currentPrice,
      lastPriceUpdate: lastPriceUpdate ?? this.lastPriceUpdate,
      transactions: transactions ?? this.transactions,
      walletType: walletType ?? this.walletType,
      walletAddress: walletAddress ?? this.walletAddress,
      exchange: exchange ?? this.exchange,
      exchangeAccount: exchangeAccount ?? this.exchangeAccount,
      linkedAccountId: linkedAccountId ?? this.linkedAccountId,
      linkedAccountName: linkedAccountName ?? this.linkedAccountName,
      createdDate: createdDate ?? this.createdDate,
      notes: notes ?? this.notes,
      metadata: metadata ?? this.metadata,
    );
  }

  String getCryptoLabel() {
    switch (cryptoType) {
      case CryptoCurrency.bitcoin:
        return 'Bitcoin';
      case CryptoCurrency.ethereum:
        return 'Ethereum';
      case CryptoCurrency.cardano:
        return 'Cardano';
      case CryptoCurrency.solana:
        return 'Solana';
      case CryptoCurrency.ripple:
        return 'Ripple (XRP)';
      case CryptoCurrency.litecoin:
        return 'Litecoin';
      case CryptoCurrency.dogecoin:
        return 'Dogecoin';
      case CryptoCurrency.polkadot:
        return 'Polkadot';
      case CryptoCurrency.uniswap:
        return 'Uniswap';
      case CryptoCurrency.chainlink:
        return 'Chainlink';
    }
  }

  String getExchangeLabel() {
    switch (exchange) {
      case CryptoExchange.coinbase:
        return 'Coinbase';
      case CryptoExchange.kraken:
        return 'Kraken';
      case CryptoExchange.binance:
        return 'Binance';
      case CryptoExchange.kucoin:
        return 'KuCoin';
      case CryptoExchange.huobi:
        return 'Huobi';
      case CryptoExchange.wazirx:
        return 'WazirX';
      case CryptoExchange.coinswitch:
        return 'CoinSwitch';
      case CryptoExchange.zebpay:
        return 'ZebPay';
      case null:
        return 'Self-Custody';
    }
  }

  String getWalletTypeLabel() {
    switch (walletType) {
      case CryptoWalletType.exchange:
        return 'Exchange Account';
      case CryptoWalletType.hardware:
        return 'Hardware Wallet';
      case CryptoWalletType.softwareHot:
        return 'Hot Wallet';
      case CryptoWalletType.softwareCold:
        return 'Cold Storage';
    }
  }
}
