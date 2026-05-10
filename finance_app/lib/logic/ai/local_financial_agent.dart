import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/ai/voice_controller.dart';
import 'package:vittara_fin_os/logic/ai/voice_fill_engine.dart';
import 'package:vittara_fin_os/logic/recurring_template_model.dart';
import 'package:vittara_fin_os/logic/recurring_templates_controller.dart';
import 'package:vittara_fin_os/services/personal_nlp_memory_service.dart';

enum LocalAgentActionType {
  openQuickEntry,
  createRecurringTemplate,
  navigate,
  systemCommand,
  unsupported,
}

class LocalAgentPlan {
  final LocalAgentActionType type;
  final String title;
  final String summary;
  final List<String> missingFields;
  final double confidence;
  final bool requiresConfirmation;

  const LocalAgentPlan({
    required this.type,
    required this.title,
    required this.summary,
    this.missingFields = const [],
    this.confidence = 0,
    this.requiresConfirmation = true,
  });

  bool get isReady => missingFields.isEmpty;
}

class LocalAgentExecutionResult {
  final bool success;
  final String message;

  const LocalAgentExecutionResult({
    required this.success,
    required this.message,
  });
}

/// Offline deterministic agent layer.
///
/// Models/parsers may suggest intent + fields, but this layer owns validation,
/// missing-slot policy, and write execution. This keeps financial actions safe
/// even if the language understanding layer changes later.
class LocalFinancialAgent {
  LocalFinancialAgent._();

  static LocalAgentPlan plan(VoiceResult result) {
    final confidence = (result.fields['nlpConfidence'] as double?) ?? 0;
    switch (result.intent) {
      case VoiceIntent.addExpense:
      case VoiceIntent.addIncome:
        return LocalAgentPlan(
          type: LocalAgentActionType.openQuickEntry,
          title: result.intent == VoiceIntent.addIncome ? 'Income' : 'Expense',
          summary: result.confirmationText,
          confidence: confidence,
        );
      case VoiceIntent.setRecurring:
        final missing = <String>[];
        if (_amount(result) == null) missing.add('amount');
        if (result.fields['date'] is! DateTime) missing.add('date');
        return LocalAgentPlan(
          type: LocalAgentActionType.createRecurringTemplate,
          title: 'Recurring Reminder',
          summary: result.confirmationText,
          missingFields: missing,
          confidence: confidence,
        );
      case VoiceIntent.navigate:
        return LocalAgentPlan(
          type: LocalAgentActionType.navigate,
          title: 'Navigation',
          summary: result.confirmationText,
          confidence: 0.9,
        );
      case VoiceIntent.query:
      case VoiceIntent.queryBalance:
      case VoiceIntent.queryGoal:
        return LocalAgentPlan(
          type: LocalAgentActionType.systemCommand,
          title: 'Answer',
          summary: result.confirmationText,
          confidence: confidence,
        );
      case VoiceIntent.addTransfer:
      case VoiceIntent.addInvestment:
      case VoiceIntent.setBudget:
      case VoiceIntent.setGoal:
      case VoiceIntent.unknown:
        return LocalAgentPlan(
          type: LocalAgentActionType.unsupported,
          title: 'Needs More Support',
          summary: result.confirmationText,
          confidence: confidence,
        );
    }
  }

  static Future<LocalAgentExecutionResult> execute(
    BuildContext context,
    VoiceResult result, {
    required String source,
  }) async {
    final plan = LocalFinancialAgent.plan(result);
    if (!plan.isReady) {
      return LocalAgentExecutionResult(
        success: false,
        message: 'Missing ${plan.missingFields.join(', ')}',
      );
    }

    switch (plan.type) {
      case LocalAgentActionType.createRecurringTemplate:
        return _createRecurringTemplate(context, result, source: source);
      case LocalAgentActionType.openQuickEntry:
      case LocalAgentActionType.navigate:
      case LocalAgentActionType.systemCommand:
      case LocalAgentActionType.unsupported:
        return LocalAgentExecutionResult(
          success: false,
          message: 'Action is handled by the existing route.',
        );
    }
  }

  static Future<LocalAgentExecutionResult> _createRecurringTemplate(
    BuildContext context,
    VoiceResult result, {
    required String source,
  }) async {
    final amount = _amount(result);
    final date = result.fields['date'] as DateTime?;
    if (amount == null || amount <= 0 || date == null) {
      return const LocalAgentExecutionResult(
        success: false,
        message: 'Amount or due date missing',
      );
    }

    final merchant = result.fields['merchant'] as String?;
    final categoryName = result.fields['category'] as String?;
    final accountName = result.fields['account'] as String?;
    final name = _firstNonEmpty([merchant, categoryName, 'EMI']);

    final template = RecurringTemplate(
      id: 'voice_rec_${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      branch: 'expense',
      amount: amount,
      categoryName: categoryName ?? 'EMI',
      accountName: accountName,
      merchant: merchant,
      description: result.confirmationText,
      tags: const ['voice', 'emi'],
      frequency: 'monthly',
      nextDueDate: date,
      createdAt: DateTime.now(),
    );

    await context.read<RecurringTemplatesController>().addTemplate(template);
    await PersonalNlpMemoryService.recordInteraction(
      source: source,
      utterance: result.fields['rawText'] as String? ?? '',
      intent: result.intent.name,
      executed: true,
      confidence: result.fields['nlpConfidence'] as double?,
      fields: result.fields,
    );

    return LocalAgentExecutionResult(
      success: true,
      message:
          'Monthly ${template.name} reminder saved for ₹${amount.toStringAsFixed(0)}.',
    );
  }

  static double? _amount(VoiceResult result) {
    final raw = result.fields['amount'];
    if (raw is num) return raw.toDouble();
    if (raw is String) return double.tryParse(raw);
    return null;
  }

  static String _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      final clean = value?.trim();
      if (clean != null && clean.isNotEmpty) return clean;
    }
    return 'Item';
  }
}
