import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:vittara_fin_os/logic/accounts_controller.dart';
import 'package:vittara_fin_os/logic/budgets_controller.dart';
import 'package:vittara_fin_os/logic/contacts_controller.dart';
import 'package:vittara_fin_os/logic/goals_controller.dart';
import 'package:vittara_fin_os/logic/investments_controller.dart';
import 'package:vittara_fin_os/logic/transactions_controller.dart';
import 'package:vittara_fin_os/logic/transaction_model.dart';
import 'package:vittara_fin_os/ui/dashboard/quick_entry_sheet.dart';
import 'package:vittara_fin_os/ui/manage/account_wizard.dart';
import 'package:vittara_fin_os/ui/manage/budgets/budget_details_screen.dart';
import 'package:vittara_fin_os/ui/manage/contacts_screen.dart';
import 'package:vittara_fin_os/ui/manage/goals/goal_details_screen.dart';
import 'package:vittara_fin_os/ui/manage/investments_screen.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/widgets/animations.dart';

const String _kRecentSearchesKey = 'global_search_recent';
const int _kMaxRecentSearches = 10;

enum _ResultType { transaction, account, investment, goal, budget, contact }

class _SearchResult {
  final _ResultType type;
  final String id;
  final String title;
  final String subtitle;
  final double? amount;
  final IconData icon;
  final Color color;
  /// Called after the search overlay is dismissed.
  final VoidCallback onNavigate;

  const _SearchResult({
    required this.type,
    required this.id,
    required this.title,
    required this.subtitle,
    this.amount,
    required this.icon,
    required this.color,
    required this.onNavigate,
  });
}

// ── NL Query Parser ────────────────────────────────────────────────────────────

class _ParsedQuery {
  final String displaySummary;   // e.g. "Food · Last month · Expenses"
  final String? keyword;         // residual keyword for title/merchant match
  final DateTime? fromDate;
  final DateTime? toDate;
  final TransactionType? type;
  final double? minAmount;
  final double? maxAmount;
  final List<String> categoryHints; // e.g. ['food', 'dining']

  const _ParsedQuery({
    required this.displaySummary,
    this.keyword,
    this.fromDate,
    this.toDate,
    this.type,
    this.minAmount,
    this.maxAmount,
    this.categoryHints = const [],
  });
}

class _NLQueryParser {
  static const _categoryKeywords = <String, List<String>>{
    'food': ['food', 'eating', 'restaurant', 'dining', 'lunch', 'dinner', 'breakfast', 'snack', 'cafe', 'coffee', 'swiggy', 'zomato'],
    'transport': ['transport', 'travel', 'uber', 'ola', 'cab', 'auto', 'metro', 'bus', 'fuel', 'petrol', 'rapido', 'namma yatri', 'irctc', 'flight'],
    'shopping': ['shopping', 'amazon', 'flipkart', 'myntra', 'meesho', 'ajio', 'nykaa', 'clothes', 'clothing', 'clothes'],
    'entertainment': ['entertainment', 'netflix', 'prime', 'hotstar', 'movie', 'cinema', 'game', 'gaming', 'spotify', 'youtube'],
    'health': ['health', 'medical', 'doctor', 'pharmacy', 'medicine', 'hospital', 'gym', 'fitness'],
    'utilities': ['utility', 'utilities', 'electricity', 'internet', 'wifi', 'mobile', 'recharge', 'bill', 'water'],
    'rent': ['rent', 'housing', 'maintenance'],
    'groceries': ['groceries', 'grocery', 'vegetables', 'fruits', 'milk', 'blinkit', 'zepto', 'bigbasket', 'dmarts', 'd-mart'],
    'investment': ['investment', 'sip', 'mutual fund', 'stocks', 'zerodha', 'groww', 'nps'],
    'transfer': ['transfer', 'upi', 'sent', 'paid', 'given'],
    'income': ['income', 'salary', 'received', 'credit'],
    'subscription': ['subscription', 'plan', 'renewal', 'annual'],
    'insurance': ['insurance', 'lic', 'premium', 'policy'],
  };

