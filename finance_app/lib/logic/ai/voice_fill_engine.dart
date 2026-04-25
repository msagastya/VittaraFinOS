import 'package:google_mlkit_entity_extraction/google_mlkit_entity_extraction.dart';
import 'device_intelligence_tier.dart';

enum VoiceIntent {
  addExpense,
  addIncome,
  addTransfer,
  addInvestment,
  setBudget,
  setGoal,
  query,
  queryBalance,
  queryGoal,
  navigate,
  unknown,
}

/// One step in the fill-engine conversation.
class FillStep {
  final VoiceIntent intent;
  final Map<String, dynamic> fields;
  final bool isComplete;
  final String? followUpQuestion;
  final String confirmationText;
  /// Fields that are uncertain — UI should highlight these for user review.
  final List<String> uncertainFields;

  const FillStep({
    required this.intent,
    required this.fields,
    required this.isComplete,
    this.followUpQuestion,
    this.confirmationText = '',
    this.uncertainFields = const [],
  });
}

/// Two-pass voice fill engine with full English / Hindi / Hinglish support.
///
/// Language support:
///   - English: active + passive voice ("I paid", "was charged", "deducted")
///   - Hindi: "kharcha kiya", "paise aaye", "bhej diya", "kat gaya"
///   - Hinglish: "swiggy pe order kiya", "auto wale ko diya"
///   - Amounts: English words, Hindi words, compound phrases
///     ("teen sau pachas" = 350, "dedh hazaar" = 1500)
///   - Synonyms: "friends & relatives" ≡ "friends and relatives"
///
/// Design principle: never fail silently.
/// - Amount is the only required field.
/// - If intent is unclear, default to expense.
/// - Always return uncertainFields so the UI can highlight fields to confirm.
class VoiceFillEngine {
  final List<String> accountNames;
  final List<String> categoryNames;
  final IntelligenceTier tier;

  Map<String, dynamic> _fields = {};
  List<String> _uncertainFields = [];
  VoiceIntent _intent = VoiceIntent.unknown;

  EntityExtractor? _extractor;
  bool _extractorReady = false;
  bool _inFlight = false; // T-172: guard against concurrent processAsync calls

  VoiceFillEngine({
    required this.accountNames,
    required this.categoryNames,
    required this.tier,
  }) {
    _initMlKit();
  }

  void _initMlKit() {
    try {
      _extractor = EntityExtractor(language: EntityExtractorLanguage.english);
      _extractorReady = true;
    } catch (_) {
      _extractorReady = false;
    }
  }

  void dispose() {
    _extractor?.close();
  }

  void reset() {
    _fields = {};
    _uncertainFields = [];
    _intent = VoiceIntent.unknown;
  }

  // ── Main entry ────────────────────────────────────────────────────────────

  /// Process the initial utterance. Returns a FillStep immediately via the
  /// rule-based layer; ML Kit result is applied asynchronously if available.
  Future<FillStep> processAsync(String utterance) async {
    // T-172: cancel the previous in-flight call (rapid double-tap on mic)
    if (_inFlight) {
      reset(); // discard previous partial state
    }
    _inFlight = true;
    try {
      return await _processAsyncInternal(utterance);
    } finally {
      _inFlight = false;
    }
  }

  Future<FillStep> _processAsyncInternal(String utterance) async {
    reset();
    // Normalize synonyms before anything else
    final normalized = _normalizeSynonyms(utterance);
    final lower = _norm(normalized);

    // Pass 1 — intent + rule-based fields (instant)
    _intent = _detectIntent(lower, normalized);
    _extractFieldsRules(normalized, lower);

    // Pass 2 — ML Kit entity extraction (fast, ~50–150ms on-device)
    if (_extractorReady && _extractor != null) {
      await _applyMlKit(normalized);
    }

    // Unknown intent with amount → default to expense
    if (_intent == VoiceIntent.unknown &&
        (_fields['amount'] as double? ?? 0) > 0) {
      _intent = VoiceIntent.addExpense;
    }

    // Mark uncertain fields for UI highlighting
    _markUncertainFields(lower);

    return _evaluate();
  }

  /// Synchronous version for follow-up answers (no async needed).
  FillStep processAnswer(String answer) {
    final normalized = _normalizeSynonyms(answer);
    final lower = _norm(normalized);
    final missing = _missingRequired();
    if (missing.isEmpty) return _evaluate();

    final field = missing.first;
    switch (field) {
      case 'amount':
        final amt = _extractAmountRules(lower);
        if (amt != null) {
          _fields['amount'] = amt;
          _uncertainFields.remove('amount');
        }
        break;
      case 'merchant':
        final w = answer.trim().split(' ').where((x) => x.length > 1).join(' ');
        _fields['merchant'] = _titleCase(w.isNotEmpty ? w : answer.trim());
        _uncertainFields.remove('merchant');
        break;
    }

    return _evaluate();
  }

  // ── Synonym normalisation ─────────────────────────────────────────────────

