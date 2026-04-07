import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/investment_model.dart';
import 'package:vittara_fin_os/logic/investments_controller.dart';
import 'package:vittara_fin_os/models/cryptocurrency_model.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/styles/responsive_utils.dart';
import 'package:vittara_fin_os/ui/widgets/common_widgets.dart';
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
  late Investment _investment;
  late Cryptocurrency crypto;

  @override
  void initState() {
    super.initState();
    _investment = widget.investment;
    _reconstructCrypto();
  }

  Investment get investment => _investment;

  void _reconstructCrypto() {
    final metadata = investment.metadata ?? {};

    // Reconstruct transactions from metadata
    final transactions = (metadata['transactions'] as List?)
            ?.map((t) => CryptoTransaction.fromMap(t as Map<String, dynamic>))
            .toList() ??
        [];

    crypto = Cryptocurrency(
      id: investment.id,
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
    // Keep investment in sync with controller for real-time updates
    _investment = context.watch<InvestmentsController>().investments
        .firstWhere((i) => i.id == investment.id, orElse: () => _investment);

    final investmentsController =
        Provider.of<InvestmentsController>(context, listen: false);
    final isProfit = crypto.gainLoss >= 0;

    return CupertinoPageScaffold(
      backgroundColor: AppStyles.getBackground(context),
      navigationBar: AppStyles.isLandscape(context) ? null : CupertinoNavigationBar(
        previousPageTitle: 'Back',
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
        border: null,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Spacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Holdings Card
              Container(
                padding: const EdgeInsets.all(Spacing.lg),
                decoration: BoxDecoration(
                  color: AppStyles.getCardColor(context),
                  borderRadius: BorderRadius.circular(Radii.md),
                  border: Border.all(
                    color: CupertinoColors.systemGrey.withValues(alpha: 0.2),
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
                        fontSize: TypeScale.body,
                      ),
                    ),
                    const SizedBox(height: Spacing.lg),
                    _DetailRow(
                      label: 'Total Quantity',
                      value:
                          '${crypto.totalQuantity.toStringAsFixed(8)} ${crypto.symbol}',
                    ),
                    const SizedBox(height: Spacing.sm),
                    _DetailRow(
                      label: 'Current Price',
                      value: '₹${crypto.currentPrice.toStringAsFixed(2)}',
                    ),
                    const SizedBox(height: Spacing.sm),
                    _DetailRow(
                      label: 'Current Value',
                      value: '₹${crypto.currentValue.toStringAsFixed(2)}',
                      isBold: true,
                      color: const Color(0xFFF7931A),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Spacing.xl),
              // Investment Summary
              Container(
                padding: const EdgeInsets.all(Spacing.lg),
                decoration: BoxDecoration(
                  color: AppStyles.getCardColor(context),
                  borderRadius: BorderRadius.circular(Radii.md),
                  border: Border.all(
                    color: CupertinoColors.systemGrey.withValues(alpha: 0.2),
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
                        fontSize: TypeScale.body,
                      ),
                    ),
                    const SizedBox(height: Spacing.lg),
                    _DetailRow(
                      label: 'Total Invested',
                      value: '₹${crypto.totalInvested.toStringAsFixed(2)}',
                    ),
                    const SizedBox(height: Spacing.sm),
                    _DetailRow(
                      label: 'Average Buy Price',
                      value: '₹${crypto.averageBuyPrice.toStringAsFixed(2)}',
                    ),
                    const SizedBox(height: Spacing.sm),
                    _DetailRow(
                      label: 'Gain/Loss',
                      value:
                          '${isProfit ? '+' : ''}₹${crypto.gainLoss.toStringAsFixed(2)}',
                      isGainLoss: true,
                      isPositive: isProfit,
                    ),
                    const SizedBox(height: Spacing.sm),
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
              const SizedBox(height: Spacing.xl),
              // Wallet Information
              Container(
                padding: const EdgeInsets.all(Spacing.lg),
                decoration: BoxDecoration(
                  color: AppStyles.getCardColor(context),
                  borderRadius: BorderRadius.circular(Radii.md),
                  border: Border.all(
                    color: CupertinoColors.systemGrey.withValues(alpha: 0.2),
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
                        fontSize: TypeScale.body,
                      ),
                    ),
                    const SizedBox(height: Spacing.lg),
                    _DetailRow(
                      label: 'Storage Type',
                      value: crypto.getWalletTypeLabel(),
                    ),
                    const SizedBox(height: Spacing.sm),
                    if (crypto.exchange != null) ...[
                      _DetailRow(
                        label: 'Exchange',
                        value: crypto.getExchangeLabel(),
                      ),
                      const SizedBox(height: Spacing.sm),
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
                const SizedBox(height: Spacing.xl),
                Container(
                  padding: const EdgeInsets.all(Spacing.lg),
                  decoration: BoxDecoration(
                    color: AppStyles.getCardColor(context),
                    borderRadius: BorderRadius.circular(Radii.md),
                    border: Border.all(
                      color: CupertinoColors.systemGrey.withValues(alpha: 0.2),
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
                          fontSize: TypeScale.body,
                        ),
                      ),
                      const SizedBox(height: Spacing.md),
                      Text(
                        crypto.notes!,
                        style: TextStyle(
                          color: AppStyles.getSecondaryTextColor(context),
                          fontSize: TypeScale.subhead,
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
                  onPressed: () =>
                      _showEditSheet(context, investmentsController),
                  child: const Text('Edit Holdings'),
                ),
              ),
              const SizedBox(height: Spacing.md),
              SizedBox(
                width: double.infinity,
                child: CupertinoButton(
                  color: AppStyles.plasmaRed.withValues(alpha: 0.1),
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
                                  .deleteInvestment(investment.id);
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
                    style: TextStyle(color: AppStyles.plasmaRed),
                  ),
                ),
              ),
              const SizedBox(height: Spacing.xl),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditSheet(
      BuildContext context, InvestmentsController investmentsCtrl) {
    final priceCtrl =
        TextEditingController(text: crypto.currentPrice.toStringAsFixed(2));
    final notesCtrl = TextEditingController(text: crypto.notes ?? '');

    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final isDark = AppStyles.isDarkMode(ctx);
          return Container(
            height: AppStyles.sheetMaxHeight(ctx),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C1C1E) : CupertinoColors.white,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  const ModalHandle(),
                  const SizedBox(height: 16),
                  Text(
                    'Edit ${crypto.name}',
                    style: TextStyle(
                        color: AppStyles.getTextColor(ctx),
                        fontSize: RT.title2(ctx),
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _EditField(
                              label: 'Current Price (₹)',
                              controller: priceCtrl,
                              isDark: isDark,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true)),
                          const SizedBox(height: 12),
                          _EditField(
                              label: 'Notes',
                              controller: notesCtrl,
                              isDark: isDark,
                              maxLines: 3),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(children: [
                      Expanded(
                        child: CupertinoButton(
                          color: isDark
                              ? const Color(0xFF3A3A3C)
                              : CupertinoColors.systemGrey5,
                          onPressed: () => Navigator.pop(ctx),
                          child: Text('Cancel',
                              style: TextStyle(
                                  color: AppStyles.getTextColor(ctx))),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: CupertinoButton.filled(
                          onPressed: () async {
                            final newPrice = double.tryParse(priceCtrl.text) ??
                                crypto.currentPrice;
                            final newNotes = notesCtrl.text.trim().isEmpty
                                ? null
                                : notesCtrl.text.trim();
                            final updatedCrypto = crypto.copyWith(
                                currentPrice: newPrice, notes: newNotes);
                            final updatedMeta = Map<String, dynamic>.from(
                                investment.metadata ?? {});
                            updatedMeta['currentPrice'] = newPrice;
                            updatedMeta['notes'] = newNotes;
                            updatedMeta['lastUpdated'] =
                                DateTime.now().toIso8601String();
                            final updatedInvestment =
                                investment.copyWith(
                              amount: updatedCrypto.currentValue,
                              metadata: updatedMeta,
                            );
                            await investmentsCtrl
                                .updateInvestment(updatedInvestment);
                            if (ctx.mounted) {
                              setState(() => crypto = updatedCrypto);
                              Navigator.pop(ctx);
                              toast.showSuccess('Investment updated');
                            }
                          },
                          child: const Text('Save'),
                        ),
                      ),
                    ]),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ).whenComplete(() {
      priceCtrl.dispose();
      notesCtrl.dispose();
    });
  }
}

class _EditField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool isDark;
  final TextInputType? keyboardType;
  final int maxLines;

  const _EditField({
    required this.label,
    required this.controller,
    required this.isDark,
    this.keyboardType,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                color: AppStyles.getSecondaryTextColor(context),
                fontSize: TypeScale.footnote,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        CupertinoTextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: TextStyle(color: AppStyles.getTextColor(context)),
          decoration: BoxDecoration(
            color:
                isDark ? const Color(0xFF2C2C2E) : CupertinoColors.systemGrey6,
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ],
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
      valueColor =
          isPositive ? AppStyles.bioGreen : AppStyles.plasmaRed;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppStyles.getSecondaryTextColor(context),
            fontSize: TypeScale.subhead,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            fontSize: TypeScale.subhead,
            fontFamily: isMonospace ? 'monospace' : null,
          ),
          textAlign: TextAlign.end,
        ),
      ],
    );
  }
}
