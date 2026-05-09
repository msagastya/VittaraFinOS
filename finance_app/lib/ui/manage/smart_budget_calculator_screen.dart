import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vittara_fin_os/logic/budget_model.dart';
import 'package:vittara_fin_os/logic/budgets_controller.dart';
import 'package:vittara_fin_os/logic/goal_model.dart';
import 'package:vittara_fin_os/logic/goals_controller.dart';
import 'package:vittara_fin_os/logic/transaction_model.dart';
import 'package:vittara_fin_os/logic/transactions_controller.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/widgets/animations.dart';
import 'package:vittara_fin_os/ui/widgets/toast_notification.dart' as toast_lib;
import 'package:vittara_fin_os/utils/date_formatter.dart';

enum _CalculatorSource { manual, history, budgets, savings }

enum _CalculatorPeriod { daily, weekly, monthly, yearly, custom }

class SmartBudgetCalculatorScreen extends StatefulWidget {
  const SmartBudgetCalculatorScreen({super.key});

  @override
  State<SmartBudgetCalculatorScreen> createState() =>
      _SmartBudgetCalculatorScreenState();
}

class _SmartBudgetCalculatorScreenState
    extends State<SmartBudgetCalculatorScreen> {
  static const _presetKey = 'smart_budget_calculator_presets';

  final _nameCtrl = TextEditingController(text: 'My plan');
  final _incomeCtrl = TextEditingController();
  final _fixedCtrl = TextEditingController();
  final _variableCtrl = TextEditingController();
  final _savingsCtrl = TextEditingController();
  final _bufferCtrl = TextEditingController(text: '10');
  final _customDaysCtrl = TextEditingController(text: '45');
  final _presetSearchCtrl = TextEditingController();

  _CalculatorSource _source = _CalculatorSource.manual;
  _CalculatorPeriod _period = _CalculatorPeriod.monthly;
  List<_BudgetPreset> _presets = [];
  bool _loaded = false;
  String _presetQuery = '';

  @override
  void initState() {
    super.initState();
    _loadPresets();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _incomeCtrl.dispose();
    _fixedCtrl.dispose();
    _variableCtrl.dispose();
    _savingsCtrl.dispose();
    _bufferCtrl.dispose();
    _customDaysCtrl.dispose();
    _presetSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPresets() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_presetKey) ?? const [];
    final presets = <_BudgetPreset>[];
    for (final item in raw) {
      try {
        presets.add(_BudgetPreset.fromJson(jsonDecode(item)));
      } catch (_) {
        // Ignore corrupted old entries instead of blocking the page.
      }
    }
    if (!mounted) return;
    setState(() {
      _presets = presets;
      _loaded = true;
    });
  }

  Future<void> _savePreset() async {
    final plan = _currentPlan();
    if (plan.income <= 0 && plan.expenses <= 0 && plan.savingsTarget <= 0) {
      toast_lib.toast.showError('Enter or import values before saving');
      return;
    }

    final preset = _BudgetPreset(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name:
          _nameCtrl.text.trim().isEmpty ? 'Budget plan' : _nameCtrl.text.trim(),
      source: _source,
      period: _period,
      income: plan.income,
      fixed: _num(_fixedCtrl),
      variable: _num(_variableCtrl),
      savingsTarget: plan.savingsTarget,
      bufferPercent: plan.bufferPercent,
      customDays: plan.days,
      createdAt: DateTime.now(),
    );
    final updated = [preset, ..._presets];
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _presetKey,
      updated.map((p) => jsonEncode(p.toJson())).toList(),
    );
    if (!mounted) return;
    setState(() => _presets = updated);
    Haptics.success();
    toast_lib.toast.showSuccess('Calculator plan saved');
  }

  Future<void> _deletePreset(String id) async {
    final updated = _presets.where((p) => p.id != id).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _presetKey,
      updated.map((p) => jsonEncode(p.toJson())).toList(),
    );
    if (!mounted) return;
    setState(() => _presets = updated);
  }

  void _loadPreset(_BudgetPreset preset) {
    setState(() {
      _nameCtrl.text = preset.name;
      _source = preset.source;
      _period = preset.period;
      _incomeCtrl.text = preset.income.toStringAsFixed(0);
      _fixedCtrl.text = preset.fixed.toStringAsFixed(0);
      _variableCtrl.text = preset.variable.toStringAsFixed(0);
      _savingsCtrl.text = preset.savingsTarget.toStringAsFixed(0);
      _bufferCtrl.text = preset.bufferPercent.toStringAsFixed(0);
      _customDaysCtrl.text = preset.customDays.toString();
    });
    Haptics.light();
  }

  void _applySource(
    _CalculatorSource source,
    TransactionsController txCtrl,
    BudgetsController budgetCtrl,
    GoalsController goalCtrl,
  ) {
    setState(() {
      _source = source;
      _clearScenarioValues();
      final autofill = switch (source) {
        _CalculatorSource.manual => null,
        _CalculatorSource.history => _fromHistory(txCtrl.transactions),
        _CalculatorSource.budgets => _fromBudgets(budgetCtrl.activeBudgets),
        _CalculatorSource.savings => _fromSavings(
            budgetCtrl.savingsplanners,
            goalCtrl.activeGoals,
            txCtrl.transactions,
          ),
      };
      if (autofill != null) {
        _incomeCtrl.text = autofill.income.toStringAsFixed(0);
        _fixedCtrl.text = autofill.fixed.toStringAsFixed(0);
        _variableCtrl.text = autofill.variable.toStringAsFixed(0);
        _savingsCtrl.text = autofill.savingsTarget.toStringAsFixed(0);
      }
    });
    Haptics.selection();
  }

  void _clearScenarioValues() {
    _incomeCtrl.clear();
    _fixedCtrl.clear();
    _variableCtrl.clear();
    _savingsCtrl.clear();
    _bufferCtrl.text = '10';
  }

  _AutofillPlan _fromHistory(List<Transaction> transactions) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month - 2, now.day);
    final recent = transactions.where((t) => t.dateTime.isAfter(start));
    var income = 0.0;
    var expense = 0.0;
    for (final tx in recent) {
      if (tx.type == TransactionType.income) {
        income += tx.amount;
      } else if (tx.type == TransactionType.expense) {
        expense += tx.amount;
      }
    }
    final monthlyIncome = income / 3;
    final monthlyExpense = expense / 3;
    return _AutofillPlan(
      income: monthlyIncome,
      fixed: monthlyExpense * 0.55,
      variable: monthlyExpense * 0.45,
      savingsTarget: math.max(0, monthlyIncome - monthlyExpense),
    );
  }

  _AutofillPlan _fromBudgets(List<Budget> budgets) {
    final normalizedLimit = budgets.fold<double>(
      0,
      (sum, budget) => sum + _toMonthly(budget.limitAmount, budget.period),
    );
    final normalizedSpend = budgets.fold<double>(
      0,
      (sum, budget) => sum + _toMonthly(budget.spentAmount, budget.period),
    );
    return _AutofillPlan(
      income: _num(_incomeCtrl),
      fixed: normalizedLimit * 0.35,
      variable: normalizedLimit * 0.65,
      savingsTarget: math.max(0, normalizedLimit - normalizedSpend),
    );
  }

  _AutofillPlan _fromSavings(
    List<SavingsPlanner> planners,
    List<Goal> goals,
    List<Transaction> transactions,
  ) {
    final history = _fromHistory(transactions);
    final plannerTarget =
        planners.fold<double>(0, (sum, p) => sum + p.monthlyTarget);
    final goalTarget =
        goals.fold<double>(0, (sum, g) => sum + g.recommendedMonthlySavings);
    return _AutofillPlan(
      income: history.income,
      fixed: history.fixed,
      variable: history.variable,
      savingsTarget: math.max(plannerTarget, goalTarget),
    );
  }

  double _toMonthly(double value, BudgetPeriod period) {
    return switch (period) {
      BudgetPeriod.daily => value * 30,
      BudgetPeriod.weekly => value * 4.345,
      BudgetPeriod.monthly => value,
      BudgetPeriod.yearly => value / 12,
    };
  }

  _ComputedPlan _currentPlan() {
    final days = switch (_period) {
      _CalculatorPeriod.daily => 1,
      _CalculatorPeriod.weekly => 7,
      _CalculatorPeriod.monthly => 30,
      _CalculatorPeriod.yearly => 365,
      _CalculatorPeriod.custom => _num(_customDaysCtrl).round().clamp(1, 3650),
    };
    final income = _num(_incomeCtrl);
    final fixed =
        _source == _CalculatorSource.manual ? 0.0 : _num(_fixedCtrl);
    final variable =
        _source == _CalculatorSource.manual ? 0.0 : _num(_variableCtrl);
    final savingsTarget = _num(_savingsCtrl);
    final bufferPercent = _source == _CalculatorSource.manual
        ? 0.0
        : _num(_bufferCtrl).clamp(0, 80).toDouble();
    final expenses = fixed + variable;
    final buffer = income * bufferPercent / 100;
    final freeCash = income - expenses - savingsTarget - buffer;
    final safeSpend = math.max(0, income - fixed - savingsTarget - buffer);

    return _ComputedPlan(
      days: days,
      income: income,
      expenses: expenses,
      savingsTarget: savingsTarget,
      bufferPercent: bufferPercent.toDouble(),
      bufferAmount: buffer,
      freeCash: freeCash,
      dailyAllowance: safeSpend / days,
      weeklyAllowance: safeSpend / days * 7,
      monthlyAllowance: safeSpend / days * 30,
      savingsRate: income <= 0 ? 0 : savingsTarget / income * 100,
      requiredCut: freeCash < 0 ? freeCash.abs() : 0,
    );
  }

  double _num(TextEditingController ctrl) {
    return double.tryParse(ctrl.text.replaceAll(',', '').trim()) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppStyles.getBackground(context),
      navigationBar: AppStyles.standardNavBar(context, 'Smart Calculator'),
      child:
          Consumer3<TransactionsController, BudgetsController, GoalsController>(
        builder: (context, txCtrl, budgetCtrl, goalCtrl, _) {
          final plan = _currentPlan();
          final visiblePresets = _filteredPresets();
          return SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                Spacing.lg,
                Spacing.md,
                Spacing.lg,
                32,
              ),
              children: [
                _HeroPanel(plan: plan),
                const SizedBox(height: Spacing.lg),
                _section(
                  title: 'Calculator mode',
                  child: Wrap(
                    spacing: Spacing.sm,
                    runSpacing: Spacing.sm,
                    children: _CalculatorSource.values.map((source) {
                      return _ChoiceChip(
                        label: _sourceLabel(source),
                        selected: _source == source,
                        onTap: () =>
                            _applySource(source, txCtrl, budgetCtrl, goalCtrl),
                      );
                    }).toList(),
                  ),
                ),
                _section(
                  title: 'Plan period',
                  trailing: _period == _CalculatorPeriod.custom
                      ? SizedBox(
                          width: 86,
                          child: _InputField(
                            controller: _customDaysCtrl,
                            label: 'Days',
                            showCurrencyPrefix: false,
                            onChanged: (_) => setState(() {}),
                          ),
                        )
                      : null,
                  child: Wrap(
                    spacing: Spacing.sm,
                    runSpacing: Spacing.sm,
                    children: _CalculatorPeriod.values.map((period) {
                      return _ChoiceChip(
                        label: _periodLabel(period),
                        selected: _period == period,
                        onTap: () => setState(() => _period = period),
                      );
                    }).toList(),
                  ),
                ),
                _section(
                  title: _source == _CalculatorSource.manual
                      ? 'Simple calculator'
                      : 'Smart scenario inputs',
                  child: _source == _CalculatorSource.manual
                      ? _buildSimpleInputs()
                      : _buildSmartInputs(),
                ),
                _section(
                  title: 'Budget plan',
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _MetricCard(
                              label: 'Daily safe spend',
                              value: CurrencyFormatter.compact(
                                  plan.dailyAllowance),
                              color: AppStyles.teal(context),
                            ),
                          ),
                          const SizedBox(width: Spacing.sm),
                          Expanded(
                            child: _MetricCard(
                              label: 'Weekly room',
                              value: CurrencyFormatter.compact(
                                  plan.weeklyAllowance),
                              color: AppStyles.violet(context),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: Spacing.sm),
                      Row(
                        children: [
                          Expanded(
                            child: _MetricCard(
                              label: 'Monthly room',
                              value: CurrencyFormatter.compact(
                                  plan.monthlyAllowance),
                              color: AppStyles.gold(context),
                            ),
                          ),
                          const SizedBox(width: Spacing.sm),
                          Expanded(
                            child: _MetricCard(
                              label: 'Savings rate',
                              value: '${plan.savingsRate.toStringAsFixed(0)}%',
                              color: plan.savingsRate >= 20
                                  ? AppStyles.gain(context)
                                  : AppStyles.loss(context),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: Spacing.md),
                      _AdviceCard(plan: plan),
                    ],
                  ),
                ),
                _section(
                  title: 'Save for later',
                  trailing: CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    onPressed: _savePreset,
                    child: Text(
                      'Save',
                      style: TextStyle(
                        color: AppStyles.getPrimaryColor(context),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  child: !_loaded
                      ? const CupertinoActivityIndicator()
                      : _presets.isEmpty
                          ? _EmptyPresets()
                          : Column(
                              children: [
                                CupertinoTextField(
                                  controller: _presetSearchCtrl,
                                  placeholder:
                                      'Search ${_presets.length} saved plans',
                                  prefix: Padding(
                                    padding:
                                        const EdgeInsets.only(left: Spacing.sm),
                                    child: Icon(
                                      CupertinoIcons.search,
                                      size: 16,
                                      color: AppStyles.getSecondaryTextColor(
                                          context),
                                    ),
                                  ),
                                  onChanged: (value) => setState(() {
                                    _presetQuery = value.trim().toLowerCase();
                                  }),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: Spacing.sm,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppStyles.l3(context),
                                    borderRadius:
                                        BorderRadius.circular(Radii.md),
                                    border: Border.all(
                                      color: AppStyles.getDividerColor(context),
                                    ),
                                  ),
                                  style: TextStyle(
                                      color: AppStyles.getTextColor(context)),
                                ),
                                const SizedBox(height: Spacing.md),
                                if (visiblePresets.isEmpty)
                                  _EmptyPresets(
                                    message:
                                        'No saved plans match this search.',
                                  )
                                else
                                  ...visiblePresets.map((preset) {
                                    return _PresetTile(
                                      preset: preset,
                                      onLoad: () => _loadPreset(preset),
                                      onDelete: () => _deletePreset(preset.id),
                                    );
                                  }),
                              ],
                            ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<_BudgetPreset> _filteredPresets() {
    if (_presetQuery.isEmpty) return _presets;
    return _presets.where((preset) {
      final haystack =
          '${preset.name} ${_sourceLabel(preset.source)} ${_periodLabel(preset.period)}'
              .toLowerCase();
      return haystack.contains(_presetQuery);
    }).toList();
  }

  Widget _buildSimpleInputs() {
    return Column(
      children: [
        _HelperNote(
          text:
              'Simple mode is separate from smart mode. Enter only money available, period, and optional amount to keep aside.',
        ),
        const SizedBox(height: Spacing.sm),
        _InputField(
          controller: _nameCtrl,
          label: 'Plan name',
          showCurrencyPrefix: false,
          keyboardType: TextInputType.text,
        ),
        _InputField(
          controller: _incomeCtrl,
          label: 'Money available for this plan',
          helper: 'Example: cash left for the month, trip budget, shopping cap',
          onChanged: (_) => setState(() {}),
        ),
        _InputField(
          controller: _savingsCtrl,
          label: 'Keep aside / must save',
          helper: 'Optional. This is removed before daily allowance is shown.',
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  Widget _buildSmartInputs() {
    return Column(
      children: [
        _HelperNote(
          text:
              'Smart modes use app context. History uses recent transactions, Budgets uses active budget limits, Savings uses goals and savings planners.',
        ),
        const SizedBox(height: Spacing.sm),
        _InputField(
          controller: _nameCtrl,
          label: 'Plan name',
          showCurrencyPrefix: false,
          keyboardType: TextInputType.text,
        ),
        _InputField(
          controller: _incomeCtrl,
          label: 'Income for this period',
          helper: 'Money expected during the selected period.',
          onChanged: (_) => setState(() {}),
        ),
        _InputField(
          controller: _fixedCtrl,
          label: 'Fixed needs / commitments',
          helper: 'Rent, EMIs, subscriptions, school fees, bills.',
          onChanged: (_) => setState(() {}),
        ),
        _InputField(
          controller: _variableCtrl,
          label: 'Flexible spending',
          helper: 'Food, travel, shopping, entertainment, unplanned spends.',
          onChanged: (_) => setState(() {}),
        ),
        _InputField(
          controller: _savingsCtrl,
          label: 'Savings or goal target',
          helper: 'Amount you want protected before spending.',
          onChanged: (_) => setState(() {}),
        ),
        _InputField(
          controller: _bufferCtrl,
          label: 'Safety buffer %',
          showCurrencyPrefix: false,
          helper: 'Extra cushion for unexpected expenses.',
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  Widget _section({
    required String title,
    required Widget child,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.lg),
      child: Container(
        decoration: AppStyles.sectionDecoration(context, radius: Radii.xl),
        padding: const EdgeInsets.all(Spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: AppStyles.titleStyle(context),
                  ),
                ),
                if (trailing != null) trailing,
              ],
            ),
            const SizedBox(height: Spacing.md),
            child,
          ],
        ),
      ),
    );
  }

  String _sourceLabel(_CalculatorSource source) {
    return switch (source) {
      _CalculatorSource.manual => 'Simple',
      _CalculatorSource.history => 'Use history',
      _CalculatorSource.budgets => 'Use budgets',
      _CalculatorSource.savings => 'Use savings',
    };
  }

  String _periodLabel(_CalculatorPeriod period) {
    return switch (period) {
      _CalculatorPeriod.daily => 'Daily',
      _CalculatorPeriod.weekly => 'Weekly',
      _CalculatorPeriod.monthly => 'Monthly',
      _CalculatorPeriod.yearly => 'Yearly',
      _CalculatorPeriod.custom => 'Custom',
    };
  }
}

class _HeroPanel extends StatelessWidget {
  final _ComputedPlan plan;

  const _HeroPanel({required this.plan});

  @override
  Widget build(BuildContext context) {
    final isHealthy = plan.freeCash >= 0;
    final color = isHealthy ? AppStyles.teal(context) : AppStyles.loss(context);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.22),
            AppStyles.getCardColor(context),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: color.withValues(alpha: 0.22)),
        boxShadow: AppStyles.elevatedCardShadow(context),
      ),
      padding: const EdgeInsets.all(Spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Budget Planning Calculator',
            style: TextStyle(
              color: AppStyles.getTextColor(context),
              fontSize: TypeScale.title2,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: Spacing.xs),
          Text(
            'Build a simple plan, import real history, or save detailed scenarios for future decisions.',
            style: TextStyle(
              color: AppStyles.getSecondaryTextColor(context),
              fontSize: TypeScale.footnote,
              height: 1.35,
            ),
          ),
          const SizedBox(height: Spacing.lg),
          Text(
            CurrencyFormatter.format(plan.freeCash, decimals: 0),
            style: TextStyle(
              color: color,
              fontSize: 34,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
            ),
          ),
          Text(
            isHealthy ? 'free cash after goals and buffer' : 'shortfall to fix',
            style: TextStyle(
              color: AppStyles.getSecondaryTextColor(context),
              fontSize: TypeScale.caption,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppStyles.getPrimaryColor(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.md,
          vertical: Spacing.sm,
        ),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.16)
              : AppStyles.l3(context).withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? color : AppStyles.getDividerColor(context),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? color : AppStyles.getTextColor(context),
            fontWeight: FontWeight.w700,
            fontSize: TypeScale.caption,
          ),
        ),
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? helper;
  final bool showCurrencyPrefix;
  final TextInputType keyboardType;
  final ValueChanged<String>? onChanged;

  const _InputField({
    required this.controller,
    required this.label,
    this.helper,
    this.showCurrencyPrefix = true,
    this.keyboardType = const TextInputType.numberWithOptions(decimal: true),
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CupertinoTextField(
            controller: controller,
            keyboardType: keyboardType,
            onChanged: onChanged,
            placeholder: label,
            prefix: !showCurrencyPrefix || keyboardType == TextInputType.text
                ? null
                : Padding(
                    padding: const EdgeInsets.only(left: Spacing.sm),
                    child: Text(
                      '₹',
                      style: TextStyle(
                        color: AppStyles.getSecondaryTextColor(context),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.sm,
              vertical: 13,
            ),
            decoration: BoxDecoration(
              color: AppStyles.l3(context),
              borderRadius: BorderRadius.circular(Radii.md),
              border: Border.all(color: AppStyles.getDividerColor(context)),
            ),
            style: TextStyle(color: AppStyles.getTextColor(context)),
          ),
          if (helper != null) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 2),
              child: Text(
                helper!,
                style: TextStyle(
                  color: AppStyles.getSecondaryTextColor(context)
                      .withValues(alpha: 0.78),
                  fontSize: TypeScale.caption,
                  height: 1.25,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HelperNote extends StatelessWidget {
  final String text;

  const _HelperNote({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: AppStyles.getPrimaryColor(context).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(
          color: AppStyles.getPrimaryColor(context).withValues(alpha: 0.18),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: AppStyles.getSecondaryTextColor(context),
          fontSize: TypeScale.caption,
          height: 1.35,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppStyles.getSecondaryTextColor(context),
              fontSize: TypeScale.caption,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: Spacing.xs),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: TypeScale.title3,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdviceCard extends StatelessWidget {
  final _ComputedPlan plan;

  const _AdviceCard({required this.plan});

  @override
  Widget build(BuildContext context) {
    final color =
        plan.freeCash >= 0 ? AppStyles.gain(context) : AppStyles.loss(context);
    final title = plan.freeCash >= 0
        ? 'This plan is workable'
        : 'This plan needs adjustment';
    final body = plan.freeCash >= 0
        ? 'You still have ${CurrencyFormatter.format(plan.freeCash, decimals: 0)} after expenses, savings, and ${plan.bufferPercent.toStringAsFixed(0)}% buffer.'
        : 'Reduce spending or targets by ${CurrencyFormatter.format(plan.requiredCut, decimals: 0)} for this period to make it safe.';

    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            plan.freeCash >= 0
                ? CupertinoIcons.check_mark_circled_solid
                : CupertinoIcons.exclamationmark_triangle_fill,
            color: color,
            size: 22,
          ),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: AppStyles.getTextColor(context),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: TextStyle(
                    color: AppStyles.getSecondaryTextColor(context),
                    height: 1.35,
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

class _PresetTile extends StatelessWidget {
  final _BudgetPreset preset;
  final VoidCallback onLoad;
  final VoidCallback onDelete;

  const _PresetTile({
    required this.preset,
    required this.onLoad,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.sm),
      child: GestureDetector(
        onTap: onLoad,
        child: Container(
          padding: const EdgeInsets.all(Spacing.md),
          decoration: BoxDecoration(
            color: AppStyles.l3(context),
            borderRadius: BorderRadius.circular(Radii.lg),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      preset.name,
                      style: TextStyle(
                        color: AppStyles.getTextColor(context),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${CurrencyFormatter.compact(preset.income)} income • ${DateFormatter.format(preset.createdAt)}',
                      style: TextStyle(
                        color: AppStyles.getSecondaryTextColor(context),
                        fontSize: TypeScale.caption,
                      ),
                    ),
                  ],
                ),
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                onPressed: onDelete,
                child: Icon(
                  CupertinoIcons.delete,
                  size: 18,
                  color: AppStyles.loss(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyPresets extends StatelessWidget {
  final String message;

  const _EmptyPresets({
    this.message =
        'No saved calculator plans yet. Save a simple or smart-filled scenario and reuse it later.',
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      style: TextStyle(
        color: AppStyles.getSecondaryTextColor(context),
        height: 1.35,
      ),
    );
  }
}

class _AutofillPlan {
  final double income;
  final double fixed;
  final double variable;
  final double savingsTarget;

  const _AutofillPlan({
    required this.income,
    required this.fixed,
    required this.variable,
    required this.savingsTarget,
  });
}

class _ComputedPlan {
  final int days;
  final double income;
  final double expenses;
  final double savingsTarget;
  final double bufferPercent;
  final double bufferAmount;
  final double freeCash;
  final double dailyAllowance;
  final double weeklyAllowance;
  final double monthlyAllowance;
  final double savingsRate;
  final double requiredCut;

  const _ComputedPlan({
    required this.days,
    required this.income,
    required this.expenses,
    required this.savingsTarget,
    required this.bufferPercent,
    required this.bufferAmount,
    required this.freeCash,
    required this.dailyAllowance,
    required this.weeklyAllowance,
    required this.monthlyAllowance,
    required this.savingsRate,
    required this.requiredCut,
  });
}

class _BudgetPreset {
  final String id;
  final String name;
  final _CalculatorSource source;
  final _CalculatorPeriod period;
  final double income;
  final double fixed;
  final double variable;
  final double savingsTarget;
  final double bufferPercent;
  final int customDays;
  final DateTime createdAt;

  const _BudgetPreset({
    required this.id,
    required this.name,
    required this.source,
    required this.period,
    required this.income,
    required this.fixed,
    required this.variable,
    required this.savingsTarget,
    required this.bufferPercent,
    required this.customDays,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'source': source.name,
        'period': period.name,
        'income': income,
        'fixed': fixed,
        'variable': variable,
        'savingsTarget': savingsTarget,
        'bufferPercent': bufferPercent,
        'customDays': customDays,
        'createdAt': createdAt.toIso8601String(),
      };

  factory _BudgetPreset.fromJson(Map<String, dynamic> json) {
    return _BudgetPreset(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Budget plan',
      source: _CalculatorSource.values.firstWhere(
        (v) => v.name == json['source'],
        orElse: () => _CalculatorSource.manual,
      ),
      period: _CalculatorPeriod.values.firstWhere(
        (v) => v.name == json['period'],
        orElse: () => _CalculatorPeriod.monthly,
      ),
      income: (json['income'] as num?)?.toDouble() ?? 0,
      fixed: (json['fixed'] as num?)?.toDouble() ?? 0,
      variable: (json['variable'] as num?)?.toDouble() ?? 0,
      savingsTarget: (json['savingsTarget'] as num?)?.toDouble() ?? 0,
      bufferPercent: (json['bufferPercent'] as num?)?.toDouble() ?? 10,
      customDays: (json['customDays'] as num?)?.toInt() ?? 30,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}
