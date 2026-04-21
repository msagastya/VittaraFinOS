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
  final String? followUpQuestion; // null when complete or unknown
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
/// Call [process] with the initial utterance, then [processAnswer] for each follow-up.
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
    final lower = utterance.toLowerCase();

    // Detect intent
    _intent = _detectIntent(lower);
    _extractFields(utterance, lower);

    return _evaluate();
  }

  // ── Follow-up answer ──────────────────────────────────────────────────────

  FillStep processAnswer(String answer) {
    final lower = answer.toLowerCase();

    // Determine which field we're waiting for and fill it
    final missing = _missingRequired();
    if (missing.isEmpty) return _evaluate();

    final field = missing.first;
    switch (field) {
      case 'account':
        final match = _matchAccount(lower);
        if (match != null) _fields['account'] = match;
        break;
      case 'toAccount':
        final match = _matchAccount(lower);
        if (match != null) _fields['toAccount'] = match;
        break;
      case 'amount':
        final amt = _extractAmount(lower);
        if (amt != null) _fields['amount'] = amt;
        break;
      case 'merchant':
        _fields['merchant'] = _titleCase(answer.trim());
        break;
      case 'category':
        final cat = _matchCategory(lower) ?? _titleCase(answer.trim());
        _fields['category'] = cat;
        break;
      case 'investmentType':
        _fields['investmentType'] = _extractInvestmentType(lower) ?? answer.trim();
        break;
      case 'units':
        final units = _extractNumber(lower);
        if (units != null) _fields['units'] = units;
        break;
      case 'pricePerUnit':
        final price = _extractAmount(lower);
        if (price != null) _fields['pricePerUnit'] = price;
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

  // ── Required fields per intent ────────────────────────────────────────────

  List<String> _missingRequired() {
    switch (_intent) {
      case VoiceIntent.addExpense:
      case VoiceIntent.addIncome:
        final r = <String>[];
        if (!_fields.containsKey('amount')) r.add('amount');
        if (!_fields.containsKey('account')) r.add('account');
        if (!_fields.containsKey('merchant') && !_fields.containsKey('category')) r.add('merchant');
        return r;
      case VoiceIntent.addTransfer:
        final r = <String>[];
        if (!_fields.containsKey('amount')) r.add('amount');
        if (!_fields.containsKey('account')) r.add('account');
        if (!_fields.containsKey('toAccount')) r.add('toAccount');
        return r;
      case VoiceIntent.addInvestment:
        final r = <String>[];
        if (!_fields.containsKey('investmentType') && !_fields.containsKey('merchant')) r.add('investmentType');
        if (!_fields.containsKey('amount') && !_fields.containsKey('units')) r.add('amount');
        return r;
      case VoiceIntent.setBudget:
        final r = <String>[];
        if (!_fields.containsKey('category')) r.add('category');
        if (!_fields.containsKey('amount')) r.add('amount');
        return r;
      case VoiceIntent.setGoal:
        final r = <String>[];
        if (!_fields.containsKey('merchant')) r.add('merchant'); // goal name
        if (!_fields.containsKey('amount')) r.add('amount');
        return r;
      case VoiceIntent.query:
      case VoiceIntent.queryBalance:
      case VoiceIntent.queryGoal:
      case VoiceIntent.navigate:
      case VoiceIntent.unknown:
        return [];
    }
  }

  // ── Field extraction ──────────────────────────────────────────────────────

  void _extractFields(String raw, String lower) {
    final amt = _extractAmount(lower);
    if (amt != null) _fields['amount'] = amt;

    final acc = _matchAccount(lower);
    if (acc != null) _fields['account'] = acc;

    final cat = _matchCategory(lower);
    if (cat != null) _fields['category'] = cat;

    final merchant = _extractMerchant(lower);
    if (merchant != null) _fields['merchant'] = merchant;

    final date = _extractDate(lower);
    if (date != null) _fields['date'] = date;

    // Transfer: look for "to <account>"
    final toAcc = _extractToAccount(lower);
    if (toAcc != null) _fields['toAccount'] = toAcc;

    // Investment specifics
    final invType = _extractInvestmentType(lower);
    if (invType != null) _fields['investmentType'] = invType;

    final units = _extractUnitsAndPrice(lower);
    if (units != null) {
      _fields['units'] = units.$1;
      _fields['pricePerUnit'] = units.$2;
      _fields['amount'] = units.$1 * units.$2;
    }
  }

  VoiceIntent _detectIntent(String lower) {
    if (_matchesAny(lower, ['add expense', 'paid', 'spent', 'bought', 'purchase', 'expense'])) {
      return VoiceIntent.addExpense;
    }
    if (_matchesAny(lower, ['received', 'salary', 'income', 'got paid', 'credited', 'add income'])) {
      return VoiceIntent.addIncome;
    }
    if (_matchesAny(lower, ['transfer', 'send', 'moved', 'sent'])) {
      return VoiceIntent.addTransfer;
    }
    if (_matchesAny(lower, ['invested', 'bought shares', 'bought stock', 'sip', 'mutual fund', 'fd', 'investment', 'nps'])) {
      return VoiceIntent.addInvestment;
    }
    if (_matchesAny(lower, ['set budget', 'budget for', 'budget limit'])) {
      return VoiceIntent.setBudget;
    }
    if (_matchesAny(lower, ['new goal', 'saving for', 'set goal'])) {
      return VoiceIntent.setGoal;
    }
    if (_matchesAny(lower, ['how much', 'show me', 'what did i spend', 'spending'])) {
      return VoiceIntent.query;
    }
    if (_matchesAny(lower, ['balance', 'how much do i have', 'my balance'])) {
      return VoiceIntent.queryBalance;
    }
    if (_matchesAny(lower, ['goal', 'how far', 'am i on track'])) {
      return VoiceIntent.queryGoal;
    }
    return VoiceIntent.unknown;
  }

  double? _extractAmount(String lower) {
    // Patterns: "500 rupees", "₹500", "five hundred", "1.5k", "1 lakh"
    final patterns = [
      RegExp(r'(?:rs\.?|₹|rupees?)[\s]*([\d,]+(?:\.\d+)?)'),
      RegExp(r'([\d,]+(?:\.\d+)?)[\s]*(?:rs\.?|₹|rupees?)'),
      RegExp(r'\b([\d,]+(?:\.\d+)?)[\s]*(k|thousand|lakh|l)\b'),
      RegExp(r'\b([\d,]+(?:\.\d+)?)\b'),
    ];
    for (final p in patterns) {
      final m = p.firstMatch(lower);
      if (m != null) {
        var s = m.group(1)!.replaceAll(',', '');
        double v = double.tryParse(s) ?? 0;
        final suffix = (m.groupCount >= 2 ? m.group(2) : null)?.toLowerCase() ?? '';
        if (suffix == 'k' || suffix == 'thousand') v *= 1000;
        if (suffix == 'lakh' || suffix == 'l') v *= 100000;
        if (v > 0) return v;
      }
    }
    return null;
  }

  String? _matchAccount(String lower) {
    for (final name in accountNames) {
      if (lower.contains(name.toLowerCase())) return name;
    }
    // Aliases
    if (_matchesAny(lower, ['main account', 'primary', 'salary account'])) {
      return accountNames.isNotEmpty ? accountNames.first : null;
    }
    if (_matchesAny(lower, ['savings', 'saving account'])) {
      return accountNames.firstWhere(
        (n) => n.toLowerCase().contains('saving'),
        orElse: () => '',
      ).nullIfEmpty;
    }
    return null;
  }

  String? _extractToAccount(String lower) {
    final toMatch = RegExp(r'\bto\b\s+(.+?)(?:\s*$|\s+(?:from|using|via))').firstMatch(lower);
    if (toMatch != null) {
      final candidate = toMatch.group(1)?.trim() ?? '';
      return _matchAccount(candidate) ?? _titleCase(candidate);
    }
    return null;
  }

  String? _matchCategory(String lower) {
    for (final cat in categoryNames) {
      if (lower.contains(cat.toLowerCase())) return cat;
    }
    const map = {
      'food': 'Food',
      'swiggy': 'Food',
      'zomato': 'Food',
      'dining': 'Dining',
      'restaurant': 'Dining',
      'petrol': 'Transport',
      'fuel': 'Transport',
      'uber': 'Transport',
      'ola': 'Transport',
      'medicine': 'Health',
      'doctor': 'Health',
      'hospital': 'Health',
      'amazon': 'Shopping',
      'flipkart': 'Shopping',
      'netflix': 'Entertainment',
      'spotify': 'Entertainment',
      'electricity': 'Utilities',
      'recharge': 'Utilities',
    };
    for (final entry in map.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }
    return null;
  }

  String? _extractMerchant(String lower) {
    // Known merchants
    const merchants = [
      'swiggy', 'zomato', 'amazon', 'flipkart', 'netflix', 'spotify',
      'uber', 'ola', 'bigbasket', 'blinkit', 'zepto', 'paytm', 'gpay',
      'phonepe', 'cred', 'myntra', 'nykaa', 'dmarts', 'reliance',
    ];
    for (final m in merchants) {
      if (lower.contains(m)) {
        return _titleCase(m);
      }
    }
    // "at <merchant>" pattern
    final atMatch = RegExp(r'\bat\s+([a-z][a-z\s]+?)(?:\s+for|\s+from|\s+using|\s*$)').firstMatch(lower);
    if (atMatch != null) return _titleCase(atMatch.group(1)!.trim());
    // "for <merchant>" pattern
    final forMatch = RegExp(r'\bfor\s+([a-z][a-z\s]+?)(?:\s+from|\s+using|\s*$)').firstMatch(lower);
    if (forMatch != null) return _titleCase(forMatch.group(1)!.trim());
    return null;
  }

  DateTime? _extractDate(String lower) {
    final now = DateTime.now();
    if (lower.contains('yesterday')) {
      return now.subtract(const Duration(days: 1));
    }
    if (lower.contains('today') || lower.contains('just now')) return now;
    if (lower.contains('this morning')) {
      return DateTime(now.year, now.month, now.day, 9, 0);
    }
    if (lower.contains('last friday')) {
      final daysBack = (now.weekday + 2) % 7 + 1;
      return now.subtract(Duration(days: daysBack));
    }
    return null;
  }

  String? _extractInvestmentType(String lower) {
    if (_matchesAny(lower, ['mutual fund', 'mf', 'sip'])) return 'Mutual Fund';
    if (_matchesAny(lower, ['share', 'stock', 'equity'])) return 'Stocks';
    if (_matchesAny(lower, ['fd', 'fixed deposit'])) return 'FD';
    if (_matchesAny(lower, ['rd', 'recurring deposit'])) return 'RD';
    if (_matchesAny(lower, ['nps'])) return 'NPS';
    if (_matchesAny(lower, ['gold'])) return 'Digital Gold';
    if (_matchesAny(lower, ['crypto', 'bitcoin', 'btc', 'eth'])) return 'Crypto';
    return null;
  }

  (double, double)? _extractUnitsAndPrice(String lower) {
    // "20 shares at 2800" or "10 units at 150 each"
    final m = RegExp(r'(\d+)\s+(?:shares?|units?)\s+at\s+(?:₹|rs\.?)?\s*(\d[\d,]*)').firstMatch(lower);
    if (m != null) {
      final units = double.tryParse(m.group(1)!) ?? 0;
      final price = double.tryParse(m.group(2)!.replaceAll(',', '')) ?? 0;
      if (units > 0 && price > 0) return (units, price);
    }
    return null;
  }

  double? _extractNumber(String lower) {
    final m = RegExp(r'\b(\d[\d,]*(?:\.\d+)?)\b').firstMatch(lower);
    if (m != null) return double.tryParse(m.group(1)!.replaceAll(',', ''));
    return null;
  }

  // ── Questions ─────────────────────────────────────────────────────────────

  String _questionFor(String field) {
    switch (field) {
      case 'account':
        if (accountNames.isEmpty) return 'Which account was this from?';
        final list = accountNames.take(3).join(', ');
        return 'Which account — $list?';
      case 'toAccount':
        if (accountNames.isEmpty) return 'Which account did you transfer to?';
        final list = accountNames.take(3).join(', ');
        return 'To which account — $list?';
      case 'amount':
        return 'How much was it?';
      case 'merchant':
        return 'What was this for?';
      case 'category':
        final topCats = categoryNames.take(3).join(', ');
        return 'Which category — $topCats, or something else?';
      case 'investmentType':
        return 'What type of investment — stocks, mutual fund, FD, or something else?';
      case 'units':
        return 'How many units or shares?';
      case 'pricePerUnit':
        return 'At what price per unit?';
      default:
        return 'Can you give me more details?';
    }
  }

  // ── Confirmation ──────────────────────────────────────────────────────────

  String _buildConfirmation() {
    final amt = _fields['amount'] as double?;
    final acc = _fields['account'] as String?;
    final merchant = _fields['merchant'] as String?;
    final cat = _fields['category'] as String?;
    final toAcc = _fields['toAccount'] as String?;
    final invType = _fields['investmentType'] as String?;
    final units = _fields['units'] as double?;

    final amtStr = amt != null ? '₹${_fmtAmt(amt)}' : '';

    switch (_intent) {
      case VoiceIntent.addExpense:
        final desc = merchant ?? cat ?? 'expense';
        return '$amtStr $desc expense${acc != null ? ' from $acc' : ''}. Confirm?';
      case VoiceIntent.addIncome:
        final src = merchant ?? cat ?? 'income';
        return '$amtStr $src${acc != null ? ' to $acc' : ''}. Confirm?';
      case VoiceIntent.addTransfer:
        return 'Transfer $amtStr from ${acc ?? 'account'} to ${toAcc ?? 'account'}. Confirm?';
      case VoiceIntent.addInvestment:
        final type = invType ?? merchant ?? 'investment';
        if (units != null) {
          final price = _fields['pricePerUnit'] as double?;
          return '${units.toInt()} $type units at ₹${price?.toInt() ?? 0} each — total $amtStr. Confirm?';
        }
        return '$amtStr $type investment. Confirm?';
      case VoiceIntent.setBudget:
        return 'Set ${cat ?? 'category'} budget to $amtStr. Confirm?';
      case VoiceIntent.setGoal:
        final goalName = merchant ?? 'goal';
        return 'New goal "$goalName" for $amtStr. Confirm?';
      case VoiceIntent.query:
        return 'Checking your spending now.';
      case VoiceIntent.queryBalance:
        return 'Checking your balance now.';
      case VoiceIntent.queryGoal:
        return 'Checking your goal progress.';
      case VoiceIntent.navigate:
        return 'Navigating now.';
      case VoiceIntent.unknown:
        return "I didn't understand that. Please try again.";
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  bool _matchesAny(String text, List<String> keywords) =>
      keywords.any((k) => text.contains(k));

  String _titleCase(String s) {
    if (s.isEmpty) return s;
    return s.split(' ').map((w) => w.isEmpty
        ? w
        : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');
  }

  String _fmtAmt(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
    return v.toInt().toString();
  }
}

extension on String {
  String? get nullIfEmpty => isEmpty ? null : this;
}
