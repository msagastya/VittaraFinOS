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
  final String? followUpQuestion; // null when complete
  final String confirmationText;  // spoken when isComplete = true

  const FillStep({
    required this.intent,
    required this.fields,
    required this.isComplete,
    this.followUpQuestion,
    this.confirmationText = '',
  });
}

/// Stateful conversational fill engine.
///
/// Design principle: be as lenient as possible.
/// - Amount is the ONLY required field for expense/income.
/// - Account is never required — auto-use first account or leave unset.
/// - Unknown intent with an amount → default to expense.
/// - Broken English, Hinglish, partial sentences → all accepted.
class VoiceFillEngine {
  final List<String> accountNames;
  final List<String> categoryNames;
  final IntelligenceTier tier;

  Map<String, dynamic> _fields = {};
  VoiceIntent _intent = VoiceIntent.unknown;

  VoiceFillEngine({
    required this.accountNames,
    required this.categoryNames,
    required this.tier,
  });

  void reset() {
    _fields = {};
    _intent = VoiceIntent.unknown;
  }

  // ── Initial utterance ─────────────────────────────────────────────────────

  FillStep process(String utterance) {
    reset();
    final lower = _normalise(utterance);

    _intent = _detectIntent(lower, utterance);
    _extractFields(utterance, lower);

    // Unknown intent but has amount → default to expense
    if (_intent == VoiceIntent.unknown &&
        _fields.containsKey('amount') &&
        (_fields['amount'] as double) > 0) {
      _intent = VoiceIntent.addExpense;
    }

    return _evaluate();
  }

  // ── Follow-up answer ──────────────────────────────────────────────────────

  FillStep processAnswer(String answer) {
    final lower = _normalise(answer);
    final missing = _missingRequired();
    if (missing.isEmpty) return _evaluate();

    final field = missing.first;
    switch (field) {
      case 'amount':
        final amt = _extractAmount(lower);
        if (amt != null) _fields['amount'] = amt;
        break;
      case 'merchant':
        // Accept anything as a description
        final words = answer.trim().split(' ');
        final meaningful = words.where((w) => w.length > 1).join(' ');
        _fields['merchant'] = _titleCase(meaningful.isNotEmpty ? meaningful : answer.trim());
        break;
    }

    return _evaluate();
  }

  // ── Evaluation ────────────────────────────────────────────────────────────

  FillStep _evaluate() {
    final missing = _missingRequired();
    if (missing.isEmpty) {
      return FillStep(
        intent: _intent,
        fields: Map.from(_fields),
        isComplete: true,
        confirmationText: _buildConfirmation(),
      );
    }
    return FillStep(
      intent: _intent,
      fields: Map.from(_fields),
      isComplete: false,
      followUpQuestion: _questionFor(missing.first),
    );
  }

  // ── Required fields — kept minimal ────────────────────────────────────────

  List<String> _missingRequired() {
    switch (_intent) {
      case VoiceIntent.addExpense:
      case VoiceIntent.addIncome:
        // Only amount is truly required; merchant is optional
        if (!_fields.containsKey('amount')) return ['amount'];
        return [];
      case VoiceIntent.addTransfer:
        if (!_fields.containsKey('amount')) return ['amount'];
        return [];
      case VoiceIntent.addInvestment:
        if (!_fields.containsKey('amount') && !_fields.containsKey('units')) return ['amount'];
        return [];
      case VoiceIntent.setBudget:
        if (!_fields.containsKey('amount')) return ['amount'];
        return [];
      case VoiceIntent.setGoal:
        if (!_fields.containsKey('amount')) return ['amount'];
        return [];
      default:
        return [];
    }
  }

  // ── Field extraction ──────────────────────────────────────────────────────

