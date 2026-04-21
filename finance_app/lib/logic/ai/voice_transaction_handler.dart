import 'package:flutter/material.dart' show Color;
import 'package:flutter/cupertino.dart' show BuildContext;
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/accounts_controller.dart';
import 'package:vittara_fin_os/logic/investment_model.dart';
import 'package:vittara_fin_os/logic/investments_controller.dart';
import 'package:vittara_fin_os/logic/payment_apps_controller.dart';
import 'package:vittara_fin_os/logic/transaction_account_adjuster.dart';
import 'package:vittara_fin_os/logic/transaction_model.dart';
import 'package:vittara_fin_os/logic/transactions_controller.dart';
import 'package:vittara_fin_os/services/sms_auto_scan_service.dart';
import 'package:vittara_fin_os/ui/widgets/toast_notification.dart';
import 'package:vittara_fin_os/utils/id_generator.dart';
import 'voice_controller.dart';
import 'voice_fill_engine.dart';
import 'voice_navigator.dart';

/// Executes a confirmed [VoiceResult] against the data layer.
///
/// Usage:
///   final result = await VoiceOverlayWidget.show(context);
///   if (result != null && context.mounted) {
///     await VoiceTransactionHandler.handle(context, result);
///   }
class VoiceTransactionHandler {
  static Future<bool> handle(BuildContext context, VoiceResult result) async {
    switch (result.intent) {
      case VoiceIntent.addExpense:
        return _saveTransaction(context, result, TransactionType.expense);
      case VoiceIntent.addIncome:
        return _saveTransaction(context, result, TransactionType.income);
      case VoiceIntent.addTransfer:
        return _saveTransfer(context, result);
      case VoiceIntent.addInvestment:
        return _saveInvestment(context, result);
      case VoiceIntent.navigate:
        return _navigate(result);
      case VoiceIntent.query:
      case VoiceIntent.queryBalance:
      case VoiceIntent.queryGoal:
        // Answers are spoken by VoiceController itself; nothing to save.
        return false;
      case VoiceIntent.setBudget:
      case VoiceIntent.setGoal:
        // Future: push creation wizard pre-filled
        return false;
      case VoiceIntent.unknown:
        return false;
    }
  }

  // ── Expense / Income ──────────────────────────────────────────────────────

  static Future<bool> _saveTransaction(
      BuildContext context, VoiceResult result, TransactionType type) async {
    final amount = _amount(result);
    if (amount == null || amount <= 0) {
      ToastController().showError('Could not parse amount');
      return false;
    }

    final accounts = context.read<AccountsController>();
    final paymentApps = context.read<PaymentAppsController>();
    final txController = context.read<TransactionsController>();

    final accountId = result.fields['account'] as String?;
    final account = accountId != null ? accounts.getAccountById(accountId) : null;
    final merchant = result.fields['merchant'] as String?;
    final description =
        merchant ?? (type == TransactionType.expense ? 'Expense' : 'Income');
    final date = _date(result);

    final tx = Transaction(
      id: IdGenerator.next(),
      description: description,
      amount: amount,
      type: type,
      dateTime: date,
      sourceAccountId: account?.id,
      sourceAccountName: account?.name,
      metadata: merchant != null ? {'merchant': merchant} : null,
    );

    await txController.addTransaction(tx);
    await TransactionAccountAdjuster.applyTransaction(
        accounts, tx, paymentApps);

    final label = type == TransactionType.expense ? 'Expense' : 'Income';
    ToastController().showSuccess('$label of ₹${amount.toStringAsFixed(0)} saved');
    return true;
  }

  // ── Transfer ──────────────────────────────────────────────────────────────

  static Future<bool> _saveTransfer(
      BuildContext context, VoiceResult result) async {
    final amount = _amount(result);
    if (amount == null || amount <= 0) {
      ToastController().showError('Could not parse amount');
      return false;
    }

    final accounts = context.read<AccountsController>();
    final paymentApps = context.read<PaymentAppsController>();
    final txController = context.read<TransactionsController>();

    final fromId = result.fields['account'] as String?;
    final toId = result.fields['toAccount'] as String?;
    final from = fromId != null ? accounts.getAccountById(fromId) : null;
    final to = toId != null ? accounts.getAccountById(toId) : null;
    final date = _date(result);

    final tx = Transaction(
      id: IdGenerator.next(),
      description: 'Transfer${to != null ? ' to ${to.name}' : ''}',
      amount: amount,
      type: TransactionType.transfer,
      dateTime: date,
      sourceAccountId: from?.id,
      sourceAccountName: from?.name,
      destinationAccountId: to?.id,
      destinationAccountName: to?.name,
    );

    await txController.addTransaction(tx);
    await TransactionAccountAdjuster.applyTransaction(accounts, tx, paymentApps);

    ToastController().showSuccess('Transfer of ₹${amount.toStringAsFixed(0)} saved');
    return true;
  }

