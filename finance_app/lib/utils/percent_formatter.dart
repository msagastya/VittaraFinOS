/// Unified percentage formatter.
/// Use these helpers everywhere — never format inline with .toStringAsFixed() + '%'.
class PercentFormatter {
  PercentFormatter._();

  /// Format as percentage: 5.0 → "+5.00%", -2.5 → "-2.50%"
  /// Always shows sign prefix.
  static String format(double value, {int decimals = 2}) {
    return '${value >= 0 ? '+' : ''}${value.toStringAsFixed(decimals)}%';
  }

  /// Format as absolute percentage (no sign): 5.0 → "5.00%", -2.5 → "2.50%"
  static String formatAbs(double value, {int decimals = 2}) {
    return '${value.abs().toStringAsFixed(decimals)}%';
  }

  /// Format as plain percentage: 5.0 → "5%", -2.5 → "-2.5%"
  /// Trims trailing zeros.
  static String plain(double value, {int decimals = 2}) {
    final sign = value < 0 ? '-' : '';
    final formatted = value.abs().toStringAsFixed(decimals);
    final trimmed = formatted.contains('.')
        ? formatted.replaceAll(RegExp(r'\.?0+$'), '')
        : formatted;
    return '$sign$trimmed%';
  }
}
