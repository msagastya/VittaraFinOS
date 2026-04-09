import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vittara_fin_os/logic/account_model.dart';
import 'package:vittara_fin_os/logic/budget_model.dart';
import 'package:vittara_fin_os/logic/goal_model.dart';
import 'package:vittara_fin_os/logic/investment_model.dart';
import 'package:vittara_fin_os/logic/transaction_model.dart';

// ---------------------------------------------------------------------------
// Achievement definitions — pure data
// ---------------------------------------------------------------------------

enum AchievementTier { foundation, discipline, mastery, legend }

class Achievement {
  final String id;
  final String name;
  final String label;
  final String description;
  final AchievementTier tier;

  const Achievement({
    required this.id,
    required this.name,
    required this.label,
    required this.description,
    required this.tier,
  });
}

const List<Achievement> kAchievements = [
  // ── Tier 1: Foundation ──────────────────────────────────────────────────
  Achievement(
    id: 'F01',
    name: 'First Steps',
    label: 'You know where your money lives',
    description: 'Added your first account. Financial clarity starts with knowing what you have.',
    tier: AchievementTier.foundation,
  ),
  Achievement(
    id: 'F02',
    name: 'Money Map',
    label: 'Full financial picture',
    description: 'Connected 3 or more account types. You can now see your complete financial landscape.',
    tier: AchievementTier.foundation,
  ),
  Achievement(
    id: 'F03',
    name: 'Budget Setter',
    label: 'Spending with intention',
    description: 'Created your first budget. Setting limits is the first step to spending less.',
    tier: AchievementTier.foundation,
  ),
  Achievement(
    id: 'F04',
    name: 'Goal Seeker',
    label: 'You know what you\'re working toward',
    description: 'Created your first financial goal. People with written goals save 2.4× more.',
    tier: AchievementTier.foundation,
  ),
  Achievement(
    id: 'F05',
    name: 'Transaction Logger',
    label: 'Building the habit',
    description: 'Logged 10 transactions. The habit of tracking is the foundation of financial discipline.',
    tier: AchievementTier.foundation,
  ),
  Achievement(
    id: 'F06',
    name: 'Portfolio Starter',
    label: 'Your money is working',
    description: 'Added your first investment. Every investor starts with a single entry.',
    tier: AchievementTier.foundation,
  ),
  Achievement(
    id: 'F07',
    name: 'Safety Net',
    label: 'Emergency fund created',
    description: 'Created an Emergency Fund goal. The safety net that protects every other goal.',
    tier: AchievementTier.foundation,
  ),

  // ── Tier 2: Discipline ──────────────────────────────────────────────────
  Achievement(
    id: 'D01',
    name: 'Budget Guardian',
    label: 'Every rupee had a plan',
    description: 'Completed a full calendar month under budget. That\'s control, not luck.',
    tier: AchievementTier.discipline,
  ),
  Achievement(
    id: 'D02',
    name: 'Saver',
    label: 'Top-tier savings rate',
    description: 'Saved 20% or more of your income in a single month. Industry benchmark: most people save less than 10%.',
    tier: AchievementTier.discipline,
  ),
  Achievement(
    id: 'D03',
    name: 'Debt Fighter',
    label: 'Reducing what you owe',
    description: 'No new credit card debt added in 30 days. Spending within means is harder than it sounds.',
    tier: AchievementTier.discipline,
  ),
  Achievement(
    id: 'D04',
    name: 'Goal Sprint',
    label: 'Consistency compounds',
    description: 'Contributed to a goal 4 weeks in a row. Small consistent actions beat occasional large ones.',
    tier: AchievementTier.discipline,
  ),
  Achievement(
    id: 'D05',
    name: 'Emergency Ready',
    label: 'Covered for 3 months',
    description: 'Your Emergency Fund covers 3× monthly expenses. You\'re protected against most short-term shocks.',
    tier: AchievementTier.discipline,
  ),

  // ── Tier 3: Mastery ─────────────────────────────────────────────────────
  Achievement(
    id: 'M01',
    name: 'Six-Month Shield',
    label: 'Industry-standard safety net',
    description: 'Emergency Fund covers 6× monthly expenses. Financial advisors call this the gold standard.',
    tier: AchievementTier.mastery,
  ),
  Achievement(
    id: 'M02',
    name: 'Diversified',
    label: 'Multi-asset portfolio',
    description: 'Holding 4 or more investment types simultaneously. Diversification is the only free lunch in investing.',
    tier: AchievementTier.mastery,
  ),
  Achievement(
    id: 'M03',
    name: 'Grade A',
    label: 'Top financial health tier',
    description: 'Financial Health Score reached 80+. You\'re in the Excellent tier across all four dimensions.',
    tier: AchievementTier.mastery,
  ),
  Achievement(
    id: 'M04',
    name: 'Consistent Saver',
    label: '12-week savings streak',
    description: 'Saved 10%+ of income for 12 weeks in a row. Consistency is the compounding engine.',
    tier: AchievementTier.mastery,
  ),
  Achievement(
    id: 'M05',
    name: 'Net Worth Builder',
    label: 'Growing month after month',
    description: 'Net worth grew for 6 consecutive months. The direction of travel matters more than the amount.',
    tier: AchievementTier.mastery,
  ),
  Achievement(
    id: 'M06',
    name: 'Full Stack',
    label: 'Everything tracked',
    description: 'Added at least one entry in all major sections. Your financial picture is now complete.',
    tier: AchievementTier.mastery,
  ),

  // ── Tier 4: Legend ───────────────────────────────────────────────────────
  Achievement(
    id: 'L01',
    name: 'Perfect Month',
    label: 'Zero compromises',
    description: 'All budgets under, savings above 20%, and no new debt — in a single calendar month. Exceptional.',
    tier: AchievementTier.legend,
  ),
  Achievement(
    id: 'L02',
    name: 'Score Champion',
    label: 'Health Score hit 100',
    description: 'Financial Health Score reached the perfect 100. Every metric firing at maximum.',
    tier: AchievementTier.legend,
  ),
  Achievement(
    id: 'L03',
    name: 'Budget Guardian Legend',
    label: '26-week streak',
    description: 'Budget Guardian streak reached 26 consecutive weeks — six full months under budget.',
    tier: AchievementTier.legend,
  ),
];