  static _ParsedQuery? parse(String query) {
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return null;

    DateTime? from, to;
    TransactionType? txType;
    double? minAmt, maxAmt;
    List<String> catHints = [];
    String residual = q;
    List<String> tags = [];

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // ── Date extraction ──────────────────────────────────────────────────────
    if (_contains(q, ['last month', 'previous month', 'past month'])) {
      final d = DateTime(now.year, now.month - 1, 1);
      from = d;
      to = DateTime(d.year, d.month + 1, 1).subtract(const Duration(seconds: 1));
      tags.add('Last month');
      residual = _remove(residual, ['last month', 'previous month', 'past month']);
    } else if (_contains(q, ['this month', 'current month'])) {
      from = DateTime(now.year, now.month, 1);
      to = now;
      tags.add('This month');
      residual = _remove(residual, ['this month', 'current month']);
    } else if (_contains(q, ['this week', 'current week'])) {
      final weekday = today.weekday;
      from = today.subtract(Duration(days: weekday - 1));
      to = now;
      tags.add('This week');
      residual = _remove(residual, ['this week', 'current week']);
    } else if (_contains(q, ['last week', 'previous week', 'past week'])) {
      final weekday = today.weekday;
      final startOfThisWeek = today.subtract(Duration(days: weekday - 1));
      from = startOfThisWeek.subtract(const Duration(days: 7));
      to = startOfThisWeek.subtract(const Duration(seconds: 1));
      tags.add('Last week');
      residual = _remove(residual, ['last week', 'previous week', 'past week']);
    } else if (_contains(q, ['today'])) {
      from = today;
      to = now;
      tags.add('Today');
      residual = _remove(residual, ['today']);
    } else if (_contains(q, ['yesterday'])) {
      from = today.subtract(const Duration(days: 1));
      to = today.subtract(const Duration(seconds: 1));
      tags.add('Yesterday');
      residual = _remove(residual, ['yesterday']);
    } else if (_contains(q, ['last 7 days', 'past 7 days', 'last seven days'])) {
      from = today.subtract(const Duration(days: 7));
      to = now;
      tags.add('Last 7 days');
      residual = _remove(residual, ['last 7 days', 'past 7 days', 'last seven days']);
    } else if (_contains(q, ['last 30 days', 'past 30 days', 'last thirty days'])) {
      from = today.subtract(const Duration(days: 30));
      to = now;
      tags.add('Last 30 days');
      residual = _remove(residual, ['last 30 days', 'past 30 days', 'last thirty days']);
    } else if (_contains(q, ['last 3 months', 'past 3 months', 'last three months'])) {
      from = DateTime(now.year, now.month - 3, 1);
      to = now;
      tags.add('Last 3 months');
      residual = _remove(residual, ['last 3 months', 'past 3 months', 'last three months']);
    } else {
      // Try month name matching
      const months = ['january','february','march','april','may','june','july','august','september','october','november','december'];
      for (int i = 0; i < months.length; i++) {
        if (q.contains(months[i])) {
          int year = now.year;
          final monthIdx = i + 1;
          if (monthIdx > now.month) year--;
          from = DateTime(year, monthIdx, 1);
          to = DateTime(year, monthIdx + 1, 1).subtract(const Duration(seconds: 1));
          tags.add(_capitalize(months[i]));
          residual = _remove(residual, [months[i]]);
          break;
        }
      }
    }

    // ── Transaction type ─────────────────────────────────────────────────────
    if (_contains(q, ['expense', 'expenses', 'spent', 'spend', 'debited', 'debit', 'outgoing', 'paid out'])) {
      txType = TransactionType.expense;
      tags.add('Expenses');
      residual = _remove(residual, ['expense', 'expenses', 'spent', 'spend', 'debited', 'debit', 'outgoing', 'paid out']);
    } else if (_contains(q, ['income', 'received', 'credited', 'earnings', 'salary', 'incoming'])) {
      txType = TransactionType.income;
      tags.add('Income');
      residual = _remove(residual, ['income', 'received', 'credited', 'earnings', 'salary', 'incoming']);
    } else if (_contains(q, ['transfer', 'transferred', 'sent', 'sent to'])) {
      txType = TransactionType.transfer;
      tags.add('Transfers');
      residual = _remove(residual, ['transfer', 'transferred', 'sent', 'sent to']);
    }

    // ── Amount range ─────────────────────────────────────────────────────────
    // "above/more than/greater than X"
    final aboveMatch = RegExp(r'(?:above|more than|greater than|over|>\s*)(?:₹|rs\.?\s*)?(\d+(?:,\d+)*(?:\.\d+)?)\s*(?:k|lakh|l|cr)?').firstMatch(q);
    if (aboveMatch != null) {
      minAmt = _parseAmount(aboveMatch.group(1)!, aboveMatch.group(0)!);
      tags.add('>₹${_fmtShort(minAmt)}');
      residual = residual.replaceAll(aboveMatch.group(0)!, '');
    }

    // "below/less than/under X"
    final belowMatch = RegExp(r'(?:below|less than|under|<\s*)(?:₹|rs\.?\s*)?(\d+(?:,\d+)*(?:\.\d+)?)\s*(?:k|lakh|l|cr)?').firstMatch(q);
    if (belowMatch != null) {
      maxAmt = _parseAmount(belowMatch.group(1)!, belowMatch.group(0)!);
      tags.add('<₹${_fmtShort(maxAmt)}');
      residual = residual.replaceAll(belowMatch.group(0)!, '');
    }

    // "between X and Y"
    final betweenMatch = RegExp(r'between\s+(?:₹|rs\.?\s*)?(\d+(?:,\d+)*(?:\.\d+)?)\s+and\s+(?:₹|rs\.?\s*)?(\d+(?:,\d+)*(?:\.\d+)?)').firstMatch(q);
    if (betweenMatch != null) {
      minAmt = _parseAmount(betweenMatch.group(1)!, betweenMatch.group(0)!);
      maxAmt = _parseAmount(betweenMatch.group(2)!, betweenMatch.group(0)!);
      tags.add('₹${_fmtShort(minAmt)}–₹${_fmtShort(maxAmt)}');
      residual = residual.replaceAll(betweenMatch.group(0)!, '');
    }

    // ── Category hints ───────────────────────────────────────────────────────
    for (final entry in _categoryKeywords.entries) {
      for (final kw in entry.value) {
        if (q.contains(kw)) {
          if (!catHints.contains(entry.key)) catHints.add(entry.key);
          if (!tags.contains(_capitalize(entry.key))) tags.add(_capitalize(entry.key));
          residual = residual.replaceAll(kw, '');
          break;
        }
      }
    }

    // Clean residual
    residual = residual
        .replaceAll(RegExp(r'\b(?:show|me|all|my|the|in|for|on|of|from|transactions?|entries?)\b'), '')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();

    // Only return parsed result if we extracted at least one constraint
    if (tags.isEmpty && residual == q.trim()) return null;

    return _ParsedQuery(
      displaySummary: tags.isEmpty ? 'Searching' : tags.join(' · '),
      keyword: residual.isEmpty ? null : residual,
      fromDate: from,
      toDate: to,
      type: txType,
      minAmount: minAmt,
      maxAmount: maxAmt,
      categoryHints: catHints,
    );
  }

