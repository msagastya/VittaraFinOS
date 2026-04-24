import 'package:vittara_fin_os/logic/investment_model.dart';
import 'package:vittara_fin_os/logic/transaction_model.dart';
import 'pattern_detector.dart';

enum OpportunityCategory {
  idleCash,
  budgetOptimization,
  investmentGap,
  subscriptionAudit,
  emergencyFund,
}

class OpportunityTip {
  final String id;
  final OpportunityCategory category;
  final String title;
  final String detail;       // specific numbers from user's actual data
  final String? actionLabel; // what to do about it
  final double potentialSavingOrGain; // ₹ estimate
  final double priority;     // 0.0–1.0, higher = surface first

  const OpportunityTip({
    required this.id,
    required this.category,
    required this.title,
    required this.detail,
    this.actionLabel,
    required this.potentialSavingOrGain,
    required this.priority,
  });
}

class OpportunitySpotter {
  OpportunitySpotter._();

  static const double _fdRate = 7.0;   // typical FD rate %
  static const double _savingsRate = 3.5; // typical savings account rate %
  static const double _idleThresholdDays = 30.0;
  static const double _idleThresholdAmount = 10000.0;

  static List<OpportunityTip> spot({
    required List<Transaction> transactions,
    required Map<String, double> accountBalances,
    SpendingPatterns? patterns,
    List<Investment>? investments,
    List<Map<String, dynamic>>? budgets,
  }) {
    final tips = <OpportunityTip>[];

    tips.addAll(_checkIdleCash(accountBalances, transactions));
    if (patterns != null) {
      tips.addAll(_checkSubscriptions(patterns, transactions));
      tips.addAll(_checkSubscriptionOverlap(patterns)); // T-100
    }
    tips.addAll(_checkEmergencyFund(accountBalances, transactions));
    tips.addAll(_checkInvestmentGap(transactions));
    if (investments != null) {
      tips.addAll(_checkFdMaturity(investments)); // T-098
    }
    if (budgets != null) {
      tips.addAll(_checkUnderusedBudget(budgets, transactions)); // T-099
    }
    tips.addAll(_checkSalaryDayInvestment(transactions)); // T-101

    // Sort by priority descending
    tips.sort((a, b) => b.priority.compareTo(a.priority));
    return tips;
  }

  // ── Idle cash opportunity ─────────────────────────────────────────────────

  static List<OpportunityTip> _checkIdleCash(
    Map<String, double> balances,
    List<Transaction> transactions,
  ) {
    final tips = <OpportunityTip>[];
    final now = DateTime.now();

    for (final entry in balances.entries) {
      final balance = entry.value;
      if (balance < _idleThresholdAmount) continue;

      // Check if this account has had any outflows recently
      final recentOutflows = transactions
          .where((t) =>
              (t.sourceAccountId == entry.key ||
                  t.metadata?['accountId'] == entry.key) &&
              t.type == TransactionType.expense &&
              t.dateTime.isAfter(now.subtract(
                  Duration(days: _idleThresholdDays.toInt()))))
          .length;

      if (recentOutflows == 0 && balance >= _idleThresholdAmount) {
        // Estimate annual gain from FD vs savings
        final interestDiff = balance * (_fdRate - _savingsRate) / 100;
        final quarterlyGain = interestDiff / 4;

        tips.add(OpportunityTip(
          id: 'idle_cash_${entry.key}',
          category: OpportunityCategory.idleCash,
          title: '₹${_compact(balance)} sitting idle',
          detail:
              'This balance hasn\'t moved in ${_idleThresholdDays.toInt()} days. '
              'Parking it in an FD at $_fdRate% vs savings at $_savingsRate% '
              'could earn ~₹${quarterlyGain.toInt()} extra per quarter.',
          actionLabel: 'Consider an FD',
          potentialSavingOrGain: quarterlyGain,
          priority: (balance / 100000).clamp(0.0, 1.0),
        ));
      }
    }

    return tips;
  }

  // ── Subscription audit ────────────────────────────────────────────────────

