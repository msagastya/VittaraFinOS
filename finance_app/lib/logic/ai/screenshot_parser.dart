import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

enum PaymentApp { gpay, phonepe, paytm, cred, bhim, other }

class PaymentScreenshotData {
  final PaymentApp app;
  final double? amount;
  final String? recipient;
  final DateTime? date;
  final String? upiRef;
  final bool isSuccessful;
  final String rawText;

  const PaymentScreenshotData({
    required this.app,
    this.amount,
    this.recipient,
    this.date,
    this.upiRef,
    required this.isSuccessful,
    required this.rawText,
  });

  bool get hasMinimumData => amount != null;
}

/// Parses payment app screenshots (GPay, PhonePe, Paytm, Cred, BHIM) to
/// extract transaction details. On-device only — no images sent anywhere.
class ScreenshotParser {
  ScreenshotParser._();

  static Future<PaymentScreenshotData> parse(File imageFile) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final recognized = await recognizer.processImage(inputImage);
      return _extract(recognized.text);
    } finally {
      recognizer.close();
    }
  }

  static PaymentScreenshotData _extract(String text) {
    final lower = text.toLowerCase();
    final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

    // Detect app
    final app = _detectApp(lower);

    // Amount
    double? amount = _extractAmount(lines, lower);

    // Recipient
    String? recipient = _extractRecipient(lines, lower, app);

    // Date
    DateTime? date = _extractDate(lines);

    // UPI Ref
    String? upiRef = _extractUpiRef(text);

    // Success detection
    final isSuccessful = lower.contains('paid') ||
        lower.contains('sent') ||
        lower.contains('success') ||
        lower.contains('completed') ||
        lower.contains('₹') && !lower.contains('failed') && !lower.contains('declined');

    return PaymentScreenshotData(
      app: app,
      amount: amount,
      recipient: recipient,
      date: date,
      upiRef: upiRef,
      isSuccessful: isSuccessful,
      rawText: text,
    );
  }

  static PaymentApp _detectApp(String lower) {
    if (lower.contains('google pay') || lower.contains('gpay') || lower.contains('tez')) {
      return PaymentApp.gpay;
    }
    if (lower.contains('phonepe') || lower.contains('phone pe')) return PaymentApp.phonepe;
    if (lower.contains('paytm')) return PaymentApp.paytm;
    if (lower.contains('cred')) return PaymentApp.cred;
    if (lower.contains('bhim')) return PaymentApp.bhim;
    return PaymentApp.other;
  }

  static double? _extractAmount(List<String> lines, String lower) {
    // Priority: lines with ₹ symbol or "paid" context
    for (final line in lines) {
      final lineLower = line.toLowerCase();
      if (lineLower.contains('paid') || lineLower.contains('sent') ||
          lineLower.contains('amount')) {
        final amt = _parseAmount(line);
        if (amt != null) return amt;
      }
    }
    // Fall back: largest amount in the text
    double? largest;
    for (final line in lines) {
      final amt = _parseAmount(line);
      if (amt != null && (largest == null || amt > largest)) {
        largest = amt;
      }
    }
    return largest;
  }

  static double? _parseAmount(String line) {
    final patterns = [
      RegExp(r'₹\s*([\d,]+(?:\.\d{1,2})?)'),
      RegExp(r'(?:rs\.?|inr)\s*([\d,]+(?:\.\d{1,2})?)', caseSensitive: false),
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

  static String? _extractRecipient(List<String> lines, String lower, PaymentApp app) {
    // "Paid to <name>", "Sent to <name>", "To <name>"
    for (final line in lines) {
      final lineLower = line.toLowerCase();
      if (lineLower.startsWith('paid to') || lineLower.startsWith('sent to') ||
          lineLower.startsWith('to ')) {
        final parts = line.split(RegExp(r'\bto\b', caseSensitive: false));
        if (parts.length >= 2) {
          final name = parts.last.trim();
          if (name.isNotEmpty && name.length < 50) return name;
        }
      }
    }
    // App-specific patterns
    if (app == PaymentApp.gpay) {
      // GPay: recipient usually bold line after "You paid"
      for (int i = 0; i < lines.length - 1; i++) {
        if (lines[i].toLowerCase().contains('you paid')) {
          return lines[i + 1].trim();
        }
      }
    }
    return null;
  }

  static DateTime? _extractDate(List<String> lines) {
    for (final line in lines) {
      // dd Mon yyyy, dd/mm/yyyy, etc.
      final m1 = RegExp(
              r'(\d{1,2})\s+(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*[\s,]+(\d{4})',
              caseSensitive: false)
          .firstMatch(line);
      if (m1 != null) {
        final day = int.tryParse(m1.group(1)!) ?? 1;
        final month = _monthIndex(m1.group(2)!);
        final year = int.tryParse(m1.group(3)!) ?? DateTime.now().year;
        return DateTime(year, month, day);
      }
      final m2 = RegExp(r'(\d{1,2})[/\-](\d{1,2})[/\-](\d{2,4})').firstMatch(line);
      if (m2 != null) {
        final day = int.tryParse(m2.group(1)!) ?? 1;
        final month = int.tryParse(m2.group(2)!) ?? 1;
        var year = int.tryParse(m2.group(3)!) ?? DateTime.now().year;
        if (year < 100) year += 2000;
        return DateTime(year, month, day);
      }
    }
    return null;
  }

  static String? _extractUpiRef(String text) {
    // UPI ref IDs: 12-digit numbers
    final m = RegExp(r'\b(\d{12})\b').firstMatch(text);
    if (m != null) return m.group(1);
    // "Transaction ID: ..."
    final m2 = RegExp(r'(?:transaction\s*id|upi\s*ref|ref\s*no)[:\s]+([A-Z0-9]{8,})',
            caseSensitive: false)
        .firstMatch(text);
    if (m2 != null) return m2.group(1);
    return null;
  }

  static int _monthIndex(String abbr) {
    const months = ['jan', 'feb', 'mar', 'apr', 'may', 'jun',
                    'jul', 'aug', 'sep', 'oct', 'nov', 'dec'];
    final idx = months.indexOf(abbr.toLowerCase().substring(0, 3));
    return idx >= 0 ? idx + 1 : 1;
  }
}
