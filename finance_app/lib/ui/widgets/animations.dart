import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:vittara_fin_os/ui/styles/app_springs.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';

// ============================================================
// HAPTIC FEEDBACK HELPERS
// ============================================================

class Haptics {
  static void light() => HapticFeedback.lightImpact();
  static void medium() => HapticFeedback.mediumImpact();
  static void heavy() => HapticFeedback.heavyImpact();
  static void selection() => HapticFeedback.selectionClick();
  static void success() {
    HapticFeedback.mediumImpact();
    Future.delayed(const Duration(milliseconds: 100), () {
      HapticFeedback.lightImpact();
    });
  }

  static void error() {
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 100), () {
      HapticFeedback.heavyImpact();
    });
  }

  static void warning() => HapticFeedback.mediumImpact();
  static void delete() => HapticFeedback.heavyImpact();
  static void reorder() => HapticFeedback.mediumImpact();
  static void toggle() => HapticFeedback.selectionClick();
}

// ============================================================
// ANIMATED COUNTER WIDGET
// ============================================================

// ── AnimatedCounter ────────────────────────────────────────────────────────
// Scramble effect: Phase 1 (0–55%) all digits cycle randomly.
// Phase 2 (55–100%) digits lock into place left-to-right (slot-machine settle).
// Non-digit characters (commas, dots, prefix, suffix) are shown immediately.
class AnimatedCounter extends StatefulWidget {
  final double value;
  final String prefix;
  final String suffix;
  final TextStyle? style;
  final Duration duration;
  final int decimals;

  const AnimatedCounter({
    super.key,
    required this.value,
    this.prefix = '',
    this.suffix = '',
    this.style,
    this.duration = const Duration(milliseconds: 900),
    this.decimals = 0,
  });

  @override
  State<AnimatedCounter> createState() => _AnimatedCounterState();
}

class _AnimatedCounterState extends State<AnimatedCounter>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  double _from = 0.0;
  final _rng = math.Random();
  static const _digits = '0123456789';

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(AnimatedCounter old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      _from = old.value;
      _ctrl
        ..duration = widget.duration
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _scramble(double progress) {
    const settleStart = 0.55;
    final target = widget.value;
    // Numeric value to display (interpolated so the number also counts up)
    final displayed = _from + (target - _from) * math.min(progress / settleStart, 1.0);
    final targetStr = displayed.toStringAsFixed(widget.decimals);

    if (progress >= 1.0) return '${widget.prefix}$targetStr${widget.suffix}';

    // Collect digit positions only
    final chars = targetStr.split('');
    final digitIndices = <int>[];
    for (int i = 0; i < chars.length; i++) {
      if (_digits.contains(chars[i])) digitIndices.add(i);
    }

    if (progress < settleStart) {
      // Phase 1: all digits scramble
      for (final idx in digitIndices) {
        chars[idx] = _digits[_rng.nextInt(10)];
      }
    } else {
      // Phase 2: settle left-to-right
      final settleProgress = (progress - settleStart) / (1.0 - settleStart);
      final settled = (settleProgress * digitIndices.length).floor();
      for (int i = settled; i < digitIndices.length; i++) {
        chars[digitIndices[i]] = _digits[_rng.nextInt(10)];
      }
    }

    return '${widget.prefix}${chars.join()}${widget.suffix}';
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          return Text(_scramble(_ctrl.value), style: widget.style);
        },
      ),
    );
  }
}

// ============================================================
// GLASSMORPHISM CONTAINER
// ============================================================

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final BorderRadius? borderRadius;
  final Border? border;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  const GlassContainer({
    super.key,
    required this.child,
    this.blur = 20,
    this.opacity = 0.1,
    this.borderRadius,
    this.border,
    this.padding,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = borderRadius ?? BorderRadius.circular(20);

    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: opacity)
                  : Colors.white.withValues(alpha: opacity + 0.6),
              borderRadius: radius,
              border: border ??
                  Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.15)
                        : Colors.white.withValues(alpha: 0.8),
                    width: 1.5,
                  ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

