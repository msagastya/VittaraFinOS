import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/investment_model.dart';
import 'package:vittara_fin_os/logic/investments_controller.dart';
import 'package:vittara_fin_os/logic/pension_model.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/widgets/toast_notification.dart';

class PensionDetailsScreen extends StatefulWidget {
  final Investment investment;

  const PensionDetailsScreen({super.key, required this.investment});

  @override
  State<PensionDetailsScreen> createState() => _PensionDetailsScreenState();
}

class _PensionDetailsScreenState extends State<PensionDetailsScreen> {
  late PensionScheme pension;

  @override
  void initState() {
    super.initState();
    final meta = widget.investment.metadata ?? {};
    pension = PensionScheme.fromMap(
        meta['pensionData'] as Map<String, dynamic>? ?? {});
  }

  @override
  Widget build(BuildContext context) {
    final investmentsCtrl =
        Provider.of<InvestmentsController>(context, listen: false);
    final isPositive = pension.gainLoss >= 0;

    return CupertinoPageScaffold(
      backgroundColor: AppStyles.getBackground(context),
      navigationBar: CupertinoNavigationBar(
        middle: Text(pension.getTypeLabel(),
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
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DetailCard(
                title: 'Account Information',
                children: [
                  _DetailRow('Scheme', pension.getTypeLabel()),
                  _DetailRow('Account Number', pension.accountNumber),
                ],
              ),
              const SizedBox(height: 20),
              _DetailCard(
                title: 'Financial Summary',
                children: [
                  _DetailRow('Principal Contributed',
                      '₹${pension.principalContributed.toStringAsFixed(2)}'),
                  _DetailRow('Current Value',
                      '₹${pension.currentValue.toStringAsFixed(2)}',
                      isBold: true),
                  _DetailRow(
                    'Gain/Loss',
                    '${isPositive ? '+' : ''}₹${pension.gainLoss.toStringAsFixed(2)}',
                    isGainLoss: true,
                    isPositive: isPositive,
                  ),
                  _DetailRow(
                    'Return %',
                    '${isPositive ? '+' : ''}${pension.gainLossPercent.toStringAsFixed(2)}%',
                    isGainLoss: true,
                    isPositive: isPositive,
                    isBold: true,
                  ),
                ],
              ),
              if (pension.notes != null && pension.notes!.isNotEmpty) ...[
                const SizedBox(height: 20),
                _DetailCard(
                  title: 'Notes',
                  children: [
                    _DetailRow('', pension.notes ?? ''),
                  ],
                ),
              ],
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
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: CupertinoButton(
                  color: CupertinoColors.systemRed.withValues(alpha: 0.1),
                  onPressed: () {
                    showCupertinoDialog(
                      context: context,
                      builder: (ctx) => CupertinoAlertDialog(
                        title: const Text('Delete Pension Account'),
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
                                toast.showSuccess('Pension account deleted!');
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
              const SizedBox(height: 20),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppStyles.getCardColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CupertinoColors.systemGrey.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 16),
          ...List.generate(
            children.length,
            (i) => Column(
              children: [
                children[i],
                if (i < children.length - 1) const SizedBox(height: 12),
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

  const _DetailRow(
    this.label,
    this.value, {
    this.isBold = false,
    this.isGainLoss = false,
    this.isPositive = true,
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
        Text(label,
            style: TextStyle(
                color: AppStyles.getSecondaryTextColor(context), fontSize: 13)),
        Text(value,
            style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
                fontSize: isBold ? 14 : 13,
                color: color)),
      ],
    );
  }
}
