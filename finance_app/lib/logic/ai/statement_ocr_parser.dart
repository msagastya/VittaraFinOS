import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// A single row extracted from a bank statement.
class StatementRow {
  final DateTime date;
  final String description;
  final double? debit;
  final double? credit;
  final double? balance;
  bool isSelected; // for bulk review UI

  StatementRow({
    required this.date,
    required this.description,
    this.debit,
    this.credit,
    this.balance,
    this.isSelected = true,
  });

  bool get isExpense => debit != null && debit! > 0;
  double get amount => isExpense ? debit! : (credit ?? 0);
}

/// On-device bank statement OCR. Handles table-layout statements from
/// major Indian banks: HDFC, SBI, ICICI, Axis, Kotak.
class StatementOcrParser {
  StatementOcrParser._();

  static Future<List<StatementRow>> parse(File imageFile) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final recognized = await recognizer.processImage(inputImage);
      return _parseTable(recognized.text);
    } finally {
      recognizer.close();
    }
  }

  static List<StatementRow> _parseTable(String text) {
    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final rows = <StatementRow>[];

    for (final line in lines) {
      final row = _tryParseRow(line);
      if (row != null) rows.add(row);
    }

    // If line-by-line fails (table columns merged), try segment parsing
    if (rows.isEmpty) {
      return _parseSegmented(text);
    }

    return rows;
  }

  /// Try to parse a single statement row from a text line.
  static StatementRow? _tryParseRow(String line) {
    // Pattern: date | description | debit | credit | balance
    // Many OCR outputs blend columns — we look for a date + at least one amount

    final dateMatch = RegExp(
      r'^(\d{1,2}[/\-\.]\d{1,2}[/\-\.]\d{2,4})',
    ).firstMatch(line);
    if (dateMatch == null) return null;

    final date = _parseDate(dateMatch.group(1)!);
    if (date == null) return null;

    final rest = line.substring(dateMatch.end).trim();
    if (rest.isEmpty) return null;

    // Extract all amounts from rest
    final amounts = RegExp(r'([\d,]+\.\d{2})').allMatches(rest).map((m) {
      return double.tryParse(m.group(1)!.replaceAll(',', '')) ?? 0;
    }).where((v) => v > 0).toList();

    if (amounts.isEmpty) return null;

    // Description: everything before the first amount
    final firstAmtMatch = RegExp(r'[\d,]+\.\d{2}').firstMatch(rest);
    final desc = firstAmtMatch != null
        ? rest.substring(0, firstAmtMatch.start).trim()
        : rest;

    // Heuristic: if 3 amounts, last is balance, first is debit or credit
    double? debit, credit, balance;
    if (amounts.length >= 3) {
      balance = amounts.last;
      // Determine debit vs credit from description keywords
      final descLower = desc.toLowerCase();
      if (_looksLikeCredit(descLower)) {
        credit = amounts[0];
      } else {
        debit = amounts[0];
      }
    } else if (amounts.length == 2) {
      balance = amounts.last;
      if (_looksLikeCredit(desc.toLowerCase())) {
        credit = amounts[0];
      } else {
        debit = amounts[0];
      }
    } else {
      if (_looksLikeCredit(desc.toLowerCase())) {
        credit = amounts[0];
      } else {
        debit = amounts[0];
      }
    }

    if (desc.isEmpty) return null;

    return StatementRow(
      date: date,
      description: desc,
      debit: debit,
      credit: credit,
      balance: balance,
    );
  }

  /// Fallback: look for multi-line transaction blocks
  static List<StatementRow> _parseSegmented(String text) {
    final rows = <StatementRow>[];
    final datePattern = RegExp(r'\d{1,2}[/\-\.]\d{1,2}[/\-\.]\d{2,4}');
    final matches = datePattern.allMatches(text).toList();

    for (int i = 0; i < matches.length; i++) {
      final start = matches[i].start;
      final end = i + 1 < matches.length ? matches[i + 1].start : text.length;
      final segment = text.substring(start, end).trim();

      final date = _parseDate(matches[i].group(0)!);
      if (date == null) continue;

      final amounts = RegExp(r'([\d,]+\.\d{2})')
          .allMatches(segment)
          .map((m) => double.tryParse(m.group(1)!.replaceAll(',', '')) ?? 0)
          .where((v) => v > 0)
          .toList();

      final desc = segment
          .replaceAll(RegExp(r'\d{1,2}[/\-\.]\d{1,2}[/\-\.]\d{2,4}'), '')
          .replaceAll(RegExp(r'[\d,]+\.\d{2}'), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

      if (amounts.isEmpty || desc.isEmpty) continue;

      final segLower = segment.toLowerCase();
      rows.add(StatementRow(
        date: date,
        description: desc,
        debit: _looksLikeCredit(segLower) ? null : amounts.first,
        credit: _looksLikeCredit(segLower) ? amounts.first : null,
        balance: amounts.length > 1 ? amounts.last : null,
      ));
    }

    return rows;
  }

  static bool _looksLikeCredit(String lower) {
    return lower.contains('credit') ||
        lower.contains('salary') ||
        lower.contains('neft cr') ||
        lower.contains('imps cr') ||
        lower.contains('upi cr') ||
        lower.contains('refund') ||
        lower.contains('cashback') ||
        lower.contains('interest credited');
  }

  static DateTime? _parseDate(String s) {
    final m = RegExp(r'(\d{1,2})[/\-\.](\d{1,2})[/\-\.](\d{2,4})').firstMatch(s);
    if (m == null) return null;
    final day = int.tryParse(m.group(1)!) ?? 1;
    final month = int.tryParse(m.group(2)!) ?? 1;
    var year = int.tryParse(m.group(3)!) ?? DateTime.now().year;
    if (year < 100) year += 2000;
    if (month < 1 || month > 12) return null;
    return DateTime(year, month, day);
  }
}
