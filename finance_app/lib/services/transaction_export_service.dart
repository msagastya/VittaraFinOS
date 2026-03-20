import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:excel/excel.dart';
import 'package:vittara_fin_os/logic/transaction_model.dart';

/// Generates beautifully styled PDF and XLSX exports for transaction lists.
class TransactionExportService {
  static const _appName = 'VittaraFinOS';
  static const _tagline = 'Track Wealth, Master Life';

  // ─── Color Palette ────────────────────────────────────────────────────────
  static const _navy    = PdfColor(0.04, 0.10, 0.16);
  static const _navyMid = PdfColor(0.07, 0.17, 0.26);
  static const _teal    = PdfColor(0.00, 0.70, 0.60);
  static const _green   = PdfColor(0.11, 0.69, 0.27);
  static const _red     = PdfColor(0.92, 0.26, 0.21);
  static const _indigo  = PdfColor(0.35, 0.34, 0.84);
  static const _orange  = PdfColor(0.96, 0.57, 0.04);
  static const _purple  = PdfColor(0.55, 0.33, 0.85);
  static const _amber   = PdfColor(1.00, 0.72, 0.00);
  static const _row0    = PdfColors.white;
  static const _row1    = PdfColor(0.96, 0.97, 0.98);
  static const _grey3   = PdfColor(0.55, 0.55, 0.60);
  static const _th      = PdfColor(0.11, 0.23, 0.32);

  // ─── Public API ──────────────────────────────────────────────────────────

