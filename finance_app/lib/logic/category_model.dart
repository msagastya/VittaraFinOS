import 'package:flutter/cupertino.dart';

class Category {
  final String id;
  final String name;
  final Color color;
  final IconData icon;
  final bool isCustom;
  final String? description;

  Category({
    required this.id,
    required this.name,
    required this.color,
    required this.icon,
    this.isCustom = false,
    this.description,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'color': color.toARGB32(),
      'iconCodePoint': icon.codePoint,
      'isCustom': isCustom,
      'description': description,
    };
  }

  factory Category.fromMap(Map<String, dynamic> map) {
    final iconCodePoint = map['iconCodePoint'] as int;
    final icon = _getIconFromCodePoint(iconCodePoint);

    return Category(
      id: map['id'],
      name: map['name'],
      color: Color(map['color']),
      icon: icon,
      isCustom: map['isCustom'] ?? false,
      description: map['description'],
    );
  }

  static IconData _getIconFromCodePoint(int codePoint) {
    // Map of code points to Cupertino icons for deserialization
    final iconMap = {for (var icon in _allAvailableIcons) icon.codePoint: icon};

    return iconMap[codePoint] ?? CupertinoIcons.question;
  }

  static const List<IconData> _allAvailableIcons = [
    CupertinoIcons.home,
    CupertinoIcons.heart,
    CupertinoIcons.heart_fill,
    CupertinoIcons.star,
    CupertinoIcons.star_fill,
    CupertinoIcons.person,
    CupertinoIcons.person_fill,
    CupertinoIcons.gear,
    CupertinoIcons.gear_alt,
    CupertinoIcons.bag_fill,
    CupertinoIcons.shopping_cart,
    CupertinoIcons.drop_fill,
    CupertinoIcons.car,
    CupertinoIcons.car_fill,
    CupertinoIcons.device_phone_portrait,
    CupertinoIcons.film_fill,
    CupertinoIcons.gamecontroller_fill,
    CupertinoIcons.music_note,
    CupertinoIcons.heart_circle_fill,
    CupertinoIcons.plus_circle_fill,
    CupertinoIcons.bolt_fill,
    CupertinoIcons.wifi,
    CupertinoIcons.book_fill,
    CupertinoIcons.square_stack_fill,
    CupertinoIcons.building_2_fill,
    CupertinoIcons.airplane,
    CupertinoIcons.shield_fill,
    CupertinoIcons.money_dollar_circle_fill,
    CupertinoIcons.sparkles,
    CupertinoIcons.scissors,
    CupertinoIcons.gift_fill,
    CupertinoIcons.hand_raised_fill,
    CupertinoIcons.ellipsis,
    CupertinoIcons.tag_fill,
    CupertinoIcons.clock,
    CupertinoIcons.calendar,
    CupertinoIcons.search,
    CupertinoIcons.location,
    CupertinoIcons.phone,
    CupertinoIcons.mail,
    CupertinoIcons.creditcard,
    CupertinoIcons.creditcard_fill,
    CupertinoIcons.checkmark,
    CupertinoIcons.checkmark_circle,
    CupertinoIcons.checkmark_circle_fill,
    CupertinoIcons.xmark,
    CupertinoIcons.xmark_circle,
    CupertinoIcons.xmark_circle_fill,
    CupertinoIcons.plus,
    CupertinoIcons.plus_circle,
    CupertinoIcons.plus_circle_fill,
    CupertinoIcons.minus,
    CupertinoIcons.minus_circle,
    CupertinoIcons.minus_circle_fill,
    CupertinoIcons.info,
    CupertinoIcons.info_circle,
    CupertinoIcons.info_circle_fill,
    CupertinoIcons.share,
    CupertinoIcons.share_up,
    CupertinoIcons.doc_on_clipboard,
    CupertinoIcons.trash,
    CupertinoIcons.trash_fill,
    CupertinoIcons.pencil,
    CupertinoIcons.pencil_outline,
    CupertinoIcons.pencil_circle,
    CupertinoIcons.pencil_circle_fill,
    CupertinoIcons.eye,
    CupertinoIcons.eye_fill,
    CupertinoIcons.eye_slash,
    CupertinoIcons.eye_slash_fill,
    CupertinoIcons.chart_bar,
    CupertinoIcons.chart_bar_fill,
    CupertinoIcons.chart_pie,
    CupertinoIcons.chart_pie_fill,
    CupertinoIcons.arrow_up,
    CupertinoIcons.arrow_down,
    CupertinoIcons.arrow_left,
    CupertinoIcons.arrow_right,
    CupertinoIcons.arrow_up_circle,
    CupertinoIcons.arrow_up_circle_fill,
    CupertinoIcons.arrow_down_circle,
    CupertinoIcons.arrow_down_circle_fill,
    CupertinoIcons.arrow_left_circle,
    CupertinoIcons.arrow_left_circle_fill,
    CupertinoIcons.arrow_right_circle,
    CupertinoIcons.arrow_right_circle_fill,
  ];
}

