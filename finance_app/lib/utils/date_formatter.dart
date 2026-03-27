/// Unified number / percentage formatter.
/// Use these helpers everywhere — never format inline with .toStringAsFixed().
class NumberFormatter {
  NumberFormatter._();

  /// Format as percentage: 5.0 → "5%", 5.234 → "5.23%", -2.5 → "-2.5%"
  static String percent(double value, {int decimals = 2}) {
    final sign = value < 0 ? '-' : '';
    final abs = value.abs();
    // Trim trailing zeros: 5.00% → 5%, 5.10% → 5.1%
    final formatted = abs.toStringAsFixed(decimals);
    final trimmed = formatted.contains('.')
        ? formatted.replaceAll(RegExp(r'\.?0+$'), '')
        : formatted;
    return '$sign$trimmed%';
  }

  /// Format as signed percentage: 5.0 → "+5%", -2.5 → "-2.5%"
  static String percentSigned(double value, {int decimals = 2}) {
    final sign = value >= 0 ? '+' : '';
    return '$sign${percent(value, decimals: decimals)}';
  }

  /// Normalize merchant name from ALL-CAPS SMS to Title Case.
  /// "ZOMATO INDIA" → "Zomato India", "starbucks" → "Starbucks"
  static String toTitleCase(String s) {
    if (s.isEmpty) return s;
    // If already mixed case, leave it alone
    if (s != s.toUpperCase() && s != s.toLowerCase()) return s;
    return s
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ')
        .trim();
  }
}

/// Compact Indian currency formatter.
/// ₹1,000 → ₹1K  |  ₹1,00,000 → ₹1L  |  ₹1,00,00,000 → ₹1Cr
class CurrencyFormatter {
  CurrencyFormatter._();

  /// Format amount as compact Indian notation (K / L / Cr).
  /// [decimals] controls decimal places in compact form.
  static String compact(double amount, {int decimals = 1}) {
    final sign = amount < 0 ? '-' : '';
    final abs = amount.abs();
    if (abs >= 1e7) {
      final v = abs / 1e7;
      return '$sign₹${_trim(v, decimals)}Cr';
    } else if (abs >= 1e5) {
      final v = abs / 1e5;
      return '$sign₹${_trim(v, decimals)}L';
    } else if (abs >= 1e3) {
      final v = abs / 1e3;
      return '$sign₹${_trim(v, decimals)}K';
    }
    return '$sign₹${abs.toStringAsFixed(0)}';
  }

  static String _trim(double v, int decimals) {
    final s = v.toStringAsFixed(decimals);
    // Remove trailing zeros after decimal point
    if (s.contains('.')) {
      return s.replaceAll(RegExp(r'\.?0+$'), '');
    }
    return s;
  }

  /// Full format with ₹ prefix (no compact, just 2 decimal places)
  static String full(double amount) => '₹${amount.toStringAsFixed(2)}';

  /// Format with ₹ prefix and Indian number grouping (2,50,000 style).
  /// [decimals] defaults to 2 for amounts, pass 0 for round numbers.
  static String format(double amount, {int decimals = 2}) {
    final sign = amount < 0 ? '-' : '';
    final abs = amount.abs();
    final formatted = _indianFormat(abs, decimals);
    return '$sign₹$formatted';
  }

  /// Same as [format] but always shows a leading '+' for positive values.
  static String formatSigned(double amount, {int decimals = 2}) {
    final sign = amount >= 0 ? '+' : '';
    return '$sign${format(amount, decimals: decimals)}';
  }

  /// Display balance gracefully:
  /// 0 → "—"  |  positive → compact  |  negative → "-₹X.XX"
  /// Use this in account/card headings where zero balance is uninformative.
  static String balance(double amount, {bool compact = false}) {
    if (amount == 0) return '—';
    return compact
        ? CurrencyFormatter.compact(amount)
        : CurrencyFormatter.format(amount, decimals: 2);
  }

