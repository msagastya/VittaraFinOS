import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart' hide Transaction;
import 'package:vittara_fin_os/logic/transaction_model.dart' as app_txn;
import 'package:vittara_fin_os/utils/id_generator.dart';

class BackupOperationResult {
  final bool success;
  final String message;
  final String? filePath;
  final String? backupJson;
  final Map<String, dynamic>? details;

  const BackupOperationResult({
    required this.success,
    required this.message,
    this.filePath,
    this.backupJson,
    this.details,
  });
}

class BackupRestoreService {
  BackupRestoreService._();

  static const int currentSchemaVersion = 4;

  // AU3-02 — DB migration skeleton
  // When bumping currentSchemaVersion to 5, implement _migrateV4toV5() and call
  // it inside the restore path when schemaVersion == 4.
  //
  // Schema v5 changes (planned):
  //   - transactions: add `derived_metadata` TEXT column (JSON blob for AI features)
  //   - categories: add `parent_category_id` TEXT column for hierarchy
  //   - investments: add `valuation_snapshots` TEXT column (JSON array)
  //
  // static void _migrateV4toV5(Map<String, dynamic> payload) {
  //   // 1. Add derived_metadata to each transaction if missing
  //   // 2. Add parent_category_id to each category if missing
  //   // 3. bump payload['schemaVersion'] = 5
  // }

  static const String backupFormat = 'vittara_backup';
  static const String _backupAppId = 'vittara_fin_os';
  static const String backupFolderName = 'backups';
  static const String backupFilePrefix = 'vittara_backup';
  static const String latestBackupPathPrefKey = 'backup_latest_file_path';

  static const String _encryptionAlgorithm = 'hmac-sha256-stream-xor-v2';
  static const String _legacyEncryptionAlgorithm = 'hmac-sha256-stream-xor-v1';
  // keyVersion 1 = derived from hardcoded seed (legacy).
  // keyVersion 2 = derived from per-device key in flutter_secure_storage.
  static const int _encryptionKeyVersion = 2;

  /// Set to true after a restore that decrypted a v1 (legacy key) backup.
  /// Callers should check this and prompt the user to create a new backup.
  static bool lastRestoreUsedLegacyKey = false;

  /// Key used to store / retrieve the per-device backup master key.
  static const String _deviceKeyStorageKey = 'vittara_backup_device_master_key_v2';
  static const String _macAssociatedData =
      'vittara_backup_authenticated_payload';

  static const Set<String> _jsonRowStringListKeys = {
    'accounts',
    'transactions',
    'investments',
    'archived_transactions',
    'categories',
    'categories_default_overrides',
  };

  static const Set<String> _jsonStringKeys = {
    'contacts',
    'tags',
    'lending_borrowing_records',
    'payment_apps',
    'goals',
    'budgets',
    'savings_planners',
    'dashboard_config',
  };

  static const Set<String> _plainStringListKeys = {
    'categories_hidden_default_ids',
    'investment_type_preferences',
  };

  // High-value app keys that should participate in backup/restore merge.
  static const Set<String> _knownRestorableKeys = {
    'accounts',
    'transactions',
    'investments',
    'archived_transactions',
    'categories',
    'categories_default_overrides',
    'categories_hidden_default_ids',
    'contacts',
    'tags',
    'lending_borrowing_records',
    'payment_apps',
    'goals',
    'budgets',
    'savings_planners',
    'dashboard_config',
    'investment_type_preferences',
    'themeMode',
    'isBiometricEnabled',
    'lockOnMinimize',
    'lockTimeoutSeconds',
    'isInvestmentTrackingEnabled',
    'showArchivedTransactions',
  };

  // LEGACY KEY (v1 backups only) — this seed is baked into the app binary and
  // provides weaker security than the per-device key used in v2+ backups.
  // If [lastRestoreUsedLegacyKey] is true after a restore, prompt the user
  // to create a fresh backup so it gets encrypted with the v2 device key.
  // DO NOT remove or change this constant — it is needed to decrypt existing v1 backups.
  static const List<int> _masterSecretSeed = [
    0x76,
    0x69,
    0x74,
    0x74,
    0x61,
    0x72,
    0x61,
    0x5F,
    0x66,
    0x69,
    0x6E,
    0x5F,
    0x6F,
    0x73,
    0x5F,
    0x62,
    0x61,
    0x63,
    0x6B,
    0x75,
    0x70,
    0x5F,
    0x6B,
    0x65,
    0x79,
  ];

