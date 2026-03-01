import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/account_model.dart';
import 'package:vittara_fin_os/logic/accounts_controller.dart';
import 'package:vittara_fin_os/logic/investment_model.dart';
import 'package:vittara_fin_os/logic/investments_controller.dart';
import 'package:vittara_fin_os/models/mutual_fund_model.dart';
import 'package:vittara_fin_os/ui/manage/mf/mf_wizard.dart';
import 'package:vittara_fin_os/ui/manage/mf/mf_wizard_controller.dart';
import 'package:vittara_fin_os/ui/manage/mf/sip_wizard.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/widgets/common_widgets.dart';
import 'package:vittara_fin_os/ui/widgets/toast_notification.dart';

class MFDetailsScreen extends StatelessWidget {
  final Investment investment;

  const MFDetailsScreen({super.key, required this.investment});

  @override
  Widget build(BuildContext context) {
    final metadata = investment.metadata ?? {};
    final investedAmount =
        (metadata['investmentAmount'] as num?)?.toDouble() ?? investment.amount;
    final currentValue = (metadata['currentValue'] as num?)?.toDouble() ?? 0;
    final bool sipActive = metadata['sipActive'] == true;
    final sipActionLabel = sipActive ? 'Manage SIP' : 'SIP';
    final gainLoss = currentValue - investedAmount;
    final gainPercent =
        investedAmount > 0 ? (gainLoss / investedAmount) * 100 : 0;

    return CupertinoPageScaffold(
      backgroundColor: AppStyles.getBackground(context),
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          metadata['schemeName'] as String? ?? investment.name,
          style: TextStyle(color: AppStyles.getTextColor(context)),
          overflow: TextOverflow.ellipsis,
        ),
        previousPageTitle: 'Back',
        backgroundColor: AppStyles.getBackground(context),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Investment Summary Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppStyles.getCardColor(context),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      metadata['schemeName'] as String? ?? investment.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      metadata['fundHouse'] as String? ?? '',
                      style: TextStyle(
                        color: AppStyles.getSecondaryTextColor(context),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Invested',
                              style: TextStyle(
                                color: AppStyles.getSecondaryTextColor(context),
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '₹${investedAmount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Current Value',
                              style: TextStyle(
                                color: AppStyles.getSecondaryTextColor(context),
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '₹${currentValue.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: currentValue >= investedAmount
                                    ? CupertinoColors.systemGreen
                                    : CupertinoColors.systemRed,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Gain/Loss Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: gainPercent >= 0
                      ? CupertinoColors.systemGreen.withValues(alpha: 0.1)
                      : CupertinoColors.systemRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: gainPercent >= 0
                        ? CupertinoColors.systemGreen.withValues(alpha: 0.3)
                        : CupertinoColors.systemRed.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Gain/Loss',
                          style: TextStyle(
                            color: AppStyles.getSecondaryTextColor(context),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${gainLoss >= 0 ? '+' : ''}₹${gainLoss.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: gainLoss >= 0
                                ? CupertinoColors.systemGreen
                                : CupertinoColors.systemRed,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Return %',
                          style: TextStyle(
                            color: AppStyles.getSecondaryTextColor(context),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${gainPercent >= 0 ? '+' : ''}${gainPercent.toStringAsFixed(2)}%',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: gainPercent >= 0
                                ? CupertinoColors.systemGreen
                                : CupertinoColors.systemRed,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Details Section
              Text(
                'Investment Details',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppStyles.getTextColor(context),
                ),
              ),
              const SizedBox(height: 12),
              _buildDetailRow(
                  'Units',
                  (metadata['units'] as num?)?.toDouble().toStringAsFixed(4) ??
                      '-'),
              _buildDetailRow('NAV @ Purchase',
                  '₹${(metadata['investmentNAV'] as num?)?.toDouble().toStringAsFixed(2) ?? '-'}'),
              _buildDetailRow('Current NAV',
                  '₹${(metadata['currentNAV'] as num?)?.toDouble().toStringAsFixed(2) ?? '-'}'),
              _buildDetailRow(
                  'Scheme Type', metadata['schemeType'] as String? ?? '-'),
              _buildDetailRow(
                  'Scheme Code', metadata['schemeCode'] as String? ?? '-'),

              if (metadata['investmentDate'] != null) ...[
                _buildDetailRow(
                  'Investment Date',
                  _formatDate(metadata['investmentDate'] as String),
                ),
              ],

              if (metadata['sipActive'] == true) ...[
                const SizedBox(height: 20),
                Text(
                  'SIP Details',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppStyles.getTextColor(context),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: SemanticColors.investments.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: SemanticColors.investments.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    'This investment has an active SIP setup.',
                    style: TextStyle(
                      color: AppStyles.getSecondaryTextColor(context),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 20),

              Text(
                'Actions',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppStyles.getTextColor(context),
                ),
              ),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: Spacing.lg,
                crossAxisSpacing: Spacing.lg,
                childAspectRatio: 1.1,
                children: [
                  _buildActionButton(
                    context,
                    icon: CupertinoIcons.plus_circle_fill,
                    label: 'Buy More',
                    color: CupertinoColors.systemGreen,
                    onTap: () => _showBuyMoreWizard(context),
                  ),
                  _buildActionButton(
                    context,
                    icon: CupertinoIcons.minus_circle_fill,
                    label: 'Sell',
                    color: CupertinoColors.systemRed,
                    onTap: () => _showSellWizard(context),
                  ),
                  _buildActionButton(
                    context,
                    icon: CupertinoIcons.repeat,
                    label: 'SIP',
                    color: CupertinoColors.systemBlue,
                    onTap: () => _handleSIPAction(context),
                  ),
                  _buildActionButton(
                    context,
                    icon: CupertinoIcons.pencil_circle_fill,
                    label: 'Edit',
                    color: CupertinoColors.systemOrange,
                    onTap: () => _showEditModal(context),
                  ),
                  _buildActionButton(
                    context,
                    icon: CupertinoIcons.money_dollar_circle_fill,
                    label: 'Dividend',
                    color: CupertinoColors.systemBrown,
                    onTap: () => _showDividendModal(context),
                  ),
                  _buildActionButton(
                    context,
                    icon: CupertinoIcons.trash_circle_fill,
                    label: 'Delete',
                    color: CupertinoColors.systemRed,
                    onTap: () => _showDeleteConfirmation(context),
                  ),
                ],
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 13),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      const months = [
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
      return '${date.day} ${months[date.month - 1]} ${date.year}';
    } catch (e) {
      return isoDate;
    }
  }

  void _showBuyMoreWizard(BuildContext context) =>
      _launchMFWizard(context, MFWizardMode.buyMore);

  void _showSellWizard(BuildContext context) =>
      _launchMFWizard(context, MFWizardMode.sell);

  void _handleSIPAction(BuildContext context) {
    final metadata = investment.metadata ?? {};
    final sipActive = metadata['sipActive'] == true;

    if (!sipActive) {
      _openSIPWizard(context);
      return;
    }

    showCupertinoModalPopup(
      context: context,
      builder: (_) => CupertinoActionSheet(
        title: const Text('SIP Options'),
        actions: [
          CupertinoActionSheetAction(
            child: const Text('Edit SIP'),
            onPressed: () {
              Navigator.pop(context);
              final account = _resolveSIPAccount(context, metadata);
              _openSIPWizard(
                context,
                initialData: metadata['sipData'] as Map<String, dynamic>?,
                initialAccount: account,
              );
            },
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            child: const Text('Stop SIP'),
            onPressed: () {
              Navigator.pop(context);
              _stopSIP(context);
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: const Text('Cancel'),
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }

  Future<void> _openSIPWizard(
    BuildContext context, {
    Map<String, dynamic>? initialData,
    Account? initialAccount,
  }) async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      CupertinoPageRoute(
        builder: (_) => SIPWizard(
          initialData: initialData,
          initialAccount: initialAccount,
        ),
      ),
    );
    if (result == null) return;

    final controller =
        Provider.of<InvestmentsController>(context, listen: false);
    final metadata = Map<String, dynamic>.from(investment.metadata ?? {});
    metadata['sipActive'] = true;
    metadata['sipData'] = result;
    metadata['sipUpdatedAt'] = DateTime.now().toIso8601String();
    final nowIso = DateTime.now().toIso8601String();
    metadata['sipLastExecutionDate'] = nowIso;
    metadata['sipStartDate'] = metadata['sipStartDate'] ?? nowIso;
    final executionLog =
        (metadata['sipExecutionLog'] as List?)?.cast<Map<String, dynamic>>() ??
            [];
    executionLog.add({
      'action': 'updated',
      'date': nowIso,
      'amount': result['sipAmount'],
      'frequency': result['frequency'],
    });
    metadata['sipExecutionLog'] = executionLog;

    final updatedInvestment = investment.copyWith(metadata: metadata);
    controller.updateInvestment(updatedInvestment);
    if (context.mounted) {
      toast.showSuccess('SIP configuration saved');
    }
  }

  void _stopSIP(BuildContext context) {
    final metadata = Map<String, dynamic>.from(investment.metadata ?? {});
    if (metadata['sipActive'] != true) return;

    metadata['sipActive'] = false;
    metadata.remove('sipData');
    metadata.remove('sipLinkedAccount');
    metadata.remove('sipFrequency');
    metadata.remove('sipStartDate');
    metadata.remove('sipLastExecutionDate');
    metadata.remove('sipExecutionLog');

    final updatedInvestment = investment.copyWith(metadata: metadata);
    Provider.of<InvestmentsController>(context, listen: false)
        .updateInvestment(updatedInvestment);
    if (context.mounted) {
      toast.showSuccess('SIP stopped for this fund');
    }
  }

  void _showEditModal(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (_) => _EditMFModal(investment: investment),
    );
  }

  void _showDividendModal(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (_) => _MFDividendModal(investment: investment),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Delete Investment'),
        content: const Text(
            'Are you sure you want to delete this mutual fund investment?'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(ctx),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Delete'),
            onPressed: () {
              Provider.of<InvestmentsController>(context, listen: false)
                  .removeInvestment(investment.id);
              Navigator.pop(ctx);
              Navigator.pop(context);
              toast.showSuccess('Investment deleted');
            },
          ),
        ],
      ),
    );
  }

  Future<void> _launchMFWizard(BuildContext context, MFWizardMode mode) async {
    final metadata = investment.metadata ?? {};
    final mutualFund = _buildMutualFund(metadata);
    final nav = _extractNav(metadata);
    final units = (metadata['units'] as num?)?.toDouble();
    final account = _resolveLinkedAccount(context, metadata);

    final intent = MFWizardIntent(
      mode: mode,
      mutualFund: mutualFund,
      transactionAmount: 0,
      transactionNav: nav,
      transactionDate: DateTime.now(),
      targetInvestment: investment,
      account: account,
      transactionUnits: mode == MFWizardMode.sell ? units : null,
      initialStep: 3,
    );

    await Navigator.of(context).push(
      CupertinoPageRoute(builder: (_) => MFWizard(intent: intent)),
    );
  }

  MutualFund _buildMutualFund(Map<String, dynamic> metadata) {
    return MutualFund(
      schemeCode: metadata['schemeCode'] as String? ?? investment.id,
      schemeName: metadata['schemeName'] as String? ?? investment.name,
      schemeType: metadata['schemeType'] as String?,
      fundHouse: metadata['fundHouse'] as String?,
      nav: (metadata['currentNAV'] as num?)?.toDouble() ??
          (metadata['investmentNAV'] as num?)?.toDouble(),
    );
  }

  double _extractNav(Map<String, dynamic> metadata) {
    return (metadata['currentNAV'] as num?)?.toDouble() ??
        (metadata['investmentNAV'] as num?)?.toDouble() ??
        0;
  }

  Account? _resolveSIPAccount(
      BuildContext context, Map<String, dynamic> metadata) {
    final accountId = (metadata['sipData']
            as Map<String, dynamic>?)?['deductionAccountId'] as String? ??
        metadata['sipLinkedAccount'] as String?;
    if (accountId == null) return null;
    final accounts =
        Provider.of<AccountsController>(context, listen: false).accounts;
    for (final account in accounts) {
      if (account.id == accountId) {
        return account;
      }
    }
    return null;
  }

  Account? _resolveLinkedAccount(
      BuildContext context, Map<String, dynamic> metadata) {
    final accountId = metadata['accountId'] as String?;
    if (accountId == null) return null;
    final accounts =
        Provider.of<AccountsController>(context, listen: false).accounts;
    for (final account in accounts) {
      if (account.id == accountId) return account;
    }
    return null;
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: AppStyles.cardDecoration(context),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 28, color: color),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: AppStyles.getTextColor(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MFDividendModal extends StatefulWidget {
  final Investment investment;

  const _MFDividendModal({required this.investment});

  @override
  State<_MFDividendModal> createState() => _MFDividendModalState();
}

class _MFDividendModalState extends State<_MFDividendModal> {
  late TextEditingController _amountController;
  DateTime _dividendDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _pickDate() {
    showCupertinoModalPopup(
      context: context,
      builder: (_) => Container(
        height: 216,
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: SafeArea(
          top: false,
          child: CupertinoDatePicker(
            mode: CupertinoDatePickerMode.date,
            initialDateTime: _dividendDate,
            onDateTimeChanged: (value) => setState(() => _dividendDate = value),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountController.text) ?? 0;
    if (amount <= 0) return;

    final controller = Provider.of<InvestmentsController>(
      context,
      listen: false,
    );
    await controller.recordInvestmentActivity(
      investmentId: widget.investment.id,
      type: 'dividend',
      amount: amount,
      description: 'Dividend from ${widget.investment.name}',
      dateTime: _dividendDate,
    );
    if (!mounted) return;
    toast.showSuccess('Dividend ₹${amount.toStringAsFixed(2)} recorded');
    Navigator.of(context).pop();
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
          children: [
            const ModalHandle(),
            SizedBox(height: Spacing.lg),
            Text(
              'Dividend',
              style: AppStyles.titleStyle(context).copyWith(fontSize: 22),
            ),
            SizedBox(height: Spacing.xxxl),
            _buildField(context, 'Amount', prefix: '₹'),
            SizedBox(height: Spacing.lg),
            _buildDateField(context),
            SizedBox(height: Spacing.xl),
            SizedBox(
              width: double.infinity,
              child: CupertinoButton.filled(
                onPressed: _submit,
                child: const Text('Record Dividend'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(BuildContext context, String label, {String? prefix}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                color: AppStyles.getTextColor(context),
                fontWeight: FontWeight.w600)),
        SizedBox(height: Spacing.xs),
        CupertinoTextField(
          controller: _amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppStyles.getBackground(context),
            borderRadius: BorderRadius.circular(12),
          ),
          prefix: prefix != null
              ? Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Text(prefix,
                      style: TextStyle(color: AppStyles.getTextColor(context))),
                )
              : null,
          style: TextStyle(color: AppStyles.getTextColor(context)),
        ),
      ],
    );
  }

  Widget _buildDateField(BuildContext context) {
    final label =
        '${_dividendDate.day}/${_dividendDate.month}/${_dividendDate.year}';
    return GestureDetector(
      onTap: _pickDate,
      child: Container(
        padding:
            EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.sm),
        decoration: BoxDecoration(
          color: AppStyles.getBackground(context),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Dividend Date',
                style: TextStyle(
                    color: AppStyles.getTextColor(context),
                    fontWeight: FontWeight.w600)),
            Text(label,
                style:
                    TextStyle(color: AppStyles.getSecondaryTextColor(context))),
          ],
        ),
      ),
    );
  }
}

class _EditMFModal extends StatefulWidget {
  final Investment investment;

  const _EditMFModal({required this.investment});

  @override
  State<_EditMFModal> createState() => _EditMFModalState();
}

class _EditMFModalState extends State<_EditMFModal> {
  late TextEditingController _amountController;
  late TextEditingController _navController;
  late TextEditingController _unitsController;

  @override
  void initState() {
    super.initState();
    final metadata = widget.investment.metadata ?? {};
    _amountController = TextEditingController(
      text: (metadata['investmentAmount'] as num?)?.toStringAsFixed(2) ??
          widget.investment.amount.toStringAsFixed(2),
    );
    _navController = TextEditingController(
      text: (metadata['investmentNAV'] as num?)?.toStringAsFixed(4) ?? '',
    );
    _unitsController = TextEditingController(
      text: (metadata['units'] as num?)?.toStringAsFixed(4) ?? '',
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _navController.dispose();
    _unitsController.dispose();
    super.dispose();
  }

  void _saveChanges() {
    final investmentAmount =
        double.tryParse(_amountController.text) ?? widget.investment.amount;
    final investmentNav = double.tryParse(_navController.text) ??
        (widget.investment.metadata?['investmentNAV'] as num?)?.toDouble() ??
        0;
    final units = double.tryParse(_unitsController.text) ??
        (widget.investment.metadata?['units'] as num?)?.toDouble() ??
        0;

    final metadata =
        Map<String, dynamic>.from(widget.investment.metadata ?? {});
    metadata['investmentAmount'] = investmentAmount;
    metadata['investmentNAV'] = investmentNav;
    metadata['units'] = units;
    metadata['currentValue'] = investmentNav * units;

    final updatedInvestment = widget.investment
        .copyWith(amount: investmentAmount, metadata: metadata);

    Provider.of<InvestmentsController>(context, listen: false)
        .updateInvestment(updatedInvestment);
    toast.showSuccess('Mutual fund updated');
    Navigator.of(context).pop();
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
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ModalHandle(),
              SizedBox(height: Spacing.lg),
              Text(
                'Edit Mutual Fund',
                style: AppStyles.titleStyle(context).copyWith(fontSize: 22),
              ),
              SizedBox(height: Spacing.xxxl),
              _buildInputField(context, 'Investment Amount', _amountController,
                  prefix: '₹'),
              SizedBox(height: Spacing.lg),
              _buildInputField(context, 'Average NAV', _navController),
              SizedBox(height: Spacing.lg),
              _buildInputField(context, 'Units', _unitsController),
              SizedBox(height: Spacing.xl),
              SizedBox(
                width: double.infinity,
                child: CupertinoButton.filled(
                  onPressed: _saveChanges,
                  child: const Text('Save Changes'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputField(
    BuildContext context,
    String label,
    TextEditingController controller, {
    String? prefix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                color: AppStyles.getTextColor(context),
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        CupertinoTextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          placeholder: '0.00',
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppStyles.getBackground(context),
            borderRadius: BorderRadius.circular(12),
          ),
          prefix: prefix != null
              ? Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Text(prefix,
                      style: TextStyle(color: AppStyles.getTextColor(context))),
                )
              : null,
          style: TextStyle(color: AppStyles.getTextColor(context)),
        ),
      ],
    );
  }
}
