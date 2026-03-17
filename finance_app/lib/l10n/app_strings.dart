/// AU3-04 — Centralised strings for future i18n.
/// When the app adopts ARB/intl, replace static consts with
/// `AppLocalizations.of(context).xxx` getters.
class AppStrings {
  AppStrings._();

  // Common actions
  static const String save = 'Save';
  static const String cancel = 'Cancel';
  static const String delete = 'Delete';
  static const String edit = 'Edit';
  static const String add = 'Add';
  static const String back = 'Back';
  static const String done = 'Done';
  static const String skip = 'Skip';
  static const String confirm = 'Confirm';

  // Common messages
  static const String noDataAvailable = 'No data available';
  static const String loadingData = 'Loading...';
  static const String errorOccurred =
      'Something went wrong. Please try again.';
  static const String confirmDelete =
      'Are you sure you want to delete this?';
  static const String discardChanges = 'Discard Changes?';
  static const String discardChangesMessage =
      'Your unsaved changes will be lost.';

  // Investment types
  static const String stocks = 'Stocks';
  static const String mutualFund = 'Mutual Fund';
  static const String fixedDeposit = 'Fixed Deposit';
  static const String recurringDeposit = 'Recurring Deposit';
  static const String gold = 'Digital Gold';
  static const String crypto = 'Crypto';
  static const String bonds = 'Bonds';
  static const String nps = 'NPS';
  static const String pension = 'Pension';
  static const String commodities = 'Commodities';
  static const String fAndO = 'F&O';
}
