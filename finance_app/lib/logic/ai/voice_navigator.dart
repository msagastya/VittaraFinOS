/// Maps voice commands to app navigation targets.
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

  /// Route path for navigator (matches existing screen routing).
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
    NavTarget.dashboard: ['home', 'dashboard', 'main', 'go back', 'go home'],
    NavTarget.investments: ['invest', 'stock', 'portfolio', 'mutual fund', 'sip', 'fd'],
    NavTarget.goals: ['goal', 'saving for', 'target'],
    NavTarget.budgets: ['budget'],
    NavTarget.netWorth: ['net worth', 'total wealth', 'wealth', 'net'],
    NavTarget.accounts: ['account', 'wallet', 'bank'],
    NavTarget.settings: ['setting', 'preference', 'configure'],
    NavTarget.notifications: ['notification', 'alert', 'reminder'],
    NavTarget.lending: ['lend', 'borrow', 'owed', 'loan'],
    NavTarget.archive: ['archive', 'deleted', 'old transaction'],
    NavTarget.calendar: ['calendar', 'schedule', 'upcoming'],
    NavTarget.transactions: ['transaction', 'history', 'all transactions'],
    NavTarget.insights: ['insight', 'analysis', 'spending pattern', 'report'],
  };

  /// Resolve a voice utterance to a NavTarget.
  /// Returns null if no match found.
  static NavTarget? resolve(String utterance) {
    final lower = utterance.toLowerCase();
    for (final entry in _map.entries) {
      for (final keyword in entry.value) {
        if (lower.contains(keyword)) return entry.key;
      }
    }
    return null;
  }
}
