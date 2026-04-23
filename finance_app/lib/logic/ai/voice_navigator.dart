/// Maps voice commands to app navigation targets.
/// Supports English, Hindi, and Hinglish navigation phrases.
enum NavTarget {
  dashboard,
  investments,
  goals,
  budgets,
  netWorth,
  accounts,
  settings,
  notifications,
  lending,
  archive,
  calendar,
  transactions,
  insights,
}

extension NavTargetLabel on NavTarget {
  String get label {
    switch (this) {
      case NavTarget.dashboard: return 'Dashboard';
      case NavTarget.investments: return 'Investments';
      case NavTarget.goals: return 'Goals';
      case NavTarget.budgets: return 'Budgets';
      case NavTarget.netWorth: return 'Net Worth';
      case NavTarget.accounts: return 'Accounts';
      case NavTarget.settings: return 'Settings';
      case NavTarget.notifications: return 'Notifications';
      case NavTarget.lending: return 'Lending & Borrowing';
      case NavTarget.archive: return 'Transaction Archive';
      case NavTarget.calendar: return 'Financial Calendar';
      case NavTarget.transactions: return 'Transactions';
      case NavTarget.insights: return 'Spending Insights';
    }
  }

  String get routeHint {
    switch (this) {
      case NavTarget.dashboard: return '/dashboard';
      case NavTarget.investments: return '/investments';
      case NavTarget.goals: return '/goals';
      case NavTarget.budgets: return '/budgets';
      case NavTarget.netWorth: return '/networth';
      case NavTarget.accounts: return '/accounts';
      case NavTarget.settings: return '/settings';
      case NavTarget.notifications: return '/notifications';
      case NavTarget.lending: return '/lending';
      case NavTarget.archive: return '/archive';
      case NavTarget.calendar: return '/calendar';
      case NavTarget.transactions: return '/transactions';
      case NavTarget.insights: return '/insights';
    }
  }
}

class VoiceNavigator {
  VoiceNavigator._();

  static const Map<NavTarget, List<String>> _map = {
    NavTarget.dashboard: [
      // English
      'home', 'dashboard', 'main screen', 'go back', 'go home', 'main page',
      // Hindi
      'ghar', 'ghar chalo', 'main', 'mukhya', 'shuruat',
      // Hinglish
      'home pe jao', 'home dikhao', 'dashboard dikhao',
    ],
    NavTarget.investments: [
      // English
      'invest', 'investments', 'stock', 'stocks', 'portfolio', 'shares',
      'mutual fund', 'sip', 'fd', 'fixed deposit', 'nps',
      // Hindi
      'nivesh', 'nivesh dikhao', 'mera portfolio', 'share baazar',
      // Hinglish
      'investment page', 'investment dikhao',
    ],
    NavTarget.goals: [
      // English
      'goal', 'goals', 'saving for', 'savings goal', 'target',
      // Hindi
      'lakshya', 'lakshya dikhao', 'mera lakshya', 'saving ka goal',
      // Hinglish
      'goals dikhao',
    ],
    NavTarget.budgets: [
      // English
      'budget', 'budgets', 'spending limit', 'my budgets',
      // Hindi
      'bhatat', 'budget dikhao', 'mera budget',
      // Hinglish
      'budget page',
    ],
    NavTarget.netWorth: [
      // English
      'net worth', 'total wealth', 'wealth', 'total assets', 'score',
      'scorecard', 'financial health',
      // Hindi
      'kul sampatti', 'kul daulat', 'net worth dikhao',
      // Hinglish
      'net worth page',
    ],
    NavTarget.accounts: [
      // English
      'account', 'accounts', 'wallet', 'bank', 'my accounts', 'balances',
      // Hindi
      'khata', 'khate', 'mera khata', 'bank account', 'paisa kahaan hai',
      // Hinglish
      'accounts dikhao', 'mere accounts',
    ],
    NavTarget.settings: [
      // English
      'setting', 'settings', 'preference', 'preferences', 'configure',
      'change pin', 'security', 'backup',
      // Hindi
      'settings dikhao', 'badlav', 'setting karo',
      // Hinglish
      'settings page',
    ],
    NavTarget.notifications: [
      // English
      'notification', 'notifications', 'alert', 'alerts', 'reminder',
      // Hindi
      'suchna', 'soochna', 'notifications dikhao',
      // Hinglish
      'notifications page',
    ],
    NavTarget.lending: [
      // English
      'lend', 'lending', 'borrow', 'borrowing', 'owed', 'loan', 'loans',
      'who owes me', 'i owe',
      // Hindi
      'udhaar', 'udhar', 'karz', 'lena dena', 'kisne paise liye',
      // Hinglish
      'lending page', 'udhaar dikhao',
    ],
    NavTarget.archive: [
      // English
      'archive', 'archived', 'deleted', 'old transactions', 'removed',
      // Hindi
      'purana', 'purani transactions', 'archive dikhao',
      // Hinglish
      'archived transactions',
    ],
    NavTarget.calendar: [
      // English
      'calendar', 'schedule', 'upcoming', 'upcoming bills', 'financial calendar',
      // Hindi
      'panchang', 'aane wale kharche', 'calendar dikhao',
      // Hinglish
      'calendar page', 'upcoming transactions',
    ],
    NavTarget.transactions: [
      // English
      'transactions', 'history', 'all transactions', 'transaction list',
      'recent transactions', 'my transactions',
      // Hindi
      'lenden', 'len den', 'transactions dikhao', 'saari transactions',
      // Hinglish
      'transaction history',
    ],
    NavTarget.insights: [
      // English
      'insight', 'insights', 'analysis', 'spending pattern', 'spending analysis',
      'report', 'reports', 'analytics',
      // Hindi
      'kharche ki jaankari', 'kharch ka hisaab', 'insights dikhao',
      // Hinglish
      'insights page', 'spending insights',
    ],
  };

  /// Resolve a voice utterance to a NavTarget.
  /// Returns null if no navigation match is found.
  static NavTarget? resolve(String utterance) {
    final lower = utterance.toLowerCase().trim();
    // Require at least 2 characters
    if (lower.length < 2) return null;

    for (final entry in _map.entries) {
      for (final keyword in entry.value) {
        if (lower.contains(keyword)) return entry.key;
      }
    }
    return null;
  }
}
