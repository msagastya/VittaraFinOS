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
  unknown
}

class _ParsedRow {
  final DateTime date;
  final String description;
  final double amount;
  final bool isDebit; // true = expense, false = income
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
  if (t.contains('hdfc bank')) {
    return t.contains('credit card') ? _BankFormat.hdfcCc : _BankFormat.hdfc;
  }
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
/// Returns null if wrong password.
String? _extractPdfText(Uint8List bytes, {String? password}) {
  try {
    final doc = PdfDocument(inputBytes: bytes, password: password ?? '');
    final extractor = PdfTextExtractor(doc);
    final text = extractor.extractText();
    doc.dispose();
    return text;
  } catch (e) {
    return null;
  }
}

/// Parses extracted PDF text into rows using bank-specific line parsers.
List<_ParsedRow> _parsePdfText(String text, _BankFormat bank) {
  final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
  final result = <_ParsedRow>[];

  // Generic date-anchored line parser
  // Looks for lines that start with or contain a recognizable date pattern
  // followed by a description and amount(s)
  final datePattern = RegExp(
    r'(\d{1,2}[/\-\.]\d{1,2}[/\-\.]\d{2,4}|\d{1,2}\s+[A-Za-z]{3}\s+\d{2,4})',
  );

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final dm = datePattern.firstMatch(line);
    if (dm == null) continue;

    final date = _parseDate(dm.group(1)!);
    if (date == null) continue;

    // Extract amounts from the line (numbers with optional decimals)
    final amounts = RegExp(r'[\d,]+\.?\d{0,2}').allMatches(line)
        .map((m) => double.tryParse(m.group(0)!.replaceAll(',', '')))
        .where((v) => v != null && v > 0)
        .cast<double>()
        .toList();
    if (amounts.isEmpty) continue;

    // Description: text between the date match and the first number
    var desc = line.substring(dm.end).trim();
    // Remove leading reference numbers
    desc = desc.replaceAll(RegExp(r'^\d{6,}\s*'), '').trim();
    // Remove trailing amounts
    desc = desc.replaceAll(RegExp(r'[\d,]+\.?\d{0,2}\s*$'), '').trim();
    if (desc.length < 3) {
      // Try merging with next line if it looks like a continuation
      if (i + 1 < lines.length && !datePattern.hasMatch(lines[i + 1])) {
        desc = lines[i + 1].replaceAll(RegExp(r'[\d,]+\.?\d{0,2}'), '').trim();
      }
    }
    if (desc.length < 3) continue;

    // For debit/credit split: try to determine direction from keywords
    final isDebit = _isDebitLine(line, bank);

    result.add(_ParsedRow(
      date: date,
      description: desc,
      amount: amounts.first,
      isDebit: isDebit,
      rawLine: line,
    ));
  }
  return result;
}

