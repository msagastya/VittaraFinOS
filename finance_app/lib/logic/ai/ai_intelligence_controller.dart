import 'package:flutter/foundation.dart';
import 'package:vittara_fin_os/logic/transaction_model.dart';
import 'package:vittara_fin_os/logic/transactions_controller.dart';
import 'device_intelligence_tier.dart';
import 'merchant_normalizer.dart';
import 'pattern_detector.dart';
import 'behavioral_fingerprint.dart';
import 'data_readiness.dart';
import 'budget_exhaustion_predictor.dart';
import 'cashflow_forecaster.dart';
import 'anomaly_detector.dart';
import 'opportunity_spotter.dart';

/// Central coordinator for all on-device AI features.
///
/// Register as a ChangeNotifier provider alongside other controllers.
/// Call [refresh] whenever transactions or accounts change meaningfully.
///
/// All computation is async and non-blocking — the UI rebuilds progressively
/// as each analysis phase completes.
class AIIntelligenceController extends ChangeNotifier {
  // ── State ──────────────────────────────────────────────────────────────────

  IntelligenceTier _tier = IntelligenceTier.entry;
  IntelligenceTier get tier => _tier;

  DataReadiness _readiness = const DataReadiness(
    hasBasicHistory: false,
    hasTwoWeeks: false,
    hasOneMonth: false,
    hasTwoMonths: false,
    hasAccount: false,
  );
  DataReadiness get readiness => _readiness;

  SpendingPatterns? _patterns;
  SpendingPatterns? get patterns => _patterns;

  BehavioralFingerprint _fingerprint = BehavioralFingerprint.neutral;
  BehavioralFingerprint get fingerprint => _fingerprint;

  List<BudgetPrediction> _budgetPredictions = [];
  List<BudgetPrediction> get budgetPredictions => _budgetPredictions;

  CashflowForecast? _cashflowForecast;
  CashflowForecast? get cashflowForecast => _cashflowForecast;

  List<AnomalyAlert> _anomalies = [];
  List<AnomalyAlert> get anomalies => _anomalies;
  List<AnomalyAlert> get recentAnomalies =>
      _anomalies.where((a) => !a.isDismissed).take(3).toList();

  List<OpportunityTip> _opportunities = [];
  List<OpportunityTip> get opportunities => _opportunities;
  List<OpportunityTip> get topOpportunities =>
      _opportunities.take(3).toList();

  bool _isComputing = false;
  bool get isComputing => _isComputing;

  bool _initialized = false;
  bool get isInitialized => _initialized;

  // ── Init ───────────────────────────────────────────────────────────────────

  /// Initialize once at startup — loads cached data and detects device tier.
  Future<void> init() async {
    if (_initialized) return;
    _tier = await DeviceIntelligenceTier.detect();
    await MerchantNormalizer.init();

    // Load any previously computed results from cache (fast, no computation)
    _patterns = await PatternDetector.loadCached();
    _fingerprint = await BehavioralFingerprintBuilder.loadCached();

    // Register hook so we get notified whenever TransactionsController data changes
    TransactionsController.onDataChanged = (txs) {
      // Lightweight refresh — patterns + fingerprint are rate-limited internally
      refresh(transactions: txs, accountCount: 1);
    };

    _initialized = true;
    notifyListeners();
  }

  // ── Refresh ────────────────────────────────────────────────────────────────

