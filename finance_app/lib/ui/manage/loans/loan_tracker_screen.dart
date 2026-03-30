import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/loan_controller.dart';
import 'package:vittara_fin_os/logic/loan_model.dart';
import 'package:vittara_fin_os/ui/manage/loans/loan_wizard.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/widgets/animations.dart';
import 'package:vittara_fin_os/ui/widgets/common_widgets.dart';
import 'package:vittara_fin_os/ui/widgets/toast_notification.dart';
import 'package:vittara_fin_os/utils/date_formatter.dart';
import 'package:vittara_fin_os/ui/widgets/animated_counter.dart' as counter_widgets;

class LoanTrackerScreen extends StatefulWidget {
  const LoanTrackerScreen({super.key});

  @override
  State<LoanTrackerScreen> createState() => _LoanTrackerScreenState();
}

class _LoanTrackerScreenState extends State<LoanTrackerScreen> {
  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppStyles.getBackground(context),
      navigationBar: AppStyles.isLandscape(context) ? null : CupertinoNavigationBar(
        middle: Text(
          'Loan / EMI Tracker',
          style: TextStyle(color: AppStyles.getTextColor(context)),
        ),
        previousPageTitle: 'Back',
        backgroundColor: AppStyles.isDarkMode(context)
            ? Colors.black
            : Colors.white.withValues(alpha: 0.95),
        border: null,
      ),
      child: Consumer<LoanController>(
        builder: (context, controller, _) {
          final active = controller.activeLoans;
          return Stack(
            children: [
              SafeArea(
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    if (AppStyles.isLandscape(context))
                      SliverToBoxAdapter(
                        child: _buildLandscapeNavBar(context),
                      ),
                    SliverToBoxAdapter(
                      child: _buildSummaryCard(context, controller),
                    ),
                    if (active.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _buildEmptyState(context),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(
                          Spacing.lg,
                          0,
                          Spacing.lg,
                          Spacing.massive,
                        ),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => Padding(
                              padding: const EdgeInsets.only(bottom: Spacing.md),
                              child: _LoanCard(
                                loan: active[index],
                                onTap: () => _showLoanDetailSheet(context, active[index]),
                                onDelete: () => _confirmDelete(context, controller, active[index]),
                              ),
                            ),
                            childCount: active.length,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Positioned(
                right: Spacing.lg,
                bottom: Spacing.xxl + MediaQuery.of(context).padding.bottom,
                child: FadingFAB(
                  onPressed: () => _openAddLoan(context),
                  color: AppStyles.loss(context),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, LoanController controller) {
    final outstanding = controller.totalOutstanding;
    final emi = controller.monthlyEMITotal;
    final isDark = AppStyles.isDarkMode(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.lg, Spacing.lg, Spacing.lg),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    const Color(0xFF1A0010),
                    const Color(0xFF0D0007),
                  ]
                : [
                    AppStyles.loss(context).withValues(alpha: 0.08),
                    AppStyles.loss(context).withValues(alpha: 0.03),
                  ],
          ),
          borderRadius: BorderRadius.circular(Radii.xxl),
          border: Border.all(
            color: AppStyles.loss(context).withValues(alpha: isDark ? 0.25 : 0.15),
            width: 1,
          ),
          boxShadow: isDark
              ? [
                  BoxShadow(
                    color: AppStyles.plasmaRed.withValues(alpha: 0.08),
                    blurRadius: 24,
                    spreadRadius: -4,
                  ),
                ]
              : [],
        ),
        padding: const EdgeInsets.all(Spacing.xl),
        child: Row(
          children: [
            Expanded(
              child: _SummaryMetric(
                label: 'Total Outstanding',
                numericValue: outstanding,
                color: AppStyles.loss(context),
              ),
            ),
            Container(
              width: 1,
              height: 44,
              color: AppStyles.loss(context).withValues(alpha: 0.2),
            ),
            Expanded(
              child: _SummaryMetric(
                label: 'Monthly EMI',
                numericValue: emi,
                color: AppStyles.teal(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.money_dollar_circle,
              size: 64,
              color: AppStyles.getSecondaryTextColor(context),
            ),
            const SizedBox(height: Spacing.lg),
            Text(
              'No loans tracked',
              style: TextStyle(
                fontSize: TypeScale.title3,
                fontWeight: FontWeight.w600,
                color: AppStyles.getTextColor(context),
              ),
            ),
            const SizedBox(height: Spacing.sm),
            Text(
              'Track your home loan, car loan, personal loan EMIs in one place.',
              style: TextStyle(
                fontSize: TypeScale.body,
                color: AppStyles.getSecondaryTextColor(context),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Spacing.xxl),
            BouncyButton(
              onPressed: () => _openAddLoan(context),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.xxl,
                  vertical: Spacing.md,
                ),
                decoration: BoxDecoration(
                  color: AppStyles.loss(context),
                  borderRadius: BorderRadius.circular(Radii.full),
                  boxShadow: Shadows.fab(AppStyles.plasmaRed),
                ),
                child: const Text(
                  'Add First Loan',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLoanDetailSheet(BuildContext context, Loan loan) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        minChildSize: 0.45,
        maxChildSize: 0.95,
        builder: (sheetCtx, scrollCtrl) => Container(
          decoration: AppStyles.bottomSheetDecoration(sheetCtx),
          child: _LoanDetailSheet(
            loan: loan,
            scrollController: scrollCtrl,
            onEdit: () {
              Navigator.of(ctx).pop();
              _openEditLoan(context, loan);
            },
          ),
        ),
      ),
    );
  }

  Future<void> _openAddLoan(BuildContext context) async {
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => LoanWizard(
          onSave: (loan) {
            context.read<LoanController>().addLoan(loan);
            toast.showSuccess('Loan added');
          },
        ),
      ),
    );
  }

  Future<void> _openEditLoan(BuildContext context, Loan loan) async {
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => LoanWizard(
          existingLoan: loan,
          onSave: (updated) {
            context.read<LoanController>().updateLoan(updated);
            toast.showSuccess('Loan updated');
          },
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    LoanController controller,
    Loan loan,
  ) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Delete Loan'),
        content: Text('Remove "${loan.name}" from your tracker?'),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await controller.deleteLoan(loan.id);
      toast.showSuccess('Loan removed');
    }
  }

  Widget _buildLandscapeNavBar(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
      child: Row(
        children: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            onPressed: () => Navigator.maybePop(context),
            child: Icon(CupertinoIcons.chevron_left, size: 20,
                color: AppStyles.getPrimaryColor(context)),
          ),
          const SizedBox(width: 8),
          Text('LOAN / EMI TRACKER',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                  color: AppStyles.getTextColor(context), letterSpacing: 1.1)),
        ],
      ),
    );
  }
}

// ─── Summary Metric ──────────────────────────────────────────────────────────

class _SummaryMetric extends StatelessWidget {
  final String label;
  final double numericValue;
  final Color color;