// ============================================================
// FADE IN ANIMATION WRAPPER
// ============================================================

class FadeInAnimation extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;
  final Curve curve;
  final Offset? slideOffset;

  const FadeInAnimation({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 400),
    this.delay = Duration.zero,
    this.curve = Curves.easeOutCubic,
    this.slideOffset,
  });

  @override
  State<FadeInAnimation> createState() => _FadeInAnimationState();
}

class _FadeInAnimationState extends State<FadeInAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: widget.curve),
    );
    _slideAnimation = Tween<Offset>(
      begin: widget.slideOffset ?? const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: widget.curve));

    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: widget.child,
      ),
    );
  }
}

// ============================================================
// STAGGERED ITEM WRAPPER (for lists)
// ============================================================

class StaggeredItem extends StatelessWidget {
  final int index;
  final Widget child;
  final Duration baseDelay;
  final Duration itemDelay;

  const StaggeredItem({
    super.key,
    required this.index,
    required this.child,
    this.baseDelay = const Duration(milliseconds: 100),
    this.itemDelay = const Duration(milliseconds: 50),
  });

  @override
  Widget build(BuildContext context) {
    return FadeInAnimation(
      delay: baseDelay + (itemDelay * index),
      slideOffset: const Offset(0, 0.15),
      child: child,
    );
  }
}

// ============================================================
// PULSE ANIMATION (for highlights)
// ============================================================

class PulseAnimation extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final double minScale;
  final double maxScale;

  const PulseAnimation({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 1500),
    this.minScale = 0.97,
    this.maxScale = 1.03,
  });

  @override
  State<PulseAnimation> createState() => _PulseAnimationState();
}

class _PulseAnimationState extends State<PulseAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _animation = Tween<double>(begin: widget.minScale, end: widget.maxScale)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(scale: _animation, child: widget.child);
  }
}

// ============================================================
// GRADIENT BORDER CONTAINER
// ============================================================

class GradientBorderContainer extends StatelessWidget {
  final Widget child;
  final List<Color> gradientColors;
  final double borderWidth;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;

  const GradientBorderContainer({
    super.key,
    required this.child,
    this.gradientColors = const [
      SemanticColors.info,
      SemanticColors.categories,
      SemanticColors.error,
    ],
    this.borderWidth = 2,
    this.borderRadius,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(24);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: radius,
      ),
      padding: EdgeInsets.all(borderWidth),
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor ?? AppStyles.getCardColor(context),
          borderRadius: BorderRadius.circular(radius.topLeft.x - borderWidth),
        ),
        child: child,
      ),
    );
  }
}

