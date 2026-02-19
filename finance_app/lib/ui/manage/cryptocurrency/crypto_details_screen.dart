import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/investment_model.dart';
import 'package:vittara_fin_os/logic/investments_controller.dart';
import 'package:vittara_fin_os/models/cryptocurrency_model.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/widgets/toast_notification.dart';

class CryptoDetailsScreen extends StatefulWidget {
  final Investment investment;

  const CryptoDetailsScreen({
    super.key,
    required this.investment,
  });

  @override
  State<CryptoDetailsScreen> createState() => _CryptoDetailsScreenState();
}

class _CryptoDetailsScreenState extends State<CryptoDetailsScreen> {
  late Cryptocurrency crypto;

  @override
  void initState() {
    super.initState();
    _reconstructCrypto();
  }

  void _reconstructCrypto() {
    final metadata = widget.investment.metadata ?? {};

    // Reconstruct transactions from metadata
    final transactions = (metadata['transactions'] as List?)
            ?.map((t) => CryptoTransaction.fromMap(t as Map<String, dynamic>))
            .toList() ??
        [];

    crypto = Cryptocurrency(
      id: widget.investment.id,
      name: metadata['name'] as String? ?? 'Unknown',
      cryptoType: CryptoCurrency.values.asMap()[0] ?? CryptoCurrency.bitcoin,
      symbol: metadata['symbol'] as String? ?? 'N/A',
      totalQuantity: (metadata['quantity'] as num?)?.toDouble() ?? 0,
      averageBuyPrice: (metadata['averageBuyPrice'] as num?)?.toDouble() ?? 0,
      totalInvested: (metadata['totalInvested'] as num?)?.toDouble() ?? 0,
      currentPrice: (metadata['currentPrice'] as num?)?.toDouble() ?? 0,
      lastPriceUpdate: DateTime.parse(
        metadata['lastUpdated'] as String? ?? DateTime.now().toIso8601String(),
      ),
      transactions: transactions,
      walletType: CryptoWalletType.values[int.tryParse(
            metadata['walletType']?.toString().split('.').last ?? '0',
          ) ??
          0],
      walletAddress: metadata['walletAddress'] as String? ?? '',
      exchange: metadata['exchange'] != null
          ? CryptoExchange.values[int.tryParse(
                metadata['exchange']?.toString().split('.').last ?? '0',
              ) ??
              0]
          : null,
      createdDate: DateTime.now(),
      notes: metadata['notes'] as String?,
      metadata: metadata,
    );
  }

  @override
  Widget build(BuildContext context) {
    final investmentsController =
        Provider.of<InvestmentsController>(context, listen: false);
    final isProfit = crypto.gainLoss >= 0;

    return CupertinoPageScaffold(
      backgroundColor: AppStyles.getBackground(context),
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          '${crypto.name} (${crypto.symbol})',
          style: TextStyle(color: AppStyles.getTextColor(context)),
        ),
        backgroundColor: AppStyles.getBackground(context),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Holdings Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppStyles.getCardColor(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.grey.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Holdings',
                      style: TextStyle(
                        color: AppStyles.getTextColor(context),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _DetailRow(
                      label: 'Total Quantity',
                      value:
                          '${crypto.totalQuantity.toStringAsFixed(8)} ${crypto.symbol}',
                    ),
                    const SizedBox(height: 8),
                    _DetailRow(
                      label: 'Current Price',
                      value: '₹${crypto.currentPrice.toStringAsFixed(2)}',
                    ),
                    const SizedBox(height: 8),
                    _DetailRow(
                      label: 'Current Value',
                      value: '₹${crypto.currentValue.toStringAsFixed(2)}',
                      isBold: true,
                      color: const Color(0xFFF7931A),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Investment Summary
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppStyles.getCardColor(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.grey.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Investment Summary',
                      style: TextStyle(
                        color: AppStyles.getTextColor(context),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _DetailRow(
                      label: 'Total Invested',
                      value: '₹${crypto.totalInvested.toStringAsFixed(2)}',
                    ),
                    const SizedBox(height: 8),
                    _DetailRow(
                      label: 'Average Buy Price',
                      value: '₹${crypto.averageBuyPrice.toStringAsFixed(2)}',
                    ),
                    const SizedBox(height: 8),
                    _DetailRow(
                      label: 'Gain/Loss',
                      value:
                          '${isProfit ? '+' : ''}₹${crypto.gainLoss.toStringAsFixed(2)}',
                      isGainLoss: true,
                      isPositive: isProfit,
                    ),
                    const SizedBox(height: 8),
                    _DetailRow(
                      label: 'Return %',
                      value:
                          '${isProfit ? '+' : ''}${crypto.gainLossPercent.toStringAsFixed(2)}%',
                      isGainLoss: true,
                      isPositive: isProfit,
                      isBold: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Wallet Information
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppStyles.getCardColor(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.grey.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Wallet Information',
                      style: TextStyle(
                        color: AppStyles.getTextColor(context),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _DetailRow(
                      label: 'Storage Type',
                      value: crypto.getWalletTypeLabel(),
                    ),
                    const SizedBox(height: 8),
                    if (crypto.exchange != null) ...[
                      _DetailRow(
                        label: 'Exchange',
                        value: crypto.getExchangeLabel(),
                      ),
                      const SizedBox(height: 8),
                    ],
                    _DetailRow(
                      label: 'Address/Account',
                      value: crypto.walletAddress,
                      isMonospace: true,
                    ),
                  ],
                ),
              ),
              if (crypto.notes != null && crypto.notes!.isNotEmpty) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppStyles.getCardColor(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.grey.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Notes',
                        style: TextStyle(
                          color: AppStyles.getTextColor(context),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        crypto.notes!,
                        style: TextStyle(
                          color: AppStyles.getSecondaryTextColor(context),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 30),
              // Action Buttons
              SizedBox(
                width: double.infinity,
                child: CupertinoButton.filled(
                  onPressed: () {
                    toast.showInfo('Edit functionality coming soon!');
                  },
                  child: const Text('Edit Holdings'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: CupertinoButton(
                  color: Colors.red.withValues(alpha: 0.1),
                  onPressed: () async {
                    showCupertinoDialog(
                      context: context,
                      builder: (context) => CupertinoAlertDialog(
                        title: const Text('Delete Investment'),
                        content: const Text(
                          'Are you sure you want to delete this cryptocurrency investment?',
                        ),
                        actions: [
                          CupertinoDialogAction(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                          CupertinoDialogAction(
                            isDestructiveAction: true,
                            onPressed: () async {
                              Navigator.pop(context);
                              await investmentsController
                                  .deleteInvestment(widget.investment.id);
                              if (context.mounted) {
                                toast.showSuccess(
                                  'Cryptocurrency investment deleted successfully!',
                                );
                                Navigator.pop(context);
                              }
                            },
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Text(
                    'Delete Investment',
                    style: TextStyle(color: Colors.red),
                  ),
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

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;
  final bool isGainLoss;
  final bool isPositive;
  final bool isMonospace;
  final Color? color;

  const _DetailRow({
    required this.label,
    required this.value,
    this.isBold = false,
    this.isGainLoss = false,
    this.isPositive = true,
    this.isMonospace = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    Color valueColor = color ?? AppStyles.getTextColor(context);
    if (isGainLoss) {
      valueColor = isPositive ? Colors.green : Colors.red;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppStyles.getSecondaryTextColor(context),
            fontSize: 13,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            fontSize: 13,
            fontFamily: isMonospace ? 'monospace' : null,
          ),
          textAlign: TextAlign.end,
        ),
      ],
    );
  }
}
