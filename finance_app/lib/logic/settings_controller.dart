import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vittara_fin_os/utils/logger.dart';

class SettingsController with ChangeNotifier {
  final AppLogger logger = AppLogger();
  final LocalAuthentication auth = LocalAuthentication();
  static const platform = MethodChannel('com.example.finance_app/secure');
  late SharedPreferences _prefs;

  // Secure storage for PIN hash and recovery code (Android Keystore / iOS Keychain)
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );
  static const _keyPinHash = 'vfos_pin_hash';
  static const _keyPinSalt = 'vfos_pin_salt_v2';

  ThemeMode _themeMode = ThemeMode.system;
  bool _isBiometricEnabled = true;
  bool _lockOnMinimize = false;
  int _lockTimeoutSeconds = 10;
  bool _isInvestmentTrackingEnabled = false; // Default OFF
  DateTime? _lastPausedTime;
  bool _isLocked = false;
  bool _appLoaded = false;
  bool _isArchivedTransactionsEnabled = false;
  bool _isSmsEnabled = false;
  String? _pinHash; // SHA-256 of the PIN
  String? _pinSalt; // Per-user random salt (base64, v2+). Null for legacy users.
  bool _showPinFallback = false; // set to true after biometric fails

  ThemeMode get themeMode => _themeMode;
  bool get isBiometricEnabled => _isBiometricEnabled;
  bool get lockOnMinimize => _lockOnMinimize;
  int get lockTimeoutSeconds => _lockTimeoutSeconds;
  bool get isInvestmentTrackingEnabled => _isInvestmentTrackingEnabled;
  bool get isLocked => _isLocked;
  bool get appLoaded => _appLoaded;
  bool get isArchivedTransactionsEnabled => _isArchivedTransactionsEnabled;
  bool get isSmsEnabled => _isSmsEnabled;
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
    _isArchivedTransactionsEnabled =
        _prefs.getBool('showArchivedTransactions') ?? false;
    _isSmsEnabled = _prefs.getBool('isSmsEnabled') ?? false;

    // Read PIN hash + salt from secure storage
    _pinHash = await _secureStorage.read(key: _keyPinHash);
    _pinSalt = await _secureStorage.read(key: _keyPinSalt);
    // One-time migration: move old pin hash from SharedPreferences → secure storage
    if (_pinHash == null) {
      final legacyHash = _prefs.getString('pinHash');
      if (legacyHash != null && legacyHash.isNotEmpty) {
        _pinHash = legacyHash;
        await _secureStorage.write(key: _keyPinHash, value: legacyHash);
        await _prefs.remove('pinHash');
        logger.info('Migrated PIN hash from SharedPreferences → secure storage',
            context: 'SettingsController');
      }
    }

    // Skip biometric setup on web
    if (!kIsWeb) {
      // Apply Secure Flag based on settings
      _updateSecureFlag();

      if (_isBiometricEnabled || isPinEnabled) {
        logger.info(
            'Startup: Security enabled (biometric=$_isBiometricEnabled, pin=$isPinEnabled), locking app.',
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
      final bool authenticated = await _authenticate(
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

  Future<void> toggleSmsScanning(bool value) async {
    _isSmsEnabled = value;
    await _prefs.setBool('isSmsEnabled', value);
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

  /// Hash PIN with optional per-user salt (v2). Falls back to legacy
  /// hardcoded-salt hash if [salt] is null (for migrating existing users).
  static String _hashPin(String pin, {String? salt}) {
    final input = salt != null ? '$salt:$pin' : 'vittara_pin_salt_$pin';
    final bytes = utf8.encode(input);
    return sha256.convert(bytes).toString();
  }

  /// Generate a cryptographically random base64 salt (16 bytes = 128 bits).
  static String _generateSalt() {
    final rng = Random.secure();
    final bytes = Uint8List.fromList(List.generate(16, (_) => rng.nextInt(256)));
    return base64Encode(bytes);
  }

  Future<void> setPin(String pin) async {
    _pinSalt = _generateSalt();
    _pinHash = _hashPin(pin, salt: _pinSalt);
    await _secureStorage.write(key: _keyPinHash, value: _pinHash!);
    await _secureStorage.write(key: _keyPinSalt, value: _pinSalt!);
    await _prefs.remove('pinHash'); // remove any legacy plaintext copy
    notifyListeners();
  }

  Future<void> clearPin() async {
    _pinHash = null;
    _pinSalt = null;
    await _secureStorage.delete(key: _keyPinHash);
    await _secureStorage.delete(key: _keyPinSalt);
    await _prefs.remove('pinHash');
    notifyListeners();
  }

  /// Called by PIN recovery flow after successful code verification.
  /// Resets PIN to new value without requiring the old PIN.
  Future<void> resetPinAfterRecovery(String newPin) async {
    _pinSalt = _generateSalt();
    _pinHash = _hashPin(newPin, salt: _pinSalt);
    await _secureStorage.write(key: _keyPinHash, value: _pinHash!);
    await _secureStorage.write(key: _keyPinSalt, value: _pinSalt!);
    await _prefs.remove('pinHash');
    notifyListeners();
  }

  /// Resets only app settings to defaults — financial data is preserved.
  Future<void> resetToDefaults() async {
    await _prefs.remove('themeMode');
    await _prefs.remove('isBiometricEnabled');
    await _prefs.remove('lockOnMinimize');
    await _prefs.remove('lockTimeoutSeconds');
    await _prefs.remove('isInvestmentTrackingEnabled');
    await _prefs.remove('showArchivedTransactions');
    await _prefs.remove('isSmsEnabled');
    _themeMode = ThemeMode.system;
    _isBiometricEnabled = true;
    _lockOnMinimize = false;
    _lockTimeoutSeconds = 10;
    _isInvestmentTrackingEnabled = false;
    _isArchivedTransactionsEnabled = false;
    _isSmsEnabled = false;
    notifyListeners();
  }

  /// Nuclear reset — wipes ALL app data from secure storage.
  /// Called only from the last-resort reset flow (triple-confirmed by user).
  Future<void> nuclearReset() async {
    await _secureStorage.deleteAll();
    await _prefs.clear();
    _pinHash = null;
    _pinSalt = null;
    _isBiometricEnabled = true;
    _lockOnMinimize = false;
    _lockTimeoutSeconds = 10;
    _isInvestmentTrackingEnabled = false;
    _isArchivedTransactionsEnabled = false;
    _isSmsEnabled = false;
    _isLocked = false;
    notifyListeners();
  }

  bool verifyPin(String pin) {
    if (_pinHash == null) return false;
    // Use per-user salt if available (v2); fall back to legacy hash for existing users.
    final match = _hashPin(pin, salt: _pinSalt) == _pinHash;
    if (match && _pinSalt == null) {
      // Migrate legacy user to per-user salt now that we have the plain PIN.
      _migrateLegacySalt(pin);
    }
    return match;
  }

  /// Upgrades a legacy (hardcoded-salt) PIN hash to a per-user random salt.
  /// Called transparently on first successful verification for legacy users.
  void _migrateLegacySalt(String pin) {
    _pinSalt = _generateSalt();
    _pinHash = _hashPin(pin, salt: _pinSalt);
    // Fire-and-forget — if this save fails the user just migrates again next login.
    _secureStorage.write(key: _keyPinHash, value: _pinHash!);
    _secureStorage.write(key: _keyPinSalt, value: _pinSalt!);
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

    // PIN-only mode: biometric disabled but PIN is set — go straight to numpad
    if (!_isBiometricEnabled && isPinEnabled) {
      showPinEntryFallback();
      return;
    }

    // No security configured (shouldn't be locked, but unlock anyway)
    if (!_isBiometricEnabled && !isPinEnabled) {
      _isLocked = false;
      notifyListeners();
      return;
    }

    try {
      final canBiometric = await auth.canCheckBiometrics;
      if (!canBiometric) {
        // Device doesn't support biometric — fall back to PIN if set
        if (isPinEnabled) showPinEntryFallback();
        return;
      }

      // biometricOnly: true prevents the system from showing its own device-PIN fallback.
      // The app handles PIN fallback through its own in-app numpad.
      final bool authenticated = await auth.authenticate(
        localizedReason: 'Unlock VittaraFinOS',
        biometricOnly:
            isPinEnabled, // suppress OS PIN sheet only when we have our own
      );

      if (authenticated) {
        _showPinFallback = false;
        _isLocked = false;
        notifyListeners();
      } else if (isPinEnabled) {
        // Biometric failed/cancelled — offer in-app PIN
        showPinEntryFallback();
      } else {
        // No PIN fallback — re-prompt biometric
        authenticateAndUnlock();
      }
    } catch (e) {
      logger.error('Unlock Error', error: e, context: 'SettingsController');
      if (isPinEnabled) showPinEntryFallback();
    }
  }
}
