import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/models/cryptocurrency_model.dart';
import 'package:vittara_fin_os/ui/manage/cryptocurrency/crypto_wizard_controller.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';

class CryptoWalletStep extends StatefulWidget {
  const CryptoWalletStep({super.key});

  @override
  State<CryptoWalletStep> createState() => _CryptoWalletStepState();
}

class _CryptoWalletStepState extends State<CryptoWalletStep> {
  late TextEditingController _addressController;

  @override
  void initState() {
    super.initState();
    final controller =
        Provider.of<CryptoWizardController>(context, listen: false);
    _addressController =
        TextEditingController(text: controller.walletAddress ?? '');
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<CryptoWizardController>(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Wallet & Storage',
            style: AppStyles.titleStyle(context),
          ),
          const SizedBox(height: 8),
          Text(
            'Select where you hold your cryptocurrency',
            style: TextStyle(color: AppStyles.getSecondaryTextColor(context)),
          ),
          const SizedBox(height: 30),
          // Wallet Type Selection
          Text(
            'Storage Type',
            style: TextStyle(
              color: AppStyles.getTextColor(context),
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          ...CryptoWalletType.values.map((type) {
            final isSelected = controller.walletType == type;
            final labels = {
              CryptoWalletType.exchange: 'Exchange Account',
              CryptoWalletType.hardware: 'Hardware Wallet',
              CryptoWalletType.softwareHot: 'Hot Wallet',
              CryptoWalletType.softwareCold: 'Cold Storage',
            };
            final descriptions = {
              CryptoWalletType.exchange: 'Coinbase, Binance, WazirX, etc.',
              CryptoWalletType.hardware: 'Ledger, Trezor, etc.',
              CryptoWalletType.softwareHot: 'Mobile/Desktop apps',
              CryptoWalletType.softwareCold: 'Paper wallets, encrypted drives',
            };

            return Column(
              children: [
                GestureDetector(
                  onTap: () {
                    controller.updateWalletType(type);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFF7931A).withValues(alpha: 0.1)
                          : AppStyles.getCardColor(context),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFFF7931A)
                            : CupertinoColors.systemGrey.withValues(alpha: 0.2),
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFFF7931A).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            type == CryptoWalletType.exchange
                                ? CupertinoIcons.building_2_fill
                                : type == CryptoWalletType.hardware
                                    ? CupertinoIcons.lock_shield_fill
                                    : CupertinoIcons.phone_fill,
                            color: const Color(0xFFF7931A),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                labels[type] ?? '',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                descriptions[type] ?? '',
                                style: TextStyle(
                                  color:
                                      AppStyles.getSecondaryTextColor(context),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          const Icon(
                            CupertinoIcons.check_mark_circled_solid,
                            color: Color(0xFFF7931A),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            );
          }),
          const SizedBox(height: 20),
          // Exchange Selection (only for exchange wallet type)
          if (controller.walletType == CryptoWalletType.exchange) ...[
            Text(
              'Select Exchange',
              style: TextStyle(
                color: AppStyles.getTextColor(context),
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: CryptoExchange.values.map((exchange) {
                final isSelected = controller.selectedExchange == exchange;
                final labels = {
                  CryptoExchange.coinbase: 'Coinbase',
                  CryptoExchange.kraken: 'Kraken',
                  CryptoExchange.binance: 'Binance',
                  CryptoExchange.kucoin: 'KuCoin',
                  CryptoExchange.huobi: 'Huobi',
                  CryptoExchange.wazirx: 'WazirX',
                  CryptoExchange.coinswitch: 'CoinSwitch',
                  CryptoExchange.zebpay: 'ZebPay',
                };

                return GestureDetector(
                  onTap: () {
                    controller.updateExchange(exchange);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFF7931A)
                          : AppStyles.getCardColor(context),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFFF7931A)
                            : CupertinoColors.systemGrey.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Text(
                      labels[exchange] ?? '',
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : AppStyles.getTextColor(context),
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
          ],
          // Wallet Address
          Text(
            controller.walletType == CryptoWalletType.exchange
                ? 'Exchange Account ID'
                : 'Wallet Address',
            style: TextStyle(
              color: AppStyles.getTextColor(context),
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          CupertinoTextField(
            controller: _addressController,
            placeholder: controller.walletType == CryptoWalletType.exchange
                ? 'e.g., user@email.com or account ID'
                : 'e.g., 1A1z7agoat2xFYx...',
            padding: const EdgeInsets.all(16),
            maxLines: 3,
            decoration: BoxDecoration(
              color: AppStyles.getCardColor(context),
              borderRadius: BorderRadius.circular(12),
            ),
            style: TextStyle(color: AppStyles.getTextColor(context)),
            onChanged: (value) {
              controller.updateWalletAddress(value);
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
