import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GoldPriceService {
  static final Logger _logger = Logger();

  static const String _cacheKey = 'gold_price_cached';
  static const String _cacheTimestampKey = 'gold_price_cached_at';
  static const Duration _cacheTTL = Duration(hours: 1);

  /// Fetch current gold price per gram in INR.
  /// Returns cached value if fresh (< 1 hour old), otherwise fetches live.
  static Future<double?> fetchCurrentGoldPrice() async {
    // Return cached price if still fresh
    final cached = await _getCachedPrice();
    if (cached != null) {
      _logger.i('Using cached gold price: ₹$cached/g');
      return cached;
    }

    // Try primary source: goldprice.org (free, no API key, most reliable)
    var price = await _fetchFromGoldPriceOrg();
    if (price != null) {
      await _cachePrice(price);
      return price;
    }

    // Try secondary source: International USD price + INR conversion
    price = await _fetchUsdGoldWithConversion();
    if (price != null) {
      await _cachePrice(price);
      return price;
    }

    // All sources failed — return stale cache if available rather than null
    final stale = await _getStalePrice();
    if (stale != null) {
      _logger.w('Using stale cached gold price: ₹$stale/g');
      return stale;
    }

    _logger
        .w('❌ All gold price sources failed - unable to fetch current price');
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
      _logger.w('Failed to cache gold price', error: e);
    }
  }

  /// Get cached gold price synchronously — for quick display without API call.
  /// Returns null if no cached price available.
  static double? getCachedPrice() =>
      null; // legacy stub; use fetchCurrentGoldPrice

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

  /// Source 1: goldprice.org - Most reliable, free, no API key
  /// Endpoint: https://data-asg.goldprice.org/dbXRates/INR
  /// Returns: xauPrice in INR per troy ounce, convert to per gram
  static Future<double?> _fetchFromGoldPriceOrg() async {
    try {
      final response = await http.get(
        Uri.parse('https://data-asg.goldprice.org/dbXRates/INR'),
        headers: {
          'User-Agent': 'VittaraFinOS/1.0 (Android)',
          'Accept': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw Exception('Timeout'),
      );

      if (response.statusCode == 200) {
        try {
          // Response format: {"items":[{"curr":"INR","xauPrice":441109.0387,...}]}
          final data = jsonDecode(response.body) as Map<String, dynamic>;

          if (data.containsKey('items') && data['items'] is List) {
            final items = data['items'] as List;
            if (items.isNotEmpty) {
              final item = items[0] as Map<String, dynamic>;

              if (item.containsKey('xauPrice')) {
                // xauPrice is per troy ounce in INR
                final pricePerOz = (item['xauPrice'] as num).toDouble();

                if (pricePerOz > 0) {
                  // Convert troy ounce to gram: 1 troy oz = 31.1035 grams
                  var pricePerGram = pricePerOz / 31.1035;

                  // Apply MCX adjustment: spot prices need ~18-20% markup to match MCX retail prices
                  // MCX includes GST, making charges, and local market factors
                  pricePerGram = pricePerGram * 1.185; // 18.5% markup

                  _logger.i(
                      '✓ GoldPrice.org (MCX Adjusted): ₹${pricePerGram.toStringAsFixed(2)}/gram');
                  return pricePerGram;
                }
              }
            }
          }
        } catch (parseError) {
          _logger.w('GoldPrice.org parse error: $parseError');
        }
      }
    } catch (e) {
      _logger.w('GoldPrice.org fetch failed: $e');
    }
    return null;
  }

  /// Source 2: USD gold price (per troy ounce) + live INR exchange rate
  /// Converts USD spot price to INR per gram
  static Future<double?> _fetchUsdGoldWithConversion() async {
    try {
      // Fetch USD gold price per troy ounce
      final response = await http.get(
        Uri.parse('https://data-asg.goldprice.org/dbXRates/USD'),
        headers: {
          'User-Agent': 'VittaraFinOS/1.0 (Android)',
          'Accept': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw Exception('Timeout'),
      );

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body) as Map<String, dynamic>;

          if (data.containsKey('items') && data['items'] is List) {
            final items = data['items'] as List;
            if (items.isNotEmpty) {
              final item = items[0] as Map<String, dynamic>;

              if (item.containsKey('xauPrice')) {
                final priceUsdPerOz = (item['xauPrice'] as num).toDouble();

                if (priceUsdPerOz > 0) {
                  // Get live exchange rate
                  final exchangeRate = await _getExchangeRate();
                  if (exchangeRate != null && exchangeRate > 0) {
                    // Convert: (USD/oz) * (INR/USD) / (grams/oz)
                    var priceINRPerGram =
                        (priceUsdPerOz * exchangeRate) / 31.1035;

                    // Apply MCX adjustment: spot prices need ~18-20% markup to match MCX retail prices
                    priceINRPerGram = priceINRPerGram * 1.185; // 18.5% markup

                    _logger.i(
                        '✓ USD Gold + ExRate (MCX Adjusted): ₹${priceINRPerGram.toStringAsFixed(2)}/gram');
                    return priceINRPerGram;
                  }
                }
              }
            }
          }
        } catch (parseError) {
          _logger.w('USD Gold conversion parse error: $parseError');
        }
      }
    } catch (e) {
      _logger.w('USD Gold price fetch failed: $e');
    }
    return null;
  }

  /// Get live USD to INR exchange rate
  static Future<double?> _getExchangeRate() async {
    try {
      // Primary forex source
      final response = await http.get(
        Uri.parse('https://api.exchangerate-api.com/v4/latest/USD'),
        headers: {
          'User-Agent': 'VittaraFinOS/1.0 (Android)',
        },
      ).timeout(
        const Duration(seconds: 3),
        onTimeout: () => throw Exception('Timeout'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final rates = data['rates'] as Map<String, dynamic>;
        final rate = (rates['INR'] as num).toDouble();
        _logger.i('Exchange rate: 1 USD = ₹$rate');
        return rate;
      }
    } catch (e) {
      _logger.w('ExchangeRate-API failed: $e');
    }

    // Fallback forex source
    try {
      final response = await http.get(
        Uri.parse('https://open.er-api.com/v6/latest/USD'),
        headers: {
          'User-Agent': 'VittaraFinOS/1.0 (Android)',
        },
      ).timeout(
        const Duration(seconds: 3),
        onTimeout: () => throw Exception('Timeout'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final rates = data['rates'] as Map<String, dynamic>;
        final rate = (rates['INR'] as num).toDouble();
        _logger.i('Exchange rate (alt): 1 USD = ₹$rate');
        return rate;
      }
    } catch (e) {
      _logger.w('Open.er-api.com failed: $e');
    }

    return null;
  }
}

// API Sources Used:
// 1. goldprice.org/dbXRates/INR (primary - direct INR per troy ounce)
//    - Free, no authentication required
//    - Direct INR pricing (most reliable for India)
//    - Fallback converts troy ounce to grams
//
// 2. goldprice.org/dbXRates/USD + exchangerate-api.com (secondary)
//    - USD per ounce converted to INR using live exchange rate
//    - Reliable fallback if INR endpoint is slow
//
// Returns null if ALL sources fail (NO hardcoded fallbacks)
// Caller MUST handle null gracefully in UI
