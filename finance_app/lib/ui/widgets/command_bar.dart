// T-023 · Universal Command Bar
// A spotlight-style full-screen modal that gives instant access to:
//   – Quick Add actions (expense, income, transfer, investment, goal, budget)
//   – Navigate To (all 13 screen destinations from VoiceNavigator)
//   – Smart Suggestions (top AI opportunities/anomalies)
//
// Open via: CommandBar.show(context)
// Long-press the dashboard FAB → this; short-press → QuickEntrySheet.

import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, Scaffold, Divider;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:vittara_fin_os/logic/ai/ai_intelligence_controller.dart';
import 'package:vittara_fin_os/logic/ai/voice_navigator.dart';
import 'package:vittara_fin_os/ui/dashboard/transaction_wizard.dart';
import 'package:vittara_fin_os/ui/manage/account_wizard.dart';
import 'package:vittara_fin_os/ui/manage/budgets/budgets_screen.dart';
import 'package:vittara_fin_os/ui/manage/goals/goals_screen.dart';
import 'package:vittara_fin_os/ui/manage/investments_screen.dart';
import 'package:vittara_fin_os/ui/manage/lending_borrowing_screen.dart';
import 'package:vittara_fin_os/ui/manage/transactions_archive_screen.dart';
import 'package:vittara_fin_os/ui/financial_calendar_screen.dart';
import 'package:vittara_fin_os/ui/manage/accounts_screen.dart';
import 'package:vittara_fin_os/ui/net_worth_page.dart';
import 'package:vittara_fin_os/ui/settings_screen.dart';
import 'package:vittara_fin_os/ui/spending_insights_screen.dart';
import 'package:vittara_fin_os/ui/transaction_history_screen.dart';
import 'package:vittara_fin_os/ui/notifications_page.dart';
import 'package:vittara_fin_os/ui/dashboard/quick_entry_sheet.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/widgets/animations.dart';

// ── Model ─────────────────────────────────────────────────────────────────────

enum _CmdSection { quickAdd, navigate, suggestions }

class _CmdItem {
  final String label;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final _CmdSection section;
  final VoidCallback action;

  const _CmdItem({
    required this.label,
    this.subtitle,
    required this.icon,
    required this.color,
    required this.section,
    required this.action,
  });
}

// ── Entry point ───────────────────────────────────────────────────────────────

class CommandBar {
  CommandBar._();

  static Future<void> show(BuildContext context) async {
    HapticFeedback.mediumImpact();
    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Command bar',
      barrierColor: Colors.black.withValues(alpha: 0.80),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (ctx, animation, _) => const _CommandBarPage(),
      transitionBuilder: (ctx, animation, _, child) {
        final curved =
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.0, -0.04),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }
}

// ── Page ──────────────────────────────────────────────────────────────────────

class _CommandBarPage extends StatefulWidget {
  const _CommandBarPage();

  @override
  State<_CommandBarPage> createState() => _CommandBarPageState();
}