// Predefined categories with icons
final List<Category> defaultCategories = [
  // Food & Dining
  Category(
    id: 'food',
    name: 'Food & Dining',
    color: const Color(0xFFFF6B6B),
    icon: CupertinoIcons.shopping_cart,
  ),
  Category(
    id: 'groceries',
    name: 'Groceries',
    color: const Color(0xFF51CF66),
    icon: CupertinoIcons.shopping_cart,
  ),
  Category(
    id: 'coffee',
    name: 'Coffee & Snacks',
    color: const Color(0xFF8B4513),
    icon: CupertinoIcons.drop_fill,
  ),

  // Transportation
  Category(
    id: 'fuel',
    name: 'Fuel',
    color: const Color(0xFFFFA500),
    icon: CupertinoIcons.car_fill,
  ),
  Category(
    id: 'taxi',
    name: 'Taxi & Rides',
    color: const Color(0xFFFFD700),
    icon: CupertinoIcons.car,
  ),
  Category(
    id: 'public_transit',
    name: 'Public Transit',
    color: const Color(0xFF0099FF),
    icon: CupertinoIcons.car_fill,
  ),

  // Shopping
  Category(
    id: 'clothing',
    name: 'Clothing & Shoes',
    color: const Color(0xFFFF69B4),
    icon: CupertinoIcons.bag_fill,
  ),
  Category(
    id: 'electronics',
    name: 'Electronics',
    color: const Color(0xFF4B0082),
    icon: CupertinoIcons.device_phone_portrait,
  ),
  Category(
    id: 'home',
    name: 'Home & Garden',
    color: const Color(0xFF8FBC8F),
    icon: CupertinoIcons.home,
  ),

  // Entertainment
  Category(
    id: 'movies',
    name: 'Movies & Shows',
    color: const Color(0xFF8B0000),
    icon: CupertinoIcons.film_fill,
  ),
  Category(
    id: 'games',
    name: 'Gaming',
    color: const Color(0xFF9370DB),
    icon: CupertinoIcons.gamecontroller_fill,
  ),
  Category(
    id: 'music',
    name: 'Music & Subscriptions',
    color: const Color(0xFFFF1493),
    icon: CupertinoIcons.music_note,
  ),

  // Health & Fitness
  Category(
    id: 'gym',
    name: 'Gym & Fitness',
    color: const Color(0xFF00CED1),
    icon: CupertinoIcons.heart_fill,
  ),
  Category(
    id: 'medical',
    name: 'Medical & Healthcare',
    color: const Color(0xFF32CD32),
    icon: CupertinoIcons.heart_circle_fill,
  ),
  Category(
    id: 'pharmacy',
    name: 'Pharmacy',
    color: const Color(0xFF006400),
    icon: CupertinoIcons.plus_circle_fill,
  ),

  // Bills & Utilities
  Category(
    id: 'electricity',
    name: 'Electricity',
    color: const Color(0xFFFFD700),
    icon: CupertinoIcons.bolt_fill,
  ),
  Category(
    id: 'water',
    name: 'Water & Gas',
    color: const Color(0xFF4169E1),
    icon: CupertinoIcons.drop_fill,
  ),
  Category(
    id: 'internet',
    name: 'Internet & Phone',
    color: const Color(0xFF1E90FF),
    icon: CupertinoIcons.wifi,
  ),

  // Education
  Category(
    id: 'books',
    name: 'Books & Education',
    color: const Color(0xFF8B4513),
    icon: CupertinoIcons.book_fill,
  ),
  Category(
    id: 'courses',
    name: 'Online Courses',
    color: const Color(0xFF4B0082),
    icon: CupertinoIcons.square_stack_fill,
  ),

  // Travel
  Category(
    id: 'hotels',
    name: 'Hotels & Accommodation',
    color: const Color(0xFF20B2AA),
    icon: CupertinoIcons.building_2_fill,
  ),
  Category(
    id: 'flights',
    name: 'Flights & Airlines',
    color: const Color(0xFF87CEEB),
    icon: CupertinoIcons.airplane,
  ),

  // Insurance & Financial
  Category(
    id: 'insurance',
    name: 'Insurance',
    color: const Color(0xFF696969),
    icon: CupertinoIcons.shield_fill,
  ),
  Category(
    id: 'bank_fees',
    name: 'Bank Fees',
    color: const Color(0xFF333333),
    icon: CupertinoIcons.money_dollar_circle_fill,
  ),

  // Personal Care
  Category(
    id: 'beauty',
    name: 'Beauty & Personal Care',
    color: const Color(0xFFFFC0CB),
    icon: CupertinoIcons.sparkles,
  ),
  Category(
    id: 'haircut',
    name: 'Haircut & Salon',
    color: const Color(0xFFDEB887),
    icon: CupertinoIcons.scissors,
  ),

  // Gifts & Donations
  Category(
    id: 'gifts',
    name: 'Gifts & Presents',
    color: const Color(0xFFFFB6C1),
    icon: CupertinoIcons.gift_fill,
  ),
  Category(
    id: 'charity',
    name: 'Charity & Donations',
    color: const Color(0xFF228B22),
    icon: CupertinoIcons.hand_raised_fill,
  ),

  // Pets
  Category(
    id: 'pets',
    name: 'Pet Care',
    color: const Color(0xFF8B4513),
    icon: CupertinoIcons.heart_fill,
  ),

  // Other
  Category(
    id: 'miscellaneous',
    name: 'Miscellaneous',
    color: const Color(0xFF808080),
    icon: CupertinoIcons.ellipsis,
  ),
];
