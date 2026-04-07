import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as device_contacts;
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vittara_fin_os/logic/account_model.dart';
import 'package:vittara_fin_os/logic/accounts_controller.dart';
import 'package:vittara_fin_os/logic/category_model.dart';
import 'package:vittara_fin_os/logic/categories_controller.dart';
import 'package:vittara_fin_os/logic/contact_model.dart';
import 'package:vittara_fin_os/logic/contacts_controller.dart';
import 'package:vittara_fin_os/logic/payment_apps_controller.dart';
import 'package:vittara_fin_os/logic/tag_model.dart';
import 'package:vittara_fin_os/logic/tags_controller.dart';
import 'package:vittara_fin_os/logic/transactions_controller.dart';
import 'package:vittara_fin_os/logic/transaction_model.dart';
import 'package:vittara_fin_os/logic/recurring_template_model.dart';
import 'package:vittara_fin_os/logic/recurring_templates_controller.dart';
import 'package:vittara_fin_os/services/sms_service.dart';
import 'package:vittara_fin_os/ui/manage/account_wizard.dart';
import 'package:vittara_fin_os/ui/manage/categories/category_creation_modal.dart';
import 'package:vittara_fin_os/ui/manage/payment_apps_screen.dart';
import 'package:vittara_fin_os/ui/manage/transfer_wizard.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/utils/form_validators.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/widgets/animations.dart';
import 'package:vittara_fin_os/ui/widgets/app_date_picker.dart';
import 'package:vittara_fin_os/ui/widgets/common_widgets.dart';
import 'package:vittara_fin_os/ui/widgets/toast_notification.dart' as toast_lib;
import 'package:vittara_fin_os/ui/styles/responsive_utils.dart';

enum TransactionWizardBranch { expense, income, transfer }

enum TransactionPaymentType { cash, upi, card, bank, wallet }

class TransactionWizard extends StatefulWidget {
  final Transaction? cloneFrom;
  final SmsParseResult? prefillFromSms;
  final TransactionWizardBranch? initialBranch;

  const TransactionWizard({super.key, this.cloneFrom, this.prefillFromSms, this.initialBranch});

  @override
  State<TransactionWizard> createState() => _TransactionWizardState();
}

class _TransactionWizardState extends State<TransactionWizard> {
  static const int _totalSteps = 12;
  late PageController _pageController;
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _cashbackController = TextEditingController();
  final TextEditingController _appWalletAmountController =
      TextEditingController();
  final TextEditingController _categorySearchController =
      TextEditingController();
  final TextEditingController _merchantController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _tagController = TextEditingController();
  final List<int> _history = [0];
  bool _amountError = false;

  TransactionWizardBranch? _branch;
  TransactionPaymentType? _paymentType;
  Account? _selectedAccount;
  String? _selectedPaymentApp;
  bool _paymentAppHasWallet = false;
  double _selectedPaymentAppWalletBalance = 0;
  DateTime _selectedDate = DateTime.now();
  bool _cashbackToApp = true;
  Category? _selectedCategory;
  final List<String> _selectedTags = [];
  String? _selectedTaxTag; // e.g. "80C", "80D", "HRA", etc.

  @override
  void dispose() {
    _pageController.dispose();
    _amountController.dispose();
    _cashbackController.dispose();
    _appWalletAmountController.dispose();
    _categorySearchController.dispose();
    _merchantController.dispose();
    _descriptionController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  void _selectBranch(TransactionWizardBranch branch) {
    if (!mounted) return;
    if (branch == TransactionWizardBranch.transfer) {
      // Use push (not pushReplacement) so back from TransferWizard
      // returns to the wizard branch selector, not the previous screen.
      Navigator.of(context).push(
        FadeScalePageRoute(page: const TransferWizard()),
      );
      return;
    }
    setState(() {
      _branch = branch;
    });
    _nextStep();
  }

  void _navigateToStep(int step, {bool record = true}) {
    FocusManager.instance.primaryFocus?.unfocus();
    if (step < 0) return; // lower-bounds guard
    if (step >= _totalSteps) {
      _completeTransaction();
      return;
    }
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
    );
    setState(() {
      _currentStep = step;
      if (record && (_history.isEmpty || _history.last != step)) {
        _history.add(step);
      }
    });
  }

  int _currentStep = 0; // overwritten in initState when initialBranch is set

  bool get _hasValidAmount {
    final v = double.tryParse(_amountController.text) ?? 0;
    return v > 0 && v <= kMaxAmountINR;
  }

  void _tryAdvanceFromAmount() {
    if (_hasValidAmount) {
      _nextStep();
    }
  }

