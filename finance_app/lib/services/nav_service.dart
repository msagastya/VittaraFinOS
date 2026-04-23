import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vittara_fin_os/services/network/secure_network_client.dart';
import 'package:vittara_fin_os/utils/app_config.dart';

/// Service for fetching NAV (Net Asset Value) data for Mutual Funds
class NAVService {
  static const String _cachePrefix = 'nav_cache_';
  static const Duration _cacheDuration = Duration(hours: 6);

  /// Fetch current NAV for a mutual fund scheme
  Future<NAVData?> getCurrentNAV(String schemeCode,
      {bool forceRefresh = false}) async {
    try {
      // Check cache first
      if (!forceRefresh) {
        final cached = await _getCachedNAV(schemeCode);
        if (cached != null) return cached;
      }

      final navData = await _fetchLatestOrFallbackNAV(schemeCode);
      if (navData == null || navData.nav <= 0) {
        return null;
      }

      await _cacheNAV(schemeCode, navData);
      return navData;
    } catch (e) {
      debugPrint('Error fetching NAV for $schemeCode: $e');
      return null;
    }
  }

  Future<NAVData?> _fetchLatestOrFallbackNAV(String schemeCode) async {
    // Primary endpoint
    try {
      final latestUrl = Uri.parse('${AppConfig.mfSchemeLatestUrl}/$schemeCode/latest');
      final latestPayload = await SecureNetworkClient.instance
          .getJson(latestUrl, timeout: const Duration(seconds: 10));
      final latestNav = _parseLatestNAVResponse(latestPayload);
      if (latestNav != null && latestNav.nav > 0) return latestNav;
    } catch (_) {}

    // Fallback endpoint: historical feed, take first record
    try {
      final fallbackUrl = Uri.parse('${AppConfig.mfSchemeLatestUrl}/$schemeCode');
      final fallbackPayload = await SecureNetworkClient.instance
          .getJson(fallbackUrl, timeout: const Duration(seconds: 10));
      final dataNode = fallbackPayload['data'];
      if (dataNode is List &&
          dataNode.isNotEmpty &&
          dataNode.first is Map<String, dynamic>) {
        final nav = NAVData.fromJson(dataNode.first as Map<String, dynamic>);
        return nav.nav > 0 ? nav : null;
      }
    } catch (_) {}

    return null;
  }

  NAVData? _parseLatestNAVResponse(dynamic payload) {
    if (payload is! Map<String, dynamic>) return null;

    final directNav = _safeParseNav(payload['nav']);
    final directDate = payload['date']?.toString();
    if (directNav != null && directDate != null) {
      return NAVData(date: NAVData._parseDate(directDate), nav: directNav);
    }

    final dataNode = payload['data'];
    if (dataNode is List &&
        dataNode.isNotEmpty &&
        dataNode.first is Map<String, dynamic>) {
      return NAVData.fromJson(dataNode.first as Map<String, dynamic>);
    }
    if (dataNode is Map<String, dynamic>) {
      return NAVData.fromJson(dataNode);
    }

    return null;
  }

  double? _safeParseNav(dynamic value) {
    if (value == null) return null;
    return double.tryParse(value.toString());
  }

  /// Fetch historical NAV data for a mutual fund scheme
  Future<List<NAVData>> getHistoricalNAV(
    String schemeCode, {
    DateTime? fromDate,
    DateTime? toDate,
    int? lastNDays,
  }) async {
    try {
      final url = Uri.parse('${AppConfig.mfSchemeLatestUrl}/$schemeCode');
      final data = await SecureNetworkClient.instance
          .getJson(url, timeout: const Duration(seconds: 15));
      final List<dynamic> navList = data['data'] ?? [];

      List<NAVData> historicalData =
          navList.map((item) => NAVData.fromJson(item)).toList();

      // Filter by date range if provided
      if (fromDate != null || toDate != null) {
        historicalData = historicalData.where((nav) {
          if (fromDate != null && nav.date.isBefore(fromDate)) return false;
          if (toDate != null && nav.date.isAfter(toDate)) return false;
          return true;
        }).toList();
      }

      // Limit to last N days if provided
      if (lastNDays != null && historicalData.length > lastNDays) {
        historicalData = historicalData.sublist(0, lastNDays);
      }

      return historicalData;
    } catch (e) {
      debugPrint('Error fetching historical NAV for $schemeCode: $e');
      return [];
    }
  }

  /// Get NAV for a specific date
  Future<NAVData?> getNAVForDate(String schemeCode, DateTime date) async {
    try {
      final historical = await getHistoricalNAV(schemeCode);

      // Find closest NAV to the requested date
      NAVData? closestNAV;
      int minDiff = 999999;

      for (final nav in historical) {
        final diff = nav.date.difference(date).inDays.abs();
        if (diff < minDiff) {
          minDiff = diff;
          closestNAV = nav;
        }
      }

      return closestNAV;
    } catch (e) {
      debugPrint('Error fetching NAV for date: $e');
      return null;
    }
  }

