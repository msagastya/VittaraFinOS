import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
          child: Consumer<TransactionsController>(
            builder: (context, txController, _) {
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

              return ListView(
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
                ],
              );
            },
          ),
        ),
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
