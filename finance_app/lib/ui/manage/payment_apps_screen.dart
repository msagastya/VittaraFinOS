import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/account_model.dart';
import 'package:vittara_fin_os/logic/accounts_controller.dart';
import 'package:vittara_fin_os/logic/payment_apps_controller.dart';
import 'package:vittara_fin_os/logic/transactions_controller.dart';
import 'package:vittara_fin_os/logic/transaction_model.dart';
import 'package:vittara_fin_os/ui/transaction_history_screen.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/widgets/animations.dart';
import 'package:vittara_fin_os/ui/widgets/common_widgets.dart';
import 'package:vittara_fin_os/ui/widgets/toast_notification.dart';
import 'package:vittara_fin_os/utils/id_generator.dart';
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
  int _selectedTab = 0; // 0 = Active, 1 = Wallets, 2 = All Apps

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

  void _showWalletTransferSheet(
    BuildContext context,
    PaymentAppsController appsController,
    Map<String, dynamic> app,
  ) {
    final balance = (app['walletBalance'] as num?)?.toDouble() ?? 0.0;
    if (balance <= 0) {
      toast.showError('Wallet balance is zero — nothing to transfer');
      return;
    }

    final amountCtrl = TextEditingController();
    final notesCtrl = TextEditingController(
      text: 'Wallet transfer from ${app['name']}',
    );
    Account? selectedAccount;

    showCupertinoModalPopup(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheetState) {
          final keyboardInset = MediaQuery.of(ctx).viewInsets.bottom;
          final accountsCtrl = ctx.read<AccountsController>();
          final accounts = accountsCtrl.accounts
              .where((a) => !a.isHidden)
              .toList();

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
                decoration: BoxDecoration(
                  color: AppStyles.getCardColor(ctx),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: Padding(
                    padding: const EdgeInsets.all(Spacing.xxl),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Handle
                        Center(
                          child: Container(
                            width: 40, height: 4,
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: AppStyles.getSecondaryTextColor(ctx)
                                  .withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),

                        // Title
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: CupertinoColors.systemIndigo
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                CupertinoIcons.arrow_right_arrow_left_circle_fill,
                                color: CupertinoColors.systemIndigo,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Transfer to Account',
                                      style: AppStyles.titleStyle(ctx)),
                                  Text(
                                    '${app['name']} Wallet · ₹${balance.toStringAsFixed(2)} available',
                                    style: TextStyle(
                                      fontSize: TypeScale.caption,
                                      color: AppStyles.getSecondaryTextColor(ctx),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: Spacing.xl),

                        // Amount field
                        Text('Amount (₹)',
                            style: TextStyle(
                              fontSize: TypeScale.footnote,
                              fontWeight: FontWeight.w600,
                              color: AppStyles.getSecondaryTextColor(ctx),
                            )),
                        const SizedBox(height: Spacing.xs),
                        CupertinoTextField(
                          controller: amountCtrl,
                          autofocus: true,
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          prefix: const Padding(
                            padding: EdgeInsets.only(left: 14),
                            child: Text('₹',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w600)),
                          ),
                          placeholder: '0.00',
                          padding: const EdgeInsets.all(14),
                          style: TextStyle(
                            color: AppStyles.getTextColor(ctx),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: BoxDecoration(
                            color: AppStyles.getBackground(ctx),
                            borderRadius: BorderRadius.circular(Radii.md),
                          ),
                          onChanged: (_) => setSheetState(() {}),
                        ),

                        const SizedBox(height: Spacing.md),

                        // Destination account
                        Text('To Account',
                            style: TextStyle(
                              fontSize: TypeScale.footnote,
                              fontWeight: FontWeight.w600,
                              color: AppStyles.getSecondaryTextColor(ctx),
                            )),
                        const SizedBox(height: Spacing.xs),

                        if (accounts.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(Spacing.md),
                            decoration: BoxDecoration(
                              color: AppStyles.getBackground(ctx),
                              borderRadius: BorderRadius.circular(Radii.md),
                            ),
                            child: Text(
                              'No accounts found. Add an account first.',
                              style: TextStyle(
                                color: AppStyles.getSecondaryTextColor(ctx),
                                fontSize: TypeScale.footnote,
                              ),
                            ),
                          )
                        else
                          GestureDetector(
                            onTap: () {
                              showCupertinoModalPopup<void>(
                                context: ctx,
                                builder: (pickerCtx) => Container(
                                  height: 300,
                                  color: AppStyles.isDarkMode(pickerCtx)
                                      ? const Color(0xFF1C1C1E)
                                      : CupertinoColors.systemBackground
                                          .resolveFrom(pickerCtx),
                                  child: Column(
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          CupertinoButton(
                                            onPressed: () =>
                                                Navigator.pop(pickerCtx),
                                            child: const Text('Cancel'),
                                          ),
                                          CupertinoButton(
                                            onPressed: () =>
                                                Navigator.pop(pickerCtx),
                                            child: const Text('Done',
                                                style: TextStyle(
                                                    fontWeight:
                                                        FontWeight.bold)),
                                          ),
                                        ],
                                      ),
                                      Expanded(
                                        child: CupertinoPicker(
                                          scrollController:
                                              FixedExtentScrollController(
                                            initialItem: selectedAccount != null
                                                ? accounts.indexWhere(
                                                    (a) =>
                                                        a.id ==
                                                        selectedAccount!.id)
                                                : 0,
                                          ),
                                          itemExtent: 44,
                                          onSelectedItemChanged: (i) {
                                            setSheetState(() =>
                                                selectedAccount = accounts[i]);
                                          },
                                          children: accounts
                                              .map((a) => Center(
                                                    child: Text(
                                                      '${a.name} (${a.bankName})',
                                                      style: TextStyle(
                                                        color: AppStyles
                                                            .getTextColor(
                                                                pickerCtx),
                                                        fontSize:
                                                            TypeScale.body,
                                                      ),
                                                    ),
                                                  ))
                                              .toList(),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ).then((_) {
                                selectedAccount ??= accounts.isNotEmpty
                                    ? accounts.first
                                    : null;
                                setSheetState(() {});
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 13),
                              decoration: BoxDecoration(
                                color: AppStyles.getBackground(ctx),
                                borderRadius: BorderRadius.circular(Radii.md),
                                border: Border.all(
                                  color: selectedAccount != null
                                      ? CupertinoColors.systemIndigo
                                          .withValues(alpha: 0.5)
                                      : Colors.transparent,
                                ),
                              ),
                              child: Row(
                                children: [
                                  if (selectedAccount != null) ...[
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: selectedAccount!.color,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                  ],
                                  Expanded(
                                    child: Text(
                                      selectedAccount != null
                                          ? '${selectedAccount!.name}  ·  ${selectedAccount!.bankName}'
                                          : 'Tap to select account',
                                      style: TextStyle(
                                        color: selectedAccount != null
                                            ? AppStyles.getTextColor(ctx)
                                            : AppStyles
                                                .getSecondaryTextColor(ctx),
                                        fontSize: TypeScale.body,
                                      ),
                                    ),
                                  ),
                                  Icon(CupertinoIcons.chevron_down,
                                      size: 14,
                                      color:
                                          AppStyles.getSecondaryTextColor(ctx)),
                                ],
                              ),
                            ),
                          ),

                        const SizedBox(height: Spacing.md),

                        // Notes field
                        Text('Note',
                            style: TextStyle(
                              fontSize: TypeScale.footnote,
                              fontWeight: FontWeight.w600,
                              color: AppStyles.getSecondaryTextColor(ctx),
                            )),
                        const SizedBox(height: Spacing.xs),
                        CupertinoTextField(
                          controller: notesCtrl,
                          placeholder: 'Add a note...',
                          padding: const EdgeInsets.all(14),
                          style: TextStyle(
                              color: AppStyles.getTextColor(ctx),
                              fontSize: TypeScale.body),
                          decoration: BoxDecoration(
                            color: AppStyles.getBackground(ctx),
                            borderRadius: BorderRadius.circular(Radii.md),
                          ),
                        ),

                        const SizedBox(height: Spacing.xl),

                        // Confirm button
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
                                color: CupertinoColors.systemIndigo,
                                onPressed: accounts.isEmpty
                                    ? null
                                    : () async {
                                        final amt = double.tryParse(
                                            amountCtrl.text.trim());
                                        if (amt == null || amt <= 0) {
                                          toast.showError(
                                              'Enter a valid amount');
                                          return;
                                        }
                                        if (amt > balance) {
                                          toast.showError(
                                              'Amount exceeds wallet balance');
                                          return;
                                        }
                                        final dest = selectedAccount ??
                                            (accounts.isNotEmpty
                                                ? accounts.first
                                                : null);
                                        if (dest == null) {
                                          toast.showError(
                                              'Select a destination account');
                                          return;
                                        }

                                        // 1. Deduct from wallet
                                        await appsController.setWalletBalance(
                                          app['id'] as String,
                                          balance - amt,
                                        );

                                        // 2. Credit destination account
                                        final accountsController =
                                            context.read<AccountsController>();
                                        final updated = dest.copyWith(
                                            balance: dest.balance + amt);
                                        await accountsController
                                            .updateAccount(updated);

                                        // 3. Record transaction
                                        final txCtrl =
                                            context
                                                .read<TransactionsController>();
                                        final note = notesCtrl.text.trim();
                                        await txCtrl.addTransaction(
                                          Transaction(
                                            id: IdGenerator.next(),
                                            type: TransactionType.transfer,
                                            description: note.isNotEmpty
                                                ? note
                                                : 'Wallet transfer from ${app['name']}',
                                            dateTime: DateTime.now(),
                                            amount: amt,
                                            sourceAccountName:
                                                '${app['name']} Wallet',
                                            destinationAccountId: dest.id,
                                            destinationAccountName: dest.name,
                                            paymentAppName:
                                                app['name'] as String,
                                            appWalletAmount: amt,
                                          ),
                                        );

                                        if (ctx.mounted) Navigator.pop(ctx);
                                        toast.showSuccess(
                                            '₹${amt.toStringAsFixed(0)} transferred to ${dest.name}');
                                      },
                                child: const Text('Transfer',
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
            ),
          );
        });
      },
    ).whenComplete(() {
      amountCtrl.dispose();
      notesCtrl.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PaymentAppsController>(
      builder: (context, appsController, child) {
        final activeApps = appsController.paymentApps
            .where((app) => (app['isEnabled'] as bool? ?? false))
            .toList();

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
            trailing: _selectedTab == 2
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
                            ? CupertinoColors.systemGreen
                            : _selectedTab == 1
                                ? CupertinoColors.systemIndigo
                                : AppStyles.accentBlue,
                        children: {
                          0: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(CupertinoIcons.checkmark_circle_fill,
                                    size: 14,
                                    color: _selectedTab == 0
                                        ? Colors.white
                                        : AppStyles.getSecondaryTextColor(context)),
                                const SizedBox(width: 6),
                                Text('Active',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: _selectedTab == 0
                                          ? Colors.white
                                          : AppStyles.getTextColor(context),
                                    )),
                                if (activeApps.isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _selectedTab == 0
                                          ? Colors.white.withValues(alpha: 0.3)
                                          : CupertinoColors.systemGreen
                                              .withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${activeApps.length}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: _selectedTab == 0
                                            ? Colors.white
                                            : CupertinoColors.systemGreen,
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
                                Icon(CupertinoIcons.creditcard_fill,
                                    size: 14,
                                    color: _selectedTab == 1
                                        ? Colors.white
                                        : AppStyles.getSecondaryTextColor(context)),
                                const SizedBox(width: 6),
                                Text('Wallets',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: _selectedTab == 1
                                          ? Colors.white
                                          : AppStyles.getTextColor(context),
                                    )),
                                if (walletApps.isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _selectedTab == 1
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
                                        color: _selectedTab == 1
                                            ? Colors.white
                                            : CupertinoColors.systemIndigo,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          2: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                    CupertinoIcons.device_phone_portrait,
                                    size: 14,
                                    color: _selectedTab == 2
                                        ? Colors.white
                                        : AppStyles.getSecondaryTextColor(context)),
                                const SizedBox(width: 6),
                                Text('All Apps',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: _selectedTab == 2
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
                          ? _buildActiveAppsTab(activeApps, appsController)
                          : _selectedTab == 1
                              ? _buildWalletsTab(walletApps, appsController)
                              : _buildAllAppsTab(filteredApps, appsController),
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

  // ── Active Apps tab ───────────────────────────────────────────────────────────

  Widget _buildActiveAppsTab(
      List<Map<String, dynamic>> activeApps, PaymentAppsController ctrl) {
    if (activeApps.isEmpty) {
      return EmptyStateView(
        icon: CupertinoIcons.checkmark_circle_fill,
        title: 'No active apps',
        subtitle: 'Enable apps in the All Apps tab to see them here.',
        actionLabel: 'Go to All Apps',
        onAction: () => setState(() => _selectedTab = 2),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
      children: activeApps
          .map((app) => _buildActiveAppCard(app, ctrl))
          .toList(),
    );
  }

  Widget _buildActiveAppCard(
      Map<String, dynamic> app, PaymentAppsController ctrl) {
    final color = (app['color'] as Color?) ?? CupertinoColors.systemBlue;
    final hasWallet = (app['hasWallet'] as bool?) ?? false;
    final balance = (app['walletBalance'] as num?)?.toDouble() ?? 0.0;

    return GestureDetector(
      onTap: () => _showPaymentAppDetailsSheet(context, ctrl, app),
      child: Container(
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
                    Text(app['name'] as String, style: AppStyles.titleStyle(context)),
                    if (hasWallet)
                      Text(
                        'Wallet ₹${balance.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: TypeScale.footnote,
                          color: balance >= 0
                              ? CupertinoColors.systemGreen
                              : CupertinoColors.systemRed,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
              Icon(CupertinoIcons.chevron_right,
                  size: 16,
                  color: AppStyles.getSecondaryTextColor(context)),
            ],
          ),
        ),
      ),
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
        onAction: () => setState(() => _selectedTab = 2),
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
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Transfer button
                if (balance > 0)
                  BouncyButton(
                    onPressed: () =>
                        _showWalletTransferSheet(context, ctrl, app),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemIndigo
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: CupertinoColors.systemIndigo
                                .withValues(alpha: 0.3),
                            width: 1),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                              CupertinoIcons
                                  .arrow_right_arrow_left_circle_fill,
                              size: 14,
                              color: CupertinoColors.systemIndigo),
                          SizedBox(width: 4),
                          Text('Transfer',
                              style: TextStyle(
                                  color: CupertinoColors.systemIndigo,
                                  fontSize: TypeScale.footnote,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                if (balance > 0) const SizedBox(width: 8),
                // Edit button
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

  void _showPaymentAppDetailsSheet(
    BuildContext context,
    PaymentAppsController appsController,
    Map<String, dynamic> app,
  ) {
    showCupertinoModalPopup(
      context: context,
      builder: (sheetContext) {
        return Consumer<TransactionsController>(
          builder: (ctx, txCtrl, _) {
            final appName = app['name'] as String;
            final appTxs = txCtrl.transactions
                .where((tx) => tx.paymentAppName == appName)
                .toList()
              ..sort((a, b) => b.dateTime.compareTo(a.dateTime));

            final color = (app['color'] as Color?) ?? CupertinoColors.systemBlue;
            final hasWallet = (app['hasWallet'] as bool?) ?? false;
            final balance = (app['walletBalance'] as num?)?.toDouble() ?? 0.0;
            final isEnabled = (app['isEnabled'] as bool?) ?? false;

            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.75,
              minChildSize: 0.4,
              maxChildSize: 0.95,
              builder: (dragCtx, scrollController) {
                return Container(
                  decoration: BoxDecoration(
                    color: AppStyles.getCardColor(ctx),
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Column(
                    children: [
                      // Handle
                      Padding(
                        padding: const EdgeInsets.only(top: 12, bottom: 4),
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppStyles.getSecondaryTextColor(ctx)
                                .withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Expanded(
                        child: ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                          children: [
                            // ── App header ────────────────────────────────
                            Row(
                              children: [
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: AppStyles.iconBoxDecoration(ctx, color),
                                  child: Center(
                                    child: Icon(CupertinoIcons.square_fill,
                                        color: color, size: 28),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(appName,
                                          style: TextStyle(
                                            fontSize: TypeScale.title2,
                                            fontWeight: FontWeight.w700,
                                            color: AppStyles.getTextColor(ctx),
                                          )),
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: isEnabled
                                              ? CupertinoColors.systemGreen
                                                  .withValues(alpha: 0.12)
                                              : CupertinoColors.systemGrey
                                                  .withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          isEnabled ? 'Active' : 'Inactive',
                                          style: TextStyle(
                                            fontSize: TypeScale.caption,
                                            fontWeight: FontWeight.w600,
                                            color: isEnabled
                                                ? CupertinoColors.systemGreen
                                                : CupertinoColors.systemGrey,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 24),

                            // ── Wallet section ────────────────────────────
                            if (hasWallet) ...[
                              Container(
                                padding: const EdgeInsets.all(Spacing.lg),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                      color: color.withValues(alpha: 0.2)),
                                ),
                                child: Row(
                                  children: [
                                    Icon(CupertinoIcons.creditcard_fill,
                                        color: color, size: 20),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text('Wallet Balance',
                                              style: TextStyle(
                                                fontSize: TypeScale.footnote,
                                                color: AppStyles
                                                    .getSecondaryTextColor(ctx),
                                              )),
                                          const SizedBox(height: 2),
                                          Text(
                                            '₹${balance.toStringAsFixed(2)}',
                                            style: TextStyle(
                                              fontSize: TypeScale.title2,
                                              fontWeight: FontWeight.w700,
                                              color: balance >= 0
                                                  ? CupertinoColors.systemGreen
                                                  : CupertinoColors.systemRed,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    BouncyButton(
                                      onPressed: () {
                                        Navigator.pop(sheetContext);
                                        _showSetWalletBalanceModal(
                                            context, appsController, app);
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 14, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: color.withValues(alpha: 0.15),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          border: Border.all(
                                              color:
                                                  color.withValues(alpha: 0.35),
                                              width: 1),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(CupertinoIcons.pencil,
                                                size: 14, color: color),
                                            const SizedBox(width: 4),
                                            Text('Edit',
                                                style: TextStyle(
                                                    color: color,
                                                    fontSize: TypeScale.footnote,
                                                    fontWeight:
                                                        FontWeight.w600)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Transfer to Account button
                              if (balance > 0) ...[
                                const SizedBox(height: 8),
                                BouncyButton(
                                  onPressed: () {
                                    Navigator.pop(sheetContext);
                                    _showWalletTransferSheet(
                                        context, appsController, app);
                                  },
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    decoration: BoxDecoration(
                                      color: CupertinoColors.systemIndigo
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                          color: CupertinoColors.systemIndigo
                                              .withValues(alpha: 0.35)),
                                    ),
                                    child: const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                            CupertinoIcons
                                                .arrow_right_arrow_left_circle_fill,
                                            size: 15,
                                            color:
                                                CupertinoColors.systemIndigo),
                                        SizedBox(width: 8),
                                        Text('Transfer to Account',
                                            style: TextStyle(
                                              color:
                                                  CupertinoColors.systemIndigo,
                                              fontWeight: FontWeight.w600,
                                              fontSize: TypeScale.footnote,
                                            )),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 16),
                            ],

                            // ── Toggle + Wallet actions ───────────────────
                            Container(
                              padding: const EdgeInsets.all(Spacing.md),
                              decoration: AppStyles.cardDecoration(ctx),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Icon(CupertinoIcons.checkmark_circle,
                                          size: 18,
                                          color: AppStyles.getSecondaryTextColor(ctx)),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text('Active',
                                            style: TextStyle(
                                              fontSize: TypeScale.body,
                                              color: AppStyles.getTextColor(ctx),
                                            )),
                                      ),
                                      StatefulBuilder(
                                        builder: (_, setSwitchState) =>
                                            CupertinoSwitch(
                                          value: isEnabled,
                                          activeTrackColor:
                                              CupertinoColors.systemGreen,
                                          onChanged: (v) async {
                                            await appsController.toggleApp(
                                                app['id'] as String, v);
                                            Navigator.pop(sheetContext);
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 1),
                                  if (!hasWallet)
                                    CupertinoButton(
                                      padding: EdgeInsets.zero,
                                      onPressed: () {
                                        Navigator.pop(sheetContext);
                                        _showEnableWalletModal(
                                            context, appsController, app);
                                      },
                                      child: Row(
                                        children: [
                                          const Icon(CupertinoIcons.creditcard,
                                              size: 18,
                                              color: CupertinoColors.systemBlue),
                                          const SizedBox(width: 12),
                                          const Text('Enable Wallet',
                                              style: TextStyle(
                                                  color:
                                                      CupertinoColors.systemBlue)),
                                        ],
                                      ),
                                    )
                                  else
                                    CupertinoButton(
                                      padding: EdgeInsets.zero,
                                      onPressed: () {
                                        appsController.setWalletSupport(
                                            app['id'] as String, false);
                                        Navigator.pop(sheetContext);
                                      },
                                      child: Row(
                                        children: [
                                          const Icon(CupertinoIcons.creditcard_fill,
                                              size: 18,
                                              color: CupertinoColors.systemOrange),
                                          const SizedBox(width: 12),
                                          const Text('Disable Wallet',
                                              style: TextStyle(
                                                  color: CupertinoColors
                                                      .systemOrange)),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 20),

                            // ── Transaction History ───────────────────────
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Transactions',
                                    style: TextStyle(
                                      fontSize: TypeScale.headline,
                                      fontWeight: FontWeight.w700,
                                      color: AppStyles.getTextColor(ctx),
                                    )),
                                if (appTxs.isNotEmpty)
                                  CupertinoButton(
                                    padding: EdgeInsets.zero,
                                    onPressed: () {
                                      Navigator.pop(sheetContext);
                                      Navigator.push(
                                        context,
                                        CupertinoPageRoute(
                                          builder: (_) =>
                                              TransactionHistoryScreen(
                                            filterPaymentAppName: appName,
                                          ),
                                        ),
                                      );
                                    },
                                    child: const Text('View All',
                                        style: TextStyle(
                                            fontSize: TypeScale.footnote,
                                            color: CupertinoColors.systemBlue)),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (appTxs.isEmpty)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 24),
                                child: Center(
                                  child: Text(
                                    'No transactions found for $appName',
                                    style: TextStyle(
                                      color: AppStyles.getSecondaryTextColor(ctx),
                                      fontSize: TypeScale.footnote,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              )
                            else
                              ...appTxs.take(5).map((tx) {
                                final isDebit =
                                    tx.type == TransactionType.expense ||
                                        tx.type == TransactionType.investment ||
                                        tx.type == TransactionType.lending;
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(Spacing.md),
                                  decoration: AppStyles.cardDecoration(ctx),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: (isDebit
                                                  ? CupertinoColors.systemRed
                                                  : CupertinoColors.systemGreen)
                                              .withValues(alpha: 0.15),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Icon(
                                          isDebit
                                              ? CupertinoIcons.arrow_up
                                              : CupertinoIcons.arrow_down,
                                          size: 16,
                                          color: isDebit
                                              ? CupertinoColors.systemRed
                                              : CupertinoColors.systemGreen,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              tx.description,
                                              style: TextStyle(
                                                fontSize: TypeScale.footnote,
                                                fontWeight: FontWeight.w600,
                                                color: AppStyles.getTextColor(ctx),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Text(
                                              '${tx.dateTime.day}/${tx.dateTime.month}/${tx.dateTime.year}',
                                              style: TextStyle(
                                                fontSize: TypeScale.caption,
                                                color: AppStyles
                                                    .getSecondaryTextColor(ctx),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        '${isDebit ? '−' : '+'}₹${tx.amount.abs().toStringAsFixed(0)}',
                                        style: TextStyle(
                                          fontSize: TypeScale.footnote,
                                          fontWeight: FontWeight.bold,
                                          color: isDebit
                                              ? CupertinoColors.systemRed
                                              : CupertinoColors.systemGreen,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),

                            const SizedBox(height: 24),

                            // ── Delete button ─────────────────────────────
                            BouncyButton(
                              onPressed: () {
                                showCupertinoDialog(
                                  context: ctx,
                                  builder: (_) => CupertinoAlertDialog(
                                    title: const Text('Delete App'),
                                    content: Text(
                                        'Remove $appName from your list?'),
                                    actions: [
                                      CupertinoDialogAction(
                                        onPressed: () => Navigator.pop(ctx),
                                        child: const Text('Cancel'),
                                      ),
                                      CupertinoDialogAction(
                                        isDestructiveAction: true,
                                        onPressed: () {
                                          appsController
                                              .deleteApp(app['id'] as String);
                                          Navigator.pop(ctx);
                                          Navigator.pop(sheetContext);
                                        },
                                        child: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              child: Container(
                                width: double.infinity,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                decoration: BoxDecoration(
                                  color: CupertinoColors.systemRed
                                      .withValues(alpha: 0.1),
                                  borderRadius:
                                      BorderRadius.circular(Radii.md),
                                  border: Border.all(
                                      color: CupertinoColors.systemRed
                                          .withValues(alpha: 0.3)),
                                ),
                                child: const Center(
                                  child: Text('Delete App',
                                      style: TextStyle(
                                          color: CupertinoColors.systemRed,
                                          fontWeight: FontWeight.w600)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
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
