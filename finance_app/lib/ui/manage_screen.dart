import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:vittara_fin_os/ui/manage/banks_screen.dart';
import 'package:vittara_fin_os/utils/logger.dart';

class ManageScreen extends StatefulWidget {
  const ManageScreen({super.key});

  @override
  State<ManageScreen> createState() => _ManageScreenState();
}

class _ManageScreenState extends State<ManageScreen> {
  final AppLogger logger = AppLogger();

  // Data model with unique IDs for reordering
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
      backgroundColor: const Color(0xFFF2F2F7), // Light gray background
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Manage'),
        previousPageTitle: 'Back',
        backgroundColor: const Color(0xFFF2F2F7).withValues(alpha:0.8), // Translucent matching bg
        border: null, // Remove border for cleaner look
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.settings, size: 24),
          onPressed: () {
            logger.info('Settings button pressed', context: 'ManageScreen');
          },
        ),
      ),
      child: SafeArea(
        child: ReorderableListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _items.length,
          onReorder: _onReorder,
          proxyDecorator: (child, index, animation) {
            return AnimatedBuilder(
              animation: animation,
              builder: (BuildContext context, Widget? child) {
                final double animValue = Curves.easeInOut.transform(animation.value);
                final double elevation = lerpDouble(0, 10, animValue)!;
                final double scale = lerpDouble(1, 1.05, animValue)!;
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha:0.2),
                          blurRadius: elevation * 2,
                          offset: Offset(0, elevation),
                        ),
                      ],
                      borderRadius: BorderRadius.circular(16),
                    ),
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
    return Container(
      key: ValueKey(item['id']),
      margin: const EdgeInsets.only(bottom: 16), // Gap between elements
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.circular(20), // Modern rounded corners
        boxShadow: [
          // Deep shadow for 3D "Elevated" look
          BoxShadow(
            color: const Color(0xFF000000).withValues(alpha:0.08),
            offset: const Offset(0, 8),
            blurRadius: 16,
            spreadRadius: -4,
          ),
          // Subtle top highlight for bevel/depth effect
          BoxShadow(
            color: const Color(0xFFFFFFFF),
            offset: const Offset(0, -1),
            blurRadius: 0,
            spreadRadius: 0,
          ),
        ],
      ),
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        onPressed: () {
          logger.info('Tapped on ${item['title']}', context: 'ManageScreen');
          if (item['id'] == 'banks') {
            Navigator.of(context).push(
              CupertinoPageRoute(builder: (context) => const BanksScreen()),
            );
          }
        },
        child: Row(
          children: [
            // Icon Container with Soft Glow
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: item['color'].withValues(alpha:0.15),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: item['color'].withValues(alpha:0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(item['icon'], size: 24, color: item['color']),
            ),
            const SizedBox(width: 20),
            // Title
            Expanded(
              child: Text(
                item['title'],
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1C1C1E), // Dark label color
                  letterSpacing: -0.5,
                ),
              ),
            ),
            // Reorder Handle Indicator (Subtle dots)
            const Icon(
              CupertinoIcons.line_horizontal_3,
              color: CupertinoColors.systemGrey4,
            ),
          ],
        ),
      ),
    );
  }
}
