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
import 'package:vittara_fin_os/ui/dashboard/transaction_wizard.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/widgets/animations.dart';
import 'package:vittara_fin_os/ui/widgets/common_widgets.dart';
import 'package:vittara_fin_os/ui/widgets/toast_notification.dart' as toast_lib;
import 'package:vittara_fin_os/utils/id_generator.dart';
import 'package:intl/intl.dart';

// ── Entry point ───────────────────────────────────────────────────────────────

void showQuickEntrySheet(BuildContext context,
    {TransactionWizardBranch branch = TransactionWizardBranch.expense}) {
  showCupertinoModalPopup<void>(
    context: context,
    builder: (ctx) => _QuickEntrySheet(initialBranch: branch),
  );
}

// ── Sheet widget ──────────────────────────────────────────────────────────────

class _QuickEntrySheet extends StatefulWidget {
  final TransactionWizardBranch initialBranch;
  const _QuickEntrySheet({required this.initialBranch});

  @override
  State<_QuickEntrySheet> createState() => _QuickEntrySheetState();
}

class _QuickEntrySheetState extends State<_QuickEntrySheet> {
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

  @override
  void initState() {
    super.initState();
    _branch = widget.initialBranch;

    final settings = context.read<SettingsController>();
    final accounts = context.read<AccountsController>();
    final paymentApps = context.read<PaymentAppsController>();

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

  @override
  void dispose() {
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
      _selectedCategory != null;

  List<String> get _recentMerchants {
    final all = context.read<TransactionsController>().transactions;
    final seen = <String>{};
    final result = <String>[];
    for (final tx in all.reversed) {
      final m = tx.metadata?['merchant'] as String?;
      if (m != null && m.isNotEmpty && seen.add(m)) {
        result.add(m);
        if (result.length >= 20) break;
      }
    }
    return result;
  }

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

    // ── Update account balance ────────────────────────────────────────────────
    Account? account;
    if (_selectedAccountId != null) {
      account = accountsCtrl.getAccountById(_selectedAccountId!);
    }
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

    if (account != null) {
      final snapped =
          accountsCtrl.getAccountById(account.id) ?? account;
      meta['sourceBalanceAfter'] = snapped.balance;
      if (snapped.creditLimit != null) {
        meta['sourceCreditLimit'] = snapped.creditLimit;
      }
    }

    final tx = Transaction(
      id: IdGenerator.next(),
      type: _branch == TransactionWizardBranch.expense
          ? TransactionType.expense
          : TransactionType.income,
      description: _descCtrl.text.trim().isEmpty
          ? (_selectedCategory?.name ?? 'Transaction')
          : _descCtrl.text.trim(),
      dateTime: DateTime.now(),
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

    await transactionsCtrl.addTransaction(tx);
    HapticFeedback.heavyImpact();
    if (mounted) Navigator.pop(context);
    toast_lib.toast.showSuccess('Transaction saved');
  }

  // ── Account picker ───────────────────────────────────────────────────────────

  void _pickAccount() {
    final accounts = context.read<AccountsController>().accounts
        .where((a) => !a.isHidden && a.type != AccountType.investment)
        .toList();
    final settings = context.read<SettingsController>();

    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Select Account'),
        actions: [
          for (final acc in accounts)
            CupertinoActionSheetAction(
              onPressed: () {
                setState(() {
                  _selectedAccountId = acc.id;
                  _selectedAccountName = acc.name;
                });
                Navigator.pop(ctx);
              },
              child: Text(acc.name),
            ),
        ],
        cancelButton: Column(
          children: [
            CupertinoButton(
              onPressed: () {
                if (_selectedAccountId != null) {
                  settings.setDefaultAccountId(_selectedAccountId);
                  toast_lib.toast.showSuccess('Default account saved');
                }
                Navigator.pop(ctx);
              },
              child: const Text('Set as default'),
            ),
            CupertinoButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Payment app picker ───────────────────────────────────────────────────────

  void _pickPaymentApp() {
    final apps = context.read<PaymentAppsController>().enabledApps;
    final settings = context.read<SettingsController>();

    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Select Payment App'),
        actions: [
          for (final app in apps)
            CupertinoActionSheetAction(
              onPressed: () {
                setState(() {
                  _selectedPaymentApp = app['name'] as String?;
                });
                Navigator.pop(ctx);
              },
              child: Text(app['name'] as String? ?? ''),
            ),
          CupertinoActionSheetAction(
            onPressed: () {
              setState(() {
                _selectedPaymentApp = null;
                _paymentAppAmountCtrl.clear();
              });
              Navigator.pop(ctx);
            },
            child: const Text('None'),
          ),
        ],
        cancelButton: Column(
          children: [
            CupertinoButton(
              onPressed: () {
                settings.setDefaultPaymentApp(_selectedPaymentApp);
                toast_lib.toast.showSuccess('Default payment app saved');
                Navigator.pop(ctx);
              },
              child: const Text('Set as default'),
            ),
            CupertinoButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final kb = MediaQuery.of(context).viewInsets.bottom;
    final isDark = AppStyles.isDarkMode(context);
    final categories = context.watch<CategoriesController>().categories;
    final tags = context.watch<TagsController>().tags;
    final bgColor = isDark ? const Color(0xFF080F1C) : CupertinoColors.systemBackground.resolveFrom(context);
    final secondaryText = AppStyles.getSecondaryTextColor(context);
    final primaryText = AppStyles.getTextColor(context);

    return AnimatedPadding(
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
                          fontSize: 20,
                          color: primaryText,
                        ),
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => Navigator.pop(context),
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

                // Scrollable content
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Type toggle ─────────────────────────────────────────
                        _buildTypeToggle(isDark),
                        const SizedBox(height: Spacing.lg),

                        // ── Amount ──────────────────────────────────────────────
                        _buildAmountField(isDark, primaryText),
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

                        // ── Optional detail rows ─────────────────────────────────
                        _buildMerchantRow(isDark, secondaryText, primaryText),
                        _buildCashbackRow(isDark, secondaryText, primaryText),
                        _buildTagsRow(tags, isDark, secondaryText, primaryText),
                        const SizedBox(height: Spacing.md),

                        // ── Defaults ─────────────────────────────────────────────
                        _buildDefaultsRow(isDark, secondaryText, primaryText),
                        const SizedBox(height: Spacing.sm),

                        // ── Date ─────────────────────────────────────────────────
                        Center(
                          child: Text(
                            'Today · ${DateFormat('dd MMM yyyy').format(DateTime.now())}',
                            style: TextStyle(
                              fontSize: 12,
                              color: secondaryText,
                            ),
                          ),
                        ),
                        const SizedBox(height: Spacing.lg),

                        // ── Save button ───────────────────────────────────────────
                        _buildSaveButton(),
                        const SizedBox(height: Spacing.sm),

                        // ── Open full wizard ──────────────────────────────────────
                        Center(
                          child: CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: () {
                              Navigator.pop(context);
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (context.mounted) {
                                  Navigator.push(
                                    context,
                                    FadeScalePageRoute(
                                      page: TransactionWizard(initialBranch: _branch),
                                    ),
                                  );
                                }
                              });
                            },
                            child: const Text(
                              'Open full wizard →',
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
        ),
      ),
    );
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
      onTap: () => setState(() => _branch = branch),
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
            fontSize: 36,
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
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: primaryText,
            ),
            placeholderStyle: TextStyle(
              fontSize: 36,
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
          style: TextStyle(fontSize: 12, color: secondaryText),
        ),
        const SizedBox(height: Spacing.sm),
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: Spacing.sm),
            itemBuilder: (ctx, i) {
              final cat = categories[i];
              final isSelected = _selectedCategory?.id == cat.id;
              return GestureDetector(
                onTap: () => setState(() => _selectedCategory = cat),
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
          style: TextStyle(fontSize: 12, color: secondaryText),
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
            style: TextStyle(fontSize: 11, color: secondaryText),
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
          // Recent merchants chips
          Builder(builder: (ctx) {
            final recent = _recentMerchants;
            if (recent.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recent',
                  style: TextStyle(fontSize: 11, color: secondaryText),
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
                          child: Text(m, style: TextStyle(fontSize: 12, color: primaryText)),
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
                Text('Goes to:', style: TextStyle(fontSize: 12, color: secondaryText)),
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
                          style: TextStyle(fontSize: 12, color: AppStyles.accentPurple),
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
                    child: const Text(
                      'Add',
                      style: TextStyle(fontSize: 13, color: AppStyles.accentPurple),
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
          Text(label, style: TextStyle(fontSize: 13, color: secondaryText)),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              style: TextStyle(fontSize: 13, color: primaryText),
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
              child: Text('Account:', style: TextStyle(fontSize: 12, color: secondaryText)),
            ),
            GestureDetector(
              onTap: _pickAccount,
              child: _smallChip(
                label: _selectedAccountName ?? 'Tap to select',
                isDark: isDark,
                primaryText: _selectedAccountName != null ? primaryText : secondaryText,
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
              child: Text('Pay via:', style: TextStyle(fontSize: 12, color: secondaryText)),
            ),
            GestureDetector(
              onTap: _pickPaymentApp,
              child: _smallChip(
                label: _selectedPaymentApp ?? 'None',
                isDark: isDark,
                primaryText: primaryText,
              ),
            ),
          ],
        ),
        // Wallet amount field (shown when a payment app is selected)
        if (_selectedPaymentApp != null) ...[
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
      child: Text(label, style: TextStyle(fontSize: 12, color: primaryText)),
    );
  }

  // ── Save button ──────────────────────────────────────────────────────────────

  Widget _buildSaveButton() {
    final canSave = _canSave;
    final isExpense = _branch == TransactionWizardBranch.expense;
    final startColor = isExpense ? const Color(0xFFFF3B30) : const Color(0xFF34C759);
    final endColor = isExpense ? const Color(0xFFFF6B60) : const Color(0xFF00C44F);

    return Opacity(
      opacity: canSave ? 1.0 : 0.4,
      child: BouncyButton(
        onPressed: canSave ? _save : () {},
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
