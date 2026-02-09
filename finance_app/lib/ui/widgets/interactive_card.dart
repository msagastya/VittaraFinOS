import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';

/// Interactive card with 3D tilt and depth effects
class InteractiveCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final VoidCallback? onTap;
  final bool enableTilt;
  final bool enableDepth;
  final Color? backgroundColor;

  const InteractiveCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.onTap,
    this.enableTilt = true,
    this.enableDepth = true,
    this.backgroundColor,
  });

  @override
  State<InteractiveCard> createState() => _InteractiveCardState();
}

class _InteractiveCardState extends State<InteractiveCard>
    with TickerProviderStateMixin {
  late AnimationController _hoverController;
  late AnimationController _pressController;
  Offset _tiltOffset = Offset.zero;
  bool _isHovering = false;

  @override
  void initState() {
    super.initState();
    _hoverController = AnimationController(
      duration: AppDurations.fast,
      vsync: this,
    );
    _pressController = AnimationController(
      duration: AppDurations.buttonPress,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _hoverController.dispose();
    _pressController.dispose();
    super.dispose();
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (!widget.enableTilt) return;

    setState(() {
      _tiltOffset = Offset(
        (_tiltOffset.dx + details.delta.dx).clamp(-20.0, 20.0),
        (_tiltOffset.dy + details.delta.dy).clamp(-20.0, 20.0),
      );
    });
  }

  void _handlePanEnd(DragEndDetails details) {
    if (!widget.enableTilt) return;

    setState(() {
      _tiltOffset = Offset.zero;
    });
  }

  void _handleTapDown(TapDownDetails details) {
    _pressController.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    _pressController.reverse();
    widget.onTap?.call();
  }

  void _handleTapCancel() {
    _pressController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = widget.backgroundColor ??
        (isDark ? Colors.grey[900]! : Colors.white);

    return GestureDetector(
      onPanUpdate: _handlePanUpdate,
      onPanEnd: _handlePanEnd,
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: MouseRegion(
        onEnter: (_) {
          setState(() => _isHovering = true);
          _hoverController.forward();
        },
        onExit: (_) {
          setState(() => _isHovering = false);
          _hoverController.reverse();
        },
        child: AnimatedBuilder(
          animation: Listenable.merge([_hoverController, _pressController]),
          builder: (context, child) {
            final tiltX = widget.enableTilt ? _tiltOffset.dx * 0.002 : 0.0;
            final tiltY = widget.enableTilt ? _tiltOffset.dy * 0.002 : 0.0;

            final scale = 1.0 +
                (_hoverController.value * 0.02) -
                (_pressController.value * 0.03);

            final elevation = widget.enableDepth
                ? 4.0 + (_hoverController.value * 8.0) - (_pressController.value * 2.0)
                : 4.0;

            return Transform(
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateX(tiltY)
                ..rotateY(tiltX)
                ..scale(scale),
              alignment: Alignment.center,
              child: Container(
                margin: widget.margin,
                width: widget.width,
                height: widget.height,
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(Radii.xxl),
                  boxShadow: [
                    BoxShadow(
                      color: isDark
                          ? Colors.black.withValues(alpha: 0.4)
                          : Colors.black.withValues(alpha: 0.1),
                      blurRadius: elevation,
                      offset: Offset(0, elevation / 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(Radii.xxl),
                  child: Padding(
                    padding: widget.padding ?? EdgeInsets.all(Spacing.lg),
                    child: widget.child,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Card with press animation and ripple effect
class PressableCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;

  const PressableCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.margin,
    this.backgroundColor,
  });

  @override
  State<PressableCard> createState() => _PressableCardState();
}

class _PressableCardState extends State<PressableCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AppDurations.fast,
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _opacityAnimation = Tween<double>(begin: 1.0, end: 0.7).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = widget.backgroundColor ??
        (isDark ? Colors.grey[900]! : Colors.white);

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap?.call();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Opacity(
              opacity: _opacityAnimation.value,
              child: Container(
                margin: widget.margin,
                padding: widget.padding ?? EdgeInsets.all(Spacing.lg),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(Radii.xxl),
                  boxShadow: [
                    BoxShadow(
                      color: isDark
                          ? Colors.black.withValues(alpha: 0.3)
                          : Colors.black.withValues(alpha: 0.08),
                      blurRadius: 12 * (1 - _controller.value * 0.5),
                      offset: Offset(0, 6 * (1 - _controller.value * 0.5)),
                    ),
                  ],
                ),
                child: widget.child,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Card with shimmer hover effect
class ShimmerCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? shimmerColor;

  const ShimmerCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.margin,
    this.shimmerColor,
  });

  @override
  State<ShimmerCard> createState() => _ShimmerCardState();
}

class _ShimmerCardState extends State<ShimmerCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isHovering = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shimmerColor = widget.shimmerColor ??
        (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.3));

    return GestureDetector(
      onTap: widget.onTap,
      child: MouseRegion(
        onEnter: (_) {
          setState(() => _isHovering = true);
          _controller.repeat();
        },
        onExit: (_) {
          setState(() => _isHovering = false);
          _controller.stop();
          _controller.reset();
        },
        child: Stack(
          children: [
            Container(
              margin: widget.margin,
              padding: widget.padding ?? EdgeInsets.all(Spacing.lg),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[900]! : Colors.white,
                borderRadius: BorderRadius.circular(Radii.xxl),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.3)
                        : Colors.black.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: widget.child,
            ),
            if (_isHovering)
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(Radii.xxl),
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      return CustomPaint(
                        painter: ShimmerPainter(
                          progress: _controller.value,
                          shimmerColor: shimmerColor,
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class ShimmerPainter extends CustomPainter {
  final double progress;
  final Color shimmerColor;

  ShimmerPainter({
    required this.progress,
    required this.shimmerColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.transparent,
          shimmerColor,
          Colors.transparent,
        ],
        stops: [
          progress - 0.3,
          progress,
          progress + 0.3,
        ].map((e) => e.clamp(0.0, 1.0)).toList(),
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      paint,
    );
  }

  @override
  bool shouldRepaint(ShimmerPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// Card with glow effect on hover
class GlowCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? glowColor;

  const GlowCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.margin,
    this.glowColor,
  });

  @override
  State<GlowCard> createState() => _GlowCardState();
}

class _GlowCardState extends State<GlowCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isHovering = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AppDurations.normal,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glowColor = widget.glowColor ?? SemanticColors.getPrimary(context);

    return GestureDetector(
      onTap: widget.onTap,
      child: MouseRegion(
        onEnter: (_) {
          setState(() => _isHovering = true);
          _controller.forward();
        },
        onExit: (_) {
          setState(() => _isHovering = false);
          _controller.reverse();
        },
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Container(
              margin: widget.margin,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(Radii.xxl),
                boxShadow: [
                  BoxShadow(
                    color: glowColor.withValues(alpha: _controller.value * 0.4),
                    blurRadius: 20 * _controller.value,
                    spreadRadius: 2 * _controller.value,
                  ),
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.3)
                        : Colors.black.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Container(
                padding: widget.padding ?? EdgeInsets.all(Spacing.lg),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[900]! : Colors.white,
                  borderRadius: BorderRadius.circular(Radii.xxl),
                ),
                child: widget.child,
              ),
            );
          },
        ),
      ),
    );
  }
}
