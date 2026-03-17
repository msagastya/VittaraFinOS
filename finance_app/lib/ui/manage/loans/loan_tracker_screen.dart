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
import 'package:vittara_fin_os/ui/widgets/toast_notification.dart';
import 'package:vittara_fin_os/utils/date_formatter.dart';

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
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          'Loan / EMI Tracker',
          style: TextStyle(color: AppStyles.getTextColor(context)),
        ),
        previousPageTitle: 'Manage',
        backgroundColor: AppStyles.isDarkMode(context)
            ? Colors.black
            : Colors.white.withValues(alpha: 0.95),
        border: null,
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => _openAddLoan(context),
          child: Icon(
            CupertinoIcons.add_circled_solid,
            color: AppStyles.getPrimaryColor(context),
            size: 26,
          ),
        ),
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
                                onTap: () => _openEditLoan(context, active[index]),
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
              // FAB
              Positioned(
                right: Spacing.lg,
                bottom: Spacing.xxl + MediaQuery.of(context).padding.bottom,
                child: _AddLoanFab(onPressed: () => _openAddLoan(context)),
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
                    AppStyles.plasmaRed.withValues(alpha: 0.08),
                    AppStyles.plasmaRed.withValues(alpha: 0.03),
                  ],
          ),
          borderRadius: BorderRadius.circular(Radii.xxl),
          border: Border.all(
            color: AppStyles.plasmaRed.withValues(alpha: isDark ? 0.25 : 0.15),
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
                value: CurrencyFormatter.compact(outstanding),
                color: AppStyles.plasmaRed,
              ),
            ),
            Container(
              width: 1,
              height: 44,
              color: AppStyles.plasmaRed.withValues(alpha: 0.2),
            ),
            Expanded(
              child: _SummaryMetric(
                label: 'Monthly EMI',
                value: CurrencyFormatter.compact(emi),
                color: AppStyles.aetherTeal,
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
                  color: AppStyles.plasmaRed,
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
}

// ─── Summary Metric ──────────────────────────────────────────────────────────

class _SummaryMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryMetric({
    required this.label,
    required this.value,
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
        Text(
          value,
          style: TextStyle(
            fontSize: TypeScale.title3,
            fontWeight: FontWeight.w800,
            color: color,
            letterSpacing: -0.5,
          ),
          textAlign: TextAlign.center,
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
        ? AppStyles.plasmaRed
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
                      style: const TextStyle(
                        fontSize: TypeScale.body,
                        fontWeight: FontWeight.w800,
                        color: AppStyles.plasmaRed,
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
                    : AppStyles.plasmaRed.withValues(alpha: 0.12),
                valueColor: AlwaysStoppedAnimation<Color>(
                  loan.progressPercent >= 0.8
                      ? AppStyles.bioGreen
                      : AppStyles.aetherTeal,
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
                    style: const TextStyle(
                      fontSize: TypeScale.caption,
                      fontWeight: FontWeight.w700,
                      color: AppStyles.aetherTeal,
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

  Color get _color {
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
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(Radii.lg),
        boxShadow: Shadows.iconGlow(_color),
      ),
      child: Icon(_icon, color: _color, size: 20),
    );
  }
}

// ─── Add FAB ─────────────────────────────────────────────────────────────────

class _AddLoanFab extends StatelessWidget {
  final VoidCallback onPressed;

  const _AddLoanFab({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return BouncyButton(
      onPressed: onPressed,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: AppStyles.plasmaRed,
          shape: BoxShape.circle,
          boxShadow: Shadows.fab(AppStyles.plasmaRed),
        ),
        child: const Icon(
          CupertinoIcons.add,
          color: Colors.white,
          size: 26,
        ),
      ),
    );
  }
}
