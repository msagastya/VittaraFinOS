import 'package:flutter/widgets.dart';
import 'package:vittara_fin_os/logic/commodities_model.dart';

class CommoditiesWizardController extends ChangeNotifier {
  int _currentStep = 0;

  CommodityType selectedType = CommodityType.gold;
  String commodityName = '';
  double? quantity;
  String? unit;
  double? buyPrice;
  double? currentPrice;
  String? exchange;
  DateTime purchaseDate = DateTime.now();
  TradePosition position = TradePosition.long;
  String? notes;

  int get currentStep => _currentStep;

  double get totalCost => (quantity ?? 0) * (buyPrice ?? 0);
  double get currentValue => (quantity ?? 0) * (currentPrice ?? 0);
  double get gainLoss => currentValue - totalCost;
  double get gainLossPercent {
    if (totalCost == 0) return 0;
    return (gainLoss / totalCost) * 100;
  }

  bool canProceed() {
    switch (_currentStep) {
      case 0:
        // Type selection step
        return commodityName.isNotEmpty;
      case 1:
        // Quantity and unit step
        return quantity != null &&
            quantity! > 0 &&
            unit != null &&
            unit!.isNotEmpty;
      case 2:
        // Price and exchange step
        return buyPrice != null &&
            buyPrice! > 0 &&
            exchange != null &&
            exchange!.isNotEmpty;
      case 3:
        // Current price and position step
        return currentPrice != null && currentPrice! > 0;
      case 4:
        // Review step
        return true;
      default:
        return false;
    }
  }

  void selectType(CommodityType type) {
    selectedType = type;
    notifyListeners();
  }

  void updateCommodityName(String name) {
    commodityName = name;
    notifyListeners();
  }

  void updateQuantity(double qty) {
    quantity = qty;
    notifyListeners();
  }

  void updateUnit(String u) {
    unit = u;
    notifyListeners();
  }

  void updateBuyPrice(double price) {
    buyPrice = price;
    notifyListeners();
  }

  void updateCurrentPrice(double price) {
    currentPrice = price;
    notifyListeners();
  }

  void updateExchange(String exch) {
    exchange = exch;
    notifyListeners();
  }

  void updatePurchaseDate(DateTime date) {
    purchaseDate = date;
    notifyListeners();
  }

  void selectPosition(TradePosition pos) {
    position = pos;
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