  /// Normalise surface variation so downstream matching is consistent:
  ///   "&"  →  "and"
  ///   "+"  →  "and"
  ///   common misspellings / alternate spellings
  ///   Devanagari digits → ASCII digits
  String _normalizeSynonyms(String raw) {
    var s = raw;

    // Devanagari digits → ASCII
    const devanagari = ['०','१','२','३','४','५','६','७','८','९'];
    for (int i = 0; i < devanagari.length; i++) {
      s = s.replaceAll(devanagari[i], '$i');
    }

    // Symbol synonyms
    s = s.replaceAll(RegExp(r'\s*&\s*'), ' and ');
    s = s.replaceAll(RegExp(r'\s*\+\s*'), ' and ');

    // Common alternate spellings
    s = s.replaceAll(RegExp(r'\brupees?\b', caseSensitive: false), 'rupees');
    s = s.replaceAll(RegExp(r'\brupaye\b', caseSensitive: false), 'rupees');
    s = s.replaceAll(RegExp(r'\brupaiye\b', caseSensitive: false), 'rupees');
    s = s.replaceAll(RegExp(r'\brupaye\b', caseSensitive: false), 'rupees');
    s = s.replaceAll(RegExp(r'\bpaise\b', caseSensitive: false), 'rupees');   // "paise" = small amount context
    s = s.replaceAll(RegExp(r'\bpaisa\b', caseSensitive: false), 'rupees');
    s = s.replaceAll(RegExp(r'\brupe\b', caseSensitive: false), 'rupees');

    // "k" after numbers = thousand (already handled in extraction but normalise here too)
    s = s.replaceAll(RegExp(r'(\d)\s*k\b', caseSensitive: false), r'\1 thousand');

    return s;
  }

  // ── ML Kit pass ───────────────────────────────────────────────────────────

  Future<void> _applyMlKit(String text) async {
    try {
      final annotations = await _extractor!.annotateText(text);
      final amounts = <({double amount, int pos})>[];
      DateTime? mlDate;

      for (final a in annotations) {
        for (final e in a.entities) {
          if (e is MoneyEntity) {
            final val = e.integerPart.toDouble() +
                (e.fractionPart > 0 ? e.fractionPart / 100.0 : 0);
            if (val >= 1 && val <= 1e8) {
              amounts.add((amount: val, pos: a.start));
            }
          } else if (e is DateTimeEntity) {
            mlDate = DateTime.fromMillisecondsSinceEpoch(e.timestamp);
          }
        }
      }

      // Override rule-based amount only if ML Kit found one (more accurate)
      if (amounts.isNotEmpty) {
        final best = amounts.reduce((a, b) => a.amount > b.amount ? a : b);
        _fields['amount'] = best.amount;
        _uncertainFields.remove('amount');
      }

      // Override date if ML Kit found one and we didn't
      if (mlDate != null && !_fields.containsKey('date')) {
        _fields['date'] = mlDate;
        _uncertainFields.remove('date');
      }
    } catch (_) {
      // ML Kit unavailable — rule-based already ran
    }
  }

  // ── Rule-based field extraction ───────────────────────────────────────────

  void _extractFieldsRules(String raw, String lower) {
    final amt = _extractAmountRules(lower);
    if (amt != null) _fields['amount'] = amt;

    final date = _extractDate(lower);
    if (date != null) _fields['date'] = date;

    final acc = _matchAccount(lower);
    if (acc != null) _fields['account'] = acc;

    if (_intent == VoiceIntent.addTransfer ||
        _anyOf(lower, [' to ', ' mein ', ' ke liye '])) {
      final toAcc = _extractToAccount(lower);
      if (toAcc != null) _fields['toAccount'] = toAcc;
    }

    final cat = _matchCategory(lower);
    if (cat != null) _fields['category'] = cat;

    final merchant = _extractMerchant(lower, raw);
    if (merchant != null) _fields['merchant'] = merchant;

    final invType = _extractInvestmentType(lower);
    if (invType != null) _fields['investmentType'] = invType;

    final up = _extractUnitsAndPrice(lower);
    if (up != null) {
      _fields['units'] = up.$1;
      _fields['pricePerUnit'] = up.$2;
      _fields['amount'] = up.$1 * up.$2;
    }
  }

  void _markUncertainFields(String lower) {
    _uncertainFields.clear();
    if (!_fields.containsKey('amount')) _uncertainFields.add('amount');

    // Intent uncertain if we defaulted without a strong signal
    const expenseSignals = [
      'paid', 'spent', 'spend', 'expense', 'kharcha', 'kharch', 'diya',
      'diye', 'liya', 'bought', 'order', 'bill', 'charged', 'deducted',
      'kat gaya', 'kata', 'gaya', 'gaye', 'nikla', 'nikle',
    ];
    if (_intent == VoiceIntent.addExpense && !_anyOf(lower, expenseSignals)) {
      _uncertainFields.add('intent');
    }

    // Merchant is uncertain if no preposition/brand match confirmed it
    if (_fields.containsKey('merchant') && !_fields.containsKey('category')) {
      _uncertainFields.add('merchant');
    }
  }

  // ── Required fields ───────────────────────────────────────────────────────

  List<String> _missingRequired() {
    switch (_intent) {
      case VoiceIntent.addExpense:
      case VoiceIntent.addIncome:
      case VoiceIntent.addTransfer:
      case VoiceIntent.addInvestment:
      case VoiceIntent.setBudget:
      case VoiceIntent.setGoal:
        if (!_fields.containsKey('amount')) return ['amount'];
        return [];
      default:
        return [];
    }
  }

  // ── Evaluation ────────────────────────────────────────────────────────────

  FillStep _evaluate() {
    final missing = _missingRequired();
    if (missing.isNotEmpty) {
      return FillStep(
        intent: _intent,
        fields: Map.from(_fields),
        isComplete: false,
        followUpQuestion: _questionFor(missing.first),
        uncertainFields: List.from(_uncertainFields),
      );
    }
    return FillStep(
      intent: _intent,
      fields: Map.from(_fields),
      isComplete: true,
      confirmationText: _buildConfirmation(),
      uncertainFields: List.from(_uncertainFields),
    );
  }

  // ── Intent detection ──────────────────────────────────────────────────────