class _CommandBarPageState extends State<_CommandBarPage> {
  final _searchCtrl = TextEditingController();
  final _focusNode = FocusNode();
  String _query = '';
  late List<_CmdItem> _allItems;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
      _buildItems();
    });
    _searchCtrl.addListener(() {
      setState(() => _query = _searchCtrl.text.toLowerCase().trim());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _buildItems() {
    if (!mounted) return;
    setState(() {
      _allItems = _buildAllItems(context);
    });
  }

  List<_CmdItem> _buildAllItems(BuildContext context) {
    final nav = Navigator.of(context, rootNavigator: true);

    void dismiss() => Navigator.of(context).pop();

    void go(Widget page) {
      dismiss();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        nav.push(FadeScalePageRoute(page: page));
      });
    }

    // ── Quick Add ────────────────────────────────────────────────────────────
    final quickAdd = <_CmdItem>[
      _CmdItem(
        label: 'Add Expense',
        subtitle: 'Record money spent',
        icon: CupertinoIcons.arrow_up_circle_fill,
        color: AppStyles.loss(context),
        section: _CmdSection.quickAdd,
        action: () {
          dismiss();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            showQuickEntrySheet(context,
                branch: TransactionWizardBranch.expense);
          });
        },
      ),
      _CmdItem(
        label: 'Add Income',
        subtitle: 'Record money received',
        icon: CupertinoIcons.arrow_down_circle_fill,
        color: AppStyles.gain(context),
        section: _CmdSection.quickAdd,
        action: () {
          dismiss();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            showQuickEntrySheet(context,
                branch: TransactionWizardBranch.income);
          });
        },
      ),
      _CmdItem(
        label: 'Transfer',
        subtitle: 'Move between accounts',
        icon: CupertinoIcons.arrow_right_arrow_left_circle_fill,
        color: AppStyles.teal(context),
        section: _CmdSection.quickAdd,
        action: () {
          dismiss();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            showQuickEntrySheet(context,
                branch: TransactionWizardBranch.transfer);
          });
        },
      ),
      _CmdItem(
        label: 'New Investment',
        subtitle: 'FD, SIP, stocks, crypto…',
        icon: CupertinoIcons.chart_bar_square_fill,
        color: AppStyles.violet(context),
        section: _CmdSection.quickAdd,
        action: () => go(const InvestmentsScreen()),
      ),
      _CmdItem(
        label: 'New Goal',
        subtitle: 'Save for something',
        icon: CupertinoIcons.flag_fill,
        color: AppStyles.gold(context),
        section: _CmdSection.quickAdd,
        action: () => go(const GoalsScreen()),
      ),
      _CmdItem(
        label: 'New Budget',
        subtitle: 'Set a spending limit',
        icon: CupertinoIcons.gauge,
        color: AppStyles.teal(context),
        section: _CmdSection.quickAdd,
        action: () => go(const BudgetsScreen()),
      ),
      _CmdItem(
        label: 'Add Account',
        subtitle: 'Bank, wallet, card',
        icon: CupertinoIcons.creditcard_fill,
        color: AppStyles.teal(context),
        section: _CmdSection.quickAdd,
        action: () {
          dismiss();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            showCupertinoModalPopup<void>(
              context: context,
              builder: (_) => const AccountWizard(),
            );
          });
        },
      ),
    ];

    // ── Navigate To ──────────────────────────────────────────────────────────
    final navItems = <_CmdItem>[
      _CmdItem(
        label: NavTarget.transactions.label,
        icon: CupertinoIcons.list_bullet,
        color: AppStyles.teal(context),
        section: _CmdSection.navigate,
        action: () => go(const TransactionHistoryScreen()),
      ),
      _CmdItem(
        label: NavTarget.accounts.label,
        icon: CupertinoIcons.creditcard,
        color: AppStyles.teal(context),
        section: _CmdSection.navigate,
        action: () => go(const AccountsScreen()),
      ),
      _CmdItem(
        label: NavTarget.investments.label,
        icon: CupertinoIcons.chart_bar_square,
        color: AppStyles.violet(context),
        section: _CmdSection.navigate,
        action: () => go(const InvestmentsScreen()),
      ),
      _CmdItem(
        label: NavTarget.budgets.label,
        icon: CupertinoIcons.gauge,
        color: AppStyles.teal(context),
        section: _CmdSection.navigate,
        action: () => go(const BudgetsScreen()),
      ),
      _CmdItem(
        label: NavTarget.goals.label,
        icon: CupertinoIcons.flag,
        color: AppStyles.gold(context),
        section: _CmdSection.navigate,
        action: () => go(const GoalsScreen()),
      ),
      _CmdItem(
        label: NavTarget.netWorth.label,
        icon: CupertinoIcons.star_circle,
        color: AppStyles.gold(context),
        section: _CmdSection.navigate,
        action: () => go(const NetWorthPage()),
      ),
      _CmdItem(
        label: NavTarget.insights.label,
        icon: CupertinoIcons.chart_pie,
        color: AppStyles.violet(context),
        section: _CmdSection.navigate,
        action: () => go(const SpendingInsightsScreen()),
      ),
      _CmdItem(
        label: NavTarget.calendar.label,
        icon: CupertinoIcons.calendar,
        color: AppStyles.teal(context),
        section: _CmdSection.navigate,
        action: () => go(const FinancialCalendarScreen()),
      ),
      _CmdItem(
        label: NavTarget.lending.label,
        icon: CupertinoIcons.hand_raised,
        color: AppStyles.gold(context),
        section: _CmdSection.navigate,
        action: () => go(const LendingBorrowingScreen()),
      ),
      _CmdItem(
        label: NavTarget.notifications.label,
        icon: CupertinoIcons.bell,
        color: AppStyles.teal(context),
        section: _CmdSection.navigate,
        action: () => go(const NotificationsPage()),
      ),
      _CmdItem(
        label: NavTarget.archive.label,
        icon: CupertinoIcons.archivebox,
        color: AppStyles.getSecondaryTextColor(context),
        section: _CmdSection.navigate,
        action: () => go(const TransactionsArchiveScreen()),
      ),
      _CmdItem(
        label: NavTarget.settings.label,
        icon: CupertinoIcons.settings,
        color: AppStyles.getSecondaryTextColor(context),
        section: _CmdSection.navigate,
        action: () => go(const SettingsScreen()),
      ),
    ];

    // ── Smart Suggestions (from AI) ──────────────────────────────────────────
    final ai = context.read<AIIntelligenceController>();
    final suggestions = <_CmdItem>[];

    for (final opp in ai.opportunities.take(2)) {
      suggestions.add(_CmdItem(
        label: opp.title,
        subtitle: opp.detail,
        icon: CupertinoIcons.lightbulb_fill,
        color: AppStyles.gold(context),
        section: _CmdSection.suggestions,
        action: () => go(const SpendingInsightsScreen()),
      ));
    }
    for (final anomaly
        in ai.anomalies.where((a) => !a.isDismissed).take(1)) {
      suggestions.add(_CmdItem(
        label: anomaly.title,
        subtitle: anomaly.explanation,
        icon: CupertinoIcons.exclamationmark_triangle_fill,
        color: AppStyles.loss(context),
        section: _CmdSection.suggestions,
        action: () => go(const TransactionHistoryScreen()),
      ));
    }

    return [...quickAdd, ...navItems, ...suggestions];
  }

  List<_CmdItem> get _filtered {
    if (_allItems.isEmpty) return [];
    if (_query.isEmpty) return _allItems;
    return _allItems
        .where((i) =>
            i.label.toLowerCase().contains(_query) ||
            (i.subtitle?.toLowerCase().contains(_query) ?? false))
        .toList();
  }

  // ── Sections ──────────────────────────────────────────────────────────────

  List<_CmdItem> _section(_CmdSection s) =>
      _filtered.where((i) => i.section == s).toList();

  @override
  Widget build(BuildContext context) {
    final isDark = AppStyles.isDarkMode(context);
    final cardColor = isDark ? AppStyles.darkL1 : AppStyles.lightCard;
    final divColor = AppStyles.getDividerColor(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Spacing.md, Spacing.md,
              Spacing.md, Spacing.md),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: Container(
                decoration: BoxDecoration(
                  color: cardColor.withValues(alpha: isDark ? 0.95 : 0.98),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppStyles.aetherTeal.withValues(alpha: 0.25),
                  ),
                ),
                child: Column(
                  children: [
                    // ── Search field ────────────────────────────────────────
                    Padding(
                      padding:
                          const EdgeInsets.fromLTRB(Spacing.lg, Spacing.lg,
                              Spacing.lg, Spacing.sm),
                      child: CupertinoTextField(
                        controller: _searchCtrl,
                        focusNode: _focusNode,
                        placeholder: 'Search actions, screens, insights…',
                        prefix: Padding(
                          padding:
                              const EdgeInsets.only(left: Spacing.sm),
                          child: Icon(
                            CupertinoIcons.search,
                            size: 18,
                            color: AppStyles.getSecondaryTextColor(context),
                          ),
                        ),
                        suffix: _query.isNotEmpty
                            ? CupertinoButton(
                                padding: const EdgeInsets.only(right: 8),
                                minSize: 0,
                                onPressed: () {
                                  _searchCtrl.clear();
                                  _focusNode.requestFocus();
                                },
                                child: Icon(
                                  CupertinoIcons.xmark_circle_fill,
                                  size: 18,
                                  color: AppStyles.getSecondaryTextColor(
                                      context),
                                ),
                              )
                            : null,
                        padding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 8),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppStyles.darkL2
                              : const Color(0xFFF0F0F5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        style: TextStyle(
                          color: AppStyles.getTextColor(context),
                          fontSize: 15,
                        ),
                      ),
                    ),
                    Divider(color: divColor, height: 1),
                    // ── Results list ────────────────────────────────────────
                    Expanded(
                      child: _filtered.isEmpty
                          ? _buildEmpty()
                          : ListView(
                              padding: const EdgeInsets.only(
                                  bottom: Spacing.xl),
                              children: [
                                if (_section(_CmdSection.quickAdd)
                                    .isNotEmpty) ...[
                                  _buildSectionHeader('Quick Add'),
                                  ..._section(_CmdSection.quickAdd)
                                      .map(_buildRow),
                                ],
                                if (_section(_CmdSection.navigate)
                                    .isNotEmpty) ...[
                                  _buildSectionHeader('Navigate'),
                                  ..._section(_CmdSection.navigate)
                                      .map(_buildRow),
                                ],
                                if (_section(_CmdSection.suggestions)
                                    .isNotEmpty) ...[
                                  _buildSectionHeader('Smart Suggestions'),
                                  ..._section(_CmdSection.suggestions)
                                      .map(_buildRow),
                                ],
                              ],
                            ),
                    ),
                    // ── Dismiss hint ────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.only(bottom: Spacing.sm),
                      child: Text(
                        'Tap outside to dismiss',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppStyles.getSecondaryTextColor(context)
                              .withValues(alpha: 0.45),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          Spacing.lg, Spacing.md, Spacing.lg, Spacing.xs),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: AppStyles.getSecondaryTextColor(context)
              .withValues(alpha: 0.7),
        ),
      ),
    );
  }

  Widget _buildRow(_CmdItem item) {
    return BouncyButton(
      onPressed: () {
        HapticFeedback.lightImpact();
        item.action();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: Spacing.lg, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: item.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(item.icon, size: 18, color: item.color),
            ),
            const SizedBox(width: Spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppStyles.getTextColor(context),
                    ),
                  ),
                  if (item.subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.subtitle!,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppStyles.getSecondaryTextColor(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              CupertinoIcons.chevron_right,
              size: 14,
              color: AppStyles.getSecondaryTextColor(context)
                  .withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            CupertinoIcons.search,
            size: 40,
            color: AppStyles.getSecondaryTextColor(context)
                .withValues(alpha: 0.3),
          ),
          const SizedBox(height: Spacing.md),
          Text(
            'No results for "$_query"',
            style: TextStyle(
              fontSize: 14,
              color: AppStyles.getSecondaryTextColor(context),
            ),
          ),
        ],
      ),
    );
  }
}
