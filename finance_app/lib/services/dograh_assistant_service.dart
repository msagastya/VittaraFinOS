import 'package:vittara_fin_os/logic/ai/voice_controller.dart';

/// Dograh assistant facade for VittaraFinOS.
///
/// Dograh itself is a server-style voice-agent stack, not an offline Flutter
/// model. This facade keeps Vittara's assistant local-first while exposing one
/// consistent assistant identity across voice entry, menu, and onboarding.
class DograhAssistantService {
  DograhAssistantService._();

  static const String name = 'Dograh';
  static const String fullName = 'Dograh Assistant';
  static const String privacyLine =
      'Local finance commands. No cloud AI unless you connect one yourself.';

  static String statusText({
    required VoiceState state,
    required bool autoStart,
    required bool hasQuestion,
  }) {
    switch (state) {
      case VoiceState.idle:
        return autoStart ? '$name is ready to listen' : 'Tap mic for $name';
      case VoiceState.listening:
        return hasQuestion
            ? '$name is listening for your answer'
            : '$name is listening... pause 3 seconds or tap mic to finish';
      case VoiceState.processing:
        return '$name is understanding your finance command...';
      case VoiceState.filling:
        return '$name needs one more detail';
      case VoiceState.confirming:
        return '$name got it';
      case VoiceState.speaking:
        return '';
      case VoiceState.error:
        return '$name needs you to try again';
    }
  }

  static const List<String> examples = [
    '500 on Swiggy yesterday',
    'open investments',
    'today summary',
    'make this month statement',
  ];
}
