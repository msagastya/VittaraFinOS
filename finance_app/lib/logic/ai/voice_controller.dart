import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'device_intelligence_tier.dart';
import 'voice_fill_engine.dart';
import 'voice_navigator.dart';

enum VoiceState {
  idle,
  listening,
  processing,
  confirming, // showing parsed intent to user
  filling,    // asking follow-up question
  speaking,   // TTS playing
  error,
}

class VoiceResult {
  final VoiceIntent intent;
  final Map<String, dynamic> fields;
  final String confirmationText;
  final bool isComplete; // all required fields filled

  const VoiceResult({
    required this.intent,
    required this.fields,
    required this.confirmationText,
    required this.isComplete,
  });
}

/// Central controller for all voice interaction.
///
/// Lifecycle:
///   startListening() → ASR → parse intent → fill engine loop → confirm → execute
///
/// Register as a ChangeNotifier provider. The UI listens to [state] and
/// [currentQuestion] to drive the voice overlay.
class VoiceController extends ChangeNotifier {
  final SpeechToText _stt = SpeechToText();
  final FlutterTts _tts = FlutterTts();

  VoiceState _state = VoiceState.idle;
  VoiceState get state => _state;

  String _transcript = '';
  String get transcript => _transcript;

  /// Current fill-engine question awaiting user answer (null when not filling).
  String? _currentQuestion;
  String? get currentQuestion => _currentQuestion;

  /// Parsed result ready for confirmation.
  VoiceResult? _pendingResult;
  VoiceResult? get pendingResult => _pendingResult;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool _ttsEnabled = true;
  bool get ttsEnabled => _ttsEnabled;

  IntelligenceTier _tier = IntelligenceTier.entry;

  late VoiceFillEngine _fillEngine;
  bool _initialized = false;

  // ── Init ───────────────────────────────────────────────────────────────────

  Future<void> init({
    required IntelligenceTier tier,
    required List<String> accountNames,
    required List<String> categoryNames,
  }) async {
    if (_initialized) return;
    _tier = tier;

    final available = await _stt.initialize(
      onError: (e) => _onSttError(e.errorMsg),
    );
    if (!available) {
      debugPrint('[VoiceController] STT not available on this device');
    }

    await _tts.setLanguage('en-IN');
    await _tts.setSpeechRate(0.45);
    await _tts.setPitch(1.0);

    _fillEngine = VoiceFillEngine(
      accountNames: accountNames,
      categoryNames: categoryNames,
      tier: _tier,
    );

    _initialized = true;
  }

  /// Update account/category lists when they change.
  void updateContext({
    required List<String> accountNames,
    required List<String> categoryNames,
  }) {
    _fillEngine = VoiceFillEngine(
      accountNames: accountNames,
      categoryNames: categoryNames,
      tier: _tier,
    );
  }

  // ── Listening ─────────────────────────────────────────────────────────────

  Future<void> startListening() async {
    if (_state != VoiceState.idle) return;
    _setError(null);

    final available = await _stt.initialize();
    if (!available) {
      _setError('Microphone not available');
      return;
    }

    _setState(VoiceState.listening);
    _transcript = '';
    notifyListeners();

    _stt.listen(
      onResult: (result) {
        _transcript = result.recognizedWords;
        notifyListeners();
        if (result.finalResult) {
          _onTranscriptFinal(_transcript);
        }
      },
      listenFor: const Duration(seconds: 10),
      pauseFor: const Duration(seconds: 2),
      localeId: 'en_IN',
      cancelOnError: true,
    );
  }

  Future<void> stopListening() async {
    await _stt.stop();
    if (_state == VoiceState.listening) {
      _setState(VoiceState.idle);
    }
  }

  // ── Fill-engine loop ──────────────────────────────────────────────────────

