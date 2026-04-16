import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/insurance_controller.dart';
import 'package:vittara_fin_os/logic/insurance_model.dart';
import 'package:vittara_fin_os/ui/manage/insurance/insurance_details_sheet.dart';
import 'package:vittara_fin_os/ui/manage/insurance/insurance_mandate_sheet.dart';
import 'package:vittara_fin_os/ui/manage/insurance/insurance_wizard.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/styles/typography.dart';
import 'package:vittara_fin_os/ui/widgets/animations.dart';
import 'package:vittara_fin_os/ui/widgets/common_widgets.dart';
import 'package:vittara_fin_os/ui/widgets/toast_notification.dart';
import 'package:vittara_fin_os/utils/date_formatter.dart';
import 'package:vittara_fin_os/logic/insurance_rider_model.dart';
import 'package:vittara_fin_os/ui/widgets/animated_counter.dart' as counter_widgets;
import 'package:vittara_fin_os/ui/styles/responsive_utils.dart';

class InsuranceScreen extends StatefulWidget {
  const InsuranceScreen({super.key});

  @override
  State<InsuranceScreen> createState() => _InsuranceScreenState();
}

class _InsuranceScreenState extends State<InsuranceScreen> {
  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppStyles.getBackground(context),
      navigationBar: AppStyles.isLandscape(context) ? null : CupertinoNavigationBar(
        middle: Text(
          'Insurance Tracker',
          style: TextStyle(color: AppStyles.getTextColor(context)),
        ),
        previousPageTitle: 'Back',
        backgroundColor: AppStyles.isDarkMode(context)
            ? Colors.black
            : Colors.white.withValues(alpha: 0.95),
        border: null,
      ),
      child: Consumer<InsuranceController>(
        builder: (context, controller, _) {
          final active = controller.activePolicies;
          final expiringSoon = controller.policiesExpiringSoon;
          return Stack(
            children: [
              SafeArea(
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: _buildSummaryCard(context, controller),
                    ),
                    if (expiringSoon.isNotEmpty)
                      SliverToBoxAdapter(
                        child: _buildRenewalWarning(context, expiringSoon),
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
                              padding:
                                  const EdgeInsets.only(bottom: Spacing.md),
                              child: _PolicyCard(
                                policy: active[index],
                                onTap: () =>
                                    showInsuranceDetailsSheet(context, active[index]),
                                onDelete: () => _confirmDelete(
                                    context, controller, active[index]),
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
                  onPressed: () => _openAddPolicy(context),
                  color: AppStyles.accentBlue,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard(
      BuildContext context, InsuranceController controller) {
    final annual = controller.totalAnnualPremium;
    final count = controller.activePolicies.length;
    final isDark = AppStyles.isDarkMode(context);
    // Coverage breakdown
    double healthCover = 0, lifeCover = 0;
    for (final p in controller.activePolicies) {
      if (p.type == InsuranceType.health) healthCover += p.sumInsured;
      if (p.type == InsuranceType.life || p.type == InsuranceType.term) lifeCover += p.sumInsured;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          Spacing.lg, Spacing.lg, Spacing.lg, Spacing.lg),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    const Color(0xFF001026),
                    const Color(0xFF000810),
                  ]
                : [
                    AppStyles.accentBlue.withValues(alpha: 0.08),
                    AppStyles.accentBlue.withValues(alpha: 0.03),
                  ],
          ),
          borderRadius: BorderRadius.circular(Radii.xxl),
          border: Border.all(
            color: AppStyles.accentBlue
                .withValues(alpha: isDark ? 0.25 : 0.15),
            width: 1,
          ),
          boxShadow: isDark
              ? [
                  BoxShadow(
                    color: AppStyles.accentBlue.withValues(alpha: 0.08),
                    blurRadius: 24,
                    spreadRadius: -4,
                  ),
                ]
              : [],
        ),
        padding: const EdgeInsets.all(Spacing.xl),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _SummaryMetric(
                    label: 'Annual Premium',
                    numericValue: annual,
                    color: AppStyles.accentBlue,
                  ),
                ),
                Container(
                  width: 1, height: 44,
                  color: AppStyles.accentBlue.withValues(alpha: 0.2),
                ),
                Expanded(
                  child: _SummaryMetric(
                    label: 'Active Policies',
                    numericValue: count.toDouble(),
                    color: AppStyles.teal(context),
                    isCurrency: false,
                  ),
                ),
              ],
            ),
            if (healthCover > 0 || lifeCover > 0) ...[
              Divider(height: Spacing.lg,
                  color: AppStyles.accentBlue.withValues(alpha: 0.12)),
              Row(
                children: [
                  if (healthCover > 0)
                    Expanded(child: _SummaryMetric(
                        label: 'Health Cover',
                        numericValue: healthCover,
                        color: AppStyles.gain(context))),
                  if (healthCover > 0 && lifeCover > 0)
                    Container(width: 1, height: 36,
                        color: AppStyles.accentBlue.withValues(alpha: 0.12)),
                  if (lifeCover > 0)
                    Expanded(child: _SummaryMetric(
                        label: 'Life Cover',
                        numericValue: lifeCover,
                        color: AppStyles.violet(context))),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRenewalWarning(
      BuildContext context, List<InsurancePolicy> expiring) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          Spacing.lg, 0, Spacing.lg, Spacing.md),
      child: Container(
        decoration: BoxDecoration(
          color: AppStyles.accentOrange.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(Radii.lg),
          border: Border.all(
            color: AppStyles.accentOrange.withValues(alpha: 0.4),
            width: 1,
          ),
        ),
        padding: const EdgeInsets.all(Spacing.md),
        child: Row(
          children: [
            const Icon(
              CupertinoIcons.bell_fill,
              color: AppStyles.accentOrange,
              size: 18,
            ),
            const SizedBox(width: Spacing.sm),
            Expanded(
              child: Text(
                expiring.length == 1
                    ? '"${expiring.first.name}" — ${expiring.first.type.dateConcept.toLowerCase()} in ${expiring.first.daysUntilRenewal} day(s).'
                    : '${expiring.length} policies due within 30 days.',
                style: const TextStyle(
                  fontSize: TypeScale.caption,
                  color: AppStyles.accentOrange,
                  fontWeight: FontWeight.w600,
                ),
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
              CupertinoIcons.shield_fill,
              size: 64,
              color: AppStyles.getSecondaryTextColor(context),
            ),
            const SizedBox(height: Spacing.lg),
            Text(
              'No insurance policies',
              style: TextStyle(
                fontSize: TypeScale.title3,
                fontWeight: FontWeight.w600,
                color: AppStyles.getTextColor(context),
              ),
            ),
            const SizedBox(height: Spacing.sm),
            Text(
              'Track your health, life, vehicle, and other insurance policies in one place.',
              style: TextStyle(
                fontSize: TypeScale.body,
                color: AppStyles.getSecondaryTextColor(context),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Spacing.xxl),
            BouncyButton(
              onPressed: () => _openAddPolicy(context),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.xxl,
                  vertical: Spacing.md,
                ),
                decoration: BoxDecoration(
                  color: AppStyles.accentBlue,
                  borderRadius: BorderRadius.circular(Radii.full),
                  boxShadow: Shadows.fab(AppStyles.accentBlue),
                ),
                child: const Text(
                  'Add First Policy',
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

  Future<void> _openAddPolicy(BuildContext context) async {
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => InsuranceWizard(
          onSave: (policy) {
            context.read<InsuranceController>().addPolicy(policy);
            toast.showSuccess('Policy added');
          },
        ),
      ),
    );
  }

  Future<void> _openEditPolicy(
      BuildContext context, InsurancePolicy policy) async {
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => InsuranceWizard(
          existingPolicy: policy,
          onSave: (updated) {
            context.read<InsuranceController>().updatePolicy(updated);
            toast.showSuccess('Policy updated');
          },
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    InsuranceController controller,
    InsurancePolicy policy,
  ) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Delete Policy'),
        content: Text('Remove "${policy.name}" from your tracker?'),
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
      await controller.deletePolicy(policy.id);
      toast.showSuccess('Policy removed');
    }
  }
}

// ─── Summary Metric ───────────────────────────────────────────────────────────

class _SummaryMetric extends StatelessWidget {
  final String label;
  final double numericValue;
  final Color color;
  final bool isCurrency;

  const _SummaryMetric({
    required this.label,
    required this.numericValue,
    required this.color,
    this.isCurrency = true,
  });

  @override
  Widget build(BuildContext context) {
    final textStyle = TextStyle(
      fontSize: TypeScale.title3,
      fontWeight: FontWeight.w800,
      color: color,
      letterSpacing: -0.5,
    );
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
        isCurrency
            ? counter_widgets.CurrencyCounter(
                value: numericValue,
                textStyle: textStyle,
                decimalPlaces: 0,
              )
            : counter_widgets.AnimatedCounter(
                value: numericValue,
                decimalPlaces: 0,
                textStyle: textStyle,
              ),
      ],
    );
  }
}

// ─── Policy Card ──────────────────────────────────────────────────────────────

class _PolicyCard extends StatelessWidget {
  final InsurancePolicy policy;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _PolicyCard({
    required this.policy,
    required this.onTap,
    required this.onDelete,
  });

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

  Color _colorForType(InsuranceType type, BuildContext context) {
    switch (type) {
      case InsuranceType.health:
        return AppStyles.loss(context);
      case InsuranceType.life:
        return AppStyles.teal(context);
      case InsuranceType.term:
        return AppStyles.violet(context);
      case InsuranceType.vehicle:
        return AppStyles.accentBlue;
      case InsuranceType.travel:
        return AppStyles.accentOrange;
      case InsuranceType.home:
        return AppStyles.gain(context);
      case InsuranceType.other:
        return AppStyles.gold(context);
    }
  }

  Color _renewalColor(BuildContext context) {
    if (policy.isExpired) return SemanticColors.getError(context);
    if (policy.isExpiringSoon) return SemanticColors.getWarning(context);
    return SemanticColors.getSuccess(context);
  }

  String _renewalLabel() {
    final concept = policy.type.dateConcept; // 'Renewal', 'Maturity', 'Trip End'
    final days = policy.daysUntilRenewal;
    if (policy.isExpired) {
      switch (policy.type) {
        case InsuranceType.term:
        case InsuranceType.life:
          return 'Matured';
        case InsuranceType.travel:
          return 'Trip ended';
        default:
          return 'Expired';
      }
    }
    if (days == 0) return '$concept today';
    if (days < 0) return '${(-days)}d ago';
    return '$concept in ${days}d';
  }

  void _showActions(BuildContext context) {
    HapticFeedback.mediumImpact();
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => RLayout.tabletConstrain(
        ctx,
        CupertinoActionSheet(
        title: Text(policy.name),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              showInsuranceDetailsSheet(context, policy);
            },
            child: const Text('View Full Details'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              onTap();
            },
            child: const Text('Edit Policy'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              showInsuranceMandateSheet(context, policy);
            },
            child: const Text('Set Up Auto-Pay'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.of(ctx).pop();
              onDelete();
            },
            child: const Text('Delete Policy'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
      ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final typeColor = _colorForType(policy.type, context);
    final renewalColor = _renewalColor(context);
    final isDark = AppStyles.isDarkMode(context);

    return GestureDetector(
      onLongPress: () => _showActions(context),
      child: BouncyButton(
        onPressed: () => _showActions(context),
        child: Container(
          decoration: AppStyles.cardDecoration(context),
          padding: const EdgeInsets.all(Spacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: typeColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(Radii.md),
                    ),
                    child: Icon(
                      _iconForType(policy.type),
                      color: typeColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: Spacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          policy.name,
                          style: AppStyles.titleStyle(context),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: Spacing.xxs),
                        Text(
                          '${policy.insurer}  ·  ${policy.type.displayName}',
                          style: TextStyle(
                            fontSize: TypeScale.caption,
                            color:
                                AppStyles.getSecondaryTextColor(context),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        CurrencyFormatter.compact(policy.sumInsured),
                        style: TextStyle(
                          fontSize: TypeScale.body,
                          fontWeight: FontWeight.w800,
                          color: typeColor,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: Spacing.xxs),
                      Text(
                        'sum insured',
                        style: TextStyle(
                          fontSize: 10,
                          color:
                              AppStyles.getSecondaryTextColor(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: Spacing.md),
              // Divider
              Divider(
                  color: isDark
                      ? const Color(0xFF1C1C1C)
                      : AppStyles.getDividerColor(context),
                  height: 1),
              const SizedBox(height: Spacing.md),
              // Bottom row: premium + renewal
              Row(
                children: [
                  // Premium info
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          CupertinoIcons.money_dollar_circle,
                          size: 14,
                          color:
                              AppStyles.getSecondaryTextColor(context),
                        ),
                        const SizedBox(width: Spacing.xs),
                        Text(
                          '${CurrencyFormatter.compact(policy.premiumAmount)} / ${policy.premiumFrequency}',
                          style: AppTypography.caption(
                            color: AppStyles.getSecondaryTextColor(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Renewal badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: Spacing.sm, vertical: 3),
                    decoration: BoxDecoration(
                      color: renewalColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(Radii.sm),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          CupertinoIcons.calendar,
                          size: 11,
                          color: renewalColor,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          _renewalLabel(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: renewalColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (policy.policyNumber != null) ...[
                const SizedBox(height: Spacing.xs),
                Text(
                  'Policy No. ${policy.policyNumber}',
                  style: TextStyle(
                    fontSize: 11,
                    color:
                        AppStyles.getSecondaryTextColor(context)
                            .withValues(alpha: 0.7),
                  ),
                ),
              ],
              if (policy.mandateEnabled) ...[
                const SizedBox(height: Spacing.xs),
                Row(
                  children: [
                    Icon(CupertinoIcons.arrow_right_arrow_left_circle_fill,
                        size: 12, color: AppStyles.teal(context)),
                    const SizedBox(width: 4),
                    Text(
                      policy.mandateNextDueDate != null
                          ? 'Auto-pay: ${DateFormatter.format(policy.mandateNextDueDate!)}'
                          : 'Auto-pay active',
                      style: AppTypography.caption(color: AppStyles.teal(context)),
                    ),
                  ],
                ),
              ],
              if (policy.riders.isNotEmpty) ...[
                const SizedBox(height: Spacing.xs),
                Row(
                  children: [
                    Icon(CupertinoIcons.shield_lefthalf_fill,
                        size: 12, color: AppStyles.accentBlue),
                    const SizedBox(width: 4),
                    Text(
                      () {
                        final activeRiders = policy.riders.where((r) => r.isActive).toList();
                        final count = activeRiders.length;
                        final label = count == 1 ? 'rider' : 'riders';
                        return '$count $label · +${CurrencyFormatter.compact(policy.totalRiderPremium)}/yr';
                      }(),
                      style: AppTypography.caption(color: AppStyles.accentBlue),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