  static Future<BackupOperationResult> createLocalBackupFile() async {
    if (kIsWeb) {
      return const BackupOperationResult(
        success: false,
        message: 'Local file backup is not available on web.',
      );
    }

    final bundleResult = await buildBackupJson();
    if (!bundleResult.success || bundleResult.backupJson == null) {
      return bundleResult;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final directory = await getApplicationDocumentsDirectory();
      final backupDir = Directory('${directory.path}/$backupFolderName');
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }

      final timestamp =
          DateTime.now().toIso8601String().replaceAll(RegExp(r'[:.]'), '-');
      final filePath = '${backupDir.path}/$backupFilePrefix-$timestamp.json';
      final backupFile = File(filePath);
      await backupFile.writeAsString(bundleResult.backupJson!, flush: true);
      await prefs.setString(latestBackupPathPrefKey, filePath);

      final details = Map<String, dynamic>.from(bundleResult.details ?? {});
      details['fileSizeBytes'] = await backupFile.length();
      return BackupOperationResult(
        success: true,
        message: 'Encrypted backup file created.',
        filePath: filePath,
        backupJson: bundleResult.backupJson,
        details: details,
      );
    } catch (error) {
      return BackupOperationResult(
        success: false,
        message: 'Failed to write local backup file: $error',
      );
    }
  }

  /// Creates a backup JSON file in the temp directory and returns the file path
  /// so the caller can share it via [share_plus]. Prefer this over
  /// [createLocalBackupFile] when the user explicitly wants to export their
  /// backup — the system share sheet lets them save to Downloads, Google Drive,
  /// WhatsApp, email, etc. so it survives app uninstall.
  static Future<BackupOperationResult> buildAndExportBackupFile() async {
    if (kIsWeb) {
      return const BackupOperationResult(
        success: false,
        message: 'File export is not available on web.',
      );
    }

    final bundleResult = await buildBackupJson();
    if (!bundleResult.success || bundleResult.backupJson == null) {
      return bundleResult;
    }

    try {
      final tmpDir = await getTemporaryDirectory();
      final timestamp =
          DateTime.now().toIso8601String().replaceAll(RegExp(r'[:.]'), '-');
      final filePath =
          '${tmpDir.path}/${backupFilePrefix}_$timestamp.json';
      await File(filePath).writeAsString(bundleResult.backupJson!, flush: true);

      final details = Map<String, dynamic>.from(bundleResult.details ?? {});
      return BackupOperationResult(
        success: true,
        message: 'Backup file ready to share.',
        filePath: filePath,
        backupJson: bundleResult.backupJson,
        details: details,
      );
    } catch (error) {
      return BackupOperationResult(
        success: false,
        message: 'Failed to prepare export file: $error',
      );
    }
  }

  // ── UTL-04: Auto-backup (daily, keep last 7) ──────────────────────────────

  static const String _lastAutoBackupDateKey = 'last_auto_backup_date';
  static const int _keepBackupCount = 7;

  /// Runs at most once per calendar day. Creates an encrypted local backup
  /// and prunes older auto-backup files, keeping the [_keepBackupCount] most
  /// recent ones. Safe to call from app startup — silently no-ops if already
  /// backed up today or if running on web.
  static Future<void> runAutoBackupIfNeeded() async {
    if (kIsWeb) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final lastDate = prefs.getString(_lastAutoBackupDateKey) ?? '';
      if (lastDate == today) return; // already backed up today

      final result = await createLocalBackupFile();
      if (result.success) {
        await prefs.setString(_lastAutoBackupDateKey, today);
        await _pruneOldAutoBackups();
      }
    } catch (_) {
      // Auto-backup must never crash the app
    }
  }

  /// Deletes oldest auto-backup files, keeping the [_keepBackupCount] newest.
  static Future<void> _pruneOldAutoBackups() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final backupDir = Directory('${directory.path}/$backupFolderName');
      if (!await backupDir.exists()) return;

      final files = await backupDir
          .list()
          .where((e) =>
              e is File &&
              e.path.contains(backupFilePrefix) &&
              e.path.endsWith('.json'))
          .cast<File>()
          .toList();

      if (files.length <= _keepBackupCount) return;

      // Sort oldest first
      files.sort((a, b) => a.path.compareTo(b.path));
      final toDelete = files.sublist(0, files.length - _keepBackupCount);
      for (final f in toDelete) {
        await f.delete();
      }
    } catch (_) {}
  }

  /// Returns the list of local backup files sorted newest-first.
  static Future<List<File>> listLocalBackups() async {
    if (kIsWeb) return [];
    try {
      final directory = await getApplicationDocumentsDirectory();
      final backupDir = Directory('${directory.path}/$backupFolderName');
      if (!await backupDir.exists()) return [];

      final files = await backupDir
          .list()
          .where((e) =>
              e is File &&
              e.path.contains(backupFilePrefix) &&
              e.path.endsWith('.json'))
          .cast<File>()
          .toList();

      files.sort((a, b) => b.path.compareTo(a.path)); // newest first
      return files;
    } catch (_) {
      return [];
    }
  }

  static Future<BackupOperationResult> buildBackupJson() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final snapshotEntries = _buildSharedPrefsSnapshot(prefs);
      final sqliteSnapshots = await _buildSQLiteSnapshots();
      final createdAt = DateTime.now().toIso8601String();
      final backupId = IdGenerator.next(prefix: 'backup');

      final summary = _buildSummary(
        snapshotEntries: {
          for (final entry in snapshotEntries) entry.key: entry,
        },
        sqliteSnapshots: sqliteSnapshots,
        source: 'schema_v$currentSchemaVersion',
      );

      final payload = {
        'schemaVersion': currentSchemaVersion,
        'appId': _backupAppId,
        'backupId': backupId,
        'createdAt': createdAt,
        'sharedPrefsSnapshot':
            snapshotEntries.map((entry) => entry.toSerialized()).toList(),
        'sqliteSnapshots': sqliteSnapshots,
        'summary': summary,
      };

      final encrypted = await _encryptPayload(jsonEncode(payload));
      final envelope = {
        'schemaVersion': currentSchemaVersion,
        'format': backupFormat,
        'appId': _backupAppId,
        'backupId': backupId,
        'createdAt': createdAt,
        'summary': summary,
        'encryption': {
          'algorithm': _encryptionAlgorithm,
          'keyVersion': 1, // must match the keyVersion used inside _encryptPayload
          'nonce': encrypted['nonce'],
          'salt': encrypted['salt'],
          'mac': encrypted['mac'],
        },
        'payload': encrypted['ciphertext'],
      };

      final jsonOutput = const JsonEncoder.withIndent('  ').convert(envelope);
      return BackupOperationResult(
        success: true,
        message: 'Encrypted backup JSON generated.',
        backupJson: jsonOutput,
        details: summary,
      );
    } catch (error) {
      return BackupOperationResult(
        success: false,
        message: 'Failed to generate backup JSON: $error',
      );
    }
  }

  static Future<BackupOperationResult> inspectBackupJson(String rawJson) async {
    try {
      final parsed = await _parseIncomingBackup(rawJson);
      return BackupOperationResult(
        success: true,
        message: 'Backup parsed successfully.',
        details: parsed.summary,
      );
    } catch (error) {
      return BackupOperationResult(
        success: false,
        message: 'Invalid backup JSON: $error',
      );
    }
  }

  static Future<BackupOperationResult> restoreLatestLocalBackup() async {
    if (kIsWeb) {
      return const BackupOperationResult(
        success: false,
        message: 'Local file restore is not available on web.',
      );
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final latestPath = prefs.getString(latestBackupPathPrefKey);

      File? latestFile;
      if (latestPath != null && latestPath.trim().isNotEmpty) {
        final candidate = File(latestPath);
        if (await candidate.exists()) {
          latestFile = candidate;
        }
      }

      latestFile ??= await _findLatestBackupFile();
      if (latestFile == null) {
        return const BackupOperationResult(
          success: false,
          message: 'No local backup file found.',
        );
      }

      final raw = await latestFile.readAsString();
      final restoreResult = await restoreFromJson(raw);
      if (!restoreResult.success) {
        return restoreResult;
      }

      return BackupOperationResult(
        success: true,
        message: 'Restored from latest local backup.',
        filePath: latestFile.path,
        details: restoreResult.details,
      );
    } catch (error) {
      return BackupOperationResult(
        success: false,
        message: 'Failed to restore latest local backup: $error',
      );
    }
  }

  static Future<BackupOperationResult> restoreFromJson(String rawJson) async {
    try {
      final parsed = await _parseIncomingBackup(rawJson);
      final prefs = await SharedPreferences.getInstance();

      await _applySnapshotMerged(prefs, parsed.snapshotEntries);
      await _restoreSQLiteSnapshots(parsed.sqliteSnapshots);

      return BackupOperationResult(
        success: true,
        message:
            'Backup restored successfully with dedupe merge (no duplicate records added).',
        details: parsed.summary,
      );
    } catch (error) {
      return BackupOperationResult(
        success: false,
        message: 'Restore failed: $error',
      );
    }
  }

  static Future<List<File>> listLocalBackupFiles() async {
    if (kIsWeb) {
      return const <File>[];
    }
    final directory = await getApplicationDocumentsDirectory();
    final backupDir = Directory('${directory.path}/$backupFolderName');
    if (!await backupDir.exists()) {
      return const <File>[];
    }

    final files = backupDir
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.json'))
        .where((file) => file.path.contains(backupFilePrefix))
        .toList();
    files.sort((a, b) {
      final aTime = a.statSync().modified;
      final bTime = b.statSync().modified;
      return bTime.compareTo(aTime);
    });
    return files;
  }

  static List<_BackupSnapshotEntry> _buildSharedPrefsSnapshot(
    SharedPreferences prefs,
  ) {
    final keys = prefs.getKeys().toList()..sort();
    final entries = <_BackupSnapshotEntry>[];
    for (final key in keys) {
      final value = prefs.get(key);
      final entry = _BackupSnapshotEntry.fromRawValue(key: key, value: value);
      if (entry != null) {
        entries.add(entry);
      }
    }
    return entries;
  }

  static Future<void> _applySnapshotMerged(
    SharedPreferences prefs,
    Map<String, _BackupSnapshotEntry> incomingEntries,
  ) async {
    for (final key in incomingEntries.keys) {
      final incoming = incomingEntries[key]!;
      final existing =
          _BackupSnapshotEntry.fromRawValue(key: key, value: prefs.get(key));
      final merged = _mergeEntry(key, existing, incoming);
      await merged.writeToPrefs(prefs);
    }

    // Keep existing values for unknown/missing keys to avoid destructive loss.
    // For known keys that don't exist in backup, we intentionally preserve current
    // values to make repeated restores idempotent and safe.
  }

  static _BackupSnapshotEntry _mergeEntry(
    String key,
    _BackupSnapshotEntry? existing,
    _BackupSnapshotEntry incoming,
  ) {
    if (existing == null) {
      return incoming;
    }

    if (existing.type != incoming.type) {
      return incoming;
    }

    switch (incoming.type) {
      case _BackupValueType.stringList:
        final existingList = List<String>.from(existing.value as List<String>);
        final incomingList = List<String>.from(incoming.value as List<String>);

        if (_jsonRowStringListKeys.contains(key)) {
          final mergedRows = _mergeJsonRowStringLists(
            key: key,
            existingRows: existingList,
            incomingRows: incomingList,
          );
          return _BackupSnapshotEntry(
            key: key,
            type: _BackupValueType.stringList,
            value: mergedRows,
          );
        }

        final dedup = <String>[];
        final seen = <String>{};
        for (final value in [...existingList, ...incomingList]) {
          if (seen.add(value)) {
            dedup.add(value);
          }
        }
        return _BackupSnapshotEntry(
          key: key,
          type: _BackupValueType.stringList,
          value: dedup,
        );

      case _BackupValueType.string:
        if (_jsonStringKeys.contains(key)) {
          final merged = _mergeJsonStringPayload(
            key,
            existing.value as String,
            incoming.value as String,
          );
          return _BackupSnapshotEntry(
            key: key,
            type: _BackupValueType.string,
            value: merged,
          );
        }
        return incoming;

      case _BackupValueType.intValue:
      case _BackupValueType.doubleValue:
      case _BackupValueType.boolValue:
        return incoming;
    }
  }

  static List<String> _mergeJsonRowStringLists({
    required String key,
    required List<String> existingRows,
    required List<String> incomingRows,
  }) {
    final byIdentity = <String, Map<String, dynamic>>{};
    final byHash = <String, Map<String, dynamic>>{};

    void ingest(List<String> rows, {required bool incomingSide}) {
      for (final row in rows) {
        try {
          final decoded = jsonDecode(row);
          if (decoded is! Map) continue;
          final normalized = _normalizeRowMap(
            key,
            Map<String, dynamic>.from(decoded),
          );

          final identity = _identityForKeyedMap(key, normalized);
          if (identity != null) {
            // Incoming rows override same identity from existing rows.
            if (incomingSide || !byIdentity.containsKey(identity)) {
              byIdentity[identity] = normalized;
            }
            continue;
          }

          final fingerprint = _fingerprintMap(normalized);
          if (incomingSide || !byHash.containsKey(fingerprint)) {
            byHash[fingerprint] = normalized;
          }
        } catch (_) {
          // Ignore malformed row.
        }
      }
    }

    ingest(existingRows, incomingSide: false);
    ingest(incomingRows, incomingSide: true);

    var candidateMaps = <Map<String, dynamic>>[
      ...byIdentity.values,
      ...byHash.values,
    ];

    if (key == 'transactions' || key == 'archived_transactions') {
      final seenFingerprints = <String>{};
      final dedupedReversed = <Map<String, dynamic>>[];
      for (final map in candidateMaps.reversed) {
        final fingerprint = _transactionFingerprint(map);
        if (!seenFingerprints.add(fingerprint)) {
          continue;
        }
        dedupedReversed.add(map);
      }
      candidateMaps = dedupedReversed.reversed.toList();
    }

    final merged = <String>[];
    for (final map in candidateMaps) {
      merged.add(jsonEncode(map));
    }

    if (key == 'transactions' || key == 'archived_transactions') {
      merged.sort((a, b) {
        DateTime dateOf(String row) {
          try {
            final decoded = jsonDecode(row);
            if (decoded is Map && decoded['dateTime'] is String) {
              return DateTime.tryParse(decoded['dateTime'] as String) ??
                  DateTime.fromMillisecondsSinceEpoch(0);
            }
          } catch (_) {
            // ignore
          }
          return DateTime.fromMillisecondsSinceEpoch(0);
        }

        return dateOf(b).compareTo(dateOf(a));
      });
    }

    return merged;
  }

  static String _mergeJsonStringPayload(
    String key,
    String existingRaw,
    String incomingRaw,
  ) {
    dynamic existingDecoded;
    dynamic incomingDecoded;

    try {
      existingDecoded = jsonDecode(existingRaw);
    } catch (_) {
      existingDecoded = null;
    }
    try {
      incomingDecoded = jsonDecode(incomingRaw);
    } catch (_) {
      incomingDecoded = null;
    }

    if (existingDecoded is List && incomingDecoded is List) {
      final existingMaps = existingDecoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      final incomingMaps = incomingDecoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();

      final merged = _mergeMapListByIdentity(
        key: key,
        existing: existingMaps,
        incoming: incomingMaps,
      );
      return jsonEncode(merged);
    }

    if (existingDecoded is Map && incomingDecoded is Map) {
      // Dashboard config and similar map payloads should prefer incoming backup.
      final merged = Map<String, dynamic>.from(existingDecoded)
        ..addAll(Map<String, dynamic>.from(incomingDecoded));
      return jsonEncode(merged);
    }

    // If incoming payload isn't parseable JSON, keep incoming raw string.
    return incomingRaw;
  }

  static List<Map<String, dynamic>> _mergeMapListByIdentity({
    required String key,
    required List<Map<String, dynamic>> existing,
    required List<Map<String, dynamic>> incoming,
  }) {
    final byIdentity = <String, Map<String, dynamic>>{};
    final byHash = <String, Map<String, dynamic>>{};

    void ingest(List<Map<String, dynamic>> rows, {required bool incomingSide}) {
      for (final row in rows) {
        final normalized = _normalizeRowMap(key, row);
        final identity = _identityForKeyedMap(key, normalized);
        if (identity != null) {
          if (incomingSide || !byIdentity.containsKey(identity)) {
            byIdentity[identity] = normalized;
          }
          continue;
        }

        final hash = _fingerprintMap(normalized);
        if (incomingSide || !byHash.containsKey(hash)) {
          byHash[hash] = normalized;
        }
      }
    }

    ingest(existing, incomingSide: false);
    ingest(incoming, incomingSide: true);

    return [...byIdentity.values, ...byHash.values];
  }

  static Map<String, dynamic> _normalizeRowMap(
    String key,
    Map<String, dynamic> map,
  ) {
    if (key == 'transactions' || key == 'archived_transactions') {
      return app_txn.Transaction.fromMap(map).toMap();
    }
    return map;
  }

  static String? _identityForKeyedMap(String key, Map<String, dynamic> map) {
    final id = map['id']?.toString().trim();
    if (id != null && id.isNotEmpty) {
      return 'id:$id';
    }

    if (key == 'contacts') {
      final name = map['name']?.toString().trim().toLowerCase();
      if (name != null && name.isNotEmpty) return 'name:$name';
    }

    if (key == 'tags') {
      final name = map['name']?.toString().trim().toLowerCase();
      if (name != null && name.isNotEmpty) return 'name:$name';
    }

    if (key == 'payment_apps') {
      final name = map['name']?.toString().trim().toLowerCase();
      if (name != null && name.isNotEmpty) return 'name:$name';
    }

    if (key == 'transactions' || key == 'archived_transactions') {
      return 'fp:${_transactionFingerprint(map)}';
    }

    return null;
  }

  static String _transactionFingerprint(Map<String, dynamic> map) {
    final metadata = map['metadata'];
    final metadataKey = metadata is Map
        ? _fingerprintMap(Map<String, dynamic>.from(metadata))
        : '';
    return [
      map['type'],
      map['amount'],
      map['dateTime'],
      map['description'],
      map['sourceAccountId'],
      map['destinationAccountId'],
      map['cashbackAccountId'],
      map['charges'],
      metadataKey,
    ].join('|');
  }

  static String _fingerprintMap(Map<String, dynamic> map) {
    final canonical = _canonicalizeJson(map);
    return sha256.convert(utf8.encode(jsonEncode(canonical))).toString();
  }

  static dynamic _canonicalizeJson(dynamic value) {
    if (value is Map) {
      final keys = value.keys.map((k) => '$k').toList()..sort();
      final sorted = <String, dynamic>{};
      for (final key in keys) {
        sorted[key] = _canonicalizeJson(value[key]);
      }
      return sorted;
    }

    if (value is List) {
      return value.map(_canonicalizeJson).toList();
    }

    return value;
  }

  static Future<_ParsedBackup> _parseIncomingBackup(String rawJson) async {
    final decoded = jsonDecode(rawJson);
    if (decoded is! Map) {
      throw const FormatException('Backup root must be an object');
    }

    final root = Map<String, dynamic>.from(decoded);
    final schemaVersion =
        (root['schemaVersion'] is int) ? root['schemaVersion'] as int : 0;

    // New encrypted schema format.
    if (root['format'] == backupFormat &&
        root['payload'] is String &&
        root['encryption'] is Map) {
      final payloadJson = await _decryptPayload(
        payloadBase64: root['payload'] as String,
        encryptionMap: Map<String, dynamic>.from(root['encryption'] as Map),
        envelopeSchemaVersion: schemaVersion,
      );
      final payloadDecoded = jsonDecode(payloadJson);
      if (payloadDecoded is! Map) {
        throw const FormatException('Backup payload is malformed');
      }

      final payload = Map<String, dynamic>.from(payloadDecoded);
      final payloadAppId = payload['appId']?.toString();
      if (payloadAppId != null &&
          payloadAppId.isNotEmpty &&
          payloadAppId != _backupAppId) {
        throw FormatException(
          'Backup belongs to a different app ($payloadAppId).',
        );
      }
      final snapshotEntries = _snapshotEntriesFromList(
        (payload['sharedPrefsSnapshot'] as List?) ?? const [],
      );
      final sqliteSnapshots = (payload['sqliteSnapshots'] is List)
          ? List<Map<String, dynamic>>.from(
              (payload['sqliteSnapshots'] as List)
                  .whereType<Map>()
                  .map((item) => Map<String, dynamic>.from(item)),
            )
          : const <Map<String, dynamic>>[];

      final normalizedSnapshot = _normalizeTransactionEntries(snapshotEntries);
      final summary = _buildSummary(
        snapshotEntries: normalizedSnapshot,
        sqliteSnapshots: sqliteSnapshots,
        source: 'schema_v${payload['schemaVersion'] ?? currentSchemaVersion}',
      );

      return _ParsedBackup(
        schemaVersion:
            (payload['schemaVersion'] as int?) ?? currentSchemaVersion,
        snapshotEntries: normalizedSnapshot,
        sqliteSnapshots: sqliteSnapshots,
        summary: summary,
      );
    }

    // Backward compatibility with previous unencrypted snapshot formats.
    final rootAppId = root['appId']?.toString();
    if (rootAppId != null &&
        rootAppId.isNotEmpty &&
        rootAppId != _backupAppId) {
      throw FormatException('Backup belongs to a different app ($rootAppId).');
    }

    if (schemaVersion >= 2 &&
        root['format'] == backupFormat &&
        root['sharedPrefsSnapshot'] is List) {
      final snapshotEntries =
          _snapshotEntriesFromList(root['sharedPrefsSnapshot'] as List);
      final normalized = _normalizeTransactionEntries(snapshotEntries);
      return _ParsedBackup(
        schemaVersion: schemaVersion,
        snapshotEntries: normalized,
        sqliteSnapshots: const <Map<String, dynamic>>[],
        summary: _buildSummary(
          snapshotEntries: normalized,
          sqliteSnapshots: const <Map<String, dynamic>>[],
          source: 'legacy_schema_v$schemaVersion',
        ),
      );
    }

    if (root['sharedPrefs'] is Map) {
      final rawPrefs = Map<String, dynamic>.from(root['sharedPrefs'] as Map);
      final snapshotEntries = <String, _BackupSnapshotEntry>{};
      for (final entry in rawPrefs.entries) {
        final normalized = _normalizeLegacyValueForKey(entry.key, entry.value);
        if (normalized != null) {
          snapshotEntries[entry.key] = normalized;
        }
      }
      final normalized = _normalizeTransactionEntries(snapshotEntries);
      return _ParsedBackup(
        schemaVersion: schemaVersion > 0 ? schemaVersion : 1,
        snapshotEntries: normalized,
        sqliteSnapshots: const <Map<String, dynamic>>[],
        summary: _buildSummary(
          snapshotEntries: normalized,
          sqliteSnapshots: const <Map<String, dynamic>>[],
          source: 'legacy_shared_prefs',
        ),
      );
    }

    final snapshotEntries = <String, _BackupSnapshotEntry>{};
    for (final entry in root.entries) {
      final normalized = _normalizeLegacyValueForKey(entry.key, entry.value);
      if (normalized != null) {
        snapshotEntries[entry.key] = normalized;
      }
    }

    if (snapshotEntries.isEmpty && root['data'] is Map) {
      final dataMap = Map<String, dynamic>.from(root['data'] as Map);
      for (final entry in dataMap.entries) {
        final normalized = _normalizeLegacyValueForKey(entry.key, entry.value);
        if (normalized != null) {
          snapshotEntries[entry.key] = normalized;
        }
      }
    }

    if (snapshotEntries.isEmpty) {
      throw const FormatException('No restorable keys found in backup');
    }

    final normalized = _normalizeTransactionEntries(snapshotEntries);
    return _ParsedBackup(
      schemaVersion: schemaVersion > 0 ? schemaVersion : 0,
      snapshotEntries: normalized,
      sqliteSnapshots: const <Map<String, dynamic>>[],
      summary: _buildSummary(
        snapshotEntries: normalized,
        sqliteSnapshots: const <Map<String, dynamic>>[],
        source: schemaVersion > 0 ? 'legacy_v$schemaVersion' : 'legacy_unknown',
      ),
    );
  }

  static Map<String, _BackupSnapshotEntry> _snapshotEntriesFromList(
    List rawEntries,
  ) {
    final entries = <String, _BackupSnapshotEntry>{};
    for (final item in rawEntries) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final parsed = _BackupSnapshotEntry.fromSerialized(map);
      if (parsed != null) {
        entries[parsed.key] = parsed;
      }
    }
    return entries;
  }

  static Map<String, _BackupSnapshotEntry> _normalizeTransactionEntries(
    Map<String, _BackupSnapshotEntry> entries,
  ) {
    final normalized = Map<String, _BackupSnapshotEntry>.from(entries);

    _BackupSnapshotEntry? normalizeEntry(
      _BackupSnapshotEntry? entry,
      String prefix,
    ) {
      if (entry == null || entry.type != _BackupValueType.stringList) {
        return entry;
      }
      final rows = entry.value as List<String>;
      final normalizedRows = _normalizeTransactionRows(rows, prefix: prefix);
      return _BackupSnapshotEntry(
        key: entry.key,
        type: _BackupValueType.stringList,
        value: normalizedRows,
      );
    }

    if (normalized.containsKey('transactions')) {
      final normalizedTransactions =
          normalizeEntry(normalized['transactions'], 'txn');
      if (normalizedTransactions != null) {
        normalized['transactions'] = normalizedTransactions;
      }
    }
    if (normalized.containsKey('archived_transactions')) {
      final normalizedArchived =
          normalizeEntry(normalized['archived_transactions'], 'archived_txn');
      if (normalizedArchived != null) {
        normalized['archived_transactions'] = normalizedArchived;
      }
    }
    return normalized;
  }

  static List<String> _normalizeTransactionRows(
    List<String> rows, {
    required String prefix,
  }) {
    final normalizedRows = <String>[];
    final usedIds = <String>{};
    final seenFingerprints = <String>{};

    for (final raw in rows) {
      try {
        final map = jsonDecode(raw);
        if (map is! Map) continue;
        var transaction = app_txn.Transaction.fromMap(
          Map<String, dynamic>.from(map),
        );
        final currentId = transaction.id.trim();
        if (currentId.isEmpty || usedIds.contains(currentId)) {
          final metadata =
              Map<String, dynamic>.from(transaction.metadata ?? {});
          if (currentId.isNotEmpty) {
            metadata['restoredOriginalId'] = currentId;
          }
          metadata['idRegeneratedDuringRestore'] = true;
          transaction = transaction.copyWith(
            id: IdGenerator.next(prefix: prefix),
            metadata: metadata,
          );
        }

        final fingerprint = _transactionFingerprint(transaction.toMap());
        if (!seenFingerprints.add(fingerprint)) {
          continue;
        }

        usedIds.add(transaction.id);
        normalizedRows.add(jsonEncode(transaction.toMap()));
      } catch (_) {
        // Skip malformed transaction rows.
      }
    }

    return normalizedRows;
  }

  static _BackupSnapshotEntry? _normalizeLegacyValueForKey(
    String key,
    dynamic value,
  ) {
    if (value is Map &&
        value.containsKey('type') &&
        value.containsKey('value')) {
      final parsed = _BackupSnapshotEntry.fromSerialized({
        'key': key,
        'type': value['type'],
        'value': value['value'],
      });
      if (parsed != null) return parsed;
    }

    if (_jsonRowStringListKeys.contains(key)) {
      if (value is List) {
        final rows = value
            .map((item) => item is String ? item : jsonEncode(item))
            .toList();
        return _BackupSnapshotEntry(
          key: key,
          type: _BackupValueType.stringList,
          value: rows,
        );
      }
      return null;
    }

    if (_plainStringListKeys.contains(key)) {
      if (value is List) {
        return _BackupSnapshotEntry(
          key: key,
          type: _BackupValueType.stringList,
          value: value.map((item) => '$item').toList(),
        );
      }
      return null;
    }

    if (_jsonStringKeys.contains(key)) {
      if (value is String) {
        return _BackupSnapshotEntry(
          key: key,
          type: _BackupValueType.string,
          value: value,
        );
      }
      return _BackupSnapshotEntry(
        key: key,
        type: _BackupValueType.string,
        value: jsonEncode(value),
      );
    }

    return _BackupSnapshotEntry.fromRawValue(key: key, value: value);
  }

  static Map<String, dynamic> _buildSummary({
    required Map<String, _BackupSnapshotEntry> snapshotEntries,
    required List<Map<String, dynamic>> sqliteSnapshots,
    required String source,
  }) {
    int transactionCount = 0;
    int uniqueTransactionIds = 0;
    int duplicateTransactionIds = 0;
    int archivedTransactionCount = 0;
    int accountCount = 0;
    int investmentCount = 0;

    List<Map<String, dynamic>> decodeRows(String key) {
      final entry = snapshotEntries[key];
      if (entry == null || entry.type != _BackupValueType.stringList) {
        return const <Map<String, dynamic>>[];
      }
      final maps = <Map<String, dynamic>>[];
      for (final row in (entry.value as List<String>)) {
        try {
          final decoded = jsonDecode(row);
          if (decoded is Map) {
            maps.add(Map<String, dynamic>.from(decoded));
          }
        } catch (_) {
          // Ignore malformed rows in summary.
        }
      }
      return maps;
    }

    final txRows = decodeRows('transactions');
    transactionCount = txRows.length;
    final ids = <String>{};
    for (final row in txRows) {
      final id = (row['id'] ?? '').toString().trim();
      if (id.isEmpty) continue;
      if (!ids.add(id)) {
        duplicateTransactionIds += 1;
      }
    }
    uniqueTransactionIds = ids.length;

    archivedTransactionCount = decodeRows('archived_transactions').length;
    accountCount = decodeRows('accounts').length;
    investmentCount = decodeRows('investments').length;

    var sqliteTableCount = 0;
    var sqliteRowCount = 0;
    for (final snapshot in sqliteSnapshots) {
      final tables = snapshot['tables'];
      if (tables is List) {
        sqliteTableCount += tables.length;
        for (final table in tables.whereType<Map>()) {
          final rows = table['rows'];
          if (rows is List) {
            sqliteRowCount += rows.length;
          }
        }
      }
    }

    return {
      'source': source,
      'keys': snapshotEntries.length,
      'transactionCount': transactionCount,
      'uniqueTransactionIds': uniqueTransactionIds,
      'duplicateTransactionIds': duplicateTransactionIds,
      'archivedTransactionCount': archivedTransactionCount,
      'accountCount': accountCount,
      'investmentCount': investmentCount,
      'sqliteDatabaseCount': sqliteSnapshots.length,
      'sqliteTableCount': sqliteTableCount,
      'sqliteRowCount': sqliteRowCount,
      'createdAt': DateTime.now().toIso8601String(),
    };
  }

  static Future<File?> _findLatestBackupFile() async {
    final files = await listLocalBackupFiles();
    return files.isEmpty ? null : files.first;
  }

  static Future<List<Map<String, dynamic>>> _buildSQLiteSnapshots() async {
    if (kIsWeb) {
      return const <Map<String, dynamic>>[];
    }

    try {
      final databasesPath = await getDatabasesPath();
      final dir = Directory(databasesPath);
      if (!await dir.exists()) {
        return const <Map<String, dynamic>>[];
      }

      final dbFiles = dir
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.db'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

      final snapshots = <Map<String, dynamic>>[];
      for (final file in dbFiles) {
        try {
          final snapshot = await _snapshotDatabase(file.path);
          snapshots.add(snapshot);
        } catch (_) {
          // Skip problematic DB file but continue with others.
        }
      }
      return snapshots;
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }

  static Future<Map<String, dynamic>> _snapshotDatabase(String dbPath) async {
    final db = await openDatabase(dbPath, readOnly: true);
    try {
      final master = await db.rawQuery(
        "SELECT name, type, sql FROM sqlite_master WHERE name NOT LIKE 'sqlite_%' ORDER BY type, name",
      );

      final tables = <Map<String, dynamic>>[];
      for (final item in master) {
        final type = (item['type'] ?? '').toString();
        if (type != 'table') continue;

        final tableName = (item['name'] ?? '').toString();
        if (tableName.isEmpty) continue;

        final escaped = _escapeIdentifier(tableName);
        final columns = await db.rawQuery('PRAGMA table_info("$escaped")');
        final rows = await db.query(tableName);

        tables.add({
          'name': tableName,
          'createSql': item['sql'],
          'columns': columns,
          'rows': rows,
        });
      }

      final userVersionResult = await db.rawQuery('PRAGMA user_version');
      final userVersion = userVersionResult.isNotEmpty
          ? (userVersionResult.first.values.first as num?)?.toInt() ?? 0
          : 0;

      return {
        'fileName': p.basename(dbPath),
        'path': dbPath,
        'capturedAt': DateTime.now().toIso8601String(),
        'userVersion': userVersion,
        'tables': tables,
      };
    } finally {
      await db.close();
    }
  }

  static Future<void> _restoreSQLiteSnapshots(
    List<Map<String, dynamic>> sqliteSnapshots,
  ) async {
    if (kIsWeb || sqliteSnapshots.isEmpty) return;

    final databasesPath = await getDatabasesPath();

    for (final snapshot in sqliteSnapshots) {
      final fileName = (snapshot['fileName'] ?? '').toString();
      if (fileName.isEmpty) continue;

      final targetPath = p.join(databasesPath, fileName);
      final db = await openDatabase(targetPath);
      try {
        await _restoreDatabaseSnapshot(db, snapshot);
      } finally {
        await db.close();
      }
    }
  }

  static Future<void> _restoreDatabaseSnapshot(
    Database db,
    Map<String, dynamic> snapshot,
  ) async {
    final tablesRaw = snapshot['tables'];
    if (tablesRaw is! List) return;

    for (final rawTable in tablesRaw) {
      if (rawTable is! Map) continue;
      final table = Map<String, dynamic>.from(rawTable);
      final tableName = (table['name'] ?? '').toString();
      if (tableName.isEmpty) continue;

      final createSql = table['createSql']?.toString();
      if (createSql != null && createSql.trim().isNotEmpty) {
        try {
          await db.execute(createSql);
        } catch (_) {
          // If table already exists or SQL is incompatible, continue.
        }
      }

      final escapedTable = _escapeIdentifier(tableName);
      final existingColumns =
          await db.rawQuery('PRAGMA table_info("$escapedTable")');
      if (existingColumns.isEmpty) {
        continue;
      }

      final existingColumnNames = existingColumns
          .map((column) => (column['name'] ?? '').toString())
          .where((name) => name.isNotEmpty)
          .toSet();

      final incomingColumnsRaw = table['columns'];
      if (incomingColumnsRaw is List) {
        for (final rawColumn in incomingColumnsRaw) {
          if (rawColumn is! Map) continue;
          final column = Map<String, dynamic>.from(rawColumn);
          final columnName = (column['name'] ?? '').toString();
          if (columnName.isEmpty || existingColumnNames.contains(columnName)) {
            continue;
          }

          final columnDefinition = _buildAddColumnDefinition(column);
          final escapedColumn = _escapeIdentifier(columnName);
          try {
            await db.execute(
              'ALTER TABLE "$escapedTable" ADD COLUMN "$escapedColumn" $columnDefinition',
            );
            existingColumnNames.add(columnName);
          } catch (_) {
            // Ignore unsupported alter operations.
          }
        }
      }

      final rowsRaw = table['rows'];
      if (rowsRaw is! List || rowsRaw.isEmpty) {
        continue;
      }

      final pkColumns = _extractPrimaryKeyColumns(existingColumns);

      if (pkColumns.isNotEmpty) {
        final batch = db.batch();
        for (final rawRow in rowsRaw.whereType<Map>()) {
          final row = _filterRowToColumns(
            Map<String, dynamic>.from(rawRow),
            existingColumnNames,
          );
          if (row.isEmpty) continue;
          batch.insert(
            tableName,
            row,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        await batch.commit(noResult: true);
        continue;
      }

      // No primary key available: avoid duplicates by comparing row fingerprints.
      final existingRows = await db.query(tableName);
      final existingFingerprints = existingRows
          .map((row) => _fingerprintMap(Map<String, dynamic>.from(row)))
          .toSet();

      final batch = db.batch();
      for (final rawRow in rowsRaw.whereType<Map>()) {
        final row = _filterRowToColumns(
          Map<String, dynamic>.from(rawRow),
          existingColumnNames,
        );
        if (row.isEmpty) continue;

        final fingerprint = _fingerprintMap(row);
        if (!existingFingerprints.add(fingerprint)) {
          continue;
        }

        batch.insert(
          tableName,
          row,
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
      await batch.commit(noResult: true);
    }
  }

  static Set<String> _extractPrimaryKeyColumns(
      List<Map<String, Object?>> info) {
    final entries = <Map<String, dynamic>>[];
    for (final row in info) {
      final pk = (row['pk'] as num?)?.toInt() ?? 0;
      if (pk > 0) {
        entries.add({
          'name': (row['name'] ?? '').toString(),
          'pk': pk,
        });
      }
    }
    entries.sort(
      (a, b) => (a['pk'] as int).compareTo(b['pk'] as int),
    );
    return entries
        .map((entry) => (entry['name'] ?? '').toString())
        .where((name) => name.isNotEmpty)
        .toSet();
  }

  static Map<String, dynamic> _filterRowToColumns(
    Map<String, dynamic> row,
    Set<String> allowedColumns,
  ) {
    final filtered = <String, dynamic>{};
    for (final entry in row.entries) {
      if (allowedColumns.contains(entry.key)) {
        filtered[entry.key] = entry.value;
      }
    }
    return filtered;
  }

  static String _buildAddColumnDefinition(Map<String, dynamic> column) {
    final type = (column['type'] ?? 'TEXT').toString().trim();
    final notNull = ((column['notnull'] as num?)?.toInt() ?? 0) > 0;
    final defaultValue = column['dflt_value'];

    final builder = StringBuffer(type.isEmpty ? 'TEXT' : type);
    if (defaultValue != null && '$defaultValue'.trim().isNotEmpty) {
      builder
        ..write(' DEFAULT ')
        ..write('$defaultValue');
      if (notNull) {
        builder.write(' NOT NULL');
      }
    }
    return builder.toString();
  }

  static String _escapeIdentifier(String input) {
    return input.replaceAll('"', '""');
  }

  /// Returns the per-device 32-byte backup master key, creating it on first use
  /// and persisting it in flutter_secure_storage (iOS Keychain / Android Keystore).
  static Future<Uint8List> _getOrCreateDeviceKey() async {
    const storage = FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
    );
    final existing = await storage.read(key: _deviceKeyStorageKey);
    if (existing != null) {
      return base64Decode(existing);
    }
    final newKey = _randomBytes(32);
    await storage.write(
      key: _deviceKeyStorageKey,
      value: base64Encode(newKey),
    );
    return newKey;
  }

  static Future<Map<String, String>> _encryptPayload(String payloadJson) async {
    // keyVersion=1 uses the hardcoded seed baked into the binary — this key
    // survives app uninstall/reinstall, making backups portable and restorable.
    // The per-device key (keyVersion=2) was deleted on uninstall, breaking
    // backup restore across reinstalls.
    const keyVersion = 1;
    final nonce = _randomBytes(16);
    final salt = _randomBytes(16);
    final seed = Uint8List.fromList(_masterSecretSeed);
    final encryptionKey = _deriveEncryptionKey(
      seed: seed,
      keyVersion: keyVersion,
      salt: salt,
      purpose: 'enc',
    );
    final macKey = _deriveEncryptionKey(
      seed: seed,
      keyVersion: keyVersion,
      salt: salt,
      purpose: 'mac',
    );

    final plaintext = Uint8List.fromList(utf8.encode(payloadJson));
    final keystream = _keystream(
      key: encryptionKey,
      nonce: nonce,
      length: plaintext.length,
    );

    final cipher = Uint8List(plaintext.length);
    for (var i = 0; i < plaintext.length; i++) {
      cipher[i] = plaintext[i] ^ keystream[i];
    }

    final macInput = _buildMacInputV2(
      algorithm: _encryptionAlgorithm,
      keyVersion: keyVersion,
      nonce: nonce,
      salt: salt,
      cipher: cipher,
    );
    final mac = Hmac(sha256, macKey).convert(macInput).bytes;

    return {
      'nonce': base64Encode(nonce),
      'salt': base64Encode(salt),
      'ciphertext': base64Encode(cipher),
      'mac': base64Encode(mac),
    };
  }

  static Future<String> _decryptPayload({
    required String payloadBase64,
    required Map<String, dynamic> encryptionMap,
    required int envelopeSchemaVersion,
  }) async {
    final algorithm = (encryptionMap['algorithm'] ?? '').toString();
    if (algorithm == _encryptionAlgorithm) {
      final nonceBase64 = encryptionMap['nonce']?.toString();
      final saltBase64 = encryptionMap['salt']?.toString();
      final macBase64 = encryptionMap['mac']?.toString();
      if (nonceBase64 == null || saltBase64 == null || macBase64 == null) {
        throw const FormatException('Missing encryption metadata in backup');
      }

      final keyVersion = _readIntOrDefault(
        encryptionMap['keyVersion'],
        _encryptionKeyVersion,
      );
      final nonce = base64Decode(nonceBase64);
      final salt = base64Decode(saltBase64);
      final cipher = base64Decode(payloadBase64);
      final mac = base64Decode(macBase64);

      // Try decrypting with the keyVersions to try, in priority order.
      // Old (buggy) exports wrote keyVersion=2 in the envelope but encrypted
      // with the portable seed (keyVersion=1). So if the stated keyVersion is 2
      // we still fall back to 1 if MAC verification fails.
      final keyVersionsToTry = keyVersion == 1
          ? [1]
          : [keyVersion, 1]; // try stated version first, then portable seed

      for (final kv in keyVersionsToTry) {
        final Uint8List seed;
        if (kv >= 2) {
          try {
            seed = await _getOrCreateDeviceKey();
          } catch (_) {
            continue; // can't get device key on this device — try next
          }
        } else {
          seed = Uint8List.fromList(_masterSecretSeed);
        }

        final encryptionKey = _deriveEncryptionKey(
          seed: seed,
          keyVersion: kv,
          salt: salt,
          purpose: 'enc',
        );
        final macKey = _deriveEncryptionKey(
          seed: seed,
          keyVersion: kv,
          salt: salt,
          purpose: 'mac',
        );
        final macInput = _buildMacInputV2(
          algorithm: algorithm,
          keyVersion: kv,
          nonce: nonce,
          salt: salt,
          cipher: cipher,
        );
        final expectedMac = Hmac(sha256, macKey).convert(macInput).bytes;

        if (_constantTimeEquals(expectedMac, mac)) {
          lastRestoreUsedLegacyKey = false;
          return _decryptWithKey(
            key: encryptionKey,
            nonce: nonce,
            cipher: cipher,
          );
        }
      }

      throw const FormatException(
        'Backup decryption failed: authentication tag mismatch',
      );
    }

    // Backward-compatible decryption for previous encrypted backups.
    if (algorithm == _legacyEncryptionAlgorithm || algorithm.isEmpty) {
      return _decryptLegacyPayload(
        payloadBase64: payloadBase64,
        encryptionMap: encryptionMap,
        envelopeSchemaVersion: envelopeSchemaVersion,
      );
    }

    throw FormatException('Unsupported encryption algorithm: $algorithm');
  }

  static Uint8List _buildMacInputV2({
    required String algorithm,
    required int keyVersion,
    required Uint8List nonce,
    required Uint8List salt,
    required Uint8List cipher,
  }) {
    final macInput = BytesBuilder(copy: false)
      ..add(utf8.encode(_macAssociatedData))
      ..addByte(0)
      ..add(utf8.encode(backupFormat))
      ..addByte(0)
      ..add(utf8.encode(algorithm))
      ..addByte(0)
      ..add(utf8.encode('$keyVersion'))
      ..addByte(0)
      ..add(nonce)
      ..add(salt)
      ..add(cipher);
    return macInput.toBytes();
  }

  static String _decryptLegacyPayload({
    required String payloadBase64,
    required Map<String, dynamic> encryptionMap,
    required int envelopeSchemaVersion,
  }) {
    final nonceBase64 = encryptionMap['nonce']?.toString();
    final macBase64 = encryptionMap['mac']?.toString();
    if (nonceBase64 == null || macBase64 == null) {
      throw const FormatException('Missing encryption metadata in backup');
    }

    final keyVersion = _readIntOrDefault(encryptionMap['keyVersion'], 1);
    final nonce = base64Decode(nonceBase64);
    final cipher = base64Decode(payloadBase64);
    final mac = base64Decode(macBase64);
    final key = _deriveLegacyEncryptionKey(keyVersion: keyVersion);

    final macContexts = <String>{
      if (envelopeSchemaVersion > 0) '$envelopeSchemaVersion',
      '$currentSchemaVersion',
    };

    for (final context in macContexts) {
      final macInput = BytesBuilder(copy: false)
        ..add(nonce)
        ..add(cipher)
        ..add(utf8.encode(context));
      final expectedMac = Hmac(sha256, key).convert(macInput.toBytes()).bytes;
      if (_constantTimeEquals(expectedMac, mac)) {
        return _decryptWithKey(
          key: key,
          nonce: nonce,
          cipher: cipher,
        );
      }
    }

    throw const FormatException(
      'Backup decryption failed: authentication tag mismatch',
    );
  }

  static String _decryptWithKey({
    required Uint8List key,
    required Uint8List nonce,
    required Uint8List cipher,
  }) {
    final keystream = _keystream(
      key: key,
      nonce: nonce,
      length: cipher.length,
    );
    final plain = Uint8List(cipher.length);
    for (var i = 0; i < cipher.length; i++) {
      plain[i] = cipher[i] ^ keystream[i];
    }
    return utf8.decode(plain);
  }

  static Uint8List _deriveLegacyEncryptionKey({
    required int keyVersion,
  }) {
    final hmac = Hmac(sha256, _masterSecretSeed);
    final bytes = hmac
        .convert(utf8.encode('backup_key_v$keyVersion:$backupFormat'))
        .bytes;
    return Uint8List.fromList(bytes);
  }

  static Uint8List _deriveEncryptionKey({
    required Uint8List seed,
    required int keyVersion,
    required Uint8List salt,
    required String purpose,
  }) {
    final master = Hmac(sha256, seed)
        .convert(utf8.encode('backup_master_v$keyVersion:$backupFormat'))
        .bytes;

    final input = BytesBuilder(copy: false)
      ..add(utf8.encode('purpose:$purpose'))
      ..addByte(0)
      ..add(salt)
      ..addByte(0)
      ..add(utf8.encode('$keyVersion'));

    final bytes = Hmac(sha256, master).convert(input.toBytes()).bytes;
    return Uint8List.fromList(bytes);
  }

  static int _readIntOrDefault(dynamic value, int defaultValue) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value) ?? defaultValue;
    }
    return defaultValue;
  }

  static Uint8List _keystream({
    required Uint8List key,
    required Uint8List nonce,
    required int length,
  }) {
    final output = BytesBuilder(copy: false);
    var counter = 0;

    while (output.length < length) {
      final counterBytes = ByteData(8)..setUint64(0, counter);
      final blockInput = BytesBuilder(copy: false)
        ..add(nonce)
        ..add(counterBytes.buffer.asUint8List());
      final block = Hmac(sha256, key).convert(blockInput.toBytes()).bytes;
      output.add(block);
      counter += 1;
    }

    final all = output.toBytes();
    return Uint8List.sublistView(all, 0, length);
  }

  static Uint8List _randomBytes(int length) {
    final random = Random.secure();
    final bytes = Uint8List(length);
    for (var i = 0; i < length; i++) {
      bytes[i] = random.nextInt(256);
    }
    return bytes;
  }

  static bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) {
      return false;
    }
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}