  VoiceIntent _detectIntent(String lower, String raw) {
    // Transfer — check first because "sent" can appear in income context too
    if (_anyOf(lower, [
      'transfer', 'transferred', 'send', 'sent to', 'moved to',
      'bheja', 'bhej', 'bhejo', 'bhej diya', 'transfer kiya',
      'move kiya', 'dal diya', 'daal diya',
    ])) return VoiceIntent.addTransfer;

    // Income — active, passive, Hinglish
    if (_anyOf(lower, [
      // English active
      'received', 'receive', 'got paid', 'got money', 'earned', 'earning',
      'credited', 'add income',
      // English passive
      'was credited', 'has been credited', 'was deposited', 'was received',
      // Hinglish active
      'mila', 'mili', 'mile', 'aaya', 'aayi', 'aaye', 'aaya paisa',
      'paise aaye', 'paise mile', 'salary aayi', 'salary aaya',
      'paisa aaya', 'aa gaya', 'aa gaye', 'jama hua', 'jama ho gaya',
      // Income category keywords
      'salary', 'income', 'refund', 'cashback', 'bonus', 'dividend',
      'stipend', 'freelance', 'rent income', 'interest aaya', 'byaj mila',
    ])) return VoiceIntent.addIncome;

    // Investment
    if (_anyOf(lower, [
      'invest', 'invested', 'investing', 'sip', 'mutual fund', 'mf',
      'share', 'stock', 'equity', 'fd', 'fixed deposit', 'rd', 'recurring deposit',
      'nps', 'gold', 'crypto', 'bitcoin', 'ppf', 'elss', 'ulip',
      'nivesh kiya', 'invest kiya', 'lagaya', 'lagaye',
    ])) return VoiceIntent.addInvestment;

    // Budget
    if (_anyOf(lower, [
      'budget for', 'set budget', 'budget limit', 'budget banao',
      'budget set karo', 'kitna budget',
    ])) return VoiceIntent.setBudget;

    // Goal
    if (_anyOf(lower, [
      'saving for', 'new goal', 'set goal', 'goal for', 'bachana hai',
      'target set karo', 'lakshya', 'goal banana',
    ])) return VoiceIntent.setGoal;

    // Query balance
    if (_anyOf(lower, [
      'balance', 'how much do i have', 'kitna hai', 'kitna bacha',
      'kitne paise hain', 'kitna paisa hai', 'account mein kitna',
      'wallet mein kitna',
    ])) return VoiceIntent.queryBalance;

    // Query general
    if (_anyOf(lower, [
      'how much', 'what did i', 'kitna', 'kitne', 'show me', 'tell me',
      'bata', 'dikhao', 'kitna kharch', 'this month kharcha',
    ])) return VoiceIntent.query;

    // Expense — active voice
    if (_anyOf(lower, [
      'paid', 'spent', 'spend', 'bought', 'purchase', 'purchased',
      'expense', 'bill', 'ordered', 'booked', 'charged', 'subscribed',
      'ate', 'had', 'used',
    ])) return VoiceIntent.addExpense;

    // Expense — passive voice (English)
    if (_anyOf(lower, [
      'was charged', 'has been charged', 'was deducted', 'has been deducted',
      'was cut', 'got deducted', 'got charged', 'was debited', 'got debited',
    ])) return VoiceIntent.addExpense;

    // Expense — Hindi / Hinglish active
    if (_anyOf(lower, [
      'diya', 'diye', 'de diya', 'de diye', 'kharcha kiya', 'kharch kiya',
      'kharcha hua', 'kharch hua', 'liya', 'le liya', 'khaaya', 'khaya',
      'pi liya', 'peena', 'order kiya', 'book kiya', 'buy kiya',
    ])) return VoiceIntent.addExpense;

    // Expense — Hindi / Hinglish passive (money went)
    if (_anyOf(lower, [
      'kat gaya', 'kat gayi', 'kat gaye', 'kata gaya', 'kata gayi',
      'cut ho gaya', 'cut hua', 'deduct hua', 'deduct ho gaya',
      'nikla', 'nikle', 'nikla paisa', 'paise gaye', 'paisa gaya',
      'gaya paisa', 'gaye paise', 'chala gaya', 'chali gayi',
      'kharch ho gaya', 'kharcha ho gaya',
    ])) return VoiceIntent.addExpense;

    return VoiceIntent.unknown;
  }

  // ── Amount extraction ─────────────────────────────────────────────────────

  double? _extractAmountRules(String lower) {
    // Step 1: resolve Hindi compound expressions (e.g. "dedh hazaar" → "1500")
    final resolved = _resolveHindiCompounds(lower);

    // Step 2: convert spoken words to digits
    final converted = _wordsToNumbers(resolved);

    final patterns = [
      // Currency symbol before amount
      RegExp(r'(?:₹|rs\.?\s*|rupees?\s*)([\d,]+(?:\.\d+)?)\s*(k|thousand|lakh|l|cr|crore)?', caseSensitive: false),
      // Amount before currency symbol
      RegExp(r'([\d,]+(?:\.\d+)?)\s*(?:₹|rs\.?|rupees?)\b', caseSensitive: false),
      // Amount followed by multiplier
      RegExp(r'\b([\d,]+(?:\.\d+)?)\s*(k|thousand|lakh|l|cr|crore)\b', caseSensitive: false),
      // Bare number (last resort)
      RegExp(r'\b(\d[\d,]*(?:\.\d+)?)\b'),
    ];

    for (final p in patterns) {
      final m = p.firstMatch(converted);
      if (m == null) continue;
      final s = m.group(1)!.replaceAll(',', '');
      double v = double.tryParse(s) ?? 0;
      if (v <= 0) continue;
      final suf = (m.groupCount >= 2 ? m.group(2) : null)?.toLowerCase() ?? '';
      if (suf == 'k' || suf == 'thousand') v *= 1000;
      if (suf == 'lakh' || suf == 'l') v *= 100000;
      if (suf == 'cr' || suf == 'crore') v *= 10000000;
      if (v > 0) return v;
    }
    return null;
  }

