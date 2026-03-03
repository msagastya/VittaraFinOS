import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/investment_model.dart';
import 'package:vittara_fin_os/logic/investments_controller.dart';
import 'package:vittara_fin_os/logic/nps_model.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/widgets/toast_notification.dart';

class NPSDetailsScreen extends StatefulWidget {
  final Investment investment;

  const NPSDetailsScreen({super.key, required this.investment});

  @override
  State<NPSDetailsScreen> createState() => _NPSDetailsScreenState();
}

class _NPSDetailsScreenState extends State<NPSDetailsScreen> {
  late NPSAccount nps;

  @override
  void initState() {
    super.initState();
    final meta = widget.investment.metadata ?? {};
    nps = NPSAccount.fromMap(meta['npsData'] as Map<String, dynamic>? ?? {});
  }

  @override
  Widget build(BuildContext context) {
    final investmentsCtrl =
        Provider.of<InvestmentsController>(context, listen: false);
    final isPositive = nps.gainLoss >= 0;

    return CupertinoPageScaffold(
      backgroundColor: AppStyles.getBackground(context),
      navigationBar: CupertinoNavigationBar(
        middle: Text('${nps.name} - NPS',
            style: TextStyle(color: AppStyles.getTextColor(context))),
        backgroundColor: AppStyles.getBackground(context),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Spacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DetailCard(
                title: 'Account Information',
                children: [
                  _DetailRow('Subscriber', nps.name),
                  _DetailRow('PRN', nps.prnNumber),
                  _DetailRow('NPS Manager', nps.npsManager.displayName),
                  _DetailRow('Account Type', nps.getAccountTypeLabel()),
                  _DetailRow('Tier', nps.getTierLabel()),
                  _DetailRow('Scheme', nps.getSchemeTypeLabel()),
                ],
              ),
              const SizedBox(height: Spacing.xl),
              _DetailCard(
                title: 'Financial Summary',
                children: [
                  _DetailRow('Total Contributed',
                      '₹${nps.totalContributed.toStringAsFixed(2)}'),
                  _DetailRow('Current Value',
                      '₹${nps.currentValue.toStringAsFixed(2)}',
                      isBold: true),
                  _DetailRow(
                    'Gain/Loss',
                    '${isPositive ? '+' : ''}₹${nps.gainLoss.toStringAsFixed(2)}',
                    isGainLoss: true,
                    isPositive: isPositive,
                  ),
                  _DetailRow(
                    'Return %',
                    '${isPositive ? '+' : ''}${nps.gainLossPercent.toStringAsFixed(2)}%',
                    isGainLoss: true,
                    isPositive: isPositive,
                    isBold: true,
                  ),
                ],
              ),
              const SizedBox(height: Spacing.xl),
              _DetailCard(
                title: 'Tax Benefits',
                children: [
                  _DetailRow('80C Benefit',
                      '₹${nps.tax80cBenefit.toStringAsFixed(2)}'),
                  _DetailRow('80CCD Benefit',
                      '₹${nps.tax80CCDBenefit.toStringAsFixed(2)}'),
                  _DetailRow('Total Tax Saving',
                      '₹${((nps.tax80cBenefit + nps.tax80CCDBenefit) * 0.30).toStringAsFixed(2)}',
                      note: '@30% tax rate'),
                ],
              ),
              const SizedBox(height: Spacing.xl),
              _DetailCard(
                title: 'Withdrawal Strategy',
                children: [
                  _DetailRow('Strategy', nps.getWithdrawalTypeLabel()),
                  if (nps.plannedRetirementDate != null) ...[
                    _DetailRow(
                      'Planned Retirement',
                      '${nps.plannedRetirementDate!.year}',
                    ),
                    _DetailRow(
                      'Years to Retirement',
                      '${nps.yearsUntilRetirement} years',
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: CupertinoButton.filled(
                  onPressed: () {
                    toast.showInfo('Edit functionality coming soon!');
                  },
                  child: const Text('Edit Account'),
                ),
              ),
              const SizedBox(height: Spacing.md),
              SizedBox(
                width: double.infinity,
                child: CupertinoButton(
                  color: CupertinoColors.systemRed.withValues(alpha: 0.1),
                  onPressed: () {
                    showCupertinoDialog(
                      context: context,
                      builder: (ctx) => CupertinoAlertDialog(
                        title: const Text('Delete NPS Account'),
                        content: const Text('Are you sure?'),
                        actions: [
                          CupertinoDialogAction(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancel'),
                          ),
                          CupertinoDialogAction(
                            isDestructiveAction: true,
                            onPressed: () async {
                              Navigator.pop(ctx);
                              await investmentsCtrl
                                  .deleteInvestment(widget.investment.id);
                              if (context.mounted) {
                                toast.showSuccess('NPS account deleted!');
                                Navigator.pop(context);
                              }
                            },
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Text('Delete Account',
                      style: TextStyle(color: CupertinoColors.systemRed)),
                ),
              ),
              const SizedBox(height: Spacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _DetailCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Spacing.lg),
      decoration: BoxDecoration(
        color: AppStyles.getCardColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CupertinoColors.systemGrey.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: TypeScale.body)),
          const SizedBox(height: Spacing.lg),
          ...List.generate(
            children.length,
            (i) => Column(
              children: [
                children[i],
                if (i < children.length - 1) const SizedBox(height: Spacing.md),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;
  final bool isGainLoss;
  final bool isPositive;
  final String? note;

  const _DetailRow(
    this.label,
    this.value, {
    this.isBold = false,
    this.isGainLoss = false,
    this.isPositive = true,
    this.note,
  });

  @override
  Widget build(BuildContext context) {
    Color? color;
    if (isGainLoss) {
      color = isPositive ? CupertinoColors.systemGreen : CupertinoColors.systemRed;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    color: AppStyles.getSecondaryTextColor(context),
                    fontSize: TypeScale.subhead)),
            if (note != null)
              Text(note!,
                  style: TextStyle(
                      color: AppStyles.getSecondaryTextColor(context),
                      fontSize: TypeScale.caption)),
          ],
        ),
        Text(value,
            style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
                fontSize: isBold ? 14 : 13,
                color: color)),
      ],
    );
  }
}
