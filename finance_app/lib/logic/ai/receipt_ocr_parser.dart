import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Extracted data from a receipt scan.
class ReceiptExtraction {
  final String? merchantName;
  final double? totalAmount;
  final DateTime? date;
  final List<String> lineItems;
  final double confidence; // 0.0–1.0

  const ReceiptExtraction({
    this.merchantName,
    this.totalAmount,
    this.date,
    required this.lineItems,
    required this.confidence,
  });

  bool get hasMinimumData => totalAmount != null;
}

/// On-device receipt OCR using ML Kit.
/// No images leave the device.
class ReceiptOcrParser {
  ReceiptOcrParser._();

  static Future<ReceiptExtraction> parse(File imageFile) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final recognized = await recognizer.processImage(inputImage);
      return _extractFromText(recognized.text, recognized.blocks);
    } finally {
      recognizer.close();
    }
  }

  static ReceiptExtraction _extractFromText(
    String fullText,
    List<TextBlock> blocks,
  ) {
    final lines = fullText.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

    String? merchant;
    double? total;
    DateTime? date;
    final lineItems = <String>[];
    double confidence = 0.0;

    // Merchant: usually in the first 3 lines, ALL CAPS or has known patterns
    for (int i = 0; i < lines.length.clamp(0, 4); i++) {
      final line = lines[i];
      if (line.length > 3 && !_looksLikeAmount(line) && !_looksLikeDate(line)) {
        // Prefer the longest header-looking line
        if (merchant == null || line.length > merchant.length) {
          merchant = _cleanMerchant(line);
        }
      }
    }

    // Total: look for "total", "grand total", "amount", "net payable"
    for (final line in lines) {
      final lower = line.toLowerCase();
      if (_matchesTotal(lower)) {
        final amt = _extractAmount(line);
        if (amt != null && (total == null || amt > total)) {
          total = amt;
        }
      }
    }

    // Date: look for date patterns
    for (final line in lines) {
      if (_looksLikeDate(line)) {
        date = _parseDate(line);
        if (date != null) break;
      }
    }

    // Line items: lines with price pattern (description + amount) in the middle
    for (final line in lines) {
      if (_looksLikeLineItem(line)) {
        lineItems.add(line.trim());
      }
    }

    // Confidence
    int signals = 0;
    if (merchant != null) signals++;
    if (total != null) signals++;
    if (date != null) signals++;
    if (lineItems.isNotEmpty) signals++;
    confidence = signals / 4.0;

    return ReceiptExtraction(
      merchantName: merchant,
      totalAmount: total,
      date: date,
      lineItems: lineItems.take(10).toList(),
      confidence: confidence,
    );
  }

  static bool _matchesTotal(String lower) {
    return lower.contains('total') ||
        lower.contains('grand total') ||
        lower.contains('net payable') ||
        lower.contains('amount payable') ||
        lower.contains('bill amount');
  }

  static bool _looksLikeAmount(String line) {
    return RegExp(r'[\d,]+\.?\d{0,2}\s*$').hasMatch(line) ||
        line.contains('₹') ||
        line.contains('rs');
  }

  static bool _looksLikeDate(String line) {
    return RegExp(r'\d{1,2}[/\-\.]\d{1,2}[/\-\.]\d{2,4}').hasMatch(line) ||
        RegExp(r'\d{1,2}\s+(?:jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)',
                caseSensitive: false)
            .hasMatch(line);
  }

  static bool _looksLikeLineItem(String line) {
    // Has text + amount at end
    return RegExp(r'^[A-Za-z].*[\d,]+\.?\d{0,2}\s*$').hasMatch(line) &&
        line.length > 5 &&
        !_matchesTotal(line.toLowerCase());
  }

  static double? _extractAmount(String line) {
    final patterns = [
      RegExp(r'(?:₹|rs\.?)\s*([\d,]+(?:\.\d{1,2})?)'),
      RegExp(r'([\d,]+\.\d{2})\s*$'),
      RegExp(r'([\d,]{3,})\s*$'),
    ];
    for (final p in patterns) {
      final m = p.firstMatch(line);
      if (m != null) {
        final v = double.tryParse(m.group(1)!.replaceAll(',', ''));
        if (v != null && v > 0) return v;
      }
    }
    return null;
  }

  static DateTime? _parseDate(String line) {
    // dd/mm/yyyy or dd-mm-yyyy
    final m1 = RegExp(r'(\d{1,2})[/\-\.](\d{1,2})[/\-\.](\d{2,4})').firstMatch(line);
    if (m1 != null) {
      final day = int.tryParse(m1.group(1)!) ?? 1;
      final month = int.tryParse(m1.group(2)!) ?? 1;
      var year = int.tryParse(m1.group(3)!) ?? DateTime.now().year;
      if (year < 100) year += 2000;
      return DateTime(year, month, day);
    }
    return null;
  }

  static String _cleanMerchant(String raw) {
    // Remove common noise
    return raw
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
