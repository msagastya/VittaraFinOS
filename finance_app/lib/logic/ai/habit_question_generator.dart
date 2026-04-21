import 'habit_observation_engine.dart';
import 'device_intelligence_tier.dart';

/// A single question in a habit-building conversation.
class HabitQuestion {
  final int stepIndex; // 0-based
  final String questionText;
  final List<HabitAnswer> answers;
  final bool isSkippable;

  const HabitQuestion({
    required this.stepIndex,
    required this.questionText,
    required this.answers,
    this.isSkippable = true,
  });
}

class HabitAnswer {
  final String id;
  final String label;
  final Map<String, dynamic> payload; // drives next question selection

  const HabitAnswer({
    required this.id,
    required this.label,
    required this.payload,
  });
}

/// Builds question sequences from a HabitOpportunity.
/// Tier 1 (flagship) uses Gemini Nano — fall back implemented here for Tier 2/3.
/// Max 5 questions per session.
class HabitQuestionGenerator {
  HabitQuestionGenerator._();

  /// Generate the next question given the opportunity and prior answers.
  /// [priorAnswers] is a list of answer payloads collected so far.
  static HabitQuestion? next({
    required HabitOpportunity opportunity,
    required List<Map<String, dynamic>> priorAnswers,
    required IntelligenceTier tier,
  }) {
    // For now all tiers use the decision-tree approach.
    // Tier 1 hook: when Gemini Nano is integrated, call it here.
    return _decisionTree(opportunity, priorAnswers);
  }

  static HabitQuestion? _decisionTree(
    HabitOpportunity opp,
    List<Map<String, dynamic>> priorAnswers,
  ) {
    final step = priorAnswers.length;
    if (step >= 4) return null; // max 4 questions

    final cat = opp.category;
    final monthly = (opp.context['monthlyAvg'] as num?)?.toDouble() ?? 0.0;
    final variance = opp.context['variance'] as double?;

    switch (step) {
      case 0:
        // Opening: is this planned or unplanned?
        return HabitQuestion(
          stepIndex: 0,
          questionText: variance != null && variance > 0.8
              ? 'Your $cat spending varies a lot — '
                'sometimes quiet, sometimes heavy. '
                'Is that mostly planned or does it just happen?'
              : '$cat costs you about ₹${_fmt(monthly)}/month. '
                'How do you feel about that?',
          answers: variance != null && variance > 0.8
              ? [
                  HabitAnswer(
                    id: 'planned',
                    label: 'Mostly planned',
                    payload: {'intent': 'controlled'},
                  ),
                  HabitAnswer(
                    id: 'unplanned',
                    label: 'It just happens',
                    payload: {'intent': 'uncontrolled'},
                  ),
                ]
              : [
                  HabitAnswer(
                    id: 'fine',
                    label: "It's fine",
                    payload: {'concern': 'low'},
                  ),
                  HabitAnswer(
                    id: 'high',
                    label: 'A bit high',
                    payload: {'concern': 'medium'},
                  ),
                  HabitAnswer(
                    id: 'too_much',
                    label: 'Too much',
                    payload: {'concern': 'high'},
                  ),
                ],
        );

      case 1:
        final concern = priorAnswers[0]['concern'] as String?;
        final intent = priorAnswers[0]['intent'] as String?;
        if (concern == 'low') return null; // user is fine, stop

        if (intent == 'uncontrolled' || concern == 'high' || concern == 'medium') {
          return HabitQuestion(
            stepIndex: 1,
            questionText:
                'Would setting a weekly $cat limit help you stay on track?',
            answers: [
              HabitAnswer(
                id: 'yes_limit',
                label: 'Yes, a limit sounds good',
                payload: {'approach': 'limit'},
              ),
              HabitAnswer(
                id: 'yes_track',
                label: 'I\'d rather just track it',
                payload: {'approach': 'track'},
              ),
              HabitAnswer(
                id: 'no',
                label: 'Not really',
                payload: {'approach': 'none'},
              ),
            ],
          );
        }
        return null;

      case 2:
        final approach = priorAnswers[1]['approach'] as String?;
        if (approach == 'none') return null;
        if (approach == 'limit') {
          final suggested = (monthly / 4.0 * 0.8).round() * 100.0;
          return HabitQuestion(
            stepIndex: 2,
            questionText:
                'What weekly limit feels right for $cat?\n'
                'Your current weekly average is around ₹${_fmt(monthly / 4.3)}.',
            answers: [
              HabitAnswer(
                id: 'tight',
                label: '₹${_fmt(suggested * 0.75)}/week',
                payload: {'limit': suggested * 0.75, 'difficulty': 'challenging'},
              ),
              HabitAnswer(
                id: 'moderate',
                label: '₹${_fmt(suggested)}/week',
                payload: {'limit': suggested, 'difficulty': 'moderate'},
              ),
              HabitAnswer(
                id: 'gentle',
                label: '₹${_fmt(suggested * 1.25)}/week',
                payload: {'limit': suggested * 1.25, 'difficulty': 'easy'},
              ),
            ],
          );
        }
        if (approach == 'track') {
          return HabitQuestion(
            stepIndex: 2,
            questionText:
                'How often would you like a spending check-in for $cat?',
            answers: [
              HabitAnswer(
                id: 'daily',
                label: 'Daily',
                payload: {'checkInFrequency': 'daily'},
              ),
              HabitAnswer(
                id: 'weekly',
                label: 'Weekly',
                payload: {'checkInFrequency': 'weekly'},
              ),
            ],
          );
        }
        return null;

      case 3:
        // Nudge style preference
        return HabitQuestion(
          stepIndex: 3,
          questionText: 'When you\'re close to your limit, what kind of reminder works best for you?',
          answers: [
            HabitAnswer(
              id: 'streak',
              label: 'Show my streak',
              payload: {'nudge': 'streak'},
            ),
            HabitAnswer(
              id: 'goal',
              label: 'Remind me of my goal',
              payload: {'nudge': 'gain'},
            ),
            HabitAnswer(
              id: 'none',
              label: 'No reminders',
              payload: {'nudge': 'none'},
            ),
          ],
        );

      default:
        return null;
    }
  }

  static String _fmt(double v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
    return v.toInt().toString();
  }
}
