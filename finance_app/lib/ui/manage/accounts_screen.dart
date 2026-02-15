import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/account_model.dart';
import 'package:vittara_fin_os/logic/accounts_controller.dart';
import 'package:vittara_fin_os/logic/transaction_model.dart';
import 'package:vittara_fin_os/logic/transactions_controller.dart';
import 'package:vittara_fin_os/logic/settings_controller.dart';
import 'package:vittara_fin_os/ui/manage/account_wizard.dart';
import 'package:vittara_fin_os/ui/manage/transfer_wizard.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/widgets/animations.dart';
import 'package:vittara_fin_os/ui/widgets/common_widgets.dart';
import 'package:vittara_fin_os/ui/widgets/toast_notification.dart';
import 'package:vittara_fin_os/utils/logger.dart';

class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  final AppLogger logger = AppLogger();
  bool _isSummaryExpanded = true;

  void _showAddOptions(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) {
        final settings =
            Provider.of<SettingsController>(context, listen: false);
        final showInvestment = settings.isInvestmentTrackingEnabled;

        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            decoration: BoxDecoration(
              color: AppStyles.getCardColor(context),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
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

    if (!mounted) return;

    if (result != null) {
      final accountsController =
          Provider.of<AccountsController>(context, listen: false);
      await accountsController.addAccount(result);
      logger.info('Added account: ${result.name}', context: 'AccountsScreen');
    }
  }

  double _getTotalBalance(List<Account> accounts) {
    // Exclude investment/demat accounts from total balance
    return accounts
        .where((account) => account.type != AccountType.investment)
        .fold(0.0, (sum, account) => sum + account.balance);
  }

  int _getDistinctTypesCount(List<Account> accounts) {
    return accounts.map((acc) => acc.type).toSet().length;
  }

  List<Account> _getAccountsByType(List<Account> accounts, AccountType type) {
    return accounts.where((account) => account.type == type).toList();
  }

  double _getTotalByType(List<Account> accounts, AccountType type) {
    return _getAccountsByType(accounts, type)
        .fold(0.0, (sum, account) => sum + account.balance);
  }

  double _getTotalCreditLimit(List<Account> accounts, AccountType type) {
    return _getAccountsByType(accounts, type)
        .fold(0.0, (sum, account) => sum + (account.creditLimit ?? 0.0));
  }

  double _getTotalCreditUsed(List<Account> accounts, AccountType type) {
    // Used = Credit Limit - Balance (where balance is available credit)
    return _getAccountsByType(accounts, type).fold(
        0.0,
        (sum, account) =>
            sum + ((account.creditLimit ?? 0.0) - account.balance));
  }

  double _getTotalCreditRemaining(List<Account> accounts, AccountType type) {
    // Remaining = Balance (which is the available credit)
    return _getAccountsByType(accounts, type)
        .fold(0.0, (sum, account) => sum + account.balance);
  }

  bool _hasAccountType(List<Account> accounts, AccountType type) {
    return accounts.any((account) => account.type == type);
  }

  String _getAccountTypeLabel(AccountType type) {
    switch (type) {
      case AccountType.savings:
        return 'Savings';
      case AccountType.current:
        return 'Current';
      case AccountType.credit:
        return 'Credit Cards';
      case AccountType.payLater:
        return 'BNPL/Wallet';
      case AccountType.wallet:
        return 'Digital Wallets';
      case AccountType.investment:
        return 'Brokers';
    }
  }

  Color _getAccountTypeColor(AccountType type) {
    switch (type) {
      case AccountType.savings:
        return const Color(0xFF007AFF);
      case AccountType.current:
        return const Color(0xFF34C759);
      case AccountType.credit:
        return const Color(0xFFFF3B30);
      case AccountType.payLater:
        return const Color(0xFFFF9500);
      case AccountType.wallet:
        return const Color(0xFF5AC8FA);
      case AccountType.investment:
        return const Color(0xFFAF52DE);
    }
  }

  Widget _buildAccountTypeSummaryCards(
      BuildContext context, List<Account> accounts) {
    // Account Summary section removed
    return SizedBox.shrink();
  }

  List<AccountType> _orderedAccountTypes(List<Account> accounts) {
    const order = <AccountType>[
      AccountType.savings,
      AccountType.current,
      AccountType.credit,
      AccountType.payLater,
      AccountType.wallet,
      AccountType.investment,
    ];
    final presentTypes =
        order.where((type) => _hasAccountType(accounts, type)).toList();
    presentTypes.sort(
      (a, b) =>
          _getTotalByType(accounts, b).compareTo(_getTotalByType(accounts, a)),
    );
    return presentTypes;
  }

  Widget _buildGroupedAccountsList(List<Account> accounts) {
    final types = _orderedAccountTypes(accounts);
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(Spacing.lg, 0, Spacing.lg, 110),
      itemCount: types.length,
      itemBuilder: (context, sectionIndex) {
        final type = types[sectionIndex];
        final sectionAccounts = _getAccountsByType(accounts, type)
          ..sort((a, b) => b.balance.compareTo(a.balance));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: EdgeInsets.only(
                  bottom: Spacing.md, top: sectionIndex == 0 ? 0 : Spacing.md),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: _getAccountTypeColor(type).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _getAccountTypeColor(type).withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _getAccountTypeColor(type),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _getAccountTypeLabel(type),
                      style:
                          AppStyles.titleStyle(context).copyWith(fontSize: 14),
                    ),
                  ),
                  Text(
                    '${sectionAccounts.length}',
                    style: TextStyle(
                      color: AppStyles.getSecondaryTextColor(context),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            ...sectionAccounts.asMap().entries.map((entry) {
              final index = entry.key;
              final account = entry.value;
              return StaggeredItem(
                key: ValueKey(account.id),
                index: sectionIndex * 100 + index,
                child: _buildSlidableAccountCard(account),
              );
            }),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppStyles.getBackground(context),
      navigationBar: CupertinoNavigationBar(
        middle: Text('Accounts',
            style: TextStyle(color: AppStyles.getTextColor(context))),
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
                EmptyStateView(
                  icon: CupertinoIcons.creditcard,
                  title: 'No Accounts Added',
                  subtitle: 'Add your bank accounts, credit cards, and more',
                  actionLabel: 'Add Account',
                  onAction: () => _showAddOptions(context),
                )
              else
                SafeArea(
                  child: Column(
                    children: [
                      // Account Type-wise Summary Cards
                      Padding(
                        padding: EdgeInsets.only(top: Spacing.lg),
                        child: _buildAccountTypeSummaryCards(context, accounts),
                      ),
                      SizedBox(height: Spacing.lg),
                      // Accounts grouped by type
                      Expanded(
                        child: _buildGroupedAccountsList(accounts),
                      ),
                    ],
                  ),
                ),
              Positioned(
                right: Spacing.lg,
                bottom: Spacing.xxxl + 70,
                child: BouncyButton(
                  onPressed: () {
                    Haptics.light();
                    Navigator.push(
                      context,
                      FadeScalePageRoute(page: const TransferWizard()),
                    );
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: Spacing.lg,
                      vertical: Spacing.md,
                    ),
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemGreen,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: CupertinoColors.systemGreen
                              .withValues(alpha: 0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          CupertinoIcons.arrow_right_arrow_left,
                          color: Colors.white,
                          size: 20,
                        ),
                        SizedBox(width: Spacing.sm),
                        const Text(
                          'Transfer',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                right: Spacing.lg,
                bottom: Spacing.xxxl,
                child: FadingFAB(
                  onPressed: () => _showAddOptions(context),
                  heroTag: 'accounts_fab',
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSlidableAccountCard(Account account) {
    return Slidable(
      endActionPane: ActionPane(
        motion: const BehindMotion(),
        extentRatio: 0.5,
        children: [
          SlidableAction(
            onPressed: (_) {
              HapticFeedback.lightImpact();
              _editAccount(account);
            },
            backgroundColor: CupertinoColors.systemBlue,
            foregroundColor: Colors.white,
            icon: CupertinoIcons.pencil,
            label: 'Edit',
            borderRadius:
                const BorderRadius.horizontal(left: Radius.circular(12)),
          ),
          SlidableAction(
            onPressed: (_) {
              HapticFeedback.heavyImpact();
              _deleteAccount(account);
            },
            backgroundColor: CupertinoColors.destructiveRed,
            foregroundColor: Colors.white,
            icon: CupertinoIcons.trash,
            label: 'Delete',
            borderRadius:
                const BorderRadius.horizontal(right: Radius.circular(12)),
          ),
        ],
      ),
      child: _buildAccountCard(account),
    );
  }

  Widget _buildAccountCard(Account account) {
    return Hero(
      tag: 'account_${account.id}',
      child: BouncyButton(
        onPressed: () => _showAccountDetailsSheet(account),
        child: Container(
          margin: EdgeInsets.only(bottom: Spacing.lg),
          decoration: AppStyles.cardDecoration(context),
          child: Padding(
            padding: Spacing.cardPadding,
            child: Row(
              children: [
                IconBox(
                  icon: account.type == AccountType.investment
                      ? CupertinoIcons.chart_bar_square_fill
                      : CupertinoIcons.building_2_fill,
                  color: account.color,
                  showGlow: true,
                ),
                SizedBox(width: Spacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(account.name, style: AppStyles.titleStyle(context)),
                      SizedBox(height: Spacing.xs),
                      Text(
                        '${account.bankName} • ${account.type.name.toUpperCase()}',
                        style: TextStyle(
                          fontSize: TypeScale.footnote,
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
                    AnimatedCounter(
                      value: account.balance,
                      prefix: '₹',
                      decimals: 2,
                      duration: AppDurations.counter,
                      style: AppStyles.titleStyle(context).copyWith(
                        color: SemanticColors.getPrimary(context),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: Spacing.xs),
                    Icon(
                      CupertinoIcons.chevron_up,
                      size: IconSizes.xs,
                      color: AppStyles.getSecondaryTextColor(context),
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
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
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
                            style: AppStyles.titleStyle(dragContext)
                                .copyWith(fontSize: 20),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${account.bankName} • ${account.type.name.toUpperCase()}',
                            style: TextStyle(
                              color:
                                  AppStyles.getSecondaryTextColor(dragContext),
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Balance display
                          Text(
                            'Balance',
                            style: TextStyle(
                              color:
                                  AppStyles.getSecondaryTextColor(dragContext),
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

                          // Credit Card Number (if exists)
                          if (account.creditCardNumber != null &&
                              account.creditCardNumber!.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Text(
                              'Card Number',
                              style: TextStyle(
                                color: AppStyles.getSecondaryTextColor(
                                    dragContext),
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              account.creditCardNumber!,
                              style: TextStyle(
                                color: AppStyles.getTextColor(dragContext),
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 2,
                              ),
                            ),
                          ],

                          // Credit Card/Pay Later - Show Credit Limit and Amount Used
                          if (account.type == AccountType.credit ||
                              account.type == AccountType.payLater) ...[
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Credit Limit',
                                        style: TextStyle(
                                          color:
                                              AppStyles.getSecondaryTextColor(
                                                  dragContext),
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '₹${(account.creditLimit ?? 0.0).toStringAsFixed(2)}',
                                        style: TextStyle(
                                          color: AppStyles.getTextColor(
                                              dragContext),
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Amount Used',
                                        style: TextStyle(
                                          color:
                                              AppStyles.getSecondaryTextColor(
                                                  dragContext),
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '₹${((account.creditLimit ?? 0.0) - account.balance).toStringAsFixed(2)}',
                                        style: TextStyle(
                                          color: CupertinoColors.systemRed,
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
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: BouncyButton(
                                  onPressed: () {
                                    Navigator.pop(modalContext);
                                    _showAdjustBalanceModal(context, account);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    decoration: BoxDecoration(
                                      color: CupertinoColors.systemGreen
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          CupertinoIcons.arrow_up_down_circle,
                                          size: 16,
                                          color: CupertinoColors.systemGreen,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Adjust Balance',
                                          style: TextStyle(
                                            color: CupertinoColors.systemGreen,
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
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: BouncyButton(
                                  onPressed: () {
                                    Navigator.pop(modalContext);
                                    _editAccount(account);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    decoration: BoxDecoration(
                                      color: CupertinoColors.systemBlue
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
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
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    decoration: BoxDecoration(
                                      color: CupertinoColors.systemRed
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
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

  void _showAdjustBalanceModal(BuildContext context, Account account) {
    final amountController = TextEditingController();
    bool isAdding = true;

    showCupertinoModalPopup(
      context: context,
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: BoxDecoration(
                color: AppStyles.getCardColor(context),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: 24,
                    right: 24,
                    top: 24,
                    bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
                  ),
                  child: SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const ModalHandle(),
                        SizedBox(height: Spacing.lg),
                        Text(
                          'Adjust Balance',
                          style: AppStyles.titleStyle(context)
                              .copyWith(fontSize: 22),
                        ),
                        SizedBox(height: Spacing.sm),
                        Text(
                          account.type == AccountType.credit ||
                                  account.type == AccountType.payLater
                              ? 'Add = Pay Card | Subtract = Spend'
                              : 'Adjust your account balance',
                          style: TextStyle(
                            color: AppStyles.getSecondaryTextColor(context),
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: Spacing.xxxl),

                        // Add/Subtract Toggle
                        Container(
                          decoration: BoxDecoration(
                            color: AppStyles.getSecondaryTextColor(context)
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.all(4),
                          child: Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    Haptics.light();
                                    setModalState(() => isAdding = true);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10),
                                    decoration: BoxDecoration(
                                      color: isAdding
                                          ? CupertinoColors.systemGreen
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          CupertinoIcons.add_circled_solid,
                                          size: 18,
                                          color: isAdding
                                              ? Colors.white
                                              : AppStyles.getSecondaryTextColor(
                                                  context),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Add',
                                          style: TextStyle(
                                            color: isAdding
                                                ? Colors.white
                                                : AppStyles
                                                    .getSecondaryTextColor(
                                                        context),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    Haptics.light();
                                    setModalState(() => isAdding = false);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10),
                                    decoration: BoxDecoration(
                                      color: !isAdding
                                          ? CupertinoColors.systemRed
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          CupertinoIcons.minus_circle_fill,
                                          size: 18,
                                          color: !isAdding
                                              ? Colors.white
                                              : AppStyles.getSecondaryTextColor(
                                                  context),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Subtract',
                                          style: TextStyle(
                                            color: !isAdding
                                                ? Colors.white
                                                : AppStyles
                                                    .getSecondaryTextColor(
                                                        context),
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
                        SizedBox(height: Spacing.xxxl),

                        // Amount Input
                        Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('₹',
                                  style: AppStyles.titleStyle(context)
                                      .copyWith(fontSize: 32)),
                              const SizedBox(width: 8),
                              IntrinsicWidth(
                                child: CupertinoTextField(
                                  controller: amountController,
                                  placeholder: '0.00',
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  autofocus: true,
                                  decoration: BoxDecoration(
                                    color: AppStyles.getCardColor(context),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  style: AppStyles.titleStyle(context).copyWith(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: Spacing.huge),

                        // Confirm Button
                        BouncyButton(
                          onPressed: () {
                            final amount =
                                double.tryParse(amountController.text);
                            if (amount != null && amount > 0) {
                              final newBalance = isAdding
                                  ? account.balance + amount
                                  : account.balance - amount;
                              final updatedAccount =
                                  account.copyWith(balance: newBalance);
                              final accountsController =
                                  Provider.of<AccountsController>(context,
                                      listen: false);
                              final oldBalance = account.balance;

                              accountsController.updateAccount(updatedAccount);

                              // Create transaction record
                              final transactionsController =
                                  Provider.of<TransactionsController>(context,
                                      listen: false);
                              final transaction = Transaction(
                                id: DateTime.now()
                                    .millisecondsSinceEpoch
                                    .toString(),
                                type: TransactionType.transfer,
                                description:
                                    '${isAdding ? "Added" : "Deducted"} ₹${amount.toStringAsFixed(2)}',
                                dateTime: DateTime.now(),
                                amount: amount,
                                sourceAccountId: account.id,
                                sourceAccountName: account.name,
                                destinationAccountId: account.id,
                                destinationAccountName: account.name,
                                metadata: {
                                  'type': 'balance_adjustment',
                                  'adjustment_type':
                                      isAdding ? 'credit' : 'debit',
                                },
                              );
                              transactionsController
                                  .addTransaction(transaction);

                              Navigator.pop(modalContext);

                              Haptics.success();
                              toast.showSuccess(
                                '${isAdding ? "Added" : "Subtracted"} ₹${amount.toStringAsFixed(2)}',
                                actionLabel: 'Undo',
                                onAction: () {
                                  final revertedAccount =
                                      account.copyWith(balance: oldBalance);
                                  accountsController
                                      .updateAccount(revertedAccount);
                                  transactionsController
                                      .removeTransaction(transaction.id);
                                  toast.showInfo('Adjustment undone');
                                },
                              );
                            }
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              color: CupertinoColors.systemBlue,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Center(
                              child: Text(
                                'Confirm',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _editAccount(Account account) async {
    logger.info('Edit account: ${account.name}', context: 'AccountsScreen');

    final Account? result = await Navigator.push<Account>(
      context,
      FadeScalePageRoute(
        page: AccountWizard(
          isInvestment: account.type == AccountType.investment,
          existingAccount: account,
        ),
      ),
    );

    if (!mounted) return;

    if (result != null) {
      final accountsController =
          Provider.of<AccountsController>(context, listen: false);
      await accountsController.updateAccount(result);
      logger.info('Updated account: ${result.name}', context: 'AccountsScreen');

      Haptics.success();
      toast.showSuccess('Account updated successfully');
    }
  }

  void _deleteAccount(Account account) {
    Haptics.warning();
    showCupertinoDialog(
      context: context,
      builder: (dialogContext) {
        return CupertinoAlertDialog(
          title: const Text('Delete Account'),
          content: Text(
              'Are you sure you want to delete "${account.name}"? This action cannot be undone.'),
          actions: [
            CupertinoDialogAction(
              child: const Text('Cancel'),
              onPressed: () => Navigator.pop(dialogContext),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              child: const Text('Delete'),
              onPressed: () {
                Haptics.delete();
                final accountsController =
                    Provider.of<AccountsController>(context, listen: false);
                final deletedName = account.name;
                accountsController.removeAccount(account.id);
                Navigator.pop(dialogContext);
                logger.info('Deleted account: $deletedName',
                    context: 'AccountsScreen');
                toast.showSuccess(
                  '"$deletedName" deleted',
                  actionLabel: 'Undo',
                  onAction: () {
                    accountsController.addAccount(account);
                    toast.showInfo('Account restored');
                  },
                );
              },
            ),
          ],
        );
      },
    );
  }
}
