enum InsuranceType { health, life, term, vehicle, travel, home, other }

extension InsuranceTypeExtension on InsuranceType {
  String get displayName {
    switch (this) {
      case InsuranceType.health:
        return 'Health';
      case InsuranceType.life:
        return 'Life';
      case InsuranceType.term:
        return 'Term';
      case InsuranceType.vehicle:
        return 'Vehicle';
      case InsuranceType.travel:
        return 'Travel';
      case InsuranceType.home:
        return 'Home';
      case InsuranceType.other:
        return 'Other';
    }
  }
}

class InsurancePolicy {
  final String id;
  final String name;
  final InsuranceType type;
  final String insurer;
  final String? policyNumber;
  final double premiumAmount;
  final String premiumFrequency; // 'monthly', 'quarterly', 'annual'
  final double sumInsured;
  final DateTime renewalDate;
  final DateTime startDate;
  final String? nomineeName;
  final String? notes;
  final bool isActive;

  InsurancePolicy({
    required this.id,
    required this.name,
    required this.type,
    required this.insurer,
    this.policyNumber,
    required this.premiumAmount,
    required this.premiumFrequency,
    required this.sumInsured,
    required this.renewalDate,
    required this.startDate,
    this.nomineeName,
    this.notes,
    this.isActive = true,
  });

  bool get isExpiringSoon =>
      !isExpired &&
      renewalDate.isBefore(DateTime.now().add(const Duration(days: 30)));

  bool get isExpired => renewalDate.isBefore(DateTime.now());

  int get daysUntilRenewal =>
      renewalDate.difference(DateTime.now()).inDays;

  /// Normalise premium to annual amount.
  double get annualPremium {
    switch (premiumFrequency) {
      case 'monthly':
        return premiumAmount * 12;
      case 'quarterly':
        return premiumAmount * 4;
      case 'annual':
      default:
        return premiumAmount;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'insurer': insurer,
      'policyNumber': policyNumber,
      'premiumAmount': premiumAmount,
      'premiumFrequency': premiumFrequency,
      'sumInsured': sumInsured,
      'renewalDate': renewalDate.toIso8601String(),
      'startDate': startDate.toIso8601String(),
      'nomineeName': nomineeName,
      'notes': notes,
      'isActive': isActive,
    };
  }

  factory InsurancePolicy.fromMap(Map<String, dynamic> map) {
    final rawType = (map['type'] as String?) ?? 'other';
    final parsedType = InsuranceType.values.firstWhere(
      (t) => t.name == rawType,
      orElse: () => InsuranceType.other,
    );
    return InsurancePolicy(
      id: map['id'] as String,
      name: map['name'] as String,
      type: parsedType,
      insurer: (map['insurer'] as String?) ?? '',
      policyNumber: map['policyNumber'] as String?,
      premiumAmount: (map['premiumAmount'] as num).toDouble(),
      premiumFrequency: (map['premiumFrequency'] as String?) ?? 'annual',
      sumInsured: (map['sumInsured'] as num).toDouble(),
      renewalDate: DateTime.parse(map['renewalDate'] as String),
      startDate: DateTime.parse(map['startDate'] as String),
      nomineeName: map['nomineeName'] as String?,
      notes: map['notes'] as String?,
      isActive: (map['isActive'] as bool?) ?? true,
    );
  }

  InsurancePolicy copyWith({
    String? id,
    String? name,
    InsuranceType? type,
    String? insurer,
    Object? policyNumber = _sentinel,
    double? premiumAmount,
    String? premiumFrequency,
    double? sumInsured,
    DateTime? renewalDate,
    DateTime? startDate,
    Object? nomineeName = _sentinel,
    Object? notes = _sentinel,
    bool? isActive,
  }) {
    return InsurancePolicy(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      insurer: insurer ?? this.insurer,
      policyNumber: policyNumber == _sentinel
          ? this.policyNumber
          : policyNumber as String?,
      premiumAmount: premiumAmount ?? this.premiumAmount,
      premiumFrequency: premiumFrequency ?? this.premiumFrequency,
      sumInsured: sumInsured ?? this.sumInsured,
      renewalDate: renewalDate ?? this.renewalDate,
      startDate: startDate ?? this.startDate,
      nomineeName:
          nomineeName == _sentinel ? this.nomineeName : nomineeName as String?,
      notes: notes == _sentinel ? this.notes : notes as String?,
      isActive: isActive ?? this.isActive,
    );
  }
}

// Sentinel for nullable copyWith fields
const Object _sentinel = Object();
