import 'package:flutter/cupertino.dart';

class Tag {
  final String id;
  final String name;
  final Color color;
  final DateTime createdDate;

  Tag({
    required this.id,
    required this.name,
    required this.color,
    required this.createdDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'colorValue': color.toARGB32(),
      'createdDate': createdDate.toIso8601String(),
    };
  }

  factory Tag.fromMap(Map<String, dynamic> map) {
    return Tag(
      id: map['id'],
      name: map['name'],
      color: Color(map['colorValue']),
      createdDate: DateTime.tryParse(map['createdDate']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Tag copyWith({
    String? id,
    String? name,
    Color? color,
    DateTime? createdDate,
  }) {
    return Tag(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      createdDate: createdDate ?? this.createdDate,
    );
  }

  // Predefined color palette for tags
  static const List<Color> colorPalette = [
    CupertinoColors.systemRed,
    CupertinoColors.systemOrange,
    CupertinoColors.systemYellow,
    CupertinoColors.systemGreen,
    CupertinoColors.systemTeal,
    CupertinoColors.systemBlue,
    CupertinoColors.systemIndigo,
    CupertinoColors.systemPurple,
    CupertinoColors.systemPink,
    CupertinoColors.systemBrown,
  ];
}
