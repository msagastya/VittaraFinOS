import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/settings_controller.dart';
import 'package:vittara_fin_os/ui/manage/banks_screen.dart';
import 'package:vittara_fin_os/ui/manage/accounts_screen.dart';
import 'package:vittara_fin_os/ui/manage/payment_apps_screen.dart';
import 'package:vittara_fin_os/ui/manage/investments_screen.dart';
import 'package:vittara_fin_os/ui/manage/categories_screen.dart';
import 'package:vittara_fin_os/ui/manage/lending_borrowing_screen.dart';
import 'package:vittara_fin_os/ui/manage/contacts_screen.dart';
import 'package:vittara_fin_os/ui/manage/tags_screen.dart';
import 'package:vittara_fin_os/ui/manage/transactions_archive_screen.dart';
import 'package:vittara_fin_os/ui/widgets/animations.dart';
import 'package:vittara_fin_os/ui/widgets/common_widgets.dart';
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
        backgroundColor:
            AppStyles.getBackground(context).withValues(alpha: 0.9),
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
            child: ReorderableListView.builder(
              padding: EdgeInsets.symmetric(
                  horizontal: Spacing.lg, vertical: Spacing.xl),
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
                        decoration: AppStyles.cardDecoration(context).copyWith(
                          boxShadow: [
                            BoxShadow(
                              color: SemanticColors.getPrimary(context)
                                  .withValues(alpha: 0.2),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
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
          );
        },
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
            decoration: AppStyles.cardDecoration(context),
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
                Icon(
                  CupertinoIcons.line_horizontal_3,
                  color: AppStyles.getSecondaryTextColor(context),
                  size: IconSizes.sm,
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
      case 'pay':
        page = const PaymentAppsScreen();
        break;
      case 'invest':
        page = const InvestmentsScreen();
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