  /// Resolves Hindi fractional/compound amount expressions before word→number
  /// conversion. These can't be handled by simple word substitution.
  ///
  ///   dedh hazaar    → 1500  (1.5 × 1000)
  ///   adha hazaar    → 500   (0.5 × 1000)
  ///   adha lakh      → 50000 (0.5 × 100000)
  ///   sawa hazaar    → 1250  (1.25 × 1000)
  ///   paune do hazaar → 1750 (2 × 1000 − 250)
  ///   paune ek lakh  → 75000 (1 × 100000 − 25000)
  ///   sawa do lakh   → 250000 (2.25 × 100000)
  String _resolveHindiCompounds(String s) {
    var r = s;

    // dedh (1.5×)
    r = r.replaceAllMapped(
      RegExp(r'\bdedh\s+hazaar\b', caseSensitive: false),
      (_) => '1500',
    );
    r = r.replaceAllMapped(
      RegExp(r'\bdedh\s+lakh\b', caseSensitive: false),
      (_) => '150000',
    );

    // adha / aadha (0.5×)
    r = r.replaceAllMapped(
      RegExp(r'\b(?:adha|aadha)\s+hazaar\b', caseSensitive: false),
      (_) => '500',
    );
    r = r.replaceAllMapped(
      RegExp(r'\b(?:adha|aadha)\s+lakh\b', caseSensitive: false),
      (_) => '50000',
    );
    r = r.replaceAllMapped(
      RegExp(r'\b(?:adha|aadha)\s+sau\b', caseSensitive: false),
      (_) => '50',
    );

    // sawa (1.25×) — sawa [N] [unit]
    r = r.replaceAllMapped(
      RegExp(r'\bsawa\s+(?:ek\s+)?hazaar\b', caseSensitive: false),
      (_) => '1250',
    );
    r = r.replaceAllMapped(
      RegExp(r'\bsawa\s+do\s+hazaar\b', caseSensitive: false),
      (_) => '2500',
    );
    r = r.replaceAllMapped(
      RegExp(r'\bsawa\s+(?:ek\s+)?lakh\b', caseSensitive: false),
      (_) => '125000',
    );
    r = r.replaceAllMapped(
      RegExp(r'\bsawa\s+do\s+lakh\b', caseSensitive: false),
      (_) => '250000',
    );

    // paune (N − 0.25×) — paune [N] [unit]
    r = r.replaceAllMapped(
      RegExp(r'\bpaune\s+do\s+hazaar\b', caseSensitive: false),
      (_) => '1750',
    );
    r = r.replaceAllMapped(
      RegExp(r'\bpaune\s+teen\s+hazaar\b', caseSensitive: false),
      (_) => '2750',
    );
    r = r.replaceAllMapped(
      RegExp(r'\bpaune\s+(?:ek\s+)?lakh\b', caseSensitive: false),
      (_) => '75000',
    );
    r = r.replaceAllMapped(
      RegExp(r'\bpaune\s+do\s+lakh\b', caseSensitive: false),
      (_) => '175000',
    );

    // Generic "N sau M" pattern: "teen sau pachas" = 3×100 + 50 = 350
    // This is handled by sequential word replacement; but handle
    // common combos explicitly for accuracy:
    r = r.replaceAllMapped(
      RegExp(r'\b(ek|do|teen|char|paanch|chhe|saat|aath|nau)\s+sau\s+((?:ek|do|teen|char|paanch|chhe|saat|aath|nau|das|gyarah|barah|tera|chaudah|pandrah|solah|satrah|attharah|unnees|bees|pachees|tees|chalees|pachas|saath|sattar|assi|nabbe)\b)', caseSensitive: false),
      (m) {
        final hundreds = _hindiSingleDigit(m.group(1)!.toLowerCase());
        final rest = _hindiNumberWord(m.group(2)!.toLowerCase());
        if (hundreds != null && rest != null) {
          return '${hundreds * 100 + rest}';
        }
        return m.group(0)!;
      },
    );

    // "N hazaar M sau P" — e.g. "do hazaar teen sau pachas" = 2350
    // Simplify: just chain word replacements for common cases
    return r;
  }

  int? _hindiSingleDigit(String w) {
    const m = {
      'ek': 1, 'do': 2, 'teen': 3, 'char': 4, 'paanch': 5,
      'chhe': 6, 'saat': 7, 'aath': 8, 'nau': 9,
    };
    return m[w];
  }

  int? _hindiNumberWord(String w) {
    const m = {
      'ek': 1, 'do': 2, 'teen': 3, 'char': 4, 'paanch': 5,
      'chhe': 6, 'saat': 7, 'aath': 8, 'nau': 9, 'das': 10,
      'gyarah': 11, 'barah': 12, 'tera': 13, 'chaudah': 14, 'pandrah': 15,
      'solah': 16, 'satrah': 17, 'attharah': 18, 'unnees': 19, 'bees': 20,
      'pachees': 25, 'tees': 30, 'chalees': 40, 'pachas': 50,
      'saath': 60, 'sattar': 70, 'assi': 80, 'nabbe': 90,
    };
    return m[w];
  }

