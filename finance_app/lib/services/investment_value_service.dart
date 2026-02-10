import 'package:vittara_fin_os/logic/investment_model.dart';
import 'package:vittara_fin_os/services/gold_price_service.dart';
import 'package:vittara_fin_os/services/nav_service.dart';
import 'package:vittara_fin_os/services/stock_api_service.dart';
import 'package:vittara_fin_os/utils/logger.dart';

class InvestmentValueService {
  final StockApiService _stockApi = StockApiService();
  final NAVService _navService = NAVService();
  final AppLogger _logger = AppLogger();

  Future<double?> fetchCurrentValue(Investment investment) async {
    switch (investment.type) {
      case InvestmentType.stocks:
        return _fetchStockValue(investment);
      case InvestmentType.mutualFund:
        return _fetchMutualFundValue(investment);
      case InvestmentType.digitalGold:
        return _fetchDigitalGoldValue(investment);
      default:
        return investment.metadata != null
            ? _asDouble(investment.metadata!['currentValue'])
            : null;
    }
  }

  Future<double?> _fetchStockValue(Investment investment) async {
    final metadata = investment.metadata ?? {};
    final symbol = (metadata['symbol'] as String?)?.trim();
    final qty = _asDouble(metadata['qty']) ?? 0;

    if (symbol?.isEmpty ?? true || qty == 0) {
      _logger.warning('Missing stock symbol/qty for ${investment.name}', context: 'InvestmentValueService');
      return metadata.containsKey('currentValue')
          ? _asDouble(metadata['currentValue'])
          : null;
    }

    final price = await _stockApi.getStockPrice(symbol!);
    if (price != null) {
      return price * qty;
    }

    return metadata.containsKey('currentValue') ? _asDouble(metadata['currentValue']) : null;
  }

  Future<double?> _fetchMutualFundValue(Investment investment) async {
    final metadata = investment.metadata ?? {};
    final schemeCode = metadata['schemeCode']?.toString();
    final units = _asDouble(metadata['units']) ?? 0;

    if (schemeCode == null || units == 0) {
      return metadata.containsKey('currentValue') ? _asDouble(metadata['currentValue']) : null;
    }

    final navData = await _navService.getCurrentNAV(schemeCode);
    if (navData != null && navData.nav > 0) {
      return units * navData.nav;
    }

    return metadata.containsKey('currentValue') ? _asDouble(metadata['currentValue']) : null;
  }

  Future<double?> _fetchDigitalGoldValue(Investment investment) async {
    final metadata = investment.metadata ?? {};
    final weight = _asDouble(metadata['weightInGrams']) ?? 0;

    if (weight == 0) {
      return metadata.containsKey('currentValue') ? _asDouble(metadata['currentValue']) : null;
    }

    final currentPrice = await GoldPriceService.fetchCurrentGoldPrice();
    if (currentPrice != null && currentPrice > 0) {
      return weight * currentPrice;
    }

    return metadata.containsKey('currentValue') ? _asDouble(metadata['currentValue']) : null;
  }

  double? _asDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}
