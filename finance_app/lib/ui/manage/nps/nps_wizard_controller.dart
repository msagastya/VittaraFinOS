import 'package:flutter/widgets.dart';
import 'package:vittara_fin_os/logic/nps_model.dart';

class NPSWizardController extends ChangeNotifier {
  int _currentStep = 0;

  // Step 0: Account Details
  String? prnNumber;
  String? fullName;
  String? nrnNumber;
  NPSTier selectedTier = NPSTier.tier1;
  NPSAccountType accountType = NPSAccountType.individual;
  NPSManager? selectedManager;
  NPSSchemeType schemeType = NPSSchemeType.equity;
  String? panNumber;

  // Step 1: Contributions
  double? totalContributed;
  DateTime lastContributionDate = DateTime.now();
  String? contributionSource;

  // Step 2: Current Status
  double? currentValue;

  // Step 3: Retirement Planning
  NPSWithdrawalType withdrawalType = NPSWithdrawalType.none;
  DateTime? plannedRetirementDate;

  // Step 4: Review
  String? notes;

  int get currentStep => _currentStep;

  // Calculations
  double get estimatedReturns {
    if (currentValue == null || totalContributed == null) return 0;
    return currentValue! - totalContributed!;
  }

  double get gainLossPercent {
    if (totalContributed == null || totalContributed == 0) return 0;
    return (estimatedReturns / totalContributed!) * 100;
  }

  bool canProceed() {
    switch (_currentStep) {
      case 0:
        return prnNumber != null &&
            prnNumber!.isNotEmpty &&
            fullName != null &&
            fullName!.isNotEmpty &&
            nrnNumber != null &&
            nrnNumber!.isNotEmpty &&
            selectedManager != null &&
            panNumber != null &&
            panNumber!.isNotEmpty;
      case 1:
        return totalContributed != null && totalContributed! > 0;
      case 2:
        return currentValue != null && currentValue! > 0;
      case 3:
        return plannedRetirementDate == null ||
            plannedRetirementDate!.isAfter(DateTime.now());
      case 4:
        return true;
      default:
        return false;
    }
  }

  void updatePRN(String prn) {
    prnNumber = prn;
    notifyListeners();
  }

  void updateName(String name) {
    fullName = name;
    notifyListeners();
  }

  void updateNRN(String nrn) {
    nrnNumber = nrn;
    notifyListeners();
  }

  void updateTier(NPSTier tier) {
    selectedTier = tier;
    notifyListeners();
  }

  void updateAccountType(NPSAccountType type) {
    accountType = type;
    notifyListeners();
  }

  void updateManager(NPSManager manager) {
    selectedManager = manager;
    notifyListeners();
  }

  void updateSchemeType(NPSSchemeType type) {
    schemeType = type;
    notifyListeners();
  }

  void updatePAN(String pan) {
    panNumber = pan;
    notifyListeners();
  }

  void updateTotalContributed(double amount) {
    totalContributed = amount;
    notifyListeners();
  }

  void updateCurrentValue(double value) {
    currentValue = value;
    notifyListeners();
  }

  void updateWithdrawalType(NPSWithdrawalType type) {
    withdrawalType = type;
    notifyListeners();
  }

  void updateRetirementDate(DateTime date) {
    plannedRetirementDate = date;
    notifyListeners();
  }

  void updateNotes(String? note) {
    notes = note;
    notifyListeners();
  }

  void nextPage() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_currentStep < 4 && canProceed()) {
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
