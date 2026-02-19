import 'package:flutter/foundation.dart';
import 'package:vittara_fin_os/logic/fo_model.dart';

class FOWizardController extends ChangeNotifier {
  int _currentStep = 0;

  FOType selectedType = FOType.futures;
  String symbol = '';
  String contractName = '';
  double? entryPrice;
  double? currentPrice;
  double? quantity;
  double? strikePrice; // For options
  DateTime expiryDate = DateTime.now().add(const Duration(days: 30));
  DateTime entryDate = DateTime.now();
  double? volatility; // For options
  double? riskFreeRate; // For options (default 6%)
  OptionsGreeks? greeks; // For options
  String? notes;

  int get currentStep => _currentStep;

  double get totalCost => (quantity ?? 0) * (entryPrice ?? 0);
  double get currentValue => (quantity ?? 0) * (currentPrice ?? 0);
  double get gainLoss => currentValue - totalCost;
  double get gainLossPercent {
    if (totalCost == 0) return 0;
    return (gainLoss / totalCost) * 100;
  }

  bool canProceed() {
    switch (_currentStep) {
      case 0:
        // Type selection
        return symbol.isNotEmpty && contractName.isNotEmpty;
      case 1:
        // Contract details
        return entryPrice != null &&
            entryPrice! > 0 &&
            quantity != null &&
            quantity! > 0;
      case 2:
        // Position details (current price)
        return currentPrice != null && currentPrice! > 0;
      case 3:
        // Greeks (for options only)
        if (selectedType == FOType.futures) return true;
        return strikePrice != null &&
            strikePrice! > 0 &&
            volatility != null &&
            volatility! > 0 &&
            riskFreeRate != null;
      case 4:
        // Risk analysis
        return true;
      case 5:
        // Review
        return true;
      default:
        return false;
    }
  }

  void selectType(FOType type) {
    selectedType = type;
    notifyListeners();
  }

  void updateSymbol(String sym) {
    symbol = sym;
    notifyListeners();
  }

  void updateContractName(String name) {
    contractName = name;
    notifyListeners();
  }

  void updateEntryPrice(double price) {
    entryPrice = price;
    notifyListeners();
  }

  void updateCurrentPrice(double price) {
    currentPrice = price;
    notifyListeners();
  }

  void updateQuantity(double qty) {
    quantity = qty;
    notifyListeners();
  }

  void updateStrikePrice(double price) {
    strikePrice = price;
    notifyListeners();
  }

  void updateExpiryDate(DateTime date) {
    expiryDate = date;
    notifyListeners();
  }

  void updateEntryDate(DateTime date) {
    entryDate = date;
    notifyListeners();
  }

  void updateVolatility(double vol) {
    volatility = vol;
    // Auto-calculate Greeks if all required data is available
    if (selectedType != FOType.futures &&
        strikePrice != null &&
        entryPrice != null &&
        volatility != null &&
        riskFreeRate != null) {
      _calculateGreeks();
    }
    notifyListeners();
  }

  void updateRiskFreeRate(double rate) {
    riskFreeRate = rate;
    // Auto-calculate Greeks if all required data is available
    if (selectedType != FOType.futures &&
        strikePrice != null &&
        entryPrice != null &&
        volatility != null &&
        riskFreeRate != null) {
      _calculateGreeks();
    }
    notifyListeners();
  }

  void updateNotes(String? note) {
    notes = note;
    notifyListeners();
  }

  void _calculateGreeks() {
    if (selectedType == FOType.futures || strikePrice == null) return;

    final timeToExpiry = expiryDate.difference(DateTime.now()).inDays / 365.0;
    if (timeToExpiry <= 0) return;

    greeks = FuturesOptions.calculateGreeks(
      spotPrice: currentPrice ?? entryPrice ?? 0,
      strikePrice: strikePrice!,
      riskFreeRate: riskFreeRate ?? 6.0,
      volatility: volatility ?? 20.0,
      timeToExpiry: timeToExpiry,
      isCall: selectedType == FOType.callOption,
    );
  }

  void nextPage() {
    if (_currentStep < 5 && canProceed()) {
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
}
