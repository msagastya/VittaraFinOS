import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/account_model.dart';
import 'package:vittara_fin_os/logic/accounts_controller.dart';
import 'package:vittara_fin_os/logic/investments_controller.dart';
import 'package:vittara_fin_os/logic/transaction_model.dart';
import 'package:vittara_fin_os/logic/transactions_controller.dart';
import 'package:vittara_fin_os/ui/dashboard/base_dashboard_widget.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/widgets/animations.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Formatter helper
// ─────────────────────────────────────────────────────────────────────────────

String _nwFmt(double v) {
  final abs = v.abs();
  final sign = v < 0 ? '-' : '';
  if (abs >= 100000) return '$sign₹${(abs / 100000).toStringAsFixed(1)}L';
  if (abs >= 1000) return '$sign₹${(abs / 1000).toStringAsFixed(1)}K';
  return '$sign₹${abs.toStringAsFixed(0)}';
}

// ─────────────────────────────────────────────────────────────────────────────
// Account type helpers
// ─────────────────────────────────────────────────────────────────────────────

Color _accountTypeColor(AccountType type, BuildContext context) {
  switch (type) {
    case AccountType.savings:
    case AccountType.current:
      return AppStyles.teal(context);
    case AccountType.credit:
    case AccountType.payLater:
      return AppStyles.loss(context);
    case AccountType.wallet:
      return AppStyles.accentOrange;
    case AccountType.investment:
      return AppStyles.violet(context);
    case AccountType.cash:
      return AppStyles.gold(context);
  }
}