  /// Display date in canonical "15 Mar 2026" format.
  /// Alias for [DateFormatter.format] — use this for consistency.
  /// AU15-02: everywhere dates are displayed to the user, use this.
  static String display(DateTime date) => DateFormatter.format(date);

  static String _indianFormat(double value, int decimals) {
    final parts = value.toStringAsFixed(decimals).split('.');
    final intPart = parts[0];
    final decPart = parts.length > 1 ? '.${parts[1]}' : '';
    if (intPart.length <= 3) return '$intPart$decPart';
    // Indian system: last 3 digits, then groups of 2
    final last3 = intPart.substring(intPart.length - 3);
    final rest = intPart.substring(0, intPart.length - 3);
    final groups = <String>[];
    for (int i = rest.length; i > 0; i -= 2) {
      groups.insert(0, rest.substring(i < 2 ? 0 : i - 2, i));
    }
    return '${groups.join(',')},$last3$decPart';
  }
}

/// Centralized date formatting utility
/// Eliminates code duplication across 14+ files
class DateFormatter {
  /// Canonical display format: "15 Mar 2026".
  /// AU15-02: use this everywhere a date is shown to the user.
  /// Identical to [format] — exists as a semantic alias.
  static String display(DateTime date) => format(date);

  /// Format date as "DD MMM YYYY" (e.g., "15 Jan 2024")
  static String format(DateTime date) {
    const months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${date.day} ${months[date.month]} ${date.year}';
  }

  /// Format date as "DD MMM YYYY, HH:MM" (e.g., "15 Jan 2024, 14:30")
  static String formatWithTime(DateTime date) {
    final timeStr =
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    return '${format(date)}, $timeStr';
  }

  /// Format date as "DD/MM/YYYY"
  static String formatSlash(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  /// Format date as "Month DD, YYYY" (e.g., "January 15, 2024")
  static String formatLong(DateTime date) {
    const months = [
      '',
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return '${months[date.month]} ${date.day}, ${date.year}';
  }

  /// Format relative date (e.g., "Today", "Yesterday", "2 days ago")
  static String formatRelative(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDay = DateTime(date.year, date.month, date.day);
    final difference = today.difference(targetDay).inDays;

    if (difference == 0) {
      return 'Today';
    } else if (difference == 1) {
      return 'Yesterday';
    } else if (difference == -1) {
      return 'Tomorrow';
    } else if (difference > 1 && difference <= 7) {
      return '$difference days ago';
    } else if (difference < -1 && difference >= -7) {
      return 'In ${-difference} days';
    } else {
      return format(date);
    }
  }

  /// Format "FY YYYY-YY" label for a given year start (e.g., 2024 → "FY 2024-25")
  static String formatFinancialYear(int fyStartYear) {
    return 'FY $fyStartYear-${((fyStartYear + 1) % 100).toString().padLeft(2, '0')}';
  }

  /// Group a list of items by date label (Today / Yesterday / DD MMM YYYY).
  /// Items are sorted newest-first before grouping.
  /// [getDate] extracts the [DateTime] from each item.
  static Map<String, List<T>> groupByDate<T>(
    List<T> items,
    DateTime Function(T) getDate,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final sorted = List<T>.from(items)
      ..sort((a, b) => getDate(b).compareTo(getDate(a)));

    final result = <String, List<T>>{};
    for (final item in sorted) {
      final d = getDate(item);
      final day = DateTime(d.year, d.month, d.day);
      final String label;
      if (day == today) {
        label = 'Today';
      } else if (day == yesterday) {
        label = 'Yesterday';
      } else {
        label = format(d);
      }
      result.putIfAbsent(label, () => []).add(item);
    }
    return result;
  }

  /// Get month name from month number (1-12)
  static String getMonthName(int month, {bool short = true}) {
    if (month < 1 || month > 12) return '';

    if (short) {
      const months = [
        '',
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ];
      return months[month];
    } else {
      const months = [
        '',
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December'
      ];
      return months[month];
    }
  }
}
