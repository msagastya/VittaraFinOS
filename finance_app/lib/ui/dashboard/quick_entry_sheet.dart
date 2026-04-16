import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, Divider, InkWell;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/account_model.dart';
import 'package:vittara_fin_os/logic/accounts_controller.dart';
import 'package:vittara_fin_os/logic/categories_controller.dart';
import 'package:vittara_fin_os/logic/category_model.dart';
import 'package:vittara_fin_os/logic/payment_apps_controller.dart';
import 'package:vittara_fin_os/logic/settings_controller.dart';
import 'package:vittara_fin_os/logic/tag_model.dart';
import 'package:vittara_fin_os/logic/tags_controller.dart';
import 'package:vittara_fin_os/logic/transaction_model.dart';
import 'package:vittara_fin_os/logic/transactions_controller.dart';
import 'package:vittara_fin_os/logic/transaction_suggestion_engine.dart';
import 'package:vittara_fin_os/ui/dashboard/transaction_wizard.dart';
import 'package:vittara_fin_os/ui/manage/account_wizard.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/styles/typography.dart';
import 'package:vittara_fin_os/ui/widgets/animations.dart';
import 'package:vittara_fin_os/ui/widgets/common_widgets.dart';
import 'package:vittara_fin_os/ui/widgets/toast_notification.dart' as toast_lib;
import 'package:vittara_fin_os/utils/date_formatter.dart';
import 'package:vittara_fin_os/utils/id_generator.dart';
import 'package:intl/intl.dart';
import 'package:vittara_fin_os/ui/styles/responsive_utils.dart';
import 'package:vittara_fin_os/main.dart' show dashboardSavedSignal;

// ── Entry point ───────────────────────────────────────────────────────────────

void showQuickEntrySheet(BuildContext context,
    {TransactionWizardBranch branch = TransactionWizardBranch.expense,
    Transaction? existingTransaction}) {
  showCupertinoModalPopup<void>(
    context: context,
    builder: (ctx) => RLayout.tabletConstrain(
      ctx,
      _QuickEntrySheet(
      initialBranch: branch,
      existingTransaction: existingTransaction,
    ),
    ),
  );
}

// ── Sheet widget ──────────────────────────────────────────────────────────────

class _QuickEntrySheet extends StatefulWidget {
  final TransactionWizardBranch initialBranch;
  final Transaction? existingTransaction;
  const _QuickEntrySheet({
    required this.initialBranch,
    this.existingTransaction,
  });

  @override
  State<_QuickEntrySheet> createState() => _QuickEntrySheetState();
}

