import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vittara_fin_os/logic/account_model.dart';
import 'package:vittara_fin_os/services/sms_parser.dart';

/// Thrown when SMS permission is denied during scan.
class SmsPermissionDeniedException implements Exception {
  const SmsPermissionDeniedException();

  @override
  String toString() => 'SmsPermissionDeniedException: SMS permission was denied';
}

/// One fully-processed SMS ready for user review.
class SmsParseResult {
  final ParsedSms parsed;
  final Account? matchedAccount;
  final double accountMatchConfidence; // 0–1
  final String accountMatchReason;

  SmsParseResult({
    required this.parsed,
    this.matchedAccount,
    this.accountMatchConfidence = 0,
    this.accountMatchReason = '',
  });
}

class SmsService {
  final SmsQuery _query = SmsQuery();
  final SmsParser _parser = SmsParser();

  void dispose() => _parser.dispose();

  /// Request READ_SMS permission. Returns true if granted.
  Future<bool> requestPermission() async {
    var status = await Permission.sms.status;
    if (!status.isGranted) status = await Permission.sms.request();
    return status.isGranted;
  }

  /// Main scan entry-point.
  /// [enabledBanks] — enabled banks from BanksController, each map has
  ///   'id', 'senderIds' (List<String>), 'isEnabled'.
  /// [accounts] — all accounts from AccountsController.
  /// [days] — how many days back to scan.
  /// [onProgress] — optional callback (0–100, status string).
  Future<List<SmsParseResult>> scanMessages({
    required List<Map<String, dynamic>> enabledBanks,
    required List<Account> accounts,
    int days = 30,
    void Function(int progress, String status)? onProgress,
  }) async {
    // Build sender-id lookup: bankId → List<String> senderIds
    final Map<String, List<String>> senderMap = {};
    for (final bank in enabledBanks) {
      final id = bank['id'] as String? ?? '';
      final ids = (bank['senderIds'] as List?)?.cast<String>() ?? [];
      if (id.isNotEmpty && ids.isNotEmpty) {
        senderMap[id] = ids;
      }
    }

    final hasPermission = await requestPermission();
    if (!hasPermission) throw const SmsPermissionDeniedException();

    onProgress?.call(5, 'Reading SMS inbox...');

    final since = DateTime.now().subtract(Duration(days: days));

    final allMessages = await _query.querySms(
      kinds: [SmsQueryKind.inbox],
      count: 5000,
    );

    final messages = allMessages
        .where((m) => m.date != null && m.date!.isAfter(since))
        .toList();

    onProgress?.call(15, 'Filtering ${messages.length} messages...');

    final results = <SmsParseResult>[];
    final total = messages.length;
    int parseAttempted = 0;

    for (int i = 0; i < total; i++) {
      final msg = messages[i];

      if (i % 15 == 0) {
        final pct = 15 + ((i / total) * 70).toInt();
        onProgress?.call(pct, 'Processing $i/$total...');
        await Future.delayed(Duration.zero); // yield to UI
      }

      final sender = msg.address ?? '';

      // If user has configured enabled banks, only process matching senders
      if (senderMap.isNotEmpty && !_senderMatchesAny(sender, senderMap)) {
        continue;
      }

      // Spam / noise filter
      if (_isNoise(sender, msg.body ?? '')) continue;

      parseAttempted++;
      final parsed = await _parser.parse(msg, senderMap);
      if (parsed == null) continue;

      // Account auto-match
      final match = _findMatchingAccount(parsed, accounts);

      results.add(SmsParseResult(
        parsed: parsed,
        matchedAccount: match?.account,
        accountMatchConfidence: match?.confidence ?? 0,
        accountMatchReason: match?.reason ?? '',
      ));
    }

    // Within-scan deduplication: same amount + same date + same sender → keep first
    final deduped = <SmsParseResult>[];
    final seenInScan = <String>{};
    for (final r in results) {
      final p = r.parsed;
      final key =
          '${p.amount.toStringAsFixed(2)}_${p.date.year}${p.date.month.toString().padLeft(2, '0')}${p.date.day.toString().padLeft(2, '0')}_${(p.accountLast4 ?? '')}';
      if (seenInScan.add(key)) {
        deduped.add(r);
      }
    }

    final failCount = parseAttempted - results.length;
    onProgress?.call(
        100, 'Done — ${deduped.length} found|$failCount unreadable');
    return deduped;
  }

  bool _senderMatchesAny(String sender, Map<String, List<String>> senderMap) {
    final sUp = sender.toUpperCase();
    return senderMap.values
        .any((ids) => ids.any((id) => sUp.contains(id.toUpperCase())));
  }

