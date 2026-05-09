import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:vittara_fin_os/logic/accounts_controller.dart';
import 'package:vittara_fin_os/logic/ai/voice_controller.dart';
import 'package:vittara_fin_os/logic/ai/voice_fill_engine.dart';
import 'package:vittara_fin_os/logic/ai/voice_navigator.dart';
import 'package:vittara_fin_os/logic/budgets_controller.dart';
import 'package:vittara_fin_os/logic/goals_controller.dart';
import 'package:vittara_fin_os/logic/investments_controller.dart';
import 'package:vittara_fin_os/logic/lending_borrowing_controller.dart';
import 'package:vittara_fin_os/logic/settings_controller.dart';
import 'package:vittara_fin_os/logic/transaction_model.dart';
import 'package:vittara_fin_os/logic/transactions_controller.dart';
import 'package:vittara_fin_os/services/monthly_statement_service.dart';
import 'package:vittara_fin_os/services/sms_auto_scan_service.dart';
import 'package:vittara_fin_os/ui/dashboard/quick_entry_sheet.dart';
import 'package:vittara_fin_os/ui/dashboard/transaction_wizard.dart';
import 'package:vittara_fin_os/ui/financial_calendar_screen.dart';
import 'package:vittara_fin_os/ui/manage/accounts_screen.dart';
import 'package:vittara_fin_os/ui/manage/budgets/budgets_screen.dart';
import 'package:vittara_fin_os/ui/manage/goals/goals_screen.dart';
import 'package:vittara_fin_os/ui/manage/investments_screen.dart';
import 'package:vittara_fin_os/ui/manage/lending_borrowing_screen.dart';
import 'package:vittara_fin_os/ui/manage/reports_analysis_screen.dart';
import 'package:vittara_fin_os/ui/manage_screen.dart';
import 'package:vittara_fin_os/ui/net_worth_page.dart';
import 'package:vittara_fin_os/ui/notifications_page.dart';
import 'package:vittara_fin_os/ui/settings/csv_import_screen.dart';
import 'package:vittara_fin_os/ui/settings_screen.dart';
import 'package:vittara_fin_os/ui/spending_insights_screen.dart';
import 'package:vittara_fin_os/ui/transaction_history_screen.dart';
import 'package:vittara_fin_os/ui/voice/voice_overlay_widget.dart';
import 'package:vittara_fin_os/ui/widgets/animations.dart';
import 'package:vittara_fin_os/ui/widgets/monthly_statement_sheet.dart';
import 'package:vittara_fin_os/ui/widgets/toast_notification.dart';

class AIVoiceCommandService {
  AIVoiceCommandService._();

  static const MethodChannel _channel =
      MethodChannel('com.vittara.finos/ai_button');
  static final FlutterTts _tts = FlutterTts();
  static bool _registered = false;
  static bool _opening = false;

