import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, Divider;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/insurance_controller.dart';
import 'package:vittara_fin_os/logic/insurance_model.dart';
import 'package:vittara_fin_os/logic/insurance_rider_model.dart';
import 'package:vittara_fin_os/ui/manage/insurance/insurance_mandate_sheet.dart';
import 'package:vittara_fin_os/ui/manage/insurance/insurance_rider_form.dart';
import 'package:vittara_fin_os/ui/manage/insurance/insurance_wizard.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/widgets/common_widgets.dart';
import 'package:vittara_fin_os/ui/widgets/toast_notification.dart';
import 'package:vittara_fin_os/utils/date_formatter.dart';
import 'package:vittara_fin_os/ui/styles/responsive_utils.dart';

void showInsuranceDetailsSheet(BuildContext context, InsurancePolicy policy) {
  showCupertinoModalPopup<void>(
    context: context,
    builder: (ctx) => RLayout.tabletConstrain(
      ctx,
      _InsuranceDetailsSheet(policy: policy),
    ),
  );
}

class _InsuranceDetailsSheet extends StatefulWidget {
  final InsurancePolicy policy;
  const _InsuranceDetailsSheet({required this.policy});

  @override
  State<_InsuranceDetailsSheet> createState() => _InsuranceDetailsSheetState();
}

class _InsuranceDetailsSheetState extends State<_InsuranceDetailsSheet> {
  late InsurancePolicy _policy;

  @override
  void initState() {
    super.initState();
    _policy = widget.policy;
  }

  IconData _iconForType(InsuranceType type) {
    switch (type) {
      case InsuranceType.health: return CupertinoIcons.heart_fill;
      case InsuranceType.life: return CupertinoIcons.person_fill;
      case InsuranceType.term: return CupertinoIcons.shield_fill;
      case InsuranceType.vehicle: return CupertinoIcons.car_fill;
      case InsuranceType.travel: return CupertinoIcons.airplane;
      case InsuranceType.home: return CupertinoIcons.house_fill;
      case InsuranceType.other: return CupertinoIcons.doc_fill;
    }
  }

  Color _colorForType(InsuranceType type) {
    switch (type) {
      case InsuranceType.health: return AppStyles.loss(context);
      case InsuranceType.life: return AppStyles.teal(context);
      case InsuranceType.term: return AppStyles.violet(context);
      case InsuranceType.vehicle: return AppStyles.accentBlue;
      case InsuranceType.travel: return AppStyles.accentOrange;
      case InsuranceType.home: return AppStyles.gain(context);
      case InsuranceType.other: return AppStyles.gold(context);
    }
  }

  Future<void> _saveRider(InsuranceRider rider) async {
    final ctrl = context.read<InsuranceController>();
    final existing = _policy.riders.indexWhere((r) => r.id == rider.id);
    List<InsuranceRider> updated;
    if (existing >= 0) {
      updated = List<InsuranceRider>.from(_policy.riders)..[existing] = rider;
    } else {
      updated = [..._policy.riders, rider];
    }
    final updatedPolicy = _policy.copyWith(riders: updated);
    await ctrl.updatePolicy(updatedPolicy);
    setState(() => _policy = updatedPolicy);
    toast.showSuccess(existing >= 0 ? 'Rider updated' : 'Rider added');
  }

