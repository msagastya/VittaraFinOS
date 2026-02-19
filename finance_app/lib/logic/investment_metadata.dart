import 'package:flutter/material.dart';
import 'package:vittara_fin_os/logic/fd_renewal_cycle.dart';

/// Base metadata interface for all investments
abstract class InvestmentMetadata {
  Map<String, dynamic> toMap();

  static InvestmentMetadata? fromMap(
      Map<String, dynamic> map, String investmentType) {
    switch (investmentType) {
      case 'fixedDeposit':
        return FDMetadata.fromMap(map);
      case 'recurringDeposit':
        return RDMetadata.fromMap(map);
      case 'stocks':
        return StockMetadata.fromMap(map);
      case 'mutualFund':
        return MutualFundMetadata.fromMap(map);
      case 'bonds':
        return BondMetadata.fromMap(map);
      case 'digitalGold':
        return DigitalGoldMetadata.fromMap(map);
      case 'cryptocurrency':
        return CryptoMetadata.fromMap(map);
      default:
        return null;
    }
  }
}

/// Fixed Deposit metadata
class FDMetadata implements InvestmentMetadata {
  final Map<String, dynamic> fdData;
  final String linkedAccountId;
  final String linkedAccountName;
  final DateTime maturityDate;
  final DateTime investmentDate;
  final DateTime createdDate;
  final double estimatedAccruedValue;
  final double maturityValue;
  final double? realizedValue;
  final double interestRate;
  final int tenureMonths;
  final String compoundingFrequency;
  final String payoutFrequency;
  final bool isCumulative;
  final double originalPrincipal;
  final bool debitedFromAccount;
  final List<FDRenewalCycle>? renewalCycles;
  final int? currentCycleIndex;
  final DateTime? lastRenewalDate;
  final DateTime? withdrawalDate;
  final double? withdrawalAmount;
  final bool isWithdrawn;

  FDMetadata({
    required this.fdData,
    required this.linkedAccountId,
    required this.linkedAccountName,
    required this.maturityDate,
    required this.investmentDate,
    required this.createdDate,
    required this.estimatedAccruedValue,
    required this.maturityValue,
    this.realizedValue,
    required this.interestRate,
    required this.tenureMonths,
    required this.compoundingFrequency,
    required this.payoutFrequency,
    required this.isCumulative,
    required this.originalPrincipal,
    required this.debitedFromAccount,
    this.renewalCycles,
    this.currentCycleIndex,
    this.lastRenewalDate,
    this.withdrawalDate,
    this.withdrawalAmount,
    this.isWithdrawn = false,
  });

  @override
  Map<String, dynamic> toMap() {
    return {
      'fdData': fdData,
      'linkedAccountId': linkedAccountId,
      'linkedAccountName': linkedAccountName,
      'maturityDate': maturityDate.toIso8601String(),
      'investmentDate': investmentDate.toIso8601String(),
      'createdDate': createdDate.toIso8601String(),
      'estimatedAccruedValue': estimatedAccruedValue,
      'maturityValue': maturityValue,
      'realizedValue': realizedValue,
      'interestRate': interestRate,
      'tenureMonths': tenureMonths,
      'compoundingFrequency': compoundingFrequency,
      'payoutFrequency': payoutFrequency,
      'isCumulative': isCumulative,
      'originalPrincipal': originalPrincipal,
      'debitedFromAccount': debitedFromAccount,
      if (renewalCycles != null)
        'renewalCycles': renewalCycles!.map((c) => c.toMap()).toList(),
      if (currentCycleIndex != null) 'currentCycleIndex': currentCycleIndex,
      if (lastRenewalDate != null)
        'lastRenewalDate': lastRenewalDate!.toIso8601String(),
      if (withdrawalDate != null)
        'withdrawalDate': withdrawalDate!.toIso8601String(),
      if (withdrawalAmount != null) 'withdrawalAmount': withdrawalAmount,
      'isWithdrawn': isWithdrawn,
    };
  }

