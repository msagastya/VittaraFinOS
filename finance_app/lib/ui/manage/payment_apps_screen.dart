import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/payment_apps_controller.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/utils/logger.dart';

class PaymentAppsScreen extends StatefulWidget {
  const PaymentAppsScreen({super.key});

  @override
  State<PaymentAppsScreen> createState() => _PaymentAppsScreenState();
}

class _PaymentAppsScreenState extends State<PaymentAppsScreen> {
  final AppLogger logger = AppLogger();
  String _searchQuery = '';
  bool _isAscending = true;

  void _onReorder(int oldIndex, int newIndex, PaymentAppsController appsController) {
    appsController.reorderApps(oldIndex, newIndex);
  }

  void _toggleApp(String appId, bool value, PaymentAppsController appsController) {
    appsController.toggleApp(appId, value);
  }

  void _deleteApp(String appId, PaymentAppsController appsController) {
    appsController.deleteApp(appId);
    logger.info('Deleted payment app: $appId', context: 'PaymentAppsScreen');
  }

  void _sortApps(PaymentAppsController appsController) {
    _isAscending = !_isAscending;
    appsController.sortApps(_isAscending);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PaymentAppsController>(
      builder: (context, appsController, child) {
        final filteredApps = appsController.paymentApps.where((app) {
          return app['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
        }).toList();

        return CupertinoPageScaffold(
          backgroundColor: AppStyles.getBackground(context),
          navigationBar: CupertinoNavigationBar(
            middle: Text('Payment Apps', style: TextStyle(color: AppStyles.getTextColor(context))),
            previousPageTitle: 'Manage',
            backgroundColor: AppStyles.getBackground(context),
            border: null,
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => _sortApps(appsController),
              child: Icon(
                _isAscending ? CupertinoIcons.sort_down : CupertinoIcons.sort_up,
                size: 24,
                color: AppStyles.accentBlue,
              ),
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppStyles.getCardColor(context),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: CupertinoSearchTextField(
                    backgroundColor: Colors.transparent,
                    style: TextStyle(color: AppStyles.getTextColor(context)),
                    placeholder: 'Search Payment Apps',
                    placeholderStyle: TextStyle(color: AppStyles.getSecondaryTextColor(context)),
                    onChanged: (value) => setState(() => _searchQuery = value),
                  ),
                ),
                Expanded(
                  child: ReorderableListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                    itemCount: filteredApps.length,
                    onReorder: (oldIndex, newIndex) =>
                        _onReorder(oldIndex, newIndex, appsController),
                    itemBuilder: (context, index) {
                      final app = filteredApps[index];
                      return _buildPaymentAppCard(app, appsController);
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPaymentAppCard(Map<String, dynamic> app, PaymentAppsController appsController) {
    return Container(
      key: ValueKey(app['id']),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: AppStyles.cardDecoration(context),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: AppStyles.iconBoxDecoration(context, app['color']),
              child: Center(
                child: Icon(
                  CupertinoIcons.square_fill,
                  color: app['color'],
                  size: 24,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                app['name'],
                style: AppStyles.titleStyle(context),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Transform.scale(
                  scale: 0.8,
                  child: CupertinoSwitch(
                    value: app['isEnabled'],
                    activeColor: CupertinoColors.systemGreen,
                    onChanged: (bool value) =>
                        _toggleApp(app['id'], value, appsController),
                  ),
                ),
                const SizedBox(width: 8),
                Theme(
                  data: Theme.of(context).copyWith(
                    popupMenuTheme: PopupMenuThemeData(
                      color: AppStyles.getCardColor(context),
                      textStyle: TextStyle(color: AppStyles.getTextColor(context)),
                    ),
                  ),
                  child: PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert,
                      color: AppStyles.getSecondaryTextColor(context),
                    ),
                    onSelected: (String result) {
                      if (result == 'delete') {
                        _deleteApp(app['id'], appsController);
                      }
                    },
                    itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                      const PopupMenuItem<String>(
                        value: 'delete',
                        child: Text(
                          'Delete',
                          style: TextStyle(color: CupertinoColors.destructiveRed),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
