import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/account_model.dart';
import 'package:vittara_fin_os/logic/accounts_controller.dart';
import 'package:vittara_fin_os/logic/investment_model.dart';
import 'package:vittara_fin_os/logic/investments_controller.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/widgets/toast_notification.dart';

class SimpleInvestmentEntryWizard extends StatefulWidget {
  final InvestmentType type;
  final String title;
  final String subtitle;
  final Color color;
  final String defaultName;
  final String? referenceLabel;
  final String? referenceHint;

  const SimpleInvestmentEntryWizard({
    super.key,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.defaultName,
    this.referenceLabel,
    this.referenceHint,
  });

  @override
  State<SimpleInvestmentEntryWizard> createState() =>
      _SimpleInvestmentEntryWizardState();
}

class _SimpleInvestmentEntryWizardState
    extends State<SimpleInvestmentEntryWizard> {
  late final TextEditingController _nameController;
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _currentValueController = TextEditingController();
  final TextEditingController _referenceController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  DateTime _investmentDate = DateTime.now();
  Account? _linkedAccount;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.defaultName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _currentValueController.dispose();
    _referenceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _investmentDate,
      firstDate: DateTime(2000, 1, 1),
      lastDate: DateTime(2100, 1, 1),
    );
    if (picked == null || !mounted) return;
    setState(() => _investmentDate = picked);
  }

  Future<void> _pickAccount() async {
    final accounts = context
        .read<AccountsController>()
        .accounts
        .where((account) => account.type != AccountType.investment)
        .toList();

    if (accounts.isEmpty) {
      toast.showInfo('No debit account found. Add an account first.');
      return;
    }

    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Select Debit Account'),
        actions: accounts
            .map(
              (account) => CupertinoActionSheetAction(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  setState(() => _linkedAccount = account);
                },
                child: Text(account.name),
              ),
            )
            .toList(),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_isSaving) return;

    final name = _nameController.text.trim();
    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    final currentValue =
        double.tryParse(_currentValueController.text.trim()) ?? amount;
    final reference = _referenceController.text.trim();
    final notes = _notesController.text.trim();

    if (name.isEmpty) {
      toast.showError('Please enter a name.');
      return;
    }
    if (amount <= 0) {
      toast.showError('Please enter a valid invested amount.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final metadata = <String, dynamic>{
        'simpleEntryMode': true,
        'investmentDate': _investmentDate.toIso8601String(),
        'purchaseDate': _investmentDate.toIso8601String(),
        'currentValue': currentValue,
        'investmentAmount': amount,
        'accountId': _linkedAccount?.id,
        'accountName': _linkedAccount?.name,
      };

      if (reference.isNotEmpty) {
        metadata['reference'] = reference;
      }
      if (notes.isNotEmpty) {
        metadata['notes'] = notes;
      }

      if (widget.type == InvestmentType.nationalSavingsScheme) {
        metadata['npsTrackingMode'] = 'standard';
      }
      if (widget.type == InvestmentType.bonds) {
        metadata['bondTrackingMode'] = 'standard';
      }

      final investment = Investment(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: name,
        type: widget.type,
        amount: amount,
        color: widget.color,
        notes: notes.isEmpty ? null : notes,
        broker: _linkedAccount?.bankName,
        metadata: metadata,
      );

      await context.read<InvestmentsController>().addInvestment(investment);

      if (!mounted) return;
      toast.showSuccess('Investment added.');
      Navigator.of(context).pop();
    } catch (error) {
      toast.showError('Failed to add investment: $error');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppStyles.getBackground(context),
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          widget.title,
          style: TextStyle(color: AppStyles.getTextColor(context)),
        ),
        previousPageTitle: 'Back',
        backgroundColor: AppStyles.getBackground(context),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              widget.subtitle,
              style: TextStyle(
                color: AppStyles.getSecondaryTextColor(context),
                fontSize: TypeScale.subhead,
              ),
            ),
            const SizedBox(height: 16),
            _buildField(
              label: 'Name',
              controller: _nameController,
              placeholder: 'Enter name',
            ),
            _buildField(
              label: 'Invested Amount',
              controller: _amountController,
              placeholder: '0.00',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            _buildField(
              label: 'Current Value (Optional)',
              controller: _currentValueController,
              placeholder: '0.00',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            if (widget.referenceLabel != null)
              _buildField(
                label: widget.referenceLabel!,
                controller: _referenceController,
                placeholder: widget.referenceHint ?? '',
              ),
            _buildDateCard(),
            const SizedBox(height: 8),
            _buildAccountCard(),
            const SizedBox(height: 8),
            _buildField(
              label: 'Notes (Optional)',
              controller: _notesController,
              placeholder: 'Add details for future tracking',
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            CupertinoButton.filled(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const CupertinoActivityIndicator(color: Colors.white)
                  : const Text('Save Investment'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required String placeholder,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppStyles.getSecondaryTextColor(context),
              fontSize: TypeScale.footnote,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          CupertinoTextField(
            controller: controller,
            keyboardType: keyboardType,
            placeholder: placeholder,
            maxLines: maxLines,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppStyles.getCardColor(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppStyles.getSecondaryTextColor(context)
                    .withValues(alpha: 0.25),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateCard() {
    return GestureDetector(
      onTap: _pickDate,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppStyles.getCardColor(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppStyles.getSecondaryTextColor(context)
                .withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          children: [
            const Icon(CupertinoIcons.calendar),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Investment Date: ${_formatDate(_investmentDate)}',
                style: TextStyle(color: AppStyles.getTextColor(context)),
              ),
            ),
            const Icon(CupertinoIcons.chevron_right, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountCard() {
    return GestureDetector(
      onTap: _pickAccount,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppStyles.getCardColor(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppStyles.getSecondaryTextColor(context)
                .withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          children: [
            const Icon(CupertinoIcons.creditcard),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _linkedAccount == null
                    ? 'Select Debit Account (Optional)'
                    : 'Debit Account: ${_linkedAccount!.name}',
                style: TextStyle(color: AppStyles.getTextColor(context)),
              ),
            ),
            const Icon(CupertinoIcons.chevron_right, size: 14),
          ],
        ),
      ),
    );
  }
}