// ---------------------------------------------------------------------------
// EngagementService — all gamification state, stored in SharedPreferences
// ---------------------------------------------------------------------------

class EngagementService with ChangeNotifier {
  SharedPreferences? _prefs;
  bool _initialized = false;

  // Streaks
  int _budgetStreakCount = 0;
  int _savingsStreakCount = 0;
  int _netWorthStreakCount = 0;

  // Achievements
  final Set<String> _unlockedAchievements = {};

  // Pending achievement to show (consumed once)
  final List<String> _pendingAchievementIds = [];

  // Onboarding
  bool _onboardingDismissed = false;
  final Set<String> _onboardingStepsDone = {};

  // Monthly digest
  String? _digestShownMonth;

  // Discovery nudges already shown
  final Set<String> _nudgesShown = {};

  // Keys
  static const _budgetStreakCountKey = 'streak_budget_count';
  static const _budgetStreakLastWeekKey = 'streak_budget_last_week';
  static const _savingsStreakCountKey = 'streak_savings_count';
  static const _savingsStreakLastWeekKey = 'streak_savings_last_week';
  static const _nwStreakCountKey = 'streak_nw_count';
  static const _nwStreakLastMonthKey = 'streak_nw_last_month';
  static const _achievementsKey = 'ach_unlocked_v1';
  static const _onboardingDismissedKey = 'onboard_dismissed';
  static const _onboardingStepsKey = 'onboard_steps_v1';
  static const _digestShownMonthKey = 'digest_shown_month';
  static const _nudgesShownKey = 'nudges_shown_v1';

  // ── Getters ────────────────────────────────────────────────────────────────

  bool get initialized => _initialized;
  int get budgetStreakCount => _budgetStreakCount;
  int get savingsStreakCount => _savingsStreakCount;
  int get netWorthStreakCount => _netWorthStreakCount;
  Set<String> get unlockedAchievements => Set.unmodifiable(_unlockedAchievements);
  bool get onboardingDismissed => _onboardingDismissed;
  Set<String> get onboardingStepsDone => Set.unmodifiable(_onboardingStepsDone);
  bool isAchievementUnlocked(String id) => _unlockedAchievements.contains(id);
  bool isOnboardingStepDone(String step) => _onboardingStepsDone.contains(step);
  bool isNudgeShown(String nudgeId) => _nudgesShown.contains(nudgeId);
  List<String> consumePendingAchievements() {
    final list = List<String>.from(_pendingAchievementIds);
    _pendingAchievementIds.clear();
    return list;
  }

