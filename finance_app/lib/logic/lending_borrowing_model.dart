enum LendingType { lent, borrowed }

class LendingBorrowing {
  final String id;
  final String personName;
  final double amount;
  final LendingType type; // lent or borrowed
  final String? description;
  final DateTime date;
  final DateTime? dueDate;
  final bool isSettled;
  final String? settledDate;

  LendingBorrowing({
    required this.id,
    required this.personName,
    required this.amount,
    required this.type,
    this.description,
    required this.date,
    this.dueDate,
    this.isSettled = false,
    this.settledDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'personName': personName,
      'amount': amount,
      'type': type.toString(), // 'LendingType.lent' or 'LendingType.borrowed'
      'description': description,
      'date': date.toIso8601String(),
      'dueDate': dueDate?.toIso8601String(),
      'isSettled': isSettled,
      'settledDate': settledDate,
    };
  }

  factory LendingBorrowing.fromMap(Map<String, dynamic> map) {
    return LendingBorrowing(
      id: map['id'],
      personName: map['personName'],
      amount: (map['amount'] as num).toDouble(),
      type: map['type'].toString().contains('lent') ? LendingType.lent : LendingType.borrowed,
      description: map['description'],
      date: DateTime.parse(map['date']),
      dueDate: map['dueDate'] != null ? DateTime.parse(map['dueDate']) : null,
      isSettled: map['isSettled'] ?? false,
      settledDate: map['settledDate'],
    );
  }

  LendingBorrowing copyWith({
    String? id,
    String? personName,
    double? amount,
    LendingType? type,
    String? description,
    DateTime? date,
    DateTime? dueDate,
    bool? isSettled,
    String? settledDate,
  }) {
    return LendingBorrowing(
      id: id ?? this.id,
      personName: personName ?? this.personName,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      description: description ?? this.description,
      date: date ?? this.date,
      dueDate: dueDate ?? this.dueDate,
      isSettled: isSettled ?? this.isSettled,
      settledDate: settledDate ?? this.settledDate,
    );
  }
}
