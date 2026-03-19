import 'package:flutter/material.dart';
import 'package:vittara_fin_os/logic/account_model.dart';
import 'package:vittara_fin_os/logic/investment_model.dart';
import 'package:vittara_fin_os/services/stock_api_service.dart';

class StocksWizardController extends ChangeNotifier {
  late final PageController pageController;
  int _currentStep;
  bool isSubmitting = false;

  /// When provided the stock search step (step 0) is pre-filled and skipped.
  final Investment? existingInvestment;

  // Step 0: Stock Selection
  StockSearchResult? selectedStock;

  // Step 1: Account Selection
  Account? selectedAccount;

  // Step 2: Details
  double qty = 0;
  double price = 0;
  DateTime purchaseDate = DateTime.now();
  double currentValue = 0;

  // Step 3: Deduction
  bool deductFromAccount = false;
  double extraCharges = 0;

  StocksWizardController({this.existingInvestment})
      : _currentStep = existingInvestment != null ? 1 : 0 {
    pageController =
        PageController(initialPage: existingInvestment != null ? 1 : 0);
    if (existingInvestment != null) {
      final meta = existingInvestment!.metadata ?? {};
      selectedStock = StockSearchResult(
        symbol: (meta['symbol'] as String?) ?? existingInvestment!.name,
        name: (meta['name'] as String?) ?? existingInvestment!.name,
        exchange: (meta['exchange'] as String?) ?? '',
        type: (meta['type'] as String?) ?? 'EQUITY',
      );
    }
  }

  int get currentStep => _currentStep;
  double get totalAmount => qty * price;
  double get totalDeduction => totalAmount + extraCharges;
  double get gainLoss => currentValue - totalAmount;
  double get gainLossPercent =>
      totalAmount > 0 ? (gainLoss / totalAmount) * 100 : 0;

  void selectStock(StockSearchResult stock) {
    selectedStock = stock;
    notifyListeners();
  }

  void selectAccount(Account account) {
    selectedAccount = account;
    notifyListeners();
  }

  void updateDetails({
    required double quantity,
    required double pricePerShare,
    DateTime? date,
    double? current,
  }) {
    qty = quantity;
    price = pricePerShare;
    if (date != null) purchaseDate = date;
    if (current != null) currentValue = current;
    notifyListeners();
  }

  void updateCurrentValue(double value) {
    currentValue = value;
    notifyListeners();
  }

  void updatePurchaseDate(DateTime date) {
    purchaseDate = date;
    notifyListeners();
  }

  void updateDeduction({required bool deduct, double charges = 0}) {
    deductFromAccount = deduct;
    extraCharges = charges;
    notifyListeners();
  }

  bool canProceed() {
    switch (_currentStep) {
      case 0: // Search
        return selectedStock != null;
      case 1: // Account
        return selectedAccount != null;
      case 2: // Details
        return qty > 0 && price > 0;
      case 3: // Deduction
        if (deductFromAccount && selectedAccount != null) {
          return selectedAccount!.balance >= totalDeduction;
        }
        return true;
      default:
        return true;
    }
  }

  void nextPage() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_currentStep < 4) {
      _currentStep++;
      pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      notifyListeners();
    }
  }

  void previousPage() {
    // If stock was pre-filled (adding to existing), step 1 is the minimum
    final minStep = existingInvestment != null ? 1 : 0;
    if (_currentStep > minStep) {
      _currentStep--;
      pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      notifyListeners();
    }
  }

  @override
  void dispose() {
    pageController.dispose();
    super.dispose();
  }
}