IconData _accountTypeIcon(AccountType type) {
  switch (type) {
    case AccountType.savings:
    case AccountType.current:
      return CupertinoIcons.building_2_fill;
    case AccountType.credit:
      return CupertinoIcons.creditcard_fill;
    case AccountType.payLater:
      return CupertinoIcons.clock_fill;
    case AccountType.wallet:
      return CupertinoIcons.bag_fill;
    case AccountType.investment:
      return CupertinoIcons.chart_bar_square_fill;
    case AccountType.cash:
      return CupertinoIcons.money_dollar_circle_fill;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Allocation ring custom painter
// ─────────────────────────────────────────────────────────────────────────────

class _AllocationRingPainter extends CustomPainter {
  final double savings;
  final double investments;
  final double debt;
  final double total;
  final Color savingsColor;
  final Color investmentsColor;
  final Color debtColor;

  _AllocationRingPainter({
    required this.savings,
    required this.investments,
    required this.debt,
    required this.total,
    required this.savingsColor,
    required this.investmentsColor,
    required this.debtColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = (math.min(size.width, size.height) / 2) - 6;
    const strokeWidth = 10.0;
    const gapDeg = 2.0;
    const gapRad = gapDeg * math.pi / 180;
    const startAngle = -math.pi / 2; // top

    // Track ring
    final trackPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(Offset(cx, cy), radius, trackPaint);

    if (total <= 0) return;

    // Clamp negative values to 0 for display
    final sSafe = savings.clamp(0, double.infinity).toDouble();
    final iSafe = investments.clamp(0, double.infinity).toDouble();
    final dSafe = debt.clamp(0, double.infinity).toDouble();
    final displayTotal = sSafe + iSafe + dSafe;
    if (displayTotal <= 0) return;

    const fullCircle = 2 * math.pi;
    const totalGaps = 3 * gapRad;
    const usable = fullCircle - totalGaps;

    final sFrac = sSafe / displayTotal;
    final iFrac = iSafe / displayTotal;
    final dFrac = dSafe / displayTotal;

    final sAngle = usable * sFrac;
    final iAngle = usable * iFrac;
    final dAngle = usable * dFrac;

    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: radius);

    void drawArc(double start, double sweep, Color color) {
      if (sweep <= 0) return;
      final paint = Paint()
        ..color = color
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, start, sweep, false, paint);
    }

    // Savings — green
    double cursor = startAngle;
    drawArc(cursor, sAngle, savingsColor);
    cursor += sAngle + gapRad;

    // Investments — teal
    drawArc(cursor, iAngle, investmentsColor);
    cursor += iAngle + gapRad;

    // Debt — red
    drawArc(cursor, dAngle, debtColor);
  }

  @override
  bool shouldRepaint(_AllocationRingPainter old) =>
      old.savings != savings ||
      old.investments != investments ||
      old.debt != debt ||
      old.total != total ||
      old.savingsColor != savingsColor ||
      old.investmentsColor != investmentsColor ||
      old.debtColor != debtColor;
}

// ─────────────────────────────────────────────────────────────────────────────
// Allocation ring widget
// ─────────────────────────────────────────────────────────────────────────────

class _AllocationRing extends StatelessWidget {
  final double savings;
  final double investments;
  final double debt;

  const _AllocationRing({
    required this.savings,
    required this.investments,
    required this.debt,
  });

  @override
  Widget build(BuildContext context) {
    final total = savings + investments + debt;
    return SizedBox(
      width: 60,
      height: 60,
      child: CustomPaint(
        painter: _AllocationRingPainter(
          savings: savings,
          investments: investments,
          debt: debt,
          total: total,
          savingsColor: AppStyles.gain(context),
          investmentsColor: AppStyles.teal(context),
          debtColor: AppStyles.loss(context),
        ),
        child: Center(
          child: Text(
            _nwFmt(savings + investments - debt),
            style: const TextStyle(
              fontSize: 7,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Legend dot
// ─────────────────────────────────────────────────────────────────────────────

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final double value;

  const _LegendItem({
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w600,
                    color: AppStyles.getSecondaryTextColor(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _nwFmt(value),
                  style: TextStyle(
                    fontSize: TypeScale.micro,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Account carousel body (StatefulWidget with Timer)
// ─────────────────────────────────────────────────────────────────────────────

class _NetWorthBody extends StatefulWidget {
  final List<Account> accounts;
  final double totalSavings;
  final double totalInvestments;
  final double totalCreditUsed;
  final double totalNetWorth;
  final double momTrendPct;
  final bool isDark;

  const _NetWorthBody({
    required this.accounts,
    required this.totalSavings,
    required this.totalInvestments,
    required this.totalCreditUsed,
    required this.totalNetWorth,
    required this.momTrendPct,
    required this.isDark,
  });

  @override
  State<_NetWorthBody> createState() => _NetWorthBodyState();
}

class _NetWorthBodyState extends State<_NetWorthBody> {
  int _carouselPage = 0;
  late final PageController _pageCtrl;
  Timer? _carouselTimer;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
    _startCarouselTimer();
  }

  void _startCarouselTimer() {
    _carouselTimer?.cancel();
    if (widget.accounts.length > 1) {
      _carouselTimer = Timer.periodic(const Duration(milliseconds: 2500), (_) {
        if (!mounted) return;
        final next = (_carouselPage + 1) % widget.accounts.length;
        _pageCtrl.animateToPage(
          next,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      });
    }
  }

  @override
  void didUpdateWidget(_NetWorthBody old) {
    super.didUpdateWidget(old);
    if (old.accounts.length != widget.accounts.length) {
      _startCarouselTimer();
    }
  }

  @override
  void dispose() {
    _carouselTimer?.cancel();
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nw = widget.totalNetWorth;
    final nwColor = nw >= 0 ? AppStyles.gain(context) : AppStyles.loss(context);
    final trend = widget.momTrendPct;
    final trendPositive = trend >= 0;
    final trendColor = trendPositive ? AppStyles.gain(context) : AppStyles.loss(context);
    final trendLabel = trendPositive
        ? '+${trend.toStringAsFixed(1)}% this month'
        : '${trend.toStringAsFixed(1)}% this month';

    final allocationTotal =
        widget.totalSavings + widget.totalInvestments + widget.totalCreditUsed;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Section 1: Net worth total + ring ──────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'NET WORTH',
                    style: TextStyle(
                      fontSize: TypeScale.micro,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w700,
                      color: AppStyles.getSecondaryTextColor(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  AnimatedCounter(
                    value: nw,
                    prefix: '₹',
                    decimals: 0,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: nwColor,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 3),
                  // Trend chip
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: Spacing.sm, vertical: 2),
                    decoration: BoxDecoration(
                      color: trendColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(Radii.full),
                      border: Border.all(
                        color: trendColor.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      trendLabel,
                      style: TextStyle(
                        fontSize: TypeScale.micro,
                        fontWeight: FontWeight.w700,
                        color: trendColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Spacing.sm),
            _AllocationRing(
              savings: widget.totalSavings,
              investments: widget.totalInvestments,
              debt: widget.totalCreditUsed,
            ),
          ],
        ),

        const SizedBox(height: Spacing.sm),

        // ── Section 2: Allocation bar ──────────────────────────────────────
        if (allocationTotal > 0) ...[
          // Segmented bar
          ClipRRect(
            borderRadius: BorderRadius.circular(Radii.full),
            child: SizedBox(
              height: 6,
              child: Row(
                children: [
                  if (widget.totalSavings > 0)
                    Flexible(
                      flex: (widget.totalSavings / allocationTotal * 1000)
                          .round(),
                      child: Container(color: AppStyles.gain(context)),
                    ),
                  if (widget.totalInvestments > 0)
                    Flexible(
                      flex: (widget.totalInvestments / allocationTotal * 1000)
                          .round(),
                      child: Container(color: AppStyles.teal(context)),
                    ),
                  if (widget.totalCreditUsed > 0)
                    Flexible(
                      flex: (widget.totalCreditUsed / allocationTotal * 1000)
                          .round(),
                      child: Container(color: AppStyles.loss(context)),
                    ),
                  // Ensure at least a tiny sliver visible when all are 0
                  if (widget.totalSavings <= 0 &&
                      widget.totalInvestments <= 0 &&
                      widget.totalCreditUsed <= 0)
                    Expanded(
                      child: Container(
                        color: widget.isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.06),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          // Legend row
          Row(
            children: [
              _LegendItem(
                color: AppStyles.gain(context),
                label: 'Savings',
                value: widget.totalSavings,
              ),
              _LegendItem(
                color: AppStyles.teal(context),
                label: 'Investments',
                value: widget.totalInvestments,
              ),
              _LegendItem(
                color: AppStyles.loss(context),
                label: 'Debt',
                value: widget.totalCreditUsed,
              ),
            ],
          ),
        ],

        const SizedBox(height: Spacing.sm),
        const Divider(height: 1),
        const SizedBox(height: Spacing.xs),

        // ── Section 3: Account Carousel ────────────────────────────────────
        if (widget.accounts.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
            child: Text(
              'No accounts yet',
              style: TextStyle(
                fontSize: TypeScale.caption,
                color: AppStyles.getSecondaryTextColor(context),
              ),
            ),
          )
        else ...[
          SizedBox(
            height: 56,
            child: PageView.builder(
              controller: _pageCtrl,
              itemCount: widget.accounts.length,
              onPageChanged: (i) => setState(() => _carouselPage = i),
              itemBuilder: (_, i) {
                final account = widget.accounts[i];
                final color = _accountTypeColor(account.type, context);
                final icon = _accountTypeIcon(account.type);
                final isDebt = account.type == AccountType.credit ||
                    account.type == AccountType.payLater;
                return Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color.withValues(alpha: 0.15),
                        border: Border.all(
                          color: color.withValues(alpha: 0.35),
                          width: 1,
                        ),
                      ),
                      child: Icon(icon, size: 16, color: color),
                    ),
                    const SizedBox(width: Spacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            account.name,
                            style: TextStyle(
                              fontSize: TypeScale.caption,
                              fontWeight: FontWeight.w600,
                              color: AppStyles.getTextColor(context),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            account.bankName,
                            style: TextStyle(
                              fontSize: TypeScale.micro,
                              color: AppStyles.getSecondaryTextColor(context),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    AnimatedCounter(
                      value: isDebt
                          ? (account.creditLimit ?? 0) - account.balance
                          : account.balance,
                      prefix: '₹',
                      decimals: 0,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          // Dot indicators
          if (widget.accounts.length > 1) ...[
            const SizedBox(height: Spacing.xs),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.accounts.length, (i) {
                final active = i == _carouselPage;
                final color =
                    _accountTypeColor(widget.accounts[i].type, context);
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 2.5),
                  width: active ? 18 : 5,
                  height: 3,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(Radii.full),
                    color: active
                        ? color
                        : color.withValues(alpha: 0.25),
                  ),
                );
              }),
            ),
          ],
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Net Worth Widget
// ─────────────────────────────────────────────────────────────────────────────

class NetWorthWidget extends BaseDashboardWidget {
  const NetWorthWidget({
    required super.config,
    super.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) => buildContent(
        context,
        columnSpan: config.columnSpan,
        rowSpan: config.rowSpan,
        width: double.infinity,
        height: double.infinity,
      );

  @override
  Widget buildContent(
    BuildContext context, {
    required int columnSpan,
    required int rowSpan,
    required double width,
    required double height,
  }) {
    return RepaintBoundary(
      child: Consumer3<AccountsController, InvestmentsController,
          TransactionsController>(
        builder: (context, accCtrl, invCtrl, txCtrl, _) {
          final accounts = accCtrl.accounts;
          final investments = invCtrl.investments;
          final transactions = txCtrl.transactions;
          final isDark = Theme.of(context).brightness == Brightness.dark;

          // ── Compute totals ────────────────────────────────────────────────
          double totalSavings = 0;
          double totalCreditUsed = 0;

          for (final acc in accounts) {
            if (acc.isHidden) continue;
            if (acc.type == AccountType.credit ||
                acc.type == AccountType.payLater) {
              // Credit used = limit - available balance
              totalCreditUsed +=
                  ((acc.creditLimit ?? 0) - acc.balance).clamp(0, double.infinity);
            } else {
              totalSavings += acc.balance;
            }
          }

          double totalInvestments = 0;
          for (final inv in investments) {
            final cv = inv.metadata?['currentValue'];
            if (cv is num) {
              totalInvestments += cv.toDouble();
            } else {
              totalInvestments += inv.amount;
            }
          }

          final totalNetWorth = totalSavings + totalInvestments - totalCreditUsed;

          // ── MoM trend calculation ─────────────────────────────────────────
          // Approximate: compare this month's net cash flow vs net worth
          final now = DateTime.now();
          final monthStart = DateTime(now.year, now.month, 1);
          final prevMonthStart = DateTime(now.year, now.month - 1, 1);

          double incomeThisMonth = 0;
          double expensesThisMonth = 0;
          double incomeLastMonth = 0;
          double expensesLastMonth = 0;

          for (final tx in transactions) {
            final isThisMonth = !tx.dateTime.isBefore(monthStart);
            final isLastMonth = !tx.dateTime.isBefore(prevMonthStart) &&
                tx.dateTime.isBefore(monthStart);

            if (tx.type == TransactionType.income) {
              if (isThisMonth) incomeThisMonth += tx.amount.abs();
              if (isLastMonth) incomeLastMonth += tx.amount.abs();
            } else if (tx.type == TransactionType.expense) {
              if (isThisMonth) expensesThisMonth += tx.amount.abs();
              if (isLastMonth) expensesLastMonth += tx.amount.abs();
            }
          }

          final netThis = incomeThisMonth - expensesThisMonth;
          final netLast = incomeLastMonth - expensesLastMonth;

          double momTrendPct = 0;
          if (totalNetWorth.abs() > 0) {
            momTrendPct = (netThis - netLast) / totalNetWorth.abs() * 100;
          }

          // ── All accounts combined for carousel (excluding hidden) ─────────
          final visibleAccounts =
              accounts.where((a) => !a.isHidden).toList();

          // ── Empty state ───────────────────────────────────────────────────
          if (visibleAccounts.isEmpty && investments.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    CupertinoIcons.creditcard,
                    size: 32,
                    color: AppStyles.getSecondaryTextColor(context)
                        .withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: Spacing.sm),
                  Text(
                    'No accounts yet',
                    style: TextStyle(
                      fontSize: TypeScale.footnote,
                      color: AppStyles.getSecondaryTextColor(context),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Add accounts to track your net worth',
                    style: TextStyle(
                      fontSize: TypeScale.caption,
                      color: AppStyles.getSecondaryTextColor(context)
                          .withValues(alpha: 0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: _NetWorthBody(
              accounts: visibleAccounts,
              totalSavings: totalSavings,
              totalInvestments: totalInvestments,
              totalCreditUsed: totalCreditUsed,
              totalNetWorth: totalNetWorth,
              momTrendPct: momTrendPct,
              isDark: isDark,
            ),
          );
        },
      ),
    );
  }
}
