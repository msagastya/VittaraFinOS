import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/transaction_model.dart';
import 'package:vittara_fin_os/logic/transactions_controller.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/widgets/animations.dart';
import 'package:vittara_fin_os/utils/id_generator.dart';

// ---------------------------------------------------------------------------
// CSV Column Mapping
// ---------------------------------------------------------------------------

enum _CsvColumn { date, description, amount, type, skip }

const _csvColumnLabels = {
  _CsvColumn.date: 'Date',
  _CsvColumn.description: 'Description',
  _CsvColumn.amount: 'Amount',
  _CsvColumn.type: 'Type (optional)',
  _CsvColumn.skip: 'Skip this column',
};

// ---------------------------------------------------------------------------
// Parse helpers
// ---------------------------------------------------------------------------

List<List<String>> _parseCsv(String raw) {
  // State-machine parser: handles quoted fields containing commas and newlines,
  // and RFC-4180 escaped quotes ("").
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
        // Peek ahead: "" is an escaped quote, otherwise end of quoted field
        if (i + 1 < raw.length && raw[i + 1] == '"') {
          current.write('"');
          i++; // skip second quote
        } else {
          inQuotes = false;
        }
      } else {
        current.write(c); // newlines inside quotes are preserved
      }
    } else {
      if (c == '"') {
        inQuotes = true;
      } else if (c == ',') {
        finishField();
      } else if (c == '\n') {
        finishRow();
      } else if (c == '\r') {
        // skip carriage returns (Windows line endings)
      } else {
        current.write(c);
      }
    }
  }
  // Flush last row
  finishRow();

  return rows;
}

DateTime? _parseDate(String raw) {
  // Try common formats: DD/MM/YYYY, MM/DD/YYYY, YYYY-MM-DD, DD-MM-YYYY
  final formats = [
    RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$'),
    RegExp(r'^(\d{4})-(\d{2})-(\d{2})$'),
    RegExp(r'^(\d{1,2})-(\d{1,2})-(\d{4})$'),
  ];
  for (final fmt in formats) {
    final m = fmt.firstMatch(raw);
    if (m != null) {
      try {
        if (fmt.pattern.startsWith(r'^(\d{4})')) {
          return DateTime(int.parse(m.group(1)!), int.parse(m.group(2)!),
              int.parse(m.group(3)!));
        }
        return DateTime(int.parse(m.group(3)!), int.parse(m.group(2)!),
            int.parse(m.group(1)!));
      } catch (_) {}
    }
  }
  return DateTime.tryParse(raw);
}

double? _parseAmount(String raw) {
  final cleaned = raw
      .replaceAll(RegExp(r'[₹\$,\s]'), '')
      .replaceAll('(', '-')
      .replaceAll(')', '');
  return double.tryParse(cleaned);
}

// ---------------------------------------------------------------------------
// Bank format auto-detection (UTL-01)
// ---------------------------------------------------------------------------

enum _BankFormat { hdfc, sbi, icici, axis, kotak, unknown }

/// Detects which bank the CSV is from based on header column names.
_BankFormat _detectBankFormat(List<String> headers) {
  final joined = headers.join(',').toLowerCase();
  if (joined.contains('narration') && joined.contains('withdrawal amt') ||
      joined.contains('debit amount') && joined.contains('chq./ref.no.')) {
    return _BankFormat.hdfc;
  }
  if (joined.contains('txn date') && joined.contains('description') &&
      (joined.contains('debit') || joined.contains('withdrawal'))) {
    if (joined.contains('sbi') || joined.contains('state bank')) {
      return _BankFormat.sbi;
    }
  }
  if (joined.contains('transaction date') && joined.contains('transaction remarks') &&
      joined.contains('withdrawal amount (inr)')) {
    return _BankFormat.icici;
  }
  if (joined.contains('tran date') && joined.contains('particulars') &&
      joined.contains('debit')) {
    return _BankFormat.axis;
  }
  if (joined.contains('transaction date') && joined.contains('description') &&
      joined.contains('debit') && joined.contains('kotak')) {
    return _BankFormat.kotak;
  }
  return _BankFormat.unknown;
}

