import 'package:flutter/material.dart';
import 'package:vittara_fin_os/logic/fixed_deposit_model.dart';
import 'package:vittara_fin_os/logic/account_model.dart';

enum TenureUnit { days, months, years }

class FDWizardController extends ChangeNotifier {
  // Step 0: Account Selection
  Account? selectedAccount;

  // Step 1: Investment Date
  DateTime investmentDate = DateTime.now();

  // Step 2: Principal Amount
  double principal = 0;

  // Step 3: Interest Rate
  double interestRate = 0;

  // Step 4: Tenure Duration
  int tenureMonths = 12;
  TenureUnit? tenureUnit;
  int tenureDuration = 12;

  // Multiple tenure unit support
  int tenureYearsInput = 0;
  int tenureMonthsInput = 0;
  int tenureDaysInput = 0;
  int tenureTotalDays = 0; // Exact total days (never lose precision)

  // Step 5: Compounding Frequency
  FDCompoundingFrequency compoundingFrequency =
      FDCompoundingFrequency.quarterly;

  // Step 6: FD Type & Payout Frequency
  bool isCumulative = true;
  FDPayoutFrequency payoutFrequency = FDPayoutFrequency.annual;

  // Step 7: Debit & Review
  bool debitFromAccount = false;
  String fdName = '';
  String? fdNotes;
  bool autoLinkEnabled = false;

  // Current step
  int currentStep = 0;

  // Calculated values
  late DateTime maturityDate;
  late double maturityValue;
  late double totalInterestAtMaturity;

  FDWizardController() {
    _updateMaturityDate();
    _updateCalculations();
  }

  void selectAccount(Account account) {
    selectedAccount = account;
    notifyListeners();
  }

  void updateInvestmentDate(DateTime date) {
    investmentDate = date;
    _updateMaturityDate();
    _updateCalculations();
    notifyListeners();
  }

  void updatePrincipal(double amount) {
    principal = amount;
    _updateCalculations();
    notifyListeners();
  }

  void updateInterestRate(double rate) {
    interestRate = rate;
    _updateCalculations();
    notifyListeners();
  }

  void updateTenure(int months) {
    tenureMonths = months;
    tenureDuration = months;
    tenureUnit = TenureUnit.months;
    _updateMaturityDate();
    _updateCalculations();
    notifyListeners();
  }

  void updateTenureWithUnit(int duration, TenureUnit unit) {
    tenureDuration = duration;
    tenureUnit = unit;

    // Convert to months for internal storage
    switch (unit) {
      case TenureUnit.days:
        // Use 30.44 (365.25/12) for accurate month approximation; round not truncate
        tenureMonths = (duration / 30.44).round().clamp(1, 12000);
        break;
      case TenureUnit.months:
        tenureMonths = duration;
        break;
      case TenureUnit.years:
        tenureMonths = duration * 12;
        break;
    }

    _updateMaturityDate();
    _updateCalculations();
    notifyListeners();
  }

  void updateTenureWithMultipleUnits(int years, int months, int days) {
    tenureYearsInput = years;
    tenureMonthsInput = months;
    tenureDaysInput = days;

    // For validation and reference: calculate approximate total months
    // (This is just for display/validation, actual maturity date uses proper date arithmetic)
    int totalMonths = (years * 12) + months;
    if (totalMonths < 1 && days > 0) {
      totalMonths = 1; // At least 1 month if only days
    }

    tenureMonths = totalMonths;
    tenureUnit = null; // Clear single unit since we're using multiple
    tenureDuration = totalMonths;

    _updateMaturityDate();
    _updateCalculations();
    notifyListeners();
  }

  void updateCompoundingFrequency(FDCompoundingFrequency frequency) {
    compoundingFrequency = frequency;
    _updateCalculations();
    notifyListeners();
  }

  void updateFDType(bool cumulative) {
    isCumulative = cumulative;
    _updateCalculations();
    notifyListeners();
  }

  void updatePayoutFrequency(FDPayoutFrequency frequency) {
    payoutFrequency = frequency;
    _updateCalculations();
    notifyListeners();
  }

  void updateFDName(String name) {
    fdName = name;
    notifyListeners();
  }

  void updateFDNotes(String? notes) {
    fdNotes = notes;
    notifyListeners();
  }

  void toggleAutoLink(bool value) {
    autoLinkEnabled = value;
    notifyListeners();
  }

  void toggleDebitFromAccount(bool value) {
    debitFromAccount = value;
    notifyListeners();
  }

  void goToStep(int step) {
    FocusManager.instance.primaryFocus?.unfocus();
    currentStep = step;
    notifyListeners();
  }