  void _extractFields(String raw, String lower) {
    // Amount — try word-based first, then numeric patterns
    final amt = _extractAmount(lower);
    if (amt != null) _fields['amount'] = amt;

    // Date
    final date = _extractDate(lower);
    if (date != null) _fields['date'] = date;

    // Account matching
    final acc = _matchAccount(lower);
    if (acc != null) _fields['account'] = acc;

    // Transfer destination
    if (_intent == VoiceIntent.addTransfer || lower.contains(' to ')) {
      final toAcc = _extractToAccount(lower);
      if (toAcc != null) _fields['toAccount'] = toAcc;
    }

    // Category
    final cat = _matchCategory(lower);
    if (cat != null) _fields['category'] = cat;

    // Merchant — try known brands first, then preposition patterns
    final merchant = _extractMerchant(lower, raw);
    if (merchant != null) _fields['merchant'] = merchant;

    // Investment type
    final invType = _extractInvestmentType(lower);
    if (invType != null) _fields['investmentType'] = invType;

    // Units × price (e.g. "20 shares at 2800")
    final up = _extractUnitsAndPrice(lower);
    if (up != null) {
      _fields['units'] = up.$1;
      _fields['pricePerUnit'] = up.$2;
      _fields['amount'] = up.$1 * up.$2;
    }
  }

  // ── Intent detection — very lenient ──────────────────────────────────────

  VoiceIntent _detectIntent(String lower, String raw) {
    // Transfer signals (check before expense — "sent" could be expense)
    if (_anyWord(lower, ['transfer', 'transferred', 'send', 'sent to', 'moved to', 'bheja',
        'bhej', 'bhejo', 'bhejna'])) {
      return VoiceIntent.addTransfer;
    }

    // Income signals
    if (_anyWord(lower, [
      'received', 'receive', 'salary', 'income', 'got paid', 'got money',
      'credited', 'add income', 'earning', 'earned', 'mila', 'aaya', 'aayi',
      'aaye', 'refund', 'cashback', 'bonus', 'dividend', 'rental income',
      'pocket money', 'stipend', 'freelance payment',
    ])) {
      return VoiceIntent.addIncome;
    }

    // Investment signals
    if (_anyWord(lower, [
      'invest', 'invested', 'sip', 'mutual fund', 'mf', 'share', 'stock',
      'equity', 'fd', 'fixed deposit', 'rd', 'recurring', 'nps', 'gold',
      'crypto', 'bitcoin', 'bought shares', 'bought stock', 'lagaya',
    ])) {
      return VoiceIntent.addInvestment;
    }

    // Budget / goal
    if (_anyWord(lower, ['budget for', 'set budget', 'budget limit', 'monthly budget'])) {
      return VoiceIntent.setBudget;
    }
    if (_anyWord(lower, ['saving for', 'new goal', 'set goal', 'goal for', 'want to buy',
        'want to save'])) {
      return VoiceIntent.setGoal;
    }

    // Query
    if (_anyWord(lower, ['how much', 'show me', 'what did i', 'spending on', 'tell me',
        'kitna', 'kitne', 'how many'])) {
      return VoiceIntent.query;
    }
    if (_anyWord(lower, ['balance', 'how much do i have', 'my balance', 'account balance',
        'kitna hai', 'kitna bacha'])) {
      return VoiceIntent.queryBalance;
    }

    // Expense signals — very broad
    if (_anyWord(lower, [
      'paid', 'spent', 'spend', 'bought', 'purchase', 'purchased',
      'expense', 'bill', 'fee', 'diya', 'diye', 'kharcha', 'kharch',
      'liya', 'order', 'ordered', 'booked', 'charged', 'deducted',
      'cut', 'went', 'used', 'ate', 'had', 'took', 'grabbed', 'picked up',
    ])) {
      return VoiceIntent.addExpense;
    }

    // If there's an amount and a merchant-like word → assume expense
    return VoiceIntent.unknown;
  }

  // ── Amount extraction — handles words + numbers + Hinglish ───────────────

  double? _extractAmount(String lower) {
    // Convert spoken words to numbers first
    final converted = _wordsToNumbers(lower);

    // Ordered patterns from most specific to least
    final patterns = [
      // "₹500", "rs 500", "rupees 500" — currency prefix
      RegExp(r'(?:₹|rs\.?\s*|rupees?\s*)([\d,]+(?:\.\d+)?)\s*(k|thousand|lakh|l|cr|crore)?'),
      // "500 rupees", "500 rs" — currency suffix
      RegExp(r'([\d,]+(?:\.\d+)?)\s*(?:₹|rs\.?|rupees?)\b'),
      // "1.5k", "2L", "3 lakh", "50k"
      RegExp(r'\b([\d,]+(?:\.\d+)?)\s*(k|thousand|lakh|l|cr|crore)\b'),
      // Plain number — last resort
      RegExp(r'\b(\d[\d,]*(?:\.\d+)?)\b'),
    ];

    for (final p in patterns) {
      final m = p.firstMatch(converted);
      if (m != null) {
        final s = m.group(1)!.replaceAll(',', '');
        double v = double.tryParse(s) ?? 0;
        if (v <= 0) continue;
        final suf = (m.groupCount >= 2 ? m.group(2) : null)?.toLowerCase() ?? '';
        if (suf == 'k' || suf == 'thousand') v *= 1000;
        if (suf == 'lakh' || suf == 'l') v *= 100000;
        if (suf == 'cr' || suf == 'crore') v *= 10000000;
        if (v > 0) return v;
      }
    }
    return null;
  }

