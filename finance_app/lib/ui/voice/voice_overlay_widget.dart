import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/accounts_controller.dart';
import 'package:vittara_fin_os/logic/ai/device_intelligence_tier.dart';
import 'package:vittara_fin_os/logic/ai/voice_controller.dart';
import 'package:vittara_fin_os/logic/categories_controller.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'voice_result_card.dart';

/// Full-screen voice interaction overlay.
/// Show via [VoiceOverlayWidget.show].
class VoiceOverlayWidget extends StatefulWidget {
  final bool showConfirmation;
  final bool autoStart;

  const VoiceOverlayWidget({
    super.key,
    this.showConfirmation = true,
    this.autoStart = false,
  });

  /// Shows the voice overlay and returns the confirmed [VoiceResult] or null.
  static Future<VoiceResult?> show(
    BuildContext context, {
    bool showConfirmation = true,
    bool autoStart = false,
  }) async {
    // Lock to portrait so orientation changes cannot interrupt an active
    // voice session mid-utterance or cause the overlay to misbehave.
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    final voice = context.read<VoiceController>();
    final accounts = context.read<AccountsController>().accounts;
    final categories = context.read<CategoriesController>().categories;
    final accountNames = accounts.map((a) => a.name).toList();
    final categoryNames = categories.map((c) => c.name).toList();

    await voice.init(
      tier: DeviceIntelligenceTier.current,
      accountNames: accountNames,
      categoryNames: categoryNames,
    );
    voice.updateContext(
      accountNames: accountNames,
      categoryNames: categoryNames,
    );

    final result = await showCupertinoModalPopup<VoiceResult?>(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => ChangeNotifierProvider.value(
        value: voice,
        child: VoiceOverlayWidget(
          showConfirmation: showConfirmation,
          autoStart: autoStart,
        ),
      ),
    );
    // Restore all orientations after the overlay is dismissed.
    await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    // Guarantee mic is dead regardless of how the modal was closed.
    if (voice.state != VoiceState.idle) voice.cancel();
    return result;
  }

  @override
  State<VoiceOverlayWidget> createState() => _VoiceOverlayWidgetState();
}

class _VoiceOverlayWidgetState extends State<VoiceOverlayWidget> {
  VoiceState? _prevState;
  final TextEditingController _typedCtrl = TextEditingController();
  bool _autoReturned = false;
  bool _autoStarted = false;

