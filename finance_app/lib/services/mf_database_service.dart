import 'package:logger/logger.dart';
import 'package:vittara_fin_os/models/mutual_fund_model.dart';
import 'package:vittara_fin_os/services/database_helper.dart';
import 'package:vittara_fin_os/services/amfi_data_service.dart';

class MFDatabaseService {
  static final MFDatabaseService _instance = MFDatabaseService._internal();
  static final Logger _logger = Logger();

  final DatabaseHelper _dbHelper = DatabaseHelper();
  static const String _lastUpdateKey = 'mf_last_update';
  static const Duration _cacheValidity = Duration(hours: 24);

  bool _isInitializing = false;
  bool _isInitialized = false;

  factory MFDatabaseService() {
    return _instance;
  }

  MFDatabaseService._internal();

  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    if (_isInitialized || _isInitializing) return;

    _isInitializing = true;
    try {
      final count = await _dbHelper.getMutualFundsCount();

      if (count == 0) {
        // First time: fetch and store data
        _logger.i('First time initialization - fetching AMFI data');
        await _fetchAndStoreAMFIData();
      } else {
        // Data exists: check if it has valid scheme types (v2 format)
        final hasValidSchemeTypes = await _dbHelper.checkIfDataHasSchemeTypes();

        if (!hasValidSchemeTypes) {
          // Old format data without scheme types: force refresh
          _logger.i(
              'Detected old data format - forcing refresh to get scheme types');
          await _fetchAndStoreAMFIData();
        } else {
          // Check if data needs refresh based on timestamp
          final lastUpdate = await _dbHelper.getMetadata(_lastUpdateKey);
          if (lastUpdate == null || _isDataStale(lastUpdate)) {
            // Stale data: refresh in background (non-blocking)
            _logger.i('Data is stale - refreshing in background');
            _refreshDataInBackground();
          } else {
            _logger.i('Data is fresh - using cached data');
          }
        }
      }
      _isInitialized = true;
    } catch (e) {
      _logger.e('Error initializing MF database: $e');
      _isInitialized =
          true; // Mark as initialized even on error to avoid blocking
    } finally {
      _isInitializing = false;
    }
  }

  Future<void> _fetchAndStoreAMFIData() async {
    try {
      _logger.i('Fetching AMFI data...');
      final mfs = await AMFIDataService.fetchAndParseAMFIData();
      _logger.i('Fetched ${mfs.length} mutual funds, storing in database...');

      await _dbHelper.insertMutualFunds(
        mfs.map((mf) => mf.toMap()).toList(),
      );

      await _dbHelper.setMetadata(
        _lastUpdateKey,
        DateTime.now().toIso8601String(),
      );

      _logger.i('Successfully stored ${mfs.length} mutual funds in database');
    } catch (e) {
      _logger.e('Error fetching and storing AMFI data: $e');
      rethrow;
    }
  }

  void _refreshDataInBackground() {
    Future.delayed(Duration.zero, () async {
      try {
        _logger.i('Background: Refreshing mutual funds data');
        await _fetchAndStoreAMFIData();
        _logger.i('Background: Data refresh completed successfully');
      } catch (e) {
        _logger.w('Background: Failed to refresh data (non-blocking): $e');
        // Don't rethrow - this is background refresh, continue with cached data
      }
    });
  }

  bool _isDataStale(String lastUpdateString) {
    try {
      final lastUpdate = DateTime.parse(lastUpdateString);
      final now = DateTime.now();
      return now.difference(lastUpdate) > _cacheValidity;
    } catch (e) {
      _logger.w('Error parsing last update timestamp: $e');
      return true; // Treat as stale on parse error
    }
  }

  Future<List<MutualFund>> searchMutualFunds(
    String query, {
    String? schemeType,
    int limit = 50,
  }) async {
    try {
      final results = await _dbHelper.searchMutualFunds(
        query,
        schemeType: schemeType,
        limit: limit,
      );
      return results.map((map) => MutualFund.fromMap(map)).toList();
    } catch (e) {
      _logger.e('Error searching mutual funds: $e');
      return [];
    }
  }

  Future<MutualFund?> getMutualFundBySchemeCode(String schemeCode) async {
    try {
      final result = await _dbHelper.getMutualFundBySchemeCode(schemeCode);
      return result != null ? MutualFund.fromMap(result) : null;
    } catch (e) {
      _logger.e('Error getting mutual fund by scheme code: $e');
      return null;
    }
  }

  Future<List<String>> getDistinctSchemeTypes() async {
    try {
      return await _dbHelper.getDistinctSchemeTypes();
    } catch (e) {
      _logger.e('Error getting distinct scheme types: $e');
      return [];
    }
  }

  Future<int> getMutualFundsCount() async {
    try {
      return await _dbHelper.getMutualFundsCount();
    } catch (e) {
      _logger.e('Error getting mutual funds count: $e');
      return 0;
    }
  }

  Future<void> refreshData() async {
    try {
      _logger.i('Manual refresh requested');
      await _fetchAndStoreAMFIData();
    } catch (e) {
      _logger.e('Error refreshing data: $e');
      rethrow;
    }
  }

  Future<void> clearData() async {
    try {
      await _dbHelper.clearAllData();
      _logger.i('All data cleared');
    } catch (e) {
      _logger.e('Error clearing data: $e');
      rethrow;
    }
  }
}
