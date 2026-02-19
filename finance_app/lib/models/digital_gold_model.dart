class DigitalGoldCompany {
  final String id;
  final String name;
  final String iconUrl;

  DigitalGoldCompany({
    required this.id,
    required this.name,
    this.iconUrl = '',
  });
}

class DigitalGoldInvestment {
  final String id;
  final String company;
  final double weight; // in grams
  final double investedRate; // rate per gram at time of investment
  final double gstRate; // default 3%
  final DateTime investmentDate;
  final double investedAmount; // amount paid including GST
  final double currentRate; // current rate per gram
  final DateTime lastUpdated;

  DigitalGoldInvestment({
    required this.id,
    required this.company,
    required this.weight,
    required this.investedRate,
    required this.gstRate,
    required this.investmentDate,
    required this.investedAmount,
    required this.currentRate,
    required this.lastUpdated,
  });

  // Calculate current value based on current rate
  double get currentValue => weight * currentRate;

  // Calculate gain/loss
  double get gainLoss => currentValue - investedAmount;

  // Calculate gain/loss percentage
  double get gainLossPercent =>
      investedAmount > 0 ? (gainLoss / investedAmount) * 100 : 0;

  // Amount per gram including GST
  double get amountPerGram => investedRate * (1 + (gstRate / 100));

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'company': company,
      'weight': weight,
      'investedRate': investedRate,
      'gstRate': gstRate,
      'investmentDate': investmentDate.toIso8601String(),
      'investedAmount': investedAmount,
      'currentRate': currentRate,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  factory DigitalGoldInvestment.fromMap(Map<String, dynamic> map) {
    return DigitalGoldInvestment(
      id: map['id'] as String,
      company: map['company'] as String,
      weight: (map['weight'] as num).toDouble(),
      investedRate: (map['investedRate'] as num).toDouble(),
      gstRate: (map['gstRate'] as num).toDouble(),
      investmentDate: DateTime.parse(map['investmentDate'] as String),
      investedAmount: (map['investedAmount'] as num).toDouble(),
      currentRate: (map['currentRate'] as num).toDouble(),
      lastUpdated: DateTime.parse(map['lastUpdated'] as String),
    );
  }
}
