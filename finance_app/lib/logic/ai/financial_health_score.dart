import 'package:vittara_fin_os/logic/goal_model.dart';
import 'package:vittara_fin_os/logic/transaction_model.dart';
import 'predicted_calendar.dart';

enum ScoreTrend { improving, stable, declining }

/// One scored dimension of financial health.
class HealthDimension {
  final String id;
  final String name;
  final String description;
  final double score; // 0–100
  final ScoreTrend trend;
  final String actionSentence; // single actionable suggestion
  /// T-096: 2-3 specific data-driven reasons for this score.
  final List<String> reasons;
  /// T-096: One concrete improvement tip.
  final String improvementTip;

  const HealthDimension({
    required this.id,
    required this.name,
    required this.description,
    required this.score,
    required this.trend,
    required this.actionSentence,
    this.reasons = const [],
    String? improvementTip,
  }) : improvementTip = improvementTip ?? actionSentence;
}

/// Complete 6-dimension financial health scorecard.
class FinancialHealthScore {
  final HealthDimension cashFlow;
  final HealthDimension savingsDiscipline;
  final HealthDimension debtPosture;
  final HealthDimension goalMomentum;
  final HealthDimension investmentConsistency;
  final HealthDimension emergencyBuffer;
  final DateTime computedAt;

  const FinancialHealthScore({
    required this.cashFlow,
    required this.savingsDiscipline,
    required this.debtPosture,
    required this.goalMomentum,
    required this.investmentConsistency,
    required this.emergencyBuffer,
    required this.computedAt,
  });

  List<HealthDimension> get dimensions => [
        cashFlow,
        savingsDiscipline,
        debtPosture,
        goalMomentum,
        investmentConsistency,
        emergencyBuffer,
      ];

  /// Weighted overall score (0–100).
  double get overallScore {
    const weights = [0.20, 0.20, 0.15, 0.15, 0.15, 0.15];
    final scores = [
      cashFlow.score,
      savingsDiscipline.score,
      debtPosture.score,
      goalMomentum.score,
      investmentConsistency.score,
      emergencyBuffer.score,
    ];
    double total = 0;
    for (int i = 0; i < scores.length; i++) {
      total += scores[i] * weights[i];
    }
    return total.clamp(0.0, 100.0);
  }

  ScoreTrend get overallTrend {
    final improving =
        dimensions.where((d) => d.trend == ScoreTrend.improving).length;
    final declining =
        dimensions.where((d) => d.trend == ScoreTrend.declining).length;
    if (improving > declining) return ScoreTrend.improving;
    if (declining > improving) return ScoreTrend.declining;
    return ScoreTrend.stable;
  }

  String get overallLabel {
    final s = overallScore;
    if (s >= 80) return 'Excellent';
    if (s >= 65) return 'Good';
    if (s >= 45) return 'Fair';
    return 'Needs Attention';
  }
}

/// Computes a FinancialHealthScore from available data.
class FinancialHealthScorer {
  FinancialHealthScorer._();

  static FinancialHealthScore compute({
    required List<Transaction> transactions,
    required Map<String, double> accountBalances,
    required List<Goal> goals,
    List<PredictedTransaction>? predictedCalendar,
  }) {
    final now = DateTime.now();
    final cut3 = now.subtract(const Duration(days: 90));
    final cut6 = now.subtract(const Duration(days: 180));

    final recent3 = transactions.where((t) => t.dateTime.isAfter(cut3)).toList();
    final recent6 = transactions.where((t) => t.dateTime.isAfter(cut6)).toList();

    return FinancialHealthScore(
      cashFlow: _scoreCashFlow(recent3, recent6, predictedCalendar),
      savingsDiscipline: _scoreSavings(recent6),
      debtPosture: _scoreDebt(recent3),
      goalMomentum: _scoreGoals(goals),
      investmentConsistency: _scoreInvestments(recent6),
      emergencyBuffer: _scoreEmergencyBuffer(accountBalances, recent3),
      computedAt: now,
    );
  }

