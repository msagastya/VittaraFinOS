import 'package:flutter/foundation.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:google_mlkit_entity_extraction/google_mlkit_entity_extraction.dart';
import 'package:vittara_fin_os/services/bank_sms_patterns.dart';
import 'package:vittara_fin_os/utils/date_formatter.dart';

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
      'transfer to',
      'trf to',
      'sent to',
      'payment done',
      'payment successful',
      'upi payment',
      'purchase at',
      'transaction of',
      'txn of',
      'debit',
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
      'transfer from',
      'trf from',
      'money received',
      'payment received',
      'credit',
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

  // Words that are NOT merchants — filter these out from merchant extraction
  static const _merchantBlocklist = [
    'HDFC', 'ICICI', 'SBI', 'AXIS', 'KOTAK', 'PNB', 'BOB', 'CANARA',
    'UNION', 'INDUS', 'IDBI', 'YES', 'IDFC', 'FEDERAL', 'PAYTM',
    'AIRTEL', 'GPAY', 'PHONEPE', 'AMAZON',
    'Bank', 'UPI', 'NEFT', 'IMPS', 'RTGS', 'ATM', 'INB', 'MB',
    'Ref', 'TXN', 'Txn', 'INFO', 'VPA',
    'Your', 'The', 'This', 'Avl', 'Available', 'Balance', 'Account',
  ];

  String? _extractMerchant(String body) {
    // High-confidence patterns first
    final highConfidencePatterns = [
      // "Info: MERCHANT NAME" or "INFO:MERCHANT"
      RegExp(r'(?:info|merchant|vpa)\s*:\s*([A-Za-z0-9][A-Za-z0-9\s&.\-@]{2,35})',
          caseSensitive: false),
      // "at MERCHANT NAME on" (bounded by "on" or end)
      RegExp(r'\bat\s+([A-Z][A-Za-z0-9\s&.\-]{2,30})(?:\s+on\b|\s+via\b|\s+for\b|\.|\s*$)',
          caseSensitive: false),
      // "paid to MERCHANT" or "payment to MERCHANT"
      RegExp(r'(?:paid|payment)\s+to\s+([A-Za-z][A-Za-z0-9\s&.\-]{2,35})(?:\s+via|\s+ref|\s+on|\.|\s*$)',
          caseSensitive: false),
      // "Trf to MERCHANT" / "Transfer to MERCHANT"
      RegExp(r'(?:trf|transfer)\s+to\s+([A-Za-z][A-Za-z0-9\s&.\-]{2,35})(?:\s+ref|\s+on|\.|\s*$)',
          caseSensitive: false),
      // UPI: "to VPA MERCHANT@okaxis"
      RegExp(r'\bto\s+([A-Za-z][A-Za-z0-9.\-]+@[A-Za-z0-9]+)',
          caseSensitive: false),
    ];

    for (final p in highConfidencePatterns) {
      final m = p.firstMatch(body);
      if (m == null) continue;
      final raw = m.group(1)?.trim() ?? '';
      if (raw.length < 2) continue;
      // Check against blocklist
      final upper = raw.toUpperCase();
      final blocked = _merchantBlocklist.any((b) =>
          upper.startsWith(b.toUpperCase()) || upper == b.toUpperCase());
      if (!blocked) return _cleanMerchantName(raw);
    }

    // Lower-confidence fallbacks
    final fallbacks = [
      RegExp(r'\bfor\s+([A-Z][A-Za-z0-9\s&.\-]{2,30})(?:\s+on\b|\s+via\b|\.|\s*$)',
          caseSensitive: false),
    ];
    for (final p in fallbacks) {
      final m = p.firstMatch(body);
      if (m == null) continue;
      final raw = m.group(1)?.trim() ?? '';
      if (raw.length < 3) continue;
      final upper = raw.toUpperCase();
      final blocked = _merchantBlocklist.any((b) => upper.startsWith(b.toUpperCase()));
      if (!blocked) return _cleanMerchantName(raw);
    }

    return null;
  }

  String _cleanMerchantName(String raw) {
    // Remove trailing noise words
    var cleaned = raw
        .replaceAll(RegExp(r'\b(ref|txn|id|no|on|via|using|at)\b.*$',
            caseSensitive: false), '')
        .trim();
    // Normalize multiple spaces
    cleaned = cleaned.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
    // Cap length
    if (cleaned.length > 30) cleaned = cleaned.substring(0, 30).trim();
    final result = cleaned.isEmpty ? raw : cleaned;
    // AU15-06: normalize ALL-CAPS merchant names to Title Case
    return NumberFormatter.toTitleCase(result);
  }

  String? _extractAccountLast4(String body) {
    // Order matters — more specific first
    final patterns = [
      // "debited from A/C XXXX1234" / "credited to A/c XX1234"
      RegExp(
          r'(?:from|to|debited\s+from|credited\s+to)\s+(?:a/?c|account|acc|acct)\s*(?:no\.?)?\s*[xX*.\s]{0,6}(\d{4})\b',
          caseSensitive: false),
      // "A/C XXXX1234" anywhere
      RegExp(r'\b(?:a/?c|account|acc|acct)\s*(?:no\.?)?\s*[xX*.\s]{0,6}(\d{4})\b',
          caseSensitive: false),
      // "account ending in 1234" / "account ending 1234"
      RegExp(r'account\s+ending\s+(?:in\s+)?(\d{4})\b', caseSensitive: false),
      // "Ac 1234" (short form used by many Indian banks)
      RegExp(r'\bac\s+[xX*]{0,4}(\d{4})\b', caseSensitive: false),
      // "savings a/c 1234" / "current ac 1234"
      RegExp(r'(?:savings|current|salary)\s+(?:a/?c|account|acc)\s*[xX*.\s]{0,4}(\d{4})\b',
          caseSensitive: false),
      // "XXXX1234" standalone — 4+ X/*/. followed by exactly 4 digits
      RegExp(r'[xX*]{3,}(\d{4})\b'),
    ];
    for (final p in patterns) {
      final m = p.firstMatch(body);
      if (m != null) return m.group(1);
    }
    return null;
  }

  String? _extractCardLast4(String body) {
    final patterns = [
      // "card no XXXX1234" / "card XXXX1234"
      RegExp(r'\b(?:debit\s+card|credit\s+card|card\s+no\.?)\s*[xX*.\s]{0,4}(\d{4})\b',
          caseSensitive: false),
      // "using card 1234" / "spent on card 1234"
      RegExp(r'(?:using|on|via)\s+(?:\w+\s+)?card\s+[xX*]{0,4}(\d{4})\b',
          caseSensitive: false),
      // "card ending in 1234"
      RegExp(r'card\s+ending\s+(?:in\s+)?(\d{4})\b', caseSensitive: false),
      // "card 1234" — generic last resort
      RegExp(r'\bcard\s+[xX*]{0,4}(\d{4})\b', caseSensitive: false),
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
    // Only match AVAILABLE/CURRENT balance — not "due", "outstanding", "minimum"
    final patterns = [
      // "Avl Bal Rs 5000" / "Avl Bal: Rs5000.00"
      RegExp(
          r'avl\s*bal\s*(?:is|:)?\s*(?:rs\.?|inr|₹)?\s*([\d,]+(?:\.\d{2})?)',
          caseSensitive: false),
      // "Available Bal: 5000"
      RegExp(
          r'available\s+bal(?:ance)?\s*(?:is|:)?\s*(?:rs\.?|inr|₹)?\s*([\d,]+(?:\.\d{2})?)',
          caseSensitive: false),
      // "Bal: Rs 5000" — only if NOT preceded by "outstanding", "due", "total"
      RegExp(
          r'(?<![outstanding|due|total|minimum]\s)(?:^|\s)bal(?:ance)?\s*(?:is|:)\s*(?:rs\.?|inr|₹)?\s*([\d,]+(?:\.\d{2})?)',
          caseSensitive: false),
    ];
    for (final p in patterns) {
      final m = p.firstMatch(body);
      if (m != null) {
        final s = m.group(1)?.replaceAll(',', '');
        if (s != null) {
          final v = double.tryParse(s);
          if (v != null && v > 0) return v;
        }
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