class _ParsedBackup {
  final int schemaVersion;
  final Map<String, _BackupSnapshotEntry> snapshotEntries;
  final List<Map<String, dynamic>> sqliteSnapshots;
  final Map<String, dynamic> summary;

  _ParsedBackup({
    required this.schemaVersion,
    required this.snapshotEntries,
    required this.sqliteSnapshots,
    required this.summary,
  });
}

enum _BackupValueType {
  string,
  intValue,
  doubleValue,
  boolValue,
  stringList,
}

class _BackupSnapshotEntry {
  final String key;
  final _BackupValueType type;
  final Object value;

  const _BackupSnapshotEntry({
    required this.key,
    required this.type,
    required this.value,
  });

  static _BackupSnapshotEntry? fromRawValue({
    required String key,
    required dynamic value,
  }) {
    if (value is String) {
      return _BackupSnapshotEntry(
        key: key,
        type: _BackupValueType.string,
        value: value,
      );
    }
    if (value is int) {
      return _BackupSnapshotEntry(
        key: key,
        type: _BackupValueType.intValue,
        value: value,
      );
    }
    if (value is double) {
      return _BackupSnapshotEntry(
        key: key,
        type: _BackupValueType.doubleValue,
        value: value,
      );
    }
    if (value is bool) {
      return _BackupSnapshotEntry(
        key: key,
        type: _BackupValueType.boolValue,
        value: value,
      );
    }
    if (value is List<String>) {
      return _BackupSnapshotEntry(
        key: key,
        type: _BackupValueType.stringList,
        value: value,
      );
    }
    return null;
  }

