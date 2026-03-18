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
import 'package:vittara_fin_os/logic/transaction_model.dart';
import 'package:vittara_fin_os/logic/transactions_controller.dart';
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
      navigationBar: CupertinoNavigationBar(
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
                      color: AppStyles.plasmaRed.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      CupertinoIcons.lock_shield,
                      size: 40,
                      color: AppStyles.plasmaRed,
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
                        color: AppStyles.solarGold.withValues(alpha: 0.8),
                      ),
                    ),
                ],
              ),
              const Spacer(),
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

  Widget _buildResultCard(int i, bool isDark) {
    final r = _results[i];
    final p = r.parsed;
    final isExpense = p.type == 'expense';
    final txColor =
        isExpense ? AppStyles.plasmaRed : AppStyles.bioGreen;
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
                          fontSize: 9,
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
                      color: _confidenceColor(r.accountMatchConfidence),
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
                        _confidenceColor(p.confidence).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${(p.confidence * 100).toInt()}% confidence',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: _confidenceColor(p.confidence),
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
        height: MediaQuery.of(ctx).size.height * 0.75,
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
                                ? AppStyles.plasmaRed
                                : AppStyles.bioGreen,
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

  Color _confidenceColor(double c) {
    if (c >= 0.85) return AppStyles.bioGreen;
    if (c >= 0.65) return CupertinoColors.systemOrange;
    return AppStyles.plasmaRed;
  }
}

// ── SMS Quick Confirm Sheet ───────────────────────────────────────────────────

class _SmsQuickConfirmSheet extends StatefulWidget {
  final SmsParseResult item;
  final VoidCallback onSaved;
  final VoidCallback onOpenWizard;

  const _SmsQuickConfirmSheet({
    required this.item,
    required this.onSaved,
    required this.onOpenWizard,
  });

  @override
  State<_SmsQuickConfirmSheet> createState() => _SmsQuickConfirmSheetState();
}

class _SmsQuickConfirmSheetState extends State<_SmsQuickConfirmSheet> {
  late bool _isExpense; // true = use SMS type (expense/income); false = transfer
  late bool _isCreditSms; // true if SMS type == 'income'
  Category? _selectedCategory;
  Account? _selectedAccount;

