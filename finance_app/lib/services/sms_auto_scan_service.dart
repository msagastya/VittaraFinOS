import 'package:flutter/cupertino.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vittara_fin_os/logic/accounts_controller.dart';
import 'package:vittara_fin_os/logic/banks_controller.dart';
import 'package:vittara_fin_os/logic/transaction_model.dart';
import 'package:vittara_fin_os/logic/transactions_controller.dart';
import 'package:vittara_fin_os/services/sms_service.dart';
import 'package:vittara_fin_os/ui/dashboard/transaction_wizard.dart';
import 'package:vittara_fin_os/ui/sms/sms_review_screen.dart';
import 'package:vittara_fin_os/ui/widgets/animations.dart';

// ── Constants ────────────────────────────────────────────────────────────────

const _seenKey = 'sms_seen_fingerprints_v1';
const _channelId = 'sms_transactions';
const _channelName = 'SMS Transaction Alerts';
const _summaryNotifId = 9000;

/// Global navigator key — attach to MaterialApp so notifications can push
/// routes even when the notification is tapped from the system tray.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

// ── Background handler (top-level, separate isolate) ─────────────────────────

@pragma('vm:entry-point')
void _onBackgroundNotification(NotificationResponse response) async {
  // "Already Entered" / "Skip" from background — persist fingerprint as seen.
  final actionId = response.actionId;
  if (actionId == 'entered' || actionId == 'skip') {
    final fp = _fpFromPayload(response.payload);
    if (fp.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_seenKey) ?? [];
      if (!list.contains(fp)) {
        list.add(fp);
        await prefs.setStringList(_seenKey, list);
      }
    }
  }
}

String _fpFromPayload(String? payload) {
  if (payload == null || payload == 'review') return '';
  final sep = payload.indexOf('|');
  return sep >= 0 ? payload.substring(sep + 1) : '';
}

// ── Service singleton ─────────────────────────────────────────────────────────

class SmsAutoScanService {
  SmsAutoScanService._();
  static final SmsAutoScanService instance = SmsAutoScanService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Results waiting for SmsReviewScreen to consume.
  List<SmsParseResult>? pendingResults;

  /// In-memory cache indexed to match notification IDs (9001+i → cachedResults[i]).
  final List<SmsParseResult> _cachedResults = [];

