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

class ManageScreen extends StatefulWidget {
  const ManageScreen({super.key});

  @override
  State<ManageScreen> createState() => _ManageScreenState();
}

class _ManageScreenState extends State<ManageScreen> {
  final AppLogger logger = AppLogger();
  static const _orderPrefKey = 'manage_screen_order';

  final List<Map<String, dynamic>> _items = [
    {
      'id': 'accounts',
      'title': 'Accounts',
      'subtitle': 'Savings, credit, cash, wallets — linked to banks',
      'icon': CupertinoIcons.creditcard_fill,
      'color': SemanticColors.accounts // natural green, safe in both themes
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
      'color': SemanticColors.liabilities, // normal red, safe in both themes
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
      'id': 'lend',
      'title': 'Personal Lending & Borrowing',
      'subtitle': 'Track money lent & borrowed',
      'icon': CupertinoIcons.money_dollar_circle_fill,
      'color': SemanticColors.lending,
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
    _loadOrder();
  }

  Future<void> _loadOrder() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_orderPrefKey);
    if (saved == null || saved.isEmpty) return;
    // Reorder _items to match saved order, keeping any new ids at end
    final ordered = <Map<String, dynamic>>[];
    for (final id in saved) {
      final idx = _items.indexWhere((item) => item['id'] == id);
      if (idx >= 0) ordered.add(_items[idx]);
    }
    // Append any items not in saved list
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

  Future<void> _saveOrder() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        _orderPrefKey, _items.map((i) => i['id'] as String).toList());
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
          // Only select the two booleans we need — avoids full rebuild on unrelated settings changes
          final showInvestments = context.select<SettingsController, bool>(
              (s) => s.isInvestmentTrackingEnabled);
          final showArchived = context.select<SettingsController, bool>(
              (s) => s.isArchivedTransactionsEnabled);

          final filteredItems = _items.where((item) {
            if (item['id'] == 'invest' && !showInvestments) return false;
            if (item['id'] == 'archived' && !showArchived) return false;
            return true;
          }).toList();

          return SafeArea(
            child: RepaintBoundary(
              child: SubtleParticleOverlay(
                particleCount: AppStyles.isLandscape(context) ? 0 : 12,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: AppStyles.backgroundGradient(context),
                  ),
                  child: Column(
                    children: [
                      if (AppStyles.isLandscape(context))
                        _buildLandscapeNavBar(context),
                      Expanded(
                        child: RLayout.tabletConstrain(
                          context,
                          ReorderableListView.builder(
                    padding: EdgeInsets.symmetric(
                      horizontal: RS.lg(context),
                      vertical: RS.xl(context),
                    ),
                    header: Padding(
                      padding: const EdgeInsets.only(bottom: Spacing.lg),
                      child: _buildManageHeader(context),
                    ),
                    itemCount: filteredItems.length,
                    onReorder: (oldIndex, newIndex) {
                      Haptics.reorder();
                      setState(() {
                        if (oldIndex < newIndex) {
                          newIndex -= 1;
                        }
                        final item = _items.removeAt(oldIndex);
                        _items.insert(newIndex, item);
                      });
                      _saveOrder();
                    },
                    proxyDecorator: (child, index, animation) {
                      return AnimatedBuilder(
                        animation: animation,
                        builder: (BuildContext context, Widget? child) {
                          return Transform.scale(
                            scale: 1.02,
                            child: Container(
                              decoration:
                                  AppStyles.cardDecoration(context).copyWith(
                                boxShadow: [
                                  ...AppStyles.elevatedShadows(
                                    context,
                                    tint: SemanticColors.getPrimary(context),
                                    strength: 0.7,
                                  ),
                                ],
                              ),
                              child: child,
                            ),
                          );
                        },
                        child: child,
                      );
                    },
                    itemBuilder: (context, index) {
                      final item = filteredItems[index];
                      return _build3DCard(item, index);
                    },
                  ),
                        ), // closes tabletConstrain
                      ), // closes Expanded
                    ], // closes Column children
                  ), // closes Column
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLandscapeNavBar(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
      child: Row(
        children: [
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
            minimumSize: const Size(44, 44),
            onPressed: () => Navigator.maybePop(context),
            child: Icon(CupertinoIcons.chevron_left, size: 20,
                color: AppStyles.getPrimaryColor(context)),
          ),
          const SizedBox(width: 8),
          Text('MANAGE',
              style: AppTypography.sectionLabel(color: AppStyles.getTextColor(context))),
        ],
      ),
    );
  }

  Widget _buildManageHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.sm),
      child: Text(
        'Hold & drag to reorder',
        style: TextStyle(
          fontSize: TypeScale.caption,
          color: AppStyles.getSecondaryTextColor(context),
          letterSpacing: 0.3,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _build3DCard(Map<String, dynamic> item, int index) {
    return Padding(
      key: ValueKey(item['id']),
      padding: const EdgeInsets.only(bottom: Spacing.lg),
      child: Hero(
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
                            color: SemanticColors.warning
                                .withValues(alpha: 0.15),
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
                Column(
                  children: [
                    Icon(
                      item['comingSoon'] == true
                          ? CupertinoIcons.lock_fill
                          : CupertinoIcons.arrow_right_circle_fill,
                      color: item['comingSoon'] == true
                          ? AppStyles.getSecondaryTextColor(context)
                          : item['color'],
                      size: IconSizes.md,
                    ),
                    const SizedBox(height: Spacing.xs),
                    Icon(
                      CupertinoIcons.line_horizontal_3,
                      color: AppStyles.getSecondaryTextColor(context),
                      size: IconSizes.xs,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

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
