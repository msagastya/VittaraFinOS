/// Central registry of all SharedPreferences keys used in VittaraFinOS.
///
/// Always use these constants instead of inline string literals to prevent
/// typos and make key audits easy.
class PrefKeys {
  PrefKeys._();

  // ── Core data ─────────────────────────────────────────────────────────────
  static const String transactions = 'transactions';
  static const String archivedTransactions = 'archived_transactions';
  static const String accounts = 'accounts';
  static const String investments = 'investments';
  static const String goals = 'goals';
  static const String budgets = 'budgets';
  static const String categories = 'categories';
  static const String tags = 'tags';
  static const String contacts = 'contacts';
  static const String lendingBorrowingRecords = 'lending_borrowing_records';
  static const String recurringTemplates = 'recurring_templates_v1';
  static const String savingsPlanners = 'savings_planners';
  static const String paymentApps = 'payment_apps';

  // ── Banks & Brokers ───────────────────────────────────────────────────────
  static const String banksState = 'banks_state_v1';
  static const String brokersState = 'brokers_state_v1';

  // ── Investment preferences ─────────────────────────────────────────────────
  static const String investmentTypePreferences = 'investment_type_preferences';

  // ── Settings ──────────────────────────────────────────────────────────────
  static const String themeMode = 'themeMode';
  static const String isBiometricEnabled = 'isBiometricEnabled';
  static const String isSmsEnabled = 'isSmsEnabled';
  static const String isInvestmentTrackingEnabled = 'isInvestmentTrackingEnabled';
  static const String lockOnMinimize = 'lockOnMinimize';
  static const String lockTimeoutSeconds = 'lockTimeoutSeconds';
  static const String showArchivedTransactions = 'showArchivedTransactions';

  // ── Security ──────────────────────────────────────────────────────────────
  /// Legacy PIN hash key (migrated to flutter_secure_storage).
  static const String pinHashLegacy = 'pinHash';
  static const String vfosPinHash = 'vfos_pin_hash';
  static const String vfosRecoveryHash = 'vfos_recovery_hash';
  static const String vfosRecoveryFailedAttempts = 'vfos_recovery_failed_attempts';
  static const String vfosRecoveryLockoutUntil = 'vfos_recovery_lockout_until';

  // ── Dashboard ─────────────────────────────────────────────────────────────
  static const String dashboardConfig = 'dashboard_config';
  static const String manageScreenOrder = 'manage_screen_order';

  // ── Investments UI prefs ───────────────────────────────────────────────────
  static const String invSort = 'inv_sort';
  static const String invSortAsc = 'inv_sort_asc';

  // ── Transaction UI prefs ──────────────────────────────────────────────────
  static const String txFilterType = 'tx_filter_type';
  static const String lastUsedCategoryId = 'last_used_category_id';

  // ── Gold price cache ──────────────────────────────────────────────────────
  static const String goldPriceCached = 'gold_price_cached';
  static const String goldPriceCachedAt = 'gold_price_cached_at';

  // ── Mutual Fund ───────────────────────────────────────────────────────────
  static const String mfLastUpdate = 'mf_last_update';
  static const String mfRecentSearches = 'mf_recent_searches';

  // ── SMS ───────────────────────────────────────────────────────────────────
  static const String smsSeenFingerprints = 'sms_seen_fingerprints_v1';

  // ── Backup ────────────────────────────────────────────────────────────────
  static const String backupLatestFilePath = 'backup_latest_file_path';

  // ── AI Planner ────────────────────────────────────────────────────────────
  static const String aiPlannerMonthlyIncome = 'ai_planner_monthly_income';
  static const String aiPlannerMustSave = 'ai_planner_must_save';
}
