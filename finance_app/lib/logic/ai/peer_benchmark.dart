import 'package:vittara_fin_os/logic/transaction_model.dart';

/// Income bracket the user optionally provides during setup.
enum IncomeBracket {
  below30k,   // < ₹30,000/month
  range30_60, // ₹30,000–60,000
  range60_100, // ₹60,000–1,00,000
  above100k,  // > ₹1,00,000
}

extension IncomeBracketLabel on IncomeBracket {
  String get label {
    switch (this) {
      case IncomeBracket.below30k: return 'Below ₹30K/month';
      case IncomeBracket.range30_60: return '₹30K–60K/month';
      case IncomeBracket.range60_100: return '₹60K–1L/month';
      case IncomeBracket.above100k: return 'Above ₹1L/month';
    }
  }
}

/// A single benchmark comparison point.
class BenchmarkPoint {
  /// Category or metric name.
  final String name;

  /// User's percentage of income spent on this.
  final double userPct;

  /// Synthetic peer range (low, high).
  final double peerLow;
  final double peerHigh;

  /// Only surface if gap is actionable (> 5%).
  bool get isActionable => userPct > peerHigh + 5;

  /// Framed as opportunity, never shame.
  String get insight {
    if (!isActionable) return '';
    final gap = (userPct - peerHigh).toStringAsFixed(0);
    return 'People with similar income typically spend '
        '${peerLow.toStringAsFixed(0)}–${peerHigh.toStringAsFixed(0)}% on ${name.toLowerCase()}. '
        'You\'re at ${userPct.toStringAsFixed(0)}% — about $gap% above the range. '
        'Bringing this closer to the average could free up meaningful monthly savings.';
  }

  const BenchmarkPoint({
    required this.name,
    required this.userPct,
    required this.peerLow,
    required this.peerHigh,
  });
}

/// Synthetic peer benchmarks — constructed from income bracket + spending norms.
/// No real user data is used. Fully on-device.
class PeerBenchmark {
  PeerBenchmark._();

  // Synthetic peer category spend % by income bracket
  // Source: approximate Indian urban household spending patterns
  static const Map<IncomeBracket, Map<String, _PeerRange>> _norms = {
    IncomeBracket.below30k: {
      'Food': _PeerRange(18, 28),
      'Transport': _PeerRange(8, 14),
      'Dining': _PeerRange(4, 8),
      'Entertainment': _PeerRange(3, 6),
      'Shopping': _PeerRange(6, 12),
      'Health': _PeerRange(4, 8),
    },
    IncomeBracket.range30_60: {
      'Food': _PeerRange(14, 22),
      'Transport': _PeerRange(7, 13),
      'Dining': _PeerRange(6, 12),
      'Entertainment': _PeerRange(4, 8),
      'Shopping': _PeerRange(7, 14),
      'Health': _PeerRange(3, 7),
    },
    IncomeBracket.range60_100: {
      'Food': _PeerRange(10, 18),
      'Transport': _PeerRange(6, 12),
      'Dining': _PeerRange(8, 15),
      'Entertainment': _PeerRange(5, 10),
      'Shopping': _PeerRange(8, 16),
      'Health': _PeerRange(3, 6),
    },
    IncomeBracket.above100k: {
      'Food': _PeerRange(8, 14),
      'Transport': _PeerRange(5, 10),
      'Dining': _PeerRange(8, 16),
      'Entertainment': _PeerRange(6, 12),
      'Shopping': _PeerRange(9, 18),
      'Health': _PeerRange(3, 6),
    },
  };

  /// Compute benchmark points for the last 3 months.
  /// Returns only actionable points (user is meaningfully above peer range).
  static List<BenchmarkPoint> compute({
    required List<Transaction> transactions,
    required IncomeBracket bracket,
  }) {
    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(days: 90));
    final recent = transactions.where((t) => t.dateTime.isAfter(cutoff)).toList();

    final income = recent
        .where((t) => t.type == TransactionType.income)
        .fold(0.0, (s, t) => s + t.amount);
    if (income <= 0) return [];

    final norms = _norms[bracket] ?? _norms[IncomeBracket.range30_60]!;
    final points = <BenchmarkPoint>[];

    // Aggregate user spend by category
    final catSpend = <String, double>{};
    for (final t in recent.where((t) => t.type == TransactionType.expense)) {
      final cat = _normalizeCategory(
          (t.metadata?['categoryName'] as String?) ?? '');
      if (cat != null) {
        catSpend[cat] = (catSpend[cat] ?? 0) + t.amount.abs();
      }
    }

    for (final entry in norms.entries) {
      final userSpend = catSpend[entry.key] ?? 0;
      final userPct = userSpend / income * 100;
      final point = BenchmarkPoint(
        name: entry.key,
        userPct: userPct,
        peerLow: entry.value.low,
        peerHigh: entry.value.high,
      );
      if (point.isActionable) points.add(point);
    }

    // Sort by gap size descending
    points.sort((a, b) =>
        (b.userPct - b.peerHigh).compareTo(a.userPct - a.peerHigh));
    return points.take(3).toList();
  }

  static String? _normalizeCategory(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('food') || lower.contains('grocer')) return 'Food';
    if (lower.contains('dining') ||
        lower.contains('restaurant') ||
        lower.contains('swiggy') ||
        lower.contains('zomato')) return 'Dining';
    if (lower.contains('transport') ||
        lower.contains('uber') ||
        lower.contains('ola') ||
        lower.contains('petrol') ||
        lower.contains('fuel')) return 'Transport';
    if (lower.contains('entertain') ||
        lower.contains('movie') ||
        lower.contains('netflix') ||
        lower.contains('spotify')) return 'Entertainment';
    if (lower.contains('shop') ||
        lower.contains('amazon') ||
        lower.contains('flipkart') ||
        lower.contains('cloth')) return 'Shopping';
    if (lower.contains('health') ||
        lower.contains('medic') ||
        lower.contains('pharma') ||
        lower.contains('doctor')) return 'Health';
    return null;
  }
}

class _PeerRange {
  final double low;
  final double high;
  const _PeerRange(this.low, this.high);
}