  // ── Cash Flow Health ──────────────────────────────────────────────────────

  static HealthDimension _scoreCashFlow(
    List<Transaction> recent3,
    List<Transaction> recent6,
    List<PredictedTransaction>? calendar,
  ) {
    final income3 = recent3
        .where((t) => t.type == TransactionType.income)
        .fold(0.0, (s, t) => s + t.amount);
    final expense3 = recent3
        .where((t) => t.type == TransactionType.expense)
        .fold(0.0, (s, t) => s + t.amount.abs());

    if (income3 == 0) {
      return const HealthDimension(
        id: 'cash_flow',
        name: 'Cash Flow',
        description: 'Income predictability vs expense volatility',
        score: 40,
        trend: ScoreTrend.stable,
        actionSentence: 'Log your income regularly to improve this score.',
      );
    }

    final ratio = income3 / expense3.clamp(1.0, double.infinity);

    // Monthly income variance
    final monthlyIncome = <int, double>{};
    for (final t in recent6.where((t) => t.type == TransactionType.income)) {
      final key = t.dateTime.year * 12 + t.dateTime.month;
      monthlyIncome[key] = (monthlyIncome[key] ?? 0) + t.amount;
    }
    final incomeVariance = _coefficientOfVariation(monthlyIncome.values.toList());

    double score = 50;
    if (ratio >= 1.5) score += 30;
    else if (ratio >= 1.2) score += 20;
    else if (ratio >= 1.0) score += 10;
    else score -= 20;

    if (incomeVariance < 0.1) score += 20;
    else if (incomeVariance < 0.25) score += 10;
    else score -= 10;

    score = score.clamp(0.0, 100.0);

    final trend = ratio >= 1.3 ? ScoreTrend.improving : ScoreTrend.stable;

    final ratioStr = ratio.toStringAsFixed(2);
    final varianceStr = (incomeVariance * 100).toStringAsFixed(0);
    return HealthDimension(
      id: 'cash_flow',
      name: 'Cash Flow',
      description: 'Income predictability vs expense volatility',
      score: score,
      trend: trend,
      actionSentence: ratio < 1.1
          ? 'Expenses are close to income — aim to keep a 20% buffer.'
          : 'Cash flow is healthy. Maintain consistent income logging.',
      reasons: [
        'Income/expense ratio: ${ratioStr}x over the last 3 months',
        'Income variance: ${varianceStr}% — ${incomeVariance < 0.15 ? 'very consistent' : incomeVariance < 0.3 ? 'moderate variability' : 'high variability'}',
        ratio >= 1.3 ? 'Comfortable buffer — income well above expenses' : 'Buffer is thin — income and expenses are close',
      ],
      improvementTip: ratio < 1.1
          ? 'Expenses are close to income — aim to keep a 20% buffer.'
          : 'Cash flow is healthy. Maintain consistent income logging.',
    );
  }

  // ── Savings Discipline ────────────────────────────────────────────────────

