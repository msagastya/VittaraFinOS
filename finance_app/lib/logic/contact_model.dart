class Contact {
  final String id;
  final String name;
  final String? phoneNumber;
  final DateTime createdDate;

  Contact({
    required this.id,
    required this.name,
    this.phoneNumber,
    required this.createdDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phoneNumber': phoneNumber,
      'createdDate': createdDate.toIso8601String(),
    };
  }

  factory Contact.fromMap(Map<String, dynamic> map) {
    return Contact(
      id: map['id'],
      name: map['name'],
      phoneNumber: map['phoneNumber'],
      createdDate: DateTime.parse(map['createdDate']),
    );
  }

  Contact copyWith({
    String? id,
    String? name,
    String? phoneNumber,
    DateTime? createdDate,
  }) {
    return Contact(
      id: id ?? this.id,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      createdDate: createdDate ?? this.createdDate,
    );
  }
}
