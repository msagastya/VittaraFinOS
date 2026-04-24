import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vittara_fin_os/logic/settings_controller.dart';
import 'package:vittara_fin_os/ui/manage/banks_screen.dart';
import 'package:vittara_fin_os/ui/manage/accounts_screen.dart';
import 'package:vittara_fin_os/ui/manage/payment_apps_screen.dart';
import 'package:vittara_fin_os/ui/manage/investments_screen.dart';
import 'package:vittara_fin_os/ui/manage/categories_screen.dart';
import 'package:vittara_fin_os/ui/manage/lending_borrowing_screen.dart';
import 'package:vittara_fin_os/ui/manage/loans/loan_tracker_screen.dart';
import 'package:vittara_fin_os/ui/manage/insurance/insurance_screen.dart';
import 'package:vittara_fin_os/ui/manage/contacts_screen.dart';
import 'package:vittara_fin_os/ui/manage/tags_screen.dart';
import 'package:vittara_fin_os/ui/manage/transactions_archive_screen.dart';
import 'package:vittara_fin_os/ui/widgets/animations.dart';
import 'package:vittara_fin_os/ui/widgets/common_widgets.dart';
import 'package:vittara_fin_os/ui/widgets/floating_particle_background.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/styles/typography.dart';
import 'package:vittara_fin_os/ui/widgets/toast_notification.dart' as toast_lib;
import 'package:vittara_fin_os/ui/styles/responsive_utils.dart';
import 'package:vittara_fin_os/utils/logger.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Section model
// ─────────────────────────────────────────────────────────────────────────────

class _Section {
  final String id;
  final String title;
  final String subtitle;
  final Color color;
  final List<String> itemIds;