  /// Convert common spoken number words to digits.
  String _wordsToNumbers(String s) {
    const words = {
      'zero': '0', 'one': '1', 'two': '2', 'three': '3', 'four': '4',
      'five': '5', 'six': '6', 'seven': '7', 'eight': '8', 'nine': '9',
      'ten': '10', 'eleven': '11', 'twelve': '12', 'thirteen': '13',
      'fourteen': '14', 'fifteen': '15', 'sixteen': '16', 'seventeen': '17',
      'eighteen': '18', 'nineteen': '19', 'twenty': '20', 'thirty': '30',
      'forty': '40', 'fifty': '50', 'sixty': '60', 'seventy': '70',
      'eighty': '80', 'ninety': '90', 'hundred': '100',
      // Hinglish
      'ek': '1', 'do': '2', 'teen': '3', 'char': '4', 'paanch': '5',
      'chhe': '6', 'saat': '7', 'aath': '8', 'nau': '9', 'das': '10',
      'bees': '20', 'tees': '30', 'chalis': '40', 'pachas': '50',
      'sau': '100', 'hazaar': '1000', 'hazar': '1000',
    };
    var result = s;
    for (final e in words.entries) {
      result = result.replaceAll(RegExp('\\b${e.key}\\b'), e.value);
    }
    return result;
  }

  String? _matchAccount(String lower) {
    for (final name in accountNames) {
      if (lower.contains(name.toLowerCase())) return name;
    }
    // Fuzzy aliases
    const aliases = {
      'savings': ['saving', 'bachat'],
      'current': ['current account', 'business account'],
      'salary': ['salary account', 'main account', 'primary'],
      'credit': ['credit card', 'cc', 'card'],
      'cash': ['cash', 'wallet', 'hand'],
    };
    for (final entry in aliases.entries) {
      if (entry.value.any((a) => lower.contains(a))) {
        final match = accountNames.firstWhere(
          (n) => n.toLowerCase().contains(entry.key),
          orElse: () => '',
        );
        if (match.isNotEmpty) return match;
      }
    }
    return null;
  }

  String? _extractToAccount(String lower) {
    final m = RegExp(r'\bto\b\s+([a-z][a-z\s]+?)(?:\s+from|\s+using|\s+via|\s*$)').firstMatch(lower);
    if (m == null) return null;
    final candidate = m.group(1)?.trim() ?? '';
    return _matchAccount(candidate) ?? (candidate.length > 1 ? _titleCase(candidate) : null);
  }

  String? _matchCategory(String lower) {
    // Check user's own category names first
    for (final cat in categoryNames) {
      if (lower.contains(cat.toLowerCase())) return cat;
    }
    // Broad category inference
    const map = <String, List<String>>{
      'Food': ['swiggy', 'zomato', 'food', 'eat', 'eating', 'lunch', 'dinner',
          'breakfast', 'snack', 'cafe', 'coffee', 'chai', 'restaurant',
          'biryani', 'pizza', 'burger', 'khana', 'khaana', 'bhojan',
          'dominos', 'mcdonalds', 'kfc', 'subway', 'starbucks'],
      'Groceries': ['grocery', 'groceries', 'vegetables', 'fruits', 'milk',
          'blinkit', 'zepto', 'bigbasket', 'dmart', 'reliance fresh',
          'sabzi', 'doodh', 'kiryana'],
      'Transport': ['uber', 'ola', 'rapido', 'namma yatri', 'metro', 'bus',
          'auto', 'cab', 'taxi', 'petrol', 'fuel', 'diesel', 'irctc',
          'train', 'flight', 'bus ticket', 'travel', 'gaadi', 'tanga'],
      'Shopping': ['amazon', 'flipkart', 'myntra', 'meesho', 'ajio', 'nykaa',
          'shopping', 'clothes', 'clothing', 'shoes', 'apparel', 'kapde'],
      'Health': ['doctor', 'hospital', 'medical', 'medicine', 'pharmacy',
          'pharma', 'gym', 'fitness', 'apollo', 'practo', 'health'],
      'Entertainment': ['netflix', 'prime', 'hotstar', 'disney', 'spotify',
          'youtube', 'movie', 'cinema', 'multiplex', 'pvr', 'inox', 'game',
          'gaming'],
      'Utilities': ['electricity', 'light bill', 'bijli', 'water bill',
          'internet', 'wifi', 'broadband', 'mobile recharge', 'recharge',
          'postpaid', 'dth', 'gas', 'cylinder', 'lpg'],
      'Rent': ['rent', 'house rent', 'kiraya', 'pg', 'hostel', 'maintenance',
          'society', 'housing'],
      'Insurance': ['insurance', 'lic', 'premium', 'policy', 'term plan'],
      'Subscription': ['subscription', 'plan', 'renewal', 'annual plan'],
    };
    for (final entry in map.entries) {
      if (entry.value.any((k) => lower.contains(k))) return entry.key;
    }
    return null;
  }

