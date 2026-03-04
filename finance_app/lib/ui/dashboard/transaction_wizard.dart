import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
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
import 'package:vittara_fin_os/ui/manage/account_wizard.dart';
import 'package:vittara_fin_os/ui/manage/categories/category_creation_modal.dart';
import 'package:vittara_fin_os/ui/manage/payment_apps_screen.dart';
import 'package:vittara_fin_os/ui/manage/transfer_wizard.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/widgets/animations.dart';
import 'package:vittara_fin_os/ui/widgets/toast_notification.dart' as toast_lib;

enum TransactionWizardBranch { expense, income, transfer }

enum TransactionPaymentType { cash, upi, card, bank, wallet }

class TransactionWizard extends StatefulWidget {
  const TransactionWizard({super.key});

  @override
  State<TransactionWizard> createState() => _TransactionWizardState();
}

class _TransactionWizardState extends State<TransactionWizard> {
  static const int _totalSteps = 12;
  final PageController _pageController = PageController();
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
    if (branch == TransactionWizardBranch.transfer) {
      Navigator.of(context).pushReplacement(
        CupertinoPageRoute(builder: (_) => const TransferWizard()),
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

  int _currentStep = 0;

  bool get _hasValidAmount =>
      (double.tryParse(_amountController.text) ?? 0) > 0;

  void _tryAdvanceFromAmount() {
    if (_hasValidAmount) {
      _nextStep();
    }
  }

  static const _lastCategoryKey = 'last_used_category_id';

  @override
  void initState() {
    super.initState();
    _amountController.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) => _restoreLastCategory());
  }

  Future<void> _restoreLastCategory() async {
    final prefs = await SharedPreferences.getInstance();
    final lastId = prefs.getString(_lastCategoryKey);
    if (lastId == null || !mounted) return;
    final controller =
        Provider.of<CategoriesController>(context, listen: false);
    final match = controller.categories
        .where((c) => c.id == lastId)
        .firstOrNull;
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
      Navigator.pop(context);
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
    toast_lib.toast.showSuccess('Transaction logged');
    Navigator.pop(context);
  }