  // ---------------------------------------------------------------------------
  // Noise / spam filter
  // ---------------------------------------------------------------------------
  static const _otpKeywords = [
    'otp',
    'one-time password',
    'one time password',
    'verification code',
    'is your otp',
    'your otp is',
    'authentication code',
    'security code',
  ];
  static const _mfKeywords = [
    'mutual fund',
    'nav ',
    'folio',
    'units allotted',
    'nfo',
    'amc',
    'sip installment',
  ];
  static const _statementKeywords = [
    'statement is',
    'statement sent',
    'total due',
    'minimum due',
    'due by',
    'payment due',
    'minimum payment',
    'outstanding balance',
    'minimum of',
    // Bill / EMI due reminders
    'is due',
    'due on',
    'bill due',
    'emi due',
    'emi is',
    'please pay',
    'kindly pay',
    'pay your',
    'autopay',
    'auto debit',
    'repayment',
  ];
  static const _mandateKeywords = [
    'upi-mandate',
    'upi mandate',
    'mandate created',
    'funds are blocked',
    'funds blocked',
    'amount blocked',
  ];
  static const _spamKeywords = [
    // General promo triggers
    'offer valid',
    'limited time offer',
    'apply now',
    'click here',
    'download app',
    'flat discount',
    'hurry up',
    'exclusive deal',
    'you have won',
    'congratulations you won',
    'lottery',
    'loan approved',
    'pre-approved loan',
    'instant loan',
    'upgrade your card',
    // Cashback / reward triggers (Jio Pay, PhonePe, Paytm promo pattern)
    'cashback',
    'earn reward',
    'earn cashback',
    'get cashback',
    'refer and earn',
    'win a prize',
    'free voucher',
    'scratch card',
    'use code',
    'promo code',
    'coupon code',
    'activate now',
    'upgrade now',
    'get rewarded',
    'special offer',
    'bonus points',
    'reward points',
    'collect points',
    'avail offer',
    'avail now',
    'enjoy offer',
    'upto % off',
    '% cashback',
    // Marketing patterns
    'tap to pay',
    'scan to pay and earn',
    'pay and earn',
    'shop and earn',
    'use jiopay',
    'use jiomoney',
    'use phonepay',
    'make your first',
    'your first payment',
  ];
  static const _mfSenders = [
    'MUTFND',
    'KFNMF',
    'IPRUMF',
    'NIMFND',
    'TATAMF',
    'GRWWMF',
    'SBIAMF',
    'HDFCMF',
    'ICICIMF',
  ];

  /// Senders that exclusively send promotional/marketing messages —
  /// never genuine debit/credit confirmations.
  static const _promotionalSenders = [
    'JIOPAY',
    'JIOFIN',
    'JIOMNY',
    'JIOADV',
    'RELJIO',
    'JIOPMN',
    'AIRPAY', // Airtel Money promotional
    'AIRTLM',
    'VILFIN',
    'FRNKFT', // Freecharge
    'FCHARGE',
    'LAZYPAY',
    'LAZADV',
    'SNAPDL', // Snapdeal Pay
    'FLIPKR', // Flipkart Pay promotional
  ];

  bool _isNoise(String sender, String body) {
    final b = body.toLowerCase();
    final s = sender.toUpperCase();
    if (_otpKeywords.any((k) => b.contains(k))) return true;
    if (_mfSenders.any((k) => s.contains(k))) return true;
    if (_promotionalSenders.any((k) => s.contains(k))) return true;
    if (_mfKeywords.any((k) => b.contains(k))) return true;
    if (_statementKeywords.any((k) => b.contains(k))) return true;
    if (_mandateKeywords.any((k) => b.contains(k))) return true;

    // Count spam keywords — 1+ → reject (promotional content is clearly not a txn)
    int hits = 0;
    for (final k in _spamKeywords) {
      if (b.contains(k) && ++hits >= 1) return true;
    }

    // No strong transaction verb → not a debit/credit notification
    final hasStrongTxn = b.contains('debited') ||
        b.contains('credited') ||
        b.contains(' dr ') ||
        b.contains(' cr ') ||
        b.contains('withdrawn') ||
        b.contains('transferred');
    if (!hasStrongTxn) return true;

    // Any URL = promotional (genuine debit/credit SMSes never embed links)
    final urlCount = RegExp(r'https?://|www\.').allMatches(b).length;
    if (urlCount >= 1) return true;

    return false;
  }