  /// Full analysis pass. Call when transaction list changes meaningfully.
  /// [accountCount] is used for data readiness evaluation.
  Future<void> refresh({
    required List<Transaction> transactions,
    required int accountCount,
    List<Map<String, dynamic>>? budgets, // raw budget maps for predictions
    Map<String, double>? accountBalances, // accountId → current balance
  }) async {
    if (_isComputing) return; // don't stack refreshes

    _isComputing = true;
    notifyListeners();

    try {
      // Phase 0: evaluate data readiness
      _readiness = DataReadiness.evaluate(
        transactions: transactions,
        accountCount: accountCount,
      );

      // Phase 1a: normalize merchant names (enriches metadata in memory only)
      _enrichMerchantNames(transactions);

      // Phase 1b: pattern detection
      if (_readiness.canDetectPatterns) {
        _patterns = await PatternDetector.analyse(transactions);
      }

      // Phase 1c: behavioral fingerprint
      if (_readiness.canComputeFingerprint) {
        _fingerprint = await BehavioralFingerprintBuilder.compute(transactions);
      }

      // Phase 2a: budget exhaustion predictions
      if (_readiness.canForecast && budgets != null) {
        _budgetPredictions = BudgetExhaustionPredictor.predict(
          transactions: transactions,
          budgets: budgets,
        );
      }

      // Phase 2b: cashflow forecast
      if (_readiness.canForecast && accountBalances != null && _patterns != null) {
        _cashflowForecast = CashflowForecaster.forecast(
          transactions: transactions,
          patterns: _patterns!,
          accountBalances: accountBalances,
        );
      }

      // Phase 2c: anomaly detection
      if (_readiness.canDetectAnomalies) {
        _anomalies = AnomalyDetector.detect(
          transactions: transactions,
          existingAlerts: _anomalies,
        );
      }

      // Phase 3: opportunity spotter
      if (_readiness.canGenerateInsights && accountBalances != null) {
        _opportunities = OpportunitySpotter.spot(
          transactions: transactions,
          accountBalances: accountBalances,
          patterns: _patterns,
        );
      }
    } catch (e) {
      debugPrint('[AIIntelligenceController] refresh error: $e');
    } finally {
      _isComputing = false;
      notifyListeners();
    }
  }

  // ── Merchant name enrichment ───────────────────────────────────────────────

  /// Normalizes merchant names in the transaction metadata cache so display
  /// widgets always show clean names without modifying persisted data.
  static final Map<String, String> _merchantCache = {};

  static String displayName(Transaction tx) {
    final raw = (tx.metadata?['merchant'] as String?)?.trim();
    if (raw != null && raw.isNotEmpty) {
      return _merchantCache.putIfAbsent(
          raw, () => MerchantNormalizer.normalize(raw));
    }
    // Fall back to normalizing the description
    return _merchantCache.putIfAbsent(
        tx.description, () => MerchantNormalizer.normalize(tx.description));
  }

  void _enrichMerchantNames(List<Transaction> transactions) {
    for (final tx in transactions) {
      displayName(tx); // warms the cache
    }
  }

  // ── Anomaly dismissal ─────────────────────────────────────────────────────

  void dismissAnomaly(String anomalyId) {
    final idx = _anomalies.indexWhere((a) => a.id == anomalyId);
    if (idx >= 0) {
      _anomalies[idx] = _anomalies[idx].copyWith(isDismissed: true);
      notifyListeners();
    }
  }

  // ── Convenience accessors ─────────────────────────────────────────────────

  /// True when at least one budget is predicted to exhaust before month end.
  bool get hasBudgetWarnings =>
      _budgetPredictions.any((p) => p.daysUntilExhaustion != null &&
          p.daysUntilExhaustion! <= 7);

  /// The single most urgent budget warning, or null.
  BudgetPrediction? get mostUrgentBudgetWarning {
    final warnings = _budgetPredictions
        .where((p) => p.daysUntilExhaustion != null)
        .toList()
      ..sort((a, b) =>
          (a.daysUntilExhaustion ?? 999)
              .compareTo(b.daysUntilExhaustion ?? 999));
    return warnings.isEmpty ? null : warnings.first;
  }

  /// Balance projected to drop below a threshold within 14 days.
  bool get hasCashflowWarning {
    final forecast = _cashflowForecast;
    if (forecast == null) return false;
    return forecast.warnings.isNotEmpty;
  }
}
