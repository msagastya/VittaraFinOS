import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';

/// Liquid swipe transition animation
class LiquidSwipeTransition extends StatefulWidget {
  final Widget child;
  final Duration duration;

  const LiquidSwipeTransition({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 600),
  });

  @override
  State<LiquidSwipeTransition> createState() => _LiquidSwipeTransitionState();
}

class _LiquidSwipeTransitionState extends State<LiquidSwipeTransition>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    );
    _controller.forward();
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
        return ClipPath(
          clipper: LiquidClipper(_animation.value),
          child: widget.child,
        );
      },
    );
  }
}

class LiquidClipper extends CustomClipper<Path> {
  final double progress;

  LiquidClipper(this.progress);

  @override
  Path getClip(Size size) {
    final path = Path();

    if (progress >= 1.0) {
      path.addRect(Rect.fromLTWH(0, 0, size.width, size.height));
      return path;
    }

    final waveHeight = 50.0 * (1 - progress);
    final progressHeight = size.height * progress;

    path.moveTo(0, size.height - progressHeight);

    for (double i = 0; i <= size.width; i++) {
      final normalized = i / size.width;
      final wave = math.sin(normalized * math.pi * 4 + progress * math.pi * 2) * waveHeight;
      path.lineTo(i, size.height - progressHeight + wave);
    }

    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(LiquidClipper oldClipper) => oldClipper.progress != progress;
}

/// Morphing container with liquid effect
class LiquidMorphingContainer extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Color? color;

  const LiquidMorphingContainer({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 400),
    this.color,
  });

  @override
  State<LiquidMorphingContainer> createState() => _LiquidMorphingContainerState();
}

class _LiquidMorphingContainerState extends State<LiquidMorphingContainer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: 1.0 + (_controller.value * 0.05),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(
                Radii.xxl * (1 + _controller.value * 0.3),
              ),
              color: widget.color,
            ),
            child: widget.child,
          ),
        );
      },
    );
  }
}

/// Shimmer liquid loading effect
class LiquidShimmer extends StatefulWidget {
  final Widget child;
  final Color? baseColor;
  final Color? highlightColor;
  final Duration duration;

  const LiquidShimmer({
    super.key,
    required this.child,
    this.baseColor,
    this.highlightColor,
    this.duration = const Duration(milliseconds: 1500),
  });

  @override
  State<LiquidShimmer> createState() => _LiquidShimmerState();
}

class _LiquidShimmerState extends State<LiquidShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = widget.baseColor ??
        (isDark ? Colors.grey[800]! : Colors.grey[300]!);
    final highlightColor = widget.highlightColor ??
        (isDark ? Colors.grey[700]! : Colors.grey[100]!);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                baseColor,
                highlightColor,
                baseColor,
              ],
              stops: [
                _controller.value - 0.3,
                _controller.value,
                _controller.value + 0.3,
              ].map((e) => e.clamp(0.0, 1.0)).toList(),
            ).createShader(bounds);
          },
          child: widget.child,
        );
      },
    );
  }
}

/// Wave animation for progress indicators
class LiquidWaveProgress extends StatefulWidget {
  final double progress;
  final double height;
  final Color? color;
  final Duration duration;

  const LiquidWaveProgress({
    super.key,
    required this.progress,
    this.height = 200.0,
    this.color,
    this.duration = const Duration(milliseconds: 2000),
  });

  @override
  State<LiquidWaveProgress> createState() => _LiquidWaveProgressState();
}

class _LiquidWaveProgressState extends State<LiquidWaveProgress>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? SemanticColors.getPrimary(context);

    return SizedBox(
      height: widget.height,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: WavePainter(
              progress: widget.progress,
              wavePhase: _controller.value,
              color: color,
            ),
            child: Container(),
          );
        },
      ),
    );
  }
}

class WavePainter extends CustomPainter {
  final double progress;
  final double wavePhase;
  final Color color;

  WavePainter({
    required this.progress,
    required this.wavePhase,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    final waveHeight = 10.0;
    final progressHeight = size.height * (1 - progress);

    path.moveTo(0, progressHeight);

    for (double i = 0; i <= size.width; i++) {
      final normalized = i / size.width;
      final wave1 = math.sin((normalized * math.pi * 2) + (wavePhase * math.pi * 2)) * waveHeight;
      final wave2 = math.sin((normalized * math.pi * 3) + (wavePhase * math.pi * 3)) * (waveHeight * 0.5);
      path.lineTo(i, progressHeight + wave1 + wave2);
    }

    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);

    // Draw lighter overlay wave
    final overlayPaint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;

    final overlayPath = Path();
    overlayPath.moveTo(0, progressHeight - 5);

    for (double i = 0; i <= size.width; i++) {
      final normalized = i / size.width;
      final wave = math.sin((normalized * math.pi * 2.5) + (wavePhase * math.pi * 2.5)) * (waveHeight * 0.7);
      overlayPath.lineTo(i, progressHeight - 5 + wave);
    }

    overlayPath.lineTo(size.width, size.height);
    overlayPath.lineTo(0, size.height);
    overlayPath.close();

    canvas.drawPath(overlayPath, overlayPaint);
  }

  @override
  bool shouldRepaint(WavePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.wavePhase != wavePhase;
}

/// Ripple effect animation
class LiquidRipple extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color? rippleColor;

  const LiquidRipple({
    super.key,
    required this.child,
    this.onTap,
    this.rippleColor,
  });

  @override
  State<LiquidRipple> createState() => _LiquidRippleState();
}

class _LiquidRippleState extends State<LiquidRipple>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Offset? _tapPosition;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AppDurations.medium,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap(TapDownDetails details) {
    setState(() {
      _tapPosition = details.localPosition;
    });
    _controller.forward(from: 0.0);
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTap,
      child: CustomPaint(
        painter: _tapPosition != null
            ? RipplePainter(
                progress: _controller,
                tapPosition: _tapPosition!,
                color: widget.rippleColor ??
                    SemanticColors.getPrimary(context).withValues(alpha: 0.3),
              )
            : null,
        child: widget.child,
      ),
    );
  }
}

class RipplePainter extends CustomPainter {
  final Animation<double> progress;
  final Offset tapPosition;
  final Color color;

  RipplePainter({
    required this.progress,
    required this.tapPosition,
    required this.color,
  }) : super(repaint: progress);

  @override
  void paint(Canvas canvas, Size size) {
    if (progress.value == 0) return;

    final maxRadius = math.sqrt(
      math.pow(size.width, 2) + math.pow(size.height, 2),
    );

    final radius = maxRadius * progress.value;
    final paint = Paint()
      ..color = color.withValues(alpha: 1.0 - progress.value)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(tapPosition, radius, paint);
  }

  @override
  bool shouldRepaint(RipplePainter oldDelegate) => true;
}
