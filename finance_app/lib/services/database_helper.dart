import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();

  factory DatabaseHelper() {
    return _instance;
  }

  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static const int _kDbVersion = 2;

  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'mutual_funds.db');

    return await openDatabase(
      path,
      version: _kDbVersion,
      onCreate: (Database db, int version) async {
        await _createTables(db);
      },
      onUpgrade: (Database db, int oldVersion, int newVersion) async {
        await _runMigrations(db, oldVersion, newVersion);
      },
    );
  }

  static Future<void> _runMigrations(
      Database db, int oldV, int newV) async {
    for (int v = oldV + 1; v <= newV; v++) {
      switch (v) {
        case 2:
          await _migrateV1ToV2(db);
          break;
      }
    }
  }

  static Future<void> _migrateV1ToV2(Database db) async {
    // Add missing indexes that greatly speed up MF search
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_mf_is_active ON mutual_funds(is_active)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_mf_scheme_code ON mutual_funds(scheme_code)');
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS mutual_funds (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        scheme_code TEXT UNIQUE NOT NULL,
        scheme_name TEXT NOT NULL,
        isin TEXT,
        scheme_type TEXT,
        fund_house TEXT,
        nav REAL,
        last_updated TEXT,
        category TEXT,
        is_active INTEGER DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_scheme_name ON mutual_funds(scheme_name)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_scheme_type ON mutual_funds(scheme_type)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_fund_house ON mutual_funds(fund_house)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_mf_is_active ON mutual_funds(is_active)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_mf_scheme_code ON mutual_funds(scheme_code)
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS mf_metadata (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  Future<int> insertMutualFund(Map<String, dynamic> mf) async {
    final db = await database;
    return await db.insert(
      'mutual_funds',
      mf,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> insertMutualFunds(List<Map<String, dynamic>> mfs) async {
    final db = await database;
    final batch = db.batch();
    for (var mf in mfs) {
      batch.insert(
        'mutual_funds',
        mf,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
    return mfs.length;
  }

  Future<List<Map<String, dynamic>>> searchMutualFunds(
    String query, {
    String? schemeType,
    int limit = 50,
  }) async {
    final db = await database;
    String whereClause = 'is_active = 1';
    final params = <dynamic>[];

    if (query.isNotEmpty) {
      whereClause += ' AND scheme_name LIKE ?';
      params.add('%$query%');
    }

    if (schemeType != null && schemeType.isNotEmpty) {
      whereClause += ' AND scheme_type = ?';
      params.add(schemeType);
    }

    return await db.query(
      'mutual_funds',
      where: whereClause,
      whereArgs: params,
      limit: limit,
    );
  }

  Future<Map<String, dynamic>?> getMutualFundBySchemeCode(
    String schemeCode,
  ) async {
    final db = await database;
    final result = await db.query(
      'mutual_funds',
      where: 'scheme_code = ? AND is_active = 1',
      whereArgs: [schemeCode],
    );
    return result.isNotEmpty ? result.first : null;
  }

  Future<List<String>> getDistinctSchemeTypes() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT DISTINCT scheme_type FROM mutual_funds WHERE is_active = 1 AND scheme_type IS NOT NULL ORDER BY scheme_type',
    );
    return result.map((e) => e['scheme_type'] as String).toList();
  }

  Future<int> getMutualFundsCount() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM mutual_funds WHERE is_active = 1',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<bool> checkIfDataHasSchemeTypes() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM mutual_funds WHERE is_active = 1 AND scheme_type IS NULL',
    );
    final nullCount = Sqflite.firstIntValue(result) ?? 0;
    // If there are no records with NULL scheme_type, data is valid
    return nullCount == 0;
  }

  Future<void> setMetadata(String key, String value) async {
    final db = await database;
    await db.insert(
      'mf_metadata',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getMetadata(String key) async {
    final db = await database;
    final result = await db.query(
      'mf_metadata',
      where: 'key = ?',
      whereArgs: [key],
    );
    return result.isNotEmpty ? result.first['value'] as String : null;
  }

  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('mutual_funds');
    await db.delete('mf_metadata');
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
