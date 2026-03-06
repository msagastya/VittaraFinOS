import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vittara_fin_os/utils/logger.dart';

class SettingsController with ChangeNotifier {
  final AppLogger logger = AppLogger();
  final LocalAuthentication auth = LocalAuthentication();
  static const platform = MethodChannel('com.example.finance_app/secure');
  late SharedPreferences _prefs;

  ThemeMode _themeMode = ThemeMode.system;
  bool _isBiometricEnabled = true;
  bool _lockOnMinimize = false;
  int _lockTimeoutSeconds = 10;
  bool _isInvestmentTrackingEnabled = false; // Default OFF
  DateTime? _lastPausedTime;
  bool _isLocked = false;
  bool _appLoaded = false;
  bool _isArchivedTransactionsEnabled = false;
  String? _pinHash; // SHA-256 of the PIN
  bool _showPinFallback = false; // set to true after biometric fails

  ThemeMode get themeMode => _themeMode;
  bool get isBiometricEnabled => _isBiometricEnabled;
  bool get lockOnMinimize => _lockOnMinimize;
  int get lockTimeoutSeconds => _lockTimeoutSeconds;
  bool get isInvestmentTrackingEnabled => _isInvestmentTrackingEnabled;
  bool get isLocked => _isLocked;
  bool get appLoaded => _appLoaded;
  bool get isArchivedTransactionsEnabled => _isArchivedTransactionsEnabled;
  bool get isPinEnabled => _pinHash != null && _pinHash!.isNotEmpty;
  bool get showPinFallback => _showPinFallback;

  void setAppLoaded() {
    _appLoaded = true;
    notifyListeners();
  }

  Future<void> loadSettings() async {
    _prefs = await SharedPreferences.getInstance();

    final themeIndex = _prefs.getInt('themeMode') ?? 0;
    if (themeIndex == 1) {
      _themeMode = ThemeMode.light;
    } else if (themeIndex == 2) {
      _themeMode = ThemeMode.dark;
    } else {
      _themeMode = ThemeMode.system;
    }

    _isBiometricEnabled = _prefs.getBool('isBiometricEnabled') ?? true;
    _lockOnMinimize = _prefs.getBool('lockOnMinimize') ?? false;
    _lockTimeoutSeconds = _prefs.getInt('lockTimeoutSeconds') ?? 10;
    _isInvestmentTrackingEnabled =
        _prefs.getBool('isInvestmentTrackingEnabled') ?? false;
    _pinHash = _prefs.getString('pinHash');
    _isArchivedTransactionsEnabled =
        _prefs.getBool('showArchivedTransactions') ?? false;

    // Skip biometric setup on web
    if (!kIsWeb) {
      // Apply Secure Flag based on settings
      _updateSecureFlag();

      if (_isBiometricEnabled) {
        logger.info('Startup: Biometric enabled, locking app.',
            context: 'SettingsController');
        _isLocked = true;
      }
    }

    notifyListeners();
  }

  Future<void> toggleInvestmentTracking(bool value) async {
    _isInvestmentTrackingEnabled = value;
    await _prefs.setBool('isInvestmentTrackingEnabled', value);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    int index = 0;
    if (mode == ThemeMode.light) index = 1;
    if (mode == ThemeMode.dark) index = 2;
    await _prefs.setInt('themeMode', index);
    notifyListeners();
  }

  Future<void> toggleBiometric(bool value) async {
    if (kIsWeb) return; // Skip on web

    if (value) {
      bool authenticated = await _authenticate(
        reason: 'Please authenticate to enable biometric security',
      );
      if (authenticated) {
        _isBiometricEnabled = true;
        await _prefs.setBool('isBiometricEnabled', true);
      }
    } else {
      _isBiometricEnabled = false;
      _isLocked = false;
      _lockOnMinimize = false;
      await _prefs.setBool('isBiometricEnabled', false);
      await _prefs.setBool('lockOnMinimize', false);
      _updateSecureFlag();
    }
    notifyListeners();
  }

  Future<void> toggleArchivedTransactions(bool value) async {
    _isArchivedTransactionsEnabled = value;
    await _prefs.setBool('showArchivedTransactions', value);
    notifyListeners();
  }