  static void registerHardwareButton(BuildContext context) {
    if (_registered) return;
    _registered = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'volumeDownDoublePress') return;
      final navContext = appNavigatorKey.currentContext ?? context;
      if (!navContext.mounted) return;
      await openAssistant(navContext, source: 'volume', autoStart: true);
    });
  }

  static Future<void> openAssistant(
    BuildContext context, {
    String source = 'manual',
    bool autoStart = false,
  }) async {
    if (_opening) return;
    if (context.read<SettingsController>().isLocked) return;

    _opening = true;
    try {
      HapticFeedback.mediumImpact();
      final result = await VoiceOverlayWidget.show(
        context,
        showConfirmation: false,
        autoStart: autoStart,
      );
      if (result == null || !context.mounted) return;
      await handleResult(context, result);
    } finally {
      _opening = false;
    }
  }

  static Future<bool> handleResult(
    BuildContext context,
    VoiceResult result,
  ) async {
    final command = result.fields['aiCommand'] as String?;

    if (command != null) {
      return _handleSystemCommand(context, command, result);
    }

    switch (result.intent) {
      case VoiceIntent.addExpense:
      case VoiceIntent.addIncome:
        _openQuickEntryFromVoice(context, result);
        return true;
      case VoiceIntent.addTransfer:
        toast.showWarning(
          'Voice transfer entry is not supported in Quick Entry yet',
        );
        return true;
      case VoiceIntent.addInvestment:
        toast.showWarning(
          'Voice investment entry is not supported in Quick Entry yet',
        );
        return true;
      case VoiceIntent.navigate:
        final target = result.fields['navTarget'] ?? result.fields['target'];
        if (target is NavTarget) {
          _openTarget(context, target);
          return true;
        }
        return false;
      case VoiceIntent.setBudget:
        Navigator.of(context).push(
          FadeScalePageRoute(page: const BudgetsScreen()),
        );
        return true;
      case VoiceIntent.setGoal:
        Navigator.of(context).push(
          FadeScalePageRoute(page: const GoalsScreen()),
        );
        return true;
      case VoiceIntent.query:
      case VoiceIntent.queryBalance:
      case VoiceIntent.queryGoal:
        await _speakAndToast(context, _buildSummary(context, DateTime.now()));
        return true;
      case VoiceIntent.unknown:
        toast.showInfo(
            'Try: "open investments", "add 500 food", or "today summary".');
        return false;
    }
  }

  static Future<bool> _handleSystemCommand(
    BuildContext context,
    String command,
    VoiceResult result,
  ) async {
    switch (command) {
      case 'themeLight':
        await context.read<SettingsController>().setThemeMode(ThemeMode.light);
        await _speakAndToast(context, 'Light mode is on.');
        return true;
      case 'themeDark':
        await context.read<SettingsController>().setThemeMode(ThemeMode.dark);
        await _speakAndToast(context, 'Dark mode is on.');
        return true;
      case 'themeSystem':
        await context.read<SettingsController>().setThemeMode(ThemeMode.system);
        await _speakAndToast(context, 'Theme is set to system mode.');
        return true;
      case 'summaryToday':
        await _speakAndToast(context, _buildSummary(context, DateTime.now()));
        return true;
      case 'summaryMonth':
        await _speakAndToast(context, _buildMonthSummary(context));
        return true;
      case 'monthlyStatement':
        await _openOrGenerateMonthlyStatement(context, result);
        return true;
      case 'importStatement':
        Navigator.of(context).push(
          FadeScalePageRoute(page: const CsvImportScreen()),
        );
        return true;
      case 'reports':
        Navigator.of(context).push(
          FadeScalePageRoute(page: const ReportsAnalysisScreen()),
        );
        return true;
      default:
        return false;
    }
  }

  static void _openQuickEntryFromVoice(
      BuildContext context, VoiceResult result) {
    final branch = result.intent == VoiceIntent.addIncome
        ? TransactionWizardBranch.income
        : TransactionWizardBranch.expense;
    final amount = _asDouble(result.fields['amount']);
    final merchant = result.fields['merchant'] as String?;
    final category = result.fields['category'] as String?;
    final account = result.fields['account'] as String?;
    final date = result.fields['date'] is DateTime
        ? result.fields['date'] as DateTime
        : DateTime.now();

    showQuickEntrySheet(
      context,
      branch: branch,
      initialAmount: amount,
      initialMerchant: merchant,
      initialDescription: merchant ?? result.confirmationText,
      initialDate: date,
      initialAccountId: account,
      initialCategoryName: category,
    );
  }

  static void _openTarget(BuildContext context, NavTarget target) {
    final nav = appNavigatorKey.currentState ?? Navigator.of(context);
    switch (target) {
      case NavTarget.dashboard:
        nav.popUntil((route) => route.isFirst);
        return;
      case NavTarget.investments:
        nav.push(FadeScalePageRoute(page: const InvestmentsScreen()));
        return;
      case NavTarget.goals:
        nav.push(FadeScalePageRoute(page: const GoalsScreen()));
        return;
      case NavTarget.budgets:
        nav.push(FadeScalePageRoute(page: const BudgetsScreen()));
        return;
      case NavTarget.netWorth:
        nav.push(FadeScalePageRoute(page: const NetWorthPage()));
        return;
      case NavTarget.accounts:
        nav.push(FadeScalePageRoute(page: const AccountsScreen()));
        return;
      case NavTarget.settings:
        nav.push(FadeScalePageRoute(page: const SettingsScreen()));
        return;
      case NavTarget.notifications:
        nav.push(FadeScalePageRoute(page: const NotificationsPage()));
        return;
      case NavTarget.lending:
        nav.push(FadeScalePageRoute(page: const LendingBorrowingScreen()));
        return;
      case NavTarget.archive:
        nav.push(FadeScalePageRoute(page: const ManageScreen()));
        return;
      case NavTarget.calendar:
        nav.push(FadeScalePageRoute(page: const FinancialCalendarScreen()));
        return;
      case NavTarget.transactions:
        nav.push(FadeScalePageRoute(page: const TransactionHistoryScreen()));
        return;
      case NavTarget.insights:
        nav.push(FadeScalePageRoute(page: const SpendingInsightsScreen()));
        return;
    }
  }

  static Future<void> _openOrGenerateMonthlyStatement(
    BuildContext context,
    VoiceResult result,
  ) async {
    final raw = (result.fields['rawText'] as String? ?? '').toLowerCase();
    final month = _parseMonth(raw);
    final year = _parseYear(raw) ?? DateTime.now().year;
    if (month == null) {
      showMonthlyStatementSheet(context);
      await _speak('Choose the statement month.');
      return;
    }

    try {
      Uint8List? iconBytes;
      try {
        final data = await rootBundle.load('assets/app_icon.png');
        iconBytes = data.buffer.asUint8List();
      } catch (_) {}

      final file = await MonthlyStatementService.build(
        year: year,
        month: month,
        allTransactions: context.read<TransactionsController>().transactions,
        accounts: context.read<AccountsController>().accounts,
        investments: context.read<InvestmentsController>().investments,
        lendingRecords: context.read<LendingBorrowingController>().records,
        appIconBytes: iconBytes,
        goals: context.read<GoalsController>().goals,
        budgets: context.read<BudgetsController>().budgets,
      );
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'VittaraFinOS Monthly Statement - ${_monthLabel(year, month)}',
      );
      await _speakAndToast(
          context, '${_monthLabel(year, month)} statement is ready.');
    } catch (e) {
      toast.showError('Could not generate statement');
    }
  }

  static String _buildSummary(BuildContext context, DateTime day) {
    final txs = context.read<TransactionsController>().transactions.where((tx) {
      return tx.dateTime.year == day.year &&
          tx.dateTime.month == day.month &&
          tx.dateTime.day == day.day;
    }).toList();
    final income = _sum(txs, TransactionType.income);
    final expense = _sum(txs, TransactionType.expense);
    final net = income - expense;
    final count = txs.length;
    return 'Today you have $count transaction${count == 1 ? '' : 's'}. '
        'Income is ₹${income.toStringAsFixed(0)}, expenses are ₹${expense.toStringAsFixed(0)}, '
        'and net cash flow is ₹${net.toStringAsFixed(0)}.';
  }

  static String _buildMonthSummary(BuildContext context) {
    final now = DateTime.now();
    final txs = context.read<TransactionsController>().transactions.where((tx) {
      return tx.dateTime.year == now.year && tx.dateTime.month == now.month;
    }).toList();
    final income = _sum(txs, TransactionType.income);
    final expense = _sum(txs, TransactionType.expense);
    final net = income - expense;
    return 'This month income is ₹${income.toStringAsFixed(0)}, expenses are ₹${expense.toStringAsFixed(0)}, '
        'and net cash flow is ₹${net.toStringAsFixed(0)}.';
  }

  static double _sum(List<Transaction> txs, TransactionType type) {
    return txs
        .where((tx) => tx.type == type)
        .fold<double>(0, (sum, tx) => sum + tx.amount.abs());
  }

  static Future<void> _speakAndToast(BuildContext context, String text) async {
    toast.showInfo(text);
    await _speak(text);
  }

  static Future<void> _speak(String text) async {
    await _tts.setLanguage('en-IN');
    await _tts.setSpeechRate(0.45);
    await _tts.speak(text);
  }

  static double? _asDouble(dynamic raw) {
    if (raw is num) return raw.toDouble();
    if (raw is String) return double.tryParse(raw);
    return null;
  }

  static int? _parseMonth(String raw) {
    const months = {
      'january': 1,
      'jan': 1,
      'february': 2,
      'feb': 2,
      'march': 3,
      'mar': 3,
      'april': 4,
      'apr': 4,
      'may': 5,
      'june': 6,
      'jun': 6,
      'july': 7,
      'jul': 7,
      'august': 8,
      'aug': 8,
      'september': 9,
      'sep': 9,
      'october': 10,
      'oct': 10,
      'november': 11,
      'nov': 11,
      'december': 12,
      'dec': 12,
    };
    for (final entry in months.entries) {
      if (raw.contains(entry.key)) return entry.value;
    }
    return null;
  }

  static int? _parseYear(String raw) {
    final match = RegExp(r'\b(20\d{2})\b').firstMatch(raw);
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  static String _monthLabel(int year, int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[month - 1]} $year';
  }
}
