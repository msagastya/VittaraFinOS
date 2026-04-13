// ignore_for_file: use_build_context_synchronously
import 'dart:typed_data';
import 'package:excel/excel.dart' hide Border;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:vittara_fin_os/logic/account_model.dart';
import 'package:vittara_fin_os/logic/accounts_controller.dart';
import 'package:vittara_fin_os/logic/transaction_model.dart';
import 'package:vittara_fin_os/logic/transactions_controller.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/styles/responsive_utils.dart';
import 'package:vittara_fin_os/ui/widgets/animations.dart';
import 'package:vittara_fin_os/utils/id_generator.dart';

// ═══════════════════════════════════════════════════════════════════════════
// DATA MODELS
// ═══════════════════════════════════════════════════════════════════════════

enum _ImportStep {
  landing,      // Step 0: Pick file or paste CSV
  password,     // Step 1: Password for encrypted file
  accountPick,  // Step 2: Link to which account
  colMapping,   // Step 3: Map columns (CSV/XLS only)
  review,       // Step 4: Review + duplicate confirmation
  importing,    // Internal: processing
  done,         // Step 5: Done
}

enum _FileFormat { csv, pdf, xls, xlsx, none }
enum _CsvColumn { date, description, amount, debit, credit, reference, type, skip }
enum _BankFormat {
  hdfc, hdfcCc, sbi, icici, iciciCc, axis, kotak,
  indusind, yesBank, federal, rbl, idfc, amex, citi,
  bankOfBaroda,
  unknown
}

class _ParsedRow {
  final DateTime date;
  final String description;
  final double amount;
  bool isDebit; // true = expense, false = income — mutable so user can flip
  final String? reference;
  final String? rawLine;
  bool isDuplicate = false;
  bool includeIfDuplicate = false;

  _ParsedRow({
    required this.date,
    required this.description,
    required this.amount,
    required this.isDebit,
    this.reference,
    this.rawLine,
  });
}

const _csvColumnLabels = {
  _CsvColumn.date: 'Date',
  _CsvColumn.description: 'Description',
  _CsvColumn.amount: 'Amount',
  _CsvColumn.debit: 'Debit/Out',
  _CsvColumn.credit: 'Credit/In',
  _CsvColumn.reference: 'Reference',
  _CsvColumn.type: 'Type',
  _CsvColumn.skip: 'Skip',
};

// ═══════════════════════════════════════════════════════════════════════════
// PARSING UTILITIES
// ═══════════════════════════════════════════════════════════════════════════

