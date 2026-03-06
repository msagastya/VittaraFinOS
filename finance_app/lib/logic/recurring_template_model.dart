class RecurringTemplate {
  final String id;
  final String name;
  final String branch; // 'expense' or 'income'
  final double amount;
  final String? categoryId;
  final String? categoryName;
  final String? accountId;
  final String? accountName;
  final String? paymentType;
  final String? paymentApp;
  final String? merchant;
  final String? description;
  final List<String> tags;
  final String frequency; // 'daily'/'weekly'/'monthly'/'yearly'
  final DateTime? nextDueDate;
  final DateTime createdAt;

  const RecurringTemplate({
    required this.id,
    required this.name,
    required this.branch,
    required this.amount,
    this.categoryId,
    this.categoryName,
    this.accountId,
    this.accountName,
    this.paymentType,
    this.paymentApp,
    this.merchant,
    this.description,
    this.tags = const [],
    this.frequency = 'monthly',
    this.nextDueDate,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'branch': branch,
        'amount': amount,
        'categoryId': categoryId,
        'categoryName': categoryName,
        'accountId': accountId,
        'accountName': accountName,
        'paymentType': paymentType,
        'paymentApp': paymentApp,
        'merchant': merchant,
        'description': description,
        'tags': tags,
        'frequency': frequency,
        'nextDueDate': nextDueDate?.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory RecurringTemplate.fromMap(Map<String, dynamic> map) =>
      RecurringTemplate(
        id: map['id'] as String,
        name: map['name'] as String,
        branch: map['branch'] as String,
        amount: (map['amount'] as num).toDouble(),
        categoryId: map['categoryId'] as String?,
        categoryName: map['categoryName'] as String?,
        accountId: map['accountId'] as String?,
        accountName: map['accountName'] as String?,
        paymentType: map['paymentType'] as String?,
        paymentApp: map['paymentApp'] as String?,
        merchant: map['merchant'] as String?,
        description: map['description'] as String?,
        tags: (map['tags'] as List?)?.cast<String>() ?? [],
        frequency: map['frequency'] as String? ?? 'monthly',
        nextDueDate: map['nextDueDate'] != null
            ? DateTime.parse(map['nextDueDate'] as String)
            : null,
        createdAt: DateTime.parse(map['createdAt'] as String),
      );

  /// Returns how many days until nextDueDate (negative = overdue).
  int? daysUntilDue() {
    if (nextDueDate == null) return null;
    return nextDueDate!.difference(DateTime.now()).inDays;
  }

  /// Advance nextDueDate by one period.
  RecurringTemplate withAdvancedDueDate() {
    final base = nextDueDate ?? DateTime.now();
    DateTime next;
    switch (frequency) {
      case 'daily':
        next = base.add(const Duration(days: 1));
        break;
      case 'weekly':
        next = base.add(const Duration(days: 7));
        break;
      case 'yearly':
        next = DateTime(base.year + 1, base.month, base.day);
        break;
      default: // monthly
        next = DateTime(base.year, base.month + 1, base.day);
    }
    return RecurringTemplate(
      id: id,
      name: name,
      branch: branch,
      amount: amount,
      categoryId: categoryId,
      categoryName: categoryName,
      accountId: accountId,
      accountName: accountName,
      paymentType: paymentType,
      paymentApp: paymentApp,
      merchant: merchant,
      description: description,
      tags: tags,
      frequency: frequency,
      nextDueDate: next,
      createdAt: createdAt,
    );
  }
}