  // ---------------------------------------------------------------------------
  // Account auto-match — scored priority system
  // ---------------------------------------------------------------------------
  _AccountMatch? _findMatchingAccount(
      ParsedSms parsed, List<Account> accounts) {
    if (accounts.isEmpty) return null;

    final bodyLower = parsed.rawMessage.toLowerCase();

    // SMS contains explicit "card" reference → likely a card transaction
    final smsIsCardTxn = bodyLower.contains('card');
    // SMS contains UPI/NEFT/IMPS/account → likely a bank account transaction
    final smsIsBankTxn = bodyLower.contains('upi') ||
        bodyLower.contains('neft') ||
        bodyLower.contains('imps') ||
        bodyLower.contains('rtgs') ||
        bodyLower.contains(' ac ') ||
        bodyLower.contains(' a/c ') ||
        bodyLower.contains('savings') ||
        bodyLower.contains('current a/c');

    // Helper — extract last 4 digits from any stored number string
    String last4(String? raw) {
      if (raw == null || raw.isEmpty) return '';
      final d = raw.replaceAll(RegExp(r'\D'), '');
      return d.length >= 4 ? d.substring(d.length - 4) : d;
    }

    // Helper — does this account's bank name match the parsed bankId?
    bool bankMatches(Account a) {
      if (parsed.bankId == null) return false;
      final parts = parsed.bankId!
          .replaceAll('_', ' ')
          .toLowerCase()
          .split(' ')
        ..removeWhere((p) => p.length < 3);
      final bn = a.bankName.toLowerCase();
      return parts.any((p) => bn.contains(p));
    }

    // ── Priority 1: Credit/pay-later card number last-4 ──────────────────────
    if (parsed.cardLast4 != null) {
      final hits = accounts.where((a) =>
          (a.type == AccountType.credit || a.type == AccountType.payLater) &&
          last4(a.creditCardNumber) == parsed.cardLast4).toList();
      if (hits.length == 1) {
        return _AccountMatch(
            account: hits.first,
            confidence: 0.97,
            reason: 'Card ••••${parsed.cardLast4}');
      }
      // Multiple hits — prefer same-bank
      final sameBankHits = hits.where(bankMatches).toList();
      if (sameBankHits.isNotEmpty) {
        return _AccountMatch(
            account: sameBankHits.first,
            confidence: 0.96,
            reason: 'Card ••••${parsed.cardLast4}');
      }
      if (hits.isNotEmpty) {
        return _AccountMatch(
            account: hits.first,
            confidence: 0.90,
            reason: 'Card ••••${parsed.cardLast4}');
      }
    }

    // ── Priority 2: accountLast4 — check metadata first, then creditCardNumber
    if (parsed.accountLast4 != null) {
      final acLast4 = parsed.accountLast4!;

      // 2a. metadata['accountLast4'] — savings/current accounts
      final byMetaAcct = accounts.where((a) {
        final stored = a.metadata?['accountLast4'] as String?;
        return stored == acLast4;
      }).toList();
      if (byMetaAcct.isNotEmpty) {
        final sameBankHits = byMetaAcct.where(bankMatches).toList();
        final best = sameBankHits.isNotEmpty ? sameBankHits.first : byMetaAcct.first;
        return _AccountMatch(
            account: best,
            confidence: sameBankHits.isNotEmpty ? 0.97 : 0.88,
            reason: 'Account ••••$acLast4');
      }

      // 2b. metadata['debitCardLast4']
      final byMetaDebit = accounts.where((a) {
        final stored = a.metadata?['debitCardLast4'] as String?;
        return stored == acLast4;
      }).toList();
      if (byMetaDebit.isNotEmpty) {
        final sameBankHits = byMetaDebit.where(bankMatches).toList();
        final best = sameBankHits.isNotEmpty ? sameBankHits.first : byMetaDebit.first;
        return _AccountMatch(
            account: best,
            confidence: sameBankHits.isNotEmpty ? 0.95 : 0.85,
            reason: 'Debit card ••••$acLast4');
      }

      // 2c. creditCardNumber field (for credit/payLater)
      final byCreditNum = accounts.where((a) =>
          (a.type == AccountType.credit || a.type == AccountType.payLater) &&
          last4(a.creditCardNumber) == acLast4).toList();
      if (byCreditNum.isNotEmpty) {
        final sameBankHits = byCreditNum.where(bankMatches).toList();
        final best = sameBankHits.isNotEmpty ? sameBankHits.first : byCreditNum.first;
        return _AccountMatch(
            account: best,
            confidence: sameBankHits.isNotEmpty ? 0.92 : 0.82,
            reason: 'Card ••••$acLast4');
      }
    }

    // ── Priority 3: Bank name match with type inference ───────────────────────
    if (parsed.bankId != null) {
      final byBank =
          accounts.where(bankMatches).toList();

      if (byBank.isEmpty) return null;

      if (byBank.length == 1) {
        return _AccountMatch(
            account: byBank.first,
            confidence: 0.65,
            reason: 'Bank: ${byBank.first.bankName}');
      }

      // Multiple accounts at same bank — use type inference
      final cardTypes = {AccountType.credit, AccountType.payLater};
      final bankTypes = {
        AccountType.savings,
        AccountType.current,
        AccountType.wallet
      };

      List<Account> preferred;
      if (smsIsCardTxn && !smsIsBankTxn) {
        // Card transaction → prefer credit/pay-later
        preferred = byBank.where((a) => cardTypes.contains(a.type)).toList();
        if (preferred.isEmpty) preferred = byBank;
      } else if (smsIsBankTxn && !smsIsCardTxn) {
        // Bank/UPI transaction → prefer savings/current
        preferred = byBank.where((a) => bankTypes.contains(a.type)).toList();
        if (preferred.isEmpty) preferred = byBank;
      } else {
        // Ambiguous — prefer savings over credit (most common debit)
        preferred = byBank.where((a) => bankTypes.contains(a.type)).toList();
        if (preferred.isEmpty) preferred = byBank;
      }

      return _AccountMatch(
          account: preferred.first,
          confidence: 0.60,
          reason: 'Bank: ${preferred.first.bankName}');
    }

    return null;
  }
}

class _AccountMatch {
  final Account account;
  final double confidence;
  final String reason;
  _AccountMatch(
      {required this.account, required this.confidence, required this.reason});
}