  String? _extractMerchant(String lower, String raw) {
    // 1. Known merchant list — check first
    const known = [
      'swiggy', 'zomato', 'amazon', 'flipkart', 'netflix', 'spotify', 'hotstar',
      'prime video', 'youtube', 'uber', 'ola', 'rapido', 'bigbasket', 'blinkit',
      'zepto', 'paytm', 'gpay', 'google pay', 'phonepe', 'cred', 'myntra',
      'nykaa', 'meesho', 'ajio', 'dmart', 'reliance', 'jio', 'airtel', 'vi',
      'bsnl', 'dominos', 'mcdonalds', 'kfc', 'subway', 'starbucks', 'dunzo',
      'instamart', 'grofers', 'apollo', 'practo', 'pvr', 'inox', 'irctc',
      'makemytrip', 'goibibo', 'cleartrip', 'groww', 'zerodha', 'upstox',
    ];
    for (final m in known) {
      if (lower.contains(m)) return _titleCase(m);
    }

    // 2. Pattern: "at <place>", "from <place>", "on <place>"
    final preps = [
      RegExp(r"\bat\s+([a-z][a-z\s'-]+?)(?:\s+for|\s+from|\s+using|\s+yesterday|\s+today|\s*$)"),
      RegExp(r"\bfrom\s+([a-z][a-z\s'-]+?)(?:\s+for|\s+to|\s+using|\s+yesterday|\s+today|\s*$)"),
      RegExp(r"\bon\s+([a-z][a-z\s'-]+?)(?:\s+for|\s+from|\s+using|\s+yesterday|\s+today|\s*$)"),
    ];
    for (final p in preps) {
      final m = p.firstMatch(lower);
      if (m != null) {
        final candidate = m.group(1)!.trim();
        // Filter out time/quantity words
        const skip = {'the', 'my', 'a', 'an', 'some', 'it', 'this', 'that',
            'home', 'office', 'night', 'morning', 'evening', 'yesterday', 'today'};
        if (!skip.contains(candidate) && candidate.length > 1) {
          return _titleCase(candidate);
        }
      }
    }

    // 3. "for <description>" — common pattern
    final forMatch = RegExp(r"\bfor\s+([a-z][a-z\s'-]+?)(?:\s+from|\s+using|\s+via|\s+to|\s*$)").firstMatch(lower);
    if (forMatch != null) {
      final candidate = forMatch.group(1)!.trim();
      const skip = {'the', 'a', 'an', 'my', 'some', 'this', 'that', 'me',
          'him', 'her', 'us', 'them', 'it', 'free', 'nothing'};
      if (!skip.contains(candidate) && candidate.length > 1) {
        return _titleCase(candidate);
      }
    }

    // 4. First "proper" word after amount removal — best guess for short utterances
    // e.g. "500 swiggy" → "Swiggy"
    final noAmt = lower
        .replaceAll(RegExp(r'\b\d[\d,\.]*\s*(?:k|lakh|l|cr|rs|rupees?)?\b'), '')
        .replaceAll(RegExp(r'\b(?:paid|spent|spend|bought|purchase|expense|for|on|at|from|the|a|an|my)\b'), '')
        .trim();
    final words = noAmt.split(RegExp(r'\s+')).where((w) => w.length > 2).toList();
    if (words.isNotEmpty) return _titleCase(words.first);

    return null;
  }

