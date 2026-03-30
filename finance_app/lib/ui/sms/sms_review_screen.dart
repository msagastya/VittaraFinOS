import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'
    show
        CircularProgressIndicator,
        AlwaysStoppedAnimation,
        Colors,
        Divider,
        SelectableText;
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/account_model.dart';
import 'package:vittara_fin_os/logic/accounts_controller.dart';
import 'package:vittara_fin_os/logic/banks_controller.dart';
import 'package:vittara_fin_os/logic/categories_controller.dart';
import 'package:vittara_fin_os/logic/category_model.dart';
import 'package:vittara_fin_os/logic/payment_apps_controller.dart';
import 'package:vittara_fin_os/logic/tags_controller.dart';
import 'package:vittara_fin_os/logic/transaction_model.dart';
import 'package:vittara_fin_os/logic/transactions_controller.dart';
import 'package:vittara_fin_os/ui/widgets/app_date_picker.dart';
import 'package:vittara_fin_os/utils/date_formatter.dart';
import 'package:vittara_fin_os/services/sms_auto_scan_service.dart';
import 'package:vittara_fin_os/services/sms_service.dart';
import 'package:vittara_fin_os/ui/dashboard/transaction_wizard.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/widgets/animations.dart';
import 'package:vittara_fin_os/ui/widgets/common_widgets.dart';
import 'package:vittara_fin_os/ui/widgets/toast_notification.dart';

class _DuplicateMatch {
  final Transaction transaction;
  final double confidence; // 0.5 or 0.8
  _DuplicateMatch({required this.transaction, required this.confidence});
}

class SmsReviewScreen extends StatefulWidget {
  /// When provided (e.g. opened from notification), skip scanning
  /// and show these pre-scanned results directly.
  final List<SmsParseResult>? preloadedResults;

  const SmsReviewScreen({super.key, this.preloadedResults});

  @override
  State<SmsReviewScreen> createState() => _SmsReviewScreenState();
}

class _SmsReviewScreenState extends State<SmsReviewScreen> {
  final SmsService _service = SmsService();

  bool _isScanning = false;
  int _scanProgress = 0;
  String _scanStatus = '';
  List<SmsParseResult> _results = [];
  final Map<int, _DuplicateMatch> _duplicates = {};
  bool _scanDone = false;
  bool _permissionDenied = false;
  int _days = 30;
  int _parseFailCount = 0;

  @override
  void initState() {
    super.initState();
    // If opened from notification, load preloaded results immediately
    final preloaded =
        widget.preloadedResults ?? SmsAutoScanService.instance.pendingResults;
    if (preloaded != null && preloaded.isNotEmpty) {
      _results = List.from(preloaded);
      _scanDone = true;
      // Clear pending so re-opening doesn't reuse stale data
      SmsAutoScanService.instance.pendingResults = null;
      WidgetsBinding.instance.addPostFrameCallback((_) => _runDupeDetection());
    }
  }

