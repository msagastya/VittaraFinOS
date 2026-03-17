enum LoanType { home, car, personal, education, gold, creditCard, other }

extension LoanTypeExtension on LoanType {
  String get displayName {
    switch (this) {
      case LoanType.home:
        return 'Home Loan';
      case LoanType.car:
        return 'Car Loan';
      case LoanType.personal:
        return 'Personal Loan';
      case LoanType.education:
        return 'Education Loan';
      case LoanType.gold:
        return 'Gold Loan';
      case LoanType.creditCard:
        return 'Credit Card';
      case LoanType.other:
        return 'Other';
    }
  }

  String get iconAsset {
    switch (this) {
      case LoanType.home:
        return 'house.fill';
      case LoanType.car:
        return 'car.fill';
      case LoanType.personal:
        return 'person.fill';
      case LoanType.education:
        return 'book.fill';
      case LoanType.gold:
        return 'star.fill';
      case LoanType.creditCard:
        return 'creditcard.fill';
      case LoanType.other:
        return 'doc.fill';
    }
  }
}

class Loan {
  final String id;
  final String name;
  final LoanType type;
  final double principalAmount;
  final double currentOutstanding;
  final double interestRate;
  final int tenureMonths;
  final int remainingMonths;
  final double emiAmount;
  final DateTime startDate;
  final DateTime nextDueDate;
  final String? bankName;
  final String? accountNumber;
  final String? notes;
  final bool isActive;

  Loan({
    required this.id,
    required this.name,
    required this.type,
    required this.principalAmount,
    required this.currentOutstanding,
    required this.interestRate,
    required this.tenureMonths,
    required this.remainingMonths,
    required this.emiAmount,
    required this.startDate,
    required this.nextDueDate,
    this.bankName,
    this.accountNumber,
    this.notes,
    this.isActive = true,
  });

  double get totalPaid => (principalAmount - currentOutstanding).clamp(0.0, principalAmount);
  double get progressPercent => principalAmount > 0 ? (totalPaid / principalAmount).clamp(0.0, 1.0) : 0.0;
  double get totalInterestPayable => (emiAmount * tenureMonths) - principalAmount;

  bool get isOverdue => nextDueDate.isBefore(DateTime.now());
  bool get isDueSoon {
    final now = DateTime.now();
    return !isOverdue && nextDueDate.difference(now).inDays <= 7;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'principalAmount': principalAmount,
      'currentOutstanding': currentOutstanding,
      'interestRate': interestRate,
      'tenureMonths': tenureMonths,
      'remainingMonths': remainingMonths,
      'emiAmount': emiAmount,
      'startDate': startDate.toIso8601String(),
      'nextDueDate': nextDueDate.toIso8601String(),
      'bankName': bankName,
      'accountNumber': accountNumber,
      'notes': notes,
      'isActive': isActive,
    };
  }

  factory Loan.fromMap(Map<String, dynamic> map) {
    final rawType = (map['type'] as String?) ?? 'other';
    final parsedType = LoanType.values.firstWhere(
      (t) => t.name == rawType,
      orElse: () => LoanType.other,
    );
    return Loan(
      id: map['id'] as String,
      name: map['name'] as String,
      type: parsedType,
      principalAmount: (map['principalAmount'] as num).toDouble(),
      currentOutstanding: (map['currentOutstanding'] as num).toDouble(),
      interestRate: (map['interestRate'] as num).toDouble(),
      tenureMonths: (map['tenureMonths'] as num).toInt(),
      remainingMonths: (map['remainingMonths'] as num).toInt(),
      emiAmount: (map['emiAmount'] as num).toDouble(),
      startDate: DateTime.parse(map['startDate'] as String),
      nextDueDate: DateTime.parse(map['nextDueDate'] as String),
      bankName: map['bankName'] as String?,
      accountNumber: map['accountNumber'] as String?,
      notes: map['notes'] as String?,
      isActive: (map['isActive'] as bool?) ?? true,
    );
  }

  Loan copyWith({
    String? id,
    String? name,
    LoanType? type,
    double? principalAmount,
    double? currentOutstanding,
    double? interestRate,
    int? tenureMonths,
    int? remainingMonths,
    double? emiAmount,
    DateTime? startDate,
    DateTime? nextDueDate,
    String? bankName,
    String? accountNumber,
    String? notes,
    bool? isActive,
  }) {
    return Loan(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      principalAmount: principalAmount ?? this.principalAmount,
      currentOutstanding: currentOutstanding ?? this.currentOutstanding,
      interestRate: interestRate ?? this.interestRate,
      tenureMonths: tenureMonths ?? this.tenureMonths,
      remainingMonths: remainingMonths ?? this.remainingMonths,
      emiAmount: emiAmount ?? this.emiAmount,
      startDate: startDate ?? this.startDate,
      nextDueDate: nextDueDate ?? this.nextDueDate,
      bankName: bankName ?? this.bankName,
      accountNumber: accountNumber ?? this.accountNumber,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
    );
  }
}
