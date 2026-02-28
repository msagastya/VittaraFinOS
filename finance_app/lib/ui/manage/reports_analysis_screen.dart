import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/account_model.dart';
import 'package:vittara_fin_os/logic/accounts_controller.dart';
import 'package:vittara_fin_os/logic/categories_controller.dart';
import 'package:vittara_fin_os/logic/category_model.dart';
import 'package:vittara_fin_os/logic/transaction_model.dart';
import 'package:vittara_fin_os/logic/transactions_controller.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/widgets/animations.dart';
import 'package:vittara_fin_os/ui/widgets/floating_particle_background.dart';
import 'package:vittara_fin_os/ui/widgets/toast_notification.dart';

const String _reportAppName = 'VittaraFinOS';
const String _reportTagline = 'Track Wealth, Master Life';

enum ReportDatePreset {
  all,
  thisMonth,
  last30Days,
  last90Days,
  thisYear,
  custom,
}

extension ReportDatePresetLabel on ReportDatePreset {
  String get label {
    switch (this) {
      case ReportDatePreset.all:
        return 'All';
      case ReportDatePreset.thisMonth:
        return 'This Month';
      case ReportDatePreset.last30Days:
        return 'Last 30D';
      case ReportDatePreset.last90Days:
        return 'Last 90D';
      case ReportDatePreset.thisYear:
        return 'This Year';
      case ReportDatePreset.custom:
        return 'Custom';
    }
  }
}

enum ReportGroupBy {
  category,
  type,
  dateDay,
  dateWeek,
  dateMonth,
  account,
  accountType,
  paymentApp,
  tag,
}

extension ReportGroupByLabel on ReportGroupBy {
  String get label {
    switch (this) {
      case ReportGroupBy.category:
        return 'Category';
      case ReportGroupBy.type:
        return 'Txn Type';
      case ReportGroupBy.dateDay:
        return 'Date (Day)';
      case ReportGroupBy.dateWeek:
        return 'Date (Week)';
      case ReportGroupBy.dateMonth:
        return 'Date (Month)';
      case ReportGroupBy.account:
        return 'Account';
      case ReportGroupBy.accountType:
        return 'Account Type';
      case ReportGroupBy.paymentApp:
        return 'Payment App';
      case ReportGroupBy.tag:
        return 'Tag';
    }
  }
}

enum ReportSortMetric {
  outflow,
  inflow,
  net,
  transferVolume,
  transactions,
}

extension ReportSortMetricLabel on ReportSortMetric {
  String get label {
    switch (this) {
      case ReportSortMetric.outflow:
        return 'Outflow';
      case ReportSortMetric.inflow:
        return 'Inflow';
      case ReportSortMetric.net:
        return 'Net';
      case ReportSortMetric.transferVolume:
        return 'Transfer';
      case ReportSortMetric.transactions:
        return 'Count';
    }
  }
}

enum ReportStrategyPreset {
  balanced,
  aggressiveSaver,
  debtCrusher,
  growthInvestor,
  essentialsFirst,
  custom,
}

extension ReportStrategyPresetLabel on ReportStrategyPreset {
  String get label {
    switch (this) {
      case ReportStrategyPreset.balanced:
        return 'Balanced';
      case ReportStrategyPreset.aggressiveSaver:
        return 'Aggressive Saver';
      case ReportStrategyPreset.debtCrusher:
        return 'Debt Crusher';
      case ReportStrategyPreset.growthInvestor:
        return 'Growth Investor';
      case ReportStrategyPreset.essentialsFirst:
        return 'Essentials First';
      case ReportStrategyPreset.custom:
        return 'Custom';
    }
  }
}

class _StrategyProfile {
  final double savingsTargetRate;
  final double essentialsCapRate;
  final double discretionaryCapRate;
  final double investmentTargetRate;
  final double debtPaydownRate;

  const _StrategyProfile({
    required this.savingsTargetRate,
    required this.essentialsCapRate,
    required this.discretionaryCapRate,
    required this.investmentTargetRate,
    required this.debtPaydownRate,
  });
}

const Map<ReportStrategyPreset, _StrategyProfile> _strategyProfiles = {
  ReportStrategyPreset.balanced: _StrategyProfile(
    savingsTargetRate: 0.25,
    essentialsCapRate: 0.55,
    discretionaryCapRate: 0.20,
    investmentTargetRate: 0.15,
    debtPaydownRate: 0.10,
  ),
  ReportStrategyPreset.aggressiveSaver: _StrategyProfile(
    savingsTargetRate: 0.40,
    essentialsCapRate: 0.50,
    discretionaryCapRate: 0.12,
    investmentTargetRate: 0.12,
    debtPaydownRate: 0.08,
  ),
  ReportStrategyPreset.debtCrusher: _StrategyProfile(
    savingsTargetRate: 0.20,
    essentialsCapRate: 0.55,
    discretionaryCapRate: 0.10,
    investmentTargetRate: 0.10,
    debtPaydownRate: 0.25,
  ),
  ReportStrategyPreset.growthInvestor: _StrategyProfile(
    savingsTargetRate: 0.22,
    essentialsCapRate: 0.50,
    discretionaryCapRate: 0.18,
    investmentTargetRate: 0.25,
    debtPaydownRate: 0.07,
  ),
  ReportStrategyPreset.essentialsFirst: _StrategyProfile(
    savingsTargetRate: 0.20,
    essentialsCapRate: 0.60,
    discretionaryCapRate: 0.12,
    investmentTargetRate: 0.10,
    debtPaydownRate: 0.08,
  ),
};

class ReportsAnalysisScreen extends StatefulWidget {
  const ReportsAnalysisScreen({super.key});

  @override
  State<ReportsAnalysisScreen> createState() => _ReportsAnalysisScreenState();
}

class _ReportsAnalysisScreenState extends State<ReportsAnalysisScreen> {
  ReportDatePreset _datePreset = ReportDatePreset.last30Days;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();

  final Set<TransactionType> _selectedTransactionTypes = {
    ...TransactionType.values
  };
  final Set<String> _selectedCategoryIds = {};
  final Set<String> _selectedAccountIds = {};
  final Set<AccountType> _selectedAccountTypes = {};
  final Set<String> _selectedTags = {};
  final Set<String> _selectedPaymentApps = {};

  bool _includeTransfers = true;
  bool _includeInvestments = true;
  bool _includeCashbackFlows = true;

  ReportGroupBy _primaryGroupBy = ReportGroupBy.category;
  ReportGroupBy _secondaryGroupBy = ReportGroupBy.type;
  ReportSortMetric _sortMetric = ReportSortMetric.outflow;
  bool _sortDescending = true;

  ReportStrategyPreset _strategyPreset = ReportStrategyPreset.balanced;
  double _customSavingsTargetRate = 0.25;
  double _customEssentialsCapRate = 0.55;
  double _customDiscretionaryCapRate = 0.20;
  double _customInvestmentRate = 0.15;
  double _customDebtRate = 0.10;

  bool _isExportingPdf = false;
  bool _isExportingExcel = false;