  Future<void> _deleteRider(InsuranceRider rider) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Remove Rider'),
        content: Text('Remove "${rider.riderName}" from this policy?'),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remove'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final ctrl = context.read<InsuranceController>();
    final updated = _policy.riders.where((r) => r.id != rider.id).toList();
    final updatedPolicy = _policy.copyWith(riders: updated);
    await ctrl.updatePolicy(updatedPolicy);
    setState(() => _policy = updatedPolicy);
    toast.showSuccess('Rider removed');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppStyles.isDarkMode(context);
    final bgColor = isDark ? const Color(0xFF0D0D0D) : CupertinoColors.systemBackground.resolveFrom(context);
    final primaryText = AppStyles.getTextColor(context);
    final secondaryText = AppStyles.getSecondaryTextColor(context);
    final cardColor = isDark ? const Color(0xFF141414) : const Color(0xFFF7F7F7);
    final borderColor = isDark ? const Color(0xFF1E1E1E) : const Color(0xFFE0E0E0);
    final typeColor = _colorForType(_policy.type);
    final activeRiders = _policy.riders.where((r) => r.isActive).toList();

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.only(bottom: 32),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ModalHandle(),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: typeColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(_iconForType(_policy.type), color: typeColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_policy.name, style: TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.bold, fontSize: 18, color: primaryText)),
                        Text('${_policy.insurer} · ${_policy.type.displayName}', style: TextStyle(fontSize: 12, color: secondaryText)),
                      ],
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => Navigator.pop(context),
                    child: Icon(CupertinoIcons.xmark_circle_fill, color: secondaryText.withValues(alpha: 0.3), size: 26),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    _sectionDivider('Policy Details', isDark),
                    _detailRow('Policy No.', _policy.policyNumber ?? '—', primaryText, secondaryText),
                    _detailRow('Type', _policy.type.displayName, primaryText, secondaryText),
                    _detailRow('Insurer', _policy.insurer, primaryText, secondaryText),
                    _detailRow('Start Date', DateFormatter.format(_policy.startDate), primaryText, secondaryText),
                    _detailRow(
                      '${_policy.type.dateConcept} Date',
                      DateFormatter.format(_policy.type.usesMaturityDate
                          ? (_policy.maturityDate ?? _policy.renewalDate)
                          : _policy.renewalDate),
                      primaryText, secondaryText,
                    ),
                    if (_policy.policyTermYears != null)
                      _detailRow('Policy Term', '${_policy.policyTermYears} years', primaryText, secondaryText),
                    if (_policy.premiumPayingTermYears != null)
                      _detailRow('Premium Paying Term', '${_policy.premiumPayingTermYears} years', primaryText, secondaryText),

                    _sectionDivider('Financial', isDark),
                    _detailRow('Sum Insured', CurrencyFormatter.compact(_policy.sumInsured), primaryText, secondaryText),
                    _detailRow('Premium', '${CurrencyFormatter.compact(_policy.premiumAmount)} / ${_policy.premiumFrequency}', primaryText, secondaryText),
                    _detailRow('Annual Premium', CurrencyFormatter.compact(_policy.annualPremium), primaryText, secondaryText),
                    if (activeRiders.isNotEmpty) ...[
                      _detailRow('Rider Premium', CurrencyFormatter.compact(_policy.totalRiderPremium), primaryText, secondaryText),
                      _detailRow('Total Annual Cost', CurrencyFormatter.compact(_policy.totalAnnualCostWithRiders), AppStyles.accentBlue, secondaryText),
                    ],

                    if (_policy.nomineeName != null) ...[
                      _sectionDivider('Nominee & Notes', isDark),
                      _detailRow('Nominee', _policy.nomineeName!, primaryText, secondaryText),
                      if (_policy.notes != null && _policy.notes!.isNotEmpty)
                        _detailRow('Notes', _policy.notes!, primaryText, secondaryText),
                    ],

                    // ── Riders ─────────────────────────────────────────────
                    _sectionDivider('Riders & Add-ons', isDark),
                    if (activeRiders.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text('No riders added yet.', style: TextStyle(fontSize: 13, color: secondaryText)),
                      )
                    else
                      ...activeRiders.map((rider) => _buildRiderCard(rider, isDark, primaryText, secondaryText, cardColor, borderColor)),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => showInsuranceRiderForm(
                        context,
                        insuranceType: _policy.type,
                        onSave: _saveRider,
                      ),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        decoration: BoxDecoration(
                          color: AppStyles.accentBlue.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppStyles.accentBlue.withValues(alpha: 0.3), style: BorderStyle.solid),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(CupertinoIcons.plus_circle_fill, size: 15, color: AppStyles.accentBlue),
                            const SizedBox(width: 6),
                            Text('Add Rider / Add-on', style: TextStyle(fontSize: 13, color: AppStyles.accentBlue, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),

                    // ── Auto-Pay Mandate ───────────────────────────────────
                    _sectionDivider('Auto-Pay Mandate', isDark),
                    if (_policy.mandateEnabled && _policy.mandateNextDueDate != null) ...[
                      _detailRow('Linked Account', _policy.mandateLinkedAccountName ?? '—', primaryText, secondaryText),
                      _detailRow('Next Due Date', DateFormatter.format(_policy.mandateNextDueDate!), primaryText, secondaryText),
                      _detailRow('Amount', CurrencyFormatter.compact(_policy.premiumAmount), primaryText, secondaryText),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppStyles.gain(context).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppStyles.gain(context).withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(CupertinoIcons.checkmark_circle_fill, size: 13, color: AppStyles.gain(context)),
                            const SizedBox(width: 6),
                            Text('Auto-pay active', style: TextStyle(fontSize: 12, color: AppStyles.gain(context), fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ] else
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text('No auto-pay mandate set up.', style: TextStyle(fontSize: 13, color: secondaryText)),
                      ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // ── Action buttons ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _actionButton(
                          label: 'Edit Policy',
                          icon: CupertinoIcons.pencil,
                          color: AppStyles.accentBlue,
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.of(context).push(CupertinoPageRoute<void>(
                              builder: (_) => InsuranceWizard(
                                existingPolicy: _policy,
                                onSave: (updated) {
                                  context.read<InsuranceController>().updatePolicy(updated);
                                  toast.showSuccess('Policy updated');
                                },
                              ),
                            ));
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _actionButton(
                          label: _policy.mandateEnabled ? 'Edit Mandate' : 'Set Auto-Pay',
                          icon: CupertinoIcons.arrow_right_arrow_left_circle_fill,
                          color: AppStyles.teal(context),
                          onTap: () {
                            Navigator.pop(context);
                            showInsuranceMandateSheet(context, _policy);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _actionButton(
                    label: 'Delete Policy',
                    icon: CupertinoIcons.trash,
                    color: AppStyles.loss(context),
                    fullWidth: true,
                    onTap: () async {
                      Navigator.pop(context);
                      final confirmed = await showCupertinoDialog<bool>(
                        context: context,
                        builder: (ctx) => CupertinoAlertDialog(
                          title: const Text('Delete Policy'),
                          content: Text('Remove "${_policy.name}" from your tracker?'),
                          actions: [
                            CupertinoDialogAction(isDestructiveAction: true, onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Delete')),
                            CupertinoDialogAction(isDefaultAction: true, onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                          ],
                        ),
                      );
                      if (confirmed == true && context.mounted) {
                        await context.read<InsuranceController>().deletePolicy(_policy.id);
                        toast.showSuccess('Policy removed');
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRiderCard(InsuranceRider rider, bool isDark, Color primaryText, Color secondaryText, Color cardColor, Color borderColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppStyles.accentBlue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(CupertinoIcons.shield_lefthalf_fill, size: 14, color: AppStyles.accentBlue),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(rider.riderName, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: primaryText)),
                      Text(rider.type.displayName, style: TextStyle(fontSize: 11, color: secondaryText)),
                    ],
                  ),
                ),
                if (rider.isInbuilt)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppStyles.gain(context).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('Inbuilt', style: TextStyle(fontSize: 10, color: AppStyles.gain(context), fontWeight: FontWeight.w600)),
                  )
                else
                  Text(
                    CurrencyFormatter.compact(rider.annualCost),
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppStyles.accentBlue),
                  ),
                const SizedBox(width: 4),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(32, 32),
                  onPressed: () => showCupertinoModalPopup<void>(
                    context: context,
                    builder: (ctx) => RLayout.tabletConstrain(
                      ctx,
                      CupertinoActionSheet(
                      title: Text(rider.riderName),
                      actions: [
                        CupertinoActionSheetAction(
                          onPressed: () {
                            Navigator.pop(ctx);
                            showInsuranceRiderForm(context, insuranceType: _policy.type, existing: rider, onSave: _saveRider);
                          },
                          child: const Text('Edit Rider'),
                        ),
                        CupertinoActionSheetAction(
                          isDestructiveAction: true,
                          onPressed: () { Navigator.pop(ctx); _deleteRider(rider); },
                          child: const Text('Remove Rider'),
                        ),
                      ],
                      cancelButton: CupertinoActionSheetAction(isDefaultAction: true, onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                    ),
                    ),
                  ),
                  child: Icon(CupertinoIcons.ellipsis_circle, size: 18, color: secondaryText),
                ),
              ],
            ),
          ),
          // Detail chips
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (rider.riderSumAssured != null)
                  _chip('SA: ${CurrencyFormatter.compact(rider.riderSumAssured!)}', isDark, secondaryText),
                if (rider.waitingPeriodDays != null)
                  _chip('Wait: ${_formatDays(rider.waitingPeriodDays!)}', isDark, secondaryText),
                if (rider.survivalPeriodDays != null)
                  _chip('Survival: ${_formatDays(rider.survivalPeriodDays!)}', isDark, secondaryText),
                if (rider.illnessCount != null)
                  _chip('${rider.illnessCount} illnesses', isDark, secondaryText),
                if (rider.isCiAccelerated == true)
                  _chip('Accelerated', isDark, AppStyles.accentOrange),
                if (rider.hasOwnTenure && rider.riderEndDate != null)
                  _chip('Until ${DateFormatter.format(rider.riderEndDate!)}', isDark, secondaryText),
                if (rider.vehicleAgeEligibilityYears != null)
                  _chip('≤ ${rider.vehicleAgeEligibilityYears}yr vehicle', isDark, secondaryText),
                if (rider.notes != null && rider.notes!.isNotEmpty)
                  _chip(rider.notes!, isDark, secondaryText),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDays(int days) {
    if (days >= 1460) return '4 years';
    if (days >= 1095) return '3 years';
    if (days >= 730) return '2 years';
    if (days >= 365) return '1 year';
    if (days >= 180) return '6 months';
    if (days >= 90) return '90 days';
    if (days >= 60) return '60 days';
    if (days >= 30) return '30 days';
    return '$days days';
  }

  Widget _chip(String label, bool isDark, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(label, style: TextStyle(fontSize: 10, color: color)),
    );
  }

  Widget _sectionDivider(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Row(
        children: [
          Text(title.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF5A6A80) : const Color(0xFF8899AA), letterSpacing: 0.8)),
          const SizedBox(width: 8),
          Expanded(child: Divider(color: isDark ? const Color(0xFF1C2A3A) : const Color(0xFFDDEEFF), height: 1)),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value, Color primaryText, Color secondaryText) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 140, child: Text(label, style: TextStyle(fontSize: 13, color: secondaryText))),
          Expanded(child: Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: primaryText), textAlign: TextAlign.right)),
        ],
      ),
    );
  }

  Widget _actionButton({required String label, required IconData icon, required Color color, required VoidCallback onTap, bool fullWidth = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: fullWidth ? double.infinity : null,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
