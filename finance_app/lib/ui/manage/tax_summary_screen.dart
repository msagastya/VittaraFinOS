import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/investment_model.dart';
import 'package:vittara_fin_os/logic/investments_controller.dart';
import 'package:vittara_fin_os/logic/transaction_model.dart';
import 'package:vittara_fin_os/logic/transactions_controller.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';

/// Metadata key used by TransactionWizard to store tax section tags.
const String _kTaxTagKey = 'taxTag';

class _TaxSection {
  final String code;
  final String label;
  final double? limitINR;

  const _TaxSection(this.code, this.label, {this.limitINR});
}

const List<_TaxSection> _kTaxSections = [
  _TaxSection('80C', '80C – Investments & Savings', limitINR: 150000),
  _TaxSection('80D', '80D – Health Insurance', limitINR: 25000),
  _TaxSection('HRA', 'HRA – House Rent Allowance'),
  _TaxSection('80G', '80G – Donations'),
  _TaxSection('80E', '80E – Education Loan Interest'),
  _TaxSection('NPS', 'NPS – Additional Contribution', limitINR: 50000),
  _TaxSection('24B', '24B – Home Loan Interest', limitINR: 200000),
];

/// Computes the financial year (Apr–Mar) for a given date.
({int startYear, int endYear}) _fyFor(DateTime d) {
  final startYear = d.month >= 4 ? d.year : d.year - 1;
  return (startYear: startYear, endYear: startYear + 1);
}

class TaxSummaryScreen extends StatefulWidget {
  const TaxSummaryScreen({super.key});

  @override
  State<TaxSummaryScreen> createState() => _TaxSummaryScreenState();
}

class _TaxSummaryScreenState extends State<TaxSummaryScreen> {
  late int _fyStartYear;

  @override
  void initState() {
    super.initState();
    final fy = _fyFor(DateTime.now());
    _fyStartYear = fy.startYear;
  }

  List<Transaction> _filterByFY(List<Transaction> all) {
    final start = DateTime(_fyStartYear, 4, 1);
    final end = DateTime(_fyStartYear + 1, 3, 31, 23, 59, 59);
    return all.where((t) {
      return !t.dateTime.isBefore(start) && !t.dateTime.isAfter(end);
    }).toList();
  }

