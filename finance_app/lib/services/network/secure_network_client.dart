import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// The ONLY class in VittaraFinOS that may make outbound HTTP calls.
///
/// All investment price services (stock, gold, NAV, AMFI) must go through
/// this client. No other file should import 'package:http/http.dart' directly.
///
/// Two layers of enforcement:
///   1. Android OS — network_security_config.xml blocks all domains not listed.
///   2. This guard  — throws [NetworkSecurityException] before even attempting
///      a connection if the host is not in [_kAllowedHosts].
///
/// NOTE: _kAllowedHosts must stay in sync with network_security_config.xml.
class SecureNetworkClient {
  SecureNetworkClient._();
  static final SecureNetworkClient instance = SecureNetworkClient._();

  static final _client = http.Client();

  // Canonical list of investment price domains.
  // MUST match network_security_config.xml exactly.
  static const _kAllowedHosts = {
    'query1.finance.yahoo.com',
    'query2.finance.yahoo.com',
    'finance.yahoo.com',
    'www.amfiindia.com',
    'api.mfapi.in',
    'open.er-api.com',
    'api.exchangerate-api.com',
    'www.nseindia.com',
  };

  // Standard browser-like headers to avoid 403s from Yahoo Finance
  static const _kDefaultHeaders = {
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/120.0.6099.230 Mobile Safari/537.36',
    'Accept': 'application/json, text/plain, */*',
    'Accept-Language': 'en-US,en;q=0.9',
  };

  /// Fetch JSON from [uri]. Returns parsed [Map<String, dynamic>].
  /// Throws [NetworkSecurityException] if host is not whitelisted.
  /// Throws [NetworkResponseException] on non-200 status.
  Future<Map<String, dynamic>> getJson(
    Uri uri, {
    Map<String, String>? extraHeaders,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    _guard(uri);
    try {
      final headers = {..._kDefaultHeaders, ...?extraHeaders};
      final response =
          await _client.get(uri, headers: headers).timeout(timeout);
      if (response.statusCode != 200) {
        throw NetworkResponseException(response.statusCode, uri.host);
      }
      return jsonDecode(response.body) as Map<String, dynamic>;
    } on NetworkSecurityException {
      rethrow;
    } on NetworkResponseException {
      rethrow;
    } on SocketException catch (e) {
      debugPrint('[SecureNetworkClient] Socket error ${uri.host}: $e');
      throw NetworkResponseException(0, uri.host, detail: 'No connection');
    } catch (e) {
      debugPrint('[SecureNetworkClient] Error ${uri.host}: $e');
      rethrow;
    }
  }

  /// Fetch plain text from [uri]. Returns response body as [String].
  Future<String> getText(
    Uri uri, {
    Map<String, String>? extraHeaders,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    _guard(uri);
    try {
      final headers = {..._kDefaultHeaders, ...?extraHeaders};
      final response =
          await _client.get(uri, headers: headers).timeout(timeout);
      if (response.statusCode != 200) {
        throw NetworkResponseException(response.statusCode, uri.host);
      }
      return response.body;
    } on NetworkSecurityException {
      rethrow;
    } on NetworkResponseException {
      rethrow;
    } on SocketException catch (e) {
      debugPrint('[SecureNetworkClient] Socket error ${uri.host}: $e');
      throw NetworkResponseException(0, uri.host, detail: 'No connection');
    } catch (e) {
      debugPrint('[SecureNetworkClient] Error ${uri.host}: $e');
      rethrow;
    }
  }

  void _guard(Uri uri) {
    if (!_kAllowedHosts.contains(uri.host)) {
      const msg = 'SECURITY VIOLATION: Outbound network call blocked.\n'
          'Only investment price domains are permitted.\n'
          'Add the domain to network_security_config.xml AND '
          'SecureNetworkClient._kAllowedHosts to allow it.';
      debugPrint('[SecureNetworkClient] $msg → host: ${uri.host}');
      throw NetworkSecurityException(uri.host);
    }
  }
}

// ── Exceptions ────────────────────────────────────────────────────────────────

class NetworkSecurityException implements Exception {
  final String host;
  const NetworkSecurityException(this.host);
  @override
  String toString() =>
      'NetworkSecurityException: call to "$host" is not permitted';
}

class NetworkResponseException implements Exception {
  final int statusCode;
  final String host;
  final String? detail;
  const NetworkResponseException(this.statusCode, this.host, {this.detail});
  @override
  String toString() =>
      'NetworkResponseException: HTTP $statusCode from $host'
      '${detail != null ? " ($detail)" : ""}';
}