  static bool _contains(String q, List<String> terms) =>
      terms.any((t) => q.contains(t));

  static String _remove(String q, List<String> terms) {
    var s = q;
    for (final t in terms) {
      s = s.replaceAll(t, '');
    }
    return s;
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  static double _parseAmount(String digits, String full) {
    final cleaned = digits.replaceAll(',', '');
    double val = double.tryParse(cleaned) ?? 0;
    final f = full.toLowerCase();
    if (f.contains('lakh') || f.contains(' l')) val *= 100000;
    if (f.contains('cr')) val *= 10000000;
    if (f.endsWith('k')) val *= 1000;
    return val;
  }

  static String _fmtShort(double v) {
    if (v >= 10000000) return '${(v / 10000000).toStringAsFixed(1)}Cr';
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
    return v.toStringAsFixed(0);
  }
}

// ── Entry point ───────────────────────────────────────────────────────────────

/// Opens the global search overlay.
void showGlobalSearch(BuildContext context) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Search',
    barrierColor: Colors.black.withValues(alpha: 0.75),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, animation, secondaryAnimation) =>
        const _GlobalSearchPage(),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
          parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.0, -0.06),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _GlobalSearchPage extends StatefulWidget {
  const _GlobalSearchPage();

  @override
  State<_GlobalSearchPage> createState() => _GlobalSearchPageState();
}