  String _wordsToNumbers(String s) {
    // English number words
    const enMap = {
      'zero': '0', 'one': '1', 'two': '2', 'three': '3', 'four': '4',
      'five': '5', 'six': '6', 'seven': '7', 'eight': '8', 'nine': '9',
      'ten': '10', 'eleven': '11', 'twelve': '12', 'thirteen': '13',
      'fourteen': '14', 'fifteen': '15', 'sixteen': '16', 'seventeen': '17',
      'eighteen': '18', 'nineteen': '19', 'twenty': '20', 'thirty': '30',
      'forty': '40', 'fifty': '50', 'sixty': '60', 'seventy': '70',
      'eighty': '80', 'ninety': '90', 'hundred': '100', 'thousand': '1000',
    };
    // Hindi number words (individual — compounds handled above)
    const hiMap = {
      'ek': '1', 'do': '2', 'teen': '3', 'char': '4', 'paanch': '5',
      'chhe': '6', 'saat': '7', 'aath': '8', 'nau': '9', 'das': '10',
      'gyarah': '11', 'barah': '12', 'tera': '13', 'chaudah': '14',
      'pandrah': '15', 'solah': '16', 'satrah': '17', 'attharah': '18',
      'unnees': '19', 'bees': '20', 'pachees': '25', 'tees': '30',
      'chalis': '40', 'chalees': '40', 'pachas': '50', 'saath': '60',
      'sattar': '70', 'assi': '80', 'nabbe': '90',
      'sau': '100', 'hazaar': '1000', 'hazar': '1000',
      'lakh': '100000', 'lac': '100000', 'crore': '10000000',
    };

    var r = s;
    for (final e in enMap.entries) {
      r = r.replaceAll(RegExp('\\b${e.key}\\b', caseSensitive: false), e.value);
    }
    for (final e in hiMap.entries) {
      r = r.replaceAll(RegExp('\\b${e.key}\\b', caseSensitive: false), e.value);
    }
    return r;
  }

  // ── Account matching ──────────────────────────────────────────────────────

  String? _matchAccount(String lower) {
    // Direct name match (case-insensitive, fuzzy-normalised)
    for (final name in accountNames) {
      if (_fuzzyContains(lower, name)) return name;
    }
    // Type aliases
    const aliases = <String, List<String>>{
      'savings': ['saving', 'bachat', 'savings account', 'bachat khata'],
      'salary': ['salary account', 'main account', 'primary', 'salary wala'],
      'credit': ['credit card', 'cc', 'card se', 'credit se'],
      'cash': ['cash', 'wallet', 'hand', 'haath mein', 'naqdh', 'naqdi'],
    };
    for (final e in aliases.entries) {
      if (e.value.any((a) => lower.contains(a))) {
        final m = accountNames.firstWhere(
            (n) => n.toLowerCase().contains(e.key), orElse: () => '');
        if (m.isNotEmpty) return m;
      }
    }
    return null;
  }

  String? _extractToAccount(String lower) {
    // English: "to X"
    var m = RegExp(r"\bto\b\s+([a-z][a-z\s'\-]+?)(?:\s+from|\s+using|\s+via|\s*$)")
        .firstMatch(lower);
    if (m != null) {
      final c = m.group(1)!.trim();
      final acct = _matchAccount(c);
      if (acct != null) return acct;
      if (c.length > 1) return _titleCase(c);
    }
    // Hindi: "X mein", "X ko"
    m = RegExp(r"\b([a-z][a-z\s'\-]+?)\s+(?:mein|ko|me)\b").firstMatch(lower);
    if (m != null) {
      final c = m.group(1)!.trim();
      final acct = _matchAccount(c);
      if (acct != null) return acct;
    }
    return null;
  }

  // ── Category matching ─────────────────────────────────────────────────────

