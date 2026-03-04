import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/fixed_deposit_model.dart';
import 'package:vittara_fin_os/logic/investments_controller.dart';
import 'package:vittara_fin_os/logic/investment_model.dart';
import 'package:vittara_fin_os/utils/date_formatter.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/widgets/toast_notification.dart';

/// Edit modal for modifying FD investment details
/// Allows editing: name, notes, bank details (non-critical fields)
/// Preserves investment history and critical financial data
class FDEditModal extends StatefulWidget {
  final FixedDeposit fd;
  final Investment originalInvestment;

  const FDEditModal({
    required this.fd,
    required this.originalInvestment,
    super.key,
  });

  @override
  State<FDEditModal> createState() => _FDEditModalState();
}

class _FDEditModalState extends State<FDEditModal> {
  late TextEditingController _nameController;
  late TextEditingController _notesController;
  late TextEditingController _bankNameController;
  late TextEditingController _bankAccountController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.fd.name);
    _notesController = TextEditingController(text: widget.fd.notes ?? '');
    _bankNameController = TextEditingController(text: widget.fd.bankName ?? '');
    _bankAccountController =
        TextEditingController(text: widget.fd.bankAccountNumber ?? '');
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
          middle: const Text('Edit FD'),
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
                        'You can edit basic details. Financial data like principal and interest rate cannot be changed to preserve investment history.',
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

              // FD Name
              _buildLabel('FD Name'),
              SizedBox(height: Spacing.sm),
              CupertinoTextField(
                controller: _nameController,
                placeholder: 'Enter FD name',
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
                placeholder: 'Add notes about this FD',
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
                    _buildReadOnlyRow('Principal',
                        '₹${widget.fd.principal.toStringAsFixed(2)}'),
                    _buildReadOnlyRow(
                        'Interest Rate', '${widget.fd.interestRate}% p.a.'),
                    _buildReadOnlyRow(
                        'Tenure', '${widget.fd.tenureMonths} months'),
                    _buildReadOnlyRow('Investment Date',
                        _formatDate(widget.fd.investmentDate)),
                    _buildReadOnlyRow(
                        'Maturity Date', _formatDate(widget.fd.maturityDate)),
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
      toast.showError('FD name cannot be empty');
      return;
    }

    try {
      final investmentsController =
          Provider.of<InvestmentsController>(context, listen: false);

      // Create updated FD with new details
      final updatedFD = widget.fd.copyWith(
        name: _nameController.text.trim(),
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
          'fdData': updatedFD.toMap(),
          'lastEditedAt': DateTime.now().toIso8601String(),
        },
      );

      await investmentsController.updateInvestment(updatedInvestment);

      if (mounted) {
        toast.showSuccess('FD details updated successfully');
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      toast.showError('Failed to update FD: $e');
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