class _GlobalSearchPageState extends State<_GlobalSearchPage>
    with SingleTickerProviderStateMixin {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;
  List<_SearchResult> _results = [];
  List<String> _recentSearches = [];
  bool _searching = false;
  String _query = '';
  _ParsedQuery? _parsedQuery;

  // Voice
  final _stt = SpeechToText();
  bool _sttReady = false;
  bool _isListening = false;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _loadRecentSearches();
    _initStt();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  Future<void> _initStt() async {
    final ok = await _stt.initialize(onError: (_) {
      if (mounted) setState(() => _isListening = false);
    });
    if (mounted) setState(() => _sttReady = ok);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _pulseCtrl.dispose();
    _controller.dispose();
    _focus.dispose();
    _stt.stop();
    super.dispose();
  }

  // ── Voice ────────────────────────────────────────────────────────────────

  Future<void> _toggleVoice() async {
    HapticFeedback.lightImpact();
    if (_isListening) {
      await _stt.stop();
      setState(() => _isListening = false);
      return;
    }
    if (!_sttReady) {
      final ok = await _stt.initialize();
      if (!ok || !mounted) return;
      setState(() => _sttReady = ok);
    }
    setState(() => _isListening = true);
    await _stt.listen(
      onResult: (result) {
        if (!mounted) return;
        final text = result.recognizedWords;
        _controller.text = text;
        _onQueryChanged(text);
        if (result.finalResult) {
          setState(() => _isListening = false);
        }
      },
      listenFor: const Duration(seconds: 10),
      pauseFor: const Duration(seconds: 2),
      cancelOnError: true,
      partialResults: true,
    );
  }

  // ── Recent searches ───────────────────────────────────────────────────────

  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_kRecentSearchesKey) ?? [];
    if (mounted) setState(() => _recentSearches = raw);
  }

  Future<void> _saveRecentSearch(String query) async {
    if (query.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final updated = [
      query,
      ..._recentSearches.where((r) => r != query),
    ].take(_kMaxRecentSearches).toList();
    await prefs.setStringList(_kRecentSearchesKey, updated);
    if (mounted) setState(() => _recentSearches = updated);
  }

  Future<void> _clearRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kRecentSearchesKey);
    if (mounted) setState(() => _recentSearches = []);
  }

  // ── Search logic ──────────────────────────────────────────────────────────

  void _onQueryChanged(String value) {
    setState(() => _query = value);
    _debounce?.cancel();
    if (value.trim().length < 2) {
      setState(() {
        _results = [];
        _searching = false;
        _parsedQuery = null;
      });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 250), () => _runSearch(value));
  }

  void _runSearch(String q) {
    if (!mounted) return;
    final raw = q.toLowerCase().trim();
    final results = <_SearchResult>[];

    // Try NL parse first
    final parsed = _NLQueryParser.parse(raw);

    final txCtrl = context.read<TransactionsController>();
    final accCtrl = context.read<AccountsController>();
    final invCtrl = context.read<InvestmentsController>();
    final goalCtrl = context.read<GoalsController>();
    final budgetCtrl = context.read<BudgetsController>();
    final contactCtrl = context.read<ContactsController>();

    // ── Transactions ──────────────────────────────────────────────────────────
    for (final tx in txCtrl.transactions) {
      if (results.where((r) => r.type == _ResultType.transaction).length >= 20) break;

      if (parsed != null) {
        // NL filter mode
        if (!_matchesParsed(tx, parsed, raw)) continue;
      } else {
        // Plain keyword mode
        final desc = tx.description.toLowerCase();
        final amt = tx.amount.toString();
        final cat = (tx.metadata?['categoryName'] as String? ?? '').toLowerCase();
        final merchant = (tx.metadata?['merchant'] as String? ?? '').toLowerCase();
        final tags = (tx.metadata?['tags'] as List? ?? [])
            .map((t) => t.toString().toLowerCase())
            .join(' ');
        final accName = (tx.sourceAccountName ?? '').toLowerCase();
        if (!desc.contains(raw) &&
            !amt.contains(raw) &&
            !cat.contains(raw) &&
            !merchant.contains(raw) &&
            !tags.contains(raw) &&
            !accName.contains(raw)) continue;
      }

      final isIncome = tx.type == TransactionType.income ||
          tx.type == TransactionType.cashback;
      final merchant = (tx.metadata?['merchant'] as String? ?? '').trim();
      final cat = (tx.metadata?['categoryName'] as String? ?? '').trim();
      final capturedTx = tx;
      results.add(_SearchResult(
        type: _ResultType.transaction,
        id: tx.id,
        title: merchant.isNotEmpty ? merchant : tx.description,
        subtitle: [
          if (cat.isNotEmpty) cat,
          _fmtDate(tx.dateTime),
          if ((tx.sourceAccountName ?? '').isNotEmpty) tx.sourceAccountName!,
        ].join(' · '),
        amount: tx.amount,
        icon: isIncome
            ? CupertinoIcons.arrow_down_circle_fill
            : CupertinoIcons.arrow_up_circle_fill,
        color: isIncome ? AppStyles.gain(context) : AppStyles.loss(context),
        onNavigate: () => showQuickEntrySheet(
          context,
          existingTransaction: capturedTx,
        ),
      ));
    }

    // In NL mode, skip other result types (user asked about transactions only)
    if (parsed == null) {
      // ── Accounts ────────────────────────────────────────────────────────────
      for (final acc in accCtrl.accounts) {
        if (results.where((r) => r.type == _ResultType.account).length >= 5) break;
        final typeLabel = _accountTypeLabel(acc.type.name);
        if (!acc.name.toLowerCase().contains(raw) &&
            !acc.bankName.toLowerCase().contains(raw) &&
            !typeLabel.toLowerCase().contains(raw)) continue;
        final capturedAcc = acc;
        results.add(_SearchResult(
          type: _ResultType.account,
          id: acc.id,
          title: acc.name,
          subtitle: '${acc.bankName} · $typeLabel',
          amount: acc.balance,
          icon: CupertinoIcons.creditcard_fill,
          color: AppStyles.teal(context),
          onNavigate: () => showCupertinoModalPopup<void>(
            context: context,
            builder: (_) => AccountWizard(existingAccount: capturedAcc),
          ),
        ));
      }

      // ── Investments ──────────────────────────────────────────────────────────
      for (final inv in invCtrl.investments) {
        if (results.where((r) => r.type == _ResultType.investment).length >= 5) break;
        if (!inv.name.toLowerCase().contains(raw) &&
            !(inv.broker ?? '').toLowerCase().contains(raw) &&
            !inv.getTypeLabel().toLowerCase().contains(raw)) continue;
        results.add(_SearchResult(
          type: _ResultType.investment,
          id: inv.id,
          title: inv.name,
          subtitle: '${inv.getTypeLabel()}${inv.broker != null ? " · ${inv.broker}" : ""}',
          amount: inv.amount,
          icon: CupertinoIcons.chart_bar_square_fill,
          color: AppStyles.violet(context),
          onNavigate: () => Navigator.of(context, rootNavigator: true).push(
            FadeScalePageRoute(page: const InvestmentsScreen()),
          ),
        ));
      }

      // ── Goals ────────────────────────────────────────────────────────────────
      for (final goal in goalCtrl.goals) {
        if (results.where((r) => r.type == _ResultType.goal).length >= 5) break;
        if (!goal.name.toLowerCase().contains(raw)) continue;
        final capturedId = goal.id;
        results.add(_SearchResult(
          type: _ResultType.goal,
          id: goal.id,
          title: goal.name,
          subtitle: 'Goal · ${_fmt(goal.currentAmount)} / ${_fmt(goal.targetAmount)}',
          amount: goal.targetAmount,
          icon: CupertinoIcons.flag_fill,
          color: AppStyles.gold(context),
          onNavigate: () => Navigator.of(context, rootNavigator: true).push(
            FadeScalePageRoute(page: GoalDetailsScreen(goalId: capturedId)),
          ),
        ));
      }

      // ── Budgets ──────────────────────────────────────────────────────────────
      for (final budget in budgetCtrl.budgets) {
        if (results.where((r) => r.type == _ResultType.budget).length >= 5) break;
        if (!budget.name.toLowerCase().contains(raw) &&
            !(budget.categoryName ?? '').toLowerCase().contains(raw)) continue;
        final capturedId = budget.id;
        results.add(_SearchResult(
          type: _ResultType.budget,
          id: budget.id,
          title: budget.name,
          subtitle: 'Budget · ${_fmt(budget.spentAmount)} / ${_fmt(budget.limitAmount)}',
          amount: budget.limitAmount,
          icon: CupertinoIcons.chart_pie_fill,
          color: AppStyles.info(context),
          onNavigate: () => Navigator.of(context, rootNavigator: true).push(
            FadeScalePageRoute(page: BudgetDetailsScreen(budgetId: capturedId)),
          ),
        ));
      }

      // ── Contacts ─────────────────────────────────────────────────────────────
      for (final contact in contactCtrl.contacts) {
        if (results.where((r) => r.type == _ResultType.contact).length >= 5) break;
        if (!contact.name.toLowerCase().contains(raw) &&
            !(contact.phoneNumber ?? '').contains(raw)) continue;
        results.add(_SearchResult(
          type: _ResultType.contact,
          id: contact.id,
          title: contact.name,
          subtitle: contact.phoneNumber ?? 'Contact',
          icon: CupertinoIcons.person_circle_fill,
          color: AppStyles.info(context),
          onNavigate: () => Navigator.of(context, rootNavigator: true).push(
            FadeScalePageRoute(page: const ContactsScreen()),
          ),
        ));
      }
    }

    if (mounted) {
      setState(() {
        _results = results;
        _parsedQuery = parsed;
        _searching = false;
      });
    }
  }

  bool _matchesParsed(Transaction tx, _ParsedQuery parsed, String rawQuery) {
    // Date range
    if (parsed.fromDate != null && tx.dateTime.isBefore(parsed.fromDate!)) return false;
    if (parsed.toDate != null && tx.dateTime.isAfter(parsed.toDate!)) return false;

    // Type
    if (parsed.type != null && tx.type != parsed.type) return false;

    // Amount
    if (parsed.minAmount != null && tx.amount < parsed.minAmount!) return false;
    if (parsed.maxAmount != null && tx.amount > parsed.maxAmount!) return false;

    // Category hints
    if (parsed.categoryHints.isNotEmpty) {
      final cat = (tx.metadata?['categoryName'] as String? ?? '').toLowerCase();
      final desc = tx.description.toLowerCase();
      final merchant = (tx.metadata?['merchant'] as String? ?? '').toLowerCase();
      final matched = parsed.categoryHints.any((hint) =>
          cat.contains(hint) ||
          desc.contains(hint) ||
          merchant.contains(hint) ||
          (_NLQueryParser._categoryKeywords[hint] ?? [])
              .any((kw) => desc.contains(kw) || merchant.contains(kw) || cat.contains(kw)));
      if (!matched) return false;
    }

    // Residual keyword
    if (parsed.keyword != null && parsed.keyword!.isNotEmpty) {
      final kw = parsed.keyword!.toLowerCase();
      final desc = tx.description.toLowerCase();
      final merchant = (tx.metadata?['merchant'] as String? ?? '').toLowerCase();
      final cat = (tx.metadata?['categoryName'] as String? ?? '').toLowerCase();
      if (!desc.contains(kw) && !merchant.contains(kw) && !cat.contains(kw)) return false;
    }

    return true;
  }

  void _onResultTap(_SearchResult result) {
    _saveRecentSearch(_query);
    final nav = result.onNavigate;
    Navigator.of(context).pop();
    WidgetsBinding.instance.addPostFrameCallback((_) => nav());
  }

  void _submitSearch(String q) {
    if (q.trim().length >= 2) _saveRecentSearch(q.trim());
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            // Search bar
            Container(
              margin: const EdgeInsets.fromLTRB(Spacing.md, Spacing.md,
                  Spacing.md, 0),
              padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.sm, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                borderRadius: BorderRadius.circular(Radii.xl),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const SizedBox(width: 4),
                  Icon(CupertinoIcons.search,
                      size: 18,
                      color: AppStyles.getSecondaryTextColor(context)),
                  const SizedBox(width: Spacing.sm),
                  Expanded(
                    child: CupertinoTextField(
                      controller: _controller,
                      focusNode: _focus,
                      placeholder: 'Search or ask in natural language…',
                      placeholderStyle: TextStyle(
                        color: AppStyles.getSecondaryTextColor(context),
                        fontSize: TypeScale.callout,
                      ),
                      style: TextStyle(
                        color: AppStyles.getTextColor(context),
                        fontSize: TypeScale.callout,
                      ),
                      decoration: null,
                      onChanged: _onQueryChanged,
                      onSubmitted: _submitSearch,
                      autocorrect: false,
                      clearButtonMode: OverlayVisibilityMode.editing,
                    ),
                  ),
                  // Mic button
                  if (_sttReady || !_isListening) ...[
                    GestureDetector(
                      onTap: _toggleVoice,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: AnimatedBuilder(
                          animation: _pulseAnim,
                          builder: (_, __) => Icon(
                            _isListening
                                ? CupertinoIcons.mic_fill
                                : CupertinoIcons.mic,
                            size: 18,
                            color: _isListening
                                ? const Color(0xFF6C63FF)
                                    .withValues(alpha: _pulseAnim.value)
                                : AppStyles.getSecondaryTextColor(context),
                          ),
                        ),
                      ),
                    ),
                  ],
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: AppStyles.getPrimaryColor(context),
                        fontSize: TypeScale.callout,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
            // Listening banner
            if (_isListening) _buildListeningBanner(context),
            const SizedBox(height: Spacing.sm),
            // Results area
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: Spacing.md),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0D0D0D) : Colors.white,
                  borderRadius: BorderRadius.circular(Radii.xl),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.20),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(Radii.xl),
                  child: _buildBody(context),
                ),
              ),
            ),
            const SizedBox(height: Spacing.md),
          ],
        ),
      ),
    );
  }

  Widget _buildListeningBanner(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (_, __) => Container(
        margin: const EdgeInsets.fromLTRB(Spacing.md, Spacing.xs, Spacing.md, 0),
        padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF6C63FF).withValues(alpha: 0.12 * _pulseAnim.value + 0.06),
          borderRadius: BorderRadius.circular(Radii.lg),
          border: Border.all(
            color: const Color(0xFF6C63FF).withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(CupertinoIcons.mic_fill,
                size: 14,
                color: const Color(0xFF6C63FF).withValues(alpha: _pulseAnim.value)),
            const SizedBox(width: 6),
            Text(
              'Listening… speak your query',
              style: TextStyle(
                fontSize: TypeScale.caption,
                color: const Color(0xFF6C63FF),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_searching) {
      return Center(
        child: CupertinoActivityIndicator(
          color: AppStyles.getPrimaryColor(context),
        ),
      );
    }

    if (_query.length >= 2 && _results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.search,
                size: 36,
                color: AppStyles.getSecondaryTextColor(context)),
            const SizedBox(height: Spacing.sm),
            Text(
              'No results for "$_query"',
              style: TextStyle(
                color: AppStyles.getSecondaryTextColor(context),
                fontSize: TypeScale.callout,
              ),
            ),
            if (_parsedQuery != null) ...[
              const SizedBox(height: Spacing.xs),
              Text(
                'Searched: ${_parsedQuery!.displaySummary}',
                style: TextStyle(
                  color: AppStyles.getSecondaryTextColor(context)
                      .withValues(alpha: 0.6),
                  fontSize: TypeScale.caption,
                ),
              ),
            ],
          ],
        ),
      );
    }

    if (_query.length >= 2 && _results.isNotEmpty) {
      return _buildResults(context);
    }

    return _buildRecentSearches(context);
  }

  Widget _buildResults(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final byType = <_ResultType, List<_SearchResult>>{};
    for (final r in _results) {
      byType.putIfAbsent(r.type, () => []).add(r);
    }

    const typeLabels = {
      _ResultType.transaction: 'TRANSACTIONS',
      _ResultType.account: 'ACCOUNTS',
      _ResultType.investment: 'INVESTMENTS',
      _ResultType.goal: 'GOALS',
      _ResultType.budget: 'BUDGETS',
      _ResultType.contact: 'CONTACTS',
    };

    final tiles = <Widget>[];

    // AI interpretation chip
    if (_parsedQuery != null) {
      final txCount = byType[_ResultType.transaction]?.length ?? 0;
      tiles.add(
        Container(
          margin: const EdgeInsets.fromLTRB(Spacing.md, Spacing.md, Spacing.md, Spacing.xs),
          padding: const EdgeInsets.symmetric(horizontal: Spacing.sm, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF6C63FF).withValues(alpha: isDark ? 0.12 : 0.07),
            borderRadius: BorderRadius.circular(Radii.lg),
          ),
          child: Row(
            children: [
              const Icon(CupertinoIcons.sparkles,
                  size: 13, color: Color(0xFF6C63FF)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${_parsedQuery!.displaySummary}  ·  $txCount result${txCount == 1 ? '' : 's'}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6C63FF),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    for (final type in _ResultType.values) {
      final group = byType[type];
      if (group == null || group.isEmpty) continue;
      // Skip section header for transactions when NL mode (chip already explains)
      if (type != _ResultType.transaction || _parsedQuery == null) {
        tiles.add(Padding(
          padding: const EdgeInsets.fromLTRB(Spacing.md, Spacing.md,
              Spacing.md, Spacing.xs),
          child: Text(typeLabels[type]!,
              style: TextStyle(
                  fontSize: TypeScale.caption,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: AppStyles.getSecondaryTextColor(context))),
        ));
      }
      for (final result in group) {
        tiles.add(_ResultTile(
          result: result,
          onTap: () => _onResultTap(result),
        ));
      }
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: Spacing.md),
      children: tiles,
    );
  }

  Widget _buildRecentSearches(BuildContext context) {
    if (_recentSearches.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(CupertinoIcons.search,
                  size: 36,
                  color: AppStyles.getSecondaryTextColor(context)
                      .withValues(alpha: 0.4)),
              const SizedBox(height: Spacing.md),
              Text(
                'Search or ask naturally',
                style: TextStyle(
                  color: AppStyles.getTextColor(context),
                  fontSize: TypeScale.callout,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: Spacing.xs),
              Text(
                '"food expenses last month"\n"transfers above ₹5000"\n"Swiggy this week"',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppStyles.getSecondaryTextColor(context),
                  fontSize: TypeScale.footnote,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(Spacing.sm),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: Spacing.sm, vertical: Spacing.xs),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('RECENT SEARCHES',
                  style: TextStyle(
                      fontSize: TypeScale.caption,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: AppStyles.getSecondaryTextColor(context))),
              CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                onPressed: _clearRecentSearches,
                child: Text('Clear',
                    style: TextStyle(
                        fontSize: TypeScale.caption,
                        color: AppStyles.getPrimaryColor(context))),
              ),
            ],
          ),
        ),
        ..._recentSearches.map((q) => _RecentSearchTile(
              query: q,
              onTap: () {
                _controller.text = q;
                _onQueryChanged(q);
              },
              onDelete: () {
                setState(() => _recentSearches.remove(q));
                SharedPreferences.getInstance().then((prefs) =>
                    prefs.setStringList(
                        _kRecentSearchesKey, _recentSearches));
              },
            )),
      ],
    );
  }

  String _fmt(double v) {
    if (v >= 10000000) return '₹${(v / 10000000).toStringAsFixed(1)}Cr';
    if (v >= 100000) return '₹${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '₹${(v / 1000).toStringAsFixed(1)}K';
    return '₹${v.toStringAsFixed(0)}';
  }

  String _fmtDate(DateTime dt) {
    const months = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    return '${dt.day} ${months[dt.month - 1]}';
  }

  String _accountTypeLabel(String typeName) {
    switch (typeName) {
      case 'savings': return 'Savings';
      case 'current': return 'Current';
      case 'credit': return 'Credit Card';
      case 'payLater': return 'Pay Later';
      case 'wallet': return 'Wallet';
      case 'cash': return 'Cash';
      case 'investment': return 'Investment';
      default: return typeName;
    }
  }
}

