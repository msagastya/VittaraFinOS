import 'package:flutter/foundation.dart';
import 'package:vittara_fin_os/models/cryptocurrency_model.dart';

class CryptoWizardController extends ChangeNotifier {
  int _currentStep = 0;

  // Step 0: Cryptocurrency Selection
  CryptoCurrency? selectedCrypto;
  String? cryptoName;
  String? cryptoSymbol;

  // Step 1: Wallet & Exchange Selection
  CryptoWalletType walletType = CryptoWalletType.exchange;
  CryptoExchange? selectedExchange;
  String? walletAddress;

  // Step 2: Purchase Details
  DateTime purchaseDate = DateTime.now();
  double? quantity;
  double? pricePerUnit; // In INR
  double? transactionFee;
  String? notes;

  // Step 3: Account Linking (Optional)
  String? linkedAccountId;
  String? linkedAccountName;

  int get currentStep => _currentStep;

  void selectCrypto(CryptoCurrency crypto) {
    selectedCrypto = crypto;
    notifyListeners();
  }

  void updateCryptoName(String name) {
    cryptoName = name;
    notifyListeners();
  }

  void updateCryptoSymbol(String symbol) {
    cryptoSymbol = symbol;
    notifyListeners();
  }

  void updateWalletType(CryptoWalletType type) {
    walletType = type;
    if (type != CryptoWalletType.exchange) {
      selectedExchange = null;
    }
    notifyListeners();
  }

  void updateExchange(CryptoExchange exchange) {
    selectedExchange = exchange;
    notifyListeners();
  }

  void updateWalletAddress(String address) {
    walletAddress = address;
    notifyListeners();
  }

  void updatePurchaseDate(DateTime date) {
    purchaseDate = date;
    notifyListeners();
  }

  void updateQuantity(double qty) {
    quantity = qty;
    notifyListeners();
  }

  void updatePricePerUnit(double price) {
    pricePerUnit = price;
    notifyListeners();
  }

  void updateTransactionFee(double? fee) {
    transactionFee = fee;
    notifyListeners();
  }

  void updateNotes(String? note) {
    notes = note;
    notifyListeners();
  }

  void updateAccountSelection(String accountId, String accountName) {
    linkedAccountId = accountId;
    linkedAccountName = accountName;
    notifyListeners();
  }

  // Calculations
  double get totalInvested {
    if (quantity == null || pricePerUnit == null) return 0;
    return quantity! * pricePerUnit!;
  }

  double get totalWithFee {
    final fee = transactionFee ?? 0;
    return totalInvested + fee;
  }

  double get averageBuyPrice {
    if (quantity == null || pricePerUnit == null) return 0;
    return pricePerUnit!;
  }

  bool canProceed() {
    switch (_currentStep) {
      case 0:
        return selectedCrypto != null &&
            cryptoName != null &&
            cryptoName!.isNotEmpty &&
            cryptoSymbol != null &&
            cryptoSymbol!.isNotEmpty;
      case 1:
        return walletAddress != null &&
            walletAddress!.isNotEmpty &&
            (walletType != CryptoWalletType.exchange || selectedExchange != null);
      case 2:
        return quantity != null &&
            quantity! > 0 &&
            pricePerUnit != null &&
            pricePerUnit! > 0;
      case 3:
        return true; // Account linking is optional
      default:
        return false;
    }
  }

  void nextPage() {
    if (_currentStep < 3 && canProceed()) {
      _currentStep++;
      notifyListeners();
    }
  }

  void previousPage() {
    if (_currentStep > 0) {
      _currentStep--;
      notifyListeners();
    }
  }

  void resetWizard() {
    _currentStep = 0;
    selectedCrypto = null;
    cryptoName = null;
    cryptoSymbol = null;
    walletType = CryptoWalletType.exchange;
    selectedExchange = null;
    walletAddress = null;
    purchaseDate = DateTime.now();
    quantity = null;
    pricePerUnit = null;
    transactionFee = null;
    notes = null;
    linkedAccountId = null;
    linkedAccountName = null;
    notifyListeners();
  }
}
