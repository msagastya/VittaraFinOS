import 'package:vittara_fin_os/logic/transaction_model.dart';
import 'behavioral_fingerprint.dart';
import 'pattern_detector.dart';

/// A paragraph-style explanation of the month — not a report, a narrative.
class MonthlyNarrative {
  final int year;
  final int month;

  /// 2-4 sentence paragraph explaining what happened this month.
  final String paragraph;

  /// One-line headline for card display.
  final String headline;

  /// Positive highlight (optional).
  final String? highlight;

  /// One thing to watch (optional).
  final String? watchOut;

  const MonthlyNarrative({
    required this.year,
    required this.month,
    required this.paragraph,
    required this.headline,
    this.highlight,
    this.watchOut,
  });
}

class MonthlyNarrativeGenerator {
  MonthlyNarrativeGenerator._();

  static MonthlyNarrative generate({
    required List<Transaction> transactions,
    required int year,
    required int month,
    BehavioralFingerprint? fingerprint,
    SpendingPatterns? patterns,
  }) {
    final monthTx = transactions.where((t) {
      return t.dateTime.year == year && t.dateTime.month == month;
    }).toList();

    if (monthTx.isEmpty) {
      return MonthlyNarrative(
        year: year,
        month: month,
        paragraph: 'No transactions recorded for this month yet.',
        headline: 'No data yet',
      );
    }

    final totalExpense = monthTx
        .where((t) => t.type == TransactionType.expense)
        .fold(0.0, (s, t) => s + t.amount.abs());
    final totalIncome = monthTx
        .where((t) => t.type == TransactionType.income)
        .fold(0.0, (s, t) => s + t.amount);
    final totalInvestments = monthTx
        .where((t) => t.type == TransactionType.investment)
        .fold(0.0, (s, t) => s + t.amount.abs());

    final savingsRate =
        totalIncome > 0 ? (totalIncome - totalExpense) / totalIncome * 100 : 0.0;

    // Category breakdown
    final categorySpend = <String, double>{};
    for (final t in monthTx.where((t) => t.type == TransactionType.expense)) {
      final cat = (t.metadata?['categoryName'] as String?) ?? 'Other';
      categorySpend[cat] = (categorySpend[cat] ?? 0) + t.amount.abs();
    }
    final sortedCats = categorySpend.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Biggest driver
    final topCat = sortedCats.isNotEmpty ? sortedCats.first : null;
    final topCatShare = totalExpense > 0 && topCat != null
        ? (topCat.value / totalExpense * 100)
        : 0.0;

    // Compare to previous month
    final prevMonthDate = DateTime(year, month - 1, 1);
    final prevMonthTx = transactions.where((t) =>
        t.dateTime.year == prevMonthDate.year &&
        t.dateTime.month == prevMonthDate.month &&
        t.type == TransactionType.expense).toList();
    final prevExpense = prevMonthTx.fold(0.0, (s, t) => s + t.amount.abs());
    final expenseDelta = prevExpense > 0
        ? ((totalExpense - prevExpense) / prevExpense * 100)
        : 0.0;

    // Number of large transactions (>₹5K)
    final largeCount =
        monthTx.where((t) => t.amount.abs() > 5000 && t.type == TransactionType.expense).length;

    // Build narrative tone based on fingerprint
    final isDisciplined = fingerprint != null &&
        fingerprint.disciplinedScore > 60;

    final monthName = _monthName(month);

    // Compose paragraph
    final sb = StringBuffer();

    // Opening sentence: spend level
    if (totalExpense == 0) {
      sb.write('No expenses recorded in $monthName. ');
    } else if (expenseDelta > 20) {
      sb.write(
          '$monthName was a higher-spend month — ₹${_fmt(totalExpense)} total expenses, '
          'up ${expenseDelta.toStringAsFixed(0)}% from last month. ');
    } else if (expenseDelta < -15) {
      sb.write(
          'Spending came in lower this month: ₹${_fmt(totalExpense)} — '
          'down ${(-expenseDelta).toStringAsFixed(0)}% from last month. ');
    } else {
      sb.write(
          'Expenses in $monthName totalled ₹${_fmt(totalExpense)}, broadly in line with last month. ');
    }

    // What drove spend
    if (topCat != null && topCatShare > 25) {
      if (largeCount > 0) {
        sb.write(
            'Most of it was driven by $largeCount large ${topCat.key.toLowerCase()} transaction${largeCount > 1 ? 's' : ''}, '
            'making up ${topCatShare.toStringAsFixed(0)}% of total spend. ');
      } else {
        sb.write(
            '${topCat.key} was the biggest category at ${topCatShare.toStringAsFixed(0)}% of total spend. ');
      }
    }

    // Savings rate
    if (totalIncome > 0) {
      if (savingsRate >= 30) {
        sb.write(
            isDisciplined
                ? 'Savings rate held at ${savingsRate.toStringAsFixed(0)}%. '
                : 'The good news: you saved ${savingsRate.toStringAsFixed(0)}% of your income. ');
      } else if (savingsRate > 0) {
        sb.write('Your savings rate this month was ${savingsRate.toStringAsFixed(0)}%. ');
      } else {
        sb.write('Expenses exceeded income this month. ');
      }
    }

    // Investments
    if (totalInvestments > 0) {
      sb.write('Investments stayed on track at ₹${_fmt(totalInvestments)}. ');
    }

    final paragraph = sb.toString().trim();

    // Headline
    String headline;
    if (totalExpense == 0) {
      headline = 'No spend data';
    } else if (expenseDelta > 20) {
      headline = 'High-spend month — ${expenseDelta.toStringAsFixed(0)}% above last month';
    } else if (expenseDelta < -15) {
      headline = 'Lighter month — spending down ${(-expenseDelta).toStringAsFixed(0)}%';
    } else {
      headline = 'Steady month — on track';
    }

    // Highlight
    String? highlight;
    if (totalInvestments > 0 && savingsRate >= 25) {
      highlight = 'Invested ₹${_fmt(totalInvestments)} while keeping savings rate at ${savingsRate.toStringAsFixed(0)}%.';
    } else if (savingsRate >= 30) {
      highlight = 'Saved ${savingsRate.toStringAsFixed(0)}% of income — great discipline.';
    }

    // Watch out
    String? watchOut;
    if (topCat != null && topCatShare > 40) {
      watchOut =
          '${topCat.key} alone was ${topCatShare.toStringAsFixed(0)}% of spend — worth watching.';
    } else if (savingsRate < 0 && totalIncome > 0) {
      watchOut = 'Spending exceeded income this month.';
    }

    return MonthlyNarrative(
      year: year,
      month: month,
      paragraph: paragraph,
      headline: headline,
      highlight: highlight,
      watchOut: watchOut,
    );
  }

  static String _monthName(int m) {
    const names = [
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return names[m.clamp(1, 12)];
  }

  static String _fmt(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
    return v.toInt().toString();
  }
}
