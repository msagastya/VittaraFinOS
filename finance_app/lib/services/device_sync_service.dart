import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vittara_fin_os/logic/backup_restore_service.dart';

class DeviceSyncState {
  final bool isPaired;
  final String deviceName;
  final DateTime? pairedAt;
  final DateTime? lastExportAt;
  final DateTime? lastImportAt;

  const DeviceSyncState({
    required this.isPaired,
    required this.deviceName,
    this.pairedAt,
    this.lastExportAt,
    this.lastImportAt,
  });
}

class DeviceSyncService {
  DeviceSyncService._();

  static const _storage = FlutterSecureStorage();
  static const _passphraseKey = 'vittara_sync_pairing_passphrase_v1';
  static const _deviceNameKey = 'vittara_sync_device_name_v1';
  static const _pairedAtKey = 'vittara_sync_paired_at_v1';
  static const _lastExportAtKey = 'vittara_sync_last_export_at_v1';
  static const _lastImportAtKey = 'vittara_sync_last_import_at_v1';

  static Future<DeviceSyncState> state() async {
    final prefs = await SharedPreferences.getInstance();
    final passphrase = await _storage.read(key: _passphraseKey);
    return DeviceSyncState(
      isPaired: passphrase != null && passphrase.trim().isNotEmpty,
      deviceName: prefs.getString(_deviceNameKey) ?? 'This device',
      pairedAt: _parseDate(prefs.getString(_pairedAtKey)),
      lastExportAt: _parseDate(prefs.getString(_lastExportAtKey)),
      lastImportAt: _parseDate(prefs.getString(_lastImportAtKey)),
    );
  }

  static Future<void> savePairing({
    required String deviceName,
    required String passphrase,
  }) async {
    final cleanedName = deviceName.trim().isEmpty
        ? 'Trusted device'
        : deviceName.trim();
    final cleanedPassphrase = passphrase.trim();
    if (cleanedPassphrase.length < 10) {
      throw ArgumentError('Sync passphrase must be at least 10 characters.');
    }

    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().toIso8601String();
    await _storage.write(key: _passphraseKey, value: cleanedPassphrase);
    await prefs.setString(_deviceNameKey, cleanedName);
    await prefs.setString(_pairedAtKey, now);
  }

  static Future<void> clearPairing() async {
    final prefs = await SharedPreferences.getInstance();
    await _storage.delete(key: _passphraseKey);
    await prefs.remove(_deviceNameKey);
    await prefs.remove(_pairedAtKey);
    await prefs.remove(_lastExportAtKey);
    await prefs.remove(_lastImportAtKey);
  }

  static Future<String?> storedPassphrase() {
    return _storage.read(key: _passphraseKey);
  }

  static Future<BackupOperationResult> createSyncPackage() async {
    final passphrase = await storedPassphrase();
    if (passphrase == null || passphrase.trim().isEmpty) {
      return const BackupOperationResult(
        success: false,
        message: 'Pair this device before creating a sync package.',
      );
    }

    final result = await BackupRestoreService.buildAndExportPasswordEncryptedFile(
      passphrase,
    );
    if (result.success) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastExportAtKey, DateTime.now().toIso8601String());
    }
    return result;
  }

  static Future<void> markImported() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastImportAtKey, DateTime.now().toIso8601String());
  }

  static DateTime? _parseDate(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return DateTime.tryParse(value);
  }
}