  const _Section({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.itemIds,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// ManageScreen
// ─────────────────────────────────────────────────────────────────────────────

class ManageScreen extends StatefulWidget {
  const ManageScreen({super.key});

  @override
  State<ManageScreen> createState() => _ManageScreenState();
}

class _ManageScreenState extends State<ManageScreen> {
  final AppLogger logger = AppLogger();
  static const _orderPrefKey = 'manage_screen_order';
  static const _collapsedPrefKeyPrefix = 'manage_section_';

  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  // Collapsed state per section id
  final Map<String, bool> _collapsed = {
    'money': false,
    'grow': false,
    'control': false,
  };

  static const List<_Section> _sections = [
    _Section(
      id: 'money',
      title: 'Money',
      subtitle: 'Accounts, payments & lending',
      color: SemanticColors.accounts,
      itemIds: ['accounts', 'banks', 'pay', 'lend'],
    ),
    _Section(
      id: 'grow',
      title: 'Grow',
      subtitle: 'Investments, goals & debt',
      color: SemanticColors.investments,
      itemIds: ['invest', 'debt', 'insurance'],
    ),
    _Section(
      id: 'control',
      title: 'Control',
      subtitle: 'Categories, tags & archive',
      color: SemanticColors.categories,
      itemIds: ['cats', 'contacts', 'tags', 'archived'],
    ),
  ];

  final List<Map<String, dynamic>> _items = [
    {
      'id': 'accounts',
      'title': 'Accounts',
      'subtitle': 'Savings, credit, cash, wallets — linked to banks',
      'icon': CupertinoIcons.creditcard_fill,
      'color': SemanticColors.accounts,
    },
    {
      'id': 'banks',
      'title': 'Banks',
      'subtitle': 'Your banks and financial institutions',
      'icon': CupertinoIcons.building_2_fill,
      'color': SemanticColors.banks,
    },
    {
      'id': 'pay',
      'title': 'Payment Apps',
      'subtitle': 'UPI & digital payment wallets',
      'icon': CupertinoIcons.device_phone_portrait,
      'color': SemanticColors.paymentApps,
    },
    {
      'id': 'lend',
      'title': 'Personal Lending & Borrowing',
      'subtitle': 'Track money lent & borrowed',
      'icon': CupertinoIcons.money_dollar_circle_fill,
      'color': SemanticColors.lending,
    },
    {
      'id': 'invest',
      'title': 'Investments',
      'subtitle': 'Stocks, MF, FD, gold & more',
      'icon': CupertinoIcons.graph_square_fill,
      'color': SemanticColors.investments,
    },
    {
      'id': 'debt',
      'title': 'Loan / EMI Tracker',
      'subtitle': 'Home, car & personal loans',
      'icon': CupertinoIcons.doc_chart_fill,
      'color': SemanticColors.liabilities,
    },
    {
      'id': 'insurance',
      'title': 'Insurance Tracker',
      'subtitle': 'Health, life & general policies',
      'icon': CupertinoIcons.shield_fill,
      'color': SemanticColors.info,
    },
    {
      'id': 'cats',
      'title': 'Categories',
      'subtitle': 'Organise spending by type',
      'icon': CupertinoIcons.square_grid_2x2_fill,
      'color': SemanticColors.categories,
    },
    {
      'id': 'contacts',
      'title': 'People',
      'subtitle': 'Contacts for transfers & splits',
      'icon': CupertinoIcons.person_2_fill,
      'color': SemanticColors.contacts,
    },
    {
      'id': 'tags',
      'title': 'Tags',
      'subtitle': 'Custom labels for transactions',
      'icon': CupertinoIcons.tag_fill,
      'color': SemanticColors.tags,
    },
    {
      'id': 'archived',
      'title': 'Archived Transactions',
      'subtitle': 'Hidden & archived entries',
      'icon': CupertinoIcons.archivebox_fill,
      'color': SemanticColors.categories,
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _searchCtrl.addListener(() {
      setState(() => _query = _searchCtrl.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    // Load order
    final saved = prefs.getStringList(_orderPrefKey);
    if (saved != null && saved.isNotEmpty) {
      final ordered = <Map<String, dynamic>>[];
      for (final id in saved) {
        final idx = _items.indexWhere((item) => item['id'] == id);
        if (idx >= 0) ordered.add(_items[idx]);
      }
      for (final item in _items) {
        if (!saved.contains(item['id'])) ordered.add(item);
      }
      if (mounted) {
        setState(() {
          _items
            ..clear()
            ..addAll(ordered);
        });
      }
    }
    // Load collapsed state
    for (final s in _sections) {
      final key = '$_collapsedPrefKeyPrefix${s.id}_collapsed';
      final collapsed = prefs.getBool(key) ?? false;
      if (mounted) setState(() => _collapsed[s.id] = collapsed);
    }
  }

  Future<void> _saveOrder() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        _orderPrefKey, _items.map((i) => i['id'] as String).toList());
  }

  Future<void> _toggleSection(String sectionId) async {
    final newVal = !(_collapsed[sectionId] ?? false);
    setState(() => _collapsed[sectionId] = newVal);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(
        '$_collapsedPrefKeyPrefix${sectionId}_collapsed', newVal);
    Haptics.light();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppStyles.getBackground(context),
      navigationBar: AppStyles.isLandscape(context)
          ? null
          : AppStyles.standardNavBar(context, 'Manage'),
      child: Builder(
        builder: (context) {
          final showInvestments = context.select<SettingsController, bool>(
              (s) => s.isInvestmentTrackingEnabled);
          final showArchived = context.select<SettingsController, bool>(
              (s) => s.isArchivedTransactionsEnabled);

          // Build a filtered items map keyed by id (respecting feature flags)
          final visibleIds = _items
              .where((item) {
                if (item['id'] == 'invest' && !showInvestments) return false;
                if (item['id'] == 'archived' && !showArchived) return false;
                return true;
              })
              .map((i) => i['id'] as String)
              .toSet();

          final isLandscape = AppStyles.isLandscape(context);

          return SafeArea(
            child: RepaintBoundary(
              child: SubtleParticleOverlay(
                particleCount: 0,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: AppStyles.backgroundGradient(context),
                  ),
                  child: isLandscape
                      ? _buildLandscapeGrid(context, visibleIds)
                      : _buildPortraitBody(context, visibleIds),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPortraitBody(BuildContext context, Set<String> visibleIds) {
    final isSearching = _query.length >= 2;
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
                RS.lg(context), RS.md(context), RS.lg(context), RS.sm(context)),
            child: _buildSearchBar(context),
          ),
        ),
        if (isSearching)
          _buildSearchResults(context, visibleIds)
        else
          ..._buildSections(context, visibleIds),
        const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
      ],
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    final isDark = AppStyles.isDarkMode(context);
    return CupertinoTextField(
      controller: _searchCtrl,
      placeholder: 'Search accounts, categories, investments…',
      prefix: Padding(
        padding: const EdgeInsets.only(left: Spacing.sm),
        child: Icon(CupertinoIcons.search,
            size: 16, color: AppStyles.getSecondaryTextColor(context)),
      ),
      suffix: _query.isNotEmpty
          ? CupertinoButton(
              padding: const EdgeInsets.only(right: 8),
              minSize: 0,
              onPressed: () => _searchCtrl.clear(),
              child: Icon(CupertinoIcons.xmark_circle_fill,
                  size: 16,
                  color: AppStyles.getSecondaryTextColor(context)),
            )
          : null,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: isDark ? AppStyles.darkL2 : const Color(0xFFF0F0F5),
        borderRadius: BorderRadius.circular(12),
      ),
      style: TextStyle(
        color: AppStyles.getTextColor(context),
        fontSize: 14,
      ),
    );
  }

  SliverList _buildSearchResults(
      BuildContext context, Set<String> visibleIds) {
    final q = _query;
    final matches = _items.where((item) {
      if (!visibleIds.contains(item['id'])) return false;
      final title = (item['title'] as String).toLowerCase();
      final subtitle = (item['subtitle'] as String? ?? '').toLowerCase();
      return title.contains(q) || subtitle.contains(q);
    }).toList();

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index == 0) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                  RS.lg(context), RS.sm(context), RS.lg(context), Spacing.sm),
              child: Text(
                '${matches.length} result${matches.length == 1 ? '' : 's'}',
                style: TextStyle(
                  fontSize: TypeScale.caption,
                  color: AppStyles.getSecondaryTextColor(context),
                ),
              ),
            );
          }
          final item = matches[index - 1];
          return Padding(
            padding: EdgeInsets.fromLTRB(
                RS.lg(context), 0, RS.lg(context), Spacing.md),
            child: _buildCard(item),
          );
        },
        childCount: matches.length + 1,
      ),
    );
  }

  List<Widget> _buildSections(BuildContext context, Set<String> visibleIds) {
    return _sections.map((section) {
      final sectionItems = section.itemIds
          .where((id) => visibleIds.contains(id))
          .map((id) => _items.firstWhere((i) => i['id'] == id))
          .toList();

      if (sectionItems.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

      final collapsed = _collapsed[section.id] ?? false;

      return SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
              RS.lg(context), RS.md(context), RS.lg(context), 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section header — tappable to collapse
              GestureDetector(
                onTap: () => _toggleSection(section.id),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: section.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          _sectionIcon(section.id),
                          size: 14,
                          color: section.color,
                        ),
                      ),
                      const SizedBox(width: Spacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              section.title,
                              style: TextStyle(
                                fontSize: TypeScale.subhead,
                                fontWeight: FontWeight.w700,
                                color: AppStyles.getTextColor(context),
                                letterSpacing: 0.2,
                              ),
                            ),
                            Text(
                              section.subtitle,
                              style: TextStyle(
                                fontSize: TypeScale.caption,
                                color: AppStyles.getSecondaryTextColor(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                      AnimatedRotation(
                        turns: collapsed ? -0.25 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          CupertinoIcons.chevron_down,
                          size: 14,
                          color: AppStyles.getSecondaryTextColor(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Items with AnimatedContainer for collapse animation
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 220),
                crossFadeState: collapsed
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                firstChild: Column(
                  children: [
                    const SizedBox(height: Spacing.xs),
                    ...sectionItems.map((item) => Padding(
                          padding: const EdgeInsets.only(bottom: Spacing.md),
                          child: _buildCard(item),
                        )),
                  ],
                ),
                secondChild: const SizedBox(width: double.infinity, height: 0),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  IconData _sectionIcon(String id) {
    switch (id) {
      case 'money':
        return CupertinoIcons.creditcard_fill;
      case 'grow':
        return CupertinoIcons.graph_square_fill;
      case 'control':
        return CupertinoIcons.slider_horizontal_3;
      default:
        return CupertinoIcons.circle_fill;
    }
  }

  Widget _buildCard(Map<String, dynamic> item) {
    return Hero(
      tag: 'manage_${item['id']}',
      child: BouncyButton(
        onPressed: () => _onCardPressed(item),
        child: Container(
          decoration: AppStyles.sectionDecoration(
            context,
            tint: item['color'],
            radius: 22,
          ),
          padding: Spacing.cardPadding,
          child: Row(
            children: [
              IconBox(
                icon: item['icon'],
                color: item['color'],
                showGlow: true,
              ),
              const SizedBox(width: Spacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['title'],
                      style: AppStyles.titleStyle(context),
                    ),
                    if (item['subtitle'] != null) ...[
                      const SizedBox(height: Spacing.xxs),
                      Text(
                        item['subtitle'] as String,
                        style: TextStyle(
                          fontSize: TypeScale.footnote,
                          color: AppStyles.getSecondaryTextColor(context),
                          fontWeight: FontWeight.w400,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (item['comingSoon'] == true) ...[
                      const SizedBox(height: Spacing.xxs),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: Spacing.sm, vertical: 2),
                        decoration: BoxDecoration(
                          color:
                              SemanticColors.warning.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Coming Soon',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: SemanticColors.warning,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                item['comingSoon'] == true
                    ? CupertinoIcons.lock_fill
                    : CupertinoIcons.arrow_right_circle_fill,
                color: item['comingSoon'] == true
                    ? AppStyles.getSecondaryTextColor(context)
                    : item['color'],
                size: IconSizes.md,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Landscape ──────────────────────────────────────────────────────────────

  Widget _buildLandscapeGrid(BuildContext context, Set<String> visibleIds) {
    final textColor = AppStyles.getTextColor(context);
    final items = _items.where((i) => visibleIds.contains(i['id'])).toList();
    return Column(
      children: [
        // Compact nav bar
        Container(
          height: 44,
          decoration: BoxDecoration(
            color: AppStyles.getCardColor(context).withValues(alpha: 0.90),
            border: Border(
              bottom: BorderSide(
                  color: AppStyles.getDividerColor(context), width: 0.5),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
          child: Row(
            children: [
              CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                onPressed: () => Navigator.maybePop(context),
                child: Icon(CupertinoIcons.chevron_left,
                    size: 18, color: AppStyles.getPrimaryColor(context)),
              ),
              const SizedBox(width: 6),
              Text(
                'MANAGE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(Spacing.md),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: Spacing.md,
              mainAxisSpacing: Spacing.md,
              childAspectRatio: 3.2,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) =>
                _buildGridCard(context, items[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildGridCard(BuildContext context, Map<String, dynamic> item) {
    final color = item['color'] as Color;
    return BouncyButton(
      onPressed: () => _onCardPressed(item),
      child: Container(
        decoration: BoxDecoration(
          color: AppStyles.getCardColor(context),
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(color: color.withValues(alpha: 0.20)),
        ),
        padding: const EdgeInsets.symmetric(
            horizontal: Spacing.md, vertical: Spacing.sm),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(Radii.sm),
              ),
              child: Icon(item['icon'] as IconData, size: 17, color: color),
            ),
            const SizedBox(width: Spacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    item['title'] as String,
                    style: TextStyle(
                      fontSize: TypeScale.subhead,
                      fontWeight: FontWeight.w600,
                      color: AppStyles.getTextColor(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (item['subtitle'] != null)
                    Text(
                      item['subtitle'] as String,
                      style: TextStyle(
                        fontSize: 10,
                        color: AppStyles.getSecondaryTextColor(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            Icon(CupertinoIcons.chevron_right,
                size: 12, color: color.withValues(alpha: 0.6)),
          ],
        ),
      ),
    );
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _onCardPressed(Map<String, dynamic> item) async {
    if (item['comingSoon'] == true) {
      toast_lib.toast.showInfo('${item['title']} – Coming Soon');
      return;
    }
    if (item['id'] == 'archived') {
      final settings = context.read<SettingsController>();
      if (settings.isArchivedTransactionsEnabled) {
        final allowed = await settings.authenticateArchivedAccess();
        if (!allowed) return;
      }
    }
    _navigateToScreen(item['id']);
  }

  void _navigateToScreen(String id) {
    Widget? page;
    switch (id) {
      case 'banks':
        page = const BanksScreen();
        break;
      case 'accounts':
        page = const AccountsScreen();
        break;
      case 'pay':
        page = const PaymentAppsScreen();
        break;
      case 'invest':
        page = const InvestmentsScreen();
        break;
      case 'debt':
        page = const LoanTrackerScreen();
        break;
      case 'insurance':
        page = const InsuranceScreen();
        break;
      case 'cats':
        page = const CategoriesScreen();
        break;
      case 'contacts':
        page = const ContactsScreen();
        break;
      case 'lend':
        page = const LendingBorrowingScreen();
        break;
      case 'tags':
        page = const TagsScreen();
        break;
      case 'archived':
        page = const TransactionsArchiveScreen();
        break;
    }
    if (page != null) {
      Navigator.of(context).push(FadeScalePageRoute(page: page));
    }
  }
}