  @override
  void initState() {
    super.initState();
    _isCreditSms = widget.item.parsed.type == 'income';
    _isExpense = true;
    _selectedAccount = widget.item.matchedAccount;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_selectedCategory == null && !_isCreditSms) {
      final cats = context.read<CategoriesController>().categories;
      if (cats.isNotEmpty) _selectedCategory = cats.first;
    }
  }

  Future<void> _save() async {
    if (_isExpense) {
      final txCtrl = context.read<TransactionsController>();
      final p = widget.item.parsed;
      final meta = <String, dynamic>{
        if (_selectedCategory != null) 'categoryId': _selectedCategory!.id,
        if (_selectedCategory != null) 'categoryName': _selectedCategory!.name,
        if (p.merchant != null) 'merchant': p.merchant,
        if (p.upiId != null) 'upiId': p.upiId,
        'fromSms': true,
      };
      if (_selectedAccount != null) {
        meta['accountId'] = _selectedAccount!.id;
        meta['accountName'] = _selectedAccount!.name;
      }
      final tx = Transaction(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: _isCreditSms ? TransactionType.income : TransactionType.expense,
        description: p.merchant ?? p.upiId ?? 'SMS Transaction',
        dateTime: p.date,
        amount: p.amount,
        metadata: meta,
      );
      await txCtrl.addTransaction(tx);
      if (!mounted) return;
      if (_selectedAccount != null) {
        final acctCtrl = context.read<AccountsController>();
        final fresh = acctCtrl.accounts
            .where((a) => a.id == _selectedAccount!.id)
            .firstOrNull;
        if (fresh != null) {
          final delta = _isCreditSms ? p.amount : -p.amount;
          await acctCtrl.updateAccount(
              fresh.copyWith(balance: fresh.balance + delta));
        }
      }
      if (!mounted) return;
      Navigator.pop(context);
      widget.onSaved();
      toast.showSuccess(
        '${_isCreditSms ? 'Income' : 'Expense'} saved — ${CurrencyFormatter.compact(p.amount)}',
      );
    } else {
      Navigator.pop(context);
      widget.onOpenWizard();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppStyles.isDarkMode(context);
    final p = widget.item.parsed;
    final sheetBg = isDark ? AppStyles.darkBackground : Colors.white;
    final accentColor =
        _isCreditSms ? AppStyles.bioGreen : AppStyles.plasmaRed;
    final smsLabel = _isCreditSms ? 'Income' : 'Expense';
    final smsIcon = _isCreditSms
        ? CupertinoIcons.arrow_down_circle_fill
        : CupertinoIcons.arrow_up_circle_fill;

    return Container(
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppStyles.getDividerColor(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            // Amount hero
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                              color: accentColor, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 5),
                        Text('SMS',
                            style: TextStyle(
                              fontSize: TypeScale.caption,
                              fontWeight: FontWeight.w700,
                              color: accentColor,
                            )),
                        if (widget.item.matchedAccount != null) ...[
                          const SizedBox(width: 4),
                          Text(
                            '· ${widget.item.matchedAccount!.bankName}',
                            style: TextStyle(
                              fontSize: TypeScale.caption,
                              color: accentColor.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_isCreditSms ? '+' : '−'}${CurrencyFormatter.compact(p.amount)}',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: accentColor,
                      letterSpacing: -1.0,
                    ),
                  ),
                ],
              ),
            ),

            // Confirmed details chips
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  _confirmedChip(context,
                      icon: CupertinoIcons.calendar,
                      label:
                          '${p.date.day} ${DateFormatter.getMonthName(p.date.month)} ${p.date.year}'),
                  if (p.merchant != null) ...[
                    const SizedBox(width: 8),
                    _confirmedChip(context,
                        icon: CupertinoIcons.building_2_fill,
                        label: p.merchant!),
                  ] else if (p.upiId != null) ...[
                    const SizedBox(width: 8),
                    _confirmedChip(context,
                        icon: CupertinoIcons.link,
                        label: p.upiId!.length > 20
                            ? '${p.upiId!.substring(0, 20)}…'
                            : p.upiId!),
                  ],
                ],
              ),
            ),

            // Type selector (2 options only)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'What is this?',
                    style: TextStyle(
                      fontSize: TypeScale.caption,
                      fontWeight: FontWeight.w600,
                      color: AppStyles.getSecondaryTextColor(context),
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _typeButton(context,
                          label: smsLabel,
                          icon: smsIcon,
                          color: accentColor,
                          selected: _isExpense,
                          onTap: () => setState(() => _isExpense = true)),
                      const SizedBox(width: 10),
                      _typeButton(context,
                          label: 'Transfer',
                          icon: CupertinoIcons.arrow_right_arrow_left,
                          color: AppStyles.accentBlue,
                          selected: !_isExpense,
                          onTap: () => setState(() => _isExpense = false)),
                    ],
                  ),
                ],
              ),
            ),

            // Category chips (expense only)
            if (_isExpense && !_isCreditSms) ...[
              const SizedBox(height: 14),
              Padding(
                padding:
                    const EdgeInsets.only(left: 20, right: 20, bottom: 4),
                child: Text('Category',
                    style: TextStyle(
                      fontSize: TypeScale.caption,
                      fontWeight: FontWeight.w600,
                      color: AppStyles.getSecondaryTextColor(context),
                      letterSpacing: 0.3,
                    )),
              ),
              SizedBox(
                height: 42,
                child: Consumer<CategoriesController>(
                  builder: (ctx, catCtrl, _) {
                    final cats = catCtrl.categories;
                    return ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: cats.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(width: 8),
                      itemBuilder: (ctx, i) {
                        final cat = cats[i];
                        final sel = _selectedCategory?.id == cat.id;
                        return GestureDetector(
                          onTap: () =>
                              setState(() => _selectedCategory = cat),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: sel
                                  ? cat.color.withValues(alpha: 0.18)
                                  : AppStyles.getBackground(context),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: sel
                                    ? cat.color
                                    : AppStyles.getDividerColor(context),
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
                                        : AppStyles.getSecondaryTextColor(
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
                                          : AppStyles.getTextColor(context),
                                    )),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],

            // Account row
            if (_selectedAccount != null && _isExpense) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Icon(CupertinoIcons.creditcard,
                        size: 13,
                        color: AppStyles.getSecondaryTextColor(context)),
                    const SizedBox(width: 6),
                    Text(_selectedAccount!.name,
                        style: TextStyle(
                          fontSize: TypeScale.footnote,
                          color: AppStyles.getSecondaryTextColor(context),
                        )),
                    const SizedBox(width: 4),
                    const Icon(CupertinoIcons.checkmark_circle_fill,
                        size: 12, color: AppStyles.bioGreen),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            // Action buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: CupertinoButton(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      color: AppStyles.getBackground(context),
                      borderRadius: BorderRadius.circular(Radii.md),
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onOpenWizard();
                      },
                      child: Text('Customize',
                          style: TextStyle(
                            fontSize: TypeScale.footnote,
                            fontWeight: FontWeight.w600,
                            color: AppStyles.getSecondaryTextColor(context),
                          )),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 3,
                    child: CupertinoButton(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      color:
                          _isExpense ? accentColor : AppStyles.accentBlue,
                      borderRadius: BorderRadius.circular(Radii.md),
                      onPressed: _save,
                      child: Text(
                        _isExpense
                            ? 'Save ${_isCreditSms ? 'Income' : 'Expense'}'
                            : 'Open Transfer',
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
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _confirmedChip(BuildContext context,
      {required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppStyles.getBackground(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: AppStyles.getDividerColor(context), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 11,
              color: AppStyles.getSecondaryTextColor(context)),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                fontSize: TypeScale.caption,
                color: AppStyles.getSecondaryTextColor(context),
              )),
          const SizedBox(width: 4),
          const Icon(CupertinoIcons.checkmark_alt,
              size: 10, color: AppStyles.bioGreen),
        ],
      ),
    );
  }

  Widget _typeButton(
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
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.15)
                : AppStyles.getBackground(context),
            borderRadius: BorderRadius.circular(Radii.md),
            border: Border.all(
              color: selected ? color : AppStyles.getDividerColor(context),
              width: selected ? 1.5 : 0.8,
            ),
          ),
          child: Column(
            children: [
              Icon(icon,
                  size: 22,
                  color: selected
                      ? color
                      : AppStyles.getSecondaryTextColor(context)),
              const SizedBox(height: 4),
              Text(label,
                  style: TextStyle(
                    fontSize: TypeScale.footnote,
                    fontWeight:
                        selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected
                        ? color
                        : AppStyles.getSecondaryTextColor(context),
                  )),
            ],
          ),
        ),
      ),
    );
  }
}
