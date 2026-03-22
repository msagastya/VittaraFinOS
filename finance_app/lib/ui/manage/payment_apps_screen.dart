import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/payment_apps_controller.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/widgets/animations.dart';
import 'package:vittara_fin_os/ui/widgets/common_widgets.dart';
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
  int _selectedTab = 0; // 0 = Wallets, 1 = All Apps

  void _onReorder(
      int oldIndex, int newIndex, PaymentAppsController appsController) {
    appsController.reorderApps(oldIndex, newIndex);
  }

  void _toggleApp(
      String appId, bool value, PaymentAppsController appsController) {
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

  void _showSetWalletBalanceModal(
    BuildContext context,
    PaymentAppsController appsController,
    Map<String, dynamic> app,
  ) {
    final controller = TextEditingController(
      text: ((app['walletBalance'] as num?)?.toDouble() ?? 0.0)
          .toStringAsFixed(2),
    );
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) {
        final keyboardInset = MediaQuery.of(ctx).viewInsets.bottom;
        return AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(bottom: keyboardInset),
          child: SafeArea(
            top: false,
            child: Container(
              constraints: BoxConstraints(
                maxHeight: AppStyles.sheetMaxHeight(ctx),
              ),
              padding: const EdgeInsets.all(Spacing.xxl),
              decoration: BoxDecoration(
                color: AppStyles.getCardColor(ctx),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Wallet Balance', style: AppStyles.titleStyle(ctx)),
                    const SizedBox(height: Spacing.md),
                    Text(
                      app['name'],
                      style: TextStyle(
                          color: AppStyles.getSecondaryTextColor(ctx)),
                    ),
                    const SizedBox(height: Spacing.md),
                    CupertinoTextField(
                      controller: controller,
                      autofocus: true,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      prefix: const Padding(
                        padding: EdgeInsets.only(left: 12),
                        child: Text('₹'),
                      ),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppStyles.getBackground(ctx),
                        borderRadius: BorderRadius.circular(Radii.md),
                      ),
                    ),
                    const SizedBox(height: Spacing.lg),
                    Row(
                      children: [
                        Expanded(
                          child: CupertinoButton(
                            color: CupertinoColors.systemGrey4,
                            onPressed: () => Navigator.pop(ctx),
                            child: Text('Cancel',
                                style: TextStyle(
                                    color: AppStyles.getTextColor(ctx))),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: CupertinoButton(
                            color: CupertinoColors.systemBlue,
                            onPressed: () {
                              final value =
                                  double.tryParse(controller.text.trim());
                              if (value == null || value < 0) return;
                              appsController.setWalletBalance(
                                  app['id'] as String, value);
                              Navigator.pop(ctx);
                            },
                            child: const Text('Save',
                                style: TextStyle(color: Colors.white)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ).whenComplete(controller.dispose);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PaymentAppsController>(
      builder: (context, appsController, child) {
        final walletApps = appsController.paymentApps
            .where((app) =>
                (app['isEnabled'] as bool? ?? false) &&
                (app['hasWallet'] as bool? ?? false))
            .toList();

        final filteredApps = appsController.paymentApps.where((app) {
          return app['name']
              .toString()
              .toLowerCase()
              .contains(_searchQuery.toLowerCase());
        }).toList();

        return CupertinoPageScaffold(
          backgroundColor: AppStyles.getBackground(context),
          navigationBar: AppStyles.isLandscape(context) ? null : CupertinoNavigationBar(
            middle: Text('Payment Apps',
                style: TextStyle(color: AppStyles.getTextColor(context))),
            previousPageTitle: 'Back',
            backgroundColor: AppStyles.getBackground(context),
            border: null,
            trailing: _selectedTab == 1
                ? CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => _sortApps(appsController),
                    child: Icon(
                      _isAscending
                          ? CupertinoIcons.sort_down
                          : CupertinoIcons.sort_up,
                      size: 24,
                      color: AppStyles.accentBlue,
                    ),
                  )
                : null,
          ),
          child: SafeArea(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Column(
                  children: [
                    // Segmented control
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: CupertinoSlidingSegmentedControl<int>(
                        groupValue: _selectedTab,
                        backgroundColor: AppStyles.getCardColor(context),
                        thumbColor: _selectedTab == 0
                            ? CupertinoColors.systemIndigo
                            : AppStyles.accentBlue,
                        children: {
                          0: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(CupertinoIcons.creditcard_fill,
                                    size: 14,
                                    color: _selectedTab == 0
                                        ? Colors.white
                                        : AppStyles.getSecondaryTextColor(context)),
                                const SizedBox(width: 6),
                                Text('Wallets',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: _selectedTab == 0
                                          ? Colors.white
                                          : AppStyles.getTextColor(context),
                                    )),
                                if (walletApps.isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _selectedTab == 0
                                          ? Colors.white.withValues(alpha: 0.3)
                                          : CupertinoColors.systemIndigo
                                              .withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${walletApps.length}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: _selectedTab == 0
                                            ? Colors.white
                                            : CupertinoColors.systemIndigo,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          1: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                    CupertinoIcons.device_phone_portrait,
                                    size: 14,
                                    color: _selectedTab == 1
                                        ? Colors.white
                                        : AppStyles.getSecondaryTextColor(context)),
                                const SizedBox(width: 6),
                                Text('All Apps',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: _selectedTab == 1
                                          ? Colors.white
                                          : AppStyles.getTextColor(context),
                                    )),
                              ],
                            ),
                          ),
                        },
                        onValueChanged: (val) {
                          if (val != null) setState(() => _selectedTab = val);
                        },
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Tab content
                    Expanded(
                      child: _selectedTab == 0
                          ? _buildWalletsTab(walletApps, appsController)
                          : _buildAllAppsTab(
                              filteredApps, appsController),
                    ),
                  ],
                ),
                Positioned(
                  right: 16,
                  bottom: 24,
                  child: BouncyButton(
                    onPressed: () =>
                        _showAddPaymentAppModal(context, appsController),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 14),
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemBlue,
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(
                            color: CupertinoColors.systemBlue
                                .withValues(alpha: 0.35),
                            blurRadius: 14,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(CupertinoIcons.add,
                              color: Colors.white, size: 20),
                          SizedBox(width: Spacing.sm),
                          Text('Add App',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: TypeScale.headline,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Wallets tab ──────────────────────────────────────────────────────────────

  Widget _buildWalletsTab(
      List<Map<String, dynamic>> walletApps, PaymentAppsController ctrl) {
    if (walletApps.isEmpty) {
      return EmptyStateView(
        icon: CupertinoIcons.creditcard_fill,
        title: 'No wallet apps',
        subtitle:
            'Enable apps with wallet feature and toggle them on to see them here.',
        actionLabel: 'Go to All Apps',
        onAction: () => setState(() => _selectedTab = 1),
      );
    }

    final totalWalletBalance = walletApps.fold<double>(
        0, (sum, app) => sum + ((app['walletBalance'] as num?)?.toDouble() ?? 0));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
      children: [
        // Total balance banner
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(Spacing.xl),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                CupertinoColors.systemIndigo,
                CupertinoColors.systemIndigo.withValues(alpha: 0.75),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: CupertinoColors.systemIndigo.withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(CupertinoIcons.creditcard_fill,
                  color: Colors.white, size: 28),
              const SizedBox(width: Spacing.lg),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Total Wallet Balance',
                      style: TextStyle(
                          color: Colors.white70,
                          fontSize: TypeScale.footnote,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Text(
                    '₹${totalWalletBalance.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: TypeScale.title1,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                '${walletApps.length} wallet${walletApps.length == 1 ? '' : 's'}',
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: TypeScale.footnote,
                    fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),

        // Wallet cards
        ...walletApps.map((app) => _buildWalletCard(app, ctrl)),
      ],
    );
  }

  Widget _buildWalletCard(
      Map<String, dynamic> app, PaymentAppsController ctrl) {
    final balance = (app['walletBalance'] as num?)?.toDouble() ?? 0.0;
    final color = (app['color'] as Color?) ?? CupertinoColors.systemBlue;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: AppStyles.sectionDecoration(context, tint: color, radius: 16),
      child: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: AppStyles.iconBoxDecoration(context, color),
              child: Center(
                child: Icon(CupertinoIcons.square_fill, color: color, size: 22),
              ),
            ),
            const SizedBox(width: Spacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(app['name'] as String,
                      style: AppStyles.titleStyle(context)),
                  const SizedBox(height: 4),
                  Text(
                    '₹${balance.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: TypeScale.headline,
                      fontWeight: FontWeight.w700,
                      color: balance >= 0 ? AppStyles.gain(context) : AppStyles.loss(context),
                    ),
                  ),
                ],
              ),
            ),
            BouncyButton(
              onPressed: () =>
                  _showSetWalletBalanceModal(context, ctrl, app),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: color.withValues(alpha: 0.35), width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.pencil, size: 14, color: color),
                    const SizedBox(width: 4),
                    Text('Edit',
                        style: TextStyle(
                            color: color,
                            fontSize: TypeScale.footnote,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── All Apps tab ─────────────────────────────────────────────────────────────

  Widget _buildAllAppsTab(
      List<Map<String, dynamic>> filteredApps, PaymentAppsController ctrl) {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          decoration: BoxDecoration(
            color: AppStyles.getCardColor(context),
            borderRadius: BorderRadius.circular(Radii.md),
          ),
          child: CupertinoSearchTextField(
            backgroundColor: Colors.transparent,
            style: TextStyle(color: AppStyles.getTextColor(context)),
            placeholder: 'Search Payment Apps',
            placeholderStyle:
                TextStyle(color: AppStyles.getSecondaryTextColor(context)),
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
        ),
        Expanded(
          child: filteredApps.isEmpty
              ? EmptyStateView(
                  icon: CupertinoIcons.device_phone_portrait,
                  title: ctrl.paymentApps.isEmpty
                      ? 'No payment apps yet'
                      : 'No apps match your search',
                  subtitle: ctrl.paymentApps.isEmpty
                      ? 'Add your first payment app to track wallet balances.'
                      : 'Try a different search term.',
                  actionLabel:
                      ctrl.paymentApps.isEmpty ? 'Add First App' : null,
                  onAction: ctrl.paymentApps.isEmpty
                      ? () => _showAddPaymentAppModal(context, ctrl)
                      : null,
                )
              : ReorderableListView.builder(
                  buildDefaultDragHandles: false,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                  itemCount: filteredApps.length,
                  onReorder: (oldIndex, newIndex) =>
                      _onReorder(oldIndex, newIndex, ctrl),
                  itemBuilder: (context, index) {
                    final app = filteredApps[index];
                    return _buildPaymentAppCard(app, ctrl);
                  },
                ),
        ),
      ],
    );
  }

  void _showEnableWalletModal(
    BuildContext context,
    PaymentAppsController appsController,
    Map<String, dynamic> app,
  ) {
    final balanceController = TextEditingController();
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) {
        final keyboardInset = MediaQuery.of(ctx).viewInsets.bottom;
        return AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(bottom: keyboardInset),
          child: SafeArea(
            top: false,
            child: Container(
              constraints: BoxConstraints(
                maxHeight: AppStyles.sheetMaxHeight(ctx),
              ),
              padding: const EdgeInsets.all(Spacing.xxl),
              decoration: BoxDecoration(
                color: AppStyles.getCardColor(ctx),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Enable Wallet', style: AppStyles.titleStyle(ctx)),
                    const SizedBox(height: Spacing.sm),
                    Text(
                      app['name'],
                      style: TextStyle(
                          color: AppStyles.getSecondaryTextColor(ctx)),
                    ),
                    const SizedBox(height: Spacing.md),
                    CupertinoTextField(
                      controller: balanceController,
                      autofocus: true,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) {
                        final opening =
                            double.tryParse(balanceController.text.trim()) ??
                                0.0;
                        appsController.setWalletSupport(
                          app['id'] as String,
                          true,
                          openingBalance: opening,
                        );
                        Navigator.pop(ctx);
                      },
                      placeholder: 'Opening balance (optional)',
                      prefix: const Padding(
                        padding: EdgeInsets.only(left: 12),
                        child: Text('₹'),
                      ),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppStyles.getBackground(ctx),
                        borderRadius: BorderRadius.circular(Radii.md),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: CupertinoButton(
                            color: CupertinoColors.systemGrey4,
                            onPressed: () => Navigator.pop(ctx),
                            child: Text('Cancel',
                                style: TextStyle(
                                    color: AppStyles.getTextColor(ctx))),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: CupertinoButton(
                            color: CupertinoColors.systemBlue,
                            onPressed: () {
                              final opening = double.tryParse(
                                      balanceController.text.trim()) ??
                                  0.0;
                              appsController.setWalletSupport(
                                app['id'] as String,
                                true,
                                openingBalance: opening,
                              );
                              Navigator.pop(ctx);
                            },
                            child: const Text('Enable',
                                style: TextStyle(color: Colors.white)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ).whenComplete(balanceController.dispose);
  }

  Widget _buildPaymentAppCard(
      Map<String, dynamic> app, PaymentAppsController appsController) {
    return Container(
      key: ValueKey(app['id']),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: AppStyles.cardDecoration(context),
      child: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
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
            const SizedBox(width: Spacing.lg),
            Expanded(
              child: Text(
                app['name'],
                style: AppStyles.titleStyle(context),
              ),
            ),
            if ((app['hasWallet'] ?? false) == true)
              GestureDetector(
                onTap: () =>
                    _showSetWalletBalanceModal(context, appsController, app),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemBlue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Wallet ₹${((app['walletBalance'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: CupertinoColors.systemBlue,
                      fontSize: TypeScale.footnote,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Transform.scale(
                  scale: 0.8,
                  child: CupertinoSwitch(
                    value: app['isEnabled'],
                    activeTrackColor: AppStyles.gain(context),
                    onChanged: (bool value) async {
                      await appsController.toggleApp(
                        app['id'] as String,
                        value,
                      );
                    },
                  ),
                ),
                const SizedBox(width: Spacing.sm),
                Theme(
                  data: Theme.of(context).copyWith(
                    popupMenuTheme: PopupMenuThemeData(
                      color: AppStyles.getCardColor(context),
                      textStyle:
                          TextStyle(color: AppStyles.getTextColor(context)),
                    ),
                  ),
                  child: PopupMenuButton<String>(
                    icon: Icon(
                      CupertinoIcons.ellipsis_vertical,
                      color: AppStyles.getSecondaryTextColor(context),
                    ),
                    onSelected: (String result) {
                      if (result == 'delete') {
                        _deleteApp(app['id'], appsController);
                      } else if (result == 'enable_wallet') {
                        _showEnableWalletModal(context, appsController, app);
                      } else if (result == 'disable_wallet') {
                        appsController.setWalletSupport(
                            app['id'] as String, false);
                      }
                    },
                    itemBuilder: (BuildContext context) =>
                        <PopupMenuEntry<String>>[
                      PopupMenuItem<String>(
                        value: (app['hasWallet'] ?? false)
                            ? 'disable_wallet'
                            : 'enable_wallet',
                        child: Text(
                          (app['hasWallet'] ?? false)
                              ? 'Disable Wallet'
                              : 'Enable Wallet',
                        ),
                      ),
                      const PopupMenuItem<String>(
                        value: 'delete',
                        child: Text(
                          'Delete',
                          style:
                              TextStyle(color: CupertinoColors.destructiveRed),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                ReorderableDragStartListener(
                  index: appsController.paymentApps
                      .indexWhere((element) => element['id'] == app['id']),
                  child: Icon(
                    CupertinoIcons.line_horizontal_3,
                    color: AppStyles.getSecondaryTextColor(context),
                    size: 18,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAddPaymentAppModal(
      BuildContext context, PaymentAppsController appsController) {
    final appNameController = TextEditingController();
    final walletBalanceController = TextEditingController();
    bool hasWallet = false;

    showCupertinoModalPopup(
      context: context,
      builder: (modalContext) {
        return StatefulBuilder(builder: (context, setModalState) {
          final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
          return AnimatedPadding(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: EdgeInsets.only(bottom: keyboardInset),
            child: SafeArea(
              top: false,
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: AppStyles.sheetMaxHeight(context),
                ),
                decoration: BoxDecoration(
                  color: AppStyles.getCardColor(context),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Column(
                        children: [
                          Container(
                            width: 40,
                            height: 5,
                            decoration: BoxDecoration(
                              color: CupertinoColors.systemGrey3,
                              borderRadius: BorderRadius.circular(2.5),
                            ),
                          ),
                          const SizedBox(height: Spacing.lg),
                          Text('Add Payment App',
                              style: AppStyles.titleStyle(context)
                                  .copyWith(fontSize: TypeScale.title2)),
                        ],
                      ),
                    ),
                    Divider(
                        color: AppStyles.getSecondaryTextColor(context)
                            .withValues(alpha: 0.2)),
                    Expanded(
                      child: SingleChildScrollView(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.all(Spacing.xxl),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('App Name',
                                style: TextStyle(
                                    fontSize: TypeScale.body,
                                    fontWeight: FontWeight.w500,
                                    color: AppStyles.getSecondaryTextColor(
                                        context))),
                            const SizedBox(height: Spacing.sm),
                            CupertinoTextField(
                              controller: appNameController,
                              autofocus: true,
                              textInputAction: TextInputAction.next,
                              placeholder: 'e.g. Google Pay, PhonePe',
                              padding: const EdgeInsets.all(Spacing.lg),
                              decoration: BoxDecoration(
                                color: AppStyles.getCardColor(context),
                                border: Border.all(
                                    color: CupertinoColors.systemBlue
                                        .withValues(alpha: 0.2)),
                                borderRadius: BorderRadius.circular(Radii.md),
                              ),
                              style: TextStyle(
                                  color: AppStyles.getTextColor(context)),
                            ),
                            const SizedBox(height: Spacing.xxl),
                            Text('Wallet feature',
                                style: TextStyle(
                                    fontSize: TypeScale.body,
                                    fontWeight: FontWeight.w500,
                                    color: AppStyles.getSecondaryTextColor(
                                        context))),
                            const SizedBox(height: Spacing.md),
                            Container(
                              decoration: BoxDecoration(
                                color: AppStyles.getSecondaryTextColor(context)
                                    .withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(Radii.md),
                              ),
                              padding: const EdgeInsets.all(Spacing.xs),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: BouncyButton(
                                      onPressed: () =>
                                          setModalState(() => hasWallet = true),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 12),
                                        decoration: BoxDecoration(
                                          color: hasWallet
                                              ? AppStyles.gain(context)
                                              : Colors.transparent,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Center(
                                          child: Text('Yes',
                                              style: TextStyle(
                                                  color: hasWallet
                                                      ? Colors.white
                                                      : AppStyles.getTextColor(
                                                          context))),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: Spacing.md),
                                  Expanded(
                                    child: BouncyButton(
                                      onPressed: () => setModalState(
                                          () => hasWallet = false),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 12),
                                        decoration: BoxDecoration(
                                          color: !hasWallet
                                              ? AppStyles.loss(context)
                                              : Colors.transparent,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Center(
                                          child: Text('No',
                                              style: TextStyle(
                                                  color: !hasWallet
                                                      ? Colors.white
                                                      : AppStyles.getTextColor(
                                                          context))),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (hasWallet) ...[
                              const SizedBox(height: Spacing.xl),
                              Text('Opening wallet balance',
                                  style: TextStyle(
                                      fontSize: TypeScale.body,
                                      fontWeight: FontWeight.w500,
                                      color: AppStyles.getSecondaryTextColor(
                                          context))),
                              const SizedBox(height: Spacing.sm),
                              CupertinoTextField(
                                controller: walletBalanceController,
                                placeholder: '0.00',
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                prefix: const Padding(
                                  padding: EdgeInsets.only(left: 12),
                                  child: Text('₹'),
                                ),
                                padding: const EdgeInsets.all(Spacing.lg),
                                decoration: BoxDecoration(
                                  color: AppStyles.getCardColor(context),
                                  border: Border.all(
                                      color: CupertinoColors.systemBlue
                                          .withValues(alpha: 0.2)),
                                  borderRadius: BorderRadius.circular(Radii.md),
                                ),
                                style: TextStyle(
                                    color: AppStyles.getTextColor(context)),
                              ),
                            ],
                            const SizedBox(height: Spacing.xxxl),
                            BouncyButton(
                              onPressed: () {
                                final name = appNameController.text.trim();
                                if (name.isEmpty) return;
                                final walletBalance = hasWallet
                                    ? (double.tryParse(walletBalanceController
                                            .text
                                            .trim()) ??
                                        0.0)
                                    : 0.0;
                                final newApp = {
                                  'id': name.replaceAll(' ', '_').toLowerCase(),
                                  'name': name,
                                  'color': CupertinoColors.systemBlue,
                                  'isEnabled': true,
                                  'hasWallet': hasWallet,
                                  'walletBalance': walletBalance,
                                };
                                appsController.addApp(newApp);
                                Navigator.pop(context);
                              },
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                decoration: BoxDecoration(
                                  color: CupertinoColors.systemBlue,
                                  borderRadius: BorderRadius.circular(Radii.md),
                                ),
                                child: const Center(
                                  child: Text('Save',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: TypeScale.headline,
                                          fontWeight: FontWeight.w600)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        });
      },
    ).whenComplete(() {
      appNameController.dispose();
      walletBalanceController.dispose();
    });
  }
}