  void _showCalculator(BuildContext context) {
    String display =
        _amountController.text.isNotEmpty ? _amountController.text : '0';
    String? pendingOp;
    double? pendingValue;
    bool justEvaled = false;

    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => RLayout.tabletConstrain(
        ctx,
        StatefulBuilder(
        builder: (ctx, setS) {
          final isDark = AppStyles.isDarkMode(ctx);
          final btnBg =
              isDark ? const Color(0xFF2C2C2E) : CupertinoColors.systemGrey6;
          final opColor = _branch == TransactionWizardBranch.income
              ? AppStyles.gain(ctx)
              : _branch == TransactionWizardBranch.expense
                  ? AppStyles.loss(ctx)
                  : CupertinoColors.systemBlue;

          void onDigit(String d) => setS(() {
                if (justEvaled || display == '0') {
                  display = d;
                  justEvaled = false;
                } else {
                  display += d;
                }
              });

          void onDecimal() => setS(() {
                if (justEvaled) {
                  display = '0.';
                  justEvaled = false;
                } else if (!display.contains('.')) {
                  display += '.';
                }
              });

          void onOp(String op) => setS(() {
                pendingValue = double.tryParse(display) ?? 0;
                pendingOp = op;
                justEvaled = true;
              });

          void onEquals() {
            if (pendingOp == null || pendingValue == null) return;
            final cur = double.tryParse(display) ?? 0;
            double r;
            switch (pendingOp) {
              case '+':
                r = pendingValue! + cur;
              case '-':
                r = pendingValue! - cur;
              case '×':
                r = pendingValue! * cur;
              case '÷':
                r = cur != 0 ? pendingValue! / cur : 0;
              default:
                r = cur;
            }
            setS(() {
              display = r == r.truncateToDouble()
                  ? r.toStringAsFixed(0)
                  : r.toStringAsFixed(2);
              pendingOp = null;
              pendingValue = null;
              justEvaled = true;
            });
          }

          void onClear() => setS(() {
                display = '0';
                pendingOp = null;
                pendingValue = null;
                justEvaled = false;
              });

          void onBack() => setS(() {
                if (display.length > 1) {
                  display = display.substring(0, display.length - 1);
                } else {
                  display = '0';
                }
              });

          Widget btn(String label,
              {VoidCallback? onTap, Color? bg, Color? fg, bool wide = false}) {
            return Expanded(
              flex: wide ? 2 : 1,
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: CupertinoButton(
                  padding: EdgeInsets.zero,
                  color: bg ?? btnBg,
                  borderRadius: BorderRadius.circular(Radii.md),
                  minimumSize: const Size(0, 52),
                  onPressed: onTap ?? () {},
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: TypeScale.title3,
                      fontWeight: FontWeight.w600,
                      color: fg ?? AppStyles.getTextColor(ctx),
                    ),
                  ),
                ),
              ),
            );
          }

          return Container(
            height: AppStyles.sheetMaxHeight(ctx),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C1C1E) : CupertinoColors.white,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  const ModalHandle(),
                  const SizedBox(height: 4),
                  if (pendingOp != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '₹$pendingValue $pendingOp',
                          style: TextStyle(
                            color: AppStyles.getSecondaryTextColor(ctx),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '₹$display',
                        style: TextStyle(
                          fontSize: 38,
                          fontWeight: FontWeight.bold,
                          color: AppStyles.getTextColor(ctx),
                        ),
                      ),
                    ),
                  ),
                  Divider(color: AppStyles.getDividerColor(ctx), height: 1),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Column(
                        children: [
                          Row(children: [
                            btn('C',
                                onTap: onClear,
                                bg: AppStyles.loss(ctx)
                                    .withValues(alpha: 0.12),
                                fg: AppStyles.loss(ctx)),
                            btn('←', onTap: onBack),
                            btn('÷',
                                onTap: () => onOp('÷'),
                                bg: opColor.withValues(alpha: 0.12),
                                fg: opColor),
                            btn('×',
                                onTap: () => onOp('×'),
                                bg: opColor.withValues(alpha: 0.12),
                                fg: opColor),
                          ]),
                          Row(children: [
                            btn('7', onTap: () => onDigit('7')),
                            btn('8', onTap: () => onDigit('8')),
                            btn('9', onTap: () => onDigit('9')),
                            btn('-',
                                onTap: () => onOp('-'),
                                bg: opColor.withValues(alpha: 0.12),
                                fg: opColor),
                          ]),
                          Row(children: [
                            btn('4', onTap: () => onDigit('4')),
                            btn('5', onTap: () => onDigit('5')),
                            btn('6', onTap: () => onDigit('6')),
                            btn('+',
                                onTap: () => onOp('+'),
                                bg: opColor.withValues(alpha: 0.12),
                                fg: opColor),
                          ]),
                          Row(children: [
                            btn('1', onTap: () => onDigit('1')),
                            btn('2', onTap: () => onDigit('2')),
                            btn('3', onTap: () => onDigit('3')),
                            btn('=',
                                onTap: onEquals,
                                bg: opColor.withValues(alpha: 0.15),
                                fg: opColor),
                          ]),
                          Row(children: [
                            btn('0', onTap: () => onDigit('0'), wide: true),
                            btn('.', onTap: onDecimal),
                            btn('✓', onTap: () {
                              onEquals();
                              final val = double.tryParse(display) ?? 0;
                              if (val > 0) {
                                _amountController.text =
                                    val == val.truncateToDouble()
                                        ? val.toStringAsFixed(0)
                                        : val.toStringAsFixed(2);
                                setState(() {});
                              }
                              Navigator.pop(ctx);
                            }, bg: opColor, fg: CupertinoColors.white),
                          ]),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      ),
    );
  }

  static const _lastCategoryKey = 'last_used_category_id';

  @override
  void initState() {
    super.initState();
    _amountController.addListener(() {
      setState(() {
        final text = _amountController.text;
        if (text.isNotEmpty) {
          final parsed = double.tryParse(text) ?? 0;
          _amountError = parsed <= 0;
        } else {
          _amountError = false;
        }
      });
    });
    final sms = widget.prefillFromSms;
    // When a branch is pre-selected (e.g. from Quick Add), skip step 0
    // entirely — the PageController starts on page 1 so there is no flash.
    final startStep =
        (widget.initialBranch != null && sms == null) ? 1 : 0;
    _currentStep = startStep;
    _pageController = PageController(initialPage: startStep);
    if (startStep > 0) {
      _history
        ..clear()
        ..add(startStep);
    }
    if (widget.initialBranch != null && sms == null) {
      _branch = widget.initialBranch;
    }
    if (sms != null) {
      _amountController.text = sms.parsed.amount.toStringAsFixed(2);
      _branch = sms.parsed.type == 'income'
          ? TransactionWizardBranch.income
          : TransactionWizardBranch.expense;
      if (sms.parsed.merchant != null) {
        _merchantController.text = sms.parsed.merchant!;
      }
      if (sms.parsed.upiId != null) {
        _descriptionController.text = sms.parsed.upiId!;
      }
      _selectedDate = sms.parsed.date;
    }
    final clone = widget.cloneFrom;
    if (clone != null) {
      _amountController.text = clone.amount.toStringAsFixed(2);
      _branch = clone.type == TransactionType.income
          ? TransactionWizardBranch.income
          : TransactionWizardBranch.expense;
      final meta = clone.metadata ?? {};
      _merchantController.text = (meta['merchant'] as String?) ?? '';
      _descriptionController.text = clone.description;
      final tags = meta['tags'];
      if (tags is List) _selectedTags.addAll(tags.cast<String>());
      _selectedTaxTag = meta['taxTag'] as String?;
      final ptName = meta['paymentType'] as String?;
      if (ptName != null) {
        _paymentType = TransactionPaymentType.values.firstWhere(
          (e) => e.name == ptName,
          orElse: () => TransactionPaymentType.upi,
        );
      }
      _selectedPaymentApp = meta['paymentApp'] as String?;
      // Category and account resolved in postFrameCallback
    }
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _restoreOrCloneCategory());
  }

  Future<void> _restoreOrCloneCategory() async {
    // Prefill from SMS: resolve matched account
    final sms = widget.prefillFromSms;
    if (sms != null) {
      if (sms.matchedAccount != null && mounted) {
        final accts = Provider.of<AccountsController>(context, listen: false);
        final match = accts.accounts
            .where((a) => a.id == sms.matchedAccount!.id)
            .firstOrNull;
        if (match != null) setState(() => _selectedAccount = match);
      }
      await _restoreLastCategory();
      return;
    }
    final clone = widget.cloneFrom;
    if (clone != null) {
      final meta = clone.metadata ?? {};
      final catId = meta['categoryId'] as String?;
      final accountId = meta['accountId'] as String?;
      if (!mounted) return;
      if (catId != null) {
        final cats = Provider.of<CategoriesController>(context, listen: false);
        final match = cats.categories.where((c) => c.id == catId).firstOrNull;
        if (match != null) setState(() => _selectedCategory = match);
      }
      if (accountId != null) {
        final accts = Provider.of<AccountsController>(context, listen: false);
        final match =
            accts.accounts.where((a) => a.id == accountId).firstOrNull;
        if (match != null) setState(() => _selectedAccount = match);
      }
      return;
    }
    await _restoreLastCategory();
  }

  Future<void> _restoreLastCategory() async {
    final prefs = await SharedPreferences.getInstance();
    final lastId = prefs.getString(_lastCategoryKey);
    if (lastId == null || !mounted) return;
    final controller =
        Provider.of<CategoriesController>(context, listen: false);
    final match =
        controller.categories.where((c) => c.id == lastId).firstOrNull;
    if (match != null && mounted) {
      setState(() => _selectedCategory = match);
    }
  }

  Future<void> _saveLastCategory(Category category) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastCategoryKey, category.id);
  }

  void _nextStep() {
    FocusManager.instance.primaryFocus?.unfocus();
    final next = _nextStepIndex(_currentStep);
    if (next >= _totalSteps) {
      _completeTransaction();
    } else {
      _navigateToStep(next);
    }
  }

  void _previousStep() {
    if (_history.length <= 1) {
      // If the user has entered any data, confirm before discarding
      final hasChanges = _amountController.text.isNotEmpty ||
          _merchantController.text.isNotEmpty ||
          _descriptionController.text.isNotEmpty;
      if (hasChanges) {
        showCupertinoDialog<bool>(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: const Text('Discard changes?'),
            content: const Text(
                'You have unsaved changes. Discard this transaction?'),
            actions: [
              CupertinoDialogAction(
                child: const Text('Keep editing'),
                onPressed: () => Navigator.pop(ctx, false),
              ),
              CupertinoDialogAction(
                isDestructiveAction: true,
                child: const Text('Discard'),
                onPressed: () => Navigator.pop(ctx, true),
              ),
            ],
          ),
        ).then((discard) {
          if (discard == true && mounted && Navigator.canPop(context)) {
            Navigator.pop(context);
          }
        });
        return;
      }
      if (Navigator.canPop(context)) Navigator.pop(context);
      return;
    }
    _history.removeLast();
    final previous = _history.last;
    _navigateToStep(previous, record: false);
  }

  int _nextStepIndex(int current) {
    switch (current) {
      case 0:
        return 1;
      case 1:
        return 2;
      case 2:
        return 3;
      case 3:
        if (_paymentType == TransactionPaymentType.cash &&
            _selectedAccount != null) {
          // Cash account was auto-selected; skip account step
          return 7;
        }
        return 4;
      case 4:
        return 5;
      case 5:
        return _paymentAppHasWallet ? 6 : 7;
      case 6:
        return 7;
      case 7:
        return 8;
      case 8:
        return 9;
      case 9:
        // Auto-skip Tags step if no tags exist in the system
        final tagsController =
            Provider.of<TagsController>(context, listen: false);
        if (tagsController.tags.isEmpty) return 11;
        return 10;
      case 10:
        return 11;
      case 11:
        return 12;
      default:
        return current + 1;
    }
  }

  Future<void> _completeTransaction() async {
    final transactionsController =
        Provider.of<TransactionsController>(context, listen: false);
    final amount = double.tryParse(_amountController.text) ?? 0;
    if (amount <= 0) {
      toast_lib.toast.showError('Please enter a valid amount');
      _navigateToStep(1);
      return;
    }

    // J14: Duplicate transaction detection (merchant-based, within 30 min)
    final merchant = _merchantController.text.trim();
    if (merchant.isNotEmpty) {
      final cutoff = DateTime.now().subtract(const Duration(minutes: 30));
      final duplicate = transactionsController.transactions.where((t) {
        final tMerchant = t.metadata?['merchant'] as String? ?? '';
        return t.amount == amount &&
            tMerchant.toLowerCase() == merchant.toLowerCase() &&
            t.dateTime.isAfter(cutoff);
      }).firstOrNull;
      if (duplicate != null) {
        if (!mounted) return;
        final proceed = await showCupertinoDialog<bool>(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: const Text('Possible Duplicate'),
            content: Text(
                'A ₹${amount.toStringAsFixed(2)} transaction at "$merchant" was logged within the last 30 minutes. Add anyway?'),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              CupertinoDialogAction(
                isDefaultAction: true,
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Add Anyway'),
              ),
            ],
          ),
        );
        if (proceed != true || !mounted) return;
      }
    }

    // Duplicate detection by amount + type + date ±1 day (when no merchant)
    if (merchant.isEmpty) {
      final txType = _branch == TransactionWizardBranch.income
          ? TransactionType.income
          : TransactionType.expense;
      final dayStart = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
      ).subtract(const Duration(days: 1));
      final dayEnd = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
      ).add(const Duration(days: 2));
      final dateTypeDuplicate = transactionsController.transactions.where((t) =>
          t.amount == amount &&
          t.type == txType &&
          t.dateTime.isAfter(dayStart) &&
          t.dateTime.isBefore(dayEnd)).firstOrNull;
      if (dateTypeDuplicate != null) {
        if (!mounted) return;
        final proceed = await showCupertinoDialog<bool>(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: const Text('Possible Duplicate'),
            content: const Text(
                'A similar transaction (same amount, same date) already exists. Add anyway?'),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              CupertinoDialogAction(
                isDefaultAction: true,
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Add Anyway'),
              ),
            ],
          ),
        );
        if (proceed != true || !mounted) return;
      }
    }

    final metadata = <String, dynamic>{
      'paymentType': _paymentType?.name,
      'categoryId': _selectedCategory?.id,
      'categoryName': _selectedCategory?.name,
      'merchant': _merchantController.text,
      'description': _descriptionController.text,
      'tags': _selectedTags,
      'accountId': _selectedAccount?.id,
      'accountName': _selectedAccount?.name,
      'paymentApp': _selectedPaymentApp,
      'cashbackAmount': double.tryParse(_cashbackController.text) ?? 0,
      'cashbackFlow': _cashbackToApp ? 'paymentApp' : 'bank',
      'appWalletAmount': double.tryParse(_appWalletAmountController.text) ?? 0,
      if (_selectedTaxTag != null) 'taxTag': _selectedTaxTag,
    };

    final accountsController =
        Provider.of<AccountsController>(context, listen: false);
    final paymentAppsController =
        Provider.of<PaymentAppsController>(context, listen: false);

    final appWalletUsedRaw =
        double.tryParse(_appWalletAmountController.text.trim()) ?? 0.0;
    final appWalletUsed = appWalletUsedRaw.clamp(0.0, amount).toDouble();
    final cashbackAmount = double.tryParse(_cashbackController.text) ?? 0;
    final accountPortion = (_branch == TransactionWizardBranch.expense &&
            _selectedPaymentApp != null)
        ? (amount - appWalletUsed).clamp(0.0, amount).toDouble()
        : amount;

    if (appWalletUsedRaw > appWalletUsed) {
      toast_lib.toast
          .showError('App wallet amount cannot exceed transaction amount');
      return;
    }

    if (appWalletUsed > _selectedPaymentAppWalletBalance) {
      toast_lib.toast.showError('App wallet amount exceeds available balance');
      return;
    }

    if (_branch == TransactionWizardBranch.expense &&
        _selectedAccount != null &&
        accountPortion > _selectedAccount!.balance) {
      toast_lib.toast
          .showError('Selected account does not have enough balance');
      return;
    }

    if (_selectedAccount != null) {
      final account = _selectedAccount!;
      final balanceDelta =
          _branch == TransactionWizardBranch.expense ? -accountPortion : amount;
      final updatedAccount =
          account.copyWith(balance: account.balance + balanceDelta);
      await accountsController.updateAccount(updatedAccount);
    }

    if (_branch == TransactionWizardBranch.expense &&
        appWalletUsed > 0 &&
        _selectedPaymentApp != null) {
      await paymentAppsController.adjustWalletBalanceByName(
          _selectedPaymentApp!, -appWalletUsed);
    }

    if (cashbackAmount > 0) {
      if (_cashbackToApp && _selectedPaymentApp != null) {
        await paymentAppsController.adjustWalletBalanceByName(
            _selectedPaymentApp!, cashbackAmount);
      } else if (_selectedAccount != null) {
        final refreshed = accountsController.accounts.firstWhere(
            (acc) => acc.id == _selectedAccount!.id,
            orElse: () => throw Exception('Account not found'));
        await accountsController.updateAccount(
          refreshed.copyWith(balance: refreshed.balance + cashbackAmount),
        );
      }
    }

    // Snapshot balance after transaction for historical display
    if (_selectedAccount != null) {
      final snapped = accountsController.accounts
          .firstWhere((a) => a.id == _selectedAccount!.id,
              orElse: () => _selectedAccount!);
      metadata['sourceBalanceAfter'] = snapped.balance;
      if (snapped.creditLimit != null) {
        metadata['sourceCreditLimit'] = snapped.creditLimit;
      }
    }

    final transaction = Transaction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: _branch == TransactionWizardBranch.income
          ? TransactionType.income
          : TransactionType.expense,
      description: _descriptionController.text.isNotEmpty
          ? _descriptionController.text
          : _selectedCategory?.name ?? 'Transaction',
      dateTime: _selectedDate,
      amount: amount,
      sourceAccountId: _selectedAccount?.id,
      sourceAccountName: _selectedAccount?.name,
      paymentAppName: _selectedPaymentApp,
      appWalletAmount: appWalletUsed > 0 ? appWalletUsed : null,
      cashbackAmount: cashbackAmount > 0 ? cashbackAmount : null,
      cashbackAccountId: (!_cashbackToApp && _selectedAccount != null)
          ? _selectedAccount!.id
          : null,
      cashbackAccountName: (!_cashbackToApp && _selectedAccount != null)
          ? _selectedAccount!.name
          : null,
      metadata: metadata,
    );

    await transactionsController.addTransaction(transaction);
    HapticFeedback.heavyImpact();
    toast_lib.toast.showSuccess('Transaction logged');
    if (mounted && Navigator.canPop(context)) Navigator.pop(context);
  }

  Widget _buildStepShell({
    required String title,
    required Widget child,
    Widget? trailing,
    Widget? footer,
  }) {
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: AppStyles.landscapeContentConstraints(context),
          child: Padding(
            padding: const EdgeInsets.only(
              left: Spacing.lg,
              right: Spacing.lg,
              top: Spacing.lg,
              bottom: Spacing.xl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: AppStyles.titleStyle(context).copyWith(
                          fontSize: TypeScale.title1,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                      ),
                    ),
                    if (trailing != null) trailing,
                  ],
                ),
                const SizedBox(height: Spacing.lg),
                Expanded(child: child),
                if (footer != null) footer,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    final branch = _branch;
    final Color barColor = branch == TransactionWizardBranch.income
        ? AppStyles.gain(context)
        : branch == TransactionWizardBranch.expense
            ? AppStyles.loss(context)
            : CupertinoColors.systemBlue;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                branch == null ? 'New Transaction' : branch.name.capitalize(),
                style: TextStyle(
                  fontSize: TypeScale.callout,
                  fontWeight: FontWeight.w700,
                  color: barColor,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: barColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${(_currentStep + 1).clamp(1, _totalSteps)} / $_totalSteps',
                  style: TextStyle(
                    fontSize: TypeScale.caption,
                    fontWeight: FontWeight.w600,
                    color: barColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.md),
          // Elevated segmented capsule progress
          Row(
            children: List.generate(_totalSteps, (i) {
              final isDone = i < _currentStep;
              final isCurrent = i == _currentStep;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    height: isCurrent ? 8 : 6,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: (isDone || isCurrent)
                          ? barColor.withValues(alpha: isCurrent ? 1.0 : 0.65)
                          : barColor.withValues(alpha: 0.10),
                      boxShadow: isCurrent
                          ? [
                              BoxShadow(
                                color: barColor.withValues(alpha: 0.6),
                                blurRadius: 8,
                                spreadRadius: 0,
                                offset: const Offset(0, 2),
                              ),
                              BoxShadow(
                                color: barColor.withValues(alpha: 0.3),
                                blurRadius: 16,
                                spreadRadius: 2,
                                offset: const Offset(0, 1),
                              ),
                            ]
                          : isDone
                              ? [
                                  BoxShadow(
                                    color: barColor.withValues(alpha: 0.2),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ]
                              : [],
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: AppStyles.isLandscape(context) ? null : CupertinoNavigationBar(
        middle: const Text('Transaction Wizard'),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _previousStep,
          child: Icon(
            _currentStep == 0 ? CupertinoIcons.xmark : CupertinoIcons.back,
            color: AppStyles.getTextColor(context),
          ),
        ),
        backgroundColor: AppStyles.getBackground(context),
        border: null,
      ),
      child: SafeArea(
        child: Column(
          children: [
            _buildProgressBar(),
            const SizedBox(height: Spacing.md),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _totalSteps,
                itemBuilder: (context, index) {
                  switch (index) {
                    case 0:
                      return _buildBranchPage();
                    case 1:
                      return _buildAmountPage();
                    case 2:
                      return _buildDatePage();
                    case 3:
                      return _buildPaymentTypePage();
                    case 4:
                      return _buildAccountPage();
                    case 5:
                      return _buildPaymentAppPage();
                    case 6:
                      return _buildCashbackPage();
                    case 7:
                      return _buildCategoryPage();
                    case 8:
                      return _buildMerchantPage();
                    case 9:
                      return _buildDescriptionPage();
                    case 10:
                      return _buildTagsPage();
                    case 11:
                      return _buildReviewPage();
                    default:
                      return const SizedBox.shrink();
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBranchPage() {
    final templatesController = context.watch<RecurringTemplatesController>();
    final templates = templatesController.templates;

    return _buildStepShell(
      title: 'What type of transaction?',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBranchButton(
            label: 'Expense',
            icon: CupertinoIcons.arrow_down_circle_fill,
            color: AppStyles.loss(context),
            onTap: () => _selectBranch(TransactionWizardBranch.expense),
          ),
          _buildBranchButton(
            label: 'Income',
            icon: CupertinoIcons.arrow_up_circle_fill,
            color: AppStyles.gain(context),
            onTap: () => _selectBranch(TransactionWizardBranch.income),
          ),
          _buildBranchButton(
            label: 'Transfer',
            icon: CupertinoIcons.arrow_right_arrow_left,
            color: CupertinoColors.systemBlue,
            onTap: () => _selectBranch(TransactionWizardBranch.transfer),
          ),
          if (templates.isNotEmpty) ...[
            const SizedBox(height: Spacing.xl),
            Row(
              children: [
                Text(
                  'Recurring Templates',
                  style: TextStyle(
                    fontSize: TypeScale.footnote,
                    fontWeight: FontWeight.w700,
                    color: AppStyles.getSecondaryTextColor(context),
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => _showManageTemplatesSheet(templatesController),
                  child: Text(
                    'Manage',
                    style: TextStyle(
                      fontSize: TypeScale.footnote,
                      color: AppStyles.getPrimaryColor(context),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Spacing.sm),
            Wrap(
              spacing: Spacing.sm,
              runSpacing: Spacing.sm,
              children: templates.map((t) {
                final daysUntil = t.daysUntilDue();
                final isDue = daysUntil != null && daysUntil <= 0;
                final color = t.branch == 'income'
                    ? AppStyles.gain(context)
                    : AppStyles.loss(context);
                return GestureDetector(
                  onTap: () => _applyTemplate(t, templatesController),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: Spacing.md, vertical: Spacing.sm),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDue
                            ? color.withValues(alpha: 0.6)
                            : color.withValues(alpha: 0.25),
                        width: isDue ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isDue
                              ? CupertinoIcons.bell_fill
                              : CupertinoIcons.repeat,
                          size: 12,
                          color: color,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          t.name,
                          style: TextStyle(
                            fontSize: TypeScale.footnote,
                            fontWeight: FontWeight.w600,
                            color: color,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '₹${t.amount % 1 == 0 ? t.amount.toStringAsFixed(0) : t.amount.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: TypeScale.caption,
                            color: color.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  void _applyTemplate(RecurringTemplate t, RecurringTemplatesController ctrl) {
    _amountController.text = t.amount % 1 == 0
        ? t.amount.toStringAsFixed(0)
        : t.amount.toStringAsFixed(2);
    _branch = t.branch == 'income'
        ? TransactionWizardBranch.income
        : TransactionWizardBranch.expense;
    if (t.merchant != null) _merchantController.text = t.merchant!;
    if (t.description != null) _descriptionController.text = t.description!;
    _selectedTags.clear();
    _selectedTags.addAll(t.tags);
    if (t.paymentType != null) {
      _paymentType = TransactionPaymentType.values
              .where((e) => e.name == t.paymentType)
              .firstOrNull ??
          _paymentType;
    }
    _selectedPaymentApp = t.paymentApp;
    // Resolve category and account in postFrame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (t.categoryId != null) {
        final cats = Provider.of<CategoriesController>(context, listen: false);
        final cat =
            cats.categories.where((c) => c.id == t.categoryId).firstOrNull;
        if (cat != null) setState(() => _selectedCategory = cat);
      }
      if (t.accountId != null) {
        final accts = Provider.of<AccountsController>(context, listen: false);
        final acct =
            accts.accounts.where((a) => a.id == t.accountId).firstOrNull;
        if (acct != null) setState(() => _selectedAccount = acct);
      }
    });
    setState(() {});
    ctrl.markUsed(t.id);
    _nextStep();
  }

  void _showSaveTemplateSheet() {
    final nameController = TextEditingController(
      text: _merchantController.text.isNotEmpty
          ? _merchantController.text
          : _selectedCategory?.name ?? '',
    );
    String frequency = 'monthly';

    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => RLayout.tabletConstrain(
        ctx,
        StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          padding: EdgeInsets.only(
            left: Spacing.xl,
            right: Spacing.xl,
            top: Spacing.xl,
            bottom: Spacing.xl + MediaQuery.of(ctx).viewInsets.bottom,
          ),
          decoration: BoxDecoration(
            color: AppStyles.getCardColor(ctx),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(child: ModalHandle()),
                const SizedBox(height: Spacing.xl),
                Text('Save Recurring Template',
                    style: AppStyles.titleStyle(ctx)),
                const SizedBox(height: Spacing.lg),
                Text('Template name',
                    style: TextStyle(
                        color: AppStyles.getSecondaryTextColor(ctx),
                        fontSize: TypeScale.footnote)),
                const SizedBox(height: Spacing.xs),
                CupertinoTextField(
                  controller: nameController,
                  placeholder: 'e.g. Netflix, Rent, Salary…',
                  padding: const EdgeInsets.all(Spacing.md),
                  decoration: BoxDecoration(
                    color: AppStyles.getBackground(ctx),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  style: TextStyle(color: AppStyles.getTextColor(ctx)),
                ),
                const SizedBox(height: Spacing.lg),
                Text('Frequency',
                    style: TextStyle(
                        color: AppStyles.getSecondaryTextColor(ctx),
                        fontSize: TypeScale.footnote)),
                const SizedBox(height: Spacing.xs),
                Row(
                  children: [
                    for (final f in ['daily', 'weekly', 'monthly', 'yearly'])
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setModalState(() => frequency = f),
                          child: Container(
                            margin:
                                EdgeInsets.only(right: f == 'yearly' ? 0 : 6),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: frequency == f
                                  ? AppStyles.getPrimaryColor(ctx)
                                      .withValues(alpha: 0.15)
                                  : AppStyles.getBackground(ctx),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: frequency == f
                                    ? AppStyles.getPrimaryColor(ctx)
                                    : AppStyles.getSecondaryTextColor(ctx)
                                        .withValues(alpha: 0.2),
                              ),
                            ),
                            child: Text(
                              f[0].toUpperCase() + f.substring(1),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: TypeScale.caption,
                                fontWeight: frequency == f
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                                color: frequency == f
                                    ? AppStyles.getPrimaryColor(ctx)
                                    : AppStyles.getSecondaryTextColor(ctx),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: Spacing.xl),
                SizedBox(
                  width: double.infinity,
                  child: CupertinoButton.filled(
                    onPressed: () {
                      final name = nameController.text.trim();
                      if (name.isEmpty) return;
                      final amount =
                          double.tryParse(_amountController.text) ?? 0;
                      // Compute next due date
                      final now = DateTime.now();
                      DateTime nextDue;
                      switch (frequency) {
                        case 'daily':
                          nextDue = now.add(const Duration(days: 1));
                          break;
                        case 'weekly':
                          nextDue = now.add(const Duration(days: 7));
                          break;
                        case 'yearly':
                          nextDue = DateTime(now.year + 1, now.month, now.day);
                          break;
                        default:
                          nextDue = DateTime(now.year, now.month + 1, now.day);
                      }
                      final template = RecurringTemplate(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        name: name,
                        branch: _branch == TransactionWizardBranch.income
                            ? 'income'
                            : 'expense',
                        amount: amount,
                        categoryId: _selectedCategory?.id,
                        categoryName: _selectedCategory?.name,
                        accountId: _selectedAccount?.id,
                        accountName: _selectedAccount?.name,
                        paymentType: _paymentType?.name,
                        paymentApp: _selectedPaymentApp,
                        merchant: _merchantController.text.isNotEmpty
                            ? _merchantController.text
                            : null,
                        description: _descriptionController.text.isNotEmpty
                            ? _descriptionController.text
                            : null,
                        tags: List.from(_selectedTags),
                        frequency: frequency,
                        nextDueDate: nextDue,
                        createdAt: now,
                      );
                      Provider.of<RecurringTemplatesController>(context,
                              listen: false)
                          .addTemplate(template);
                      Navigator.pop(ctx);
                      toast_lib.toast.showSuccess('Template "$name" saved');
                    },
                    child: const Text('Save Template'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    ).whenComplete(nameController.dispose);
  }

  void _showManageTemplatesSheet(RecurringTemplatesController ctrl) {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => RLayout.tabletConstrain(
        ctx,
        Container(
        decoration: BoxDecoration(
          color: AppStyles.getCardColor(ctx),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: Spacing.lg),
              const ModalHandle(),
              const SizedBox(height: Spacing.lg),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Spacing.xl),
                child: Text('Recurring Templates',
                    style: AppStyles.titleStyle(ctx)),
              ),
              const SizedBox(height: Spacing.md),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: ctrl.templates.length,
                  itemBuilder: (_, i) {
                    final t = ctrl.templates[i];
                    final color = t.branch == 'income'
                        ? AppStyles.gain(ctx)
                        : AppStyles.loss(ctx);
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: Spacing.xl, vertical: Spacing.xs),
                      child: Row(
                        children: [
                          Icon(CupertinoIcons.repeat, size: 16, color: color),
                          const SizedBox(width: Spacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(t.name,
                                    style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: AppStyles.getTextColor(ctx))),
                                Text(
                                    '₹${t.amount.toStringAsFixed(0)} • ${t.frequency}',
                                    style: TextStyle(
                                        fontSize: TypeScale.caption,
                                        color: AppStyles.getSecondaryTextColor(
                                            ctx))),
                              ],
                            ),
                          ),
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            onPressed: () {
                              ctrl.deleteTemplate(t.id);
                              Navigator.pop(ctx);
                            },
                            child: Icon(CupertinoIcons.trash,
                                size: 18, color: AppStyles.loss(ctx)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: Spacing.lg),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildBranchButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.md),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: Spacing.lg, vertical: Spacing.xl),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withValues(alpha: 0.18),
                color.withValues(alpha: 0.06),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border:
                Border.all(color: color.withValues(alpha: 0.35), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.12),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withValues(alpha: 0.25)),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: Spacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: TypeScale.title3,
                        fontWeight: FontWeight.w700,
                        color: AppStyles.getTextColor(context),
                      ),
                    ),
                    const SizedBox(height: Spacing.xxs),
                    Text(
                      label == 'Expense'
                          ? 'Track money going out'
                          : label == 'Income'
                              ? 'Record money coming in'
                              : 'Move between accounts',
                      style: TextStyle(
                        fontSize: TypeScale.footnote,
                        color: color.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(CupertinoIcons.arrow_right_circle_fill,
                  color: color.withValues(alpha: 0.7), size: 22),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAmountPage() {
    return _buildStepShell(
      title: 'How much?',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Enter the transaction amount',
            style: TextStyle(
              color: AppStyles.getSecondaryTextColor(context),
              fontSize: TypeScale.subhead,
            ),
          ),
          const SizedBox(height: Spacing.xxl),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: Spacing.xl, vertical: Spacing.xl),
            decoration: BoxDecoration(
              color: AppStyles.getCardColor(context),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _amountError
                    ? AppStyles.loss(context)
                    : (_branch == TransactionWizardBranch.income
                            ? AppStyles.gain(context)
                            : _branch == TransactionWizardBranch.expense
                                ? AppStyles.loss(context)
                                : CupertinoColors.systemBlue)
                        .withValues(alpha: 0.25),
                width: _amountError ? 1.5 : 1.0,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () => _showCalculator(context),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '₹',
                        style: TextStyle(
                          fontSize: TypeScale.displayLarge,
                          fontWeight: FontWeight.w800,
                          color: _branch == TransactionWizardBranch.income
                              ? AppStyles.gain(context)
                              : _branch == TransactionWizardBranch.expense
                                  ? AppStyles.loss(context)
                                  : CupertinoColors.systemBlue,
                        ),
                      ),
                      Text(
                        'calc',
                        style: TextStyle(
                          fontSize: 8,
                          color: AppStyles.getSecondaryTextColor(context)
                              .withValues(alpha: 0.6),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: Spacing.sm),
                Expanded(
                  child: CupertinoTextField(
                    controller: _amountController,
                    autofocus: _currentStep == 1,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    textInputAction: TextInputAction.done,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(kAmountInputRegex),
                    ],
                    onChanged: (_) {
                      if (_amountError) setState(() => _amountError = false);
                    },
                    onSubmitted: (_) => _tryAdvanceFromAmount(),
                    placeholder: '0',
                    placeholderStyle: TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.w800,
                      color: AppStyles.getSecondaryTextColor(context)
                          .withValues(alpha: 0.3),
                    ),
                    style: TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.w800,
                      color: AppStyles.getTextColor(context),
                    ),
                    decoration: null,
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),
          if (_amountError) ...[
            const SizedBox(height: Spacing.sm),
            Row(
              children: [
                Icon(
                  CupertinoIcons.exclamationmark_circle,
                  size: 14,
                  color: AppStyles.loss(context),
                ),
                const SizedBox(width: 6),
                Text(
                  'Amount must be greater than ₹0',
                  style: TextStyle(
                    fontSize: TypeScale.footnote,
                    color: AppStyles.loss(context),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: Spacing.lg),
          // Quick amount shortcuts
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final preset in [
                  ('+10', 10.0),
                  ('+50', 50.0),
                  ('+100', 100.0),
                  ('+200', 200.0),
                  ('+500', 500.0),
                  ('+1K', 1000.0),
                  ('+2K', 2000.0),
                  ('+5K', 5000.0),
                  ('+10K', 10000.0),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: Spacing.sm),
                    child: CupertinoButton(
                      padding: const EdgeInsets.symmetric(
                          horizontal: Spacing.lg, vertical: Spacing.sm),
                      color: AppStyles.getCardColor(context),
                      borderRadius: BorderRadius.circular(20),
                      minimumSize: Size.zero,
                      onPressed: () {
                        final current =
                            double.tryParse(_amountController.text) ?? 0;
                        final next = current + preset.$2;
                        _amountController.text =
                            next == next.truncate().toDouble()
                                ? next.toStringAsFixed(0)
                                : next.toStringAsFixed(2);
                        setState(() {});
                      },
                      child: Text(
                        preset.$1,
                        style: TextStyle(
                          fontSize: TypeScale.footnote,
                          fontWeight: FontWeight.w600,
                          color: _branch == TransactionWizardBranch.income
                              ? AppStyles.gain(context)
                              : _branch == TransactionWizardBranch.expense
                                  ? AppStyles.loss(context)
                                  : CupertinoColors.systemBlue,
                        ),
                      ),
                    ),
                  ),
                // ÷2 (halve) and ×2 (double)
                Padding(
                  padding: const EdgeInsets.only(right: Spacing.sm),
                  child: CupertinoButton(
                    padding: const EdgeInsets.symmetric(
                        horizontal: Spacing.lg, vertical: Spacing.sm),
                    color: AppStyles.getCardColor(context),
                    borderRadius: BorderRadius.circular(20),
                    minimumSize: Size.zero,
                    onPressed: () {
                      final current =
                          double.tryParse(_amountController.text) ?? 0;
                      if (current <= 0) return;
                      final next = current / 2;
                      _amountController.text =
                          next == next.truncate().toDouble()
                              ? next.toStringAsFixed(0)
                              : next.toStringAsFixed(2);
                      setState(() {});
                    },
                    child: Text(
                      '÷2',
                      style: TextStyle(
                        fontSize: TypeScale.footnote,
                        fontWeight: FontWeight.w600,
                        color: AppStyles.getSecondaryTextColor(context),
                      ),
                    ),
                  ),
                ),
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(
                      horizontal: Spacing.lg, vertical: Spacing.sm),
                  color: AppStyles.getCardColor(context),
                  borderRadius: BorderRadius.circular(20),
                  minimumSize: Size.zero,
                  onPressed: () {
                    final current =
                        double.tryParse(_amountController.text) ?? 0;
                    if (current <= 0) return;
                    final next = current * 2;
                    _amountController.text = next == next.truncate().toDouble()
                        ? next.toStringAsFixed(0)
                        : next.toStringAsFixed(2);
                    setState(() {});
                  },
                  child: Text(
                    '×2',
                    style: TextStyle(
                      fontSize: TypeScale.footnote,
                      fontWeight: FontWeight.w600,
                      color: AppStyles.getSecondaryTextColor(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      footer: _buildFooterButton(
        label: 'Continue',
        disabled: !_hasValidAmount,
        onPressed: _nextStep,
      ),
    );
  }

  Widget _buildFooterButton({
    required String label,
    required VoidCallback onPressed,
    bool disabled = false,
  }) {
    final branch = _branch;
    final Color btnColor = branch == TransactionWizardBranch.income
        ? AppStyles.gain(context)
        : branch == TransactionWizardBranch.expense
            ? AppStyles.loss(context)
            : CupertinoColors.systemBlue;
    final Color activeColor =
        disabled ? AppStyles.getSecondaryTextColor(context) : btnColor;

    return Padding(
      padding: const EdgeInsets.only(top: Spacing.md),
      child: GestureDetector(
        onTap: disabled ? null : onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            gradient: disabled
                ? null
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      activeColor,
                      activeColor.withValues(alpha: 0.75),
                    ],
                  ),
            color: disabled ? AppStyles.getCardColor(context) : null,
            borderRadius: BorderRadius.circular(18),
            boxShadow: disabled
                ? []
                : [
                    BoxShadow(
                      color: activeColor.withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: TypeScale.callout,
                fontWeight: FontWeight.w700,
                color: disabled
                    ? AppStyles.getSecondaryTextColor(context)
                    : CupertinoColors.white,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOptionalFooter({
    required VoidCallback onNext,
    required VoidCallback onSkip,
    String nextLabel = 'Next',
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildFooterButton(label: nextLabel, onPressed: onNext),
        CupertinoButton(
          padding: const EdgeInsets.symmetric(vertical: 4),
          onPressed: onSkip,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Skip',
                style: TextStyle(
                  fontSize: TypeScale.footnote,
                  color: AppStyles.getSecondaryTextColor(context),
                ),
              ),
              Text(
                'Optional — you can add this later',
                style: TextStyle(
                  fontSize: TypeScale.label,
                  color: AppStyles.getSecondaryTextColor(context)
                      .withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDatePage() {
    return _buildStepShell(
      title: 'When did it happen?',
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(Spacing.lg),
            decoration: BoxDecoration(
              color: AppStyles.getCardColor(context),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Selected date',
                  style: TextStyle(
                      color: AppStyles.getSecondaryTextColor(context)),
                ),
                const SizedBox(height: Spacing.sm),
                InkWell(
                  onTap: () => _showDatePicker(),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                        style: AppStyles.titleStyle(context)
                            .copyWith(fontSize: 18),
                      ),
                      const Icon(CupertinoIcons.calendar),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      footer: _buildFooterButton(label: 'Next', onPressed: _nextStep),
    );
  }

  Future<void> _showDatePicker() async {
    final picked = await showAppDatePicker(
      context: context,
      initialDate: _selectedDate,
      minimumDate: DateTime.now().subtract(const Duration(days: 365 * 30)),
      maximumDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Widget _buildPaymentTypePage() {
    final types = {
      TransactionPaymentType.cash: 'Cash',
      TransactionPaymentType.upi: 'UPI',
      TransactionPaymentType.card: 'Card',
      TransactionPaymentType.bank: 'Bank Transfer',
      TransactionPaymentType.wallet: 'Wallet',
    };
    final icons = {
      TransactionPaymentType.cash: CupertinoIcons.money_dollar_circle,
      TransactionPaymentType.upi: CupertinoIcons.device_phone_portrait,
      TransactionPaymentType.card: CupertinoIcons.creditcard_fill,
      TransactionPaymentType.bank: CupertinoIcons.building_2_fill,
      TransactionPaymentType.wallet: CupertinoIcons.money_dollar_circle_fill,
    };

    return _buildStepShell(
      title: 'How did you pay?',
      child: Column(
        children: types.entries.map((entry) {
          final paymentType = entry.key;
          final label = entry.value;
          final isSelected = _paymentType == paymentType;
          return _buildSelectableTile(
            label: label,
            subtitle: 'Tap to choose $label',
            icon: icons[paymentType]!,
            selected: isSelected,
            onTap: () {
              setState(() {
                _paymentType = paymentType;
              });
              // Auto-select cash account so balance is updated on save
              if (paymentType == TransactionPaymentType.cash) {
                final accounts =
                    Provider.of<AccountsController>(context, listen: false)
                        .accounts;
                final cashAccounts =
                    accounts.where((a) => a.type == AccountType.cash).toList();
                if (cashAccounts.isNotEmpty) {
                  setState(() => _selectedAccount = cashAccounts.first);
                }
              } else {
                // Clear cash auto-selection when switching away from cash
                if (_selectedAccount?.type == AccountType.cash) {
                  setState(() => _selectedAccount = null);
                }
              }
              _nextStep();
            },
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSelectableTile({
    required String label,
    required String subtitle,
    required IconData icon,
    bool selected = false,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.sm),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(
              horizontal: Spacing.lg, vertical: Spacing.md),
          decoration: BoxDecoration(
            gradient: selected
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      CupertinoColors.systemBlue.withValues(alpha: 0.18),
                      CupertinoColors.systemBlue.withValues(alpha: 0.06),
                    ],
                  )
                : null,
            color: selected ? null : AppStyles.getCardColor(context),
            borderRadius: BorderRadius.circular(Radii.lg),
            border: Border.all(
              color: selected
                  ? CupertinoColors.systemBlue.withValues(alpha: 0.6)
                  : AppStyles.getSecondaryTextColor(context)
                      .withValues(alpha: 0.12),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: selected
                      ? CupertinoColors.systemBlue.withValues(alpha: 0.2)
                      : AppStyles.getSecondaryTextColor(context)
                          .withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: selected
                      ? CupertinoColors.systemBlue
                      : AppStyles.getSecondaryTextColor(context),
                  size: 22,
                ),
              ),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: TypeScale.callout,
                        fontWeight: FontWeight.w600,
                        color: selected
                            ? CupertinoColors.systemBlue
                            : AppStyles.getTextColor(context),
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Icon(CupertinoIcons.checkmark_circle_fill,
                    color: CupertinoColors.systemBlue, size: 22)
              else
                Icon(CupertinoIcons.circle,
                    color: AppStyles.getSecondaryTextColor(context)
                        .withValues(alpha: 0.3),
                    size: 22),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccountPage() {
    return Consumer<AccountsController>(
      builder: (context, accountsController, child) {
        final accounts = _filteredAccounts(accountsController.accounts);
        final emptyStateMessage = _paymentType == TransactionPaymentType.cash
            ? 'No cash account available. Add one to track cash flow.'
            : 'No eligible accounts available';
        return _buildStepShell(
          title: 'Select account',
          child: Column(
            children: [
              Expanded(
                child: accounts.isEmpty
                    ? Center(
                        child: Text(
                          emptyStateMessage,
                          style: TextStyle(
                              color: AppStyles.getSecondaryTextColor(context)),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView.builder(
                        itemCount: accounts.length,
                        itemBuilder: (context, index) {
                          final account = accounts[index];
                          final isSelected = _selectedAccount?.id == account.id;
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedAccount = account;
                              });
                              _nextStep();
                            },
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? CupertinoColors.systemBlue
                                        .withValues(alpha: 0.12)
                                    : AppStyles.getCardColor(context),
                                borderRadius: BorderRadius.circular(Radii.md),
                                border: Border.all(
                                  color: isSelected
                                      ? CupertinoColors.systemBlue
                                      : Colors.transparent,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color:
                                          account.color.withValues(alpha: 0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      _iconForAccount(account),
                                      color: account.color,
                                    ),
                                  ),
                                  const SizedBox(width: Spacing.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          account.name,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color:
                                                AppStyles.getTextColor(context),
                                          ),
                                        ),
                                        Text(
                                          account.bankName,
                                          style: TextStyle(
                                              color: AppStyles
                                                  .getSecondaryTextColor(
                                                      context),
                                              fontSize: TypeScale.footnote),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '₹${account.balance.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              CupertinoButton(
                onPressed: () => _addAccount(),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(CupertinoIcons.add),
                    const SizedBox(width: Spacing.sm),
                    Text('Add Account',
                        style:
                            TextStyle(color: AppStyles.getTextColor(context))),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  IconData _iconForAccount(Account account) {
    switch (account.type) {
      case AccountType.savings:
      case AccountType.current:
        return CupertinoIcons.house_fill;
      case AccountType.credit:
      case AccountType.payLater:
        return CupertinoIcons.creditcard;
      case AccountType.wallet:
        return CupertinoIcons.money_dollar_circle_fill;
      case AccountType.investment:
        return CupertinoIcons.building_2_fill;
      case AccountType.cash:
        return CupertinoIcons.money_dollar_circle;
    }
  }

  List<Account> _filteredAccounts(List<Account> list) {
    if (_paymentType == null) return [];
    switch (_paymentType!) {
      case TransactionPaymentType.cash:
        final dedicatedCash =
            list.where((acct) => acct.type == AccountType.cash).toList();
        if (dedicatedCash.isNotEmpty) {
          return dedicatedCash;
        }
        // Backward compatibility for users tracking cash in wallet accounts.
        return list.where((acct) => acct.type == AccountType.wallet).toList();
      case TransactionPaymentType.upi:
        return list
            .where((acct) =>
                acct.type == AccountType.savings ||
                acct.type == AccountType.current ||
                acct.type == AccountType.wallet)
            .toList();
      case TransactionPaymentType.card:
        return list
            .where((acct) =>
                acct.type == AccountType.credit ||
                acct.type == AccountType.payLater)
            .toList();
      case TransactionPaymentType.bank:
        return list
            .where((acct) =>
                acct.type == AccountType.savings ||
                acct.type == AccountType.current)
            .toList();
      case TransactionPaymentType.wallet:
        return list.where((acct) => acct.type == AccountType.wallet).toList();
    }
  }

  void _addAccount() {
    Navigator.of(context)
        .push<Account?>(
      FadeScalePageRoute(page: const AccountWizard()),
    )
        .then((result) {
      if (result != null) {
        Provider.of<AccountsController>(context, listen: false)
            .addAccount(result);
      }
    });
  }

  void _selectPaymentApp(Map<String, dynamic> app, {bool autoAdvance = true}) {
    setState(() {
      _selectedPaymentApp = app['name'] as String?;
      _paymentAppHasWallet = app['hasWallet'] == true;
      _selectedPaymentAppWalletBalance =
          (app['walletBalance'] as num?)?.toDouble() ?? 0.0;
      if (!_paymentAppHasWallet) {
        _appWalletAmountController.clear();
      }
    });
    if (autoAdvance) {
      _nextStep();
    }
  }

  Future<void> _openPaymentAppsAndAutoSelect(
      PaymentAppsController appsController) async {
    final previouslyEnabledIds = appsController.paymentApps
        .where((app) => app['isEnabled'] == true)
        .map((app) => app['id'].toString())
        .toSet();

    await Navigator.of(context).push(
      FadeScalePageRoute(page: const PaymentAppsScreen()),
    );

    if (!mounted) return;

    final enabledApps = appsController.paymentApps
        .where((app) => app['isEnabled'] == true)
        .toList();

    if (enabledApps.isEmpty) {
      setState(() {
        _selectedPaymentApp = null;
        _paymentAppHasWallet = false;
        _selectedPaymentAppWalletBalance = 0.0;
        _appWalletAmountController.clear();
      });
      return;
    }

    Map<String, dynamic>? chosenApp;
    for (final app in enabledApps) {
      final id = app['id']?.toString();
      if (id != null && !previouslyEnabledIds.contains(id)) {
        chosenApp = app;
        break;
      }
    }

    if (chosenApp == null && _selectedPaymentApp != null) {
      final current = appsController.getAppByName(_selectedPaymentApp!);
      if (current != null && current['isEnabled'] == true) {
        chosenApp = current;
      }
    }

    chosenApp ??= enabledApps.first;
    _selectPaymentApp(chosenApp);
  }

  Widget _buildPaymentAppPage() {
    return Consumer<PaymentAppsController>(
      builder: (context, appsController, child) {
        final apps = appsController.paymentApps
            .where((app) => app['isEnabled'] == true)
            .toList();
        return _buildStepShell(
          title: 'Payment App',
          child: Column(
            children: [
              Expanded(
                child: apps.isEmpty
                    ? Center(
                        child: Text(
                          'Enable at least one payment app to continue',
                          style: TextStyle(
                              color: AppStyles.getSecondaryTextColor(context)),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView.builder(
                        itemCount: apps.length,
                        itemBuilder: (context, index) {
                          final app = apps[index];
                          final isSelected = _selectedPaymentApp == app['name'];
                          return GestureDetector(
                            onTap: () => _selectPaymentApp(app),
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? CupertinoColors.systemBlue
                                        .withValues(alpha: 0.12)
                                    : AppStyles.getCardColor(context),
                                borderRadius: BorderRadius.circular(Radii.md),
                                border: Border.all(
                                  color: isSelected
                                      ? CupertinoColors.systemBlue
                                      : Colors.transparent,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: (app['color'] as Color)
                                          .withValues(alpha: 0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(CupertinoIcons.app,
                                        color: app['color']),
                                  ),
                                  const SizedBox(width: Spacing.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(app['name'],
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w600)),
                                        Text(
                                          (app['hasWallet'] ?? false)
                                              ? 'Wallet ₹${((app['walletBalance'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)}'
                                              : 'No wallet',
                                          style: TextStyle(
                                              color: AppStyles
                                                  .getSecondaryTextColor(
                                                      context),
                                              fontSize: TypeScale.footnote),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isSelected)
                                    const Icon(
                                        CupertinoIcons.checkmark_circle_fill,
                                        color: CupertinoColors.systemBlue),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CupertinoButton(
                    onPressed: () =>
                        _openPaymentAppsAndAutoSelect(appsController),
                    child: Row(
                      children: [
                        const Icon(CupertinoIcons.add_circled_solid),
                        const SizedBox(width: 6),
                        Text('Manage / Enable Apps',
                            style: TextStyle(
                                color: AppStyles.getTextColor(context))),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          footer: _buildFooterButton(
            label: 'Next',
            onPressed: _nextStep,
            disabled: _selectedPaymentApp == null,
          ),
        );
      },
    );
  }

  Widget _buildCashbackPage() {
    return _buildStepShell(
      title: 'Cashback handling',
      child: Column(
        children: [
          if (_paymentAppHasWallet) ...[
            Text(
              'Amount from app wallet',
              style: TextStyle(color: AppStyles.getSecondaryTextColor(context)),
            ),
            const SizedBox(height: Spacing.sm),
            CupertinoTextField(
              controller: _appWalletAmountController,
              autofocus: _currentStep == 6,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.next,
              placeholder: '0.00',
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              decoration: BoxDecoration(
                color: AppStyles.getCardColor(context),
                borderRadius: BorderRadius.circular(Radii.md),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Available wallet: ₹${_selectedPaymentAppWalletBalance.toStringAsFixed(2)}',
              style: TextStyle(
                color: AppStyles.getSecondaryTextColor(context),
                fontSize: TypeScale.footnote,
              ),
            ),
            const SizedBox(height: Spacing.md),
          ],
          Text(
            'Add cashback if you expect rewards from this payment app',
            style: TextStyle(color: AppStyles.getSecondaryTextColor(context)),
          ),
          const SizedBox(height: Spacing.md),
          CupertinoTextField(
            controller: _cashbackController,
            autofocus: _currentStep == 6 && !_paymentAppHasWallet,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => _nextStep(),
            placeholder: '0.00',
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            decoration: BoxDecoration(
              color: AppStyles.getCardColor(context),
              borderRadius: BorderRadius.circular(Radii.md),
            ),
          ),
          const SizedBox(height: Spacing.md),
          CupertinoSegmentedControl<bool>(
            groupValue: _cashbackToApp,
            children: {
              true: const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Add to App wallet'),
              ),
              false: const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Add to bank account'),
              ),
            },
            onValueChanged: (value) => setState(() => _cashbackToApp = value),
          ),
        ],
      ),
      footer: _buildFooterButton(label: 'Next', onPressed: _nextStep),
    );
  }

  Widget _buildCategoryPage() {
    return Consumer<CategoriesController>(
      builder: (context, categoriesController, child) {
        final categories = categoriesController.categories
            .where((cat) =>
                _categorySearchController.text.isEmpty ||
                cat.name
                    .toLowerCase()
                    .contains(_categorySearchController.text.toLowerCase()))
            .toList();
        return _buildStepShell(
          title: 'Choose category',
          child: Column(
            children: [
              CupertinoSearchTextField(
                controller: _categorySearchController,
                placeholder: 'Search categories',
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: Spacing.md),
              Expanded(
                child: categories.isEmpty
                    ? Center(
                        child: Text('No matching categories',
                            style: TextStyle(
                                color:
                                    AppStyles.getSecondaryTextColor(context))),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          const cols = 2;
                          const spacing = Spacing.sm;
                          final itemW = (constraints.maxWidth - (cols - 1) * spacing) / cols;
                          return GridView.count(
                        crossAxisCount: cols,
                        childAspectRatio: itemW / (itemW / 3.0),
                        crossAxisSpacing: spacing,
                        mainAxisSpacing: spacing,
                        children: categories.map((category) {
                          final selected = _selectedCategory?.id == category.id;
                          return GestureDetector(
                            onTap: () {
                              setState(() => _selectedCategory = category);
                              _saveLastCategory(category);
                              _nextStep();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: Spacing.sm),
                              decoration: BoxDecoration(
                                color: selected
                                    ? category.color.withValues(alpha: 0.2)
                                    : AppStyles.getCardColor(context),
                                borderRadius: BorderRadius.circular(Radii.md),
                                border: Border.all(
                                    color: selected
                                        ? category.color
                                        : Colors.transparent),
                              ),
                              child: Row(
                                children: [
                                  Icon(category.icon, color: category.color),
                                  const SizedBox(width: Spacing.sm),
                                  Expanded(
                                    child: Text(
                                      category.name,
                                      style: TextStyle(
                                          color:
                                              AppStyles.getTextColor(context)),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                          );
                        },
                      ),
              ),
              CupertinoButton(
                onPressed: () => _showAddCategoryModal(categoriesController),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(CupertinoIcons.add),
                    const SizedBox(width: Spacing.sm),
                    Text('Create category',
                        style:
                            TextStyle(color: AppStyles.getTextColor(context))),
                  ],
                ),
              ),
            ],
          ),
          footer: _buildFooterButton(
              label: 'Next',
              onPressed: _nextStep,
              disabled: _selectedCategory == null),
        );
      },
    );
  }

  void _showAddCategoryModal(CategoriesController controller) {
    showCreateCategoryModal(context, controller: controller).then((category) {
      if (!mounted || category == null) return;
      setState(() => _selectedCategory = category);
      _saveLastCategory(category);
      _nextStep();
    });
  }

  Widget _buildMerchantPage() {
    return Consumer2<ContactsController, TransactionsController>(
      builder: (context, contactsController, txController, child) {
        final contacts = contactsController.contacts;
        final query = _merchantController.text.toLowerCase();

        // Collect recent merchant names from past transactions
        final recentMerchants = <String>{};
        for (final tx in txController.transactions) {
          final m = tx.metadata?['merchant'] as String?;
          if (m != null && m.trim().isNotEmpty) {
            recentMerchants.add(m.trim());
          }
          if (recentMerchants.length >= 20) break;
        }

        // Filter contacts by search query
        final filteredContacts = query.isEmpty
            ? contacts
            : contacts
                .where((c) => c.name.toLowerCase().contains(query))
                .toList();

        // Filter recent merchants by query
        final filteredRecent = query.isEmpty
            ? recentMerchants.take(8).toList()
            : recentMerchants
                .where((m) => m.toLowerCase().contains(query))
                .take(6)
                .toList();

        return _buildStepShell(
          title: 'Merchant / Person',
          child: Column(
            children: [
              // Search / manual entry field
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: CupertinoTextField(
                  controller: _merchantController,
                  placeholder: 'e.g., Zomato, Amazon, Uber',
                  prefix: Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Icon(
                      CupertinoIcons.search,
                      size: 18,
                      color: AppStyles.getSecondaryTextColor(context),
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                  style: TextStyle(color: AppStyles.getTextColor(context)),
                  decoration: BoxDecoration(
                    color: AppStyles.getCardColor(context),
                    borderRadius: BorderRadius.circular(Radii.md),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
              const SizedBox(height: Spacing.sm),

              // Recent merchants autocomplete chips
              if (filteredRecent.isNotEmpty) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    query.isEmpty ? 'Recent' : 'Suggestions',
                    style: TextStyle(
                      fontSize: TypeScale.caption,
                      fontWeight: FontWeight.w600,
                      color: AppStyles.getSecondaryTextColor(context),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: filteredRecent.map((name) {
                      return GestureDetector(
                        onTap: () {
                          setState(() => _merchantController.text = name);
                          _nextStep();
                        },
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: CupertinoColors.systemOrange
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: CupertinoColors.systemOrange
                                  .withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                CupertinoIcons.clock,
                                size: 11,
                                color: CupertinoColors.systemOrange,
                              ),
                              const SizedBox(width: Spacing.xs),
                              Text(
                                name,
                                style: const TextStyle(
                                  fontSize: TypeScale.footnote,
                                  fontWeight: FontWeight.w500,
                                  color: CupertinoColors.systemOrange,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: Spacing.md),
              ],

              // People list
              Expanded(
                child: filteredContacts.isEmpty
                    ? Center(
                        child: Text(
                          query.isEmpty
                              ? 'No people yet. Add manually or import from contacts'
                              : 'No matches for "$query"',
                          style: TextStyle(
                              color: AppStyles.getSecondaryTextColor(context)),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView.builder(
                        itemCount: filteredContacts.length,
                        itemBuilder: (context, index) {
                          final contact = filteredContacts[index];
                          final isSelected =
                              _merchantController.text == contact.name;
                          return GestureDetector(
                            onTap: () {
                              setState(() =>
                                  _merchantController.text = contact.name);
                              _nextStep();
                            },
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppStyles.gain(context)
                                        .withValues(alpha: 0.12)
                                    : AppStyles.getCardColor(context),
                                borderRadius: BorderRadius.circular(Radii.md),
                                border: Border.all(
                                  color: isSelected
                                      ? AppStyles.gain(context)
                                      : Colors.transparent,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(CupertinoIcons.person_fill),
                                  const SizedBox(width: Spacing.md),
                                  Expanded(
                                    child: Text(
                                      contact.name,
                                      style: TextStyle(
                                          color:
                                              AppStyles.getTextColor(context)),
                                    ),
                                  ),
                                  if (isSelected)
                                    Icon(
                                      CupertinoIcons.checkmark_alt_circle_fill,
                                      color: AppStyles.gain(context),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              CupertinoButton(
                onPressed: () => _showAddPersonModal(contactsController),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(CupertinoIcons.add),
                    const SizedBox(width: Spacing.sm),
                    Text('Add Person',
                        style:
                            TextStyle(color: AppStyles.getTextColor(context))),
                  ],
                ),
              ),
            ],
          ),
          footer: _buildOptionalFooter(
            onNext: _nextStep,
            onSkip: () {
              _merchantController.clear();
              _nextStep();
            },
          ),
        );
      },
    );
  }

  void _showAddPersonModal(ContactsController controller) {
    final nameController = TextEditingController();
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => RLayout.tabletConstrain(
        ctx,
        Container(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          24 + MediaQuery.of(ctx).viewInsets.bottom,
        ),
        decoration: BoxDecoration(
          color: AppStyles.getCardColor(ctx),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Add person', style: AppStyles.titleStyle(ctx)),
                const SizedBox(height: Spacing.md),
                CupertinoTextField(
                  controller: nameController,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) {
                    final name = nameController.text.trim();
                    if (name.isEmpty) return;
                    final contact = Contact(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      name: name,
                      createdDate: DateTime.now(),
                    );
                    controller.addContact(contact);
                    setState(() => _merchantController.text = contact.name);
                    Navigator.pop(ctx);
                    _nextStep();
                  },
                  placeholder: 'Name',
                  padding: const EdgeInsets.all(Spacing.lg),
                  decoration: BoxDecoration(
                    color: AppStyles.getBackground(ctx),
                    borderRadius: BorderRadius.circular(Radii.md),
                  ),
                ),
                const SizedBox(height: Spacing.md),
                CupertinoButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showPhoneContactsPicker(
                      controller: controller,
                      advanceAfterPick: true,
                    );
                  },
                  child: const Text('Pick from phone contacts'),
                ),
                const SizedBox(height: Spacing.sm),
                CupertinoButton.filled(
                  onPressed: () {
                    final name = nameController.text.trim();
                    if (name.isEmpty) return;
                    final contact = Contact(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      name: name,
                      createdDate: DateTime.now(),
                    );
                    controller.addContact(contact);
                    setState(() => _merchantController.text = contact.name);
                    Navigator.pop(ctx);
                    _nextStep();
                  },
                  child: const Text('Save'),
                ),
              ],
            )),
      ),
      ),
    ).whenComplete(nameController.dispose);
  }

  Future<void> _showPhoneContactsPicker({
    required ContactsController controller,
    required bool advanceAfterPick,
  }) async {
    final permissionStatus = await Permission.contacts.request();
    if (!permissionStatus.isGranted) {
      toast_lib.toast.showError('Contacts permission is required');
      return;
    }

    List<device_contacts.Contact> rawContacts;
    try {
      rawContacts = await device_contacts.FlutterContacts.getContacts(
          withProperties: true);
    } catch (_) {
      toast_lib.toast.showError('Unable to load phone contacts');
      return;
    }
    final seenNames = <String>{};
    final mappedContacts = <Contact>[];
    for (final contact in rawContacts) {
      final name = contact.displayName.trim();
      if (name.isEmpty) continue;
      final normalized = name.toLowerCase();
      if (seenNames.contains(normalized)) continue;
      seenNames.add(normalized);
      final phone =
          contact.phones.isNotEmpty ? contact.phones.first.number.trim() : null;
      mappedContacts.add(
        Contact(
          id: contact.id,
          name: name,
          phoneNumber: phone?.isNotEmpty == true ? phone : null,
          createdDate: DateTime.now(),
        ),
      );
    }
    mappedContacts.sort((a, b) => a.name.compareTo(b.name));

    if (mappedContacts.isEmpty) {
      toast_lib.toast.showInfo('No phone contacts available');
      return;
    }

    if (!mounted) return;
    final picked = await showCupertinoModalPopup<Contact>(
      context: context,
      builder: (ctx) => RLayout.tabletConstrain(
        ctx,
        _PhoneContactsPickerSheet(contacts: mappedContacts),
      ),
    );

    if (!mounted || picked == null) return;
    controller.addContact(picked);
    setState(() => _merchantController.text = picked.name);
    if (advanceAfterPick) {
      _nextStep();
    }
  }

  Widget _buildDescriptionPage() {
    return Consumer<TransactionsController>(
      builder: (context, txController, child) {
        final query = _descriptionController.text.toLowerCase();

        // Collect recent unique descriptions
        final recentDescs = <String>{};
        for (final tx in txController.transactions) {
          final d = tx.metadata?['description'] as String?;
          if (d != null && d.trim().isNotEmpty) {
            recentDescs.add(d.trim());
          }
          if (recentDescs.length >= 20) break;
        }

        final suggestions = query.isEmpty
            ? recentDescs.take(8).toList()
            : recentDescs
                .where((d) => d.toLowerCase().contains(query))
                .take(6)
                .toList();

        return _buildStepShell(
          title: 'Description',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CupertinoTextField(
                controller: _descriptionController,
                autofocus: _currentStep == 9,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _nextStep(),
                onChanged: (_) => setState(() {}),
                placeholder: 'e.g., Lunch with team, Monthly Netflix',
                padding: const EdgeInsets.all(Spacing.lg),
                decoration: BoxDecoration(
                  color: AppStyles.getCardColor(context),
                  borderRadius: BorderRadius.circular(Radii.md),
                ),
                maxLines: 4,
                style: TextStyle(color: AppStyles.getTextColor(context)),
              ),
              if (suggestions.isNotEmpty) ...[
                const SizedBox(height: Spacing.lg),
                Text(
                  query.isEmpty ? 'Recent' : 'Suggestions',
                  style: TextStyle(
                    fontSize: TypeScale.caption,
                    fontWeight: FontWeight.w600,
                    color: AppStyles.getSecondaryTextColor(context),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: Spacing.sm),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: suggestions.map((desc) {
                    return GestureDetector(
                      onTap: () =>
                          setState(() => _descriptionController.text = desc),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppStyles.getCardColor(context),
                          borderRadius: BorderRadius.circular(Radii.lg),
                          border: Border.all(
                            color: AppStyles.getSecondaryTextColor(context)
                                .withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              CupertinoIcons.doc_text,
                              size: 11,
                              color: AppStyles.getSecondaryTextColor(context),
                            ),
                            const SizedBox(width: Spacing.xs),
                            Text(
                              desc.length > 30
                                  ? '${desc.substring(0, 28)}…'
                                  : desc,
                              style: TextStyle(
                                fontSize: TypeScale.footnote,
                                color: AppStyles.getTextColor(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
              _buildTaxTagPicker(),
            ],
          ),
          footer: _buildOptionalFooter(
            onNext: _nextStep,
            onSkip: () {
              _descriptionController.clear();
              setState(() => _selectedTaxTag = null);
              _nextStep();
            },
          ),
        );
      },
    );
  }

  static const List<({String code, String label, String? limit})>
      _taxSections = [
    (code: '80C', label: '80C – Investments', limit: '₹1,50,000'),
    (code: '80D', label: '80D – Health Insurance', limit: '₹25,000'),
    (code: 'HRA', label: 'HRA – House Rent Allowance', limit: null),
    (code: '80G', label: '80G – Donations', limit: null),
    (code: '80E', label: '80E – Education Loan Interest', limit: null),
    (code: 'NPS', label: 'NPS – Additional ₹50K', limit: '₹50,000'),
    (code: '24B', label: '24B – Home Loan Interest', limit: '₹2,00,000'),
  ];

  Widget _buildTaxTagPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: Spacing.lg),
        Row(
          children: [
            Icon(CupertinoIcons.doc_text,
                size: 13,
                color: AppStyles.gold(context)),
            const SizedBox(width: 6),
            Text(
              'Tax Section (Optional)',
              style: TextStyle(
                fontSize: TypeScale.caption,
                fontWeight: FontWeight.w600,
                color: AppStyles.gold(context),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: Spacing.sm),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            GestureDetector(
              onTap: () => setState(() => _selectedTaxTag = null),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: _selectedTaxTag == null
                      ? AppStyles.gold(context).withValues(alpha: 0.2)
                      : AppStyles.getCardColor(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _selectedTaxTag == null
                        ? AppStyles.gold(context)
                        : Colors.transparent,
                  ),
                ),
                child: Text(
                  'None',
                  style: TextStyle(
                    fontSize: TypeScale.footnote,
                    color: AppStyles.getTextColor(context),
                  ),
                ),
              ),
            ),
            ..._taxSections.map((section) {
              final isSelected = _selectedTaxTag == section.code;
              return GestureDetector(
                onTap: () => setState(() => _selectedTaxTag = section.code),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppStyles.gold(context).withValues(alpha: 0.2)
                        : AppStyles.getCardColor(context),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? AppStyles.gold(context)
                          : Colors.transparent,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        section.code,
                        style: TextStyle(
                          fontSize: TypeScale.footnote,
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? AppStyles.gold(context)
                              : AppStyles.getTextColor(context),
                        ),
                      ),
                      if (section.limit != null)
                        Text(
                          'Limit: ${section.limit}',
                          style: TextStyle(
                            fontSize: TypeScale.label,
                            color: AppStyles.getSecondaryTextColor(context),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ],
    );
  }

  Widget _buildTagsPage() {
    return Consumer<TagsController>(
      builder: (context, tagsController, child) {
        final availableTags = tagsController.tags;
        return _buildStepShell(
          title: 'Tags',
          child: Column(
            children: [
              Wrap(
                spacing: Spacing.sm,
                runSpacing: Spacing.sm,
                children: availableTags.map((tag) {
                  final isSelected = _selectedTags.contains(tag.name);
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedTags.remove(tag.name);
                        } else {
                          _selectedTags.add(tag.name);
                        }
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? tag.color.withValues(alpha: 0.2)
                            : AppStyles.getCardColor(context),
                        borderRadius: BorderRadius.circular(Radii.lg),
                        border: Border.all(
                            color: isSelected ? tag.color : Colors.transparent),
                      ),
                      child: Text(tag.name,
                          style: TextStyle(
                              color: AppStyles.getTextColor(context))),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: Spacing.md),
              CupertinoTextField(
                controller: _tagController,
                autofocus: _currentStep == 10,
                placeholder: 'e.g., food, entertainment',
                textInputAction: TextInputAction.done,
                onSubmitted: (_) {
                  if (_tagController.text.isEmpty) {
                    _nextStep();
                    return;
                  }
                  final newTag = Tag(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: _tagController.text,
                    color: Tag.colorPalette[
                        _selectedTags.length % Tag.colorPalette.length],
                    createdDate: DateTime.now(),
                  );
                  tagsController.addTag(newTag);
                  setState(() {
                    _selectedTags.add(newTag.name);
                    _tagController.clear();
                  });
                },
                suffix: GestureDetector(
                  onTap: () {
                    if (_tagController.text.isEmpty) return;
                    final newTag = Tag(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      name: _tagController.text,
                      color: Tag.colorPalette[
                          _selectedTags.length % Tag.colorPalette.length],
                      createdDate: DateTime.now(),
                    );
                    tagsController.addTag(newTag);
                    setState(() {
                      _selectedTags.add(newTag.name);
                      _tagController.clear();
                    });
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Icon(CupertinoIcons.add_circled_solid),
                  ),
                ),
                padding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                decoration: BoxDecoration(
                  color: AppStyles.getCardColor(context),
                  borderRadius: BorderRadius.circular(Radii.md),
                ),
              ),
            ],
          ),
          footer: _buildOptionalFooter(
            onNext: _nextStep,
            onSkip: () {
              setState(() => _selectedTags.clear());
              _nextStep();
            },
          ),
        );
      },
    );
  }

  Widget _buildReviewPage() {
    final amount = double.tryParse(_amountController.text) ?? 0;
    return _buildStepShell(
      title: 'Review',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildReviewRow('Amount', '₹${amount.toStringAsFixed(2)}'),
          _buildReviewRow('Date',
              '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}'),
          _buildReviewRow('Payment type', _paymentType?.name ?? '-'),
          if (_selectedAccount != null)
            _buildReviewRow('Account', _selectedAccount!.name),
          if (_selectedPaymentApp != null)
            _buildReviewRow('Payment App', _selectedPaymentApp!),
          if (_appWalletAmountController.text.isNotEmpty)
            _buildReviewRow(
                'From App Wallet', '₹${_appWalletAmountController.text}'),
          if (_selectedAccount != null &&
              _appWalletAmountController.text.isNotEmpty)
            _buildReviewRow('From Account',
                '₹${(amount - (double.tryParse(_appWalletAmountController.text) ?? 0)).toStringAsFixed(2)}'),
          if (_cashbackController.text.isNotEmpty)
            _buildReviewRow('Cashback',
                '₹${_cashbackController.text} (${_cashbackToApp ? 'App' : 'Bank'})'),
          if (_selectedCategory != null)
            _buildReviewRow('Category', _selectedCategory!.name),
          if (_merchantController.text.isNotEmpty)
            _buildReviewRow('Merchant', _merchantController.text),
          if (_descriptionController.text.isNotEmpty)
            _buildReviewRow('Description', _descriptionController.text),
          if (_selectedTags.isNotEmpty)
            _buildReviewRow('Tags', _selectedTags.join(', ')),
          const Spacer(),
          // Save as recurring template option
          Padding(
            padding: const EdgeInsets.only(bottom: Spacing.sm),
            child: GestureDetector(
              onTap: _showSaveTemplateSheet,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(CupertinoIcons.repeat,
                      size: 13,
                      color: AppStyles.getSecondaryTextColor(context)),
                  const SizedBox(width: 5),
                  Text(
                    'Save as Recurring Template',
                    style: TextStyle(
                      fontSize: TypeScale.footnote,
                      color: AppStyles.getSecondaryTextColor(context),
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ],
              ),
            ),
          ),
          _buildFooterButton(
              label: 'Save Transaction', onPressed: _completeTransaction),
        ],
      ),
    );
  }

  Widget _buildReviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style:
                  TextStyle(color: AppStyles.getSecondaryTextColor(context))),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppStyles.getTextColor(context)),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhoneContactsPickerSheet extends StatefulWidget {
  final List<Contact> contacts;

  const _PhoneContactsPickerSheet({required this.contacts});

  @override
  State<_PhoneContactsPickerSheet> createState() =>
      _PhoneContactsPickerSheetState();
}

class _PhoneContactsPickerSheetState extends State<_PhoneContactsPickerSheet> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final filteredContacts = widget.contacts.where((contact) {
      if (query.isEmpty) return true;
      return contact.name.toLowerCase().contains(query) ||
          (contact.phoneNumber?.toLowerCase().contains(query) ?? false);
    }).toList();

    return Container(
      height: AppStyles.sheetMaxHeight(context),
      decoration: BoxDecoration(
        color: AppStyles.getCardColor(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey3,
                borderRadius: BorderRadius.circular(100),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
              child: Row(
                children: [
                  Text(
                    'Phone contacts',
                    style: AppStyles.titleStyle(context)
                        .copyWith(fontSize: TypeScale.title2),
                  ),
                  const Spacer(),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: CupertinoSearchTextField(
                controller: _searchController,
                placeholder: 'Search contacts',
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(height: Spacing.sm),
            Expanded(
              child: filteredContacts.isEmpty
                  ? Center(
                      child: Text(
                        'No matching contacts',
                        style: TextStyle(
                            color: AppStyles.getSecondaryTextColor(context)),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
                      itemCount: filteredContacts.length,
                      itemBuilder: (context, index) {
                        final contact = filteredContacts[index];
                        return GestureDetector(
                          onTap: () => Navigator.pop(context, contact),
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.all(Spacing.md),
                            decoration: BoxDecoration(
                              color: AppStyles.getBackground(context),
                              borderRadius: BorderRadius.circular(Radii.md),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: CupertinoColors.systemBlue
                                        .withValues(alpha: 0.14),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      contact.name[0].toUpperCase(),
                                      style: const TextStyle(
                                        color: CupertinoColors.systemBlue,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: Spacing.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        contact.name,
                                        style: TextStyle(
                                          color:
                                              AppStyles.getTextColor(context),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (contact.phoneNumber?.isNotEmpty ??
                                          false)
                                        Text(
                                          contact.phoneNumber!,
                                          style: TextStyle(
                                            color:
                                                AppStyles.getSecondaryTextColor(
                                                    context),
                                            fontSize: TypeScale.footnote,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const Icon(CupertinoIcons.chevron_right),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

extension on String {
  String capitalize() =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}