/// A custom page route with spring-approximated physics transitions.
///
/// Scale uses a back-out cubic that overshoots ~4% before settling at 1.0,
/// matching the feel of a SpringDescription(mass:1, stiffness:220, damping:22).
/// Full `animateWith(SpringSimulation)` requires a custom ModalRoute; this
/// achieves the same perceived result within PageRouteBuilder.
/// T1 — Push transition: go deeper into hierarchy.
///
/// Enter (new screen): scale 0.94→1.0 spring + slight upward slide + fade 0→1.
/// Exit (screen being covered): scale 1.0→0.96 + fade 1.0→0.6 via secondaryAnimation.
/// Feel: diving forward — the previous screen recedes as the new one emerges.
class FadeScalePageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  // Spring overshoot for the entering scale.
  static const _enterScale = Cubic(0.34, 1.56, 0.64, 1.0);
  // Crisp deceleration for fade — no overshoot on opacity.
  static const _fadeCurve = Cubic(0.25, 0.46, 0.45, 0.94);
  // Ease-out for the secondary (exit) animations.
  static const _exitCurve = Cubic(0.25, 0.46, 0.45, 0.94);

  FadeScalePageRoute({required this.page})
      : super(
          opaque: false,
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // ── Enter: new screen comes in ──────────────────────────────────
            final enterScale = Tween(begin: 0.94, end: 1.0)
                .chain(CurveTween(curve: _enterScale));
            final enterFade = Tween(begin: 0.0, end: 1.0)
                .chain(CurveTween(curve: _fadeCurve));
            final enterSlide = Tween(
              begin: const Offset(0.0, 0.022),
              end: Offset.zero,
            ).chain(CurveTween(curve: _enterScale));

            // ── Exit: screen being pushed away recedes slightly ─────────────
            final exitScale = Tween(begin: 1.0, end: 0.96)
                .chain(CurveTween(curve: _exitCurve));
            final exitFade = Tween(begin: 1.0, end: 0.6)
                .chain(CurveTween(curve: _exitCurve));

            return FadeTransition(
              opacity: secondaryAnimation.drive(exitFade),
              child: ScaleTransition(
                scale: secondaryAnimation.drive(exitScale),
                child: FadeTransition(
                  opacity: animation.drive(enterFade),
                  child: SlideTransition(
                    position: animation.drive(enterSlide),
                    child: ScaleTransition(
                      scale: animation.drive(enterScale),
                      child: child,
                    ),
                  ),
                ),
              ),
            );
          },
          transitionDuration: const Duration(milliseconds: 340),
          reverseTransitionDuration: const Duration(milliseconds: 220),
        );
}

/// T3 — Replace transition: same-hierarchy crossfade.
///
/// Use when swapping content at the same level (tab switch, state swap).
/// Outgoing fades + scales to 0.98; incoming fades + scales from 0.98.
/// Duration: 200ms. NOT for navigating deeper (use FadeScalePageRoute for that).
///
/// Usage:
/// ```dart
/// T3CrossFade(
///   stateKey: ValueKey(_selectedTab),
///   child: MyTabContent(...),
/// )
/// ```
class T3CrossFade extends StatelessWidget {
  final Widget child;
  final Object stateKey;
  const T3CrossFade({super.key, required this.stateKey, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) {
        final scale = Tween(begin: 0.98, end: 1.0)
            .animate(CurvedAnimation(parent: animation, curve: Curves.easeOut));
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: scale, child: child),
        );
      },
      child: KeyedSubtree(key: ValueKey(stateKey), child: child),
    );
  }
}

/// A wrapper widget that scales down when pressed and provides haptic feedback.
class BouncyButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onPressed;
  final double scaleFactor;
  final bool enableHaptics;

  const BouncyButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.scaleFactor = 0.96,
    this.enableHaptics = true,
  });

  @override
  State<BouncyButton> createState() => _BouncyButtonState();
}