  Future<bool> authenticateArchivedAccess(
      {String reason = 'Authenticate to view archived transactions'}) async {
    if (!_isArchivedTransactionsEnabled || !_isBiometricEnabled || kIsWeb) {
      return true;
    }

    return await _authenticate(reason: reason);
  }

  Future<void> toggleLockOnMinimize(bool value) async {
    if (kIsWeb) return; // Skip on web

    _lockOnMinimize = value;
    await _prefs.setBool('lockOnMinimize', value);
    _updateSecureFlag();
    notifyListeners();
  }

  Future<void> setLockTimeout(int seconds) async {
    _lockTimeoutSeconds = seconds;
    await _prefs.setInt('lockTimeoutSeconds', seconds);
    notifyListeners();
  }

  Future<void> _updateSecureFlag() async {
    if (kIsWeb) return; // Skip on web

    try {
      if (_lockOnMinimize) {
        await platform.invokeMethod('enableSecure');
      } else {
        await platform.invokeMethod('disableSecure');
      }
    } catch (e) {
      logger.error('Failed to update secure flag',
          error: e, context: 'SettingsController');
    }
  }

  void appPaused() {
    if (_lockOnMinimize) {
      _lastPausedTime = DateTime.now();
      logger.info('App Paused. Timer started.', context: 'SettingsController');
    }
  }

  void appResumed() {
    if (kIsWeb || !_lockOnMinimize || _lastPausedTime == null) return;

    final durationPaused = DateTime.now().difference(_lastPausedTime!);
    logger.info('App Resumed after ${durationPaused.inSeconds}s',
        context: 'SettingsController');

    if (durationPaused.inSeconds >= _lockTimeoutSeconds) {
      _isLocked = true;
      notifyListeners();
      if (_isBiometricEnabled) {
        authenticateAndUnlock();
      }
    }
    _lastPausedTime = null;
  }

  Future<bool> _authenticate(
      {String reason = 'Please authenticate to change settings'}) async {
    if (kIsWeb) return false; // Biometric not available on web

    try {
      final bool canAuthenticateWithBiometrics = await auth.canCheckBiometrics;
      if (!canAuthenticateWithBiometrics) return false;

      return await auth.authenticate(
        localizedReason: reason,
      );
    } catch (e) {
      logger.error('Auth Error', error: e, context: 'SettingsController');
      return false;
    }
  }

  static String _hashPin(String pin) {
    final bytes = utf8.encode('vittara_pin_salt_$pin');
    return sha256.convert(bytes).toString();
  }

  Future<void> setPin(String pin) async {
    _pinHash = _hashPin(pin);
    await _prefs.setString('pinHash', _pinHash!);
    notifyListeners();
  }

  Future<void> clearPin() async {
    _pinHash = null;
    await _prefs.remove('pinHash');
    notifyListeners();
  }

  bool verifyPin(String pin) {
    if (_pinHash == null) return false;
    return _hashPin(pin) == _pinHash;
  }

  void showPinEntryFallback() {
    _showPinFallback = true;
    notifyListeners();
  }

  void hidePinFallback() {
    _showPinFallback = false;
    notifyListeners();
  }

  void authenticateAndUnlockWithPin() {
    _showPinFallback = false;
    _isLocked = false;
    notifyListeners();
  }

  Future<void> authenticateAndUnlock() async {
    if (kIsWeb) return; // Skip on web

    try {
      final canBiometric = await auth.canCheckBiometrics;
      if (!canBiometric) {
        // Biometric not available — show PIN if set
        if (isPinEnabled) showPinEntryFallback();
        return;
      }
      bool authenticated = await auth.authenticate(
        localizedReason: 'Unlock VittaraFinOS',
      );

      if (authenticated) {
        _showPinFallback = false;
        _isLocked = false;
        notifyListeners();
      } else if (isPinEnabled) {
        // Biometric failed — offer PIN fallback
        showPinEntryFallback();
      }
    } catch (e) {
      logger.error('Unlock Error', error: e, context: 'SettingsController');
      if (isPinEnabled) showPinEntryFallback();
    }
  }
}