  factory FDMetadata.fromMap(Map<String, dynamic> map) {
    List<FDRenewalCycle>? cycles;
    final cyclesData = map['renewalCycles'];
    if (cyclesData is List) {
      cycles = [];
      for (var c in cyclesData) {
        try {
          if (c is Map<String, dynamic>) {
            cycles.add(FDRenewalCycle.fromMap(c));
          } else if (c is Map) {
            cycles.add(FDRenewalCycle.fromMap(Map<String, dynamic>.from(c)));
          }
        } catch (e) {
          debugPrint('Error parsing renewal cycle: $e');
        }
      }
    }

    return FDMetadata(
      fdData: Map<String, dynamic>.from(map['fdData'] ?? {}),
      linkedAccountId: map['linkedAccountId'] as String,
      linkedAccountName: map['linkedAccountName'] as String,
      maturityDate: DateTime.parse(map['maturityDate'] as String),
      investmentDate: DateTime.parse(map['investmentDate'] as String),
      createdDate: DateTime.parse(map['createdDate'] as String),
      estimatedAccruedValue: (map['estimatedAccruedValue'] as num).toDouble(),
      maturityValue: (map['maturityValue'] as num).toDouble(),
      realizedValue: map['realizedValue'] != null
          ? (map['realizedValue'] as num).toDouble()
          : null,
      interestRate: (map['interestRate'] as num).toDouble(),
      tenureMonths: map['tenureMonths'] as int,
      compoundingFrequency: map['compoundingFrequency'] as String,
      payoutFrequency: map['payoutFrequency'] as String,
      isCumulative: map['isCumulative'] as bool,
      originalPrincipal: (map['originalPrincipal'] as num).toDouble(),
      debitedFromAccount: map['debitedFromAccount'] as bool? ?? false,
      renewalCycles: cycles,
      currentCycleIndex: map['currentCycleIndex'] as int?,
      lastRenewalDate: map['lastRenewalDate'] != null
          ? DateTime.parse(map['lastRenewalDate'] as String)
          : null,
      withdrawalDate: map['withdrawalDate'] != null
          ? DateTime.parse(map['withdrawalDate'] as String)
          : null,
      withdrawalAmount: map['withdrawalAmount'] != null
          ? (map['withdrawalAmount'] as num).toDouble()
          : null,
      isWithdrawn: map['isWithdrawn'] as bool? ?? false,
    );
  }

  FDMetadata copyWith({
    Map<String, dynamic>? fdData,
    String? linkedAccountId,
    String? linkedAccountName,
    DateTime? maturityDate,
    DateTime? investmentDate,
    DateTime? createdDate,
    double? estimatedAccruedValue,
    double? maturityValue,
    double? realizedValue,
    double? interestRate,
    int? tenureMonths,
    String? compoundingFrequency,
    String? payoutFrequency,
    bool? isCumulative,
    double? originalPrincipal,
    bool? debitedFromAccount,
    List<FDRenewalCycle>? renewalCycles,
    int? currentCycleIndex,
    DateTime? lastRenewalDate,
    DateTime? withdrawalDate,
    double? withdrawalAmount,
    bool? isWithdrawn,
  }) {
    return FDMetadata(
      fdData: fdData ?? this.fdData,
      linkedAccountId: linkedAccountId ?? this.linkedAccountId,
      linkedAccountName: linkedAccountName ?? this.linkedAccountName,
      maturityDate: maturityDate ?? this.maturityDate,
      investmentDate: investmentDate ?? this.investmentDate,
      createdDate: createdDate ?? this.createdDate,
      estimatedAccruedValue:
          estimatedAccruedValue ?? this.estimatedAccruedValue,
      maturityValue: maturityValue ?? this.maturityValue,
      realizedValue: realizedValue ?? this.realizedValue,
      interestRate: interestRate ?? this.interestRate,
      tenureMonths: tenureMonths ?? this.tenureMonths,
      compoundingFrequency: compoundingFrequency ?? this.compoundingFrequency,
      payoutFrequency: payoutFrequency ?? this.payoutFrequency,
      isCumulative: isCumulative ?? this.isCumulative,
      originalPrincipal: originalPrincipal ?? this.originalPrincipal,
      debitedFromAccount: debitedFromAccount ?? this.debitedFromAccount,
      renewalCycles: renewalCycles ?? this.renewalCycles,
      currentCycleIndex: currentCycleIndex ?? this.currentCycleIndex,
      lastRenewalDate: lastRenewalDate ?? this.lastRenewalDate,
      withdrawalDate: withdrawalDate ?? this.withdrawalDate,
      withdrawalAmount: withdrawalAmount ?? this.withdrawalAmount,
      isWithdrawn: isWithdrawn ?? this.isWithdrawn,
    );
  }
}

/// Recurring Deposit metadata
class RDMetadata implements InvestmentMetadata {
  final Map<String, dynamic> rdData;
  final String linkedAccountId;
  final String linkedAccountName;
  final DateTime maturityDate;
  final DateTime startDate;
  final double monthlyInstallment;
  final double estimatedMaturityValue;
  final double interestRate;
  final int tenureMonths;
  final String compoundingFrequency;
  final DateTime? withdrawalDate;
  final double? withdrawalAmount;
  final bool isWithdrawn;
  final List<DateTime> paymentDates;
  final double totalPaid;

