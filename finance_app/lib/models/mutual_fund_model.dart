class MutualFund {
  final int? id;
  final String schemeCode;
  final String schemeName;
  final String? isin;
  final String? schemeType;
  final String? fundHouse;
  final double? nav;
  final String? lastUpdated;
  final String? category;
  final int isActive;

  MutualFund({
    this.id,
    required this.schemeCode,
    required this.schemeName,
    this.isin,
    this.schemeType,
    this.fundHouse,
    this.nav,
    this.lastUpdated,
    this.category,
    this.isActive = 1,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'scheme_code': schemeCode,
      'scheme_name': schemeName,
      'isin': isin,
      'scheme_type': schemeType,
      'fund_house': fundHouse,
      'nav': nav,
      'last_updated': lastUpdated,
      'category': category,
      'is_active': isActive,
    };
  }

  factory MutualFund.fromMap(Map<String, dynamic> map) {
    return MutualFund(
      id: map['id'] as int?,
      schemeCode: map['scheme_code'] as String,
      schemeName: map['scheme_name'] as String,
      isin: map['isin'] as String?,
      schemeType: map['scheme_type'] as String?,
      fundHouse: map['fund_house'] as String?,
      nav: map['nav'] as double?,
      lastUpdated: map['last_updated'] as String?,
      category: map['category'] as String?,
      isActive: map['is_active'] as int? ?? 1,
    );
  }

  @override
  String toString() =>
      'MutualFund(id: $id, schemeCode: $schemeCode, schemeName: $schemeName, schemeType: $schemeType, fundHouse: $fundHouse)';
}
