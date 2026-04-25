import 'dart:math' as math;

/// T-122: XIRR (Extended Internal Rate of Return) calculator.
///
/// Uses Newton-Raphson iteration to find the annualized rate of return
/// given a series of dated cashflows.
///
/// Cashflow conventions:
///   - Negative  = cash paid out (investments / purchases)
///   - Positive  = cash received (redemptions / maturity proceeds)
///
/// Example:
///   final rate = XirrCalculator.compute([
///     (DateTime(2022, 1, 1), -100000),   // initial investment
///     (DateTime(2024, 1, 1),  130000),   // redemption
///   ]);
///   // → ~0.1401  (≈ 14% p.a.)
class XirrCalculator {
  XirrCalculator._();

  static const int _maxIterations = 100;
  static const double _tolerance = 1e-7;
  static const double _guess = 0.1; // initial rate guess: 10%

  /// Compute XIRR for a list of (date, cashflow) pairs.
  ///
  /// Returns the annualized IRR as a decimal (e.g. 0.14 = 14%).
  /// Returns null if:
  ///   - There are fewer than 2 cashflows
  ///   - All cashflows have the same sign (no solution exists)
  ///   - Newton-Raphson fails to converge
  static double? compute(List<(DateTime date, double cashflow)> cashflows) {
    if (cashflows.length < 2) return null;

    final hasPositive = cashflows.any((c) => c.$2 > 0);
    final hasNegative = cashflows.any((c) => c.$2 < 0);
    if (!hasPositive || !hasNegative) return null;

    // Sort by date
    final sorted = List.of(cashflows)
      ..sort((a, b) => a.$1.compareTo(b.$1));

    final t0 = sorted.first.$1;
    // Year fractions from the first cashflow date
    final yearFracs = sorted
        .map((c) => c.$1.difference(t0).inDays / 365.0)
        .toList();

    double rate = _guess;

    for (int iter = 0; iter < _maxIterations; iter++) {
      double npv = 0;
      double dnpv = 0; // derivative

      for (int i = 0; i < sorted.length; i++) {
        final cf = sorted[i].$2;
        final t = yearFracs[i];
        final denom = math.pow(1 + rate, t);
        npv += cf / denom;
        if (t != 0) dnpv -= t * cf / (math.pow(1 + rate, t + 1));
      }

      if (dnpv.abs() < 1e-12) return null; // derivative near zero, give up

      final newRate = rate - npv / dnpv;

      if ((newRate - rate).abs() < _tolerance) {
        return newRate.isFinite ? newRate : null;
      }

      rate = newRate;

      // Guard against divergence
      if (rate < -0.9999 || rate > 100 || rate.isNaN) return null;
    }

    return null; // did not converge
  }

  /// Convenience: format XIRR as a percentage string, e.g. "14.2% p.a."
  static String format(double? xirr) {
    if (xirr == null) return '—';
    final pct = xirr * 100;
    return '${pct >= 0 ? '' : ''}${pct.toStringAsFixed(1)}% p.a.';
  }
}
