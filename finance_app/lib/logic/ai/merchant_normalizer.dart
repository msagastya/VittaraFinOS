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
    // "SWIGGY*ORDER*123456789" → "SWIGGY"
    s = s.replaceAll(RegExp(r'\*[A-Z0-9]{4,}'), '');
    // "merchant@upi", "merchant@okicici", "merchant@ybl" → strip VPA
    s = s.replaceAll(RegExp(r'@[a-z][a-z0-9]*'), '');
    // Trailing / leading numeric IDs: "AMAZON 987654321" → "AMAZON"
    s = s.replaceAll(RegExp(r'\s+\d{5,}'), '');
    s = s.replaceAll(RegExp(r'^\d{5,}\s+'), '');
    // Slash-separated noise: "HDFC/UPI/12345" → "HDFC"
    s = s.replaceAll(RegExp(r'\s*/.*$'), '');
    // UTR/reference suffixes: "MERCHANT UTR1234567" → "MERCHANT"
    s = s.replaceAll(RegExp(r'\bUTR\s*\d+\b', caseSensitive: false), '');
    // Bank transaction codes at end: "MERCHANT-TXN-123"
    s = s.replaceAll(RegExp(r'\-?TXN\-?\d+', caseSensitive: false), '');

    // ── Payment gateway prefixes ─────────────────────────────────────────────
    s = s.replaceFirst(
      RegExp(r'^(POS|NFS|IB|UPI|NEFT|IMPS|RTGS|ACH|ACH DR|NACH|ECS|ATM|CMS|BIL|INT)\s*[/*:\-]?\s*', caseSensitive: false),
      '',
    );

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

    // ── Food delivery & quick commerce ────────────────────────────────────────
    if (lower.contains('swgy') || lower.contains('swiggy')) {
      if (lower.contains('instamart')) return 'Swiggy Instamart';
      return 'Swiggy';
    }
    if (lower.contains('zomato') || lower.contains('zomat')) return 'Zomato';
    if (lower.contains('dunzo')) return 'Dunzo';
    if (lower.contains('blinkit') || lower.contains('grofer')) return 'Blinkit';
    if (lower.contains('bigbasket') || lower.contains('bbstar') || lower.contains('bb ')) return 'BigBasket';
    if (lower.contains('zepto')) return 'Zepto';
    if (lower.contains('instamart')) return 'Swiggy Instamart';
    if (lower.contains('jiomart')) return 'JioMart';

    // ── E-commerce ────────────────────────────────────────────────────────────
    if (lower.contains('amazon') || lower.contains('amzn') || lower.contains('amzpay')) return 'Amazon';
    if (lower.contains('flipkart') || lower.contains('fkrt') || lower.contains('fk ')) return 'Flipkart';
    if (lower.contains('myntra')) return 'Myntra';
    if (lower.contains('meesho')) return 'Meesho';
    if (lower.contains('nykaa fashion')) return 'Nykaa Fashion';
    if (lower.contains('nykaa')) return 'Nykaa';
    if (lower.contains('ajio')) return 'AJIO';
    if (lower.contains('snapdeal')) return 'Snapdeal';
    if (lower.contains('shopsy')) return 'Shopsy';
    if (lower.contains('tata cliq') || lower.contains('tatacliq')) return 'Tata CLiQ';
    if (lower.contains('limeroad')) return 'LimeRoad';

    // ── Travel ────────────────────────────────────────────────────────────────
    if (lower.contains('makemytrip') || lower.contains('mmt')) return 'MakeMyTrip';
    if (lower.contains('irctc')) return 'IRCTC';
    if (lower.contains('redbus') || lower.contains('red bus')) return 'redBus';
    if (lower.contains('abhibus')) return 'AbhiBus';
    if (lower.contains('ola') && !lower.contains('olafs') && !lower.contains('olarich')) return 'Ola';
    if (lower.contains('uber')) return 'Uber';
    if (lower.contains('rapido')) return 'Rapido';
    if (lower.contains('namma yatri') || lower.contains('nammayatri')) return 'Namma Yatri';
    if (lower.contains('yatra')) return 'Yatra';
    if (lower.contains('cleartrip')) return 'Cleartrip';
    if (lower.contains('goibibo')) return 'Goibibo';
    if (lower.contains('indigo') || lower.contains('6e ')) return 'IndiGo';
    if (lower.contains('air india') || lower.contains('airindia')) return 'Air India';
    if (lower.contains('spicejet')) return 'SpiceJet';
    if (lower.contains('akasa')) return 'Akasa Air';
    if (lower.contains('fastag') || lower.contains('fast tag') || lower.contains('netc')) return 'FASTag';

    // ── Telecom / utilities ───────────────────────────────────────────────────
    if (lower.contains('airtel')) return 'Airtel';
    if (lower.contains('reliance jio') || lower.contains('jio')) return 'Jio';
    if (lower.contains('vodafone') || lower.contains(' vi ') || lower.contains('vi-')) return 'Vi (Vodafone)';
    if (lower.contains('bsnl')) return 'BSNL';
    if (lower.contains('bescom') || lower.contains('msedcl') || lower.contains('tpddl') ||
        lower.contains('uppcl') || lower.contains('wbsedcl') || lower.contains('electricity') ||
        lower.contains('bijli')) return 'Electricity Bill';
    if (lower.contains('piped gas') || lower.contains('indraprastha gas') || lower.contains('mgl') ||
        lower.contains('mahanagar gas') || lower.contains('adani gas')) return 'Gas Bill';
    if (lower.contains('act fibernet') || lower.contains('hathway') || lower.contains('tikona')) return 'Broadband';

    // ── Streaming & entertainment ──────────────────────────────────────────────
    if (lower.contains('netflix')) return 'Netflix';
    if (lower.contains('hotstar') || lower.contains('disney+') || lower.contains('disneyplus')) return 'Disney+ Hotstar';
    if (lower.contains('spotify')) return 'Spotify';
    if (lower.contains('youtube premium') || lower.contains('yt premium')) return 'YouTube Premium';
    if (lower.contains('prime video') || lower.contains('primevideo')) return 'Amazon Prime Video';
    if (lower.contains('zee5')) return 'ZEE5';
    if (lower.contains('sonyliv')) return 'SonyLIV';
    if (lower.contains('jiosaavn') || lower.contains('jio saavn')) return 'JioSaavn';
    if (lower.contains('wynk')) return 'Wynk Music';
    if (lower.contains('mxplayer') || lower.contains('mx player')) return 'MX Player';
    if (lower.contains('pvr')) return 'PVR Cinemas';
    if (lower.contains('inox')) return 'INOX';
    if (lower.contains('cinepolis')) return 'Cinepolis';
    if (lower.contains('bookmyshow') || lower.contains('book my show')) return 'BookMyShow';

    // ── Health & pharmacy ──────────────────────────────────────────────────────
    if (lower.contains('1mg') || lower.contains('tata 1mg')) return 'Tata 1mg';
    if (lower.contains('pharmeasy')) return 'PharmEasy';
    if (lower.contains('netmeds')) return 'Netmeds';
    if (lower.contains('apollo') && (lower.contains('pharm') || lower.contains('hospital') || lower.contains('clinic'))) return 'Apollo';
    if (lower.contains('practo')) return 'Practo';
    if (lower.contains('cult.fit') || lower.contains('cultfit') || lower.contains('cure.fit')) return 'Cult.fit';

    // ── Coffee & QSR ───────────────────────────────────────────────────────────
    if (lower.contains('starbucks')) return 'Starbucks';
    if (lower.contains('cafe coffee day') || lower.contains('ccd')) return 'Café Coffee Day';
    if (lower.contains('mcdonalds') || lower.contains('mcdonald') || lower.contains('mcd')) return "McDonald's";
    if (lower.contains('domino') || lower.contains("domino's")) return "Domino's";
    if (lower.contains('kfc')) return 'KFC';
    if (lower.contains('subway')) return 'Subway';
    if (lower.contains('burger king')) return 'Burger King';
    if (lower.contains('pizza hut') || lower.contains('pizzahut')) return 'Pizza Hut';
    if (lower.contains('biggies') || lower.contains('wow momo')) return lower.contains('wow') ? 'Wow! Momo' : s;
    if (lower.contains('naturals') && lower.contains('ice')) return "Natural's Ice Cream";
    if (lower.contains('chaayos')) return 'Chaayos';
    if (lower.contains('third wave') || lower.contains('thirdwave')) return 'Third Wave Coffee';
    if (lower.contains('haldiram')) return "Haldiram's";
    if (lower.contains('bikanervala')) return 'Bikanervala';

    // ── Fuel ──────────────────────────────────────────────────────────────────
    if (lower.contains('indian oil') || lower.contains('iocl')) return 'Indian Oil';
    if (lower.contains('bharat petroleum') || lower.contains('bpcl')) return 'Bharat Petroleum';
    if (lower.contains('hpcl') || lower.contains('hindustan petroleum') || lower.contains('hp petrol')) return 'HP Petrol';
    if (lower.contains('essar') || lower.contains('nayara')) return 'Nayara Energy';
    if (lower.contains('petrol') || lower.contains('fuel') || lower.contains('diesel')) return 'Fuel';

    // ── Finance / investing / insurance ───────────────────────────────────────
    if (lower.contains('lic')) return 'LIC';
    if (lower.contains('policybazaar')) return 'PolicyBazaar';
    if (lower.contains('groww')) return 'Groww';
    if (lower.contains('zerodha') || lower.contains('kite')) return 'Zerodha';
    if (lower.contains('upstox')) return 'Upstox';
    if (lower.contains('angel one') || lower.contains('angelone') || lower.contains('angel broking')) return 'Angel One';
    if (lower.contains('hdfc securities') || lower.contains('hdfc sec')) return 'HDFC Securities';
    if (lower.contains('icicidirect') || lower.contains('icici direct')) return 'ICICI Direct';
    if (lower.contains('coin by zerodha') || lower.contains('zerodha coin')) return 'Zerodha Coin';
    if (lower.contains('paytm money')) return 'Paytm Money';
    if (lower.contains('smallcase')) return 'Smallcase';
    if (lower.contains('indmoney') || lower.contains('ind money')) return 'INDmoney';

    // ── Payment apps ───────────────────────────────────────────────────────────
    if (lower.contains('phonepe') || lower.contains('phone pe')) return 'PhonePe';
    if (lower.contains('google pay') || lower.contains('gpay') || lower.contains('tez')) return 'Google Pay';
    if (lower.contains('paytm') && !lower.contains('paytm money')) return 'Paytm';
    if (lower.contains('cred')) return 'CRED';
    if (lower.contains('bhim')) return 'BHIM';
    if (lower.contains('mobikwik')) return 'MobiKwik';
    if (lower.contains('freecharge')) return 'FreeCharge';

    // ── Supermarkets & grocery ────────────────────────────────────────────────
    if (lower.contains('reliance smart') || lower.contains('reliance fresh') || lower.contains('smart bazaar')) return 'Reliance Retail';
    if (lower.contains('dmart') || lower.contains('d-mart') || lower.contains('d mart')) return 'DMart';
    if (lower.contains("spencer's") || lower.contains('spencers')) return "Spencer's";
    if (lower.contains('big bazaar') || lower.contains('bigbazaar')) return 'Big Bazaar';
    if (lower.contains('star bazaar') || lower.contains('starbazaar') || lower.contains('tata star')) return 'Star Market';
    if (lower.contains('spar')) return 'SPAR';

    // ── Banks (for transfers/ATM) ────────────────────────────────────────────
    if (lower.contains('hdfc')) return 'HDFC Bank';
    if (lower.contains('icici')) return 'ICICI Bank';
    if (lower.contains('sbi') || lower.contains('state bank')) return 'SBI';
    if (lower.contains('axis bank') || lower.contains('axis ')) return 'Axis Bank';
    if (lower.contains('kotak')) return 'Kotak Bank';
    if (lower.contains('yes bank') || lower.contains('yesbank')) return 'Yes Bank';
    if (lower.contains('indusind')) return 'IndusInd Bank';
    if (lower.contains('pnb') || lower.contains('punjab national')) return 'PNB';
    if (lower.contains('bank of baroda') || lower.contains('bob ')) return 'Bank of Baroda';
    if (lower.contains('canara')) return 'Canara Bank';

    // ── Education ────────────────────────────────────────────────────────────
    if (lower.contains('byju') || lower.contains("byju's")) return "BYJU'S";
    if (lower.contains('unacademy')) return 'Unacademy';
    if (lower.contains('vedantu')) return 'Vedantu';
    if (lower.contains('udemy')) return 'Udemy';
    if (lower.contains('coursera')) return 'Coursera';
    if (lower.contains('toppr')) return 'Toppr';

    // ── Salary / income patterns ──────────────────────────────────────────────
    if (lower.contains('salary') || lower.contains('sal cr')) return 'Salary Credit';
    if (lower.contains('neft cr') || lower.contains('imps cr')) return s;

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
