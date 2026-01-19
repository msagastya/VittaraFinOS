import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vittara_fin_os/utils/logger.dart';

class SettingsController with ChangeNotifier {
  final AppLogger logger = AppLogger();
  final LocalAuthentication auth = LocalAuthentication();
  late SharedPreferences _prefs;

  ThemeMode _themeMode = ThemeMode.system;
  bool _isBiometricEnabled = true;
  bool _lockOnMinimize = false;
  int _lockTimeoutSeconds = 10;
  DateTime? _lastPausedTime;
  bool _isLocked = false;

  ThemeMode get themeMode => _themeMode;
  bool get isBiometricEnabled => _isBiometricEnabled;
  bool get lockOnMinimize => _lockOnMinimize;
  int get lockTimeoutSeconds => _lockTimeoutSeconds;
  bool get isLocked => _isLocked;

  Future<void> loadSettings() async {
    _prefs = await SharedPreferences.getInstance();
    
    final themeIndex = _prefs.getInt('themeMode') ?? 0;
    if (themeIndex == 1) _themeMode = ThemeMode.light;
    else if (themeIndex == 2) _themeMode = ThemeMode.dark;
    else _themeMode = ThemeMode.system;

    _isBiometricEnabled = _prefs.getBool('isBiometricEnabled') ?? true;
    _lockOnMinimize = _prefs.getBool('lockOnMinimize') ?? false;
    _lockTimeoutSeconds = _prefs.getInt('lockTimeoutSeconds') ?? 10;

    // IMMEDIATE LOCK ON STARTUP if Biometric is enabled
    if (_isBiometricEnabled) {
      logger.info('Startup: Biometric enabled, locking app.', context: 'SettingsController');
      _isLocked = true;
      // We don't trigger authenticateAndUnlock() here immediately to avoid popup loops during splash
      // The UI will show the LockScreen, which has an "Unlock" button.
    }

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
    if (value) {
      bool authenticated = await _authenticate();
      if (authenticated) {
        _isBiometricEnabled = true;
        await _prefs.setBool('isBiometricEnabled', true);
      }
    } else {
      _isBiometricEnabled = false;
      await _prefs.setBool('isBiometricEnabled', false);
    }
    notifyListeners();
  }

  Future<void> toggleLockOnMinimize(bool value) async {
    _lockOnMinimize = value;
    await _prefs.setBool('lockOnMinimize', value);
    notifyListeners();
  }

  Future<void> setLockTimeout(int seconds) async {
    _lockTimeoutSeconds = seconds;
    await _prefs.setInt('lockTimeoutSeconds', seconds);
    notifyListeners();
  }

  void appPaused() {
    if (_lockOnMinimize) {
      _lastPausedTime = DateTime.now();
      // Persist pause time in case app is killed? 
      // Actually, if app is killed, we want Lock on Launch (handled in loadSettings).
      // So in-memory variable is fine for minimize/resume cycle.
      logger.info('App Paused. Timer started.', context: 'SettingsController');
    }
  }

  void appResumed() {
    if (!_lockOnMinimize || _lastPausedTime == null) return;

    final durationPaused = DateTime.now().difference(_lastPausedTime!);
    logger.info('App Resumed after ${durationPaused.inSeconds}s', context: 'SettingsController');

    if (durationPaused.inSeconds >= _lockTimeoutSeconds) {
      _isLocked = true;
      notifyListeners();
      if (_isBiometricEnabled) {
        authenticateAndUnlock();
      }
    }
    _lastPausedTime = null;
  }

  Future<bool> _authenticate() async {
    try {
      final bool canAuthenticateWithBiometrics = await auth.canCheckBiometrics;
      if (!canAuthenticateWithBiometrics) return false;

      return await auth.authenticate(
        localizedReason: 'Please authenticate to change settings',
      );
    } catch (e) {
      logger.error('Auth Error', error: e, context: 'SettingsController');
      return false;
    }
  }

  Future<void> authenticateAndUnlock() async {
    try {
      bool authenticated = await auth.authenticate(
        localizedReason: 'Unlock VittaraFinOS',
      );

      if (authenticated) {
        _isLocked = false;
        notifyListeners();
      }
    } catch (e) {
      logger.error('Unlock Error', error: e, context: 'SettingsController');
    }
  }
}