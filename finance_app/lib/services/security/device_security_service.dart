import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:safe_device/safe_device.dart';

/// Device-level security checks run once at startup.
///
/// On a rooted/jailbroken device the app continues to function —
/// we warn the user rather than hard-blocking, since legitimate
/// power users may run rooted devices. The warning is surfaced
/// through [isCompromised] and [warningMessage] for the UI layer.
///
/// Checks performed (all on-device, no network):
///   • Root (Android) / Jailbreak (iOS) via safe_device
///   • Developer options / USB debugging active (Android only)
///   • Running in an emulator
class DeviceSecurityService {
  DeviceSecurityService._();
  static final DeviceSecurityService instance = DeviceSecurityService._();

  bool _checked = false;
  bool _isRooted = false;
  bool _isDeveloperMode = false;
  bool _isEmulator = false;

  bool get isCompromised => _isRooted || _isEmulator;
  bool get isDeveloperMode => _isDeveloperMode;

  /// Human-readable warning, or null if device is clean.
  String? get warningMessage {
    if (!_checked) return null;
    final parts = <String>[];
    if (_isRooted) parts.add(Platform.isAndroid ? 'rooted' : 'jailbroken');
    if (_isEmulator) parts.add('running on an emulator');
    if (parts.isEmpty) return null;
    return 'Security warning: device is ${parts.join(' and ')}. '
        'Your financial data may be at risk.';
  }

  /// Run all checks. Safe to call multiple times — only runs once.
  Future<void> check() async {
    if (_checked) return;
    if (kIsWeb) {
      _checked = true;
      return;
    }
    try {
      _isRooted = await SafeDevice.isJailBroken;
      _isEmulator = await SafeDevice.isRealDevice == false;
      if (Platform.isAndroid) {
        _isDeveloperMode = await SafeDevice.isDevelopmentModeEnable;
      }
    } catch (e) {
      debugPrint('[DeviceSecurityService] check error: $e');
    }
    _checked = true;
    if (isCompromised) {
      debugPrint('[DeviceSecurityService] WARNING: $warningMessage');
    } else {
      debugPrint('[DeviceSecurityService] Device security OK'
          '${_isDeveloperMode ? " (developer mode on)" : ""}');
    }
  }

  // ── Screenshot protection ────────────────────────────────────────────────

  static const _channel = MethodChannel('com.vittara.finos/secure');

  /// Call once at app start — FLAG_SECURE is already set in MainActivity.onCreate,
  /// but this keeps the Dart side in sync for future dynamic enable/disable.
  Future<void> enableScreenshotProtection() async {
    try {
      await _channel.invokeMethod('enableSecure');
    } catch (e) {
      debugPrint('[DeviceSecurityService] enableSecure error: $e');
    }
  }

  /// Disable screenshot protection — not used currently, exposed for future
  /// use (e.g., allowing screenshots in a specific export flow if needed).
  Future<void> disableScreenshotProtection() async {
    try {
      await _channel.invokeMethod('disableSecure');
    } catch (e) {
      debugPrint('[DeviceSecurityService] disableSecure error: $e');
    }
  }
}
