import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vittara_fin_os/logic/accounts_controller.dart';
import 'package:vittara_fin_os/logic/contacts_controller.dart';
import 'package:vittara_fin_os/logic/goals_controller.dart';
import 'package:vittara_fin_os/logic/investments_controller.dart';
import 'package:vittara_fin_os/logic/transactions_controller.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';

const String _kRecentSearchesKey = 'global_search_recent';
const int _kMaxRecentSearches = 10;

enum _ResultType { transaction, account, investment, goal, contact }

class _SearchResult {
  final _ResultType type;
  final String id;
  final String title;
  final String subtitle;
  final double? amount;
  final IconData icon;
  final Color color;

  const _SearchResult({
    required this.type,
    required this.id,
    required this.title,
    required this.subtitle,
    this.amount,
    required this.icon,
    required this.color,
  });
}

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

class _GlobalSearchPageState extends State<_GlobalSearchPage> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;
  List<_SearchResult> _results = [];
  List<String> _recentSearches = [];
  bool _searching = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

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

  void _onQueryChanged(String value) {
    setState(() => _query = value);
    _debounce?.cancel();
    if (value.trim().length < 2) {
      setState(() {
        _results = [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 200), () => _runSearch(value));
  }

  void _runSearch(String q) {
    if (!mounted) return;
    final query = q.toLowerCase().trim();
    final results = <_SearchResult>[];
    final txCtrl = context.read<TransactionsController>();
    final accCtrl = context.read<AccountsController>();
    final invCtrl = context.read<InvestmentsController>();
    final goalCtrl = context.read<GoalsController>();
    final contactCtrl = context.read<ContactsController>();

    // Transactions
    for (final tx in txCtrl.transactions) {
      if (results.where((r) => r.type == _ResultType.transaction).length >= 5)
        break;
      final desc = tx.description.toLowerCase();
      final amt = tx.amount.toString();
      final cat = (tx.metadata?['categoryName'] as String? ?? '').toLowerCase();
      if (desc.contains(query) || amt.contains(query) || cat.contains(query)) {
        results.add(_SearchResult(
          type: _ResultType.transaction,
          id: tx.id,
          title: tx.description,
          subtitle: cat.isNotEmpty ? cat : _fmtDate(tx.dateTime),
          amount: tx.amount,
          icon: CupertinoIcons.arrow_right_arrow_left_circle_fill,
          color: tx.type.name.toLowerCase().contains('income')
              ? AppStyles.gain(context)
              : AppStyles.loss(context),
        ));
      }
    }

    // Accounts
    for (final acc in accCtrl.accounts) {
      if (results.where((r) => r.type == _ResultType.account).length >= 3) break;
      if (acc.name.toLowerCase().contains(query) ||
          acc.bankName.toLowerCase().contains(query)) {
        results.add(_SearchResult(
          type: _ResultType.account,
          id: acc.id,
          title: acc.name,
          subtitle: acc.bankName,
          amount: acc.balance,
          icon: CupertinoIcons.creditcard_fill,
          color: AppStyles.teal(context),
        ));
      }
    }

    // Investments
    for (final inv in invCtrl.investments) {
      if (results.where((r) => r.type == _ResultType.investment).length >= 5)
        break;
      if (inv.name.toLowerCase().contains(query) ||
          (inv.broker ?? '').toLowerCase().contains(query) ||
          inv.getTypeLabel().toLowerCase().contains(query)) {
        results.add(_SearchResult(
          type: _ResultType.investment,
          id: inv.id,
          title: inv.name,
          subtitle: inv.getTypeLabel(),
          amount: inv.amount,
          icon: CupertinoIcons.chart_bar_square_fill,
          color: AppStyles.violet(context),
        ));
      }
    }

    // Goals
    for (final goal in goalCtrl.goals) {
      if (results.where((r) => r.type == _ResultType.goal).length >= 3) break;
      if (goal.name.toLowerCase().contains(query)) {
        results.add(_SearchResult(
          type: _ResultType.goal,
          id: goal.id,
          title: goal.name,
          subtitle: 'Goal · ${_fmt(goal.currentAmount)} / ${_fmt(goal.targetAmount)}',
          amount: goal.targetAmount,
          icon: CupertinoIcons.star_fill,
          color: AppStyles.gold(context),
        ));
      }
    }

    // Contacts
    for (final contact in contactCtrl.contacts) {
      if (results.where((r) => r.type == _ResultType.contact).length >= 3) break;
      if (contact.name.toLowerCase().contains(query)) {
        results.add(_SearchResult(
          type: _ResultType.contact,
          id: contact.id,
          title: contact.name,
          subtitle: contact.phoneNumber ?? 'Contact',
          icon: CupertinoIcons.person_circle_fill,
          color: AppStyles.info(context),
        ));
      }
    }

    if (mounted) {
      setState(() {
        _results = results;
        _searching = false;
      });
    }
  }

  void _submitSearch(String q) {
    if (q.trim().length >= 2) _saveRecentSearch(q.trim());
  }

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
                color: isDark
                    ? const Color(0xFF1C1C1E)
                    : Colors.white,
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
                      placeholder: 'Search transactions, accounts, goals…',
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
            const SizedBox(height: Spacing.sm),
            // Results area
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: Spacing.md),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF0D0D0D)
                      : Colors.white,
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
          ],
        ),
      );
    }

    if (_query.length >= 2 && _results.isNotEmpty) {
      return _buildResults(context);
    }

    // Show recent searches
    return _buildRecentSearches(context);
  }

  Widget _buildRecentSearches(BuildContext context) {
    if (_recentSearches.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.clock,
                size: 36,
                color: AppStyles.getSecondaryTextColor(context)),
            const SizedBox(height: Spacing.sm),
            Text(
              'Search transactions, accounts, investments, goals and contacts',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppStyles.getSecondaryTextColor(context),
                fontSize: TypeScale.footnote,
              ),
            ),
          ],
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

  Widget _buildResults(BuildContext context) {
    // Group by type
    final byType = <_ResultType, List<_SearchResult>>{};
    for (final r in _results) {
      byType.putIfAbsent(r.type, () => []).add(r);
    }

    final typeLabels = {
      _ResultType.transaction: 'TRANSACTIONS',
      _ResultType.account: 'ACCOUNTS',
      _ResultType.investment: 'INVESTMENTS',
      _ResultType.goal: 'GOALS',
      _ResultType.contact: 'CONTACTS',
    };

    final tiles = <Widget>[];
    for (final type in _ResultType.values) {
      final group = byType[type];
      if (group == null || group.isEmpty) continue;
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
      for (final result in group) {
        tiles.add(_ResultTile(
          result: result,
          onTap: () {
            _saveRecentSearch(_query);
            Navigator.of(context).pop();
            // Future: navigate to result
          },
        ));
      }
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: Spacing.md),
      children: tiles,
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
}

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
