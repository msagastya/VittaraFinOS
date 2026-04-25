import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vittara_fin_os/logic/investment_model.dart';
import 'package:vittara_fin_os/services/gold_price_service.dart';
import 'package:vittara_fin_os/services/nav_service.dart';
import 'package:vittara_fin_os/services/stock_api_service.dart';
import 'package:vittara_fin_os/utils/logger.dart';

class InvestmentValueResult {
  final double? currentValue;
  final double? currentNAV;

  InvestmentValueResult({this.currentValue, this.currentNAV});
}

class InvestmentValueService {
  final StockApiService _stockApi = StockApiService();
  final NAVService _navService = NAVService();
  final AppLogger _logger = AppLogger();

  Future<InvestmentValueResult?> fetchCurrentValue(
    Investment investment, {
    bool forceRefresh = false,
  }) async {
    switch (investment.type) {
      case InvestmentType.stocks:
        return _fetchStockValue(investment);
      case InvestmentType.mutualFund:
        return _fetchMutualFundValue(investment, forceRefresh: forceRefresh);
      case InvestmentType.digitalGold:
        return _fetchDigitalGoldValue(investment);
      default:
        return Future.value(InvestmentValueResult(
            currentValue: _calculateFallbackCurrentValue(investment)));
    }
  }

  Future<InvestmentValueResult?> _fetchStockValue(Investment investment) async {
    final metadata = investment.metadata ?? {};
    final symbol = (metadata['symbol'] as String?)?.trim();
    final qty = _asDouble(metadata['qty']) ?? 0;

    if (symbol?.isEmpty ?? true || qty == 0) {
      _logger.warning('Missing stock symbol/qty for ${investment.name}',
          context: 'InvestmentValueService');
      return metadata.containsKey('currentValue')
          ? InvestmentValueResult(
              currentValue: _asDouble(metadata['currentValue']))
          : null;
    }

    final price = await _stockApi.getStockPrice(symbol!);
    if (price != null) {
      return InvestmentValueResult(currentValue: price * qty);
    }

    return metadata.containsKey('currentValue')
        ? InvestmentValueResult(
            currentValue: _asDouble(metadata['currentValue']))
        : null;
  }

  Future<InvestmentValueResult?> _fetchMutualFundValue(
    Investment investment, {
    bool forceRefresh = false,
  }) async {
    final metadata = investment.metadata ?? {};
    final schemeCode = _normalizeSchemeCode(metadata['schemeCode']);
    final units = _asDouble(metadata['units']) ?? 0;

    if (schemeCode == null || units <= 0) {
      return metadata.containsKey('currentValue')
          ? InvestmentValueResult(
              currentValue: _asDouble(metadata['currentValue']),
              currentNAV: _asDouble(metadata['currentNAV']),
            )
          : null;
    }

    final candidates = _schemeCodeCandidates(schemeCode);
    for (final code in candidates) {
      final navData = await _navService.getCurrentNAV(
        code,
        forceRefresh: forceRefresh,
      );
      if (navData != null && navData.nav > 0) {
        return InvestmentValueResult(
          currentValue: units * navData.nav,
          currentNAV: navData.nav,
        );
      }
    }

    return metadata.containsKey('currentValue')
        ? InvestmentValueResult(
            currentValue: _asDouble(metadata['currentValue']),
            currentNAV: _asDouble(metadata['currentNAV']),
          )
        : null;
  }

  Future<InvestmentValueResult?> _fetchDigitalGoldValue(
      Investment investment) async {
    final metadata = investment.metadata ?? {};
    final weight = _asDouble(metadata['weightInGrams']) ?? 0;

    if (weight == 0) {
      return metadata.containsKey('currentValue')
          ? InvestmentValueResult(
              currentValue: _asDouble(metadata['currentValue']))
          : null;
    }

    final currentPrice = await GoldPriceService.fetchCurrentGoldPrice();
    if (currentPrice != null && currentPrice > 0) {
      return InvestmentValueResult(currentValue: weight * currentPrice);
    }

    return metadata.containsKey('currentValue')
        ? InvestmentValueResult(
            currentValue: _asDouble(metadata['currentValue']))
        : null;
  }

