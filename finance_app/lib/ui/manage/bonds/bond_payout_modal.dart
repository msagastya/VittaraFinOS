import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/bond_payout_generator.dart';
import 'package:vittara_fin_os/logic/account_model.dart';
import 'package:vittara_fin_os/logic/accounts_controller.dart';
import 'package:vittara_fin_os/logic/investment_model.dart';
import 'package:vittara_fin_os/logic/investments_controller.dart';
import 'package:vittara_fin_os/logic/notification_helpers.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/widgets/common_widgets.dart';
import 'package:vittara_fin_os/ui/widgets/toast_notification.dart';

class BondPayoutModal extends StatefulWidget {
  final Investment bond;
  final BondPayoutNotificationInfo notification;

  const BondPayoutModal({
    required this.bond,
    required this.notification,
    super.key,
  });

  @override
  State<BondPayoutModal> createState() => _BondPayoutModalState();
}

class _BondPayoutModalState extends State<BondPayoutModal> {
  late TextEditingController _amountController;
  late DateTime _selectedDate;
  String? _selectedAccountId;
  String? _selectedAccountName;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController();
    _selectedDate = widget.notification.schedule.payoutDate;
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _showAccountSelector(BuildContext context) {
    final accountsController =
        Provider.of<AccountsController>(context, listen: false);
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppStyles.getCardColor(context),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: Spacing.lg),
                Text('Select Account', style: AppStyles.titleStyle(context)),
                const SizedBox(height: Spacing.sm),
                Column(
                  children: accountsController.accounts.map((account) {
                    final isSelected = _selectedAccountId == account.id;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedAccountId = account.id;
                          _selectedAccountName = account.name;
                        });
                        Navigator.pop(ctx);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.blue.withOpacity(0.1)
                              : AppStyles.getBackground(context),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color:
                                isSelected ? Colors.blue : Colors.transparent,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    account.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14),
                                  ),
                                  Text(
                                    account.bankName,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppStyles.getSecondaryTextColor(
                                          context),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected)
                              const Icon(
                                  CupertinoIcons.checkmark_alt_circle_fill,
                                  color: Colors.blue),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: Spacing.lg),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDatePicker(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => Container(
        height: 300,
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppStyles.getCardColor(context),
                border: Border(
                    bottom: BorderSide(color: Colors.grey.withOpacity(0.2))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Select Date', style: AppStyles.titleStyle(context)),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: const Icon(CupertinoIcons.xmark),
                  ),
                ],
              ),
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: _selectedDate,
                onDateTimeChanged: (value) =>
                    setState(() => _selectedDate = value),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _savePayout() async {
    final investmentsController =
        Provider.of<InvestmentsController>(context, listen: false);
    try {
      final payoutRecord = BondPayoutRecord(
        payoutNumber: widget.notification.schedule.payoutNumber,
        scheduledPayoutDate: widget.notification.schedule.payoutDate,
        payoutAmount: double.parse(_amountController.text),
        actualPayoutDate: _selectedDate,
        creditAccountId: _selectedAccountId,
        creditAccountName: _selectedAccountName,
        recordedDate: DateTime.now(),
      );

      final updatedMetadata =
          Map<String, dynamic>.from(widget.bond.metadata ?? {});
      final pastPayouts = (updatedMetadata['pastPayouts'] as List?)
              ?.cast<Map<String, dynamic>>() ??
          [];
      pastPayouts.add(payoutRecord.toMap());
      updatedMetadata['pastPayouts'] = pastPayouts;

      final updatedBond = widget.bond.copyWith(metadata: updatedMetadata);
      await investmentsController.updateInvestment(updatedBond);

      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payout recorded successfully!')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppStyles.getCardColor(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ModalHandle(),
            const SizedBox(height: Spacing.lg),
            Text('Record Bond Payout',
                style: AppStyles.titleStyle(context).copyWith(fontSize: 22)),
            const SizedBox(height: Spacing.xxxl),
            Text('Payout Amount',
                style:
                    TextStyle(color: AppStyles.getSecondaryTextColor(context))),
            const SizedBox(height: Spacing.xs),
            CupertinoTextField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              placeholder: '0.00',
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppStyles.getBackground(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.withOpacity(0.2)),
              ),
              prefix: const Padding(
                padding: EdgeInsets.only(left: 12),
                child: Text('₹'),
              ),
            ),
            const SizedBox(height: Spacing.lg),
            Text('Payout Date',
                style:
                    TextStyle(color: AppStyles.getSecondaryTextColor(context))),
            const SizedBox(height: Spacing.xs),
            GestureDetector(
              onTap: () => _showDatePicker(context),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppStyles.getBackground(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                      style: TextStyle(color: AppStyles.getTextColor(context)),
                    ),
                    const Icon(CupertinoIcons.calendar),
                  ],
                ),
              ),
            ),
            const SizedBox(height: Spacing.lg),
            Text('Debit Account',
                style:
                    TextStyle(color: AppStyles.getSecondaryTextColor(context))),
            const SizedBox(height: Spacing.xs),
            GestureDetector(
              onTap: () => _showAccountSelector(context),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppStyles.getBackground(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        _selectedAccountName ?? 'Select account',
                        style: TextStyle(
                          color: _selectedAccountName == null
                              ? AppStyles.getSecondaryTextColor(context)
                              : AppStyles.getTextColor(context),
                          fontWeight: _selectedAccountName != null
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                    const Icon(CupertinoIcons.down_arrow),
                  ],
                ),
              ),
            ),
            const SizedBox(height: Spacing.xl),
            SizedBox(
              width: double.infinity,
              child: CupertinoButton.filled(
                onPressed:
                    _selectedAccountId == null || _amountController.text.isEmpty
                        ? null
                        : _savePayout,
                child: const Text('Save Payout'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
