import 'dart:async';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/account_model.dart';
import 'package:vittara_fin_os/logic/accounts_controller.dart';
import 'package:vittara_fin_os/logic/settings_controller.dart';
import 'package:vittara_fin_os/ui/manage/account_wizard.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/widgets/animations.dart';
import 'package:vittara_fin_os/utils/logger.dart';

class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  final AppLogger logger = AppLogger();

  void _showAddOptions(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) {
        final settings = Provider.of<SettingsController>(context, listen: false);
        final showInvestment = settings.isInvestmentTrackingEnabled;

        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            decoration: BoxDecoration(
              color: AppStyles.getCardColor(context),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.all(24),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemGrey3,
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Add New Account',
                    style: AppStyles.titleStyle(context).copyWith(fontSize: 22),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Select the type of account you want to add',
                    style: TextStyle(
                      color: AppStyles.getSecondaryTextColor(context),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: _buildOptionCard(
                          context,
                          title: 'Bank\nAccount',
                          icon: CupertinoIcons.building_2_fill,
                          color: CupertinoColors.systemBlue,
                          onTap: () {
                            Navigator.pop(context);
                            _startWizard(isInvestment: false);
                          },
                        ),
                      ),
                      if (showInvestment) ...[
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildOptionCard(
                            context,
                            title: 'Investment\nAccount',
                            icon: CupertinoIcons.graph_square_fill,
                            color: CupertinoColors.systemPurple,
                            onTap: () {
                              Navigator.pop(context);
                              _startWizard(isInvestment: true);
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildOptionCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return BouncyButton(
      onPressed: onTap,
      child: Container(
        height: 160,
        decoration: AppStyles.cardDecoration(context).copyWith(
          border: Border.all(
            color: color.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: color),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppStyles.titleStyle(context).copyWith(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startWizard({required bool isInvestment}) async {
    final Account? result = await Navigator.push<Account>(
      context,
      FadeScalePageRoute(page: AccountWizard(isInvestment: isInvestment)),
    );

    if (result != null) {
      final accountsController = Provider.of<AccountsController>(context, listen: false);
      await accountsController.addAccount(result);
      logger.info('Added account: ${result.name}', context: 'AccountsScreen');
    }
  }

  void _onReorder(int oldIndex, int newIndex) {
    final accountsController = Provider.of<AccountsController>(context, listen: false);
    accountsController.reorderAccounts(oldIndex, newIndex);
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppStyles.getBackground(context),
      navigationBar: CupertinoNavigationBar(
        middle: Text('Accounts', style: TextStyle(color: AppStyles.getTextColor(context))),
        previousPageTitle: 'Manage',
        backgroundColor: AppStyles.getBackground(context),
        border: null,
      ),
      child: Consumer<AccountsController>(
        builder: (context, accountsController, child) {
          final accounts = accountsController.accounts;
          return Stack(
            children: [
              if (accounts.isEmpty)
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        CupertinoIcons.creditcard,
                        size: 64,
                        color: AppStyles.getSecondaryTextColor(context).withValues(alpha: 0.3),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No Accounts Added',
                        style: TextStyle(
                          color: AppStyles.getSecondaryTextColor(context),
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
              else
                SafeArea(
                  child: ReorderableListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    itemCount: accounts.length,
                    onReorder: _onReorder,
                    itemBuilder: (context, index) {
                      return _buildAccountCard(accounts[index]);
                    },
                  ),
                ),
              Positioned(
                right: 16,
                bottom: 32,
                child: FadingFloatingActionButton(
                  onPressed: () => _showAddOptions(context),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAccountCard(Account account) {
    return BouncyButton(
      onPressed: () => _showAccountDetailsSheet(account),
      child: Container(
        key: ValueKey(account.id),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: AppStyles.cardDecoration(context),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: AppStyles.iconBoxDecoration(context, account.color),
                child: Center(
                  child: Icon(
                    account.type == AccountType.investment
                        ? CupertinoIcons.chart_bar_square_fill
                        : CupertinoIcons.building_2_fill,
                    color: account.color,
                    size: 26,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(account.name, style: AppStyles.titleStyle(context)),
                    const SizedBox(height: 4),
                    Text(
                      '${account.bankName} • ${account.type.name.toUpperCase()}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppStyles.getSecondaryTextColor(context),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${account.balance.toStringAsFixed(2)}',
                    style: AppStyles.titleStyle(context).copyWith(
                      color: AppStyles.accentBlue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Icon(
                    CupertinoIcons.chevron_up,
                    size: 14,
                    color: AppStyles.getSecondaryTextColor(context),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAccountDetailsSheet(Account account) {
    showCupertinoModalPopup(
      context: context,
      builder: (modalContext) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          builder: (dragContext, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: AppStyles.getCardColor(dragContext),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                controller: scrollController,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle bar
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemGrey3,
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Account Details
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            account.name,
                            style: AppStyles.titleStyle(dragContext).copyWith(fontSize: 20),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${account.bankName} • ${account.type.name.toUpperCase()}',
                            style: TextStyle(
                              color: AppStyles.getSecondaryTextColor(dragContext),
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Balance display
                          Text(
                            'Balance',
                            style: TextStyle(
                              color: AppStyles.getSecondaryTextColor(dragContext),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '₹${account.balance.toStringAsFixed(2)}',
                            style: AppStyles.titleStyle(dragContext).copyWith(
                              fontSize: 28,
                              color: AppStyles.accentBlue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          // Credit Card/Pay Later - Show Credit Limit and Amount Used
                          if (account.type == AccountType.credit ||
                              account.type == AccountType.payLater) ...[
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Credit Limit',
                                        style: TextStyle(
                                          color: AppStyles.getSecondaryTextColor(dragContext),
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '₹${account.balance.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          color: AppStyles.getTextColor(dragContext),
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Amount Used',
                                        style: TextStyle(
                                          color: AppStyles.getSecondaryTextColor(dragContext),
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '₹0.00',
                                        style: TextStyle(
                                          color: AppStyles.getTextColor(dragContext),
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],

                          const SizedBox(height: 32),
                        ],
                      ),
                    ),

                    // Action Buttons
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        children: [
                          Expanded(
                            child: BouncyButton(
                              onPressed: () {
                                Navigator.pop(modalContext);
                                _editAccount(account);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: CupertinoColors.systemBlue.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      CupertinoIcons.pencil,
                                      size: 16,
                                      color: CupertinoColors.systemBlue,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Edit',
                                      style: TextStyle(
                                        color: CupertinoColors.systemBlue,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: BouncyButton(
                              onPressed: () {
                                Navigator.pop(modalContext);
                                _deleteAccount(account);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: CupertinoColors.systemRed.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      CupertinoIcons.trash,
                                      size: 16,
                                      color: CupertinoColors.systemRed,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Delete',
                                      style: TextStyle(
                                        color: CupertinoColors.systemRed,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _editAccount(Account account) {
    logger.info('Edit account: ${account.name}', context: 'AccountsScreen');
    // For now, show a simple dialog. In future, can open account edit screen
    showCupertinoDialog(
      context: context,
      builder: (context) {
        return CupertinoAlertDialog(
          title: const Text('Edit Account'),
          content: Text('Edit functionality for "${account.name}" coming soon!'),
          actions: [
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        );
      },
    );
  }

  void _deleteAccount(Account account) {
    showCupertinoDialog(
      context: context,
      builder: (context) {
        return CupertinoAlertDialog(
          title: const Text('Delete Account'),
          content: Text('Are you sure you want to delete "${account.name}"? This action cannot be undone.'),
          actions: [
            CupertinoDialogAction(
              child: const Text('Cancel'),
              onPressed: () => Navigator.pop(context),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              child: const Text('Delete'),
              onPressed: () {
                final accountsController = Provider.of<AccountsController>(context, listen: false);
                accountsController.removeAccount(account.id);
                Navigator.pop(context);
                logger.info('Deleted account: ${account.name}', context: 'AccountsScreen');
              },
            ),
          ],
        );
      },
    );
  }
}

class FadingFloatingActionButton extends StatefulWidget {
  final VoidCallback onPressed;
  const FadingFloatingActionButton({super.key, required this.onPressed});
  @override
  State<FadingFloatingActionButton> createState() => _FadingFloatingActionButtonState();
}

class _FadingFloatingActionButtonState extends State<FadingFloatingActionButton> with SingleTickerProviderStateMixin {
  Timer? _timer;
  late AnimationController _controller;
  late Animation<double> _animation;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _animation = Tween<double>(begin: 1.0, end: 0.3).animate(_controller);
    _startInactivityTimer();
  }
  
  void _startInactivityTimer() {
    _timer?.cancel();
    if (_controller.value > 0) _controller.reverse();
    _timer = Timer(const Duration(seconds: 4), () { if (mounted) _controller.forward(); });
  }
  
  @override
  void dispose() { _timer?.cancel(); _controller.dispose(); super.dispose(); }
  
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value,
          child: GestureDetector(
            onTapDown: (_) => _startInactivityTimer(),
            onTap: () { _startInactivityTimer(); widget.onPressed(); },
            child: Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: CupertinoColors.systemBlue,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: CupertinoColors.systemBlue.withValues(alpha: 0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 4)
                  )
                ],
              ),
              child: const Icon(CupertinoIcons.add, color: Colors.white, size: 28),
            ),
          ),
        );
      },
    );
  }
}