  static HealthDimension _scoreSavings(List<Transaction> recent6) {
    // Compute monthly savings rate for each of the last 6 months
    final now = DateTime.now();
    final monthRates = <double>[];

    for (int i = 0; i < 6; i++) {
      final month = DateTime(now.year, now.month - i, 1);
      final monthTx = recent6.where((t) =>
          t.dateTime.year == month.year &&
          t.dateTime.month == month.month);
      final inc = monthTx
          .where((t) => t.type == TransactionType.income)
          .fold(0.0, (s, t) => s + t.amount);
      final exp = monthTx
          .where((t) => t.type == TransactionType.expense)
          .fold(0.0, (s, t) => s + t.amount.abs());
      if (inc > 0) monthRates.add((inc - exp) / inc * 100);
    }

    if (monthRates.isEmpty) {
      return const HealthDimension(
        id: 'savings',
        name: 'Savings Discipline',
        description: 'Savings rate consistency over 6 months',
        score: 30,
        trend: ScoreTrend.stable,
        actionSentence: 'Log income and expenses consistently to track savings.',
      );
    }

    final avgRate = monthRates.fold(0.0, (s, r) => s + r) / monthRates.length;
    final cv = _coefficientOfVariation(monthRates);

    double score = 0;
    if (avgRate >= 30) score = 90;
    else if (avgRate >= 20) score = 75;
    else if (avgRate >= 10) score = 55;
    else if (avgRate >= 0) score = 35;
    else score = 10;

    // Consistency bonus/penalty
    if (cv < 0.2) score += 10;
    else if (cv > 0.5) score -= 10;

    // Trend: last 2 months vs first 2 months
    ScoreTrend trend = ScoreTrend.stable;
    if (monthRates.length >= 4) {
      final recent = (monthRates[0] + monthRates[1]) / 2;
      final older = (monthRates[2] + monthRates[3]) / 2;
      if (recent > older + 3) trend = ScoreTrend.improving;
      else if (recent < older - 3) trend = ScoreTrend.declining;
    }

    final positiveMonths = monthRates.where((r) => r > 0).length;
    return HealthDimension(
      id: 'savings',
      name: 'Savings Discipline',
      description: 'Savings rate consistency over 6 months',
      score: score.clamp(0.0, 100.0),
      trend: trend,
      actionSentence: avgRate < 10
          ? 'Aim to save at least 10% of income each month as a baseline.'
          : avgRate < 20
              ? 'Good start. Pushing toward 20% would significantly strengthen your position.'
              : 'Strong savings rate. Keep the consistency going.',
      reasons: [
        'Average savings rate: ${avgRate.toStringAsFixed(0)}% over last ${monthRates.length} months',
        'Saved in $positiveMonths of ${monthRates.length} months',
        cv < 0.2 ? 'Very consistent savings pattern' : 'Savings rate varies month to month',
      ],
      improvementTip: avgRate < 10
          ? 'Aim to save at least 10% of income each month as a baseline.'
          : avgRate < 20
              ? 'Pushing toward 20% savings rate would significantly strengthen your position.'
              : 'Strong savings rate. Keep the consistency going.',
    );
  }

  // ── Debt Posture ──────────────────────────────────────────────────────────

  static HealthDimension _scoreDebt(List<Transaction> recent3) {
    final income = recent3
        .where((t) => t.type == TransactionType.income)
        .fold(0.0, (s, t) => s + t.amount);
    final borrowing = recent3
        .where((t) => t.type == TransactionType.borrowing)
        .fold(0.0, (s, t) => s + t.amount.abs());

    if (income == 0) {
      return const HealthDimension(
        id: 'debt',
        name: 'Debt Posture',
        description: 'Borrowing and obligations as a ratio of income',
        score: 60,
        trend: ScoreTrend.stable,
        actionSentence: 'No debt data available — score will improve as you log.',
      );
    }

    final debtRatio = borrowing / income;
    double score;
    if (debtRatio == 0) {
      score = 95;
    } else if (debtRatio < 0.1) {
      score = 80;
    } else if (debtRatio < 0.3) {
      score = 60;
    } else if (debtRatio < 0.5) {
      score = 40;
    } else {
      score = 20;
    }

    return HealthDimension(
      id: 'debt',
      name: 'Debt Posture',
      description: 'Borrowing and obligations as a ratio of income',
      score: score,
      trend: ScoreTrend.stable,
      reasons: [
        borrowing == 0
            ? 'No borrowing logged in the last 3 months'
            : 'Borrowed ₹${_fmt(borrowing)} vs ₹${_fmt(income)} income (${(debtRatio * 100).toStringAsFixed(0)}%)',
        debtRatio == 0
            ? 'Debt-free position — excellent financial posture'
            : debtRatio < 0.1
                ? 'Low debt-to-income ratio — well within safe range'
                : debtRatio < 0.3
                    ? 'Moderate debt level — manageable but worth monitoring'
                    : 'High debt-to-income ratio — above recommended 30% threshold',
      ],
      improvementTip: debtRatio > 0.3
          ? 'Borrowing above 30% of income — prioritise reducing this before new commitments.'
          : debtRatio > 0
              ? 'Manageable debt. Track repayments to avoid compounding.'
              : 'Debt-free — maintain this position by avoiding unnecessary credit.',
      actionSentence: debtRatio > 0.3
          ? 'Borrowing is above 30% of income — prioritise reducing this.'
          : debtRatio > 0
              ? 'Manageable debt level. Track repayments carefully.'
              : 'No borrowing logged — solid posture.',
    );
  }

