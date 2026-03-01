enum LendingType { lent, borrowed }

enum LendingHistoryEventType {
  created,
  amountIncreased,
  amountReduced,
  edited,
  settled,
  reopened,
}

class LendingHistoryEvent {
  final String id;
  final LendingHistoryEventType type;
  final DateTime timestamp;
  final double? amountDelta;
  final double resultingAmount;
  final String? note;

  LendingHistoryEvent({
    required this.id,
    required this.type,
    required this.timestamp,
    required this.resultingAmount,
    this.amountDelta,
    this.note,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'timestamp': timestamp.toIso8601String(),
      'amountDelta': amountDelta,
      'resultingAmount': resultingAmount,
      'note': note,
    };
  }

  factory LendingHistoryEvent.fromMap(Map<String, dynamic> map) {
    final rawType = (map['type'] as String?) ?? 'edited';
    final parsedType = LendingHistoryEventType.values.firstWhere(
      (item) => item.name == rawType,
      orElse: () => LendingHistoryEventType.edited,
    );

    return LendingHistoryEvent(
      id: map['id'] as String? ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      type: parsedType,
      timestamp: map['timestamp'] != null
          ? DateTime.parse(map['timestamp'] as String)
          : DateTime.now(),
      amountDelta: (map['amountDelta'] as num?)?.toDouble(),
      resultingAmount: (map['resultingAmount'] as num?)?.toDouble() ?? 0,
      note: map['note'] as String?,
    );
  }
}

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
  final List<LendingHistoryEvent> history;

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
    this.history = const [],
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
      'history': history.map((item) => item.toMap()).toList(),
    };
  }

  factory LendingBorrowing.fromMap(Map<String, dynamic> map) {
    return LendingBorrowing(
      id: map['id'],
      personName: map['personName'],
      amount: (map['amount'] as num).toDouble(),
      type: map['type'].toString().contains('lent')
          ? LendingType.lent
          : LendingType.borrowed,
      description: map['description'],
      date: DateTime.parse(map['date']),
      dueDate: map['dueDate'] != null ? DateTime.parse(map['dueDate']) : null,
      isSettled: map['isSettled'] ?? false,
      settledDate: map['settledDate'],
      history: (map['history'] as List?)
              ?.map((item) => LendingHistoryEvent.fromMap(
                  Map<String, dynamic>.from(item as Map)))
              .toList() ??
          const [],
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
    List<LendingHistoryEvent>? history,
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
      history: history ?? this.history,
    );
  }
}