  static List<OpportunityTip> _checkSubscriptions(
    SpendingPatterns patterns,
    List<Transaction> transactions,
  ) {
    final tips = <OpportunityTip>[];
    final now = DateTime.now();

    // Find recurring subscriptions not used recently (no matching tx in 45+ days)
    final staleSubscriptions = patterns.recurring.where((r) {
      if (r.type != TransactionType.expense) return false;
      if (r.confidence < 0.6) return false;
      final daysSinceLastSeen = now.difference(r.lastSeen).inDays;
      return daysSinceLastSeen > 45 && r.intervalDays <= 35;
    }).toList();

    for (final sub in staleSubscriptions) {
      final annualCost = sub.typicalAmount * (365 / sub.intervalDays);
      tips.add(OpportunityTip(
        id: 'sub_${sub.merchantNormalized}',
        category: OpportunityCategory.subscriptionAudit,
        title: '${sub.merchantNormalized} may be unused',
        detail:
            'You last paid for ${sub.merchantNormalized} '
            '${now.difference(sub.lastSeen).inDays} days ago. '
            'That\'s ~₹${annualCost.toInt()}/year if still active.',
        actionLabel: 'Review subscription',
        potentialSavingOrGain: annualCost,
        priority: (annualCost / 10000).clamp(0.0, 0.7),
      ));
    }

    return tips;
  }

  // ── Emergency fund check ──────────────────────────────────────────────────

  static List<OpportunityTip> _checkEmergencyFund(
    Map<String, double> accountBalances,
    List<Transaction> transactions,
  ) {
    final now = DateTime.now();
    final recentExpenses = transactions
        .where((t) =>
            t.type == TransactionType.expense &&
            t.dateTime.isAfter(now.subtract(const Duration(days: 90))))
        .fold(0.0, (sum, t) => sum + t.amount);

    final monthlyAvgExpense = recentExpenses / 3;
    if (monthlyAvgExpense <= 0) return [];

    final recommendedBuffer = monthlyAvgExpense * 3;
    final totalLiquid = accountBalances.values
        .fold(0.0, (s, v) => s + v);

    if (totalLiquid < recommendedBuffer) {
      final gap = recommendedBuffer - totalLiquid;
      return [
        OpportunityTip(
          id: 'emergency_fund',
          category: OpportunityCategory.emergencyFund,
          title: 'Emergency fund gap',
          detail:
              'Your 3-month expense buffer should be ~₹${recommendedBuffer.toInt()} '
              '(based on ₹${monthlyAvgExpense.toInt()}/month average spend). '
              'You\'re currently ₹${gap.toInt()} short.',
          actionLabel: 'Build emergency fund',
          potentialSavingOrGain: gap,
          priority: (gap / recommendedBuffer).clamp(0.0, 0.8),
        ),
      ];
    }

    return [];
  }

  // ── Investment gap check ──────────────────────────────────────────────────

  static List<OpportunityTip> _checkInvestmentGap(
      List<Transaction> transactions) {
    final now = DateTime.now();
    final recentIncome = transactions
        .where((t) =>
            t.type == TransactionType.income &&
            t.dateTime.isAfter(now.subtract(const Duration(days: 90))))
        .fold(0.0, (s, t) => s + t.amount);

    final recentInvestments = transactions
        .where((t) =>
            t.type == TransactionType.investment &&
            t.dateTime.isAfter(now.subtract(const Duration(days: 90))))
        .fold(0.0, (s, t) => s + t.amount);

    if (recentIncome <= 0) return [];

    final investmentRate = recentInvestments / recentIncome;
    if (investmentRate < 0.10) {
      // Investing less than 10% of income
      final idealMonthly = (recentIncome / 3) * 0.15;
      final currentMonthly = recentInvestments / 3;
      final gap = idealMonthly - currentMonthly;

      return [
        OpportunityTip(
          id: 'investment_gap',
          category: OpportunityCategory.investmentGap,
          title: 'Investment rate below 10%',
          detail:
              'You\'re investing ${(investmentRate * 100).toStringAsFixed(1)}% '
              'of income (₹${currentMonthly.toInt()}/month). '
              'Increasing to 15% would add ~₹${gap.toInt()}/month to your portfolio.',
          actionLabel: 'Add a SIP or FD',
          potentialSavingOrGain: gap * 12,
          priority: 0.6,
        ),
      ];
    }

    return [];
  }

  // ── T-098: FD maturity check ──────────────────────────────────────────────

