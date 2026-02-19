import 'package:flutter/material.dart';
import 'package:vittara_fin_os/logic/bond_cashflow_model.dart';

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

  // ---------------------------------------------------------------------------
  // Legacy step compatibility fields.
  // These are used by older Bond step widgets still present in the codebase.
  // ---------------------------------------------------------------------------
  BondType selectedType = BondType.fixedCoupon;
  DateTime purchaseDate = DateTime.now();
  double purchasePrice = 0;
  double faceValue = 1000;
  int paymentsPerYear = 1; // 1=annual, 2=semi annual, 12=monthly

  double? fixedCouponRate; // percentage
  double? zeroMaturityValue;
  double? interestRate; // percentage for amortizing
  double? referenceRate; // percentage for floating
  double? spread; // percentage over reference

  String? purchaseAccountId;
  String? purchaseAccountName;
  bool autoDebitFromPurchaseAccount = false;

  String? paymentAccountId;
  String? paymentAccountName;
  bool autoTransferPayments = false;

  bool linkToNPS = false;
  String? linkedNpsId;
  bool createNewNps = false;
  String newNpsName = '';

  int get currentStep => _currentStep;
  int get totalSteps =>
      6; // 0-5 (6 steps: Name, Amount, Account, Frequency, Dates, Review)

  int get _effectivePaymentsPerYear {
    if (selectedType == BondType.monthlyFixed) return 12;
    return paymentsPerYear.clamp(1, 12).toInt();
  }

  DateTime get _effectiveMaturityDate {
    if (maturityDate.isAfter(purchaseDate)) return maturityDate;
    return purchaseDate.add(const Duration(days: 365));
  }

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
    if (accountId != null && purchaseAccountId == null) {
      purchaseAccountId = accountId;
      purchaseAccountName = accountName;
    }
    if (accountId == null) {
      autoDebit = false;
      autoDebitFromPurchaseAccount = false;
    }
    notifyListeners();
  }

  void updateAutoDebit(bool value) {
    autoDebit = value;
    autoDebitFromPurchaseAccount = value;
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

  // Legacy API methods used by old step widgets.
  void selectType(BondType type) {
    selectedType = type;
    if (type == BondType.monthlyFixed) {
      paymentsPerYear = 12;
    }
    notifyListeners();
  }

  void updatePurchaseDate(DateTime date) {
    purchaseDate = date;
    notifyListeners();
  }

  void updatePurchasePrice(double value) {
    purchasePrice = value;
    notifyListeners();
  }

  void updateFaceValue(double value) {
    faceValue = value;
    notifyListeners();
  }

  void updatePaymentsPerYear(int value) {
    paymentsPerYear = value.clamp(1, 12);
    notifyListeners();
  }

  void updateFixedCouponRate(double value) {
    fixedCouponRate = value;
    notifyListeners();
  }

  void updateZeroMaturityValue(double value) {
    zeroMaturityValue = value;
    notifyListeners();
  }

  void updateInterestRate(double value) {
    interestRate = value;
    notifyListeners();
  }

  void updateReferenceRate(double value) {
    referenceRate = value;
    notifyListeners();
  }

  void updateSpread(double value) {
    spread = value;
    notifyListeners();
  }

  void updatePurchaseAccount(String accountId, String accountName) {
    purchaseAccountId = accountId;
    purchaseAccountName = accountName;
    linkedAccountId ??= accountId;
    linkedAccountName ??= accountName;
    notifyListeners();
  }

  void updatePaymentAccount(String accountId, String accountName) {
    paymentAccountId = accountId;
    paymentAccountName = accountName;
    notifyListeners();
  }

  void updateAutoTransfer(bool value) {
    autoTransferPayments = value;
    notifyListeners();
  }

  void updateLinkToNPS(bool value) {
    linkToNPS = value;
    if (!value) {
      linkedNpsId = null;
      createNewNps = false;
      newNpsName = '';
    }
    notifyListeners();
  }

  void updateLinkedNps(String? npsId) {
    linkedNpsId = npsId;
    if (npsId != null) {
      createNewNps = false;
    }
    notifyListeners();
  }

  void updateCreateNewNps(bool value) {
    createNewNps = value;
    if (value) {
      linkedNpsId = null;
    } else {
      newNpsName = '';
    }
    notifyListeners();
  }

  void updateNewNpsName(String value) {
    newNpsName = value;
    notifyListeners();
  }

  List<BondCashFlow> get generatedCashFlows {
    if (purchasePrice <= 0 || faceValue <= 0) {
      return const [];
    }

    final maturity = _effectiveMaturityDate;
    final annualFixedRate =
        (fixedCouponRate ?? 0).clamp(0.0, 100.0).toDouble() / 100;

    switch (selectedType) {
      case BondType.zeroCoupon:
        return CashFlowGenerator.generateZeroCouponCashFlows(
          purchaseDate: purchaseDate,
          purchasePrice: purchasePrice,
          maturityDate: maturity,
          maturityValue: zeroMaturityValue != null && zeroMaturityValue! > 0
              ? zeroMaturityValue!
              : faceValue,
        );
      case BondType.amortizing:
        return CashFlowGenerator.generateAmortizingCashFlows(
          purchaseDate: purchaseDate,
          purchasePrice: purchasePrice,
          maturityDate: maturity,
          faceValue: faceValue,
          annualInterestRate: (interestRate ?? fixedCouponRate ?? 0)
                  .clamp(0.0, 100.0)
                  .toDouble() /
              100,
          paymentsPerYear: _effectivePaymentsPerYear,
        );
      case BondType.floatingRate:
        final annualFloatingRate = ((referenceRate ?? 0) + (spread ?? 0))
                .clamp(0.0, 100.0)
                .toDouble() /
            100;
        return CashFlowGenerator.generateFixedCouponCashFlows(
          purchaseDate: purchaseDate,
          purchasePrice: purchasePrice,
          maturityDate: maturity,
          faceValue: faceValue,
          annualCouponRate: annualFloatingRate,
          paymentsPerYear: _effectivePaymentsPerYear,
        );
      case BondType.monthlyFixed:
        return CashFlowGenerator.generateFixedCouponCashFlows(
          purchaseDate: purchaseDate,
          purchasePrice: purchasePrice,
          maturityDate: maturity,
          faceValue: faceValue,
          annualCouponRate: annualFixedRate,
          paymentsPerYear: 12,
        );
      case BondType.fixedCoupon:
        return CashFlowGenerator.generateFixedCouponCashFlows(
          purchaseDate: purchaseDate,
          purchasePrice: purchasePrice,
          maturityDate: maturity,
          faceValue: faceValue,
          annualCouponRate: annualFixedRate,
          paymentsPerYear: _effectivePaymentsPerYear,
        );
    }
  }

  double get totalInvested => generatedCashFlows
      .where((cf) => cf.amount < 0)
      .fold(0.0, (sum, cf) => sum + cf.amount.abs());

  double get totalReceived => generatedCashFlows
      .where((cf) => cf.amount > 0)
      .fold(0.0, (sum, cf) => sum + cf.amount);

  double get gainLoss => totalReceived - totalInvested;

  double get gainLossPercent =>
      totalInvested > 0 ? (gainLoss / totalInvested) * 100 : 0.0;

  double? get calculatedYield {
    final flows = generatedCashFlows;
    if (flows.length < 2) return null;
    try {
      return BondYieldCalculator.calculateYield(flows);
    } catch (_) {
      return null;
    }
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