  const _SummaryMetric({
    required this.label,
    required this.numericValue,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: TypeScale.caption,
            color: AppStyles.getSecondaryTextColor(context),
            letterSpacing: 0.3,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: Spacing.xs),
        counter_widgets.CurrencyCounter(
          value: numericValue,
          textStyle: TextStyle(
            fontSize: TypeScale.title3,
            fontWeight: FontWeight.w800,
            color: color,
            letterSpacing: -0.5,
          ),
          decimalPlaces: 0,
        ),
      ],
    );
  }
}

// ─── Loan Card ───────────────────────────────────────────────────────────────

class _LoanCard extends StatelessWidget {
  final Loan loan;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _LoanCard({
    required this.loan,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppStyles.isDarkMode(context);
    final dueColor = loan.isOverdue
        ? AppStyles.loss(context)
        : loan.isDueSoon
            ? AppStyles.accentOrange
            : AppStyles.getSecondaryTextColor(context);

    return GestureDetector(
      onLongPress: () => _showActions(context),
      child: BouncyButton(
      onPressed: onTap,
      child: Container(
        decoration: AppStyles.cardDecoration(context),
        padding: const EdgeInsets.all(Spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                _LoanTypeIcon(type: loan.type),
                const SizedBox(width: Spacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        loan.name,
                        style: AppStyles.titleStyle(context),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (loan.bankName != null) ...[
                        const SizedBox(height: Spacing.xxs),
                        Text(
                          loan.bankName!,
                          style: TextStyle(
                            fontSize: TypeScale.caption,
                            color: AppStyles.getSecondaryTextColor(context),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      CurrencyFormatter.compact(loan.currentOutstanding),
                      style: TextStyle(
                        fontSize: TypeScale.body,
                        fontWeight: FontWeight.w800,
                        color: AppStyles.loss(context),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: Spacing.xxs),
                    Text(
                      'outstanding',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppStyles.getSecondaryTextColor(context),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: Spacing.md),
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(Radii.full),
              child: LinearProgressIndicator(
                value: loan.progressPercent,
                minHeight: 6,
                backgroundColor: isDark
                    ? const Color(0xFF1C1C1C)
                    : AppStyles.loss(context).withValues(alpha: 0.12),
                valueColor: AlwaysStoppedAnimation<Color>(
                  loan.progressPercent >= 0.8
                      ? AppStyles.gain(context)
                      : AppStyles.teal(context),
                ),
              ),
            ),
            const SizedBox(height: Spacing.xs),
            Row(
              children: [
                Text(
                  '${(loan.progressPercent * 100).toStringAsFixed(0)}% paid off',
                  style: TextStyle(
                    fontSize: TypeScale.caption,
                    color: AppStyles.getSecondaryTextColor(context),
                  ),
                ),
                const Spacer(),
                Text(
                  '${loan.remainingMonths} months left',
                  style: TextStyle(
                    fontSize: TypeScale.caption,
                    color: AppStyles.getSecondaryTextColor(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Spacing.md),
            // EMI + Due Date row
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.md,
                vertical: Spacing.sm,
              ),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF0A0A0A)
                    : AppStyles.getBackground(context).withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(Radii.md),
              ),
              child: Row(
                children: [
                  Icon(
                    CupertinoIcons.calendar_circle_fill,
                    size: 14,
                    color: dueColor,
                  ),
                  const SizedBox(width: Spacing.xs),
                  Expanded(
                    child: Text(
                      loan.isOverdue
                          ? 'Overdue — ${DateFormatter.format(loan.nextDueDate)}'
                          : loan.isDueSoon
                              ? 'Due soon — ${DateFormatter.format(loan.nextDueDate)}'
                              : 'Next EMI: ${DateFormatter.format(loan.nextDueDate)}',
                      style: TextStyle(
                        fontSize: TypeScale.caption,
                        color: dueColor,
                        fontWeight: loan.isOverdue || loan.isDueSoon
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                  Text(
                    CurrencyFormatter.format(loan.emiAmount, decimals: 0),
                    style: TextStyle(
                      fontSize: TypeScale.caption,
                      fontWeight: FontWeight.w700,
                      color: AppStyles.teal(context),
                    ),
                  ),
                  Text(
                    '/mo',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppStyles.getSecondaryTextColor(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Future<void> _showActions(BuildContext context) async {
    HapticFeedback.mediumImpact();
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(loan.name),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              onTap();
            },
            child: const Text('Edit Loan'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.of(ctx).pop();
              onDelete();
            },
            child: const Text('Delete Loan'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
  }
}

// ─── Loan Type Icon ───────────────────────────────────────────────────────────

class _LoanTypeIcon extends StatelessWidget {
  final LoanType type;

  const _LoanTypeIcon({required this.type});

  IconData get _icon {
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

  Color _colorFor(BuildContext context) {
    switch (type) {
      case LoanType.home:
        return AppStyles.teal(context);
      case LoanType.car:
        return AppStyles.accentBlue;
      case LoanType.personal:
        return AppStyles.violet(context);
      case LoanType.education:
        return AppStyles.gold(context);
      case LoanType.gold:
        return AppStyles.gold(context);
      case LoanType.creditCard:
        return AppStyles.loss(context);
      case LoanType.other:
        return AppStyles.accentOrange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(context);
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(Radii.lg),
        boxShadow: Shadows.iconGlow(color),
      ),
      child: Icon(_icon, color: color, size: 20),
    );
  }
}


// ─── Loan Detail Sheet ───────────────────────────────────────────────────────

class _LoanDetailSheet extends StatefulWidget {
  final Loan loan;
  final ScrollController scrollController;
  final VoidCallback onEdit;

  const _LoanDetailSheet({
    required this.loan,
    required this.scrollController,
    required this.onEdit,
  });

  @override
  State<_LoanDetailSheet> createState() => _LoanDetailSheetState();
}

class _LoanDetailSheetState extends State<_LoanDetailSheet> {
  final TextEditingController _prepayCtrl = TextEditingController();
  double? _prepayAmount;
  bool _showFullSchedule = false;

  @override
  void dispose() {
    _prepayCtrl.dispose();
    super.dispose();
  }

  List<({int month, double principal, double interest, double balance})> _buildSchedule() {
    final monthlyRate = widget.loan.interestRate / 12 / 100;
    double balance = widget.loan.currentOutstanding;
    final emi = widget.loan.emiAmount;
    final rows = <({int month, double principal, double interest, double balance})>[];
    final maxRows = _showFullSchedule ? 360 : 12;
    for (int i = 1; balance > 0.01 && i <= maxRows; i++) {
      final interest = balance * monthlyRate;
      var principal = emi - interest;
      if (principal > balance) principal = balance;
      balance = (balance - principal).clamp(0.0, double.infinity);
      rows.add((month: i, principal: principal, interest: interest, balance: balance));
    }
    return rows;
  }

  ({int savedMonths, double savedInterest})? _computePrepaymentSavings() {
    if (_prepayAmount == null || _prepayAmount! <= 0) return null;
    final monthlyRate = widget.loan.interestRate / 12 / 100;
    final emi = widget.loan.emiAmount;
    if (emi <= 0 || monthlyRate <= 0) return null;

    int computeMonths(double startBalance) {
      double b = startBalance;
      int m = 0;
      while (b > 0.01 && m < 600) {
        final interest = b * monthlyRate;
        var principal = emi - interest;
        if (principal <= 0) break;
        if (principal > b) principal = b;
        b -= principal;
        m++;
      }
      return m;
    }

    double computeTotalInterest(double startBalance) {
      double b = startBalance;
      double total = 0;
      int m = 0;
      while (b > 0.01 && m < 600) {
        final interest = b * monthlyRate;
        var principal = emi - interest;
        if (principal <= 0) break;
        if (principal > b) principal = b;
        total += interest;
        b -= principal;
        m++;
      }
      return total;
    }

    final m1 = computeMonths(widget.loan.currentOutstanding);
    final m2 = computeMonths((widget.loan.currentOutstanding - _prepayAmount!).clamp(0.0, widget.loan.currentOutstanding));
    final i1 = computeTotalInterest(widget.loan.currentOutstanding);
    final i2 = computeTotalInterest((widget.loan.currentOutstanding - _prepayAmount!).clamp(0.0, widget.loan.currentOutstanding));
    return (savedMonths: m1 - m2, savedInterest: i1 - i2);
  }

  @override
  Widget build(BuildContext context) {
    final loan = widget.loan;
    final isDark = AppStyles.isDarkMode(context);
    final accentColor = AppStyles.loss(context);
    final schedule = _buildSchedule();
    final savings = _computePrepaymentSavings();

    return SingleChildScrollView(
      controller: widget.scrollController,
      padding: const EdgeInsets.fromLTRB(Spacing.lg, 0, Spacing.lg, Spacing.xxxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ModalHandle(),
          // Header
          Row(
            children: [
              _LoanTypeIcon(type: loan.type),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(loan.name,
                        style: TextStyle(fontSize: TypeScale.title3,
                            fontWeight: FontWeight.w800,
                            color: AppStyles.getTextColor(context))),
                    if (loan.bankName != null)
                      Text(loan.bankName!,
                          style: TextStyle(fontSize: TypeScale.footnote,
                              color: AppStyles.getSecondaryTextColor(context))),
                  ],
                ),
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: widget.onEdit,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppStyles.getPrimaryColor(context).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('Edit',
                      style: TextStyle(fontSize: TypeScale.footnote,
                          fontWeight: FontWeight.w700,
                          color: AppStyles.getPrimaryColor(context))),
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.lg),

          // Key metrics grid
          Container(
            padding: const EdgeInsets.all(Spacing.md),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: isDark ? 0.06 : 0.04),
              borderRadius: BorderRadius.circular(Radii.xl),
              border: Border.all(color: accentColor.withValues(alpha: 0.15)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    _metricCell('Outstanding', '₹${loan.currentOutstanding.toStringAsFixed(0)}', accentColor),
                    _metricCell('Monthly EMI', '₹${loan.emiAmount.toStringAsFixed(0)}', AppStyles.teal(context)),
                  ],
                ),
                const SizedBox(height: Spacing.sm),
                Row(
                  children: [
                    _metricCell('Interest Rate', '${loan.interestRate.toStringAsFixed(2)}% p.a.', AppStyles.warning(context)),
                    _metricCell('Total Interest', '₹${loan.totalInterestPayable.toStringAsFixed(0)}', AppStyles.getSecondaryTextColor(context)),
                  ],
                ),
                const SizedBox(height: Spacing.sm),
                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(Radii.full),
                  child: Stack(children: [
                    Container(height: 6, color: AppStyles.getDividerColor(context)),
                    FractionallySizedBox(
                      widthFactor: loan.progressPercent,
                      child: Container(
                        height: 6,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [accentColor.withValues(alpha: 0.6), accentColor]),
                          borderRadius: BorderRadius.circular(Radii.full),
                        ),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 4),
                Row(children: [
                  Text('${(loan.progressPercent * 100).toStringAsFixed(0)}% paid',
                      style: TextStyle(fontSize: TypeScale.caption,
                          color: AppStyles.gain(context), fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Text('₹${loan.totalPaid.toStringAsFixed(0)} paid',
                      style: TextStyle(fontSize: TypeScale.caption,
                          color: AppStyles.getSecondaryTextColor(context))),
                ]),
              ],
            ),
          ),

          const SizedBox(height: Spacing.lg),

          // Prepayment Calculator
          _bloombergSectionHeader('PREPAYMENT CALCULATOR', CupertinoIcons.money_dollar_circle, AppStyles.teal(context)),
          const SizedBox(height: Spacing.sm),
          CupertinoTextField(
            controller: _prepayCtrl,
            placeholder: 'Enter extra amount (₹)',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            prefix: const Padding(
                padding: EdgeInsets.only(left: 12),
                child: Text('₹', style: TextStyle(fontWeight: FontWeight.w700))),
            style: TextStyle(color: AppStyles.getTextColor(context), fontWeight: FontWeight.w700),
            decoration: BoxDecoration(
              color: AppStyles.getCardColor(context),
              borderRadius: BorderRadius.circular(Radii.lg),
              border: Border.all(color: AppStyles.getDividerColor(context)),
            ),
            onChanged: (v) => setState(() => _prepayAmount = double.tryParse(v)),
          ),
          if (savings != null && savings.savedMonths > 0) ...[
            const SizedBox(height: Spacing.sm),
            Container(
              padding: const EdgeInsets.all(Spacing.md),
              decoration: BoxDecoration(
                color: AppStyles.teal(context).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(Radii.lg),
                border: Border.all(color: AppStyles.teal(context).withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  Icon(CupertinoIcons.checkmark_circle_fill,
                      size: 16, color: AppStyles.teal(context)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Save ${savings.savedMonths} month${savings.savedMonths == 1 ? '' : 's'} · '
                      '₹${savings.savedInterest.toStringAsFixed(0)} interest saved',
                      style: TextStyle(fontSize: TypeScale.footnote,
                          fontWeight: FontWeight.w700,
                          color: AppStyles.teal(context)),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (savings != null && savings.savedMonths == 0) ...[
            const SizedBox(height: Spacing.sm),
            Text('Loan fully paid off with this prepayment.',
                style: TextStyle(fontSize: TypeScale.footnote,
                    color: AppStyles.gain(context), fontWeight: FontWeight.w700)),
          ],

          const SizedBox(height: Spacing.lg),

          // Amortization Schedule
          _bloombergSectionHeader('AMORTIZATION SCHEDULE', CupertinoIcons.calendar, accentColor),
          const SizedBox(height: Spacing.sm),

          // Table header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.sm, vertical: Spacing.xs),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF111111) : const Color(0xFFF5F5F7),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(Radii.md)),
            ),
            child: Row(
              children: [
                _amortCol('Mo.', 1, isHeader: true),
                _amortCol('Principal', 2, isHeader: true),
                _amortCol('Interest', 2, isHeader: true),
                _amortCol('Balance', 2, isHeader: true),
              ],
            ),
          ),

          ...schedule.map((row) {
            final isEven = row.month % 2 == 0;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: Spacing.sm, vertical: 5),
              decoration: BoxDecoration(
                color: isEven
                    ? (isDark ? const Color(0xFF0A0A0A) : const Color(0xFFFBFBFD))
                    : Colors.transparent,
              ),
              child: Row(
                children: [
                  _amortCol('${row.month}', 1),
                  _amortCol('₹${row.principal.toStringAsFixed(0)}', 2,
                      color: AppStyles.teal(context)),
                  _amortCol('₹${row.interest.toStringAsFixed(0)}', 2,
                      color: accentColor.withValues(alpha: 0.8)),
                  _amortCol('₹${row.balance.toStringAsFixed(0)}', 2),
                ],
              ),
            );
          }),

          if (!_showFullSchedule && loan.currentOutstanding > 0)
            CupertinoButton(
              onPressed: () => setState(() => _showFullSchedule = true),
              child: Text('Show full schedule',
                  style: TextStyle(color: AppStyles.getPrimaryColor(context),
                      fontSize: TypeScale.footnote)),
            ),
        ],
      ),
    );
  }

  Widget _bloombergSectionHeader(String label, IconData icon, Color accent) {
    return Row(
      children: [
        Container(
          width: 22, height: 22,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Icon(icon, size: 13, color: accent),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                color: accent, letterSpacing: 1.0)),
      ],
    );
  }

  Widget _metricCell(String label, String value, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600,
                  color: AppStyles.getSecondaryTextColor(context), letterSpacing: 0.5)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(fontSize: TypeScale.callout, fontWeight: FontWeight.w800,
                  color: color)),
        ],
      ),
    );
  }

  Widget _amortCol(String text, int flex, {bool isHeader = false, Color? color}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: TextStyle(
          fontSize: isHeader ? 9 : TypeScale.caption,
          fontWeight: isHeader ? FontWeight.w700 : FontWeight.w500,
          color: color ?? (isHeader
              ? AppStyles.getSecondaryTextColor(context)
              : AppStyles.getTextColor(context)),
          letterSpacing: isHeader ? 0.5 : 0,
        ),
      ),
    );
  }
}
