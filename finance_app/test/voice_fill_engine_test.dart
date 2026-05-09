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
  });
}
