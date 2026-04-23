import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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
  final bool isComplete;
  /// Fields the engine is uncertain about — UI highlights these for user review.
  final List<String> uncertainFields;

  const VoiceResult({
    required this.intent,
    required this.fields,
    required this.confirmationText,
    required this.isComplete,
    this.uncertainFields = const [],
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

  /// Countdown seconds before auto-starting mic on follow-up questions.
  /// Null when no countdown is active.
  int? _autoListenCountdown;
  int? get autoListenCountdown => _autoListenCountdown;

  Timer? _countdownTimer;

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
    HapticFeedback.lightImpact(); // signal mic is open

    _stt.listen(
      onResult: (result) {
        _transcript = result.recognizedWords;
        notifyListeners();
        if (result.finalResult) {
          _onTranscriptFinal(_transcript);
        }
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(milliseconds: 2500),
      cancelOnError: true,
      localeId: 'en_IN',
    );
  }

  Future<void> stopListening() async {
    // Capture transcript BEFORE stopping — some Android STT implementations
    // clear the buffer when stop() is called, or never fire a finalResult
    // callback on manual stop (hold-and-release pattern).
    final captured = _transcript.trim();
    await _stt.stop();

    // If still in listening state, the STT did NOT fire a finalResult callback.
    // Process what we captured manually so hold-to-speak actually works.
    if (_state == VoiceState.listening) {
      if (captured.isNotEmpty) {
        _onTranscriptFinal(captured);
      } else {
        _setState(VoiceState.idle);
      }
    }
    // If state already changed (STT fired finalResult before stop returned),
    // do nothing — processing is already underway.
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
      return; // No TTS here — UI shows the confirmation card
    }

    // Parse + fill — ML Kit runs async on-device, ~100ms
    final step = await _fillEngine.processAsync(text);
    if (step.isComplete) {
      _pendingResult = VoiceResult(
        intent: step.intent,
        fields: step.fields,
        confirmationText: step.confirmationText,
        isComplete: true,
        uncertainFields: step.uncertainFields,
      );
      _setState(VoiceState.confirming);
    } else if (step.followUpQuestion != null) {
      _currentQuestion = step.followUpQuestion;
      _setState(VoiceState.filling);
      _startAutoListenCountdown();
    } else {
      _setError("Didn't catch that — try: \"500 on Swiggy\" or just say the amount.");
      _setState(VoiceState.idle);
    }
  }

  /// Called from UI "Tap to answer" button when in [VoiceState.filling].
  /// Also called automatically after [autoAnswerDelayMs] when a question appears.
  Future<void> listenForAnswer() => _listenForAnswer();

  Future<void> _listenForAnswer() async {
    // Small gap so the question text is visible before the mic opens
    await Future.delayed(const Duration(milliseconds: 300));
    _setState(VoiceState.listening);
    _transcript = '';
    notifyListeners();
    HapticFeedback.lightImpact(); // signal mic is open

    _stt.listen(
      onResult: (result) {
        _transcript = result.recognizedWords;
        notifyListeners();
        if (result.finalResult) {
          _onAnswerReceived(_transcript);
        }
      },
      listenFor: const Duration(seconds: 20),
      pauseFor: const Duration(milliseconds: 2500),
      cancelOnError: true,
      localeId: 'en_IN',
    );
  }

  void _onAnswerReceived(String answer) {
    _setState(VoiceState.processing);
    final step = _fillEngine.processAnswer(answer);
    if (step.isComplete) {
      _currentQuestion = null;
      _pendingResult = VoiceResult(
        intent: step.intent,
        fields: step.fields,
        confirmationText: step.confirmationText,
        isComplete: true,
        uncertainFields: step.uncertainFields,
      );
      _setState(VoiceState.confirming);
    } else if (step.followUpQuestion != null) {
      _currentQuestion = step.followUpQuestion;
      _setState(VoiceState.filling);
      _startAutoListenCountdown();
    } else {
      _setError("Still couldn't get that — try just saying the amount.");
      _setState(VoiceState.idle);
    }
  }

  // ── Auto-listen countdown ─────────────────────────────────────────────────

  /// Starts a 2-second countdown then automatically opens the mic.
  /// This gives the user time to read the follow-up question before speaking.
  void _startAutoListenCountdown() {
    _cancelCountdown();
    _autoListenCountdown = 2;
    notifyListeners();

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_autoListenCountdown == null || _autoListenCountdown! <= 0) {
        t.cancel();
        _autoListenCountdown = null;
        notifyListeners();
        if (_state == VoiceState.filling) {
          listenForAnswer();
        }
        return;
      }
      _autoListenCountdown = _autoListenCountdown! - 1;
      notifyListeners();
    });
  }

  void _cancelCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _autoListenCountdown = null;
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
    _cancelCountdown();
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
    _cancelCountdown();
    _stt.cancel();
    _tts.stop();
    super.dispose();
  }
}
