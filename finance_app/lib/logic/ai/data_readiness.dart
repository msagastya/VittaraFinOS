import 'package:vittara_fin_os/logic/transaction_model.dart';

/// Tracks whether there is enough data for each AI feature to be meaningful.
///
/// AI features gate themselves on these flags — no empty insights, no predictions
/// from a single week of data, no habits triggered on day 1.
class DataReadiness {
  /// Minimum 20 transactions recorded.
  final bool hasBasicHistory;

  /// At least 14 days of transaction history span.
  final bool hasTwoWeeks;

  /// At least 30 days of transaction history.
  final bool hasOneMonth;

  /// At least 60 days — enough for pattern and seasonal detection.
  final bool hasTwoMonths;

  /// At least one account is set up.
  final bool hasAccount;

  /// Pattern detection and recurring tx detection can run.
  bool get canDetectPatterns => hasTwoWeeks && hasBasicHistory;

  /// Cashflow forecasting can run.
  bool get canForecast => hasOneMonth && hasBasicHistory;

  /// Habit observation engine can start watching.
  bool get canBuildHabits => hasTwoWeeks && hasBasicHistory;

  /// First habit question can be surfaced.
  bool get canSurfaceHabitQuestion => hasOneMonth && hasBasicHistory;

  /// Insights and narrative can be generated.
  bool get canGenerateInsights => hasOneMonth && hasBasicHistory;

  /// Anomaly detection can run (needs baseline).
  bool get canDetectAnomalies => hasTwoMonths && hasBasicHistory;

  /// Behavioral fingerprint can be computed.
  bool get canComputeFingerprint => hasOneMonth && hasBasicHistory;

  /// Financial health score can be shown.
  bool get canShowHealthScore => hasOneMonth && hasBasicHistory;

  /// Peer benchmarking can run.
  bool get canBenchmark => hasTwoMonths;

  const DataReadiness({
    required this.hasBasicHistory,
    required this.hasTwoWeeks,
    required this.hasOneMonth,
    required this.hasTwoMonths,
    required this.hasAccount,
  });

  /// Evaluates readiness from the current transaction list and account count.
  factory DataReadiness.evaluate({
    required List<Transaction> transactions,
    required int accountCount,
  }) {
    if (transactions.isEmpty) {
      return const DataReadiness(
        hasBasicHistory: false,
        hasTwoWeeks: false,
        hasOneMonth: false,
        hasTwoMonths: false,
        hasAccount: false,
      );
    }

    final now = DateTime.now();
    final sorted = [...transactions]
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    final oldest = sorted.first.dateTime;
    final spanDays = now.difference(oldest).inDays;

    return DataReadiness(
      hasBasicHistory: transactions.length >= 20,
      hasTwoWeeks: spanDays >= 14,
      hasOneMonth: spanDays >= 30,
      hasTwoMonths: spanDays >= 60,
      hasAccount: accountCount >= 1,
    );
  }

  /// Human-readable summary of what's still needed for a feature.
  String missingDescription(String feature) {
    final parts = <String>[];
    if (!hasBasicHistory) parts.add('at least 20 transactions');
    if (!hasTwoWeeks) parts.add('at least 14 days of history');
    if (!hasOneMonth) parts.add('at least 30 days of history');
    if (!hasTwoMonths) parts.add('at least 60 days of history');
    if (parts.isEmpty) return '$feature is ready';
    return '$feature needs ${parts.join(' and ')}';
  }

  /// Days until the basic 30-day threshold is met, given the oldest transaction.
  int daysUntilOneMonth(DateTime? oldestTransactionDate) {
    if (oldestTransactionDate == null) return 30;
    final spanDays =
        DateTime.now().difference(oldestTransactionDate).inDays;
    return (30 - spanDays).clamp(0, 30);
  }
}
