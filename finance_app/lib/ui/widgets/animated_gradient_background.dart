import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';

/// Animated gradient background with smooth color transitions
class AnimatedGradientBackground extends StatefulWidget {
  final Widget child;
  final List<Color> colors;
  final Duration duration;
  final AlignmentGeometry begin;
  final AlignmentGeometry end;

  const AnimatedGradientBackground({
    super.key,
    required this.child,
    this.colors = const [
      Color(0xFF667EEA),
      Color(0xFF764BA2),
      Color(0xFF667EEA),
    ],
    this.duration = const Duration(seconds: 4),
    this.begin = Alignment.topLeft,
    this.end = Alignment.bottomRight,
  });

  @override
  State<AnimatedGradientBackground> createState() =>
      _AnimatedGradientBackgroundState();
}

class _AnimatedGradientBackgroundState extends State<AnimatedGradientBackground>
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
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: widget.begin,
              end: widget.end,
              colors: widget.colors,
              stops: _generateStops(),
            ),
          ),
          child: widget.child,
        );
      },
    );
  }

  List<double> _generateStops() {
    final count = widget.colors.length;
    final progress = _controller.value;

    return List.generate(count, (index) {
      final base = index / (count - 1);
      final offset = math.sin(progress * math.pi * 2) * 0.1;
      return (base + offset).clamp(0.0, 1.0);
    });
  }
}

/// Mesh gradient background with multiple animated gradient layers
class MeshGradientBackground extends StatefulWidget {
  final Widget child;
  final Duration duration;

  const MeshGradientBackground({
    super.key,
    required this.child,
    this.duration = const Duration(seconds: 8),
  });

  @override
  State<MeshGradientBackground> createState() => _MeshGradientBackgroundState();
}

class _MeshGradientBackgroundState extends State<MeshGradientBackground>
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
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          children: [
            // Base gradient
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF667EEA).withValues(alpha: 0.6),
                    Color(0xFF764BA2).withValues(alpha: 0.6),
                  ],
                ),
              ),
            ),
            // Animated overlay gradient
            Transform.rotate(
              angle: _controller.value * math.pi * 2,
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(
                      math.cos(_controller.value * math.pi * 2) * 0.5,
                      math.sin(_controller.value * math.pi * 2) * 0.5,
                    ),
                    radius: 1.5,
                    colors: [
                      Colors.purple.withValues(alpha: 0.3),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // Second animated overlay
            Transform.rotate(
              angle: -_controller.value * math.pi * 2,
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(
                      math.sin(_controller.value * math.pi * 2) * 0.5,
                      math.cos(_controller.value * math.pi * 2) * 0.5,
                    ),
                    radius: 1.5,
                    colors: [
                      Colors.blue.withValues(alpha: 0.3),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            widget.child,
          ],
        );
      },
    );
  }
}

/// Gradient orbs that float around the screen
class FloatingGradientOrbs extends StatefulWidget {
  final Widget child;
  final int orbCount;
  final Duration duration;

  const FloatingGradientOrbs({
    super.key,
    required this.child,
    this.orbCount = 3,
    this.duration = const Duration(seconds: 10),
  });

  @override
  State<FloatingGradientOrbs> createState() => _FloatingGradientOrbsState();
}

class _FloatingGradientOrbsState extends State<FloatingGradientOrbs>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<OrbData> _orbs;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    )..repeat();

    // Generate random orb data
    _orbs = List.generate(
      widget.orbCount,
      (index) => OrbData(
        color: ColorPalettes
            .gradientPresets[index % ColorPalettes.gradientPresets.length],
        offsetX: (index * 0.3) - 0.3,
        offsetY: (index * 0.25) - 0.25,
        size: 200.0 + (index * 50.0),
        speed: 1.0 + (index * 0.2),
      ),
    );
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
        return Stack(
          children: [
            // Render orbs
            ..._orbs.map((orb) => _buildOrb(orb)),
            // Child content
            widget.child,
          ],
        );
      },
    );
  }

  Widget _buildOrb(OrbData orb) {
    final progress = _controller.value * orb.speed;
    final x = orb.offsetX + math.cos(progress * math.pi * 2) * 0.3;
    final y = orb.offsetY + math.sin(progress * math.pi * 2) * 0.3;

    return Positioned.fill(
      child: Align(
        alignment: Alignment(x, y),
        child: Container(
          width: orb.size,
          height: orb.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                orb.color.withValues(alpha: 0.3),
                orb.color.withValues(alpha: 0.1),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class OrbData {
  final Color color;
  final double offsetX;
  final double offsetY;
  final double size;
  final double speed;

  OrbData({
    required this.color,
    required this.offsetX,
    required this.offsetY,
    required this.size,
    required this.speed,
  });
}

/// Subtle animated gradient for cards and containers
class SubtleGradientAnimation extends StatefulWidget {
  final Widget child;
  final List<Color> colors;
  final Duration duration;

  const SubtleGradientAnimation({
    super.key,
    required this.child,
    this.colors = const [
      Color(0xFF667EEA),
      Color(0xFF764BA2),
    ],
    this.duration = const Duration(seconds: 3),
  });

  @override
  State<SubtleGradientAnimation> createState() =>
      _SubtleGradientAnimationState();
}

class _SubtleGradientAnimationState extends State<SubtleGradientAnimation>
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
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.lerp(
                Alignment.topLeft,
                Alignment.topRight,
                _controller.value,
              )!,
              end: Alignment.lerp(
                Alignment.bottomRight,
                Alignment.bottomLeft,
                _controller.value,
              )!,
              colors:
                  widget.colors.map((c) => c.withValues(alpha: 0.8)).toList(),
            ),
          ),
          child: widget.child,
        );
      },
    );
  }
}

/// Pulsing gradient border animation
class PulsingGradientBorder extends StatefulWidget {
  final Widget child;
  final double borderWidth;
  final List<Color> gradientColors;
  final Duration duration;
  final double borderRadius;

  const PulsingGradientBorder({
    super.key,
    required this.child,
    this.borderWidth = 2.0,
    this.gradientColors = const [
      Color(0xFF667EEA),
      Color(0xFF764BA2),
    ],
    this.duration = const Duration(seconds: 2),
    this.borderRadius = 16.0,
  });

  @override
  State<PulsingGradientBorder> createState() => _PulsingGradientBorderState();
}

class _PulsingGradientBorderState extends State<PulsingGradientBorder>
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
        final intensity = 0.5 + (_controller.value * 0.5);

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              colors: widget.gradientColors
                  .map((c) => c.withValues(alpha: intensity))
                  .toList(),
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(widget.borderWidth),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(
                  widget.borderRadius - widget.borderWidth,
                ),
                color: Theme.of(context).scaffoldBackgroundColor,
              ),
              child: widget.child,
            ),
          ),
        );
      },
    );
  }
}