  RDMetadata({
    required this.rdData,
    required this.linkedAccountId,
    required this.linkedAccountName,
    required this.maturityDate,
    required this.startDate,
    required this.monthlyInstallment,
    required this.estimatedMaturityValue,
    required this.interestRate,
    required this.tenureMonths,
    required this.compoundingFrequency,
    this.withdrawalDate,
    this.withdrawalAmount,
    this.isWithdrawn = false,
    this.paymentDates = const [],
    required this.totalPaid,
  });

  @override
  Map<String, dynamic> toMap() {
    return {
      'rdData': rdData,
      'linkedAccountId': linkedAccountId,
      'linkedAccountName': linkedAccountName,
      'maturityDate': maturityDate.toIso8601String(),
      'startDate': startDate.toIso8601String(),
      'monthlyInstallment': monthlyInstallment,
      'estimatedMaturityValue': estimatedMaturityValue,
      'interestRate': interestRate,
      'tenureMonths': tenureMonths,
      'compoundingFrequency': compoundingFrequency,
      if (withdrawalDate != null)
        'withdrawalDate': withdrawalDate!.toIso8601String(),
      if (withdrawalAmount != null) 'withdrawalAmount': withdrawalAmount,
      'isWithdrawn': isWithdrawn,
      'paymentDates': paymentDates.map((d) => d.toIso8601String()).toList(),
      'totalPaid': totalPaid,
    };
  }

  factory RDMetadata.fromMap(Map<String, dynamic> map) {
    return RDMetadata(
      rdData: Map<String, dynamic>.from(map['rdData'] ?? {}),
      linkedAccountId: map['linkedAccountId'] as String,
      linkedAccountName: map['linkedAccountName'] as String,
      maturityDate: DateTime.parse(map['maturityDate'] as String),
      startDate: DateTime.parse(map['startDate'] as String),
      monthlyInstallment: (map['monthlyInstallment'] as num).toDouble(),
      estimatedMaturityValue: (map['estimatedMaturityValue'] as num).toDouble(),
      interestRate: (map['interestRate'] as num).toDouble(),
      tenureMonths: map['tenureMonths'] as int,
      compoundingFrequency: map['compoundingFrequency'] as String,
      withdrawalDate: map['withdrawalDate'] != null
          ? DateTime.parse(map['withdrawalDate'] as String)
          : null,
      withdrawalAmount: map['withdrawalAmount'] != null
          ? (map['withdrawalAmount'] as num).toDouble()
          : null,
      isWithdrawn: map['isWithdrawn'] as bool? ?? false,
      paymentDates: (map['paymentDates'] as List?)
              ?.map((d) => DateTime.parse(d as String))
              .toList() ??
          [],
      totalPaid: (map['totalPaid'] as num).toDouble(),
    );
  }
}

/// Stock/Equity metadata
class StockMetadata implements InvestmentMetadata {
  final String symbol;
  final String? isin;
  final double quantity;
  final double averagePrice;
  final double currentPrice;
  final DateTime purchaseDate;
  final String exchange;
  final String? sector;
  final String? linkedAccountId;
  final String? linkedAccountName;
  final List<StockTransaction> transactions;

  StockMetadata({
    required this.symbol,
    this.isin,
    required this.quantity,
    required this.averagePrice,
    required this.currentPrice,
    required this.purchaseDate,
    required this.exchange,
    this.sector,
    this.linkedAccountId,
    this.linkedAccountName,
    this.transactions = const [],
  });

  double get currentValue => quantity * currentPrice;
  double get totalInvested => quantity * averagePrice;
  double get gainLoss => currentValue - totalInvested;
  double get gainLossPercentage => (gainLoss / totalInvested) * 100;

  @override
  Map<String, dynamic> toMap() {
    return {
      'symbol': symbol,
      'isin': isin,
      'quantity': quantity,
      'averagePrice': averagePrice,
      'currentPrice': currentPrice,
      'purchaseDate': purchaseDate.toIso8601String(),
      'exchange': exchange,
      'sector': sector,
      'linkedAccountId': linkedAccountId,
      'linkedAccountName': linkedAccountName,
      'transactions': transactions.map((t) => t.toMap()).toList(),
    };
  }