  static List<OpportunityTip> _checkFdMaturity(List<Investment> investments) {
    final tips = <OpportunityTip>[];
    final now = DateTime.now();
    final in30Days = now.add(const Duration(days: 30));

    for (final inv in investments) {
      if (inv.type != InvestmentType.fixedDeposit) continue;
      final maturityStr = inv.metadata?['maturityDate'] as String?;
      if (maturityStr == null) continue;
      DateTime maturityDate;
      try {
        maturityDate = DateTime.parse(maturityStr);
      } catch (_) {
        continue;
      }
      if (maturityDate.isAfter(now) && maturityDate.isBefore(in30Days)) {
        final daysLeft = maturityDate.difference(now).inDays;
        final bankName = inv.broker ?? inv.name;
        tips.add(OpportunityTip(
          id: 'fd_maturity_${inv.id}',
          category: OpportunityCategory.idleCash,
          title: '$bankName FD matures in $daysLeft days',
          detail: 'Your ${bankName} FD of ₹${_compact(inv.amount)} matures on '
              '${maturityDate.day}/${maturityDate.month}/${maturityDate.year}. '
              'Plan renewal or redeployment before it auto-renews.',
          actionLabel: 'Plan renewal',
          potentialSavingOrGain: inv.amount * 0.005, // approx 6mo interest on renewal
          priority: 0.85,
        ));
      }
    }
    return tips;
  }

  // ── T-099: Underused budget check ─────────────────────────────────────────

  static List<OpportunityTip> _checkUnderusedBudget(
    List<Map<String, dynamic>> budgets,
    List<Transaction> transactions,
  ) {
    final tips = <OpportunityTip>[];
    final now = DateTime.now();

    for (final b in budgets) {
      final category = b['category'] as String? ?? '';
      final limit = (b['amount'] as num?)?.toDouble() ?? 0;
      if (limit == 0) continue;

      // Check usage in last 3 months
      int underusedMonths = 0;
      for (int i = 1; i <= 3; i++) {
        final mDate = DateTime(now.year, now.month - i, 1);
        final spent = transactions
            .where((t) =>
                t.type == TransactionType.expense &&
                t.dateTime.year == mDate.year &&
                t.dateTime.month == mDate.month &&
                ((t.metadata?['categoryName'] as String?) ?? '') == category)
            .fold(0.0, (s, t) => s + t.amount.abs());
        if (spent < limit * 0.5) underusedMonths++;
      }

      if (underusedMonths >= 3) {
        // Find median spend across those 3 months
        final spends = <double>[];
        for (int i = 1; i <= 3; i++) {
          final mDate = DateTime(now.year, now.month - i, 1);
          final spent = transactions
              .where((t) =>
                  t.type == TransactionType.expense &&
                  t.dateTime.year == mDate.year &&
                  t.dateTime.month == mDate.month &&
                  ((t.metadata?['categoryName'] as String?) ?? '') == category)
              .fold(0.0, (s, t) => s + t.amount.abs());
          spends.add(spent);
        }
        spends.sort();
        final medianSpend = spends[1];
        final suggestedLimit = (medianSpend * 1.2).ceilToDouble();

        tips.add(OpportunityTip(
          id: 'underused_budget_$category',
          category: OpportunityCategory.budgetOptimization,
          title: '$category budget is barely used',
          detail: 'Your $category budget is ₹${_compact(limit)}/month but '
              'you\'ve used less than 50% for 3 months in a row. '
              'Lowering to ₹${_compact(suggestedLimit)} frees up mental overhead.',
          actionLabel: 'Adjust budget',
          potentialSavingOrGain: limit - suggestedLimit,
          priority: 0.5,
        ));
      }
    }
    return tips;
  }

  // ── T-100: Subscription overlap check ────────────────────────────────────

  static const _overlapPairs = [
    ['hotstar', 'jiocinema'],
    ['jiocinema', 'hotstar'],
    ['spotify', 'jiosaavn'],
    ['jiosaavn', 'spotify'],
    ['netflix', 'amazon prime'],
    ['amazon prime', 'netflix'],
    ['gaana', 'spotify'],
    ['gaana', 'jiosaavn'],
  ];

