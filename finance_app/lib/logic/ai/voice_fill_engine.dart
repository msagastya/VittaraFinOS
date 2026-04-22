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

/// Two-pass voice fill engine:
///   Pass 1 — ML Kit entity extraction (MoneyEntity + DateTimeEntity)
///   Pass 2 — Rule-based intent + merchant/category inference
///
/// Design principle: never fail silently.
/// - Amount is the only required field.
/// - If intent is unclear, default to expense.
/// - Always return a result with an uncertainFields list so the UI can
///   ask the user to confirm or correct specific fields.
class VoiceFillEngine {
  final List<String> accountNames;
  final List<String> categoryNames;
  final IntelligenceTier tier;

  Map<String, dynamic> _fields = {};
  List<String> _uncertainFields = [];
  VoiceIntent _intent = VoiceIntent.unknown;

  EntityExtractor? _extractor;
  bool _extractorReady = false;

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
    reset();
    final lower = _norm(utterance);

    // Pass 1 — intent + rule-based fields (instant)
    _intent = _detectIntent(lower, utterance);
    _extractFieldsRules(utterance, lower);

    // Pass 2 — ML Kit entity extraction (fast, ~50–150ms on-device)
    if (_extractorReady && _extractor != null) {
      await _applyMlKit(utterance);
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
    final lower = _norm(answer);
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

  // ── ML Kit pass ───────────────────────────────────────────────────────────

  Future<void> _applyMlKit(String text) async {
    try {
      final annotations = await _extractor!.annotateText(text);
      final amounts = <({double amount, int pos})>[];
      DateTime? mlDate;

      for (final a in annotations) {
        for (final e in a.entities) {
          if (e is MoneyEntity) {
            // ML Kit's MoneyEntity gives integerPart + fractionPart
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

      // Override rule-based amount only if ML Kit found one (it's more accurate)
      if (amounts.isNotEmpty) {
        // Pick the amount closest to a currency symbol or largest
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
      // ML Kit unavailable — rule-based already ran, no action needed
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

    if (_intent == VoiceIntent.addTransfer || lower.contains(' to ')) {
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
    // Amount is uncertain if not found
    if (!_fields.containsKey('amount')) _uncertainFields.add('amount');
    // Intent is uncertain if we defaulted to expense
    if (_intent == VoiceIntent.addExpense &&
        !_anyOf(lower, ['paid', 'spent', 'expense', 'kharcha', 'diya', 'bought'])) {
      _uncertainFields.add('intent');
    }
    // Merchant is uncertain if we used a best-guess (no preposition/brand match)
    if (_fields.containsKey('merchant') &&
        !_fields.containsKey('category')) {
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
    if (_anyOf(lower, ['transfer', 'transferred', 'send', 'sent to', 'moved to',
        'bheja', 'bhej', 'bhejo'])) return VoiceIntent.addTransfer;

    if (_anyOf(lower, ['received', 'receive', 'salary', 'income', 'got paid',
        'got money', 'credited', 'add income', 'earning', 'earned',
        'mila', 'aaya', 'aayi', 'aaye', 'refund', 'cashback', 'bonus',
        'dividend', 'stipend', 'freelance'])) return VoiceIntent.addIncome;

    if (_anyOf(lower, ['invest', 'invested', 'sip', 'mutual fund', 'mf',
        'share', 'stock', 'equity', 'fd', 'fixed deposit', 'rd', 'recurring',
        'nps', 'gold', 'crypto', 'bitcoin'])) return VoiceIntent.addInvestment;

    if (_anyOf(lower, ['budget for', 'set budget', 'budget limit'])) {
      return VoiceIntent.setBudget;
    }
    if (_anyOf(lower, ['saving for', 'new goal', 'set goal', 'goal for'])) {
      return VoiceIntent.setGoal;
    }
    if (_anyOf(lower, ['balance', 'how much do i have', 'kitna hai', 'kitna bacha'])) {
      return VoiceIntent.queryBalance;
    }
    if (_anyOf(lower, ['how much', 'what did i', 'kitna', 'kitne', 'show me',
        'tell me'])) return VoiceIntent.query;

    if (_anyOf(lower, ['paid', 'spent', 'spend', 'bought', 'purchase',
        'expense', 'bill', 'diya', 'diye', 'kharcha', 'kharch', 'liya',
        'order', 'ordered', 'booked', 'charged', 'deducted', 'ate', 'had'])) {
      return VoiceIntent.addExpense;
    }

    return VoiceIntent.unknown;
  }

  // ── Amount extraction ─────────────────────────────────────────────────────

  double? _extractAmountRules(String lower) {
    final converted = _wordsToNumbers(lower);

    final patterns = [
      RegExp(r'(?:₹|rs\.?\s*|rupees?\s*)([\d,]+(?:\.\d+)?)\s*(k|thousand|lakh|l|cr|crore)?'),
      RegExp(r'([\d,]+(?:\.\d+)?)\s*(?:₹|rs\.?|rupees?)\b'),
      RegExp(r'\b([\d,]+(?:\.\d+)?)\s*(k|thousand|lakh|l|cr|crore)\b'),
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

  String _wordsToNumbers(String s) {
    const map = {
      'zero': '0', 'one': '1', 'two': '2', 'three': '3', 'four': '4',
      'five': '5', 'six': '6', 'seven': '7', 'eight': '8', 'nine': '9',
      'ten': '10', 'eleven': '11', 'twelve': '12', 'thirteen': '13',
      'fourteen': '14', 'fifteen': '15', 'sixteen': '16', 'seventeen': '17',
      'eighteen': '18', 'nineteen': '19', 'twenty': '20', 'thirty': '30',
      'forty': '40', 'fifty': '50', 'sixty': '60', 'seventy': '70',
      'eighty': '80', 'ninety': '90', 'hundred': '100',
      'ek': '1', 'do': '2', 'teen': '3', 'char': '4', 'paanch': '5',
      'chhe': '6', 'saat': '7', 'aath': '8', 'nau': '9', 'das': '10',
      'bees': '20', 'tees': '30', 'chalis': '40', 'pachas': '50',
      'sau': '100', 'hazaar': '1000', 'hazar': '1000',
    };
    var r = s;
    for (final e in map.entries) {
      r = r.replaceAll(RegExp('\\b${e.key}\\b'), e.value);
    }
    return r;
  }

  // ── Account matching ──────────────────────────────────────────────────────

  String? _matchAccount(String lower) {
    for (final name in accountNames) {
      if (lower.contains(name.toLowerCase())) return name;
    }
    const aliases = {
      'savings': ['saving', 'bachat'],
      'salary': ['salary account', 'main account', 'primary'],
      'credit': ['credit card', 'cc'],
      'cash': ['cash', 'wallet', 'hand'],
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
    final m = RegExp(r'\bto\b\s+([a-z][a-z\s]+?)(?:\s+from|\s+using|\s*$)')
        .firstMatch(lower);
    if (m == null) return null;
    final candidate = m.group(1)!.trim();
    return _matchAccount(candidate) ??
        (candidate.length > 1 ? _titleCase(candidate) : null);
  }

  // ── Category matching ─────────────────────────────────────────────────────

  static const _catMap = <String, List<String>>{
    'Food': ['swiggy', 'zomato', 'food', 'eat', 'eating', 'ate', 'lunch',
        'dinner', 'breakfast', 'snack', 'cafe', 'coffee', 'chai', 'tea',
        'restaurant', 'dining', 'dhaba', 'dominos', 'kfc', 'mcdonalds',
        'subway', 'starbucks', 'pizza', 'burger', 'biryani', 'khana', 'bhojan'],
    'Groceries': ['grocery', 'groceries', 'vegetables', 'sabzi', 'fruits',
        'milk', 'doodh', 'kiryana', 'ration', 'blinkit', 'zepto', 'bigbasket',
        'dmart', 'grofers'],
    'Transport': ['uber', 'ola', 'rapido', 'cab', 'taxi', 'auto', 'rickshaw',
        'metro', 'bus', 'train', 'petrol', 'fuel', 'diesel', 'irctc', 'flight',
        'namma yatri', 'makemytrip', 'goibibo', 'cleartrip', 'travel'],
    'Shopping': ['amazon', 'flipkart', 'myntra', 'meesho', 'ajio', 'nykaa',
        'shopping', 'clothes', 'shoes', 'kapde', 'dress'],
    'Entertainment': ['netflix', 'prime', 'hotstar', 'disney', 'spotify',
        'youtube', 'movie', 'cinema', 'pvr', 'inox', 'game', 'gaming'],
    'Health': ['doctor', 'hospital', 'medical', 'medicine', 'dawa', 'dawai',
        'pharmacy', 'gym', 'fitness', 'apollo', 'practo'],
    'Utilities': ['electricity', 'bijli', 'water bill', 'internet', 'wifi',
        'recharge', 'postpaid', 'dth', 'gas', 'cylinder', 'lpg', 'jio',
        'airtel', 'vi', 'bsnl', 'bill'],
    'Rent': ['rent', 'kiraya', 'pg', 'hostel', 'maintenance', 'society'],
    'Insurance': ['insurance', 'lic', 'premium', 'policy'],
    'Investment': ['sip', 'mutual fund', 'mf', 'shares', 'stocks', 'groww',
        'zerodha', 'nps', 'ppf', 'fd', 'gold', 'crypto'],
    'Subscription': ['subscription', 'plan', 'renewal'],
  };

  String? _matchCategory(String lower) {
    for (final cat in categoryNames) {
      if (lower.contains(cat.toLowerCase())) return cat;
    }
    for (final e in _catMap.entries) {
      if (e.value.any((k) => lower.contains(k))) return e.key;
    }
    return null;
  }

  // ── Merchant extraction ───────────────────────────────────────────────────

  String? _extractMerchant(String lower, String raw) {
    const known = ['swiggy', 'zomato', 'amazon', 'flipkart', 'netflix',
        'spotify', 'hotstar', 'prime video', 'uber', 'ola', 'rapido',
        'bigbasket', 'blinkit', 'zepto', 'paytm', 'gpay', 'google pay',
        'phonepe', 'cred', 'myntra', 'nykaa', 'meesho', 'ajio', 'dmart',
        'reliance', 'jio', 'airtel', 'dominos', 'mcdonalds', 'kfc', 'subway',
        'starbucks', 'apollo', 'practo', 'pvr', 'inox', 'irctc', 'makemytrip',
        'goibibo', 'groww', 'zerodha', 'upstox'];
    for (final m in known) {
      if (lower.contains(m)) return _titleCase(m);
    }

    // Preposition patterns
    final preps = [
      RegExp(r"\bat\s+([a-z][a-z\s'-]+?)(?:\s+for|\s+from|\s+yesterday|\s+today|\s*$)"),
      RegExp(r"\bfrom\s+([a-z][a-z\s'-]+?)(?:\s+for|\s+to|\s+yesterday|\s+today|\s*$)"),
      RegExp(r"\bfor\s+([a-z][a-z\s'-]+?)(?:\s+from|\s+using|\s+via|\s+to|\s*$)"),
    ];
    const skip = {'the', 'my', 'a', 'an', 'some', 'it', 'this', 'that',
        'me', 'him', 'her', 'us', 'them', 'free', 'home', 'office'};
    for (final p in preps) {
      final m = p.firstMatch(lower);
      if (m != null) {
        final c = m.group(1)!.trim();
        if (!skip.contains(c) && c.length > 1) return _titleCase(c);
      }
    }

    // Best-guess: first meaningful word after stripping amount + noise
    final noAmt = lower
        .replaceAll(RegExp(r'\b\d[\d,\.]*\s*(?:k|lakh|l|cr|rs|rupees?)?\b'), '')
        .replaceAll(RegExp(r'\b(?:paid|spent|spend|bought|purchase|expense|for|on|at|from|the|a|an|my)\b'), '')
        .trim();
    final words = noAmt.split(RegExp(r'\s+')).where((w) => w.length > 2).toList();
    if (words.isNotEmpty) return _titleCase(words.first);

    return null;
  }

  // ── Date extraction ───────────────────────────────────────────────────────

  DateTime? _extractDate(String lower) {
    final now = DateTime.now();
    if (_anyOf(lower, ['yesterday', 'kal', 'kal ka', 'kal ki'])) {
      return now.subtract(const Duration(days: 1));
    }
    if (_anyOf(lower, ['today', 'aaj', 'just now', 'abhi'])) return now;
    if (_anyOf(lower, ['this morning', 'subah'])) {
      return DateTime(now.year, now.month, now.day, 9, 0);
    }
    if (_anyOf(lower, ['this evening', 'shaam'])) {
      return DateTime(now.year, now.month, now.day, 18, 0);
    }
    if (_anyOf(lower, ['2 days ago', 'day before yesterday', 'parso'])) {
      return now.subtract(const Duration(days: 2));
    }
    const days = ['monday','tuesday','wednesday','thursday','friday','saturday','sunday'];
    for (int i = 0; i < days.length; i++) {
      if (lower.contains(days[i])) {
        final target = i + 1;
        int diff = (now.weekday - target + 7) % 7;
        if (diff == 0) diff = 7;
        return now.subtract(Duration(days: diff));
      }
    }
    return null;
  }

  // ── Investment type ───────────────────────────────────────────────────────

  String? _extractInvestmentType(String lower) {
    if (_anyOf(lower, ['mutual fund', 'mf', 'sip'])) return 'Mutual Fund';
    if (_anyOf(lower, ['share', 'stock', 'equity'])) return 'Stocks';
    if (_anyOf(lower, ['fd', 'fixed deposit'])) return 'FD';
    if (_anyOf(lower, ['rd', 'recurring deposit'])) return 'RD';
    if (_anyOf(lower, ['nps', 'national pension'])) return 'NPS';
    if (_anyOf(lower, ['gold'])) return 'Digital Gold';
    if (_anyOf(lower, ['crypto', 'bitcoin', 'btc', 'eth'])) return 'Crypto';
    if (_anyOf(lower, ['bond'])) return 'Bonds';
    return null;
  }

  (double, double)? _extractUnitsAndPrice(String lower) {
    final m = RegExp(r'(\d+)\s+(?:shares?|units?)\s+at\s+(?:₹|rs\.?)?\s*(\d[\d,]*)')
        .firstMatch(lower);
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
      case 'amount': return 'How much was it?';
      case 'merchant': return 'What was it for?';
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
        return 'New goal "${merchant ?? "Goal"}" for $amtStr. Save?';
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
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
    return v.toInt().toString();
  }
}
