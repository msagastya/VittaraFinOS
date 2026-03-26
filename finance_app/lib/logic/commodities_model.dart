enum CommodityType { gold, silver, oil, gas, wheat, cotton }

enum TradePosition { long, short }

class Commodity {
  final String id;
  final String name;
  final CommodityType type;
  final double quantity;
  final String unit;
  final double buyPrice;
  final double currentPrice;
  final TradePosition position;
  final DateTime purchaseDate;
  final String exchange;
  final DateTime createdDate;
  final String? notes;

  Commodity({
    required this.id,
    required this.name,
    required this.type,
    required this.quantity,
    required this.unit,
    required this.buyPrice,
    required this.currentPrice,
    required this.position,
    required this.purchaseDate,
    required this.exchange,
    required this.createdDate,
    this.notes,
  });

  double get totalCost => quantity * buyPrice;
  double get currentValue => quantity * currentPrice;
  double get gainLoss => currentValue - totalCost;
  double get gainLossPercent =>
      totalCost > 0 ? (gainLoss / totalCost) * 100 : 0;

  String getTypeLabel() {
    switch (type) {
      case CommodityType.gold:
        return 'Gold';
      case CommodityType.silver:
        return 'Silver';
      case CommodityType.oil:
        return 'Crude Oil';
      case CommodityType.gas:
        return 'Natural Gas';
      case CommodityType.wheat:
        return 'Wheat';
      case CommodityType.cotton:
        return 'Cotton';
    }
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'type': type.index,
        'quantity': quantity,
        'unit': unit,
        'buyPrice': buyPrice,
        'currentPrice': currentPrice,
        'position': position.index,
        'purchaseDate': purchaseDate.toIso8601String(),
        'exchange': exchange,
        'createdDate': createdDate.toIso8601String(),
        'notes': notes,
      };

  factory Commodity.fromMap(Map<String, dynamic> map) => Commodity(
        id: map['id'],
        name: map['name'],
        type: CommodityType.values[((map['type'] as num?)?.toInt() ?? 0).clamp(0, CommodityType.values.length - 1)],
        quantity: (map['quantity'] as num).toDouble(),
        unit: map['unit'],
        buyPrice: (map['buyPrice'] as num).toDouble(),
        currentPrice: (map['currentPrice'] as num).toDouble(),
        position: TradePosition.values[((map['position'] as num?)?.toInt() ?? 0).clamp(0, TradePosition.values.length - 1)],
        purchaseDate: DateTime.parse(map['purchaseDate']),
        exchange: map['exchange'],
        createdDate: DateTime.parse(map['createdDate']),
        notes: map['notes'] as String?,
      );
}
