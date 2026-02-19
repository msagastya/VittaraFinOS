import 'package:flutter/material.dart';
import 'package:vittara_fin_os/models/digital_gold_model.dart';

class DigitalGoldWizardController extends ChangeNotifier {
  final PageController pageController = PageController();
  int _currentStep = 0;

  // Step 1: Company Selection
  DigitalGoldCompany? selectedCompany;

  // Step 2: Invested Amount (total including GST)
  double investedAmount = 0;

  // Step 3: Investment Rate (₹ per gram)
  double investmentRate = 0;

  // Step 4: GST Rate (default 3%)
  double gstRate = 3.0;

  // Step 5: Investment Date
  DateTime investmentDate = DateTime.now();

  // Legacy review step compatibility state
  bool isFetchingPrice = false;
  double? currentGoldPrice;
  String priceError = '';

  int get currentStep => _currentStep;

  // Calculate actual amount (before GST)
  double get actualAmount => investedAmount / (1 + (gstRate / 100));

  // Calculate GST amount
  double get gstAmount => investedAmount - actualAmount;

  // Calculate weight in grams
  double get weightInGrams =>
      investmentRate > 0 ? actualAmount / investmentRate : 0;

  // Legacy alias used by older weight step
  double get weight => weightInGrams;

  // Current valuation fields used by older review step
  double get currentValue => (currentGoldPrice ?? 0.0) * weightInGrams;
  double get gainLoss => currentValue - investedAmount;
  double get gainLossPercent =>
      investedAmount > 0 ? (gainLoss / investedAmount) * 100 : 0.0;

  void selectCompany(DigitalGoldCompany company) {
    selectedCompany = company;
    notifyListeners();
  }

  void updateInvestedAmount(double value) {
    investedAmount = value;
    notifyListeners();
  }

  void updateInvestmentRate(double value) {
    investmentRate = value;
    notifyListeners();
  }

  void updateGSTRate(double value) {
    gstRate = value;
    notifyListeners();
  }

  void updateInvestmentDate(DateTime date) {
    investmentDate = date;
    notifyListeners();
  }

  // Legacy setter used by older weight step.
  void updateWeight(double value) {
    final safeWeight = value < 0 ? 0.0 : value;
    if (investmentRate <= 0) {
      notifyListeners();
      return;
    }
    final actual = safeWeight * investmentRate;
    investedAmount = actual * (1 + (gstRate / 100));
    notifyListeners();
  }

  void setFetchingPrice(bool value) {
    isFetchingPrice = value;
    if (value) {
      priceError = '';
    }
    notifyListeners();
  }

  void setCurrentGoldPrice(double? value) {
    currentGoldPrice = value;
    isFetchingPrice = false;
    priceError = '';
    notifyListeners();
  }

  void setPriceError(String error) {
    priceError = error;
    isFetchingPrice = false;
    notifyListeners();
  }

  bool canProceed() {
    switch (_currentStep) {
      case 0: // Company Selection
        return selectedCompany != null;
      case 1: // Invested Amount
        return investedAmount > 0;
      case 2: // Investment Rate
        return investmentRate > 0;
      case 3: // GST Rate
        return gstRate >= 0;
      case 4: // Investment Date
        return true;
      default:
        return true;
    }
  }

  void nextPage() {
    if (_currentStep < 5) {
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
