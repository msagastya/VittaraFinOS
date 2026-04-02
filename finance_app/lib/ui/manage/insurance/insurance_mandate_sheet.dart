import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/account_model.dart';
import 'package:vittara_fin_os/logic/accounts_controller.dart';
import 'package:vittara_fin_os/logic/insurance_controller.dart';
import 'package:vittara_fin_os/logic/insurance_model.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/widgets/common_widgets.dart';
import 'package:vittara_fin_os/ui/widgets/toast_notification.dart';
import 'package:vittara_fin_os/utils/date_formatter.dart';

void showInsuranceMandateSheet(BuildContext context, InsurancePolicy policy) {
  showCupertinoModalPopup<void>(
    context: context,
    builder: (ctx) => _InsuranceMandateSheet(policy: policy),
  );
}

class _InsuranceMandateSheet extends StatefulWidget {
  final InsurancePolicy policy;
  const _InsuranceMandateSheet({required this.policy});

  @override
  State<_InsuranceMandateSheet> createState() => _InsuranceMandateSheetState();
}

class _InsuranceMandateSheetState extends State<_InsuranceMandateSheet> {
  late bool _mandateEnabled;
  late String? _linkedAccountId;
  late String? _linkedAccountName;
  late DateTime _nextDueDate;

  @override
  void initState() {
    super.initState();
    _mandateEnabled = widget.policy.mandateEnabled;
    _linkedAccountId = widget.policy.mandateLinkedAccountId;
    _linkedAccountName = widget.policy.mandateLinkedAccountName;
    _nextDueDate = widget.policy.mandateNextDueDate ?? _defaultDueDate();
  }

  DateTime _defaultDueDate() {
    // Default: next renewal date or 30 days from now
    final renewal = widget.policy.type.usesMaturityDate
        ? (widget.policy.maturityDate ?? widget.policy.renewalDate)
        : widget.policy.renewalDate;
    final now = DateTime.now();
    if (renewal.isAfter(now)) return renewal;
    return now.add(const Duration(days: 30));
  }

