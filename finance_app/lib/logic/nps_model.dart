enum NPSTier { tier1, tier2 }

enum NPSSchemeType { equity, debt, alternative, gold }

enum NPSAccountType { individual, nri, minor, huf }

enum NPSManager {
  sbi('State Bank of India'),
  icici('ICICI Prudential'),
  hdfc('HDFC Standard'),
  reliance('Reliance Nippon'),
  axis('Axis Mutual Fund'),
  kotak('Kotak Mahindra'),
  birlaAxa('Birla AXA'),
  lAndT('L&T Mutual Fund');

  final String displayName;
  const NPSManager(this.displayName);
}

enum NPSWithdrawalType { immediate, staggered, none }

class NPSContribution {
  final String id;
  final DateTime date;
  final double amount;
  final String? source; // Salary, Personal, etc.
  final String? notes;

  NPSContribution({
    required this.id,
    required this.date,
    required this.amount,
    this.source,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'amount': amount,
      'source': source,
      'notes': notes,
    };
  }

  factory NPSContribution.fromMap(Map<String, dynamic> map) {
    return NPSContribution(
      id: map['id'],
      date: DateTime.parse(map['date']),
      amount: (map['amount'] as num).toDouble(),
      source: map['source'] as String?,
      notes: map['notes'] as String?,
    );
  }
}

class NPSAccount {
  final String id;
  final String prnNumber; // Permanent Retirement Number
  final String name;
  final String nrn; // National Registration Number
  final NPSTier tier;
  final NPSAccountType accountType;
  final NPSManager npsManager;
  final NPSSchemeType schemeType;
  final String panNumber;

  // Financial details
  final double totalContributed;
  final double currentValue;
  final List<NPSContribution> contributions;

  // Returns
  final double estimatedReturns;

  // Withdrawal settings
  final NPSWithdrawalType withdrawalType;
  final DateTime? plannedRetirementDate;

  // Metadata
  final DateTime createdDate;
  final DateTime lastUpdate;
  final String? notes;
  final Map<String, dynamic>? metadata;

  NPSAccount({
    required this.id,
    required this.prnNumber,
    required this.name,
    required this.nrn,
    required this.tier,
    required this.accountType,
    required this.npsManager,
    required this.schemeType,
    required this.panNumber,
    required this.totalContributed,
    required this.currentValue,
    required this.contributions,
    required this.estimatedReturns,
    required this.withdrawalType,
    this.plannedRetirementDate,
    required this.createdDate,
    required this.lastUpdate,
    this.notes,
    this.metadata,
  });

  /// Gain/Loss from NPS investment
  double get gainLoss => currentValue - totalContributed;

  /// Gain/Loss percentage
  double get gainLossPercent =>
      totalContributed > 0 ? (gainLoss / totalContributed) * 100 : 0;

  /// Years until retirement
  int get yearsUntilRetirement {
    if (plannedRetirementDate == null) return 0;
    return plannedRetirementDate!.year - DateTime.now().year;
  }

  /// Projected value at retirement (simple: current + estimated returns)
  double get projectedMaturityValue => currentValue + estimatedReturns;

  /// Tax benefit under 80C (₹1,50,000 limit + ₹50,000 under 80CCD)
  double get tax80cBenefit => (totalContributed).clamp(0, 150000);
  double get tax80CCDBenefit => (totalContributed - 150000).clamp(0, 50000);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'prnNumber': prnNumber,
      'name': name,
      'nrn': nrn,
      'tier': tier.index,
      'accountType': accountType.index,
      'npsManager': npsManager.index,
      'schemeType': schemeType.index,
      'panNumber': panNumber,
      'totalContributed': totalContributed,
      'currentValue': currentValue,
      'contributions': contributions.map((c) => c.toMap()).toList(),
      'estimatedReturns': estimatedReturns,
      'withdrawalType': withdrawalType.index,
      'plannedRetirementDate': plannedRetirementDate?.toIso8601String(),
      'createdDate': createdDate.toIso8601String(),
      'lastUpdate': lastUpdate.toIso8601String(),
      'notes': notes,
      'metadata': metadata,
    };
  }

  factory NPSAccount.fromMap(Map<String, dynamic> map) {
    return NPSAccount(
      id: map['id'],
      prnNumber: map['prnNumber'],
      name: map['name'],
      nrn: map['nrn'],
      tier: NPSTier.values[map['tier'] as int],
      accountType: NPSAccountType.values[map['accountType'] as int],
      npsManager: NPSManager.values[map['npsManager'] as int],
      schemeType: NPSSchemeType.values[map['schemeType'] as int],
      panNumber: map['panNumber'],
      totalContributed: (map['totalContributed'] as num).toDouble(),
      currentValue: (map['currentValue'] as num).toDouble(),
      contributions: (map['contributions'] as List?)
              ?.map((c) => NPSContribution.fromMap(c as Map<String, dynamic>))
              .toList() ??
          [],
      estimatedReturns: (map['estimatedReturns'] as num).toDouble(),
      withdrawalType: NPSWithdrawalType.values[map['withdrawalType'] as int],
      plannedRetirementDate: map['plannedRetirementDate'] != null
          ? DateTime.parse(map['plannedRetirementDate'])
          : null,
      createdDate: DateTime.parse(map['createdDate']),
      lastUpdate: DateTime.parse(map['lastUpdate']),
      notes: map['notes'] as String?,
      metadata: map['metadata'] as Map<String, dynamic>?,
    );
  }

  String getTierLabel() =>
      tier == NPSTier.tier1 ? 'Tier 1 (Locked)' : 'Tier 2 (Flexible)';
  String getAccountTypeLabel() {
    switch (accountType) {
      case NPSAccountType.individual:
        return 'Individual';
      case NPSAccountType.nri:
        return 'NRI';
      case NPSAccountType.minor:
        return 'Minor';
      case NPSAccountType.huf:
        return 'HUF';
    }
  }

  String getSchemeTypeLabel() {
    switch (schemeType) {
      case NPSSchemeType.equity:
        return 'Equity (E)';
      case NPSSchemeType.debt:
        return 'Debt (D)';
      case NPSSchemeType.alternative:
        return 'Alternative (A)';
      case NPSSchemeType.gold:
        return 'Gold (G)';
    }
  }

  String getWithdrawalTypeLabel() {
    switch (withdrawalType) {
      case NPSWithdrawalType.immediate:
        return 'Immediate Annuity';
      case NPSWithdrawalType.staggered:
        return 'Staggered Withdrawal';
      case NPSWithdrawalType.none:
        return 'No Withdrawal Planned';
    }
  }
}