class _BouncyButtonState extends State<BouncyButton>
    with SingleTickerProviderStateMixin {
  // Upper-bound 1.0 so controller can travel 0→1 (scale = lerp 1.0→scaleFactor).
  late final AnimationController _controller = AnimationController.unbounded(
    vsync: this,
    value: 0.0,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Drives the scale value: controller value 0 = normal, 1 = fully pressed.
  double get _scale =>
      1.0 - (1.0 - widget.scaleFactor) * _controller.value.clamp(0.0, 1.2);

  void _press() {
    _controller.animateWith(
      SpringSimulation(AppSprings.crisp, _controller.value, 1.0, 0.0),
    );
    if (widget.enableHaptics) Haptics.light();
  }

  void _release() {
    _controller.animateWith(
      SpringSimulation(AppSprings.bouncy, _controller.value, 0.0, 0.0),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _press(),
      onTapUp: (_) {
        _release();
        widget.onPressed();
      },
      onTapCancel: _release,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => Transform.scale(
          scale: _scale,
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}

// ============================================================
// SHAKE ANIMATION (for validation errors)
// ============================================================

/// Shakes the child widget horizontally - useful for validation errors
class ShakeAnimation extends StatefulWidget {
  final Widget child;
  final bool shake;
  final VoidCallback? onShakeComplete;
  final double offset;

  const ShakeAnimation({
    super.key,
    required this.child,
    this.shake = false,
    this.onShakeComplete,
    this.offset = 10.0,
  });

  @override
  State<ShakeAnimation> createState() => ShakeAnimationState();
}

class ShakeAnimationState extends State<ShakeAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppDurations.shake,
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticIn),
    );
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _controller.reset();
        widget.onShakeComplete?.call();
      }
    });

    if (widget.shake) {
      _startShake();
    }
  }

  @override
  void didUpdateWidget(ShakeAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shake && !oldWidget.shake) {
      _startShake();
    }
  }

  void _startShake() {
    Haptics.error();
    _controller.forward();
  }

  /// Call this method externally to trigger the shake
  void shake() {
    _startShake();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _getOffset(double animation) {
    // Creates a dampening oscillation effect
    final sinValue = math.sin(animation * math.pi * 4);
    final dampening = 1 - animation;
    return sinValue * widget.offset * dampening;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_getOffset(_animation.value), 0),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

// ============================================================
// SUCCESS PULSE (for save confirmations)
// ============================================================

/// Briefly pulses with a success color overlay
class SuccessPulse extends StatefulWidget {
  final Widget child;
  final bool trigger;
  final Color? color;
  final VoidCallback? onComplete;

  const SuccessPulse({
    super.key,
    required this.child,
    this.trigger = false,
    this.color,
    this.onComplete,
  });

  @override
  State<SuccessPulse> createState() => SuccessPulseState();
}

class SuccessPulseState extends State<SuccessPulse>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppDurations.slow,
    );
    _animation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.3), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.3, end: 0.0), weight: 70),
    ]).animate(
        CurvedAnimation(parent: _controller, curve: MotionCurves.standard));

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete?.call();
      }
    });

    if (widget.trigger) {
      _pulse();
    }
  }

  @override
  void didUpdateWidget(SuccessPulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger && !oldWidget.trigger) {
      _pulse();
    }
  }

  void _pulse() {
    Haptics.success();
    _controller.forward(from: 0);
  }

  /// Call this method externally to trigger the pulse
  void pulse() {
    _pulse();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pulseColor = widget.color ?? SemanticColors.getSuccess(context);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: Radii.cardRadius,
            boxShadow: _animation.value > 0
                ? [
                    BoxShadow(
                      color: pulseColor.withValues(alpha: _animation.value),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

// ============================================================
// SLIDE TRANSITION HELPERS
// ============================================================

/// Slide in from different directions
class SlideInAnimation extends StatefulWidget {
  final Widget child;
  final SlideDirection direction;
  final Duration duration;
  final Duration delay;
  final Curve curve;

  const SlideInAnimation({
    super.key,
    required this.child,
    this.direction = SlideDirection.bottom,
    this.duration = const Duration(milliseconds: 400),
    this.delay = Duration.zero,
    this.curve = Curves.easeOutCubic,
  });

  @override
  State<SlideInAnimation> createState() => _SlideInAnimationState();
}

enum SlideDirection { left, right, top, bottom }

class _SlideInAnimationState extends State<SlideInAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);

    final beginOffset = switch (widget.direction) {
      SlideDirection.left => const Offset(-1.0, 0),
      SlideDirection.right => const Offset(1.0, 0),
      SlideDirection.top => const Offset(0, -1.0),
      SlideDirection.bottom => const Offset(0, 1.0),
    };

    _slideAnimation = Tween<Offset>(begin: beginOffset, end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: widget.curve));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _controller, curve: widget.curve));

    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: widget.child,
      ),
    );
  }
}

// ============================================================
// SCALE IN ANIMATION
// ============================================================

/// Scale in from small to full size
class ScaleInAnimation extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;
  final Curve curve;
  final double beginScale;

  const ScaleInAnimation({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 300),
    this.delay = Duration.zero,
    this.curve = Curves.easeOutBack,
    this.beginScale = 0.0,
  });

  @override
  State<ScaleInAnimation> createState() => _ScaleInAnimationState();
}