/// RFC-4180-compliant CSV state-machine parser.
List<List<String>> _parseCsvText(String raw) {
  final rows = <List<String>>[];
  final cols = <String>[];
  var current = StringBuffer();
  var inQuotes = false;

  void finishField() {
    cols.add(current.toString().trim());
    current = StringBuffer();
  }

  void finishRow() {
    finishField();
    if (cols.isNotEmpty && cols.any((c) => c.isNotEmpty)) {
      rows.add(List<String>.from(cols));
    }
    cols.clear();
  }

  for (var i = 0; i < raw.length; i++) {
    final c = raw[i];
    if (inQuotes) {
      if (c == '"') {
        if (i + 1 < raw.length && raw[i + 1] == '"') {
          current.write('"');
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        current.write(c);
      }
    } else {
      if (c == '"') {
        inQuotes = true;
      } else if (c == ',') {
        finishField();
      } else if (c == '\t') {
        finishField(); // Also support TSV
      } else if (c == '\n') {
        finishRow();
      } else if (c == '\r') {
        // skip
      } else {
        current.write(c);
      }
    }
  }
  finishRow();
  return rows;
}

/// Parses many date formats used by Indian banks.
DateTime? _parseDate(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return null;

  // Try ISO 8601 first
  final iso = DateTime.tryParse(s);
  if (iso != null) return iso;

  // DD/MM/YYYY  DD-MM-YYYY  DD.MM.YYYY
  final dmy = RegExp(r'^(\d{1,2})[/\-\.](\d{1,2})[/\-\.](\d{4})$');
  var m = dmy.firstMatch(s);
  if (m != null) {
    try {
      return DateTime(int.parse(m.group(3)!), int.parse(m.group(2)!), int.parse(m.group(1)!));
    } catch (_) {}
  }

  // MM/DD/YYYY
  final mdy = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$');
  m = mdy.firstMatch(s);
  if (m != null) {
    final mo = int.tryParse(m.group(1)!);
    final dy = int.tryParse(m.group(2)!);
    final yr = int.tryParse(m.group(3)!);
    if (mo != null && dy != null && yr != null && mo <= 12 && dy <= 31) {
      try { return DateTime(yr, mo, dy); } catch (_) {}
    }
  }

  // DD MMM YYYY  (e.g. 01 Jan 2026 or 01-Jan-2026)
  final dMonthY = RegExp(
      r'^(\d{1,2})[\s\-\./]([A-Za-z]{3})[\s\-\./](\d{2,4})$');
  m = dMonthY.firstMatch(s);
  if (m != null) {
    const months = ['jan','feb','mar','apr','may','jun','jul','aug','sep','oct','nov','dec'];
    final monIdx = months.indexOf(m.group(2)!.toLowerCase());
    if (monIdx >= 0) {
      try {
        int yr = int.parse(m.group(3)!);
        if (yr < 100) yr += 2000;
        return DateTime(yr, monIdx + 1, int.parse(m.group(1)!));
      } catch (_) {}
    }
  }

  // YYYY/MM/DD
  final ymd2 = RegExp(r'^(\d{4})[/\-](\d{2})[/\-](\d{2})$');
  m = ymd2.firstMatch(s);
  if (m != null) {
    try {
      return DateTime(int.parse(m.group(1)!), int.parse(m.group(2)!), int.parse(m.group(3)!));
    } catch (_) {}
  }

  return null;
}

/// Parses amount strings: handles ₹, $, commas, Dr/Cr suffix, parentheses.
double? _parseAmount(String raw) {
  if (raw.trim().isEmpty) return null;
  var s = raw.trim()
      .replaceAll(RegExp(r'[₹\$,\s]'), '')
      .replaceAll('(', '-')
      .replaceAll(')', '');
  final isDr = s.toLowerCase().endsWith('dr');
  final isCr = s.toLowerCase().endsWith('cr');
  s = s.replaceAll(RegExp(r'[a-zA-Z]'), '');
  final v = double.tryParse(s);
  if (v == null) return null;
  if (isDr) return -v.abs();
  if (isCr) return v.abs();
  return v;
}

// ═══════════════════════════════════════════════════════════════════════════
// BANK DETECTION
// ═══════════════════════════════════════════════════════════════════════════

_BankFormat _detectBankFromHeaders(List<String> headers) {
  final joined = headers.join('|').toLowerCase();

  if (joined.contains('narration') && joined.contains('withdrawal amt')) return _BankFormat.hdfc;
  if (joined.contains('narration') && joined.contains('debit amount')) return _BankFormat.hdfc;
  if (joined.contains('transaction remarks') && joined.contains('withdrawal amount (inr)')) return _BankFormat.icici;
  if (joined.contains('txn date') && (joined.contains('debit') || joined.contains('withdrawal'))) return _BankFormat.sbi;
  if (joined.contains('tran date') && joined.contains('particulars') && joined.contains('debit')) return _BankFormat.axis;
  if (joined.contains('transaction date') && joined.contains('description') && joined.contains('debit') && joined.contains('credit')) {
    if (joined.contains('kotak')) return _BankFormat.kotak;
    if (joined.contains('indusind')) return _BankFormat.indusind;
    if (joined.contains('yes')) return _BankFormat.yesBank;
    return _BankFormat.kotak; // generic debit/credit split
  }
  if (joined.contains('date') && joined.contains('particulars') && joined.contains('withdrawals')) return _BankFormat.federal;
  if (joined.contains('posting date') && joined.contains('transaction description')) return _BankFormat.hdfcCc;
  if (joined.contains('statement date') && joined.contains('merchant')) return _BankFormat.amex;

  return _BankFormat.unknown;
}

_BankFormat _detectBankFromText(String text) {
  final t = text.toLowerCase();
  if (t.contains('bank of baroda') || t.contains('bankofbaroda') ||
      t.contains('barb0') || t.contains('baroda')) return _BankFormat.bankOfBaroda;
  if (t.contains('hdfc bank')) {
    return t.contains('credit card') ? _BankFormat.hdfcCc : _BankFormat.hdfc;
  }
  // HDFC CC without "HDFC Bank" text (Tata Neu Plus etc)
  if (t.contains('tata neu') && t.contains('credit card')) return _BankFormat.hdfcCc;
  if (t.contains('hdfc bank credit card')) return _BankFormat.hdfcCc;
  if (t.contains('state bank of india') || t.contains('sbi')) return _BankFormat.sbi;
  if (t.contains('icici bank')) return _BankFormat.icici;
  if (t.contains('axis bank')) return _BankFormat.axis;
  if (t.contains('kotak mahindra') || t.contains('kotak bank')) return _BankFormat.kotak;
  if (t.contains('indusind bank')) return _BankFormat.indusind;
  if (t.contains('yes bank')) return _BankFormat.yesBank;
  if (t.contains('federal bank')) return _BankFormat.federal;
  if (t.contains('rbl bank')) return _BankFormat.rbl;
  if (t.contains('idfc first bank') || t.contains('idfc bank')) return _BankFormat.idfc;
  if (t.contains('american express') || t.contains('amex')) return _BankFormat.amex;
  if (t.contains('citibank') || t.contains('citi bank')) return _BankFormat.citi;
  return _BankFormat.unknown;
}

String _bankDisplayName(_BankFormat f) {
  switch (f) {
    case _BankFormat.hdfc: return 'HDFC Bank';
    case _BankFormat.hdfcCc: return 'HDFC Credit Card';
    case _BankFormat.sbi: return 'SBI';
    case _BankFormat.icici: return 'ICICI Bank';
    case _BankFormat.iciciCc: return 'ICICI Credit Card';
    case _BankFormat.axis: return 'Axis Bank';
    case _BankFormat.kotak: return 'Kotak Bank';
    case _BankFormat.indusind: return 'IndusInd Bank';
    case _BankFormat.yesBank: return 'Yes Bank';
    case _BankFormat.federal: return 'Federal Bank';
    case _BankFormat.rbl: return 'RBL Bank';
    case _BankFormat.idfc: return 'IDFC First Bank';
    case _BankFormat.amex: return 'American Express';
    case _BankFormat.citi: return 'Citibank';
    case _BankFormat.bankOfBaroda: return 'Bank of Baroda';
    case _BankFormat.unknown: return 'Unknown Bank';
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// COLUMN AUTO-MAPPING
// ═══════════════════════════════════════════════════════════════════════════

Map<int, _CsvColumn> _buildColumnMapping(List<String> headers, _BankFormat format) {
  final mapping = <int, _CsvColumn>{};

  // Bank-specific known layouts (header substring → column role)
  final bankPatterns = <_BankFormat, Map<String, _CsvColumn>>{
    _BankFormat.hdfc: {
      'date': _CsvColumn.date,
      'narration': _CsvColumn.description,
      'chq': _CsvColumn.reference,
      'withdrawal amt': _CsvColumn.debit,
      'debit amount': _CsvColumn.debit,
      'deposit amt': _CsvColumn.credit,
      'credit amount': _CsvColumn.credit,
      'closing balance': _CsvColumn.skip,
    },
    _BankFormat.sbi: {
      'txn date': _CsvColumn.date,
      'value date': _CsvColumn.skip,
      'description': _CsvColumn.description,
      'ref no': _CsvColumn.reference,
      'debit': _CsvColumn.debit,
      'credit': _CsvColumn.credit,
      'balance': _CsvColumn.skip,
    },
    _BankFormat.icici: {
      'transaction date': _CsvColumn.date,
      'value date': _CsvColumn.skip,
      'transaction remarks': _CsvColumn.description,
      'chq': _CsvColumn.reference,
      'withdrawal amount': _CsvColumn.debit,
      'deposit amount': _CsvColumn.credit,
      'balance': _CsvColumn.skip,
    },
    _BankFormat.axis: {
      'tran date': _CsvColumn.date,
      'particulars': _CsvColumn.description,
      'chq': _CsvColumn.reference,
      'debit': _CsvColumn.debit,
      'credit': _CsvColumn.credit,
      'balance': _CsvColumn.skip,
    },
    _BankFormat.kotak: {
      'transaction date': _CsvColumn.date,
      'description': _CsvColumn.description,
      'cheque': _CsvColumn.reference,
      'debit': _CsvColumn.debit,
      'credit': _CsvColumn.credit,
      'balance': _CsvColumn.skip,
    },
  };

  final bp = bankPatterns[format] ?? {};

  for (var i = 0; i < headers.length; i++) {
    final h = headers[i].toLowerCase().trim();
    _CsvColumn? mapped;
    for (final entry in bp.entries) {
      if (h.contains(entry.key)) { mapped = entry.value; break; }
    }
    mapped ??= _heuristicColumn(h);
    mapping[i] = mapped;
  }
  return mapping;
}

_CsvColumn _heuristicColumn(String h) {
  if (h.contains('date') || h.contains('dt') || h == 'on') return _CsvColumn.date;
  if (h.contains('desc') || h.contains('narr') || h.contains('particular') ||
      h.contains('detail') || h.contains('remark') || h.contains('memo') ||
      h.contains('transaction') && h.contains('detail')) return _CsvColumn.description;
  if (h.contains('debit') || h.contains('withdrawal') || h.contains('dr') && h.length <= 6) {
    return _CsvColumn.debit;
  }
  if (h.contains('credit') && !h.contains('card') || h.contains('deposit') ||
      h == 'cr') return _CsvColumn.credit;
  if (h.contains('amount') || h.contains('amt')) return _CsvColumn.amount;
  if (h.contains('ref') || h.contains('chq') || h.contains('cheque') ||
      h.contains('transaction id')) return _CsvColumn.reference;
  if (h.contains('type') || h.contains('mode')) return _CsvColumn.type;
  return _CsvColumn.skip;
}

// ═══════════════════════════════════════════════════════════════════════════
// ML CATEGORIZATION ENGINE
// ═══════════════════════════════════════════════════════════════════════════

class _CategoryResult {
  final String categoryName;
  final TransactionType type;
  final String? merchant;

  const _CategoryResult(this.categoryName, this.type, {this.merchant});
}

_CategoryResult _categorize(String description) {
  final d = description.toLowerCase();

  // ── Income ──────────────────────────────────────────────────────────────
  if (_anyOf(d, ['salary', 'sal cr', 'payroll', 'sal credit', 'ctc', 'pay slip', 'monthly pay',
                  'stipend', 'wages', 'compensation'])) {
    return const _CategoryResult('Salary', TransactionType.income);
  }
  if (_anyOf(d, ['dividend', 'div cr', 'interest credit', 'int cr', 'interest earned',
                  'fd interest', 'rd interest', 'savings interest'])) {
    return const _CategoryResult('Interest & Dividends', TransactionType.income);
  }
  if (_anyOf(d, ['refund', 'reversal', 'cashback', 'clbk', 'cb credit', 'reward'])) {
    return const _CategoryResult('Refunds & Cashback', TransactionType.cashback);
  }
  if (_anyOf(d, ['rent received', 'rental income', 'house rent received'])) {
    return const _CategoryResult('Rental Income', TransactionType.income);
  }
  if (_anyOf(d, ['freelance', 'consulting fee', 'professional fee', 'client payment',
                  'project payment', 'invoice'])) {
    return const _CategoryResult('Freelance / Business', TransactionType.income);
  }
  if (_anyOf(d, ['transfer from', 'neft cr', 'imps cr', 'upi cr', 'rtgs cr'])) {
    return const _CategoryResult('Transfer In', TransactionType.income);
  }

  // ── Food & Dining ────────────────────────────────────────────────────────
  if (_anyOf(d, ['swiggy', 'zomato', 'uber eat', 'dunzo', 'eatsure', 'faasos', 'freshmenu',
                  'box8', 'dominos', 'pizza hut', 'kfc', 'mcdonalds', "mcdonald's",
                  'burger king', 'subway', 'starbucks', 'ccd', 'cafe coffee', 'barista',
                  'restaurant', 'hotel food', 'dhaba', 'biryani', 'thali',
                  'food', 'meal'])) {
    return const _CategoryResult('Food & Dining', TransactionType.expense);
  }

  // ── Groceries ────────────────────────────────────────────────────────────
  if (_anyOf(d, ['bigbasket', 'grofer', 'dmart', 'jiomart', 'reliance fresh',
                  'blinkit', 'zepto', 'swiggy instamart', 'more supermarket',
                  'nature\'s basket', 'star bazaar', 'spencers', 'grocery',
                  'supermarket', 'kirana', 'provision', 'vegetables', 'fruits'])) {
    return const _CategoryResult('Groceries', TransactionType.expense);
  }

  // ── Transport ────────────────────────────────────────────────────────────
  if (_anyOf(d, ['uber', 'ola', 'rapido', 'yulu', 'bounce', 'vogo', 'blu-smart',
                  'irctc', 'redbus', 'abhibus', 'goibibo bus', 'cleartrip bus',
                  'metro', 'bmtc', 'best bus', 'dtc', 'mkl', 'toll', 'fastag',
                  'petrol', 'diesel', 'fuel', 'hp petrol', 'iocl', 'bpcl',
                  'cab', 'taxi', 'auto', 'parking'])) {
    return const _CategoryResult('Transport', TransactionType.expense);
  }

  // ── Shopping ─────────────────────────────────────────────────────────────
  if (_anyOf(d, ['amazon', 'flipkart', 'myntra', 'nykaa', 'meesho', 'snapdeal',
                  'tata cliq', 'ajio', 'lenskart', 'pepperfry', 'ikea',
                  'h&m', 'zara', 'decathlon', 'croma', 'reliance digital',
                  'vijay sales', 'shopping', 'mall', 'boutique', 'cloth',
                  'apparel', 'fashion', 'footwear', 'shoe'])) {
    return const _CategoryResult('Shopping', TransactionType.expense);
  }

  // ── Utilities ────────────────────────────────────────────────────────────
  if (_anyOf(d, ['electricity', 'bescom', 'msedcl', 'tata power', 'adani elec',
                  'water bill', 'bwssb', 'gas bill', 'indane', 'hp gas', 'bharat gas',
                  'broadband', 'airtel', 'jio', 'vi ', 'vodafone', 'bsnl', 'mtnl',
                  'mobile bill', 'postpaid', 'recharge', 'utility', 'bill payment',
                  'bbps', 'society maintenance', 'maintenance charge'])) {
    return const _CategoryResult('Utilities', TransactionType.expense);
  }

  // ── Healthcare ───────────────────────────────────────────────────────────
  if (_anyOf(d, ['hospital', 'clinic', 'pharmacy', 'medical', 'apollo', 'fortis',
                  'max healthcare', 'narayana', 'netmeds', '1mg', 'pharmeasy',
                  'medplus', 'health', 'doctor', 'consultation', 'lab test',
                  'pathlab', 'diagnostic', 'dental', 'optical', 'spectacles'])) {
    return const _CategoryResult('Healthcare', TransactionType.expense);
  }

  // ── Entertainment ────────────────────────────────────────────────────────
  if (_anyOf(d, ['netflix', 'hotstar', 'disney', 'prime video', 'amazon prime',
                  'spotify', 'youtube premium', 'apple music', 'gaana',
                  'bookmyshow', 'pvr', 'inox', 'cinepolis', 'game', 'steam',
                  'playstation', 'xbox', 'entertainment', 'event', 'concert',
                  'theatre', 'amusement', 'zoo', 'museum'])) {
    return const _CategoryResult('Entertainment', TransactionType.expense);
  }

  // ── Rent & Housing ───────────────────────────────────────────────────────
  if (_anyOf(d, ['rent', 'housing', 'maintenance fee', 'society', 'apartment',
                  'pg payment', 'hostel fee', 'flat rent', 'lease'])) {
    return const _CategoryResult('Rent & Housing', TransactionType.expense);
  }

  // ── Education ────────────────────────────────────────────────────────────
  if (_anyOf(d, ['school fee', 'college fee', 'tuition', 'coursera', 'udemy',
                  'byjus', 'unacademy', 'vedantu', 'education', 'admission',
                  'exam fee', 'books', 'stationery', 'student'])) {
    return const _CategoryResult('Education', TransactionType.expense);
  }

  // ── Travel ───────────────────────────────────────────────────────────────
  if (_anyOf(d, ['irctc', 'indigo', 'spicejet', 'air india', 'vistara', 'goair',
                  'akasa', 'air asia', 'flight', 'airline', 'makemytrip',
                  'goibibo', 'cleartrip', 'yatra', 'ixigo', 'hotel', 'oyo',
                  'treebo', 'fabhotel', 'airbnb', 'vacation', 'tour',
                  'holiday', 'passport', 'visa'])) {
    return const _CategoryResult('Travel', TransactionType.expense);
  }

  // ── EMI / Loans ──────────────────────────────────────────────────────────
  if (_anyOf(d, ['emi', 'loan repay', 'equated monthly', 'loan emi', 'car emi',
                  'home loan', 'personal loan', 'credit emi', 'emi debit',
                  'nach', 'mandate', 'auto debit loan'])) {
    return const _CategoryResult('EMI / Loans', TransactionType.expense);
  }

  // ── Investments ──────────────────────────────────────────────────────────
  if (_anyOf(d, ['mutual fund', 'mf sip', 'sip', 'nse', 'bse', 'demat',
                  'zerodha', 'groww', 'upstox', 'kuvera', 'coin', 'paytm money',
                  'hdfc sec', 'icicidirect', 'kotak sec', 'edelweiss',
                  'fd booking', 'fixed deposit', 'rd booking', 'recurring',
                  'ppf', 'nps', 'epf', 'gold bond', 'sovereign gold',
                  'sgb', 'investment'])) {
    return const _CategoryResult('Investments', TransactionType.expense);
  }

  // ── Insurance ────────────────────────────────────────────────────────────
  if (_anyOf(d, ['insurance', 'lic', 'premium', 'life insurance', 'term plan',
                  'health insurance', 'motor insurance', 'vehicle insurance',
                  'star health', 'niva bupa', 'hdfc life', 'icici pru',
                  'sbi life', 'tata aia'])) {
    return const _CategoryResult('Insurance', TransactionType.expense);
  }

  // ── Charity / Donations ──────────────────────────────────────────────────
  if (_anyOf(d, ['donation', 'charity', 'ngo', 'temple', 'church', 'mosque',
                  'pm cares', 'relief fund', 'welfare'])) {
    return const _CategoryResult('Donations', TransactionType.expense);
  }

  // ── ATM / Cash ───────────────────────────────────────────────────────────
  if (_anyOf(d, ['atm', 'cash withdrawal', 'cash deposit', 'cdm'])) {
    return const _CategoryResult('Cash', TransactionType.expense);
  }

  // ── Bank Charges ─────────────────────────────────────────────────────────
  if (_anyOf(d, ['bank charge', 'service charge', 'annual fee', 'processing fee',
                  'gst', 'interest debit', 'penalty', 'late fee', 'charges debit',
                  'sms charge', 'locker rent'])) {
    return const _CategoryResult('Bank Charges', TransactionType.expense);
  }

  return const _CategoryResult('Uncategorized', TransactionType.expense);
}

bool _anyOf(String text, List<String> keywords) {
  for (final kw in keywords) {
    if (text.contains(kw)) return true;
  }
  return false;
}

/// Tries to extract a clean merchant name from a UPI/NEFT description.
String _cleanMerchant(String description) {
  // UPI: format is often "UPI-MerchantName/reference"
  final upi = RegExp(r'UPI[-/]([^/\d\s][^/]{2,30})', caseSensitive: false);
  final um = upi.firstMatch(description);
  if (um != null) return _titleCase(um.group(1)!.trim());

  // NEFT/IMPS: remove common prefixes
  var cleaned = description
      .replaceAll(RegExp(r'^(NEFT|IMPS|RTGS|ACH|NACH|ECS)\s*[-/]?\s*', caseSensitive: false), '')
      .replaceAll(RegExp(r'\d{9,}'), '') // remove long reference numbers
      .trim();

  if (cleaned.length > 4) return _titleCase(cleaned.split('/').first.trim());
  return description;
}

String _titleCase(String s) {
  if (s.isEmpty) return s;
  return s.split(RegExp(r'\s+')).map((w) {
    if (w.isEmpty) return w;
    return w[0].toUpperCase() + w.substring(1).toLowerCase();
  }).join(' ');
}

// ═══════════════════════════════════════════════════════════════════════════
// FILE PARSERS
// ═══════════════════════════════════════════════════════════════════════════

/// Parses rows from CSV text and column mapping into _ParsedRow list.
List<_ParsedRow> _buildRowsFromCsv(
  List<List<String>> tableRows,
  Map<int, _CsvColumn> mapping,
) {
  final dateIdx = mapping.entries.where((e) => e.value == _CsvColumn.date).map((e) => e.key).firstOrNull;
  final descIdx = mapping.entries.where((e) => e.value == _CsvColumn.description).map((e) => e.key).firstOrNull;
  final amtIdx = mapping.entries.where((e) => e.value == _CsvColumn.amount).map((e) => e.key).firstOrNull;
  final debitIdx = mapping.entries.where((e) => e.value == _CsvColumn.debit).map((e) => e.key).firstOrNull;
  final creditIdx = mapping.entries.where((e) => e.value == _CsvColumn.credit).map((e) => e.key).firstOrNull;
  final refIdx = mapping.entries.where((e) => e.value == _CsvColumn.reference).map((e) => e.key).firstOrNull;

  final result = <_ParsedRow>[];
  for (final row in tableRows) {
    if (dateIdx == null || dateIdx >= row.length) continue;
    final date = _parseDate(row[dateIdx]);
    if (date == null) continue;

    final desc = descIdx != null && descIdx < row.length ? row[descIdx] : '';
    if (desc.trim().isEmpty) continue;

    double? amount;
    bool isDebit = true;

    if (amtIdx != null && amtIdx < row.length) {
      amount = _parseAmount(row[amtIdx]);
      if (amount != null) isDebit = amount < 0;
    } else {
      final debit = debitIdx != null && debitIdx < row.length ? _parseAmount(row[debitIdx]) : null;
      final credit = creditIdx != null && creditIdx < row.length ? _parseAmount(row[creditIdx]) : null;
      if (debit != null && debit > 0) { amount = debit; isDebit = true; }
      else if (credit != null && credit > 0) { amount = credit; isDebit = false; }
    }
    if (amount == null || amount == 0) continue;

    final ref = refIdx != null && refIdx < row.length ? row[refIdx] : null;
    result.add(_ParsedRow(
      date: date,
      description: desc,
      amount: amount.abs(),
      isDebit: isDebit,
      reference: ref?.isNotEmpty == true ? ref : null,
    ));
  }
  return result;
}

/// Parses XLS/XLSX bytes into rows.
List<List<String>> _parseExcelBytes(Uint8List bytes) {
  final excel = Excel.decodeBytes(bytes);
  // Use the first non-empty sheet
  for (final sheetName in excel.tables.keys) {
    final sheet = excel.tables[sheetName]!;
    if (sheet.rows.isEmpty) continue;
    return sheet.rows.map((row) {
      return row.map((cell) => cell?.value?.toString() ?? '').toList();
    }).toList();
  }
  return [];
}

/// Extracts text from PDF bytes using Syncfusion, optionally with password.
/// Uses extractTextLines() to get position-aware fragments, then reconstructs
/// proper table rows by grouping fragments at similar Y positions and sorting
/// left-to-right. This handles bank statement PDFs where columns are stored as
/// separate text streams and extractText() gives them in wrong order.
String? _extractPdfText(Uint8List bytes, {String? password}) {
  try {
    final doc = PdfDocument(inputBytes: bytes, password: password ?? '');
    final extractor = PdfTextExtractor(doc);

    final allRows = <String>[];

    for (var pageIdx = 0; pageIdx < doc.pages.count; pageIdx++) {
      // extractTextLines gives each fragment with its bounding Rect on the page
      final lines = extractor.extractTextLines(
        startPageIndex: pageIdx,
        endPageIndex: pageIdx,
      );
      if (lines.isEmpty) continue;

      // Sort fragments: primary = top (Y), secondary = left (X)
      // This restores visual reading order even when content streams are columnar
      lines.sort((a, b) {
        final dy = a.bounds.top.compareTo(b.bounds.top);
        if (dy != 0) return dy;
        return a.bounds.left.compareTo(b.bounds.left);
      });

      // Group fragments whose Y positions are within 6 pts of each other → same row
      final rowGroups = <List<TextLine>>[];
      List<TextLine>? currentGroup;
      double? groupTop;

      for (final line in lines) {
        if (groupTop == null || (line.bounds.top - groupTop).abs() > 6) {
          if (currentGroup != null) rowGroups.add(currentGroup);
          currentGroup = [line];
          groupTop = line.bounds.top;
        } else {
          currentGroup!.add(line);
          // Expand groupTop toward the new line so rows with slight drift stay merged
          groupTop = (groupTop! + line.bounds.top) / 2;
        }
      }
      if (currentGroup != null) rowGroups.add(currentGroup);

      // Join each group into a single text line, space-separated
      for (final group in rowGroups) {
        // Sort group members left-to-right
        group.sort((a, b) => a.bounds.left.compareTo(b.bounds.left));
        final rowText = group
            .map((l) => l.text.trim())
            .where((t) => t.isNotEmpty)
            .join('  '); // double-space preserves column gaps for amount parsing
        if (rowText.isNotEmpty) allRows.add(rowText);
      }
    }

    doc.dispose();
    final text = allRows.join('\n').trim();
    return text.isEmpty ? null : text;
  } catch (e) {
    return null;
  }
}

/// Smart universal PDF parser — works for any bank statement format.
/// Tries multiple strategies in order and returns first non-empty result.
List<_ParsedRow> _parsePdfText(String text, _BankFormat bank) {
  final isCC = _detectIsCreditCard(text);

  // Strategy 1: Line-based parser (primary, works when Syncfusion gives row-by-row text)
  var rows = isCC ? _parseCreditCardPdf(text) : _parseSavingsAccountPdf(text);
  if (rows.isNotEmpty) return rows;

  // Strategy 2: Swap type (in case CC detection was wrong)
  rows = isCC ? _parseSavingsAccountPdf(text) : _parseCreditCardPdf(text);
  if (rows.isNotEmpty) return rows;

  // Strategy 3: Multiline/full-text savings parser
  // Works when Syncfusion gives columnar or non-line-structured output
  rows = _parseSavingsMultiline(text);
  if (rows.isNotEmpty) return rows;

  // Strategy 4: Multiline credit card parser
  rows = _parseCreditCardMultiline(text);
  return rows;
}

// ═══════════════════════════════════════════════════════════════════════════════
// MULTILINE SAVINGS PARSER
// Scans entire text as a blob — finds date positions, extracts the segment
// between consecutive dates, pulls amounts+balance from it.
// Works when Syncfusion gives columnar/non-row-structured output.
// ═══════════════════════════════════════════════════════════════════════════════
List<_ParsedRow> _parseSavingsMultiline(String text) {
  final result = <_ParsedRow>[];

  // Pick the date format that appears most often in the text
  final dateFmts = [
    RegExp(r'\b(\d{2}-\d{2}-\d{4})\b'),   // DD-MM-YYYY
    RegExp(r'\b(\d{2}/\d{2}/\d{4})\b'),   // DD/MM/YYYY
    RegExp(r'\b(\d{2}\.\d{2}\.\d{4})\b'), // DD.MM.YYYY
    RegExp(r'\b(\d{1,2}\s+[A-Za-z]{3}\s+\d{4})\b'), // D MMM YYYY
  ];

  RegExp? dateRx;
  int maxCount = 0;
  for (final rx in dateFmts) {
    final c = rx.allMatches(text).length;
    if (c > maxCount) { maxCount = c; dateRx = rx; }
  }
  if (dateRx == null || maxCount < 2) return result;

  final allDateM = dateRx.allMatches(text).toList();
  final amtRx   = RegExp(r'([\d,]+\.\d{2})', caseSensitive: false);
  final balDirRx = RegExp(r'([\d,]+\.\d{2})\s+(Cr|Dr)\b', caseSensitive: false);

  double prevBalance = 0;
  bool   prevSet = false;

  for (var i = 0; i < allDateM.length; i++) {
    final dm = allDateM[i];

    // Segment from this date to next date (max 600 chars to avoid overlap)
    final segEnd = i + 1 < allDateM.length
        ? allDateM[i + 1].start
        : (dm.start + 600 < text.length ? dm.start + 600 : text.length);
    final segment = text.substring(dm.start, segEnd);
    final segLo   = segment.toLowerCase();

    // Capture opening/closing balance for tracking; skip as transactions
    if (segLo.contains('opening balance') || segLo.contains('closing balance') ||
        segLo.contains('brought forward') || segLo.contains('b/f')) {
      final bm = balDirRx.firstMatch(segment);
      if (bm != null) {
        final v = double.tryParse(bm.group(1)!.replaceAll(',', ''));
        if (v != null) {
          prevBalance = (bm.group(2)?.toUpperCase() ?? 'CR') == 'DR' ? -v : v;
          prevSet = true;
        }
      }
      continue;
    }

    // Skip header rows
    if (segLo.contains('narration') || segLo.contains('particulars') ||
        segLo.contains('withdrawal') || segLo.contains('deposit') &&
        segLo.contains('balance')) continue;

    // All amounts in this segment
    final allAmts = amtRx.allMatches(segment).toList();
    if (allAmts.isEmpty) continue;

    // Balance = last amount with Cr/Dr suffix; fallback = last amount
    final balMatches = balDirRx.allMatches(segment).toList();
    double newBalance;
    int balStart;
    if (balMatches.isNotEmpty) {
      final bm = balMatches.last;
      final v  = double.tryParse(bm.group(1)!.replaceAll(',', ''));
      if (v == null) continue;
      newBalance = (bm.group(2)?.toUpperCase() ?? 'CR') == 'DR' ? -v : v;
      balStart = bm.start;
    } else if (allAmts.length >= 2) {
      final v = double.tryParse(allAmts.last.group(1)!.replaceAll(',', ''));
      if (v == null) continue;
      newBalance = v;
      balStart   = allAmts.last.start;
    } else {
      continue;
    }

    // Transaction amounts = all amounts before the balance
    final txnAmts = allAmts.where((m) => m.start < balStart).toList();
    if (txnAmts.isEmpty) continue;
    final txnAmt = double.tryParse(txnAmts.last.group(1)!.replaceAll(',', ''));
    if (txnAmt == null || txnAmt <= 0) continue;

    // Debit/credit via balance tracking
    bool isDebit;
    if (!prevSet) {
      isDebit = _isTxnDebitByKeyword(segment);
    } else {
      final eD = (prevBalance - txnAmt - newBalance).abs();
      final eC = (prevBalance + txnAmt - newBalance).abs();
      isDebit   = (eD - eC).abs() < 0.02 ? _isTxnDebitByKeyword(segment) : eD < eC;
    }
    prevBalance = newBalance;
    prevSet     = true;

    // Description: text between date and first amount
    final dateStr  = dm.group(0)!;
    final afterDate = segment.substring(dateStr.length);
    final firstAmt  = amtRx.firstMatch(afterDate);
    var desc = firstAmt != null
        ? afterDate.substring(0, firstAmt.start).trim()
        : afterDate.replaceAll(amtRx, ' ').trim();
    desc = desc.replaceAll(RegExp(r'\s+'), ' ').trim();
    desc = _cleanUniversalDesc(desc);
    if (desc.length < 2) continue;

    final date = _parseDate(dateStr);
    if (date == null) continue;

    result.add(_ParsedRow(date: date, description: desc, amount: txnAmt, isDebit: isDebit));
  }
  return result;
}

// ═══════════════════════════════════════════════════════════════════════════════
// MULTILINE CREDIT CARD PARSER
// Scans entire text for date+time blocks followed by a currency amount.
// Works when Syncfusion breaks CC transaction lines unpredictably.
// ═══════════════════════════════════════════════════════════════════════════════
List<_ParsedRow> _parseCreditCardMultiline(String text) {
  final result = <_ParsedRow>[];

  // Combined pattern: date (with optional pipe+time) then up to 300 chars then amount
  // multiline-safe because we operate on the full text blob
  final txnRx = RegExp(
    r'(\d{2}[/\-]\d{2}[/\-]\d{4})(?:\|?\s*\d{2}:\d{2})?\s+'
    r'((?:(?!(?:\d{2}[/\-]\d{2}[/\-]\d{4})).){1,300}?)'
    r'\s*(\+)?\s*(?:[C₹]|Rs\.?|INR)\s*([\d,]+\.\d{2})',
    caseSensitive: false,
    dotAll: true, // . matches \n too
  );

  for (final m in txnRx.allMatches(text)) {
    final dateStr = m.group(1)!;
    final desc    = (m.group(2) ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
    final hasPlus = m.group(3) != null;
    final amtStr  = m.group(4)!.replaceAll(',', '');

    final date   = _parseDate(dateStr);
    final amount = double.tryParse(amtStr);
    if (date == null || amount == null || amount <= 0) continue;
    if (desc.isEmpty) continue;

    final descUp   = desc.toUpperCase();
    final isPayment = hasPlus ||
        descUp.contains('CC PAYMENT') || descUp.contains('PAYMENT RECEIVED') ||
        descUp.contains('AUTOPAY')    || descUp.contains('BPPY CC') ||
        descUp.contains('REFUND')     || descUp.contains('CREDIT ADJUSTMENT');

    result.add(_ParsedRow(
      date: date,
      description: _cleanCreditCardDesc(desc),
      amount: amount,
      isDebit: !isPayment,
    ));
  }
  return result;
}

// ── Format auto-detector ──────────────────────────────────────────────────────

bool _detectIsCreditCard(String text) {
  final t = text.toLowerCase();
  return t.contains('credit card') ||
      t.contains('minimum due') ||
      t.contains('minimum amount due') ||
      t.contains('total amount due') ||
      t.contains('credit limit') ||
      t.contains('available credit') ||
      t.contains('statement balance') ||
      t.contains('billing period') ||
      t.contains('neucoins') || // HDFC Tata Neu
      (t.contains('payment due') && !t.contains('savings account'));
}

// ═══════════════════════════════════════════════════════════════════════════════
// UNIVERSAL SAVINGS/CURRENT ACCOUNT PARSER
// Works for: BOB, HDFC, SBI, ICICI, Axis, Kotak, IndusInd, Yes Bank, Federal,
//            any bank whose PDF follows DATE | DESC | AMOUNT(s) | BALANCE Cr|Dr
// Core insight: track the running balance → if prevBalance - txn ≈ newBalance
// it's a debit; if prevBalance + txn ≈ newBalance it's a credit.
// No per-bank knowledge required.
// ═══════════════════════════════════════════════════════════════════════════════
List<_ParsedRow> _parseSavingsAccountPdf(String text) {
  final result   = <_ParsedRow>[];

  // Normalise line endings — Syncfusion sometimes emits \r\n or just \r
  final normalised = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  final rawLines = normalised.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

  // ── Detect date format used in this specific PDF ──────────────────────────
  // Patterns: DD-MM-YYYY, DD/MM/YYYY, DD.MM.YYYY, DDMMYYYY (rare)
  // Also: DD MMM YYYY, DD-MMM-YY
  final dateFmts = [
    RegExp(r'^\d{2}-\d{2}-\d{4}\b'),  // BOB: DD-MM-YYYY
    RegExp(r'^\d{2}/\d{2}/\d{4}\b'),  // HDFC/ICICI: DD/MM/YYYY
    RegExp(r'^\d{2}\.\d{2}\.\d{4}\b'), // some banks: DD.MM.YYYY
    RegExp(r'^\d{1,2}\s+[A-Za-z]{3}\s+\d{4}\b'), // SBI: D MMM YYYY
    RegExp(r'^\d{2}-[A-Za-z]{3}-\d{4}\b'), // some: DD-MMM-YYYY
    RegExp(r'^\d{2}-[A-Za-z]{3}-\d{2}\b'), // some: DD-MMM-YY
  ];
  RegExp? activeDateRx;
  for (final rx in dateFmts) {
    if (rawLines.any((l) => rx.hasMatch(l))) { activeDateRx = rx; break; }
  }
  // Fallback: any DD/MM or DD-MM style date at line start
  activeDateRx ??= RegExp(r'^\d{1,2}[/\-\.]\d{1,2}[/\-\.]');

  // ── Detect whether balance has explicit Cr|Dr suffix ─────────────────────
  // BOB-style: "1250.00 28776.44 Cr"  — two amounts + Cr/Dr at line end
  // HDFC-style: "1250.00  23050.00"   — last number is balance, no suffix
  final hasCrDrSuffix = rawLines.any((l) =>
      RegExp(r'[\d,]+\.\d{2}\s+(?:Cr|Dr)\s*$', caseSensitive: false).hasMatch(l));

  final txnEndRx = hasCrDrSuffix
      ? RegExp(r'[\d,]+\.\d{2}\s+(?:Cr|Dr)\s*$', caseSensitive: false)
      : RegExp(r'[\d,]+\.\d{2}\s*$');

  // ── Phase 1: Rebuild wrapped narration lines ──────────────────────────────
  // A new transaction starts when the line begins with a date.
  // Continuation lines (no date) are appended to the current buffer.
  // We flush when the buffer matches a complete transaction ending.
  final rebuilt = <String>[];
  var buf = StringBuffer();

  for (final line in rawLines) {
    if (activeDateRx.hasMatch(line)) {
      if (buf.isNotEmpty) rebuilt.add(buf.toString().trim());
      buf = StringBuffer(line);
    } else if (buf.isNotEmpty) {
      buf.write(' $line');
    }
    if (buf.isNotEmpty && txnEndRx.hasMatch(buf.toString())) {
      rebuilt.add(buf.toString().trim());
      buf = StringBuffer();
    }
  }
  if (buf.isNotEmpty) rebuilt.add(buf.toString().trim());

  // ── Phase 2: Parse each rebuilt line ─────────────────────────────────────
  // Amount pattern: numbers with exactly 2 decimal places, possibly comma-
  // separated. We deliberately exclude numbers without decimals to avoid
  // matching reference numbers like 111243113217.
  final amtRx = RegExp(r'([\d,]+\.\d{2})(?:\s+(Cr|Dr))?', caseSensitive: false);

  double prevBalance = 0;
  bool  prevBalanceSet = false;

  for (final line in rebuilt) {
    final lo = line.toLowerCase();

    // ── Skip non-transaction lines ──────────────────────────────────────────
    if (lo.contains('date') && (lo.contains('narration') || lo.contains('description') ||
        lo.contains('particulars'))) continue;
    if (lo.contains('opening balance') || lo.contains('closing balance') ||
        lo.contains('b/f') || lo.contains('brought forward')) {
      // Capture opening balance for tracking
      final m = amtRx.allMatches(line).toList();
      if (m.isNotEmpty) {
        final lastM = m.last;
        final bal = double.tryParse(lastM.group(1)!.replaceAll(',', ''));
        if (bal != null) {
          final dir = lastM.group(2)?.toUpperCase() ?? 'CR';
          prevBalance = dir == 'DR' ? -bal : bal;
          prevBalanceSet = true;
        }
      }
      continue;
    }
    if (lo.contains('page ') && lo.contains('|')) continue;
    if (lo.startsWith('http') || lo.contains('customer care') ||
        lo.contains('toll free') || lo.contains('1800 5')) continue;
    if (lo.contains('fixed deposit') || lo.contains('term deposit') ||
        lo.contains('abbreviation') || lo.contains('nominee')) continue;
    if (lo.contains('summary of') || lo.contains('account number') && lo.length < 30) continue;

    // ── Extract date ────────────────────────────────────────────────────────
    final dateM = activeDateRx.firstMatch(line);
    if (dateM == null) continue;
    final date = _parseDate(line.substring(dateM.start, dateM.end).trim());
    if (date == null) continue;

    // ── Extract all amounts from the line ───────────────────────────────────
    // Each match: group(1)=number string, group(2)=Cr|Dr suffix (may be null)
    final amtMatches = amtRx.allMatches(line).toList();
    if (amtMatches.isEmpty) continue;

    // The LAST amount in the line is the running balance
    final balMatch  = amtMatches.last;
    final balStr    = balMatch.group(1)!.replaceAll(',', '');
    final balDirStr = balMatch.group(2)?.toUpperCase() ?? 'CR';
    final balance   = double.tryParse(balStr);
    if (balance == null) continue;
    final newBalance = balDirStr == 'DR' ? -balance : balance;

    // Transaction amount(s): all amounts except the last (balance) one
    final txnMatches = amtMatches.length > 1
        ? amtMatches.sublist(0, amtMatches.length - 1)
        : amtMatches; // single amount — might be balance or txn; handle below

    // If there is only one amount in the line AND no prior balance context,
    // skip (we can't determine debit/credit reliably)
    if (txnMatches.isEmpty) continue;

    // Pick the transaction amount: use the last of the non-balance amounts.
    // Banks with separate debit/credit columns will show only one non-zero value.
    final txnStr = txnMatches.last.group(1)!.replaceAll(',', '');
    final amount = double.tryParse(txnStr);
    if (amount == null || amount <= 0) continue;

    // ── Determine debit vs credit using balance tracking ────────────────────
    bool isDebit;
    if (!prevBalanceSet || prevBalance == 0) {
      // No prior balance — fall back to keyword / direction heuristics
      isDebit = _isTxnDebitByKeyword(line);
    } else {
      final errDebit  = (prevBalance - amount - newBalance).abs();
      final errCredit = (prevBalance + amount - newBalance).abs();
      // Allow a small tolerance for rounding (0.02)
      if ((errDebit - errCredit).abs() < 0.02) {
        isDebit = _isTxnDebitByKeyword(line);
      } else {
        isDebit = errDebit < errCredit;
      }
    }
    prevBalance    = newBalance;
    prevBalanceSet = true;

    // ── Extract description ─────────────────────────────────────────────────
    final afterDate = line.substring(dateM.end).trim();
    // Description ends just before the first amount
    final firstAmtStart = amtMatches.first.start - (line.length - afterDate.length);
    var desc = firstAmtStart > 0
        ? afterDate.substring(0, firstAmtStart.clamp(0, afterDate.length)).trim()
        : afterDate.replaceAll(amtRx, ' ').trim();
    desc = _cleanUniversalDesc(desc);
    if (desc.length < 2) continue;

    result.add(_ParsedRow(
      date: date,
      description: desc,
      amount: amount,
      isDebit: isDebit,
      rawLine: line,
    ));
  }
  return result;
}

// ── Keyword-based debit/credit for when balance tracking isn't possible ──────
bool _isTxnDebitByKeyword(String line) {
  final l = line.toLowerCase();
  // Strong credit signals
  if (l.contains('achcr') || l.contains('salary') || l.contains('refund') ||
      l.contains('dividend') || l.contains('interest credit') ||
      l.contains('neft cr') || l.contains('rtgs cr') || l.contains('cr ')) return false;
  // Strong debit signals
  if (l.contains('achdr') || l.contains('dcardfee') || l.contains('withdrawal') ||
      l.contains('chgs') || l.contains('fee') || l.contains('dr ') ||
      l.contains('upi')) return true;
  return true; // default: debit
}

// ── Universal description cleaner ────────────────────────────────────────────
// Works across all banks: cleans UPI handles, NEFT/RTGS refs, ACH codes,
// reference numbers, and other bank-specific noise without per-bank knowledge.
String _cleanUniversalDesc(String raw) {
  var d = raw.trim();

  // UPI/refNo/time/UPI/handle@bank or UPI-MERCHANT NAME
  if (RegExp(r'^UPI/', caseSensitive: false).hasMatch(d)) {
    final parts = d.split('/');
    // Parts: [UPI, refNo, time, UPI, handle, ...]
    // Try to get the human-readable part after the last slash
    final handle = parts.length >= 5 ? parts[4] : parts.last;
    final name   = handle.split('@').first.trim();
    if (name.length > 2) return 'UPI: $name';
  }
  if (d.toUpperCase().startsWith('UPI-')) d = d.substring(4).trim();

  // ACHDR/EntityName/.../... → "ACH Debit: EntityName"
  if (RegExp(r'^ACHDR/', caseSensitive: false).hasMatch(d)) {
    final entity = d.split('/').skip(1).first.trim();
    if (entity.isNotEmpty) return 'ACH Debit: $entity';
  }
  // ACHCR/EntityName/.../... → "ACH Credit: EntityName"
  if (RegExp(r'^ACHCR/', caseSensitive: false).hasMatch(d)) {
    final entity = d.split('/').skip(1).first.trim();
    if (entity.isNotEmpty) return 'ACH Credit: $entity';
  }

  // NEFT-XXXXXXXXrefXXX-Name or NEFT/... → "NEFT: Name"
  if (RegExp(r'^NEFT[-/]', caseSensitive: false).hasMatch(d)) {
    final rem = d.substring(5).replaceAll(RegExp(r'^[A-Z0-9]{8,}\s*[-/\s]?'), '').trim();
    if (rem.length > 2) return 'NEFT: $rem';
  }
  // RTGS-... → similar
  if (RegExp(r'^RTGS[-/]', caseSensitive: false).hasMatch(d)) {
    final rem = d.substring(5).replaceAll(RegExp(r'^[A-Z0-9]{8,}\s*[-/\s]?'), '').trim();
    if (rem.length > 2) return 'RTGS: $rem';
  }

  // IMPS/..., NACH/..., ENACH/... → standardise prefix
  for (final prefix in ['IMPS', 'NACH', 'ENACH', 'ECS', 'SI', 'MBK']) {
    if (d.toUpperCase().startsWith('$prefix/') || d.toUpperCase().startsWith('$prefix-')) {
      final rem = d.substring(prefix.length + 1);
      // Remove leading long numeric ref
      final clean = rem.replaceAll(RegExp(r'^[\d/]{6,}\s*/?'), '').trim();
      return clean.length > 2 ? '$prefix: $clean' : '$prefix $rem';
    }
  }

  // Remove embedded long reference numbers (8+ digits) that aren't part of a word
  d = d.replaceAll(RegExp(r'(?<!\w)\d{8,}(?!\w)'), '').trim();
  // Remove long alphanumeric codes (reference/transaction IDs)
  d = d.replaceAll(RegExp(r'\b[A-Z0-9]{12,}\b'), '').trim();
  // Remove trailing slashes or hyphens
  d = d.replaceAll(RegExp(r'[/\-]+\s*$'), '').trim();
  // Collapse whitespace
  d = d.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
  return d.isNotEmpty ? d : raw.trim();
}

// ═══════════════════════════════════════════════════════════════════════════════
// UNIVERSAL CREDIT CARD PDF PARSER
// Works for: HDFC CC, ICICI CC, Axis CC, SBI Card, any credit card statement.
// Core insight:
//  - Transaction rows have date + time (or just date) + description + amount
//  - A '+' sign (or payment keyword) before the amount = credit (payment received)
//  - Absence of '+' = debit (purchase)
//  - Currency symbol can be ₹, C (PDF artefact), Rs, $ — all handled
// ═══════════════════════════════════════════════════════════════════════════════
// Regex that identifies a line as the START of a credit card transaction
final _ccDateStartRx = RegExp(
  r'^\d{2}[/\-\.]\d{2}[/\-\.]\d{2,4}[\||\s]',
);

List<_ParsedRow> _parseCreditCardPdf(String text) {
  final result    = <_ParsedRow>[];
  final rawLines  = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

  // ── Phase 1: Rebuild wrapped CC transaction lines ─────────────────────────
  // HDFC Tata Neu CC (and others) often split a single transaction line at a
  // column boundary, e.g.:
  //   "02/03/2026| 20:01 BPPY CC PAYMENT DP016061200... (Ref#"
  //   "ST26063...520) +  C 1,100.00 l"
  // We detect a new transaction start by the date-at-start pattern and flush
  // when we see a currency+amount at the end of the buffer.
  final ccAmtEndRx = RegExp(
    r'(?:[C₹]|Rs\.?|INR)\s*[\d,]+\.\d{2}',
    caseSensitive: false,
  );

  final rebuilt = <String>[];
  var buf = StringBuffer();

  for (final line in rawLines) {
    if (_ccDateStartRx.hasMatch(line)) {
      if (buf.isNotEmpty) rebuilt.add(buf.toString().trim());
      buf = StringBuffer(line);
    } else if (buf.isNotEmpty) {
      buf.write(' $line');
    } else {
      rebuilt.add(line); // non-transaction line, keep as-is
    }
    // Flush when we see a currency amount (transaction is complete)
    if (buf.isNotEmpty && ccAmtEndRx.hasMatch(buf.toString())) {
      rebuilt.add(buf.toString().trim());
      buf = StringBuffer();
    }
  }
  if (buf.isNotEmpty) rebuilt.add(buf.toString().trim());

  // Pattern A: DD/MM/YYYY| HH:MM description [+] CURR amount
  //   (HDFC CC, ICICI CC with time component)
  // Pattern B: DD/MM/YYYY description [+] CURR amount
  //   (SBI Card, Axis CC — date only)
  // Pattern C: DD-MMM-YYYY description + CURR amount
  //   (Amex, Citibank)
  // We try all patterns on each line.

  final currRx = r'(?:[C₹]|Rs\.?|INR)\s*'; // currency symbol variants
  final amtRx  = r'([\d,]+\.\d{2})';

  final patterns = [
    // With time and pipe: DD/MM/YYYY| HH:MM
    RegExp(
      r'^(\d{2}/\d{2}/\d{4})\|\s*\d{2}:\d{2}\s+(.+?)\s*(\+)?\s*' + currRx + amtRx,
      caseSensitive: false,
    ),
    // With time, no pipe: DD/MM/YYYY HH:MM
    RegExp(
      r'^(\d{2}/\d{2}/\d{4})\s+\d{2}:\d{2}\s+(.+?)\s*(\+)?\s*' + currRx + amtRx,
      caseSensitive: false,
    ),
    // Date only, slash: DD/MM/YYYY
    RegExp(
      r'^(\d{2}/\d{2}/\d{4})\s+(.+?)\s*(\+)?\s*' + currRx + amtRx,
      caseSensitive: false,
    ),
    // Date only, dash: DD-MM-YYYY or DD-MMM-YYYY
    RegExp(
      r'^(\d{2}[-\./]\d{2}[-\./]\d{4}|\d{2}-[A-Za-z]{3}-\d{4})\s+(.+?)\s*(\+)?\s*' + currRx + amtRx,
      caseSensitive: false,
    ),
    // Fallback: any date anywhere in line + description + amount
    // Group structure kept consistent: (date)(desc)(+?)(amount)
    RegExp(
      r'(\d{1,2}[/\-\.]\d{1,2}[/\-\.]\d{2,4})\s+(.+?)\s*(\+)?\s*' + currRx + amtRx,
      caseSensitive: false,
    ),
  ];

  for (final line in rebuilt) {
    // Skip header/footer lines
    final lo = line.toLowerCase();
    if (lo.contains('date') && (lo.contains('description') || lo.contains('transaction'))) continue;
    if (lo.contains('total') && lo.contains('due')) continue;
    if (lo.contains('minimum') && lo.contains('due')) continue;
    if (lo.contains('previous statement') || lo.contains('payments/credit')) continue;
    if (lo.contains('page ') || lo.startsWith('http')) continue;

    for (final rx in patterns) {
      final m = rx.firstMatch(line);
      if (m == null) continue;

      final dateStr = m.group(1)!;
      final desc    = m.group(2)!.trim();
      final hasPlus = m.group(3) != null;
      final amtStr  = m.group(4)!.replaceAll(',', '');

      final date = _parseDate(dateStr);
      if (date == null) break;

      final amount = double.tryParse(amtStr);
      if (amount == null || amount <= 0) break;

      // Determine debit/credit
      final descUp = desc.toUpperCase();
      final isPayment = hasPlus ||
          descUp.contains('CC PAYMENT') ||
          descUp.contains('PAYMENT RECEIVED') ||
          descUp.contains('AUTOPAY') ||
          descUp.contains('BILL PAYMENT') ||
          descUp.contains('ONLINE PAYMENT') ||
          descUp.contains('BPPY CC') ||
          descUp.contains('CREDIT ADJUSTMENT') ||
          descUp.contains('REFUND');

      result.add(_ParsedRow(
        date: date,
        description: _cleanCreditCardDesc(desc),
        amount: amount,
        isDebit: !isPayment,
        rawLine: line,
      ));
      break; // matched — stop trying patterns
    }
  }
  return result;
}

/// Cleans credit-card transaction descriptions regardless of issuing bank.
String _cleanCreditCardDesc(String raw) {
  var d = raw.trim();

  // Structured payment ref: "BPPY CC PAYMENT DPxxx (Ref# STxxx)" → "CC Payment"
  if (d.toUpperCase().contains('CC PAYMENT') || d.toUpperCase().startsWith('BPPY CC')) {
    return 'CC Payment';
  }

  // Remove parenthesised reference blocks: (Ref# ...), (Ref No ...), (TXN ...)
  d = d.replaceAll(RegExp(r'\s*\([Rr]ef[#\s]\w+\)', caseSensitive: false), '').trim();
  d = d.replaceAll(RegExp(r'\s*\([Tt]xn\s*[#:]\s*\w+\)', caseSensitive: false), '').trim();

  // Remove inline reference codes like DP016061..., ST2606..., AX996..., P3...
  d = d.replaceAll(RegExp(r'\b[A-Z]{2}\d{8,}\w*', caseSensitive: false), '').trim();

  // Remove trailing alphanumeric codes (no spaces, 8+ chars)
  d = d.replaceAll(RegExp(r'\s+[A-Z0-9]{8,}\s*$', caseSensitive: false), '').trim();

  // Remove "UPI-" prefix
  if (d.toUpperCase().startsWith('UPI-')) d = d.substring(4).trim();

  // Collapse whitespace
  d = d.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
  return d.isNotEmpty ? d : raw.trim();
}

// ═══════════════════════════════════════════════════════════════════════════
// DUPLICATE DETECTION
// ═══════════════════════════════════════════════════════════════════════════

void _detectDuplicates(List<_ParsedRow> parsed, List<Transaction> existing) {
  for (final row in parsed) {
    row.isDuplicate = existing.any((e) {
      final sameAmount = e.amount == row.amount;
      final sameDate = e.dateTime.difference(row.date).inDays.abs() <= 1;
      final sameDesc = e.description.toLowerCase() == row.description.toLowerCase() ||
          (e.metadata?['merchant']?.toString().toLowerCase() ==
              row.description.toLowerCase());
      return sameAmount && sameDate && sameDesc;
    });
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SCREEN
// ═══════════════════════════════════════════════════════════════════════════

class CsvImportScreen extends StatefulWidget {
  const CsvImportScreen({super.key});

  @override
  State<CsvImportScreen> createState() => _CsvImportScreenState();
}

class _CsvImportScreenState extends State<CsvImportScreen> {
  _ImportStep _step = _ImportStep.landing;
  _FileFormat _fileFormat = _FileFormat.none;
  _BankFormat _detectedBank = _BankFormat.unknown;

  // File data
  Uint8List? _fileBytes;
  String? _fileName;
  bool _needsPassword = false;
  final _passwordCtrl = TextEditingController();
  bool _showPassword = false;
  String? _passwordError;
  bool _isProcessing = false; // true while PDF decryption/parsing is running
  int? _expandedReviewIndex;   // which review tile is currently expanded

  // Paste mode
  bool _pasteMode = false;
  final _csvPasteCtrl = TextEditingController();

  // Raw table for CSV/XLS
  List<List<String>> _rawRows = [];
  List<String> _headers = [];
  Map<int, _CsvColumn> _columnMapping = {};

  // Account selection
  Account? _selectedAccount;

  // Parsed rows
  List<_ParsedRow> _parsedRows = [];

  // Import results
  int _imported = 0;
  int _duplicatesSkipped = 0;
  bool _importing = false;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _csvPasteCtrl.dispose();
    super.dispose();
  }

  // ─── STEP NAVIGATION ───────────────────────────────────────────────────

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'pdf', 'xls', 'xlsx'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final ext = file.extension?.toLowerCase() ?? '';
      _FileFormat fmt;
      switch (ext) {
        case 'csv': fmt = _FileFormat.csv; break;
        case 'pdf': fmt = _FileFormat.pdf; break;
        case 'xls': fmt = _FileFormat.xls; break;
        case 'xlsx': fmt = _FileFormat.xlsx; break;
        default: _showError('Unsupported file type: .$ext'); return;
      }

      setState(() {
        _fileBytes = file.bytes;
        _fileName = file.name;
        _fileFormat = fmt;
        _needsPassword = false;
        _passwordError = null;
        _passwordCtrl.clear();
      });

      _processFile();
    } catch (e) {
      _showError('Could not open file: $e');
    }
  }

  Future<void> _processFile() async {
    if (_fileBytes == null) return;

    if (_fileFormat == _FileFormat.pdf) {
      setState(() => _isProcessing = true);
      final bytes = _fileBytes!;
      final text  = await Future(() => _extractPdfText(bytes));
      if (!mounted) return;
      if (text == null) {
        // Likely password-protected
        setState(() {
          _isProcessing = false;
          _needsPassword = true;
          _step = _ImportStep.password;
        });
        return;
      }
      final bank = _detectBankFromText(text);
      final rows = await Future(() => _parsePdfText(text, bank));
      if (!mounted) return;
      setState(() => _isProcessing = false);
      if (rows.isEmpty) {
        _showPdfError();
        return;
      }
      setState(() {
        _detectedBank = bank;
        _parsedRows   = rows;
        _step         = _ImportStep.accountPick;
      });
      return;
    }

    if (_fileFormat == _FileFormat.csv) {
      final text = String.fromCharCodes(_fileBytes!);
      _processCsvText(text);
      return;
    }

    if (_fileFormat == _FileFormat.xls || _fileFormat == _FileFormat.xlsx) {
      _processExcel();
      return;
    }
  }

  void _processCsvText(String text) {
    final rows = _parseCsvText(text);
    if (rows.isEmpty) {
      _showError('No data found in file.');
      return;
    }
    final headers = rows.first;
    final bank = _detectBankFromHeaders(headers);
    final mapping = _buildColumnMapping(headers, bank);
    setState(() {
      _rawRows = rows;
      _headers = headers;
      _detectedBank = bank;
      _columnMapping = mapping;
      _step = _ImportStep.accountPick;
    });
  }

  void _processExcel() {
    try {
      final rows = _parseExcelBytes(_fileBytes!);
      if (rows.isEmpty) { _showError('No data found in file.'); return; }
      final headers = rows.first.map((c) => c.toString()).toList();
      final bank = _detectBankFromHeaders(headers);
      final mapping = _buildColumnMapping(headers, bank);
      setState(() {
        _rawRows = rows;
        _headers = headers;
        _detectedBank = bank;
        _columnMapping = mapping;
        _step = _ImportStep.accountPick;
      });
    } catch (e) {
      // Excel files can be password-protected too
      setState(() {
        _needsPassword = true;
        _step = _ImportStep.password;
      });
    }
  }


  Future<void> _submitPassword() async {
    final pwd = _passwordCtrl.text.trim();
    if (pwd.isEmpty) {
      setState(() => _passwordError = 'Please enter the file password.');
      return;
    }
    setState(() { _passwordError = null; _isProcessing = true; });

    if (_fileFormat == _FileFormat.pdf) {
      // Run heavy PDF work off the UI thread
      final bytes = _fileBytes!;
      final variants = {pwd, pwd.toUpperCase(), pwd.toLowerCase()}.toList();

      String? text;
      for (final variant in variants) {
        // Use Future.microtask so the loading indicator renders before blocking
        text = await Future(() => _extractPdfText(bytes, password: variant));
        if (text != null) break;
      }

      if (!mounted) return;
      if (text == null) {
        setState(() {
          _isProcessing = false;
          _passwordError = 'Incorrect password. Please try again.';
        });
        return;
      }

      // Parse off UI thread too — can be slow on large statements
      final bank  = _detectBankFromText(text);
      final rows  = await Future(() => _parsePdfText(text!, bank));

      if (!mounted) return;
      setState(() => _isProcessing = false);

      if (rows.isEmpty) {
        _showPdfError();
        return;
      }
      setState(() {
        _detectedBank = bank;
        _parsedRows   = rows;
        _step         = _ImportStep.accountPick;
      });
      return;
    }

    setState(() => _isProcessing = false);
    // For Excel password-protected files, the excel package doesn't support it natively.
    setState(() {
      _passwordError = 'Password-protected Excel files are not yet supported. '
          'Please save as CSV first (File → Save As → CSV in Excel).';
    });
  }

  void _onAccountSelected(Account account) {
    setState(() {
      _selectedAccount = account;
      // For PDF format, parsedRows are already ready
      if (_fileFormat == _FileFormat.pdf) {
        _detectDuplicatesStep();
        _step = _ImportStep.review;
        return;
      }
      // For CSV/XLS, check if column mapping needs manual review
      final cols = _columnMapping.values.toSet();
      final autoMapped = cols.contains(_CsvColumn.date) &&
          cols.contains(_CsvColumn.description) &&
          (cols.contains(_CsvColumn.amount) ||
           cols.contains(_CsvColumn.debit) ||
           cols.contains(_CsvColumn.credit));
      if (autoMapped) {
        _buildParsedRows();
        _step = _ImportStep.review;
      } else {
        _step = _ImportStep.colMapping;
      }
    });
  }

  void _buildParsedRows() {
    final dataRows = _rawRows.length > 1 ? _rawRows.sublist(1) : _rawRows;
    final rows = _buildRowsFromCsv(dataRows, _columnMapping);
    setState(() {
      _parsedRows = rows;
    });
    _detectDuplicatesStep();
  }

  void _detectDuplicatesStep() {
    final existing = context.read<TransactionsController>().transactions;
    _detectDuplicates(_parsedRows, existing);
  }

  Future<void> _importTransactions() async {
    setState(() { _importing = true; _step = _ImportStep.importing; });

    final controller = context.read<TransactionsController>();
    final account = _selectedAccount!;

    final toAdd = <Transaction>[];
    int dupes = 0;

    for (final row in _parsedRows) {
      if (row.isDuplicate && !row.includeIfDuplicate) {
        dupes++;
        continue;
      }
      final (categoryName, txType, merchant) = _buildTxMeta(row);
      toAdd.add(Transaction(
        id: IdGenerator.next(prefix: 'imp'),
        type: row.isDebit ? txType : TransactionType.income,
        description: row.description,
        dateTime: row.date,
        amount: row.amount,
        sourceAccountId: account.id,
        sourceAccountName: account.name,
        metadata: {
          'source': 'bank_import',
          'categoryName': categoryName,
          'merchant': merchant ?? row.description,
          'bank': _bankDisplayName(_detectedBank),
          if (row.reference != null) 'reference': row.reference,
          if (_fileName != null) 'importFile': _fileName,
        },
      ));
    }

    await controller.addTransactionsBatch(toAdd);

    setState(() {
      _imported = toAdd.length;
      _duplicatesSkipped = dupes;
      _importing = false;
      _step = _ImportStep.done;
    });
  }

  (String, TransactionType, String?) _buildTxMeta(_ParsedRow row) {
    final cat = _categorize(row.description);
    final merchant = _cleanMerchant(row.description);
    return (cat.categoryName, cat.type, merchant);
  }

  // ─── ERROR ──────────────────────────────────────────────────────────────

  void _showError(String msg) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Error'),
        content: Text(msg),
        actions: [
          CupertinoDialogAction(child: const Text('OK'), onPressed: () => Navigator.of(ctx).pop()),
        ],
      ),
    );
  }

  void _showPdfError() {
    _showError(
      'Could not extract transactions from this PDF.\n\n'
      'Try exporting your statement as CSV from your bank\'s app or website.',
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final title = _stepTitle();
    return CupertinoPageScaffold(
      backgroundColor: AppStyles.getBackground(context),
      navigationBar: AppStyles.isLandscape(context)
          ? null
          : CupertinoNavigationBar(
              middle: Text(title, style: TextStyle(color: AppStyles.getTextColor(context))),
              previousPageTitle: _step == _ImportStep.landing ? 'Back' : null,
              leading: _step != _ImportStep.landing && _step != _ImportStep.done && _step != _ImportStep.importing
                  ? CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: _goBack,
                      child: Icon(CupertinoIcons.chevron_left, color: AppStyles.getPrimaryColor(context)),
                    )
                  : null,
              backgroundColor: AppStyles.isDarkMode(context) ? Colors.black : Colors.white.withValues(alpha: 0.95),
              border: null,
            ),
      child: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: KeyedSubtree(
            key: ValueKey(_step),
            child: _buildCurrentStep(),
          ),
        ),
      ),
    );
  }

  String _stepTitle() {
    switch (_step) {
      case _ImportStep.landing: return 'Import Bank Statement';
      case _ImportStep.password: return 'Enter Password';
      case _ImportStep.accountPick: return 'Link Account';
      case _ImportStep.colMapping: return 'Map Columns';
      case _ImportStep.review: return 'Review Transactions';
      case _ImportStep.importing: return 'Importing…';
      case _ImportStep.done: return 'Import Complete';
    }
  }

  void _goBack() {
    setState(() {
      switch (_step) {
        case _ImportStep.password:
          _step = _ImportStep.landing;
          break;
        case _ImportStep.accountPick:
          _step = _ImportStep.landing;
          break;
        case _ImportStep.colMapping:
          _step = _ImportStep.accountPick;
          break;
        case _ImportStep.review:
          if (_fileFormat == _FileFormat.pdf) {
            _step = _ImportStep.accountPick;
          } else {
            final cols = _columnMapping.values.toSet();
            final autoMapped = cols.contains(_CsvColumn.date) &&
                cols.contains(_CsvColumn.description);
            _step = autoMapped ? _ImportStep.accountPick : _ImportStep.colMapping;
          }
          break;
        default: break;
      }
    });
  }

  Widget _buildCurrentStep() {
    switch (_step) {
      case _ImportStep.landing: return _buildLanding();
      case _ImportStep.password: return _buildPasswordStep();
      case _ImportStep.accountPick: return _buildAccountPick();
      case _ImportStep.colMapping: return _buildColMapping();
      case _ImportStep.review: return _buildReview();
      case _ImportStep.importing: return _buildImporting();
      case _ImportStep.done: return _buildDone();
    }
  }

  // ─── STEP 0: LANDING ────────────────────────────────────────────────────

  Widget _buildLanding() {
    return ListView(
      padding: const EdgeInsets.all(Spacing.lg),
      children: [
        _buildHeroHeader(),
        const SizedBox(height: Spacing.xl),
        // Format cards
        Text('Supported Formats',
          style: TextStyle(fontSize: TypeScale.footnote, fontWeight: FontWeight.w700,
              color: AppStyles.getSecondaryTextColor(context), letterSpacing: 0.5)),
        const SizedBox(height: Spacing.md),
        _buildFormatGrid(),
        const SizedBox(height: Spacing.xl),
        // Pick file button
        BouncyButton(
          onPressed: _pickFile,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: AppStyles.aetherTeal,
              borderRadius: BorderRadius.circular(Radii.lg),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(CupertinoIcons.folder_open, color: Colors.black, size: 18),
                SizedBox(width: 8),
                Text('Pick File from Storage',
                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 15)),
              ],
            ),
          ),
        ),
        const SizedBox(height: Spacing.lg),
        // Or divider
        Row(children: [
          Expanded(child: Divider(color: AppStyles.getSecondaryTextColor(context).withValues(alpha: 0.2))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text('or', style: TextStyle(fontSize: TypeScale.footnote, color: AppStyles.getSecondaryTextColor(context))),
          ),
          Expanded(child: Divider(color: AppStyles.getSecondaryTextColor(context).withValues(alpha: 0.2))),
        ]),
        const SizedBox(height: Spacing.lg),
        // Paste CSV toggle
        if (!_pasteMode)
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => setState(() => _pasteMode = true),
            child: Text('Paste CSV text instead',
                style: TextStyle(fontSize: TypeScale.footnote, color: AppStyles.aetherTeal)),
          )
        else ...[
          Text('Paste CSV Text',
              style: TextStyle(fontSize: TypeScale.footnote, fontWeight: FontWeight.w700, color: AppStyles.getTextColor(context))),
          const SizedBox(height: Spacing.sm),
          Container(
            decoration: BoxDecoration(
              color: AppStyles.getCardColor(context),
              borderRadius: BorderRadius.circular(Radii.md),
            ),
            child: CupertinoTextField(
              controller: _csvPasteCtrl,
              placeholder: 'Date,Description,Amount\n01/01/2026,Zomato,-250\n02/01/2026,Salary,50000',
              maxLines: 8,
              padding: const EdgeInsets.all(Spacing.md),
              style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: AppStyles.getTextColor(context)),
              placeholderStyle: TextStyle(fontSize: 11, color: AppStyles.getSecondaryTextColor(context).withValues(alpha: 0.5)),
              decoration: null,
            ),
          ),
          const SizedBox(height: Spacing.md),
          BouncyButton(
            onPressed: () {
              if (_csvPasteCtrl.text.trim().isEmpty) {
                _showError('Please paste some CSV data first.'); return;
              }
              setState(() { _fileFormat = _FileFormat.csv; });
              _processCsvText(_csvPasteCtrl.text);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(color: AppStyles.aetherTeal, borderRadius: BorderRadius.circular(Radii.md)),
              child: const Center(
                child: Text('Parse CSV', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ],
        const SizedBox(height: Spacing.xl),
        _buildBankSupportInfo(),
      ],
    );
  }

  Widget _buildHeroHeader() {
    return Container(
      padding: const EdgeInsets.all(Spacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF00B890).withValues(alpha: 0.12), const Color(0xFF7B5CEF).withValues(alpha: 0.08)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: const Color(0xFF00B890).withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF00B890), Color(0xFF7B5CEF)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(CupertinoIcons.arrow_down_doc_fill, color: Colors.white, size: 22),
          ),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Smart Bank Import', style: TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 16,
                    fontWeight: FontWeight.w700, color: AppStyles.getTextColor(context))),
                const SizedBox(height: 2),
                Text('AI-powered parsing · 14 banks · 4 formats',
                    style: TextStyle(fontSize: 11, color: AppStyles.getSecondaryTextColor(context))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormatGrid() {
    const formats = [
      ('CSV', CupertinoIcons.doc_text, Color(0xFF00B890), 'Excel export, bank portal'),
      ('PDF', CupertinoIcons.doc_richtext, Color(0xFFE53E3E), 'Bank statement PDFs'),
      ('XLS', CupertinoIcons.table, Color(0xFF2E7D32), 'Older Excel format'),
      ('XLSX', CupertinoIcons.doc_chart_fill, Color(0xFF1565C0), 'Modern Excel format'),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 3.2,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: formats.map((f) {
        final (label, icon, color, sub) = f;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Row(children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppStyles.getTextColor(context))),
                Text(sub, style: TextStyle(fontSize: 9, color: AppStyles.getSecondaryTextColor(context)), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            )),
          ]),
        );
      }).toList(),
    );
  }

  Widget _buildBankSupportInfo() {
    const banks = [
      'HDFC Bank', 'SBI', 'ICICI Bank', 'Axis Bank', 'Kotak Bank',
      'IndusInd', 'Yes Bank', 'Federal Bank', 'RBL Bank', 'IDFC First',
      'AmEx', 'Citibank', 'HDFC CC', '+ any CSV',
    ];
    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: AppStyles.getCardColor(context),
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Supported Banks',
              style: TextStyle(fontSize: TypeScale.caption, fontWeight: FontWeight.w700,
                  color: AppStyles.getSecondaryTextColor(context), letterSpacing: 0.4)),
          const SizedBox(height: Spacing.sm),
          Wrap(
            spacing: 6, runSpacing: 6,
            children: banks.map((b) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppStyles.aetherTeal.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppStyles.aetherTeal.withValues(alpha: 0.2)),
              ),
              child: Text(b, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Color(0xFF00B890))),
            )).toList(),
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            'Balances are NOT modified — import is read-only.',
            style: TextStyle(fontSize: 10, color: AppStyles.getSecondaryTextColor(context), fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  // ─── STEP 1: PASSWORD ───────────────────────────────────────────────────

  Widget _buildPasswordStep() {
    return ListView(
      padding: const EdgeInsets.all(Spacing.lg),
      children: [
        _StepHeader(
          step: 1, total: 4,
          icon: CupertinoIcons.lock_shield_fill,
          iconColor: CupertinoColors.systemOrange,
          title: 'File is Password Protected',
          subtitle: 'Enter the password to unlock your statement file.',
        ),
        const SizedBox(height: Spacing.xl),
        Container(
          padding: const EdgeInsets.all(Spacing.md),
          decoration: BoxDecoration(
            color: CupertinoColors.systemOrange.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(Radii.md),
            border: Border.all(color: CupertinoColors.systemOrange.withValues(alpha: 0.25)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(CupertinoIcons.info_circle, size: 14, color: CupertinoColors.systemOrange),
              const SizedBox(width: 6),
              Text('Common passwords:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppStyles.getTextColor(context))),
            ]),
            const SizedBox(height: 6),
            Text(
              '• HDFC: Your PAN number (e.g. ABCDE1234F)\n'
              '• SBI / ICICI: Date of birth (DDMMYYYY)\n'
              '• Axis Bank: Last 4 digits of registered mobile\n'
              '• Kotak: Date of birth (DDMMYYYY)\n'
              '• Credit Cards: PAN number or registered mobile',
              style: TextStyle(fontSize: 11, color: AppStyles.getSecondaryTextColor(context), height: 1.6),
            ),
          ]),
        ),
        const SizedBox(height: Spacing.lg),
        Text(_fileName ?? 'Selected file',
            style: TextStyle(fontSize: TypeScale.caption, color: AppStyles.getSecondaryTextColor(context))),
        const SizedBox(height: Spacing.sm),
        Container(
          decoration: BoxDecoration(
            color: AppStyles.getCardColor(context),
            borderRadius: BorderRadius.circular(Radii.md),
            border: _passwordError != null
                ? Border.all(color: SemanticColors.error.withValues(alpha: 0.6))
                : null,
          ),
          child: CupertinoTextField(
            controller: _passwordCtrl,
            placeholder: 'Enter file password',
            obscureText: !_showPassword,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            style: TextStyle(fontSize: TypeScale.body, color: AppStyles.getTextColor(context)),
            decoration: null,
            suffix: CupertinoButton(
              padding: const EdgeInsets.only(right: 8),
              minimumSize: Size.zero,
              onPressed: () => setState(() => _showPassword = !_showPassword),
              child: Icon(
                _showPassword ? CupertinoIcons.eye_slash : CupertinoIcons.eye,
                size: 18, color: AppStyles.getSecondaryTextColor(context),
              ),
            ),
          ),
        ),
        if (_passwordError != null) ...[
          const SizedBox(height: Spacing.sm),
          Text(_passwordError!, style: const TextStyle(fontSize: 12, color: SemanticColors.error)),
        ],
        const SizedBox(height: Spacing.xl),
        BouncyButton(
          onPressed: _isProcessing ? () {} : () => _submitPassword(),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: _isProcessing
                  ? AppStyles.aetherTeal.withValues(alpha: 0.5)
                  : AppStyles.aetherTeal,
              borderRadius: BorderRadius.circular(Radii.md),
            ),
            child: Center(
              child: _isProcessing
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.black,
                      ),
                    )
                  : const Text('Unlock File', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700)),
            ),
          ),
        ),
      ],
    );
  }

  // ─── STEP 2: ACCOUNT PICK ───────────────────────────────────────────────

  Widget _buildAccountPick() {
    final allAccounts = context.read<AccountsController>().accounts
        .where((a) => !a.isHidden).toList();

    // Split: accounts whose bank name matches detected bank vs rest
    final bankName = _bankDisplayName(_detectedBank).toLowerCase();
    final matchingAccounts = _detectedBank == _BankFormat.unknown
        ? <Account>[]
        : allAccounts.where((a) =>
            a.bankName.toLowerCase().contains(bankName.split(' ').first) ||
            bankName.contains(a.bankName.toLowerCase().split(' ').first)).toList();
    final otherAccounts = allAccounts
        .where((a) => !matchingAccounts.any((m) => m.id == a.id)).toList();

    return ListView(
      padding: const EdgeInsets.all(Spacing.lg),
      children: [
        _StepHeader(
          step: 2, total: 4,
          icon: CupertinoIcons.creditcard_fill,
          iconColor: AppStyles.aetherTeal,
          title: 'Which account is this?',
          subtitle: 'Select the account this statement belongs to. Balances are NOT modified.',
        ),
        if (_detectedBank != _BankFormat.unknown) ...[
          const SizedBox(height: Spacing.md),
          _buildDetectedBankBadge(_detectedBank),
        ],
        const SizedBox(height: Spacing.lg),
        if (allAccounts.isEmpty)
          Container(
            padding: const EdgeInsets.all(Spacing.lg),
            decoration: BoxDecoration(color: AppStyles.getCardColor(context), borderRadius: BorderRadius.circular(Radii.md)),
            child: Text('No accounts found. Add an account first.',
                style: TextStyle(color: AppStyles.getSecondaryTextColor(context)), textAlign: TextAlign.center),
          )
        else ...[
          // Matching bank accounts shown at top with a label
          if (matchingAccounts.isNotEmpty) ...[
            _buildSectionLabel('${_bankDisplayName(_detectedBank)} accounts'),
            ...matchingAccounts.map((acc) => _buildAccountTile(acc, highlighted: true)),
            if (otherAccounts.isNotEmpty) ...[
              const SizedBox(height: Spacing.md),
              _buildSectionLabel('Other accounts'),
            ],
          ],
          ...otherAccounts.map((acc) => _buildAccountTile(acc)),
        ],
        const SizedBox(height: Spacing.md),
        _buildSectionLabel('Not linked'),
        _buildAccountTile(null),
      ],
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.sm),
      child: Text(label,
          style: TextStyle(fontSize: TypeScale.caption, fontWeight: FontWeight.w700,
              color: AppStyles.getSecondaryTextColor(context), letterSpacing: 0.4)),
    );
  }

  Widget _buildAccountTile(Account? acc, {bool highlighted = false}) {
    final isSelected = _selectedAccount?.id == acc?.id && !(_selectedAccount == null && acc != null);
    final label = acc?.name ?? 'No specific account';
    final sub = acc != null ? '${acc.type.name.toUpperCase()} · ${acc.bankName}' : 'Transactions will not be linked to any account';
    final color = acc?.color ?? AppStyles.getSecondaryTextColor(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.sm),
      child: GestureDetector(
        onTap: () => _onAccountSelected(acc ?? _dummyAccount()),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(Spacing.md),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.1) : AppStyles.getCardColor(context),
            borderRadius: BorderRadius.circular(Radii.md),
            border: isSelected ? Border.all(color: color.withValues(alpha: 0.5), width: 1.5) : null,
          ),
          child: Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                child: Icon(acc != null ? CupertinoIcons.creditcard_fill : CupertinoIcons.question_circle_fill,
                    size: 18, color: color),
              ),
              const SizedBox(width: Spacing.md),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(label, style: TextStyle(fontWeight: FontWeight.w600, fontSize: TypeScale.footnote, color: AppStyles.getTextColor(context)))),
                  if (highlighted && !isSelected)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00B890).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('Likely', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF00B890))),
                    ),
                ]),
                Text(sub, style: TextStyle(fontSize: TypeScale.caption, color: AppStyles.getSecondaryTextColor(context))),
              ])),
              if (isSelected)
                Icon(CupertinoIcons.checkmark_circle_fill, size: 20, color: color),
            ],
          ),
        ),
      ),
    );
  }

  // Placeholder for "no account" selection
  Account _dummyAccount() => Account(
    id: '', name: 'No specific account', bankName: '',
    type: AccountType.savings, balance: 0, color: Colors.grey,
    createdDate: DateTime.now(),
  );

  // ─── STEP 3: COLUMN MAPPING ─────────────────────────────────────────────

  Widget _buildColMapping() {
    return ListView(
      padding: const EdgeInsets.all(Spacing.lg),
      children: [
        _StepHeader(
          step: 3, total: 4,
          icon: CupertinoIcons.table,
          iconColor: CupertinoColors.systemBlue,
          title: 'Map Columns',
          subtitle: 'Tell us what each column represents.',
        ),
        if (_detectedBank != _BankFormat.unknown) ...[
          const SizedBox(height: Spacing.md),
          _buildDetectedBankBadge(_detectedBank),
        ],
        const SizedBox(height: Spacing.lg),
        ..._headers.asMap().entries.map((e) {
          final i = e.key;
          final header = e.value;
          final current = _columnMapping[i] ?? _CsvColumn.skip;
          final sample = _rawRows.length > 1 ? (_rawRows[1].length > i ? _rawRows[1][i] : '') : '';
          return _buildMappingRow(i, header, current, sample);
        }),
        const SizedBox(height: Spacing.xl),
        Row(children: [
          Expanded(child: BouncyButton(
            onPressed: _goBack,
            child: _secondaryBtn('Back'),
          )),
          const SizedBox(width: Spacing.sm),
          Expanded(child: BouncyButton(
            onPressed: () {
              final cols = _columnMapping.values.toSet();
              if (!cols.contains(_CsvColumn.date)) { _showError('Please map a Date column.'); return; }
              if (!cols.contains(_CsvColumn.description)) { _showError('Please map a Description column.'); return; }
              if (!cols.contains(_CsvColumn.amount) && !cols.contains(_CsvColumn.debit)) {
                _showError('Please map an Amount or Debit column.'); return;
              }
              _buildParsedRows();
              setState(() => _step = _ImportStep.review);
            },
            child: _primaryBtn('Preview'),
          )),
        ]),
      ],
    );
  }

  Widget _buildMappingRow(int i, String header, _CsvColumn current, String sample) {
    return Container(
      margin: const EdgeInsets.only(bottom: Spacing.md),
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(color: AppStyles.getCardColor(context), borderRadius: BorderRadius.circular(Radii.md)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(header, style: TextStyle(fontWeight: FontWeight.w600, fontSize: TypeScale.footnote, color: AppStyles.getTextColor(context))),
            if (sample.isNotEmpty)
              Text('e.g. $sample', style: TextStyle(fontSize: 10, color: AppStyles.getSecondaryTextColor(context)), maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
        ]),
        const SizedBox(height: Spacing.sm),
        Wrap(
          spacing: 6, runSpacing: 6,
          children: _CsvColumn.values.map((col) {
            final active = current == col;
            return GestureDetector(
              onTap: () => setState(() => _columnMapping[i] = col),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: active ? AppStyles.aetherTeal.withValues(alpha: 0.15) : AppStyles.getBackground(context),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: active ? AppStyles.aetherTeal.withValues(alpha: 0.6) : AppStyles.getSecondaryTextColor(context).withValues(alpha: 0.2),
                    width: active ? 1.5 : 1,
                  ),
                ),
                child: Text(_csvColumnLabels[col]!,
                    style: TextStyle(fontSize: 11, fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                        color: active ? AppStyles.aetherTeal : AppStyles.getSecondaryTextColor(context))),
              ),
            );
          }).toList(),
        ),
      ]),
    );
  }

  // ─── STEP 4: REVIEW ─────────────────────────────────────────────────────

  Widget _buildReview() {
    final total = _parsedRows.length;
    final duplicates = _parsedRows.where((r) => r.isDuplicate).length;
    final income = _parsedRows.where((r) => !r.isDebit).fold(0.0, (s, r) => s + r.amount);
    final expense = _parsedRows.where((r) => r.isDebit).fold(0.0, (s, r) => s + r.amount);

    return Column(children: [
      // Summary cards
      Padding(
        padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.md, Spacing.lg, 0),
        child: Column(children: [
          _buildSummaryCards(total, duplicates, income, expense),
          if (duplicates > 0) ...[
            const SizedBox(height: Spacing.md),
            _buildDuplicateWarning(duplicates),
          ],
          const SizedBox(height: Spacing.md),
        ]),
      ),
      // Transaction list
      Expanded(
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(Spacing.lg, 0, Spacing.lg, 100),
          itemCount: _parsedRows.length,
          separatorBuilder: (_, __) => const SizedBox(height: Spacing.xs),
          itemBuilder: (ctx, i) => _buildReviewTile(_parsedRows[i], i),
        ),
      ),
      // Bottom action bar
      _buildReviewBottomBar(total, duplicates),
    ]);
  }

  Widget _buildSummaryCards(int total, int dupes, double income, double expense) {
    return Row(children: [
      _buildSummaryChip('$total', 'transactions', CupertinoColors.systemBlue),
      const SizedBox(width: 8),
      _buildSummaryChip('+₹${_fmt(income)}', 'credit', CupertinoColors.activeGreen),
      const SizedBox(width: 8),
      _buildSummaryChip('-₹${_fmt(expense)}', 'debit', CupertinoColors.systemRed),
      if (dupes > 0) ...[
        const SizedBox(width: 8),
        _buildSummaryChip('$dupes', 'dupes', CupertinoColors.systemOrange),
      ],
    ]);
  }

  Widget _buildSummaryChip(String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(children: [
          Text(value, style: TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 12, fontWeight: FontWeight.w700, color: color)),
          Text(label, style: TextStyle(fontSize: 9, color: AppStyles.getSecondaryTextColor(context))),
        ]),
      ),
    );
  }

  Widget _buildDuplicateWarning(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.sm),
      decoration: BoxDecoration(
        color: CupertinoColors.systemOrange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(Radii.sm),
        border: Border.all(color: CupertinoColors.systemOrange.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        const Icon(CupertinoIcons.exclamationmark_triangle_fill, size: 14, color: CupertinoColors.systemOrange),
        const SizedBox(width: 8),
        Expanded(child: Text(
          '$count possible duplicate${count > 1 ? 's' : ''} detected — toggled OFF by default. Tap to include.',
          style: const TextStyle(fontSize: 11, color: CupertinoColors.systemOrange),
        )),
      ]),
    );
  }

  Widget _buildReviewTile(_ParsedRow row, int index) {
    final cat         = _categorize(row.description);
    final isDuplicate = row.isDuplicate;
    final isIncluded  = !isDuplicate || row.includeIfDuplicate;
    final isExpanded  = _expandedReviewIndex == index;
    final txColor     = row.isDebit ? SemanticColors.error : SemanticColors.success;

    // Formatted date e.g. "01 Mar 2026"
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final dateLabel =
        '${row.date.day.toString().padLeft(2, '0')} ${months[row.date.month - 1]} ${row.date.year}';

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: isIncluded ? 1.0 : 0.45,
      child: GestureDetector(
        onTap: () => setState(() =>
            _expandedReviewIndex = isExpanded ? null : index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: AppStyles.getCardColor(context),
            borderRadius: BorderRadius.circular(Radii.md),
            border: isDuplicate
                ? Border.all(
                    color: CupertinoColors.systemOrange
                        .withValues(alpha: isIncluded ? 0.5 : 0.25),
                    width: 1)
                : isExpanded
                    ? Border.all(
                        color: txColor.withValues(alpha: 0.35), width: 1)
                    : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Collapsed header row ──────────────────────────────────────
              Padding(
                padding: const EdgeInsets.all(Spacing.sm),
                child: Row(children: [
                  // Type icon
                  Container(
                    width: 34, height: 34,
                    decoration: BoxDecoration(
                      color: txColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      row.isDebit
                          ? CupertinoIcons.arrow_down_circle_fill
                          : CupertinoIcons.arrow_up_circle_fill,
                      size: 16, color: txColor,
                    ),
                  ),
                  const SizedBox(width: Spacing.sm),
                  // Merchant + date + category
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(child: Text(
                          _cleanMerchant(row.description),
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600,
                              color: AppStyles.getTextColor(context)),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        )),
                        if (isDuplicate)
                          Container(
                            margin: const EdgeInsets.only(left: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: CupertinoColors.systemOrange.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('Duplicate',
                                style: TextStyle(fontSize: 8,
                                    color: CupertinoColors.systemOrange,
                                    fontWeight: FontWeight.w700)),
                          ),
                      ]),
                      Row(children: [
                        Text(dateLabel,
                            style: TextStyle(fontSize: 10,
                                color: AppStyles.getSecondaryTextColor(context))),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: CupertinoColors.systemGrey6.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(cat.categoryName,
                              style: TextStyle(fontSize: 9,
                                  color: AppStyles.getSecondaryTextColor(context))),
                        ),
                      ]),
                    ],
                  )),
                  const SizedBox(width: Spacing.sm),
                  // Amount + expand chevron
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(
                      '${row.isDebit ? '-' : '+'}₹${_fmt(row.amount)}',
                      style: TextStyle(
                          fontFamily: 'SpaceGrotesk', fontSize: 13,
                          fontWeight: FontWeight.w700, color: txColor),
                    ),
                    if (isDuplicate) ...[
                      const SizedBox(height: 2),
                      GestureDetector(
                        onTap: () => setState(
                            () => row.includeIfDuplicate = !row.includeIfDuplicate),
                        child: Text(
                          row.includeIfDuplicate ? 'Include' : 'Skip',
                          style: TextStyle(
                            fontSize: 10,
                            color: row.includeIfDuplicate
                                ? const Color(0xFF00B890)
                                : CupertinoColors.systemOrange,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ] else
                      AnimatedRotation(
                        turns: isExpanded ? 0.5 : 0.0,
                        duration: const Duration(milliseconds: 220),
                        child: Icon(CupertinoIcons.chevron_down,
                            size: 11,
                            color: AppStyles.getSecondaryTextColor(context)),
                      ),
                  ]),
                ]),
              ),

              // ── Expanded detail panel ─────────────────────────────────────
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeInOut,
                child: isExpanded
                    ? _buildExpandedDetail(row, cat, txColor, dateLabel)
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedDetail(
      _ParsedRow row, _CategoryResult cat, Color txColor, String dateLabel) {
    final secColor = AppStyles.getSecondaryTextColor(context);
    final divColor = const Color(0xFF1C1C1C);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(height: 1, color: divColor),
        Padding(
          padding: const EdgeInsets.fromLTRB(Spacing.sm, Spacing.sm, Spacing.sm, Spacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // Full narration
              _detailRow(
                CupertinoIcons.doc_text, 'Full Description',
                row.description, secColor,
              ),
              const SizedBox(height: Spacing.sm),

              // Date + Type side by side
              Row(children: [
                Expanded(child: _detailRow(
                  CupertinoIcons.calendar, 'Date', dateLabel, secColor,
                )),
                const SizedBox(width: Spacing.md),
                Expanded(child: _detailRow(
                  row.isDebit
                      ? CupertinoIcons.minus_circle_fill
                      : CupertinoIcons.plus_circle_fill,
                  'Type',
                  row.isDebit ? 'Expense / Debit' : 'Income / Credit',
                  secColor,
                  valueColor: txColor,
                )),
              ]),
              const SizedBox(height: Spacing.sm),

              // Category + Amount side by side
              Row(children: [
                Expanded(child: _detailRow(
                  CupertinoIcons.tag_fill, 'Category',
                  cat.categoryName, secColor,
                )),
                const SizedBox(width: Spacing.md),
                Expanded(child: _detailRow(
                  CupertinoIcons.money_dollar_circle_fill, 'Amount',
                  '₹${_fmt(row.amount)}', secColor,
                  valueColor: txColor,
                )),
              ]),

              // Reference (if present)
              if (row.reference != null && row.reference!.isNotEmpty) ...[
                const SizedBox(height: Spacing.sm),
                _detailRow(
                  CupertinoIcons.number_circle, 'Reference',
                  row.reference!, secColor,
                ),
              ],

              const SizedBox(height: Spacing.sm),
              Divider(height: 1, color: divColor),
              const SizedBox(height: Spacing.sm),

              // Flip debit/credit button
              GestureDetector(
                onTap: () => setState(() => row.isDebit = !row.isDebit),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: txColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(Radii.sm),
                    border: Border.all(color: txColor.withValues(alpha: 0.25)),
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(CupertinoIcons.arrow_2_squarepath,
                        size: 13, color: txColor),
                    const SizedBox(width: 6),
                    Text(
                      row.isDebit
                          ? 'Mark as Income instead'
                          : 'Mark as Expense instead',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600,
                          color: txColor),
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _detailRow(IconData icon, String label, String value, Color secColor,
      {Color? valueColor}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, size: 10, color: secColor),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(fontSize: 9, color: secColor,
                fontWeight: FontWeight.w500)),
      ]),
      const SizedBox(height: 2),
      Text(value,
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600,
              color: valueColor ?? AppStyles.getTextColor(context))),
    ]);
  }

  Widget _buildReviewBottomBar(int total, int dupes) {
    final toImport = _parsedRows.where((r) => !r.isDuplicate || r.includeIfDuplicate).length;
    return Container(
      padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.md, Spacing.lg, Spacing.lg),
      decoration: BoxDecoration(
        color: AppStyles.getBackground(context),
        boxShadow: AppStyles.elevatedShadows(context, strength: 0.3),
      ),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$toImport transactions will be imported',
              style: TextStyle(fontSize: TypeScale.footnote, fontWeight: FontWeight.w600, color: AppStyles.getTextColor(context))),
          if (dupes > 0)
            Text('${dupes - _parsedRows.where((r) => r.isDuplicate && r.includeIfDuplicate).length} duplicates skipped',
                style: TextStyle(fontSize: TypeScale.caption, color: AppStyles.getSecondaryTextColor(context))),
        ])),
        const SizedBox(width: Spacing.md),
        BouncyButton(
          onPressed: () { if (toImport > 0) _importTransactions(); },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.xl, vertical: 12),
            decoration: BoxDecoration(
              color: toImport > 0 ? AppStyles.aetherTeal : AppStyles.getSecondaryTextColor(context).withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(Radii.md),
            ),
            child: Text('Import $toImport', style: TextStyle(
                color: toImport > 0 ? Colors.black : AppStyles.getSecondaryTextColor(context),
                fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }

  // ─── IMPORTING ──────────────────────────────────────────────────────────

  Widget _buildImporting() {
    return const Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        CupertinoActivityIndicator(radius: 18),
        SizedBox(height: Spacing.lg),
        Text('Importing transactions…', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
      ]),
    );
  }

  // ─── STEP 5: DONE ───────────────────────────────────────────────────────

  Widget _buildDone() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.xl),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: SemanticColors.success.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(CupertinoIcons.checkmark_circle_fill, size: 44, color: SemanticColors.success),
          ),
          const SizedBox(height: Spacing.lg),
          Text('Import Complete',
              style: TextStyle(fontFamily: 'SpaceGrotesk', fontSize: TypeScale.title2,
                  fontWeight: FontWeight.w700, color: AppStyles.getTextColor(context))),
          const SizedBox(height: Spacing.sm),
          Text('$_imported transaction${_imported != 1 ? 's' : ''} imported',
              style: TextStyle(fontSize: TypeScale.body, color: AppStyles.getSecondaryTextColor(context))),
          if (_duplicatesSkipped > 0) ...[
            const SizedBox(height: Spacing.xs),
            Text('$_duplicatesSkipped duplicate${_duplicatesSkipped != 1 ? 's' : ''} skipped',
                style: const TextStyle(fontSize: TypeScale.footnote, color: CupertinoColors.systemOrange)),
          ],
          if (_selectedAccount != null && _selectedAccount!.id.isNotEmpty) ...[
            const SizedBox(height: Spacing.xs),
            Text('Linked to: ${_selectedAccount!.name}',
                style: TextStyle(fontSize: TypeScale.footnote, color: AppStyles.getSecondaryTextColor(context))),
          ],
          const SizedBox(height: Spacing.xxl),
          BouncyButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: Spacing.xl, vertical: Spacing.md),
              decoration: BoxDecoration(color: AppStyles.aetherTeal, borderRadius: BorderRadius.circular(Radii.md)),
              child: const Text('Done', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ),
        ]),
      ),
    );
  }

  // ─── SHARED WIDGETS ─────────────────────────────────────────────────────

  Widget _primaryBtn(String label) => Container(
    padding: const EdgeInsets.symmetric(vertical: Spacing.md),
    decoration: BoxDecoration(color: AppStyles.aetherTeal, borderRadius: BorderRadius.circular(Radii.md)),
    child: Center(child: Text(label, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w700))),
  );

  Widget _secondaryBtn(String label) => Container(
    padding: const EdgeInsets.symmetric(vertical: Spacing.md),
    decoration: BoxDecoration(color: AppStyles.getCardColor(context), borderRadius: BorderRadius.circular(Radii.md)),
    child: Center(child: Text(label, style: TextStyle(color: AppStyles.getTextColor(context), fontWeight: FontWeight.w600))),
  );

  Widget _buildDetectedBankBadge(_BankFormat bank) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.sm),
      decoration: BoxDecoration(
        color: CupertinoColors.activeGreen.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(Radii.sm),
        border: Border.all(color: CupertinoColors.activeGreen.withValues(alpha: 0.25)),
      ),
      child: Row(children: [
        const Icon(CupertinoIcons.checkmark_seal_fill, size: 13, color: CupertinoColors.activeGreen),
        const SizedBox(width: 6),
        Text(
          'Detected: ${_bankDisplayName(bank)} — format auto-recognised',
          style: const TextStyle(fontSize: TypeScale.caption, color: CupertinoColors.activeGreen, fontWeight: FontWeight.w500),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════════════════════════════════════

String _fmt(double v) {
  if (v >= 10000000) return '${(v / 10000000).toStringAsFixed(1)}Cr';
  if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
  if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
  return v.toStringAsFixed(0);
}

// ═══════════════════════════════════════════════════════════════════════════
// STEP HEADER WIDGET
// ═══════════════════════════════════════════════════════════════════════════

class _StepHeader extends StatelessWidget {
  final int step;
  final int total;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  const _StepHeader({
    required this.step,
    required this.total,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 20, color: iconColor),
      ),
      const SizedBox(width: Spacing.md),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Step $step of $total',
            style: TextStyle(fontSize: TypeScale.caption, color: AppStyles.aetherTeal, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(title, style: TextStyle(fontSize: TypeScale.title3, fontWeight: FontWeight.w700, color: AppStyles.getTextColor(context))),
        const SizedBox(height: Spacing.xs),
        Text(subtitle, style: TextStyle(fontSize: TypeScale.footnote, color: AppStyles.getSecondaryTextColor(context))),
      ])),
    ]);
  }
}