/// Returns a pre-filled column mapping based on detected bank format.
/// Falls back to heuristic matching for unknown formats.
Map<int, _CsvColumn> _buildColumnMapping(
    List<String> headers, _BankFormat format) {
  final mapping = <int, _CsvColumn>{};

  // Bank-specific known layouts
  final patterns = <_BankFormat, Map<String, _CsvColumn>>{
    _BankFormat.hdfc: {
      'date': _CsvColumn.date,
      'narration': _CsvColumn.description,
      'withdrawal amt': _CsvColumn.amount,
      'debit amount': _CsvColumn.amount,
      'deposit amt': _CsvColumn.skip,
      'credit amount': _CsvColumn.skip,
    },
    _BankFormat.sbi: {
      'txn date': _CsvColumn.date,
      'description': _CsvColumn.description,
      'debit': _CsvColumn.amount,
      'credit': _CsvColumn.skip,
    },
    _BankFormat.icici: {
      'transaction date': _CsvColumn.date,
      'transaction remarks': _CsvColumn.description,
      'withdrawal amount (inr)': _CsvColumn.amount,
      'deposit amount (inr)': _CsvColumn.skip,
    },
    _BankFormat.axis: {
      'tran date': _CsvColumn.date,
      'particulars': _CsvColumn.description,
      'debit': _CsvColumn.amount,
      'credit': _CsvColumn.skip,
    },
    _BankFormat.kotak: {
      'transaction date': _CsvColumn.date,
      'description': _CsvColumn.description,
      'debit': _CsvColumn.amount,
      'credit': _CsvColumn.skip,
    },
  };

  final bankPatterns = patterns[format] ?? {};

  for (var i = 0; i < headers.length; i++) {
    final h = headers[i].toLowerCase().trim();
    _CsvColumn? mapped;

    // Bank-specific match first
    for (final entry in bankPatterns.entries) {
      if (h.contains(entry.key)) {
        mapped = entry.value;
        break;
      }
    }

    // Generic heuristic fallback
    mapped ??= _heuristicColumnMapping(h);
    mapping[i] = mapped;
  }
  return mapping;
}

_CsvColumn _heuristicColumnMapping(String headerLower) {
  if (headerLower.contains('date') || headerLower.contains('dt')) {
    return _CsvColumn.date;
  }
  if (headerLower.contains('desc') || headerLower.contains('narr') ||
      headerLower.contains('particular') || headerLower.contains('detail') ||
      headerLower.contains('remark') || headerLower.contains('memo')) {
    return _CsvColumn.description;
  }
  if (headerLower.contains('debit') || headerLower.contains('withdrawal') ||
      headerLower.contains('amount') || headerLower.contains('amt')) {
    return _CsvColumn.amount;
  }
  if (headerLower.contains('type') || headerLower.contains('mode')) {
    return _CsvColumn.type;
  }
  return _CsvColumn.skip;
}

// ---------------------------------------------------------------------------
// Keyword-based auto-categorization (UTL-01)
// ---------------------------------------------------------------------------