  /// Calculate returns over a period
  Future<double?> calculateReturns(
    String schemeCode, {
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final startNAV = await getNAVForDate(schemeCode, startDate);
      final endNAV = await getNAVForDate(schemeCode, endDate);

      if (startNAV == null || endNAV == null) return null;

      final returns = ((endNAV.nav - startNAV.nav) / startNAV.nav) * 100;
      return returns;
    } catch (e) {
      debugPrint('Error calculating returns: $e');
      return null;
    }
  }

  /// Calculate XIRR (Extended Internal Rate of Return) for SIP investments.
  /// Uses Newton-Raphson on actual cashflow dates for a proper annualized IRR.
  Future<double?> calculateXIRR(List<SIPTransaction> transactions) async {
    try {
      if (transactions.isEmpty) return null;

      // Build cashflows: outflows (-) on each purchase date,
      // single inflow (+) today for total current market value.
      final today = DateTime.now();
      final List<({DateTime date, double amount})> cashflows = [];
      double totalCurrentValue = 0;

      for (final tx in transactions) {
        if (tx.purchaseNAV <= 0) continue;
        final units = tx.amount / tx.purchaseNAV;
        totalCurrentValue += units * tx.currentNAV;
        cashflows.add((date: tx.date, amount: -tx.amount));
      }

      if (cashflows.isEmpty || totalCurrentValue <= 0) return null;
      cashflows.add((date: today, amount: totalCurrentValue));

      // Newton-Raphson: solve NPV(rate) = 0.
      final t0 = cashflows.first.date;
      double rate = 0.1; // initial guess 10%
      const maxIter = 100;
      const tol = 1e-7;

      for (int i = 0; i < maxIter; i++) {
        double npv = 0, dnpv = 0;
        for (final cf in cashflows) {
          final t = cf.date.difference(t0).inDays / 365.0;
          final denom = math.pow(1 + rate, t).toDouble();
          npv += cf.amount / denom;
          dnpv -= t * cf.amount / (denom * (1 + rate));
        }
        if (dnpv.abs() < 1e-12) break;
        final delta = npv / dnpv;
        rate -= delta;
        if (delta.abs() < tol) break;
      }

      if (!rate.isFinite || rate <= -1) return null;
      return rate * 100; // return as percentage
    } catch (e) {
      debugPrint('Error calculating XIRR: $e');
      return null;
    }
  }

  /// Cache NAV data
  Future<void> _cacheNAV(String schemeCode, NAVData navData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_cachePrefix$schemeCode';
      final cacheData = {
        'data': navData.toJson(),
        'timestamp': DateTime.now().toIso8601String(),
      };
      await prefs.setString(cacheKey, json.encode(cacheData));
    } catch (e) {
      debugPrint('Error caching NAV: $e');
    }
  }

  /// Get cached NAV data
  Future<NAVData?> _getCachedNAV(String schemeCode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_cachePrefix$schemeCode';
      final cacheJson = prefs.getString(cacheKey);

      if (cacheJson == null) return null;

      final cacheData = json.decode(cacheJson);
      final timestamp = DateTime.parse(cacheData['timestamp']);

      // Check if cache is still valid
      if (DateTime.now().difference(timestamp) > _cacheDuration) {
        return null;
      }

      return NAVData.fromJson(cacheData['data']);
    } catch (e) {
      debugPrint('Error reading NAV cache: $e');
      return null;
    }
  }

  /// Clear all NAV cache
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      for (final key in keys) {
        if (key.startsWith(_cachePrefix)) {
          await prefs.remove(key);
        }
      }
    } catch (e) {
      debugPrint('Error clearing NAV cache: $e');
    }
  }

  /// Bulk fetch NAVs for multiple schemes
  Future<Map<String, NAVData>> bulkFetchNAVs(
    List<String> schemeCodes, {
    bool forceRefresh = false,
  }) async {
    final Map<String, NAVData> results = {};

    await Future.wait(
      schemeCodes.map((code) async {
        final nav = await getCurrentNAV(code, forceRefresh: forceRefresh);
        if (nav != null) {
          results[code] = nav;
        }
      }),
    );

    return results;
  }
}

/// NAV data model
class NAVData {
  final DateTime date;
  final double nav;

  NAVData({
    required this.date,
    required this.nav,
  });

  factory NAVData.fromJson(Map<String, dynamic> json) {
    return NAVData(
      date: _parseDate(json['date'] ?? ''),
      nav: double.tryParse(json['nav']?.toString() ?? '0') ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'nav': nav,
    };
  }

  static DateTime _parseDate(String dateStr) {
    try {
      // Handle DD-MM-YYYY format from AMFI
      final parts = dateStr.split('-');
      if (parts.length == 3) {
        final day = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final year = int.parse(parts[2]);
        return DateTime(year, month, day);
      }
      return DateTime.parse(dateStr);
    } catch (e) {
      return DateTime.now();
    }
  }
}

/// SIP transaction model for XIRR calculation
class SIPTransaction {
  final DateTime date;
  final double amount;
  final double purchaseNAV;
  final double currentNAV;

  SIPTransaction({
    required this.date,
    required this.amount,
    required this.purchaseNAV,
    required this.currentNAV,
  });
}
