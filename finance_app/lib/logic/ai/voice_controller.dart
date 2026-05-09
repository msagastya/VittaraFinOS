import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
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
  filling, // asking follow-up question
  speaking, // TTS playing
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
class VoiceController extends ChangeNotifier with WidgetsBindingObserver {
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

  /// Hard session timeout — if the mic has been open for this long without
  /// resolution, cancel automatically to prevent zombie sessions.
  static const _kMaxSessionSeconds = 45;
  Timer? _sessionTimeoutTimer;

  IntelligenceTier _tier = IntelligenceTier.entry;

  late VoiceFillEngine _fillEngine;
  bool _initialized = false;
  String? _lastProcessedTranscript;

  // ── App lifecycle ─────────────────────────────────────────────────────────

  /// Kill the mic immediately when the app is backgrounded or killed.
  /// This prevents the "microphone keeps running after leaving the screen"
  /// zombie bug where STT stays alive even when the app is in recents.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      if (_state != VoiceState.idle) {
        cancel();
      }
    }
  }

  // ── Init ───────────────────────────────────────────────────────────────────

  Future<void> init({
    required IntelligenceTier tier,
    required List<String> accountNames,
    required List<String> categoryNames,
  }) async {
    if (_initialized) return;
    _tier = tier;

    // Register for lifecycle events so the mic is killed on app background.
    WidgetsBinding.instance.addObserver(this);

    final available = await _stt.initialize(
      onError: (e) => _onSttError(e.errorMsg),
      onStatus: _handleSttStatus,
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

    final available = await _stt.initialize(
      onError: (e) => _onSttError(e.errorMsg),
      onStatus: _handleSttStatus,
    );
    if (!available) {
      _setError('Microphone not available');
      return;
    }

    _setState(VoiceState.listening);
    _transcript = '';
    _lastProcessedTranscript = null;
    notifyListeners();
    HapticFeedback.lightImpact(); // signal mic is open
    _resetSessionTimeout(); // start 45s hard kill timer

    _stt.listen(
      onResult: (result) {
        _transcript = result.recognizedWords;
        notifyListeners();
        if (result.finalResult) {
          _onTranscriptFinal(_transcript);
        }
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
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

  /// Manual fallback for the voice overlay. This uses the exact same parser as
  /// speech input, so a user can type "500 on Swiggy" if STT is unavailable.
  Future<void> submitText(String text) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty) {
      _setError('Type something like "500 on Swiggy"');
      return;
    }
    _cancelCountdown();
    await _stt.stop();
    _currentQuestion = null;
    _transcript = cleanText;
    _lastProcessedTranscript = null;
    notifyListeners();
    _resetSessionTimeout();
    _onTranscriptFinal(cleanText);
  }

  void _onTranscriptFinal(String text) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty) {
      _setState(VoiceState.idle);
      return;
    }
    if (_lastProcessedTranscript == cleanText &&
        (_state == VoiceState.processing ||
            _state == VoiceState.confirming ||
            _state == VoiceState.filling)) {
      return;
    }
    _lastProcessedTranscript = cleanText;

    _setState(VoiceState.processing);

    try {
      final systemCommand = _resolveSystemCommand(cleanText);
      if (systemCommand != null) {
        _pendingResult = VoiceResult(
          intent: VoiceIntent.query,
          fields: {
            'aiCommand': systemCommand.$1,
            'rawText': cleanText,
          },
          confirmationText: systemCommand.$2,
          isComplete: true,
        );
        _setState(VoiceState.confirming);
        return;
      }

      // Check for navigation intent first
      final navTarget = VoiceNavigator.resolve(cleanText);
      if (navTarget != null) {
        _pendingResult = VoiceResult(
          intent: VoiceIntent.navigate,
          fields: {'navTarget': navTarget, 'rawText': cleanText},
          confirmationText: 'Opening ${navTarget.label}.',
          isComplete: true,
        );
        _setState(VoiceState.confirming);
        return; // No TTS here — UI shows the confirmation card
      }

      // Parse + fill — ML Kit runs async on-device, ~100ms
      final step = await _fillEngine.processAsync(cleanText);
      if (step.isComplete) {
        _pendingResult = VoiceResult(
          intent: step.intent,
          fields: {...step.fields, 'rawText': cleanText},
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
        _setError(
            "Didn't catch that — try: \"500 on Swiggy\" or just say the amount.");
        _setState(VoiceState.idle);
      }
    } catch (e) {
      debugPrint('[VoiceController] Parse failed: $e');
      _setError('Could not understand that — try again');
      _setState(VoiceState.idle);
    }
  }

  /// Called from UI "Tap to answer" button when in [VoiceState.filling].
  /// Also called automatically after [autoAnswerDelayMs] when a question appears.
  Future<void> listenForAnswer() => _listenForAnswer();

  Future<void> _listenForAnswer() async {
    // Small gap so the question text is visible before the mic opens
    await Future.delayed(const Duration(milliseconds: 300));
    final available = await _stt.initialize(
      onError: (e) => _onSttError(e.errorMsg),
      onStatus: _handleSttStatus,
    );
    if (!available) {
      _setError('Microphone not available');
      _setState(VoiceState.filling);
      return;
    }
    _setState(VoiceState.listening);
    _transcript = '';
    _lastProcessedTranscript = null;
    notifyListeners();
    HapticFeedback.lightImpact(); // signal mic is open
    _resetSessionTimeout(); // restart 45s hard kill timer for follow-up

    _stt.listen(
      onResult: (result) {
        _transcript = result.recognizedWords;
        notifyListeners();
        if (result.finalResult) {
          _onAnswerReceived(_transcript);
        }
      },
      listenFor: const Duration(seconds: 20),
      pauseFor: const Duration(seconds: 3),
      cancelOnError: true,
      localeId: 'en_IN',
    );
  }

  void _onAnswerReceived(String answer) {
    final cleanAnswer = answer.trim();
    if (cleanAnswer.isEmpty) {
      _setState(VoiceState.filling);
      return;
    }
    _setState(VoiceState.processing);
    try {
      final step = _fillEngine.processAnswer(cleanAnswer);
      if (step.isComplete) {
        _currentQuestion = null;
        _pendingResult = VoiceResult(
          intent: step.intent,
          fields: {...step.fields, 'rawText': cleanAnswer},
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
    } catch (e) {
      debugPrint('[VoiceController] Follow-up parse failed: $e');
      _setError("Still couldn't get that — try just saying the amount.");
      _setState(VoiceState.filling);
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

  // ── Session timeout ───────────────────────────────────────────────────────

  /// Starts (or restarts) the 45-second hard-kill timer.
  /// If the session is still active when it fires, cancel() is called
  /// automatically — prevents zombie mic sessions.
  void _resetSessionTimeout() {
    _sessionTimeoutTimer?.cancel();
    _sessionTimeoutTimer = Timer(
      const Duration(seconds: _kMaxSessionSeconds),
      () {
        if (_state != VoiceState.idle) {
          debugPrint('[VoiceController] Session timeout — auto-cancelling.');
          cancel();
        }
      },
    );
  }

  void _cancelSessionTimeout() {
    _sessionTimeoutTimer?.cancel();
    _sessionTimeoutTimer = null;
  }

  // ── Confirm / Cancel ──────────────────────────────────────────────────────

  /// Called by UI when user taps "Confirm".
  void confirm() {
    _cancelSessionTimeout();
    _fillEngine.reset();
    _currentQuestion = null;
    _lastProcessedTranscript = null;
    _setState(VoiceState.idle);
    // The UI reads pendingResult and executes the action.
  }

  /// Called by UI when user taps "Edit" or "Cancel".
  void cancel() {
    _cancelCountdown();
    _cancelSessionTimeout();
    _stt.cancel();
    _tts.stop();
    _fillEngine.reset();
    _currentQuestion = null;
    _pendingResult = null;
    _lastProcessedTranscript = null;
    _setState(VoiceState.idle);
  }

  // ── TTS ───────────────────────────────────────────────────────────────────

  Future<void> _speak(String text) async {
    if (!_ttsEnabled || text.isEmpty) return;
    _setState(VoiceState.speaking);
    await _tts.speak(text);
    // TTS is fire-and-forget — we don't wait for completion
  }

  (String, String)? _resolveSystemCommand(String text) {
    final lower = text.toLowerCase().trim();
    bool any(List<String> words) => words.any(lower.contains);

    if (any([
      'dark mode',
      'night mode',
      'turn dark',
      'make dark',
      'theme dark',
      'black mode',
      'dark karo',
    ])) {
      return ('themeDark', 'Turning dark mode on.');
    }
    if (any([
      'light mode',
      'day mode',
      'turn light',
      'make light',
      'theme light',
      'light karo',
    ])) {
      return ('themeLight', 'Turning light mode on.');
    }
    if (any(['system theme', 'auto theme', 'device theme'])) {
      return ('themeSystem', 'Using the system theme.');
    }
    if (any([
      'today summary',
      'todays summary',
      "today's summary",
      'read summary',
      'read today',
      'aaj ka summary',
      'aaj ka hisaab',
    ])) {
      return ('summaryToday', "Reading today's summary.");
    }
    if (any([
      'month summary',
      'monthly summary',
      'this month summary',
      'mahine ka summary',
      'mahine ka hisaab',
    ])) {
      return ('summaryMonth', 'Reading this month summary.');
    }
    if (any([
      'monthly statement',
      'export statement',
      'statement export',
      'generate statement',
      'download statement',
      'month statement',
    ])) {
      return ('monthlyStatement', 'Opening monthly statement export.');
    }
    if (any([
      'import statement',
      'bank statement import',
      'import bank statement',
    ])) {
      return ('importStatement', 'Opening bank statement import.');
    }
    if (any([
      'report analysis',
      'reports analysis',
      'report and analysis',
      'analytics',
      'analysis page',
    ])) {
      return ('reports', 'Opening reports and analysis.');
    }
    return null;
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

  void _handleSttStatus(String status) {
    if (status != 'notListening' || _state != VoiceState.listening) return;

    final captured = _transcript.trim();
    if (captured.isEmpty) {
      _setState(VoiceState.idle);
      return;
    }

    if (_currentQuestion != null) {
      _onAnswerReceived(captured);
    } else {
      _onTranscriptFinal(captured);
    }
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
    WidgetsBinding.instance.removeObserver(this);
    _cancelCountdown();
    _cancelSessionTimeout();
    _stt.cancel();
    _tts.stop();
    super.dispose();
  }
}
