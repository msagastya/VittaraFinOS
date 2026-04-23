import 'package:vittara_fin_os/services/network/secure_network_client.dart';
import 'package:vittara_fin_os/utils/logger.dart';

class StockSearchResult {
  final String symbol;
  final String name;
  final String exchange;
  final String type;

  StockSearchResult({
    required this.symbol,
    required this.name,
    required this.exchange,
    required this.type,
  });

  factory StockSearchResult.fromJson(Map<String, dynamic> json) {
    return StockSearchResult(
      symbol: json['symbol'] ?? '',
      name: json['shortname'] ?? json['longname'] ?? '',
      exchange: json['exchange'] ?? '',
      type: json['quoteType'] ?? '',
    );
  }
}

class StockApiService {
  final AppLogger _logger = AppLogger();
  static const String _baseUrl =
      'https://query1.finance.yahoo.com/v1/finance/search';

  Future<List<StockSearchResult>> searchStocks(String query) async {
    if (query.isEmpty) return [];
    try {
      final url = Uri.parse('$_baseUrl?q=$query&quotesCount=20&newsCount=0');
      final data = await SecureNetworkClient.instance.getJson(url);
      final quotes = data['quotes'] as List<dynamic>? ?? [];
      return quotes
          .where((q) => q['quoteType'] == 'EQUITY' || q['quoteType'] == 'ETF')
          .map((q) => StockSearchResult.fromJson(q as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _logger.error('Error searching stocks', error: e, context: 'StockApiService');
      rethrow;
    }
  }

  Future<double?> getStockPrice(String symbol) async {
    try {
      final url = Uri.parse(
          'https://query1.finance.yahoo.com/v8/finance/chart/$symbol?interval=1d&range=1d');
      final data = await SecureNetworkClient.instance.getJson(url);
      final result = (data['chart']?['result'] as List?)?.firstOrNull;
      return (result?['meta']?['regularMarketPrice'] as num?)?.toDouble();
    } catch (e) {
      _logger.error('Error fetching price for $symbol',
          error: e, context: 'StockApiService');
      return null;
    }
  }
}