  bool get isOnboardingVisible {
    if (_onboardingDismissed) return false;
    const allSteps = {'account', 'transaction', 'income', 'budget', 'goal'};
    return !_onboardingStepsDone.containsAll(allSteps);
  }

  int get onboardingStepCount => _onboardingStepsDone.length.clamp(0, 5);

  bool get shouldShowDigest {
    final now = DateTime.now();
    if (now.day > 5) return false; // only first 5 days of month
    final currentMonth = '${now.year}_${now.month.toString().padLeft(2, '0')}';
    return _digestShownMonth != currentMonth;
  }

  // ── Initialize ─────────────────────────────────────────────────────────────

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();

    _budgetStreakCount = _prefs!.getInt(_budgetStreakCountKey) ?? 0;
    _savingsStreakCount = _prefs!.getInt(_savingsStreakCountKey) ?? 0;
    _netWorthStreakCount = _prefs!.getInt(_nwStreakCountKey) ?? 0;

    final achieved = _prefs!.getStringList(_achievementsKey) ?? [];
    _unlockedAchievements.addAll(achieved);

    _onboardingDismissed = _prefs!.getBool(_onboardingDismissedKey) ?? false;
    final steps = _prefs!.getStringList(_onboardingStepsKey) ?? [];
    _onboardingStepsDone.addAll(steps);

    _digestShownMonth = _prefs!.getString(_digestShownMonthKey);

    final nudges = _prefs!.getStringList(_nudgesShownKey) ?? [];
    _nudgesShown.addAll(nudges);