class _ScaleInAnimationState extends State<ScaleInAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _scaleAnimation = Tween<double>(begin: widget.beginScale, end: 1.0)
        .animate(CurvedAnimation(parent: _controller, curve: widget.curve));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _controller, curve: MotionCurves.standard));

    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );
  }
}

// ============================================================
// ANIMATED VISIBILITY
// ============================================================

/// Smoothly animates visibility changes
class AnimatedVisibility extends StatelessWidget {
  final bool visible;
  final Widget child;
  final Duration duration;
  final Curve curve;

  const AnimatedVisibility({
    super.key,
    required this.visible,
    required this.child,
    this.duration = const Duration(milliseconds: 200),
    this.curve = Curves.easeInOut,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: visible ? 1.0 : 0.0,
      duration: duration,
      curve: curve,
      child: AnimatedScale(
        scale: visible ? 1.0 : 0.95,
        duration: duration,
        curve: curve,
        child: IgnorePointer(
          ignoring: !visible,
          child: child,
        ),
      ),
    );
  }
}

// ============================================================
// CUSTOM PAGE TRANSITIONS
// ============================================================

/// Slide from right page transition (iOS-style)
class SlideRightPageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  SlideRightPageRoute({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final tween = Tween(begin: const Offset(1.0, 0.0), end: Offset.zero)
                .chain(CurveTween(curve: MotionCurves.standard));
            final fadeTween = Tween(begin: 0.0, end: 1.0)
                .chain(CurveTween(curve: MotionCurves.standard));

            return SlideTransition(
              position: animation.drive(tween),
              child: FadeTransition(
                opacity: animation.drive(fadeTween),
                child: child,
              ),
            );
          },
          transitionDuration: AppDurations.pageTransition,
          reverseTransitionDuration: AppDurations.pageTransitionReverse,
        );
}

/// Slide up from bottom page transition (modal-style)
class SlideUpPageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  SlideUpPageRoute({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final tween = Tween(begin: const Offset(0.0, 1.0), end: Offset.zero)
                .chain(CurveTween(curve: MotionCurves.standard));

            return SlideTransition(
              position: animation.drive(tween),
              child: child,
            );
          },
          transitionDuration: AppDurations.pageTransition,
          reverseTransitionDuration: AppDurations.pageTransitionReverse,
        );
}

// ============================================================
// NUMBER TICKER (alternative to AnimatedCounter)
// ============================================================

/// A more visually engaging number ticker with rolling digits
class NumberTicker extends StatelessWidget {
  final double value;
  final String prefix;
  final String suffix;
  final TextStyle? style;
  final Duration duration;
  final int decimals;

  const NumberTicker({
    super.key,
    required this.value,
    this.prefix = '',
    this.suffix = '',
    this.style,
    this.duration = const Duration(milliseconds: 800),
    this.decimals = 0,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: duration,
      curve: MotionCurves.emphasis,
      builder: (context, animatedValue, child) {
        return Text(
          '$prefix${animatedValue.toStringAsFixed(decimals)}$suffix',
          style: style,
        );
      },
    );
  }
}

// ============================================================
// FLOATING ANIMATION (subtle up/down float)
// ============================================================

/// Creates a subtle floating effect
class FloatingAnimation extends StatefulWidget {
  final Widget child;
  final double offset;
  final Duration duration;

  const FloatingAnimation({
    super.key,
    required this.child,
    this.offset = 6.0,
    this.duration = const Duration(milliseconds: 2000),
  });

  @override
  State<FloatingAnimation> createState() => _FloatingAnimationState();
}

class _FloatingAnimationState extends State<FloatingAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _animation = Tween<double>(begin: -widget.offset, end: widget.offset)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _animation.value),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

// ============================================================
// TYPEWRITER TEXT ANIMATION
// ============================================================

