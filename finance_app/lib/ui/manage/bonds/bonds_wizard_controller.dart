import 'package:flutter/foundation.dart';
import 'package:vittara_fin_os/logic/bonds_model.dart';

class BondsWizardController extends ChangeNotifier {
  int _currentStep = 0;

  // Step 0: Bond Selection
  BondType? selectedBondType;
  String? selectedIssuer;
  double? faceValue;
  String? bondName;

  // Step 1: Bond Details
  double? couponRate; // Annual percentage
  CouponFrequency couponFrequency = CouponFrequency.annual;
  int purchaseQuantity = 1;
  String? creditRating;

  // Step 2: Purchase Information
  DateTime purchaseDate = DateTime.now();
  double? purchasePrice; // Price per bond
  String? notes;

  // Step 3: Account Selection
  String? selectedAccountId;
  String? selectedAccountName;

  int get currentStep => _currentStep;

  void updateBondType(BondType type) {
    selectedBondType = type;
    notifyListeners();
  }

  void updateIssuer(String issuer) {
    selectedIssuer = issuer;
    notifyListeners();
  }

  void updateBondName(String name) {
    bondName = name;
    notifyListeners();
  }

  void updateFaceValue(double value) {
    faceValue = value;
    notifyListeners();
  }

  void updateCouponRate(double rate) {
    couponRate = rate;
    notifyListeners();
  }

  void updateCouponFrequency(CouponFrequency frequency) {
    couponFrequency = frequency;
    notifyListeners();
  }

  void updatePurchaseQuantity(int quantity) {
    purchaseQuantity = quantity;
    notifyListeners();
  }

  void updateCreditRating(String rating) {
    creditRating = rating;
    notifyListeners();
  }

  void updatePurchaseDate(DateTime date) {
    purchaseDate = date;
    notifyListeners();
  }

  void updatePurchasePrice(double price) {
    purchasePrice = price;
    notifyListeners();
  }

  void updateNotes(String? note) {
    notes = note;
    notifyListeners();
  }

  void updateAccountSelection(String accountId, String accountName) {
    selectedAccountId = accountId;
    selectedAccountName = accountName;
    notifyListeners();
  }

  // Calculations
  double get totalCost {
    if (purchaseQuantity == 0 || purchasePrice == null) return 0;
    return purchaseQuantity * purchasePrice!;
  }

  double get maturityValue {
    if (purchaseQuantity == 0 || faceValue == null) return 0;
    return purchaseQuantity * faceValue!;
  }

  double? calculateYTM() {
    if (purchasePrice == null ||
        faceValue == null ||
        couponRate == null ||
        purchaseDate.isAfter(DateTime.now())) {
      return null;
    }

    final now = DateTime.now();
    final yearsToMaturity = 5.0; // Placeholder, should be calculated from maturity date
    final annualCoupon = (couponRate! / 100) * faceValue!;

    try {
      return BondCalculator.calculateYieldToMaturity(
        currentPrice: purchasePrice!,
        faceValue: faceValue!,
        annualCoupon: annualCoupon,
        yearsToMaturity: yearsToMaturity.toInt(),
      );
    } catch (e) {
      return null;
    }
  }

  double get annualCouponPayment {
    if (couponRate == null || faceValue == null) return 0;
    return (couponRate! / 100) * faceValue! * purchaseQuantity;
  }

  double get couponPerPayment {
    if (couponRate == null || faceValue == null) return 0;
    final annual = (couponRate! / 100) * faceValue!;
    final paymentsPerYear =
        couponFrequency == CouponFrequency.annual
            ? 1
            : couponFrequency == CouponFrequency.semiAnnual
                ? 2
                : couponFrequency == CouponFrequency.quarterly
                    ? 4
                    : 12;
    return (annual / paymentsPerYear) * purchaseQuantity;
  }

  bool canProceed() {
    switch (_currentStep) {
      case 0:
        return selectedBondType != null &&
            selectedIssuer != null &&
            faceValue != null &&
            faceValue! > 0 &&
            bondName != null &&
            bondName!.isNotEmpty;
      case 1:
        return couponRate != null &&
            couponRate! > 0 &&
            purchaseQuantity > 0;
      case 2:
        return purchasePrice != null && purchasePrice! > 0;
      case 3:
        return selectedAccountId != null;
      default:
        return false;
    }
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

  void resetWizard() {
    _currentStep = 0;
    selectedBondType = null;
    selectedIssuer = null;
    faceValue = null;
    bondName = null;
    couponRate = null;
    couponFrequency = CouponFrequency.annual;
    purchaseQuantity = 1;
    creditRating = null;
    purchaseDate = DateTime.now();
    purchasePrice = null;
    notes = null;
    selectedAccountId = null;
    selectedAccountName = null;
    notifyListeners();
  }
}