  Widget _buildStepShell({
    required String title,
    required Widget child,
    Widget? trailing,
    Widget? footer,
  }) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
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
            SizedBox(height: Spacing.lg),
            Expanded(child: child),
            if (footer != null) footer,
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    final branch = _branch;
    final Color barColor = branch == TransactionWizardBranch.income
        ? CupertinoColors.systemGreen
        : branch == TransactionWizardBranch.expense
            ? CupertinoColors.systemRed
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
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
          SizedBox(height: Spacing.md),
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
      navigationBar: CupertinoNavigationBar(
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
    return _buildStepShell(
      title: 'What type of transaction?',
      child: Column(
        children: [
          _buildBranchButton(
            label: 'Expense',
            icon: CupertinoIcons.arrow_down_circle_fill,
            color: CupertinoColors.systemRed,
            onTap: () => _selectBranch(TransactionWizardBranch.expense),
          ),
          _buildBranchButton(
            label: 'Income',
            icon: CupertinoIcons.arrow_up_circle_fill,
            color: CupertinoColors.systemGreen,
            onTap: () => _selectBranch(TransactionWizardBranch.income),
          ),
          _buildBranchButton(
            label: 'Transfer',
            icon: CupertinoIcons.arrow_right_arrow_left,
            color: CupertinoColors.systemBlue,
            onTap: () => _selectBranch(TransactionWizardBranch.transfer),
          ),
        ],
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
              SizedBox(width: Spacing.lg),
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
                    SizedBox(height: Spacing.xxs),
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
          SizedBox(height: Spacing.xxl),
          Container(
            padding: EdgeInsets.symmetric(
                horizontal: Spacing.xl, vertical: Spacing.xl),
            decoration: BoxDecoration(
              color: AppStyles.getCardColor(context),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: (_branch == TransactionWizardBranch.income
                        ? CupertinoColors.systemGreen
                        : _branch == TransactionWizardBranch.expense
                            ? CupertinoColors.systemRed
                            : CupertinoColors.systemBlue)
                    .withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  '₹',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: _branch == TransactionWizardBranch.income
                        ? CupertinoColors.systemGreen
                        : _branch == TransactionWizardBranch.expense
                            ? CupertinoColors.systemRed
                            : CupertinoColors.systemBlue,
                  ),
                ),
                SizedBox(width: Spacing.sm),
                Expanded(
                  child: CupertinoTextField(
                    controller: _amountController,
                    autofocus: _currentStep == 1,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    textInputAction: TextInputAction.done,
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
        ? CupertinoColors.systemGreen
        : branch == TransactionWizardBranch.expense
            ? CupertinoColors.systemRed
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
          padding: const EdgeInsets.symmetric(vertical: 8),
          onPressed: onSkip,
          child: Text(
            'Skip',
            style: TextStyle(
              fontSize: TypeScale.footnote,
              color: AppStyles.getSecondaryTextColor(context),
            ),
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

  void _showDatePicker() {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => Container(
        height: 260,
        color: AppStyles.getCardColor(ctx),
        child: Column(
          children: [
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: _selectedDate,
                minimumDate: DateTime.now().subtract(const Duration(days: 365 * 30)),
                maximumDate: DateTime.now(),
                onDateTimeChanged: (value) {
                  setState(() => _selectedDate = value);
                },
              ),
            ),
            CupertinoButton(
              child: const Text('Done'),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
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
            borderRadius: BorderRadius.circular(16),
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
              SizedBox(width: Spacing.md),
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
                Icon(CupertinoIcons.checkmark_circle_fill,
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
                                borderRadius: BorderRadius.circular(12),
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
      CupertinoPageRoute(builder: (_) => const PaymentAppsScreen()),
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
                                borderRadius: BorderRadius.circular(12),
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
                                            style: TextStyle(
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
                borderRadius: BorderRadius.circular(12),
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
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(height: Spacing.md),
          CupertinoSegmentedControl<bool>(
            groupValue: _cashbackToApp,
            children: {
              true: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('Add to App wallet'),
              ),
              false: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
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
                    : GridView.count(
                        crossAxisCount: 2,
                        childAspectRatio: 3,
                        crossAxisSpacing: Spacing.sm,
                        mainAxisSpacing: Spacing.sm,
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
                                borderRadius: BorderRadius.circular(12),
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
                  placeholder: 'Type merchant name or search people',
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
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 12),
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
                              Icon(
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
                                    ? CupertinoColors.systemGreen
                                        .withValues(alpha: 0.12)
                                    : AppStyles.getCardColor(context),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? CupertinoColors.systemGreen
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
                                    const Icon(
                                      CupertinoIcons.checkmark_alt_circle_fill,
                                      color: CupertinoColors.systemGreen,
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
      builder: (ctx) => Container(
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
                    borderRadius: BorderRadius.circular(12),
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
      builder: (ctx) => _PhoneContactsPickerSheet(contacts: mappedContacts),
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
              TextField(
                controller: _descriptionController,
                autofocus: _currentStep == 9,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _nextStep(),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Notes for later',
                  filled: true,
                  fillColor: AppStyles.getCardColor(context),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                maxLines: 4,
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
                          borderRadius: BorderRadius.circular(16),
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
            ],
          ),
          footer: _buildOptionalFooter(
            onNext: _nextStep,
            onSkip: () {
              _descriptionController.clear();
              _nextStep();
            },
          ),
        );
      },
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
                        borderRadius: BorderRadius.circular(16),
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
                placeholder: 'Add new tag',
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
                  borderRadius: BorderRadius.circular(12),
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
      height: MediaQuery.of(context).size.height * 0.78,
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
                    style: AppStyles.titleStyle(context).copyWith(fontSize: TypeScale.title2),
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
                              borderRadius: BorderRadius.circular(12),
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