  /// Category keyword map — English + Hindi + Hinglish
  static const _catKeywords = <String, List<String>>{
    'Food': [
      // Brands
      'swiggy', 'zomato', 'dunzo', 'dominos', 'kfc', 'mcdonalds', 'subway',
      'starbucks', 'pizza hut', 'burger king', 'haldirams',
      // English
      'food', 'eat', 'eating', 'ate', 'lunch', 'dinner', 'breakfast',
      'snack', 'snacks', 'cafe', 'coffee', 'tea', 'restaurant', 'dining',
      'pizza', 'burger', 'biryani', 'juice', 'dessert', 'ice cream',
      'sweets', 'mithai',
      // Hindi / Hinglish
      'khana', 'khane', 'khaana', 'bhojan', 'nashta', 'chai', 'chaai',
      'dhaba', 'hotel', 'tapri', 'juice wale', 'mithai wale',
      'kha liya', 'kha aaya', 'pi liya',
    ],
    'Groceries': [
      'grocery', 'groceries', 'vegetables', 'veggies', 'sabzi', 'subzi',
      'fruits', 'milk', 'doodh', 'kiryana', 'kirana', 'ration', 'dal',
      'chawal', 'rice', 'atta', 'flour', 'oil', 'cooking oil',
      'blinkit', 'zepto', 'bigbasket', 'dmart', 'grofers', 'instamart',
      'reliance fresh', 'smart bazaar', 'more',
    ],
    'Transport': [
      'uber', 'ola', 'rapido', 'namma yatri', 'bluecar', 'cab', 'taxi',
      'auto', 'rickshaw', 'metro', 'bus', 'train', 'local', 'tram',
      'petrol', 'fuel', 'diesel', 'cng', 'irctc', 'flight', 'airways',
      'makemytrip', 'goibibo', 'cleartrip', 'travel', 'yatra', 'abhibus',
      'redbus', 'toll', 'fastag',
      // Hindi
      'safar', 'gaadi', 'auto wale', 'cab wala',
    ],
    'Shopping': [
      'amazon', 'flipkart', 'myntra', 'meesho', 'ajio', 'nykaa', 'tata cliq',
      'shopsy', 'limeroad', 'snapdeal', 'jiomart',
      'shopping', 'clothes', 'shoes', 'jeans', 'shirt', 'dress', 'saree',
      'suit', 'kurta', 'bag', 'wallet', 'watch', 'accessories',
      // Hindi
      'kapde', 'joote', 'kharidna', 'kharid', 'kharida',
    ],
    'Entertainment': [
      'netflix', 'prime', 'hotstar', 'disney', 'spotify', 'youtube',
      'zee5', 'sonyliv', 'jiosaavn', 'wynk', 'apple music',
      'movie', 'cinema', 'film', 'pvr', 'inox', 'cinepolis',
      'game', 'gaming', 'steam', 'playstation', 'xbox', 'concert', 'event',
      // Hindi
      'filam', 'tamaasha', 'maza', 'timepass',
    ],
    'Health': [
      'doctor', 'hospital', 'clinic', 'medical', 'medicine', 'medicines',
      'dawa', 'dawai', 'tablet', 'syrup', 'pharmacy', 'chemist',
      'gym', 'fitness', 'yoga', 'physiotherapy', 'dentist', 'eye',
      'apollo', 'practo', 'pharmeasy', 'netmeds', '1mg',
      // Hindi
      'davai', 'ilaj',
    ],
    'Utilities': [
      'electricity', 'bijli', 'power bill', 'water bill', 'water',
      'internet', 'wifi', 'broadband', 'recharge', 'mobile recharge',
      'postpaid', 'dth', 'tatasky', 'dishtv', 'airtel dth',
      'gas', 'cylinder', 'lpg', 'piped gas', 'jio', 'airtel', 'vi', 'bsnl',
      'bill',
      // Hindi
      'bijli bill', 'paani ka bill', 'gas cylinder',
    ],
    'Rent': [
      'rent', 'kiraya', 'pg', 'hostel', 'maintenance', 'society', 'housing',
      'lease', 'flat', 'house rent', 'makaan',
    ],
    'Insurance': [
      'insurance', 'lic', 'premium', 'policy', 'bima', 'mediclaim',
      'life insurance', 'health insurance', 'term plan', 'hdfc life',
      'icici prudential', 'max life', 'policybazaar',
    ],
    'Investment': [
      'sip', 'mutual fund', 'mf', 'shares', 'stocks', 'groww', 'zerodha',
      'upstox', 'angel', 'nps', 'ppf', 'elss', 'fd', 'gold',
      'crypto', 'bitcoin', 'eth', 'nivesh',
    ],
    'Subscription': [
      'subscription', 'plan', 'renewal', 'annual', 'monthly plan',
      'membership', 'pass',
    ],
    'Education': [
      'school', 'college', 'university', 'fees', 'tuition', 'coaching',
      'course', 'book', 'books', 'stationery', 'udemy', 'coursera',
      'byju', 'vedantu', 'unacademy',
      // Hindi
      'padhai', 'kitab', 'fees bharni',
    ],
    'Personal Care': [
      'salon', 'parlour', 'haircut', 'spa', 'massage', 'beauty', 'nykaa',
      'mamaearth', 'lakme', 'loreal', 'shampoo', 'soap', 'toiletries',
      // Hindi
      'baal katna', 'nai', 'dhobi', 'laundry',
    ],
    'Friends and Relatives': [
      // All variants of this common user-created category
      'friends', 'relatives', 'family', 'dost', 'yaaron', 'rishtedaar',
      'bhai', 'behen', 'papa', 'mummy', 'mama', 'chacha', 'maama',
      'nana', 'nani', 'dada', 'dadi', 'sasural',
      'gift', 'gifting', 'birthday', 'anniversary', 'party',
      // Hinglish
      'yaar ko diya', 'dost ko diya', 'ghar bheja',
    ],
    'Dining Out': [
      'dine', 'dining out', 'restaurant', 'bar', 'pub', 'lounge',
      'bahar khana', 'bahar khaana', 'khane gaye', 'restaurant gaye',
    ],
    'Petrol': [
      'petrol', 'diesel', 'fuel', 'cng', 'pump', 'petrol pump',
      'iocl', 'bpcl', 'hpcl', 'indian oil', 'bharat petroleum',
      'hp petrol',
    ],
    'EMI': [
      'emi', 'loan emi', 'home loan', 'car loan', 'bike emi',
      'installment', 'kist', 'kisht',
    ],
  };

  String? _matchCategory(String lower) {
    // 1. Check user-defined category names (fuzzy match)
    for (final name in categoryNames) {
      if (_fuzzyContains(lower, name)) return name;
    }

    // 2. Check built-in keyword map
    for (final e in _catKeywords.entries) {
      for (final kw in e.value) {
        if (lower.contains(kw)) return e.key;
      }
    }

    // 3. Check user-defined names against the keyword lists
    // (e.g. user has "Khana" as category — match keywords in "Food" group)
    for (final name in categoryNames) {
      final nameLower = _normCategoryName(name);
      for (final e in _catKeywords.entries) {
        if (_normCategoryName(e.key) == nameLower) {
          for (final kw in e.value) {
            if (lower.contains(kw)) return name; // return user's actual name
          }
        }
        // Fuzzy: user category "Friends & Relatives" matches keyword in "Friends and Relatives"
        for (final kw in e.value) {
          if (_normCategoryName(kw) == nameLower && lower.contains(kw)) {
            return name;
          }
        }
      }
    }

    return null;
  }

