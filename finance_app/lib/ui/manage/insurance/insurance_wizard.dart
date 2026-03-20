import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vittara_fin_os/logic/insurance_model.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/widgets/animations.dart';
import 'package:vittara_fin_os/utils/date_formatter.dart';
import 'package:vittara_fin_os/utils/id_generator.dart';

class InsuranceWizard extends StatefulWidget {
  final InsurancePolicy? existingPolicy;
  final void Function(InsurancePolicy) onSave;

  const InsuranceWizard({
    super.key,
    this.existingPolicy,
    required this.onSave,
  });

  @override
  State<InsuranceWizard> createState() => _InsuranceWizardState();
}

class _InsuranceWizardState extends State<InsuranceWizard> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  static const int _totalSteps = 5;
  bool _isSaving = false;
  bool _hasUnsavedChanges = false;

  // Step 1 — Type
  InsuranceType _selectedType = InsuranceType.health;

  // Step 2 — Policy Details
  final _nameController = TextEditingController();
  final _insurerController = TextEditingController();
  final _policyNumberController = TextEditingController();

  // Step 3 — Financial Details
  final _premiumController = TextEditingController();
  String _premiumFrequency = 'annual';
  final _sumInsuredController = TextEditingController();

  // Step 4 — Dates + Nominee
  DateTime _startDate = DateTime.now();
  // Used for: health/vehicle/home/other (renewal), travel (trip end)
  DateTime _renewalDate = DateTime.now().add(const Duration(days: 365));
  // Used for: term (auto-calculated), life (user-picked)
  DateTime? _maturityDate;
  int? _policyTermYears;
  int? _premiumPayingTermYears;
  final _policyTermController = TextEditingController();
  final _premPayingTermController = TextEditingController();
  final _nomineeController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final p = widget.existingPolicy;
    if (p != null) {
      _selectedType = p.type;
      _nameController.text = p.name;
      _insurerController.text = p.insurer;
      _policyNumberController.text = p.policyNumber ?? '';
      _premiumController.text = p.premiumAmount.toStringAsFixed(0);
      _premiumFrequency = p.premiumFrequency;
      _sumInsuredController.text = p.sumInsured.toStringAsFixed(0);
      _startDate = p.startDate;
      _renewalDate = p.renewalDate;
      _maturityDate = p.maturityDate;
      _policyTermYears = p.policyTermYears;
      _premiumPayingTermYears = p.premiumPayingTermYears;
      if (p.policyTermYears != null) {
        _policyTermController.text = p.policyTermYears.toString();
      }
      if (p.premiumPayingTermYears != null) {
        _premPayingTermController.text = p.premiumPayingTermYears.toString();
      }
      _nomineeController.text = p.nomineeName ?? '';
      _notesController.text = p.notes ?? '';
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _insurerController.dispose();
    _policyNumberController.dispose();
    _premiumController.dispose();
    _sumInsuredController.dispose();
    _policyTermController.dispose();
    _premPayingTermController.dispose();
    _nomineeController.dispose();
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
          _showError('Please enter a policy name.');
          return false;
        }
        if (_insurerController.text.trim().isEmpty) {
          _showError('Please enter the insurer name.');
          return false;
        }
        return true;
      case 2:
        final premium = double.tryParse(_premiumController.text);
        final sumInsured = double.tryParse(_sumInsuredController.text);
        if (premium == null || premium <= 0) {
          _showError('Enter a valid premium amount.');
          return false;
        }
        if (sumInsured == null || sumInsured <= 0) {
          _showError('Enter a valid sum insured amount.');
          return false;
        }
        return true;
      case 3:
        // Validate date step based on type
        if (_selectedType == InsuranceType.term) {
          if (_policyTermYears == null || _policyTermYears! <= 0) {
            _showError('Please enter a valid policy term (years).');
            return false;
          }
        } else if (_selectedType == InsuranceType.life) {
          if (_maturityDate == null) {
            _showError('Please select a maturity date.');
            return false;
          }
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

    // For term/life, store maturityDate as the effective date.
    // renewalDate is set to maturityDate for fallback compatibility.
    final DateTime effectiveRenewal;
    if (_selectedType.usesMaturityDate) {
      effectiveRenewal = _maturityDate ?? _renewalDate;
    } else {
      effectiveRenewal = _renewalDate;
    }

    final policy = InsurancePolicy(
      id: widget.existingPolicy?.id ?? IdGenerator.next(prefix: 'ins'),
      name: _nameController.text.trim(),
      type: _selectedType,
      insurer: _insurerController.text.trim(),
      policyNumber: _policyNumberController.text.trim().isNotEmpty
          ? _policyNumberController.text.trim()
          : null,
      premiumAmount: double.parse(_premiumController.text),
      premiumFrequency: _premiumFrequency,
      sumInsured: double.parse(_sumInsuredController.text),
      renewalDate: effectiveRenewal,
      startDate: _startDate,
      nomineeName: _nomineeController.text.trim().isNotEmpty
          ? _nomineeController.text.trim()
          : null,
      notes: _notesController.text.trim().isNotEmpty
          ? _notesController.text.trim()
          : null,
      maturityDate: _selectedType.usesMaturityDate ? _maturityDate : null,
      policyTermYears: _policyTermYears,
      premiumPayingTermYears: _premiumPayingTermYears,
    );

    widget.onSave(policy);
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
            widget.existingPolicy != null ? 'Edit Policy' : 'Add Insurance',
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
                          // Reset type-specific date fields on type change
                          _maturityDate = null;
                          _policyTermYears = null;
                          _premiumPayingTermYears = null;
                          _policyTermController.clear();
                          _premPayingTermController.clear();
                        });
                      },
                    ),
                    _Step2PolicyDetails(
                      nameController: _nameController,
                      insurerController: _insurerController,
                      policyNumberController: _policyNumberController,
                      onChanged: () =>
                          setState(() => _hasUnsavedChanges = true),
                    ),
                    _Step3FinancialDetails(
                      premiumController: _premiumController,
                      premiumFrequency: _premiumFrequency,
                      sumInsuredController: _sumInsuredController,
                      onFrequencyChanged: (freq) => setState(() {
                        _premiumFrequency = freq;
                        _hasUnsavedChanges = true;
                      }),
                      onChanged: () =>
                          setState(() => _hasUnsavedChanges = true),
                    ),
                    _Step4DatesNominee(
                      selectedType: _selectedType,
                      startDate: _startDate,
                      renewalDate: _renewalDate,
                      maturityDate: _maturityDate,
                      policyTermYears: _policyTermYears,
                      premiumPayingTermYears: _premiumPayingTermYears,
                      policyTermController: _policyTermController,
                      premPayingTermController: _premPayingTermController,
                      nomineeController: _nomineeController,
                      notesController: _notesController,
                      onStartDateChanged: (d) => setState(() {
                        _startDate = d;
                        _hasUnsavedChanges = true;
                        // Auto-recalculate maturity for term
                        if (_selectedType == InsuranceType.term &&
                            _policyTermYears != null) {
                          _maturityDate = DateTime(
                            d.year + _policyTermYears!,
                            d.month,
                            d.day,
                          );
                        }
                      }),
                      onRenewalDateChanged: (d) => setState(() {
                        _renewalDate = d;
                        _hasUnsavedChanges = true;
                      }),
                      onMaturityDateChanged: (d) => setState(() {
                        _maturityDate = d;
                        _hasUnsavedChanges = true;
                      }),
                      onPolicyTermChanged: (years) => setState(() {
                        _policyTermYears = years;
                        _hasUnsavedChanges = true;
                        if (years != null && years > 0) {
                          _maturityDate = DateTime(
                            _startDate.year + years,
                            _startDate.month,
                            _startDate.day,
                          );
                        } else {
                          _maturityDate = null;
                        }
                      }),
                      onPremPayingTermChanged: (years) => setState(() {
                        _premiumPayingTermYears = years;
                        _hasUnsavedChanges = true;
                      }),
                      onChanged: () =>
                          setState(() => _hasUnsavedChanges = true),
                    ),
                    _Step5Review(
                      policyName: _nameController.text.trim(),
                      insurer: _insurerController.text.trim(),
                      policyNumber: _policyNumberController.text.trim(),
                      policyType: _selectedType,
                      premiumAmount:
                          double.tryParse(_premiumController.text) ?? 0,
                      premiumFrequency: _premiumFrequency,
                      sumInsured:
                          double.tryParse(_sumInsuredController.text) ?? 0,
                      startDate: _startDate,
                      renewalDate: _renewalDate,
                      maturityDate: _maturityDate,
                      policyTermYears: _policyTermYears,
                      premiumPayingTermYears: _premiumPayingTermYears,
                      nomineeName: _nomineeController.text.trim(),
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
      padding: const EdgeInsets.symmetric(
          horizontal: Spacing.lg, vertical: Spacing.md),
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
                            ? AppStyles.accentBlue
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
    const accentColor = AppStyles.accentBlue;
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
            color: isLast ? AppStyles.aetherTeal : accentColor,
            borderRadius: BorderRadius.circular(Radii.lg),
            boxShadow:
                Shadows.fab(isLast ? AppStyles.aetherTeal : accentColor),
          ),
          alignment: Alignment.center,
          child: _isSaving
              ? const CupertinoActivityIndicator(color: Colors.white)
              : Text(
                  isLast ? 'Save Policy' : 'Continue',
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
  final InsuranceType selected;
  final void Function(InsuranceType) onSelect;

  const _Step1TypeSelector({
    required this.selected,
    required this.onSelect,
  });

  static const _types = InsuranceType.values;

  IconData _iconForType(InsuranceType type) {
    switch (type) {
      case InsuranceType.health:
        return CupertinoIcons.heart_fill;
      case InsuranceType.life:
        return CupertinoIcons.person_fill;
      case InsuranceType.term:
        return CupertinoIcons.shield_fill;
      case InsuranceType.vehicle:
        return CupertinoIcons.car_fill;
      case InsuranceType.travel:
        return CupertinoIcons.airplane;
      case InsuranceType.home:
        return CupertinoIcons.house_fill;
      case InsuranceType.other:
        return CupertinoIcons.doc_fill;
    }
  }

  Color _colorForType(InsuranceType type) {
    switch (type) {
      case InsuranceType.health:
        return AppStyles.plasmaRed;
      case InsuranceType.life:
        return AppStyles.aetherTeal;
      case InsuranceType.term:
        return AppStyles.novaPurple;
      case InsuranceType.vehicle:
        return AppStyles.accentBlue;
      case InsuranceType.travel:
        return AppStyles.accentOrange;
      case InsuranceType.home:
        return AppStyles.bioGreen;
      case InsuranceType.other:
        return AppStyles.solarGold;
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
            'Insurance Type',
            style: TextStyle(
              fontSize: TypeScale.display,
              fontWeight: FontWeight.w800,
              color: AppStyles.getTextColor(context),
            ),
          ),
          const SizedBox(height: Spacing.xs),
          Text(
            'Select the category that best describes this policy.',
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
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
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

// ─── Step 2: Policy Details ───────────────────────────────────────────────────

class _Step2PolicyDetails extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController insurerController;
  final TextEditingController policyNumberController;
  final VoidCallback onChanged;

  const _Step2PolicyDetails({
    required this.nameController,
    required this.insurerController,
    required this.policyNumberController,
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
            'Policy Details',
            style: TextStyle(
              fontSize: TypeScale.display,
              fontWeight: FontWeight.w800,
              color: AppStyles.getTextColor(context),
            ),
          ),
          const SizedBox(height: Spacing.xs),
          Text(
            'Name this policy so you can find it easily.',
            style: TextStyle(
              fontSize: TypeScale.body,
              color: AppStyles.getSecondaryTextColor(context),
            ),
          ),
          const SizedBox(height: Spacing.xxl),
          _WizardField(
            controller: nameController,
            label: 'Policy Name',
            placeholder: 'e.g. Star Health Senior Citizen Red Carpet',
            keyboardType: TextInputType.text,
            autofocus: true,
            onChanged: (_) => onChanged(),
          ),
          const SizedBox(height: Spacing.lg),
          _WizardField(
            controller: insurerController,
            label: 'Insurer / Insurance Company',
            placeholder: 'e.g. HDFC ERGO, LIC, Star Health',
            keyboardType: TextInputType.text,
            onChanged: (_) => onChanged(),
          ),
          const SizedBox(height: Spacing.lg),
          _WizardField(
            controller: policyNumberController,
            label: 'Policy Number (optional)',
            placeholder: 'e.g. P/141213/01/2024/000123',
            keyboardType: TextInputType.text,
            onChanged: (_) => onChanged(),
          ),
        ],
      ),
    );
  }
}

