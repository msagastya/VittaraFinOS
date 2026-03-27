import 'package:flutter/material.dart';
import 'package:vittara_fin_os/logic/recurring_deposit_model.dart';
import 'package:vittara_fin_os/logic/account_model.dart';

class RDWizardController extends ChangeNotifier {
  // Step 0: Account Selection
  Account? selectedAccount;

  // Step 1: Start Date
  DateTime startDate = DateTime.now();

  // Step 2: Installment Amount
  double monthlyAmount = 0;

  // Step 3: Interest Rate
  double interestRate = 0;

  // Step 4: Number of Installments
  int totalInstallments = 12;

  // Step 5: Payment Frequency
  RDPaymentFrequency paymentFrequency = RDPaymentFrequency.monthly;

  // Step 6: Review
  String rdName = '';
  String? rdNotes;
  bool autoPaymentEnabled = false;
  bool debitFromAccount = false;

  // Current step
  int currentStep = 0;

  // Calculated values
  late DateTime maturityDate;
  late double maturityValue;
  late double totalInterestAtMaturity;
  late double totalInvestedAmount;

  RDWizardController() {
    _updateMaturityDate();
    _updateCalculations();
  }

  void selectAccount(Account account) {
    selectedAccount = account;
    notifyListeners();
  }

  void updateStartDate(DateTime date) {
    startDate = date;
    _updateMaturityDate();
    _updateCalculations();
    notifyListeners();
  }

  void updateMonthlyAmount(double amount) {
    monthlyAmount = amount;
    _updateCalculations();
    notifyListeners();
  }

  void updateInterestRate(double rate) {
    interestRate = rate;
    _updateCalculations();
    notifyListeners();
  }

  void updateTotalInstallments(int count) {
    totalInstallments = count;
    _updateMaturityDate();
    _updateCalculations();
    notifyListeners();
  }

  void updatePaymentFrequency(RDPaymentFrequency frequency) {
    paymentFrequency = frequency;
    _updateCalculations();
    notifyListeners();
  }

  void updateRDName(String name) {
    rdName = name;
    notifyListeners();
  }

  void updateRDNotes(String? notes) {
    rdNotes = notes;
    notifyListeners();
  }

  void toggleAutoPayment(bool value) {
    autoPaymentEnabled = value;
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
    if (currentStep < 6) {
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
        return true; // Start date
      case 2:
        return monthlyAmount > 0;
      case 3:
        return interestRate > 0;
      case 4:
        return totalInstallments > 0;
      case 5:
        return true; // Payment frequency
      case 6:
        return rdName.isNotEmpty;
      default:
        return false;
    }
  }

  bool get canSubmit {
    return selectedAccount != null &&
        monthlyAmount > 0 &&
        interestRate > 0 &&
        totalInstallments > 0 &&
        rdName.isNotEmpty;
  }

  void _updateMaturityDate() {
    final monthsPerInstallment = _getMonthsForFrequency(paymentFrequency);
    final totalMonths = totalInstallments * monthsPerInstallment;

    var newMonth = startDate.month + totalMonths;
    var newYear = startDate.year;

    while (newMonth > 12) {
      newMonth -= 12;
      newYear++;
    }

    maturityDate = DateTime(newYear, newMonth, startDate.day);
  }

  void _updateCalculations() {
    totalInvestedAmount = monthlyAmount * totalInstallments;

    maturityValue = RDCalculator.calculateMaturityValue(
      monthlyAmount: monthlyAmount,
      annualRate: interestRate,
      totalInstallments: totalInstallments,
      frequency: paymentFrequency,
    );

    totalInterestAtMaturity = maturityValue - totalInvestedAmount;
  }

  int _getMonthsForFrequency(RDPaymentFrequency frequency) {
    switch (frequency) {
      case RDPaymentFrequency.monthly:
        return 1;
      case RDPaymentFrequency.quarterly:
        return 3;
      case RDPaymentFrequency.semiAnnual:
        return 6;
      case RDPaymentFrequency.annual:
        return 12;
    }
  }

  RecurringDeposit buildRD() {
    final now = DateTime.now();
    final rdId =
        'rd_${DateTime.now().millisecondsSinceEpoch}_${selectedAccount?.id ?? ''}';

    // Generate installment schedule
    final installments = RDCalculator.generateInstallmentSchedule(
      rdId: rdId,
      monthlyAmount: monthlyAmount,
      startDate: startDate,
      totalInstallments: totalInstallments,
      frequency: paymentFrequency,
      annualRate: interestRate,
    );

    return RecurringDeposit(
      id: rdId,
      name: rdName,
      monthlyAmount: monthlyAmount,
      interestRate: interestRate,
      totalInstallments: totalInstallments,
      paymentFrequency: paymentFrequency,
      linkedAccountId: selectedAccount!.id,
      linkedAccountName: selectedAccount!.name,
      autoPaymentEnabled: autoPaymentEnabled,
      createdDate: now,
      startDate: startDate,
      maturityDate: maturityDate,
      status: RDStatus.active,
      installments: installments,
      totalInvestedAmount: totalInvestedAmount,
      totalInterestAtMaturity: totalInterestAtMaturity,
      maturityValue: maturityValue,
      estimatedAccruedValue: monthlyAmount, // First installment invested
      realizedValue: monthlyAmount,
      notes: rdNotes,
      bankName: selectedAccount?.bankName,
      bankAccountNumber: null,
      metadata: {
        'debitedFromAccount': debitFromAccount,
      },
    );
  }

  void reset() {
    selectedAccount = null;
    startDate = DateTime.now();
    monthlyAmount = 0;
    interestRate = 0;
    totalInstallments = 12;
    paymentFrequency = RDPaymentFrequency.monthly;
    rdName = '';
    rdNotes = null;
    autoPaymentEnabled = false;
    debitFromAccount = false;
    currentStep = 0;
    _updateMaturityDate();
    _updateCalculations();
    notifyListeners();
  }
}