/// Animates text appearing character by character
class TypewriterText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Duration characterDuration;
  final VoidCallback? onComplete;

  const TypewriterText({
    super.key,
    required this.text,
    this.style,
    this.characterDuration = const Duration(milliseconds: 50),
    this.onComplete,
  });

  @override
  State<TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<TypewriterText> {
  String _displayText = '';
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _animateText();
  }

  void _animateText() async {
    while (_currentIndex < widget.text.length && mounted) {
      await Future.delayed(widget.characterDuration);
      if (mounted) {
        setState(() {
          _currentIndex++;
          _displayText = widget.text.substring(0, _currentIndex);
        });
      }
    }
    widget.onComplete?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Text(_displayText, style: widget.style);
  }
}

// ============================================================
// ANIMATED GRADIENT BORDER
// ============================================================

/// A container with an animated rotating gradient border
class AnimatedGradientBorder extends StatefulWidget {
  final Widget child;
  final List<Color> colors;
  final double borderWidth;
  final BorderRadius? borderRadius;
  final Duration duration;

  const AnimatedGradientBorder({
    super.key,
    required this.child,
    this.colors = const [
      Color(0xFF667EEA),
      Color(0xFF764BA2),
      Color(0xFFF093FB),
      Color(0xFF667EEA),
    ],
    this.borderWidth = 2,
    this.borderRadius,
    this.duration = const Duration(seconds: 3),
  });

  @override
  State<AnimatedGradientBorder> createState() => _AnimatedGradientBorderState();
}

