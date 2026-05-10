import 'package:flutter_test/flutter_test.dart';
import 'package:vittara_fin_os/logic/ai/device_intelligence_tier.dart';
import 'package:vittara_fin_os/logic/ai/voice_fill_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late VoiceFillEngine engine;

  setUp(() {
    engine = VoiceFillEngine(
      accountNames: const ['SBI Savings', 'Cash'],
      categoryNames: const ['Food', 'Travel', 'Salary', 'Shopping'],
      tier: IntelligenceTier.entry,
    );
  });

  tearDown(() {
    engine.dispose();
  });

  test('parses common expense utterance with amount and merchant', () async {
    final step = await engine.processAsync('paid 500 on Swiggy from SBI');

    expect(step.intent, VoiceIntent.addExpense);
    expect(step.isComplete, isTrue);
    expect(step.fields['amount'], 500);
    expect(step.confirmationText.toLowerCase(), contains('save'));
  });

  test('parses Hinglish income utterance', () async {
    final step = await engine.processAsync('salary aayi 50000 SBI mein');

    expect(step.intent, VoiceIntent.addIncome);
    expect(step.isComplete, isTrue);
    expect(step.fields['amount'], 50000);
  });

  test('asks follow-up when amount is missing', () async {
    final step = await engine.processAsync('paid for lunch');

    expect(step.intent, VoiceIntent.addExpense);
    expect(step.isComplete, isFalse);
    expect(step.followUpQuestion, isNotNull);
  });

  test('parses investment utterance', () async {
    final step = await engine.processAsync('invested 10000 in mutual fund');

    expect(step.intent, VoiceIntent.addInvestment);
    expect(step.isComplete, isTrue);
    expect(step.fields['amount'], 10000);
    expect(step.fields['nlpConfidence'], greaterThan(0.5));
  });

  test('adds local NLP confidence and interpretation metadata', () async {
    final step = await engine.processAsync('paid 500 on Swiggy from SBI');

    expect(step.confidence, greaterThan(0.7));
    expect(step.interpretation.toLowerCase(), contains('expense'));
    expect(step.reasoning, contains('amount'));
    expect(step.fields['nlpReasoning'], contains('account'));
  });

  test('fuzzy matches minor account typo locally', () async {
    final step = await engine.processAsync('paid 500 for lunch from sbii');

    expect(step.intent, VoiceIntent.addExpense);
    expect(step.fields['account'], 'SBI Savings');
    expect(step.uncertainFields, isNot(contains('amount')));
  });

  test('parses EMI recurring reminder with due date', () async {
    final step = await engine.processAsync('set emi 12000 every 5th from SBI');

    expect(step.intent, VoiceIntent.setRecurring);
    expect(step.isComplete, isTrue);
    expect(step.fields['amount'], 12000);
    expect(step.fields['date'], isA<DateTime>());
    expect((step.fields['date'] as DateTime).day, 5);
    expect(step.confirmationText.toLowerCase(), contains('monthly'));
  });

  test('asks EMI due date follow-up when date is missing', () async {
    final step = await engine.processAsync('set emi 12000 from SBI');

    expect(step.intent, VoiceIntent.setRecurring);
    expect(step.isComplete, isFalse);
    expect(step.followUpQuestion?.toLowerCase(), contains('date'));
  });
}
