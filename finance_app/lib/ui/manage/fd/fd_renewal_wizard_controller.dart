import 'package:flutter/material.dart';
import 'package:vittara_fin_os/logic/fixed_deposit_model.dart';
import 'package:vittara_fin_os/logic/account_model.dart';

enum TenureUnit { days, months, years }

class FDRenewalWizardController extends ChangeNotifier {
  // Pre-filled from existing FD
  final FixedDeposit existingFD;
  Account? selectedAccount;

  // Renewal Date (typically today)
  DateTime renewalDate = DateTime.now();

  // Principal (auto-filled from maturity value of existing FD)
  late double principal;

  // Interest Rate
  double interestRate = 0;

  // Tenure Duration (with flexible input)
  int tenureMonths = 12;
  TenureUnit? tenureUnit;
  int tenureDuration = 12;

  // Multiple tenure unit support
  int tenureYearsInput = 0;
  int tenureMonthsInput = 0;
  int tenureDaysInput = 0;
  int tenureTotalDays = 0;

  // Compounding Frequency
  FDCompoundingFrequency compoundingFrequency =
      FDCompoundingFrequency.quarterly;

  // FD Type & Payout Frequency
  bool isCumulative = true;
  FDPayoutFrequency payoutFrequency = FDPayoutFrequency.annual;

  // Renewal Details
  String fdName = '';
  String? fdNotes;
  bool autoLinkEnabled = false;

  // Current step
  int currentStep = 0;

  // Calculated values
  late DateTime maturityDate;
  late double maturityValue;
  late double totalInterestAtMaturity;

  FDRenewalWizardController({required this.existingFD}) {
    // Pre-fill with existing FD data
    principal = existingFD.maturityValue;
    interestRate = existingFD.interestRate;
    compoundingFrequency = existingFD.compoundingFrequency;
    isCumulative = existingFD.isCumulative;
    payoutFrequency = existingFD.payoutFrequency;
    fdName = '${existingFD.name} (Renewal)';
    tenureMonths = existingFD.tenureMonths;
    tenureDuration = existingFD.tenureMonths;

    _updateMaturityDate();
    _updateCalculations();
  }

  void updateInterestRate(double rate) {
    interestRate = rate;
    _updateCalculations();
    notifyListeners();
  }

  void updateTenureWithMultipleUnits(int years, int months, int days) {
    tenureYearsInput = years;
    tenureMonthsInput = months;
    tenureDaysInput = days;

    // For validation and reference: calculate approximate total months
    int totalMonths = (years * 12) + months;
    if (totalMonths < 1 && days > 0) totalMonths = 1;

    tenureMonths = totalMonths;
    tenureUnit = null;
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

  void goToStep(int step) {
    FocusManager.instance.primaryFocus?.unfocus();
    currentStep = step;
    notifyListeners();
  }

  void nextStep() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (currentStep < 4) {
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
        return interestRate > 0;
      case 1:
        return tenureMonths > 0;
      case 2:
      case 3:
        return true;
      case 4:
        return fdName.isNotEmpty;
      default:
        return false;
    }
  }

  void _updateMaturityDate() {
    // Proper date arithmetic (handles leap years and varying month lengths)
    DateTime result = renewalDate;

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
          var newMonth = result.month + tenureDuration;
          var newYear = result.year;

          while (newMonth > 12) {
            newMonth -= 12;
            newYear++;
          }

          final maxDayInMonth = DateTime(newYear, newMonth + 1, 0).day;
          final day = result.day > maxDayInMonth ? maxDayInMonth : result.day;

          maturityDate = DateTime(newYear, newMonth, day);
          break;

        case TenureUnit.years:
          maturityDate = DateTime(
            result.year + tenureDuration,
            result.month,
            result.day,
          );
          break;

        case null:
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
      maturityValue = _calculateMaturityValueCumulative(
        principal: principal,
        annualRate: interestRate,
        years: tenureMonths / 12,
        compoundingFrequency: compoundingFrequency,
      );
    } else {
      maturityValue = _calculateMaturityValueNonCumulative(
        principal: principal,
        annualRate: interestRate,
        years: tenureMonths / 12,
        payoutFrequency: payoutFrequency,
      );
    }

    totalInterestAtMaturity = maturityValue - principal;
  }

  double _calculateMaturityValueCumulative({
    required double principal,
    required double annualRate,
    required double years,
    required FDCompoundingFrequency compoundingFrequency,
  }) {
    final int n = _getCompoundingPeriods(compoundingFrequency);
    final double r = annualRate / 100;
    return principal * pow(1 + (r / n), n * years).toDouble();
  }

  double _calculateMaturityValueNonCumulative({
    required double principal,
    required double annualRate,
    required double years,
    required FDPayoutFrequency payoutFrequency,
  }) {
    final double r = annualRate / 100;
    return principal * (1 + (r * years));
  }

  int _getCompoundingPeriods(FDCompoundingFrequency frequency) {
    switch (frequency) {
      case FDCompoundingFrequency.monthly:
        return 12;
      case FDCompoundingFrequency.quarterly:
        return 4;
      case FDCompoundingFrequency.semiAnnual:
        return 2;
      case FDCompoundingFrequency.annual:
        return 1;
    }
  }

  num pow(num x, num y) {
    return x == 0
        ? 0
        : x > 0
            ? _pow(x, y)
            : -_pow(-x, y);
  }

  num _pow(num x, num y) {
    return y < 0
        ? 1 / _pow(x, -y)
        : y == 0
            ? 1
            : x * _pow(x, y - 1);
  }
}