class _AnimatedGradientBorderState extends State<AnimatedGradientBorder>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.borderRadius ?? Radii.cardRadius;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: SweepGradient(
              colors: widget.colors,
              transform: GradientRotation(_controller.value * 2 * math.pi),
            ),
            borderRadius: radius,
          ),
          padding: EdgeInsets.all(widget.borderWidth),
          child: Container(
            decoration: BoxDecoration(
              color: AppStyles.getCardColor(context),
              borderRadius: BorderRadius.circular(
                radius.topLeft.x - widget.borderWidth,
              ),
            ),
            child: widget.child,
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LoadingDots — SYS-02
// 3-dot wave animation for async operations. Drop-in for CupertinoActivityIndicator.
// ─────────────────────────────────────────────────────────────────────────────
class LoadingDots extends StatefulWidget {
  final Color? color;
  final double dotSize;
  final double spacing;

  const LoadingDots({
    super.key,
    this.color,
    this.dotSize = 7.0,
    this.spacing = 5.0,
  });

  @override
  State<LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<LoadingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dotColor = widget.color ??
        (Theme.of(context).brightness == Brightness.dark
            ? Colors.white54
            : Colors.black45);
    return SizedBox(
      height: widget.dotSize * 2,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          return AnimatedBuilder(
            animation: _ctrl,
            builder: (context, _) {
              // Each dot is offset by 0.33 in the cycle → wave effect
              final phase = (_ctrl.value - i / 3).remainder(1.0);
              // Map phase 0..0.5 → 0..1..0 (sine wave only in first half)
              final t = (math.sin(phase * 2 * math.pi) + 1) / 2;
              final offset = -widget.dotSize * 0.6 * t;
              return Padding(
                padding: EdgeInsets.symmetric(horizontal: widget.spacing / 2),
                child: Transform.translate(
                  offset: Offset(0, offset),
                  child: Container(
                    width: widget.dotSize,
                    height: widget.dotSize,
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SuccessCheckmark — SYS-02
// Animated path-draw checkmark for completion states (400ms draw animation).
// ─────────────────────────────────────────────────────────────────────────────
class SuccessCheckmark extends StatefulWidget {
  final double size;
  final Color? color;
  final Color? circleColor;
  final Duration duration;

  const SuccessCheckmark({
    super.key,
    this.size = 56.0,
    this.color,
    this.circleColor,
    this.duration = const Duration(milliseconds: 500),
  });

  @override
  State<SuccessCheckmark> createState() => _SuccessCheckmarkState();
}

class _SuccessCheckmarkState extends State<SuccessCheckmark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _circleAnim;
  late final Animation<double> _checkAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _circleAnim = CurvedAnimation(
        parent: _ctrl, curve: const Interval(0.0, 0.6, curve: Curves.easeOut));
    _checkAnim = CurvedAnimation(
        parent: _ctrl, curve: const Interval(0.4, 1.0, curve: Curves.easeOut));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final checkColor = widget.color ?? SemanticColors.success;
    final circleColor = widget.circleColor ??
        checkColor.withValues(alpha: 0.15);

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: CustomPaint(
            painter: _CheckmarkPainter(
              circleProgress: _circleAnim.value,
              checkProgress: _checkAnim.value,
              checkColor: checkColor,
              circleColor: circleColor,
              strokeWidth: widget.size * 0.06,
            ),
          ),
        );
      },
    );
  }
}

class _CheckmarkPainter extends CustomPainter {
  final double circleProgress;
  final double checkProgress;
  final Color checkColor;
  final Color circleColor;
  final double strokeWidth;

  _CheckmarkPainter({
    required this.circleProgress,
    required this.checkProgress,
    required this.checkColor,
    required this.circleColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - strokeWidth / 2;

    // Draw circle fill background
    final fillPaint = Paint()..color = circleColor;
    canvas.drawCircle(center, radius * circleProgress, fillPaint);

    // Draw circle stroke
    final circlePaint = Paint()
      ..color = checkColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * circleProgress,
      false,
      circlePaint,
    );

    if (checkProgress <= 0) return;

    // Checkmark path: two segments — short left arm then long right arm
    final s = size.width;
    final p1 = Offset(s * 0.22, s * 0.52); // start of tick
    final p2 = Offset(s * 0.42, s * 0.70); // bottom of tick
    final p3 = Offset(s * 0.76, s * 0.32); // top right

    // Total path length (approx) for interpolation
    final seg1Len = (p2 - p1).distance;
    final seg2Len = (p3 - p2).distance;
    final totalLen = seg1Len + seg2Len;
    final drawn = checkProgress * totalLen;

    final checkPaint = Paint()
      ..color = checkColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    path.moveTo(p1.dx, p1.dy);

    if (drawn <= seg1Len) {
      final t = drawn / seg1Len;
      path.lineTo(p1.dx + (p2.dx - p1.dx) * t, p1.dy + (p2.dy - p1.dy) * t);
    } else {
      path.lineTo(p2.dx, p2.dy);
      final t = (drawn - seg1Len) / seg2Len;
      path.lineTo(p2.dx + (p3.dx - p2.dx) * t, p2.dy + (p3.dy - p2.dy) * t);
    }
    canvas.drawPath(path, checkPaint);
  }

  @override
  bool shouldRepaint(_CheckmarkPainter old) =>
      old.circleProgress != circleProgress || old.checkProgress != checkProgress;
}

// ─────────────────────────────────────────────────────────────────────────────
// SwipeDeleteIndicator — SYS-02
// Red (delete) / green (archive) sliding background for list items.
// Wrap any list tile with this and set alignment to reveal the correct side.
// ─────────────────────────────────────────────────────────────────────────────
class SwipeActionBackground extends StatelessWidget {
  /// Alignment.centerLeft = action on left (e.g. edit/archive)
  /// Alignment.centerRight = action on right (e.g. delete)
  final Alignment alignment;
  final Color color;
  final IconData icon;
  final String label;

  const SwipeActionBackground({
    super.key,
    required this.alignment,
    required this.color,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final isLeft = alignment == Alignment.centerLeft;
    return Container(
      color: color,
      alignment: alignment,
      padding: EdgeInsets.only(
        left: isLeft ? Spacing.xl : 0,
        right: isLeft ? 0 : Spacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 22),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: TypeScale.caption,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
