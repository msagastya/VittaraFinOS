import 'dart:io';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:vittara_fin_os/logic/account_model.dart';
import 'package:vittara_fin_os/ui/widgets/animated_counter.dart' as counter_widgets;
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
import 'package:vittara_fin_os/utils/date_formatter.dart';
import 'package:vittara_fin_os/ui/transaction_history_screen.dart';
import 'package:vittara_fin_os/utils/logger.dart';
import 'package:vittara_fin_os/services/transaction_export_service.dart';

class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  // AU1-05 — persist search across navigation
  static String _persistedSearchQuery = '';

  final AppLogger logger = AppLogger();
  final PageController _categoryPageController = PageController();
  int _selectedCategoryIndex = 0;
  String _searchQuery = '';
  late final TextEditingController _searchController;

  // Memoized filter+sort cache — avoids redundant work on every build
  final Map<String, List<Account>> _filterSortCache = {};
  String _lastCacheKey = '';
  bool _hiddenSectionExpanded = false;

  @override
  void initState() {
    super.initState();
    _searchQuery = _persistedSearchQuery;
    _searchController = TextEditingController(text: _persistedSearchQuery);
  }

  @override
  void dispose() {
    _categoryPageController.dispose();
    _searchController.dispose();
    super.dispose();
  }

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
            decoration: AppStyles.bottomSheetDecoration(context),
            padding: const EdgeInsets.all(Spacing.xxl),
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
                  const SizedBox(height: Spacing.xxl),
                  Text(
                    'Add New Account',
                    style: AppStyles.titleStyle(context)
                        .copyWith(fontSize: TypeScale.title1),
                  ),
                  const SizedBox(height: Spacing.sm),
                  Text(
                    'Select the type of account you want to add',
                    style: TextStyle(
                      color: AppStyles.getSecondaryTextColor(context),
                      fontSize: TypeScale.body,
                    ),
                  ),
                  const SizedBox(height: Spacing.xxxl),
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
                        const SizedBox(width: Spacing.lg),
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
                  const SizedBox(height: Spacing.xxxl),
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
        padding: const EdgeInsets.all(Spacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(Spacing.lg),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: color),
            ),
            const SizedBox(height: Spacing.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppStyles.titleStyle(context)
                  .copyWith(fontSize: TypeScale.headline),
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

  List<Account> _getAccountsByType(List<Account> accounts, AccountType type) {
    return accounts.where((account) => account.type == type).toList();
  }

  double _getTotalByType(List<Account> accounts, AccountType type) {
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
      case AccountType.cash:
        return 'Cash in Hand';
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
      case AccountType.cash:
        return const Color(0xFF30D158);
    }
  }

  IconData _getAccountTypeIcon(AccountType type) {
    switch (type) {
      case AccountType.savings:
      case AccountType.current:
        return CupertinoIcons.building_2_fill;
      case AccountType.credit:
      case AccountType.payLater:
        return CupertinoIcons.creditcard_fill;
      case AccountType.wallet:
        return CupertinoIcons.square_stack_3d_down_right_fill;
      case AccountType.investment:
        return CupertinoIcons.chart_bar_square_fill;
      case AccountType.cash:
        return CupertinoIcons.money_dollar_circle_fill;
    }
  }

  List<AccountType> _orderedAccountTypes(List<Account> accounts) {
    const order = <AccountType>[
      AccountType.savings,
      AccountType.current,
      AccountType.cash,
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

  void _syncSelectedCategoryIndex(List<AccountType> types) {
    if (types.isEmpty) return;
    final maxIndex = types.length - 1;
    if (_selectedCategoryIndex > maxIndex) {
      final target = maxIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _selectedCategoryIndex = target);
        _categoryPageController.jumpToPage(target);
      });
    }
  }

  Widget _buildAllAccountsSummary(List<Account> accounts) {
    const liabilityTypes = {AccountType.credit, AccountType.payLater};
    final assets = accounts
        .where((a) => !liabilityTypes.contains(a.type))
        .fold(0.0, (s, a) => s + a.balance);
    // For credit/payLater: balance = available credit, so amount owed = creditLimit - balance
    final liabilities = accounts
        .where((a) => liabilityTypes.contains(a.type))
        .fold(0.0, (s, a) => s + ((a.creditLimit ?? 0.0) - a.balance));
    final net = assets - liabilities;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppStyles.getCardColor(context),
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(
            color: AppStyles.getSecondaryTextColor(context)
                .withValues(alpha: 0.15),
          ),
        ),
        child: Row(
          children: [
            _buildSummaryColumn('Assets', assets, AppStyles.gain(context)),
            _buildDivider(),
            _buildSummaryColumn(
                'Liabilities', liabilities, AppStyles.loss(context)),
            _buildDivider(),
            _buildSummaryColumn('Net Worth', net,
                net >= 0 ? AppStyles.accentBlue : AppStyles.loss(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryColumn(String label, double amount, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: TypeScale.caption,
              color: AppStyles.getSecondaryTextColor(context),
            ),
          ),
          const SizedBox(height: 2),
          counter_widgets.CurrencyCounter(
            value: amount.abs(),
            textStyle: TextStyle(
              fontSize: TypeScale.footnote,
              fontWeight: FontWeight.w700,
              color: color,
            ),
            decimalPlaces: 0,
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 28,
      color: AppStyles.getSecondaryTextColor(context).withValues(alpha: 0.2),
    );
  }

  Widget _buildCategoryTabs(List<AccountType> types, List<Account> accounts) {
    return SizedBox(
      height: 88,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
        itemCount: types.length,
        separatorBuilder: (_, __) => const SizedBox(width: Spacing.sm),
        itemBuilder: (context, index) {
          final type = types[index];
          final isSelected = index == _selectedCategoryIndex;
          final total = _getTotalByType(accounts, type);
          return BouncyButton(
            onPressed: () {
              setState(() => _selectedCategoryIndex = index);
              _categoryPageController.animateToPage(
                index,
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
              );
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected
                    ? _getAccountTypeColor(type).withValues(alpha: 0.16)
                    : AppStyles.getCardColor(context),
                borderRadius: BorderRadius.circular(Radii.md),
                border: Border.all(
                  color: isSelected
                      ? _getAccountTypeColor(type)
                      : AppStyles.getSecondaryTextColor(context)
                          .withValues(alpha: 0.2),
                  width: isSelected ? 1.6 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _getAccountTypeLabel(type),
                    style: AppStyles.titleStyle(context)
                        .copyWith(fontSize: TypeScale.subhead),
                  ),
                  const SizedBox(height: Spacing.xs),
                  Text(
                    '₹${total.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: TypeScale.footnote,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? _getAccountTypeColor(type)
                          : AppStyles.getSecondaryTextColor(context),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<Account> _filterAccountsBySearch(List<Account> accounts) {
    if (_searchQuery.isEmpty) return accounts;
    final q = _searchQuery.toLowerCase();
    return accounts
        .where((acc) =>
            acc.name.toLowerCase().contains(q) ||
            acc.bankName.toLowerCase().contains(q))
        .toList();
  }

  /// Returns filtered + sorted accounts for the given type.
  /// Memoized: recomputes only when source list, search query, or type changes.
  List<Account> _getFilteredSortedAccounts(
      List<Account> all, AccountType type) {
    final key = [
      all.length,
      all.isEmpty ? '' : all.first.id,
      all.isEmpty ? '' : all.last.id,
      type.index,
      _searchQuery,
    ].join('|');

    if (_filterSortCache.containsKey(key)) return _filterSortCache[key]!;

    // Evict stale entries when source list changes
    if (_lastCacheKey != key) {
      _filterSortCache.clear();
      _lastCacheKey = key;
    }

    final sorted = _filterAccountsBySearch(_getAccountsByType(all, type))
      ..sort((a, b) => b.balance.compareTo(a.balance));

    _filterSortCache[key] = sorted;
    return sorted;
  }

  Widget _buildCategoryPage(AccountType type, List<Account> allAccounts) {
    final sectionAccounts = _getFilteredSortedAccounts(allAccounts, type);
    final total = _getTotalByType(allAccounts, type);
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(Spacing.lg, 0, Spacing.lg, Spacing.md),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: _getAccountTypeColor(type).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(Radii.md),
            border: Border.all(
              color: _getAccountTypeColor(type).withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${_getAccountTypeLabel(type)} Total',
                  style: AppStyles.titleStyle(context)
                      .copyWith(fontSize: TypeScale.body),
                ),
              ),
              Text(
                '₹${total.toStringAsFixed(2)}',
                style: AppStyles.titleStyle(context).copyWith(
                  fontSize: TypeScale.callout,
                  color: _getAccountTypeColor(type),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: sectionAccounts.isEmpty && _searchQuery.isNotEmpty
              ? _buildNoSearchResults()
              : RefreshIndicator(
                  onRefresh: () =>
                      context.read<AccountsController>().loadAccounts(),
                  color: AppStyles.accentBlue,
                  child: ListView.builder(
                    key: PageStorageKey('accounts_list_${type.name}'),
                    padding:
                        const EdgeInsets.fromLTRB(Spacing.lg, 0, Spacing.lg, 110),
                    itemCount: sectionAccounts.length,
                    itemBuilder: (context, index) {
                      final account = sectionAccounts[index];
                      return StaggeredItem(
                        key: ValueKey('${type.name}_${account.id}'),
                        index: index,
                        child: _buildSlidableAccountCard(account),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildNoSearchResults() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            CupertinoIcons.search,
            size: 48,
            color: AppStyles.getSecondaryTextColor(context).withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            'No results for "$_searchQuery"',
            style: AppStyles.titleStyle(context)
                .copyWith(fontSize: TypeScale.headline),
          ),
          const SizedBox(height: 8),
          Text(
            'Try a different search term',
            style: TextStyle(
              fontSize: TypeScale.body,
              color: AppStyles.getSecondaryTextColor(context),
            ),
          ),
          const SizedBox(height: 16),
          CupertinoButton(
            onPressed: () => setState(() {
              _searchController.clear();
              _searchQuery = '';
              _persistedSearchQuery = '';
            }),
            child: const Text('Clear Search'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppStyles.getBackground(context),
      navigationBar: AppStyles.isLandscape(context) ? null : CupertinoNavigationBar(
        middle: Text('Accounts',
            style: TextStyle(color: AppStyles.getTextColor(context))),
        previousPageTitle: 'Back',
        backgroundColor: AppStyles.getBackground(context),
        border: null,
      ),
      child: Consumer<AccountsController>(
        builder: (context, accountsController, child) {
          if (!accountsController.isLoaded) {
            return const SafeArea(child: SkeletonListView(itemCount: 5));
          }
          final allAccounts = accountsController.accounts;
          final visibleAccounts =
              allAccounts.where((a) => !a.isHidden).toList();
          final hiddenAccounts =
              allAccounts.where((a) => a.isHidden).toList();
          final types = _orderedAccountTypes(visibleAccounts);
          _syncSelectedCategoryIndex(types);
          return Stack(
            children: [
              if (allAccounts.isEmpty)
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
                      const SizedBox(height: Spacing.lg),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
                        child: CupertinoSearchTextField(
                          controller: _searchController,
                          placeholder: 'Search accounts',
                          backgroundColor: AppStyles.getCardColor(context),
                          style:
                              TextStyle(color: AppStyles.getTextColor(context)),
                          placeholderStyle: TextStyle(
                              color: AppStyles.getSecondaryTextColor(context),
                              fontSize: TypeScale.body),
                          onChanged: (v) => setState(() { _searchQuery = v; _persistedSearchQuery = v; }),
                        ),
                      ),
                      const SizedBox(height: Spacing.sm),
                      _buildAllAccountsSummary(visibleAccounts),
                      const SizedBox(height: Spacing.sm),
                      _buildCategoryTabs(types, visibleAccounts),
                      const SizedBox(height: Spacing.md),
                      Expanded(
                        child: CustomScrollView(
                          slivers: [
                            SliverFillRemaining(
                              hasScrollBody: true,
                              child: Column(
                                children: [
                                  Expanded(
                                    child: types.isEmpty
                                        ? const SizedBox.shrink()
                                        : PageView.builder(
                                            controller:
                                                _categoryPageController,
                                            itemCount: types.length,
                                            onPageChanged: (index) {
                                              setState(() =>
                                                  _selectedCategoryIndex =
                                                      index);
                                            },
                                            itemBuilder: (context, index) {
                                              return _buildCategoryPage(
                                                  types[index],
                                                  visibleAccounts);
                                            },
                                          ),
                                  ),
                                  if (hiddenAccounts.isNotEmpty)
                                    _buildHiddenAccountsSection(
                                        hiddenAccounts),
                                ],
                              ),
                            ),
                          ],
                        ),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: Spacing.lg,
                      vertical: Spacing.md,
                    ),
                    decoration: BoxDecoration(
                      color: AppStyles.gain(context),
                      borderRadius: BorderRadius.circular(Radii.md),
                      boxShadow: [
                        BoxShadow(
                          color: AppStyles.gain(context)
                              .withValues(alpha: 0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          CupertinoIcons.arrow_right_arrow_left,
                          color: Colors.white,
                          size: 20,
                        ),
                        SizedBox(width: Spacing.sm),
                        Text(
                          'Transfer',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: TypeScale.body,
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
                child: Semantics(
                  label: 'Add account',
                  button: true,
                  child: FadingFAB(
                    onPressed: () => _showAddOptions(context),
                    heroTag: 'accounts_fab',
                  ),
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
      startActionPane: ActionPane(
        motion: const BehindMotion(),
        extentRatio: 0.25,
        children: [
          SlidableAction(
            onPressed: (_) {
              HapticFeedback.mediumImpact();
              _hideAccount(account);
            },
            backgroundColor: CupertinoColors.systemIndigo,
            foregroundColor: Colors.white,
            icon: CupertinoIcons.eye_slash_fill,
            label: 'Hide',
            borderRadius: const BorderRadius.horizontal(
              left: Radius.circular(12),
              right: Radius.circular(12),
            ),
          ),
        ],
      ),
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

  Widget _buildSlidableHiddenAccountCard(Account account) {
    return Slidable(
      startActionPane: ActionPane(
        motion: const BehindMotion(),
        extentRatio: 0.25,
        children: [
          SlidableAction(
            onPressed: (_) {
              HapticFeedback.mediumImpact();
              _unhideAccount(account);
            },
            backgroundColor: CupertinoColors.systemGreen,
            foregroundColor: Colors.white,
            icon: CupertinoIcons.eye_fill,
            label: 'Unhide',
            borderRadius: const BorderRadius.horizontal(
              left: Radius.circular(12),
              right: Radius.circular(12),
            ),
          ),
        ],
      ),
      child: _buildAccountCard(account),
    );
  }

  Widget _buildHiddenAccountsSection(List<Account> hiddenAccounts) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () {
            Haptics.light();
            setState(() => _hiddenSectionExpanded = !_hiddenSectionExpanded);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: Spacing.lg, vertical: Spacing.md),
            child: Row(
              children: [
                Icon(
                  CupertinoIcons.eye_slash,
                  size: 16,
                  color: AppStyles.getSecondaryTextColor(context),
                ),
                const SizedBox(width: 8),
                Text(
                  'Hidden Accounts (${hiddenAccounts.length})',
                  style: TextStyle(
                    fontSize: TypeScale.subhead,
                    fontWeight: FontWeight.w600,
                    color: AppStyles.getSecondaryTextColor(context),
                  ),
                ),
                const Spacer(),
                AnimatedRotation(
                  turns: _hiddenSectionExpanded ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    CupertinoIcons.chevron_down,
                    size: 14,
                    color: AppStyles.getSecondaryTextColor(context),
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding:
                const EdgeInsets.fromLTRB(Spacing.lg, 0, Spacing.lg, Spacing.lg),
            itemCount: hiddenAccounts.length,
            itemBuilder: (context, index) {
              return _buildSlidableHiddenAccountCard(hiddenAccounts[index]);
            },
          ),
          crossFadeState: _hiddenSectionExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 250),
        ),
      ],
    );
  }

  void _hideAccount(Account account) {
    final accountsController =
        Provider.of<AccountsController>(context, listen: false);
    accountsController.hideAccount(account.id);
    Haptics.light();
    toast.showSuccess(
      '"${account.name}" hidden',
      actionLabel: 'Undo',
      onAction: () {
        accountsController.unhideAccount(account.id);
        toast.showInfo('Account restored');
      },
    );
  }

  void _unhideAccount(Account account) {
    final accountsController =
        Provider.of<AccountsController>(context, listen: false);
    accountsController.unhideAccount(account.id);
    Haptics.light();
    toast.showSuccess('"${account.name}" is now visible');
  }

  Widget _buildAccountCard(Account account) {
    return Hero(
      tag: 'account_${account.id}',
      child: BouncyButton(
        onPressed: () => _showAccountDetailsSheet(account),
        child: Container(
          margin: const EdgeInsets.only(bottom: Spacing.lg),
          decoration: AppStyles.accentCardDecoration(context, account.color),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(Radii.xxl),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Left accent bar
                  Container(
                    width: 4,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          account.color,
                          account.color.withValues(alpha: 0.35),
                        ],
                      ),
                    ),
                  ),
                  // Card content
                  Expanded(
                    child: Padding(
                      padding: Spacing.cardPadding,
                      child: Row(
                        children: [
                          IconBox(
                            icon: _getAccountTypeIcon(account.type),
                            color: account.color,
                            showGlow: true,
                          ),
                          const SizedBox(width: Spacing.lg),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(account.name,
                                    style: AppStyles.titleStyle(context),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                                const SizedBox(height: Spacing.xs),
                                Text(
                                  '${account.bankName} · ${account.type.name.toUpperCase()}',
                                  style: TextStyle(
                                    fontSize: TypeScale.footnote,
                                    color: account.color
                                        .withValues(alpha: 0.75),
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                CurrencyFormatter.compact(account.balance),
                                style: AppStyles.amountStyle(context,
                                    color: account.color),
                              ),
                              const SizedBox(height: Spacing.xs),
                              Icon(
                                CupertinoIcons.chevron_right,
                                size: IconSizes.xs,
                                color: AppStyles.getSecondaryTextColor(context),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Returns all transactions that involve [account] on either side.
  List<Transaction> _getAccountTransactions(Account account) {
    final txController = context.read<TransactionsController>();
    return txController.transactions.where((tx) {
      final metaId = tx.metadata?['accountId'] as String?;
      return metaId == account.id ||
          tx.sourceAccountId == account.id ||
          tx.destinationAccountId == account.id;
    }).toList()
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
  }

  Future<void> _exportAccountCsv(Account account) async {
    final txList = _getAccountTransactions(account);
    final buffer = StringBuffer();
    buffer.writeln(
        'Date,Type,Summary,Amount,From Account,To Account,Merchant,Description,Category,Tags');
    for (final t in txList) {
      final meta = t.metadata ?? {};
      String esc(String v) {
        if (v.contains(',') || v.contains('"') || v.contains('\n')) {
          return '"${v.replaceAll('"', '""')}"';
        }
        return v;
      }

      final row = [
        DateFormatter.formatWithTime(t.dateTime),
        t.getTypeLabel(),
        esc(t.getSummary()),
        t.amount.toStringAsFixed(2),
        esc((t.sourceAccountName ?? '').toString()),
        esc((meta['destinationAccountName'] ?? '').toString()),
        esc((meta['merchant'] ?? '').toString()),
        esc((meta['description'] ?? t.description).toString()),
        esc((meta['categoryName'] ?? '').toString()),
        esc((meta['tags'] as List?)?.join('; ') ?? ''),
      ].join(',');
      buffer.writeln(row);
    }
    try {
      final dir = await getApplicationDocumentsDirectory();
      final reportsDir = Directory('${dir.path}/reports')
        ..createSync(recursive: true);
      final ts = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .substring(0, 19);
      final safeName = account.name.replaceAll(RegExp(r'[^\w]'), '_');
      final file = File('${reportsDir.path}/${safeName}_$ts.csv');
      await file.writeAsString(buffer.toString());
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/csv')],
        subject: '${account.name} — Transaction Export',
      );
      // Clean up temp file after sharing
      try { await file.delete(); } catch (_) {}
    } catch (e) {
      if (mounted) toast.showError('Export failed: $e');
    }
  }

  Future<void> _exportAccountPdf(Account account) async {
    final txList = _getAccountTransactions(account);
    if (txList.isEmpty) { toast.showError('No transactions to export'); return; }
    try {
      final file = await TransactionExportService.buildPdf(
        txList,
        title: '${account.name} Statement',
        accountName: account.name,
      );
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/pdf')],
        subject: '${account.name} — PDF Statement',
      );
      try { await file.delete(); } catch (_) {}
    } catch (e) {
      if (mounted) toast.showError('Export failed: $e');
    }
  }

  Future<void> _exportAccountXlsx(Account account) async {
    final txList = _getAccountTransactions(account);
    if (txList.isEmpty) { toast.showError('No transactions to export'); return; }
    try {
      final file = await TransactionExportService.buildXlsx(
        txList,
        title: '${account.name} Transactions',
        accountName: account.name,
      );
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')],
        subject: '${account.name} — Excel Export',
      );
      try { await file.delete(); } catch (_) {}
    } catch (e) {
      if (mounted) toast.showError('Export failed: $e');
    }
  }

  void _showAccountExportSheet(BuildContext context, Account account) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text('Export — ${account.name}'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () { Navigator.pop(ctx); _exportAccountPdf(account); },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.doc_richtext, color: CupertinoColors.systemRed),
                SizedBox(width: 10),
                Text('Export as PDF', style: TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () { Navigator.pop(ctx); _exportAccountXlsx(account); },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.square_grid_2x2, color: CupertinoColors.systemGreen),
                SizedBox(width: 10),
                Text('Export as Excel (.xlsx)', style: TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () { Navigator.pop(ctx); _exportAccountCsv(account); },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.doc_plaintext, color: CupertinoColors.systemBlue),
                SizedBox(width: 10),
                Text('Export as CSV', style: TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          isDefaultAction: true,
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  /// Compute 30-day balance history for an account by reversing transactions.
  List<double> _computeBalanceHistory(Account account) {
    final txController = context.read<TransactionsController>();
    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(days: 30));

    bool isForAccount(Transaction tx) {
      final metaId = tx.metadata?['accountId'] as String?;
      return metaId == account.id ||
          tx.sourceAccountId == account.id ||
          tx.destinationAccountId == account.id;
    }

    final relevantTxs = txController.transactions
        .where((tx) => isForAccount(tx) && tx.dateTime.isAfter(cutoff))
        .toList()
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime)); // newest first

    // Work backwards from current balance
    double running = account.balance;
    final dayPoints = <int, double>{0: running};
    for (final tx in relevantTxs) {
      final daysAgo = now.difference(tx.dateTime).inDays.clamp(0, 30);
      if (tx.sourceAccountId == account.id) {
        running += tx.amount; // reverse: money left account
      } else if (tx.destinationAccountId == account.id) {
        running -= tx.amount; // reverse: money arrived at account
      } else {
        // non-transfer: expense reduces balance, income increases
        if (tx.type == TransactionType.expense ||
            tx.type == TransactionType.investment ||
            tx.type == TransactionType.lending) {
          running += tx.amount;
        } else if (tx.type == TransactionType.income ||
            tx.type == TransactionType.cashback ||
            tx.type == TransactionType.borrowing) {
          running -= tx.amount;
        }
      }
      dayPoints[daysAgo] = running;
    }

    // Build result array indexed [0]=30dAgo … [30]=today
    final result = List<double>.filled(31, running);
    // Populate known points (daysAgo=0 is today=index30, daysAgo=30 is index0)
    dayPoints.forEach((daysAgo, v) => result[30 - daysAgo] = v);
    // Forward fill gaps
    for (int i = 1; i < 31; i++) {
      if (result[i] == running && !dayPoints.containsKey(30 - i)) {
        result[i] = result[i - 1];
      }
    }
    return result;
  }

  void _showAccountDetailsSheet(Account account) {
    showCupertinoModalPopup(
      context: context,
      builder: (modalContext) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          builder: (dragContext, scrollController) {
            // Consumer ensures the sheet rebuilds when accounts or transactions change
            return Consumer2<AccountsController, TransactionsController>(
              builder: (ctx, acctCtrl, txCtrl, _) {
                // Always use the freshest account data by ID
                final freshAccount = acctCtrl.accounts
                    .firstWhere((a) => a.id == account.id, orElse: () => account);
                final balanceHistory = _computeBalanceHistory(freshAccount);
                final recentTxs = _getAccountTransactions(freshAccount).take(3).toList();
            return Container(
              decoration: AppStyles.bottomSheetDecoration(dragContext),
              child: SingleChildScrollView(
                controller: scrollController,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const ModalHandle(),
                    const SizedBox(height: Spacing.xl),

                    // Account Details
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            freshAccount.name,
                            style: AppStyles.titleStyle(dragContext)
                                .copyWith(fontSize: TypeScale.title2),
                          ),
                          const SizedBox(height: Spacing.sm),
                          Text(
                            '${freshAccount.bankName} • ${freshAccount.type.name.toUpperCase()}',
                            style: TextStyle(
                              color:
                                  AppStyles.getSecondaryTextColor(dragContext),
                              fontSize: TypeScale.body,
                            ),
                          ),
                          const SizedBox(height: Spacing.lg),

                          // Balance display
                          Text(
                            'Balance',
                            style: TextStyle(
                              color:
                                  AppStyles.getSecondaryTextColor(dragContext),
                              fontSize: TypeScale.footnote,
                            ),
                          ),
                          const SizedBox(height: Spacing.xs),
                          Text(
                            '₹${freshAccount.balance.toStringAsFixed(2)}',
                            style: AppStyles.titleStyle(dragContext).copyWith(
                              fontSize: TypeScale.largeTitle,
                              color: AppStyles.accentBlue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          // Credit Card Number (if exists)
                          if (freshAccount.creditCardNumber != null &&
                              freshAccount.creditCardNumber!.isNotEmpty) ...[
                            const SizedBox(height: Spacing.lg),
                            Text(
                              'Card Number',
                              style: TextStyle(
                                color: AppStyles.getSecondaryTextColor(
                                    dragContext),
                                fontSize: TypeScale.footnote,
                              ),
                            ),
                            const SizedBox(height: Spacing.xs),
                            GestureDetector(
                              onLongPress: () {
                                Clipboard.setData(ClipboardData(
                                    text: freshAccount.creditCardNumber!));
                                HapticFeedback.lightImpact();
                                toast.showSuccess('Card number copied — clears in 30s');
                                Future.delayed(const Duration(seconds: 30), () {
                                  Clipboard.setData(const ClipboardData(text: ''));
                                });
                              },
                              child: Row(
                                children: [
                                  Text(
                                    freshAccount.creditCardNumber!,
                                    style: TextStyle(
                                      color: AppStyles.getTextColor(dragContext),
                                      fontSize: TypeScale.headline,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                  const SizedBox(width: Spacing.sm),
                                  CupertinoButton(
                                    padding: EdgeInsets.zero,
                                    onPressed: () {
                                      Clipboard.setData(ClipboardData(
                                          text: freshAccount.creditCardNumber!));
                                      HapticFeedback.lightImpact();
                                      toast.showSuccess('Card number copied — clears in 30s');
                                      Future.delayed(const Duration(seconds: 30), () {
                                        Clipboard.setData(const ClipboardData(text: ''));
                                      });
                                    }, minimumSize: const Size(28, 28),
                                    child: Icon(
                                      CupertinoIcons.doc_on_doc,
                                      size: 18,
                                      color: AppStyles.teal(dragContext),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          // Credit Card/Pay Later - Show Credit Limit and Amount Used
                          if (freshAccount.type == AccountType.credit ||
                              freshAccount.type == AccountType.payLater) ...[
                            const SizedBox(height: Spacing.xxl),
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
                                          fontSize: TypeScale.footnote,
                                        ),
                                      ),
                                      const SizedBox(height: Spacing.xs),
                                      Text(
                                        '₹${(freshAccount.creditLimit ?? 0.0).toStringAsFixed(2)}',
                                        style: TextStyle(
                                          color: AppStyles.getTextColor(
                                              dragContext),
                                          fontSize: TypeScale.headline,
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
                                          fontSize: TypeScale.footnote,
                                        ),
                                      ),
                                      const SizedBox(height: Spacing.xs),
                                      Text(
                                        '₹${((account.creditLimit ?? 0.0) - account.balance).toStringAsFixed(2)}',
                                        style: TextStyle(
                                          color: AppStyles.loss(dragContext),
                                          fontSize: TypeScale.headline,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],

                          // Balance history sparkline
                          const SizedBox(height: Spacing.xl),
                          Text(
                            '30-Day Balance Trend',
                            style: TextStyle(
                              color:
                                  AppStyles.getSecondaryTextColor(dragContext),
                              fontSize: TypeScale.footnote,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: Spacing.sm),
                          Container(
                            height: 80,
                            decoration: BoxDecoration(
                              color: AppStyles.getBackground(dragContext),
                              borderRadius: BorderRadius.circular(Radii.md),
                            ),
                            clipBehavior: Clip.hardEdge,
                            child: CustomPaint(
                              painter: _BalanceSparklinePainter(
                                values: balanceHistory,
                                lineColor: account.color,
                                gridColor: AppStyles.getSecondaryTextColor(
                                    dragContext),
                              ),
                              size: Size.infinite,
                            ),
                          ),

                          // Recent Transactions
                          const SizedBox(height: Spacing.xl),
                          Row(
                            children: [
                              Text(
                                'Recent Transactions',
                                style: TextStyle(
                                  color: AppStyles.getSecondaryTextColor(
                                      dragContext),
                                  fontSize: TypeScale.footnote,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Spacer(),
                              CupertinoButton(
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(0, 0),
                                  onPressed: () {
                                    Navigator.pop(modalContext);
                                    Navigator.push(
                                      context,
                                      CupertinoPageRoute(
                                        builder: (_) =>
                                            TransactionHistoryScreen(
                                          filterAccountId: account.id,
                                          filterAccountName: account.name,
                                        ),
                                      ),
                                    );
                                  },
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        CupertinoIcons.list_bullet,
                                        size: 14,
                                        color: AppStyles.teal(dragContext),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'View All',
                                        style: TextStyle(
                                          color: AppStyles.teal(dragContext),
                                          fontSize: TypeScale.footnote,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: Spacing.sm),
                          if (recentTxs.isEmpty)
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                              child: Text(
                                'No transactions yet',
                                style: TextStyle(
                                  color: AppStyles.getSecondaryTextColor(
                                      dragContext),
                                  fontSize: TypeScale.body,
                                ),
                              ),
                            )
                          else
                            ...recentTxs.map((tx) {
                              final meta = tx.metadata ?? {};
                              final isSend =
                                  tx.sourceAccountId == account.id;
                              final isReceive =
                                  tx.destinationAccountId == account.id;
                              final isExpense =
                                  tx.type == TransactionType.expense ||
                                      tx.type == TransactionType.investment ||
                                      tx.type == TransactionType.lending;
                              Color amtColor;
                              String prefix;
                              if (isSend) {
                                amtColor = AppStyles.loss(dragContext);
                                prefix = '−';
                              } else if (isReceive) {
                                amtColor = AppStyles.gain(dragContext);
                                prefix = '+';
                              } else if (isExpense) {
                                amtColor = AppStyles.loss(dragContext);
                                prefix = '−';
                              } else {
                                amtColor = AppStyles.gain(dragContext);
                                prefix = '+';
                              }
                              final label = (meta['categoryName'] as String?) ??
                                  tx.getTypeLabel();
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: AppStyles.getBackground(dragContext),
                                  borderRadius:
                                      BorderRadius.circular(Radii.md),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            tx.description,
                                            style: TextStyle(
                                              color: AppStyles.getTextColor(
                                                  dragContext),
                                              fontSize: TypeScale.body,
                                              fontWeight: FontWeight.w500,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${DateFormatter.format(tx.dateTime)}  ·  $label',
                                            style: TextStyle(
                                              color:
                                                  AppStyles.getSecondaryTextColor(
                                                      dragContext),
                                              fontSize: TypeScale.caption,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      '$prefix₹${tx.amount.abs().toStringAsFixed(0)}',
                                      style: TextStyle(
                                        color: amtColor,
                                        fontSize: TypeScale.body,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),

                          const SizedBox(height: Spacing.xl),
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
                                      color: AppStyles.gain(modalContext)
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
                                          color: AppStyles.gain(modalContext),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Adjust Balance',
                                          style: TextStyle(
                                            color: AppStyles.gain(modalContext),
                                            fontSize: TypeScale.body,
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
                          const SizedBox(height: Spacing.md),
                          Row(
                            children: [
                              Expanded(
                                child: BouncyButton(
                                  onPressed: () {
                                    Navigator.pop(modalContext);
                                    _showAccountExportSheet(context, account);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    decoration: BoxDecoration(
                                      color: CupertinoColors.systemOrange
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          CupertinoIcons.share,
                                          size: 16,
                                          color: CupertinoColors.systemOrange,
                                        ),
                                        SizedBox(width: 6),
                                        Text(
                                          'Export',
                                          style: TextStyle(
                                            color: CupertinoColors.systemOrange,
                                            fontSize: TypeScale.body,
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
                          const SizedBox(height: Spacing.md),
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
                                    child: const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          CupertinoIcons.pencil,
                                          size: 16,
                                          color: CupertinoColors.systemBlue,
                                        ),
                                        SizedBox(width: 6),
                                        Text(
                                          'Edit',
                                          style: TextStyle(
                                            color: CupertinoColors.systemBlue,
                                            fontSize: TypeScale.body,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: Spacing.md),
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
                                      color: AppStyles.loss(modalContext)
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
                                          color: AppStyles.loss(modalContext),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Delete',
                                          style: TextStyle(
                                            color: AppStyles.loss(modalContext),
                                            fontSize: TypeScale.body,
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
                    const SizedBox(height: Spacing.xl),
                  ],
                ),
              ),
            );
              }, // end Consumer builder
            ); // end Consumer
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
                        const SizedBox(height: Spacing.lg),
                        Text(
                          'Adjust Balance',
                          style: AppStyles.titleStyle(context)
                              .copyWith(fontSize: TypeScale.title1),
                        ),
                        const SizedBox(height: Spacing.sm),
                        Text(
                          account.type == AccountType.credit ||
                                  account.type == AccountType.payLater
                              ? 'Add = Pay Card | Subtract = Spend'
                              : 'Adjust your account balance',
                          style: TextStyle(
                            color: AppStyles.getSecondaryTextColor(context),
                            fontSize: TypeScale.body,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: Spacing.xxxl),

                        // Add/Subtract Toggle
                        Container(
                          decoration: BoxDecoration(
                            color: AppStyles.getSecondaryTextColor(context)
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(Radii.md),
                          ),
                          padding: const EdgeInsets.all(Spacing.xs),
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
                                          ? AppStyles.gain(context)
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
                                          ? AppStyles.loss(context)
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
                        const SizedBox(height: Spacing.xxxl),

                        // Amount Input
                        Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('₹',
                                  style: AppStyles.titleStyle(context)
                                      .copyWith(fontSize: TypeScale.display)),
                              const SizedBox(width: Spacing.sm),
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
                                    borderRadius: BorderRadius.circular(Radii.md),
                                  ),
                                  style: AppStyles.titleStyle(context).copyWith(
                                      fontSize: TypeScale.display,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: Spacing.huge),

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
                              borderRadius: BorderRadius.circular(Radii.lg),
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
    ).whenComplete(amountController.dispose);
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
          content: Builder(builder: (ctx) {
            final txController =
                Provider.of<TransactionsController>(ctx, listen: false);
            final linkedCount =
                txController.getTransactionsByAccount(account.id).length;
            return Text(linkedCount > 0
                ? 'Delete "${account.name}"? $linkedCount linked transaction${linkedCount == 1 ? '' : 's'} will be marked as deleted. This cannot be undone.'
                : 'Are you sure you want to delete "${account.name}"? This action cannot be undone.');
          }),
          actions: [
            CupertinoDialogAction(
              child: const Text('Cancel'),
              onPressed: () => Navigator.pop(dialogContext),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              child: const Text('Delete'),
              onPressed: () async {
                Haptics.delete();
                final accountsController =
                    Provider.of<AccountsController>(context, listen: false);
                final txController =
                    Provider.of<TransactionsController>(context, listen: false);
                final deletedName = account.name;
                // Mark all linked transactions so they show the deleted account label
                final linked = txController.getTransactionsByAccount(account.id);
                for (final tx in linked) {
                  final updatedMeta = Map<String, dynamic>.from(tx.metadata ?? {});
                  updatedMeta['deletedAccountName'] = account.name;
                  updatedMeta['deletedAccountId'] = account.id;
                  await txController.updateTransaction(
                    tx.copyWith(metadata: updatedMeta));
                }
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

class _BalanceSparklinePainter extends CustomPainter {
  final List<double>
      values; // 31 data points: index 0 = 30 days ago, 30 = today
  final Color lineColor;
  final Color gridColor;

  const _BalanceSparklinePainter({
    required this.values,
    required this.lineColor,
    required this.gridColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;

    const pad = 8.0;
    final w = size.width - pad * 2;
    final h = size.height - pad * 2;

    final minV = values.reduce((a, b) => a < b ? a : b);
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final range = (maxV - minV).abs();
    final lo = range == 0 ? minV - 1 : minV;
    final hi = range == 0 ? maxV + 1 : maxV;
    final span = hi - lo;

    double xOf(int i) => pad + (i / (values.length - 1)) * w;
    double yOf(double v) => pad + h - ((v - lo) / span * h);

    final path = Path();
    for (int i = 0; i < values.length; i++) {
      final x = xOf(i);
      final y = yOf(values[i]);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    // Gradient fill
    final fillPath = Path.from(path)
      ..lineTo(xOf(values.length - 1), pad + h)
      ..lineTo(pad, pad + h)
      ..close();
    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            lineColor.withValues(alpha: 0.25),
            lineColor.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(pad, pad, w, h)),
    );

    // Line
    canvas.drawPath(
      path,
      Paint()
        ..color = lineColor
        ..strokeWidth = 1.8
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Endpoint dot
    final lastX = xOf(values.length - 1);
    final lastY = yOf(values.last);
    canvas.drawCircle(Offset(lastX, lastY), 3.5, Paint()..color = lineColor);
  }

  @override
  bool shouldRepaint(_BalanceSparklinePainter old) =>
      old.values != values || old.lineColor != lineColor;
}