  static List<OpportunityTip> _checkSubscriptionOverlap(
      SpendingPatterns patterns) {
    final tips = <OpportunityTip>[];
    final activeSubscriptions = patterns.recurring
        .where((r) =>
            r.type == TransactionType.expense &&
            r.confidence >= 0.6 &&
            r.intervalDays <= 35)
        .map((r) => r.merchantNormalized.toLowerCase())
        .toSet();

    final foundOverlaps = <Set<String>>{};

    for (final pair in _overlapPairs) {
      final a = pair[0];
      final b = pair[1];
      final aMatch = activeSubscriptions.any((s) => s.contains(a));
      final bMatch = activeSubscriptions.any((s) => s.contains(b));
      if (aMatch && bMatch) {
        final key = {a, b};
        if (!foundOverlaps.any((k) => k.containsAll(key))) {
          foundOverlaps.add(key);
          // Find amounts
          final aSub = patterns.recurring.firstWhere(
              (r) => r.merchantNormalized.toLowerCase().contains(a),
              orElse: () => patterns.recurring.first);
          final bSub = patterns.recurring.firstWhere(
              (r) => r.merchantNormalized.toLowerCase().contains(b),
              orElse: () => patterns.recurring.first);
          final combinedMonthly = aSub.typicalAmount + bSub.typicalAmount;

          tips.add(OpportunityTip(
            id: 'sub_overlap_${a}_$b',
            category: OpportunityCategory.subscriptionAudit,
            title: 'Overlapping streaming services',
            detail:
                'You may be paying for overlapping services: ${aSub.merchantNormalized} '
                'and ${bSub.merchantNormalized}. '
                'Combined: ₹${_compact(combinedMonthly)}/month. '
                'Consider keeping only one.',
            actionLabel: 'Review subscriptions',
            potentialSavingOrGain: (aSub.typicalAmount < bSub.typicalAmount
                    ? aSub.typicalAmount
                    : bSub.typicalAmount) *
                12,
            priority: 0.65,
          ));
        }
      }
    }
    return tips;
  }

  // ── T-101: Salary day investment check ───────────────────────────────────

  static List<OpportunityTip> _checkSalaryDayInvestment(
      List<Transaction> transactions) {
    final now = DateTime.now();
    final recent90 = transactions
        .where((t) => t.dateTime.isAfter(now.subtract(const Duration(days: 90))))
        .toList();

    // Detect salary: recurring income >= ₹10K around month start/end
    final incomes = recent90
        .where((t) => t.type == TransactionType.income && t.amount >= 10000)
        .toList();

    if (incomes.isEmpty) return [];

    // Group by "salary day" — day of month with repeated large income
    final dayFreq = <int, int>{};
    for (final t in incomes) {
      final day = t.dateTime.day;
      // Treat days 28-31 as salary at "end of month"
      final normalizedDay = day >= 28 ? 28 : day;
      dayFreq[normalizedDay] = (dayFreq[normalizedDay] ?? 0) + 1;
    }

    final salaryDay = dayFreq.entries
        .where((e) => e.value >= 2)
        .fold<MapEntry<int, int>?>(
            null, (best, e) => best == null || e.value > best.value ? e : best);

    if (salaryDay == null) return [];

    // Check if any investment occurs within 3 days of salary day in last 3 months
    int monthsWithPostSalaryInvestment = 0;
    for (int i = 1; i <= 3; i++) {
      final mDate = DateTime(now.year, now.month - i, 1);
      final windowStart = DateTime(mDate.year, mDate.month, salaryDay.key);
      final windowEnd = windowStart.add(const Duration(days: 3));
      final hasInvestment = recent90.any((t) =>
          t.type == TransactionType.investment &&
          t.dateTime.isAfter(windowStart) &&
          t.dateTime.isBefore(windowEnd));
      if (hasInvestment) monthsWithPostSalaryInvestment++;
    }

    if (monthsWithPostSalaryInvestment == 0) {
      final salaryAmount = incomes
          .where((t) {
            final normalizedDay = t.dateTime.day >= 28 ? 28 : t.dateTime.day;
            return normalizedDay == salaryDay.key;
          })
          .fold(0.0, (s, t) => s + t.amount) /
          salaryDay.value;

      return [
        OpportunityTip(
          id: 'salary_day_investment',
          category: OpportunityCategory.investmentGap,
          title: 'Invest on salary day',
          detail: 'Your salary (~₹${_compact(salaryAmount)}) arrives around '
              'day ${salaryDay.key == 28 ? "end of month" : salaryDay.key.toString()} '
              'but no investment follows within 3 days. '
              'Setting up a SIP on salary day automates investing before spending.',
          actionLabel: 'Set up a SIP',
          potentialSavingOrGain: salaryAmount * 0.10 * 12, // 10% annual potential
          priority: 0.55,
        ),
      ];
    }
    return [];
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static String _compact(double amount) {
    if (amount >= 100000) return '${(amount / 100000).toStringAsFixed(1)}L';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(0)}K';
    return amount.toInt().toString();
  }
}