  void _runDupeDetection() {
    if (!mounted) return;
    final txCtrl = Provider.of<TransactionsController>(context, listen: false);
    final txns = txCtrl.transactions;
    final dupes = <int, _DuplicateMatch>{};
    for (int i = 0; i < _results.length; i++) {
      final p = _results[i].parsed;
      final matchedId = _results[i].matchedAccount?.id;
      Transaction? best;
      double bestConf = 0;
      for (final t in txns) {
        if ((t.amount - p.amount).abs() > 1.0) continue;
        if (t.dateTime.difference(p.date).inDays.abs() > 1) continue;
        final tId = (t.metadata ?? {})['accountId'] as String?;
        final conf = (matchedId != null && tId == matchedId) ? 0.8 : 0.5;
        if (conf > bestConf) {
          bestConf = conf;
          best = t;
        }
      }
      if (best != null) {
        dupes[i] = _DuplicateMatch(transaction: best, confidence: bestConf);
      }
    }
    setState(() {
      _duplicates
        ..clear()
        ..addAll(dupes);
    });
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  Future<void> _startScan() async {
    setState(() {
      _isScanning = true;
      _scanProgress = 0;
      _scanStatus = 'Initialising...';
      _results = [];
      _scanDone = false;
      _permissionDenied = false;
    });

    final banksCtrl = Provider.of<BanksController>(context, listen: false);
    final accountsCtrl =
        Provider.of<AccountsController>(context, listen: false);

    try {
      final results = await _service.scanMessages(
        enabledBanks: banksCtrl.enabledBanks,
        accounts: accountsCtrl.accounts,
        days: _days,
        onProgress: (pct, status) {
          if (mounted) {
            setState(() {
              _scanProgress = pct;
              // Status may encode failCount after pipe delimiter
              if (status.contains('|')) {
                final parts = status.split('|');
                _scanStatus = parts[0];
                final failStr = parts[1].replaceAll(RegExp(r'[^0-9]'), '');
                _parseFailCount = int.tryParse(failStr) ?? 0;
              } else {
                _scanStatus = status;
              }
            });
          }
        },
      );

      if (!mounted) return;

      setState(() {
        _isScanning = false;
        _results = results;
        _scanDone = true;
      });

      _runDupeDetection();
    } on SmsPermissionDeniedException {
      if (!mounted) return;
      setState(() {
        _isScanning = false;
        _permissionDenied = true;
        _scanDone = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isScanning = false;
        _scanDone = true;
        _results = [];
      });
    }
  }

  void _openSmsReview(SmsParseResult r) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetCtx) => _SmsQuickConfirmSheet(
        item: r,
        onSaved: () {
          if (!mounted) return;
          setState(() => _results.remove(r));
        },
        onOpenWizard: () {
          Navigator.of(context)
              .push(FadeScalePageRoute(
                  page: TransactionWizard(prefillFromSms: r)))
              .then((_) {
            if (!mounted) return;
            setState(() => _results.remove(r));
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppStyles.isDarkMode(context);
    final bg = isDark
        ? AppStyles.darkBackground
        : CupertinoColors.systemGroupedBackground;

    return CupertinoPageScaffold(
      backgroundColor: bg,
      navigationBar: AppStyles.isLandscape(context) ? null : CupertinoNavigationBar(
        backgroundColor:
            isDark ? const Color(0xFF000000) : CupertinoColors.systemBackground,
        previousPageTitle: 'Back',
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(),
          child:
              const Icon(CupertinoIcons.xmark, size: 20, color: AppStyles.accentBlue),
        ),
        middle: Text(
          'Import from SMS',
          style: TextStyle(
            fontFamily: 'SpaceGrotesk',
            fontWeight: FontWeight.w700,
            fontSize: 17,
            color: AppStyles.getTextColor(context),
          ),
        ),
        trailing: null,
        border: null,
      ),
      child: SafeArea(
        child: _isScanning
            ? _buildScanningState()
            : _permissionDenied
                ? _buildPermissionDeniedState()
                : !_scanDone
                    ? _buildInitialState()
                    : _results.isEmpty
                        ? _buildNoResultsState()
                        : _buildResultsList(),
      ),
    );
  }

  // ── Permission denied state ──────────────────────────────────────────────────

  Widget _buildPermissionDeniedState() {
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(Spacing.xl),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppStyles.loss(context).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      CupertinoIcons.lock_shield,
                      size: 40,
                      color: AppStyles.loss(context),
                    ),
                  ),
                  const SizedBox(height: Spacing.lg),
                  Text(
                    'SMS Permission Required',
                    style: TextStyle(
                      fontFamily: 'SpaceGrotesk',
                      fontSize: TypeScale.title3,
                      fontWeight: FontWeight.w700,
                      color: AppStyles.getTextColor(context),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: Spacing.sm),
                  Text(
                    'VittaraFinOS needs SMS access to auto-detect bank transactions.\n\nPlease grant the permission in Settings.',
                    style: TextStyle(
                      fontSize: TypeScale.subhead,
                      color: AppStyles.getSecondaryTextColor(context),
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: Spacing.xl),
                  CupertinoButton.filled(
                    onPressed: () => openAppSettings(),
                    child: const Text(
                      'Open Settings',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: Spacing.sm),
                  CupertinoButton(
                    onPressed: () => setState(() {
                      _permissionDenied = false;
                    }),
                    child: const Text(
                      'Try Again',
                      style: TextStyle(
                        color: AppStyles.accentBlue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Initial state ────────────────────────────────────────────────────────────

  Widget _buildInitialState() {
    final isDark = AppStyles.isDarkMode(context);
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Spacing.lg),
            child: Column(
              children: [
                const SizedBox(height: Spacing.xl),
                _buildIllustration(),
                const SizedBox(height: Spacing.xl),
                Text(
                  'Scan Your Bank SMS',
                  style: TextStyle(
                    fontFamily: 'SpaceGrotesk',
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppStyles.getTextColor(context),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: Spacing.sm),
                Text(
                  'VittaraFinOS reads your SMS inbox to auto-detect bank\ntransactions. Nothing leaves your device.',
                  style: TextStyle(
                    fontSize: TypeScale.subhead,
                    color: AppStyles.getSecondaryTextColor(context),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: Spacing.xl),
                _buildDaySelector(isDark),
                const SizedBox(height: Spacing.xl),
                _buildPrivacyNote(isDark),
              ],
            ),
          ),
        ),
        _buildScanButton(),
      ],
    );
  }

  Widget _buildIllustration() {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppStyles.accentBlue.withValues(alpha: 0.2),
            AppStyles.accentTeal.withValues(alpha: 0.1),
          ],
        ),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        CupertinoIcons.chat_bubble_text_fill,
        size: 48,
        color: AppStyles.accentBlue,
      ),
    );
  }

