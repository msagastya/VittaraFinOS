import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:excel/excel.dart';
import 'package:vittara_fin_os/logic/transaction_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Analytical breakdown models
// ─────────────────────────────────────────────────────────────────────────────

class _AccountStat {
  final String name;
  double income = 0, expense = 0, transfer = 0, investment = 0;
  int count = 0;
  _AccountStat(this.name);
  double get net           => income - expense;
  double get totalActivity => income + expense + transfer + investment;
}

class _CategoryStat {
  final String name;
  double amount = 0;
  int count = 0;
  _CategoryStat(this.name);
}

class _MerchantStat {
  final String name;
  double amount = 0;
  double maxTxn = 0;
  int count = 0;
  _MerchantStat(this.name);
  double get avg => count > 0 ? amount / count : 0;
}

class _MonthStat {
  final String label;
  final int sortKey; // yyyyMM
  double income = 0, expense = 0;
  _MonthStat(this.label, this.sortKey);
  double get net => income - expense;
}

// ─────────────────────────────────────────────────────────────────────────────
/// Fully-branded, data-rich PDF + multi-sheet XLSX export service.
// ─────────────────────────────────────────────────────────────────────────────
class TransactionExportService {
  static const _appName = 'VittaraFinOS';
  static const _tagline = 'Track Wealth, Master Life';

  // Roboto fonts loaded once per buildPdf() — support ₹ and full Unicode.
  static late pw.Font _regFont;
  static late pw.Font _boldFont;
  static late pw.Font _obliqueFont;

  // ── Brand palette (matches design_tokens.dart exactly) ────────────────────
  // SemanticColors.primary = #00B890 → PdfColor(0, 184/255, 144/255)
  // SemanticColors.info    = #7B5CEF → PdfColor(123/255, 92/255, 239/255)
  static const _brandTeal   = PdfColor(0.000, 0.722, 0.565); // #00B890
  static const _brandViolet = PdfColor(0.482, 0.361, 0.937); // #7B5CEF

  // ── Extended palette ───────────────────────────────────────────────────────
  static const _navy       = PdfColor(0.035, 0.098, 0.157);
  static const _navyMid    = PdfColor(0.067, 0.165, 0.255);
  static const _green      = PdfColor(0.000, 0.784, 0.463); // #00C876
  static const _red        = PdfColor(0.878, 0.188, 0.314); // #E03050
  static const _indigo     = PdfColor(0.482, 0.361, 0.937); // #7B5CEF
  static const _orange     = PdfColor(1.000, 0.584, 0.000); // #FF9500
  static const _purple     = PdfColor(0.686, 0.322, 0.871); // #AF52DE
  static const _blue       = PdfColor(0.000, 0.478, 1.000); // #007AFF
  static const _amber      = PdfColor(1.000, 0.722, 0.000);
  static const _greyLight  = PdfColor(0.900, 0.910, 0.920);
  static const _greyMid    = PdfColor(0.550, 0.550, 0.600);
  static const _greyDark   = PdfColor(0.350, 0.400, 0.450);
  static const _th         = PdfColor(0.110, 0.230, 0.320);
  static const _row0       = PdfColors.white;
  static const _row1       = PdfColor(0.965, 0.972, 0.980);

  // ── Tinted backgrounds (light versions of accent for card fills) ───────────
  static const _tintGreen  = PdfColor(0.870, 0.980, 0.910); // #DEF9E8
  static const _tintRed    = PdfColor(0.985, 0.880, 0.890); // #FCE1E4
  static const _tintTeal   = PdfColor(0.860, 0.975, 0.960); // #DBF9F4
  static const _tintViolet = PdfColor(0.935, 0.910, 0.990); // #EEE8FC
  static const _tintOrange = PdfColor(1.000, 0.950, 0.860); // #FFF2DC
  static const _tintBlue   = PdfColor(0.870, 0.935, 1.000); // #DEEEIF
  static const _tintNavy   = PdfColor(0.900, 0.920, 0.950); // stats bg

  // ── Chart palette ─────────────────────────────────────────────────────────
  static const List<PdfColor> _palette = [
    PdfColor(0.000, 0.722, 0.565),
    PdfColor(0.482, 0.361, 0.937),
    PdfColor(0.000, 0.784, 0.463),
    PdfColor(1.000, 0.584, 0.000),
    PdfColor(0.878, 0.188, 0.314),
    PdfColor(0.000, 0.478, 1.000),
    PdfColor(0.686, 0.322, 0.871),
    PdfColor(0.188, 0.714, 0.753),
  ];
  static const List<PdfColor> _paletteTint = [
    PdfColor(0.860, 0.975, 0.960),
    PdfColor(0.935, 0.910, 0.990),
    PdfColor(0.870, 0.980, 0.910),
    PdfColor(1.000, 0.950, 0.860),
    PdfColor(0.985, 0.880, 0.890),
    PdfColor(0.870, 0.935, 1.000),
    PdfColor(0.960, 0.900, 0.985),
    PdfColor(0.870, 0.965, 0.975),
  ];

