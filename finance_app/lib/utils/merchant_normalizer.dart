/// Normalizes merchant names by trimming, title-casing,
/// and deduplicating common variations.
class MerchantNormalizer {
  MerchantNormalizer._();

  static const Map<String, String> _aliases = {
    'zomato food': 'Zomato',
    'swiggy order': 'Swiggy',
    'amazon.in': 'Amazon',
    'amazon pay': 'Amazon Pay',
    'uber trip': 'Uber',
    'ola cab': 'Ola',
    'netflix.com': 'Netflix',
    'spotify': 'Spotify',
    'google pay': 'Google Pay',
    'phonepe': 'PhonePe',
    'paytm': 'Paytm',
    'hdfc bank': 'HDFC Bank',
    'icici bank': 'ICICI Bank',
    'sbi': 'SBI',
  };

  /// Returns a canonical merchant name for display.
  static String normalize(String raw) {
    if (raw.isEmpty) return raw;
    final lower = raw.trim().toLowerCase();
    for (final entry in _aliases.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }
    // Title case — split on spaces, hyphens, and dashes
    return raw.trim().split(RegExp(r'[\s\-–]++')).map((w) {
      if (w.isEmpty) return w;
      // Preserve apostrophes: "mcdonald's" → "McDonald's" not "Mcdonald'S"
      final apostrophe = w.indexOf("'");
      if (apostrophe > 0) {
        return w[0].toUpperCase() +
            w.substring(1, apostrophe).toLowerCase() +
            "'" +
            w.substring(apostrophe + 1);
      }
      return w[0].toUpperCase() + w.substring(1).toLowerCase();
    }).join(' ');
  }

  /// Returns true if two merchant names likely refer to the same merchant.
  static bool isSameMerchant(String a, String b) {
    return normalize(a).toLowerCase() == normalize(b).toLowerCase();
  }
}
