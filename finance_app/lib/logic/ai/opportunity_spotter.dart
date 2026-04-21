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
  }) {
    final tips = <OpportunityTip>[];

    tips.addAll(_checkIdleCash(accountBalances, transactions));
    if (patterns != null) {
      tips.addAll(_checkSubscriptions(patterns, transactions));
    }
    tips.addAll(_checkEmergencyFund(accountBalances, transactions));
    tips.addAll(_checkInvestmentGap(transactions));

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

  // ── Helpers ───────────────────────────────────────────────────────────────

  static String _compact(double amount) {
    if (amount >= 100000) return '${(amount / 100000).toStringAsFixed(1)}L';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(0)}K';
    return amount.toInt().toString();
  }
}
