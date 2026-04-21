import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';

/// The three intelligence tiers — determined once at startup, never shown to user.
///
/// Tier 1 (flagship): Gemini Nano via Android AICore. Full natural language
///   reasoning. Pixel 8+, Samsung S24+, OnePlus 12+.
/// Tier 2 (midRange): TFLite models + statistical engine. 4GB+ RAM, Android 10+.
/// Tier 3 (entry): Pure statistical engine + rule system. All other devices.
///
/// Every feature is available on every tier — Tier 1 just reasons more deeply.
enum IntelligenceTier { flagship, midRange, entry }

class DeviceIntelligenceTier {
  DeviceIntelligenceTier._();

  static IntelligenceTier? _cached;

  /// Returns the tier for this device. Cached after first call.
  static Future<IntelligenceTier> detect() async {
    if (_cached != null) return _cached!;
    _cached = await _detectTier();
    return _cached!;
  }

  /// Synchronous access — returns [entry] until [detect()] has been called.
  static IntelligenceTier get current => _cached ?? IntelligenceTier.entry;

  static Future<IntelligenceTier> _detectTier() async {
    if (kIsWeb || !Platform.isAndroid) return IntelligenceTier.entry;

    try {
      final info = DeviceInfoPlugin();
      final android = await info.androidInfo;

      final sdkInt = android.version.sdkInt;
      final totalRam = _estimateRamGb(android.supportedAbis);

      // Flagship check: Android 14+ (API 34+) on known flagship SoC families.
      // Gemini Nano requires Android 14 and AICore, which ships on:
      //   - Google Pixel 8 series and later (Tensor G3+)
      //   - Samsung Galaxy S24 series and later (Snapdragon 8 Gen 3 / Exynos 2400)
      //   - OnePlus 12 and later (Snapdragon 8 Gen 3)
      if (sdkInt >= 34 && _isFlagshipDevice(android)) {
        return IntelligenceTier.flagship;
      }

      // Mid-range: Android 10+ (API 29+) with 4GB+ RAM equivalent
      if (sdkInt >= 29 && totalRam >= 4) {
        return IntelligenceTier.midRange;
      }

      return IntelligenceTier.entry;
    } catch (_) {
      return IntelligenceTier.entry;
    }
  }

  /// Detects flagship-class devices by manufacturer + model prefix heuristics.
  /// This does NOT gate features — it only enables the Gemini Nano path.
  static bool _isFlagshipDevice(AndroidDeviceInfo android) {
    final manufacturer = android.manufacturer.toLowerCase();
    final model = android.model.toLowerCase();
    final hardware = android.hardware.toLowerCase();

    // Google Pixel 8 and later
    if (manufacturer == 'google') {
      final pixelMatch = RegExp(r'pixel\s*([89]|[1-9]\d)');
      if (pixelMatch.hasMatch(model)) return true;
    }

    // Samsung Galaxy S24+ and later
    if (manufacturer == 'samsung') {
      final samsungMatch = RegExp(r'sm-s(9[2-9][0-9]|[1-9]\d{3})');
      if (samsungMatch.hasMatch(model)) return true;
      // Galaxy S24 Ultra, S25 etc
      if (model.contains('s24') || model.contains('s25') || model.contains('s26')) {
        return true;
      }
    }

    // OnePlus 12 and later
    if (manufacturer == 'oneplus') {
      final opMatch = RegExp(r'cph\d{4}|ph0[89]|ph[1-9]\d');
      if (opMatch.hasMatch(model)) return true;
    }

    // Snapdragon 8 Gen 3 / Gen 4 hardware IDs
    if (hardware.contains('kalama') ||
        hardware.contains('pineapple') ||
        hardware.contains('sun')) {
      return true;
    }

    return false;
  }

  /// Rough RAM estimate from the number of supported ABIs — crude but no
  /// permission needed. Real RAM detection requires READ_PHONE_STATE on older
  /// APIs, so we use a proxy.
  static int _estimateRamGb(List<String> abis) {
    // arm64-v8a + armeabi-v7a + x86_64 → flagship/high-end → assume 6GB+
    if (abis.length >= 3) return 6;
    // arm64-v8a + armeabi-v7a → mid-range → assume 4GB
    if (abis.length == 2) return 4;
    // armeabi-v7a only → older/entry → assume 2GB
    return 2;
  }

  // ── Convenience helpers ────────────────────────────────────────────────────

  static bool get isFlagship => current == IntelligenceTier.flagship;
  static bool get isMidRange => current == IntelligenceTier.midRange;
  static bool get isEntry => current == IntelligenceTier.entry;

  /// True if TFLite models should be loaded (Tier 1 + Tier 2).
  static bool get shouldLoadTflite =>
      current == IntelligenceTier.flagship ||
      current == IntelligenceTier.midRange;

  static String get tierLabel {
    switch (current) {
      case IntelligenceTier.flagship:
        return 'flagship';
      case IntelligenceTier.midRange:
        return 'midRange';
      case IntelligenceTier.entry:
        return 'entry';
    }
  }
}
