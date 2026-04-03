import 'package:flutter/material.dart';
import 'package:vittara_fin_os/logic/account_model.dart';
import 'package:vittara_fin_os/logic/investment_model.dart';
import 'package:vittara_fin_os/models/mutual_fund_model.dart';

enum MFType { existing, newMF }

enum MFWizardMode { add, buyMore, sell, sip }

class MFWizardIntent {
  final MFWizardMode mode;
  final Investment? targetInvestment;
  final MutualFund mutualFund;
  final Account? account;
  final double transactionAmount;
  final double transactionNav;
  final DateTime transactionDate;
  final double? transactionUnits;
  final int initialStep;
  final bool sipActive;

  const MFWizardIntent({
    required this.mode,
    required this.mutualFund,
    required this.transactionAmount,
    required this.transactionNav,
    required this.transactionDate,
    this.targetInvestment,
    this.account,
    this.transactionUnits,
    this.initialStep = 3,
    this.sipActive = false,
  });
}

class MFWizardController extends ChangeNotifier {
  final PageController pageController;
  int _currentStep = 0;
  final MFWizardIntent? intent;

  MFWizardController({this.intent})
      : pageController = PageController(initialPage: intent?.initialStep ?? 0) {
    _currentStep = intent?.initialStep ?? 0;
    final initialIntent = intent;
    if (initialIntent != null) {
      _initializeFromIntent(initialIntent);
    }
  }

  MFWizardMode mode = MFWizardMode.add;
  Investment? targetInvestment;

  // Step 1: Mutual Fund Selection
  MutualFund? selectedMF;

  // Step 2: Existing or New choice
  MFType? selectedMFType;

  // Step 3: Demat Account Selection
  Account? selectedAccount;

  // Step 4: Investment Details
  // Common
  double investmentAmount = 0;
  double extraCharges = 0; // Transaction charges/fees deducted from invested amount
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

  double get totalAmount => investmentAmount;

  double get netInvestmentAmount => (investmentAmount - extraCharges).clamp(0, double.infinity);

  double get calculatedUnits {
    if (selectedMFType == MFType.existing) {
      return averageNAV > 0 ? netInvestmentAmount / averageNAV : 0;
    } else {
      return fetchedNAV != null && fetchedNAV! > 0
          ? netInvestmentAmount / fetchedNAV!
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

  void updateCharges(double charges) {
    extraCharges = charges.clamp(0, double.infinity);
    notifyListeners();
  }

  void jumpToStep(int step) {
    FocusManager.instance.primaryFocus?.unfocus();
    if (step < 0 || step > 5) return;
    _currentStep = step;
    pageController.jumpToPage(step);
    notifyListeners();
  }

  void _initializeFromIntent(MFWizardIntent intent) {
    mode = intent.mode;
    targetInvestment = intent.targetInvestment;
    selectedMF = intent.mutualFund;
    selectedMFType = MFType.existing;
    selectedAccount = intent.account;
    investmentAmount = intent.transactionAmount;
    averageNAV = intent.transactionNav;
    investmentDate = intent.transactionDate;
    units = intent.transactionUnits ??
        (intent.transactionNav > 0
            ? intent.transactionAmount / intent.transactionNav
            : 0);
    sipActive = intent.sipActive;
    if (intent.mode == MFWizardMode.sip) {
      sipActive = true;
    }
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

  void updateDeduction({
    required bool deduct,
    Account? deductAccount,
  }) {
    deductFromAccount = deduct;
    deductionAccount = deduct ? deductAccount : null;
    notifyListeners();
  }

  void selectDeductionAccount(Account account) {
    if (selectedMFType == MFType.newMF) {
      updateNewMFDetails(
        amount: investmentAmount,
        date: investmentDate,
        deduct: true,
        deductAccount: account,
        fetchedNav: fetchedNAV,
      );
    } else {
      updateDeduction(deduct: true, deductAccount: account);
    }
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
    FocusManager.instance.primaryFocus?.unfocus();
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
