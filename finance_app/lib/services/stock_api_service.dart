import 'dart:convert';
import 'package:http/http.dart' as http;
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
      final response = await http.get(url, headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
      }).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final quotes = data['quotes'] as List<dynamic>? ?? [];

        return quotes
            .where((q) => q['quoteType'] == 'EQUITY' || q['quoteType'] == 'ETF')
            .map((q) => StockSearchResult.fromJson(q))
            .toList();
      } else {
        _logger.error('Failed to search stocks: ${response.statusCode}',
            error: response.body, context: 'StockApiService');
        throw Exception('Failed to load stock data');
      }
    } catch (e) {
      _logger.error('Error searching stocks',
          error: e, context: 'StockApiService');
      rethrow;
    }
  }

  Future<double?> getStockPrice(String symbol) async {
    // Note: Yahoo Finance chart API often works without key for simple current price
    // https://query1.finance.yahoo.com/v8/finance/chart/AAPL?interval=1d&range=1d
    try {
      final url = Uri.parse(
          'https://query1.finance.yahoo.com/v8/finance/chart/$symbol?interval=1d&range=1d');
      final response = await http.get(url, headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
      }).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final result = data['chart']['result'][0];
        final meta = result['meta'];
        return (meta['regularMarketPrice'] as num?)?.toDouble();
      }
    } catch (e) {
      _logger.error('Error fetching price for $symbol',
          error: e, context: 'StockApiService');
    }
    return null;
  }
}
