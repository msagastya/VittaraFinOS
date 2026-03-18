import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GoldPriceService {
  static final Logger _logger = Logger();

  static const String _cacheKey = 'gold_price_cached';
  static const String _cacheTimestampKey = 'gold_price_cached_at';
  static const Duration _cacheTTL = Duration(hours: 1);

  // Yahoo Finance: Gold Futures (COMEX) — free, no API key, reliable
  static const String _yahooGoldUrl =
      'https://query1.finance.yahoo.com/v8/finance/chart/GC=F?interval=1d&range=1d';
  static const String _yahooGoldUrlAlt =
      'https://query2.finance.yahoo.com/v8/finance/chart/GC=F?interval=1d&range=1d';

  // Exchange rate fallbacks
  static const String _exchangeRatePrimary =
      'https://open.er-api.com/v6/latest/USD';
  static const String _exchangeRateFallback =
      'https://api.exchangerate-api.com/v4/latest/USD';

  /// Fetch current gold price per gram in INR.
  /// Returns cached value if fresh (< 1 hour old), otherwise fetches live.
  static Future<double?> fetchCurrentGoldPrice() async {
    final cached = await _getCachedPrice();
    if (cached != null) {
      _logger.i('Using cached gold price: ₹$cached/g');
      return cached;
    }

    // Step 1: Get USD gold price per troy ounce from Yahoo Finance
    final priceUsdPerOz = await _fetchGoldUsdFromYahoo();
    if (priceUsdPerOz != null && priceUsdPerOz > 0) {
      // Step 2: Convert to INR per gram
      final exchangeRate = await _getUsdInrRate();
      if (exchangeRate != null && exchangeRate > 0) {
        // (USD/oz) × (INR/USD) ÷ (31.1035 g/oz) × MCX markup
        final pricePerGram = (priceUsdPerOz * exchangeRate / 31.1035) * 1.185;
        _logger.i(
            '✓ Yahoo Finance + ExRate: ₹${pricePerGram.toStringAsFixed(2)}/gram '
            '(gold=\$$priceUsdPerOz/oz, rate=₹$exchangeRate)');
        await _cachePrice(pricePerGram);
        return pricePerGram;
      }
    }

    // All sources failed — return stale cache rather than null
    final stale = await _getStalePrice();
    if (stale != null) {
      _logger.w('Using stale cached gold price: ₹$stale/g');
      return stale;
    }

    _logger.w('❌ All gold price sources failed');
    return null;
  }

  /// Fetch USD gold price per troy ounce via Yahoo Finance
  static Future<double?> _fetchGoldUsdFromYahoo() async {
    for (final url in [_yahooGoldUrl, _yahooGoldUrlAlt]) {
      try {
        final response = await http.get(
          Uri.parse(url),
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 Chrome/120.0.0.0 Mobile Safari/537.36',
            'Accept': 'application/json',
          },
        ).timeout(const Duration(seconds: 8));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final result = (data['chart']?['result'] as List?)?.firstOrNull;
          if (result != null) {
            final price =
                (result['meta']?['regularMarketPrice'] as num?)?.toDouble();
            if (price != null && price > 0) {
              _logger.i('Yahoo Finance gold: \$$price/oz');
              return price;
            }
          }
        }
      } catch (e) {
        _logger.w('Yahoo Finance ($url) failed: $e');
      }
    }
    return null;
  }

  /// Get live USD → INR exchange rate
  static Future<double?> _getUsdInrRate() async {
    for (final url in [_exchangeRatePrimary, _exchangeRateFallback]) {
      try {
        final response = await http.get(
          Uri.parse(url),
          headers: {'User-Agent': 'VittaraFinOS/1.0'},
        ).timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final rates = data['rates'] as Map<String, dynamic>?;
          final rate = (rates?['INR'] as num?)?.toDouble();
          if (rate != null && rate > 0) {
            _logger.i('ExRate: 1 USD = ₹$rate (from $url)');
            return rate;
          }
        }
      } catch (e) {
        _logger.w('ExRate ($url) failed: $e');
      }
    }
    return null;
  }

  static Future<double?> _getCachedPrice() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt(_cacheTimestampKey);
      if (timestamp == null) return null;
      final age = DateTime.now().millisecondsSinceEpoch - timestamp;
      if (age > _cacheTTL.inMilliseconds) return null;
      return prefs.getDouble(_cacheKey);
    } catch (_) {
      return null;
    }
  }

  static Future<double?> _getStalePrice() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getDouble(_cacheKey);
    } catch (_) {
      return null;
    }
  }

  static Future<void> _cachePrice(double price) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_cacheKey, price);
      await prefs.setInt(
          _cacheTimestampKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      _logger.w('Failed to cache gold price: $e');
    }
  }

  /// Returns the DateTime when the gold price was last cached, or null.
  static Future<DateTime?> getLastFetchedTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt(_cacheTimestampKey);
      if (timestamp == null) return null;
      return DateTime.fromMillisecondsSinceEpoch(timestamp);
    } catch (_) {
      return null;
    }
  }

  // Legacy stub — use fetchCurrentGoldPrice() instead
  static double? getCachedPrice() => null;
}