/// Maps common transaction keywords to category names.
/// Returns (categoryName, transactionType).
(String, TransactionType) _autoCategorize(String description) {
  final d = description.toLowerCase();

  // Income signals
  if (d.contains('salary') || d.contains('sal credit') || d.contains('payroll')) {
    return ('Salary', TransactionType.income);
  }
  if (d.contains('dividend') || d.contains('interest credit') || d.contains('int cr')) {
    return ('Dividends & Interest', TransactionType.income);
  }
  if (d.contains('refund') || d.contains('cashback') || d.contains('reversal')) {
    return ('Refunds', TransactionType.cashback);
  }
  if (d.contains('rent received') || d.contains('rental income')) {
    return ('Rental Income', TransactionType.income);
  }

  // Food & Dining
  if (d.contains('swiggy') || d.contains('zomato') || d.contains('uber eat') ||
      d.contains('restaurant') || d.contains('café') || d.contains('cafe') ||
      d.contains('hotel food') || d.contains('pizza') || d.contains('burger')) {
    return ('Food & Dining', TransactionType.expense);
  }

  // Groceries
  if (d.contains('bigbasket') || d.contains('grofer') || d.contains('dmart') ||
      d.contains('jiomart') || d.contains('reliance fresh') ||
      d.contains('grocery') || d.contains('supermarket') || d.contains('blinkit')) {
    return ('Groceries', TransactionType.expense);
  }

  // Transport
  if (d.contains('uber') || d.contains('ola') || d.contains('rapido') ||
      d.contains('irctc') || d.contains('redbus') || d.contains('petrol') ||
      d.contains('diesel') || d.contains('metro') || d.contains('fuel')) {
    return ('Transport', TransactionType.expense);
  }

  // Shopping
  if (d.contains('amazon') || d.contains('flipkart') || d.contains('myntra') ||
      d.contains('nykaa') || d.contains('meesho') || d.contains('shopping') ||
      d.contains('mall')) {
    return ('Shopping', TransactionType.expense);
  }

  // Utilities
  if (d.contains('electricity') || d.contains('bescom') || d.contains('tata power') ||
      d.contains('water bill') || d.contains('gas bill') || d.contains('broadband') ||
      d.contains('airtel') || d.contains('jio') || d.contains('bsnl') ||
      d.contains('utility')) {
    return ('Utilities', TransactionType.expense);
  }

  // Healthcare
  if (d.contains('hospital') || d.contains('clinic') || d.contains('pharmacy') ||
      d.contains('medical') || d.contains('apollo') || d.contains('netmeds') ||
      d.contains('1mg') || d.contains('health')) {
    return ('Healthcare', TransactionType.expense);
  }

  // Entertainment
  if (d.contains('netflix') || d.contains('hotstar') || d.contains('prime video') ||
      d.contains('spotify') || d.contains('youtube premium') ||
      d.contains('bookmyshow') || d.contains('pvr') || d.contains('inox') ||
      d.contains('entertainment')) {
    return ('Entertainment', TransactionType.expense);
  }

  // Rent & Housing
  if (d.contains('rent') || d.contains('housing') || d.contains('maintenance fee')) {
    return ('Rent & Housing', TransactionType.expense);
  }

  // Education
  if (d.contains('school fee') || d.contains('college fee') || d.contains('tuition') ||
      d.contains('coursera') || d.contains('udemy') || d.contains('education')) {
    return ('Education', TransactionType.expense);
  }

  // EMI / Loans
  if (d.contains('emi') || d.contains('loan repay') || d.contains('equated monthly')) {
    return ('EMI / Loans', TransactionType.expense);
  }

  // Investments
  if (d.contains('mutual fund') || d.contains('nse') || d.contains('bse') ||
      d.contains('sip') || d.contains('mf') || d.contains('demat') ||
      d.contains('zerodha') || d.contains('groww') || d.contains('hdfc sec')) {
    return ('Investments', TransactionType.investment);
  }

  // Insurance
  if (d.contains('insurance') || d.contains('lic') || d.contains('premium')) {
    return ('Insurance', TransactionType.expense);
  }

  // Default — use amount sign to guess
  return ('Uncategorized', TransactionType.expense);
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class CsvImportScreen extends StatefulWidget {
  const CsvImportScreen({super.key});

  @override
  State<CsvImportScreen> createState() => _CsvImportScreenState();
}

class _CsvImportScreenState extends State<CsvImportScreen> {
  // Step: 0 = paste CSV, 1 = column mapping, 2 = preview, 3 = done
  int _step = 0;
  final _csvController = TextEditingController();
  List<List<String>> _rows = [];
  List<String> _headers = [];
  Map<int, _CsvColumn> _columnMapping = {};
  List<Transaction> _preview = [];
  List<Transaction> _toImport = [];
  int _duplicatesSkipped = 0;
  int _imported = 0;
  bool _importing = false;
  _BankFormat _detectedBank = _BankFormat.unknown;

  @override
  void dispose() {
    _csvController.dispose();
    super.dispose();
  }

  void _parseCsvInput() {
    final rows = _parseCsv(_csvController.text);
    if (rows.isEmpty) {
      _showError('No data found. Paste at least one row of CSV data.');
      return;
    }
    setState(() {
      _rows = rows;
      _headers = rows.first;
      // Bank format detection + smart column mapping
      _detectedBank = _detectBankFormat(_headers);
      _columnMapping = _buildColumnMapping(_headers, _detectedBank);
      _step = 1;
    });
  }

  void _buildPreview() {
    // Validate mapping: need at least date, description, amount
    final cols = _columnMapping.values.toSet();
    if (!cols.contains(_CsvColumn.date)) {
      _showError('Please map a Date column.');
      return;
    }
    if (!cols.contains(_CsvColumn.description)) {
      _showError('Please map a Description column.');
      return;
    }
    if (!cols.contains(_CsvColumn.amount)) {
      _showError('Please map an Amount column.');
      return;
    }

    final dateIdx = _columnMapping.entries
        .firstWhere((e) => e.value == _CsvColumn.date)
        .key;
    final descIdx = _columnMapping.entries
        .firstWhere((e) => e.value == _CsvColumn.description)
        .key;
    final amtIdx = _columnMapping.entries
        .firstWhere((e) => e.value == _CsvColumn.amount)
        .key;

    final dataRows = _rows.length > 1 ? _rows.sublist(1) : _rows;
    final parsed = <Transaction>[];
    for (final row in dataRows) {
      if (row.length <= dateIdx ||
          row.length <= descIdx ||
          row.length <= amtIdx) {
        continue;
      }
      final date = _parseDate(row[dateIdx]);
      final amount = _parseAmount(row[amtIdx]);
      if (date == null || amount == null) { continue; }
      final desc = row[descIdx];
      // Auto-categorize by keyword
      final (categoryName, inferredType) = _autoCategorize(desc);
      final txType = amount < 0
          ? (inferredType == TransactionType.income ? TransactionType.expense : inferredType)
          : (amount > 0 && inferredType == TransactionType.income ? TransactionType.income : inferredType);
      parsed.add(Transaction(
        id: IdGenerator.next(prefix: 'csv'),
        type: txType,
        description: desc,
        dateTime: date,
        amount: amount.abs(),
        metadata: {
          'source': 'csv_import',
          'merchant': desc,
          'categoryName': categoryName,
          'bank': _detectedBank.name,
        },
      ));
    }

    setState(() {
      _preview = parsed.take(5).toList();
      _toImport = parsed;
      _step = 2;
    });
  }

  Future<void> _importTransactions() async {
    setState(() => _importing = true);
    final controller = context.read<TransactionsController>();
    final existing = controller.transactions;
    final existingKeys = existing
        .map((t) => '${t.dateTime.toIso8601String().substring(0, 10)}_${t.amount}_${t.description}')
        .toSet();

    // Build a fuzzy duplicate set: (amount, description) keyed; date within ±1 day checked separately
    final existingList = existing.toList();
    final toAdd = <Transaction>[];
    int dupes = 0;
    for (final tx in _toImport) {
      final isDupe = existingKeys.contains(
              '${tx.dateTime.toIso8601String().substring(0, 10)}_${tx.amount}_${tx.description}') ||
          existingList.any((e) =>
              e.amount == tx.amount &&
              e.description == tx.description &&
              e.dateTime.difference(tx.dateTime).inDays.abs() <= 1);
      if (isDupe) {
        dupes++;
      } else {
        toAdd.add(tx);
      }
    }

    await controller.addTransactionsBatch(toAdd);

    setState(() {
      _imported = toAdd.length;
      _duplicatesSkipped = dupes;
      _importing = false;
      _step = 3;
    });
  }

  void _showError(String msg) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Error'),
        content: Text(msg),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppStyles.getBackground(context),
      navigationBar: AppStyles.isLandscape(context) ? null : CupertinoNavigationBar(
        middle: Text('Import CSV'),
        previousPageTitle: 'Back',
        backgroundColor: AppStyles.getBackground(context),
        border: null,
      ),
      child: SafeArea(
        child: _buildStep(context),
      ),
    );
  }

  Widget _buildStep(BuildContext context) {
    switch (_step) {
      case 0:
        return _buildPasteStep(context);
      case 1:
        return _buildMappingStep(context);
      case 2:
        return _buildPreviewStep(context);
      case 3:
        return _buildDoneStep(context);
      default:
        return const SizedBox.shrink();
    }
  }

  // ---------------------------------------------------------------------------
  // Step 0: Paste CSV
  // ---------------------------------------------------------------------------
  Widget _buildPasteStep(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(Spacing.lg),
      children: [
        _StepHeader(
          step: 1,
          total: 4,
          title: 'Paste your CSV',
          subtitle:
              'Copy your bank statement CSV text and paste it below. The first row should be column headers.',
        ),
        const SizedBox(height: Spacing.lg),
        Container(
          decoration: BoxDecoration(
            color: AppStyles.getCardColor(context),
            borderRadius: BorderRadius.circular(Radii.md),
          ),
          child: CupertinoTextField(
            controller: _csvController,
            placeholder:
                'Date,Description,Amount\n01/01/2026,Zomato,-250\n02/01/2026,Salary,50000',
            maxLines: 12,
            padding: const EdgeInsets.all(Spacing.md),
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: TypeScale.footnote,
              color: AppStyles.getTextColor(context),
            ),
            placeholderStyle: TextStyle(
              fontSize: TypeScale.footnote,
              color:
                  AppStyles.getSecondaryTextColor(context).withValues(alpha: 0.5),
            ),
            decoration: null,
          ),
        ),
        const SizedBox(height: Spacing.lg),
        Container(
          padding: const EdgeInsets.all(Spacing.md),
          decoration: BoxDecoration(
            color: AppStyles.aetherTeal.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(Radii.md),
            border: Border.all(
              color: AppStyles.aetherTeal.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Supported formats',
                style: TextStyle(
                  fontSize: TypeScale.footnote,
                  fontWeight: FontWeight.w600,
                  color: AppStyles.getTextColor(context),
                ),
              ),
              const SizedBox(height: Spacing.xs),
              Text(
                '• Dates: DD/MM/YYYY, YYYY-MM-DD, DD-MM-YYYY\n'
                '• Amounts: plain numbers, with ₹/\$, negative for debits\n'
                '• First row must be column headers',
                style: TextStyle(
                  fontSize: TypeScale.caption,
                  color: AppStyles.getSecondaryTextColor(context),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Spacing.xl),
        BouncyButton(
          onPressed: _parseCsvInput,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: Spacing.md),
            decoration: BoxDecoration(
              color: AppStyles.aetherTeal,
              borderRadius: BorderRadius.circular(Radii.md),
            ),
            child: const Center(
              child: Text(
                'Next: Map Columns',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Step 1: Column Mapping
  // ---------------------------------------------------------------------------
  Widget _buildMappingStep(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(Spacing.lg),
      children: [
        _StepHeader(
          step: 2,
          total: 4,
          title: 'Map columns',
          subtitle: 'Tell us what each column means.',
        ),
        if (_detectedBank != _BankFormat.unknown) ...[
          const SizedBox(height: Spacing.md),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.sm),
            decoration: BoxDecoration(
              color: CupertinoColors.activeGreen.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(Radii.sm),
              border: Border.all(color: CupertinoColors.activeGreen.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(CupertinoIcons.checkmark_seal_fill,
                    size: 14, color: CupertinoColors.activeGreen),
                const SizedBox(width: Spacing.sm),
                Text(
                  'Detected: ${_detectedBank.name.toUpperCase()} Bank format — columns auto-mapped',
                  style: const TextStyle(
                    fontSize: TypeScale.caption,
                    color: CupertinoColors.activeGreen,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: Spacing.lg),
        ...List.generate(_headers.length, (i) {
          return Container(
            margin: const EdgeInsets.only(bottom: Spacing.sm),
            padding: const EdgeInsets.symmetric(
                horizontal: Spacing.md, vertical: Spacing.sm),
            decoration: BoxDecoration(
              color: AppStyles.getCardColor(context),
              borderRadius: BorderRadius.circular(Radii.md),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    _headers[i],
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: TypeScale.footnote,
                      color: AppStyles.getTextColor(context),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: Spacing.sm),
                Expanded(
                  flex: 3,
                  child: CupertinoSlidingSegmentedControl<_CsvColumn>(
                    groupValue: _columnMapping[i] ?? _CsvColumn.skip,
                    children: {
                      for (final e in _CsvColumn.values)
                        e: Text(
                          _csvColumnLabels[e]!.split(' ').first,
                          style: const TextStyle(fontSize: 11),
                        ),
                    },
                    onValueChanged: (v) {
                      if (v != null) {
                        setState(() => _columnMapping[i] = v);
                      }
                    },
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: Spacing.xl),
        Row(
          children: [
            Expanded(
              child: BouncyButton(
                onPressed: () => setState(() => _step = 0),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: Spacing.md),
                  decoration: BoxDecoration(
                    color: AppStyles.getCardColor(context),
                    borderRadius: BorderRadius.circular(Radii.md),
                  ),
                  child: Center(
                    child: Text(
                      'Back',
                      style: TextStyle(
                        color: AppStyles.getTextColor(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: Spacing.sm),
            Expanded(
              child: BouncyButton(
                onPressed: _buildPreview,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: Spacing.md),
                  decoration: BoxDecoration(
                    color: AppStyles.aetherTeal,
                    borderRadius: BorderRadius.circular(Radii.md),
                  ),
                  child: const Center(
                    child: Text(
                      'Preview',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Step 2: Preview
  // ---------------------------------------------------------------------------
  Widget _buildPreviewStep(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(Spacing.lg),
      children: [
        _StepHeader(
          step: 3,
          total: 4,
          title: 'Preview',
          subtitle:
              'Showing first ${_preview.length} of ${_toImport.length} transactions. Duplicates will be skipped.',
        ),
        const SizedBox(height: Spacing.lg),
        ..._preview.map((tx) => Container(
              margin: const EdgeInsets.only(bottom: Spacing.sm),
              padding: const EdgeInsets.all(Spacing.md),
              decoration: BoxDecoration(
                color: AppStyles.getCardColor(context),
                borderRadius: BorderRadius.circular(Radii.md),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: tx.type == TransactionType.expense
                          ? SemanticColors.error.withValues(alpha: 0.15)
                          : SemanticColors.success.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(Radii.sm),
                    ),
                    child: Icon(
                      tx.type == TransactionType.expense
                          ? CupertinoIcons.arrow_down_circle_fill
                          : CupertinoIcons.arrow_up_circle_fill,
                      size: 18,
                      color: tx.type == TransactionType.expense
                          ? SemanticColors.error
                          : SemanticColors.success,
                    ),
                  ),
                  const SizedBox(width: Spacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tx.description,
                          style: TextStyle(
                            fontSize: TypeScale.footnote,
                            fontWeight: FontWeight.w600,
                            color: AppStyles.getTextColor(context),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${tx.dateTime.day}/${tx.dateTime.month}/${tx.dateTime.year}',
                          style: TextStyle(
                            fontSize: TypeScale.caption,
                            color: AppStyles.getSecondaryTextColor(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    tx.type == TransactionType.expense
                        ? '-₹${tx.amount.toStringAsFixed(0)}'
                        : '+₹${tx.amount.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: TypeScale.footnote,
                      fontWeight: FontWeight.w700,
                      color: tx.type == TransactionType.expense
                          ? SemanticColors.error
                          : SemanticColors.success,
                    ),
                  ),
                ],
              ),
            )),
        if (_toImport.length > 5) ...[
          const SizedBox(height: Spacing.sm),
          Text(
            '+ ${_toImport.length - 5} more transactions',
            style: TextStyle(
              fontSize: TypeScale.caption,
              color: AppStyles.getSecondaryTextColor(context),
            ),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: Spacing.xl),
        Row(
          children: [
            Expanded(
              child: BouncyButton(
                onPressed: () => setState(() => _step = 1),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: Spacing.md),
                  decoration: BoxDecoration(
                    color: AppStyles.getCardColor(context),
                    borderRadius: BorderRadius.circular(Radii.md),
                  ),
                  child: Center(
                    child: Text(
                      'Back',
                      style: TextStyle(
                        color: AppStyles.getTextColor(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: Spacing.sm),
            Expanded(
              child: BouncyButton(
                onPressed: _importing ? () {} : _importTransactions,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: Spacing.md),
                  decoration: BoxDecoration(
                    color: _importing
                        ? AppStyles.aetherTeal.withValues(alpha: 0.5)
                        : AppStyles.aetherTeal,
                    borderRadius: BorderRadius.circular(Radii.md),
                  ),
                  child: Center(
                    child: _importing
                        ? const CupertinoActivityIndicator()
                        : const Text(
                            'Import',
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Step 3: Done
  // ---------------------------------------------------------------------------
  Widget _buildDoneStep(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: SemanticColors.success.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                CupertinoIcons.checkmark_circle_fill,
                size: 44,
                color: SemanticColors.success,
              ),
            ),
            const SizedBox(height: Spacing.lg),
            Text(
              'Import Complete',
              style: TextStyle(
                fontSize: TypeScale.title2,
                fontWeight: FontWeight.w700,
                color: AppStyles.getTextColor(context),
              ),
            ),
            const SizedBox(height: Spacing.sm),
            Text(
              '$_imported transactions imported',
              style: TextStyle(
                fontSize: TypeScale.body,
                color: AppStyles.getSecondaryTextColor(context),
              ),
            ),
            if (_duplicatesSkipped > 0) ...[
              const SizedBox(height: Spacing.xs),
              Text(
                '$_duplicatesSkipped duplicates skipped',
                style: TextStyle(
                  fontSize: TypeScale.footnote,
                  color: SemanticColors.warning,
                ),
              ),
            ],
            const SizedBox(height: Spacing.xxl),
            BouncyButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    vertical: Spacing.md, horizontal: Spacing.xl),
                decoration: BoxDecoration(
                  color: AppStyles.aetherTeal,
                  borderRadius: BorderRadius.circular(Radii.md),
                ),
                child: const Text(
                  'Done',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Step header
// ---------------------------------------------------------------------------

class _StepHeader extends StatelessWidget {
  final int step;
  final int total;
  final String title;
  final String subtitle;

  const _StepHeader({
    required this.step,
    required this.total,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Step $step of $total',
          style: TextStyle(
            fontSize: TypeScale.caption,
            color: AppStyles.aetherTeal,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: Spacing.xs),
        Text(
          title,
          style: TextStyle(
            fontSize: TypeScale.title3,
            fontWeight: FontWeight.w700,
            color: AppStyles.getTextColor(context),
          ),
        ),
        const SizedBox(height: Spacing.xs),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: TypeScale.footnote,
            color: AppStyles.getSecondaryTextColor(context),
          ),
        ),
      ],
    );
  }
}
