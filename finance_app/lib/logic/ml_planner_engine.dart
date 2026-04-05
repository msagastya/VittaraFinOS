// ─────────────────────────────────────────────────────────────────────────────
// MLPlannerEngine — pure Dart, on-device statistical ML for financial planning.
//
// No external packages. No internet. No pre-trained model files.
// Algorithms: OLS linear regression, exponential smoothing, normal CDF
// approximation, seasonality index, variance-based completion probability.
//
// Minimum data requirement: 3 months of transactions for any ML output.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:math' as math;
import 'package:vittara_fin_os/logic/transaction_model.dart';

/// One calendar month's aggregated financials.
class MonthlyDataPoint {
  final int year;
  final int month;
  final double income;
  final double expenses;
  double get savings => (income - expenses).clamp(0.0, double.infinity);

  const MonthlyDataPoint({
    required this.year,
    required this.month,
    required this.income,
    required this.expenses,
  });
}

/// Output of the ML layer — all fields are nullable when data is insufficient.
class MLAnalysis {
  /// Whether there is enough data (≥3 months) to produce meaningful output.
  final bool dataSufficient;

  /// Number of months of transaction history available.
  final int dataMonths;

  /// ML-predicted next-month income (exponential-smoothed + linear trend blend).
  final double? predictedIncome;

  /// ML-predicted next-month expenses.
  final double? predictedExpenses;

  /// ML-predicted next-month savings (derived from above).
  final double? predictedSavings;

  /// Monthly savings trend slope (₹/month). Positive = improving, negative = declining.
  final double? trendSlope;

  /// R² of the savings trend regression (0–1). ≥0.6 = reliable trend.
  final double? trendRSquared;

  /// 0–1 probability of completing the goal on time given savings variance.
  /// Null when target is not set or data is insufficient.
  final double? goalCompletionProbability;

  /// Confidence interval for months to goal completion.
  /// low = optimistic (75th percentile savings), high = conservative (25th percentile).
  final ({int low, int mid, int high})? completionMonthsRange;

  /// Seasonal multiplier for the next 3 calendar months (avg).
  /// >1.0 = typically a higher-spend period, <1.0 = lighter.
  final double? upcomingSeasonalMultiplier;

  /// Human-readable insight about the savings trend, or null.
  final String? trendInsight;

  /// Human-readable seasonal warning for the next ~3 months, or null.
  final String? seasonalWarning;

  const MLAnalysis({
    required this.dataSufficient,
    required this.dataMonths,
    this.predictedIncome,
    this.predictedExpenses,
    this.predictedSavings,
    this.trendSlope,
    this.trendRSquared,
    this.goalCompletionProbability,
    this.completionMonthsRange,
    this.upcomingSeasonalMultiplier,
    this.trendInsight,
    this.seasonalWarning,
  });

  static const insufficient = MLAnalysis(dataSufficient: false, dataMonths: 0);
}

class MLPlannerEngine {
  MLPlannerEngine._();

  static const int _minMonths = 3;

  // ── Public entry point ───────────────────────────────────────────────────