  @override
  void initState() {
    super.initState();
    _applyDatePreset(ReportDatePreset.last30Days, callSetState: false);
    _applyStrategyPreset(ReportStrategyPreset.balanced, callSetState: false);
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppStyles.getBackground(context),
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          'Reports & Analysis',
          style: TextStyle(color: AppStyles.getTextColor(context)),
        ),
        previousPageTitle: 'Manage',
        backgroundColor: AppStyles.getCardColor(context).withValues(alpha: 0.9),
        border: null,
      ),
      child: Consumer3<TransactionsController, AccountsController,
          CategoriesController>(
        builder: (
          context,
          transactionsController,
          accountsController,
          categoriesController,
          _,
        ) {
          final accountsById = {
            for (final account in accountsController.accounts)
              account.id: account
          };

          final filteredTransactions = _applyFilters(
            transactionsController.transactions,
            accountsById,
          );
          final summary = _computeSummary(filteredTransactions);
          final groupedMetrics = _buildGroupedMetrics(
            filteredTransactions,
            accountsById,
            _primaryGroupBy,
            _secondaryGroupBy,
          );
          final trendPoints = _buildTrendPoints(filteredTransactions);
          final strategyProfile = _effectiveStrategyProfile();
          final strategyEvaluation = _evaluateStrategy(
            filteredTransactions,
            summary,
            strategyProfile,
          );
          final snapshot = _ReportSnapshot(
            generatedAt: DateTime.now(),
            startDate: _startDate,
            endDate: _endDate,
            datePreset: _datePreset,
            primaryGroupBy: _primaryGroupBy,
            secondaryGroupBy: _secondaryGroupBy,
            summary: summary,
            groupedMetrics: groupedMetrics,
            transactions: filteredTransactions,
            strategyProfile: strategyProfile,
            strategyEvaluation: strategyEvaluation,
            accountsById: accountsById,
          );

          final availableTags =
              _collectAvailableTags(transactionsController.transactions);
          final availableApps = _collectAvailablePaymentApps(
            transactionsController.transactions,
          );

          return SafeArea(
            child: SubtleParticleOverlay(
              particleCount: 30,
              child: Container(
                decoration: BoxDecoration(
                  gradient: AppStyles.backgroundGradient(context),
                ),
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    Spacing.lg,
                    Spacing.lg,
                    Spacing.lg,
                    Spacing.huge,
                  ),
                  children: [
                    _buildSummaryHeader(summary, filteredTransactions.length),
                    SizedBox(height: Spacing.lg),
                    _buildFiltersCard(
                      categories: categoriesController.categories,
                      accounts: accountsController.accounts,
                      availableTags: availableTags,
                      availableApps: availableApps,
                    ),
                    SizedBox(height: Spacing.lg),
                    _buildStrategyCard(strategyEvaluation),
                    SizedBox(height: Spacing.lg),
                    _buildChartsCard(groupedMetrics, trendPoints),
                    SizedBox(height: Spacing.lg),
                    _buildBreakdownTable(groupedMetrics),
                    SizedBox(height: Spacing.lg),
                    _buildExportCard(snapshot),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryHeader(_ReportSummary summary, int count) {
    return Container(
      padding: EdgeInsets.all(Spacing.lg),
      decoration: AppStyles.sectionDecoration(
        context,
        tint: SemanticColors.primary,
        radius: Radii.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: SemanticColors.primary.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(Radii.md),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  CupertinoIcons.chart_bar_square_fill,
                  color: SemanticColors.primary,
                  size: IconSizes.md,
                ),
              ),
              SizedBox(width: Spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Deep Analysis',
                      style: AppStyles.titleStyle(context).copyWith(
                        fontSize: TypeScale.title2,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: Spacing.xs),
                    Text(
                      '${_datePreset.label} • ${_formatDate(_startDate)} to ${_formatDate(_endDate)}',
                      style: TextStyle(
                        color: AppStyles.getSecondaryTextColor(context),
                        fontSize: TypeScale.footnote,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: Spacing.lg),
          Wrap(
            spacing: Spacing.md,
            runSpacing: Spacing.md,
            children: [
              _buildMetricPill(
                label: 'Transactions',
                value: count.toString(),
                color: SemanticColors.info,
              ),
              _buildMetricPill(
                label: 'Inflow',
                value: '₹${summary.inflow.toStringAsFixed(0)}',
                color: SemanticColors.success,
              ),
              _buildMetricPill(
                label: 'Outflow',
                value: '₹${summary.outflow.toStringAsFixed(0)}',
                color: SemanticColors.error,
              ),
              _buildMetricPill(
                label: 'Net',
                value: '₹${summary.net.toStringAsFixed(0)}',
                color: summary.net >= 0
                    ? SemanticColors.success
                    : SemanticColors.warning,
              ),
              _buildMetricPill(
                label: 'Transfer Volume',
                value: '₹${summary.transferVolume.toStringAsFixed(0)}',
                color: SemanticColors.categories,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricPill({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding:
          EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.sm),
      decoration: AppStyles.tabDecoration(
        context,
        selected: true,
        color: color,
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
          SizedBox(height: Spacing.xxs),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: TypeScale.callout,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersCard({
    required List<Category> categories,
    required List<Account> accounts,
    required List<String> availableTags,
    required List<String> availableApps,
  }) {
    return Container(
      padding: EdgeInsets.all(Spacing.lg),
      decoration: AppStyles.sectionDecoration(
        context,
        tint: SemanticColors.primary.withValues(alpha: 0.82),
        radius: Radii.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(
            icon: CupertinoIcons.slider_horizontal_3,
            title: 'Analysis Filters',
            subtitle: 'Customize by date, account, category, type, and tags',
          ),
          SizedBox(height: Spacing.md),
          Wrap(
            spacing: Spacing.sm,
            runSpacing: Spacing.sm,
            children: ReportDatePreset.values.map((preset) {
              final selected = _datePreset == preset;
              return _buildChip(
                label: preset.label,
                selected: selected,
                color: SemanticColors.primary,
                onTap: () => _applyDatePreset(preset),
              );
            }).toList(),
          ),
          if (_datePreset == ReportDatePreset.custom) ...[
            SizedBox(height: Spacing.md),
            Row(
              children: [
                Expanded(
                  child: _buildDateButton(
                    label: 'Start',
                    value: _formatDate(_startDate),
                    onTap: () => _pickCustomDate(isStart: true),
                  ),
                ),
                SizedBox(width: Spacing.sm),
                Expanded(
                  child: _buildDateButton(
                    label: 'End',
                    value: _formatDate(_endDate),
                    onTap: () => _pickCustomDate(isStart: false),
                  ),
                ),
              ],
            ),
          ],
          SizedBox(height: Spacing.md),
          Wrap(
            spacing: Spacing.sm,
            runSpacing: Spacing.sm,
            children: TransactionType.values.map((type) {
              final selected = _selectedTransactionTypes.contains(type);
              return _buildChip(
                label: type.name,
                selected: selected,
                color: SemanticColors.info,
                onTap: () {
                  setState(() {
                    if (selected) {
                      _selectedTransactionTypes.remove(type);
                    } else {
                      _selectedTransactionTypes.add(type);
                    }
                  });
                },
              );
            }).toList(),
          ),
          SizedBox(height: Spacing.md),
          _buildSwitchRow(
            label: 'Include transfers in analysis',
            value: _includeTransfers,
            onChanged: (value) => setState(() => _includeTransfers = value),
          ),
          _buildSwitchRow(
            label: 'Include investment outflows',
            value: _includeInvestments,
            onChanged: (value) => setState(() => _includeInvestments = value),
          ),
          _buildSwitchRow(
            label: 'Include cashback credits',
            value: _includeCashbackFlows,
            onChanged: (value) => setState(() => _includeCashbackFlows = value),
          ),
          SizedBox(height: Spacing.md),
          Row(
            children: [
              Expanded(
                child: _buildPickerButton(
                  label: 'Primary Group',
                  value: _primaryGroupBy.label,
                  onTap: () => _pickGroupBy(isPrimary: true),
                ),
              ),
              SizedBox(width: Spacing.sm),
              Expanded(
                child: _buildPickerButton(
                  label: 'Secondary Group',
                  value: _secondaryGroupBy.label,
                  onTap: () => _pickGroupBy(isPrimary: false),
                ),
              ),
            ],
          ),
          SizedBox(height: Spacing.sm),
          Row(
            children: [
              Expanded(
                child: _buildPickerButton(
                  label: 'Sort By',
                  value: _sortMetric.label,
                  onTap: _pickSortMetric,
                ),
              ),
              SizedBox(width: Spacing.sm),
              Expanded(
                child: _buildPickerButton(
                  label: 'Order',
                  value: _sortDescending ? 'Descending' : 'Ascending',
                  onTap: () =>
                      setState(() => _sortDescending = !_sortDescending),
                ),
              ),
            ],
          ),
          SizedBox(height: Spacing.md),
          Wrap(
            spacing: Spacing.sm,
            runSpacing: Spacing.sm,
            children: [
              _buildFilterActionButton(
                label: 'Categories',
                count: _selectedCategoryIds.length,
                onTap: () => _showMultiSelectSheet<String>(
                  title: 'Filter Categories',
                  options: categories
                      .map((c) => _SelectableOption<String>(
                            value: c.id,
                            label: c.name,
                          ))
                      .toList(),
                  selected: _selectedCategoryIds,
                  onApply: (selected) => setState(() => _selectedCategoryIds
                    ..clear()
                    ..addAll(selected)),
                ),
              ),
              _buildFilterActionButton(
                label: 'Accounts',
                count: _selectedAccountIds.length,
                onTap: () => _showMultiSelectSheet<String>(
                  title: 'Filter Accounts',
                  options: accounts
                      .map((a) => _SelectableOption<String>(
                            value: a.id,
                            label: a.name,
                          ))
                      .toList(),
                  selected: _selectedAccountIds,
                  onApply: (selected) => setState(() => _selectedAccountIds
                    ..clear()
                    ..addAll(selected)),
                ),
              ),
              _buildFilterActionButton(
                label: 'Account Types',
                count: _selectedAccountTypes.length,
                onTap: () => _showMultiSelectSheet<AccountType>(
                  title: 'Filter Account Types',
                  options: AccountType.values
                      .map((type) => _SelectableOption<AccountType>(
                            value: type,
                            label: _accountTypeLabel(type),
                          ))
                      .toList(),
                  selected: _selectedAccountTypes,
                  onApply: (selected) => setState(() => _selectedAccountTypes
                    ..clear()
                    ..addAll(selected)),
                ),
              ),
              _buildFilterActionButton(
                label: 'Tags',
                count: _selectedTags.length,
                onTap: () => _showMultiSelectSheet<String>(
                  title: 'Filter Tags',
                  options: availableTags
                      .map((tag) => _SelectableOption<String>(
                            value: tag,
                            label: tag,
                          ))
                      .toList(),
                  selected: _selectedTags,
                  onApply: (selected) => setState(() => _selectedTags
                    ..clear()
                    ..addAll(selected)),
                ),
              ),
              _buildFilterActionButton(
                label: 'Payment Apps',
                count: _selectedPaymentApps.length,
                onTap: () => _showMultiSelectSheet<String>(
                  title: 'Filter Payment Apps',
                  options: availableApps
                      .map((app) => _SelectableOption<String>(
                            value: app,
                            label: app,
                          ))
                      .toList(),
                  selected: _selectedPaymentApps,
                  onApply: (selected) => setState(() => _selectedPaymentApps
                    ..clear()
                    ..addAll(selected)),
                ),
              ),
              _buildFilterActionButton(
                label: 'Reset Filters',
                count: 0,
                onTap: _resetFilters,
                color: SemanticColors.warning,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateButton({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return BouncyButton(
      onPressed: onTap,
      child: Container(
        padding:
            EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.sm),
        decoration: AppStyles.tabDecoration(
          context,
          selected: true,
          color: AppStyles.accentBlue.withValues(alpha: 0.75),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: AppStyles.getSecondaryTextColor(context),
                fontSize: TypeScale.caption,
              ),
            ),
            SizedBox(height: Spacing.xxs),
            Text(
              value,
              style: TextStyle(
                color: AppStyles.getTextColor(context),
                fontWeight: FontWeight.w700,
                fontSize: TypeScale.callout,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPickerButton({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return BouncyButton(
      onPressed: onTap,
      child: Container(
        padding:
            EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.sm),
        decoration: AppStyles.tabDecoration(
          context,
          selected: true,
          color: AppStyles.accentTeal.withValues(alpha: 0.72),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: AppStyles.getSecondaryTextColor(context),
                fontSize: TypeScale.caption,
              ),
            ),
            SizedBox(height: Spacing.xxs),
            Text(
              value,
              style: TextStyle(
                color: AppStyles.getTextColor(context),
                fontWeight: FontWeight.w700,
                fontSize: TypeScale.callout,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchRow({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: Spacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: AppStyles.getTextColor(context),
                fontSize: TypeScale.footnote,
              ),
            ),
          ),
          CupertinoSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _buildFilterActionButton({
    required String label,
    required int count,
    required VoidCallback onTap,
    Color color = SemanticColors.info,
  }) {
    return BouncyButton(
      onPressed: onTap,
      child: Container(
        padding:
            EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.sm),
        decoration: AppStyles.tabDecoration(
          context,
          selected: count > 0 || label == 'Reset Filters',
          color: color,
        ),
        child: Text(
          count > 0 ? '$label ($count)' : label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: TypeScale.footnote,
          ),
        ),
      ),
    );
  }

  Widget _buildStrategyCard(_StrategyEvaluation evaluation) {
    final profile = _effectiveStrategyProfile();
    return Container(
      padding: EdgeInsets.all(Spacing.lg),
      decoration: AppStyles.sectionDecoration(
        context,
        tint: SemanticColors.lending.withValues(alpha: 0.85),
        radius: Radii.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(
            icon: CupertinoIcons.compass_fill,
            title: 'Predefined Strategies + Custom',
            subtitle: 'Pick a strategy or tune rates as per your requirement',
          ),
          SizedBox(height: Spacing.md),
          Wrap(
            spacing: Spacing.sm,
            runSpacing: Spacing.sm,
            children: ReportStrategyPreset.values.map((preset) {
              final selected = _strategyPreset == preset;
              return _buildChip(
                label: preset.label,
                selected: selected,
                color: SemanticColors.lending,
                onTap: () => _applyStrategyPreset(preset),
              );
            }).toList(),
          ),
          if (_strategyPreset == ReportStrategyPreset.custom) ...[
            SizedBox(height: Spacing.md),
            _buildSlider(
              label: 'Savings Target',
              value: _customSavingsTargetRate,
              min: 0.05,
              max: 0.60,
              onChanged: (value) =>
                  setState(() => _customSavingsTargetRate = value),
            ),
            _buildSlider(
              label: 'Essentials Cap',
              value: _customEssentialsCapRate,
              min: 0.30,
              max: 0.80,
              onChanged: (value) =>
                  setState(() => _customEssentialsCapRate = value),
            ),
            _buildSlider(
              label: 'Discretionary Cap',
              value: _customDiscretionaryCapRate,
              min: 0.05,
              max: 0.40,
              onChanged: (value) =>
                  setState(() => _customDiscretionaryCapRate = value),
            ),
            _buildSlider(
              label: 'Investment Target',
              value: _customInvestmentRate,
              min: 0.00,
              max: 0.40,
              onChanged: (value) =>
                  setState(() => _customInvestmentRate = value),
            ),
            _buildSlider(
              label: 'Debt Paydown Target',
              value: _customDebtRate,
              min: 0.00,
              max: 0.40,
              onChanged: (value) => setState(() => _customDebtRate = value),
            ),
          ],
          SizedBox(height: Spacing.md),
          Container(
            padding: EdgeInsets.all(Spacing.md),
            decoration: AppStyles.sectionDecoration(
              context,
              tint: SemanticColors.lending.withValues(alpha: 0.62),
              radius: Radii.md,
              elevated: false,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Strategy Outcome',
                  style: TextStyle(
                    color: AppStyles.getTextColor(context),
                    fontWeight: FontWeight.w700,
                    fontSize: TypeScale.callout,
                  ),
                ),
                SizedBox(height: Spacing.sm),
                Text(
                  'Income: ₹${evaluation.income.toStringAsFixed(0)} • Outflow: ₹${evaluation.outflow.toStringAsFixed(0)} • Savings: ₹${evaluation.actualSavings.toStringAsFixed(0)}',
                  style: TextStyle(
                    color: AppStyles.getSecondaryTextColor(context),
                    fontSize: TypeScale.footnote,
                  ),
                ),
                SizedBox(height: Spacing.xs),
                Text(
                  'Target savings (${(profile.savingsTargetRate * 100).toStringAsFixed(0)}%): ₹${evaluation.targetSavings.toStringAsFixed(0)} • Gap: ₹${evaluation.savingsGap.toStringAsFixed(0)}',
                  style: TextStyle(
                    color: evaluation.savingsGap <= 0
                        ? SemanticColors.success
                        : SemanticColors.warning,
                    fontSize: TypeScale.footnote,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: Spacing.sm),
                ...evaluation.recommendations.map(
                  (rec) => Padding(
                    padding: EdgeInsets.only(bottom: Spacing.xs),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• '),
                        Expanded(
                          child: Text(
                            rec,
                            style: TextStyle(
                              color: AppStyles.getTextColor(context),
                              fontSize: TypeScale.footnote,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: Spacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ${(value * 100).toStringAsFixed(0)}%',
            style: TextStyle(
              color: AppStyles.getSecondaryTextColor(context),
              fontSize: TypeScale.footnote,
            ),
          ),
          CupertinoSlider(
            value: value,
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildChartsCard(
    List<_GroupedMetric> groupedMetrics,
    List<_TrendPoint> trendPoints,
  ) {
    final topBars = groupedMetrics.take(8).toList();
    return Container(
      padding: EdgeInsets.all(Spacing.lg),
      decoration: AppStyles.sectionDecoration(
        context,
        tint: SemanticColors.info.withValues(alpha: 0.86),
        radius: Radii.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(
            icon: CupertinoIcons.chart_bar_alt_fill,
            title: 'Charts & Visual Analysis',
            subtitle: 'Primary distribution and net trend movement',
          ),
          SizedBox(height: Spacing.md),
          Text(
            'Primary Group Distribution (${_primaryGroupBy.label})',
            style: TextStyle(
              color: AppStyles.getSecondaryTextColor(context),
              fontSize: TypeScale.footnote,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: Spacing.sm),
          Container(
            height: 230,
            padding: EdgeInsets.all(Spacing.sm),
            decoration: AppStyles.sectionDecoration(
              context,
              tint: SemanticColors.info.withValues(alpha: 0.65),
              radius: Radii.md,
              elevated: false,
            ),
            child: topBars.isEmpty
                ? _buildEmptyMini('No grouped data for the selected filters')
                : CustomPaint(
                    painter: _BarDistributionPainter(
                      groups: topBars,
                      metric: _sortMetric,
                      textColor: AppStyles.getTextColor(context),
                      secondaryColor: AppStyles.getSecondaryTextColor(context),
                    ),
                    child: const SizedBox.expand(),
                  ),
          ),
          SizedBox(height: Spacing.md),
          Text(
            'Net Trend',
            style: TextStyle(
              color: AppStyles.getSecondaryTextColor(context),
              fontSize: TypeScale.footnote,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: Spacing.sm),
          Container(
            height: 190,
            padding: EdgeInsets.all(Spacing.sm),
            decoration: AppStyles.sectionDecoration(
              context,
              tint: SemanticColors.primary.withValues(alpha: 0.62),
              radius: Radii.md,
              elevated: false,
            ),
            child: trendPoints.length < 2
                ? _buildEmptyMini('Need at least 2 data points for trend')
                : CustomPaint(
                    painter: _TrendPainter(
                      points: trendPoints,
                      positiveColor: SemanticColors.success,
                      negativeColor: SemanticColors.error,
                      axisColor: AppStyles.getSecondaryTextColor(context),
                    ),
                    child: const SizedBox.expand(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyMini(String message) {
    return Center(
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: AppStyles.getSecondaryTextColor(context),
          fontSize: TypeScale.footnote,
        ),
      ),
    );
  }

  Widget _buildBreakdownTable(List<_GroupedMetric> groupedMetrics) {
    final groups = groupedMetrics.take(20).toList();
    return Container(
      padding: EdgeInsets.all(Spacing.lg),
      decoration: AppStyles.sectionDecoration(
        context,
        tint: SemanticColors.categories.withValues(alpha: 0.8),
        radius: Radii.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(
            icon: CupertinoIcons.table_fill,
            title: 'Multi-level Breakdown',
            subtitle:
                'Primary: ${_primaryGroupBy.label} • Secondary: ${_secondaryGroupBy.label}',
          ),
          SizedBox(height: Spacing.md),
          if (groups.isEmpty)
            Text(
              'No groups found for current filters.',
              style: TextStyle(
                color: AppStyles.getSecondaryTextColor(context),
                fontSize: TypeScale.footnote,
              ),
            ),
          ...groups.map((group) => _buildGroupCard(group)),
        ],
      ),
    );
  }

  Widget _buildGroupCard(_GroupedMetric group) {
    return Container(
      margin: EdgeInsets.only(bottom: Spacing.sm),
      padding: EdgeInsets.all(Spacing.md),
      decoration: AppStyles.sectionDecoration(
        context,
        tint: group.net >= 0 ? SemanticColors.success : SemanticColors.error,
        radius: Radii.md,
        elevated: false,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            group.label,
            style: TextStyle(
              color: AppStyles.getTextColor(context),
              fontWeight: FontWeight.w700,
              fontSize: TypeScale.callout,
            ),
          ),
          SizedBox(height: Spacing.xs),
          Text(
            '${group.transactionCount} txns • In ₹${group.inflow.toStringAsFixed(0)} • Out ₹${group.outflow.toStringAsFixed(0)} • Net ₹${group.net.toStringAsFixed(0)}',
            style: TextStyle(
              color: AppStyles.getSecondaryTextColor(context),
              fontSize: TypeScale.footnote,
            ),
          ),
          if (group.secondaryBreakdown.isNotEmpty) ...[
            SizedBox(height: Spacing.sm),
            ...group.secondaryBreakdown.take(5).map(
                  (subGroup) => Padding(
                    padding: EdgeInsets.only(bottom: Spacing.xxs),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '• ${subGroup.label}',
                            style: TextStyle(
                              color: AppStyles.getSecondaryTextColor(context),
                              fontSize: TypeScale.caption,
                            ),
                          ),
                        ),
                        Text(
                          'Net ₹${subGroup.net.toStringAsFixed(0)}',
                          style: TextStyle(
                            color: subGroup.net >= 0
                                ? SemanticColors.success
                                : SemanticColors.error,
                            fontSize: TypeScale.caption,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ],
      ),
    );
  }

  Widget _buildExportCard(_ReportSnapshot snapshot) {
    return Container(
      padding: EdgeInsets.all(Spacing.lg),
      decoration: AppStyles.sectionDecoration(
        context,
        tint: SemanticColors.success.withValues(alpha: 0.86),
        radius: Radii.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(
            icon: CupertinoIcons.doc_on_doc_fill,
            title: 'Download Report',
            subtitle:
                'Professional export with app branding, strategy, and analytics',
          ),
          SizedBox(height: Spacing.md),
          Row(
            children: [
              Expanded(
                child: CupertinoButton.filled(
                  onPressed:
                      _isExportingPdf ? null : () => _exportPdf(snapshot),
                  child: _isExportingPdf
                      ? const CupertinoActivityIndicator(color: Colors.white)
                      : const Text('Export PDF'),
                ),
              ),
              SizedBox(width: Spacing.sm),
              Expanded(
                child: CupertinoButton(
                  color: SemanticColors.info,
                  onPressed:
                      _isExportingExcel ? null : () => _exportExcel(snapshot),
                  child: _isExportingExcel
                      ? const CupertinoActivityIndicator(color: Colors.white)
                      : const Text('Export Excel'),
                ),
              ),
            ],
          ),
          SizedBox(height: Spacing.sm),
          Text(
            'PDF includes logo-style header, app name, tagline, deep analytics, grouped breakdown, and strategy results. Excel export is compatible with spreadsheet tools.',
            style: TextStyle(
              color: AppStyles.getSecondaryTextColor(context),
              fontSize: TypeScale.caption,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: AppStyles.iconBoxDecoration(
            context,
            SemanticColors.primary,
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: SemanticColors.primary, size: IconSizes.sm),
        ),
        SizedBox(width: Spacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: AppStyles.getTextColor(context),
                  fontWeight: FontWeight.w800,
                  fontSize: TypeScale.callout,
                ),
              ),
              SizedBox(height: Spacing.xxs),
              Text(
                subtitle,
                style: TextStyle(
                  color: AppStyles.getSecondaryTextColor(context),
                  fontSize: TypeScale.caption,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChip({
    required String label,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return BouncyButton(
      onPressed: onTap,
      child: Container(
        padding:
            EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.sm),
        decoration: AppStyles.tabDecoration(
          context,
          selected: selected,
          color: color,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? color : AppStyles.getSecondaryTextColor(context),
            fontWeight: FontWeight.w700,
            fontSize: TypeScale.footnote,
          ),
        ),
      ),
    );
  }

  List<Transaction> _applyFilters(
    List<Transaction> transactions,
    Map<String, Account> accountsById,
  ) {
    return transactions.where((tx) {
      if (!_isWithinDateRange(tx.dateTime)) return false;

      if (!_selectedTransactionTypes.contains(tx.type)) return false;
      if (!_includeTransfers && tx.type == TransactionType.transfer) {
        return false;
      }
      if (!_includeInvestments && tx.type == TransactionType.investment) {
        return false;
      }
      if (!_includeCashbackFlows && tx.type == TransactionType.cashback) {
        return false;
      }

      if (_selectedCategoryIds.isNotEmpty) {
        final categoryId = tx.metadata?['categoryId']?.toString();
        if (categoryId == null || !_selectedCategoryIds.contains(categoryId)) {
          return false;
        }
      }

      final accountIds = _transactionAccountIds(tx);
      if (_selectedAccountIds.isNotEmpty &&
          accountIds.intersection(_selectedAccountIds).isEmpty) {
        return false;
      }

      if (_selectedAccountTypes.isNotEmpty) {
        final accountTypes = accountIds
            .map((id) => accountsById[id]?.type)
            .whereType<AccountType>()
            .toSet();
        if (accountTypes.intersection(_selectedAccountTypes).isEmpty) {
          return false;
        }
      }

      if (_selectedTags.isNotEmpty) {
        final tags = _extractTags(tx);
        if (tags.intersection(_selectedTags).isEmpty) return false;
      }

      if (_selectedPaymentApps.isNotEmpty) {
        final paymentApp = _paymentAppLabel(tx);
        if (!_selectedPaymentApps.contains(paymentApp)) return false;
      }

      return true;
    }).toList();
  }

  bool _isWithinDateRange(DateTime date) {
    final txDay = DateTime(date.year, date.month, date.day);
    final startDay =
        DateTime(_startDate.year, _startDate.month, _startDate.day);
    final endDay = DateTime(_endDate.year, _endDate.month, _endDate.day);
    return !txDay.isBefore(startDay) && !txDay.isAfter(endDay);
  }

  Set<String> _transactionAccountIds(Transaction tx) {
    final ids = <String>{};
    final metadata = tx.metadata;
    void addIfNonEmpty(String? value) {
      if (value != null && value.isNotEmpty) ids.add(value);
    }

    addIfNonEmpty(tx.sourceAccountId);
    addIfNonEmpty(tx.destinationAccountId);
    addIfNonEmpty(tx.cashbackAccountId);
    addIfNonEmpty(metadata?['accountId']?.toString());
    return ids;
  }

  Set<String> _extractTags(Transaction tx) {
    final raw = tx.metadata?['tags'];
    if (raw is List) {
      return raw
          .map((tag) => tag.toString().trim())
          .where((tag) => tag.isNotEmpty)
          .toSet();
    }
    return {};
  }

  String _paymentAppLabel(Transaction tx) {
    final app =
        tx.paymentAppName ?? tx.metadata?['paymentApp']?.toString() ?? '';
    if (app.trim().isEmpty) return 'No Payment App';
    return app.trim();
  }

  _ReportSummary _computeSummary(List<Transaction> transactions) {
    final summary = _ReportSummary();
    for (final tx in transactions) {
      final flow = _flowFor(tx);
      summary.add(flow);
    }
    return summary;
  }

  _FlowParts _flowFor(Transaction tx) {
    double inflow = 0;
    double outflow = 0;
    double transferVolume = 0;
    double charges = 0;
    double cashback = 0;

    final amount = tx.amount.clamp(0.0, double.infinity).toDouble();
    switch (tx.type) {
      case TransactionType.income:
      case TransactionType.borrowing:
        inflow += amount;
        break;
      case TransactionType.expense:
      case TransactionType.lending:
        outflow += amount;
        break;
      case TransactionType.investment:
        if (_includeInvestments) outflow += amount;
        break;
      case TransactionType.transfer:
        if (_includeTransfers) transferVolume += amount;
        charges = (tx.charges ?? 0).clamp(0.0, double.infinity).toDouble();
        if (charges > 0) outflow += charges;
        break;
      case TransactionType.cashback:
        if (_includeCashbackFlows) {
          final credit = (tx.cashbackAmount ?? tx.amount)
              .clamp(0.0, double.infinity)
              .toDouble();
          inflow += credit;
          cashback += credit;
        }
        break;
    }

    if (_includeCashbackFlows && tx.type != TransactionType.cashback) {
      final bonus =
          (tx.cashbackAmount ?? 0).clamp(0.0, double.infinity).toDouble();
      if (bonus > 0) {
        inflow += bonus;
        cashback += bonus;
      }
    }

    return _FlowParts(
      inflow: inflow,
      outflow: outflow,
      transferVolume: transferVolume,
      charges: charges,
      cashback: cashback,
      transactions: 1,
    );
  }

  List<_GroupedMetric> _buildGroupedMetrics(
    List<Transaction> transactions,
    Map<String, Account> accountsById,
    ReportGroupBy primaryGroupBy,
    ReportGroupBy secondaryGroupBy,
  ) {
    final primaryBuckets = <String, _MetricAccumulator>{};
    final secondaryBuckets = <String, Map<String, _MetricAccumulator>>{};

    for (final tx in transactions) {
      final primaryLabels = _labelsForGroupBy(tx, primaryGroupBy, accountsById);
      final secondaryLabels =
          _labelsForGroupBy(tx, secondaryGroupBy, accountsById);
      final flow = _flowFor(tx);

      for (final primary in primaryLabels) {
        final primaryAcc =
            primaryBuckets.putIfAbsent(primary, _MetricAccumulator.new);
        primaryAcc.add(flow);

        final secMap = secondaryBuckets.putIfAbsent(
            primary, () => <String, _MetricAccumulator>{});
        for (final secondary in secondaryLabels) {
          final secAcc = secMap.putIfAbsent(secondary, _MetricAccumulator.new);
          secAcc.add(flow);
        }
      }
    }

    final groups = primaryBuckets.entries.map((entry) {
      final secondary = secondaryBuckets[entry.key] ?? {};
      final secondaryMetrics = secondary.entries
          .map((sec) => _GroupedMetric.fromAccumulator(sec.key, sec.value))
          .toList();
      _sortGroupedMetrics(secondaryMetrics);
      return _GroupedMetric.fromAccumulator(
        entry.key,
        entry.value,
        secondaryBreakdown: secondaryMetrics,
      );
    }).toList();

    _sortGroupedMetrics(groups);
    return groups;
  }

  void _sortGroupedMetrics(List<_GroupedMetric> groups) {
    int compare(_GroupedMetric a, _GroupedMetric b) {
      double aMetric;
      double bMetric;
      switch (_sortMetric) {
        case ReportSortMetric.outflow:
          aMetric = a.outflow;
          bMetric = b.outflow;
          break;
        case ReportSortMetric.inflow:
          aMetric = a.inflow;
          bMetric = b.inflow;
          break;
        case ReportSortMetric.net:
          aMetric = a.net;
          bMetric = b.net;
          break;
        case ReportSortMetric.transferVolume:
          aMetric = a.transferVolume;
          bMetric = b.transferVolume;
          break;
        case ReportSortMetric.transactions:
          aMetric = a.transactionCount.toDouble();
          bMetric = b.transactionCount.toDouble();
          break;
      }

      final cmp = aMetric.compareTo(bMetric);
      return _sortDescending ? -cmp : cmp;
    }

    groups.sort(compare);
  }

  List<String> _labelsForGroupBy(
    Transaction tx,
    ReportGroupBy groupBy,
    Map<String, Account> accountsById,
  ) {
    switch (groupBy) {
      case ReportGroupBy.category:
        return [
          tx.metadata?['categoryName']?.toString().trim().isNotEmpty == true
              ? tx.metadata!['categoryName'].toString().trim()
              : 'Uncategorized'
        ];
      case ReportGroupBy.type:
        return [tx.getTypeLabel()];
      case ReportGroupBy.dateDay:
        return [_formatDate(tx.dateTime)];
      case ReportGroupBy.dateWeek:
        return [_formatWeekLabel(tx.dateTime)];
      case ReportGroupBy.dateMonth:
        return [_formatMonthLabel(tx.dateTime)];
      case ReportGroupBy.account:
        if (tx.type == TransactionType.transfer) {
          final labels = <String>{};
          if (tx.sourceAccountName?.trim().isNotEmpty == true) {
            labels.add('From: ${tx.sourceAccountName!.trim()}');
          }
          if (tx.destinationAccountName?.trim().isNotEmpty == true) {
            labels.add('To: ${tx.destinationAccountName!.trim()}');
          }
          if (labels.isNotEmpty) return labels.toList();
        }
        return [
          tx.metadata?['accountName']?.toString().trim().isNotEmpty == true
              ? tx.metadata!['accountName'].toString().trim()
              : tx.sourceAccountName ??
                  tx.destinationAccountName ??
                  tx.cashbackAccountName ??
                  'Unassigned Account'
        ];
      case ReportGroupBy.accountType:
        if (tx.type == TransactionType.transfer) {
          final labels = <String>{};
          final sourceType = accountsById[tx.sourceAccountId]?.type;
          final destinationType = accountsById[tx.destinationAccountId]?.type;
          if (sourceType != null) {
            labels.add('From: ${_accountTypeLabel(sourceType)}');
          }
          if (destinationType != null) {
            labels.add('To: ${_accountTypeLabel(destinationType)}');
          }
          if (labels.isNotEmpty) return labels.toList();
        }
        final types = _transactionAccountIds(tx)
            .map((id) => accountsById[id]?.type)
            .whereType<AccountType>()
            .map(_accountTypeLabel)
            .toSet();
        return types.isEmpty ? ['Unknown Account Type'] : types.toList();
      case ReportGroupBy.paymentApp:
        return [_paymentAppLabel(tx)];
      case ReportGroupBy.tag:
        final tags = _extractTags(tx).toList()..sort();
        return tags.isEmpty ? ['Untagged'] : tags;
    }
  }

  List<_TrendPoint> _buildTrendPoints(List<Transaction> transactions) {
    final buckets = <DateTime, _MetricAccumulator>{};
    for (final tx in transactions) {
      final day =
          DateTime(tx.dateTime.year, tx.dateTime.month, tx.dateTime.day);
      final bucket = buckets.putIfAbsent(day, _MetricAccumulator.new);
      bucket.add(_flowFor(tx));
    }

    final points = buckets.entries
        .map((entry) => _TrendPoint(
              date: entry.key,
              net: entry.value.net,
              inflow: entry.value.inflow,
              outflow: entry.value.outflow,
            ))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return points;
  }

  _StrategyProfile _effectiveStrategyProfile() {
    if (_strategyPreset == ReportStrategyPreset.custom) {
      return _StrategyProfile(
        savingsTargetRate: _customSavingsTargetRate,
        essentialsCapRate: _customEssentialsCapRate,
        discretionaryCapRate: _customDiscretionaryCapRate,
        investmentTargetRate: _customInvestmentRate,
        debtPaydownRate: _customDebtRate,
      );
    }
    return _strategyProfiles[_strategyPreset] ??
        _strategyProfiles[ReportStrategyPreset.balanced]!;
  }

  _StrategyEvaluation _evaluateStrategy(
    List<Transaction> transactions,
    _ReportSummary summary,
    _StrategyProfile profile,
  ) {
    double essentialOutflow = 0;
    double discretionaryOutflow = 0;
    double investmentOutflow = 0;
    double debtOutflow = 0;

    for (final tx in transactions) {
      if (tx.type == TransactionType.expense) {
        if (_isEssentialExpense(tx)) {
          essentialOutflow += tx.amount;
        } else {
          discretionaryOutflow += tx.amount;
        }
      }
      if (tx.type == TransactionType.investment) {
        investmentOutflow += tx.amount;
      }
      if (_isDebtRelated(tx)) {
        debtOutflow += tx.amount;
      }
    }

    final income = summary.inflow;
    final outflow = summary.outflow;
    final actualSavings = income - outflow;
    final targetSavings = income * profile.savingsTargetRate;
    final savingsGap = targetSavings - actualSavings;

    final essentialRatio = income > 0 ? essentialOutflow / income : 0.0;
    final discretionaryRatio = income > 0 ? discretionaryOutflow / income : 0.0;
    final investmentRatio = income > 0 ? investmentOutflow / income : 0.0;
    final debtRatio = income > 0 ? debtOutflow / income : 0.0;

    final recommendations = <String>[];
    if (income <= 0) {
      recommendations.add(
        'No inflow detected in current filter range. Include income transactions or expand date range for strategy evaluation.',
      );
      return _StrategyEvaluation(
        income: income,
        outflow: outflow,
        actualSavings: actualSavings,
        targetSavings: targetSavings,
        savingsGap: savingsGap,
        recommendations: recommendations,
      );
    }

    if (savingsGap > 0) {
      recommendations.add(
        'Increase monthly savings by ₹${savingsGap.toStringAsFixed(0)} to meet the target strategy.',
      );
    } else {
      recommendations.add(
        'Savings target achieved. Current buffer exceeds strategy requirement by ₹${(-savingsGap).toStringAsFixed(0)}.',
      );
    }

    if (essentialRatio > profile.essentialsCapRate) {
      recommendations.add(
        'Essentials are ${(essentialRatio * 100).toStringAsFixed(0)}% of income. Renegotiate recurring obligations or cap utilities/subscriptions.',
      );
    }
    if (discretionaryRatio > profile.discretionaryCapRate) {
      recommendations.add(
        'Discretionary spend is ${(discretionaryRatio * 100).toStringAsFixed(0)}% of income. Reduce low-priority spend buckets first.',
      );
    }
    if (investmentRatio < profile.investmentTargetRate) {
      recommendations.add(
        'Investment allocation is ${(investmentRatio * 100).toStringAsFixed(0)}%. Strategy target is ${(profile.investmentTargetRate * 100).toStringAsFixed(0)}%.',
      );
    }
    if (debtRatio < profile.debtPaydownRate &&
        profile.debtPaydownRate > 0.0 &&
        debtOutflow > 0) {
      recommendations.add(
        'Debt servicing is ${(debtRatio * 100).toStringAsFixed(0)}%. Strategy recommends ${(profile.debtPaydownRate * 100).toStringAsFixed(0)}% until liabilities compress.',
      );
    }

    if (recommendations.length < 2) {
      recommendations.add(
        'Use account-type and category filters to drill down and identify high-variance spending periods.',
      );
    }

    return _StrategyEvaluation(
      income: income,
      outflow: outflow,
      actualSavings: actualSavings,
      targetSavings: targetSavings,
      savingsGap: savingsGap,
      recommendations: recommendations,
    );
  }

  bool _isEssentialExpense(Transaction tx) {
    final merged = [
      tx.description,
      tx.metadata?['categoryName']?.toString() ?? '',
      tx.metadata?['merchant']?.toString() ?? '',
    ].join(' ').toLowerCase();

    const keywords = [
      'rent',
      'emi',
      'loan',
      'insurance',
      'electricity',
      'water',
      'gas',
      'internet',
      'wifi',
      'school fee',
      'fees',
      'medical',
      'pharmacy',
      'maintenance',
      'utility',
      'subscription',
    ];

    for (final keyword in keywords) {
      if (merged.contains(keyword)) return true;
    }
    return false;
  }

  bool _isDebtRelated(Transaction tx) {
    final merged = [
      tx.description,
      tx.metadata?['categoryName']?.toString() ?? '',
      tx.metadata?['merchant']?.toString() ?? '',
    ].join(' ').toLowerCase();
    return merged.contains('loan') ||
        merged.contains('emi') ||
        merged.contains('credit');
  }

  void _applyDatePreset(ReportDatePreset preset, {bool callSetState = true}) {
    final now = DateTime.now();
    DateTime start;
    DateTime end = DateTime(now.year, now.month, now.day);

    switch (preset) {
      case ReportDatePreset.all:
        start = DateTime(2000, 1, 1);
        break;
      case ReportDatePreset.thisMonth:
        start = DateTime(now.year, now.month, 1);
        break;
      case ReportDatePreset.last30Days:
        start = end.subtract(const Duration(days: 29));
        break;
      case ReportDatePreset.last90Days:
        start = end.subtract(const Duration(days: 89));
        break;
      case ReportDatePreset.thisYear:
        start = DateTime(now.year, 1, 1);
        break;
      case ReportDatePreset.custom:
        start = _startDate;
        end = _endDate;
        break;
    }

    if (callSetState) {
      setState(() {
        _datePreset = preset;
        _startDate = start;
        _endDate = end;
      });
    } else {
      _datePreset = preset;
      _startDate = start;
      _endDate = end;
    }
  }

  void _applyStrategyPreset(ReportStrategyPreset preset,
      {bool callSetState = true}) {
    final profile = _strategyProfiles[preset];
    void applyValues() {
      _strategyPreset = preset;
      if (profile != null) {
        _customSavingsTargetRate = profile.savingsTargetRate;
        _customEssentialsCapRate = profile.essentialsCapRate;
        _customDiscretionaryCapRate = profile.discretionaryCapRate;
        _customInvestmentRate = profile.investmentTargetRate;
        _customDebtRate = profile.debtPaydownRate;
      }
    }

    if (callSetState) {
      setState(applyValues);
    } else {
      applyValues();
    }
  }

  Future<void> _pickCustomDate({required bool isStart}) async {
    final initialDate = isStart ? _startDate : _endDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000, 1, 1),
      lastDate: DateTime(2100, 1, 1),
    );
    if (picked == null) return;

    setState(() {
      _datePreset = ReportDatePreset.custom;
      if (isStart) {
        _startDate = DateTime(picked.year, picked.month, picked.day);
        if (_startDate.isAfter(_endDate)) _endDate = _startDate;
      } else {
        _endDate = DateTime(picked.year, picked.month, picked.day);
        if (_endDate.isBefore(_startDate)) _startDate = _endDate;
      }
    });
  }

  Future<void> _pickGroupBy({required bool isPrimary}) async {
    final selected = isPrimary ? _primaryGroupBy : _secondaryGroupBy;
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(isPrimary ? 'Primary Grouping' : 'Secondary Grouping'),
        actions: ReportGroupBy.values.map((groupBy) {
          final isSelected = groupBy == selected;
          return CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              setState(() {
                if (isPrimary) {
                  _primaryGroupBy = groupBy;
                } else {
                  _secondaryGroupBy = groupBy;
                }
              });
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isSelected)
                  const Padding(
                    padding: EdgeInsets.only(right: 6),
                    child: Icon(
                      CupertinoIcons.check_mark,
                      size: 16,
                    ),
                  ),
                Text(groupBy.label),
              ],
            ),
          );
        }).toList(),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  Future<void> _pickSortMetric() async {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Sort Grouped Metrics'),
        actions: ReportSortMetric.values.map((metric) {
          final isSelected = metric == _sortMetric;
          return CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              setState(() => _sortMetric = metric);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isSelected)
                  const Padding(
                    padding: EdgeInsets.only(right: 6),
                    child: Icon(CupertinoIcons.check_mark, size: 16),
                  ),
                Text(metric.label),
              ],
            ),
          );
        }).toList(),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  Future<void> _showMultiSelectSheet<T>({
    required String title,
    required List<_SelectableOption<T>> options,
    required Set<T> selected,
    required ValueChanged<Set<T>> onApply,
  }) async {
    final localSelected = <T>{...selected};
    final sortedOptions = [...options]..sort(
        (a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()),
      );

    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Container(
            height: MediaQuery.of(ctx).size.height * 0.75,
            decoration: AppStyles.sectionDecoration(
              ctx,
              tint: AppStyles.accentBlue.withValues(alpha: 0.8),
              radius: 24,
            ).copyWith(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  SizedBox(height: Spacing.md),
                  Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppStyles.getSecondaryTextColor(ctx)
                          .withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  SizedBox(height: Spacing.md),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: Spacing.lg),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: AppStyles.titleStyle(ctx),
                          ),
                        ),
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: () {
                            setSheetState(localSelected.clear);
                          },
                          child: const Text('Clear'),
                        ),
                        SizedBox(width: Spacing.sm),
                        CupertinoButton.filled(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          onPressed: () {
                            onApply(localSelected);
                            Navigator.of(ctx).pop();
                          },
                          child: const Text('Apply'),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: Spacing.sm),
                  Expanded(
                    child: ListView.builder(
                      itemCount: sortedOptions.length,
                      itemBuilder: (ctx, index) {
                        final option = sortedOptions[index];
                        final isSelected = localSelected.contains(option.value);
                        return GestureDetector(
                          onTap: () {
                            setSheetState(() {
                              if (isSelected) {
                                localSelected.remove(option.value);
                              } else {
                                localSelected.add(option.value);
                              }
                            });
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: Spacing.lg,
                              vertical: Spacing.md,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppStyles.accentBlue.withValues(alpha: 0.14)
                                  : null,
                              border: Border(
                                bottom: BorderSide(
                                  color: AppStyles.getDividerColor(ctx)
                                      .withValues(alpha: 0.25),
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    option.label,
                                    style: TextStyle(
                                      color: AppStyles.getTextColor(ctx),
                                      fontSize: TypeScale.callout,
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  const Icon(
                                    CupertinoIcons.check_mark_circled_solid,
                                    color: SemanticColors.success,
                                  ),
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
        },
      ),
    );
  }

  void _resetFilters() {
    setState(() {
      _selectedTransactionTypes
        ..clear()
        ..addAll(TransactionType.values);
      _selectedCategoryIds.clear();
      _selectedAccountIds.clear();
      _selectedAccountTypes.clear();
      _selectedTags.clear();
      _selectedPaymentApps.clear();
      _includeTransfers = true;
      _includeInvestments = true;
      _includeCashbackFlows = true;
      _applyDatePreset(ReportDatePreset.last30Days, callSetState: false);
      _primaryGroupBy = ReportGroupBy.category;
      _secondaryGroupBy = ReportGroupBy.type;
      _sortMetric = ReportSortMetric.outflow;
      _sortDescending = true;
    });
    toast.showSuccess('Analysis filters reset');
  }

  Future<void> _exportPdf(_ReportSnapshot snapshot) async {
    setState(() => _isExportingPdf = true);
    try {
      final directory = await _ensureReportDirectory();
      final fileName = 'deep_analysis_${_timestamp()}.pdf';
      final file = File('${directory.path}/$fileName');
      final lines = _buildPdfLines(snapshot);
      final bytes = _MinimalPdfBuilder.build(lines);
      await file.writeAsBytes(bytes, flush: true);
      if (!mounted) return;
      toast.showSuccess('PDF exported');
      await _showExportPathDialog('PDF', file.path);
    } catch (e) {
      toast.showError('Failed to export PDF: $e');
    } finally {
      if (mounted) setState(() => _isExportingPdf = false);
    }
  }

  Future<void> _exportExcel(_ReportSnapshot snapshot) async {
    setState(() => _isExportingExcel = true);
    try {
      final directory = await _ensureReportDirectory();
      final fileName = 'deep_analysis_${_timestamp()}.xls';
      final file = File('${directory.path}/$fileName');
      final content = _buildExcelWorkbook(snapshot);
      await file.writeAsString(content, flush: true);
      if (!mounted) return;
      toast.showSuccess('Excel export generated');
      await _showExportPathDialog('Excel', file.path);
    } catch (e) {
      toast.showError('Failed to export Excel: $e');
    } finally {
      if (mounted) setState(() => _isExportingExcel = false);
    }
  }

  Future<Directory> _ensureReportDirectory() async {
    final baseDir = await getApplicationDocumentsDirectory();
    final reportDir = Directory('${baseDir.path}/reports');
    if (!await reportDir.exists()) {
      await reportDir.create(recursive: true);
    }
    return reportDir;
  }

  Future<void> _showExportPathDialog(String format, String path) async {
    await showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text('$format Export Ready'),
        content: Text(
          path,
          style: const TextStyle(fontSize: 12),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: path));
              if (ctx.mounted) Navigator.of(ctx).pop();
              toast.showInfo('Export path copied');
            },
            child: const Text('Copy Path'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  List<String> _buildPdfLines(_ReportSnapshot snapshot) {
    final lines = <String>[
      '[V] $_reportAppName',
      _reportTagline,
      'Generated: ${_formatDateTime(snapshot.generatedAt)}',
      'Date Preset: ${snapshot.datePreset.label}',
      'Range: ${_formatDate(snapshot.startDate)} to ${_formatDate(snapshot.endDate)}',
      'Primary Group: ${snapshot.primaryGroupBy.label}',
      'Secondary Group: ${snapshot.secondaryGroupBy.label}',
      '------------------------------------------------------------',
      'Summary',
      'Transactions: ${snapshot.summary.transactionCount}',
      'Inflow (INR): ${snapshot.summary.inflow.toStringAsFixed(2)}',
      'Outflow (INR): ${snapshot.summary.outflow.toStringAsFixed(2)}',
      'Net (INR): ${snapshot.summary.net.toStringAsFixed(2)}',
      'Transfer Volume (INR): ${snapshot.summary.transferVolume.toStringAsFixed(2)}',
      'Charges (INR): ${snapshot.summary.charges.toStringAsFixed(2)}',
      'Cashback (INR): ${snapshot.summary.cashback.toStringAsFixed(2)}',
      '------------------------------------------------------------',
      'Strategy',
      'Savings Target %: ${(snapshot.strategyProfile.savingsTargetRate * 100).toStringAsFixed(1)}',
      'Essentials Cap %: ${(snapshot.strategyProfile.essentialsCapRate * 100).toStringAsFixed(1)}',
      'Discretionary Cap %: ${(snapshot.strategyProfile.discretionaryCapRate * 100).toStringAsFixed(1)}',
      'Investment Target %: ${(snapshot.strategyProfile.investmentTargetRate * 100).toStringAsFixed(1)}',
      'Debt Target %: ${(snapshot.strategyProfile.debtPaydownRate * 100).toStringAsFixed(1)}',
      'Savings Gap (INR): ${snapshot.strategyEvaluation.savingsGap.toStringAsFixed(2)}',
      '------------------------------------------------------------',
      'Top Group Breakdown',
    ];

    for (final group in snapshot.groupedMetrics.take(14)) {
      lines.add(
        '${group.label}: In ${group.inflow.toStringAsFixed(0)}, Out ${group.outflow.toStringAsFixed(0)}, Net ${group.net.toStringAsFixed(0)}, Txn ${group.transactionCount}',
      );
      for (final sub in group.secondaryBreakdown.take(3)) {
        lines.add(
          '  - ${sub.label}: Net ${sub.net.toStringAsFixed(0)} (${sub.transactionCount})',
        );
      }
    }
    lines.add('------------------------------------------------------------');
    lines.add('Recommendations');
    for (final rec in snapshot.strategyEvaluation.recommendations.take(10)) {
      lines.add('- $rec');
    }

    return lines;
  }

  String _buildExcelWorkbook(_ReportSnapshot snapshot) {
    final sb = StringBuffer();
    sb.writeln('<?xml version="1.0"?>');
    sb.writeln('<?mso-application progid="Excel.Sheet"?>');
    sb.writeln(
      '<Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet" '
      'xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet">',
    );

    sb.writeln('<Worksheet ss:Name="Summary"><Table>');
    _appendExcelRow(sb, ['App', _reportAppName]);
    _appendExcelRow(sb, ['Tagline', _reportTagline]);
    _appendExcelRow(
        sb, ['Generated At', _formatDateTime(snapshot.generatedAt)]);
    _appendExcelRow(sb, ['Date Preset', snapshot.datePreset.label]);
    _appendExcelRow(sb, [
      'Range',
      '${_formatDate(snapshot.startDate)} to ${_formatDate(snapshot.endDate)}'
    ]);
    _appendExcelRow(sb, ['Transactions', snapshot.summary.transactionCount]);
    _appendExcelRow(sb, ['Inflow', snapshot.summary.inflow]);
    _appendExcelRow(sb, ['Outflow', snapshot.summary.outflow]);
    _appendExcelRow(sb, ['Net', snapshot.summary.net]);
    _appendExcelRow(sb, ['Transfer Volume', snapshot.summary.transferVolume]);
    _appendExcelRow(sb, ['Charges', snapshot.summary.charges]);
    _appendExcelRow(sb, ['Cashback', snapshot.summary.cashback]);
    _appendExcelRow(sb, []);
    _appendExcelRow(
      sb,
      ['Group', 'Txn Count', 'Inflow', 'Outflow', 'Net', 'Transfer', 'Charges'],
    );
    for (final group in snapshot.groupedMetrics) {
      _appendExcelRow(
        sb,
        [
          group.label,
          group.transactionCount,
          group.inflow,
          group.outflow,
          group.net,
          group.transferVolume,
          group.charges,
        ],
      );
      for (final sub in group.secondaryBreakdown) {
        _appendExcelRow(
          sb,
          [
            '  > ${sub.label}',
            sub.transactionCount,
            sub.inflow,
            sub.outflow,
            sub.net,
            sub.transferVolume,
            sub.charges,
          ],
        );
      }
    }
    sb.writeln('</Table></Worksheet>');

    sb.writeln('<Worksheet ss:Name="Transactions"><Table>');
    _appendExcelRow(
      sb,
      [
        'Date',
        'Type',
        'Description',
        'Amount',
        'Inflow',
        'Outflow',
        'Transfer',
        'Charges',
        'Cashback',
        'Category',
        'Account',
        'Account Type',
        'Payment App',
        'Tags',
      ],
    );
    for (final tx in snapshot.transactions) {
      final flow = _flowFor(tx);
      final accountLabel = tx.sourceAccountName ??
          tx.destinationAccountName ??
          tx.cashbackAccountName ??
          tx.metadata?['accountName']?.toString() ??
          '';
      final accountType = _transactionAccountIds(tx)
          .map((id) => snapshot.accountsById[id]?.type)
          .whereType<AccountType>()
          .map(_accountTypeLabel)
          .join(' | ');
      final tags = _extractTags(tx).join(' | ');
      _appendExcelRow(
        sb,
        [
          _formatDate(tx.dateTime),
          tx.getTypeLabel(),
          tx.description,
          tx.amount,
          flow.inflow,
          flow.outflow,
          flow.transferVolume,
          flow.charges,
          flow.cashback,
          tx.metadata?['categoryName']?.toString() ?? '',
          accountLabel,
          accountType,
          _paymentAppLabel(tx),
          tags,
        ],
      );
    }
    sb.writeln('</Table></Worksheet>');
    sb.writeln('</Workbook>');
    return sb.toString();
  }

  void _appendExcelRow(StringBuffer sb, List<dynamic> cells) {
    sb.write('<Row>');
    for (final cell in cells) {
      if (cell is num) {
        sb.write(
          '<Cell><Data ss:Type="Number">${cell.toString()}</Data></Cell>',
        );
      } else {
        sb.write(
          '<Cell><Data ss:Type="String">${_xmlEscape(cell.toString())}</Data></Cell>',
        );
      }
    }
    sb.writeln('</Row>');
  }

  String _xmlEscape(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  List<String> _collectAvailableTags(List<Transaction> transactions) {
    final tags = <String>{};
    for (final tx in transactions) {
      tags.addAll(_extractTags(tx));
    }
    final list = tags.where((tag) => tag.isNotEmpty).toList()..sort();
    return list;
  }

  List<String> _collectAvailablePaymentApps(List<Transaction> transactions) {
    final apps = <String>{};
    for (final tx in transactions) {
      final app = _paymentAppLabel(tx);
      if (app != 'No Payment App') apps.add(app);
    }
    final list = apps.toList()..sort();
    return list;
  }

  String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  String _formatDateTime(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '${_formatDate(date)} $hour:$minute';
  }

  String _formatWeekLabel(DateTime date) {
    final week = _weekOfYear(date).toString().padLeft(2, '0');
    return '${date.year}-W$week';
  }

  int _weekOfYear(DateTime date) {
    final firstDay = DateTime(date.year, 1, 1);
    final dayOfYear = date.difference(firstDay).inDays + 1;
    return ((dayOfYear + firstDay.weekday - 1) / 7).ceil();
  }

  String _formatMonthLabel(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    return '${date.year}-$month';
  }

  String _accountTypeLabel(AccountType type) {
    switch (type) {
      case AccountType.savings:
        return 'Savings';
      case AccountType.current:
        return 'Current';
      case AccountType.credit:
        return 'Credit';
      case AccountType.payLater:
        return 'Pay Later';
      case AccountType.wallet:
        return 'Wallet';
      case AccountType.investment:
        return 'Investment';
      case AccountType.cash:
        return 'Cash';
    }
  }

  String _timestamp() {
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    final hour = now.hour.toString().padLeft(2, '0');
    final min = now.minute.toString().padLeft(2, '0');
    final sec = now.second.toString().padLeft(2, '0');
    return '${now.year}$month${day}_$hour$min$sec';
  }
}

class _SelectableOption<T> {
  final T value;
  final String label;

  const _SelectableOption({
    required this.value,
    required this.label,
  });
}

class _FlowParts {
  final double inflow;
  final double outflow;
  final double transferVolume;
  final double charges;
  final double cashback;
  final int transactions;

  const _FlowParts({
    required this.inflow,
    required this.outflow,
    required this.transferVolume,
    required this.charges,
    required this.cashback,
    required this.transactions,
  });
}

class _ReportSummary {
  double inflow = 0.0;
  double outflow = 0.0;
  double transferVolume = 0.0;
  double charges = 0.0;
  double cashback = 0.0;
  int transactionCount = 0;

  double get net => inflow - outflow;

  void add(_FlowParts flow) {
    inflow += flow.inflow;
    outflow += flow.outflow;
    transferVolume += flow.transferVolume;
    charges += flow.charges;
    cashback += flow.cashback;
    transactionCount += flow.transactions;
  }
}

class _MetricAccumulator {
  double inflow = 0.0;
  double outflow = 0.0;
  double transferVolume = 0.0;
  double charges = 0.0;
  double cashback = 0.0;
  int transactions = 0;

  double get net => inflow - outflow;

  void add(_FlowParts flow) {
    inflow += flow.inflow;
    outflow += flow.outflow;
    transferVolume += flow.transferVolume;
    charges += flow.charges;
    cashback += flow.cashback;
    transactions += flow.transactions;
  }
}

class _GroupedMetric {
  final String label;
  final double inflow;
  final double outflow;
  final double transferVolume;
  final double charges;
  final double cashback;
  final int transactionCount;
  final List<_GroupedMetric> secondaryBreakdown;

  const _GroupedMetric({
    required this.label,
    required this.inflow,
    required this.outflow,
    required this.transferVolume,
    required this.charges,
    required this.cashback,
    required this.transactionCount,
    this.secondaryBreakdown = const [],
  });

  double get net => inflow - outflow;

  factory _GroupedMetric.fromAccumulator(
    String label,
    _MetricAccumulator acc, {
    List<_GroupedMetric> secondaryBreakdown = const [],
  }) {
    return _GroupedMetric(
      label: label,
      inflow: acc.inflow,
      outflow: acc.outflow,
      transferVolume: acc.transferVolume,
      charges: acc.charges,
      cashback: acc.cashback,
      transactionCount: acc.transactions,
      secondaryBreakdown: secondaryBreakdown,
    );
  }
}

class _TrendPoint {
  final DateTime date;
  final double net;
  final double inflow;
  final double outflow;

  const _TrendPoint({
    required this.date,
    required this.net,
    required this.inflow,
    required this.outflow,
  });
}

class _StrategyEvaluation {
  final double income;
  final double outflow;
  final double actualSavings;
  final double targetSavings;
  final double savingsGap;
  final List<String> recommendations;

  const _StrategyEvaluation({
    required this.income,
    required this.outflow,
    required this.actualSavings,
    required this.targetSavings,
    required this.savingsGap,
    required this.recommendations,
  });
}

class _ReportSnapshot {
  final DateTime generatedAt;
  final DateTime startDate;
  final DateTime endDate;
  final ReportDatePreset datePreset;
  final ReportGroupBy primaryGroupBy;
  final ReportGroupBy secondaryGroupBy;
  final _ReportSummary summary;
  final List<_GroupedMetric> groupedMetrics;
  final List<Transaction> transactions;
  final _StrategyProfile strategyProfile;
  final _StrategyEvaluation strategyEvaluation;
  final Map<String, Account> accountsById;

  const _ReportSnapshot({
    required this.generatedAt,
    required this.startDate,
    required this.endDate,
    required this.datePreset,
    required this.primaryGroupBy,
    required this.secondaryGroupBy,
    required this.summary,
    required this.groupedMetrics,
    required this.transactions,
    required this.strategyProfile,
    required this.strategyEvaluation,
    required this.accountsById,
  });
}

class _BarDistributionPainter extends CustomPainter {
  final List<_GroupedMetric> groups;
  final ReportSortMetric metric;
  final Color textColor;
  final Color secondaryColor;

  _BarDistributionPainter({
    required this.groups,
    required this.metric,
    required this.textColor,
    required this.secondaryColor,
  });

  double _metricValue(_GroupedMetric metricData) {
    switch (metric) {
      case ReportSortMetric.outflow:
        return metricData.outflow;
      case ReportSortMetric.inflow:
        return metricData.inflow;
      case ReportSortMetric.net:
        return metricData.net.abs();
      case ReportSortMetric.transferVolume:
        return metricData.transferVolume;
      case ReportSortMetric.transactions:
        return metricData.transactionCount.toDouble();
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (groups.isEmpty) return;

    final topPadding = 12.0;
    final bottomPadding = 48.0;
    final leftPadding = 12.0;
    final rightPadding = 10.0;
    final chartHeight = size.height - topPadding - bottomPadding;
    final chartWidth = size.width - leftPadding - rightPadding;

    final maxValue = groups
        .map(_metricValue)
        .fold<double>(0.0, (max, value) => value > max ? value : max);
    if (maxValue <= 0) return;

    final barGap = 8.0;
    final barWidth =
        (chartWidth - (barGap * (groups.length - 1))) / groups.length;
    final palette = <Color>[
      SemanticColors.primary,
      SemanticColors.info,
      SemanticColors.success,
      SemanticColors.warning,
      SemanticColors.categories,
      SemanticColors.lending,
      SemanticColors.accounts,
      SemanticColors.error,
    ];

    final axisPaint = Paint()
      ..color = secondaryColor.withValues(alpha: 0.35)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(leftPadding, topPadding + chartHeight),
      Offset(leftPadding + chartWidth, topPadding + chartHeight),
      axisPaint,
    );

    for (int i = 0; i < groups.length; i++) {
      final value = _metricValue(groups[i]);
      final height = (value / maxValue) * chartHeight;
      final x = leftPadding + (i * (barWidth + barGap));
      final y = topPadding + (chartHeight - height);
      final color = palette[i % palette.length];

      final barRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth, height),
        const Radius.circular(6),
      );
      final barPaint = Paint()..color = color.withValues(alpha: 0.85);
      canvas.drawRRect(barRect, barPaint);

      final label = groups[i].label.length > 8
          ? '${groups[i].label.substring(0, 8)}…'
          : groups[i].label;
      final labelPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: textColor,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout(maxWidth: barWidth + 6);
      labelPainter.paint(
        canvas,
        Offset(x - 2, topPadding + chartHeight + 6),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BarDistributionPainter oldDelegate) {
    return oldDelegate.groups != groups || oldDelegate.metric != metric;
  }
}

class _TrendPainter extends CustomPainter {
  final List<_TrendPoint> points;
  final Color positiveColor;
  final Color negativeColor;
  final Color axisColor;

  _TrendPainter({
    required this.points,
    required this.positiveColor,
    required this.negativeColor,
    required this.axisColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final leftPadding = 10.0;
    final rightPadding = 10.0;
    final topPadding = 12.0;
    final bottomPadding = 12.0;
    final width = size.width - leftPadding - rightPadding;
    final height = size.height - topPadding - bottomPadding;
    final minNet = points.map((p) => p.net).fold<double>(
        points.first.net, (min, value) => value < min ? value : min);
    final maxNet = points.map((p) => p.net).fold<double>(
        points.first.net, (max, value) => value > max ? value : max);

    final adjustedMin = minNet == maxNet ? minNet - 1 : minNet;
    final adjustedMax = minNet == maxNet ? maxNet + 1 : maxNet;

    final midY =
        topPadding + ((adjustedMax / (adjustedMax - adjustedMin)) * height);
    final axisPaint = Paint()
      ..color = axisColor.withValues(alpha: 0.25)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(leftPadding, midY),
      Offset(leftPadding + width, midY),
      axisPaint,
    );

    final path = Path();
    for (int i = 0; i < points.length; i++) {
      final x = leftPadding + (i / (points.length - 1)) * width;
      final normalized =
          (points[i].net - adjustedMin) / (adjustedMax - adjustedMin);
      final y = topPadding + height - (normalized * height);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final linePaint = Paint()
      ..color = points.last.net >= 0 ? positiveColor : negativeColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, linePaint);

    for (int i = 0;
        i < points.length;
        i += math.max(1, (points.length / 10).floor())) {
      final x = leftPadding + (i / (points.length - 1)) * width;
      final normalized =
          (points[i].net - adjustedMin) / (adjustedMax - adjustedMin);
      final y = topPadding + height - (normalized * height);
      canvas.drawCircle(
        Offset(x, y),
        2.4,
        Paint()..color = linePaint.color.withValues(alpha: 0.85),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) {
    return oldDelegate.points != points;
  }
}

class _MinimalPdfBuilder {
  static Uint8List build(List<String> inputLines) {
    final lines = [...inputLines];
    if (lines.length > 48) {
      lines
        ..removeRange(48, lines.length)
        ..add('... output truncated for single-page export ...');
    }
    final content = _buildContentStream(lines);
    final contentLength = utf8.encode(content).length;

    final objects = <String>[
      '<< /Type /Catalog /Pages 2 0 R >>',
      '<< /Type /Pages /Count 1 /Kids [3 0 R] >>',
      '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] '
          '/Contents 4 0 R /Resources << /Font << /F1 5 0 R >> >> >>',
      '<< /Length $contentLength >>\nstream\n$content\nendstream',
      '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
    ];

    final buffer = StringBuffer('%PDF-1.4\n');
    final offsets = <int>[0];
    int objectIndex = 1;
    for (final object in objects) {
      offsets.add(utf8.encode(buffer.toString()).length);
      buffer.write('$objectIndex 0 obj\n$object\nendobj\n');
      objectIndex++;
    }

    final xrefOffset = utf8.encode(buffer.toString()).length;
    buffer.write('xref\n0 ${objects.length + 1}\n');
    buffer.write('0000000000 65535 f \n');
    for (final offset in offsets.skip(1)) {
      buffer.write('${offset.toString().padLeft(10, '0')} 00000 n \n');
    }
    buffer.write(
      'trailer << /Size ${objects.length + 1} /Root 1 0 R >>\n'
      'startxref\n$xrefOffset\n%%EOF',
    );
    return Uint8List.fromList(utf8.encode(buffer.toString()));
  }

  static String _buildContentStream(List<String> lines) {
    final sb = StringBuffer();
    sb.writeln('BT');
    sb.writeln('/F1 11 Tf');
    sb.writeln('50 800 Td');
    for (int i = 0; i < lines.length; i++) {
      final escaped = _escapePdfText(lines[i]);
      if (i > 0) sb.writeln('0 -14 Td');
      sb.writeln('($escaped) Tj');
    }
    sb.writeln('ET');
    return sb.toString();
  }

  static String _escapePdfText(String text) {
    return text
        .replaceAll('\\', '\\\\')
        .replaceAll('(', '\\(')
        .replaceAll(')', '\\)')
        .replaceAll('\n', ' ');
  }
}
