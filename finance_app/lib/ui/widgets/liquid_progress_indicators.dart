import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';

/// Circular liquid progress indicator with wave animation
class LiquidCircularProgress extends StatefulWidget {
  final double progress;
  final double size;
  final Color? color;
  final Color? backgroundColor;
  final Widget? center;

  const LiquidCircularProgress({
    super.key,
    required this.progress,
    this.size = 120.0,
    this.color,
    this.backgroundColor,
    this.center,
  });

  @override
  State<LiquidCircularProgress> createState() => _LiquidCircularProgressState();
}

class _LiquidCircularProgressState extends State<LiquidCircularProgress>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
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
    final backgroundColor = widget.backgroundColor ??
        (Theme.of(context).brightness == Brightness.dark
            ? Colors.grey[800]!
            : Colors.grey[200]!);

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background circle
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: backgroundColor,
            ),
          ),
          // Liquid wave
          ClipOval(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return CustomPaint(
                  size: Size(widget.size, widget.size),
                  painter: LiquidCircularPainter(
                    progress: widget.progress,
                    wavePhase: _controller.value,
                    color: color,
                  ),
                );
              },
            ),
          ),
          // Center content
          if (widget.center != null) widget.center!,
        ],
      ),
    );
  }
}

class LiquidCircularPainter extends CustomPainter {
  final double progress;
  final double wavePhase;
  final Color color;

  LiquidCircularPainter({
    required this.progress,
    required this.wavePhase,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.width / 2;
    final center = Offset(size.width / 2, size.height / 2);
    final fillHeight = size.height * (1 - progress);

    final path = Path();
    const waveHeight = 8.0;

    // Start from left edge
    path.moveTo(0, fillHeight);

    // Draw wave
    for (double x = 0; x <= size.width; x += 2) {
      final normalized = x / size.width;
      final wave1 =
          math.sin((normalized * math.pi * 2) + (wavePhase * math.pi * 2)) *
              waveHeight;
      final wave2 =
          math.sin((normalized * math.pi * 3) + (wavePhase * math.pi * 3)) *
              (waveHeight * 0.5);
      path.lineTo(x, fillHeight + wave1 + wave2);
    }

    // Complete the path
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    // Clip to circle
    canvas.clipPath(
        Path()..addOval(Rect.fromCircle(center: center, radius: radius)));

    // Draw liquid
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, paint);

    // Draw lighter overlay wave
    final overlayPath = Path();
    overlayPath.moveTo(0, fillHeight - 3);

    for (double x = 0; x <= size.width; x += 2) {
      final normalized = x / size.width;
      final wave =
          math.sin((normalized * math.pi * 2.5) + (wavePhase * math.pi * 2.5)) *
              (waveHeight * 0.7);
      overlayPath.lineTo(x, fillHeight - 3 + wave);
    }

    overlayPath.lineTo(size.width, size.height);
    overlayPath.lineTo(0, size.height);
    overlayPath.close();

    final overlayPaint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;

    canvas.drawPath(overlayPath, overlayPaint);
  }

  @override
  bool shouldRepaint(LiquidCircularPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.wavePhase != wavePhase;
}

/// Linear liquid progress bar with wave animation
class LiquidLinearProgress extends StatefulWidget {
  final double progress;
  final double height;
  final double? width;
  final Color? color;
  final Color? backgroundColor;
  final BorderRadius? borderRadius;

  const LiquidLinearProgress({
    super.key,
    required this.progress,
    this.height = 12.0,
    this.width,
    this.color,
    this.backgroundColor,
    this.borderRadius,
  });

  @override
  State<LiquidLinearProgress> createState() => _LiquidLinearProgressState();
}

class _LiquidLinearProgressState extends State<LiquidLinearProgress>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
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
    final backgroundColor = widget.backgroundColor ??
        (Theme.of(context).brightness == Brightness.dark
            ? Colors.grey[800]!
            : Colors.grey[200]!);

    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius:
            widget.borderRadius ?? BorderRadius.circular(widget.height / 2),
      ),
      child: ClipRRect(
        borderRadius:
            widget.borderRadius ?? BorderRadius.circular(widget.height / 2),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return CustomPaint(
              painter: LiquidLinearPainter(
                progress: widget.progress,
                wavePhase: _controller.value,
                color: color,
              ),
            );
          },
        ),
      ),
    );
  }
}

