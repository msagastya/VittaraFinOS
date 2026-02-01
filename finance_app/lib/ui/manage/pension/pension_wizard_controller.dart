import 'package:flutter/foundation.dart';
import 'package:vittara_fin_os/logic/pension_model.dart';

class PensionWizardController extends ChangeNotifier {
  int _currentStep = 0;

  PensionSchemeType selectedScheme = PensionSchemeType.apy;
  String? accountNumber;
  double? principalContributed;
  double? currentValue;
  String? notes;

  int get currentStep => _currentStep;

  double get gainLoss => (currentValue ?? 0) - (principalContributed ?? 0);
  double get gainLossPercent {
    if (principalContributed == null || principalContributed == 0) return 0;
    return (gainLoss / principalContributed!) * 100;
  }

  bool canProceed() {
    switch (_currentStep) {
      case 0:
        // Scheme selection - always proceed (scheme has default)
        return true;
      case 1:
        // Account number input
        return accountNumber != null && accountNumber!.isNotEmpty;
      case 2:
        // Principal and current value inputs
        return principalContributed != null &&
            principalContributed! > 0 &&
            currentValue != null &&
            currentValue! > 0;
      case 3:
        // Review step
        return true;
      default:
        return false;
    }
  }

  void selectScheme(PensionSchemeType scheme) {
    selectedScheme = scheme;
    notifyListeners();
  }

  void updateAccountNumber(String number) {
    accountNumber = number;
    notifyListeners();
  }

  void updatePrincipal(double amount) {
    principalContributed = amount;
    notifyListeners();
  }

  void updateCurrentValue(double value) {
    currentValue = value;
    notifyListeners();
  }

  void updateNotes(String? note) {
    notes = note;
    notifyListeners();
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
}