  // ── Investment ────────────────────────────────────────────────────────────

  static Future<bool> _saveInvestment(
      BuildContext context, VoiceResult result) async {
    final amount = _amount(result);
    if (amount == null || amount <= 0) {
      ToastController().showError('Could not parse amount');
      return false;
    }

    final invController = context.read<InvestmentsController>();
    final accounts = context.read<AccountsController>();
    final paymentApps = context.read<PaymentAppsController>();
    final txController = context.read<TransactionsController>();
    final date = _date(result);

    final typeStr = result.fields['investmentType'] as String? ?? 'stocks';
    final invType = _parseInvestmentType(typeStr);
    final name = result.fields['merchant'] as String? ?? _invTypeName(invType);

    final investment = Investment(
      id: IdGenerator.next(),
      name: name,
      type: invType,
      amount: amount,
      color: const Color(0xFF6C63FF),
    );
    await invController.addInvestment(investment);

    // Record a transaction for cash flow tracking
    final accountId = result.fields['account'] as String?;
    final account =
        accountId != null ? accounts.getAccountById(accountId) : null;
    final tx = Transaction(
      id: IdGenerator.next(),
      description: 'Investment: $name',
      amount: amount,
      type: TransactionType.investment,
      dateTime: date,
      sourceAccountId: account?.id,
      sourceAccountName: account?.name,
    );
    await txController.addTransaction(tx);
    await TransactionAccountAdjuster.applyTransaction(accounts, tx, paymentApps);

    ToastController().showSuccess('Investment of ₹${amount.toStringAsFixed(0)} saved');
    return true;
  }

  // ── Navigate ──────────────────────────────────────────────────────────────

  static bool _navigate(VoiceResult result) {
    final target = result.fields['navTarget'];
    if (target is! NavTarget) return false;
    appNavigatorKey.currentState?.pushNamed(target.routeHint);
    return false;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static double? _amount(VoiceResult result) {
    final raw = result.fields['amount'];
    if (raw is num) return raw.toDouble();
    if (raw is String) return double.tryParse(raw);
    return null;
  }

  static DateTime _date(VoiceResult result) {
    final raw = result.fields['date'];
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw) ?? DateTime.now();
    return DateTime.now();
  }

  static String _invTypeName(InvestmentType t) {
    switch (t) {
      case InvestmentType.mutualFund:
        return 'Mutual Fund';
      case InvestmentType.fixedDeposit:
        return 'Fixed Deposit';
      case InvestmentType.recurringDeposit:
        return 'Recurring Deposit';
      case InvestmentType.digitalGold:
        return 'Digital Gold';
      case InvestmentType.cryptocurrency:
        return 'Crypto';
      case InvestmentType.bonds:
        return 'Bonds';
      case InvestmentType.pensionSchemes:
        return 'Pension / NPS';
      default:
        return 'Stocks';
    }
  }

  static InvestmentType _parseInvestmentType(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('mutual') ||
        lower.contains('mf') ||
        lower.contains('sip')) {
      return InvestmentType.mutualFund;
    }
    if (lower.contains('fd') || lower.contains('fixed')) {
      return InvestmentType.fixedDeposit;
    }
    if (lower.contains('rd') || lower.contains('recurring')) {
      return InvestmentType.recurringDeposit;
    }
    if (lower.contains('gold')) return InvestmentType.digitalGold;
    if (lower.contains('crypto') ||
        lower.contains('bitcoin') ||
        lower.contains('btc')) {
      return InvestmentType.cryptocurrency;
    }
    if (lower.contains('bond')) return InvestmentType.bonds;
    if (lower.contains('nps') || lower.contains('pension')) {
      return InvestmentType.pensionSchemes;
    }
    return InvestmentType.stocks;
  }
}