  // ═══════════════════════════════════════════════════════════════════════════
  // PUBLIC API
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<File> buildPdf(
    List<Transaction> transactions, {
    String title = 'Transaction Statement',
    String? accountName,
  }) async {
    // Load Roboto fonts (supports ₹ — unlike built-in Helvetica which is Latin-1 only).
    final regBytes  = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
    final boldBytes = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
    _regFont     = pw.Font.ttf(regBytes);
    _boldFont    = pw.Font.ttf(boldBytes);
    _obliqueFont = _regFont;

    final doc   = pw.Document();
    final stats = _computeStats(transactions);
    final range = _buildDateRange(transactions);
    final now   = DateTime.now();
    final label = accountName ?? title;

    final acctStats     = _byAccount(transactions);
    final catStats      = _byCategory(transactions);
    final merchantStats = _byMerchant(transactions);
    final monthlyStats  = _byMonth(transactions);
    final typeStats     = _byType(transactions, stats);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        header: (ctx) => _pageHeader(label, now, ctx),
        footer: (ctx) => _pageFooter(ctx),
        build: (ctx) => [
          _infoBand(label, range, transactions.length, stats),
          pw.SizedBox(height: 2),
          _summaryRow(stats),
          pw.SizedBox(height: 16),

          _sectionBanner('Transaction Breakdown', 'Distribution by type and volume', _brandTeal, _brandViolet, '01'),
          pw.SizedBox(height: 6),
          _typeBreakdownSection(typeStats),
          pw.SizedBox(height: 14),

          if (acctStats.length > 1) ...[
            _sectionBanner('By Account', 'Activity split across all accounts', _blue, _brandTeal, '02'),
            pw.SizedBox(height: 6),
            _accountBreakdownSection(acctStats),
            pw.SizedBox(height: 14),
          ],

          if (catStats.isNotEmpty) ...[
            _sectionBanner('Top Spending Categories', 'Where your money goes', _brandViolet, _indigo, '03'),
            pw.SizedBox(height: 6),
            _categoryBreakdownSection(catStats, stats['expense']!),
            pw.SizedBox(height: 14),
          ],

          if (merchantStats.isNotEmpty) ...[
            _sectionBanner('Top Merchants & Apps', 'Highest-spend vendors and wallets', _orange, _red, '04'),
            pw.SizedBox(height: 6),
            _merchantBreakdownSection(merchantStats),
            pw.SizedBox(height: 14),
          ],

          if (monthlyStats.length > 1) ...[
            _sectionBanner('Monthly Trend', 'Income vs expenses over time', _green, _brandTeal, '05'),
            pw.SizedBox(height: 6),
            _monthlyTrendSection(monthlyStats),
            pw.SizedBox(height: 14),
          ],

          _sectionBanner('Key Insights', 'Computed observations from this statement', _brandViolet, _blue, '06'),
          pw.SizedBox(height: 6),
          _insightsSection(stats, acctStats, catStats, merchantStats, monthlyStats, transactions),
          pw.SizedBox(height: 18),

          _sectionBanner(
            'All Transactions',
            '${transactions.length} record${transactions.length == 1 ? '' : 's'} — full statement',
            _navy, _navyMid, '07',
          ),
          pw.SizedBox(height: 6),
          _tableHeaderRow(),
          ...transactions.asMap().entries.map((e) => _tableDataRow(e.value, e.key.isEven)),
          pw.SizedBox(height: 12),
        ],
      ),
    );

    final bytes = await doc.save();
    final dir = await _reportDir();
    final file = File('${dir.path}/transactions_${_timestamp()}.pdf');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  static Future<File> buildXlsx(
    List<Transaction> transactions, {
    String title = 'Transactions',
    String? accountName,
  }) async {
    final excel = Excel.createExcel();
    excel.delete('Sheet1');

    final label = accountName ?? title;
    final stats = _computeStats(transactions);
    final acctStats     = _byAccount(transactions);
    final catStats      = _byCategory(transactions);
    final merchantStats = _byMerchant(transactions);
    final monthlyStats  = _byMonth(transactions);

    _buildSummarySheet(excel, label, stats, transactions, acctStats);
    _buildTransactionsSheet(excel, transactions, label);
    _buildByAccountSheet(excel, acctStats, stats);
    _buildByCategorySheet(excel, catStats, stats['expense']!);
    _buildByMerchantSheet(excel, merchantStats);
    _buildMonthlyTrendsSheet(excel, monthlyStats);

    final bytes = excel.encode()!;
    final dir   = await _reportDir();
    final file  = File('${dir.path}/transactions_${_timestamp()}.xlsx');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PDF — Logo & Page Chrome
  // ═══════════════════════════════════════════════════════════════════════════

  /// Matches _BrandHeader exactly: gradient rounded rect + bold "V"
  static pw.Widget _logoMark({double size = 44}) {
    return pw.Container(
      width: size, height: size,
      decoration: pw.BoxDecoration(
        gradient: pw.LinearGradient(
          colors: [_brandTeal, _brandViolet],
          begin: pw.Alignment.topLeft,
          end: pw.Alignment.bottomRight,
        ),
        borderRadius: pw.BorderRadius.all(pw.Radius.circular(size * 0.286)),
      ),
      alignment: pw.Alignment.center,
      child: pw.Text('V',
        style: pw.TextStyle(
          font: _boldFont,
          fontSize: size * 0.46,
          color: PdfColors.white,
        )),
    );
  }

  static pw.Widget _pageHeader(String label, DateTime now, pw.Context ctx) {
    return pw.Container(
      height: 78,
      decoration: pw.BoxDecoration(
        gradient: pw.LinearGradient(
          colors: [_navy, _navyMid],
          begin: pw.Alignment.centerLeft,
          end: pw.Alignment.centerRight,
        ),
      ),
      padding: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 14),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          _logoMark(size: 46),
          pw.SizedBox(width: 12),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text(_appName,
                style: pw.TextStyle(
                  font: _boldFont, fontSize: 15,
                  color: PdfColors.white, letterSpacing: 1.4,
                )),
              pw.SizedBox(height: 3),
              pw.Text(_tagline,
                style: pw.TextStyle(
                  font: _obliqueFont, fontSize: 7.5,
                  color: const PdfColor(0.55, 0.68, 0.80),
                )),
            ],
          ),
          pw.Spacer(),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text('TRANSACTION STATEMENT',
                style: pw.TextStyle(
                  font: _boldFont, fontSize: 7.5,
                  color: PdfColors.white, letterSpacing: 1.2,
                )),
              pw.SizedBox(height: 4),
              pw.Text('Generated ${_fmtDate(now)}',
                style: pw.TextStyle(
                  font: _regFont, fontSize: 7,
                  color: const PdfColor(0.55, 0.68, 0.80),
                )),
              pw.SizedBox(height: 5),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: pw.BoxDecoration(
                  gradient: pw.LinearGradient(
                    colors: [_brandTeal, _brandViolet],
                    begin: pw.Alignment.centerLeft,
                    end: pw.Alignment.centerRight,
                  ),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(9)),
                ),
                child: pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                  style: pw.TextStyle(
                    font: _boldFont, fontSize: 7,
                    color: PdfColors.white,
                  )),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _pageFooter(pw.Context ctx) {
    return pw.Container(
      height: 28,
      padding: const pw.EdgeInsets.symmetric(horizontal: 28),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColor(0.86, 0.87, 0.90), width: 0.7)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Container(
            width: 4, height: 16,
            decoration: pw.BoxDecoration(
              gradient: pw.LinearGradient(
                colors: [_brandTeal, _brandViolet],
                begin: pw.Alignment.topCenter,
                end: pw.Alignment.bottomCenter,
              ),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
            ),
          ),
          pw.SizedBox(width: 7),
          pw.Text(_appName,
            style: pw.TextStyle(font: _boldFont, fontSize: 7.5, color: _greyDark)),
          pw.Text(' | $_tagline',
            style: pw.TextStyle(font: _obliqueFont, fontSize: 7, color: _greyMid)),
          pw.Spacer(),
          pw.Text('Confidential | Personal Use Only',
            style: pw.TextStyle(font: _regFont, fontSize: 6.5, color: _greyMid)),
        ],
      ),
    );
  }

  /// Info band below header: shows scope label, count, date range + mini net-flow pill
  static pw.Widget _infoBand(String label, String range, int count, Map<String, double> stats) {
    final net = stats['net']!;
    return pw.Container(
      decoration: const pw.BoxDecoration(color: _navyMid),
      padding: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 9),
      child: pw.Row(
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: pw.BoxDecoration(
              gradient: pw.LinearGradient(
                colors: [_brandTeal, _brandViolet],
                begin: pw.Alignment.centerLeft,
                end: pw.Alignment.centerRight,
              ),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
            ),
            child: pw.Text(label,
              style: pw.TextStyle(font: _boldFont, fontSize: 8, color: PdfColors.white)),
          ),
          pw.SizedBox(width: 10),
          pw.Text('$count transaction${count == 1 ? '' : 's'}',
            style: pw.TextStyle(font: _regFont, fontSize: 8, color: const PdfColor(0.70, 0.80, 0.88))),
          pw.Spacer(),
          // Net flow pill
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: pw.BoxDecoration(
              color: net >= 0 ? const PdfColor(0.00, 0.60, 0.37) : const PdfColor(0.70, 0.12, 0.22),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
            ),
            child: pw.Text(
              'NET: ${net >= 0 ? '+' : '-'}₹${_fmtAmt(net.abs())}',
              style: pw.TextStyle(font: _boldFont, fontSize: 7.5, color: PdfColors.white),
            ),
          ),
          pw.SizedBox(width: 10),
          pw.Text(range,
            style: pw.TextStyle(font: _regFont, fontSize: 8, color: const PdfColor(0.70, 0.80, 0.88))),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PDF — Summary Stats (6 colorful cards)
  // ═══════════════════════════════════════════════════════════════════════════

  static pw.Widget _summaryRow(Map<String, double> stats) {
    final net = stats['net']!;
    final netColor = net >= 0 ? _green : _red;
    final netTint  = net >= 0 ? _tintGreen : _tintRed;
    return pw.Container(
      padding: const pw.EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: pw.BoxDecoration(
        gradient: pw.LinearGradient(
          colors: [const PdfColor(0.94, 0.95, 0.97), const PdfColor(0.97, 0.97, 0.98)],
          begin: pw.Alignment.topLeft,
          end: pw.Alignment.bottomRight,
        ),
      ),
      child: pw.Row(
        children: [
          _statCard('INCOME',    '+₹${_fmtAmt(stats['income']!)}',    _green,      _tintGreen,  '+'),
          pw.SizedBox(width: 6),
          _statCard('EXPENSES',  '-₹${_fmtAmt(stats['expense']!)}',   _red,        _tintRed,    '-'),
          pw.SizedBox(width: 6),
          _statCard('NET FLOW',  '${net >= 0 ? '+' : '-'}₹${_fmtAmt(net.abs())}', netColor, netTint, '='),
          pw.SizedBox(width: 6),
          _statCard('INVESTED',  '₹${_fmtAmt(stats['investment']!)}', _indigo,     _tintViolet, '*'),
          pw.SizedBox(width: 6),
          _statCard('TRANSFERS', '₹${_fmtAmt(stats['transfer']!)}',   _brandTeal,  _tintTeal,   '<>'),
          pw.SizedBox(width: 6),
          _statCard('RECORDS',   '${stats['count']!.toInt()}',          _navy,       _tintNavy,   '#'),
        ],
      ),
    );
  }

  static pw.Widget _statCard(String label, String value, PdfColor accent, PdfColor tint, String sym) {
    return pw.Expanded(
      child: pw.Container(
        decoration: pw.BoxDecoration(
          gradient: pw.LinearGradient(
            colors: [tint, PdfColors.white],
            begin: pw.Alignment.topLeft,
            end: pw.Alignment.bottomRight,
          ),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(7)),
          border: pw.Border(
            top: pw.BorderSide(color: accent, width: 3),
          ),
        ),
        padding: const pw.EdgeInsets.fromLTRB(8, 8, 8, 8),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(children: [
              pw.Container(
                width: 14, height: 14,
                decoration: pw.BoxDecoration(
                  color: accent,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(7)),
                ),
                alignment: pw.Alignment.center,
                child: pw.Text(sym,
                  style: pw.TextStyle(font: _boldFont, fontSize: 7, color: PdfColors.white)),
              ),
              pw.SizedBox(width: 5),
              pw.Text(label,
                style: pw.TextStyle(font: _boldFont, fontSize: 5.5, color: _greyMid, letterSpacing: 0.4)),
            ]),
            pw.SizedBox(height: 6),
            pw.Text(value,
              style: pw.TextStyle(font: _boldFont, fontSize: 10, color: accent)),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PDF — Colorful Section Banner
  // ═══════════════════════════════════════════════════════════════════════════

  static pw.Widget _sectionBanner(
    String title, String subtitle,
    PdfColor from, PdfColor to, String num,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.fromLTRB(22, 9, 22, 9),
      decoration: pw.BoxDecoration(
        gradient: pw.LinearGradient(
          colors: [from, to],
          begin: pw.Alignment.centerLeft,
          end: pw.Alignment.centerRight,
        ),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(7)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Container(
            width: 22, height: 22,
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(11)),
            ),
            alignment: pw.Alignment.center,
            child: pw.Text(num,
              style: pw.TextStyle(font: _boldFont, fontSize: 8, color: from)),
          ),
          pw.SizedBox(width: 10),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(title,
                style: pw.TextStyle(font: _boldFont, fontSize: 12, color: PdfColors.white)),
              pw.SizedBox(height: 1),
              pw.Text(subtitle,
                style: pw.TextStyle(font: _obliqueFont, fontSize: 7.5,
                  color: const PdfColor(0.95, 0.95, 0.98))),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PDF — Shared bar
  // ═══════════════════════════════════════════════════════════════════════════

  static pw.Widget _hBar(double fraction, PdfColor fill, {double h = 8}) {
    final pct = fraction.clamp(0.0, 1.0);
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

  /// Small colored pill showing text (e.g. percentage)
  static pw.Widget _pill(String text, PdfColor bg) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: pw.BoxDecoration(
        color: bg,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Text(text,
        style: pw.TextStyle(font: _boldFont, fontSize: 7, color: PdfColors.white)),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PDF — Section 01: Type Breakdown
  // ═══════════════════════════════════════════════════════════════════════════

  static pw.Widget _typeBreakdownSection(List<Map<String, dynamic>> typeStats) {
    final maxAmt = typeStats.fold<double>(0, (m, s) => (s['amount'] as double) > m ? s['amount'] as double : m);
    final total  = typeStats.fold<double>(0, (s, e) => s + (e['amount'] as double));
    return pw.Column(
      children: typeStats.asMap().entries.map((entry) {
        final i     = entry.key;
        final item  = entry.value;
        final amt   = item['amount'] as double;
        final color = item['color'] as PdfColor;
        final label = item['label'] as String;
        final count = item['count'] as int;
        final pct   = maxAmt > 0 ? amt / maxAmt : 0.0;
        final pctOf = total > 0 ? (amt / total * 100) : 0.0;
        final tint  = _paletteTint[i % _paletteTint.length];
        return pw.Container(
          padding: const pw.EdgeInsets.fromLTRB(20, 7, 20, 7),
          decoration: pw.BoxDecoration(
            color: i.isEven ? tint : PdfColors.white,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          margin: const pw.EdgeInsets.only(bottom: 3),
          child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
            pw.Container(
              width: 12, height: 12,
              decoration: pw.BoxDecoration(
                color: color,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
              ),
            ),
            pw.SizedBox(width: 8),
            pw.SizedBox(width: 72,
              child: pw.Text(label,
                style: pw.TextStyle(font: _boldFont, fontSize: 9, color: _navy))),
            pw.Expanded(child: _hBar(pct, color, h: 9)),
            pw.SizedBox(width: 8),
            _pill('${pctOf.toStringAsFixed(0)}%', color),
            pw.SizedBox(width: 8),
            pw.SizedBox(width: 62,
              child: pw.Text('₹${_fmtAmt(amt)}',
                textAlign: pw.TextAlign.right,
                style: pw.TextStyle(font: _boldFont, fontSize: 9, color: color))),
            pw.SizedBox(width: 8),
            pw.SizedBox(width: 38,
              child: pw.Text('$count txns',
                textAlign: pw.TextAlign.right,
                style: pw.TextStyle(font: _regFont, fontSize: 7, color: _greyMid))),
          ]),
        );
      }).toList(),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PDF — Section 02: By Account
  // ═══════════════════════════════════════════════════════════════════════════

  static pw.Widget _accountBreakdownSection(List<_AccountStat> stats) {
    final maxActivity = stats.fold<double>(0, (m, s) => s.totalActivity > m ? s.totalActivity : m);
    return pw.Column(
      children: [
        // Column headers
        pw.Container(
          padding: const pw.EdgeInsets.fromLTRB(20, 8, 20, 8),
          decoration: pw.BoxDecoration(
            gradient: pw.LinearGradient(
              colors: [_blue, _brandTeal],
              begin: pw.Alignment.centerLeft,
              end: pw.Alignment.centerRight,
            ),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          child: pw.Row(children: [
            pw.SizedBox(width: 110, child: _hdrText('ACCOUNT')),
            pw.Expanded(child: _hdrText('ACTIVITY')),
            pw.SizedBox(width: 62,  child: _hdrText('INCOME',    right: true)),
            pw.SizedBox(width: 62,  child: _hdrText('EXPENSES',  right: true)),
            pw.SizedBox(width: 54,  child: _hdrText('NET',       right: true)),
            pw.SizedBox(width: 32,  child: _hdrText('TXNS',      right: true)),
          ]),
        ),
        ...stats.asMap().entries.map((entry) {
          final i  = entry.key;
          final s  = entry.value;
          final frac = maxActivity > 0 ? s.totalActivity / maxActivity : 0.0;
          final netColor = s.net >= 0 ? _green : _red;
          return pw.Container(
            color: i.isEven ? _tintTeal : PdfColors.white,
            padding: const pw.EdgeInsets.fromLTRB(20, 6, 20, 6),
            child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
              pw.SizedBox(width: 110,
                child: pw.Text(
                  s.name.length > 17 ? '${s.name.substring(0, 17)}...' : s.name,
                  style: pw.TextStyle(font: _boldFont, fontSize: 8.5, color: _navy))),
              pw.Expanded(child: _hBar(frac, _brandTeal)),
              pw.SizedBox(width: 4),
              pw.SizedBox(width: 62,
                child: pw.Text('+₹${_fmtAmt(s.income)}',
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(font: _regFont, fontSize: 7.5, color: _green))),
              pw.SizedBox(width: 62,
                child: pw.Text('-₹${_fmtAmt(s.expense)}',
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(font: _regFont, fontSize: 7.5, color: _red))),
              pw.SizedBox(width: 54,
                child: pw.Text(
                  '${s.net >= 0 ? '+' : '-'}₹${_fmtAmt(s.net.abs())}',
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(font: _boldFont, fontSize: 7.5, color: netColor))),
              pw.SizedBox(width: 32,
                child: pw.Text('${s.count}',
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(font: _regFont, fontSize: 7.5, color: _greyMid))),
            ]),
          );
        }),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PDF — Section 03: Top Categories
  // ═══════════════════════════════════════════════════════════════════════════

  static pw.Widget _categoryBreakdownSection(List<_CategoryStat> stats, double totalExpense) {
    final top    = stats.take(8).toList();
    final maxAmt = top.fold<double>(0, (m, s) => s.amount > m ? s.amount : m);
    return pw.Column(
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.fromLTRB(20, 8, 20, 8),
          decoration: pw.BoxDecoration(
            gradient: pw.LinearGradient(
              colors: [_brandViolet, _indigo],
              begin: pw.Alignment.centerLeft,
              end: pw.Alignment.centerRight,
            ),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          child: pw.Row(children: [
            pw.SizedBox(width: 16),
            pw.SizedBox(width: 86,  child: _hdrText('CATEGORY')),
            pw.Expanded(            child: _hdrText('SHARE OF EXPENSES')),
            pw.SizedBox(width: 62,  child: _hdrText('AMOUNT',  right: true)),
            pw.SizedBox(width: 44,  child: _hdrText('% TOTAL', right: true)),
            pw.SizedBox(width: 38,  child: _hdrText('TXNS',    right: true)),
          ]),
        ),
        ...top.asMap().entries.map((entry) {
          final i = entry.key;
          final s = entry.value;
          final frac  = maxAmt > 0 ? s.amount / maxAmt : 0.0;
          final pctOf = totalExpense > 0 ? s.amount / totalExpense * 100 : 0.0;
          final color = _palette[i % _palette.length];
          final tint  = _paletteTint[i % _paletteTint.length];
          return pw.Container(
            color: i.isEven ? tint : PdfColors.white,
            padding: const pw.EdgeInsets.fromLTRB(20, 6, 20, 6),
            child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
              pw.Container(
                width: 10, height: 10,
                decoration: pw.BoxDecoration(
                  color: color,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
                ),
              ),
              pw.SizedBox(width: 6),
              pw.SizedBox(width: 86,
                child: pw.Text(
                  s.name.isEmpty ? 'Uncategorised' : s.name,
                  style: pw.TextStyle(font: _boldFont, fontSize: 8.5, color: _navy))),
              pw.Expanded(child: _hBar(frac, color)),
              pw.SizedBox(width: 8),
              pw.SizedBox(width: 62,
                child: pw.Text('₹${_fmtAmt(s.amount)}',
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(font: _boldFont, fontSize: 8.5, color: color))),
              pw.SizedBox(width: 6),
              pw.SizedBox(width: 44,
                child: pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: _pill('${pctOf.toStringAsFixed(0)}%', color))),
              pw.SizedBox(width: 4),
              pw.SizedBox(width: 34,
                child: pw.Text('${s.count}',
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(font: _regFont, fontSize: 7.5, color: _greyMid))),
            ]),
          );
        }),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PDF — Section 04: Top Merchants
  // ═══════════════════════════════════════════════════════════════════════════

  static pw.Widget _merchantBreakdownSection(List<_MerchantStat> stats) {
    final top    = stats.take(8).toList();
    final maxAmt = top.fold<double>(0, (m, s) => s.amount > m ? s.amount : m);
    return pw.Column(
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.fromLTRB(20, 8, 20, 8),
          decoration: pw.BoxDecoration(
            gradient: pw.LinearGradient(
              colors: [_orange, _red],
              begin: pw.Alignment.centerLeft,
              end: pw.Alignment.centerRight,
            ),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          child: pw.Row(children: [
            pw.SizedBox(width: 16),
            pw.SizedBox(width: 100, child: _hdrText('MERCHANT / APP')),
            pw.Expanded(            child: _hdrText('SPEND')),
            pw.SizedBox(width: 62,  child: _hdrText('TOTAL',    right: true)),
            pw.SizedBox(width: 38,  child: _hdrText('COUNT',    right: true)),
            pw.SizedBox(width: 62,  child: _hdrText('AVG / TXN',right: true)),
          ]),
        ),
        ...top.asMap().entries.map((entry) {
          final i = entry.key;
          final s = entry.value;
          final frac  = maxAmt > 0 ? s.amount / maxAmt : 0.0;
          final color = _palette[i % _palette.length];
          final tint  = _paletteTint[i % _paletteTint.length];
          return pw.Container(
            color: i.isEven ? tint : PdfColors.white,
            padding: const pw.EdgeInsets.fromLTRB(20, 6, 20, 6),
            child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
              pw.Container(
                width: 10, height: 10,
                decoration: pw.BoxDecoration(
                  gradient: pw.LinearGradient(colors: [_orange, color], begin: pw.Alignment.topLeft, end: pw.Alignment.bottomRight),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
                ),
              ),
              pw.SizedBox(width: 6),
              pw.SizedBox(width: 100,
                child: pw.Text(
                  s.name.length > 16 ? '${s.name.substring(0, 16)}...' : s.name,
                  style: pw.TextStyle(font: _boldFont, fontSize: 8.5, color: _navy))),
              pw.Expanded(child: _hBar(frac, color)),
              pw.SizedBox(width: 4),
              pw.SizedBox(width: 62,
                child: pw.Text('₹${_fmtAmt(s.amount)}',
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(font: _boldFont, fontSize: 8.5, color: color))),
              pw.SizedBox(width: 38,
                child: pw.Text('${s.count}',
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(font: _regFont, fontSize: 7.5, color: _greyMid))),
              pw.SizedBox(width: 62,
                child: pw.Text('₹${_fmtAmt(s.avg)}',
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(font: _regFont, fontSize: 7.5, color: _greyMid))),
            ]),
          );
        }),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PDF — Section 05: Monthly Trend
  // ═══════════════════════════════════════════════════════════════════════════

  static pw.Widget _monthlyTrendSection(List<_MonthStat> months) {
    final all    = months.take(12).toList();
    final maxVal = all.fold<double>(0, (m, s) {
      final hi = s.income > s.expense ? s.income : s.expense;
      return hi > m ? hi : m;
    });
    return pw.Column(
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.fromLTRB(20, 8, 20, 8),
          decoration: pw.BoxDecoration(
            gradient: pw.LinearGradient(
              colors: [_green, _brandTeal],
              begin: pw.Alignment.centerLeft,
              end: pw.Alignment.centerRight,
            ),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          child: pw.Row(children: [
            pw.SizedBox(width: 50,  child: _hdrText('MONTH')),
            pw.Expanded(            child: _hdrText('INCOME / EXPENSE BARS')),
            pw.SizedBox(width: 60,  child: _hdrText('+INCOME',  right: true)),
            pw.SizedBox(width: 60,  child: _hdrText('-EXPENSE', right: true)),
            pw.SizedBox(width: 60,  child: _hdrText('NET FLOW', right: true)),
          ]),
        ),
        ...all.asMap().entries.map((entry) {
          final i = entry.key;
          final s = entry.value;
          final incFrac = maxVal > 0 ? s.income / maxVal : 0.0;
          final expFrac = maxVal > 0 ? s.expense / maxVal : 0.0;
          final netColor = s.net >= 0 ? _green : _red;
          // Alternating month label color
          final labelColor = _palette[i % _palette.length];
          return pw.Container(
            color: i.isEven ? _tintTeal : _tintGreen,
            padding: const pw.EdgeInsets.fromLTRB(20, 6, 20, 6),
            child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
              pw.SizedBox(width: 50,
                child: pw.Text(s.label,
                  style: pw.TextStyle(font: _boldFont, fontSize: 8.5, color: labelColor))),
              pw.Expanded(
                child: pw.Column(children: [
                  pw.Row(children: [
                    pw.SizedBox(width: 36,
                      child: pw.Text('Income',
                        style: pw.TextStyle(font: _regFont, fontSize: 6.5, color: _green))),
                    pw.Expanded(child: _hBar(incFrac, _green, h: 6)),
                  ]),
                  pw.SizedBox(height: 3),
                  pw.Row(children: [
                    pw.SizedBox(width: 36,
                      child: pw.Text('Expense',
                        style: pw.TextStyle(font: _regFont, fontSize: 6.5, color: _red))),
                    pw.Expanded(child: _hBar(expFrac, _red, h: 6)),
                  ]),
                ]),
              ),
              pw.SizedBox(width: 6),
              pw.SizedBox(width: 60,
                child: pw.Text('+₹${_fmtAmt(s.income)}',
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(font: _regFont, fontSize: 7.5, color: _green))),
              pw.SizedBox(width: 60,
                child: pw.Text('-₹${_fmtAmt(s.expense)}',
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(font: _regFont, fontSize: 7.5, color: _red))),
              pw.SizedBox(width: 60,
                child: pw.Text(
                  '${s.net >= 0 ? '+' : '-'}₹${_fmtAmt(s.net.abs())}',
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(font: _boldFont, fontSize: 8, color: netColor))),
            ]),
          );
        }),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PDF — Section 06: Insights
  // ═══════════════════════════════════════════════════════════════════════════

  static pw.Widget _insightsSection(
    Map<String, double> stats,
    List<_AccountStat> accounts,
    List<_CategoryStat> categories,
    List<_MerchantStat> merchants,
    List<_MonthStat> months,
    List<Transaction> txns,
  ) {
    final bullets = <Map<String, String>>[];
    final income = stats['income']!;
    final expense = stats['expense']!;

    if (income > 0) {
      final rate = ((income - expense) / income * 100).clamp(0.0, 100.0);
      bullets.add({'text': 'Savings rate: ${rate.toStringAsFixed(1)}% — Rs ${_fmtAmt((income - expense).clamp(0, double.infinity))} saved from Rs ${_fmtAmt(income)} income.', 'tag': 'SAVE'});
    }
    if (categories.isNotEmpty) {
      final top = categories.first;
      final pct = expense > 0 ? top.amount / expense * 100 : 0.0;
      bullets.add({'text': 'Top category: ${top.name.isEmpty ? 'Uncategorised' : top.name} = ${pct.toStringAsFixed(0)}% of expenses (Rs ${_fmtAmt(top.amount)}, ${top.count} transactions).', 'tag': 'CAT'});
    }
    if (accounts.isNotEmpty) {
      final top = accounts.reduce((a, b) => a.count > b.count ? a : b);
      final pct = txns.isNotEmpty ? top.count / txns.length * 100 : 0.0;
      bullets.add({'text': 'Most active: ${top.name} with ${top.count} transactions (${pct.toStringAsFixed(0)}% of all activity).', 'tag': 'ACCT'});
    }
    if (merchants.isNotEmpty) {
      final top = merchants.first;
      bullets.add({'text': 'Top merchant: ${top.name} — Rs ${_fmtAmt(top.amount)} across ${top.count} transactions (avg Rs ${_fmtAmt(top.avg)}).', 'tag': 'MRCH'});
    }
    if (months.length > 1) {
      final peak = months.reduce((a, b) => a.expense > b.expense ? a : b);
      bullets.add({'text': 'Peak expense month: ${peak.label} — Rs ${_fmtAmt(peak.expense)} spent.', 'tag': 'PEAK'});
    }
    final expTxns = txns.where((t) => t.type == TransactionType.expense || t.type == TransactionType.lending).toList();
    if (expTxns.isNotEmpty) {
      final avg = expTxns.fold<double>(0, (s, t) => s + t.amount) / expTxns.length;
      bullets.add({'text': 'Average expense transaction: Rs ${_fmtAmt(avg)} across ${expTxns.length} expense records.', 'tag': 'AVG'});
    }
    if (txns.length > 1) {
      final sorted = txns.map((t) => t.dateTime).toList()..sort();
      final days = sorted.last.difference(sorted.first).inDays + 1;
      if (days > 1 && expense > 0) {
        bullets.add({'text': 'Period span: $days days — average daily expenditure Rs ${_fmtAmt(expense / days)}.', 'tag': 'DAYS'});
      }
    }

    return pw.Column(
      children: bullets.asMap().entries.map((entry) {
        final i     = entry.key;
        final b     = entry.value;
        final color = _palette[i % _palette.length];
        final tint  = _paletteTint[i % _paletteTint.length];
        return pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 5),
          padding: const pw.EdgeInsets.fromLTRB(14, 8, 14, 8),
          decoration: pw.BoxDecoration(
            color: tint,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
            border: pw.Border(left: pw.BorderSide(color: color, width: 4)),
          ),
          child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
            pw.Container(
              width: 26,
              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: pw.BoxDecoration(
                color: color,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
              ),
              alignment: pw.Alignment.center,
              child: pw.Text(b['tag']!,
                style: pw.TextStyle(font: _boldFont, fontSize: 5.5, color: PdfColors.white)),
            ),
            pw.SizedBox(width: 8),
            pw.Expanded(
              child: pw.Text(b['text']!,
                style: pw.TextStyle(font: _regFont, fontSize: 8.5, color: const PdfColor(0.14, 0.18, 0.26))),
            ),
          ]),
        );
      }).toList(),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PDF — Section 07: Transaction Table
  // ═══════════════════════════════════════════════════════════════════════════

  static pw.Widget _hdrText(String t, {bool right = false}) => pw.Text(t,
    textAlign: right ? pw.TextAlign.right : pw.TextAlign.left,
    style: pw.TextStyle(font: _boldFont, fontSize: 7,
      color: PdfColors.white, letterSpacing: 0.6));

  static pw.Widget _tableHeaderRow() {
    return pw.Container(
      height: 26, color: _th,
      padding: const pw.EdgeInsets.symmetric(horizontal: 24),
      child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
        pw.SizedBox(width: 58,  child: _hdrText('DATE')),
        pw.SizedBox(width: 68,  child: _hdrText('TYPE')),
        pw.Expanded(            child: _hdrText('DESCRIPTION')),
        pw.SizedBox(width: 80,  child: _hdrText('AMOUNT', right: true)),
        pw.SizedBox(width: 88,  child: _hdrText('ACCOUNT')),
      ]),
    );
  }

  static pw.Widget _tableDataRow(Transaction t, bool even) {
    final meta      = t.metadata ?? {};
    final eventType = meta['investmentEventType'] as String?;
    final isCredit  = _isCredit(t.type, eventType);
    final typeColor = _typeColor(t.type, eventType);
    final amtColor  = isCredit ? _green : _red;
    final amtStr    = '${isCredit ? '+' : '-'}₹${_fmtAmt(t.amount)}';
    final description = (meta['description'] ?? meta['merchant'] ?? t.description ?? t.getSummary()).toString();
    final account   = (meta['accountName'] ?? t.sourceAccountName ?? '').toString();
    final typeLabel = _typeLabel(t.type, eventType);
    // Subtle tinted row based on type
    final rowBg = even
        ? PdfColor(typeColor.red * 0.04 + 0.96, typeColor.green * 0.04 + 0.96, typeColor.blue * 0.04 + 0.95)
        : PdfColors.white;

    return pw.Container(
      constraints: const pw.BoxConstraints(minHeight: 20),
      color: rowBg,
      padding: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
        pw.SizedBox(width: 58,
          child: pw.Text(_fmtDateShort(t.dateTime),
            style: pw.TextStyle(font: _regFont, fontSize: 7.5, color: _greyMid))),
        pw.SizedBox(width: 68,
          child: pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: pw.BoxDecoration(
              color: PdfColor(typeColor.red * 0.14 + 0.86, typeColor.green * 0.14 + 0.86, typeColor.blue * 0.14 + 0.86),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
            ),
            child: pw.Text(typeLabel,
              style: pw.TextStyle(font: _boldFont, fontSize: 6.5, color: typeColor)),
          )),
        pw.Expanded(
          child: pw.Text(
            description.length > 40 ? '${description.substring(0, 40)}...' : description,
            style: pw.TextStyle(font: _regFont, fontSize: 8.5, color: const PdfColor(0.12, 0.15, 0.20)))),
        pw.SizedBox(width: 80,
          child: pw.Text(amtStr, textAlign: pw.TextAlign.right,
            style: pw.TextStyle(font: _boldFont, fontSize: 8.5, color: amtColor))),
        pw.SizedBox(width: 88,
          child: pw.Text(
            account.length > 14 ? '${account.substring(0, 14)}...' : account,
            style: pw.TextStyle(font: _regFont, fontSize: 7.5, color: _greyMid))),
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // EXCEL — Sheet 1: Summary (with advanced formulas)
  // ═══════════════════════════════════════════════════════════════════════════

  static void _buildSummarySheet(
    Excel excel, String label,
    Map<String, double> stats,
    List<Transaction> txns,
    List<_AccountStat> acctStats,
  ) {
    final s = excel['Summary'];
    final tx = 'Transactions'; // sheet name for cross-sheet formulas
    final dr = 8;              // first data row (1-indexed) in Transactions sheet
    final de = 7 + txns.length;

    // ── Branding ──
    _xc(s, 0, 0, '$_appName — $label',        _xs(bold: true, fs: 18, fh: '#0A1929'));
    _xc(s, 1, 0, _tagline,                     _xs(fs: 9, fh: '#7B5CEF', italic: true));
    _xc(s, 2, 0, 'Generated: ${_fmtDateTime(DateTime.now())}  |  ${txns.length} transactions  |  ${_buildDateRange(txns)}',
                                               _xs(fs: 8, fh: '#6B7280', italic: true));

    // ── Key Metrics header ──
    _xc(s, 4, 0, 'KEY METRICS', _xs(bold: true, fs: 11, fh: '#0A1929'));
    const mh = ['Metric', 'Amount (₹)', 'Formula Used', 'Notes'];
    for (int i = 0; i < mh.length; i++) {
      _xc(s, 5, i, mh[i], _xs(bold: true, fs: 9, fh: '#FFFFFF', bg: '#0A1929', ha: HorizontalAlign.Center));
    }

    // Row data: [label, formula, description, bg, fgHex]
    final metrics = [
      ['Total Income',
        'IFERROR(SUMPRODUCT(($tx!C$dr:C$de="Income")*$tx!F$dr:F$de)'
        '+SUMPRODUCT(($tx!C$dr:C$de="Cashback")*$tx!F$dr:F$de)'
        '+SUMPRODUCT(($tx!C$dr:C$de="Borrowing")*$tx!F$dr:F$de),0)',
        'SUMPRODUCT of income + cashback + borrowing types', '#F0FDF4', '#1CB045'],
      ['Total Expenses',
        'IFERROR(SUMPRODUCT(($tx!C$dr:C$de="Expense")*$tx!F$dr:F$de)'
        '+SUMPRODUCT(($tx!C$dr:C$de="Lending")*$tx!F$dr:F$de),0)',
        'SUMPRODUCT of expense + lending types', '#FFF1F0', '#EB4235'],
      ['Net Flow',       'IFERROR(B7-B8,0)',
        'Income minus Expenses (cross-ref B7–B8)', '#F0FDFA', '#00B399'],
      ['Total Invested',
        'IFERROR(SUMPRODUCT(($tx!C$dr:C$de="Investment")*$tx!F$dr:F$de),0)',
        'SUMPRODUCT of investment type rows', '#F5F3FF', '#5957D6'],
      ['Transfers',
        'IFERROR(SUMPRODUCT(($tx!C$dr:C$de="Transfer")*$tx!F$dr:F$de),0)',
        'SUMPRODUCT of transfer type rows', '#EFF6FF', '#007AFF'],
      ['Transaction Count', null, 'Total record count', '#F9FAFB', '#0A1929'],
    ];

    for (int i = 0; i < metrics.length; i++) {
      final m   = metrics[i];
      final row = 6 + i;
      _xc(s, row, 0, m[0], _xs(bold: true, fs: 9, fh: '#374151', bg: m[3]));
      if (m[1] != null) {
        _xf(s, row, 1, m[1]!, _xs(bold: true, fs: 12, fh: m[4]!, bg: m[3]));
      } else {
        _xc(s, row, 1, txns.length.toDouble(), _xs(bold: true, fs: 12, fh: m[4]!, bg: m[3]));
      }
      _xc(s, row, 2, m[1] ?? 'Direct value', _xs(fs: 7, fh: '#6B7280', bg: m[3], italic: true));
      _xc(s, row, 3, m[2], _xs(fs: 8, fh: '#6B7280', bg: m[3], italic: true));
    }

    // ── Derived metrics ──
    _xc(s, 13, 0, 'DERIVED METRICS', _xs(bold: true, fs: 11, fh: '#0A1929'));
    final derived = [
      ['Savings Rate (%)',        'IFERROR((B7-B8)/B7*100,0)',           'Percentage of income saved'],
      ['Expense Ratio (%)',       'IFERROR(B8/B7*100,0)',                'Expenses as % of income'],
      ['Avg Expense Transaction', 'IFERROR(AVERAGEIF($tx!C$dr:C$de,"Expense",$tx!F$dr:F$de),0)', 'Average per expense record'],
      ['Largest Single Expense',  'IFERROR(MAXIFS($tx!F$dr:F$de,$tx!C$dr:C$de,"Expense"),0)',    'Maximum single expense value'],
      ['Smallest Expense',        'IFERROR(MINIFS($tx!F$dr:F$de,$tx!C$dr:C$de,"Expense"),0)',    'Minimum single expense value'],
      ['Expense Std Dev',         'IFERROR(STDEV(IF($tx!C$dr:C$de="Expense",$tx!F$dr:F$de)),0)','Volatility of spending'],
      ['Expense Txn Count',       'IFERROR(COUNTIF($tx!C$dr:C$de,"Expense"),0)',                 'Number of expense records'],
      ['Income Txn Count',        'IFERROR(COUNTIF($tx!C$dr:C$de,"Income"),0)',                  'Number of income records'],
    ];
    for (int i = 0; i < derived.length; i++) {
      final d   = derived[i];
      final row = 14 + i;
      final bg  = i.isEven ? '#FFFFFF' : '#F9FAFB';
      _xc(s, row, 0, d[0], _xs(bold: true, fs: 9, fh: '#374151', bg: bg));
      _xf(s, row, 1, d[1], _xs(bold: true, fs: 11, fh: '#1CB045', bg: bg));
      _xc(s, row, 3, d[2], _xs(fs: 8, fh: '#6B7280', bg: bg, italic: true));
    }

    // ── Account summary ──
    _xc(s, 24, 0, 'ACCOUNT SUMMARY', _xs(bold: true, fs: 11, fh: '#0A1929'));
    const ah = ['Account', 'Income', 'Expenses', 'Net', 'Transactions', '% of Activity'];
    for (int i = 0; i < ah.length; i++) {
      _xc(s, 25, i, ah[i], _xs(bold: true, fs: 9, fh: '#FFFFFF', bg: '#0A1929', ha: HorizontalAlign.Center));
    }
    final totalAct = acctStats.fold<double>(0, (sum, a) => sum + a.totalActivity);
    for (int i = 0; i < acctStats.length; i++) {
      final a  = acctStats[i];
      final bg = i.isEven ? '#FFFFFF' : '#F9FAFB';
      final pct = totalAct > 0 ? a.totalActivity / totalAct * 100 : 0.0;
      _xc(s, 26 + i, 0, a.name,   _xs(bold: true, fs: 9, fh: '#111827', bg: bg));
      _xc(s, 26 + i, 1, a.income, _xs(fs: 9, fh: '#1CB045', bg: bg));
      _xc(s, 26 + i, 2, a.expense,_xs(fs: 9, fh: '#EB4235', bg: bg));
      _xc(s, 26 + i, 3, a.net,    _xs(bold: true, fs: 9, fh: a.net >= 0 ? '#1CB045' : '#EB4235', bg: bg));
      _xc(s, 26 + i, 4, a.count.toDouble(), _xs(fs: 9, fh: '#374151', bg: bg, ha: HorizontalAlign.Center));
      _xc(s, 26 + i, 5, double.parse(pct.toStringAsFixed(1)), _xs(fs: 9, fh: '#7B5CEF', bg: bg));
    }

    s.setColumnWidth(0, 30.0); s.setColumnWidth(1, 18.0);
    s.setColumnWidth(2, 42.0); s.setColumnWidth(3, 38.0);
    s.setColumnWidth(4, 16.0); s.setColumnWidth(5, 14.0);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // EXCEL — Sheet 2: Transactions (with running balance)
  // ═══════════════════════════════════════════════════════════════════════════

  static void _buildTransactionsSheet(Excel excel, List<Transaction> txns, String label) {
    final s   = excel['Transactions'];
    final now = DateTime.now();

    _xc(s, 0, 0, '$_appName — $label', _xs(bold: true, fs: 14, fh: '#0A1929'));
    _xc(s, 1, 0, 'Generated: ${_fmtDateTime(now)}  |  ${txns.length} transactions  |  ${_buildDateRange(txns)}',
        _xs(fs: 8, fh: '#6B7280', italic: true));

    // Stats block row 3-4
    final st = _computeStats(txns);
    const sl = ['INCOME','EXPENSES','NET FLOW','TRANSFERS','INVESTMENTS','COUNT'];
    final sv = [st['income']!, st['expense']!, st['net']!, st['transfer']!, st['investment']!, st['count']!];
    const sc = ['#1CB045','#EB4235','#00B399','#00B399','#5957D6','#0A1929'];
    for (int i = 0; i < sl.length; i++) {
      _xc(s, 3, i, sl[i], _xs(bold: true, fs: 7, fh: '#6B7280'));
      _xc(s, 4, i, i == 5 ? sv[i].toInt() : sv[i], _xs(bold: true, fs: 13, fh: sc[i]));
    }

    // Headers row 6 (0-indexed)
    const hdrs = ['Date','Time','Type','Description','Merchant','Amount (₹)','Flow','Account','Category','Tags','Running Balance'];
    for (int i = 0; i < hdrs.length; i++) {
      _xc(s, 6, i, hdrs[i], _xs(bold: true, fs: 9, fh: '#FFFFFF', bg: '#0A1929', ha: HorizontalAlign.Center));
    }

    // Data rows — row 7 (0-indexed) = row 8 (1-indexed)
    for (int i = 0; i < txns.length; i++) {
      final t   = txns[i];
      final meta = t.metadata ?? {};
      final row = 7 + i;
      final bg  = i.isEven ? '#FFFFFF' : '#F3F4F6';
      final ev  = meta['investmentEventType'] as String?;
      final isC = _isCredit(t.type, ev);
      final th  = _typeHex(t.type, ev);
      final desc    = (meta['description'] ?? meta['merchant'] ?? t.description ?? t.getSummary()).toString();
      final merch   = (meta['merchant'] ?? '').toString();
      final acct    = (meta['accountName'] ?? t.sourceAccountName ?? '').toString();
      final cat     = (meta['categoryName'] ?? '').toString();
      final tags    = (meta['tags'] as List?)?.join(', ') ?? '';

      CellStyle b() => _xs(fs: 9, bg: bg);

      _xc(s, row, 0,  _fmtSlash(t.dateTime), b());
      _xc(s, row, 1,  '${t.dateTime.hour.toString().padLeft(2,'0')}:${t.dateTime.minute.toString().padLeft(2,'0')}', b());
      _xc(s, row, 2,  t.getTypeLabel(),    _xs(fs: 9, bold: true, fh: th, bg: bg));
      _xc(s, row, 3,  desc, b());
      _xc(s, row, 4,  merch, b());
      _xc(s, row, 5,  t.amount, _xs(fs: 9, bold: true, fh: th, bg: bg));
      _xc(s, row, 6,  isC ? 'Inflow' : 'Outflow', _xs(fs: 9, bold: true, fh: th, bg: bg));
      _xc(s, row, 7,  acct, b());
      _xc(s, row, 8,  cat, b());
      _xc(s, row, 9,  tags, b());
      // Running balance column K (index 10): cumulative signed sum
      if (i == 0) {
        _xf(s, row, 10, 'IF(G8="Inflow",F8,-F8)', _xs(fs: 9, bold: true, fh: '#374151', bg: bg));
      } else {
        final prev = row; // previous row 1-indexed = row (0-indexed)
        _xf(s, row, 10, 'K$prev+IF(G${row+1}="Inflow",F${row+1},-F${row+1})',
            _xs(fs: 9, bold: true, fh: '#374151', bg: bg));
      }
    }

    // Totals
    final tot = 7 + txns.length;
    _xc(s, tot, 3, 'TOTALS', _xs(bold: true, fs: 9, fh: '#FFFFFF', bg: '#0A1929'));
    _xf(s, tot, 5, 'SUM(F8:F${tot})', _xs(bold: true, fs: 9, fh: '#FFFFFF', bg: '#0A1929'));

    const cw = [14.0,8.0,13.0,38.0,22.0,14.0,10.0,22.0,18.0,26.0,16.0];
    for (int i = 0; i < cw.length; i++) s.setColumnWidth(i, cw[i]);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // EXCEL — Sheet 3: By Account (with RANK + formulas)
  // ═══════════════════════════════════════════════════════════════════════════

  static void _buildByAccountSheet(Excel excel, List<_AccountStat> stats, Map<String, double> gStats) {
    final s = excel['By Account'];
    _xc(s, 0, 0, '$_appName — Account Breakdown', _xs(bold: true, fs: 14, fh: '#0A1929'));
    _xc(s, 1, 0, 'Income, expenses, net flow and rank for each account',
        _xs(fs: 8, fh: '#6B7280', italic: true));

    const h = ['Account','Income (₹)','Expenses (₹)','Net Flow (₹)','Transfers (₹)','Investments (₹)','Transactions','% Activity','Rank by Activity'];
    for (int i = 0; i < h.length; i++) {
      _xc(s, 3, i, h[i], _xs(bold: true, fs: 9, fh: '#FFFFFF', bg: '#0A1929', ha: HorizontalAlign.Center));
    }

    final totalAct = stats.fold<double>(0, (sum, a) => sum + a.totalActivity);
    final n = stats.length;

    for (int i = 0; i < n; i++) {
      final a  = stats[i];
      final bg = i.isEven ? '#FFFFFF' : '#F9FAFB';
      final pct = totalAct > 0 ? a.totalActivity / totalAct * 100 : 0.0;
      final dr  = 5 + i; // 1-indexed row
      _xc(s, 4+i, 0, a.name,       _xs(bold: true, fs: 9, fh: '#111827', bg: bg));
      _xc(s, 4+i, 1, a.income,     _xs(fs: 9, fh: '#1CB045', bg: bg));
      _xc(s, 4+i, 2, a.expense,    _xs(fs: 9, fh: '#EB4235', bg: bg));
      _xc(s, 4+i, 3, a.net,        _xs(bold: true, fs: 9, fh: a.net >= 0 ? '#1CB045' : '#EB4235', bg: bg));
      _xc(s, 4+i, 4, a.transfer,   _xs(fs: 9, fh: '#00B399', bg: bg));
      _xc(s, 4+i, 5, a.investment, _xs(fs: 9, fh: '#5957D6', bg: bg));
      _xc(s, 4+i, 6, a.count.toDouble(), _xs(fs: 9, fh: '#374151', bg: bg, ha: HorizontalAlign.Center));
      _xc(s, 4+i, 7, double.parse(pct.toStringAsFixed(1)), _xs(fs: 9, fh: '#7B5CEF', bg: bg));
      // RANK by income descending
      _xf(s, 4+i, 8, 'IFERROR(RANK(B$dr,B\$5:B\$${4+n},0),"-")',
          _xs(bold: true, fs: 9, fh: '#FF9500', bg: bg, ha: HorizontalAlign.Center));
    }

    // Totals row
    final tot = 4 + n;
    _xc(s, tot, 0, 'TOTAL', _xs(bold: true, fs: 9, fh: '#FFFFFF', bg: '#374151'));
    _xf(s, tot, 1, 'SUM(B5:B${tot})', _xs(bold: true, fs: 9, fh: '#1CB045', bg: '#F0FDF4'));
    _xf(s, tot, 2, 'SUM(C5:C${tot})', _xs(bold: true, fs: 9, fh: '#EB4235', bg: '#FFF1F0'));
    _xf(s, tot, 3, 'B${tot+1}-C${tot+1}',
        _xs(bold: true, fs: 9, fh: gStats['net']! >= 0 ? '#1CB045' : '#EB4235', bg: '#F0FDFA'));
    _xf(s, tot, 6, 'SUM(G5:G${tot})', _xs(bold: true, fs: 9, fh: '#374151', bg: '#F9FAFB'));
    _xf(s, tot, 7, 'SUM(H5:H${tot})', _xs(bold: true, fs: 9, fh: '#7B5CEF', bg: '#F5F3FF'));

    const cw = [28.0,16.0,16.0,16.0,16.0,16.0,14.0,14.0,14.0];
    for (int i = 0; i < cw.length; i++) s.setColumnWidth(i, cw[i]);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // EXCEL — Sheet 4: By Category (RANK + cumulative %)
  // ═══════════════════════════════════════════════════════════════════════════

  static void _buildByCategorySheet(Excel excel, List<_CategoryStat> stats, double totalExpense) {
    final s = excel['By Category'];
    _xc(s, 0, 0, '$_appName — Category Breakdown', _xs(bold: true, fs: 14, fh: '#0A1929'));
    _xc(s, 1, 0, 'All expense categories sorted by amount — with rank, avg, and cumulative share',
        _xs(fs: 8, fh: '#6B7280', italic: true));

    const h = ['Category','Total Spent (₹)','Txn Count','Avg / Txn (₹)','% of Expenses','Cumulative %','Rank'];
    for (int i = 0; i < h.length; i++) {
      _xc(s, 3, i, h[i], _xs(bold: true, fs: 9, fh: '#FFFFFF', bg: '#0A1929', ha: HorizontalAlign.Center));
    }

    final n = stats.length;
    for (int i = 0; i < n; i++) {
      final c  = stats[i];
      final bg = i.isEven ? '#FFFFFF' : '#F9FAFB';
      final pct = totalExpense > 0 ? c.amount / totalExpense * 100 : 0.0;
      final dr  = 5 + i;
      _xc(s, 4+i, 0, c.name.isEmpty ? 'Uncategorised' : c.name,
          _xs(bold: true, fs: 9, fh: '#111827', bg: bg));
      _xc(s, 4+i, 1, c.amount, _xs(fs: 9, fh: '#EB4235', bg: bg));
      _xc(s, 4+i, 2, c.count.toDouble(), _xs(fs: 9, fh: '#374151', bg: bg, ha: HorizontalAlign.Center));
      // Avg formula
      _xf(s, 4+i, 3, 'IFERROR(B$dr/C$dr,0)', _xs(fs: 9, fh: '#374151', bg: bg));
      _xc(s, 4+i, 4, double.parse(pct.toStringAsFixed(2)), _xs(fs: 9, fh: '#7B5CEF', bg: bg));
      // Cumulative % — running SUM from top to this row divided by grand total
      if (i == 0) {
        _xf(s, 4+i, 5, 'IFERROR(E5,0)', _xs(fs: 9, fh: '#00B399', bg: bg));
      } else {
        _xf(s, 4+i, 5, 'IFERROR(F${dr-1}+E$dr,0)', _xs(fs: 9, fh: '#00B399', bg: bg));
      }
      // RANK by amount
      _xf(s, 4+i, 6, 'IFERROR(RANK(B$dr,B\$5:B\$${4+n},0),"-")',
          _xs(bold: true, fs: 9, fh: '#FF9500', bg: bg, ha: HorizontalAlign.Center));
    }

    // Totals
    final tot = 4 + n;
    _xc(s, tot, 0, 'TOTAL', _xs(bold: true, fs: 9, fh: '#FFFFFF', bg: '#374151'));
    _xf(s, tot, 1, 'SUM(B5:B${tot})', _xs(bold: true, fs: 9, fh: '#EB4235', bg: '#FFF1F0'));
    _xf(s, tot, 2, 'SUM(C5:C${tot})', _xs(bold: true, fs: 9, fh: '#374151', bg: '#F9FAFB'));
    _xf(s, tot, 4, 'SUM(E5:E${tot})', _xs(bold: true, fs: 9, fh: '#7B5CEF', bg: '#F5F3FF'));

    const cw = [28.0,18.0,14.0,18.0,16.0,16.0,10.0];
    for (int i = 0; i < cw.length; i++) s.setColumnWidth(i, cw[i]);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // EXCEL — Sheet 5: By Merchant (RANK + MAXIFS per merchant)
  // ═══════════════════════════════════════════════════════════════════════════

  static void _buildByMerchantSheet(Excel excel, List<_MerchantStat> stats) {
    final s = excel['By Merchant'];
    _xc(s, 0, 0, '$_appName — Merchant & App Breakdown', _xs(bold: true, fs: 14, fh: '#0A1929'));
    _xc(s, 1, 0, 'Top merchants by total spend — sorted descending',
        _xs(fs: 8, fh: '#6B7280', italic: true));

    const h = ['Merchant / App','Total Spent (₹)','Txn Count','Avg / Txn (₹)','Max Txn (₹)','% of Merchant Total','Rank'];
    for (int i = 0; i < h.length; i++) {
      _xc(s, 3, i, h[i], _xs(bold: true, fs: 9, fh: '#FFFFFF', bg: '#0A1929', ha: HorizontalAlign.Center));
    }

    final n    = stats.length;
    final gran = stats.fold<double>(0, (s, m) => s + m.amount);

    for (int i = 0; i < n; i++) {
      final m  = stats[i];
      final bg = i.isEven ? '#FFFFFF' : '#F9FAFB';
      final dr  = 5 + i;
      final pct = gran > 0 ? m.amount / gran * 100 : 0.0;
      _xc(s, 4+i, 0, m.name.isEmpty ? 'Unknown' : m.name,
          _xs(bold: true, fs: 9, fh: '#111827', bg: bg));
      _xc(s, 4+i, 1, m.amount, _xs(fs: 9, fh: '#007AFF', bg: bg));
      _xc(s, 4+i, 2, m.count.toDouble(), _xs(fs: 9, fh: '#374151', bg: bg, ha: HorizontalAlign.Center));
      // Avg formula
      _xf(s, 4+i, 3, 'IFERROR(B$dr/C$dr,0)', _xs(fs: 9, fh: '#374151', bg: bg));
      _xc(s, 4+i, 4, m.maxTxn, _xs(fs: 9, fh: '#E03050', bg: bg));
      _xc(s, 4+i, 5, double.parse(pct.toStringAsFixed(2)), _xs(fs: 9, fh: '#7B5CEF', bg: bg));
      // RANK
      _xf(s, 4+i, 6, 'IFERROR(RANK(B$dr,B\$5:B\$${4+n},0),"-")',
          _xs(bold: true, fs: 9, fh: '#FF9500', bg: bg, ha: HorizontalAlign.Center));
    }

    // Totals
    final tot = 4 + n;
    _xc(s, tot, 0, 'TOTAL', _xs(bold: true, fs: 9, fh: '#FFFFFF', bg: '#374151'));
    _xf(s, tot, 1, 'SUM(B5:B${tot})', _xs(bold: true, fs: 9, fh: '#007AFF', bg: '#EFF6FF'));
    _xf(s, tot, 2, 'SUM(C5:C${tot})', _xs(bold: true, fs: 9, fh: '#374151', bg: '#F9FAFB'));
    _xf(s, tot, 5, 'SUM(F5:F${tot})', _xs(bold: true, fs: 9, fh: '#7B5CEF', bg: '#F5F3FF'));

    const cw = [28.0,18.0,14.0,18.0,16.0,16.0,10.0];
    for (int i = 0; i < cw.length; i++) s.setColumnWidth(i, cw[i]);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // EXCEL — Sheet 6: Monthly Trends (MoM % change)
  // ═══════════════════════════════════════════════════════════════════════════

  static void _buildMonthlyTrendsSheet(Excel excel, List<_MonthStat> months) {
    if (months.isEmpty) return;
    final s = excel['Monthly Trends'];
    _xc(s, 0, 0, '$_appName — Monthly Trends', _xs(bold: true, fs: 14, fh: '#0A1929'));
    _xc(s, 1, 0, 'Month-over-month income, expense, net flow and % change',
        _xs(fs: 8, fh: '#6B7280', italic: true));

    const h = ['Month','Income (₹)','Expenses (₹)','Net Flow (₹)','MoM Income Δ%','MoM Expense Δ%','Savings Rate %'];
    for (int i = 0; i < h.length; i++) {
      _xc(s, 3, i, h[i], _xs(bold: true, fs: 9, fh: '#FFFFFF', bg: '#0A1929', ha: HorizontalAlign.Center));
    }

    final n = months.length;
    for (int i = 0; i < n; i++) {
      final m  = months[i];
      final bg = i.isEven ? '#FFFFFF' : '#F9FAFB';
      final dr = 5 + i;
      _xc(s, 4+i, 0, m.label,   _xs(bold: true, fs: 9, fh: '#111827', bg: bg));
      _xc(s, 4+i, 1, m.income,  _xs(fs: 9, fh: '#1CB045', bg: bg));
      _xc(s, 4+i, 2, m.expense, _xs(fs: 9, fh: '#EB4235', bg: bg));
      _xc(s, 4+i, 3, m.net,     _xs(bold: true, fs: 9, fh: m.net >= 0 ? '#1CB045' : '#EB4235', bg: bg));
      // MoM income % change: (this - prev) / prev * 100
      if (i == 0) {
        _xc(s, 4+i, 4, 'N/A', _xs(fs: 9, fh: '#9CA3AF', bg: bg));
        _xc(s, 4+i, 5, 'N/A', _xs(fs: 9, fh: '#9CA3AF', bg: bg));
      } else {
        _xf(s, 4+i, 4, 'IFERROR((B$dr-B${dr-1})/B${dr-1}*100,0)',
            _xs(fs: 9, fh: '#00B399', bg: bg));
        _xf(s, 4+i, 5, 'IFERROR((C$dr-C${dr-1})/C${dr-1}*100,0)',
            _xs(fs: 9, fh: '#E03050', bg: bg));
      }
      // Savings rate this month
      _xf(s, 4+i, 6, 'IFERROR((B$dr-C$dr)/B$dr*100,0)',
          _xs(fs: 9, fh: '#7B5CEF', bg: bg));
    }

    // Totals / averages
    final tot = 4 + n;
    _xc(s, tot, 0, 'TOTAL', _xs(bold: true, fs: 9, fh: '#FFFFFF', bg: '#374151'));
    _xf(s, tot, 1, 'SUM(B5:B${tot})',  _xs(bold: true, fs: 9, fh: '#1CB045', bg: '#F0FDF4'));
    _xf(s, tot, 2, 'SUM(C5:C${tot})',  _xs(bold: true, fs: 9, fh: '#EB4235', bg: '#FFF1F0'));
    _xf(s, tot, 3, 'B${tot+1}-C${tot+1}', _xs(bold: true, fs: 9, fh: '#00B399', bg: '#F0FDFA'));

    _xc(s, tot+2, 0, 'AVERAGES', _xs(bold: true, fs: 9, fh: '#FFFFFF', bg: '#374151'));
    _xf(s, tot+2, 1, 'IFERROR(AVERAGE(B5:B${tot}),0)', _xs(bold: true, fs: 9, fh: '#1CB045', bg: '#F0FDF4'));
    _xf(s, tot+2, 2, 'IFERROR(AVERAGE(C5:C${tot}),0)', _xs(bold: true, fs: 9, fh: '#EB4235', bg: '#FFF1F0'));
    _xf(s, tot+2, 3, 'IFERROR(AVERAGE(D5:D${tot}),0)', _xs(bold: true, fs: 9, fh: '#00B399', bg: '#F0FDFA'));
    _xf(s, tot+2, 6, 'IFERROR(AVERAGE(G5:G${tot}),0)', _xs(bold: true, fs: 9, fh: '#7B5CEF', bg: '#F5F3FF'));

    const cw = [16.0,18.0,18.0,18.0,18.0,18.0,16.0];
    for (int i = 0; i < cw.length; i++) s.setColumnWidth(i, cw[i]);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Excel helper — short-named setters
  // ═══════════════════════════════════════════════════════════════════════════

  static void _xc(Sheet sheet, int row, int col, dynamic value, CellStyle? style) {
    final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
    if (value is String)       cell.value = TextCellValue(value);
    else if (value is int)     cell.value = IntCellValue(value);
    else if (value is double)  cell.value = DoubleCellValue(value);
    if (style != null) cell.cellStyle = style;
  }

  static void _xf(Sheet sheet, int row, int col, String formula, CellStyle? style) {
    final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
    cell.value = FormulaCellValue(formula);
    if (style != null) cell.cellStyle = style;
  }

  static CellStyle _xs({
    bool bold = false, bool italic = false,
    int fs = 10,
    String fh = '#000000',
    String? bg,
    HorizontalAlign? ha,
  }) {
    if (bg != null && ha != null) {
      return CellStyle(bold: bold, italic: italic, fontSize: fs,
        fontColorHex: ExcelColor.fromHexString(fh),
        backgroundColorHex: ExcelColor.fromHexString(bg),
        horizontalAlign: ha);
    }
    if (bg != null) {
      return CellStyle(bold: bold, italic: italic, fontSize: fs,
        fontColorHex: ExcelColor.fromHexString(fh),
        backgroundColorHex: ExcelColor.fromHexString(bg));
    }
    if (ha != null) {
      return CellStyle(bold: bold, italic: italic, fontSize: fs,
        fontColorHex: ExcelColor.fromHexString(fh),
        horizontalAlign: ha);
    }
    return CellStyle(bold: bold, italic: italic, fontSize: fs,
      fontColorHex: ExcelColor.fromHexString(fh));
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Data computation
  // ═══════════════════════════════════════════════════════════════════════════

  static Map<String, double> _computeStats(List<Transaction> txns) {
    double income = 0, expense = 0, transfer = 0, investment = 0;
    for (final t in txns) {
      switch (t.type) {
        case TransactionType.income:
        case TransactionType.cashback:
        case TransactionType.borrowing:
          income += t.amount; break;
        case TransactionType.expense:
        case TransactionType.lending:
          expense += t.amount; break;
        case TransactionType.transfer:
          transfer += t.amount; break;
        case TransactionType.investment:
          investment += t.amount; break;
      }
    }
    return {'income': income, 'expense': expense, 'net': income - expense,
            'transfer': transfer, 'investment': investment, 'count': txns.length.toDouble()};
  }

  static List<_AccountStat> _byAccount(List<Transaction> txns) {
    final map = <String, _AccountStat>{};
    for (final t in txns) {
      final meta = t.metadata ?? {};
      final name = (meta['accountName'] ?? t.sourceAccountName ?? 'Unknown').toString();
      final s = map.putIfAbsent(name, () => _AccountStat(name));
      s.count++;
      switch (t.type) {
        case TransactionType.income: case TransactionType.cashback: case TransactionType.borrowing:
          s.income += t.amount; break;
        case TransactionType.expense: case TransactionType.lending:
          s.expense += t.amount; break;
        case TransactionType.transfer:   s.transfer += t.amount;   break;
        case TransactionType.investment: s.investment += t.amount; break;
      }
    }
    return map.values.toList()..sort((a, b) => b.totalActivity.compareTo(a.totalActivity));
  }

  static List<_CategoryStat> _byCategory(List<Transaction> txns) {
    final map = <String, _CategoryStat>{};
    for (final t in txns) {
      if (t.type != TransactionType.expense && t.type != TransactionType.lending) continue;
      final name = ((t.metadata ?? {})['categoryName'] ?? '').toString();
      final s = map.putIfAbsent(name, () => _CategoryStat(name));
      s.amount += t.amount; s.count++;
    }
    return map.values.toList()..sort((a, b) => b.amount.compareTo(a.amount));
  }

  static List<_MerchantStat> _byMerchant(List<Transaction> txns) {
    final map = <String, _MerchantStat>{};
    for (final t in txns) {
      if (t.type != TransactionType.expense && t.type != TransactionType.lending) continue;
      final name = ((t.metadata ?? {})['merchant'] ?? '').toString().trim();
      if (name.isEmpty) continue;
      final s = map.putIfAbsent(name, () => _MerchantStat(name));
      s.amount += t.amount; s.count++;
      if (t.amount > s.maxTxn) s.maxTxn = t.amount;
    }
    return map.values.toList()..sort((a, b) => b.amount.compareTo(a.amount));
  }

  static List<_MonthStat> _byMonth(List<Transaction> txns) {
    final map = <int, _MonthStat>{};
    for (final t in txns) {
      final key = t.dateTime.year * 100 + t.dateTime.month;
      final s = map.putIfAbsent(key, () => _MonthStat(_monthLabel(t.dateTime), key));
      switch (t.type) {
        case TransactionType.income: case TransactionType.cashback: case TransactionType.borrowing:
          s.income += t.amount; break;
        case TransactionType.expense: case TransactionType.lending:
          s.expense += t.amount; break;
        default: break;
      }
    }
    return map.values.toList()..sort((a, b) => a.sortKey.compareTo(b.sortKey));
  }

  static List<Map<String, dynamic>> _byType(List<Transaction> txns, Map<String, double> stats) {
    final counts = <TransactionType, int>{};
    for (final t in txns) counts[t.type] = (counts[t.type] ?? 0) + 1;

    double lendAmt = 0, borrowAmt = 0;
    int lendCnt = 0, borrowCnt = 0;
    for (final t in txns) {
      if (t.type == TransactionType.lending)  { lendAmt += t.amount;   lendCnt++; }
      if (t.type == TransactionType.borrowing) { borrowAmt += t.amount; borrowCnt++; }
    }
    final entries = [
      {'label': 'Income',     'amount': stats['income']!,     'color': _green,       'type': TransactionType.income},
      {'label': 'Expense',    'amount': stats['expense']!,    'color': _red,         'type': TransactionType.expense},
      {'label': 'Investment', 'amount': stats['investment']!, 'color': _indigo,      'type': TransactionType.investment},
      {'label': 'Transfer',   'amount': stats['transfer']!,   'color': _brandTeal,   'type': TransactionType.transfer},
      if (lendAmt > 0)   {'label': 'Lending',   'amount': lendAmt,   'color': _orange, 'type': TransactionType.lending},
      if (borrowAmt > 0) {'label': 'Borrowing', 'amount': borrowAmt, 'color': _purple, 'type': TransactionType.borrowing},
    ];
    return entries
        .where((e) => (e['amount'] as double) > 0)
        .map((e) => {...e, 'count': counts[e['type']] ?? 0})
        .toList();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Type helpers
  // ═══════════════════════════════════════════════════════════════════════════

  static bool _isCredit(TransactionType type, String? ev) {
    if (ev == 'sell' || ev == 'decrease' || ev == 'dividend') return true;
    return type == TransactionType.income || type == TransactionType.cashback || type == TransactionType.borrowing;
  }

  static PdfColor _typeColor(TransactionType type, String? ev) {
    if (ev == 'dividend')                        return _amber;
    if (ev == 'sell' || ev == 'decrease')        return _green;
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

  static String _typeHex(TransactionType type, String? ev) {
    if (ev == 'dividend')                        return '#FFB800';
    if (ev == 'sell' || ev == 'decrease')        return '#00C876';
    switch (type) {
      case TransactionType.income:     return '#00C876';
      case TransactionType.cashback:   return '#00C876';
      case TransactionType.expense:    return '#E03050';
      case TransactionType.transfer:   return '#00B890';
      case TransactionType.investment: return '#7B5CEF';
      case TransactionType.lending:    return '#FF9500';
      case TransactionType.borrowing:  return '#AF52DE';
    }
  }

  static String _typeLabel(TransactionType type, String? ev) {
    if (ev == 'dividend')                        return 'Dividend';
    if (ev == 'sell' || ev == 'decrease')        return 'Sell';
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

  // ═══════════════════════════════════════════════════════════════════════════
  // Formatting helpers
  // ═══════════════════════════════════════════════════════════════════════════

  static String _buildDateRange(List<Transaction> txns) {
    if (txns.isEmpty) return 'No date range';
    final sorted = txns.map((t) => t.dateTime).toList()..sort();
    final from = _fmtDate(sorted.first);
    final to   = _fmtDate(sorted.last);
    return from == to ? from : '$from – $to';
  }

  static const _mo = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];

  static String _fmtDate(DateTime d) => '${d.day} ${_mo[d.month - 1]} ${d.year}';
  static String _fmtDateShort(DateTime d) =>
      '${d.day.toString().padLeft(2, ' ')} ${_mo[d.month - 1]}\'${d.year.toString().substring(2)}';
  static String _fmtDateTime(DateTime d) =>
      '${_fmtDate(d)}, ${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';
  static String _fmtSlash(DateTime d) =>
      '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';
  static String _monthLabel(DateTime d) => "${_mo[d.month - 1]} '${d.year.toString().substring(2)}";

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