  @override
  void initState() {
    super.initState();
    if (widget.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted || _autoStarted) return;
        _autoStarted = true;
        await context.read<VoiceController>().startListening();
      });
    }
  }

  @override
  void dispose() {
    _typedCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<VoiceController>(
      builder: (context, voice, _) {
        // Fire haptic when transcript is finalized (state enters confirming)
        if (voice.state == VoiceState.confirming &&
            _prevState != VoiceState.confirming) {
          HapticFeedback.lightImpact();
        }
        _prevState = voice.state;

        // Show result card when confirming
        if (voice.state == VoiceState.confirming &&
            voice.pendingResult != null) {
          if (!widget.showConfirmation) {
            if (!_autoReturned) {
              _autoReturned = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                final result = voice.pendingResult;
                voice.confirm();
                Navigator.of(context).pop(result);
              });
            }
            return _buildAutoReturnCard(context);
          }
          return VoiceResultCard(
            result: voice.pendingResult!,
            onConfirm: (result) {
              HapticFeedback.heavyImpact();
              Future.delayed(const Duration(milliseconds: 120),
                  () => HapticFeedback.lightImpact());
              Future.delayed(const Duration(milliseconds: 240),
                  () => HapticFeedback.lightImpact());
              voice.confirm();
              Navigator.of(context).pop(result);
            },
            onEdit: () {
              voice.cancel();
              Navigator.of(context).pop(null);
            },
          );
        }

        return GestureDetector(
          onTap: () {
            // Cancel unconditionally — kills mic even if STT is mid-session.
            voice.cancel();
            Navigator.of(context).pop(null);
          },
          child: Container(
            color: Colors.transparent,
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              top: false,
              child: GestureDetector(
                onTap: () {},
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  padding: const EdgeInsets.all(Spacing.xxl),
                  decoration: BoxDecoration(
                    color: AppStyles.getCardColor(context),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: AppStyles.aetherTeal.withValues(alpha: 0.3),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppStyles.aetherTeal.withValues(alpha: 0.15),
                        blurRadius: 32,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildWaveform(voice),
                      const SizedBox(height: Spacing.xl),
                      _buildStatusText(voice, context),
                      if (voice.transcript.isNotEmpty) ...[
                        const SizedBox(height: Spacing.md),
                        _buildTranscript(voice.transcript, context),
                      ],
                      if (voice.currentQuestion != null) ...[
                        const SizedBox(height: Spacing.md),
                        _buildQuestion(voice.currentQuestion!, context),
                        // Countdown + auto-listen indicator
                        if (voice.autoListenCountdown != null) ...[
                          const SizedBox(height: Spacing.sm),
                          _buildCountdown(voice.autoListenCountdown!, context),
                        ],
                      ],
                      if (voice.errorMessage != null) ...[
                        const SizedBox(height: Spacing.md),
                        _buildError(voice.errorMessage!, context),
                      ],
                      const SizedBox(height: Spacing.xl),
                      _buildMicButton(voice, context),
                      const SizedBox(height: Spacing.lg),
                      _buildTypedFallback(voice, context),
                      // Manual fallback: "Tap to answer" shown only if countdown finished
                      // but user didn't speak and mic went idle (e.g. cancelled)
                      if (voice.state == VoiceState.filling &&
                          voice.autoListenCountdown == null) ...[
                        const SizedBox(height: Spacing.md),
                        CupertinoButton.filled(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 32, vertical: 10),
                          onPressed: () => voice.listenForAnswer(),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(CupertinoIcons.mic_fill,
                                  size: 16, color: CupertinoColors.white),
                              SizedBox(width: 8),
                              Text('Tap to answer',
                                  style: TextStyle(fontSize: 15)),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: Spacing.md),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          voice.cancel();
                          Navigator.of(context).pop(null);
                        },
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 15,
                            color: AppStyles.getSecondaryTextColor(context),
                          ),
                        ),
                      ),
                      const SizedBox(height: Spacing.sm),
                      Text(
                        'Tap outside the card to dismiss',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppStyles.getSecondaryTextColor(context)
                              .withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildWaveform(VoiceController voice) {
    final isListening = voice.state == VoiceState.listening;
    return _WaveformIndicator(isAnimating: isListening);
  }

  Widget _buildAutoReturnCard(BuildContext context) {
    return Container(
      color: Colors.transparent,
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          padding: const EdgeInsets.all(Spacing.xl),
          decoration: BoxDecoration(
            color: AppStyles.getCardColor(context),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppStyles.aetherTeal.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CupertinoActivityIndicator(radius: 9),
              const SizedBox(width: Spacing.md),
              Text(
                'Opening Quick Entry...',
                style: TextStyle(
                  color: AppStyles.getTextColor(context),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusText(VoiceController voice, BuildContext context) {
    String text;
    switch (voice.state) {
      case VoiceState.idle:
        text = widget.autoStart ? 'Ready to listen' : 'Tap mic and speak';
        break;
      case VoiceState.listening:
        text = voice.currentQuestion != null
            ? 'Speak your answer'
            : 'Listening... pause 3 seconds or tap mic to finish';
        break;
      case VoiceState.processing:
        text = 'Understanding...';
        break;
      case VoiceState.filling:
        text = 'Follow-up question';
        break;
      case VoiceState.confirming:
        text = 'Got it';
        break;
      case VoiceState.speaking:
        text = '';
        break;
      case VoiceState.error:
        text = 'Try again';
        break;
    }
    if (text.isEmpty) return const SizedBox.shrink();
    return Text(
      text,
      style: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: voice.state == VoiceState.filling
            ? AppStyles.aetherTeal
            : AppStyles.getTextColor(context),
      ),
    );
  }

  Widget _buildCountdown(int seconds, BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CupertinoActivityIndicator(radius: 7),
        const SizedBox(width: 6),
        Text(
          seconds > 0 ? 'Mic opens in $seconds...' : 'Opening mic...',
          style: TextStyle(
            fontSize: 13,
            color: AppStyles.getSecondaryTextColor(context),
          ),
        ),
      ],
    );
  }

  Widget _buildTranscript(String transcript, BuildContext context) {
    return Text(
      '"$transcript"',
      style: TextStyle(
        fontSize: 15,
        fontStyle: FontStyle.italic,
        color: AppStyles.getSecondaryTextColor(context),
      ),
      textAlign: TextAlign.center,
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildQuestion(String question, BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: AppStyles.aetherTeal.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppStyles.aetherTeal.withValues(alpha: 0.2)),
      ),
      child: Text(
        question,
        style: TextStyle(
          fontSize: 15,
          color: AppStyles.getTextColor(context),
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildError(String error, BuildContext context) {
    return Text(
      error,
      style: TextStyle(
        fontSize: 13,
        color: AppStyles.loss(context),
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildMicButton(VoiceController voice, BuildContext context) {
    final isListening = voice.state == VoiceState.listening;
    final isProcessing = voice.state == VoiceState.processing;

    return GestureDetector(
      onLongPressStart: (_) async {
        HapticFeedback.mediumImpact();
        await voice.startListening();
      },
      onLongPressEnd: (_) async {
        await voice.stopListening();
      },
      onTap: () async {
        if (voice.state == VoiceState.listening) {
          await voice.stopListening();
        } else if (voice.state == VoiceState.idle) {
          HapticFeedback.mediumImpact();
          await voice.startListening();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: isListening ? 80 : 64,
        height: isListening ? 80 : 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isListening
              ? AppStyles.aetherTeal
              : AppStyles.aetherTeal.withValues(alpha: 0.15),
          border: Border.all(
            color: AppStyles.aetherTeal,
            width: isListening ? 2 : 1,
          ),
          boxShadow: isListening
              ? [
                  BoxShadow(
                    color: AppStyles.aetherTeal.withValues(alpha: 0.4),
                    blurRadius: 20,
                    spreadRadius: 4,
                  )
                ]
              : [],
        ),
        child: isProcessing
            ? const CupertinoActivityIndicator()
            : Icon(
                isListening ? CupertinoIcons.mic_fill : CupertinoIcons.mic,
                color:
                    isListening ? CupertinoColors.white : AppStyles.aetherTeal,
                size: 28,
              ),
      ),
    );
  }

  Widget _buildTypedFallback(VoiceController voice, BuildContext context) {
    final busy = voice.state == VoiceState.listening ||
        voice.state == VoiceState.processing ||
        voice.state == VoiceState.speaking;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Or type the sentence',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: AppStyles.getSecondaryTextColor(context),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: Spacing.sm),
        Row(
          children: [
            Expanded(
              child: CupertinoTextField(
                controller: _typedCtrl,
                enabled: !busy,
                placeholder: '500 on Swiggy yesterday',
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submitTyped(voice),
                padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.md,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppStyles.l3(context),
                  borderRadius: BorderRadius.circular(Radii.md),
                  border: Border.all(
                    color: AppStyles.getDividerColor(context),
                  ),
                ),
                style: TextStyle(color: AppStyles.getTextColor(context)),
              ),
            ),
            const SizedBox(width: Spacing.sm),
            CupertinoButton(
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.md,
                vertical: 11,
              ),
              color: AppStyles.aetherTeal,
              borderRadius: BorderRadius.circular(Radii.md),
              onPressed: busy ? null : () => _submitTyped(voice),
              child: const Icon(
                CupertinoIcons.arrow_right,
                size: 18,
                color: CupertinoColors.white,
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _submitTyped(VoiceController voice) {
    final text = _typedCtrl.text.trim();
    if (text.isEmpty) return;
    HapticFeedback.selectionClick();
    voice.submitText(text);
  }
}

/// Animated waveform bars while listening.
class _WaveformIndicator extends StatefulWidget {
  final bool isAnimating;
  const _WaveformIndicator({required this.isAnimating});

  @override
  State<_WaveformIndicator> createState() => _WaveformIndicatorState();
}

class _WaveformIndicatorState extends State<_WaveformIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(7, (i) {
              final phase = (i / 7) * 3.14159;
              final amplitude = widget.isAnimating
                  ? ((_ctrl.value + phase / 3.14159) % 1.0)
                  : 0.15;
              final height = 8 + (amplitude * 32);
              return Container(
                width: 4,
                height: height,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: AppStyles.aetherTeal.withValues(
                    alpha: widget.isAnimating ? 0.8 : 0.3,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}