  static MLAnalysis analyze({
    required List<Transaction> transactions,
    required double currentSaved,
    double? targetAmount,
    int? monthsRemaining,
  }) {
    final history = _buildMonthlyHistory(transactions);
    if (history.length < _minMonths) {
      return MLAnalysis(dataSufficient: false, dataMonths: history.length);
    }

    // Extract sorted time-series (oldest → newest)
    final sorted = history.values.toList()
      ..sort((a, b) => DateTime(a.year, a.month)
          .compareTo(DateTime(b.year, b.month)));

    final incomeHistory  = sorted.map((m) => m.income).toList();
    final expenseHistory = sorted.map((m) => m.expenses).toList();
    final savingsHistory = sorted.map((m) => m.savings).toList();

    // ── Predictions ──────────────────────────────────────────────────────
    final predictedIncome   = _predictNext(incomeHistory);
    final predictedExpenses = _predictNext(expenseHistory);
    final predictedSavings  =
        (predictedIncome - predictedExpenses).clamp(0.0, double.infinity);

    // ── Savings trend ────────────────────────────────────────────────────
    final reg = _linearRegression(savingsHistory);
    final trendSlope   = reg.slope;
    final trendRSq     = reg.rSquared;
    final trendInsight = _trendInsight(savingsHistory, trendSlope, trendRSq);

    // ── Goal probability & range ──────────────────────────────────────────
    double? prob;
    ({int low, int mid, int high})? range;
    if (targetAmount != null && targetAmount > 0 && monthsRemaining != null &&
        monthsRemaining > 0) {
      final remaining =
          (targetAmount - currentSaved).clamp(0.0, double.infinity);
      prob = _goalCompletionProbability(
        remaining: remaining,
        monthlySavings: savingsHistory,
        monthsRemaining: monthsRemaining,
        predictedSavings: predictedSavings,
      );
      range = _completionRange(
        remaining: remaining,
        monthlySavings: savingsHistory,
        predictedSavings: predictedSavings,
      );
    }

    // ── Seasonality ───────────────────────────────────────────────────────
    final now = DateTime.now();
    final upcomingMonths = [
      ((now.month) % 12) + 1,
      ((now.month + 1) % 12) + 1,
      ((now.month + 2) % 12) + 1,
    ];
    final seasonalMultipliers =
        upcomingMonths.map((m) => _seasonalMultiplier(sorted, m)).toList();
    final avgUpcomingSeasonal =
        seasonalMultipliers.reduce((a, b) => a + b) / 3;
    final seasonalWarning = _seasonalWarning(sorted, upcomingMonths, now);

    return MLAnalysis(
      dataSufficient: true,
      dataMonths: history.length,
      predictedIncome: predictedIncome,
      predictedExpenses: predictedExpenses,
      predictedSavings: predictedSavings,
      trendSlope: trendSlope,
      trendRSquared: trendRSq,
      goalCompletionProbability: prob,
      completionMonthsRange: range,
      upcomingSeasonalMultiplier: avgUpcomingSeasonal,
      trendInsight: trendInsight,
      seasonalWarning: seasonalWarning,
    );
  }

  // ── Monthly history builder ───────────────────────────────────────────────

  static Map<String, MonthlyDataPoint> _buildMonthlyHistory(
      List<Transaction> transactions) {
    final Map<String, ({double income, double expenses})> buckets = {};

    for (final tx in transactions) {
      final key =
          '${tx.dateTime.year}-${tx.dateTime.month.toString().padLeft(2, '0')}';
      final cur = buckets[key] ?? (income: 0.0, expenses: 0.0);
      if (tx.type == TransactionType.income ||
          tx.type == TransactionType.cashback) {
        buckets[key] = (income: cur.income + tx.amount.abs(), expenses: cur.expenses);
      } else if (tx.type == TransactionType.expense) {
        buckets[key] = (income: cur.income, expenses: cur.expenses + tx.amount.abs());
      }
    }

    // Keep months that have at least some income or expense data
    final result = <String, MonthlyDataPoint>{};
    for (final entry in buckets.entries) {
      final parts = entry.key.split('-');
      if (parts.length == 2) {
        final year = int.tryParse(parts[0]);
        final month = int.tryParse(parts[1]);
        if (year != null && month != null) {
          result[entry.key] = MonthlyDataPoint(
            year: year,
            month: month,
            income: entry.value.income,
            expenses: entry.value.expenses,
          );
        }
      }
    }
    return result;
  }

  // ── Exponential smoothing + linear trend blend (Holt's method) ────────────
  //
  // Blends EMA (weight = 0.4) with the linear extrapolation of the last
  // regression. EMA alone is reactive; regression alone can extrapolate badly.
  // The blend is robust with only 3–12 data points.

