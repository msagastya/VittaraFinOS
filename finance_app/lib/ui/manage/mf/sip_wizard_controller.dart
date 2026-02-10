import 'package:flutter/material.dart';
import 'package:vittara_fin_os/logic/account_model.dart';

enum SIPFrequency { daily, weekly, monthly }
enum StepUpTenure { monthly, yearly }

class SIPWizardController extends ChangeNotifier {
  SIPWizardController({Map<String, dynamic>? initialData, Account? initialAccount}) {
    _initializeFromData(initialData);
    deductionAccount = initialAccount;
  }

  final PageController pageController = PageController();
  int _currentStep = 0;

  // Step 1: SIP Amount
  double sipAmount = 0;

  // Step 2: Frequency & Deduction
  SIPFrequency frequency = SIPFrequency.monthly;
  int? selectedWeekday; // 0-6 (Monday-Sunday)
  int selectedMonthDay = 1; // 1-31
  Account? deductionAccount;

  // Step 3: Step Up
  bool stepUpEnabled = false;
  double stepUpPercent = 0;
  StepUpTenure stepUpTenure = StepUpTenure.yearly;
  int stepUpDuration = 1; // years or months

  int get currentStep => _currentStep;

  void updateSIPAmount(double amount) {
    sipAmount = amount;
    notifyListeners();
  }

  void updateFrequency(SIPFrequency freq) {
    frequency = freq;
    if (freq == SIPFrequency.monthly && selectedMonthDay == 0) {
      selectedMonthDay = 1;
    }
    notifyListeners();
  }

  void updateWeekday(int? day) {
    selectedWeekday = day;
    notifyListeners();
  }

  void updateMonthDay(int day) {
    selectedMonthDay = day;
    notifyListeners();
  }

  void updateDeductionAccount(Account? account) {
    deductionAccount = account;
    notifyListeners();
  }

  void toggleStepUp(bool enabled) {
    stepUpEnabled = enabled;
    notifyListeners();
  }

  void updateStepUp({
    required double percent,
    required StepUpTenure tenure,
    required int duration,
  }) {
    stepUpPercent = percent;
    stepUpTenure = tenure;
    stepUpDuration = duration;
    notifyListeners();
  }

  bool canProceed() {
    switch (_currentStep) {
      case 0: // SIP Amount
        return sipAmount > 0;
      case 1: // Frequency & Deduction
        if (frequency == SIPFrequency.weekly && selectedWeekday == null) {
          return false;
        }
        return deductionAccount != null;
      case 2: // Step Up
        if (stepUpEnabled) {
          return stepUpPercent > 0 && stepUpDuration > 0;
        }
        return true;
      case 3: // Review
        return true;
      default:
        return true;
    }
  }

  void _initializeFromData(Map<String, dynamic>? data) {
    if (data == null) return;

    sipAmount = (data['sipAmount'] as num?)?.toDouble() ?? sipAmount;
    frequency = _parseFrequency(data['frequency'] as String?) ?? frequency;
    selectedWeekday = (data['weekday'] as int?) ?? selectedWeekday;
    selectedMonthDay = (data['monthDay'] as int?) ?? selectedMonthDay;
    stepUpEnabled = data['stepUpEnabled'] == true;
    stepUpPercent = (data['stepUpPercent'] as num?)?.toDouble() ?? stepUpPercent;
    stepUpTenure = _parseStepUpTenure(data['stepUpTenure'] as String?) ?? stepUpTenure;
    stepUpDuration = (data['stepUpDuration'] as int?) ?? stepUpDuration;
  }

  SIPFrequency? _parseFrequency(String? value) {
    if (value == null) return null;
    return SIPFrequency.values.firstWhere(
      (freq) => freq.name.toLowerCase() == value.toLowerCase(),
      orElse: () => SIPFrequency.monthly,
    );
  }

  StepUpTenure? _parseStepUpTenure(String? value) {
    if (value == null) return null;
    return StepUpTenure.values.firstWhere(
      (tenure) => tenure.name.toLowerCase() == value.toLowerCase(),
      orElse: () => StepUpTenure.yearly,
    );
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

  Map<String, dynamic> getSIPData() {
    return {
      'sipAmount': sipAmount,
      'frequency': frequency.name,
      'weekday': selectedWeekday,
      'monthDay': selectedMonthDay,
      'deductionAccountId': deductionAccount?.id,
      'deductionAccountName': deductionAccount?.name,
      'stepUpEnabled': stepUpEnabled,
      'stepUpPercent': stepUpPercent,
      'stepUpTenure': stepUpTenure.name,
      'stepUpDuration': stepUpDuration,
    };
  }

  @override
  void dispose() {
    pageController.dispose();
    super.dispose();
  }
}