  /// Normalise a category name for fuzzy matching:
  /// "Friends & Relatives" → "friends and relatives"
  /// "food & dining" → "food and dining"
  String _normCategoryName(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'\s*&\s*'), ' and ')
        .replaceAll(RegExp(r'\s*\+\s*'), ' and ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Fuzzy contains — normalises both sides before checking.
  bool _fuzzyContains(String haystack, String needle) {
    return _normCategoryName(haystack).contains(_normCategoryName(needle));
  }

  // ── Merchant extraction ───────────────────────────────────────────────────

  String? _extractMerchant(String lower, String raw) {
    // Known brand list — checked first
    const known = [
      'swiggy', 'zomato', 'amazon', 'flipkart', 'netflix', 'spotify',
      'hotstar', 'prime video', 'uber', 'ola', 'rapido', 'bigbasket',
      'blinkit', 'zepto', 'paytm', 'gpay', 'google pay', 'phonepe', 'cred',
      'myntra', 'nykaa', 'meesho', 'ajio', 'dmart', 'reliance', 'jio',
      'airtel', 'vodafone', 'bsnl', 'dominos', 'mcdonalds', 'kfc', 'subway',
      'starbucks', 'pizza hut', 'burger king', 'apollo', 'practo', 'pvr',
      'inox', 'irctc', 'makemytrip', 'goibibo', 'groww', 'zerodha', 'upstox',
      'dunzo', 'tata', 'hdfc', 'icici', 'sbi', 'axis', 'kotak', 'indusind',
      'paytm mall', 'nykaa fashion', 'haldirams', 'bisleri', 'amul',
    ];
    for (final m in known) {
      if (lower.contains(m)) return _titleCase(m);
    }

    // English prepositions: "at X", "from X", "for X", "on X"
    final engPreps = [
      RegExp(r"\bat\s+([a-z][a-z0-9\s'\-]+?)(?:\s+for|\s+from|\s+yesterday|\s+today|\s+this|\s+last|\s*$)"),
      RegExp(r"\bfrom\s+([a-z][a-z0-9\s'\-]+?)(?:\s+for|\s+to|\s+yesterday|\s+today|\s+this|\s+last|\s*$)"),
      RegExp(r"\bon\s+([a-z][a-z0-9\s'\-]+?)(?:\s+for|\s+from|\s+yesterday|\s+today|\s+this|\s*$)"),
    ];

    // Hindi postpositions: "X ko", "X se", "X mein", "X pe", "X wale ko", "X wali ko"
    final hindiPostfixes = [
      RegExp(r"\b([a-z][a-z0-9\s'\-]+?)\s+(?:ko|ko diya|ko bheja)\b"),
      RegExp(r"\b([a-z][a-z0-9\s'\-]+?)\s+(?:se|se liya|se khareeda)\b"),
      RegExp(r"\b([a-z][a-z0-9\s'\-]+?)\s+(?:mein|me|pe|par)\b"),
      RegExp(r"\b([a-z][a-z0-9\s'\-]+?)\s+wale?\s+ko\b"),
    ];

    const skip = {
      'the', 'my', 'a', 'an', 'some', 'it', 'this', 'that', 'me', 'him',
      'her', 'us', 'them', 'free', 'home', 'office', 'online', 'yesterday',
      'today', 'tomorrow', 'morning', 'evening', 'night', 'last',
      'next', 'aaj', 'kal', 'abhi', 'subah', 'shaam',
    };

    for (final p in [...engPreps, ...hindiPostfixes]) {
      final m = p.firstMatch(lower);
      if (m != null) {
        final c = m.group(1)!.trim();
        if (!skip.contains(c) && c.length > 1 && !RegExp(r'^\d+$').hasMatch(c)) {
          return _titleCase(c);
        }
      }
    }

    // Best-guess: first meaningful word after stripping amount + noise words
    const noiseWords = {
      'paid', 'spent', 'spend', 'bought', 'purchase', 'expense', 'for',
      'on', 'at', 'from', 'the', 'a', 'an', 'my', 'kiya', 'kiye', 'diya',
      'diye', 'liya', 'hua', 'hue', 'aur', 'bhi', 'hi', 'toh', 'ne',
      'mein', 'mujhe', 'main', 'maine', 'gaya', 'gaye', 'aaya', 'aayi',
      'aaye', 'rupees', 'rs', 'thousand', 'lakh', 'crore', 'hazaar',
      'sau', 'was', 'is', 'has', 'have', 'been', 'got', 'get', 'did',
    };
    final noAmt = lower
        .replaceAll(RegExp(r'\b\d[\d,\.]*\s*(?:k|lakh|l|cr|rs|rupees?)?\b'), '')
        .trim();
    final words = noAmt.split(RegExp(r'\s+'))
        .where((w) => w.length > 2 && !noiseWords.contains(w))
        .toList();
    if (words.isNotEmpty) return _titleCase(words.first);

    return null;
  }

  // ── Date extraction ───────────────────────────────────────────────────────

  DateTime? _extractDate(String lower) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Today
    if (_anyOf(lower, ['today', 'aaj', 'just now', 'abhi', 'aaj ka', 'aaj ki'])) {
      return now;
    }
    // Yesterday
    if (_anyOf(lower, [
      'yesterday', 'kal', 'kal ka', 'kal ki', 'kal kiya', 'kal hua',
      'beete kal', 'kal subah', 'kal shaam',
    ])) {
      return today.subtract(const Duration(days: 1));
    }
    // Day before yesterday
    if (_anyOf(lower, [
      '2 days ago', 'two days ago', 'day before yesterday',
      'parso', 'parson', 'parso ka',
    ])) {
      return today.subtract(const Duration(days: 2));
    }
    // "N days ago"
    final daysAgo = RegExp(r'\b(\d+)\s+days?\s+ago\b').firstMatch(lower);
    if (daysAgo != null) {
      final n = int.tryParse(daysAgo.group(1)!) ?? 0;
      if (n > 0 && n <= 90) return today.subtract(Duration(days: n));
    }
    // "N din pehle"
    final dinPehle = RegExp(r'\b(\d+)\s+din\s+(?:pehle|pahle)\b').firstMatch(lower);
    if (dinPehle != null) {
      final n = int.tryParse(dinPehle.group(1)!) ?? 0;
      if (n > 0 && n <= 90) return today.subtract(Duration(days: n));
    }

    // Time of day
    if (_anyOf(lower, ['this morning', 'aaj subah', 'subah mein'])) {
      return DateTime(now.year, now.month, now.day, 9, 0);
    }
    if (_anyOf(lower, ['this evening', 'aaj shaam', 'shaam ko'])) {
      return DateTime(now.year, now.month, now.day, 18, 0);
    }
    if (_anyOf(lower, ['last night', 'raat ko', 'raat mein', 'kal raat'])) {
      return DateTime(now.year, now.month, now.day - 1, 21, 0);
    }

    // "Last week" / "pichle hafte"
    if (_anyOf(lower, ['last week', 'pichle hafte', 'pichhle hafte', 'pichle week'])) {
      return today.subtract(const Duration(days: 7));
    }

    // Named weekdays (past)
    const days = [
      'monday', 'tuesday', 'wednesday', 'thursday', 'friday',
      'saturday', 'sunday',
    ];
    const hindiDays = [
      'somwar', 'mangalwar', 'budhwar', 'guruwar', 'shukrawar',
      'shaniwar', 'raviwar',
    ];
    for (int i = 0; i < days.length; i++) {
      if (lower.contains(days[i]) || lower.contains(hindiDays[i])) {
        final target = i + 1; // weekday: 1=Monday
        int diff = (now.weekday - target + 7) % 7;
        if (diff == 0) diff = 7;
        return today.subtract(Duration(days: diff));
      }
    }

    return null;
  }

  // ── Investment type ───────────────────────────────────────────────────────

  String? _extractInvestmentType(String lower) {
    if (_anyOf(lower, ['mutual fund', 'mf', 'sip', 'elss', 'index fund'])) return 'Mutual Fund';
    if (_anyOf(lower, ['share', 'stock', 'equity', 'nse', 'bse'])) return 'Stocks';
    if (_anyOf(lower, ['fd', 'fixed deposit'])) return 'FD';
    if (_anyOf(lower, ['rd', 'recurring deposit', 'recurring'])) return 'RD';
    if (_anyOf(lower, ['nps', 'national pension', 'pension'])) return 'NPS';
    if (_anyOf(lower, ['ppf', 'public provident'])) return 'PPF';
    if (_anyOf(lower, ['gold', 'digital gold', 'sgb', 'sovereign gold'])) return 'Digital Gold';
    if (_anyOf(lower, ['crypto', 'bitcoin', 'btc', 'eth', 'ethereum'])) return 'Crypto';
    if (_anyOf(lower, ['bond', 'bonds', 'debenture'])) return 'Bonds';
    return null;
  }

  (double, double)? _extractUnitsAndPrice(String lower) {
    final m = RegExp(
      r'(\d+)\s+(?:shares?|units?|stocks?)\s+(?:at|of|@)\s*(?:₹|rs\.?)?\s*(\d[\d,]*)',
      caseSensitive: false,
    ).firstMatch(lower);
    if (m != null) {
      final u = double.tryParse(m.group(1)!) ?? 0;
      final p = double.tryParse(m.group(2)!.replaceAll(',', '')) ?? 0;
      if (u > 0 && p > 0) return (u, p);
    }
    return null;
  }

  // ── Follow-up questions ───────────────────────────────────────────────────

  String _questionFor(String field) {
    switch (field) {
      case 'amount': return 'Kitna tha? (How much was it?)';
      case 'merchant': return 'Kahan pe? (What was it for or where?)';
      default: return 'Can you say that again?';
    }
  }

  // ── Confirmation text ─────────────────────────────────────────────────────

  String _buildConfirmation() {
    final amt = _fields['amount'] as double?;
    final acc = _fields['account'] as String?;
    final merchant = _fields['merchant'] as String?;
    final cat = _fields['category'] as String?;
    final toAcc = _fields['toAccount'] as String?;
    final invType = _fields['investmentType'] as String?;
    final units = _fields['units'] as double?;
    final amtStr = amt != null ? '₹${_fmtAmt(amt)}' : '';
    final desc = merchant ?? cat;

    switch (_intent) {
      case VoiceIntent.addExpense:
        if (desc != null && acc != null) return '$amtStr on $desc from $acc. Save?';
        if (desc != null) return '$amtStr on $desc. Save?';
        return '$amtStr expense${acc != null ? " from $acc" : ""}. Save?';
      case VoiceIntent.addIncome:
        if (desc != null) return '$amtStr from $desc${acc != null ? " to $acc" : ""}. Save?';
        return '$amtStr income${acc != null ? " to $acc" : ""}. Save?';
      case VoiceIntent.addTransfer:
        return 'Transfer $amtStr from ${acc ?? "your account"} to ${toAcc ?? "another account"}. Save?';
      case VoiceIntent.addInvestment:
        final type = invType ?? merchant ?? 'investment';
        if (units != null) {
          final price = _fields['pricePerUnit'] as double?;
          return '${units.toInt()} $type at ₹${price?.toInt() ?? 0} each — $amtStr. Save?';
        }
        return '$amtStr in $type. Save?';
      case VoiceIntent.setBudget:
        return 'Set ${cat ?? "category"} budget to $amtStr. Save?';
      case VoiceIntent.setGoal:
        return 'New goal "${merchant ?? cat ?? "Goal"}" for $amtStr. Save?';
      default:
        return 'Got it. Save?';
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  bool _anyOf(String text, List<String> kws) => kws.any((k) => text.contains(k));
  String _norm(String s) => s.toLowerCase().trim();
  String _titleCase(String s) => s.split(' ')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
  String _fmtAmt(double v) {
    if (v >= 10000000) return '₹${(v / 10000000).toStringAsFixed(1)}Cr';
    if (v >= 100000) return '₹${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '₹${(v / 1000).toStringAsFixed(0)}K';
    return '₹${v.toInt()}';
  }
}
