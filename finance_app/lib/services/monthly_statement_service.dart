import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:vittara_fin_os/logic/account_model.dart';
import 'package:vittara_fin_os/logic/investment_model.dart';
import 'package:vittara_fin_os/logic/lending_borrowing_model.dart';
import 'package:vittara_fin_os/logic/transaction_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Internal helpers
// ─────────────────────────────────────────────────────────────────────────────

class _AcctRow {
  final String name;
  final double opening;
  final double debits;
  final double credits;
  _AcctRow({required this.name, required this.opening, required this.debits, required this.credits});
  double get closing => opening - debits + credits;
  double get net => credits - debits;
}

class _TxRow {
  final DateTime date;
  final String description;
  final String paymentApp;
  final double debit;
  final double credit;
  _TxRow({required this.date, required this.description, this.paymentApp = '', this.debit = 0, this.credit = 0});
}

// ─────────────────────────────────────────────────────────────────────────────
/// Generates a comprehensive monthly financial statement PDF.
/// Includes: cover, executive summary, per-account statements (with running
/// balance), category breakdown, payment app breakdown, investments by type,
/// dividends, lending & borrowing, merchant analysis, and full transaction log.
// ─────────────────────────────────────────────────────────────────────────────
class MonthlyStatementService {
  static const _appName = 'VittaraFinOS';
  static const _tagline = 'Track Wealth, Master Life';

  // ── Brand palette ──────────────────────────────────────────────────────────
  static const _brandTeal   = PdfColor(0.000, 0.722, 0.565);
  static const _brandViolet = PdfColor(0.482, 0.361, 0.937);
  static const _navy        = PdfColor(0.035, 0.098, 0.157);
  static const _navyMid     = PdfColor(0.067, 0.165, 0.255);
  static const _green       = PdfColor(0.000, 0.784, 0.463);
  static const _red         = PdfColor(0.878, 0.188, 0.314);
  static const _indigo      = PdfColor(0.482, 0.361, 0.937);
  static const _orange      = PdfColor(1.000, 0.584, 0.000);
  static const _purple      = PdfColor(0.686, 0.322, 0.871);
  static const _blue        = PdfColor(0.000, 0.478, 1.000);
  static const _amber       = PdfColor(1.000, 0.722, 0.000);
  static const _grey        = PdfColor(0.550, 0.550, 0.600);
  static const _greyLight   = PdfColor(0.900, 0.910, 0.920);
  static const _greyDk      = PdfColor(0.350, 0.400, 0.450);
  static const _row0        = PdfColors.white;
  static const _row1        = PdfColor(0.965, 0.972, 0.982);

  static const List<PdfColor> _pal = [
    PdfColor(0.000, 0.722, 0.565), PdfColor(0.482, 0.361, 0.937),
    PdfColor(0.000, 0.784, 0.463), PdfColor(1.000, 0.584, 0.000),
    PdfColor(0.878, 0.188, 0.314), PdfColor(0.000, 0.478, 1.000),
    PdfColor(0.686, 0.322, 0.871), PdfColor(0.188, 0.714, 0.753),
  ];
  static const List<PdfColor> _palTint = [
    PdfColor(0.860, 0.975, 0.960), PdfColor(0.935, 0.910, 0.990),
    PdfColor(0.870, 0.980, 0.910), PdfColor(1.000, 0.950, 0.860),
    PdfColor(0.985, 0.880, 0.890), PdfColor(0.870, 0.935, 1.000),
    PdfColor(0.960, 0.900, 0.985), PdfColor(0.870, 0.965, 0.975),
  ];

