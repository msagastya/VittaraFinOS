import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/transaction_model.dart';
import 'package:vittara_fin_os/logic/transactions_controller.dart';
import 'package:vittara_fin_os/ui/dashboard/base_dashboard_widget.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';

// ---------------------------------------------------------------------------
// Data models for insight cards
// ---------------------------------------------------------------------------

class _InsightCard {
  final IconData icon;
  final String title;
  final String value;
  final String? comparison;
  final Color color;

  const _InsightCard({
    required this.icon,
    required this.title,
    required this.value,
    this.comparison,
    required this.color,
  });
}

// ---------------------------------------------------------------------------
// Compute insights from transactions
// ---------------------------------------------------------------------------

List<_InsightCard> _computeInsights(
    List<Transaction> transactions, BuildContext context) {
  final now = DateTime.now();
  final startOfMonth = DateTime(now.year, now.month, 1);
  final startOfLastMonth =
      DateTime(now.year, now.month - 1 < 1 ? now.year - 1 : now.year,
          now.month - 1 < 1 ? 12 : now.month - 1, 1);
  final endOfLastMonth = startOfMonth.subtract(const Duration(microseconds: 1));

  final thisMonth = transactions
      .where((t) =>
          t.type == TransactionType.expense &&
          !t.dateTime.isBefore(startOfMonth))
      .toList();

  final lastMonth = transactions
      .where((t) =>
          t.type == TransactionType.expense &&
          !t.dateTime.isBefore(startOfLastMonth) &&
          !t.dateTime.isAfter(endOfLastMonth))
      .toList();

  final cards = <_InsightCard>[];

  // 1. Top category this month
  final categoryTotals = <String, double>{};
  for (final t in thisMonth) {
    final cat = (t.metadata?['categoryName'] as String?) ?? 'Other';
    categoryTotals[cat] = (categoryTotals[cat] ?? 0) + t.amount.abs();
  }
  if (categoryTotals.isNotEmpty) {
    final topEntry = categoryTotals.entries
        .reduce((a, b) => a.value > b.value ? a : b);
    cards.add(_InsightCard(
      icon: CupertinoIcons.tag_fill,
      title: 'Top category this month',
      value: topEntry.key,
      comparison:
          '₹${topEntry.value >= 1000 ? '${(topEntry.value / 1000).toStringAsFixed(1)}K' : topEntry.value.toStringAsFixed(0)}',
      color: AppStyles.aetherTeal,
    ));
  }

  // 2. vs last month
  final thisTotal = thisMonth.fold(0.0, (s, t) => s + t.amount.abs());
  final lastTotal = lastMonth.fold(0.0, (s, t) => s + t.amount.abs());
  if (lastTotal > 0) {
    final pctChange = ((thisTotal - lastTotal) / lastTotal) * 100;
    final isUp = pctChange >= 0;
    cards.add(_InsightCard(
      icon: isUp ? CupertinoIcons.arrow_up_circle_fill : CupertinoIcons.arrow_down_circle_fill,
      title: 'vs last month',
      value:
          '₹${thisTotal >= 1000 ? '${(thisTotal / 1000).toStringAsFixed(1)}K' : thisTotal.toStringAsFixed(0)}',
      comparison:
          '${isUp ? '+' : ''}${pctChange.toStringAsFixed(1)}% vs ₹${lastTotal >= 1000 ? '${(lastTotal / 1000).toStringAsFixed(1)}K' : lastTotal.toStringAsFixed(0)}',
      color: isUp ? SemanticColors.error : SemanticColors.success,
    ));
  }

  // 3. Biggest transaction this month
  if (thisMonth.isNotEmpty) {
    final biggest = thisMonth.reduce(
        (a, b) => a.amount.abs() > b.amount.abs() ? a : b);
    final merchant =
        (biggest.metadata?['merchant'] as String?) ?? biggest.description;
    cards.add(_InsightCard(
      icon: CupertinoIcons.bolt_fill,
      title: 'Biggest transaction',
      value:
          '₹${biggest.amount.abs() >= 1000 ? '${(biggest.amount.abs() / 1000).toStringAsFixed(1)}K' : biggest.amount.abs().toStringAsFixed(0)}',
      comparison: merchant,
      color: SemanticColors.warning,
    ));
  }

  // 4. Savings rate
  final incomeThisMonth = transactions
      .where((t) =>
          t.type == TransactionType.income &&
          !t.dateTime.isBefore(startOfMonth))
      .fold(0.0, (s, t) => s + t.amount.abs());
  if (incomeThisMonth > 0) {
    final savings = incomeThisMonth - thisTotal;
    final rate = (savings / incomeThisMonth) * 100;
    cards.add(_InsightCard(
      icon: CupertinoIcons.checkmark_seal_fill,
      title: 'Savings rate',
      value: '${rate.clamp(0, 100).toStringAsFixed(1)}%',
      comparison:
          '₹${savings >= 1000 ? '${(savings / 1000).toStringAsFixed(1)}K' : savings.toStringAsFixed(0)} saved of ₹${incomeThisMonth >= 1000 ? '${(incomeThisMonth / 1000).toStringAsFixed(1)}K' : incomeThisMonth.toStringAsFixed(0)}',
      color: rate >= 20 ? SemanticColors.success : SemanticColors.warning,
    ));
  }

  if (cards.isEmpty) {
    cards.add(_InsightCard(
      icon: CupertinoIcons.lightbulb_fill,
      title: 'No insights yet',
      value: 'Add transactions',
      comparison: 'to see spending insights',
      color: AppStyles.aetherTeal,
    ));
  }

  return cards;
}

