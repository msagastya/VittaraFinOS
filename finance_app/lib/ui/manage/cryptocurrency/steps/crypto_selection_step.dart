import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/models/cryptocurrency_model.dart';
import 'package:vittara_fin_os/ui/manage/cryptocurrency/crypto_wizard_controller.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';

class CryptoSelectionStep extends StatefulWidget {
  const CryptoSelectionStep({super.key});

  @override
  State<CryptoSelectionStep> createState() => _CryptoSelectionStepState();
}

class _CryptoSelectionStepState extends State<CryptoSelectionStep> {
  late TextEditingController _nameController;
  late TextEditingController _symbolController;

  final cryptoOptions = [
    ('Bitcoin', 'BTC', CryptoCurrency.bitcoin),
    ('Ethereum', 'ETH', CryptoCurrency.ethereum),
    ('Cardano', 'ADA', CryptoCurrency.cardano),
    ('Solana', 'SOL', CryptoCurrency.solana),
    ('Ripple', 'XRP', CryptoCurrency.ripple),
    ('Litecoin', 'LTC', CryptoCurrency.litecoin),
    ('Dogecoin', 'DOGE', CryptoCurrency.dogecoin),
    ('Polkadot', 'DOT', CryptoCurrency.polkadot),
    ('Uniswap', 'UNI', CryptoCurrency.uniswap),
    ('Chainlink', 'LINK', CryptoCurrency.chainlink),
  ];

  @override
  void initState() {
    super.initState();
    final controller =
        Provider.of<CryptoWizardController>(context, listen: false);
    _nameController = TextEditingController(text: controller.cryptoName ?? '');
    _symbolController =
        TextEditingController(text: controller.cryptoSymbol ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _symbolController.dispose();
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
            'Select Cryptocurrency',
            style: AppStyles.titleStyle(context),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose or add your cryptocurrency investment',
            style: TextStyle(color: AppStyles.getSecondaryTextColor(context)),
          ),
          const SizedBox(height: 30),
          // Popular cryptocurrencies grid
          Text(
            'Popular Cryptocurrencies',
            style: TextStyle(
              color: AppStyles.getTextColor(context),
              fontWeight: FontWeight.w600,
              fontSize: TypeScale.body,
            ),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.2,
            ),
            itemCount: cryptoOptions.length,
            itemBuilder: (context, index) {
              final (name, symbol, cryptoType) = cryptoOptions[index];
              final isSelected = controller.selectedCrypto == cryptoType;

              return GestureDetector(
                onTap: () {
                  controller.selectCrypto(cryptoType);
                  controller.updateCryptoName(name);
                  controller.updateCryptoSymbol(symbol);
                  _nameController.text = name;
                  _symbolController.text = symbol;
                },
                child: Container(
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
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFFF7931A).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          symbol,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: TypeScale.headline,
                            color: Color(0xFFF7931A),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: TypeScale.subhead,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (isSelected)
                        const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Icon(
                            CupertinoIcons.check_mark_circled_solid,
                            color: Color(0xFFF7931A),
                            size: 16,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 30),
          // Custom cryptocurrency entry
          Text(
            'Custom Cryptocurrency',
            style: TextStyle(
              color: AppStyles.getTextColor(context),
              fontWeight: FontWeight.w600,
              fontSize: TypeScale.body,
            ),
          ),
          const SizedBox(height: 12),
          CupertinoTextField(
            controller: _nameController,
            placeholder: 'Cryptocurrency name',
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppStyles.getCardColor(context),
              borderRadius: BorderRadius.circular(12),
            ),
            style: TextStyle(color: AppStyles.getTextColor(context)),
            onChanged: (value) {
              controller.updateCryptoName(value);
              if (value.isNotEmpty) {
                // Deselect preset if custom name entered
                if (_nameController.text !=
                    cryptoOptions
                        .firstWhere(
                          (e) => e.$3 == controller.selectedCrypto,
                          orElse: () => ('', '', CryptoCurrency.bitcoin),
                        )
                        .$1) {
                  controller.selectCrypto(null as dynamic);
                }
              }
            },
          ),
          const SizedBox(height: 12),
          CupertinoTextField(
            controller: _symbolController,
            placeholder: 'Symbol (e.g., BTC, ETH)',
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppStyles.getCardColor(context),
              borderRadius: BorderRadius.circular(12),
            ),
            style: TextStyle(color: AppStyles.getTextColor(context)),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[A-Z]')),
            ],
            onChanged: (value) {
              controller.updateCryptoSymbol(value.toUpperCase());
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