// ── Result tile ───────────────────────────────────────────────────────────────

class _ResultTile extends StatelessWidget {
  final _SearchResult result;
  final VoidCallback onTap;

  const _ResultTile({required this.result, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: Spacing.md, vertical: Spacing.sm),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: result.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(Radii.md),
                ),
                alignment: Alignment.center,
                child: Icon(result.icon, size: 16, color: result.color),
              ),
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(result.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: TypeScale.callout,
                            fontWeight: FontWeight.w600,
                            color: AppStyles.getTextColor(context))),
                    Text(result.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: TypeScale.caption,
                            color: AppStyles.getSecondaryTextColor(context))),
                  ],
                ),
              ),
              if (result.amount != null) ...[
                const SizedBox(width: Spacing.sm),
                Text(
                  _fmt(result.amount!),
                  style: TextStyle(
                      fontSize: TypeScale.footnote,
                      fontWeight: FontWeight.w700,
                      color: result.type == _ResultType.transaction
                          ? result.color
                          : AppStyles.getTextColor(context)),
                ),
              ],
              const SizedBox(width: Spacing.xs),
              Icon(
                CupertinoIcons.chevron_right,
                size: 12,
                color: AppStyles.getSecondaryTextColor(context)
                    .withValues(alpha: 0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmt(double v) {
    if (v >= 10000000) return '₹${(v / 10000000).toStringAsFixed(1)}Cr';
    if (v >= 100000) return '₹${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '₹${(v / 1000).toStringAsFixed(1)}K';
    return '₹${v.toStringAsFixed(0)}';
  }
}

// ── Recent search tile ────────────────────────────────────────────────────────

class _RecentSearchTile extends StatelessWidget {
  final String query;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _RecentSearchTile({
    required this.query,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: Spacing.md, vertical: Spacing.sm),
          child: Row(
            children: [
              Icon(CupertinoIcons.clock,
                  size: 16,
                  color: AppStyles.getSecondaryTextColor(context)),
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: Text(query,
                    style: TextStyle(
                        fontSize: TypeScale.callout,
                        color: AppStyles.getTextColor(context))),
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                onPressed: onDelete,
                child: Icon(CupertinoIcons.xmark,
                    size: 14,
                    color: AppStyles.getSecondaryTextColor(context)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