  Widget _buildDaySelector(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppStyles.darkCard : CupertinoColors.systemBackground,
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(Spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Scan period',
            style: TextStyle(
              fontSize: TypeScale.footnote,
              fontWeight: FontWeight.w600,
              color: AppStyles.getSecondaryTextColor(context),
            ),
          ),
          const SizedBox(height: Spacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [7, 15, 30, 60, 90].map((d) {
              final isSelected = _days == d;
              return GestureDetector(
                onTap: () => setState(() => _days = d),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppStyles.accentBlue
                        : (isDark
                            ? const Color(0xFF1C1C1E)
                            : CupertinoColors.systemGrey6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${d}d',
                    style: TextStyle(
                      fontSize: TypeScale.footnote,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? Colors.white
                          : AppStyles.getTextColor(context),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyNote(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: AppStyles.accentBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(
          color: AppStyles.accentBlue.withValues(alpha: 0.15),
        ),
      ),
      padding: const EdgeInsets.all(Spacing.md),
      child: const Row(
        children: [
          Icon(CupertinoIcons.lock_shield_fill,
              size: 20, color: AppStyles.accentBlue),
          SizedBox(width: Spacing.sm),
          Expanded(
            child: Text(
              'SMS data is processed on-device only and is never uploaded.',
              style: TextStyle(
                fontSize: TypeScale.footnote,
                color: AppStyles.accentBlue,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.lg, 0, Spacing.lg, Spacing.lg),
      child: BouncyButton(
        onPressed: _startScan,
        child: Container(
          width: double.infinity,
          height: 54,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppStyles.accentBlue, AppStyles.accentTeal],
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: AppStyles.elevatedShadows(
              context,
              tint: AppStyles.accentBlue,
              strength: 0.7,
            ),
          ),
          child: const Center(
            child: Text(
              'Scan SMS Inbox',
              style: TextStyle(
                color: Colors.white,
                fontSize: TypeScale.body,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Scanning state ──────────────────────────────────────────────────────────

  Widget _buildScanningState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 80,
                  height: 80,
                  child: CircularProgressIndicator(
                    value: _scanProgress / 100,
                    strokeWidth: 5,
                    backgroundColor: AppStyles.getSecondaryTextColor(context)
                        .withValues(alpha: 0.15),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(AppStyles.accentBlue),
                  ),
                ),
                Text(
                  '$_scanProgress%',
                  style: TextStyle(
                    fontFamily: 'SpaceGrotesk',
                    fontWeight: FontWeight.w700,
                    fontSize: TypeScale.callout,
                    color: AppStyles.getTextColor(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Spacing.xl),
            Text(
              _scanStatus,
              style: TextStyle(
                fontSize: TypeScale.subhead,
                color: AppStyles.getSecondaryTextColor(context),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Spacing.sm),
            Text(
              'This may take a few seconds.',
              style: TextStyle(
                fontSize: TypeScale.footnote,
                color: AppStyles.getSecondaryTextColor(context)
                    .withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── No results ──────────────────────────────────────────────────────────────

  Widget _buildNoResultsState() {
    return Column(
      children: [
        Expanded(
          child: EmptyStateView(
            icon: CupertinoIcons.chat_bubble_text,
            title: 'No Transactions Found',
            subtitle:
                'No bank SMS transactions were detected for the last $_days days.\n\nTry enabling banks in Manage → Banks, or increase the scan period.',
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Spacing.lg, 0, Spacing.lg, Spacing.lg),
          child: CupertinoButton(
            onPressed: () => setState(() {
              _scanDone = false;
              _results = [];
            }),
            child: const Text(
              'Try Again',
              style: TextStyle(
                  color: AppStyles.accentBlue, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  // ── Results list ────────────────────────────────────────────────────────────

  Widget _buildResultsList() {
    final isDark = AppStyles.isDarkMode(context);
    return Column(
      children: [
        // Summary bar
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: Spacing.lg, vertical: Spacing.sm),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_results.length} transaction${_results.length == 1 ? '' : 's'} found  ·  tap to add',
                    style: TextStyle(
                      fontSize: TypeScale.footnote,
                      color: AppStyles.getSecondaryTextColor(context),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (_parseFailCount > 0)
                    Text(
                      '$_parseFailCount message${_parseFailCount == 1 ? '' : 's'} could not be parsed',
                      style: TextStyle(
                        fontSize: TypeScale.caption,
                        color: AppStyles.gold(context).withValues(alpha: 0.8),
                      ),
                    ),
                ],
              ),
              const Spacer(),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _dismissAll,
                child: Text(
                  'Dismiss All',
                  style: TextStyle(
                    fontSize: TypeScale.footnote,
                    color: AppStyles.loss(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => setState(() {
                  _scanDone = false;
                  _results = [];
                }),
                child: const Text(
                  'Re-scan',
                  style: TextStyle(
                    fontSize: TypeScale.footnote,
                    color: AppStyles.accentBlue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Cards
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(Spacing.lg, 0, Spacing.lg, Spacing.lg),
            itemCount: _results.length,
            itemBuilder: (ctx, i) => _buildResultCard(i, isDark),
          ),
        ),

      ],
    );
  }

  void _dismissAll() {
    showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Dismiss All?'),
        content: Text(
          'Mark all ${_results.length} detected transaction${_results.length == 1 ? '' : 's'} as seen. You can re-scan anytime.',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Dismiss All'),
          ),
        ],
      ),
    ).then((confirmed) async {
      if (confirmed != true || !mounted) return;
      final svc = SmsAutoScanService.instance;
      for (final r in _results) {
        await svc.markSeen(svc.fingerprint(r));
      }
      if (!mounted) return;
      setState(() {
        _results = [];
        _scanDone = false;
      });
    });
  }

  Widget _buildResultCard(int i, bool isDark) {
    final r = _results[i];
    final p = r.parsed;
    final isExpense = p.type == 'expense';
    final txColor =
        isExpense ? AppStyles.loss(context) : AppStyles.gain(context);
    final fmt =
        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
    final dateFmt = DateFormat('dd MMM · hh:mm a');
    final dupe = _duplicates[i];
    final acctNum = r.matchedAccount?.creditCardNumber;
    final acctSuffix = acctNum != null && acctNum.length >= 4
        ? acctNum.substring(acctNum.length - 4)
        : null;

    return GestureDetector(
      onTap: () => _openSmsReview(r),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppStyles.darkCard : CupertinoColors.systemBackground,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(
          color: isDark
                  ? Colors.white.withValues(alpha: 0.07)
                  : Colors.black.withValues(alpha: 0.07),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left: colored accent bar
                Container(
                  width: 4,
                  height: 48,
                  decoration: BoxDecoration(
                    color: txColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 12),
                // Center: amount + meta
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Amount
                      Text(
                        fmt.format(p.amount),
                        style: TextStyle(
                          fontFamily: 'SpaceGrotesk',
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: txColor,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Date + Bank
                      Row(
                        children: [
                          Text(
                            dateFmt.format(p.date),
                            style: TextStyle(
                              fontSize: TypeScale.caption,
                              color: AppStyles.getSecondaryTextColor(context),
                            ),
                          ),
                          if (p.bankId != null) ...[
                            Text(
                              '  ·  ',
                              style: TextStyle(
                                color:
                                    AppStyles.getSecondaryTextColor(context),
                              ),
                            ),
                            Text(
                              p.bankId!
                                  .replaceAll('_', ' ')
                                  .split(' ')
                                  .first
                                  .toUpperCase(),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppStyles.accentBlue,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Right: type badge + tap hint
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Type badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: txColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isExpense ? 'EXPENSE' : 'INCOME',
                        style: TextStyle(
                          fontSize: TypeScale.micro,
                          fontWeight: FontWeight.w800,
                          color: txColor,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Icon(
                      CupertinoIcons.add_circled,
                      size: 22,
                      color: txColor.withValues(alpha: 0.7),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Divider ───────────────────────────────────────────────────
          Divider(
            height: 1,
            thickness: 1,
            color:
                (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
          ),

          // ── Meta chips row ────────────────────────────────────────────
          Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  // Merchant
                  if (p.merchant != null)
                    _chip(
                      CupertinoIcons.building_2_fill,
                      p.merchant!,
                      isDark,
                    ),
                  // Account match
                  if (r.matchedAccount != null)
                    _chip(
                      CupertinoIcons.creditcard,
                      '${r.matchedAccount!.bankName}'
                      '${acctSuffix != null ? ' ··$acctSuffix' : ''}'
                      '  ${(r.accountMatchConfidence * 100).toInt()}%',
                      isDark,
                      color: _confidenceColor(context, r.accountMatchConfidence),
                    ),
                  // Duplicate warning
                  if (dupe != null)
                    _chip(
                      CupertinoIcons.exclamationmark_triangle_fill,
                      'Possible duplicate '
                      '${(dupe.confidence * 100).toInt()}%',
                      isDark,
                      color: dupe.confidence >= 0.8
                          ? CupertinoColors.systemOrange
                          : CupertinoColors.systemYellow,
                    ),
                ],
              ),
          ),

          // ── Footer: confidence + View message ─────────────────────────
          Divider(
            height: 1,
            thickness: 1,
            color:
                (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            child: Row(
              children: [
                // Confidence indicator
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color:
                        _confidenceColor(context, p.confidence).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${(p.confidence * 100).toInt()}% confidence',
                    style: TextStyle(
                      fontSize: TypeScale.label,
                      fontWeight: FontWeight.w600,
                      color: _confidenceColor(context, p.confidence),
                    ),
                  ),
                ),
                const Spacer(),
                // View full message button
                CupertinoButton(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  onPressed: () => _showMessageModal(i, isDark),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        CupertinoIcons.eye,
                        size: 14,
                        color: AppStyles.accentBlue,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'View message',
                        style: TextStyle(
                          fontSize: TypeScale.caption,
                          color: AppStyles.accentBlue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _chip(IconData icon, String label, bool isDark, {Color? color}) {
    final c =
        color ?? (isDark ? const Color(0xFF8E8E93) : const Color(0xFF6C6C70));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: c),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: c,
            ),
          ),
        ],
      ),
    );
  }

  void _showMessageModal(int i, bool isDark) {
    final r = _results[i];
    final p = r.parsed;
    final fmt =
        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
    final dateFmt = DateFormat('dd MMMM yyyy · hh:mm a');
    final dupe = _duplicates[i];

    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => Container(
        height: AppStyles.sheetMaxHeight(ctx),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF1C1C1E)
              : CupertinoColors.systemBackground,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.black)
                      .withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fmt.format(p.amount),
                          style: TextStyle(
                            fontFamily: 'SpaceGrotesk',
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: p.type == 'expense'
                                ? AppStyles.loss(context)
                                : AppStyles.gain(context),
                          ),
                        ),
                        Text(
                          dateFmt.format(p.date),
                          style: TextStyle(
                            fontSize: 13,
                            color: AppStyles.getSecondaryTextColor(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Icon(CupertinoIcons.xmark_circle_fill,
                        color: AppStyles.getSecondaryTextColor(context)
                            .withValues(alpha: 0.5),
                        size: 28),
                  ),
                ],
              ),
            ),
            Divider(
                height: 1,
                color: (isDark ? Colors.white : Colors.black)
                    .withValues(alpha: 0.08)),
            // Scrollable content
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Parsed fields
                  _modalRow('From', p.sender),
                  if (p.bankId != null)
                    _modalRow(
                        'Bank', p.bankId!.replaceAll('_', ' ').toUpperCase()),
                  if (p.merchant != null) _modalRow('Merchant', p.merchant!),
                  if (p.upiId != null) _modalRow('UPI ID', p.upiId!),
                  if (p.accountLast4 != null)
                    _modalRow('Account', '····${p.accountLast4}'),
                  if (p.cardLast4 != null)
                    _modalRow('Card', '····${p.cardLast4}'),
                  if (p.balance != null)
                    _modalRow('Balance after', fmt.format(p.balance)),
                  _modalRow('Parsed by', p.parseMethod.replaceAll('_', ' ')),
                  const SizedBox(height: 20),
                  // Duplicate warning
                  if (dupe != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemOrange
                            .withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: CupertinoColors.systemOrange
                              .withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                              CupertinoIcons.exclamationmark_triangle_fill,
                              size: 16,
                              color: CupertinoColors.systemOrange),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Possible duplicate: '
                              '${fmt.format(dupe.transaction.amount)} '
                              'on ${DateFormat('dd MMM yyyy').format(dupe.transaction.dateTime)} '
                              '(${(dupe.confidence * 100).toInt()}% match)',
                              style: const TextStyle(
                                fontSize: TypeScale.caption,
                                color: CupertinoColors.systemOrange,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  // Full SMS message
                  Text(
                    'Full Message',
                    style: TextStyle(
                      fontSize: TypeScale.caption,
                      fontWeight: FontWeight.w700,
                      color: AppStyles.getSecondaryTextColor(context),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: (isDark ? Colors.white : Colors.black)
                          .withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(Radii.md),
                      border: Border.all(
                        color: (isDark ? Colors.white : Colors.black)
                            .withValues(alpha: 0.08),
                      ),
                    ),
                    child: SelectableText(
                      p.rawMessage,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.6,
                        color: AppStyles.getTextColor(context),
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _modalRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: AppStyles.getSecondaryTextColor(context),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppStyles.getTextColor(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _confidenceColor(BuildContext context, double c) {
    if (c >= 0.85) return AppStyles.gain(context);
    if (c >= 0.65) return CupertinoColors.systemOrange;
    return AppStyles.loss(context);
  }
}

// ── SMS Quick Confirm Sheet ───────────────────────────────────────────────────

class _SmsQuickConfirmSheet extends StatefulWidget {
  final SmsParseResult item;
  final VoidCallback onSaved;
  final VoidCallback onOpenWizard; // used only for Transfer type

  const _SmsQuickConfirmSheet({
    required this.item,
    required this.onSaved,
    required this.onOpenWizard,
  });

  @override
  State<_SmsQuickConfirmSheet> createState() => _SmsQuickConfirmSheetState();
}

class _SmsQuickConfirmSheetState extends State<_SmsQuickConfirmSheet> {
  // ── Type ─────────────────────────────────────────────────────────────────
  late bool _isCreditSms;
  late _SmsConfirmType _txType;

  // ── Fields ────────────────────────────────────────────────────────────────
  late TextEditingController _amountController;
  late TextEditingController _descriptionController;
  late TextEditingController _tagController;
  late DateTime _selectedDate;
  Category? _selectedCategory;
  Account? _selectedAccount;
  String? _selectedPaymentApp;
  final List<String> _selectedTags = [];

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.item.parsed;
    _isCreditSms = p.type == 'income';
    _txType = _isCreditSms ? _SmsConfirmType.income : _SmsConfirmType.expense;
    _amountController =
        TextEditingController(text: p.amount.toStringAsFixed(2));
    _descriptionController =
        TextEditingController(text: p.merchant ?? p.upiId ?? '');
    _tagController = TextEditingController();
    _selectedDate = p.date;
    _selectedAccount = widget.item.matchedAccount;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_selectedCategory == null &&
        _txType == _SmsConfirmType.expense) {
      final cats = context.read<CategoriesController>().categories;
      if (cats.isNotEmpty) _selectedCategory = cats.first;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  // ── Save ─────────────────────────────────────────────────────────────────
  Future<void> _save() async {
    if (_txType == _SmsConfirmType.transfer) {
      Navigator.pop(context);
      widget.onOpenWizard();
      return;
    }
    final amount = double.tryParse(_amountController.text) ?? 0;
    if (amount <= 0) {
      toast.showError('Enter a valid amount');
      return;
    }
    if (_saving) return;
    setState(() => _saving = true);

    try {
      final txCtrl = context.read<TransactionsController>();
      final type = _txType == _SmsConfirmType.income
          ? TransactionType.income
          : TransactionType.expense;
      final meta = <String, dynamic>{
        if (_selectedCategory != null) 'categoryId': _selectedCategory!.id,
        if (_selectedCategory != null)
          'categoryName': _selectedCategory!.name,
        if (_selectedPaymentApp != null) 'paymentApp': _selectedPaymentApp,
        if (_selectedTags.isNotEmpty) 'tags': _selectedTags,
        'fromSms': true,
      };
      if (_selectedAccount != null) {
        meta['accountId'] = _selectedAccount!.id;
        meta['accountName'] = _selectedAccount!.name;
      }
      // Compute balance snapshot to record at time of transaction
      if (_selectedAccount != null) {
        final current = context.read<AccountsController>().accounts
            .firstWhere((a) => a.id == _selectedAccount!.id,
                orElse: () => _selectedAccount!);
        final delta = type == TransactionType.income ? amount : -amount;
        meta['sourceBalanceAfter'] = current.balance + delta;
        if (current.creditLimit != null) {
          meta['sourceCreditLimit'] = current.creditLimit;
        }
      }
      final desc = _descriptionController.text.trim();
      final tx = Transaction(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: type,
        description: desc.isNotEmpty ? desc : 'SMS Transaction',
        dateTime: _selectedDate,
        amount: amount,
        // sourceAccountId + paymentAppName must be set directly (not just in
        // metadata) so that TransactionAccountAdjuster.reverseTransaction()
        // can find them and correctly reverse balances on permanent delete.
        sourceAccountId: _selectedAccount?.id,
        sourceAccountName: _selectedAccount?.name,
        paymentAppName: _selectedPaymentApp,
        metadata: meta,
      );
      await txCtrl.addTransaction(tx);
      if (!mounted) return;

      // Update account balance
      if (_selectedAccount != null) {
        final acctCtrl = context.read<AccountsController>();
        final fresh = acctCtrl.accounts
            .where((a) => a.id == _selectedAccount!.id)
            .firstOrNull;
        if (fresh != null) {
          final delta =
              type == TransactionType.income ? amount : -amount;
          await acctCtrl
              .updateAccount(fresh.copyWith(balance: fresh.balance + delta));
        }
      }

      // Update payment app wallet
      if (_selectedPaymentApp != null) {
        final appCtrl = context.read<PaymentAppsController>();
        final delta =
            type == TransactionType.income ? amount : -amount;
        await appCtrl.adjustWalletBalanceByName(
            _selectedPaymentApp!, delta);
      }

      if (!mounted) return;
      Navigator.pop(context);
      widget.onSaved();
      toast.showSuccess(
        '${type == TransactionType.income ? 'Income' : 'Expense'} saved — ${CurrencyFormatter.compact(amount)}',
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Tag helpers ──────────────────────────────────────────────────────────
  void _addTag(String tag) {
    final t = tag.trim();
    if (t.isNotEmpty && !_selectedTags.contains(t)) {
      setState(() => _selectedTags.add(t));
    }
    _tagController.clear();
  }

  void _removeTag(String tag) => setState(() => _selectedTags.remove(tag));

  // ── Pickers ──────────────────────────────────────────────────────────────
  Future<void> _pickDate() async {
    final picked = await showAppDatePicker(
      context: context,
      initialDate: _selectedDate,
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  void _pickAccount() {
    final accounts =
        context.read<AccountsController>().accounts;
    if (accounts.isEmpty) return;
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Select Account'),
        actions: [
          ...accounts.map((a) => CupertinoActionSheetAction(
                onPressed: () {
                  setState(() => _selectedAccount = a);
                  Navigator.pop(ctx);
                },
                child: Text(a.name),
              )),
          CupertinoActionSheetAction(
            onPressed: () {
              setState(() => _selectedAccount = null);
              Navigator.pop(ctx);
            },
            child: const Text('No Account'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  void _pickPaymentApp() {
    final apps =
        context.read<PaymentAppsController>().paymentApps;
    if (apps.isEmpty) return;
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Select Payment App'),
        actions: [
          ...apps.map((a) => CupertinoActionSheetAction(
                onPressed: () {
                  setState(() => _selectedPaymentApp = a['name'] as String);
                  Navigator.pop(ctx);
                },
                child: Text(a['name'] as String),
              )),
          CupertinoActionSheetAction(
            onPressed: () {
              setState(() => _selectedPaymentApp = null);
              Navigator.pop(ctx);
            },
            child: const Text('None'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = AppStyles.isDarkMode(context);
    final p = widget.item.parsed;
    final isTransfer = _txType == _SmsConfirmType.transfer;
    final isIncome = _txType == _SmsConfirmType.income;
    final accentColor = isTransfer
        ? AppStyles.accentBlue
        : isIncome
            ? AppStyles.gain(context)
            : AppStyles.loss(context);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (ctx, scrollController) => Container(
        decoration: AppStyles.bottomSheetDecoration(context),
        child: Column(
          children: [
            // ── Handle + header ───────────────────────────────────────────
            const ModalHandle(),
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(Spacing.lg, 4, Spacing.lg, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Save from SMS',
                      style: AppStyles.headerStyle(context),
                    ),
                  ),
                  // SMS source badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: accentColor.withValues(alpha: 0.3),
                          width: 0.8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                              color: accentColor,
                              shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'SMS',
                          style: TextStyle(
                            fontSize: TypeScale.caption,
                            fontWeight: FontWeight.w700,
                            color: accentColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Spacing.sm),

            // ── Scrollable form ───────────────────────────────────────────
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(
                    Spacing.lg, 0, Spacing.lg, Spacing.xxxl),
                children: [
                  // ── Amount ─────────────────────────────────────────────
                  _FormSection(
                    label: 'Amount',
                    fromSms: true,
                    child: CupertinoTextField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      prefix: Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: Text('₹',
                            style: AppStyles.titleStyle(context)),
                      ),
                      style: AppStyles.titleStyle(context).copyWith(
                          fontWeight: FontWeight.w700),
                      decoration: BoxDecoration(
                        color: AppStyles.getCardColor(context),
                        borderRadius: BorderRadius.circular(Radii.md),
                        border: Border.all(
                            color: AppStyles.getDividerColor(context)),
                      ),
                    ),
                  ),
                  const SizedBox(height: Spacing.lg),

                  // ── Date ───────────────────────────────────────────────
                  _FormSection(
                    label: 'Date',
                    fromSms: true,
                    child: GestureDetector(
                      onTap: _pickDate,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 14),
                        decoration: BoxDecoration(
                          color: AppStyles.getCardColor(context),
                          borderRadius: BorderRadius.circular(Radii.md),
                          border: Border.all(
                              color: AppStyles.getDividerColor(context)),
                        ),
                        child: Row(
                          children: [
                            Icon(CupertinoIcons.calendar,
                                size: 16,
                                color:
                                    AppStyles.getSecondaryTextColor(context)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${_selectedDate.day} ${DateFormatter.getMonthName(_selectedDate.month)} ${_selectedDate.year}',
                                style: TextStyle(fontSize: TypeScale.body, color: AppStyles.getTextColor(context)),
                              ),
                            ),
                            Icon(CupertinoIcons.chevron_right,
                                size: 14,
                                color:
                                    AppStyles.getSecondaryTextColor(context)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: Spacing.lg),

                  // ── Type ───────────────────────────────────────────────
                  _FormSection(
                    label: 'Type',
                    fromSms: true,
                    child: Row(
                      children: [
                        _typeChip(
                          context,
                          label: 'Expense',
                          icon: CupertinoIcons.arrow_up_circle_fill,
                          color: AppStyles.loss(context),
                          selected: _txType == _SmsConfirmType.expense,
                          onTap: () {
                            setState(() {
                              _txType = _SmsConfirmType.expense;
                              if (_selectedCategory == null) {
                                final cats = context
                                    .read<CategoriesController>()
                                    .categories;
                                if (cats.isNotEmpty) {
                                  _selectedCategory = cats.first;
                                }
                              }
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        _typeChip(
                          context,
                          label: 'Income',
                          icon: CupertinoIcons.arrow_down_circle_fill,
                          color: AppStyles.gain(context),
                          selected: _txType == _SmsConfirmType.income,
                          onTap: () => setState(
                              () => _txType = _SmsConfirmType.income),
                        ),
                        const SizedBox(width: 8),
                        _typeChip(
                          context,
                          label: 'Transfer',
                          icon: CupertinoIcons.arrow_right_arrow_left,
                          color: AppStyles.accentBlue,
                          selected: _txType == _SmsConfirmType.transfer,
                          onTap: () => setState(
                              () => _txType = _SmsConfirmType.transfer),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Spacing.lg),

                  // ── Category (expense only) ────────────────────────────
                  if (_txType == _SmsConfirmType.expense) ...[
                    _FormSection(
                      label: 'Category',
                      isEmpty: _selectedCategory == null,
                      child: Consumer<CategoriesController>(
                        builder: (ctx, catCtrl, _) {
                          final cats = catCtrl.categories;
                          return SizedBox(
                            height: 42,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: cats.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 8),
                              itemBuilder: (ctx, i) {
                                final cat = cats[i];
                                final sel =
                                    _selectedCategory?.id == cat.id;
                                return GestureDetector(
                                  onTap: () => setState(
                                      () => _selectedCategory = cat),
                                  child: AnimatedContainer(
                                    duration:
                                        const Duration(milliseconds: 160),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: sel
                                          ? cat.color
                                              .withValues(alpha: 0.18)
                                          : AppStyles.getCardColor(context),
                                      borderRadius:
                                          BorderRadius.circular(20),
                                      border: Border.all(
                                        color: sel
                                            ? cat.color
                                            : AppStyles.getDividerColor(
                                                context),
                                        width: sel ? 1.5 : 0.8,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(cat.icon,
                                            size: 13,
                                            color: sel
                                                ? cat.color
                                                : AppStyles
                                                    .getSecondaryTextColor(
                                                        context)),
                                        const SizedBox(width: 5),
                                        Text(cat.name,
                                            style: TextStyle(
                                              fontSize: TypeScale.caption,
                                              fontWeight: sel
                                                  ? FontWeight.w700
                                                  : FontWeight.w500,
                                              color: sel
                                                  ? cat.color
                                                  : AppStyles.getTextColor(
                                                      context),
                                            )),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: Spacing.lg),
                  ],

                  // ── Account ────────────────────────────────────────────
                  _FormSection(
                    label: 'Account',
                    fromSms: _selectedAccount != null &&
                        widget.item.matchedAccount?.id ==
                            _selectedAccount?.id,
                    isEmpty: _selectedAccount == null,
                    child: GestureDetector(
                      onTap: _pickAccount,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 14),
                        decoration: BoxDecoration(
                          color: AppStyles.getCardColor(context),
                          borderRadius: BorderRadius.circular(Radii.md),
                          border: Border.all(
                            color: _selectedAccount == null
                                ? AppStyles.loss(context).withValues(alpha: 0.5)
                                : AppStyles.getDividerColor(context),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(CupertinoIcons.creditcard,
                                size: 16,
                                color: _selectedAccount == null
                                    ? AppStyles.loss(context)
                                    : AppStyles.getSecondaryTextColor(
                                        context)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _selectedAccount?.name ?? 'Tap to select account',
                                style: TextStyle(fontSize: TypeScale.body, color: AppStyles.getTextColor(context)).copyWith(
                                  color: _selectedAccount == null
                                      ? AppStyles.loss(context)
                                      : AppStyles.getTextColor(context),
                                ),
                              ),
                            ),
                            Icon(CupertinoIcons.chevron_right,
                                size: 14,
                                color:
                                    AppStyles.getSecondaryTextColor(context)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: Spacing.lg),

                  // ── Payment App ────────────────────────────────────────
                  Consumer<PaymentAppsController>(
                    builder: (ctx, appCtrl, _) {
                      if (appCtrl.paymentApps.isEmpty) return const SizedBox.shrink();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _FormSection(
                            label: 'Payment App',
                            isEmpty: _selectedPaymentApp == null,
                            child: GestureDetector(
                              onTap: _pickPaymentApp,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 14),
                                decoration: BoxDecoration(
                                  color: AppStyles.getCardColor(context),
                                  borderRadius:
                                      BorderRadius.circular(Radii.md),
                                  border: Border.all(
                                      color:
                                          AppStyles.getDividerColor(context)),
                                ),
                                child: Row(
                                  children: [
                                    Icon(CupertinoIcons.device_phone_portrait,
                                        size: 16,
                                        color: AppStyles.getSecondaryTextColor(
                                            context)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _selectedPaymentApp ??
                                            'Optional — tap to select',
                                        style: TextStyle(fontSize: TypeScale.body, color: AppStyles.getTextColor(context))
                                            .copyWith(
                                          color: _selectedPaymentApp == null
                                              ? AppStyles.getSecondaryTextColor(
                                                  context)
                                              : AppStyles.getTextColor(context),
                                        ),
                                      ),
                                    ),
                                    Icon(CupertinoIcons.chevron_right,
                                        size: 14,
                                        color: AppStyles.getSecondaryTextColor(
                                            context)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: Spacing.lg),
                        ],
                      );
                    },
                  ),

                  // ── Description ────────────────────────────────────────
                  _FormSection(
                    label: 'Description',
                    fromSms: p.merchant != null || p.upiId != null,
                    isEmpty: _descriptionController.text.trim().isEmpty,
                    child: CupertinoTextField(
                      controller: _descriptionController,
                      placeholder: 'Merchant, note or description',
                      placeholderStyle: TextStyle(
                          color: AppStyles.getSecondaryTextColor(context)),
                      style: TextStyle(fontSize: TypeScale.body, color: AppStyles.getTextColor(context)),
                      decoration: BoxDecoration(
                        color: AppStyles.getCardColor(context),
                        borderRadius: BorderRadius.circular(Radii.md),
                        border: Border.all(
                            color: AppStyles.getDividerColor(context)),
                      ),
                      padding: const EdgeInsets.all(12),
                    ),
                  ),
                  const SizedBox(height: Spacing.lg),

                  // ── Tags ───────────────────────────────────────────────
                  Consumer<TagsController>(
                    builder: (ctx, tagsCtrl, _) {
                      if (tagsCtrl.tags.isEmpty &&
                          _selectedTags.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _FormSection(
                            label: 'Tags',
                            isEmpty: _selectedTags.isEmpty,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Existing system tags as chips
                                if (tagsCtrl.tags.isNotEmpty)
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    children: tagsCtrl.tags.map((tag) {
                                      final sel = _selectedTags
                                          .contains(tag.name);
                                      return GestureDetector(
                                        onTap: () => sel
                                            ? _removeTag(tag.name)
                                            : _addTag(tag.name),
                                        child: AnimatedContainer(
                                          duration: const Duration(
                                              milliseconds: 150),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 5),
                                          decoration: BoxDecoration(
                                            color: sel
                                                ? AppStyles.accentBlue
                                                    .withValues(alpha: 0.15)
                                                : AppStyles.getCardColor(
                                                    context),
                                            borderRadius:
                                                BorderRadius.circular(16),
                                            border: Border.all(
                                              color: sel
                                                  ? AppStyles.accentBlue
                                                  : AppStyles.getDividerColor(
                                                      context),
                                              width: sel ? 1.5 : 0.8,
                                            ),
                                          ),
                                          child: Text(
                                            tag.name,
                                            style: TextStyle(
                                              fontSize: TypeScale.caption,
                                              fontWeight: sel
                                                  ? FontWeight.w700
                                                  : FontWeight.w500,
                                              color: sel
                                                  ? AppStyles.accentBlue
                                                  : AppStyles.getTextColor(
                                                      context),
                                            ),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                // Selected custom tags
                                if (_selectedTags
                                    .where((t) => !tagsCtrl.tags
                                        .any((tt) => tt.name == t))
                                    .isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    children: _selectedTags
                                        .where((t) => !tagsCtrl.tags
                                            .any((tt) => tt.name == t))
                                        .map((t) => GestureDetector(
                                              onTap: () => _removeTag(t),
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 5),
                                                decoration: BoxDecoration(
                                                  color: AppStyles.accentBlue
                                                      .withValues(alpha: 0.15),
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                  border: Border.all(
                                                      color:
                                                          AppStyles.accentBlue),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Text(t,
                                                        style: const TextStyle(
                                                            fontSize:
                                                                TypeScale.caption,
                                                            color: AppStyles
                                                                .accentBlue)),
                                                    const SizedBox(width: 4),
                                                    const Icon(
                                                        CupertinoIcons.xmark,
                                                        size: 10,
                                                        color:
                                                            AppStyles.accentBlue),
                                                  ],
                                                ),
                                              ),
                                            ))
                                        .toList(),
                                  ),
                                ],
                                const SizedBox(height: 8),
                                // Custom tag input
                                CupertinoTextField(
                                  controller: _tagController,
                                  placeholder: 'Add a tag and press Return',
                                  placeholderStyle: TextStyle(
                                      color: AppStyles.getSecondaryTextColor(
                                          context)),
                                  style: TextStyle(fontSize: TypeScale.body, color: AppStyles.getTextColor(context)),
                                  decoration: BoxDecoration(
                                    color: AppStyles.getCardColor(context),
                                    borderRadius:
                                        BorderRadius.circular(Radii.md),
                                    border: Border.all(
                                        color:
                                            AppStyles.getDividerColor(context)),
                                  ),
                                  padding: const EdgeInsets.all(10),
                                  onSubmitted: _addTag,
                                  textInputAction: TextInputAction.done,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: Spacing.lg),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),

            // ── Save button ───────────────────────────────────────────────
            Container(
              color: AppStyles.getBackground(context),
              padding: EdgeInsets.fromLTRB(
                Spacing.lg,
                Spacing.md,
                Spacing.lg,
                MediaQuery.of(context).padding.bottom + Spacing.md,
              ),
              child: CupertinoButton(
                padding:
                    const EdgeInsets.symmetric(vertical: 16),
                color: isTransfer
                    ? AppStyles.accentBlue
                    : isIncome
                        ? AppStyles.gain(context)
                        : AppStyles.loss(context),
                borderRadius: BorderRadius.circular(Radii.md),
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const CupertinoActivityIndicator(
                        color: Colors.white)
                    : Text(
                        isTransfer
                            ? 'Open Transfer Wizard'
                            : isIncome
                                ? 'Save Income'
                                : 'Save Expense',
                        style: const TextStyle(
                          fontSize: TypeScale.callout,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _typeChip(
    BuildContext context, {
    required String label,
    required IconData icon,
    required Color color,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding:
              const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.15)
                : AppStyles.getCardColor(context),
            borderRadius: BorderRadius.circular(Radii.md),
            border: Border.all(
              color: selected
                  ? color
                  : AppStyles.getDividerColor(context),
              width: selected ? 1.5 : 0.8,
            ),
          ),
          child: Column(
            children: [
              Icon(icon,
                  size: 18,
                  color: selected
                      ? color
                      : AppStyles.getSecondaryTextColor(context)),
              const SizedBox(height: 4),
              Text(label,
                  style: TextStyle(
                    fontSize: TypeScale.caption,
                    fontWeight: selected
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: selected
                        ? color
                        : AppStyles.getTextColor(context),
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Form section label widget ─────────────────────────────────────────────────

class _FormSection extends StatelessWidget {
  final String label;
  final Widget child;
  final bool fromSms;
  final bool isEmpty;

  const _FormSection({
    required this.label,
    required this.child,
    this.fromSms = false,
    this.isEmpty = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: TypeScale.caption,
                fontWeight: FontWeight.w600,
                color: AppStyles.getSecondaryTextColor(context),
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(width: 6),
            if (fromSms)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: AppStyles.accentBlue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(CupertinoIcons.checkmark_alt,
                        size: 9, color: AppStyles.accentBlue),
                    const SizedBox(width: 3),
                    const Text(
                      'from SMS',
                      style: TextStyle(
                        fontSize: TypeScale.micro,
                        fontWeight: FontWeight.w700,
                        color: AppStyles.accentBlue,
                      ),
                    ),
                  ],
                ),
              )
            else if (isEmpty)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: AppStyles.loss(context).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'empty',
                  style: TextStyle(
                    fontSize: TypeScale.micro,
                    fontWeight: FontWeight.w600,
                    color: AppStyles.loss(context),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

enum _SmsConfirmType { expense, income, transfer }