  void _pickAccount() {
    final accounts = context.read<AccountsController>().accounts
        .where((a) => !a.isHidden && a.type != AccountType.investment)
        .toList();

    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) {
        final isDark = AppStyles.isDarkMode(ctx);
        final bgColor = isDark ? const Color(0xFF0D0D0D) : CupertinoColors.systemBackground.resolveFrom(ctx);
        final secondaryText = AppStyles.getSecondaryTextColor(ctx);
        final primaryText = AppStyles.getTextColor(ctx);

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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: Text('Select Account',
                    style: TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.bold, fontSize: 17, color: primaryText),
                  ),
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.45),
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: accounts.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final acc = accounts[i];
                      final isSelected = acc.id == _linkedAccountId;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _linkedAccountId = acc.id;
                            _linkedAccountName = acc.name;
                          });
                          Navigator.pop(ctx);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected ? acc.color.withValues(alpha: 0.12) : (isDark ? const Color(0xFF141414) : const Color(0xFFF7F7F7)),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected ? acc.color.withValues(alpha: 0.6) : (isDark ? const Color(0xFF1E1E1E) : const Color(0xFFE0E0E0)),
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36, height: 36,
                                decoration: BoxDecoration(
                                  color: acc.color.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Center(
                                  child: Container(
                                    width: 12, height: 12,
                                    decoration: BoxDecoration(color: acc.color, shape: BoxShape.circle),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(acc.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: primaryText)),
                                    Text(acc.bankName, style: TextStyle(fontSize: 11, color: secondaryText)),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                Icon(CupertinoIcons.checkmark_circle_fill, size: 18, color: acc.color),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFEEEEEE),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(child: Text('Cancel', style: TextStyle(fontSize: 14, color: secondaryText))),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _pickDate() {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) {
        final isDark = AppStyles.isDarkMode(ctx);
        return Container(
          height: 280,
          color: isDark ? const Color(0xFF1C1C1E) : CupertinoColors.systemBackground.resolveFrom(ctx),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                  CupertinoButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: _nextDueDate,
                  minimumDate: DateTime.now(),
                  onDateTimeChanged: (d) => setState(() => _nextDueDate = d),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _save() async {
    if (_mandateEnabled && _linkedAccountId == null) {
      toast.showError('Please select an account');
      return;
    }
    final ctrl = context.read<InsuranceController>();
    final updated = widget.policy.copyWith(
      mandateEnabled: _mandateEnabled,
      mandateLinkedAccountId: _mandateEnabled ? _linkedAccountId : null,
      mandateLinkedAccountName: _mandateEnabled ? _linkedAccountName : null,
      mandateNextDueDate: _mandateEnabled ? _nextDueDate : null,
    );
    await ctrl.updatePolicy(updated);
    if (mounted) {
      Navigator.pop(context);
      toast.showSuccess(_mandateEnabled ? 'Auto-pay mandate set up' : 'Mandate disabled');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppStyles.isDarkMode(context);
    final bgColor = isDark ? const Color(0xFF0D0D0D) : CupertinoColors.systemBackground.resolveFrom(context);
    final primaryText = AppStyles.getTextColor(context);
    final secondaryText = AppStyles.getSecondaryTextColor(context);
    final cardColor = isDark ? const Color(0xFF141414) : const Color(0xFFF7F7F7);
    final borderColor = isDark ? const Color(0xFF1E1E1E) : const Color(0xFFE0E0E0);

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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Auto-Pay Mandate',
                        style: TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.bold, fontSize: 18, color: primaryText),
                      ),
                      Text(widget.policy.name, style: TextStyle(fontSize: 12, color: secondaryText)),
                    ],
                  ),
                  const Spacer(),
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
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Enable toggle
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: borderColor),
                      ),
                      child: Row(
                        children: [
                          Icon(CupertinoIcons.arrow_right_arrow_left_circle_fill,
                            size: 20, color: _mandateEnabled ? AppStyles.teal(context) : secondaryText),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Enable Auto-Pay', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: primaryText)),
                                Text('Get a reminder when premium is due', style: TextStyle(fontSize: 11, color: secondaryText)),
                              ],
                            ),
                          ),
                          CupertinoSwitch(
                            value: _mandateEnabled,
                            activeTrackColor: AppStyles.teal(context),
                            onChanged: (v) => setState(() => _mandateEnabled = v),
                          ),
                        ],
                      ),
                    ),
                    if (_mandateEnabled) ...[
                      const SizedBox(height: 12),
                      // Account picker
                      GestureDetector(
                        onTap: _pickAccount,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: _linkedAccountId != null
                                  ? AppStyles.accentBlue.withValues(alpha: 0.4)
                                  : borderColor,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(CupertinoIcons.creditcard_fill,
                                size: 20,
                                color: _linkedAccountId != null ? AppStyles.accentBlue : secondaryText),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Debit Account', style: TextStyle(fontSize: 13, color: secondaryText)),
                                    Text(
                                      _linkedAccountName ?? 'Tap to select',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: _linkedAccountId != null ? primaryText : secondaryText,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(CupertinoIcons.chevron_right, size: 14, color: secondaryText),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Next due date
                      GestureDetector(
                        onTap: _pickDate,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: borderColor),
                          ),
                          child: Row(
                            children: [
                              Icon(CupertinoIcons.calendar, size: 20, color: AppStyles.accentBlue),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Next Due Date', style: TextStyle(fontSize: 13, color: secondaryText)),
                                    Text(
                                      DateFormatter.format(_nextDueDate),
                                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: primaryText),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(CupertinoIcons.chevron_right, size: 14, color: secondaryText),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Info box
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppStyles.accentBlue.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppStyles.accentBlue.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(CupertinoIcons.info_circle, size: 14, color: AppStyles.accentBlue),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'When the due date is within 7 days, you\'ll see a reminder in Notifications → Upcoming with options to Pay Now or Skip.',
                                style: TextStyle(fontSize: 11, color: AppStyles.accentBlue, height: 1.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            // Save button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GestureDetector(
                onTap: _save,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: AppStyles.teal(context),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      _mandateEnabled ? 'Save Mandate' : 'Disable Mandate',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
