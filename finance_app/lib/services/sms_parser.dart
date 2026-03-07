import 'package:flutter/foundation.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:google_mlkit_entity_extraction/google_mlkit_entity_extraction.dart';
import 'package:vittara_fin_os/services/bank_sms_patterns.dart';

/// Result of parsing one SMS message.
class ParsedSms {
  final double amount;
  final String type; // 'expense' or 'income'
  final String? merchant;
  final String? accountLast4;
  final String? cardLast4;
  final String? upiId;
  final double? balance;
  final String? bankId;
  final DateTime date;
  final String rawMessage;
  final String sender;
  final double confidence; // 0.0 – 1.0
  final String parseMethod; // for debug

  ParsedSms({
    required this.amount,
    required this.type,
    required this.merchant,
    required this.accountLast4,
    required this.cardLast4,
    required this.upiId,
    required this.balance,
    required this.bankId,
    required this.date,
    required this.rawMessage,
    required this.sender,
    required this.confidence,
    required this.parseMethod,
  });
}

class SmsParser {
  EntityExtractor? _extractor;
  bool _extractorReady = false;

  SmsParser() {
    _initMlKit();
  }

  Future<void> _initMlKit() async {
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

  /// Parse a single SMS. Returns null if it cannot be parsed as a transaction.
  /// [enabledBankSenderIds]: map of bankId → List<senderIds> for user's enabled banks.
  Future<ParsedSms?> parse(
    SmsMessage msg,
    Map<String, List<String>> enabledBankSenderIds,
  ) async {
    final sender = msg.address ?? '';
    final body = msg.body ?? '';
    final date = msg.date ?? DateTime.now();

    // Pass 1 — bank-specific patterns
    final pass1 =
        _parseWithBankPatterns(sender, body, date, enabledBankSenderIds);
    if (pass1 != null) return pass1;

    // Pass 2 — ML Kit entity extraction
    if (_extractorReady && _extractor != null) {
      final pass2 =
          await _parseWithMlKit(sender, body, date, enabledBankSenderIds);
      if (pass2 != null) return pass2;
    }

    // Pass 3 — generic regex fallback
    return _parseWithGenericRegex(sender, body, date, enabledBankSenderIds);
  }

  // ---------------------------------------------------------------------------
  // PASS 1 — bank-specific patterns
  // ---------------------------------------------------------------------------
  ParsedSms? _parseWithBankPatterns(
    String sender,
    String body,
    DateTime date,
    Map<String, List<String>> enabledBankSenderIds,
  ) {
    final senderUp = sender.toUpperCase();
    final bodyLower = body.toLowerCase();

    // Find which enabled bank this sender belongs to
    String? matchedBankId;
    BankPattern? bankPattern;

    for (final entry in enabledBankSenderIds.entries) {
      final bankId = entry.key;
      final senderIds = entry.value;
      if (senderIds.any((id) => senderUp.contains(id.toUpperCase()))) {
        matchedBankId = bankId;
        bankPattern = BankSmsPatterns.all[bankId];
        break;
      }
    }

    // If user has configured banks but sender doesn't match any — reject
    if (enabledBankSenderIds.isNotEmpty && matchedBankId == null) return null;

    // If no user config, try default patterns for all banks
    if (bankPattern == null) {
      for (final bp in BankSmsPatterns.all.values) {
        if (bp.matchesSender(sender)) {
          bankPattern = bp;
          matchedBankId = bp.bankId;
          break;
        }
      }
    }

    if (bankPattern == null) return null;

    final isDebit = _isDebit(bodyLower);
    final patterns =
        isDebit ? bankPattern.debitPatterns : bankPattern.creditPatterns;

    for (final p in patterns) {
      final m = p.match(body);
      if (m == null) continue;
      final amtStr = m.group(p.amountGroup)?.replaceAll(',', '');
      final amount = amtStr != null ? double.tryParse(amtStr) : null;
      if (amount == null || amount < 1 || amount > 1e8) continue;

      String? acctLast4;
      if (p.accountGroup != null && p.accountGroup! <= m.groupCount) {
        acctLast4 = m.group(p.accountGroup!);
      }
      String? cardLast4;
      if (p.cardGroup != null && p.cardGroup! <= m.groupCount) {
        cardLast4 = m.group(p.cardGroup!);
      }

      return ParsedSms(
        amount: amount,
        type: isDebit ? 'expense' : 'income',
        merchant: _extractMerchant(body),
        accountLast4: acctLast4 ?? _extractAccountLast4(body),
        cardLast4: cardLast4 ?? _extractCardLast4(body),
        upiId: _extractUpiId(body),
        balance: _extractBalance(body),
        bankId: matchedBankId,
        date: date,
        rawMessage: body,
        sender: sender,
        confidence: 0.95,
        parseMethod: 'bank_pattern:${p.description}',
      );
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // PASS 2 — ML Kit MoneyEntity extraction
  // ---------------------------------------------------------------------------
  Future<ParsedSms?> _parseWithMlKit(
    String sender,
    String body,
    DateTime date,
    Map<String, List<String>> enabledBankSenderIds,
  ) async {
    try {
      final annotations = await _extractor!.annotateText(body);
      final List<({double amount, int pos})> amounts = [];
      DateTime? extractedDate;

      for (final a in annotations) {
        for (final e in a.entities) {
          if (e is MoneyEntity) {
            final val = e.integerPart.toDouble() +
                (e.fractionPart > 0 ? e.fractionPart / 100.0 : 0);
            if (val >= 1 && val <= 1e8) {
              amounts.add((amount: val, pos: a.start));
            }
          } else if (e is DateTimeEntity) {
            extractedDate = DateTime.fromMillisecondsSinceEpoch(e.timestamp);
          }
        }
      }

      if (amounts.isEmpty) return null;

      final bodyLower = body.toLowerCase();
      final amount = _scoreBestAmount(bodyLower, amounts);
      if (amount == null) return null;

      final bankId = _guessBankFromSender(sender, enabledBankSenderIds);
      return ParsedSms(
        amount: amount,
        type: _isDebit(bodyLower) ? 'expense' : 'income',
        merchant: _extractMerchant(body),
        accountLast4: _extractAccountLast4(body),
        cardLast4: _extractCardLast4(body),
        upiId: _extractUpiId(body),
        balance: _extractBalance(body),
        bankId: bankId,
        date: extractedDate ?? date,
        rawMessage: body,
        sender: sender,
        confidence: 0.80,
        parseMethod: 'mlkit',
      );
    } catch (e) {
      debugPrint('MLKit parse error: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // PASS 3 — generic regex
  // ---------------------------------------------------------------------------
  ParsedSms? _parseWithGenericRegex(
    String sender,
    String body,
    DateTime date,
    Map<String, List<String>> enabledBankSenderIds,
  ) {
    final bodyLower = body.toLowerCase();

    final patterns = [
      // "Rs.2498.00 Dr." / "Rs.136.00 Cr."
      RegExp(r'(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{2})?)\s+(?:dr\.?|cr\.?)\b',
          caseSensitive: false),
      // "debited Rs 1000" / "credited INR 500"
      RegExp(
          r'(?:debited|credited|paid|received|withdrawn|deposited|spent)\s+(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{2})?)',
          caseSensitive: false),
      // "Rs 1000 debited"
      RegExp(
          r'(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{2})?)\s+(?:debited|credited|paid|spent)',
          caseSensitive: false),
      // "Amount: Rs 1000"
      RegExp(r'(?:amount|amt)[\s:]+(?:rs\.?|inr|₹)?\s*([\d,]+(?:\.\d{2})?)',
          caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final m = pattern.firstMatch(bodyLower);
      if (m == null) continue;
      final amtStr = m.group(1)?.replaceAll(',', '');
      final amount = amtStr != null ? double.tryParse(amtStr) : null;
      if (amount == null || amount < 1 || amount > 1e8) continue;
      if (_isBalanceContext(bodyLower, m.start, m.end)) continue;

      final bankId = _guessBankFromSender(sender, enabledBankSenderIds);
      return ParsedSms(
        amount: amount,
        type: _isDebit(bodyLower) ? 'expense' : 'income',
        merchant: _extractMerchant(body),
        accountLast4: _extractAccountLast4(body),
        cardLast4: _extractCardLast4(body),
        upiId: _extractUpiId(body),
        balance: _extractBalance(body),
        bankId: bankId,
        date: date,
        rawMessage: body,
        sender: sender,
        confidence: 0.65,
        parseMethod: 'generic_regex',
      );
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  bool _isDebit(String bodyLower) {
    const debitWords = [
      'debited',
      'deducted',
      'dr.',
      ' dr ',
      'paid',
      'spent',
      'withdrawn',
      'payment of',
      'purchase of',
    ];
    const creditWords = [
      'credited',
      'cr.',
      ' cr ',
      'received',
      'deposited',
      'refund',
      'cashback',
      'reversed',
    ];
    final dIdx = debitWords
        .map((w) => bodyLower.indexOf(w))
        .where((i) => i >= 0)
        .fold<int>(bodyLower.length, (a, b) => a < b ? a : b);
    final cIdx = creditWords
        .map((w) => bodyLower.indexOf(w))
        .where((i) => i >= 0)
        .fold<int>(bodyLower.length, (a, b) => a < b ? a : b);
    return dIdx <= cIdx; // debit wins tie → default expense
  }

  double? _scoreBestAmount(
    String bodyLower,
    List<({double amount, int pos})> amounts,
  ) {
    const balanceKeywords = [
      'avl bal',
      'avlbal',
      'available balance',
      'avail bal',
      'total bal',
      'current bal',
      'closing bal',
      'balance:',
      'bal:',
      'outstanding',
      'limit is',
      'balance is',
      '(bal',
      '(avl',
    ];
    const txnKeywords = [
      'debited',
      'credited',
      'paid',
      'received',
      'dr.',
      'cr.'
    ];

    List<({double amount, int score})> scored = [];
    for (final a in amounts) {
      int score = 0;
      final start = (a.pos - 70).clamp(0, bodyLower.length);
      final end = (a.pos + 70).clamp(0, bodyLower.length);
      final ctx = bodyLower.substring(start, end);
      for (final k in txnKeywords) {
        if (ctx.contains(k)) score += 10;
      }
      for (final k in balanceKeywords) {
        if (ctx.contains(k)) score -= 20;
      }
      if (amounts.first == a) score += 5;
      scored.add((amount: a.amount, score: score));
    }
    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.first.score >= 0 ? scored.first.amount : null;
  }

  bool _isBalanceContext(String bodyLower, int start, int end) {
    const keys = [
      'avl bal',
      'avlbal',
      'available balance',
      'total bal',
      'current bal',
      'closing bal',
      'balance:',
      'outstanding',
    ];
    final ctxStart = (start - 70).clamp(0, bodyLower.length);
    final ctxEnd = (end + 70).clamp(0, bodyLower.length);
    final ctx = bodyLower.substring(ctxStart, ctxEnd);
    return keys.any((k) => ctx.contains(k));
  }

  String? _extractMerchant(String body) {
    final patterns = [
      RegExp(r'\bat\s+([A-Z][A-Za-z0-9\s&.\-]{2,40})'),
      RegExp(r'\bto\s+([A-Z][A-Za-z0-9\s&.\-]{2,40})'),
      RegExp(r'\bfor\s+([A-Z][A-Za-z0-9\s&.\-]{2,40})'),
    ];
    for (final p in patterns) {
      final m = p.firstMatch(body);
      if (m != null) {
        final v = m.group(1)?.trim();
        if (v != null && v.length >= 3) return v;
      }
    }
    return null;
  }

  String? _extractAccountLast4(String body) {
    final patterns = [
      RegExp(
          r'(?:from|to|debited\s+from|credited\s+to)\s+(?:a/?c|account)\s+[xX*]{0,4}(\d{4})\b',
          caseSensitive: false),
      RegExp(r'(?:a/?c|account)(?:\s+no\.?)?\s+[xX*]{0,4}(\d{4})\b',
          caseSensitive: false),
      RegExp(r'account\s+ending\s+(?:in\s+)?(\d{4})\b', caseSensitive: false),
    ];
    for (final p in patterns) {
      final m = p.firstMatch(body);
      if (m != null) return m.group(1);
    }
    return null;
  }

  String? _extractCardLast4(String body) {
    final patterns = [
      RegExp(r'card\s+(?:no\.?\s+)?[xX*]{0,4}(\d{4})\b', caseSensitive: false),
      RegExp(r'using\s+card\s+[xX*]{0,4}(\d{4})\b', caseSensitive: false),
      RegExp(r'card\s+ending\s+(?:in\s+)?(\d{4})\b', caseSensitive: false),
    ];
    for (final p in patterns) {
      final m = p.firstMatch(body);
      if (m != null) return m.group(1);
    }
    return null;
  }

  String? _extractUpiId(String body) {
    final m = RegExp(r'([a-zA-Z0-9._\-]+@[a-zA-Z]+)').firstMatch(body);
    return m?.group(1);
  }

  double? _extractBalance(String body) {
    final patterns = [
      RegExp(
          r'(?:avail|avl)\s*(?:bal)?\s*(?:is|:)?\s*(?:rs\.?|inr|₹)?\s*([\d,]+(?:\.\d{2})?)',
          caseSensitive: false),
      RegExp(
          r'(?:balance|bal)\s*(?:is|:)?\s*(?:rs\.?|inr|₹)?\s*([\d,]+(?:\.\d{2})?)',
          caseSensitive: false),
    ];
    for (final p in patterns) {
      final m = p.firstMatch(body);
      if (m != null) {
        final s = m.group(1)?.replaceAll(',', '');
        if (s != null) return double.tryParse(s);
      }
    }
    return null;
  }

  String? _guessBankFromSender(
      String sender, Map<String, List<String>> enabledBankSenderIds) {
    final sUp = sender.toUpperCase();
    for (final entry in enabledBankSenderIds.entries) {
      if (entry.value.any((id) => sUp.contains(id.toUpperCase()))) {
        return entry.key;
      }
    }
    // Fallback: check default sender IDs
    for (final bp in BankSmsPatterns.all.values) {
      if (bp.matchesSender(sender)) return bp.bankId;
    }
    return null;
  }
}