  // ── Goal Momentum ─────────────────────────────────────────────────────────

  static HealthDimension _scoreGoals(List<Goal> goals) {
    final active = goals.where((g) => !g.isCompleted).toList();
    if (active.isEmpty) {
      return const HealthDimension(
        id: 'goals',
        name: 'Goal Momentum',
        description: 'On-track rate across all active goals',
        score: 50,
        trend: ScoreTrend.stable,
        actionSentence: 'Set a savings goal to start building momentum.',
      );
    }

    final onTrack = active.where((g) => g.isOnTrack).length;
    final rate = onTrack / active.length;
    final score = (rate * 100).clamp(0.0, 100.0);

    return HealthDimension(
      id: 'goals',
      name: 'Goal Momentum',
      description: 'On-track rate across all active goals',
      score: score,
      trend: rate >= 0.8 ? ScoreTrend.improving : ScoreTrend.stable,
      reasons: [
        '$onTrack of ${active.length} active goal${active.length > 1 ? 's' : ''} on track',
        rate == 1.0
            ? 'All goals progressing as planned'
            : '${active.length - onTrack} goal${(active.length - onTrack) > 1 ? 's' : ''} behind schedule',
        active.isNotEmpty
            ? 'Goals tracked: ${active.map((g) => g.name).take(3).join(', ')}${active.length > 3 ? '...' : ''}'
            : 'No active goals set',
      ],
      improvementTip: rate < 0.5
          ? 'Review under-funded goals and increase monthly contributions.'
          : rate < 1.0
              ? 'A small top-up this month could bring lagging goals back on track.'
              : 'All goals on track — maintain current contribution pace.',
      actionSentence: rate < 0.5
          ? '${active.length - onTrack} of your goals are behind schedule — review contributions.'
          : rate < 1.0
              ? '${active.length - onTrack} goal${(active.length - onTrack) > 1 ? 's' : ''} slightly off-track.'
              : 'All goals on track — great discipline.',
    );
  }

  // ── Investment Consistency ────────────────────────────────────────────────

  static HealthDimension _scoreInvestments(List<Transaction> recent6) {
    final income = recent6
        .where((t) => t.type == TransactionType.income)
        .fold(0.0, (s, t) => s + t.amount);
    final invested = recent6
        .where((t) => t.type == TransactionType.investment)
        .fold(0.0, (s, t) => s + t.amount.abs());

    if (income == 0) {
      return const HealthDimension(
        id: 'investments',
        name: 'Investment Consistency',
        description: 'SIP regularity and portfolio growth',
        score: 40,
        trend: ScoreTrend.stable,
        actionSentence: 'Log income to enable investment rate calculation.',
      );
    }

    final rate = invested / income;

    // Monthly investment consistency
    final now = DateTime.now();
    int monthsWithInvestment = 0;
    for (int i = 0; i < 6; i++) {
      final month = DateTime(now.year, now.month - i, 1);
      final hasInv = recent6.any((t) =>
          t.type == TransactionType.investment &&
          t.dateTime.year == month.year &&
          t.dateTime.month == month.month);
      if (hasInv) monthsWithInvestment++;
    }
    final consistency = monthsWithInvestment / 6.0;

    double score = 0;
    if (rate >= 0.20) score = 85;
    else if (rate >= 0.15) score = 72;
    else if (rate >= 0.10) score = 58;
    else if (rate >= 0.05) score = 40;
    else score = 20;

    // Consistency modifier
    score += (consistency - 0.5) * 20;
    score = score.clamp(0.0, 100.0);

    return HealthDimension(
      id: 'investments',
      name: 'Investment Consistency',
      description: 'SIP regularity and portfolio contributions',
      score: score,
      trend: consistency > 0.8 ? ScoreTrend.improving : ScoreTrend.stable,
      reasons: [
        'Invested in $monthsWithInvestment of last 6 months',
        'Investment rate: ${(rate * 100).toStringAsFixed(0)}% of income over 6 months',
        consistency >= 0.8
            ? 'Strong habit — investing regularly every month'
            : 'Inconsistent — missing some months breaks compound growth',
      ],
      improvementTip: rate < 0.10
          ? 'Start a SIP of even ₹500/month — consistency matters more than amount.'
          : consistency < 0.7
              ? 'Automate a monthly SIP to remove the decision each month.'
              : 'Strong habit. Consider increasing by 1% of income annually.',
      actionSentence: rate < 0.10
          ? 'Investing less than 10% of income — start a SIP to build this habit.'
          : consistency < 0.7
              ? 'Investment rate is good but irregular. Set up a monthly SIP for consistency.'
              : 'Strong and consistent investment habit.',
    );
  }

