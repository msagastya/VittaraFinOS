import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'
    show
        CircularProgressIndicator,
        AlwaysStoppedAnimation,
        Colors,
        Divider,
        SelectableText;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/accounts_controller.dart';
import 'package:vittara_fin_os/logic/banks_controller.dart';
import 'package:vittara_fin_os/logic/transaction_model.dart';
import 'package:vittara_fin_os/logic/transactions_controller.dart';
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
  final Set<int> _selected = {};
  final Map<int, _DuplicateMatch> _duplicates = {};
  bool _scanDone = false;
  int _days = 30;

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
      _selected.clear();
      for (int i = 0; i < _results.length; i++) {
        if (_results[i].parsed.confidence >= 0.8 && !dupes.containsKey(i)) {
          _selected.add(i);
        }
      }
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
      _selected.clear();
      _scanDone = false;
    });

    final banksCtrl = Provider.of<BanksController>(context, listen: false);
    final accountsCtrl =
        Provider.of<AccountsController>(context, listen: false);

    final results = await _service.scanMessages(
      enabledBanks: banksCtrl.enabledBanks,
      accounts: accountsCtrl.accounts,
      days: _days,
      onProgress: (pct, status) {
        if (mounted) {
          setState(() {
            _scanProgress = pct;
            _scanStatus = status;
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
  }

  void _toggleSelect(int i) => setState(
      () => _selected.contains(i) ? _selected.remove(i) : _selected.add(i));

  void _selectAll() => setState(
      () => _selected.addAll(List.generate(_results.length, (i) => i)));

  void _deselectAll() => setState(() => _selected.clear());

  void _importSelected() {
    if (_selected.isEmpty) return;
    final toImport = _selected.map((i) => _results[i]).toList()
      ..sort((a, b) => a.parsed.date.compareTo(b.parsed.date));
    _openNextWizard(toImport, 0);
  }

  void _openNextWizard(List<SmsParseResult> list, int index) {
    if (index >= list.length) {
      toast.showSuccess(
        '${list.length} transaction${list.length == 1 ? '' : 's'} imported',
      );
      if (mounted) Navigator.of(context).pop();
      return;
    }
    Navigator.of(context)
        .push(
      FadeScalePageRoute(
        page: TransactionWizard(prefillFromSms: list[index]),
      ),
    )
        .then((_) {
      if (mounted) _openNextWizard(list, index + 1);
    });
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
        border: Border(
          bottom: BorderSide(
            color:
                (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
          ),
        ),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(),
          child:
              Icon(CupertinoIcons.xmark, size: 20, color: AppStyles.accentBlue),
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
        trailing: _scanDone && _results.isNotEmpty
            ? CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _selected.length == _results.length
                    ? _deselectAll
                    : _selectAll,
                child: Text(
                  _selected.length == _results.length ? 'None' : 'All',
                  style: TextStyle(
                    color: AppStyles.accentBlue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            : null,
      ),
      child: SafeArea(
        child: _isScanning
            ? _buildScanningState()
            : !_scanDone
                ? _buildInitialState()
                : _results.isEmpty
                    ? _buildNoResultsState()
                    : _buildResultsList(),
      ),
    );
  }

  // ── Initial state ────────────────────────────────────────────────────────────

  Widget _buildInitialState() {
    final isDark = AppStyles.isDarkMode(context);
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(Spacing.lg),
            child: Column(
              children: [
                SizedBox(height: Spacing.xl),
                _buildIllustration(),
                SizedBox(height: Spacing.xl),
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
                SizedBox(height: Spacing.sm),
                Text(
                  'VittaraFinOS reads your SMS inbox to auto-detect bank\ntransactions. Nothing leaves your device.',
                  style: TextStyle(
                    fontSize: TypeScale.subhead,
                    color: AppStyles.getSecondaryTextColor(context),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: Spacing.xl),
                _buildDaySelector(isDark),
                SizedBox(height: Spacing.xl),
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
      child: Icon(
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
      padding: EdgeInsets.all(Spacing.md),
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
          SizedBox(height: Spacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [7, 15, 30, 60, 90].map((d) {
              final isSelected = _days == d;
              return GestureDetector(
                onTap: () => setState(() => _days = d),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppStyles.accentBlue.withValues(alpha: 0.15),
        ),
      ),
      padding: EdgeInsets.all(Spacing.md),
      child: Row(
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
      padding: EdgeInsets.fromLTRB(Spacing.lg, 0, Spacing.lg, Spacing.lg),
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
        padding: EdgeInsets.all(Spacing.xl),
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
                        AlwaysStoppedAnimation<Color>(AppStyles.accentBlue),
                  ),
                ),
                Text(
                  '$_scanProgress%',
                  style: TextStyle(
                    fontFamily: 'SpaceGrotesk',
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: AppStyles.getTextColor(context),
                  ),
                ),
              ],
            ),
            SizedBox(height: Spacing.xl),
            Text(
              _scanStatus,
              style: TextStyle(
                fontSize: TypeScale.subhead,
                color: AppStyles.getSecondaryTextColor(context),
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: Spacing.sm),
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
          padding: EdgeInsets.fromLTRB(Spacing.lg, 0, Spacing.lg, Spacing.lg),
          child: CupertinoButton(
            onPressed: () => setState(() {
              _scanDone = false;
              _results = [];
            }),
            child: Text(
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
          padding: EdgeInsets.symmetric(
              horizontal: Spacing.lg, vertical: Spacing.sm),
          child: Row(
            children: [
              Text(
                '${_results.length} found · ${_selected.length} selected',
                style: TextStyle(
                  fontSize: TypeScale.footnote,
                  color: AppStyles.getSecondaryTextColor(context),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => setState(() {
                  _scanDone = false;
                  _results = [];
                  _selected.clear();
                }),
                child: Text(
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
            padding: EdgeInsets.fromLTRB(Spacing.lg, 0, Spacing.lg, Spacing.lg),
            itemCount: _results.length,
            itemBuilder: (ctx, i) => _buildResultCard(i, isDark),
          ),
        ),

        // Import button
        _buildImportBar(isDark),
      ],
    );
  }

  Widget _buildResultCard(int i, bool isDark) {
    final r = _results[i];
    final p = r.parsed;
    final isExpense = p.type == 'expense';
    final isSelected = _selected.contains(i);
    final txColor =
        isExpense ? CupertinoColors.systemRed : CupertinoColors.systemGreen;
    final fmt =
        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
    final dateFmt = DateFormat('dd MMM · hh:mm a');
    final dupe = _duplicates[i];
    final acctNum = r.matchedAccount?.creditCardNumber;
    final acctSuffix = acctNum != null && acctNum.length >= 4
        ? acctNum.substring(acctNum.length - 4)
        : null;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppStyles.darkCard : CupertinoColors.systemBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected
              ? AppStyles.accentBlue.withValues(alpha: 0.7)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.07)
                  : Colors.black.withValues(alpha: 0.07)),
          width: isSelected ? 2 : 1,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: AppStyles.accentBlue.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                )
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row ────────────────────────────────────────────────
          GestureDetector(
            onTap: () => _toggleSelect(i),
            behavior: HitTestBehavior.opaque,
            child: Padding(
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
                                fontSize: 12,
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
                                style: TextStyle(
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
                  // Right: type badge + checkbox
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
                      // Checkbox
                      GestureDetector(
                        onTap: () => _toggleSelect(i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppStyles.accentBlue
                                : Colors.transparent,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? AppStyles.accentBlue
                                  : AppStyles.getSecondaryTextColor(context)
                                      .withValues(alpha: 0.35),
                              width: 2,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(CupertinoIcons.checkmark,
                                  size: 14, color: Colors.white)
                              : null,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
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
          GestureDetector(
            onTap: () => _toggleSelect(i),
            behavior: HitTestBehavior.opaque,
            child: Padding(
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
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        CupertinoIcons.eye,
                        size: 14,
                        color: AppStyles.accentBlue,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'View message',
                        style: TextStyle(
                          fontSize: 12,
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
                                ? CupertinoColors.systemRed
                                : CupertinoColors.systemGreen,
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
                    _modalRow('Balance after', fmt.format(p.balance!)),
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
                                fontSize: 12,
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
                      fontSize: 12,
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
                      borderRadius: BorderRadius.circular(12),
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

  Widget _buildDuplicateBanner(_DuplicateMatch dupe, bool isDark) {
    final conf = dupe.confidence;
    final color = conf >= 0.8
        ? CupertinoColors.systemOrange
        : CupertinoColors.systemYellow;
    final fmt =
        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
    final dateFmt = DateFormat('dd MMM yyyy');
    return Container(
      padding:
          EdgeInsets.symmetric(horizontal: Spacing.sm, vertical: Spacing.xs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(CupertinoIcons.exclamationmark_triangle_fill,
              size: 13, color: color),
          SizedBox(width: Spacing.xs),
          Expanded(
            child: Text(
              'Possible duplicate · ${fmt.format(dupe.transaction.amount)}'
              ' on ${dateFmt.format(dupe.transaction.dateTime)}'
              ' · ${(conf * 100).toInt()}% match',
              style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImportBar(bool isDark) {
    return Container(
      padding:
          EdgeInsets.fromLTRB(Spacing.lg, Spacing.sm, Spacing.lg, Spacing.lg),
      decoration: BoxDecoration(
        color: isDark ? AppStyles.darkCard : CupertinoColors.systemBackground,
        border: Border(
          top: BorderSide(
            color:
                (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
          ),
        ),
      ),
      child: BouncyButton(
        onPressed: _selected.isEmpty ? () {} : _importSelected,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          height: 54,
          decoration: BoxDecoration(
            gradient: _selected.isEmpty
                ? null
                : const LinearGradient(
                    colors: [AppStyles.accentBlue, AppStyles.accentTeal]),
            color: _selected.isEmpty
                ? (isDark
                    ? const Color(0xFF2C2C2E)
                    : CupertinoColors.systemGrey5)
                : null,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: Text(
              _selected.isEmpty
                  ? 'Select transactions to import'
                  : 'Import ${_selected.length} Transaction${_selected.length == 1 ? '' : 's'}',
              style: TextStyle(
                color: _selected.isEmpty
                    ? AppStyles.getSecondaryTextColor(context)
                    : Colors.white,
                fontSize: TypeScale.body,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _confidenceColor(double c) {
    if (c >= 0.85) return CupertinoColors.systemGreen;
    if (c >= 0.65) return CupertinoColors.systemOrange;
    return CupertinoColors.systemRed;
  }
}