  static const _mo = ['January','February','March','April','May','June',
                       'July','August','September','October','November','December'];
  static const _mos = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];

  // ═══════════════════════════════════════════════════════════════════════════
  // PUBLIC API
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<File> build({
    required int year,
    required int month,
    required List<Transaction> allTransactions,
    required List<Account> accounts,
    required List<Investment> investments,
    required List<LendingBorrowing> lendingRecords,
    Uint8List? appIconBytes,
  }) async {
    final monthStart  = DateTime(year, month, 1);
    final monthEnd    = DateTime(year, month + 1, 1).subtract(const Duration(milliseconds: 1));
    final monthLabel  = '${_mo[month - 1]} $year';
    final monthTxns   = allTransactions
        .where((t) => !t.dateTime.isBefore(monthStart) && !t.dateTime.isAfter(monthEnd))
        .toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

    final visibleAccounts = accounts.where((a) => !a.isHidden).toList();
    final acctRows = _buildAcctRows(visibleAccounts, allTransactions, monthTxns, monthStart);
    final stats    = _computeStats(monthTxns);

    final doc = pw.Document();

    final ib = appIconBytes; // capture for closures

    // ── 1. Cover ──
    doc.addPage(_coverPage(monthLabel, monthTxns.length, stats, visibleAccounts, ib));

    // ── 2. Executive Summary ──
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      header: (ctx) => _hdr('Executive Summary', monthLabel, ctx, ib),
      footer: (ctx) => _ftr(ctx),
      build: (_) => [
        pw.SizedBox(height: 10),
        _summaryStatRow(stats),
        pw.SizedBox(height: 14),
        _sectionBanner('Account Balance Overview', 'Opening → Closing balances for ${_mo[month - 1]}', _brandTeal, _blue, 'A'),
        pw.SizedBox(height: 6),
        _acctBalanceTable(acctRows),
        pw.SizedBox(height: 14),
        _sectionBanner('Month at a Glance', 'Key patterns and highlights', _brandViolet, _indigo, 'G'),
        pw.SizedBox(height: 6),
        _glanceSection(stats, monthTxns, acctRows),
      ],
    ));

    // ── 3. Per-Account Statements ──
    for (int ai = 0; ai < visibleAccounts.length; ai++) {
      final account = visibleAccounts[ai];
      final row     = acctRows.firstWhere((r) => r.name == account.name,
          orElse: () => _AcctRow(name: account.name, opening: account.balance, debits: 0, credits: 0));
      final txRows  = _txRowsForAccount(account, monthTxns);
      if (txRows.isEmpty) continue;

      doc.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        header: (ctx) => _hdr('Account Statement', monthLabel, ctx, ib),
        footer: (ctx) => _ftr(ctx),
        build: (_) => [
          pw.SizedBox(height: 10),
          _acctSectionHeader(account, row, ai),
          pw.SizedBox(height: 6),
          _acctTxTable(txRows, row.opening),
          pw.SizedBox(height: 8),
          _acctClosingSummary(row),
        ],
      ));
    }

    // ── 4. Category Breakdown ──
    final catGroups = _groupByCategory(monthTxns);
    if (catGroups.isNotEmpty) {
      doc.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        header: (ctx) => _hdr('Category Breakdown', monthLabel, ctx, ib),
        footer: (ctx) => _ftr(ctx),
        build: (_) => [
          pw.SizedBox(height: 10),
          _sectionBanner('Spending by Category', 'All transactions grouped by category', _brandViolet, _indigo, 'C'),
          pw.SizedBox(height: 6),
          _catSummaryBars(catGroups, stats['expense']!),
          pw.SizedBox(height: 14),
          ...catGroups.entries.expand((entry) => [
            _subSectionHeader(entry.key.isEmpty ? 'Uncategorised' : entry.key, entry.value.length, _pal[catGroups.keys.toList().indexOf(entry.key) % _pal.length]),
            pw.SizedBox(height: 4),
            _miniTxTable(entry.value),
            pw.SizedBox(height: 10),
          ]),
        ],
      ));
    }

    // ── 5. Payment App Breakdown ──
    final appGroups = _groupByPaymentApp(monthTxns);
    if (appGroups.isNotEmpty) {
      doc.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        header: (ctx) => _hdr('Payment Apps', monthLabel, ctx, ib),
        footer: (ctx) => _ftr(ctx),
        build: (_) => [
          pw.SizedBox(height: 10),
          _sectionBanner('Payment App Breakdown', 'Transactions via each payment app / UPI method', _orange, _amber, 'P'),
          pw.SizedBox(height: 6),
          _appSummaryBars(appGroups),
          pw.SizedBox(height: 14),
          ...appGroups.entries.expand((entry) => [
            _subSectionHeader(entry.key, entry.value.length, _pal[appGroups.keys.toList().indexOf(entry.key) % _pal.length]),
            pw.SizedBox(height: 4),
            _miniTxTable(entry.value),
            pw.SizedBox(height: 10),
          ]),
        ],
      ));
    }

    // ── 6. Investments ──
    final invTxns = monthTxns.where((t) => t.type == TransactionType.investment).toList();
    if (investments.isNotEmpty || invTxns.isNotEmpty) {
      final invByType = _groupInvestmentsByType(investments);
      final invTxByType = _groupInvTxsByType(invTxns);
      doc.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        header: (ctx) => _hdr('Investments', monthLabel, ctx, ib),
        footer: (ctx) => _ftr(ctx),
        build: (_) => [
          pw.SizedBox(height: 10),
          _sectionBanner('Investment Portfolio', 'Holdings and transactions by investment type', _indigo, _brandViolet, 'I'),
          pw.SizedBox(height: 6),
          _investmentSummaryTable(invByType),
          pw.SizedBox(height: 14),
          if (invTxns.isNotEmpty) ...[
            _sectionBanner('Investment Transactions This Month', '${invTxns.length} investment events recorded', _brandViolet, _purple, 'T'),
            pw.SizedBox(height: 6),
            ...invTxByType.entries.expand((entry) => [
              _subSectionHeader(entry.key, entry.value.length, _indigo),
              pw.SizedBox(height: 4),
              _miniTxTable(entry.value),
              pw.SizedBox(height: 10),
            ]),
          ],
        ],
      ));
    }

    // ── 7. Dividends ──
    final divTxns = monthTxns.where((t) {
      final ev = (t.metadata ?? {})['investmentEventType'] as String?;
      return ev == 'dividend';
    }).toList();
    if (divTxns.isNotEmpty) {
      doc.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        header: (ctx) => _hdr('Dividends', monthLabel, ctx, ib),
        footer: (ctx) => _ftr(ctx),
        build: (_) => [
          pw.SizedBox(height: 10),
          _sectionBanner('Dividend Income', '${divTxns.length} dividend events — total Rs ${_fmtAmt(divTxns.fold(0.0, (s, t) => s + t.amount))}', _amber, _orange, 'D'),
          pw.SizedBox(height: 6),
          _dividendTable(divTxns),
        ],
      ));
    }

    // ── 8. Lending & Borrowing ──
    final lentTxns   = monthTxns.where((t) => t.type == TransactionType.lending).toList();
    final borrowTxns = monthTxns.where((t) => t.type == TransactionType.borrowing).toList();
    final activeLent     = lendingRecords.where((r) => r.type == LendingType.lent).toList();
    final activeBorrowed = lendingRecords.where((r) => r.type == LendingType.borrowed).toList();
    if (lentTxns.isNotEmpty || borrowTxns.isNotEmpty || activeLent.isNotEmpty || activeBorrowed.isNotEmpty) {
      doc.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        header: (ctx) => _hdr('Lending & Borrowing', monthLabel, ctx, ib),
        footer: (ctx) => _ftr(ctx),
        build: (_) => [
          pw.SizedBox(height: 10),
          _sectionBanner('Lending & Borrowing', 'Money lent to others and borrowed from others', _orange, _red, 'L'),
          pw.SizedBox(height: 6),
          if (activeLent.isNotEmpty) ...[
            _subSectionHeader('Money Lent (You lent to others)', activeLent.length, _orange),
            pw.SizedBox(height: 4),
            _lbTable(activeLent, LendingType.lent),
            pw.SizedBox(height: 8),
          ],
          if (lentTxns.isNotEmpty) ...[
            _subSectionHeader('Lending Transactions This Month', lentTxns.length, _orange),
            pw.SizedBox(height: 4),
            _miniTxTable(lentTxns),
            pw.SizedBox(height: 10),
          ],
          if (activeBorrowed.isNotEmpty) ...[
            _subSectionHeader('Money Borrowed (Others lent to you)', activeBorrowed.length, _red),
            pw.SizedBox(height: 4),
            _lbTable(activeBorrowed, LendingType.borrowed),
            pw.SizedBox(height: 8),
          ],
          if (borrowTxns.isNotEmpty) ...[
            _subSectionHeader('Borrowing Transactions This Month', borrowTxns.length, _red),
            pw.SizedBox(height: 4),
            _miniTxTable(borrowTxns),
          ],
        ],
      ));
    }

    // ── 9. Merchant Analysis ──
    final merchantGroups = _groupByMerchant(monthTxns);
    if (merchantGroups.isNotEmpty) {
      doc.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        header: (ctx) => _hdr('Merchant Analysis', monthLabel, ctx, ib),
        footer: (ctx) => _ftr(ctx),
        build: (_) => [
          pw.SizedBox(height: 10),
          _sectionBanner('Merchant-wise Breakdown', 'All spend grouped by merchant / vendor', _blue, _brandTeal, 'M'),
          pw.SizedBox(height: 6),
          _merchantSummaryBars(merchantGroups),
          pw.SizedBox(height: 14),
          ...merchantGroups.entries.expand((entry) => [
            _subSectionHeader(entry.key.isEmpty ? 'Unknown Merchant' : entry.key, entry.value.length, _pal[merchantGroups.keys.toList().indexOf(entry.key) % _pal.length]),
            pw.SizedBox(height: 4),
            _miniTxTable(entry.value),
            pw.SizedBox(height: 10),
          ]),
        ],
      ));
    }

    // ── 10. Full Transaction Log ──
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      header: (ctx) => _hdr('Full Transaction Log', monthLabel, ctx, ib),
      footer: (ctx) => _ftr(ctx),
      build: (_) => [
        pw.SizedBox(height: 10),
        _sectionBanner('Complete Transaction Log', '${monthTxns.length} records for ${_mo[month - 1]} $year — chronological', _navy, _navyMid, 'F'),
        pw.SizedBox(height: 6),
        _fullLogTable(monthTxns),
      ],
    ));

    final bytes = await doc.save();
    final dir   = await _reportDir();
    final file  = File('${dir.path}/monthly_${year}_${month.toString().padLeft(2, '0')}_${_timestamp()}.pdf');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 1 — Cover page (pw.Page, full design)
  // ═══════════════════════════════════════════════════════════════════════════

  static pw.Page _coverPage(String monthLabel, int txnCount, Map<String, double> stats, List<Account> accounts, Uint8List? ib) {
    final net = stats['net']!;
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      build: (ctx) => pw.Stack(children: [
        // Full-page gradient background
        pw.Container(
          width: double.infinity, height: double.infinity,
          decoration: pw.BoxDecoration(
            gradient: pw.LinearGradient(
              colors: [_navy, _navyMid, const PdfColor(0.08, 0.20, 0.35)],
              begin: pw.Alignment.topLeft,
              end: pw.Alignment.bottomRight,
            ),
          ),
        ),
        // Decorative circles
        pw.Positioned(top: -60, right: -60,
          child: pw.Container(
            width: 220, height: 220,
            decoration: pw.BoxDecoration(
              color: const PdfColor(0.00, 0.72, 0.57, 0.08),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(110)),
            ),
          )),
        pw.Positioned(bottom: -80, left: -80,
          child: pw.Container(
            width: 280, height: 280,
            decoration: pw.BoxDecoration(
              color: const PdfColor(0.48, 0.36, 0.94, 0.06),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(140)),
            ),
          )),
        // Content
        pw.Padding(
          padding: const pw.EdgeInsets.all(48),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Logo + brand
              pw.Row(children: [
                _logoMark(60, ib),
                pw.SizedBox(width: 16),
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text(_appName, style: pw.TextStyle(font: pw.Font.helveticaBold(), fontSize: 22, color: PdfColors.white, letterSpacing: 2.0)),
                  pw.SizedBox(height: 4),
                  pw.Text(_tagline, style: pw.TextStyle(font: pw.Font.helveticaOblique(), fontSize: 10, color: const PdfColor(0.55, 0.70, 0.82))),
                ]),
              ]),
              pw.SizedBox(height: 60),
              // Document type label
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: pw.BoxDecoration(
                  gradient: pw.LinearGradient(colors: [_brandTeal, _brandViolet], begin: pw.Alignment.centerLeft, end: pw.Alignment.centerRight),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                child: pw.Text('MONTHLY FINANCIAL STATEMENT',
                  style: pw.TextStyle(font: pw.Font.helveticaBold(), fontSize: 9, color: PdfColors.white, letterSpacing: 1.5)),
              ),
              pw.SizedBox(height: 16),
              // Month title
              pw.Text(monthLabel,
                style: pw.TextStyle(font: pw.Font.helveticaBold(), fontSize: 48, color: PdfColors.white, letterSpacing: 0.5)),
              pw.SizedBox(height: 8),
              pw.Text('A comprehensive view of all your financial activity',
                style: pw.TextStyle(font: pw.Font.helvetica(), fontSize: 12, color: const PdfColor(0.60, 0.72, 0.84))),
              pw.SizedBox(height: 48),
              // Quick stats row
              pw.Row(children: [
                _coverStat('INCOME',    '+Rs ${_fmtAmt(stats['income']!)}',    _green),
                pw.SizedBox(width: 12),
                _coverStat('EXPENSES',  '-Rs ${_fmtAmt(stats['expense']!)}',   _red),
                pw.SizedBox(width: 12),
                _coverStat('NET',       '${net >= 0 ? '+' : '-'}Rs ${_fmtAmt(net.abs())}', net >= 0 ? _green : _red),
                pw.SizedBox(width: 12),
                _coverStat('INVESTED',  'Rs ${_fmtAmt(stats['investment']!)}', _indigo),
                pw.SizedBox(width: 12),
                _coverStat('RECORDS',   '$txnCount',                           _brandTeal),
              ]),
              pw.SizedBox(height: 36),
              // Accounts listed
              pw.Wrap(
                spacing: 8, runSpacing: 8,
                children: accounts.map((a) => pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: pw.BoxDecoration(
                    color: const PdfColor(0.10, 0.22, 0.38),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
                    border: pw.Border.all(color: const PdfColor(0.22, 0.38, 0.55), width: 0.8),
                  ),
                  child: pw.Text(a.name,
                    style: pw.TextStyle(font: pw.Font.helvetica(), fontSize: 8, color: const PdfColor(0.70, 0.82, 0.92))),
                )).toList(),
              ),
              pw.Spacer(),
              // Footer line
              pw.Container(height: 1, color: const PdfColor(0.15, 0.30, 0.45)),
              pw.SizedBox(height: 10),
              pw.Row(children: [
                pw.Text('Generated ${_fmtDate(DateTime.now())}',
                  style: pw.TextStyle(font: pw.Font.helvetica(), fontSize: 8, color: const PdfColor(0.45, 0.58, 0.70))),
                pw.Spacer(),
                pw.Text('Confidential  •  Personal Use Only',
                  style: pw.TextStyle(font: pw.Font.helvetica(), fontSize: 8, color: const PdfColor(0.45, 0.58, 0.70))),
              ]),
            ],
          ),
        ),
      ]),
    );
  }

  static pw.Widget _coverStat(String label, String value, PdfColor color) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: const PdfColor(0.08, 0.18, 0.32),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
          border: pw.Border(top: pw.BorderSide(color: color, width: 3)),
        ),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(label, style: pw.TextStyle(font: pw.Font.helvetica(), fontSize: 6.5, color: const PdfColor(0.55, 0.68, 0.80), letterSpacing: 0.5)),
          pw.SizedBox(height: 5),
          pw.Text(value, style: pw.TextStyle(font: pw.Font.helveticaBold(), fontSize: 11, color: color)),
        ]),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 2 — Executive Summary widgets
  // ═══════════════════════════════════════════════════════════════════════════

  static pw.Widget _summaryStatRow(Map<String, double> stats) {
    final net = stats['net']!;
    return pw.Container(
      padding: const pw.EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: pw.BoxDecoration(
        gradient: pw.LinearGradient(
          colors: [const PdfColor(0.94, 0.95, 0.97), const PdfColor(0.97, 0.97, 0.99)],
          begin: pw.Alignment.topLeft, end: pw.Alignment.bottomRight,
        ),
      ),
      child: pw.Row(children: [
        _sCard('INCOME',    '+Rs ${_fmtAmt(stats['income']!)}',    _green,      const PdfColor(0.87, 0.98, 0.91), '↑'),
        pw.SizedBox(width: 6),
        _sCard('EXPENSES',  '-Rs ${_fmtAmt(stats['expense']!)}',   _red,        const PdfColor(0.99, 0.88, 0.89), '↓'),
        pw.SizedBox(width: 6),
        _sCard('NET FLOW',  '${net >= 0 ? '+' : '-'}Rs ${_fmtAmt(net.abs())}', net >= 0 ? _green : _red, net >= 0 ? const PdfColor(0.87, 0.98, 0.91) : const PdfColor(0.99, 0.88, 0.89), '='),
        pw.SizedBox(width: 6),
        _sCard('INVESTED',  'Rs ${_fmtAmt(stats['investment']!)}', _indigo,     const PdfColor(0.93, 0.91, 0.99), '★'),
        pw.SizedBox(width: 6),
        _sCard('TRANSFERS', 'Rs ${_fmtAmt(stats['transfer']!)}',   _brandTeal,  const PdfColor(0.86, 0.97, 0.96), '⇄'),
        pw.SizedBox(width: 6),
        _sCard('RECORDS',   '${stats['count']!.toInt()}',          _navy,       const PdfColor(0.90, 0.92, 0.95), '#'),
      ]),
    );
  }

  static pw.Widget _sCard(String l, String v, PdfColor accent, PdfColor tint, String sym) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.fromLTRB(8, 8, 8, 8),
        decoration: pw.BoxDecoration(
          gradient: pw.LinearGradient(colors: [tint, PdfColors.white], begin: pw.Alignment.topLeft, end: pw.Alignment.bottomRight),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(7)),
          border: pw.Border(top: pw.BorderSide(color: accent, width: 3)),
        ),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Row(children: [
            pw.Container(
              width: 13, height: 13,
              decoration: pw.BoxDecoration(color: accent, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(7))),
              alignment: pw.Alignment.center,
              child: pw.Text(sym, style: pw.TextStyle(font: pw.Font.helveticaBold(), fontSize: 7, color: PdfColors.white)),
            ),
            pw.SizedBox(width: 4),
            pw.Text(l, style: pw.TextStyle(font: pw.Font.helveticaBold(), fontSize: 5.5, color: _grey, letterSpacing: 0.4)),
          ]),
          pw.SizedBox(height: 5),
          pw.Text(v, style: pw.TextStyle(font: pw.Font.helveticaBold(), fontSize: 9.5, color: accent)),
        ]),
      ),
    );
  }

  static pw.Widget _acctBalanceTable(List<_AcctRow> rows) {
    return pw.Column(children: [
      pw.Container(
        padding: const pw.EdgeInsets.fromLTRB(20, 8, 20, 8),
        decoration: pw.BoxDecoration(
          gradient: pw.LinearGradient(colors: [_brandTeal, _blue], begin: pw.Alignment.centerLeft, end: pw.Alignment.centerRight),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        ),
        child: pw.Row(children: [
          pw.SizedBox(width: 130, child: _wt('ACCOUNT')),
          pw.SizedBox(width: 72,  child: _wt('OPENING',  right: true)),
          pw.SizedBox(width: 72,  child: _wt('DEBITS',   right: true)),
          pw.SizedBox(width: 72,  child: _wt('CREDITS',  right: true)),
          pw.SizedBox(width: 72,  child: _wt('CLOSING',  right: true)),
          pw.SizedBox(width: 60,  child: _wt('NET',      right: true)),
        ]),
      ),
      ...rows.asMap().entries.map((e) {
        final i = e.key; final r = e.value;
        final netColor = r.net >= 0 ? _green : _red;
        return pw.Container(
          color: i.isEven ? const PdfColor(0.86, 0.97, 0.96) : PdfColors.white,
          padding: const pw.EdgeInsets.fromLTRB(20, 7, 20, 7),
          child: pw.Row(children: [
            pw.SizedBox(width: 130, child: pw.Text(r.name.length > 20 ? '${r.name.substring(0, 20)}…' : r.name,
                style: pw.TextStyle(font: pw.Font.helveticaBold(), fontSize: 8.5, color: _navy))),
            pw.SizedBox(width: 72,  child: _amtCell(r.opening,  _grey)),
            pw.SizedBox(width: 72,  child: _amtCell(r.debits,   _red)),
            pw.SizedBox(width: 72,  child: _amtCell(r.credits,  _green)),
            pw.SizedBox(width: 72,  child: _amtCell(r.closing,  _navy, bold: true)),
            pw.SizedBox(width: 60,  child: _amtCell(r.net, netColor, bold: true, sign: true)),
          ]),
        );
      }),
      // Totals
      pw.Container(
        color: const PdfColor(0.11, 0.23, 0.32),
        padding: const pw.EdgeInsets.fromLTRB(20, 7, 20, 7),
        child: pw.Row(children: [
          pw.SizedBox(width: 130, child: pw.Text('TOTAL', style: pw.TextStyle(font: pw.Font.helveticaBold(), fontSize: 8.5, color: PdfColors.white))),
          pw.SizedBox(width: 72,  child: _amtCell(rows.fold(0.0, (s, r) => s + r.opening),  PdfColors.white, bold: true)),
          pw.SizedBox(width: 72,  child: _amtCell(rows.fold(0.0, (s, r) => s + r.debits),   const PdfColor(1.0, 0.65, 0.68), bold: true)),
          pw.SizedBox(width: 72,  child: _amtCell(rows.fold(0.0, (s, r) => s + r.credits),  const PdfColor(0.65, 1.0, 0.78), bold: true)),
          pw.SizedBox(width: 72,  child: _amtCell(rows.fold(0.0, (s, r) => s + r.closing),  PdfColors.white, bold: true)),
          pw.SizedBox(width: 60,  child: _amtCell(rows.fold(0.0, (s, r) => s + r.net), const PdfColor(0.60, 0.90, 0.78), bold: true, sign: true)),
        ]),
      ),
    ]);
  }

  static pw.Widget _glanceSection(Map<String, double> stats, List<Transaction> txns, List<_AcctRow> rows) {
    final income  = stats['income']!;
    final expense = stats['expense']!;
    final points  = <String>[];
    if (income > 0) points.add('Savings rate: ${((income - expense) / income * 100).clamp(0, 100).toStringAsFixed(1)}% — Rs ${_fmtAmt((income - expense).clamp(0, double.infinity))} of Rs ${_fmtAmt(income)} income saved.');
    final expTxns = txns.where((t) => t.type == TransactionType.expense).toList();
    if (expTxns.isNotEmpty) {
      final avg = expTxns.fold(0.0, (s, t) => s + t.amount) / expTxns.length;
      points.add('${expTxns.length} expense transactions averaging Rs ${_fmtAmt(avg)} each.');
    }
    final invTxns = txns.where((t) => t.type == TransactionType.investment).toList();
    if (invTxns.isNotEmpty) points.add('Rs ${_fmtAmt(stats['investment']!)} invested across ${invTxns.length} investment events.');
    if (rows.isNotEmpty) {
      final best = rows.reduce((a, b) => a.net > b.net ? a : b);
      points.add('Best performing account: ${best.name} with a net of ${best.net >= 0 ? '+' : '-'}Rs ${_fmtAmt(best.net.abs())}.');
    }
    final divs = txns.where((t) => (t.metadata ?? {})['investmentEventType'] == 'dividend').toList();
    if (divs.isNotEmpty) points.add('${divs.length} dividend receipt${divs.length == 1 ? '' : 's'} totalling Rs ${_fmtAmt(divs.fold(0.0, (s, t) => s + t.amount))}.');

    return pw.Column(
      children: points.asMap().entries.map((e) {
        final color = _pal[e.key % _pal.length];
        final tint  = _palTint[e.key % _palTint.length];
        return pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 5),
          padding: const pw.EdgeInsets.fromLTRB(14, 8, 14, 8),
          decoration: pw.BoxDecoration(
            color: tint,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
            border: pw.Border(left: pw.BorderSide(color: color, width: 4)),
          ),
          child: pw.Row(children: [
            pw.Container(
              width: 6, height: 6,
              decoration: pw.BoxDecoration(color: color, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3))),
            ),
            pw.SizedBox(width: 8),
            pw.Expanded(child: pw.Text(e.value, style: pw.TextStyle(font: pw.Font.helvetica(), fontSize: 8.5, color: const PdfColor(0.14, 0.18, 0.26)))),
          ]),
        );
      }).toList(),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 3 — Per-Account Statement
  // ═══════════════════════════════════════════════════════════════════════════

  static pw.Widget _acctSectionHeader(Account account, _AcctRow row, int idx) {
    final color = _pal[idx % _pal.length];
    final tint  = _palTint[idx % _palTint.length];
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: tint,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        border: pw.Border.all(color: color, width: 1.5),
      ),
      child: pw.Row(children: [
        pw.Container(
          width: 48, height: 48,
          decoration: pw.BoxDecoration(
            gradient: pw.LinearGradient(colors: [color, _brandViolet], begin: pw.Alignment.topLeft, end: pw.Alignment.bottomRight),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
          ),
          alignment: pw.Alignment.center,
          child: pw.Text(account.name.substring(0, 1).toUpperCase(),
            style: pw.TextStyle(font: pw.Font.helveticaBold(), fontSize: 20, color: PdfColors.white)),
        ),
        pw.SizedBox(width: 14),
        pw.Expanded(
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(account.name, style: pw.TextStyle(font: pw.Font.helveticaBold(), fontSize: 13, color: _navy)),
            pw.SizedBox(height: 3),
            pw.Text('${account.bankName}  •  ${_acctTypeLabel(account.type)}',
              style: pw.TextStyle(font: pw.Font.helvetica(), fontSize: 8, color: _grey)),
          ]),
        ),
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          pw.Text('OPENING',  style: pw.TextStyle(font: pw.Font.helvetica(),     fontSize: 7, color: _grey, letterSpacing: 0.5)),
          pw.Text('Rs ${_fmtAmt(row.opening)}', style: pw.TextStyle(font: pw.Font.helveticaBold(), fontSize: 12, color: _navy)),
        ]),
        pw.SizedBox(width: 24),
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          pw.Text('CLOSING',  style: pw.TextStyle(font: pw.Font.helvetica(),     fontSize: 7, color: _grey, letterSpacing: 0.5)),
          pw.Text('Rs ${_fmtAmt(row.closing)}', style: pw.TextStyle(font: pw.Font.helveticaBold(), fontSize: 12, color: row.net >= 0 ? _green : _red)),
        ]),
      ]),
    );
  }

  static pw.Widget _acctTxTable(List<_TxRow> rows, double opening) {
    double running = opening;
    return pw.Column(children: [
      // Header
      pw.Container(
        padding: const pw.EdgeInsets.fromLTRB(16, 7, 16, 7),
        decoration: pw.BoxDecoration(
          gradient: pw.LinearGradient(colors: [_navy, _navyMid], begin: pw.Alignment.centerLeft, end: pw.Alignment.centerRight),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        ),
        child: pw.Row(children: [
          pw.SizedBox(width: 50,  child: _wt('DATE')),
          pw.Expanded(            child: _wt('DESCRIPTION')),
          pw.SizedBox(width: 64,  child: _wt('APP / METHOD')),
          pw.SizedBox(width: 68,  child: _wt('DEBIT',    right: true)),
          pw.SizedBox(width: 68,  child: _wt('CREDIT',   right: true)),
          pw.SizedBox(width: 76,  child: _wt('BALANCE',  right: true)),
        ]),
      ),
      ...rows.asMap().entries.map((e) {
        final i = e.key; final r = e.value;
        if (r.debit > 0)  running -= r.debit;
        if (r.credit > 0) running += r.credit;
        return pw.Container(
          color: i.isEven ? _row1 : _row0,
          padding: const pw.EdgeInsets.fromLTRB(16, 5, 16, 5),
          child: pw.Row(children: [
            pw.SizedBox(width: 50,  child: pw.Text(_fmtDateShort(r.date), style: pw.TextStyle(font: pw.Font.helvetica(), fontSize: 7, color: _grey))),
            pw.Expanded(child: pw.Text(
              r.description.length > 42 ? '${r.description.substring(0, 42)}…' : r.description,
              style: pw.TextStyle(font: pw.Font.helvetica(), fontSize: 8, color: _navy))),
            pw.SizedBox(width: 64,  child: pw.Text(r.paymentApp, style: pw.TextStyle(font: pw.Font.helvetica(), fontSize: 7, color: _grey), textAlign: pw.TextAlign.right)),
            pw.SizedBox(width: 68,  child: r.debit > 0
                ? pw.Text('-Rs ${_fmtAmt(r.debit)}',  textAlign: pw.TextAlign.right, style: pw.TextStyle(font: pw.Font.helveticaBold(), fontSize: 7.5, color: _red))
                : pw.Text('', textAlign: pw.TextAlign.right)),
            pw.SizedBox(width: 68,  child: r.credit > 0
                ? pw.Text('+Rs ${_fmtAmt(r.credit)}', textAlign: pw.TextAlign.right, style: pw.TextStyle(font: pw.Font.helveticaBold(), fontSize: 7.5, color: _green))
                : pw.Text('', textAlign: pw.TextAlign.right)),
            pw.SizedBox(width: 76,  child: pw.Text('Rs ${_fmtAmt(running)}', textAlign: pw.TextAlign.right,
                style: pw.TextStyle(font: pw.Font.helveticaBold(), fontSize: 7.5, color: running >= 0 ? _navy : _red))),
          ]),
        );
      }),
    ]);
  }

  static pw.Widget _acctClosingSummary(_AcctRow row) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: row.net >= 0 ? const PdfColor(0.87, 0.98, 0.91) : const PdfColor(0.99, 0.88, 0.89),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        border: pw.Border.all(color: row.net >= 0 ? _green : _red, width: 1),
      ),
      child: pw.Row(children: [
        _closingCell('TOTAL DEBITS',  '-Rs ${_fmtAmt(row.debits)}',  _red),
        pw.SizedBox(width: 20),
        _closingCell('TOTAL CREDITS', '+Rs ${_fmtAmt(row.credits)}', _green),
        pw.SizedBox(width: 20),
        _closingCell('NET CHANGE', '${row.net >= 0 ? '+' : '-'}Rs ${_fmtAmt(row.net.abs())}', row.net >= 0 ? _green : _red),
        pw.Spacer(),
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          pw.Text('CLOSING BALANCE', style: pw.TextStyle(font: pw.Font.helveticaBold(), fontSize: 7, color: _grey, letterSpacing: 0.5)),
          pw.SizedBox(height: 3),
          pw.Text('Rs ${_fmtAmt(row.closing)}', style: pw.TextStyle(font: pw.Font.helveticaBold(), fontSize: 16, color: row.net >= 0 ? _green : _red)),
        ]),
      ]),
    );
  }

  static pw.Widget _closingCell(String label, String value, PdfColor color) {
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Text(label, style: pw.TextStyle(font: pw.Font.helvetica(), fontSize: 7, color: _grey, letterSpacing: 0.4)),
      pw.SizedBox(height: 2),
      pw.Text(value, style: pw.TextStyle(font: pw.Font.helveticaBold(), fontSize: 11, color: color)),
    ]);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 4/5/9 — Category / App / Merchant bar summaries
  // ═══════════════════════════════════════════════════════════════════════════

  static pw.Widget _catSummaryBars(Map<String, List<Transaction>> groups, double totalExpense) {
    final entries = groups.entries.toList()
      ..sort((a, b) => _sumAmt(b.value).compareTo(_sumAmt(a.value)));
    final maxAmt = entries.isEmpty ? 1.0 : _sumAmt(entries.first.value);
    return pw.Column(children: entries.asMap().entries.map((e) {
      final i = e.key; final name = e.value.key; final txns = e.value.value;
      final amt  = _sumAmt(txns);
      final frac = maxAmt > 0 ? amt / maxAmt : 0.0;
      final pct  = totalExpense > 0 ? amt / totalExpense * 100 : 0.0;
      final col  = _pal[i % _pal.length];
      final tint = _palTint[i % _palTint.length];
      return pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 4),
        padding: const pw.EdgeInsets.fromLTRB(16, 6, 16, 6),
        decoration: pw.BoxDecoration(color: tint, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4))),
        child: pw.Row(children: [
          pw.Container(width: 10, height: 10, decoration: pw.BoxDecoration(color: col, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)))),
          pw.SizedBox(width: 8),
          pw.SizedBox(width: 90, child: pw.Text(name.isEmpty ? 'Uncategorised' : name, style: pw.TextStyle(font: pw.Font.helveticaBold(), fontSize: 8, color: _navy))),
          pw.Expanded(child: _hBar(frac, col)),
          pw.SizedBox(width: 6),
          _pill('${pct.toStringAsFixed(0)}%', col),
          pw.SizedBox(width: 8),
          pw.SizedBox(width: 60, child: pw.Text('Rs ${_fmtAmt(amt)}', textAlign: pw.TextAlign.right, style: pw.TextStyle(font: pw.Font.helveticaBold(), fontSize: 8, color: col))),
          pw.SizedBox(width: 6),
          pw.SizedBox(width: 36, child: pw.Text('${txns.length} txns', textAlign: pw.TextAlign.right, style: pw.TextStyle(font: pw.Font.helvetica(), fontSize: 7, color: _grey))),
        ]),
      );
    }).toList());
  }

  static pw.Widget _appSummaryBars(Map<String, List<Transaction>> groups) {
    final entries = groups.entries.toList()..sort((a, b) => _sumAmt(b.value).compareTo(_sumAmt(a.value)));
    final maxAmt  = entries.isEmpty ? 1.0 : _sumAmt(entries.first.value);
    return pw.Column(children: entries.asMap().entries.map((e) {
      final i = e.key; final name = e.value.key; final txns = e.value.value;
      final amt = _sumAmt(txns); final frac = maxAmt > 0 ? amt / maxAmt : 0.0;
      final col = _pal[i % _pal.length]; final tint = _palTint[i % _palTint.length];
      return pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 4),
        padding: const pw.EdgeInsets.fromLTRB(16, 6, 16, 6),
        decoration: pw.BoxDecoration(color: tint, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4))),
        child: pw.Row(children: [
          pw.SizedBox(width: 100, child: pw.Text(name, style: pw.TextStyle(font: pw.Font.helveticaBold(), fontSize: 8, color: _navy))),
          pw.Expanded(child: _hBar(frac, col)),
          pw.SizedBox(width: 8),
          pw.SizedBox(width: 60, child: pw.Text('Rs ${_fmtAmt(amt)}', textAlign: pw.TextAlign.right, style: pw.TextStyle(font: pw.Font.helveticaBold(), fontSize: 8, color: col))),
          pw.SizedBox(width: 6),
          pw.SizedBox(width: 36, child: pw.Text('${txns.length} txns', textAlign: pw.TextAlign.right, style: pw.TextStyle(font: pw.Font.helvetica(), fontSize: 7, color: _grey))),
        ]),
      );
    }).toList());
  }

  static pw.Widget _merchantSummaryBars(Map<String, List<Transaction>> groups) {
    final entries = groups.entries.toList()..sort((a, b) => _sumAmt(b.value).compareTo(_sumAmt(a.value)));
    final top = entries.take(12).toList();
    final maxAmt = top.isEmpty ? 1.0 : _sumAmt(top.first.value);
    return pw.Column(children: top.asMap().entries.map((e) {
      final i = e.key; final name = e.value.key; final txns = e.value.value;
      final amt = _sumAmt(txns); final frac = maxAmt > 0 ? amt / maxAmt : 0.0;
      final col = _pal[i % _pal.length]; final tint = _palTint[i % _palTint.length];
      return pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 4),
        padding: const pw.EdgeInsets.fromLTRB(16, 6, 16, 6),
        decoration: pw.BoxDecoration(color: tint, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4))),
        child: pw.Row(children: [
          pw.SizedBox(width: 100, child: pw.Text(name.isEmpty ? 'Unknown' : name, style: pw.TextStyle(font: pw.Font.helveticaBold(), fontSize: 8, color: _navy))),
          pw.Expanded(child: _hBar(frac, col)),
          pw.SizedBox(width: 8),
          pw.SizedBox(width: 60, child: pw.Text('Rs ${_fmtAmt(amt)}', textAlign: pw.TextAlign.right, style: pw.TextStyle(font: pw.Font.helveticaBold(), fontSize: 8, color: col))),
          pw.SizedBox(width: 6),
          pw.SizedBox(width: 36, child: pw.Text('${txns.length} txns', textAlign: pw.TextAlign.right, style: pw.TextStyle(font: pw.Font.helvetica(), fontSize: 7, color: _grey))),
        ]),
      );
    }).toList());
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 6 — Investments
  // ═══════════════════════════════════════════════════════════════════════════

  static pw.Widget _investmentSummaryTable(Map<String, List<Investment>> byType) {
    if (byType.isEmpty) return pw.Text('No investments on record.', style: pw.TextStyle(font: pw.Font.helvetica(), fontSize: 9, color: _grey));
    return pw.Column(children: [
      pw.Container(
        padding: const pw.EdgeInsets.fromLTRB(16, 7, 16, 7),
        decoration: pw.BoxDecoration(
          gradient: pw.LinearGradient(colors: [_indigo, _brandViolet], begin: pw.Alignment.centerLeft, end: pw.Alignment.centerRight),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        ),
        child: pw.Row(children: [
          pw.SizedBox(width: 130, child: _wt('INVESTMENT TYPE')),
          pw.Expanded(            child: _wt('HOLDINGS')),
          pw.SizedBox(width: 90,  child: _wt('TOTAL VALUE', right: true)),
          pw.SizedBox(width: 40,  child: _wt('COUNT', right: true)),
        ]),
      ),
      ...byType.entries.toList().asMap().entries.map((e) {
        final i = e.key; final type = e.value.key; final items = e.value.value;
        final total = items.fold(0.0, (s, inv) => s + inv.amount);
        final col = _pal[i % _pal.length];
        return pw.Container(
          color: i.isEven ? _palTint[i % _palTint.length] : PdfColors.white,
          padding: const pw.EdgeInsets.fromLTRB(16, 6, 16, 6),
          child: pw.Row(children: [
            pw.Container(width: 10, height: 10, decoration: pw.BoxDecoration(color: col, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)))),
            pw.SizedBox(width: 6),
            pw.SizedBox(width: 124, child: pw.Text(type, style: pw.TextStyle(font: pw.Font.helveticaBold(), fontSize: 8.5, color: _navy))),
            pw.Expanded(child: pw.Text(items.map((inv) => inv.name).take(3).join(', ') + (items.length > 3 ? '…' : ''),
                style: pw.TextStyle(font: pw.Font.helvetica(), fontSize: 7.5, color: _grey))),
            pw.SizedBox(width: 90, child: pw.Text('Rs ${_fmtAmt(total)}', textAlign: pw.TextAlign.right,
                style: pw.TextStyle(font: pw.Font.helveticaBold(), fontSize: 8.5, color: col))),
            pw.SizedBox(width: 40, child: pw.Text('${items.length}', textAlign: pw.TextAlign.right,
                style: pw.TextStyle(font: pw.Font.helvetica(), fontSize: 7.5, color: _grey))),
          ]),
        );
      }),
    ]);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 7 — Dividends table
  // ═══════════════════════════════════════════════════════════════════════════

  static pw.Widget _dividendTable(List<Transaction> divs) {
    return pw.Column(children: [
      pw.Container(
        padding: const pw.EdgeInsets.fromLTRB(16, 7, 16, 7),
        decoration: pw.BoxDecoration(
          gradient: pw.LinearGradient(colors: [_amber, _orange], begin: pw.Alignment.centerLeft, end: pw.Alignment.centerRight),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        ),
        child: pw.Row(children: [
          pw.SizedBox(width: 58,  child: _wt('DATE')),
          pw.Expanded(            child: _wt('DESCRIPTION / SOURCE')),
          pw.SizedBox(width: 72,  child: _wt('ACCOUNT')),
          pw.SizedBox(width: 78,  child: _wt('AMOUNT', right: true)),
        ]),
      ),
      ...divs.asMap().entries.map((e) {
        final i = e.key; final t = e.value;
        final meta = t.metadata ?? {};
        final desc = (meta['description'] ?? meta['merchant'] ?? t.description ?? t.getSummary()).toString();
        final acct = (meta['accountName'] ?? t.sourceAccountName ?? '').toString();
        return pw.Container(
          color: i.isEven ? const PdfColor(1.0, 0.97, 0.87) : PdfColors.white,
          padding: const pw.EdgeInsets.fromLTRB(16, 5, 16, 5),
          child: pw.Row(children: [
            pw.SizedBox(width: 58,  child: pw.Text(_fmtDateShort(t.dateTime), style: pw.TextStyle(font: pw.Font.helvetica(), fontSize: 7.5, color: _grey))),
            pw.Expanded(child: pw.Text(desc.length > 44 ? '${desc.substring(0, 44)}…' : desc, style: pw.TextStyle(font: pw.Font.helvetica(), fontSize: 8.5, color: _navy))),
            pw.SizedBox(width: 72,  child: pw.Text(acct, style: pw.TextStyle(font: pw.Font.helvetica(), fontSize: 7.5, color: _grey))),
            pw.SizedBox(width: 78,  child: pw.Text('+Rs ${_fmtAmt(t.amount)}', textAlign: pw.TextAlign.right, style: pw.TextStyle(font: pw.Font.helveticaBold(), fontSize: 8.5, color: _amber))),
          ]),
        );
      }),
    ]);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 8 — Lending & Borrowing records table
  // ═══════════════════════════════════════════════════════════════════════════

  static pw.Widget _lbTable(List<LendingBorrowing> records, LendingType ltype) {
    final accentColor = ltype == LendingType.lent ? _orange : _red;
    return pw.Column(children: [
      pw.Container(
        padding: const pw.EdgeInsets.fromLTRB(16, 7, 16, 7),
        decoration: pw.BoxDecoration(
          gradient: pw.LinearGradient(colors: [accentColor, ltype == LendingType.lent ? _amber : _purple], begin: pw.Alignment.centerLeft, end: pw.Alignment.centerRight),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        ),
        child: pw.Row(children: [
          pw.Expanded(child: _wt('PERSON / ENTITY')),
          pw.SizedBox(width: 58,  child: _wt('DATE')),
          pw.SizedBox(width: 72,  child: _wt('AMOUNT', right: true)),
          pw.SizedBox(width: 60,  child: _wt('DUE DATE')),
          pw.SizedBox(width: 54,  child: _wt('STATUS', right: true)),
        ]),
      ),
      ...records.asMap().entries.map((e) {
        final i = e.key; final r = e.value;
        final tint = ltype == LendingType.lent ? const PdfColor(1.0, 0.95, 0.86) : const PdfColor(0.99, 0.88, 0.89);
        return pw.Container(
          color: i.isEven ? tint : PdfColors.white,
          padding: const pw.EdgeInsets.fromLTRB(16, 5, 16, 5),
          child: pw.Row(children: [
            pw.Expanded(child: pw.Text(r.personName, style: pw.TextStyle(font: pw.Font.helveticaBold(), fontSize: 8.5, color: _navy))),
            pw.SizedBox(width: 58,  child: pw.Text(_fmtDateShort(r.date), style: pw.TextStyle(font: pw.Font.helvetica(), fontSize: 7.5, color: _grey))),
            pw.SizedBox(width: 72,  child: pw.Text('Rs ${_fmtAmt(r.amount)}', textAlign: pw.TextAlign.right, style: pw.TextStyle(font: pw.Font.helveticaBold(), fontSize: 8.5, color: accentColor))),
            pw.SizedBox(width: 60,  child: pw.Text(r.dueDate != null ? _fmtDateShort(r.dueDate!) : '—', style: pw.TextStyle(font: pw.Font.helvetica(), fontSize: 7.5, color: _grey))),
            pw.SizedBox(width: 54,  child: pw.Container(
              alignment: pw.Alignment.centerRight,
              child: pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: pw.BoxDecoration(
                  color: r.isSettled ? _green : accentColor,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Text(r.isSettled ? 'Settled' : 'Active',
                  style: pw.TextStyle(font: pw.Font.helveticaBold(), fontSize: 6.5, color: PdfColors.white)),
              ),
            )),
          ]),
        );
      }),
    ]);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 10 — Full Transaction Log
  // ═══════════════════════════════════════════════════════════════════════════

  static pw.Widget _fullLogTable(List<Transaction> txns) {
    return pw.Column(children: [
      pw.Container(
        padding: const pw.EdgeInsets.fromLTRB(16, 7, 16, 7),
        decoration: pw.BoxDecoration(
          gradient: pw.LinearGradient(colors: [_navy, _navyMid], begin: pw.Alignment.centerLeft, end: pw.Alignment.centerRight),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        ),
        child: pw.Row(children: [
          pw.SizedBox(width: 56,  child: _wt('DATE')),
          pw.SizedBox(width: 66,  child: _wt('TYPE')),
          pw.Expanded(            child: _wt('DESCRIPTION')),
          pw.SizedBox(width: 62,  child: _wt('APP')),
          pw.SizedBox(width: 76,  child: _wt('AMOUNT', right: true)),
          pw.SizedBox(width: 80,  child: _wt('ACCOUNT')),
        ]),
      ),
      ...txns.asMap().entries.map((e) {
        final i = e.key; final t = e.value;
        final meta    = t.metadata ?? {};
        final ev      = meta['investmentEventType'] as String?;
        final isCredit = _isCredit(t.type, ev);
        final tc      = _typeColor(t.type, ev);
        final desc    = (meta['description'] ?? meta['merchant'] ?? t.description ?? t.getSummary()).toString();
        final app     = (t.paymentAppName ?? meta['paymentApp'] ?? '').toString();
        final acct    = (meta['accountName'] ?? t.sourceAccountName ?? '').toString();
        final tl      = _typeLabel(t.type, ev);
        final rowBg   = i.isEven
            ? PdfColor(tc.red * 0.04 + 0.96, tc.green * 0.04 + 0.96, tc.blue * 0.04 + 0.95)
            : PdfColors.white;
        return pw.Container(
          color: rowBg,
          padding: const pw.EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: pw.Row(children: [
            pw.SizedBox(width: 56,  child: pw.Text(_fmtDateShort(t.dateTime), style: pw.TextStyle(font: pw.Font.helvetica(), fontSize: 7, color: _grey))),
            pw.SizedBox(width: 66,  child: pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: pw.BoxDecoration(
                color: PdfColor(tc.red * 0.14 + 0.86, tc.green * 0.14 + 0.86, tc.blue * 0.14 + 0.86),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
              ),
              child: pw.Text(tl, style: pw.TextStyle(font: pw.Font.helveticaBold(), fontSize: 6.5, color: tc)),
            )),
            pw.Expanded(child: pw.Text(
              desc.length > 38 ? '${desc.substring(0, 38)}…' : desc,
              style: pw.TextStyle(font: pw.Font.helvetica(), fontSize: 8, color: _navy))),
            pw.SizedBox(width: 62,  child: pw.Text(app, style: pw.TextStyle(font: pw.Font.helvetica(), fontSize: 7, color: _grey), textAlign: pw.TextAlign.right)),
            pw.SizedBox(width: 76,  child: pw.Text(
              '${isCredit ? '+' : '-'}Rs ${_fmtAmt(t.amount)}',
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(font: pw.Font.helveticaBold(), fontSize: 8, color: isCredit ? _green : _red))),
            pw.SizedBox(width: 80,  child: pw.Text(
              acct.length > 12 ? '${acct.substring(0, 12)}…' : acct,
              style: pw.TextStyle(font: pw.Font.helvetica(), fontSize: 7, color: _grey))),
          ]),
        );
      }),
    ]);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Shared mini transaction table (used in category / app / merchant sections)
  // ═══════════════════════════════════════════════════════════════════════════

  static pw.Widget _miniTxTable(List<Transaction> txns) {
    return pw.Column(children: txns.asMap().entries.map((e) {
      final i = e.key; final t = e.value;
      final meta    = t.metadata ?? {};
      final ev      = meta['investmentEventType'] as String?;
      final isC     = _isCredit(t.type, ev);
      final tc      = _typeColor(t.type, ev);
      final desc    = (meta['description'] ?? meta['merchant'] ?? t.description ?? t.getSummary()).toString();
      final acct    = (meta['accountName'] ?? t.sourceAccountName ?? '').toString();
      final app     = (t.paymentAppName ?? meta['paymentApp'] ?? '').toString();
      return pw.Container(
        color: i.isEven ? _row1 : _row0,
        padding: const pw.EdgeInsets.fromLTRB(22, 4, 22, 4),
        child: pw.Row(children: [
          pw.SizedBox(width: 52, child: pw.Text(_fmtDateShort(t.dateTime), style: pw.TextStyle(font: pw.Font.helvetica(), fontSize: 7, color: _grey))),
          pw.Expanded(child: pw.Text(
            desc.length > 44 ? '${desc.substring(0, 44)}…' : desc,
            style: pw.TextStyle(font: pw.Font.helvetica(), fontSize: 8, color: _navy))),
          if (app.isNotEmpty) pw.SizedBox(width: 60, child: pw.Text(app, textAlign: pw.TextAlign.right, style: pw.TextStyle(font: pw.Font.helvetica(), fontSize: 7, color: _grey))),
          pw.SizedBox(width: 76,  child: pw.Text(
            '${isC ? '+' : '-'}Rs ${_fmtAmt(t.amount)}',
            textAlign: pw.TextAlign.right,
            style: pw.TextStyle(font: pw.Font.helveticaBold(), fontSize: 8, color: isC ? _green : _red))),
          pw.SizedBox(width: 80,  child: pw.Text(
            acct.length > 12 ? '${acct.substring(0, 12)}…' : acct,
            style: pw.TextStyle(font: pw.Font.helvetica(), fontSize: 7, color: _grey))),
        ]),
      );
    }).toList());
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Shared page header / footer
  // ═══════════════════════════════════════════════════════════════════════════

  static pw.Widget _hdr(String section, String monthLabel, pw.Context ctx, Uint8List? ib) {
    return pw.Container(
      height: 52,
      decoration: pw.BoxDecoration(
        gradient: pw.LinearGradient(colors: [_navy, _navyMid], begin: pw.Alignment.centerLeft, end: pw.Alignment.centerRight),
      ),
      padding: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
        _logoMark(30, ib),
        pw.SizedBox(width: 10),
        pw.Expanded(
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(_appName, style: pw.TextStyle(font: pw.Font.helveticaBold(), fontSize: 11, color: PdfColors.white, letterSpacing: 1.2)),
            pw.Text(section.toUpperCase(), style: pw.TextStyle(font: pw.Font.helvetica(), fontSize: 7, color: const PdfColor(0.55, 0.70, 0.82), letterSpacing: 0.8)),
          ]),
        ),
        pw.Text(monthLabel, style: pw.TextStyle(font: pw.Font.helveticaBold(), fontSize: 10, color: PdfColors.white)),
        pw.SizedBox(width: 14),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          decoration: pw.BoxDecoration(
            gradient: pw.LinearGradient(colors: [_brandTeal, _brandViolet], begin: pw.Alignment.centerLeft, end: pw.Alignment.centerRight),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
          ),
          child: pw.Text('${ctx.pageNumber} / ${ctx.pagesCount}',
            style: pw.TextStyle(font: pw.Font.helveticaBold(), fontSize: 7, color: PdfColors.white)),
        ),
      ]),
    );
  }

  static pw.Widget _ftr(pw.Context ctx) {
    return pw.Container(
      height: 24,
      padding: const pw.EdgeInsets.symmetric(horizontal: 24),
      decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: PdfColor(0.86, 0.87, 0.90), width: 0.7))),
      child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
        pw.Container(
          width: 4, height: 13,
          decoration: pw.BoxDecoration(
            gradient: pw.LinearGradient(colors: [_brandTeal, _brandViolet], begin: pw.Alignment.topCenter, end: pw.Alignment.bottomCenter),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
          ),
        ),
        pw.SizedBox(width: 6),
        pw.Text('$_appName  •  $_tagline', style: pw.TextStyle(font: pw.Font.helveticaOblique(), fontSize: 7, color: _greyDk)),
        pw.Spacer(),
        pw.Text('Monthly Statement  •  Confidential', style: pw.TextStyle(font: pw.Font.helvetica(), fontSize: 6.5, color: _grey)),
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Section banner and sub-section header
  // ═══════════════════════════════════════════════════════════════════════════

  static pw.Widget _sectionBanner(String title, String subtitle, PdfColor from, PdfColor to, String tag) {
    return pw.Container(
      padding: const pw.EdgeInsets.fromLTRB(18, 9, 18, 9),
      decoration: pw.BoxDecoration(
        gradient: pw.LinearGradient(colors: [from, to], begin: pw.Alignment.centerLeft, end: pw.Alignment.centerRight),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(7)),
      ),
      child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
        pw.Container(
          width: 22, height: 22,
          decoration: pw.BoxDecoration(color: PdfColors.white, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(11))),
          alignment: pw.Alignment.center,
          child: pw.Text(tag, style: pw.TextStyle(font: pw.Font.helveticaBold(), fontSize: 8, color: from)),
        ),
        pw.SizedBox(width: 10),
        pw.Expanded(
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(title, style: pw.TextStyle(font: pw.Font.helveticaBold(), fontSize: 12, color: PdfColors.white)),
            pw.Text(subtitle, style: pw.TextStyle(font: pw.Font.helveticaOblique(), fontSize: 7.5, color: const PdfColor(0.95, 0.95, 0.98))),
          ]),
        ),
      ]),
    );
  }

  static pw.Widget _subSectionHeader(String title, int count, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.fromLTRB(16, 7, 16, 7),
      decoration: pw.BoxDecoration(
        color: PdfColor(color.red * 0.1 + 0.88, color.green * 0.1 + 0.88, color.blue * 0.1 + 0.90),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        border: pw.Border(left: pw.BorderSide(color: color, width: 4)),
      ),
      child: pw.Row(children: [
        pw.Text(title, style: pw.TextStyle(font: pw.Font.helveticaBold(), fontSize: 10, color: _navy)),
        pw.SizedBox(width: 8),
        _pill('$count record${count == 1 ? '' : 's'}', color),
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Shared widgets
  // ═══════════════════════════════════════════════════════════════════════════

  static pw.Widget _logoMark(double size, [Uint8List? iconBytes]) {
    if (iconBytes != null) {
      // Real app icon inside a white rounded-rect container (looks clean on any bg)
      return pw.Container(
        width: size, height: size,
        decoration: pw.BoxDecoration(
          color: PdfColors.white,
          borderRadius: pw.BorderRadius.all(pw.Radius.circular(size * 0.22)),
          boxShadow: [pw.BoxShadow(color: PdfColors.black, blurRadius: 4, spreadRadius: 0, offset: const PdfPoint(0, 1))],
        ),
        padding: pw.EdgeInsets.all(size * 0.10),
        child: pw.Image(pw.MemoryImage(iconBytes), width: size * 0.80, height: size * 0.80),
      );
    }
    // Fallback: gradient V box
    return pw.Container(
      width: size, height: size,
      decoration: pw.BoxDecoration(
        gradient: pw.LinearGradient(colors: [_brandTeal, _brandViolet], begin: pw.Alignment.topLeft, end: pw.Alignment.bottomRight),
        borderRadius: pw.BorderRadius.all(pw.Radius.circular(size * 0.286)),
      ),
      alignment: pw.Alignment.center,
      child: pw.Text('V', style: pw.TextStyle(font: pw.Font.helveticaBold(), fontSize: size * 0.46, color: PdfColors.white)),
    );
  }

  static pw.Widget _wt(String t, {bool right = false}) => pw.Text(t,
    textAlign: right ? pw.TextAlign.right : pw.TextAlign.left,
    style: pw.TextStyle(font: pw.Font.helveticaBold(), fontSize: 7, color: PdfColors.white, letterSpacing: 0.5));

  static pw.Widget _amtCell(double v, PdfColor color, {bool bold = false, bool sign = false}) {
    final str = sign ? '${v >= 0 ? '+' : '-'}Rs ${_fmtAmt(v.abs())}' : 'Rs ${_fmtAmt(v)}';
    return pw.Text(str, textAlign: pw.TextAlign.right,
      style: pw.TextStyle(font: bold ? pw.Font.helveticaBold() : pw.Font.helvetica(), fontSize: 8, color: color));
  }

  static pw.Widget _hBar(double fraction, PdfColor fill, {double h = 8}) {
    final pct   = fraction.clamp(0.0, 1.0);
    final fFlex = (pct * 1000).round().clamp(1, 1000);
    final eFlex = ((1.0 - pct) * 1000).round().clamp(0, 1000);
    return pw.ClipRRect(
      horizontalRadius: 4, verticalRadius: 4,
      child: pw.Row(children: [
        pw.Expanded(flex: fFlex, child: pw.Container(height: h, color: fill)),
        if (eFlex > 0) pw.Expanded(flex: eFlex, child: pw.Container(height: h, color: _greyLight)),
      ]),
    );
  }

  static pw.Widget _pill(String text, PdfColor bg) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: pw.BoxDecoration(color: bg, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8))),
      child: pw.Text(text, style: pw.TextStyle(font: pw.Font.helveticaBold(), fontSize: 7, color: PdfColors.white)),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Data computation helpers
  // ═══════════════════════════════════════════════════════════════════════════

  static Map<String, double> _computeStats(List<Transaction> txns) {
    double income = 0, expense = 0, transfer = 0, investment = 0;
    for (final t in txns) {
      switch (t.type) {
        case TransactionType.income: case TransactionType.cashback: case TransactionType.borrowing:
          income += t.amount; break;
        case TransactionType.expense: case TransactionType.lending:
          expense += t.amount; break;
        case TransactionType.transfer:   transfer += t.amount;   break;
        case TransactionType.investment: investment += t.amount; break;
      }
    }
    return {'income': income, 'expense': expense, 'net': income - expense,
            'transfer': transfer, 'investment': investment, 'count': txns.length.toDouble()};
  }

  static List<_AcctRow> _buildAcctRows(
    List<Account> accounts,
    List<Transaction> all,
    List<Transaction> monthTxns,
    DateTime monthStart,
  ) {
    return accounts.map((account) {
      // Opening balance: current balance reversed for all transactions from monthStart onwards
      double balance = account.balance;
      for (final t in all) {
        if (t.dateTime.isBefore(monthStart)) continue;
        final meta  = t.metadata ?? {};
        final srcN  = (meta['accountName'] ?? t.sourceAccountName ?? '').toString();
        final dstN  = (t.destinationAccountName ?? '').toString();
        if (srcN == account.name) {
          switch (t.type) {
            case TransactionType.income: case TransactionType.cashback: case TransactionType.borrowing:
              balance -= t.amount; break; // was added, reverse
            case TransactionType.expense: case TransactionType.lending:
            case TransactionType.investment: case TransactionType.transfer:
              balance += t.amount; break; // was subtracted, reverse
          }
        } else if (dstN == account.name && t.type == TransactionType.transfer) {
          balance -= t.amount; // was added to dest, reverse
        }
      }
      final opening = balance;

      // Debits & credits for the month
      double debits = 0, credits = 0;
      for (final t in monthTxns) {
        final meta  = t.metadata ?? {};
        final srcN  = (meta['accountName'] ?? t.sourceAccountName ?? '').toString();
        final dstN  = (t.destinationAccountName ?? '').toString();
        if (srcN == account.name) {
          switch (t.type) {
            case TransactionType.expense: case TransactionType.lending:
            case TransactionType.investment: case TransactionType.transfer:
              debits += t.amount; break;
            case TransactionType.income: case TransactionType.cashback: case TransactionType.borrowing:
              credits += t.amount; break;
          }
        } else if (dstN == account.name && t.type == TransactionType.transfer) {
          credits += t.amount;
        }
      }
      return _AcctRow(name: account.name, opening: opening, debits: debits, credits: credits);
    }).toList();
  }

  static List<_TxRow> _txRowsForAccount(Account account, List<Transaction> monthTxns) {
    final rows = <_TxRow>[];
    for (final t in monthTxns) {
      final meta = t.metadata ?? {};
      final srcN = (meta['accountName'] ?? t.sourceAccountName ?? '').toString();
      final dstN = (t.destinationAccountName ?? '').toString();
      final app  = (t.paymentAppName ?? meta['paymentApp'] ?? '').toString();

      if (srcN == account.name) {
        final isC = t.type == TransactionType.income || t.type == TransactionType.cashback || t.type == TransactionType.borrowing;
        final desc = (meta['description'] ?? meta['merchant'] ?? t.description ?? t.getSummary()).toString();
        rows.add(_TxRow(
          date: t.dateTime, description: desc, paymentApp: app,
          debit:  isC ? 0 : t.amount,
          credit: isC ? t.amount : 0,
        ));
      } else if (dstN == account.name && t.type == TransactionType.transfer) {
        rows.add(_TxRow(
          date: t.dateTime, paymentApp: app,
          description: 'Transfer from ${srcN.isNotEmpty ? srcN : 'unknown account'}',
          credit: t.amount,
        ));
      }
    }
    rows.sort((a, b) => a.date.compareTo(b.date));
    return rows;
  }

  static Map<String, List<Transaction>> _groupByCategory(List<Transaction> txns) {
    final map = <String, List<Transaction>>{};
    for (final t in txns) {
      final cat = ((t.metadata ?? {})['categoryName'] ?? '').toString();
      map.putIfAbsent(cat, () => []).add(t);
    }
    final sorted = map.entries.toList()..sort((a, b) => _sumAmt(b.value).compareTo(_sumAmt(a.value)));
    return Map.fromEntries(sorted);
  }

  static Map<String, List<Transaction>> _groupByPaymentApp(List<Transaction> txns) {
    final map = <String, List<Transaction>>{};
    for (final t in txns) {
      final app = (t.paymentAppName ?? (t.metadata ?? {})['paymentApp'] ?? '').toString().trim();
      if (app.isEmpty) continue;
      map.putIfAbsent(app, () => []).add(t);
    }
    final sorted = map.entries.toList()..sort((a, b) => b.value.length.compareTo(a.value.length));
    return Map.fromEntries(sorted);
  }

  static Map<String, List<Transaction>> _groupByMerchant(List<Transaction> txns) {
    final map = <String, List<Transaction>>{};
    for (final t in txns) {
      if (t.type != TransactionType.expense && t.type != TransactionType.lending) continue;
      final merchant = ((t.metadata ?? {})['merchant'] ?? '').toString().trim();
      map.putIfAbsent(merchant, () => []).add(t);
    }
    final sorted = map.entries.toList()..sort((a, b) => _sumAmt(b.value).compareTo(_sumAmt(a.value)));
    return Map.fromEntries(sorted);
  }

  static Map<String, List<Investment>> _groupInvestmentsByType(List<Investment> investments) {
    final map = <String, List<Investment>>{};
    for (final inv in investments) {
      final label = inv.getTypeLabel();
      map.putIfAbsent(label, () => []).add(inv);
    }
    return map;
  }

  static Map<String, List<Transaction>> _groupInvTxsByType(List<Transaction> txns) {
    final map = <String, List<Transaction>>{};
    for (final t in txns) {
      final meta = t.metadata ?? {};
      final typeLabel = (meta['investmentTypeLabel'] ?? meta['investmentType'] ?? 'Investment').toString();
      map.putIfAbsent(typeLabel, () => []).add(t);
    }
    return map;
  }

  static double _sumAmt(List<Transaction> txns) => txns.fold(0.0, (s, t) => s + t.amount);

  // ═══════════════════════════════════════════════════════════════════════════
  // Type helpers
  // ═══════════════════════════════════════════════════════════════════════════

  static bool _isCredit(TransactionType type, String? ev) {
    if (ev == 'sell' || ev == 'decrease' || ev == 'dividend') return true;
    return type == TransactionType.income || type == TransactionType.cashback || type == TransactionType.borrowing;
  }

  static PdfColor _typeColor(TransactionType type, String? ev) {
    if (ev == 'dividend')                     return _amber;
    if (ev == 'sell' || ev == 'decrease')     return _green;
    switch (type) {
      case TransactionType.income:     return _green;
      case TransactionType.cashback:   return _green;
      case TransactionType.expense:    return _red;
      case TransactionType.transfer:   return _brandTeal;
      case TransactionType.investment: return _indigo;
      case TransactionType.lending:    return _orange;
      case TransactionType.borrowing:  return _purple;
    }
  }

  static String _typeLabel(TransactionType type, String? ev) {
    if (ev == 'dividend')                     return 'Dividend';
    if (ev == 'sell' || ev == 'decrease')     return 'Sell';
    switch (type) {
      case TransactionType.income:     return 'Income';
      case TransactionType.cashback:   return 'Cashback';
      case TransactionType.expense:    return 'Expense';
      case TransactionType.transfer:   return 'Transfer';
      case TransactionType.investment: return 'Invest';
      case TransactionType.lending:    return 'Lend';
      case TransactionType.borrowing:  return 'Borrow';
    }
  }

  static String _acctTypeLabel(AccountType t) {
    switch (t) {
      case AccountType.savings:    return 'Savings';
      case AccountType.current:    return 'Current';
      case AccountType.credit:     return 'Credit Card';
      case AccountType.payLater:   return 'Pay Later';
      case AccountType.wallet:     return 'Wallet';
      case AccountType.investment: return 'Investment';
      case AccountType.cash:       return 'Cash';
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Formatting
  // ═══════════════════════════════════════════════════════════════════════════

  static const _moAbbr = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];

  static String _fmtDate(DateTime d) => '${d.day} ${_moAbbr[d.month - 1]} ${d.year}';
  static String _fmtDateShort(DateTime d) =>
      '${d.day.toString().padLeft(2, ' ')} ${_moAbbr[d.month - 1]}\'${d.year.toString().substring(2)}';

  static String _fmtAmt(double v) {
    if (v > 10000000) return '${(v / 10000000).toStringAsFixed(2)}Cr';
    if (v >= 100000)  return '${(v / 100000).toStringAsFixed(2)}L';
    if (v >= 1000)    return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }

  static Future<Directory> _reportDir() async {
    final base = await getApplicationDocumentsDirectory();
    final d = Directory('${base.path}/reports');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  static String _timestamp() =>
      DateTime.now().toIso8601String().replaceAll(':', '-').substring(0, 19);
}
