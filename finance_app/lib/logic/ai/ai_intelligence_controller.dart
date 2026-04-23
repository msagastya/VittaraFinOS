import 'package:flutter/foundation.dart';
import 'package:vittara_fin_os/logic/goal_model.dart';
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
import 'goal_timeline.dart';
import 'predicted_calendar.dart';
import 'monthly_narrative.dart';
import 'habit_observation_engine.dart';
import 'habit_constructor.dart';
import 'behavioral_nudge.dart';
import 'financial_health_score.dart';

/// Callbacks the AI controller uses to pull live data from other controllers.
/// Injected at startup from main.dart so the AI controller stays decoupled
/// from the Provider tree while still getting real balances, budgets, and goals.
class AIDataProviders {
  /// Returns current account balances as {accountId: balance}.
  final Map<String, double> Function() accountBalances;

  /// Returns active budgets as raw maps (Budget.toMap()).
  final List<Map<String, dynamic>> Function() budgets;

  /// Returns active goals.
  final List<Goal> Function() goals;

  /// Returns current account count.
  final int Function() accountCount;

  const AIDataProviders({
    required this.accountBalances,
    required this.budgets,
    required this.goals,
    required this.accountCount,
  });
}

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

  // Phase 2 — goal timelines + predicted calendar
  List<GoalTimelineAnalysis> _goalTimelines = [];
  List<GoalTimelineAnalysis> get goalTimelines => _goalTimelines;

  List<PredictedTransaction> _predictedCalendar = [];
  List<PredictedTransaction> get predictedCalendar => _predictedCalendar;

  // Phase 3 — narrative
  MonthlyNarrative? _currentMonthNarrative;
  MonthlyNarrative? get currentMonthNarrative => _currentMonthNarrative;

  // Phase 4 — habits
  List<HabitOpportunity> _habitOpportunities = [];
  List<HabitOpportunity> get habitOpportunities => _habitOpportunities;
  HabitOpportunity? get topHabitOpportunity =>
      _habitOpportunities.isEmpty ? null : _habitOpportunities.first;

  List<HabitContract> _activeHabits = [];
  List<HabitContract> get activeHabits => _activeHabits;

  List<HabitNudge> _habitNudges = [];
  List<HabitNudge> get habitNudges => _habitNudges;

  // Phase 6 — financial health score
  FinancialHealthScore? _healthScore;
  FinancialHealthScore? get healthScore => _healthScore;

  bool _isComputing = false;
  bool get isComputing => _isComputing;

  bool _initialized = false;
  bool get isInitialized => _initialized;

  AIDataProviders? _providers;

  // ── Init ───────────────────────────────────────────────────────────────────

  /// Wire live data providers after all controllers are ready.
  /// Call from main.dart after the Provider tree is built.
  void wireProviders(AIDataProviders providers) {
    _providers = providers;
  }

  /// Initialize once at startup — loads cached data and detects device tier.
  Future<void> init() async {
    if (_initialized) return;
    _tier = await DeviceIntelligenceTier.detect();
    await MerchantNormalizer.init();

    // Load any previously computed results from cache (fast, no computation)
    _patterns = await PatternDetector.loadCached();
    _fingerprint = await BehavioralFingerprintBuilder.loadCached();

    // Load persisted habits
    _activeHabits = await HabitConstructor.loadAll();

    // Register hook so we get notified whenever TransactionsController data changes.
    // Pull real balances/budgets/goals from wired providers if available.
    TransactionsController.onDataChanged = (txs) {
      final p = _providers;
      refresh(
        transactions: txs,
        accountCount: p != null ? p.accountCount() : 1,
        budgets: p?.budgets(),
        accountBalances: p?.accountBalances(),
        goals: p?.goals(),
      );
    };

    _initialized = true;
    notifyListeners();

    // Trigger an immediate refresh using whatever transactions are already loaded.
    // This handles the case where TransactionsController finished loading before
    // this hook was registered (race condition on startup / after reinstall).
    final existing = TransactionsController.lastKnownTransactions;
    if (existing != null && existing.isNotEmpty) {
      final p = _providers;
      refresh(
        transactions: existing,
        accountCount: p != null ? p.accountCount() : 1,
        budgets: p?.budgets(),
        accountBalances: p?.accountBalances(),
        goals: p?.goals(),
      );
    }
  }

  // ── Refresh ────────────────────────────────────────────────────────────────

  /// Full analysis pass. Call when transaction list changes meaningfully.
  /// [accountCount] is used for data readiness evaluation.
  Future<void> refresh({
    required List<Transaction> transactions,
    required int accountCount,
    List<Map<String, dynamic>>? budgets, // raw budget maps for predictions
    Map<String, double>? accountBalances, // accountId → current balance
    List<Goal>? goals, // for goal timeline analysis
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

      // Phase 3a: opportunity spotter
      if (_readiness.canGenerateInsights && accountBalances != null) {
        _opportunities = OpportunitySpotter.spot(
          transactions: transactions,
          accountBalances: accountBalances,
          patterns: _patterns,
        );
      }

      // Phase 2 extras: goal timelines + predicted calendar
      if (_readiness.canForecast && goals != null) {
        _goalTimelines = GoalTimeline.analyse(
          goals: goals,
          transactions: transactions,
        );
      }
      if (_readiness.canDetectPatterns && _patterns != null) {
        _predictedCalendar = PredictedCalendar.build(
          patterns: _patterns!,
          from: DateTime.now(),
        );
      }

      // Phase 3b: monthly narrative
      if (_readiness.canGenerateInsights) {
        final now = DateTime.now();
        _currentMonthNarrative = MonthlyNarrativeGenerator.generate(
          transactions: transactions,
          year: now.year,
          month: now.month,
          fingerprint: _readiness.canComputeFingerprint ? _fingerprint : null,
          patterns: _patterns,
        );
      }

      // Phase 4: habit opportunities + nudges
      if (_readiness.canBuildHabits) {
        _habitOpportunities = HabitObservationEngine.observe(
          transactions: transactions,
          readiness: _readiness,
        );
      }

      // Phase 6: Financial Health Score
      if (_readiness.canShowHealthScore && accountBalances != null) {
        _healthScore = FinancialHealthScorer.compute(
          transactions: transactions,
          accountBalances: accountBalances,
          goals: goals ?? [],
          predictedCalendar: _predictedCalendar.isNotEmpty ? _predictedCalendar : null,
        );
      }

      // Reload persisted habits and compute nudges
      _activeHabits = await HabitConstructor.loadAll();
      if (_activeHabits.isNotEmpty) {
        _habitNudges = BehavioralNudgeEngine.compute(
          habits: _activeHabits,
          transactions: transactions,
          currentStreakDays: 0, // wired to TransactionsController.loggingStreakDays separately
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

  // ── Habit management ──────────────────────────────────────────────────────

  /// Persist a new habit contract and update local state.
  Future<void> addHabit(HabitContract contract) async {
    await HabitConstructor.save(contract);
    _activeHabits = await HabitConstructor.loadAll();
    notifyListeners();
  }

  /// Update an existing habit (e.g. after difficulty calibration).
  Future<void> updateHabit(HabitContract updated) async {
    await HabitConstructor.update(updated);
    _activeHabits = await HabitConstructor.loadAll();
    notifyListeners();
  }

  /// Monthly narrative for a specific month (useful for history view).
  MonthlyNarrative narrativeFor(
    List<Transaction> transactions,
    int year,
    int month,
  ) {
    return MonthlyNarrativeGenerator.generate(
      transactions: transactions,
      year: year,
      month: month,
      fingerprint: _readiness.canComputeFingerprint ? _fingerprint : null,
      patterns: _patterns,
    );
  }
}