    _initialized = true;
    notifyListeners();
  }

  // ── Health score snapshots ─────────────────────────────────────────────────

  String _hsKey(int year, int week) =>
      'hs_snap_${year}_W${week.toString().padLeft(2, '0')}';

  Future<void> saveHealthSnapshot(int score) async {
    if (_prefs == null) return;
    final now = DateTime.now();
    final week = _isoWeek(now);
    await _prefs!.setInt(_hsKey(now.year, week), score);
  }

  /// Returns 8 weekly scores newest-first; null = no data for that week
  List<int?> getHealthHistory() {
    if (_prefs == null) return List.filled(8, null);
    final results = <int?>[];
    for (int i = 7; i >= 0; i--) {
      final date = DateTime.now().subtract(Duration(days: i * 7));
      results.add(_prefs!.getInt(_hsKey(date.year, _isoWeek(date))));
    }
    return results;
  }

  int? getPrevWeekScore() {
    if (_prefs == null) return null;
    final prev = DateTime.now().subtract(const Duration(days: 7));
    return _prefs!.getInt(_hsKey(prev.year, _isoWeek(prev)));
  }

  // ── Streaks ────────────────────────────────────────────────────────────────

  Future<void> evaluateBudgetStreak(List<Budget> budgets) async {
    if (_prefs == null) return;
    final now = DateTime.now();
    final weekKey = '${now.year}_W${_isoWeek(now).toString().padLeft(2, '0')}';
    if (_prefs!.getString(_budgetStreakLastWeekKey) == weekKey) return;

    final active = budgets.where((b) => b.isActive).toList();
    if (active.isEmpty) return; // no budgets yet → don't penalize

    final allOnTrack = active.every((b) => b.status != BudgetStatus.exceeded);
    _budgetStreakCount = allOnTrack ? _budgetStreakCount + 1 : 0;

    await _prefs!.setInt(_budgetStreakCountKey, _budgetStreakCount);
    await _prefs!.setString(_budgetStreakLastWeekKey, weekKey);
    notifyListeners();
  }

  Future<void> evaluateSavingsStreak(
      List<Transaction> transactions) async {
    if (_prefs == null) return;
    final now = DateTime.now();
    final weekKey = '${now.year}_W${_isoWeek(now).toString().padLeft(2, '0')}';
    if (_prefs!.getString(_savingsStreakLastWeekKey) == weekKey) return;

    final weekAgo = now.subtract(const Duration(days: 7));
    double income = 0, expenses = 0;
    for (final tx in transactions) {
      if (tx.dateTime.isBefore(weekAgo)) continue;
      if (tx.type == TransactionType.income ||
          tx.type == TransactionType.cashback) {
        income += tx.amount;
      } else if (tx.type == TransactionType.expense) {
        expenses += tx.amount;
      }
    }

    if (income <= 0) return; // no income logged → skip
    final rate = (income - expenses) / income * 100;
    _savingsStreakCount = rate >= 10.0 ? _savingsStreakCount + 1 : 0;

    await _prefs!.setInt(_savingsStreakCountKey, _savingsStreakCount);
    await _prefs!.setString(_savingsStreakLastWeekKey, weekKey);
    notifyListeners();
  }

  Future<void> evaluateNetWorthStreak({
    required double currentNetWorth,
    required double prevMonthNetWorth,
  }) async {
    if (_prefs == null) return;
    final now = DateTime.now();
    final monthKey = '${now.year}_${now.month.toString().padLeft(2, '0')}';
    if (_prefs!.getString(_nwStreakLastMonthKey) == monthKey) return;

    _netWorthStreakCount = currentNetWorth > prevMonthNetWorth
        ? _netWorthStreakCount + 1
        : 0;

    await _prefs!.setInt(_nwStreakCountKey, _netWorthStreakCount);
    await _prefs!.setString(_nwStreakLastMonthKey, monthKey);
    notifyListeners();
  }

  // ── Achievement checking ───────────────────────────────────────────────────

  Future<void> checkAchievements({
    required List<Transaction> transactions,
    required List<Account> accounts,
    required List<Budget> budgets,
    required List<Goal> goals,
    required List<Investment> investments,
    required int healthScore,
  }) async {
    if (_prefs == null) return;

    // F01 — first account
    if (accounts.isNotEmpty) await _unlock('F01');

    // F02 — 3+ account types
    final accountTypes = accounts.map((a) => a.type).toSet();
    if (accountTypes.length >= 3) await _unlock('F02');

    // F03 — first budget
    if (budgets.isNotEmpty) await _unlock('F03');

    // F04 — first goal
    if (goals.isNotEmpty) await _unlock('F04');

    // F05 — 10 transactions
    if (transactions.length >= 10) await _unlock('F05');

    // F06 — first investment
    if (investments.isNotEmpty) await _unlock('F06');

    // F07 — emergency fund goal exists
    if (goals.any((g) => g.type == GoalType.emergency)) await _unlock('F07');

    // D01 — full month under budget (all active budgets not exceeded for current month)
    if (budgets.isNotEmpty &&
        budgets.where((b) => b.isActive).isNotEmpty &&
        budgets.where((b) => b.isActive).every((b) => b.status != BudgetStatus.exceeded)) {
      final now = DateTime.now();
      if (now.day >= 28) await _unlock('D01'); // only award at end of month
    }

    // D02 — 20%+ savings rate this month
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    double mIncome = 0, mExpenses = 0;
    for (final tx in transactions) {
      if (tx.dateTime.isBefore(monthStart)) continue;
      if (tx.type == TransactionType.income || tx.type == TransactionType.cashback) {
        mIncome += tx.amount;
      } else if (tx.type == TransactionType.expense) {
        mExpenses += tx.amount;
      }
    }
    if (mIncome > 0) {
      final rate = (mIncome - mExpenses) / mIncome * 100;
      if (rate >= 20.0) await _unlock('D02');
    }

    // D03 — no new credit card spending in 30 days
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));
    final hasNewCreditSpend = transactions.any((tx) =>
        tx.dateTime.isAfter(thirtyDaysAgo) &&
        tx.type == TransactionType.expense &&
        (tx.metadata?['accountType'] == 'credit' ||
            tx.metadata?['paymentMethod'] == 'credit'));
    if (!hasNewCreditSpend && transactions.any((tx) => tx.dateTime.isAfter(thirtyDaysAgo))) {
      await _unlock('D03');
    }

    // D04 — goal contribution streak of 4 weeks
    final completedGoals = goals.where((g) => g.isCompleted).toList();
    if (completedGoals.isNotEmpty || goals.any((g) => g.currentAmount > 0)) {
      // Check if contributions span at least 4 distinct weeks
      final allContributions = goals
          .expand((g) => g.contributions)
          .map((c) => c.date)
          .toList()
        ..sort();
      if (allContributions.length >= 4) {
        final weeks = allContributions
            .map((d) => '${d.year}_${_isoWeek(d)}')
            .toSet();
        if (weeks.length >= 4) await _unlock('D04');
      }
    }

    // D05 — Emergency Fund covers 3× monthly expenses
    final emergencyGoal = goals.where((g) => g.type == GoalType.emergency).firstOrNull;
    if (emergencyGoal != null && mExpenses > 0) {
      if (emergencyGoal.currentAmount >= mExpenses * 3) await _unlock('D05');
    }

    // M01 — Emergency Fund covers 6× monthly expenses
    if (emergencyGoal != null && mExpenses > 0) {
      if (emergencyGoal.currentAmount >= mExpenses * 6) await _unlock('M01');
    }

    // M02 — 4+ investment types
    final activeInvestments =
        investments.where((i) => i.metadata?['isWithdrawn'] != true).toList();
    if (activeInvestments.map((i) => i.type).toSet().length >= 4) {
      await _unlock('M02');
    }

    // M03 — Health score ≥ 80
    if (healthScore >= 80) await _unlock('M03');

    // M04 — savings streak ≥ 12 weeks
    if (_savingsStreakCount >= 12) await _unlock('M04');

    // M05 — net worth streak ≥ 6 months
    if (_netWorthStreakCount >= 6) await _unlock('M05');

    // M06 — full stack: accounts, budgets, goals, investments all have entries
    if (accounts.isNotEmpty &&
        budgets.isNotEmpty &&
        goals.isNotEmpty &&
        investments.isNotEmpty) {
      await _unlock('M06');
    }

    // L01 — perfect month: all budgets under + savings ≥ 20% + no new credit debt
    if (mIncome > 0) {
      final l01Rate = (mIncome - mExpenses) / mIncome * 100;
      if (l01Rate >= 20.0 &&
          budgets.where((b) => b.isActive).isNotEmpty &&
          budgets.where((b) => b.isActive).every((b) => b.status != BudgetStatus.exceeded) &&
          !hasNewCreditSpend) {
        await _unlock('L01');
      }
    }

    // L02 — perfect health score
    if (healthScore >= 100) await _unlock('L02');

    // L03 — budget streak ≥ 26
    if (_budgetStreakCount >= 26) await _unlock('L03');
  }

  Future<void> _unlock(String id) async {
    if (_unlockedAchievements.contains(id) || _prefs == null) return;
    _unlockedAchievements.add(id);
    await _prefs!.setStringList(_achievementsKey, _unlockedAchievements.toList());
    await _prefs!.setString(
        'ach_date_$id', DateTime.now().toIso8601String());
    _pendingAchievementIds.add(id);
    notifyListeners();
  }

  DateTime? getAchievementDate(String id) {
    if (_prefs == null) return null;
    final raw = _prefs!.getString('ach_date_$id');
    return raw != null ? DateTime.tryParse(raw) : null;
  }

  // ── Onboarding ─────────────────────────────────────────────────────────────

  Future<void> markOnboardingStep(String step) async {
    if (_prefs == null || _onboardingStepsDone.contains(step)) return;
    _onboardingStepsDone.add(step);
    await _prefs!.setStringList(_onboardingStepsKey, _onboardingStepsDone.toList());
    notifyListeners();
  }

  Future<void> dismissOnboarding() async {
    if (_prefs == null) return;
    _onboardingDismissed = true;
    await _prefs!.setBool(_onboardingDismissedKey, true);
    notifyListeners();
  }

  // ── Monthly Digest ─────────────────────────────────────────────────────────

  Future<void> markDigestShown() async {
    if (_prefs == null) return;
    final now = DateTime.now();
    _digestShownMonth =
        '${now.year}_${now.month.toString().padLeft(2, '0')}';
    await _prefs!.setString(_digestShownMonthKey, _digestShownMonth!);
    notifyListeners();
  }

  // ── Discovery nudges ───────────────────────────────────────────────────────

  Future<void> markNudgeShown(String nudgeId) async {
    if (_prefs == null || _nudgesShown.contains(nudgeId)) return;
    _nudgesShown.add(nudgeId);
    await _prefs!.setStringList(_nudgesShownKey, _nudgesShown.toList());
    notifyListeners();
  }

  // ── ISO week helper ────────────────────────────────────────────────────────

  int _isoWeek(DateTime date) {
    final jan4 = DateTime(date.year, 1, 4);
    final startOfW1 = jan4.subtract(Duration(days: jan4.weekday - 1));
    final diff = date.difference(startOfW1).inDays;
    if (diff < 0) return _isoWeek(DateTime(date.year - 1, 12, 28));
    return (diff ~/ 7) + 1;
  }
}