class LiquidLinearPainter extends CustomPainter {
  final double progress;
  final double wavePhase;
  final Color color;

  LiquidLinearPainter({
    required this.progress,
    required this.wavePhase,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final progressWidth = size.width * progress;
    final path = Path();
    final waveHeight = size.height * 0.3;

    path.moveTo(0, 0);

    // Draw top wave
    for (double x = 0; x <= progressWidth; x += 2) {
      final normalized = x / size.width;
      final wave =
          math.sin((normalized * math.pi * 4) + (wavePhase * math.pi * 2)) *
              waveHeight;
      path.lineTo(x, wave);
    }

    // Complete the path
    path.lineTo(progressWidth, size.height);
    path.lineTo(0, size.height);
    path.close();

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, paint);

    // Draw gradient overlay
    final gradient = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [
        color,
        color.withValues(alpha: 0.7),
        color,
      ],
      stops: [
        0.0,
        wavePhase,
        1.0,
      ],
    );

    final gradientPaint = Paint()
      ..shader = gradient
          .createShader(Rect.fromLTWH(0, 0, progressWidth, size.height));

    canvas.drawRect(
        Rect.fromLTWH(0, 0, progressWidth, size.height), gradientPaint);
  }

  @override
  bool shouldRepaint(LiquidLinearPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.wavePhase != wavePhase;
}

/// Pulsing dot progress indicator
class PulsingDotProgress extends StatefulWidget {
  final int dotCount;
  final double dotSize;
  final Color? color;
  final Duration duration;

  const PulsingDotProgress({
    super.key,
    this.dotCount = 3,
    this.dotSize = 12.0,
    this.color,
    this.duration = const Duration(milliseconds: 1200),
  });

  @override
  State<PulsingDotProgress> createState() => _PulsingDotProgressState();
}

class _PulsingDotProgressState extends State<PulsingDotProgress>
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

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(widget.dotCount, (index) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final delay = index / widget.dotCount;
            final progress = (_controller.value + delay) % 1.0;
            final scale = 0.5 + (math.sin(progress * math.pi * 2) * 0.5);
            final opacity = 0.3 + (scale * 0.7);

            return Container(
              margin: EdgeInsets.symmetric(horizontal: widget.dotSize * 0.3),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: widget.dotSize,
                  height: widget.dotSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: opacity),
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }
}

/// Spinning arc progress indicator
class SpinningArcProgress extends StatefulWidget {
  final double size;
  final Color? color;
  final double strokeWidth;

  const SpinningArcProgress({
    super.key,
    this.size = 40.0,
    this.color,
    this.strokeWidth = 4.0,
  });

  @override
  State<SpinningArcProgress> createState() => _SpinningArcProgressState();
}

class _SpinningArcProgressState extends State<SpinningArcProgress>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
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
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: SpinningArcPainter(
              progress: _controller.value,
              color: color,
              strokeWidth: widget.strokeWidth,
            ),
          );
        },
      ),
    );
  }
}

class SpinningArcPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  SpinningArcPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Draw rotating arc
    final startAngle = progress * math.pi * 2;
    const sweepAngle = math.pi * 1.5;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      paint,
    );

    // Draw second arc with fade
    final fadePaint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle + math.pi,
      math.pi * 0.5,
      false,
      fadePaint,
    );
  }

  @override
  bool shouldRepaint(SpinningArcPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// Liquid loading skeleton for content placeholders
class LiquidSkeleton extends StatefulWidget {
  final double? width;
  final double height;
  final BorderRadius? borderRadius;

  const LiquidSkeleton({
    super.key,
    this.width,
    this.height = 20.0,
    this.borderRadius,
  });

  @override
  State<LiquidSkeleton> createState() => _LiquidSkeletonState();
}

class _LiquidSkeletonState extends State<LiquidSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
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
    final baseColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final highlightColor = isDark ? Colors.grey[700]! : Colors.grey[100]!;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius:
                widget.borderRadius ?? BorderRadius.circular(widget.height / 2),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                baseColor,
                highlightColor,
                baseColor,
              ],
              stops: [
                math.max(0.0, _controller.value - 0.3),
                _controller.value,
                math.min(1.0, _controller.value + 0.3),
              ],
            ),
          ),
        );
      },
    );
  }
}