bool _isDebitLine(String line, _BankFormat bank) {
  final l = line.toLowerCase();
  if (l.contains('cr ') || l.contains(' cr') || l.contains('credit') ||
      l.contains('deposit') || l.contains('salary')) return false;
  if (l.contains('dr ') || l.contains(' dr') || l.contains('debit') ||
      l.contains('withdrawal') || l.contains('payment')) return true;
  // Default: assume debit if no signal
  return true;
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

  void _processFile() {
    if (_fileBytes == null) return;

    if (_fileFormat == _FileFormat.pdf) {
      final text = _extractPdfText(_fileBytes!);
      if (text == null) {
        // Likely password-protected
        setState(() {
          _needsPassword = true;
          _step = _ImportStep.password;
        });
        return;
      }
      _processPdfText(text);
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

  void _processPdfText(String text) {
    final bank = _detectBankFromText(text);
    final rows = _parsePdfText(text, bank);
    if (rows.isEmpty) {
      _showError('Could not extract transactions from this PDF.\n\nTry exporting your statement as CSV from your bank\'s app or website.');
      return;
    }
    setState(() {
      _detectedBank = bank;
      _parsedRows = rows;
      _step = _ImportStep.accountPick;
    });
  }

  void _submitPassword() {
    final pwd = _passwordCtrl.text.trim();
    if (pwd.isEmpty) {
      setState(() => _passwordError = 'Please enter the file password.');
      return;
    }
    setState(() { _passwordError = null; });

    if (_fileFormat == _FileFormat.pdf) {
      final text = _extractPdfText(_fileBytes!, password: pwd);
      if (text == null) {
        setState(() => _passwordError = 'Incorrect password. Please try again.');
        return;
      }
      _processPdfText(text);
      return;
    }

    // For Excel password-protected files, the excel package doesn't support it natively.
    // Show informative message.
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
          onPressed: _submitPassword,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(color: AppStyles.aetherTeal, borderRadius: BorderRadius.circular(Radii.md)),
            child: const Center(child: Text('Unlock File', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700))),
          ),
        ),
      ],
    );
  }

  // ─── STEP 2: ACCOUNT PICK ───────────────────────────────────────────────

  Widget _buildAccountPick() {
    final accounts = context.read<AccountsController>().accounts;

    return ListView(
      padding: const EdgeInsets.all(Spacing.lg),
      children: [
        _StepHeader(
          step: 2, total: 4,
          icon: CupertinoIcons.creditcard_fill,
          iconColor: AppStyles.aetherTeal,
          title: 'Link to Account',
          subtitle: 'Which account does this statement belong to? Transactions will be associated — balances are NOT affected.',
        ),
        if (_detectedBank != _BankFormat.unknown) ...[
          const SizedBox(height: Spacing.md),
          _buildDetectedBankBadge(_detectedBank),
        ],
        const SizedBox(height: Spacing.lg),
        if (accounts.isEmpty)
          Container(
            padding: const EdgeInsets.all(Spacing.lg),
            decoration: BoxDecoration(color: AppStyles.getCardColor(context), borderRadius: BorderRadius.circular(Radii.md)),
            child: Text('No accounts found. Add an account first.',
                style: TextStyle(color: AppStyles.getSecondaryTextColor(context)), textAlign: TextAlign.center),
          )
        else
          ...accounts.map((acc) => _buildAccountTile(acc)),
        const SizedBox(height: Spacing.sm),
        // "No specific account" option
        _buildAccountTile(null),
      ],
    );
  }

  Widget _buildAccountTile(Account? acc) {
    final isSelected = _selectedAccount?.id == acc?.id && !(_selectedAccount == null && acc != null);
    final label = acc?.name ?? 'No specific account';
    final sub = acc != null ? '${acc.type.name} · ${acc.bankName}' : 'Transactions will not be linked to any account';
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
                Text(label, style: TextStyle(fontWeight: FontWeight.w600, fontSize: TypeScale.footnote, color: AppStyles.getTextColor(context))),
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
          itemBuilder: (ctx, i) => _buildReviewTile(_parsedRows[i]),
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

  Widget _buildReviewTile(_ParsedRow row) {
    final cat = _categorize(row.description);
    final isDuplicate = row.isDuplicate;
    final isIncluded = !isDuplicate || row.includeIfDuplicate;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: isIncluded ? 1.0 : 0.45,
      child: Container(
        padding: const EdgeInsets.all(Spacing.sm),
        decoration: BoxDecoration(
          color: AppStyles.getCardColor(context),
          borderRadius: BorderRadius.circular(Radii.md),
          border: isDuplicate
              ? Border.all(color: CupertinoColors.systemOrange.withValues(alpha: isIncluded ? 0.5 : 0.25), width: 1)
              : null,
        ),
        child: Row(children: [
          // Type indicator
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: (row.isDebit ? SemanticColors.error : SemanticColors.success).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              row.isDebit ? CupertinoIcons.arrow_down_circle_fill : CupertinoIcons.arrow_up_circle_fill,
              size: 16,
              color: row.isDebit ? SemanticColors.error : SemanticColors.success,
            ),
          ),
          const SizedBox(width: Spacing.sm),
          // Details
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(
                _cleanMerchant(row.description),
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppStyles.getTextColor(context)),
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
                  child: const Text('Duplicate', style: TextStyle(fontSize: 8, color: CupertinoColors.systemOrange, fontWeight: FontWeight.w700)),
                ),
            ]),
            Row(children: [
              Text(
                '${row.date.day}/${row.date.month}/${row.date.year}',
                style: TextStyle(fontSize: 10, color: AppStyles.getSecondaryTextColor(context)),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey6.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(cat.categoryName, style: TextStyle(fontSize: 9, color: AppStyles.getSecondaryTextColor(context))),
              ),
            ]),
          ])),
          const SizedBox(width: Spacing.sm),
          // Amount + toggle for duplicates
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(
              '${row.isDebit ? '-' : '+'}₹${_fmt(row.amount)}',
              style: TextStyle(
                fontFamily: 'SpaceGrotesk', fontSize: 13, fontWeight: FontWeight.w700,
                color: row.isDebit ? SemanticColors.error : SemanticColors.success,
              ),
            ),
            if (isDuplicate) ...[
              const SizedBox(height: 2),
              GestureDetector(
                onTap: () => setState(() => row.includeIfDuplicate = !row.includeIfDuplicate),
                child: Text(
                  row.includeIfDuplicate ? 'Include' : 'Skip',
                  style: TextStyle(
                    fontSize: 10,
                    color: row.includeIfDuplicate ? const Color(0xFF00B890) : CupertinoColors.systemOrange,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ]),
        ]),
      ),
    );
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