// ─── Step 3: Financial Details ────────────────────────────────────────────────

class _Step3FinancialDetails extends StatelessWidget {
  final TextEditingController premiumController;
  final String premiumFrequency;
  final TextEditingController sumInsuredController;
  final void Function(String) onFrequencyChanged;
  final VoidCallback onChanged;

  const _Step3FinancialDetails({
    required this.premiumController,
    required this.premiumFrequency,
    required this.sumInsuredController,
    required this.onFrequencyChanged,
    required this.onChanged,
  });

  static const _frequencies = ['monthly', 'quarterly', 'annual'];

  String _frequencyLabel(String freq) {
    switch (freq) {
      case 'monthly':
        return 'Monthly';
      case 'quarterly':
        return 'Quarterly';
      case 'annual':
      default:
        return 'Annual';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppStyles.isDarkMode(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(Spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Financial Details',
            style: TextStyle(
              fontSize: TypeScale.display,
              fontWeight: FontWeight.w800,
              color: AppStyles.getTextColor(context),
            ),
          ),
          const SizedBox(height: Spacing.xs),
          Text(
            'Enter premium amount and coverage details.',
            style: TextStyle(
              fontSize: TypeScale.body,
              color: AppStyles.getSecondaryTextColor(context),
            ),
          ),
          const SizedBox(height: Spacing.xxl),
          _WizardField(
            controller: premiumController,
            label: 'Premium Amount (Rs)',
            placeholder: 'Amount per payment period',
            keyboardType:
                const TextInputType.numberWithOptions(decimal: false),
            autofocus: true,
            onChanged: (_) => onChanged(),
          ),
          const SizedBox(height: Spacing.lg),
          Text(
            'PAYMENT FREQUENCY',
            style: TextStyle(
              fontSize: TypeScale.caption,
              fontWeight: FontWeight.w600,
              color: AppStyles.getSecondaryTextColor(context),
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: Spacing.xs),
          Row(
            children: _frequencies.map((freq) {
              final isSelected = freq == premiumFrequency;
              const color = AppStyles.accentBlue;
              final isLast = freq == 'annual';
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                      right: isLast ? 0 : Spacing.sm),
                  child: BouncyButton(
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      onFrequencyChanged(freq);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding:
                          const EdgeInsets.symmetric(vertical: Spacing.sm),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? color.withValues(alpha: 0.15)
                            : isDark
                                ? const Color(0xFF0D0D0D)
                                : AppStyles.lightCard,
                        borderRadius:
                            BorderRadius.circular(Radii.md),
                        border: Border.all(
                          color: isSelected
                              ? color
                              : AppStyles.getDividerColor(context),
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _frequencyLabel(freq),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isSelected
                              ? color
                              : AppStyles.getTextColor(context),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: Spacing.lg),
          _WizardField(
            controller: sumInsuredController,
            label: 'Sum Insured / Coverage (Rs)',
            placeholder: 'Total coverage amount',
            keyboardType:
                const TextInputType.numberWithOptions(decimal: false),
            onChanged: (_) => onChanged(),
          ),
        ],
      ),
    );
  }
}

// ─── Step 4: Dates + Nominee ──────────────────────────────────────────────────

class _Step4DatesNominee extends StatelessWidget {
  final InsuranceType selectedType;
  final DateTime startDate;
  final DateTime renewalDate;
  final DateTime? maturityDate;
  final int? policyTermYears;
  final int? premiumPayingTermYears;
  final TextEditingController policyTermController;
  final TextEditingController premPayingTermController;
  final TextEditingController nomineeController;
  final TextEditingController notesController;
  final void Function(DateTime) onStartDateChanged;
  final void Function(DateTime) onRenewalDateChanged;
  final void Function(DateTime?) onMaturityDateChanged;
  final void Function(int?) onPolicyTermChanged;
  final void Function(int?) onPremPayingTermChanged;
  final VoidCallback onChanged;

  const _Step4DatesNominee({
    required this.selectedType,
    required this.startDate,
    required this.renewalDate,
    required this.maturityDate,
    required this.policyTermYears,
    required this.premiumPayingTermYears,
    required this.policyTermController,
    required this.premPayingTermController,
    required this.nomineeController,
    required this.notesController,
    required this.onStartDateChanged,
    required this.onRenewalDateChanged,
    required this.onMaturityDateChanged,
    required this.onPolicyTermChanged,
    required this.onPremPayingTermChanged,
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
            'Dates & Nominee',
            style: TextStyle(
              fontSize: TypeScale.display,
              fontWeight: FontWeight.w800,
              color: AppStyles.getTextColor(context),
            ),
          ),
          const SizedBox(height: Spacing.xs),
          Text(
            _subtitleForType(selectedType),
            style: TextStyle(
              fontSize: TypeScale.body,
              color: AppStyles.getSecondaryTextColor(context),
            ),
          ),
          const SizedBox(height: Spacing.xxl),
          _DatePickerField(
            label: 'Policy Start Date',
            date: startDate,
            onChanged: onStartDateChanged,
          ),
          const SizedBox(height: Spacing.lg),
          ..._buildTypeDateFields(context),
          const SizedBox(height: Spacing.lg),
          _WizardField(
            controller: nomineeController,
            label: 'Nominee Name (optional)',
            placeholder: 'e.g. Priya Sharma',
            keyboardType: TextInputType.text,
            onChanged: (_) => onChanged(),
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

  String _subtitleForType(InsuranceType type) {
    switch (type) {
      case InsuranceType.term:
        return 'Enter the policy term — maturity date is calculated automatically.';
      case InsuranceType.life:
        return 'Set the maturity date and premium paying term.';
      case InsuranceType.travel:
        return 'Set trip dates and nominee details.';
      default:
        return 'Set the policy dates and nominee details.';
    }
  }

  List<Widget> _buildTypeDateFields(BuildContext context) {
    switch (selectedType) {
      case InsuranceType.term:
        return _buildTermFields(context);
      case InsuranceType.life:
        return _buildLifeFields(context);
      case InsuranceType.travel:
        return _buildTravelFields(context);
      default:
        return _buildRenewalFields(context);
    }
  }

  // Term: policy term years input + auto-calculated maturity date display
  List<Widget> _buildTermFields(BuildContext context) {
    return [
      _WizardField(
        controller: policyTermController,
        label: 'Policy Term (years)',
        placeholder: 'e.g. 30',
        keyboardType: TextInputType.number,
        onChanged: (val) {
          final years = int.tryParse(val.trim());
          onPolicyTermChanged(years);
        },
      ),
      if (maturityDate != null) ...[
        const SizedBox(height: Spacing.md),
        _InfoBanner(
          icon: CupertinoIcons.calendar_badge_plus,
          color: AppStyles.novaPurple,
          label: 'Calculated Maturity Date',
          value: DateFormatter.format(maturityDate!),
        ),
      ],
    ];
  }

  // Life: maturity date picker + optional premium paying term
  List<Widget> _buildLifeFields(BuildContext context) {
    return [
      _DatePickerField(
        label: 'Maturity Date',
        date: maturityDate ?? DateTime.now().add(const Duration(days: 365 * 20)),
        onChanged: (d) => onMaturityDateChanged(d),
      ),
      const SizedBox(height: Spacing.lg),
      _WizardField(
        controller: premPayingTermController,
        label: 'Premium Paying Term (years, optional)',
        placeholder: 'e.g. 20  (leave blank if same as policy)',
        keyboardType: TextInputType.number,
        onChanged: (val) {
          final years = int.tryParse(val.trim());
          onPremPayingTermChanged(years);
        },
      ),
    ];
  }

  // Travel: trip end date (semantically a "renewal" but different label)
  List<Widget> _buildTravelFields(BuildContext context) {
    return [
      _DatePickerField(
        label: 'Trip End Date',
        date: renewalDate,
        onChanged: onRenewalDateChanged,
      ),
    ];
  }

  // Health / Vehicle / Home / Other: renewal date
  List<Widget> _buildRenewalFields(BuildContext context) {
    return [
      _DatePickerField(
        label: selectedType == InsuranceType.vehicle
            ? 'Renewal / Expiry Date'
            : 'Renewal Date',
        date: renewalDate,
        onChanged: onRenewalDateChanged,
      ),
    ];
  }
}

// ─── Step 5: Review ───────────────────────────────────────────────────────────

class _Step5Review extends StatelessWidget {
  final String policyName;
  final String insurer;
  final String policyNumber;
  final InsuranceType policyType;
  final double premiumAmount;
  final String premiumFrequency;
  final double sumInsured;
  final DateTime startDate;
  final DateTime renewalDate;
  final DateTime? maturityDate;
  final int? policyTermYears;
  final int? premiumPayingTermYears;
  final String nomineeName;

  const _Step5Review({
    required this.policyName,
    required this.insurer,
    required this.policyNumber,
    required this.policyType,
    required this.premiumAmount,
    required this.premiumFrequency,
    required this.sumInsured,
    required this.startDate,
    required this.renewalDate,
    required this.maturityDate,
    required this.policyTermYears,
    required this.premiumPayingTermYears,
    required this.nomineeName,
  });

  double get _annualPremium {
    switch (premiumFrequency) {
      case 'monthly':
        return premiumAmount * 12;
      case 'quarterly':
        return premiumAmount * 4;
      default:
        return premiumAmount;
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
                  label: 'Policy Name',
                  value: policyName.isEmpty ? '—' : policyName,
                  valueColor: AppStyles.getTextColor(context),
                ),
                _ReviewRow(label: 'Type', value: policyType.displayName),
                _ReviewRow(
                  label: 'Insurer',
                  value: insurer.isEmpty ? '—' : insurer,
                ),
                if (policyNumber.isNotEmpty)
                  _ReviewRow(label: 'Policy No.', value: policyNumber),
                _divider(context),
                _ReviewRow(
                  label: 'Premium',
                  value:
                      '${CurrencyFormatter.compact(premiumAmount)} / $premiumFrequency',
                  valueColor: AppStyles.accentBlue,
                ),
                _ReviewRow(
                  label: 'Annual Premium',
                  value: CurrencyFormatter.compact(_annualPremium),
                  valueColor: AppStyles.accentOrange,
                ),
                _ReviewRow(
                  label: 'Sum Insured',
                  value: CurrencyFormatter.compact(sumInsured),
                  valueColor: AppStyles.aetherTeal,
                ),
                _divider(context),
                _ReviewRow(
                  label: 'Start Date',
                  value: DateFormatter.format(startDate),
                ),
                ..._buildDateReviewRows(context),
                if (nomineeName.isNotEmpty)
                  _ReviewRow(label: 'Nominee', value: nomineeName),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildDateReviewRows(BuildContext context) {
    switch (policyType) {
      case InsuranceType.term:
        final termText =
            policyTermYears != null ? '$policyTermYears years' : '—';
        final matText = maturityDate != null
            ? DateFormatter.format(maturityDate!)
            : '—';
        final isSoon = maturityDate != null &&
            maturityDate!.isBefore(
                DateTime.now().add(const Duration(days: 30)));
        return [
          _ReviewRow(label: 'Policy Term', value: termText),
          _ReviewRow(
            label: 'Maturity Date',
            value: matText,
            valueColor: isSoon ? AppStyles.accentOrange : null,
          ),
        ];

      case InsuranceType.life:
        final matText = maturityDate != null
            ? DateFormatter.format(maturityDate!)
            : '—';
        final isSoon = maturityDate != null &&
            maturityDate!.isBefore(
                DateTime.now().add(const Duration(days: 30)));
        final payTermText = premiumPayingTermYears != null
            ? '$premiumPayingTermYears years'
            : '—';
        return [
          _ReviewRow(
            label: 'Maturity Date',
            value: matText,
            valueColor: isSoon ? AppStyles.accentOrange : null,
          ),
          _ReviewRow(
            label: 'Premium Paying Term',
            value: payTermText,
          ),
        ];

      case InsuranceType.travel:
        return [
          _ReviewRow(
            label: 'Trip End Date',
            value: DateFormatter.format(renewalDate),
            valueColor: renewalDate
                    .isBefore(DateTime.now().add(const Duration(days: 30)))
                ? AppStyles.accentOrange
                : null,
          ),
        ];

      default:
        return [
          _ReviewRow(
            label: policyType == InsuranceType.vehicle
                ? 'Renewal / Expiry'
                : 'Renewal Date',
            value: DateFormatter.format(renewalDate),
            valueColor: renewalDate
                    .isBefore(DateTime.now().add(const Duration(days: 30)))
                ? AppStyles.accentOrange
                : null,
          ),
        ];
    }
  }

  Widget _divider(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
      child:
          Divider(color: AppStyles.getDividerColor(context), height: 1),
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
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                fontSize: TypeScale.body,
                fontWeight: FontWeight.w600,
                color: valueColor ?? AppStyles.getTextColor(context),
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Info Banner (read-only computed value display) ───────────────────────────

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _InfoBanner({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      padding: const EdgeInsets.symmetric(
          horizontal: Spacing.md, vertical: Spacing.sm),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: TypeScale.caption,
                    color: color,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: TypeScale.body,
                    fontWeight: FontWeight.w700,
                    color: AppStyles.getTextColor(context),
                  ),
                ),
              ],
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
              color: AppStyles.getSecondaryTextColor(context)
                  .withValues(alpha: 0.6),
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
              color:
                  isDark ? const Color(0xFF0D0D0D) : AppStyles.lightCard,
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
              padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.lg, vertical: Spacing.sm),
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
                maximumDate:
                    DateTime.now().add(const Duration(days: 365 * 50)),
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
