import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vittara_fin_os/logic/account_model.dart';
import 'package:vittara_fin_os/services/sms_parser.dart';

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
    if (!hasPermission) return [];

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

    onProgress?.call(100, 'Done — ${results.length} transactions found');
    return results;
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

  bool _isNoise(String sender, String body) {
    final b = body.toLowerCase();
    final s = sender.toUpperCase();
    if (_otpKeywords.any((k) => b.contains(k))) return true;
    if (_mfSenders.any((k) => s.contains(k))) return true;
    if (_mfKeywords.any((k) => b.contains(k))) return true;
    if (_statementKeywords.any((k) => b.contains(k))) return true;
    if (_mandateKeywords.any((k) => b.contains(k))) return true;

    // Count spam keywords — 2+ → reject
    int hits = 0;
    for (final k in _spamKeywords) {
      if (b.contains(k) && ++hits >= 2) return true;
    }

    // No transaction context at all
    final hasTxn = b.contains('debited') ||
        b.contains('credited') ||
        b.contains('paid') ||
        b.contains('received') ||
        b.contains(' dr ') ||
        b.contains(' cr ') ||
        b.contains('withdrawn') ||
        b.contains('transferred');
    if (!hasTxn && hits >= 1) return true;

    // Multiple URLs = promotional
    final urlCount = RegExp(r'https?://|www\.').allMatches(b).length;
    if (urlCount >= 2) return true;

    return false;
  }

  // ---------------------------------------------------------------------------
  // Account auto-match
  // ---------------------------------------------------------------------------
  _AccountMatch? _findMatchingAccount(
      ParsedSms parsed, List<Account> accounts) {
    if (accounts.isEmpty) return null;

    // 1. Exact account last-4 match within same bank
    if (parsed.accountLast4 != null) {
      final byBankAndAc = accounts.where((a) {
        final acNum = a.creditCardNumber ?? '';
        return acNum.endsWith(parsed.accountLast4!) &&
            (parsed.bankId == null ||
                a.bankName.toLowerCase().contains(
                    parsed.bankId!.replaceAll('_', ' ').toLowerCase()));
      }).toList();
      if (byBankAndAc.isNotEmpty) {
        return _AccountMatch(
          account: byBankAndAc.first,
          confidence: 0.95,
          reason: 'Matched account ending **${parsed.accountLast4}',
        );
      }

      // 2. Exact account last-4 match (any bank)
      final byAc = accounts
          .where(
              (a) => (a.creditCardNumber ?? '').endsWith(parsed.accountLast4!))
          .toList();
      if (byAc.isNotEmpty) {
        return _AccountMatch(
          account: byAc.first,
          confidence: 0.85,
          reason: 'Matched account ending **${parsed.accountLast4}',
        );
      }
    }

    // 3. Card last-4 match
    if (parsed.cardLast4 != null) {
      final byCard = accounts
          .where((a) =>
              a.type == AccountType.credit &&
              (a.creditCardNumber ?? '').endsWith(parsed.cardLast4!))
          .toList();
      if (byCard.isNotEmpty) {
        return _AccountMatch(
          account: byCard.first,
          confidence: 0.90,
          reason: 'Matched card ending **${parsed.cardLast4}',
        );
      }
    }

    // 4. Bank name match
    if (parsed.bankId != null) {
      final bankNameParts = parsed.bankId!
          .replaceAll('_', ' ')
          .toLowerCase()
          .split(' ')
        ..removeWhere((p) => p.length < 3);
      final byBank = accounts.where((a) {
        final bn = a.bankName.toLowerCase();
        return bankNameParts.any((part) => bn.contains(part));
      }).toList();
      if (byBank.isNotEmpty) {
        return _AccountMatch(
          account: byBank.first,
          confidence: 0.65,
          reason: 'Matched bank: ${byBank.first.bankName}',
        );
      }
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