  void nextStep() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (currentStep < 7) {
      currentStep++;
      notifyListeners();
    }
  }

  void previousStep() {
    if (currentStep > 0) {
      currentStep--;
      notifyListeners();
    }
  }

  bool get canProceedToNextStep {
    switch (currentStep) {
      case 0:
        return selectedAccount != null;
      case 1:
        return true; // Investment date
      case 2:
        return principal > 0;
      case 3:
        return interestRate > 0 && interestRate <= 50.0;
      case 4:
        return tenureMonths > 0;
      case 5:
      case 6:
        return true;
      case 7:
        return fdName.isNotEmpty;
      default:
        return false;
    }
  }

  bool get canSubmit {
    return selectedAccount != null &&
        principal > 0 &&
        interestRate > 0 &&
        tenureMonths > 0 &&
        fdName.isNotEmpty;
  }

  void _updateMaturityDate() {
    // Proper date arithmetic (handles leap years and varying month lengths)
    DateTime result = investmentDate;

    if (tenureUnit == null) {
      // Multi-unit input (Years + Months + Days)
      // Add years first
      if (tenureYearsInput > 0) {
        result = DateTime(
          result.year + tenureYearsInput,
          result.month,
          result.day,
        );
      }

      // Then add months
      if (tenureMonthsInput > 0) {
        var newMonth = result.month + tenureMonthsInput;
        var newYear = result.year;

        while (newMonth > 12) {
          newMonth -= 12;
          newYear++;
        }

        // Handle day overflow for months with fewer days
        final maxDayInMonth = DateTime(newYear, newMonth + 1, 0).day;
        final day = result.day > maxDayInMonth ? maxDayInMonth : result.day;

        result = DateTime(newYear, newMonth, day);
      }

      // Finally add days
      if (tenureDaysInput > 0) {
        result = result.add(Duration(days: tenureDaysInput));
      }

      maturityDate = result;
    } else {
      // Single unit input (Days, Months, or Years)
      switch (tenureUnit) {
        case TenureUnit.days:
          maturityDate = result.add(Duration(days: tenureDuration));
          break;

        case TenureUnit.months:
          // Add months properly
          var newMonth = result.month + tenureDuration;
          var newYear = result.year;

          while (newMonth > 12) {
            newMonth -= 12;
            newYear++;
          }

          // Handle day overflow
          final maxDayInMonth = DateTime(newYear, newMonth + 1, 0).day;
          final day = result.day > maxDayInMonth ? maxDayInMonth : result.day;

          maturityDate = DateTime(newYear, newMonth, day);
          break;

        case TenureUnit.years:
          // Add years properly
          maturityDate = DateTime(
            result.year + tenureDuration,
            result.month,
            result.day,
          );
          break;

        case null:
          // Fallback (shouldn't happen)
          var newMonth = result.month + tenureMonths;
          var newYear = result.year;

          while (newMonth > 12) {
            newMonth -= 12;
            newYear++;
          }

          maturityDate = DateTime(newYear, newMonth, result.day);
      }
    }
  }

  void _updateCalculations() {
    if (isCumulative) {
      maturityValue = FDCalculator.calculateMaturityValueCumulative(
        principal: principal,
        annualRate: interestRate,
        tenureMonths: tenureMonths,
        frequency: compoundingFrequency,
      );
    } else {
      maturityValue = FDCalculator.calculateMaturityValueNonCumulative(
        principal: principal,
        annualRate: interestRate,
        tenureMonths: tenureMonths,
      );
    }
    totalInterestAtMaturity = maturityValue - principal;
  }

  FixedDeposit buildFD() {
    final now = DateTime.now();
    const uuid = '';

    // Generate unique ID
    final fdId =
        'fd_${DateTime.now().millisecondsSinceEpoch}_${selectedAccount?.id ?? ''}';

    // Generate payout schedule ONLY for non-cumulative FDs
    List<PayoutRecord> pastPayouts = [];
    List<PayoutRecord> upcomingPayouts = [];

    if (!isCumulative) {
      final payouts = FDCalculator.generatePayoutSchedule(
        fdId: fdId,
        principal: principal,
        annualRate: interestRate,
        investmentDate: investmentDate,
        tenureMonths: tenureMonths,
        payoutFrequency: payoutFrequency,
        compoundingFrequency: compoundingFrequency,
        isCumulative: isCumulative,
        maturityDate: maturityDate,
      );

      // Separate past and upcoming payouts
      pastPayouts = payouts.where((p) => p.isProcessed).toList();
      upcomingPayouts = payouts.where((p) => !p.isProcessed).toList();
    }

    return FixedDeposit(
      id: fdId,
      name: fdName,
      principal: principal,
      interestRate: interestRate,
      tenureMonths: tenureMonths,
      compoundingFrequency: compoundingFrequency,
      payoutFrequency: payoutFrequency,
      isCumulative: isCumulative,
      linkedAccountId: selectedAccount!.id,
      linkedAccountName: selectedAccount!.name,
      autoLinkEnabled: autoLinkEnabled,
      createdDate: now,
      investmentDate: investmentDate,
      maturityDate: maturityDate,
      status: FDStatus.active,
      pastPayouts: pastPayouts,
      upcomingPayouts: upcomingPayouts,
      maturityValue: maturityValue,
      totalInterestAtMaturity: totalInterestAtMaturity,
      estimatedAccruedValue: principal,
      realizedValue: principal,
      notes: fdNotes,
      bankName: selectedAccount?.bankName,
      bankAccountNumber: null,
    );
  }

  void reset() {
    selectedAccount = null;
    investmentDate = DateTime.now();
    principal = 0;
    interestRate = 0;
    tenureMonths = 12;
    tenureUnit = TenureUnit.months;
    tenureDuration = 12;
    compoundingFrequency = FDCompoundingFrequency.quarterly;
    isCumulative = true;
    payoutFrequency = FDPayoutFrequency.annual;
    debitFromAccount = false;
    fdName = '';
    fdNotes = null;
    autoLinkEnabled = false;
    currentStep = 0;
    _updateMaturityDate();
    _updateCalculations();
    notifyListeners();
  }
}
