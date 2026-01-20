import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:vittara_fin_os/ui/manage/banks_screen.dart';
import 'package:vittara_fin_os/ui/manage/accounts_screen.dart';
import 'package:vittara_fin_os/ui/manage/payment_apps_screen.dart';
import 'package:vittara_fin_os/ui/settings_screen.dart';
import 'package:vittara_fin_os/ui/widgets/animations.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/utils/logger.dart';

class ManageScreen extends StatefulWidget {
  const ManageScreen({super.key});

  @override
  State<ManageScreen> createState() => _ManageScreenState();
}

class _ManageScreenState extends State<ManageScreen> {
  final AppLogger logger = AppLogger();

  final List<Map<String, dynamic>> _items = [
    {'id': 'banks', 'title': 'Banks', 'icon': CupertinoIcons.building_2_fill, 'color': CupertinoColors.systemBlue},
    {'id': 'accounts', 'title': 'Accounts', 'icon': CupertinoIcons.creditcard_fill, 'color': CupertinoColors.systemGreen},
    {'id': 'pay', 'title': 'Payment Apps', 'icon': CupertinoIcons.device_phone_portrait, 'color': CupertinoColors.systemIndigo},
    {'id': 'invest', 'title': 'Investments', 'icon': CupertinoIcons.graph_square_fill, 'color': CupertinoColors.systemOrange},
    {'id': 'debt', 'title': 'Liabilities', 'icon': CupertinoIcons.money_dollar_circle_fill, 'color': CupertinoColors.systemRed},
    {'id': 'cats', 'title': 'Categories', 'icon': CupertinoIcons.square_grid_2x2_fill, 'color': CupertinoColors.systemPurple},
    {'id': 'lend', 'title': 'Personal Lending', 'icon': CupertinoIcons.person_2_fill, 'color': CupertinoColors.systemTeal},
    {'id': 'tags', 'title': 'Tags', 'icon': CupertinoIcons.tag_fill, 'color': CupertinoColors.systemPink},
  ];

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final item = _items.removeAt(oldIndex);
      _items.insert(newIndex, item);
    });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppStyles.getBackground(context),
      navigationBar: CupertinoNavigationBar(
        middle: Text('Manage', style: TextStyle(color: AppStyles.getTextColor(context))),
        previousPageTitle: 'Back',
        backgroundColor: AppStyles.getBackground(context).withValues(alpha: 0.9),
        border: null,
      ),
      child: SafeArea(
        child: ReorderableListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          itemCount: _items.length,
          onReorder: _onReorder,
          proxyDecorator: (child, index, animation) {
            return AnimatedBuilder(
              animation: animation,
              builder: (BuildContext context, Widget? child) {
                return Transform.scale(
                  scale: 1.02,
                  child: Container(
                    decoration: AppStyles.cardDecoration(context),
                    child: child,
                  ),
                );
              },
              child: child,
            );
          },
          itemBuilder: (context, index) {
            final item = _items[index];
            return _build3DCard(item, index);
          },
        ),
      ),
    );
  }

  Widget _build3DCard(Map<String, dynamic> item, int index) {
    return Padding(
      key: ValueKey(item['id']),
      padding: const EdgeInsets.only(bottom: 16),
      child: BouncyButton(
        onPressed: () {
          logger.info('Tapped on ${item['title']}', context: 'ManageScreen');
          if (item['id'] == 'banks') {
            Navigator.of(context).push(FadeScalePageRoute(page: const BanksScreen()));
          } else if (item['id'] == 'accounts') {
            Navigator.of(context).push(FadeScalePageRoute(page: const AccountsScreen()));
          } else if (item['id'] == 'pay') {
            Navigator.of(context).push(FadeScalePageRoute(page: const PaymentAppsScreen()));
          }
        },
        child: Container(
          decoration: AppStyles.cardDecoration(context),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: AppStyles.iconBoxDecoration(context, item['color']),
                child: Icon(item['icon'], size: 24, color: item['color']),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  item['title'],
                  style: AppStyles.titleStyle(context),
                ),
              ),
              Icon(
                CupertinoIcons.line_horizontal_3,
                color: AppStyles.getSecondaryTextColor(context),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
