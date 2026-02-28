import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/settings_controller.dart';
import 'package:vittara_fin_os/ui/manage/banks_screen.dart';
import 'package:vittara_fin_os/ui/manage/accounts_screen.dart';
import 'package:vittara_fin_os/ui/manage/cash_screen.dart';
import 'package:vittara_fin_os/ui/manage/payment_apps_screen.dart';
import 'package:vittara_fin_os/ui/manage/investments_screen.dart';
import 'package:vittara_fin_os/ui/manage/categories_screen.dart';
import 'package:vittara_fin_os/ui/manage/lending_borrowing_screen.dart';
import 'package:vittara_fin_os/ui/manage/contacts_screen.dart';
import 'package:vittara_fin_os/ui/manage/tags_screen.dart';
import 'package:vittara_fin_os/ui/manage/transactions_archive_screen.dart';
import 'package:vittara_fin_os/ui/manage/reports_analysis_screen.dart';
import 'package:vittara_fin_os/ui/widgets/animations.dart';
import 'package:vittara_fin_os/ui/widgets/common_widgets.dart';
import 'package:vittara_fin_os/ui/widgets/floating_particle_background.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/utils/logger.dart';

class ManageScreen extends StatefulWidget {
  const ManageScreen({super.key});

  @override
  State<ManageScreen> createState() => _ManageScreenState();
}

class _ManageScreenState extends State<ManageScreen> {
  final AppLogger logger = AppLogger();

  final List<Map<String, dynamic>> _items = [
    {
      'id': 'banks',
      'title': 'Banks',
      'icon': CupertinoIcons.building_2_fill,
      'color': CupertinoColors.systemBlue
    },
    {
      'id': 'accounts',
      'title': 'Accounts',
      'icon': CupertinoIcons.creditcard_fill,
      'color': CupertinoColors.systemGreen
    },
    {
      'id': 'cash',
      'title': 'Cash',
      'icon': CupertinoIcons.money_dollar_circle_fill,
      'color': CupertinoColors.systemMint
    },
    {
      'id': 'pay',
      'title': 'Payment Apps',
      'icon': CupertinoIcons.device_phone_portrait,
      'color': CupertinoColors.systemIndigo
    },
    {
      'id': 'invest',
      'title': 'Investments',
      'icon': CupertinoIcons.graph_square_fill,
      'color': CupertinoColors.systemOrange
    },
    {
      'id': 'debt',
      'title': 'Liabilities',
      'icon': CupertinoIcons.money_dollar_circle_fill,
      'color': CupertinoColors.systemRed
    },
    {
      'id': 'cats',
      'title': 'Categories',
      'icon': CupertinoIcons.square_grid_2x2_fill,
      'color': CupertinoColors.systemPurple
    },
    {
      'id': 'reports',
      'title': 'Reports & Analysis',
      'icon': CupertinoIcons.chart_bar_square_fill,
      'color': CupertinoColors.systemCyan
    },
    {
      'id': 'contacts',
      'title': 'People',
      'icon': CupertinoIcons.person_2_fill,
      'color': CupertinoColors.systemBrown
    },
    {
      'id': 'lend',
      'title': 'Personal Lending & Borrowing',
      'icon': CupertinoIcons.money_dollar_circle_fill,
      'color': CupertinoColors.systemTeal
    },
    {
      'id': 'tags',
      'title': 'Tags',
      'icon': CupertinoIcons.tag_fill,
      'color': CupertinoColors.systemIndigo
    },
    {
      'id': 'archived',
      'title': 'Archived Transactions',
      'icon': CupertinoIcons.archivebox_fill,
      'color': CupertinoColors.systemPurple
    },
  ];

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppStyles.getBackground(context),
      navigationBar: CupertinoNavigationBar(
        middle: Text('Manage',
            style: TextStyle(color: AppStyles.getTextColor(context))),
        previousPageTitle: 'Back',
        backgroundColor: AppStyles.getCardColor(context).withValues(alpha: 0.9),
        border: null,
      ),
      child: Consumer<SettingsController>(
        builder: (context, settings, child) {
          // Filter items based on settings
          final filteredItems = _items.where((item) {
            // Hide Investments if Investment Tracking is disabled
            if (item['id'] == 'invest' &&
                !settings.isInvestmentTrackingEnabled) {
              return false;
            }
            if (item['id'] == 'archived' &&
                !settings.isArchivedTransactionsEnabled) {
              return false;
            }
            return true;
          }).toList();

          return SafeArea(
            child: SubtleParticleOverlay(
              particleCount: 34,
              child: Container(
                decoration: BoxDecoration(
                  gradient: AppStyles.backgroundGradient(context),
                ),
                child: ReorderableListView.builder(
                  padding: EdgeInsets.symmetric(
                    horizontal: Spacing.lg,
                    vertical: Spacing.xl,
                  ),
                  header: Padding(
                    padding: EdgeInsets.only(bottom: Spacing.lg),
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
                    return _build3DCard(item, index, settings);
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildManageHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(Spacing.lg),
      decoration: AppStyles.sectionDecoration(
        context,
        tint: AppStyles.accentTeal,
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: AppStyles.iconBoxDecoration(
              context,
              AppStyles.accentTeal,
            ),
            child: const Icon(
              CupertinoIcons.square_grid_2x2_fill,
              color: AppStyles.accentTeal,
            ),
          ),
          SizedBox(width: Spacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Manage Workspace',
                  style: AppStyles.titleStyle(context).copyWith(
                    fontSize: TypeScale.title2,
                  ),
                ),
                SizedBox(height: Spacing.xs),
                Text(
                  'Reorder modules and open any entity with one tap',
                  style: TextStyle(
                    color: AppStyles.getSecondaryTextColor(context),
                    fontSize: TypeScale.footnote,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _build3DCard(
      Map<String, dynamic> item, int index, SettingsController settings) {
    return Padding(
      key: ValueKey(item['id']),
      padding: EdgeInsets.only(bottom: Spacing.lg),
      child: Hero(
        tag: 'manage_${item['id']}',
        child: BouncyButton(
          onPressed: () => _onCardPressed(item, settings),
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
                SizedBox(width: Spacing.lg),
                Expanded(
                  child: Text(
                    item['title'],
                    style: AppStyles.titleStyle(context),
                  ),
                ),
                Column(
                  children: [
                    Icon(
                      CupertinoIcons.arrow_right_circle_fill,
                      color: item['color'],
                      size: IconSizes.md,
                    ),
                    SizedBox(height: Spacing.xs),
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

  Future<void> _onCardPressed(
      Map<String, dynamic> item, SettingsController settings) async {
    if (item['id'] == 'archived' && settings.isArchivedTransactionsEnabled) {
      final allowed = await settings.authenticateArchivedAccess();
      if (!allowed) return;
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
      case 'cash':
        page = const CashScreen();
        break;
      case 'pay':
        page = const PaymentAppsScreen();
        break;
      case 'invest':
        page = const InvestmentsScreen();
        break;
      case 'cats':
        page = const CategoriesScreen();
        break;
      case 'reports':
        page = const ReportsAnalysisScreen();
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
