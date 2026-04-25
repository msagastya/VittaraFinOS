import 'package:intl/intl.dart';

/// T-152: Centralised INR currency formatter that respects the user's
/// number format preference (Indian vs International).
///
/// Usage:
///   CurrencyFormatter.formatINR(1234567.50)   // "₹12,34,567"   (Indian)
///   CurrencyFormatter.formatINR(1234567.50,
///       indian: false)                         // "₹1,234,567"  (International)
///   CurrencyFormatter.formatINR(1234567.50,
///       short: true)                           // "₹12.3L"       (short Indian)
class CurrencyFormatter {
  CurrencyFormatter._();

  static final _indianFmt = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );
  static final _intlFmt = NumberFormat.currency(
    locale: 'en_US',
    symbol: '₹',
    decimalDigits: 0,
  );

  /// Formats [amount] as INR.
  ///
  /// [indian]: when true (default), uses Indian numbering (1,00,000).
  ///           when false, uses International (100,000).
  /// [short]:  when true, abbreviates — ₹1.2K, ₹3.4L, ₹1.2Cr.
  static String formatINR(double amount,
      {bool indian = true, bool short = false}) {
    if (short) return _shortFormat(amount);
    final fmt = indian ? _indianFmt : _intlFmt;
    return fmt.format(amount.abs());
  }

  static String _shortFormat(double amount) {
    final abs = amount.abs();
    final sign = amount < 0 ? '-' : '';
    if (abs >= 1e7) {
      final cr = abs / 1e7;
      return '${sign}₹${cr % 1 == 0 ? cr.toInt() : cr.toStringAsFixed(1)}Cr';
    }
    if (abs >= 1e5) {
      final lakh = abs / 1e5;
      return '${sign}₹${lakh % 1 == 0 ? lakh.toInt() : lakh.toStringAsFixed(1)}L';
    }
    if (abs >= 1e3) {
      final k = abs / 1e3;
      return '${sign}₹${k % 1 == 0 ? k.toInt() : k.toStringAsFixed(1)}K';
    }
    return '${sign}₹${abs.toInt()}';
  }
}