  static _BackupSnapshotEntry? fromSerialized(Map<String, dynamic> map) {
    final key = map['key']?.toString();
    final typeRaw = map['type']?.toString();
    if (key == null || key.trim().isEmpty || typeRaw == null) {
      return null;
    }

    switch (typeRaw) {
      case 'string':
        return _BackupSnapshotEntry(
          key: key,
          type: _BackupValueType.string,
          value: map['value']?.toString() ?? '',
        );
      case 'int':
        final intValue = map['value'] is int
            ? map['value'] as int
            : int.tryParse('${map['value']}');
        if (intValue == null) return null;
        return _BackupSnapshotEntry(
          key: key,
          type: _BackupValueType.intValue,
          value: intValue,
        );
      case 'double':
        final doubleValue = map['value'] is num
            ? (map['value'] as num).toDouble()
            : double.tryParse('${map['value']}');
        if (doubleValue == null) return null;
        return _BackupSnapshotEntry(
          key: key,
          type: _BackupValueType.doubleValue,
          value: doubleValue,
        );
      case 'bool':
        final raw = map['value'];
        bool? boolValue;
        if (raw is bool) {
          boolValue = raw;
        } else if ('$raw'.toLowerCase() == 'true') {
          boolValue = true;
        } else if ('$raw'.toLowerCase() == 'false') {
          boolValue = false;
        }
        if (boolValue == null) return null;
        return _BackupSnapshotEntry(
          key: key,
          type: _BackupValueType.boolValue,
          value: boolValue,
        );
      case 'stringList':
        final value = map['value'];
        if (value is! List) return null;
        return _BackupSnapshotEntry(
          key: key,
          type: _BackupValueType.stringList,
          value: value.map((item) => '$item').toList(),
        );
      default:
        return null;
    }
  }

  Map<String, dynamic> toSerialized() {
    return {
      'key': key,
      'type': _serializedType,
      'value': value,
    };
  }

  String get _serializedType {
    switch (type) {
      case _BackupValueType.string:
        return 'string';
      case _BackupValueType.intValue:
        return 'int';
      case _BackupValueType.doubleValue:
        return 'double';
      case _BackupValueType.boolValue:
        return 'bool';
      case _BackupValueType.stringList:
        return 'stringList';
    }
  }

  Future<void> writeToPrefs(SharedPreferences prefs) async {
    switch (type) {
      case _BackupValueType.string:
        await prefs.setString(key, value as String);
      case _BackupValueType.intValue:
        await prefs.setInt(key, value as int);
      case _BackupValueType.doubleValue:
        await prefs.setDouble(key, value as double);
      case _BackupValueType.boolValue:
        await prefs.setBool(key, value as bool);
      case _BackupValueType.stringList:
        await prefs.setStringList(key, (value as List<String>));
    }
  }
}