  double? _asDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  String? _normalizeSchemeCode(dynamic rawCode) {
    final code = rawCode?.toString().trim();
    if (code == null || code.isEmpty) return null;
    return code;
  }

  List<String> _schemeCodeCandidates(String code) {
    final candidates = <String>[code];
    final digitsOnly = code.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.isNotEmpty && digitsOnly != code) {
      candidates.add(digitsOnly);
    }
    return candidates;
  }

  // ── T-114: Static MF NAV fetch with 24-hour cache ─────────────────────────

  /// Fetch current NAV for a scheme code. Returns null on error/offline.
  /// Cache key: `nav_cache_{schemeCode}`, TTL 24 hours.
  static Future<double?> fetchMfNav(String schemeCode) async {
    const ttl = Duration(hours: 24);
    final cacheKey = 'nav_cache_$schemeCode';
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(cacheKey);
      if (cached != null) {
        final m = jsonDecode(cached) as Map<String, dynamic>;
        final ts = DateTime.parse(m['ts'] as String);
        if (DateTime.now().difference(ts) < ttl) {
          return (m['nav'] as num).toDouble();
        }
      }
      final uri = Uri.parse('https://api.mfapi.in/mf/$schemeCode');
      final resp = await http.get(uri).timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        final data = (body['data'] as List?)?.firstOrNull as Map?;
        final navStr = data?['nav'] as String?;
        final nav = navStr != null ? double.tryParse(navStr) : null;
        if (nav != null) {
          await prefs.setString(cacheKey,
              jsonEncode({'nav': nav, 'ts': DateTime.now().toIso8601String()}));
          return nav;
        }
      }
    } catch (e) {
      debugPrint('[InvestmentValueService] fetchMfNav error: $e');
    }
    return null;
  }

  // ── T-115: Static stock price fetch with 15-minute cache ──────────────────

  /// Fetch current stock price for NSE symbol. Returns null if unavailable.
  /// Cache key: `stock_price_{symbol}`, TTL 15 minutes.
  static final _stockSvc = StockApiService();
  static Future<double?> fetchStockPrice(String symbol) async {
    const ttl = Duration(minutes: 15);
    final cacheKey = 'stock_price_${symbol.toUpperCase()}';
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(cacheKey);
      if (cached != null) {
        final m = jsonDecode(cached) as Map<String, dynamic>;
        final ts = DateTime.parse(m['ts'] as String);
        if (DateTime.now().difference(ts) < ttl) {
          return (m['price'] as num).toDouble();
        }
      }
      final price = await _stockSvc.getStockPrice(symbol);
      if (price != null) {
        await prefs.setString(cacheKey, jsonEncode(
            {'price': price, 'ts': DateTime.now().toIso8601String()}));
        return price;
      }
    } catch (e) {
      debugPrint('[InvestmentValueService] fetchStockPrice error: $e');
    }
    return null;
  }

  // ── T-116: Static crypto price fetch with 15-minute cache ─────────────────

  /// Fetch INR price for a CoinGecko coin ID (e.g. "bitcoin").
  /// Cache key: `crypto_price_{coinId}`, TTL 15 minutes.
  static Future<double?> fetchCryptoPrice(String coinId) async {
    const ttl = Duration(minutes: 15);
    final cacheKey = 'crypto_price_$coinId';
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(cacheKey);
      if (cached != null) {
        final m = jsonDecode(cached) as Map<String, dynamic>;
        final ts = DateTime.parse(m['ts'] as String);
        if (DateTime.now().difference(ts) < ttl) {
          return (m['price'] as num).toDouble();
        }
      }
      final uri = Uri.parse(
          'https://api.coingecko.com/api/v3/simple/price'
          '?ids=$coinId&vs_currencies=inr');
      final resp = await http.get(uri).timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        final price = (body[coinId]?['inr'] as num?)?.toDouble();
        if (price != null) {
          await prefs.setString(cacheKey, jsonEncode(
              {'price': price, 'ts': DateTime.now().toIso8601String()}));
          return price;
        }
      }
    } catch (e) {
      debugPrint('[InvestmentValueService] fetchCryptoPrice error: $e');
    }
    return null;
  }

  double _calculateFallbackCurrentValue(Investment investment) {
    final metadata = investment.metadata;
    if (metadata != null) {
      final isFdOrRd = investment.type == InvestmentType.fixedDeposit ||
          investment.type == InvestmentType.recurringDeposit;

      if (investment.type == InvestmentType.fixedDeposit) {
        final maturityDateStr = metadata['maturityDate'] as String?;
        if (maturityDateStr != null) {
          try {
            final maturityDate = DateTime.parse(maturityDateStr);
            final today = DateTime.now();
            final daysUntilMaturity = maturityDate.difference(today).inDays;
            if (daysUntilMaturity <= 10) {
              if (metadata.containsKey('maturityValue')) {
                return (metadata['maturityValue'] as num).toDouble();
              }
              if (metadata.containsKey('estimatedAccruedValue')) {
                return (metadata['estimatedAccruedValue'] as num).toDouble();
              }
            }
          } catch (_) {
            // ignore and continue
          }
        }
      }

      if (investment.type == InvestmentType.fixedDeposit ||
          investment.type == InvestmentType.recurringDeposit) {
        final interestRate = (metadata['interestRate'] as num?)?.toDouble();
        final investmentDateStr = metadata['investmentDate'] as String?;
        final compoundingFreqStr = metadata['compoundingFrequency'] as String?;
        final isCumulative = (metadata['isCumulative'] as bool?) ?? true;

        if (interestRate != null && investmentDateStr != null && isCumulative) {
          try {
            final investmentDate = DateTime.parse(investmentDateStr);
            final today = DateTime.now();
            final daysElapsed = today.difference(investmentDate).inDays;

            if (daysElapsed > 0) {
              final principal = investment.amount;
              double currentValue = principal;

              int compoundsPerYear = 4;
              if (compoundingFreqStr != null) {
                final lower = compoundingFreqStr.toLowerCase();
                if (lower.contains('annually')) {
                  compoundsPerYear = 1;
                } else if (lower.contains('semi')) {
                  compoundsPerYear = 2;
                } else if (lower.contains('quarterly')) {
                  compoundsPerYear = 4;
                } else if (lower.contains('monthly')) {
                  compoundsPerYear = 12;
                } else if (lower.contains('daily')) {
                  compoundsPerYear = 365;
                }
              }

              if (compoundsPerYear <= 0) return principal;
              final daysPerCompound = 365 / compoundsPerYear;
              final compoundsElapsed = daysElapsed / daysPerCompound;
              final rate = interestRate / 100.0;
              final ratePerCompound = rate / compoundsPerYear;
              currentValue = principal *
                  pow(1 + ratePerCompound, compoundsElapsed).toDouble();

              return currentValue;
            }
          } catch (_) {
            // fallback below
          }
        }

        if (metadata.containsKey('estimatedAccruedValue')) {
          return (metadata['estimatedAccruedValue'] as num).toDouble();
        }
      }

      if (!isFdOrRd &&
          metadata.containsKey('currentValue') &&
          metadata['currentValue'] != 0) {
        return (metadata['currentValue'] as num).toDouble();
      }

      if (metadata.containsKey('estimatedAccruedValue')) {
        return (metadata['estimatedAccruedValue'] as num).toDouble();
      }
    }
    return investment.amount;
  }
}