class _QuickEntrySheetState extends State<_QuickEntrySheet>
    with TickerProviderStateMixin {
  late TransactionWizardBranch _branch;
  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();
  final TextEditingController _merchantCtrl = TextEditingController();
  final TextEditingController _cashbackCtrl = TextEditingController();
  final TextEditingController _paymentAppAmountCtrl = TextEditingController();
  final TextEditingController _newTagCtrl = TextEditingController();

  Category? _selectedCategory;
  List<String> _selectedTags = [];
  String? _selectedAccountId;
  String? _selectedAccountName;
  String? _selectedPaymentApp;
  // Cashback destination: true = to payment app wallet, false = back to account
  bool _cashbackToApp = false;
  Color _newTagColor = Tag.colorPalette.first;

  bool _showMerchantField = false;
  bool _showCashbackField = false;
  bool _showTagPicker = false;
  bool _showNewTagInput = false;
  // true when the current _selectedCategory was set by ML auto-suggestion
  // (not by the user tapping). Lets us override it on the next merchant change.
  bool _categoryAutoSuggested = false;

  // Dirty tracking — true once the user has entered any data
  bool _isDirty = false;

  DateTime _selectedDate = DateTime.now();

  // ── Phase 5A/5C animation controllers ────────────────────────────────────────

  /// Drives the open animation: amount scale 0.95→1.0 and pill stagger.
  late AnimationController _openCtrl;
  late Animation<double> _amountScale;
  late Animation<double> _pill0Opacity;
  late Animation<double> _pill1Opacity;

  /// Drives the waiting-for-input pulse on the amount field (5C).
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseOpacity;

  /// True while save-confirmation flash (5D) is playing.
  bool _saveFlash = false;

  /// Key for the amount field ShakeAnimation — triggered on failed save tap.
  final GlobalKey<ShakeAnimationState> _amountShakeKey = GlobalKey();

  /// True while error flash (10C) is playing on the save button.
  bool _errorFlash = false;

  @override
  void initState() {
    super.initState();
    _branch = widget.initialBranch;

    final settings = context.read<SettingsController>();
    final accounts = context.read<AccountsController>();
    final paymentApps = context.read<PaymentAppsController>();
    final categories = context.read<CategoriesController>();

    // If editing an existing transaction, pre-fill the form
    if (widget.existingTransaction != null) {
      final tx = widget.existingTransaction!;
      _amountCtrl.text = tx.amount.toStringAsFixed(2);
      _descCtrl.text = tx.description;
      _selectedDate = tx.dateTime;

      // Set branch based on transaction type
      if (tx.type == TransactionType.expense) {
        _branch = TransactionWizardBranch.expense;
      } else if (tx.type == TransactionType.income) {
        _branch = TransactionWizardBranch.income;
      }

      // Pre-fill category
      final catId = tx.metadata?['categoryId'] as String?;
      if (catId != null) {
        _selectedCategory = categories.getCategoryById(catId);
      }

      // Pre-fill account
      if (tx.sourceAccountId != null) {
        _selectedAccountId = tx.sourceAccountId;
        _selectedAccountName = tx.sourceAccountName;
      }

      // Pre-fill merchant if available
      final merchant = tx.metadata?['merchant'] as String?;
      if (merchant != null) {
        _merchantCtrl.text = merchant;
        _showMerchantField = true;
      }

      // Pre-fill cashback if available
      if (tx.cashbackAmount != null && tx.cashbackAmount! > 0) {
        _cashbackCtrl.text = tx.cashbackAmount!.toStringAsFixed(2);
        _showCashbackField = true;
      }

      // Pre-fill app wallet amount if available
      if (tx.appWalletAmount != null && tx.appWalletAmount! > 0) {
        _paymentAppAmountCtrl.text = tx.appWalletAmount!.toStringAsFixed(2);
      }

      // Pre-fill payment app if available
      if (tx.paymentAppName != null) {
        _selectedPaymentApp = tx.paymentAppName;
      }

      // Pre-fill tags if available
      final tags = tx.metadata?['tags'] as List?;
      if (tags != null) {
        _selectedTags = List<String>.from(tags);
        _showTagPicker = _selectedTags.isNotEmpty;
      }
    } else {
      // New transaction - use defaults
      // Resolve default account
      final defaultAccountId = settings.defaultAccountId;
      if (defaultAccountId != null) {
        final acc = accounts.getAccountById(defaultAccountId);
        if (acc != null && !acc.isHidden && acc.type != AccountType.investment) {
          _selectedAccountId = acc.id;
          _selectedAccountName = acc.name;
        }
      }
      if (_selectedAccountId == null) {
        final nonCash = accounts.accounts
            .where((a) => !a.isHidden && a.type != AccountType.investment && a.type != AccountType.cash)
            .toList();
        if (nonCash.isNotEmpty) {
          _selectedAccountId = nonCash.first.id;
          _selectedAccountName = nonCash.first.name;
        } else {
          // Fall back to cash accounts (e.g. fresh-install user with only "Cash in Hand")
          final cashAccounts = accounts.accounts
              .where((a) => !a.isHidden && a.type == AccountType.cash)
              .toList();
          if (cashAccounts.isNotEmpty) {
            _selectedAccountId = cashAccounts.first.id;
            _selectedAccountName = cashAccounts.first.name;
          }
        }
      }

      // Resolve default payment app
      final defaultApp = settings.defaultPaymentAppName;
      if (defaultApp != null) {
        final found = paymentApps.enabledApps.where((a) => a['name'] == defaultApp).isNotEmpty;
        if (found) _selectedPaymentApp = defaultApp;
      }
      if (_selectedPaymentApp == null && paymentApps.enabledApps.isNotEmpty) {
        _selectedPaymentApp = paymentApps.enabledApps.first['name'] as String?;
      }
    }

    // ML auto-suggest: when merchant changes, auto-pick the most likely category
    _merchantCtrl.addListener(_onMerchantChanged);

    // Dirty tracking
    _amountCtrl.addListener(_markDirty);
    _merchantCtrl.addListener(_markDirty);
    _descCtrl.addListener(_markDirty);
  }

  void _onMerchantChanged() {
    // Only auto-suggest; never override a category the user manually tapped
    if (!_categoryAutoSuggested && _selectedCategory != null) return;
    final txs = context.read<TransactionsController>().transactions;
    final cats = context.read<CategoriesController>().categories;
    final suggestion = TransactionSuggestionEngine.suggestCategoryForMerchant(
      txs, _merchantCtrl.text, cats,
    );
    if (suggestion != null) {
      setState(() {
        _selectedCategory = suggestion;
        _categoryAutoSuggested = true;
      });
    } else if (_categoryAutoSuggested) {
      // Merchant was cleared / no longer matches — clear the auto-suggestion
      setState(() {
        _selectedCategory = null;
        _categoryAutoSuggested = false;
      });
    }

    // ── Phase 5A open animation ───────────────────────────────────────────────
    _openCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _amountScale = Tween(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(
        parent: _openCtrl,
        curve: const Interval(0.24, 1.0, curve: Curves.easeOutCubic),
      ),
    );
    _pill0Opacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _openCtrl,
        curve: const Interval(0.0, 0.55, curve: Curves.easeOut),
      ),
    );
    _pill1Opacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _openCtrl,
        curve: const Interval(0.08, 0.65, curve: Curves.easeOut),
      ),
    );
    // Start 120ms after sheet arrives
    Future.delayed(const Duration(milliseconds: 120), () {
      if (mounted) _openCtrl.forward();
    });

    // ── Phase 5C waiting pulse ────────────────────────────────────────────────
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _pulseOpacity = Tween(begin: 0.20, end: 0.60).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _pulseCtrl.repeat(reverse: true);
    // Stop pulse the moment user types anything
    _amountCtrl.addListener(() {
      if (_amountCtrl.text.isNotEmpty && _pulseCtrl.isAnimating) {
        _pulseCtrl.stop();
        _pulseCtrl.value = 1.0; // lock at full opacity
      }
    });
  }

  @override
  void dispose() {
    _openCtrl.dispose();
    _pulseCtrl.dispose();
    _amountCtrl.dispose();
    _descCtrl.dispose();
    _merchantCtrl.dispose();
    _cashbackCtrl.dispose();
    _paymentAppAmountCtrl.dispose();
    _newTagCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  Color get _branchColor =>
      _branch == TransactionWizardBranch.expense
          ? const Color(0xFFFF3B30)
          : const Color(0xFF34C759);

  bool get _canSave =>
      _amountCtrl.text.trim().isNotEmpty &&
      (double.tryParse(_amountCtrl.text) ?? 0) > 0 &&
      _selectedCategory != null &&
      _selectedAccountId != null;

  void _markDirty() {
    if (!_isDirty) setState(() => _isDirty = true);
  }

  Future<bool> _confirmDiscard() async {
    if (!_isDirty) return true;
    final result = await showCupertinoDialog<bool>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Discard transaction?'),
        content: const Text('Your unsaved entry will be lost.'),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep Editing'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// Delegates to TransactionSuggestionEngine — most-used categories first.
  List<Category> _rankedCategories(List<Category> all) =>
      TransactionSuggestionEngine.rankedCategories(
        context.read<TransactionsController>().transactions,
        all,
      );

  String _accountTypeLabel(AccountType type) {
    switch (type) {
      case AccountType.savings: return 'Savings';
      case AccountType.current: return 'Current';
      case AccountType.credit: return 'Credit Card';
      case AccountType.payLater: return 'Pay Later';
      case AccountType.wallet: return 'Wallet';
      case AccountType.cash: return 'Cash';
      case AccountType.investment: return 'Investment';
    }
  }

  bool get _selectedPaymentAppHasWallet {
    if (_selectedPaymentApp == null) return false;
    final apps = context.read<PaymentAppsController>().enabledApps;
    final app = apps.where((a) => a['name'] == _selectedPaymentApp).firstOrNull;
    return (app?['hasWallet'] as bool?) ?? false;
  }

  /// Merchants sorted by how often they've been used (most-used first).
  List<String> get _rankedMerchants =>
      TransactionSuggestionEngine.rankedMerchants(
        context.read<TransactionsController>().transactions,
      );

  // ── Save transaction ─────────────────────────────────────────────────────────

  Future<void> _save() async {
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    if (amount <= 0 || _selectedCategory == null) return;

    final accountsCtrl = context.read<AccountsController>();
    final paymentAppsCtrl = context.read<PaymentAppsController>();
    final transactionsCtrl = context.read<TransactionsController>();

    final appWalletUsedRaw =
        double.tryParse(_paymentAppAmountCtrl.text.trim()) ?? 0.0;
    final appWalletUsed = appWalletUsedRaw.clamp(0.0, amount).toDouble();
    final cashbackAmount = double.tryParse(_cashbackCtrl.text.trim()) ?? 0.0;

    // For expense: account pays (amount - appWalletUsed). For income: full amount credited.
    final accountPortion =
        (_branch == TransactionWizardBranch.expense && _selectedPaymentApp != null)
            ? (amount - appWalletUsed).clamp(0.0, amount).toDouble()
            : amount;

    // ── Build metadata identical to full wizard ───────────────────────────────
    final meta = <String, dynamic>{
      'categoryId': _selectedCategory!.id,
      'categoryName': _selectedCategory!.name,
      'merchant': _merchantCtrl.text.trim(),
      'description': _descCtrl.text.trim(),
      'tags': _selectedTags,
      'accountId': _selectedAccountId,
      'accountName': _selectedAccountName,
      'paymentApp': _selectedPaymentApp,
      'cashbackAmount': cashbackAmount,
      'cashbackFlow': _cashbackToApp ? 'paymentApp' : 'bank',
      'appWalletAmount': appWalletUsed,
    };

    Account? account;
    if (_selectedAccountId != null) {
      account = accountsCtrl.getAccountById(_selectedAccountId!);
    }

    if (account != null) {
      final snapped = accountsCtrl.getAccountById(account.id) ?? account;
      // Snapshot must reflect balance AFTER this transaction is applied
      final balanceDelta = _branch == TransactionWizardBranch.expense
          ? -accountPortion
          : amount;
      meta['sourceBalanceAfter'] = snapped.balance + balanceDelta;
      if (snapped.creditLimit != null) {
        meta['sourceCreditLimit'] = snapped.creditLimit;
      }
    }

    final tx = Transaction(
      id: widget.existingTransaction?.id ?? IdGenerator.next(),
      type: _branch == TransactionWizardBranch.expense
          ? TransactionType.expense
          : TransactionType.income,
      description: _descCtrl.text.trim().isEmpty
          ? (_selectedCategory?.name ?? 'Transaction')
          : _descCtrl.text.trim(),
      dateTime: _selectedDate,
      amount: amount,
      sourceAccountId: _selectedAccountId,
      sourceAccountName: _selectedAccountName,
      paymentAppName: _selectedPaymentApp,
      appWalletAmount: appWalletUsed > 0 ? appWalletUsed : null,
      cashbackAmount: cashbackAmount > 0 ? cashbackAmount : null,
      cashbackAccountId: (cashbackAmount > 0 && !_cashbackToApp && account != null)
          ? account.id
          : null,
      cashbackAccountName: (cashbackAmount > 0 && !_cashbackToApp && account != null)
          ? account.name
          : null,
      metadata: meta,
    );

    // Handle edit vs new transaction
    if (widget.existingTransaction != null) {
      // Edit mode: use cascade-aware editTransaction
      final editSuccess = await transactionsCtrl.editTransaction(
        tx,
        accountsCtrl,
        paymentAppsCtrl,
      );
      if (!editSuccess) {
        toast_lib.toast.showError('Edit window expired (24h limit)');
        return;
      }
      HapticFeedback.heavyImpact();
      if (mounted) {
        await _triggerSaveFlash();
        if (mounted) Navigator.pop(context);
      }
      toast_lib.toast.showSuccess('Transaction updated');
    } else {
      // New transaction mode: manual balance updates
      // ── Update account balance ────────────────────────────────────────────────
      if (account != null) {
        final balanceDelta =
            _branch == TransactionWizardBranch.expense ? -accountPortion : amount;
        await accountsCtrl
            .updateAccount(account.copyWith(balance: account.balance + balanceDelta));
      }

      // ── Deduct from payment app wallet ───────────────────────────────────────
      if (_branch == TransactionWizardBranch.expense &&
          appWalletUsed > 0 &&
          _selectedPaymentApp != null) {
        await paymentAppsCtrl.adjustWalletBalanceByName(
            _selectedPaymentApp!, -appWalletUsed);
      }

      // ── Apply cashback ────────────────────────────────────────────────────────
      if (cashbackAmount > 0) {
        if (_cashbackToApp && _selectedPaymentApp != null) {
          await paymentAppsCtrl.adjustWalletBalanceByName(
              _selectedPaymentApp!, cashbackAmount);
        } else if (account != null) {
          // Re-fetch after previous update
          final refreshed = accountsCtrl.getAccountById(account.id) ?? account;
          await accountsCtrl.updateAccount(
              refreshed.copyWith(balance: refreshed.balance + cashbackAmount));
        }
      }

      await transactionsCtrl.addTransaction(tx);
      HapticFeedback.heavyImpact();
      dashboardSavedSignal.value++; // triggers FAB checkmark morph
      if (mounted) {
        await _triggerSaveFlash();
        if (mounted) Navigator.pop(context);
      }
      toast_lib.toast.showSuccess('Transaction saved');
    }
  }

  /// Phase 5D — brief success flash before the sheet dismisses.
  Future<void> _triggerSaveFlash() async {
    setState(() => _saveFlash = true);
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) setState(() => _saveFlash = false);
  }

  /// Phase 10C — shake amount field + flash button red on failed save tap.
  Future<void> _triggerErrorFlash() async {
    _amountShakeKey.currentState?.shake(); // also fires Haptics.error()
    setState(() => _errorFlash = true);
    await Future.delayed(const Duration(milliseconds: 200));
    if (mounted) setState(() => _errorFlash = false);
  }

  // ── Account picker ───────────────────────────────────────────────────────────

  void _pickAccount() {
    final accounts = context.read<AccountsController>().accounts
        .where((a) => !a.isHidden && a.type != AccountType.investment)
        .toList();
    final settings = context.read<SettingsController>();

    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) {
        final isDark = AppStyles.isDarkMode(ctx);
        final bgColor = isDark ? const Color(0xFF0D0D0D) : CupertinoColors.systemBackground.resolveFrom(ctx);
        final cardColor = isDark ? const Color(0xFF141414) : const Color(0xFFF7F7F7);
        final secondaryText = AppStyles.getSecondaryTextColor(ctx);
        final primaryText = AppStyles.getTextColor(ctx);

        return RLayout.tabletConstrain(
          ctx,
          Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.only(bottom: 32),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ModalHandle(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: Row(
                    children: [
                      Text(
                        'Select Account',
                        style: TextStyle(
                          fontFamily: 'SpaceGrotesk',
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                          color: primaryText,
                        ),
                      ),
                      const Spacer(),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => Navigator.pop(ctx),
                        child: Icon(CupertinoIcons.xmark_circle_fill,
                            color: secondaryText.withValues(alpha: 0.3), size: 26),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(ctx).size.height * 0.5,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: accounts.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final acc = accounts[i];
                      final isSelected = acc.id == _selectedAccountId;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedAccountId = acc.id;
                            _selectedAccountName = acc.name;
                          });
                          Navigator.pop(ctx);
                        },
                        child: AnimatedContainer(
                          duration: AppDurations.fast,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? acc.color.withValues(alpha: 0.12)
                                : cardColor,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected
                                  ? acc.color.withValues(alpha: 0.6)
                                  : (isDark ? const Color(0xFF1E1E1E) : const Color(0xFFE0E0E0)),
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: acc.color.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Center(
                                  child: Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: acc.color,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      acc.name,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: primaryText,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${acc.bankName} · ${_accountTypeLabel(acc.type)}',
                                      style: AppTypography.caption(color: secondaryText),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    CurrencyFormatter.compact(acc.balance),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: acc.balance >= 0
                                          ? const Color(0xFF34C759)
                                          : const Color(0xFFFF3B30),
                                    ),
                                  ),
                                  if (acc.id == settings.defaultAccountId) ...[
                                    const SizedBox(height: 2),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: AppStyles.accentBlue.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'Default',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                          color: AppStyles.accentBlue,
                                        ),
                                      ),
                                    ),
                                  ] else if (isSelected) ...[
                                    const SizedBox(height: 2),
                                    Icon(CupertinoIcons.checkmark_circle_fill,
                                        size: 14, color: acc.color),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.pop(ctx),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFEEEEEE),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text('Cancel',
                                  style: AppTypography.body(color: secondaryText)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            if (_selectedAccountId != null) {
                              settings.setDefaultAccountId(_selectedAccountId);
                              toast_lib.toast.showSuccess('Default account saved');
                            }
                            Navigator.pop(ctx);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: AppStyles.accentBlue.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppStyles.accentBlue.withValues(alpha: 0.3)),
                            ),
                            child: Center(
                              child: Text(
                                'Set as default',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppStyles.accentBlue,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        );
      },
    );
  }

  // ── Payment app picker ───────────────────────────────────────────────────────

  void _pickPaymentApp() {
    final apps = context.read<PaymentAppsController>().enabledApps;
    final settings = context.read<SettingsController>();

    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) {
        final isDark = AppStyles.isDarkMode(ctx);
        final bgColor = isDark ? const Color(0xFF0D0D0D) : CupertinoColors.systemBackground.resolveFrom(ctx);
        final cardColor = isDark ? const Color(0xFF141414) : const Color(0xFFF7F7F7);
        final secondaryText = AppStyles.getSecondaryTextColor(ctx);
        final primaryText = AppStyles.getTextColor(ctx);

        // "None" is appended at the end
        final allItems = [...apps, null];

        return RLayout.tabletConstrain(
          ctx,
          Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.only(bottom: 32),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ModalHandle(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: Row(
                    children: [
                      Text(
                        'Pay via',
                        style: TextStyle(
                          fontFamily: 'SpaceGrotesk',
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                          color: primaryText,
                        ),
                      ),
                      const Spacer(),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => Navigator.pop(ctx),
                        child: Icon(CupertinoIcons.xmark_circle_fill,
                            color: secondaryText.withValues(alpha: 0.3), size: 26),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(ctx).size.height * 0.5,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: allItems.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final app = allItems[i];
                      final appName = app?['name'] as String?;
                      final appColor = (app?['color'] as Color?) ?? secondaryText;
                      final hasWallet = (app?['hasWallet'] as bool?) ?? false;
                      final walletBal = (app?['walletBalance'] as double?) ?? 0.0;
                      final isSelected = appName == _selectedPaymentApp ||
                          (appName == null && _selectedPaymentApp == null);

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedPaymentApp = appName;
                            if (appName == null || !hasWallet) {
                              _paymentAppAmountCtrl.clear();
                            }
                          });
                          Navigator.pop(ctx);
                        },
                        child: AnimatedContainer(
                          duration: AppDurations.fast,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? appColor.withValues(alpha: 0.12)
                                : cardColor,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected
                                  ? appColor.withValues(alpha: 0.6)
                                  : (isDark ? const Color(0xFF1E1E1E) : const Color(0xFFE0E0E0)),
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: appColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Center(
                                  child: appName == null
                                      ? Icon(CupertinoIcons.xmark, size: 16, color: secondaryText)
                                      : Text(
                                          appName[0],
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: appColor,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      appName ?? 'None',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: appName == null ? secondaryText : primaryText,
                                      ),
                                    ),
                                    if (hasWallet && walletBal > 0) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        'Wallet: ${CurrencyFormatter.compact(walletBal)}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: const Color(0xFF34C759),
                                        ),
                                      ),
                                    ] else if (hasWallet) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        'Wallet enabled',
                                        style: AppTypography.caption(color: secondaryText),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (appName != null && appName == settings.defaultPaymentAppName) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: AppStyles.accentBlue.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'Default',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                          color: AppStyles.accentBlue,
                                        ),
                                      ),
                                    ),
                                    if (isSelected) const SizedBox(height: 4),
                                  ],
                                  if (isSelected)
                                    Icon(CupertinoIcons.checkmark_circle_fill,
                                        size: 18,
                                        color: appName == null ? secondaryText : appColor),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.pop(ctx),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFEEEEEE),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text('Cancel',
                                  style: AppTypography.body(color: secondaryText)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            settings.setDefaultPaymentApp(_selectedPaymentApp);
                            toast_lib.toast.showSuccess('Default payment app saved');
                            Navigator.pop(ctx);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: AppStyles.accentBlue.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppStyles.accentBlue.withValues(alpha: 0.3)),
                            ),
                            child: Center(
                              child: Text(
                                'Set as default',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppStyles.accentBlue,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        );
      },
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final kb = MediaQuery.of(context).viewInsets.bottom;
    final isDark = AppStyles.isDarkMode(context);
    final categories = context.watch<CategoriesController>().categories;
    final tags = context.watch<TagsController>().tags;
    final bgBase = isDark ? const Color(0xFF080F1C) : CupertinoColors.systemBackground.resolveFrom(context);
    final bgColor = _saveFlash
        ? Color.lerp(bgBase, SemanticColors.success, 0.12)!
        : bgBase;
    final secondaryText = AppStyles.getSecondaryTextColor(context);
    final primaryText = AppStyles.getTextColor(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscard() && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: AnimatedPadding(
      padding: EdgeInsets.only(bottom: kb),
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: Radii.modalRadius,
        ),
        child: SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: AppStyles.sheetMaxHeight(context),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                const ModalHandle(),

                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Quick Entry',
                        style: TextStyle(
                          fontFamily: 'SpaceGrotesk',
                          fontWeight: FontWeight.bold,
                          fontSize: RT.title2(context),
                          color: primaryText,
                        ),
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () async {
                          if (await _confirmDiscard() && context.mounted) {
                            Navigator.pop(context);
                          }
                        },
                        child: Icon(
                          CupertinoIcons.xmark_circle_fill,
                          color: secondaryText.withValues(alpha: 0.4),
                          size: 28,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: Spacing.sm),

                // ── No-account warning banner ──────────────────────────────────
                Builder(builder: (ctx) {
                  final allAccounts = ctx.watch<AccountsController>().accounts
                      .where((a) => !a.isHidden && a.type != AccountType.investment)
                      .toList();
                  if (allAccounts.isNotEmpty) return const SizedBox.shrink();
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      showCupertinoModalPopup<void>(
                        context: context,
                        builder: (_) => AccountWizard(),
                      );
                    },
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(Spacing.lg, 0, Spacing.lg, Spacing.sm),
                      padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF9500).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(Radii.md),
                        border: Border.all(color: const Color(0xFFFF9500).withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(CupertinoIcons.exclamationmark_triangle_fill,
                              color: Color(0xFFFF9500), size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'No account set up yet. Tap to add one first.',
                              style: TextStyle(
                                fontSize: TypeScale.footnote,
                                color: AppStyles.getTextColor(context),
                              ),
                            ),
                          ),
                          const Icon(CupertinoIcons.chevron_right,
                              color: Color(0xFFFF9500), size: 13),
                        ],
                      ),
                    ),
                  );
                }),

                // Scrollable content
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Type toggle — stagger in (Phase 5A) ─────────────────
                        AnimatedBuilder(
                          animation: _openCtrl,
                          builder: (context, child) => Opacity(
                            opacity: _pill0Opacity.value,
                            child: child,
                          ),
                          child: _buildTypeToggle(isDark),
                        ),
                        const SizedBox(height: Spacing.lg),

                        // ── Amount — scale in + waiting pulse (Phase 5A/5C) ──────
                        ShakeAnimation(
                          key: _amountShakeKey,
                          child: AnimatedBuilder(
                            animation: Listenable.merge([_openCtrl, _pulseCtrl]),
                            builder: (context, child) {
                              final isEmpty = _amountCtrl.text.isEmpty;
                              return Transform.scale(
                                scale: _amountScale.value,
                                child: isEmpty
                                    ? Opacity(
                                        opacity: _pulseOpacity.value,
                                        child: child,
                                      )
                                    : child,
                              );
                            },
                            child: _buildAmountField(isDark, primaryText),
                          ),
                        ),
                        const SizedBox(height: Spacing.lg),

                        // ── Category ────────────────────────────────────────────
                        _buildCategorySection(categories, isDark, secondaryText, primaryText),
                        const SizedBox(height: Spacing.lg),

                        // ── Description ─────────────────────────────────────────
                        _buildDescriptionField(isDark, secondaryText),
                        const SizedBox(height: Spacing.lg),

                        // ── Details divider ──────────────────────────────────────
                        _buildDetailsDivider(isDark, secondaryText),
                        const SizedBox(height: Spacing.md),

                        // ── Defaults ─────────────────────────────────────────────
                        _buildDefaultsRow(isDark, secondaryText, primaryText),
                        const SizedBox(height: Spacing.md),

                        // ── Optional detail rows ─────────────────────────────────
                        _buildMerchantRow(isDark, secondaryText, primaryText),
                        _buildCashbackRow(isDark, secondaryText, primaryText),
                        _buildTagsRow(tags, isDark, secondaryText, primaryText),
                        const SizedBox(height: Spacing.sm),

                        // ── Date (tappable) ───────────────────────────────────────
                        _buildDateRow(isDark, secondaryText, primaryText),
                        const SizedBox(height: Spacing.lg),

                        // ── Save button ───────────────────────────────────────────
                        _buildSaveButton(),
                        const SizedBox(height: Spacing.sm),

                        // ── Open full wizard ──────────────────────────────────────
                        Center(
                          child: CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: () {
                              // Build a prefill stub so the wizard auto-populates
                              final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
                              final meta = <String, dynamic>{
                                if (_selectedCategory != null) 'categoryId': _selectedCategory!.id,
                                if (_selectedCategory != null) 'categoryName': _selectedCategory!.name,
                                'merchant': _merchantCtrl.text.trim(),
                                'description': _descCtrl.text.trim(),
                                'tags': _selectedTags,
                                if (_selectedAccountId != null) 'accountId': _selectedAccountId,
                                if (_selectedAccountName != null) 'accountName': _selectedAccountName,
                                if (_selectedPaymentApp != null) 'paymentApp': _selectedPaymentApp,
                              };
                              final stub = Transaction(
                                id: IdGenerator.next(),
                                type: _branch == TransactionWizardBranch.expense
                                    ? TransactionType.expense
                                    : TransactionType.income,
                                description: _descCtrl.text.trim().isEmpty
                                    ? (_selectedCategory?.name ?? '')
                                    : _descCtrl.text.trim(),
                                dateTime: _selectedDate,
                                amount: amount > 0 ? amount : 0.01,
                                sourceAccountId: _selectedAccountId,
                                sourceAccountName: _selectedAccountName,
                                paymentAppName: _selectedPaymentApp,
                                metadata: meta,
                              );
                              Navigator.pop(context);
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (context.mounted) {
                                  Navigator.push(
                                    context,
                                    FadeScalePageRoute(
                                      page: TransactionWizard(cloneFrom: stub),
                                    ),
                                  );
                                }
                              });
                            },
                            child: const Text(
                              'More options →',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppStyles.accentBlue,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: Spacing.md),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ), // SafeArea/Container chain
      ), // Container (closes AnimatedPadding's child:)
      ), // AnimatedPadding (closes PopScope's child:)
    ); // PopScope
  }

  // ── Type toggle ──────────────────────────────────────────────────────────────

  Widget _buildTypeToggle(bool isDark) {
    return Row(
      children: [
        Expanded(child: _typeChip(TransactionWizardBranch.expense, '↑ Expense', isDark)),
        const SizedBox(width: Spacing.sm),
        Expanded(child: _typeChip(TransactionWizardBranch.income, '↓ Income', isDark)),
      ],
    );
  }

  Widget _typeChip(TransactionWizardBranch branch, String label, bool isDark) {
    final isActive = _branch == branch;
    final color = branch == TransactionWizardBranch.expense
        ? const Color(0xFFFF3B30)
        : const Color(0xFF34C759);
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _branch = branch);
      },
      child: AnimatedContainer(
        duration: AppDurations.fast,
        padding: const EdgeInsets.symmetric(vertical: Spacing.md),
        decoration: BoxDecoration(
          color: isActive ? color.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(
            color: isActive ? color : (isDark ? const Color(0xFF2A2A3A) : const Color(0xFFCCDDEE)),
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'SpaceGrotesk',
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              fontSize: 14,
              color: isActive ? color : AppStyles.getSecondaryTextColor(context),
            ),
          ),
        ),
      ),
    );
  }

  // ── Amount field ─────────────────────────────────────────────────────────────

  Widget _buildAmountField(bool isDark, Color primaryText) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '₹',
          style: TextStyle(
            fontSize: RT.displayLarge(context),
            fontWeight: FontWeight.bold,
            color: _branchColor,
          ),
        ),
        const SizedBox(width: Spacing.xs),
        SizedBox(
          width: 200,
          child: CupertinoTextField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            placeholder: '0',
            style: TextStyle(
              fontSize: RT.displayLarge(context),
              fontWeight: FontWeight.bold,
              color: primaryText,
            ),
            placeholderStyle: TextStyle(
              fontSize: RT.displayLarge(context),
              fontWeight: FontWeight.bold,
              color: AppStyles.getSecondaryTextColor(context).withValues(alpha: 0.4),
            ),
            decoration: const BoxDecoration(),
            textAlign: TextAlign.center,
            onChanged: (_) => setState(() {}),
          ),
        ),
      ],
    );
  }

  // ── Category section ─────────────────────────────────────────────────────────

  Widget _buildCategorySection(
    List<Category> categories,
    bool isDark,
    Color secondaryText,
    Color primaryText,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Category',
          style: AppTypography.footnote(color: secondaryText),
        ),
        const SizedBox(height: Spacing.sm),
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: Spacing.sm),
            itemBuilder: (ctx, i) {
              final cat = _rankedCategories(categories)[i];
              final isSelected = _selectedCategory?.id == cat.id;
              return GestureDetector(
                onTap: () => setState(() {
                  _selectedCategory = cat;
                  _categoryAutoSuggested = false; // user chose manually
                }),
                child: AnimatedContainer(
                  duration: AppDurations.fast,
                  padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.sm),
                  decoration: BoxDecoration(
                    color: isSelected ? cat.color.withValues(alpha: 0.15) : Colors.transparent,
                    borderRadius: BorderRadius.circular(Radii.full),
                    border: Border.all(
                      color: isSelected ? cat.color : (isDark ? const Color(0xFF2A2A3A) : const Color(0xFFCCDDEE)),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: cat.color,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(cat.icon, size: 10, color: Colors.white),
                      ),
                      const SizedBox(width: Spacing.xs),
                      Text(
                        cat.name,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          color: isSelected ? cat.color : AppStyles.getTextColor(context),
                        ),
                      ),
                      // ML auto-suggestion badge
                      if (isSelected && _categoryAutoSuggested) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: cat.color.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'AI',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: cat.color,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── Description field ────────────────────────────────────────────────────────

  Widget _buildDescriptionField(bool isDark, Color secondaryText) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Description',
          style: AppTypography.footnote(color: secondaryText),
        ),
        const SizedBox(height: Spacing.sm),
        CupertinoTextField(
          controller: _descCtrl,
          placeholder: 'What was this for? (optional)',
          style: TextStyle(color: AppStyles.getTextColor(context), fontSize: 14),
          placeholderStyle: TextStyle(color: secondaryText.withValues(alpha: 0.6), fontSize: 14),
          padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.sm),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0D1829) : const Color(0xFFF2F6FF),
            borderRadius: BorderRadius.circular(Radii.md),
          ),
        ),
      ],
    );
  }

  // ── Details divider ──────────────────────────────────────────────────────────

  Widget _buildDetailsDivider(bool isDark, Color secondaryText) {
    return Row(
      children: [
        Expanded(
          child: Divider(
            color: isDark ? const Color(0xFF1C2A3A) : const Color(0xFFCCDDEE),
            thickness: 0.5,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
          child: Text(
            'Details',
            style: AppTypography.caption(color: secondaryText),
          ),
        ),
        Expanded(
          child: Divider(
            color: isDark ? const Color(0xFF1C2A3A) : const Color(0xFFCCDDEE),
            thickness: 0.5,
          ),
        ),
      ],
    );
  }

  // ── Merchant row ─────────────────────────────────────────────────────────────

  Widget _buildMerchantRow(bool isDark, Color secondaryText, Color primaryText) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() {
            _showMerchantField = !_showMerchantField;
          }),
          child: _detailRow(
            icon: CupertinoIcons.building_2_fill,
            iconColor: Colors.grey,
            label: 'Merchant',
            value: _merchantCtrl.text.isEmpty ? '—' : _merchantCtrl.text,
            primaryText: primaryText,
            secondaryText: secondaryText,
          ),
        ),
        if (_showMerchantField) ...[
          const SizedBox(height: Spacing.xs),
          // Frequency-ranked merchant chips (most used first)
          Builder(builder: (ctx) {
            final recent = _rankedMerchants;
            if (recent.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Most used',
                  style: AppTypography.caption(color: secondaryText),
                ),
                const SizedBox(height: Spacing.xs),
                SizedBox(
                  height: 34,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: recent.length,
                    separatorBuilder: (_, __) => const SizedBox(width: Spacing.xs),
                    itemBuilder: (_, i) {
                      final m = recent[i];
                      final isSelected = _merchantCtrl.text == m;
                      return GestureDetector(
                        onTap: () => setState(() {
                          _merchantCtrl.text = isSelected ? '' : m;
                        }),
                        child: AnimatedContainer(
                          duration: AppDurations.fast,
                          padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.grey.withValues(alpha: 0.2)
                                : (isDark ? const Color(0xFF0D1829) : const Color(0xFFF2F6FF)),
                            borderRadius: BorderRadius.circular(Radii.full),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.grey
                                  : (isDark ? const Color(0xFF2A3A55) : const Color(0xFFBBCCEE)),
                            ),
                          ),
                          child: Text(m, style: AppTypography.footnote(color: primaryText)),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: Spacing.xs),
              ],
            );
          }),
          CupertinoTextField(
            controller: _merchantCtrl,
            placeholder: 'Or type a merchant name',
            style: TextStyle(color: primaryText, fontSize: 14),
            placeholderStyle: TextStyle(color: secondaryText.withValues(alpha: 0.6), fontSize: 14),
            padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.sm),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0D1829) : const Color(0xFFF2F6FF),
              borderRadius: BorderRadius.circular(Radii.md),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
        const SizedBox(height: Spacing.sm),
      ],
    );
  }

  // ── Cashback row ─────────────────────────────────────────────────────────────

  Widget _buildCashbackRow(bool isDark, Color secondaryText, Color primaryText) {
    final hasCashback = _cashbackCtrl.text.isNotEmpty;
    final cbDest = (_cashbackToApp && _selectedPaymentApp != null)
        ? '→ $_selectedPaymentApp wallet'
        : (_selectedAccountName != null ? '→ $_selectedAccountName' : '→ Account');
    final valueStr = hasCashback ? '₹${_cashbackCtrl.text} $cbDest' : '—';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _showCashbackField = !_showCashbackField),
          child: _detailRow(
            icon: CupertinoIcons.percent,
            iconColor: AppStyles.accentOrange,
            label: 'Cashback',
            value: valueStr,
            primaryText: primaryText,
            secondaryText: secondaryText,
          ),
        ),
        if (_showCashbackField) ...[
          const SizedBox(height: Spacing.xs),
          CupertinoTextField(
            controller: _cashbackCtrl,
            placeholder: 'Cashback amount (₹)',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(color: primaryText, fontSize: 14),
            placeholderStyle: TextStyle(color: secondaryText.withValues(alpha: 0.6), fontSize: 14),
            padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.sm),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0D1829) : const Color(0xFFF2F6FF),
              borderRadius: BorderRadius.circular(Radii.md),
            ),
            onChanged: (_) => setState(() {}),
          ),
          // Cashback destination toggle — always account or payment app wallet
          if (_selectedPaymentApp != null) ...[
            const SizedBox(height: Spacing.xs),
            Row(
              children: [
                Text('Goes to:', style: AppTypography.footnote(color: secondaryText)),
                const SizedBox(width: Spacing.sm),
                _cashbackDestChip(
                  label: _selectedAccountName ?? 'Account',
                  active: !_cashbackToApp,
                  color: AppStyles.accentOrange,
                  isDark: isDark,
                  onTap: () => setState(() => _cashbackToApp = false),
                ),
                const SizedBox(width: Spacing.xs),
                _cashbackDestChip(
                  label: '$_selectedPaymentApp Wallet',
                  active: _cashbackToApp,
                  color: AppStyles.accentOrange,
                  isDark: isDark,
                  onTap: () => setState(() => _cashbackToApp = true),
                ),
              ],
            ),
          ],
        ],
        const SizedBox(height: Spacing.sm),
      ],
    );
  }

  Widget _cashbackDestChip({
    required String label,
    required bool active,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppDurations.fast,
        padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: 5),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(Radii.full),
          border: Border.all(
            color: active ? color : (isDark ? const Color(0xFF2A3A55) : const Color(0xFFBBCCEE)),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: active ? color : AppStyles.getSecondaryTextColor(context),
            fontWeight: active ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  // ── Tags row ─────────────────────────────────────────────────────────────────

  Widget _buildTagsRow(
    List<Tag> tags,
    bool isDark,
    Color secondaryText,
    Color primaryText,
  ) {
    final tagNames = _selectedTags.isEmpty ? '—' : _selectedTags.join(', ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() {
            _showTagPicker = !_showTagPicker;
            if (!_showTagPicker) _showNewTagInput = false;
          }),
          child: _detailRow(
            icon: CupertinoIcons.tag_fill,
            iconColor: AppStyles.accentPurple,
            label: 'Tags',
            value: tagNames,
            primaryText: primaryText,
            secondaryText: secondaryText,
          ),
        ),
        if (_showTagPicker) ...[
          const SizedBox(height: Spacing.sm),
          Wrap(
            spacing: Spacing.sm,
            runSpacing: Spacing.sm,
            children: [
              // Existing tags
              for (final tag in tags)
                Builder(builder: (ctx) {
                  final isSelected = _selectedTags.contains(tag.name);
                  return GestureDetector(
                    onTap: () => setState(() {
                      if (isSelected) {
                        _selectedTags = List.from(_selectedTags)..remove(tag.name);
                      } else {
                        _selectedTags = List.from(_selectedTags)..add(tag.name);
                      }
                    }),
                    child: AnimatedContainer(
                      duration: AppDurations.fast,
                      padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.xs),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? tag.color.withValues(alpha: 0.2)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(Radii.full),
                        border: Border.all(
                          color: isSelected
                              ? tag.color
                              : (isDark ? const Color(0xFF2A2A3A) : const Color(0xFFCCDDEE)),
                        ),
                      ),
                      child: Text(
                        tag.name,
                        style: TextStyle(
                          fontSize: 12,
                          color: isSelected ? tag.color : secondaryText,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                }),

              // Add new tag button
              if (!_showNewTagInput)
                GestureDetector(
                  onTap: () => setState(() => _showNewTagInput = true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.xs),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(Radii.full),
                      border: Border.all(
                        color: AppStyles.accentPurple.withValues(alpha: 0.5),
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(CupertinoIcons.plus, size: 11, color: AppStyles.accentPurple),
                        const SizedBox(width: 4),
                        Text(
                          'New tag',
                          style: AppTypography.footnote(color: AppStyles.accentPurple),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),

          // Inline new tag creation
          if (_showNewTagInput) ...[
            const SizedBox(height: Spacing.sm),
            Row(
              children: [
                Expanded(
                  child: CupertinoTextField(
                    controller: _newTagCtrl,
                    placeholder: 'Tag name',
                    autofocus: true,
                    style: TextStyle(color: primaryText, fontSize: 13),
                    placeholderStyle: TextStyle(color: secondaryText.withValues(alpha: 0.6), fontSize: 13),
                    padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.sm),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0D1829) : const Color(0xFFF2F6FF),
                      borderRadius: BorderRadius.circular(Radii.md),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: Spacing.sm),
                // Color dots
                for (final c in Tag.colorPalette.take(5))
                  GestureDetector(
                    onTap: () => setState(() => _newTagColor = c),
                    child: Container(
                      width: 20,
                      height: 20,
                      margin: const EdgeInsets.only(left: 4),
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: _newTagColor == c
                            ? Border.all(color: primaryText, width: 2)
                            : null,
                      ),
                    ),
                  ),
                const SizedBox(width: Spacing.sm),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(32, 32),
                  onPressed: () {
                    final name = _newTagCtrl.text.trim();
                    if (name.isEmpty) return;
                    final tagsCtrl = context.read<TagsController>();
                    final newTag = Tag(
                      id: IdGenerator.next(),
                      name: name,
                      color: _newTagColor,
                      createdDate: DateTime.now(),
                    );
                    tagsCtrl.addTag(newTag);
                    setState(() {
                      _selectedTags = List.from(_selectedTags)..add(name);
                      _newTagCtrl.clear();
                      _showNewTagInput = false;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppStyles.accentPurple.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(Radii.md),
                    ),
                    child: Text(
                      'Add',
                      style: AppTypography.subhead(color: AppStyles.accentPurple),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
        const SizedBox(height: Spacing.sm),
      ],
    );
  }

  // ── Detail row helper ────────────────────────────────────────────────────────

  Widget _detailRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required Color primaryText,
    required Color secondaryText,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
      child: Row(
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: Spacing.sm),
          Text(label, style: AppTypography.subhead(color: secondaryText)),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              style: AppTypography.subhead(color: primaryText),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: Spacing.xs),
          Icon(CupertinoIcons.chevron_down, size: 12, color: secondaryText.withValues(alpha: 0.5)),
        ],
      ),
    );
  }

  // ── Defaults row ─────────────────────────────────────────────────────────────

  Widget _buildDefaultsRow(bool isDark, Color secondaryText, Color primaryText) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Account row
        Row(
          children: [
            SizedBox(
              width: 72,
              child: Text('Account:', style: AppTypography.footnote(color: secondaryText)),
            ),
            Expanded(
              child: GestureDetector(
                onTap: _pickAccount,
                child: _editableChip(
                  label: _selectedAccountName ?? 'Tap to select',
                  isDark: isDark,
                  primaryText: _selectedAccountName != null ? primaryText : secondaryText,
                  isSelected: _selectedAccountName != null,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: Spacing.xs),
        // Payment App row
        Row(
          children: [
            SizedBox(
              width: 72,
              child: Text('Pay via:', style: AppTypography.footnote(color: secondaryText)),
            ),
            Expanded(
              child: GestureDetector(
                onTap: _pickPaymentApp,
                child: _editableChip(
                  label: _selectedPaymentApp ?? 'None',
                  isDark: isDark,
                  primaryText: primaryText,
                  isSelected: _selectedPaymentApp != null,
                ),
              ),
            ),
          ],
        ),
        // Wallet amount field (shown only when selected app has wallet feature)
        if (_selectedPaymentApp != null && _selectedPaymentAppHasWallet) ...[
          const SizedBox(height: Spacing.xs),
          Row(
            children: [
              const SizedBox(width: 72),
              Expanded(
                child: CupertinoTextField(
                  controller: _paymentAppAmountCtrl,
                  placeholder: 'Amount paid via $_selectedPaymentApp wallet (optional)',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(color: primaryText, fontSize: 12),
                  placeholderStyle: TextStyle(color: secondaryText.withValues(alpha: 0.5), fontSize: 12),
                  padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0D1829) : const Color(0xFFF2F6FF),
                    borderRadius: BorderRadius.circular(Radii.md),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildDateRow(bool isDark, Color secondaryText, Color primaryText) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selected = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final isToday = selected == today;
    final isYesterday = selected == today.subtract(const Duration(days: 1));

    String label;
    if (isToday) {
      label = 'Today · ${DateFormat('dd MMM yyyy').format(_selectedDate)}';
    } else if (isYesterday) {
      label = 'Yesterday · ${DateFormat('dd MMM yyyy').format(_selectedDate)}';
    } else {
      label = DateFormat('EEE, dd MMM yyyy').format(_selectedDate);
    }

    return GestureDetector(
      onTap: () {
        showCupertinoModalPopup<void>(
          context: context,
          builder: (ctx) => RLayout.tabletConstrain(
            ctx,
            Container(
            height: 280,
            color: isDark ? const Color(0xFF1C1C1E) : CupertinoColors.systemBackground.resolveFrom(ctx),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CupertinoButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                    CupertinoButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                Expanded(
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.date,
                    initialDateTime: _selectedDate,
                    maximumDate: DateTime.now(),
                    onDateTimeChanged: (picked) => setState(() => _selectedDate = picked),
                  ),
                ),
              ],
            ),
          ),
          ),
        );
      },
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.calendar, size: 13, color: secondaryText),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppTypography.footnote(color: secondaryText),
            ),
            const SizedBox(width: 4),
            Icon(CupertinoIcons.pencil, size: 11, color: secondaryText.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }

  Widget _smallChip({required String label, required bool isDark, required Color primaryText}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.xs),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D1829) : const Color(0xFFEEF4FF),
        borderRadius: BorderRadius.circular(Radii.full),
        border: Border.all(
          color: isDark ? const Color(0xFF2A3A55) : const Color(0xFFBBCCEE),
        ),
      ),
      child: Text(label, style: AppTypography.footnote(color: primaryText)),
    );
  }

  Widget _editableChip({
    required String label,
    required bool isDark,
    required Color primaryText,
    required bool isSelected,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.xs),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D1829) : const Color(0xFFEEF4FF),
        borderRadius: BorderRadius.circular(Radii.full),
        border: Border.all(
          color: isSelected
              ? AppStyles.accentBlue.withValues(alpha: 0.5)
              : (isDark ? const Color(0xFF2A3A55) : const Color(0xFFBBCCEE)),
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              label,
              style: AppTypography.footnote(color: primaryText),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: Spacing.xs),
          Icon(
            CupertinoIcons.pencil,
            size: 10,
            color: AppStyles.accentBlue.withValues(alpha: 0.7),
          ),
        ],
      ),
    );
  }

  // ── Save button ──────────────────────────────────────────────────────────────

  Widget _buildSaveButton() {
    final canSave = _canSave;
    final isExpense = _branch == TransactionWizardBranch.expense;
    final startColor = _errorFlash
        ? SemanticColors.getError(context).withValues(alpha: 0.85)
        : isExpense ? const Color(0xFFFF3B30) : const Color(0xFF34C759);
    final endColor = _errorFlash
        ? SemanticColors.getError(context)
        : isExpense ? const Color(0xFFFF6B60) : const Color(0xFF00C44F);

    return Opacity(
      opacity: canSave ? 1.0 : (_errorFlash ? 0.9 : 0.4),
      child: BouncyButton(
        onPressed: canSave ? _save : _triggerErrorFlash,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: Spacing.md),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [startColor, endColor],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(Radii.md),
          ),
          child: const Center(
            child: Text(
              'Save Transaction',
              style: TextStyle(
                fontFamily: 'SpaceGrotesk',
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