  DateTime? _extractDate(String lower) {
    final now = DateTime.now();
    if (_anyWord(lower, ['yesterday', 'kal', 'kal ka', 'kal ki'])) {
      return now.subtract(const Duration(days: 1));
    }
    if (_anyWord(lower, ['today', 'aaj', 'just now', 'abhi'])) return now;
    if (_anyWord(lower, ['this morning', 'subah'])) {
      return DateTime(now.year, now.month, now.day, 9, 0);
    }
    if (_anyWord(lower, ['this evening', 'shaam', 'evening'])) {
      return DateTime(now.year, now.month, now.day, 18, 0);
    }
    if (_anyWord(lower, ['2 days ago', 'day before yesterday', 'parso', 'parson'])) {
      return now.subtract(const Duration(days: 2));
    }
    // "last monday/tuesday/..."
    const days = ['monday','tuesday','wednesday','thursday','friday','saturday','sunday'];
    for (int i = 0; i < days.length; i++) {
      if (lower.contains(days[i])) {
        final target = i + 1; // DateTime weekday is 1=Monday
        int diff = (now.weekday - target + 7) % 7;
        if (diff == 0) diff = 7; // "last X" means previous week's X
        return now.subtract(Duration(days: diff));
      }
    }
    return null;
  }

  String? _extractInvestmentType(String lower) {
    if (_anyWord(lower, ['mutual fund', 'mf', 'sip'])) return 'Mutual Fund';
    if (_anyWord(lower, ['share', 'stock', 'equity', 'nifty', 'sensex'])) return 'Stocks';
    if (_anyWord(lower, ['fd', 'fixed deposit'])) return 'FD';
    if (_anyWord(lower, ['rd', 'recurring deposit'])) return 'RD';
    if (_anyWord(lower, ['nps', 'national pension'])) return 'NPS';
    if (_anyWord(lower, ['gold', 'digital gold', 'sovereign gold'])) return 'Digital Gold';
    if (_anyWord(lower, ['crypto', 'bitcoin', 'btc', 'eth', 'ethereum'])) return 'Crypto';
    if (_anyWord(lower, ['bond', 'debenture'])) return 'Bonds';
    return null;
  }

  (double, double)? _extractUnitsAndPrice(String lower) {
    final m = RegExp(r'(\d+)\s+(?:shares?|units?)\s+at\s+(?:₹|rs\.?)?\s*(\d[\d,]*)').firstMatch(lower);
    if (m != null) {
      final units = double.tryParse(m.group(1)!) ?? 0;
      final price = double.tryParse(m.group(2)!.replaceAll(',', '')) ?? 0;
      if (units > 0 && price > 0) return (units, price);
    }
    return null;
  }

  // ── Questions ─────────────────────────────────────────────────────────────

  String _questionFor(String field) {
    switch (field) {
      case 'amount':
        return 'How much was it?';
      case 'merchant':
        return 'What was it for?';
      default:
        return 'Can you say that again?';
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
        if (acc != null) return '$amtStr expense from $acc. Save?';
        return '$amtStr expense. Save?';
      case VoiceIntent.addIncome:
        if (desc != null) return '$amtStr from $desc${acc != null ? " to $acc" : ""}. Save?';
        return '$amtStr income${acc != null ? " to $acc" : ""}. Save?';
      case VoiceIntent.addTransfer:
        final from = acc ?? 'your account';
        final to = toAcc ?? 'another account';
        return 'Transfer $amtStr from $from to $to. Save?';
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
      case VoiceIntent.query:
        return 'Checking your spending.';
      case VoiceIntent.queryBalance:
        return 'Checking your balance.';
      case VoiceIntent.queryGoal:
        return 'Checking your goal.';
      case VoiceIntent.navigate:
        return 'Opening it now.';
      case VoiceIntent.unknown:
        return 'Got it. Save?';
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  bool _anyWord(String text, List<String> keywords) =>
      keywords.any((k) => text.contains(k));

  String _normalise(String s) => s.toLowerCase().trim();

  String _titleCase(String s) => s
      .split(' ')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');

  String _fmtAmt(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
    return v.toInt().toString();
  }
}