// ---------------------------------------------------------------------------
// Widget
// ---------------------------------------------------------------------------

class InsightsWidget extends BaseDashboardWidget {
  const InsightsWidget({
    required super.config,
    super.onTap,
    super.key,
  });

  @override
  Widget buildContent(
    BuildContext context, {
    required int columnSpan,
    required int rowSpan,
    required double width,
    required double height,
  }) {
    return Consumer<TransactionsController>(
      builder: (context, txController, _) {
        final cards = _computeInsights(txController.transactions, context);
        return _InsightsPageView(cards: cards, compact: columnSpan == 1);
      },
    );
  }
}

class _InsightsPageView extends StatefulWidget {
  final List<_InsightCard> cards;
  final bool compact;

  const _InsightsPageView({required this.cards, required this.compact});

  @override
  State<_InsightsPageView> createState() => _InsightsPageViewState();
}

class _InsightsPageViewState extends State<_InsightsPageView> {
  int _currentPage = 0;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.cards.length,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemBuilder: (context, index) {
              return _InsightCardTile(
                card: widget.cards[index],
                compact: widget.compact,
              );
            },
          ),
        ),
        if (widget.cards.length > 1) ...[
          const SizedBox(height: Spacing.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.cards.length, (i) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: _currentPage == i ? 16 : 6,
                height: 4,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: _currentPage == i
                      ? AppStyles.aetherTeal
                      : AppStyles.getSecondaryTextColor(context)
                          .withValues(alpha: 0.3),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}

class _InsightCardTile extends StatelessWidget {
  final _InsightCard card;
  final bool compact;

  const _InsightCardTile({required this.card, required this.compact});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: Spacing.sm,
        vertical: compact ? Spacing.xs : Spacing.sm,
      ),
      child: Row(
        children: [
          Container(
            width: compact ? 36 : 44,
            height: compact ? 36 : 44,
            decoration: BoxDecoration(
              color: card.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(Radii.md),
            ),
            child: Icon(
              card.icon,
              size: compact ? 18 : 22,
              color: card.color,
            ),
          ),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  card.title,
                  style: TextStyle(
                    fontSize: compact ? TypeScale.caption : TypeScale.footnote,
                    color: AppStyles.getSecondaryTextColor(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  card.value,
                  style: TextStyle(
                    fontSize: compact ? TypeScale.footnote : TypeScale.body,
                    fontWeight: FontWeight.w700,
                    color: AppStyles.getTextColor(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (card.comparison != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    card.comparison!,
                    style: TextStyle(
                      fontSize: TypeScale.caption,
                      color: AppStyles.getSecondaryTextColor(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
