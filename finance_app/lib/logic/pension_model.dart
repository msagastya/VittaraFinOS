enum PensionSchemeType { apy, epf, ppf }

class PensionContribution {
  final DateTime date;
  final double amount;
  final double? employerContribution;

  PensionContribution({
    required this.date,
    required this.amount,
    this.employerContribution,
  });

  Map<String, dynamic> toMap() => {
        'date': date.toIso8601String(),
        'amount': amount,
        'employerContribution': employerContribution,
      };

  factory PensionContribution.fromMap(Map<String, dynamic> map) =>
      PensionContribution(
        date: DateTime.parse(map['date']),
        amount: (map['amount'] as num).toDouble(),
        employerContribution: map['employerContribution'] as double?,
      );
}

class PensionScheme {
  final String id;
  final String accountNumber;
  final PensionSchemeType type;
  final double principalContributed;
  final double currentValue;
  final List<PensionContribution> contributions;
  final DateTime createdDate;
  final String? notes;

  PensionScheme({
    required this.id,
    required this.accountNumber,
    required this.type,
    required this.principalContributed,
    required this.currentValue,
    required this.contributions,
    required this.createdDate,
    this.notes,
  });

  double get gainLoss => currentValue - principalContributed;
  double get gainLossPercent =>
      principalContributed > 0 ? (gainLoss / principalContributed) * 100 : 0;

  String getTypeLabel() {
    switch (type) {
      case PensionSchemeType.apy:
        return 'Atal Pension Yojana (APY)';
      case PensionSchemeType.epf:
        return 'Employee Provident Fund (EPF)';
      case PensionSchemeType.ppf:
        return 'Public Provident Fund (PPF)';
    }
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'accountNumber': accountNumber,
        'type': type.index,
        'principalContributed': principalContributed,
        'currentValue': currentValue,
        'contributions': contributions.map((c) => c.toMap()).toList(),
        'createdDate': createdDate.toIso8601String(),
        'notes': notes,
      };

  factory PensionScheme.fromMap(Map<String, dynamic> map) => PensionScheme(
        id: map['id'],
        accountNumber: map['accountNumber'],
        type: PensionSchemeType.values[map['type'] as int],
        principalContributed: (map['principalContributed'] as num).toDouble(),
        currentValue: (map['currentValue'] as num).toDouble(),
        contributions: (map['contributions'] as List?)
                ?.map((c) =>
                    PensionContribution.fromMap(c as Map<String, dynamic>))
                .toList() ??
            [],
        createdDate: DateTime.parse(map['createdDate']),
        notes: map['notes'] as String?,
      );
}
