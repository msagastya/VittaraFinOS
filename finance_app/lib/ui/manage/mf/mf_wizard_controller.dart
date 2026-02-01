import 'package:flutter/material.dart';
import 'package:vittara_fin_os/logic/account_model.dart';
import 'package:vittara_fin_os/models/mutual_fund_model.dart';

enum MFType { existing, newMF }

class MFWizardController extends ChangeNotifier {
  final PageController pageController = PageController();
  int _currentStep = 0;

  // Step 1: Mutual Fund Selection
  MutualFund? selectedMF;

  // Step 2: Existing or New choice
  MFType? selectedMFType;

  // Step 3: Demat Account Selection
  Account? selectedAccount;

  // Step 4: Investment Details
  // Common
  double investmentAmount = 0;
  DateTime investmentDate = DateTime.now();
  Account? deductionAccount; // For New MF only
  bool deductFromAccount = false; // For New MF only

  // Existing MF specific
  double averageNAV = 0;
  double units = 0;

  // New MF specific (will be fetched)
  double? fetchedNAV;

  // Step 5: SIP
  bool sipActive = false;
  Map<String, dynamic>? sipData;

  int get currentStep => _currentStep;

  double get totalAmount {
    if (selectedMFType == MFType.existing) {
      return investmentAmount;
    } else {
      return investmentAmount;
    }
  }

  double get calculatedUnits {
    if (selectedMFType == MFType.existing) {
      return averageNAV > 0 ? investmentAmount / averageNAV : 0;
    } else {
      return fetchedNAV != null && fetchedNAV! > 0
          ? investmentAmount / fetchedNAV!
          : 0;
    }
  }

  void selectMutualFund(MutualFund mf) {
    selectedMF = mf;
    notifyListeners();
  }

  void selectMFType(MFType type) {
    selectedMFType = type;
    notifyListeners();
  }

  void selectAccount(Account account) {
    selectedAccount = account;
    notifyListeners();
  }

  // For Existing MF
  void updateExistingMFDetails({
    required double amount,
    required double nav,
    DateTime? date,
  }) {
    investmentAmount = amount;
    averageNAV = nav;
    if (date != null) investmentDate = date;
    notifyListeners();
  }

  // For New MF
  void updateNewMFDetails({
    required double amount,
    required DateTime date,
    required bool deduct,
    Account? deductAccount,
    double? fetchedNav,
  }) {
    investmentAmount = amount;
    investmentDate = date;
    deductFromAccount = deduct;
    deductionAccount = deductAccount;
    fetchedNAV = fetchedNav;
    notifyListeners();
  }

  void updatePurchaseDate(DateTime date) {
    investmentDate = date;
    notifyListeners();
  }

  void setFetchedNAV(double? nav) {
    fetchedNAV = nav;
    notifyListeners();
  }

  void setSIPData(Map<String, dynamic>? data) {
    sipData = data;
    sipActive = data != null;
    notifyListeners();
  }

  bool canProceed() {
    switch (_currentStep) {
      case 0: // Search
        return selectedMF != null;
      case 1: // Existing or New
        return selectedMFType != null;
      case 2: // Account Selection
        return selectedAccount != null;
      case 3: // Investment Details
        if (selectedMFType == MFType.existing) {
          return investmentAmount > 0 && averageNAV > 0;
        } else {
          return investmentAmount > 0 && fetchedNAV != null && fetchedNAV! > 0;
        }
      case 4: // SIP or Review
        return true;
      case 5: // Review (if SIP was added)
        return true;
      default:
        return true;
    }
  }

  void nextPage() {
    if (_currentStep < 6) {
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