  String _fYLabel() => 'FY $_fyStartYear–${(_fyStartYear + 1).toString().substring(2)}';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return CupertinoPageScaffold(
      navigationBar: AppStyles.isLandscape(context) ? null : CupertinoNavigationBar(
        middle: Text('Tax Summary · ${_fYLabel()}'),
        previousPageTitle: 'Back',
        backgroundColor: AppStyles.getBackground(context),
        border: null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              onPressed: () {
                setState(() => _fyStartYear--);
              },
              child: const Icon(CupertinoIcons.chevron_left, size: 18),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              onPressed: () {
                final currentFy = _fyFor(DateTime.now()).startYear;
                if (_fyStartYear < currentFy) {
                  setState(() => _fyStartYear++);
                }
              },
              child: Icon(
                CupertinoIcons.chevron_right,
                size: 18,
                color: _fyStartYear < _fyFor(DateTime.now()).startYear
                    ? null
                    : CupertinoColors.systemGrey,
              ),
            ),
          ],
        ),
      ),
      child: SafeArea(
        child: Container(
          color: isDark ? Colors.black : CupertinoColors.systemGroupedBackground,
          child: Consumer2<TransactionsController, InvestmentsController>(
            builder: (context, txController, invController, _) {
              final fyTxns = _filterByFY(txController.transactions);

              // Group tagged transactions by section code
              final Map<String, List<Transaction>> grouped = {};
              for (final tx in fyTxns) {
                final tag = tx.metadata?[_kTaxTagKey] as String?;
                if (tag != null && tag.isNotEmpty) {
                  grouped.putIfAbsent(tag, () => []).add(tx);
                }
              }

              // Total tagged
              final totalTagged = grouped.values
                  .expand((l) => l)
                  .fold<double>(0, (s, t) => s + t.amount);

              final hasTags = grouped.isNotEmpty;

              // Capital gains: equity investments grouped by holding period.
              final equityTypes = {InvestmentType.stocks, InvestmentType.mutualFund};
              final equityInvestments = invController.investments
                  .where((i) => equityTypes.contains(i.type))
                  .toList();
              final now = DateTime.now();
              final ltcgHoldings = <Investment>[];
              final stcgHoldings = <Investment>[];
              for (final inv in equityInvestments) {
                final purchaseDate = _investmentPurchaseDate(inv);
                if (purchaseDate == null) continue;
                final months = (now.year - purchaseDate.year) * 12 +
                    (now.month - purchaseDate.month);
                if (months >= 12) {
                  ltcgHoldings.add(inv);
                } else {
                  stcgHoldings.add(inv);
                }
              }

              // 80C from investments: NPS & NSS (auto-detected).
              final autoDetected80C = invController.investments.where((i) =>
                  i.type == InvestmentType.nationalSavingsScheme ||
                  i.type == InvestmentType.pensionSchemes);
              final autoDetected80CTotal =
                  autoDetected80C.fold<double>(0, (s, i) => s + i.amount);

              return Column(
                children: [
                  if (AppStyles.isLandscape(context))
                    _buildLandscapeNavBar(context),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(
                          Spacing.lg, Spacing.lg, Spacing.lg, 80),
                      children: [
                  // Header summary
                  Container(
                    padding: const EdgeInsets.all(Spacing.lg),
                    decoration: AppStyles.sectionDecoration(
                      context,
                      tint: AppStyles.gold(context).withValues(alpha: 0.6),
                      radius: Radii.xl,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppStyles.gold(context)
                                    .withValues(alpha: 0.18),
                                borderRadius:
                                    BorderRadius.circular(Radii.md),
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                CupertinoIcons.doc_text_fill,
                                color: AppStyles.gold(context),
                                size: IconSizes.sm,
                              ),
                            ),
                            const SizedBox(width: Spacing.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'India Tax Deductions',
                                    style: TextStyle(
                                      color: AppStyles.getTextColor(context),
                                      fontWeight: FontWeight.w800,
                                      fontSize: TypeScale.callout,
                                    ),
                                  ),
                                  Text(
                                    _fYLabel(),
                                    style: TextStyle(
                                      color: AppStyles.getSecondaryTextColor(
                                          context),
                                      fontSize: TypeScale.caption,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: Spacing.md),
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            _statBox(
                              context,
                              label: 'Tagged Txns',
                              value: grouped.values
                                  .fold<int>(0, (s, l) => s + l.length)
                                  .toString(),
                            ),
                            _statBox(
                              context,
                              label: 'Total Claimed',
                              value: _fmt(totalTagged),
                            ),
                            _statBox(
                              context,
                              label: 'Sections Used',
                              value: grouped.keys.length.toString(),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: Spacing.lg),

                  if (!hasTags)
                    Container(
                      padding: const EdgeInsets.all(Spacing.xl),
                      decoration: BoxDecoration(
                        color: AppStyles.getCardColor(context),
                        borderRadius: BorderRadius.circular(Radii.lg),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            CupertinoIcons.doc_text_fill,
                            size: 40,
                            color: AppStyles.getSecondaryTextColor(context),
                          ),
                          const SizedBox(height: Spacing.md),
                          Text(
                            'No Tax-Tagged Transactions',
                            style: TextStyle(
                              color: AppStyles.getTextColor(context),
                              fontWeight: FontWeight.w700,
                              fontSize: TypeScale.callout,
                            ),
                          ),
                          const SizedBox(height: Spacing.xs),
                          Text(
                            'Tag transactions with a tax section (80C, 80D, HRA…) in the Description step of Add Transaction.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppStyles.getSecondaryTextColor(context),
                              fontSize: TypeScale.footnote,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ..._kTaxSections.map((section) {
                      final txns = grouped[section.code] ?? [];
                      if (txns.isEmpty) return const SizedBox.shrink();
                      final total =
                          txns.fold<double>(0, (s, t) => s + t.amount);
                      final limit = section.limitINR;
                      final progress =
                          limit != null ? (total / limit).clamp(0.0, 1.0) : null;
                      final isOver =
                          limit != null && total > limit;

                      return Container(
                        margin: const EdgeInsets.only(bottom: Spacing.md),
                        padding: const EdgeInsets.all(Spacing.md),
                        decoration: BoxDecoration(
                          color: AppStyles.getCardColor(context),
                          borderRadius:
                              BorderRadius.circular(Radii.lg),
                          border: Border.all(
                            color: isOver
                                ? AppStyles.gold(context)
                                    .withValues(alpha: 0.5)
                                : AppStyles.getDividerColor(context),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppStyles.gold(context)
                                        .withValues(alpha: 0.15),
                                    borderRadius:
                                        BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    section.code,
                                    style: TextStyle(
                                      fontSize: TypeScale.footnote,
                                      fontWeight: FontWeight.w800,
                                      color: AppStyles.gold(context),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: Spacing.sm),
                                Expanded(
                                  child: Text(
                                    section.label,
                                    style: TextStyle(
                                      fontSize: TypeScale.callout,
                                      fontWeight: FontWeight.w600,
                                      color:
                                          AppStyles.getTextColor(context),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: Spacing.sm),
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _fmt(total),
                                  style: TextStyle(
                                    fontSize: TypeScale.title3,
                                    fontWeight: FontWeight.w700,
                                    color: isOver
                                        ? AppStyles.gold(context)
                                        : AppStyles.getTextColor(context),
                                  ),
                                ),
                                if (limit != null)
                                  Text(
                                    'Limit: ${_fmt(limit)}',
                                    style: TextStyle(
                                      fontSize: TypeScale.caption,
                                      color: AppStyles
                                          .getSecondaryTextColor(context),
                                    ),
                                  ),
                              ],
                            ),
                            if (progress != null) ...[
                              const SizedBox(height: Spacing.sm),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: progress,
                                  minHeight: 6,
                                  backgroundColor: AppStyles
                                      .getDividerColor(context),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    isOver
                                        ? AppStyles.gold(context)
                                        : AppStyles.gain(context),
                                  ),
                                ),
                              ),
                              const SizedBox(height: Spacing.xs),
                              Text(
                                isOver
                                    ? 'Exceeds limit by ${_fmt(total - limit)}'
                                    : '${_fmt(limit! - total)} remaining',
                                style: TextStyle(
                                  fontSize: TypeScale.caption,
                                  color: isOver
                                      ? AppStyles.gold(context)
                                      : AppStyles.getSecondaryTextColor(
                                          context),
                                ),
                              ),
                            ],
                            const SizedBox(height: Spacing.sm),
                            Text(
                              '${txns.length} transaction${txns.length == 1 ? '' : 's'}',
                              style: TextStyle(
                                fontSize: TypeScale.caption,
                                color: AppStyles.getSecondaryTextColor(context),
                              ),
                            ),
                            const SizedBox(height: Spacing.sm),
                            ...txns.take(3).map((tx) => Padding(
                                  padding: const EdgeInsets.only(
                                      bottom: Spacing.xs),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          tx.description,
                                          maxLines: 1,
                                          overflow:
                                              TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: TypeScale.footnote,
                                            color: AppStyles.getTextColor(
                                                context),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: Spacing.sm),
                                      Text(
                                        _fmt(tx.amount),
                                        style: TextStyle(
                                          fontSize: TypeScale.footnote,
                                          fontWeight: FontWeight.w600,
                                          color: AppStyles.getTextColor(
                                              context),
                                        ),
                                      ),
                                    ],
                                  ),
                                )),
                            if (txns.length > 3)
                              Text(
                                '+ ${txns.length - 3} more',
                                style: TextStyle(
                                  fontSize: TypeScale.caption,
                                  color: AppStyles.getSecondaryTextColor(
                                      context),
                                ),
                              ),
                          ],
                        ),
                      );
                    }),

                  // Capital Gains Overview
                  if (ltcgHoldings.isNotEmpty || stcgHoldings.isNotEmpty) ...[
                    const SizedBox(height: Spacing.lg),
                    _sectionHeader(context, 'CAPITAL GAINS OVERVIEW',
                        CupertinoIcons.chart_bar_alt_fill,
                        AppStyles.teal(context)),
                    const SizedBox(height: Spacing.sm),
                    Container(
                      padding: const EdgeInsets.all(Spacing.md),
                      decoration: BoxDecoration(
                        color: AppStyles.getCardColor(context),
                        borderRadius: BorderRadius.circular(Radii.lg),
                        border: Border.all(color: AppStyles.getDividerColor(context)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _cgPill(context,
                                    label: 'LTCG Eligible',
                                    count: ltcgHoldings.length,
                                    total: ltcgHoldings.fold<double>(0, (s, i) => s + i.amount),
                                    color: AppStyles.gain(context)),
                              ),
                              const SizedBox(width: Spacing.sm),
                              Expanded(
                                child: _cgPill(context,
                                    label: 'STCG / <1 yr',
                                    count: stcgHoldings.length,
                                    total: stcgHoldings.fold<double>(0, (s, i) => s + i.amount),
                                    color: AppStyles.warning(context)),
                              ),
                            ],
                          ),
                          if (ltcgHoldings.isNotEmpty) ...[
                            const SizedBox(height: Spacing.sm),
                            Text('Long-term holdings (>12 months)',
                                style: TextStyle(
                                    fontSize: TypeScale.caption,
                                    color: AppStyles.getSecondaryTextColor(context))),
                            const SizedBox(height: Spacing.xs),
                            ...ltcgHoldings.take(3).map((inv) =>
                                _holdingRow(context, inv, now, isLtcg: true)),
                            if (ltcgHoldings.length > 3)
                              Text('+ ${ltcgHoldings.length - 3} more',
                                  style: TextStyle(
                                      fontSize: TypeScale.caption,
                                      color: AppStyles.getSecondaryTextColor(context))),
                          ],
                          if (stcgHoldings.isNotEmpty) ...[
                            const SizedBox(height: Spacing.sm),
                            Text('Short-term holdings (<12 months)',
                                style: TextStyle(
                                    fontSize: TypeScale.caption,
                                    color: AppStyles.getSecondaryTextColor(context))),
                            const SizedBox(height: Spacing.xs),
                            ...stcgHoldings.take(3).map((inv) =>
                                _holdingRow(context, inv, now, isLtcg: false)),
                          ],
                        ],
                      ),
                    ),
                  ],

                  // 80C Auto-detected from investments
                  if (autoDetected80CTotal > 0) ...[
                    const SizedBox(height: Spacing.lg),
                    _sectionHeader(context, '80C AUTO-DETECTED',
                        CupertinoIcons.rosette, AppStyles.violet(context)),
                    const SizedBox(height: Spacing.sm),
                    Container(
                      padding: const EdgeInsets.all(Spacing.md),
                      decoration: BoxDecoration(
                        color: AppStyles.getCardColor(context),
                        borderRadius: BorderRadius.circular(Radii.lg),
                        border: Border.all(color: AppStyles.getDividerColor(context)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'From NPS / NSS investments',
                            style: TextStyle(
                                fontSize: TypeScale.footnote,
                                color: AppStyles.getSecondaryTextColor(context)),
                          ),
                          const SizedBox(height: Spacing.sm),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_fmt(autoDetected80CTotal),
                                  style: TextStyle(
                                      fontSize: TypeScale.title3,
                                      fontWeight: FontWeight.w700,
                                      color: AppStyles.violet(context))),
                              Text('Limit: ₹1.50L',
                                  style: TextStyle(
                                      fontSize: TypeScale.caption,
                                      color: AppStyles.getSecondaryTextColor(context))),
                            ],
                          ),
                          const SizedBox(height: Spacing.sm),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: (autoDetected80CTotal / 150000).clamp(0.0, 1.0),
                              minHeight: 6,
                              backgroundColor: AppStyles.getDividerColor(context),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  AppStyles.violet(context)),
                            ),
                          ),
                          const SizedBox(height: Spacing.xs),
                          Text(
                            autoDetected80CTotal >= 150000
                                ? 'Limit reached — maximised!'
                                : '${_fmt(150000 - autoDetected80CTotal)} remaining to maximise',
                            style: TextStyle(
                                fontSize: TypeScale.caption,
                                color: AppStyles.getSecondaryTextColor(context)),
                          ),
                        ],
                      ),
                    ),
                  ],
                      ],
                    ), // closes ListView
                  ), // closes Expanded
                ], // closes Column children
              ); // closes Column
            },
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title,
      IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(title,
            style: TextStyle(
                fontSize: TypeScale.caption,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: color)),
      ],
    );
  }

  Widget _cgPill(BuildContext context,
      {required String label,
      required int count,
      required double total,
      required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: Spacing.sm, vertical: Spacing.xs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: TypeScale.micro,
                  fontWeight: FontWeight.w700,
                  color: color)),
          const SizedBox(height: 2),
          Text(_fmt(total),
              style: TextStyle(
                  fontSize: TypeScale.footnote,
                  fontWeight: FontWeight.w700,
                  color: AppStyles.getTextColor(context))),
          Text('$count holding${count == 1 ? '' : 's'}',
              style: TextStyle(
                  fontSize: TypeScale.micro,
                  color: AppStyles.getSecondaryTextColor(context))),
        ],
      ),
    );
  }

  Widget _holdingRow(BuildContext context, Investment inv,
      DateTime now, {required bool isLtcg}) {
    final purchaseDate = _investmentPurchaseDate(inv);
    final months = purchaseDate == null
        ? 0
        : (now.year - purchaseDate.year) * 12 +
            (now.month - purchaseDate.month);
    final label = months >= 12
        ? '${(months / 12).floor()}y ${months % 12}m'
        : '${months}m';
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(inv.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: TypeScale.footnote,
                    color: AppStyles.getTextColor(context))),
          ),
          const SizedBox(width: Spacing.sm),
          Text(_fmt(inv.amount),
              style: TextStyle(
                  fontSize: TypeScale.footnote,
                  fontWeight: FontWeight.w600,
                  color: AppStyles.getTextColor(context))),
          const SizedBox(width: Spacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: (isLtcg ? AppStyles.gain(context) : AppStyles.warning(context))
                  .withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(label,
                style: TextStyle(
                    fontSize: TypeScale.micro,
                    fontWeight: FontWeight.w700,
                    color: isLtcg
                        ? AppStyles.gain(context)
                        : AppStyles.warning(context))),
          ),
        ],
      ),
    );
  }

  /// Extracts the purchase date from an investment's activity log or metadata.
  DateTime? _investmentPurchaseDate(Investment inv) {
    final meta = inv.metadata;
    if (meta == null) return null;
    // Try direct metadata keys first.
    for (final key in ['investmentDate', 'purchaseDate', 'startDate', 'createdAt']) {
      final raw = meta[key];
      if (raw is String && raw.isNotEmpty) {
        final parsed = DateTime.tryParse(raw);
        if (parsed != null) return parsed;
      }
    }
    // Try first 'create' entry in activityLog.
    final log = meta['activityLog'];
    if (log is List && log.isNotEmpty) {
      final createEntry = log.firstWhere(
        (e) => e is Map && (e['type'] as String?)?.toLowerCase() == 'create',
        orElse: () => null,
      );
      if (createEntry != null) {
        final raw = createEntry['date'];
        if (raw is String) return DateTime.tryParse(raw);
      }
    }
    return null;
  }

  Widget _buildLandscapeNavBar(BuildContext context) {
    return Container(
      height: 40,
      color: AppStyles.getBackground(context),
      padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
      child: Row(
        children: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            onPressed: () => Navigator.of(context).maybePop(),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(CupertinoIcons.chevron_left,
                    size: 16, color: AppStyles.getPrimaryColor(context)),
                const SizedBox(width: 2),
                Text('Back',
                    style: TextStyle(
                        fontSize: TypeScale.footnote,
                        color: AppStyles.getPrimaryColor(context))),
              ],
            ),
          ),
          const Spacer(),
          Text('TAX SUMMARY · ${_fYLabel()}',
              style: TextStyle(
                  fontSize: TypeScale.caption,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: AppStyles.getTextColor(context))),
          const Spacer(),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                onPressed: () => setState(() => _fyStartYear--),
                child: Icon(CupertinoIcons.chevron_left,
                    size: 16, color: AppStyles.getPrimaryColor(context)),
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                onPressed: () {
                  final currentFy = _fyFor(DateTime.now()).startYear;
                  if (_fyStartYear < currentFy) setState(() => _fyStartYear++);
                },
                child: Icon(CupertinoIcons.chevron_right,
                    size: 16,
                    color: _fyStartYear < _fyFor(DateTime.now()).startYear
                        ? AppStyles.getPrimaryColor(context)
                        : CupertinoColors.systemGrey),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statBox(BuildContext context,
      {required String label, required String value}) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: TypeScale.title3,
            fontWeight: FontWeight.w700,
            color: AppStyles.gold(context),
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: TypeScale.caption,
            color: AppStyles.getSecondaryTextColor(context),
          ),
        ),
      ],
    );
  }

  String _fmt(double v) {
    if (v >= 100000) {
      return '₹${(v / 100000).toStringAsFixed(2)}L';
    } else if (v >= 1000) {
      return '₹${(v / 1000).toStringAsFixed(1)}K';
    }
    return '₹${v.toStringAsFixed(0)}';
  }
}