  // ── Emergency Buffer ──────────────────────────────────────────────────────

  static HealthDimension _scoreEmergencyBuffer(
    Map<String, double> accountBalances,
    List<Transaction> recent3,
  ) {
    final totalLiquid =
        accountBalances.values.fold(0.0, (s, v) => s + v);
    final monthlyExpense = recent3
            .where((t) => t.type == TransactionType.expense)
            .fold(0.0, (s, t) => s + t.amount.abs()) /
        3.0;

    if (monthlyExpense == 0) {
      return const HealthDimension(
        id: 'emergency',
        name: 'Emergency Buffer',
        description: 'Liquid savings vs 3-month expense cover',
        score: 50,
        trend: ScoreTrend.stable,
        actionSentence: 'Log expenses to calculate your emergency buffer.',
      );
    }

    final monthsCovered = totalLiquid / monthlyExpense;
    double score;
    if (monthsCovered >= 6) score = 95;
    else if (monthsCovered >= 3) score = 75;
    else if (monthsCovered >= 2) score = 55;
    else if (monthsCovered >= 1) score = 35;
    else score = 15;

    final gap = ((3 - monthsCovered) * monthlyExpense).clamp(0.0, double.infinity);

    return HealthDimension(
      id: 'emergency',
      name: 'Emergency Buffer',
      description: 'Liquid savings vs 3-month expense cover',
      score: score,
      trend: monthsCovered >= 3 ? ScoreTrend.stable : ScoreTrend.declining,
      reasons: [
        'Liquid balance: ₹${_fmt(totalLiquid)}',
        'Monthly expenses (avg): ₹${_fmt(monthlyExpense)}',
        monthsCovered < 1
            ? 'Buffer covers less than 1 month of expenses — critical gap'
            : 'Buffer covers ${monthsCovered.toStringAsFixed(1)} months of expenses (target: 3–6)',
      ],
      improvementTip: monthsCovered < 3
          ? 'Add ₹${_fmt(gap / 3)} per month for 3 months to reach a 3-month buffer.'
          : 'Buffer is healthy. Consider growing to 6 months for extra security.',
      actionSentence: monthsCovered < 3
          ? 'Buffer covers ${monthsCovered.toStringAsFixed(1)} months — target 3. Gap: ₹${_fmt(gap)}.'
          : 'Emergency buffer is healthy at ${monthsCovered.toStringAsFixed(1)} months.',
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static double _coefficientOfVariation(List<double> values) {
    if (values.length < 2) return 0;
    final mean = values.fold(0.0, (s, v) => s + v) / values.length;
    if (mean == 0) return 0;
    final variance = values.map((v) => (v - mean) * (v - mean)).fold(0.0, (s, v) => s + v) / values.length;
    return (variance < 1e-9 ? 0.0 : variance / (mean * mean));
  }

  static String _fmt(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
    return v.toInt().toString();
  }
}
