import 'dart:math' as math;

enum FOType { futures, callOption, putOption }

class OptionsGreeks {
  final double delta;
  final double gamma;
  final double theta;
  final double vega;
  final double rho;

  OptionsGreeks({
    required this.delta,
    required this.gamma,
    required this.theta,
    required this.vega,
    required this.rho,
  });

  Map<String, dynamic> toMap() => {
    'delta': delta,
    'gamma': gamma,
    'theta': theta,
    'vega': vega,
    'rho': rho,
  };

  factory OptionsGreeks.fromMap(Map<String, dynamic> map) => OptionsGreeks(
    delta: (map['delta'] as num).toDouble(),
    gamma: (map['gamma'] as num).toDouble(),
    theta: (map['theta'] as num).toDouble(),
    vega: (map['vega'] as num).toDouble(),
    rho: (map['rho'] as num).toDouble(),
  );
}

class FuturesOptions {
  final String id;
  final String symbol;
  final String name;
  final FOType type;
  final double entryPrice;
  final double currentPrice;
  final double quantity;
  final double? strikePrice; // For options only
  final DateTime expiryDate;
  final DateTime entryDate;
  final double? volatility; // Annual volatility in %
  final double? riskFreeRate; // Annual risk-free rate in %
  final OptionsGreeks? greeks; // For options only
  final DateTime createdDate;
  final String? notes;

  FuturesOptions({
    required this.id,
    required this.symbol,
    required this.name,
    required this.type,
    required this.entryPrice,
    required this.currentPrice,
    required this.quantity,
    this.strikePrice,
    required this.expiryDate,
    required this.entryDate,
    this.volatility,
    this.riskFreeRate,
    this.greeks,
    required this.createdDate,
    this.notes,
  });

  double get totalCost => quantity * entryPrice;
  double get currentValue => quantity * currentPrice;
  double get gainLoss => currentValue - totalCost;
  double get gainLossPercent =>
      totalCost > 0 ? (gainLoss / totalCost) * 100 : 0;

  int get daysToExpiry {
    final today = DateTime.now();
    return expiryDate.difference(today).inDays;
  }

  String getTypeLabel() {
    switch (type) {
      case FOType.futures:
        return 'Futures';
      case FOType.callOption:
        return 'Call Option';
      case FOType.putOption:
        return 'Put Option';
    }
  }

  /// Calculate max profit for the position
  double getMaxProfit() {
    switch (type) {
      case FOType.futures:
        return double.infinity; // Unlimited profit
      case FOType.callOption:
        return double.infinity; // Unlimited profit
      case FOType.putOption:
        return (strikePrice! - entryPrice) * quantity; // Limited to strike
    }
  }

  /// Calculate max loss for the position
  double getMaxLoss() {
    switch (type) {
      case FOType.futures:
        return double.infinity; // Unlimited loss
      case FOType.callOption:
        return totalCost; // Limited to premium paid
      case FOType.putOption:
        return double.infinity; // Unlimited loss
    }
  }

  /// Calculate breakeven price
  double getBreakeven() {
    switch (type) {
      case FOType.futures:
        return entryPrice;
      case FOType.callOption:
        return entryPrice + strikePrice!;
      case FOType.putOption:
        return strikePrice! - entryPrice;
    }
  }

  /// Black-Scholes Greeks calculation for options
  static OptionsGreeks calculateGreeks({
    required double spotPrice,
    required double strikePrice,
    required double riskFreeRate,
    required double volatility,
    required double timeToExpiry, // in years
    required bool isCall,
  }) {
    const double nofzero = 0.2316419;
    const double a1 = 0.319381530;
    const double a2 = -0.356563782;
    const double a3 = 1.781477937;
    const double a4 = -1.821255978;
    const double a5 = 1.330274429;

    final double sigma = volatility / 100; // Convert percentage to decimal
    final double r = riskFreeRate / 100;
    final double t = timeToExpiry;

    final double d1 = (math.log(spotPrice / strikePrice) +
            (r + 0.5 * sigma * sigma) * t) /
        (sigma * math.sqrt(t));
    final double d2 = d1 - sigma * math.sqrt(t);

    // Cumulative normal distribution
    double cumulativeNormal(double x) {
      final double a = a1 * x + a2 * x * x + a3 * x * x * x +
                       a4 * x * x * x * x + a5 * x * x * x * x * x;
      final double k = 1 / (1 + nofzero * x.abs());
      if (x >= 0) {
        return 1 -
            0.39894228 *
                math.exp(-0.5 * x * x) *
                k *
                a;
      } else {
        return 0.39894228 * math.exp(-0.5 * x * x) * k * a;
      }
    }

    final double nd1 = 0.39894228 * math.exp(-0.5 * d1 * d1);
    final double nd2 = 0.39894228 * math.exp(-0.5 * d2 * d2);
    final double n1 = cumulativeNormal(d1);
    final double n2 = cumulativeNormal(d2);
    final double n_d1 = cumulativeNormal(-d1);
    final double n_d2 = cumulativeNormal(-d2);

    // Calculate Greeks
    final double delta = isCall ? n1 : n1 - 1;
    final double gamma = nd1 / (spotPrice * sigma * math.sqrt(t));
    final double theta = isCall
        ? (-spotPrice * nd1 * sigma / (2 * math.sqrt(t)) -
            r * strikePrice * math.exp(-r * t) * n2) /
            365
        : (-spotPrice * nd1 * sigma / (2 * math.sqrt(t)) +
            r * strikePrice * math.exp(-r * t) * n_d2) /
            365;
    final double vega =
        spotPrice * nd1 * math.sqrt(t) / 100; // Per 1% change in volatility
    final double rho = isCall
        ? strikePrice * t * math.exp(-r * t) * n2 / 100
        : -strikePrice * t * math.exp(-r * t) * n_d2 / 100;

    return OptionsGreeks(
      delta: delta,
      gamma: gamma,
      theta: theta,
      vega: vega,
      rho: rho,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'symbol': symbol,
    'name': name,
    'type': type.index,
    'entryPrice': entryPrice,
    'currentPrice': currentPrice,
    'quantity': quantity,
    'strikePrice': strikePrice,
    'expiryDate': expiryDate.toIso8601String(),
    'entryDate': entryDate.toIso8601String(),
    'volatility': volatility,
    'riskFreeRate': riskFreeRate,
    'greeks': greeks?.toMap(),
    'createdDate': createdDate.toIso8601String(),
    'notes': notes,
  };

  factory FuturesOptions.fromMap(Map<String, dynamic> map) => FuturesOptions(
    id: map['id'],
    symbol: map['symbol'],
    name: map['name'],
    type: FOType.values[map['type'] as int],
    entryPrice: (map['entryPrice'] as num).toDouble(),
    currentPrice: (map['currentPrice'] as num).toDouble(),
    quantity: (map['quantity'] as num).toDouble(),
    strikePrice: map['strikePrice'] as double?,
    expiryDate: DateTime.parse(map['expiryDate']),
    entryDate: DateTime.parse(map['entryDate']),
    volatility: map['volatility'] as double?,
    riskFreeRate: map['riskFreeRate'] as double?,
    greeks: map['greeks'] != null
        ? OptionsGreeks.fromMap(map['greeks'] as Map<String, dynamic>)
        : null,
    createdDate: DateTime.parse(map['createdDate']),
    notes: map['notes'] as String?,
  );
}