  // ── Init ──────────────────────────────────────────────────────────────────

  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      const InitializationSettings(android: androidSettings),
      onDidReceiveNotificationResponse: _onForeground,
      onDidReceiveBackgroundNotificationResponse: _onBackgroundNotification,
    );

    // Create notification channel
    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: 'Bank transactions auto-detected from SMS',
      importance: Importance.high,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // Ask for notification permission (Android 13+)
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    _initialized = true;
  }

  // ── Foreground response handler ───────────────────────────────────────────

  void _onForeground(NotificationResponse response) async {
    final actionId = response.actionId;
    final payload = response.payload ?? '';

    if (actionId == 'entered' || actionId == 'skip') {
      final fp = _fpFromPayload(payload);
      if (fp.isNotEmpty) await _markSeen(fp);
      await _plugin.cancel(response.id ?? 0);
      return;
    }

    if (actionId == 'add') {
      // payload format: "{index}|{fingerprint}"
      final sep = payload.indexOf('|');
      final idx = sep > 0 ? int.tryParse(payload.substring(0, sep)) : null;
      final fp = sep > 0 ? payload.substring(sep + 1) : '';
      if (idx != null && idx < _cachedResults.length) {
        await _markSeen(fp);
        await _plugin.cancel(response.id ?? 0);
        appNavigatorKey.currentState?.push(
          FadeScalePageRoute(
            page: TransactionWizard(prefillFromSms: _cachedResults[idx]),
          ),
        );
        return;
      }
    }

    // Tap on notification body / "Review All" → open SMS review screen
    if (pendingResults?.isNotEmpty == true) {
      appNavigatorKey.currentState?.push(
        CupertinoPageRoute(builder: (_) => const SmsReviewScreen()),
      );
    }
  }

  // ── Startup scan ──────────────────────────────────────────────────────────

  Future<void> runStartupScan({
    required BanksController banksCtrl,
    required AccountsController accountsCtrl,
    required TransactionsController txCtrl,
  }) async {
    await initialize();

    final smsService = SmsService();
    final hasPermission = await smsService.requestPermission();
    if (!hasPermission) {
      smsService.dispose();
      return;
    }

    final results = await smsService.scanMessages(
      enabledBanks: banksCtrl.enabledBanks,
      accounts: accountsCtrl.accounts,
      days: 7,
    );
    smsService.dispose();

    if (results.isEmpty) return;

    // Filter already-seen and auto-skip 80%+ duplicates
    final seen = await _loadSeen();
    final txns = txCtrl.transactions;

    final fresh = results.where((r) {
      if (seen.contains(_fingerprint(r))) return false;
      final p = r.parsed;
      final matchedId = r.matchedAccount?.id;
      for (final t in txns) {
        if ((t.amount - p.amount).abs() > 1.0) continue;
        if (t.dateTime.difference(p.date).inDays.abs() > 1) continue;
        final tId = (t.metadata ?? {})['accountId'] as String?;
        if (matchedId != null && tId == matchedId) return false; // 80% match
      }
      return true;
    }).toList();

    if (fresh.isEmpty) return;

    _cachedResults
      ..clear()
      ..addAll(fresh);
    pendingResults = fresh;

    await _showNotifications(fresh, txns);
  }

  // ── Notification builder ──────────────────────────────────────────────────

  Future<void> _showNotifications(
      List<SmsParseResult> results, List<Transaction> txns) async {
    // Cancel previous SMS notifications
    for (int i = 0; i < 10; i++) {
      await _plugin.cancel(9001 + i);
    }
    await _plugin.cancel(_summaryNotifId);

    final fmt =
        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    // ── Individual notifications (max 5) ─────────────────────────────────
    final toShow = results.take(5).toList();
    for (int i = 0; i < toShow.length; i++) {
      final r = toShow[i];
      final p = r.parsed;
      final fp = _fingerprint(r);
      final isExpense = p.type == 'expense';

      // Check if any existing transaction is a possible duplicate
      bool hasDuplicate = false;
      for (final t in txns) {
        if ((t.amount - p.amount).abs() <= 1.0 &&
            t.dateTime.difference(p.date).inDays.abs() <= 1) {
          hasDuplicate = true;
          break;
        }
      }

      final merchantName = p.merchant ??
          p.bankId?.replaceAll('_', ' ').split(' ').first ??
          'Bank';
      final accountTag =
          r.matchedAccount != null ? ' · ${r.matchedAccount!.bankName}' : '';

      await _plugin.show(
        9001 + i,
        '${isExpense ? 'Spent' : 'Received'} ${fmt.format(p.amount)}',
        '$merchantName$accountTag${hasDuplicate ? ' · Possible duplicate' : ''}',
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            importance: Importance.high,
            priority: Priority.high,
            groupKey: 'sms_txn_group',
            actions: const [
              AndroidNotificationAction(
                'add',
                'Add',
                showsUserInterface: true,
              ),
              AndroidNotificationAction(
                'entered',
                'Already Entered',
                cancelNotification: true,
              ),
              AndroidNotificationAction(
                'skip',
                'Skip',
                cancelNotification: true,
              ),
            ],
          ),
        ),
        payload: '$i|$fp',
      );
    }

    // ── Summary / group notification ──────────────────────────────────────
    await _plugin.show(
      _summaryNotifId,
      'Bank Transactions Detected',
      '${results.length} new transaction${results.length == 1 ? '' : 's'} found in SMS',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.high,
          priority: Priority.high,
          groupKey: 'sms_txn_group',
          setAsGroupSummary: true,
          styleInformation: InboxStyleInformation(
            results.take(5).map((r) {
              final p = r.parsed;
              return '${p.type == 'expense' ? '▼' : '▲'} '
                  '${fmt.format(p.amount)}  '
                  '${p.merchant ?? p.bankId ?? 'Bank'}';
            }).toList(),
            summaryText:
                '${results.length} transaction${results.length == 1 ? '' : 's'}',
            contentTitle: 'VittaraFinOS · SMS Scan',
          ),
          actions: const [
            AndroidNotificationAction(
              'review',
              'Review All',
              showsUserInterface: true,
            ),
            AndroidNotificationAction(
              'skip',
              'Dismiss',
              cancelNotification: true,
            ),
          ],
        ),
      ),
      payload: 'review',
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _fingerprint(SmsParseResult r) {
    final p = r.parsed;
    return '${p.amount.toStringAsFixed(0)}'
        '_${p.date.day}${p.date.month}${p.date.year}'
        '_${p.sender.hashCode.abs()}';
  }

  Future<void> _markSeen(String fp) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_seenKey) ?? [];
    if (!list.contains(fp)) {
      list.add(fp);
      await prefs.setStringList(_seenKey, list);
    }
  }

  Future<Set<String>> _loadSeen() async {
    final prefs = await SharedPreferences.getInstance();
    return Set<String>.from(prefs.getStringList(_seenKey) ?? []);
  }
}
