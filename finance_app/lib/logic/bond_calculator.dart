import 'dart:math';

class BondCalculator {
  /// Calculates Yield to Maturity using Newton-Raphson iteration.
  ///
  /// Returns the annual YTM as a decimal (e.g. 0.065 = 6.5%).
  /// Falls back to [couponRate] when inputs are degenerate.
  static double calculateYieldToMaturity({
    required double faceValue,
    required double couponRate,
    required double marketPrice,
    required double yearsToMaturity,
    int paymentsPerYear = 1,
  }) {
    if (yearsToMaturity <= 0 || marketPrice <= 0 || faceValue <= 0) {
      return couponRate;
    }
    final coupon = faceValue * couponRate / paymentsPerYear;
    final n = (yearsToMaturity * paymentsPerYear).round();
    if (n <= 0) return couponRate;

    double ytm = couponRate;
    for (int i = 0; i < 100; i++) {
      final r = ytm / paymentsPerYear;
      double pv = 0;
      double dpv = 0;
      for (int t = 1; t <= n; t++) {
        final disc = pow(1 + r, t);
        pv += coupon / disc;
        dpv -= t * coupon / (disc * (1 + r));
      }
      final maturityDisc = pow(1 + r, n);
      pv += faceValue / maturityDisc;
      dpv -= n * faceValue / (maturityDisc * (1 + r));
      pv -= marketPrice;
      if (dpv.abs() < 1e-10) break;
      ytm -= (pv / dpv) / paymentsPerYear;
      if (ytm < 0) ytm = 0.001;
    }
    return ytm;
  }
}
