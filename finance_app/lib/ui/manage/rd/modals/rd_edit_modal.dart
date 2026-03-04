import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/recurring_deposit_model.dart';
import 'package:vittara_fin_os/logic/investments_controller.dart';
import 'package:vittara_fin_os/logic/investment_model.dart';
import 'package:vittara_fin_os/utils/date_formatter.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/widgets/toast_notification.dart';

/// Edit modal for modifying RD investment details
/// Allows editing: name, notes, bank details, auto-payment settings
/// Preserves investment history and critical financial data
class RDEditModal extends StatefulWidget {
  final RecurringDeposit rd;
  final Investment originalInvestment;

  const RDEditModal({
    required this.rd,
    required this.originalInvestment,
    super.key,
  });

  @override
  State<RDEditModal> createState() => _RDEditModalState();
}

class _RDEditModalState extends State<RDEditModal> {
  late TextEditingController _nameController;
  late TextEditingController _notesController;
  late TextEditingController _bankNameController;
  late TextEditingController _bankAccountController;
  late bool _autoPaymentEnabled;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.rd.name);
    _notesController = TextEditingController(text: widget.rd.notes ?? '');
    _bankNameController = TextEditingController(text: widget.rd.bankName ?? '');
    _bankAccountController =
        TextEditingController(text: widget.rd.bankAccountNumber ?? '');
    _autoPaymentEnabled = widget.rd.autoPaymentEnabled;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    _bankNameController.dispose();
    _bankAccountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: AppStyles.getBackground(context),
        appBar: CupertinoNavigationBar(
          middle: const Text('Edit RD'),
          previousPageTitle: 'Back',
          backgroundColor: AppStyles.getBackground(context),
          border: null,
          trailing: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: _saveChanges,
            child: Text(
              'Save',
              style: TextStyle(
                color: SemanticColors.getPrimary(context),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.all(Spacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info banner
              Container(
                padding: EdgeInsets.all(Spacing.md),
                decoration: BoxDecoration(
                  color: SemanticColors.getInfo(context).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color:
                        SemanticColors.getInfo(context).withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      CupertinoIcons.info_circle_fill,
                      color: SemanticColors.getInfo(context),
                      size: IconSizes.sm,
                    ),
                    SizedBox(width: Spacing.sm),
                    Expanded(
                      child: Text(
                        'You can edit basic details and settings. Financial data like installment amount and interest rate cannot be changed.',
                        style: TextStyle(
                          color: SemanticColors.getInfo(context),
                          fontSize: TypeScale.footnote,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: Spacing.xl),

              // RD Name
              _buildLabel('RD Name'),
              SizedBox(height: Spacing.sm),
              CupertinoTextField(
                controller: _nameController,
                placeholder: 'Enter RD name',
                style: TextStyle(color: AppStyles.getTextColor(context)),
                decoration: BoxDecoration(
                  color: AppStyles.getCardColor(context),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppStyles.getDividerColor(context),
                  ),
                ),
                padding: EdgeInsets.all(Spacing.md),
              ),
              SizedBox(height: Spacing.lg),

              // Auto-Payment Toggle
              Container(
                padding: EdgeInsets.all(Spacing.lg),
                decoration: BoxDecoration(
                  color: AppStyles.getCardColor(context),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppStyles.getDividerColor(context),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Auto-Payment',
                            style: TextStyle(
                              color: AppStyles.getTextColor(context),
                              fontWeight: FontWeight.w600,
                              fontSize: TypeScale.body,
                            ),
                          ),
                          SizedBox(height: Spacing.xxs),
                          Text(
                            'Auto-debit future installments',
                            style: TextStyle(
                              color: AppStyles.getSecondaryTextColor(context),
                              fontSize: TypeScale.footnote,
                            ),
                          ),
                        ],
                      ),
                    ),
                    CupertinoSwitch(
                      value: _autoPaymentEnabled,
                      onChanged: (value) {
                        setState(() {
                          _autoPaymentEnabled = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
              SizedBox(height: Spacing.lg),

              // Bank Name
              _buildLabel('Bank Name'),
              SizedBox(height: Spacing.sm),
              CupertinoTextField(
                controller: _bankNameController,
                placeholder: 'Enter bank name',
                style: TextStyle(color: AppStyles.getTextColor(context)),
                decoration: BoxDecoration(
                  color: AppStyles.getCardColor(context),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppStyles.getDividerColor(context),
                  ),
                ),
                padding: EdgeInsets.all(Spacing.md),
              ),
              SizedBox(height: Spacing.lg),

              // Bank Account Number
              _buildLabel('Bank Account Number'),
              SizedBox(height: Spacing.sm),
              CupertinoTextField(
                controller: _bankAccountController,
                placeholder: 'Enter account number',
                style: TextStyle(color: AppStyles.getTextColor(context)),
                decoration: BoxDecoration(
                  color: AppStyles.getCardColor(context),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppStyles.getDividerColor(context),
                  ),
                ),
                padding: EdgeInsets.all(Spacing.md),
              ),
              SizedBox(height: Spacing.lg),

              // Notes
              _buildLabel('Notes (Optional)'),
              SizedBox(height: Spacing.sm),
              CupertinoTextField(
                controller: _notesController,
                placeholder: 'Add notes about this RD',
                style: TextStyle(color: AppStyles.getTextColor(context)),
                maxLines: 4,
                decoration: BoxDecoration(
                  color: AppStyles.getCardColor(context),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppStyles.getDividerColor(context),
                  ),
                ),
                padding: EdgeInsets.all(Spacing.md),
              ),
              SizedBox(height: Spacing.xl),

              // Read-only information section
              Text(
                'Investment Details (Read-only)',
                style: TextStyle(
                  color: AppStyles.getSecondaryTextColor(context),
                  fontSize: TypeScale.footnote,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: Spacing.md),
              Container(
                padding: EdgeInsets.all(Spacing.lg),
                decoration: BoxDecoration(
                  color: AppStyles.getCardColor(context).withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppStyles.getDividerColor(context),
                  ),
                ),
                child: Column(
                  children: [
                    _buildReadOnlyRow('Monthly Amount',
                        '₹${widget.rd.monthlyAmount.toStringAsFixed(2)}'),
                    _buildReadOnlyRow(
                        'Interest Rate', '${widget.rd.interestRate}% p.a.'),
                    _buildReadOnlyRow(
                        'Total Installments', '${widget.rd.totalInstallments}'),
                    _buildReadOnlyRow(
                        'Start Date', _formatDate(widget.rd.startDate)),
                    _buildReadOnlyRow(
                        'Maturity Date', _formatDate(widget.rd.maturityDate)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        color: AppStyles.getTextColor(context),
        fontSize: TypeScale.body,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildReadOnlyRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: Spacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppStyles.getSecondaryTextColor(context),
              fontSize: TypeScale.footnote,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: AppStyles.getSecondaryTextColor(context),
              fontSize: TypeScale.footnote,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveChanges() async {
    if (_nameController.text.trim().isEmpty) {
      toast.showError('RD name cannot be empty');
      return;
    }

    try {
      final investmentsController =
          Provider.of<InvestmentsController>(context, listen: false);

      // Create updated RD with new details
      final updatedRD = widget.rd.copyWith(
        name: _nameController.text.trim(),
        autoPaymentEnabled: _autoPaymentEnabled,
        bankName: _bankNameController.text.trim().isEmpty
            ? null
            : _bankNameController.text.trim(),
        bankAccountNumber: _bankAccountController.text.trim().isEmpty
            ? null
            : _bankAccountController.text.trim(),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );

      // Update the investment
      final updatedInvestment = widget.originalInvestment.copyWith(
        name: _nameController.text.trim(),
        metadata: {
          ...?widget.originalInvestment.metadata,
          'rdData': updatedRD.toMap(),
          'autoPayment': _autoPaymentEnabled,
          'lastEditedAt': DateTime.now().toIso8601String(),
        },
      );

      await investmentsController.updateInvestment(updatedInvestment);

      if (mounted) {
        toast.showSuccess('RD details updated successfully');
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      toast.showError('Failed to update RD: $e');
    }
  }

  String _formatDate(DateTime date) {
    final months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${date.day} ${DateFormatter.getMonthName(date.month)} ${date.year}';
  }
}