  static double _predictNext(List<double> series) {
    if (series.isEmpty) return 0;
    if (series.length == 1) return series.first;

    // Exponential moving average (alpha = 0.35 — moderate recency weight)
    const alpha = 0.35;
    double ema = series.first;
    for (int i = 1; i < series.length; i++) {
      ema = alpha * series[i] + (1 - alpha) * ema;
    }

    // Linear regression extrapolation
    final reg = _linearRegression(series);
    final linNext = reg.intercept + reg.slope * series.length;

    // Blend: if R² is high, trust the trend more; if low, lean on EMA.
    final rSqClamped = reg.rSquared.clamp(0.0, 1.0);
    final blended = rSqClamped * linNext + (1 - rSqClamped) * ema;

    // Never predict below zero for income/expenses
    return blended.clamp(0.0, double.infinity);
  }

  // ── OLS Linear regression ─────────────────────────────────────────────────
  //
  // y = slope * x + intercept, where x is the month index (0, 1, 2 ...)

  static ({double slope, double intercept, double rSquared}) _linearRegression(
      List<double> y) {
    final n = y.length;
    if (n < 2) return (slope: 0, intercept: y.isEmpty ? 0 : y.first, rSquared: 0);

    double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
    for (int i = 0; i < n; i++) {
      sumX  += i;
      sumY  += y[i];
      sumXY += i * y[i];
      sumX2 += i * i.toDouble();
    }
    final denom = n * sumX2 - sumX * sumX;
    if (denom == 0) return (slope: 0, intercept: sumY / n, rSquared: 0);

    final slope     = (n * sumXY - sumX * sumY) / denom;
    final intercept = (sumY - slope * sumX) / n;

    // R² = 1 - SS_res / SS_tot
    final yMean  = sumY / n;
    double ssTot = 0, ssRes = 0;
    for (int i = 0; i < n; i++) {
      ssTot += (y[i] - yMean) * (y[i] - yMean);
      final yHat = slope * i + intercept;
      ssRes += (y[i] - yHat) * (y[i] - yHat);
    }
    final rSq = ssTot > 0 ? (1 - ssRes / ssTot).clamp(0.0, 1.0) : 0.0;
    return (slope: slope, intercept: intercept, rSquared: rSq);
  }

  // ── Standard deviation ────────────────────────────────────────────────────

  static double _stdDev(List<double> series) {
    if (series.length < 2) return 0;
    final mean = series.reduce((a, b) => a + b) / series.length;
    final variance =
        series.map((x) => (x - mean) * (x - mean)).reduce((a, b) => a + b) /
            (series.length - 1);
    return math.sqrt(variance);
  }

  // ── Goal completion probability ───────────────────────────────────────────
  //
  // Models total accumulated savings over N months as approximately Normal
  // (Central Limit Theorem). P(total >= remaining) via standard normal CDF.
  //
  // This is the same model used in actuarial financial planning tools.

  static double _goalCompletionProbability({
    required double remaining,
    required List<double> monthlySavings,
    required int monthsRemaining,
    required double predictedSavings,
  }) {
    if (monthsRemaining <= 0) return remaining <= 0 ? 1.0 : 0.0;
    if (remaining <= 0) return 1.0;

    final mean = predictedSavings;
    final std  = _stdDev(monthlySavings);

    // Total savings over N months: Normal(N*mean, sqrt(N)*std)
    final totalMean = monthsRemaining * mean;
    final totalStd  = math.sqrt(monthsRemaining.toDouble()) * std;

    if (totalStd <= 0) return totalMean >= remaining ? 1.0 : 0.0;

    // P(X >= remaining) = 1 - Φ(z)  where z = (remaining - totalMean) / totalStd
    final z = (remaining - totalMean) / totalStd;
    return (1.0 - _standardNormalCDF(z)).clamp(0.0, 1.0);
  }

  // ── Completion months — confidence interval ───────────────────────────────
  //
  // Uses savings std-dev to produce an (optimistic, expected, conservative)
  // range. 0.675 * σ = 75th/25th percentile of a normal distribution.

  static ({int low, int mid, int high}) _completionRange({
    required double remaining,
    required List<double> monthlySavings,
    required double predictedSavings,
  }) {
    final std = _stdDev(monthlySavings);

    int months(double s) {
      if (s <= 0) return 999;
      return (remaining / s).ceil();
    }

    final optimistic   = math.max(predictedSavings + 0.675 * std, predictedSavings * 1.05);
    final pessimistic  = math.max(predictedSavings - 0.675 * std, predictedSavings * 0.20);

    return (
      low:  months(optimistic),
      mid:  months(predictedSavings),
      high: months(pessimistic),
    );
  }