  factory StockMetadata.fromMap(Map<String, dynamic> map) {
    return StockMetadata(
      symbol: map['symbol'] as String,
      isin: map['isin'] as String?,
      quantity: (map['quantity'] as num).toDouble(),
      averagePrice: (map['averagePrice'] as num).toDouble(),
      currentPrice: (map['currentPrice'] as num).toDouble(),
      purchaseDate: DateTime.parse(map['purchaseDate'] as String),
      exchange: map['exchange'] as String,
      sector: map['sector'] as String?,
      linkedAccountId: map['linkedAccountId'] as String?,
      linkedAccountName: map['linkedAccountName'] as String?,
      transactions: (map['transactions'] as List?)
              ?.map((t) => StockTransaction.fromMap(t as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

/// Stock transaction record
class StockTransaction {
  final DateTime date;
  final String type; // 'buy' or 'sell'
  final double quantity;
  final double price;
  final double? fees;

  StockTransaction({
    required this.date,
    required this.type,
    required this.quantity,
    required this.price,
    this.fees,
  });

  double get totalAmount => (quantity * price) + (fees ?? 0);

  Map<String, dynamic> toMap() {
    return {
      'date': date.toIso8601String(),
      'type': type,
      'quantity': quantity,
      'price': price,
      'fees': fees,
    };
  }

  factory StockTransaction.fromMap(Map<String, dynamic> map) {
    return StockTransaction(
      date: DateTime.parse(map['date'] as String),
      type: map['type'] as String,
      quantity: (map['quantity'] as num).toDouble(),
      price: (map['price'] as num).toDouble(),
      fees: map['fees'] != null ? (map['fees'] as num).toDouble() : null,
    );
  }
}

/// Mutual Fund metadata
class MutualFundMetadata implements InvestmentMetadata {
  final String schemeCode;
  final String schemeName;
  final String fundHouse;
  final String schemeType;
  final double units;
  final double purchaseNAV;
  final double currentNAV;
  final DateTime purchaseDate;
  final String? linkedAccountId;
  final String? linkedAccountName;
  final String? folioNumber;

  MutualFundMetadata({
    required this.schemeCode,
    required this.schemeName,
    required this.fundHouse,
    required this.schemeType,
    required this.units,
    required this.purchaseNAV,
    required this.currentNAV,
    required this.purchaseDate,
    this.linkedAccountId,
    this.linkedAccountName,
    this.folioNumber,
  });

  double get currentValue => units * currentNAV;
  double get investedValue => units * purchaseNAV;
  double get gainLoss => currentValue - investedValue;
  double get returns => (gainLoss / investedValue) * 100;

  @override
  Map<String, dynamic> toMap() {
    return {
      'schemeCode': schemeCode,
      'schemeName': schemeName,
      'fundHouse': fundHouse,
      'schemeType': schemeType,
      'units': units,
      'purchaseNAV': purchaseNAV,
      'currentNAV': currentNAV,
      'purchaseDate': purchaseDate.toIso8601String(),
      'linkedAccountId': linkedAccountId,
      'linkedAccountName': linkedAccountName,
      'folioNumber': folioNumber,
    };
  }

  factory MutualFundMetadata.fromMap(Map<String, dynamic> map) {
    return MutualFundMetadata(
      schemeCode: map['schemeCode'] as String,
      schemeName: map['schemeName'] as String,
      fundHouse: map['fundHouse'] as String,
      schemeType: map['schemeType'] as String,
      units: (map['units'] as num).toDouble(),
      purchaseNAV: (map['purchaseNAV'] as num).toDouble(),
      currentNAV: (map['currentNAV'] as num).toDouble(),
      purchaseDate: DateTime.parse(map['purchaseDate'] as String),
      linkedAccountId: map['linkedAccountId'] as String?,
      linkedAccountName: map['linkedAccountName'] as String?,
      folioNumber: map['folioNumber'] as String?,
    );
  }
}

/// Bond metadata
class BondMetadata implements InvestmentMetadata {
  final String bondName;
  final String issuer;
  final double faceValue;
  final double couponRate;
  final DateTime issueDate;
  final DateTime maturityDate;
  final String frequency; // 'Annual', 'Semi-Annual', 'Quarterly'
  final double? currentMarketPrice;
  final String? linkedAccountId;
  final String? linkedAccountName;

  BondMetadata({
    required this.bondName,
    required this.issuer,
    required this.faceValue,
    required this.couponRate,
    required this.issueDate,
    required this.maturityDate,
    required this.frequency,
    this.currentMarketPrice,
    this.linkedAccountId,
    this.linkedAccountName,
  });

  @override
  Map<String, dynamic> toMap() {
    return {
      'bondName': bondName,
      'issuer': issuer,
      'faceValue': faceValue,
      'couponRate': couponRate,
      'issueDate': issueDate.toIso8601String(),
      'maturityDate': maturityDate.toIso8601String(),
      'frequency': frequency,
      'currentMarketPrice': currentMarketPrice,
      'linkedAccountId': linkedAccountId,
      'linkedAccountName': linkedAccountName,
    };
  }

  factory BondMetadata.fromMap(Map<String, dynamic> map) {
    return BondMetadata(
      bondName: map['bondName'] as String,
      issuer: map['issuer'] as String,
      faceValue: (map['faceValue'] as num).toDouble(),
      couponRate: (map['couponRate'] as num).toDouble(),
      issueDate: DateTime.parse(map['issueDate'] as String),
      maturityDate: DateTime.parse(map['maturityDate'] as String),
      frequency: map['frequency'] as String,
      currentMarketPrice: map['currentMarketPrice'] != null
          ? (map['currentMarketPrice'] as num).toDouble()
          : null,
      linkedAccountId: map['linkedAccountId'] as String?,
      linkedAccountName: map['linkedAccountName'] as String?,
    );
  }
}

/// Digital Gold metadata
class DigitalGoldMetadata implements InvestmentMetadata {
  final double grams;
  final double purchasePricePerGram;
  final double currentPricePerGram;
  final DateTime purchaseDate;
  final String provider; // 'Paytm', 'PhonePe', etc.
  final String? linkedAccountId;
  final String? linkedAccountName;

  DigitalGoldMetadata({
    required this.grams,
    required this.purchasePricePerGram,
    required this.currentPricePerGram,
    required this.purchaseDate,
    required this.provider,
    this.linkedAccountId,
    this.linkedAccountName,
  });

  double get currentValue => grams * currentPricePerGram;
  double get investedValue => grams * purchasePricePerGram;
  double get gainLoss => currentValue - investedValue;
  double get returns => (gainLoss / investedValue) * 100;

  @override
  Map<String, dynamic> toMap() {
    return {
      'grams': grams,
      'purchasePricePerGram': purchasePricePerGram,
      'currentPricePerGram': currentPricePerGram,
      'purchaseDate': purchaseDate.toIso8601String(),
      'provider': provider,
      'linkedAccountId': linkedAccountId,
      'linkedAccountName': linkedAccountName,
    };
  }

  factory DigitalGoldMetadata.fromMap(Map<String, dynamic> map) {
    return DigitalGoldMetadata(
      grams: (map['grams'] as num).toDouble(),
      purchasePricePerGram: (map['purchasePricePerGram'] as num).toDouble(),
      currentPricePerGram: (map['currentPricePerGram'] as num).toDouble(),
      purchaseDate: DateTime.parse(map['purchaseDate'] as String),
      provider: map['provider'] as String,
      linkedAccountId: map['linkedAccountId'] as String?,
      linkedAccountName: map['linkedAccountName'] as String?,
    );
  }
}

/// Cryptocurrency metadata
class CryptoMetadata implements InvestmentMetadata {
  final String symbol;
  final String name;
  final double quantity;
  final double averagePrice;
  final double currentPrice;
  final DateTime purchaseDate;
  final String exchange;
  final String? walletAddress;
  final String? linkedAccountId;
  final String? linkedAccountName;

  CryptoMetadata({
    required this.symbol,
    required this.name,
    required this.quantity,
    required this.averagePrice,
    required this.currentPrice,
    required this.purchaseDate,
    required this.exchange,
    this.walletAddress,
    this.linkedAccountId,
    this.linkedAccountName,
  });

  double get currentValue => quantity * currentPrice;
  double get investedValue => quantity * averagePrice;
  double get gainLoss => currentValue - investedValue;
  double get returns => (gainLoss / investedValue) * 100;

  @override
  Map<String, dynamic> toMap() {
    return {
      'symbol': symbol,
      'name': name,
      'quantity': quantity,
      'averagePrice': averagePrice,
      'currentPrice': currentPrice,
      'purchaseDate': purchaseDate.toIso8601String(),
      'exchange': exchange,
      'walletAddress': walletAddress,
      'linkedAccountId': linkedAccountId,
      'linkedAccountName': linkedAccountName,
    };
  }

  factory CryptoMetadata.fromMap(Map<String, dynamic> map) {
    return CryptoMetadata(
      symbol: map['symbol'] as String,
      name: map['name'] as String,
      quantity: (map['quantity'] as num).toDouble(),
      averagePrice: (map['averagePrice'] as num).toDouble(),
      currentPrice: (map['currentPrice'] as num).toDouble(),
      purchaseDate: DateTime.parse(map['purchaseDate'] as String),
      exchange: map['exchange'] as String,
      walletAddress: map['walletAddress'] as String?,
      linkedAccountId: map['linkedAccountId'] as String?,
      linkedAccountName: map['linkedAccountName'] as String?,
    );
  }
}
