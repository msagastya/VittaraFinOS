import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

/// Central SQLite service for VittaraFinOS.
///
/// Schema strategy: each table stores full JSON in a [data] TEXT column plus
/// a small set of indexed columns for fast queries. This keeps serialization
/// simple (reuse existing toMap/fromMap), avoids schema drift when models
/// evolve, and lets every model be queried by its key fields.
///
/// Upgrade path: bump [_kSchemaVersion] and add a case to [_onUpgrade].
class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();

  Database? _db;

  Database get db {
    assert(_db != null,
        'DatabaseService.open() must be called before accessing db');
    return _db!;
  }

  bool get isOpen => _db != null;

  static const int _kSchemaVersion = 1;
  static const String _kDbKeyStorageKey = 'vittara_db_key';

  // Android Keystore-backed secure storage — key never leaves the secure enclave
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      keyCipherAlgorithm:
          KeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding,
      storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
    ),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  // ── Open ──────────────────────────────────────────────────────────────────

  Future<void> open() async {
    if (_db != null) return;
    final key = await _getOrCreateDbKey();
    final docDir = await getApplicationDocumentsDirectory();
    final path = join(docDir.path, 'vittara.db');

    try {
      _db = await _openWithKey(path, key);
    } on DatabaseException {
      // Database exists but was created without encryption (dev migration).
      // Delete and recreate — acceptable during build phase; data migrated next.
      debugPrint('[DatabaseService] Legacy unencrypted DB detected — recreating encrypted.');
      await File(path).delete();
      _db = await _openWithKey(path, key);
    }
    debugPrint('[DatabaseService] Opened encrypted DB: $path');
  }

  Future<Database> _openWithKey(String path, String key) {
    return openDatabase(
      path,
      password: key,
      version: _kSchemaVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: (db) async {
        // Android's SQLiteDatabase.execSQL() rejects statements that return
        // values (like PRAGMA journal_mode). Use rawQuery instead.
        try {
          await db.rawQuery('PRAGMA journal_mode=WAL');
        } catch (e) {
          debugPrint('[DatabaseService] WAL mode unavailable: $e');
        }
        try {
          await db.rawQuery('PRAGMA foreign_keys=ON');
        } catch (e) {
          debugPrint('[DatabaseService] FK pragma unavailable: $e');
        }
      },
    );
  }

  /// Returns the DB encryption key from secure storage, creating one if absent.
  Future<String> _getOrCreateDbKey() async {
    final existing = await _secureStorage.read(key: _kDbKeyStorageKey);
    if (existing != null && existing.isNotEmpty) return existing;

    // Generate a fresh 32-byte (256-bit) random key
    final rng = Random.secure();
    final keyBytes = List.generate(32, (_) => rng.nextInt(256));
    final newKey =
        keyBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    await _secureStorage.write(key: _kDbKeyStorageKey, value: newKey);
    debugPrint('[DatabaseService] Generated new DB encryption key');
    return newKey;
  }

  Future<void> _onCreate(Database db, int version) async {
    // ── transactions ─────────────────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE transactions (
        id                TEXT PRIMARY KEY,
        date_time         INTEGER NOT NULL,
        type              INTEGER NOT NULL,
        amount            REAL    NOT NULL,
        source_account_id TEXT,
        is_archived       INTEGER NOT NULL DEFAULT 0,
        data              TEXT    NOT NULL
      )
    ''');
    await db.execute(
        'CREATE INDEX idx_tx_dt   ON transactions(date_time DESC)');
    await db.execute(
        'CREATE INDEX idx_tx_type ON transactions(type)');
    await db.execute(
        'CREATE INDEX idx_tx_acc  ON transactions(source_account_id)');
    await db.execute(
        'CREATE INDEX idx_tx_arch ON transactions(is_archived)');

    // ── accounts ─────────────────────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE accounts (
        id   TEXT PRIMARY KEY,
        data TEXT NOT NULL
      )
    ''');

    // ── investments ──────────────────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE investments (
        id   TEXT PRIMARY KEY,
        data TEXT NOT NULL
      )
    ''');

    // ── goals ────────────────────────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE goals (
        id   TEXT PRIMARY KEY,
        data TEXT NOT NULL
      )
    ''');

    // ── budgets ──────────────────────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE budgets (
        id   TEXT PRIMARY KEY,
        data TEXT NOT NULL
      )
    ''');

    // ── savings_planners ─────────────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE savings_planners (
        id   TEXT PRIMARY KEY,
        data TEXT NOT NULL
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Future schema migrations go here as version-cased blocks:
    // if (oldVersion < 2) { ... }
  }

  // ── Migration from SharedPreferences ─────────────────────────────────────

  /// One-time migration. Reads legacy SharedPreferences JSON lists and writes
  /// them into SQLite. Each table is migrated at most once (checked before
  /// inserting). After migration the SharedPreferences key is deleted.
  Future<void> migrateFromSharedPrefsIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();

    // ── transactions (stored as List<String> of JSON)
    await _migrateJsonList(
      prefs: prefs,
      prefsKey: 'transactions',
      table: 'transactions',
      rowBuilder: (map) => _txRow(map, archived: false),
    );

    // ── archived transactions (separate key, merged in with is_archived=1)
    await _migrateJsonList(
      prefs: prefs,
      prefsKey: 'archived_transactions',
      table: 'transactions',
      rowBuilder: (map) => _txRow(map, archived: true),
    );

    // ── accounts
    await _migrateJsonList(
      prefs: prefs,
      prefsKey: 'accounts',
      table: 'accounts',
      rowBuilder: (map) => {'id': map['id']?.toString() ?? '', 'data': jsonEncode(map)},
    );

    // ── investments
    await _migrateJsonList(
      prefs: prefs,
      prefsKey: 'investments',
      table: 'investments',
      rowBuilder: (map) => {'id': map['id']?.toString() ?? '', 'data': jsonEncode(map)},
    );

    // ── goals (stored as single JSON string of array)
    await _migrateJsonString(
      prefs: prefs,
      prefsKey: 'goals',
      table: 'goals',
      rowBuilder: (map) => {'id': map['id']?.toString() ?? '', 'data': jsonEncode(map)},
    );

    // ── budgets
    await _migrateJsonString(
      prefs: prefs,
      prefsKey: 'budgets',
      table: 'budgets',
      rowBuilder: (map) => {'id': map['id']?.toString() ?? '', 'data': jsonEncode(map)},
    );

    // ── savings planners
    await _migrateJsonString(
      prefs: prefs,
      prefsKey: 'savings_planners',
      table: 'savings_planners',
      rowBuilder: (map) => {'id': map['id']?.toString() ?? '', 'data': jsonEncode(map)},
    );
  }

  // ── One-time external seed (manual recovery) ──────────────────────────────

  /// Checks for `vittara_seed.json` in the app's external files directory
  /// (written by `adb push` during a manual recovery). If found, inserts all
  /// rows directly into the encrypted DB and deletes the file.
  ///
  /// Format: `{ "transactions": [...], "archived_transactions": [...],
  ///            "accounts": [...], "investments": [...],
  ///            "goals": [...], "budgets": [...] }`
  ///
  /// Each array item is the raw map returned by the model's toMap().
  Future<void> seedFromExternalFileIfPresent() async {
    try {
      final extDir = await getExternalStorageDirectory();
      if (extDir == null) return;
      final seedFile = File(join(extDir.path, 'vittara_seed.json'));
      if (!await seedFile.exists()) return;

      debugPrint('[DatabaseService] Found vittara_seed.json — seeding...');
      final raw = await seedFile.readAsString();
      final data = jsonDecode(raw) as Map<String, dynamic>;

      Future<void> insertList(String key, String table,
          {bool archived = false}) async {
        final items = (data[key] as List?)?.cast<Map<String, dynamic>>() ?? [];
        if (items.isEmpty) return;
        final batch = _db!.batch();
        for (final map in items) {
          final row = table == 'transactions'
              ? _txRow(map, archived: archived)
              : {'id': map['id']?.toString() ?? '', 'data': jsonEncode(map)};
          if ((row['id'] as String? ?? '').isEmpty) continue;
          batch.insert(table, row,
              conflictAlgorithm: ConflictAlgorithm.replace);
        }
        await batch.commit(noResult: true);
        debugPrint('[DatabaseService] Seeded ${items.length} rows → $table');
      }

      await insertList('transactions', 'transactions');
      await insertList('archived_transactions', 'transactions', archived: true);
      await insertList('accounts', 'accounts');
      await insertList('investments', 'investments');
      await insertList('goals', 'goals');
      await insertList('budgets', 'budgets');

      await seedFile.delete();
      debugPrint('[DatabaseService] Seed complete — file deleted');
    } catch (e) {
      debugPrint('[DatabaseService] seedFromExternalFile error: $e');
    }
  }

  /// Migrates a SharedPreferences key that holds List<String> (each item JSON).
  Future<void> _migrateJsonList({
    required SharedPreferences prefs,
    required String prefsKey,
    required String table,
    required Map<String, dynamic> Function(Map<String, dynamic>) rowBuilder,
  }) async {
    final rows = prefs.getStringList(prefsKey);
    if (rows == null || rows.isEmpty) return;

    final existing = await _db!.query(table,
        where: 'id IS NOT NULL', limit: 1, columns: ['id']);
    if (existing.isNotEmpty) {
      // Already migrated — just clean up prefs
      await prefs.remove(prefsKey);
      return;
    }

    final batch = _db!.batch();
    for (final row in rows) {
      try {
        final map = jsonDecode(row) as Map<String, dynamic>;
        final dbRow = rowBuilder(map);
        if ((dbRow['id'] as String).isNotEmpty) {
          batch.insert(table, dbRow,
              conflictAlgorithm: ConflictAlgorithm.ignore);
        }
      } catch (e) {
        debugPrint('[DatabaseService] Migration skip malformed row: $e');
      }
    }
    await batch.commit(noResult: true);
    await prefs.remove(prefsKey);
    debugPrint('[DatabaseService] Migrated $prefsKey → $table');
  }

  /// Migrates a SharedPreferences key that holds a single JSON-encoded array.
  Future<void> _migrateJsonString({
    required SharedPreferences prefs,
    required String prefsKey,
    required String table,
    required Map<String, dynamic> Function(Map<String, dynamic>) rowBuilder,
  }) async {
    final raw = prefs.getString(prefsKey);
    if (raw == null || raw.isEmpty) return;

    final existing = await _db!.query(table,
        where: 'id IS NOT NULL', limit: 1, columns: ['id']);
    if (existing.isNotEmpty) {
      await prefs.remove(prefsKey);
      return;
    }

    try {
      final list = jsonDecode(raw) as List<dynamic>;
      final batch = _db!.batch();
      for (final item in list) {
        if (item is Map<String, dynamic>) {
          final dbRow = rowBuilder(item);
          if ((dbRow['id'] as String).isNotEmpty) {
            batch.insert(table, dbRow,
                conflictAlgorithm: ConflictAlgorithm.ignore);
          }
        }
      }
      await batch.commit(noResult: true);
    } catch (e) {
      debugPrint('[DatabaseService] Migration parse error $prefsKey: $e');
    }
    await prefs.remove(prefsKey);
    debugPrint('[DatabaseService] Migrated $prefsKey → $table');
  }

  // ── Row builders ──────────────────────────────────────────────────────────

  static Map<String, dynamic> _txRow(Map<String, dynamic> map,
      {required bool archived}) {
    // Parse dateTime — stored as ISO string in legacy data
    final rawDate = map['dateTime'];
    int dateMs = DateTime.now().millisecondsSinceEpoch;
    if (rawDate is String) {
      final dt = DateTime.tryParse(rawDate);
      if (dt != null) dateMs = dt.millisecondsSinceEpoch;
    }

    final rawType = map['type'];
    final typeIndex =
        rawType is int ? rawType : int.tryParse('$rawType') ?? 0;

    final rawAmount = map['amount'];
    final amount = rawAmount is num
        ? rawAmount.toDouble()
        : double.tryParse('$rawAmount') ?? 0.0;

    return {
      'id': map['id']?.toString() ?? '',
      'date_time': dateMs,
      'type': typeIndex,
      'amount': amount,
      'source_account_id': map['sourceAccountId']?.toString(),
      'is_archived': archived ? 1 : 0,
      'data': jsonEncode(map),
    };
  }

  // ── Generic CRUD helpers ──────────────────────────────────────────────────

  /// Insert or replace a simple id+data row.
  Future<void> upsertDataRow(String table, String id, Map<String, dynamic> data) {
    return _db!.insert(
      table,
      {'id': id, 'data': jsonEncode(data)},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Insert or replace a transaction row (includes indexed columns).
  Future<void> upsertTransaction(Map<String, dynamic> txMap,
      {bool archived = false}) {
    return _db!.insert(
      'transactions',
      _txRow(txMap, archived: archived),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteRow(String table, String id) {
    return _db!.delete(table, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getAllData(String table) async {
    final rows = await _db!.query(table);
    return rows
        .map((r) => jsonDecode(r['data'] as String) as Map<String, dynamic>)
        .toList();
  }

  /// Load all transactions with optional archived filter.
  Future<List<Map<String, dynamic>>> getTransactions(
      {bool archived = false}) async {
    final rows = await _db!.query(
      'transactions',
      where: 'is_archived = ?',
      whereArgs: [archived ? 1 : 0],
      orderBy: 'date_time DESC',
    );
    return rows
        .map((r) => jsonDecode(r['data'] as String) as Map<String, dynamic>)
        .toList();
  }

  /// Batch-insert multiple transaction maps in one transaction.
  Future<void> upsertTransactionsBatch(List<Map<String, dynamic>> maps,
      {bool archived = false}) async {
    final batch = _db!.batch();
    for (final map in maps) {
      batch.insert(
        'transactions',
        _txRow(map, archived: archived),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  /// Batch-insert multiple simple id+data rows in one transaction.
  Future<void> upsertDataRowsBatch(
      String table, List<Map<String, dynamic>> items) async {
    final batch = _db!.batch();
    for (final item in items) {
      final id = item['id']?.toString() ?? '';
      if (id.isEmpty) continue;
      batch.insert(
        table,
        {'id': id, 'data': jsonEncode(item)},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
