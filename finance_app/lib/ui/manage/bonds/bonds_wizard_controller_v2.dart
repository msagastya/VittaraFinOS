import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

enum PayoutFrequency {
  monthly,
  quarterly,
  semiAnnual,
  annual,
  atMaturity,
}

class BondsWizardControllerV2 extends ChangeNotifier {
  final PageController pageController = PageController();
  int _currentStep = 0;

  // Step 1: Bond Name
  String bondName = '';

  // Step 2: Bond Amount (investment amount)
  double bondAmount = 0;

  // Step 3: Account Selection
  String? linkedAccountId;
  String? linkedAccountName;
  bool autoDebit = false;

  // Step 4: Payout Frequency
  PayoutFrequency payoutFrequency = PayoutFrequency.annual;

  // Step 5: Dates
  DateTime maturityDate = DateTime.now().add(const Duration(days: 365 * 3));
  int firstPayoutMonth = 1; // For non-maturity payouts: 1-12
  int firstPayoutDay = 1; // For non-maturity payouts: 1-31

  int get currentStep => _currentStep;
  int get totalSteps => 6; // 0-5 (6 steps: Name, Amount, Account, Frequency, Dates, Review)

  bool canProceed() {
    switch (_currentStep) {
      case 0:
        // Bond name
        return bondName.isNotEmpty;
      case 1:
        // Bond amount
        return bondAmount > 0;
      case 2:
        // Account (optional)
        return true;
      case 3:
        // Payout frequency (always selected)
        return true;
      case 4:
        // Dates validation
        if (payoutFrequency == PayoutFrequency.atMaturity) {
          return maturityDate.isAfter(DateTime.now());
        } else {
          return maturityDate.isAfter(DateTime.now()) &&
              firstPayoutDay >= 1 &&
              firstPayoutDay <= 31 &&
              firstPayoutMonth >= 1 &&
              firstPayoutMonth <= 12;
        }
      case 5:
        // Review (always can proceed to save)
        return true;
      default:
        return false;
    }
  }

  // Getters for display
  String get payoutFrequencyLabel {
    switch (payoutFrequency) {
      case PayoutFrequency.monthly:
        return 'Monthly';
      case PayoutFrequency.quarterly:
        return 'Quarterly';
      case PayoutFrequency.semiAnnual:
        return 'Semi-Annual';
      case PayoutFrequency.annual:
        return 'Annual';
      case PayoutFrequency.atMaturity:
        return 'At Maturity';
    }
  }

  // Update methods
  void updateBondName(String name) {
    bondName = name;
    notifyListeners();
  }

  void updateBondAmount(double amount) {
    bondAmount = amount;
    notifyListeners();
  }

  void updateLinkedAccount(String? accountId, String? accountName) {
    linkedAccountId = accountId;
    linkedAccountName = accountName;
    if (accountId == null) {
      autoDebit = false;
    }
    notifyListeners();
  }

  void updateAutoDebit(bool value) {
    autoDebit = value;
    notifyListeners();
  }

  void updatePayoutFrequency(PayoutFrequency frequency) {
    payoutFrequency = frequency;
    notifyListeners();
  }

  void updateMaturityDate(DateTime date) {
    maturityDate = date;
    notifyListeners();
  }

  void updateFirstPayoutMonth(int month) {
    firstPayoutMonth = month.clamp(1, 12);
    notifyListeners();
  }

  void updateFirstPayoutDay(int day) {
    firstPayoutDay = day.clamp(1, 31);
    notifyListeners();
  }

  void nextPage() {
    if (_currentStep < totalSteps - 1 && canProceed()) {
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
