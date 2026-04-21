import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Cleans raw merchant strings into recognizable display names.
///
/// Two-pass system:
///   Pass 1 — built-in regex rules (UPI refs, bank codes, known prefixes)
///   Pass 2 — learned alias map from user corrections (persisted in SharedPrefs)
///
/// Learns over time: when the user recategorizes a transaction and edits
/// the description/merchant, [learnAlias] is called so future occurrences
/// are resolved without asking again.
class MerchantNormalizer {
  MerchantNormalizer._();

  static const _prefKey = 'ai_merchant_alias_map';

  // User-learned alias map: raw string fragment → clean display name
  static Map<String, String> _aliasMap = {};
  static bool _loaded = false;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Load persisted alias map. Call once at app startup.
  static Future<void> init() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefKey);
      if (raw != null) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        _aliasMap = decoded.map((k, v) => MapEntry(k, v.toString()));
      }
    } catch (_) {}
    _loaded = true;
  }

  /// Normalize a raw merchant/description string to a clean display name.
  static String normalize(String raw) {
    if (raw.trim().isEmpty) return raw;

    // Pass 1 — learned aliases (checked first, user corrections take priority)
    final fromAlias = _lookupAlias(raw);
    if (fromAlias != null) return fromAlias;

    // Pass 2 — built-in rules
    return _applyRules(raw.trim());
  }

  /// Teach the normalizer that [rawFragment] maps to [cleanName].
  /// Persists across sessions.
  static Future<void> learnAlias(String rawFragment, String cleanName) async {
    final key = rawFragment.toLowerCase().trim();
    if (key.isEmpty || cleanName.trim().isEmpty) return;
    _aliasMap[key] = cleanName.trim();
    await _persist();
  }

  // ── Internal ───────────────────────────────────────────────────────────────

  static String? _lookupAlias(String raw) {
    final lower = raw.toLowerCase();
    // Longest-match: check all alias keys, return the match with longest key
    String? bestMatch;
    int bestLen = 0;
    for (final entry in _aliasMap.entries) {
      if (lower.contains(entry.key) && entry.key.length > bestLen) {
        bestMatch = entry.value;
        bestLen = entry.key.length;
      }
    }
    return bestMatch;
  }

  static String _applyRules(String raw) {
    String s = raw;

    // ── UPI reference stripping ──────────────────────────────────────────────
    // Remove trailing UPI transaction IDs: "SWIGGY*ORDER*123456789" → "SWIGGY"
    s = s.replaceAll(RegExp(r'\*[A-Z0-9]{6,}'), '');
    // Remove UPI VPA suffixes: "merchant@upi", "merchant@okicici"
    s = s.replaceAll(RegExp(r'@[a-z]+[a-z0-9]*'), '');
    // Remove numeric-only segments: "AMAZON 123456" → "AMAZON"
    s = s.replaceAll(RegExp(r'\s+\d{5,}'), '');

    // ── Payment gateway prefixes ─────────────────────────────────────────────
    s = s.replaceFirst(RegExp(r'^(POS|NFS|IB|UPI|NEFT|IMPS|RTGS|ACH|ATM)\s*[/*-]?\s*', caseSensitive: false), '');

    // ── Known merchant brand normalization ───────────────────────────────────
    s = _normalizeBrand(s);

    // ── General cleanup ──────────────────────────────────────────────────────
    // Remove trailing/leading punctuation and extra spaces
    s = s.replaceAll(RegExp(r'[_\-*/]+'), ' ');
    s = s.replaceAll(RegExp(r'\s{2,}'), ' ');
    s = s.trim();

    // Title-case if all-caps (common in bank statements)
    if (s == s.toUpperCase() && s.length > 2) {
      s = _toTitleCase(s);
    }

    return s.isEmpty ? raw : s;
  }

  static String _normalizeBrand(String s) {
    final lower = s.toLowerCase();

    // Food delivery
    if (lower.contains('swgy') || lower.contains('swiggy')) return 'Swiggy';
    if (lower.contains('zomato') || lower.contains('zomat')) return 'Zomato';
    if (lower.contains('dunzo')) return 'Dunzo';
    if (lower.contains('blinkit') || lower.contains('grofer')) return 'Blinkit';
    if (lower.contains('bigbasket') || lower.contains('bbstar')) return 'BigBasket';
    if (lower.contains('zepto')) return 'Zepto';
    if (lower.contains('instamart')) return 'Swiggy Instamart';

    // E-commerce
    if (lower.contains('amazon') || lower.contains('amzn')) return 'Amazon';
    if (lower.contains('flipkart') || lower.contains('fkrt')) return 'Flipkart';
    if (lower.contains('myntra')) return 'Myntra';
    if (lower.contains('meesho')) return 'Meesho';
    if (lower.contains('nykaa')) return 'Nykaa';
    if (lower.contains('ajio')) return 'AJIO';

    // Travel
    if (lower.contains('makemytrip') || lower.contains('mmt')) return 'MakeMyTrip';
    if (lower.contains('irctc')) return 'IRCTC';
    if (lower.contains('redbus')) return 'redBus';
    if (lower.contains('ola') && !lower.contains('olafs')) return 'Ola';
    if (lower.contains('uber')) return 'Uber';
    if (lower.contains('rapido')) return 'Rapido';
    if (lower.contains('yatra')) return 'Yatra';
    if (lower.contains('cleartrip')) return 'Cleartrip';

    // Utilities / bills
    if (lower.contains('airtel')) return 'Airtel';
    if (lower.contains('jio') || lower.contains('reliance jio')) return 'Jio';
    if (lower.contains('vodafone') || lower.contains('vi ') || lower.contains(' vi')) return 'Vi (Vodafone)';
    if (lower.contains('bsnl')) return 'BSNL';
    if (lower.contains('bescom') || lower.contains('msedcl') || lower.contains('tpddl') || lower.contains('electricity')) return 'Electricity Bill';
    if (lower.contains('piped gas') || lower.contains('indraprastha gas') || lower.contains('mgl')) return 'Gas Bill';

    // Streaming
    if (lower.contains('netflix')) return 'Netflix';
    if (lower.contains('hotstar') || lower.contains('disney')) return 'Disney+ Hotstar';
    if (lower.contains('spotify')) return 'Spotify';
    if (lower.contains('youtube premium')) return 'YouTube Premium';
    if (lower.contains('prime video') || lower.contains('primevideo')) return 'Amazon Prime';
    if (lower.contains('zee5')) return 'ZEE5';
    if (lower.contains('sonyliv')) return 'SonyLIV';

    // Health & pharmacy
    if (lower.contains('1mg') || lower.contains('tata 1mg')) return 'Tata 1mg';
    if (lower.contains('pharmeasy')) return 'PharmEasy';
    if (lower.contains('apollo')) return 'Apollo Pharmacy';
    if (lower.contains('netmeds')) return 'Netmeds';

    // Coffee & quick service
    if (lower.contains('starbucks')) return 'Starbucks';
    if (lower.contains('cafe coffee day') || lower.contains('ccd')) return 'Café Coffee Day';
    if (lower.contains('mcdonalds') || lower.contains('mcdonald')) return "McDonald's";
    if (lower.contains('domino') || lower.contains("domino's")) return "Domino's";
    if (lower.contains('kfc')) return 'KFC';
    if (lower.contains('subway')) return 'Subway';
    if (lower.contains('burger king')) return 'Burger King';

    // Fuel
    if (lower.contains('indian oil') || lower.contains('iocl')) return 'Indian Oil';
    if (lower.contains('bharat petroleum') || lower.contains('bpcl')) return 'Bharat Petroleum';
    if (lower.contains('hpcl') || lower.contains('hindustan petroleum')) return 'HP Petrol';
    if (lower.contains('petrol') || lower.contains('fuel')) return 'Fuel';

    // Finance / insurance
    if (lower.contains('lic')) return 'LIC';
    if (lower.contains('policybazaar')) return 'PolicyBazaar';
    if (lower.contains('groww')) return 'Groww';
    if (lower.contains('zerodha')) return 'Zerodha';
    if (lower.contains('upstox')) return 'Upstox';
    if (lower.contains('coin by zerodha') || lower.contains('coin ')) return 'Zerodha Coin';
    if (lower.contains('paytm money')) return 'Paytm Money';

    // Supermarkets
    if (lower.contains('reliance smart') || lower.contains('reliance fresh')) return 'Reliance Fresh';
    if (lower.contains('dmart') || lower.contains('d-mart')) return 'DMart';
    if (lower.contains('more ') || lower.contains(' more')) return 'More Supermarket';
    if (lower.contains('spencer')) return "Spencer's";
    if (lower.contains('big bazaar')) return 'Big Bazaar';

    // Salary/income patterns
    if (lower.contains('salary') || lower.contains('sal cr')) return 'Salary Credit';
    if (lower.contains('neft cr') || lower.contains('imps cr')) {
      return s; // keep original — it has sender info
    }

    return s;
  }

  static String _toTitleCase(String s) {
    return s.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  static Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, jsonEncode(_aliasMap));
    } catch (_) {}
  }
}