  static Future<File> buildPdf(
    List<Transaction> transactions, {
    String title = 'Transaction Statement',
    String? accountName,
  }) async {
    final doc = pw.Document();
    final stats = _computeStats(transactions);
    final dateRange = _buildDateRange(transactions);
    final now = DateTime.now();
    final label = accountName ?? title;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        header: (ctx) => _pageHeader(label, now, ctx),
        footer: (ctx) => _pageFooter(now, ctx),
        build: (ctx) => [
          _infoBand(label, dateRange),
          _statsRow(stats),
          pw.SizedBox(height: 4),
          _tableHeaderRow(),
          ...transactions.asMap().entries.map(
            (e) => _tableDataRow(e.value, e.key.isEven),
          ),
          pw.SizedBox(height: 8),
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

    // Remove default blank sheet
    excel.delete('Sheet1');

    final sheet = excel['Transactions'];
    final stats = _computeStats(transactions);
    final now = DateTime.now();
    final label = accountName ?? title;

    // ── Title ──
    _setCell(sheet, 0, 0, '$_appName — $label', CellStyle(
      bold: true,
      fontSize: 16,
      fontColorHex: ExcelColor.fromHexString('#0A1929'),
    ));
    _setCell(sheet, 1, 0,
      'Generated: ${_fmtDateTime(now)}  |  ${transactions.length} transactions  |  Range: ${_buildDateRange(transactions)}',
      CellStyle(fontSize: 9, fontColorHex: ExcelColor.fromHexString('#6B7280'), italic: true),
    );

    // ── Stats labels (row 3, 0-indexed = 3) ──
    final statLabels  = ['INCOME', 'EXPENSES', 'NET FLOW', 'TRANSFERS', 'INVESTMENTS', 'COUNT'];
    final statValues  = [stats['income']!, stats['expense']!, stats['net']!, stats['transfer']!, stats['investment']!, stats['count']!];
    final statColors  = ['#1CB045', '#EB4235', '#00B399', '#00B399', '#5957D6', '#0A1929'];
    for (int i = 0; i < statLabels.length; i++) {
      _setCell(sheet, 3, i, statLabels[i], CellStyle(
        bold: true, fontSize: 8,
        fontColorHex: ExcelColor.fromHexString('#6B7280'),
      ));
      _setCell(sheet, 4, i, i == 5 ? statValues[i].toInt() : statValues[i], CellStyle(
        bold: true, fontSize: 14,
        fontColorHex: ExcelColor.fromHexString(statColors[i]),
      ));
    }

    // ── Column headers (row 6) ──
    const headers = ['Date', 'Time', 'Type', 'Description', 'Merchant', 'Amount (₹)', 'Flow', 'Account', 'Category', 'Tags'];
    for (int i = 0; i < headers.length; i++) {
      _setCell(sheet, 6, i, headers[i], CellStyle(
        bold: true,
        fontSize: 10,
        backgroundColorHex: ExcelColor.fromHexString('#0A1929'),
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
        horizontalAlign: HorizontalAlign.Center,
      ));
    }

    // ── Data rows (starting row 7) ──
    for (int i = 0; i < transactions.length; i++) {
      final t = transactions[i];
      final meta = t.metadata ?? {};
      final row = 7 + i;
      final bg = i.isEven ? '#FFFFFF' : '#F3F4F6';
      final eventType = meta['investmentEventType'] as String?;
      final isCredit = _isCredit(t.type, eventType);
      final typeHex = _typeHex(t.type, eventType);
      // Amount sign: green for inflow, red for outflow — matches type color for transfers/investments
      final amtColor = typeHex;

      final description = (meta['description'] ?? meta['merchant'] ?? t.description ?? t.getSummary()).toString();
      final merchant = (meta['merchant'] ?? '').toString();
      final account = (meta['accountName'] ?? t.sourceAccountName ?? '').toString();
      final category = (meta['categoryName'] ?? '').toString();
      final tags = (meta['tags'] as List?)?.join(', ') ?? '';

      CellStyle base() => CellStyle(fontSize: 10, backgroundColorHex: ExcelColor.fromHexString(bg));

      _setCell(sheet, row, 0, _fmtSlash(t.dateTime), base());
      _setCell(sheet, row, 1, '${t.dateTime.hour.toString().padLeft(2,'0')}:${t.dateTime.minute.toString().padLeft(2,'0')}', base());
      _setCell(sheet, row, 2, t.getTypeLabel(), CellStyle(
        fontSize: 10, bold: true,
        backgroundColorHex: ExcelColor.fromHexString(bg),
        fontColorHex: ExcelColor.fromHexString(typeHex),
      ));
      _setCell(sheet, row, 3, description, base());
      _setCell(sheet, row, 4, merchant, base());
      _setCell(sheet, row, 5, t.amount, CellStyle(
        fontSize: 10, bold: true,
        backgroundColorHex: ExcelColor.fromHexString(bg),
        fontColorHex: ExcelColor.fromHexString(amtColor),
      ));
      _setCell(sheet, row, 6, isCredit ? 'Inflow' : 'Outflow', CellStyle(
        fontSize: 10, bold: true,
        backgroundColorHex: ExcelColor.fromHexString(bg),
        fontColorHex: ExcelColor.fromHexString(typeHex),
      ));
      _setCell(sheet, row, 7, account, base());
      _setCell(sheet, row, 8, category, base());
      _setCell(sheet, row, 9, tags, base());
    }

    // ── Column widths ──
    final colWidths = [14.0, 8.0, 13.0, 36.0, 20.0, 14.0, 10.0, 22.0, 18.0, 25.0];
    for (int i = 0; i < colWidths.length; i++) {
      sheet.setColumnWidth(i, colWidths[i]);
    }

    final bytes = excel.encode()!;
    final dir = await _reportDir();
    final file = File('${dir.path}/transactions_${_timestamp()}.xlsx');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  // ─── PDF Widgets ──────────────────────────────────────────────────────────

  static pw.Widget _pageHeader(String label, DateTime now, pw.Context ctx) {
    return pw.Container(
      height: 72,
      color: _navy,
      padding: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 12),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          // Logo circle
          pw.Container(
            width: 40, height: 40,
            decoration: pw.BoxDecoration(
              color: _teal,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(20)),
            ),
            alignment: pw.Alignment.center,
            child: pw.Text('V', style: pw.TextStyle(
              font: pw.Font.helveticaBold(), fontSize: 20, color: PdfColors.white,
            )),
          ),
          pw.SizedBox(width: 12),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text(_appName, style: pw.TextStyle(
                font: pw.Font.helveticaBold(), fontSize: 15, color: PdfColors.white,
                letterSpacing: 1.5,
              )),
              pw.SizedBox(height: 3),
              pw.Text('Transaction Statement', style: pw.TextStyle(
                font: pw.Font.helveticaOblique(), fontSize: 8,
                color: const PdfColor(0.60, 0.72, 0.82),
              )),
            ],
          ),
          pw.Spacer(),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text('Generated ${_fmtDate(now)}', style: pw.TextStyle(
                font: pw.Font.helvetica(), fontSize: 7.5,
                color: const PdfColor(0.60, 0.72, 0.82),
              )),
              pw.SizedBox(height: 5),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: pw.BoxDecoration(
                  color: _teal,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                  style: pw.TextStyle(
                    font: pw.Font.helveticaBold(), fontSize: 7.5, color: PdfColors.white,
                  )),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _pageFooter(DateTime now, pw.Context ctx) {
    return pw.Container(
      height: 28,
      padding: const pw.EdgeInsets.symmetric(horizontal: 28),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColor(0.86, 0.87, 0.90), width: 0.8)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Container(
            width: 5, height: 16,
            decoration: pw.BoxDecoration(
              color: _teal,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
            ),
          ),
          pw.SizedBox(width: 6),
          pw.Text(_appName, style: pw.TextStyle(
            font: pw.Font.helveticaBold(), fontSize: 7.5,
            color: const PdfColor(0.35, 0.40, 0.45),
          )),
          pw.Text('  $_tagline', style: pw.TextStyle(
            font: pw.Font.helveticaOblique(), fontSize: 7,
            color: const PdfColor(0.60, 0.60, 0.65),
          )),
          pw.Spacer(),
          pw.Text('Confidential • For Personal Use Only', style: pw.TextStyle(
            font: pw.Font.helvetica(), fontSize: 7,
            color: const PdfColor(0.65, 0.65, 0.70),
          )),
        ],
      ),
    );
  }

  static pw.Widget _infoBand(String label, String dateRange) {
    return pw.Container(
      color: _navyMid,
      padding: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 8),
      child: pw.Row(
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: pw.BoxDecoration(
              color: const PdfColor(0.00, 0.50, 0.43),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.Text(label, style: pw.TextStyle(
              font: pw.Font.helveticaBold(), fontSize: 8, color: PdfColors.white,
            )),
          ),
          pw.Spacer(),
          pw.Text(dateRange, style: pw.TextStyle(
            font: pw.Font.helvetica(), fontSize: 8,
            color: const PdfColor(0.70, 0.80, 0.88),
          )),
        ],
      ),
    );
  }

  static pw.Widget _statsRow(Map<String, double> stats) {
    final net = stats['net']!;
    return pw.Container(
      color: const PdfColor(0.95, 0.96, 0.97),
      padding: const pw.EdgeInsets.fromLTRB(20, 10, 20, 10),
      child: pw.Row(
        children: [
          _statCard('INCOME', 'Rs ${_fmtAmt(stats['income']!)}', _green, '+'),
          pw.SizedBox(width: 8),
          _statCard('EXPENSES', 'Rs ${_fmtAmt(stats['expense']!)}', _red, '-'),
          pw.SizedBox(width: 8),
          _statCard(
            'NET FLOW',
            '${net >= 0 ? '+' : '-'}Rs ${_fmtAmt(net.abs())}',
            net >= 0 ? _green : _red, '~',
          ),
          pw.SizedBox(width: 8),
          _statCard('TRANSACTIONS', '${stats['count']!.toInt()}', _teal, '#'),
          pw.SizedBox(width: 8),
          _statCard('INVESTED', 'Rs ${_fmtAmt(stats['investment']!)}', _indigo, '*'),
        ],
      ),
    );
  }

  static pw.Widget _statCard(String label, String value, PdfColor accent, String symbol) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.fromLTRB(8, 7, 8, 7),
        decoration: pw.BoxDecoration(
          color: PdfColors.white,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
          border: pw.Border(left: pw.BorderSide(color: accent, width: 3.5)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              children: [
                pw.Text(symbol, style: pw.TextStyle(
                  font: pw.Font.helveticaBold(), fontSize: 9, color: accent,
                )),
                pw.SizedBox(width: 3),
                pw.Text(label, style: pw.TextStyle(
                  font: pw.Font.helvetica(), fontSize: 6.5,
                  color: const PdfColor(0.55, 0.55, 0.62),
                )),
              ],
            ),
            pw.SizedBox(height: 4),
            pw.Text(value, style: pw.TextStyle(
              font: pw.Font.helveticaBold(), fontSize: 11, color: accent,
            )),
          ],
        ),
      ),
    );
  }

  static pw.Widget _tableHeaderRow() {
    return pw.Container(
      height: 24,
      color: _th,
      padding: const pw.EdgeInsets.symmetric(horizontal: 28),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.SizedBox(width: 60,  child: _thText('DATE')),
          pw.SizedBox(width: 70,  child: _thText('TYPE')),
          pw.Expanded(            child: _thText('DESCRIPTION')),
          pw.SizedBox(width: 76,  child: _thText('AMOUNT', right: true)),
          pw.SizedBox(width: 90,  child: _thText('ACCOUNT')),
        ],
      ),
    );
  }

  static pw.Widget _thText(String t, {bool right = false}) => pw.Text(t,
    textAlign: right ? pw.TextAlign.right : pw.TextAlign.left,
    style: pw.TextStyle(
      font: pw.Font.helveticaBold(), fontSize: 7,
      color: const PdfColor(0.70, 0.82, 0.92), letterSpacing: 0.8,
    ),
  );

  static pw.Widget _tableDataRow(Transaction t, bool even) {
    final meta = t.metadata ?? {};
    final eventType = meta['investmentEventType'] as String?;
    final isCredit = _isCredit(t.type, eventType);
    final typeColor = _typeColor(t.type, eventType);
    final amtColor = isCredit ? _green : _red;
    final amtStr = '${isCredit ? '+' : '-'}Rs ${_fmtAmt(t.amount)}';
    final description = (meta['description'] ?? meta['merchant'] ?? t.description ?? t.getSummary()).toString();
    final account = (meta['accountName'] ?? t.sourceAccountName ?? '').toString();
    final typeLabel = _typeLabel(t.type, eventType);

    return pw.Container(
      constraints: const pw.BoxConstraints(minHeight: 20),
      color: even ? _row0 : _row1,
      padding: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          // Date
          pw.SizedBox(
            width: 60,
            child: pw.Text(_fmtDateShort(t.dateTime), style: pw.TextStyle(
              font: pw.Font.helvetica(), fontSize: 7.5, color: _grey3,
            )),
          ),
          // Type badge
          pw.SizedBox(
            width: 70,
            child: pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: pw.BoxDecoration(
                color: PdfColor(typeColor.red * 0.13, typeColor.green * 0.13, typeColor.blue * 0.13),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
              ),
              child: pw.Text(typeLabel, style: pw.TextStyle(
                font: pw.Font.helveticaBold(), fontSize: 6.5, color: typeColor,
              )),
            ),
          ),
          // Description
          pw.Expanded(
            child: pw.Text(
              description.length > 38 ? '${description.substring(0, 38)}…' : description,
              style: pw.TextStyle(
                font: pw.Font.helvetica(), fontSize: 8.5,
                color: const PdfColor(0.12, 0.15, 0.20),
              ),
            ),
          ),
          // Amount
          pw.SizedBox(
            width: 76,
            child: pw.Text(amtStr, textAlign: pw.TextAlign.right, style: pw.TextStyle(
              font: pw.Font.helveticaBold(), fontSize: 8.5, color: amtColor,
            )),
          ),
          // Account
          pw.SizedBox(
            width: 90,
            child: pw.Text(
              account.length > 15 ? '${account.substring(0, 15)}…' : account,
              style: pw.TextStyle(font: pw.Font.helvetica(), fontSize: 7.5, color: _grey3),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

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
    return {
      'income': income, 'expense': expense,
      'net': income - expense, 'transfer': transfer,
      'investment': investment, 'count': txns.length.toDouble(),
    };
  }

  static bool _isCredit(TransactionType type, String? eventType) {
    if (eventType == 'sell' || eventType == 'decrease' || eventType == 'dividend') return true;
    return type == TransactionType.income ||
        type == TransactionType.cashback ||
        type == TransactionType.borrowing;
  }

  static PdfColor _typeColor(TransactionType type, String? eventType) {
    if (eventType == 'dividend') return _amber;
    if (eventType == 'sell' || eventType == 'decrease') return _green;
    switch (type) {
      case TransactionType.income:   return _green;
      case TransactionType.cashback: return _green;
      case TransactionType.expense:  return _red;
      case TransactionType.transfer: return _teal;
      case TransactionType.investment: return _indigo;
      case TransactionType.lending:  return _orange;
      case TransactionType.borrowing: return _purple;
    }
  }

  static String _typeHex(TransactionType type, String? eventType) {
    if (eventType == 'dividend') return '#FFB800';
    if (eventType == 'sell' || eventType == 'decrease') return '#1CB045';
    switch (type) {
      case TransactionType.income:   return '#1CB045';
      case TransactionType.cashback: return '#1CB045';
      case TransactionType.expense:  return '#EB4235';
      case TransactionType.transfer: return '#00B399';
      case TransactionType.investment: return '#5957D6';
      case TransactionType.lending:  return '#F5920A';
      case TransactionType.borrowing: return '#8B55D9';
    }
  }

  static String _typeLabel(TransactionType type, String? eventType) {
    if (eventType == 'dividend') return 'Dividend';
    if (eventType == 'sell' || eventType == 'decrease') return 'Sell';
    switch (type) {
      case TransactionType.income:   return 'Income';
      case TransactionType.cashback: return 'Cashback';
      case TransactionType.expense:  return 'Expense';
      case TransactionType.transfer: return 'Transfer';
      case TransactionType.investment: return 'Invest';
      case TransactionType.lending:  return 'Lend';
      case TransactionType.borrowing: return 'Borrow';
    }
  }

  static String _buildDateRange(List<Transaction> txns) {
    if (txns.isEmpty) return 'No date range';
    final sorted = txns.map((t) => t.dateTime).toList()..sort();
    final from = _fmtDate(sorted.first);
    final to   = _fmtDate(sorted.last);
    return from == to ? from : '$from – $to';
  }

  static const _months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];

  static String _fmtDate(DateTime d) =>
      '${d.day} ${_months[d.month - 1]} ${d.year}';

  static String _fmtDateShort(DateTime d) =>
      '${d.day.toString().padLeft(2,' ')} ${_months[d.month - 1]}\'${d.year.toString().substring(2)}';

  static String _fmtDateTime(DateTime d) =>
      '${_fmtDate(d)}, ${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';

  static String _fmtSlash(DateTime d) =>
      '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';

  static String _fmtAmt(double v) {
    if (v >= 10000000) return '${(v / 10000000).toStringAsFixed(2)}Cr';
    if (v >= 100000)   return '${(v / 100000).toStringAsFixed(2)}L';
    if (v >= 1000)     return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }

  static void _setCell(Sheet sheet, int row, int col, dynamic value, CellStyle? style) {
    final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
    if (value is String) cell.value = TextCellValue(value);
    else if (value is int) cell.value = IntCellValue(value);
    else if (value is double) cell.value = DoubleCellValue(value);
    if (style != null) cell.cellStyle = style;
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