  void _onTranscriptFinal(String text) async {
    if (text.trim().isEmpty) {
      _setState(VoiceState.idle);
      return;
    }

    _setState(VoiceState.processing);

    // Check for navigation intent first
    final navTarget = VoiceNavigator.resolve(text);
    if (navTarget != null) {
      _pendingResult = VoiceResult(
        intent: VoiceIntent.navigate,
        fields: {'target': navTarget},
        confirmationText: 'Opening ${navTarget.label}.',
        isComplete: true,
      );
      _setState(VoiceState.confirming);
      await _speak('Opening ${navTarget.label}.');
      return;
    }

    // Parse + fill
    final step = _fillEngine.process(text);
    if (step.isComplete) {
      _pendingResult = VoiceResult(
        intent: step.intent,
        fields: step.fields,
        confirmationText: step.confirmationText,
        isComplete: true,
      );
      _setState(VoiceState.confirming);
      await _speak(step.confirmationText);
    } else if (step.followUpQuestion != null) {
      _currentQuestion = step.followUpQuestion;
      _setState(VoiceState.filling);
      await _speak(step.followUpQuestion!);
      // Immediately re-listen for the answer
      _listenForAnswer();
    } else {
      _setError("I didn't catch that — try again?");
      await _speak("I didn't catch that. Try again?");
      _setState(VoiceState.idle);
    }
  }

  Future<void> _listenForAnswer() async {
    await Future.delayed(const Duration(milliseconds: 400));
    _setState(VoiceState.listening);
    _transcript = '';
    notifyListeners();

    _stt.listen(
      onResult: (result) {
        _transcript = result.recognizedWords;
        notifyListeners();
        if (result.finalResult) {
          _onAnswerReceived(_transcript);
        }
      },
      listenFor: const Duration(seconds: 8),
      pauseFor: const Duration(seconds: 2),
      localeId: 'en_IN',
      cancelOnError: true,
    );
  }

  void _onAnswerReceived(String answer) async {
    _setState(VoiceState.processing);
    final step = _fillEngine.processAnswer(answer);
    if (step.isComplete) {
      _currentQuestion = null;
      _pendingResult = VoiceResult(
        intent: step.intent,
        fields: step.fields,
        confirmationText: step.confirmationText,
        isComplete: true,
      );
      _setState(VoiceState.confirming);
      await _speak(step.confirmationText);
    } else if (step.followUpQuestion != null) {
      _currentQuestion = step.followUpQuestion;
      _setState(VoiceState.filling);
      await _speak(step.followUpQuestion!);
      _listenForAnswer();
    } else {
      _setError("I didn't catch that. Want to try again?");
      await _speak("I didn't catch that.");
      _setState(VoiceState.idle);
    }
  }

  // ── Confirm / Cancel ──────────────────────────────────────────────────────

  /// Called by UI when user taps "Confirm".
  void confirm() {
    _fillEngine.reset();
    _currentQuestion = null;
    _setState(VoiceState.idle);
    // The UI reads pendingResult and executes the action.
  }

  /// Called by UI when user taps "Edit" or "Cancel".
  void cancel() {
    _fillEngine.reset();
    _currentQuestion = null;
    _pendingResult = null;
    _setState(VoiceState.idle);
  }

  // ── TTS ───────────────────────────────────────────────────────────────────

  Future<void> _speak(String text) async {
    if (!_ttsEnabled || text.isEmpty) return;
    _setState(VoiceState.speaking);
    await _tts.speak(text);
    // TTS is fire-and-forget — we don't wait for completion
  }

  void setTtsEnabled(bool v) {
    _ttsEnabled = v;
    notifyListeners();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _setState(VoiceState s) {
    _state = s;
    notifyListeners();
  }

  void _setError(String? msg) {
    _errorMessage = msg;
    if (msg != null) notifyListeners();
  }

  void _onSttError(String msg) {
    debugPrint('[VoiceController] STT error: $msg');
    _setError('Could not hear clearly — try again');
    _setState(VoiceState.idle);
  }

  @override
  void dispose() {
    _stt.cancel();
    _tts.stop();
    super.dispose();
  }
}