  // ── Seasonality index ─────────────────────────────────────────────────────
  //
  // Computes the average expense for a given calendar month (1–12) divided
  // by the overall monthly average. 1.3 means that month is 30% more expensive
  // on average.

  static double _seasonalMultiplier(
      List<MonthlyDataPoint> sorted, int calendarMonth) {
    final overallAvg = sorted.isEmpty
        ? 0.0
        : sorted.map((m) => m.expenses).reduce((a, b) => a + b) / sorted.length;
    if (overallAvg <= 0) return 1.0;

    final sameMonthEntries =
        sorted.where((m) => m.month == calendarMonth).toList();
    if (sameMonthEntries.isEmpty) return 1.0;

    final monthAvg = sameMonthEntries.map((m) => m.expenses).reduce((a, b) => a + b) /
        sameMonthEntries.length;
    return (monthAvg / overallAvg).clamp(0.1, 5.0);
  }

  static final _monthNames = [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  // ── Human-readable insights ───────────────────────────────────────────────

  static String? _trendInsight(
      List<double> savingsHistory, double slope, double rSq) {
    if (savingsHistory.length < 3) return null;
    final mean = savingsHistory.reduce((a, b) => a + b) / savingsHistory.length;
    if (mean <= 0) return null;

    final slopeAsPercent = slope / mean;
    // Only report trend if R² ≥ 0.35 (trend explains at least 35% of variance)
    if (rSq < 0.35) {
      return 'Your savings are variable — no clear trend yet.';
    }
    if (slopeAsPercent > 0.05) {
      return 'Savings trending up ↑ by ₹${_fmtNum(slope.abs())}/month over the last ${savingsHistory.length} months.';
    }
    if (slopeAsPercent < -0.05) {
      return 'Savings trending down ↓ by ₹${_fmtNum(slope.abs())}/month. Address this before it widens the gap.';
    }
    return 'Savings are stable — consistent month-to-month.';
  }

  static String? _seasonalWarning(
    List<MonthlyDataPoint> sorted,
    List<int> upcomingMonths,
    DateTime now,
  ) {
    if (sorted.length < 12) return null; // need a full year to judge seasonality

    final highSpendMonths = upcomingMonths
        .where((m) => _seasonalMultiplier(sorted, m) >= 1.20)
        .toList();
    if (highSpendMonths.isEmpty) return null;

    final names = highSpendMonths.map((m) => _monthNames[m]).join(', ');
    final pct = ((highSpendMonths
                    .map((m) => _seasonalMultiplier(sorted, m))
                    .reduce((a, b) => a + b) /
                highSpendMonths.length -
            1) *
        100).round();

    return '$names ${highSpendMonths.length == 1 ? 'is' : 'are'} historically ~$pct% higher spend for you. '
        'Factor this into your plan this quarter.';
  }

  static String _fmtNum(double v) =>
      v >= 1e5 ? '${(v / 1e5).toStringAsFixed(1)}L' : v.toStringAsFixed(0);

  // ── Standard normal CDF (Abramowitz & Stegun approximation, error < 7.5e-8) ─
  //
  // Reference: Handbook of Mathematical Functions, formula 26.2.17.

  static double _standardNormalCDF(double z) {
    const a1 =  0.254829592;
    const a2 = -0.284496736;
    const a3 =  1.421413741;
    const a4 = -1.453152027;
    const a5 =  1.061405429;
    const p  =  0.3275911;

    final sign = z < 0 ? -1.0 : 1.0;
    final x = z.abs() / math.sqrt(2);
    final t = 1.0 / (1.0 + p * x);
    final y = 1.0 -
        (((((a5 * t + a4) * t) + a3) * t + a2) * t + a1) *
            t *
            math.exp(-x * x);
    return 0.5 * (1.0 + sign * y);
  }
}
