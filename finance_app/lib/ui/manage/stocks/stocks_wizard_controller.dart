import 'package:flutter/material.dart';
import 'package:vittara_fin_os/logic/account_model.dart';
import 'package:vittara_fin_os/services/stock_api_service.dart';

class StocksWizardController extends ChangeNotifier {
  final PageController pageController = PageController();
  int _currentStep = 0;

  // Step 1: Stock Selection
  StockSearchResult? selectedStock;

  // Step 2: Account Selection
  Account? selectedAccount;

  // Step 3: Details
  double qty = 0;
  double price = 0;
  
  // Step 4: Deduction
  bool deductFromAccount = false;
  double extraCharges = 0;

  int get currentStep => _currentStep;
  double get totalAmount => qty * price;
  double get totalDeduction => totalAmount + extraCharges;

  void selectStock(StockSearchResult stock) {
    selectedStock = stock;
    notifyListeners();
  }

  void selectAccount(Account account) {
    selectedAccount = account;
    notifyListeners();
  }

  void updateDetails({required double quantity, required double pricePerShare}) {
    qty = quantity;
    price = pricePerShare;
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
    if (_currentStep > 0) {
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
