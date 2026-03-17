import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/insurance_controller.dart';
import 'package:vittara_fin_os/logic/insurance_model.dart';
import 'package:vittara_fin_os/ui/manage/insurance/insurance_wizard.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/widgets/animations.dart';
import 'package:vittara_fin_os/ui/widgets/toast_notification.dart';
import 'package:vittara_fin_os/utils/date_formatter.dart';

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
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          'Insurance Tracker',
          style: TextStyle(color: AppStyles.getTextColor(context)),
        ),
        previousPageTitle: 'Manage',
        backgroundColor: AppStyles.isDarkMode(context)
            ? Colors.black
            : Colors.white.withValues(alpha: 0.95),
        border: null,
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => _openAddPolicy(context),
          child: const Icon(
            CupertinoIcons.add_circled_solid,
            color: AppStyles.accentBlue,
            size: 26,
          ),
        ),
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
                                    _openEditPolicy(context, active[index]),
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
              // FAB
              Positioned(
                right: Spacing.lg,
                bottom:
                    Spacing.xxl + MediaQuery.of(context).padding.bottom,
                child: _AddPolicyFab(
                    onPressed: () => _openAddPolicy(context)),
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
        child: Row(
          children: [
            Expanded(
              child: _SummaryMetric(
                label: 'Annual Premium',
                value: CurrencyFormatter.compact(annual),
                color: AppStyles.accentBlue,
              ),
            ),
            Container(
              width: 1,
              height: 44,
              color: AppStyles.accentBlue.withValues(alpha: 0.2),
            ),
            Expanded(
              child: _SummaryMetric(
                label: 'Active Policies',
                value: '$count',
                color: AppStyles.aetherTeal,
              ),
            ),
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
                    ? '"${expiring.first.name}" renews in ${expiring.first.daysUntilRenewal} day(s).'
                    : '${expiring.length} policies renewing within 30 days.',
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

  Color _renewalColor() {
    if (policy.isExpired) return AppStyles.plasmaRed;
    if (policy.isExpiringSoon) return AppStyles.accentOrange;
    return AppStyles.bioGreen;
  }

  String _renewalLabel() {
    if (policy.isExpired) return 'Expired';
    final days = policy.daysUntilRenewal;
    if (days == 0) return 'Renews today';
    if (days < 0) return 'Expired ${(-days)} days ago';
    return 'Renews in $days days';
  }

  void _showActions(BuildContext context) {
    HapticFeedback.mediumImpact();
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(policy.name),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              onTap();
            },
            child: const Text('Edit Policy'),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final typeColor = _colorForType(policy.type);
    final renewalColor = _renewalColor();
    final isDark = AppStyles.isDarkMode(context);

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
                          style: TextStyle(
                            fontSize: TypeScale.caption,
                            color:
                                AppStyles.getSecondaryTextColor(context),
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
            ],
          ),
        ),
      ),
    );
  }
}

// ─── FAB ─────────────────────────────────────────────────────────────────────

class _AddPolicyFab extends StatelessWidget {
  final VoidCallback onPressed;

  const _AddPolicyFab({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return BouncyButton(
      onPressed: onPressed,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: AppStyles.accentBlue,
          shape: BoxShape.circle,
          boxShadow: Shadows.fab(AppStyles.accentBlue),
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
