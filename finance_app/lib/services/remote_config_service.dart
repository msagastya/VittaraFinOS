import 'dart:convert';
import 'package:flutter/services.dart';

/// AU3-06 — Local feature flag service.
/// Replace asset-based config with Firebase Remote Config when needed.
class RemoteConfigService {
  static final RemoteConfigService _instance = RemoteConfigService._();
  static RemoteConfigService get instance => _instance;
  RemoteConfigService._();

  Map<String, dynamic> _config = {};

  Future<void> initialize() async {
    try {
      final json =
          await rootBundle.loadString('assets/remote_config.json');
      _config = jsonDecode(json) as Map<String, dynamic>;
    } catch (_) {
      _config = _defaults;
    }
  }

  bool getBool(String key, {bool defaultValue = false}) =>
      _config[key] as bool? ?? defaultValue;

  String getString(String key, {String defaultValue = ''}) =>
      _config[key] as String? ?? defaultValue;

  static const Map<String, dynamic> _defaults = {
    'enable_receipt_ocr': false,
    'enable_family_mode': false,
    'enable_ai_insights': false,
    'enable_crypto_tracking': true,
    'enable_fo_tracking': true,
  };
}
