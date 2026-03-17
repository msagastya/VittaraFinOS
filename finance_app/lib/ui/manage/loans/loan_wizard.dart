import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vittara_fin_os/logic/loan_model.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/widgets/animations.dart';
import 'package:vittara_fin_os/utils/date_formatter.dart';
import 'package:vittara_fin_os/utils/id_generator.dart';

class LoanWizard extends StatefulWidget {
  final Loan? existingLoan;
  final void Function(Loan) onSave;

  const LoanWizard({
    super.key,
    this.existingLoan,
    required this.onSave,
  });

  @override
  State<LoanWizard> createState() => _LoanWizardState();
}

class _LoanWizardState extends State<LoanWizard> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  static const int _totalSteps = 5;
  bool _isSaving = false;
  bool _hasUnsavedChanges = false;

  // Step 1 — Type
  LoanType _selectedType = LoanType.personal;

  // Step 2 — Basic Details
  final _nameController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _accountNumberController = TextEditingController();

  // Step 3 — Amounts
  final _principalController = TextEditingController();
  final _outstandingController = TextEditingController();
  final _emiController = TextEditingController();

  // Step 4 — Terms
  final _interestRateController = TextEditingController();
  final _tenureController = TextEditingController();
  final _remainingController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _nextDueDate = DateTime.now().add(const Duration(days: 7));

  @override
  void initState() {
    super.initState();
    final l = widget.existingLoan;
    if (l != null) {
      _selectedType = l.type;
      _nameController.text = l.name;
      _bankNameController.text = l.bankName ?? '';
      _accountNumberController.text = l.accountNumber ?? '';
      _principalController.text = l.principalAmount.toStringAsFixed(0);
      _outstandingController.text = l.currentOutstanding.toStringAsFixed(0);
      _emiController.text = l.emiAmount.toStringAsFixed(0);
      _interestRateController.text = l.interestRate.toStringAsFixed(2);
      _tenureController.text = l.tenureMonths.toString();
      _remainingController.text = l.remainingMonths.toString();
      _notesController.text = l.notes ?? '';
      _startDate = l.startDate;
      _nextDueDate = l.nextDueDate;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _bankNameController.dispose();
    _accountNumberController.dispose();
    _principalController.dispose();
    _outstandingController.dispose();
    _emiController.dispose();
    _interestRateController.dispose();
    _tenureController.dispose();
    _remainingController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _nextStep() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!_validateCurrentStep()) return;
    if (_currentStep < _totalSteps - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
      setState(() => _currentStep++);
    } else {
      _finishWizard();
    }
  }

  void _prevStep() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
      setState(() => _currentStep--);
    } else {
      _maybePop();
    }
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 1:
        if (_nameController.text.trim().isEmpty) {
          _showError('Please enter a loan name.');
          return false;
        }
        return true;
      case 2:
        final principal = double.tryParse(_principalController.text);
        final outstanding = double.tryParse(_outstandingController.text);
        final emi = double.tryParse(_emiController.text);
        if (principal == null || principal <= 0) {
          _showError('Enter a valid principal amount.');
          return false;
        }
        if (outstanding == null || outstanding < 0) {
          _showError('Enter a valid outstanding amount.');
          return false;
        }
        if (emi == null || emi <= 0) {
          _showError('Enter a valid EMI amount.');
          return false;
        }
        return true;
      case 3:
        final rate = double.tryParse(_interestRateController.text);
        final tenure = int.tryParse(_tenureController.text);
        final remaining = int.tryParse(_remainingController.text);
        if (rate == null || rate <= 0) {
          _showError('Enter a valid interest rate.');
          return false;
        }
        if (tenure == null || tenure <= 0) {
          _showError('Enter a valid tenure in months.');
          return false;
        }
        if (remaining == null || remaining < 0) {
          _showError('Enter valid remaining months.');
          return false;
        }
        return true;
      default:
        return true;
    }
  }

  void _showError(String message) {
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Validation Error'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _maybePop() async {
    if (!_hasUnsavedChanges) {
      Navigator.of(context).pop();
      return;
    }
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Discard Changes?'),
        content: const Text('Any unsaved data will be lost.'),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Discard'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep Editing'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      Navigator.of(context).pop();
    }
  }

  void _finishWizard() {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    final loan = Loan(
      id: widget.existingLoan?.id ?? IdGenerator.next(prefix: 'loan'),
      name: _nameController.text.trim(),
      type: _selectedType,
      principalAmount: double.parse(_principalController.text),
      currentOutstanding: double.parse(_outstandingController.text),
      interestRate: double.parse(_interestRateController.text),
      tenureMonths: int.parse(_tenureController.text),
      remainingMonths: int.parse(_remainingController.text),
      emiAmount: double.parse(_emiController.text),
      startDate: _startDate,
      nextDueDate: _nextDueDate,
      bankName: _bankNameController.text.trim().isNotEmpty
          ? _bankNameController.text.trim()
          : null,
      accountNumber: _accountNumberController.text.trim().isNotEmpty
          ? _accountNumberController.text.trim()
          : null,
      notes: _notesController.text.trim().isNotEmpty
          ? _notesController.text.trim()
          : null,
    );

    widget.onSave(loan);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_currentStep > 0) {
          _prevStep();
          return false;
        }
        if (_hasUnsavedChanges) {
          await _maybePop();
          return false;
        }
        return true;
      },
      child: CupertinoPageScaffold(
        backgroundColor: AppStyles.getBackground(context),
        navigationBar: CupertinoNavigationBar(
          middle: Text(
            widget.existingLoan != null ? 'Edit Loan' : 'Add Loan',
            style: TextStyle(color: AppStyles.getTextColor(context)),
          ),
          leading: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: _prevStep,
            child: Icon(
              _currentStep == 0
                  ? CupertinoIcons.xmark
                  : CupertinoIcons.arrow_left,
              color: AppStyles.getPrimaryColor(context),
              size: 20,
            ),
          ),
          backgroundColor: AppStyles.isDarkMode(context)
              ? Colors.black
              : Colors.white.withValues(alpha: 0.95),
          border: null,
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildStepIndicator(context),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _Step1TypeSelector(
                      selected: _selectedType,
                      onSelect: (t) {
                        setState(() {
                          _selectedType = t;
                          _hasUnsavedChanges = true;
                        });
                      },
                    ),
                    _Step2BasicDetails(
                      nameController: _nameController,
                      bankNameController: _bankNameController,
                      accountNumberController: _accountNumberController,
                      onChanged: () => setState(() => _hasUnsavedChanges = true),
                    ),
                    _Step3Amounts(
                      principalController: _principalController,
                      outstandingController: _outstandingController,
                      emiController: _emiController,
                      onChanged: () => setState(() => _hasUnsavedChanges = true),
                    ),
                    _Step4Terms(
                      interestRateController: _interestRateController,
                      tenureController: _tenureController,
                      remainingController: _remainingController,
                      notesController: _notesController,
                      startDate: _startDate,
                      nextDueDate: _nextDueDate,
                      onStartDateChanged: (d) =>
                          setState(() { _startDate = d; _hasUnsavedChanges = true; }),
                      onNextDueDateChanged: (d) =>
                          setState(() { _nextDueDate = d; _hasUnsavedChanges = true; }),
                      onChanged: () => setState(() => _hasUnsavedChanges = true),
                    ),
                    _Step5Review(
                      loanName: _nameController.text.trim(),
                      loanType: _selectedType,
                      bankName: _bankNameController.text.trim(),
                      principal: double.tryParse(_principalController.text) ?? 0,
                      outstanding: double.tryParse(_outstandingController.text) ?? 0,
                      emi: double.tryParse(_emiController.text) ?? 0,
                      interestRate: double.tryParse(_interestRateController.text) ?? 0,
                      tenureMonths: int.tryParse(_tenureController.text) ?? 0,
                      remainingMonths: int.tryParse(_remainingController.text) ?? 0,
                      startDate: _startDate,
                      nextDueDate: _nextDueDate,
                    ),
                  ],
                ),
              ),
              _buildBottomBar(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.md),
      child: Column(
        children: [
          Row(
            children: List.generate(_totalSteps, (i) {
              final done = i < _currentStep;
              final active = i == _currentStep;
              return Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 3,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: done
                        ? AppStyles.aetherTeal
                        : active
                            ? AppStyles.plasmaRed
                            : AppStyles.getDividerColor(context),
                    borderRadius: BorderRadius.circular(Radii.full),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: Spacing.xs),
          Text(
            'Step ${_currentStep + 1} of $_totalSteps',
            style: TextStyle(
              fontSize: TypeScale.caption,
              color: AppStyles.getSecondaryTextColor(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    final isLast = _currentStep == _totalSteps - 1;
    return Container(
      padding: EdgeInsets.fromLTRB(
        Spacing.lg,
        Spacing.md,
        Spacing.lg,
        Spacing.md + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: AppStyles.getBackground(context),
        border: Border(
          top: BorderSide(
            color: AppStyles.getDividerColor(context),
            width: 0.5,
          ),
        ),
      ),
      child: BouncyButton(
        onPressed: _isSaving ? () {} : _nextStep,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: Spacing.md),
          decoration: BoxDecoration(
            color: isLast ? AppStyles.aetherTeal : AppStyles.plasmaRed,
            borderRadius: BorderRadius.circular(Radii.lg),
            boxShadow: Shadows.fab(isLast ? AppStyles.aetherTeal : AppStyles.plasmaRed),
          ),
          alignment: Alignment.center,
          child: _isSaving
              ? const CupertinoActivityIndicator(color: Colors.white)
              : Text(
                  isLast ? 'Save Loan' : 'Continue',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ),
    );
  }
}

// ─── Step 1: Type Selector ────────────────────────────────────────────────────

class _Step1TypeSelector extends StatelessWidget {
  final LoanType selected;
  final void Function(LoanType) onSelect;

  const _Step1TypeSelector({
    required this.selected,
    required this.onSelect,
  });

  static const _types = LoanType.values;

  IconData _iconForType(LoanType type) {
    switch (type) {
      case LoanType.home:
        return CupertinoIcons.house_fill;
      case LoanType.car:
        return CupertinoIcons.car_fill;
      case LoanType.personal:
        return CupertinoIcons.person_fill;
      case LoanType.education:
        return CupertinoIcons.book_fill;
      case LoanType.gold:
        return CupertinoIcons.star_fill;
      case LoanType.creditCard:
        return CupertinoIcons.creditcard_fill;
      case LoanType.other:
        return CupertinoIcons.doc_fill;
    }
  }

  Color _colorForType(LoanType type) {
    switch (type) {
      case LoanType.home:
        return AppStyles.aetherTeal;
      case LoanType.car:
        return AppStyles.accentBlue;
      case LoanType.personal:
        return AppStyles.novaPurple;
      case LoanType.education:
        return AppStyles.solarGold;
      case LoanType.gold:
        return AppStyles.accentAmber;
      case LoanType.creditCard:
        return AppStyles.plasmaRed;
      case LoanType.other:
        return AppStyles.accentOrange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(Spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What type of loan?',
            style: TextStyle(
              fontSize: TypeScale.display,
              fontWeight: FontWeight.w800,
              color: AppStyles.getTextColor(context),
            ),
          ),
          const SizedBox(height: Spacing.xs),
          Text(
            'Select the loan category that best describes this debt.',
            style: TextStyle(
              fontSize: TypeScale.body,
              color: AppStyles.getSecondaryTextColor(context),
            ),
          ),
          const SizedBox(height: Spacing.xl),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.0,
            ),
            itemCount: _types.length,
            itemBuilder: (context, i) {
              final type = _types[i];
              final isSelected = type == selected;
              final color = _colorForType(type);
              return BouncyButton(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  onSelect(type);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? color.withValues(alpha: 0.18)
                        : AppStyles.getCardColor(context),
                    borderRadius: BorderRadius.circular(Radii.xl),
                    border: Border.all(
                      color: isSelected
                          ? color
                          : AppStyles.getDividerColor(context),
                      width: isSelected ? 1.5 : 1,
                    ),
                    boxShadow: isSelected ? Shadows.iconGlow(color) : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(_iconForType(type), color: color, size: 28),
                      const SizedBox(height: Spacing.xs),
                      Text(
                        type.displayName,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected
                              ? color
                              : AppStyles.getTextColor(context),
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─── Step 2: Basic Details ────────────────────────────────────────────────────

class _Step2BasicDetails extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController bankNameController;
  final TextEditingController accountNumberController;
  final VoidCallback onChanged;

  const _Step2BasicDetails({
    required this.nameController,
    required this.bankNameController,
    required this.accountNumberController,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(Spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Loan Details',
            style: TextStyle(
              fontSize: TypeScale.display,
              fontWeight: FontWeight.w800,
              color: AppStyles.getTextColor(context),
            ),
          ),
          const SizedBox(height: Spacing.xs),
          Text(
            'Give this loan a name you\'ll recognize.',
            style: TextStyle(
              fontSize: TypeScale.body,
              color: AppStyles.getSecondaryTextColor(context),
            ),
          ),
          const SizedBox(height: Spacing.xxl),
          _WizardField(
            controller: nameController,
            label: 'Loan Name',
            placeholder: 'e.g. SBI Home Loan',
            keyboardType: TextInputType.text,
            autofocus: true,
            onChanged: (_) => onChanged(),
          ),
          const SizedBox(height: Spacing.lg),
          _WizardField(
            controller: bankNameController,
            label: 'Bank / Lender Name',
            placeholder: 'e.g. State Bank of India (optional)',
            keyboardType: TextInputType.text,
            onChanged: (_) => onChanged(),
          ),
          const SizedBox(height: Spacing.lg),
          _WizardField(
            controller: accountNumberController,
            label: 'Account / Loan Number',
            placeholder: 'e.g. XXXX-XXXX-1234 (optional)',
            keyboardType: TextInputType.text,
            onChanged: (_) => onChanged(),
          ),
        ],
      ),
    );
  }
}

// ─── Step 3: Amounts ──────────────────────────────────────────────────────────

class _Step3Amounts extends StatelessWidget {
  final TextEditingController principalController;
  final TextEditingController outstandingController;
  final TextEditingController emiController;
  final VoidCallback onChanged;

  const _Step3Amounts({
    required this.principalController,
    required this.outstandingController,
    required this.emiController,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(Spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Loan Amounts',
            style: TextStyle(
              fontSize: TypeScale.display,
              fontWeight: FontWeight.w800,
              color: AppStyles.getTextColor(context),
            ),
          ),
          const SizedBox(height: Spacing.xs),
          Text(
            'Enter the original loan amount and current balance.',
            style: TextStyle(
              fontSize: TypeScale.body,
              color: AppStyles.getSecondaryTextColor(context),
            ),
          ),
          const SizedBox(height: Spacing.xxl),
          _WizardField(
            controller: principalController,
            label: 'Principal Amount (₹)',
            placeholder: 'Original loan amount',
            keyboardType: const TextInputType.numberWithOptions(decimal: false),
            autofocus: true,
            onChanged: (_) => onChanged(),
          ),
          const SizedBox(height: Spacing.lg),
          _WizardField(
            controller: outstandingController,
            label: 'Current Outstanding (₹)',
            placeholder: 'Remaining balance as of today',
            keyboardType: const TextInputType.numberWithOptions(decimal: false),
            onChanged: (_) => onChanged(),
          ),
          const SizedBox(height: Spacing.lg),
          _WizardField(
            controller: emiController,
            label: 'Monthly EMI (₹)',
            placeholder: 'Monthly instalment amount',
            keyboardType: const TextInputType.numberWithOptions(decimal: false),
            onChanged: (_) => onChanged(),
          ),
        ],
      ),
    );
  }
}

// ─── Step 4: Terms ────────────────────────────────────────────────────────────

class _Step4Terms extends StatelessWidget {
  final TextEditingController interestRateController;
  final TextEditingController tenureController;
  final TextEditingController remainingController;
  final TextEditingController notesController;
  final DateTime startDate;
  final DateTime nextDueDate;
  final void Function(DateTime) onStartDateChanged;
  final void Function(DateTime) onNextDueDateChanged;
  final VoidCallback onChanged;

  const _Step4Terms({
    required this.interestRateController,
    required this.tenureController,
    required this.remainingController,
    required this.notesController,
    required this.startDate,
    required this.nextDueDate,
    required this.onStartDateChanged,
    required this.onNextDueDateChanged,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(Spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Loan Terms',
            style: TextStyle(
              fontSize: TypeScale.display,
              fontWeight: FontWeight.w800,
              color: AppStyles.getTextColor(context),
            ),
          ),
          const SizedBox(height: Spacing.xs),
          Text(
            'Set the interest rate, tenure, and key dates.',
            style: TextStyle(
              fontSize: TypeScale.body,
              color: AppStyles.getSecondaryTextColor(context),
            ),
          ),
          const SizedBox(height: Spacing.xxl),
          _WizardField(
            controller: interestRateController,
            label: 'Interest Rate (% per annum)',
            placeholder: 'e.g. 8.5',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            onChanged: (_) => onChanged(),
          ),
          const SizedBox(height: Spacing.lg),
          Row(
            children: [
              Expanded(
                child: _WizardField(
                  controller: tenureController,
                  label: 'Total Tenure (months)',
                  placeholder: 'e.g. 240',
                  keyboardType: TextInputType.number,
                  onChanged: (_) => onChanged(),
                ),
              ),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: _WizardField(
                  controller: remainingController,
                  label: 'Months Remaining',
                  placeholder: 'e.g. 192',
                  keyboardType: TextInputType.number,
                  onChanged: (_) => onChanged(),
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.lg),
          _DatePickerField(
            label: 'Loan Start Date',
            date: startDate,
            onChanged: onStartDateChanged,
          ),
          const SizedBox(height: Spacing.lg),
          _DatePickerField(
            label: 'Next EMI Due Date',
            date: nextDueDate,
            onChanged: onNextDueDateChanged,
          ),
          const SizedBox(height: Spacing.lg),
          _WizardField(
            controller: notesController,
            label: 'Notes (optional)',
            placeholder: 'Any additional details...',
            keyboardType: TextInputType.multiline,
            maxLines: 3,
            onChanged: (_) => onChanged(),
          ),
        ],
      ),
    );
  }
}

// ─── Step 5: Review ───────────────────────────────────────────────────────────

class _Step5Review extends StatelessWidget {
  final String loanName;
  final LoanType loanType;
  final String bankName;
  final double principal;
  final double outstanding;
  final double emi;
  final double interestRate;
  final int tenureMonths;
  final int remainingMonths;
  final DateTime startDate;
  final DateTime nextDueDate;

  const _Step5Review({
    required this.loanName,
    required this.loanType,
    required this.bankName,
    required this.principal,
    required this.outstanding,
    required this.emi,
    required this.interestRate,
    required this.tenureMonths,
    required this.remainingMonths,
    required this.startDate,
    required this.nextDueDate,
  });

  @override
  Widget build(BuildContext context) {
    final totalInterest = (emi * tenureMonths) - principal;
    final progressPercent =
        principal > 0 ? ((principal - outstanding) / principal).clamp(0.0, 1.0) : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(Spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Review & Save',
            style: TextStyle(
              fontSize: TypeScale.display,
              fontWeight: FontWeight.w800,
              color: AppStyles.getTextColor(context),
            ),
          ),
          const SizedBox(height: Spacing.xs),
          Text(
            'Confirm the details before saving.',
            style: TextStyle(
              fontSize: TypeScale.body,
              color: AppStyles.getSecondaryTextColor(context),
            ),
          ),
          const SizedBox(height: Spacing.xxl),
          Container(
            decoration: AppStyles.cardDecoration(context),
            padding: const EdgeInsets.all(Spacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ReviewRow(
                  label: 'Loan Name',
                  value: loanName.isEmpty ? '—' : loanName,
                  valueColor: AppStyles.getTextColor(context),
                ),
                _ReviewRow(label: 'Type', value: loanType.displayName),
                if (bankName.isNotEmpty) _ReviewRow(label: 'Bank', value: bankName),
                _divider(context),
                _ReviewRow(
                  label: 'Principal',
                  value: CurrencyFormatter.compact(principal),
                ),
                _ReviewRow(
                  label: 'Outstanding',
                  value: CurrencyFormatter.compact(outstanding),
                  valueColor: AppStyles.plasmaRed,
                ),
                _ReviewRow(
                  label: 'Monthly EMI',
                  value: CurrencyFormatter.format(emi, decimals: 0),
                  valueColor: AppStyles.aetherTeal,
                ),
                _divider(context),
                _ReviewRow(
                  label: 'Interest Rate',
                  value: '$interestRate% p.a.',
                ),
                _ReviewRow(
                  label: 'Tenure',
                  value: '$tenureMonths months',
                ),
                _ReviewRow(
                  label: 'Remaining',
                  value: '$remainingMonths months',
                ),
                _ReviewRow(
                  label: 'Est. Total Interest',
                  value: CurrencyFormatter.compact(totalInterest > 0 ? totalInterest : 0),
                  valueColor: AppStyles.accentOrange,
                ),
                _divider(context),
                _ReviewRow(
                  label: 'Start Date',
                  value: DateFormatter.format(startDate),
                ),
                _ReviewRow(
                  label: 'Next Due',
                  value: DateFormatter.format(nextDueDate),
                ),
                const SizedBox(height: Spacing.md),
                Text(
                  'Progress',
                  style: TextStyle(
                    fontSize: TypeScale.caption,
                    color: AppStyles.getSecondaryTextColor(context),
                  ),
                ),
                const SizedBox(height: Spacing.xs),
                ClipRRect(
                  borderRadius: BorderRadius.circular(Radii.full),
                  child: LinearProgressIndicator(
                    value: progressPercent,
                    minHeight: 8,
                    backgroundColor: AppStyles.getDividerColor(context),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      progressPercent >= 0.8
                          ? AppStyles.bioGreen
                          : AppStyles.aetherTeal,
                    ),
                  ),
                ),
                const SizedBox(height: Spacing.xs),
                Text(
                  '${(progressPercent * 100).toStringAsFixed(0)}% paid off',
                  style: TextStyle(
                    fontSize: TypeScale.caption,
                    color: AppStyles.getSecondaryTextColor(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
      child: Divider(
        color: AppStyles.getDividerColor(context),
        height: 1,
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _ReviewRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: TypeScale.body,
              color: AppStyles.getSecondaryTextColor(context),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: TypeScale.body,
              fontWeight: FontWeight.w600,
              color: valueColor ?? AppStyles.getTextColor(context),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Shared Wizard Widgets ────────────────────────────────────────────────────

class _WizardField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String placeholder;
  final TextInputType keyboardType;
  final bool autofocus;
  final void Function(String)? onChanged;
  final int? maxLines;

  const _WizardField({
    required this.controller,
    required this.label,
    required this.placeholder,
    required this.keyboardType,
    this.autofocus = false,
    this.onChanged,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppStyles.isDarkMode(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: TypeScale.caption,
            fontWeight: FontWeight.w600,
            color: AppStyles.getSecondaryTextColor(context),
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: Spacing.xs),
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0D0D0D) : AppStyles.lightCard,
            borderRadius: BorderRadius.circular(Radii.md),
            border: Border.all(
              color: AppStyles.getDividerColor(context),
              width: 1,
            ),
          ),
          child: CupertinoTextField(
            controller: controller,
            placeholder: placeholder,
            keyboardType: keyboardType,
            autofocus: autofocus,
            maxLines: maxLines,
            onChanged: onChanged,
            style: TextStyle(
              color: AppStyles.getTextColor(context),
              fontSize: TypeScale.body,
            ),
            placeholderStyle: TextStyle(
              color: AppStyles.getSecondaryTextColor(context).withValues(alpha: 0.6),
              fontSize: TypeScale.body,
            ),
            padding: const EdgeInsets.all(Spacing.md),
            decoration: const BoxDecoration(),
          ),
        ),
      ],
    );
  }
}

class _DatePickerField extends StatelessWidget {
  final String label;
  final DateTime date;
  final void Function(DateTime) onChanged;

  const _DatePickerField({
    required this.label,
    required this.date,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppStyles.isDarkMode(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: TypeScale.caption,
            fontWeight: FontWeight.w600,
            color: AppStyles.getSecondaryTextColor(context),
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: Spacing.xs),
        GestureDetector(
          onTap: () => _showDatePicker(context),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0D0D0D) : AppStyles.lightCard,
              borderRadius: BorderRadius.circular(Radii.md),
              border: Border.all(
                color: AppStyles.getDividerColor(context),
                width: 1,
              ),
            ),
            padding: const EdgeInsets.all(Spacing.md),
            child: Row(
              children: [
                Icon(
                  CupertinoIcons.calendar,
                  size: 16,
                  color: AppStyles.getPrimaryColor(context),
                ),
                const SizedBox(width: Spacing.sm),
                Text(
                  DateFormatter.format(date),
                  style: TextStyle(
                    fontSize: TypeScale.body,
                    color: AppStyles.getTextColor(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showDatePicker(BuildContext context) async {
    DateTime picked = date;
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => Container(
        height: 280,
        color: AppStyles.getCardColor(context),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.sm),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: AppStyles.getSecondaryTextColor(context),
                      ),
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      onChanged(picked);
                      Navigator.of(ctx).pop();
                    },
                    child: Text(
                      'Done',
                      style: TextStyle(
                        color: AppStyles.getPrimaryColor(context),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: date,
                maximumDate: DateTime.now().add(const Duration(days: 365 * 30)),
                minimumDate: DateTime(2000),
                onDateTimeChanged: (d) => picked = d,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
