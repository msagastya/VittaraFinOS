import 'package:flutter/material.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';

/// Floating Action Button with liquid ripple effects
class LiquidFAB extends StatefulWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final Color? color;
  final Color? iconColor;
  final double size;
  final String? tooltip;

  const LiquidFAB({
    super.key,
    required this.onPressed,
    required this.icon,
    this.color,
    this.iconColor,
    this.size = 56.0,
    this.tooltip,
  });

  @override
  State<LiquidFAB> createState() => _LiquidFABState();
}

class _LiquidFABState extends State<LiquidFAB> with TickerProviderStateMixin {
  late AnimationController _hoverController;
  late AnimationController _pressController;
  late AnimationController _rippleController;
  bool _isPressed = false;

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
    _rippleController = AnimationController(
      duration: AppDurations.medium,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _hoverController.dispose();
    _pressController.dispose();
    _rippleController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
    _pressController.forward();
    _rippleController.forward(from: 0.0);
  }

  void _handleTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    _pressController.reverse();
    widget.onPressed();
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
    _pressController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? SemanticColors.getPrimary(context);
    final iconColor = widget.iconColor ?? Colors.white;

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _hoverController,
          _pressController,
          _rippleController,
        ]),
        builder: (context, child) {
          final scale = 1.0 - (_pressController.value * 0.1);
          final elevation = 8.0 +
              (_hoverController.value * 4.0) -
              (_pressController.value * 4.0);

          return Transform.scale(
            scale: scale,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: elevation,
                    offset: Offset(0, elevation / 2),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Ripple effect
                  if (_rippleController.value > 0)
                    CustomPaint(
                      size: Size(widget.size, widget.size),
                      painter: RipplePainter(
                        progress: _rippleController.value,
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                  // Icon
                  Icon(
                    widget.icon,
                    color: iconColor,
                    size: IconSizes.fabIcon,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class RipplePainter extends CustomPainter {
  final double progress;
  final Color color;

  RipplePainter({
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    // Draw expanding ripple
    final paint = Paint()
      ..color = color.withValues(alpha: (1.0 - progress) * 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawCircle(center, maxRadius * progress, paint);

    // Draw second ripple
    if (progress > 0.3) {
      final secondProgress = (progress - 0.3) / 0.7;
      final secondPaint = Paint()
        ..color = color.withValues(alpha: (1.0 - secondProgress) * 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;

      canvas.drawCircle(center, maxRadius * secondProgress * 0.8, secondPaint);
    }
  }

  @override
  bool shouldRepaint(RipplePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// Extended FAB with liquid morphing effect
class LiquidExtendedFAB extends StatefulWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String label;
  final Color? color;
  final Color? iconColor;
  final Color? textColor;

  const LiquidExtendedFAB({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.label,
    this.color,
    this.iconColor,
    this.textColor,
  });

  @override
  State<LiquidExtendedFAB> createState() => _LiquidExtendedFABState();
}

class _LiquidExtendedFABState extends State<LiquidExtendedFAB>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _morphAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AppDurations.normal,
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    _morphAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: MotionCurves.emphasis,
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
    final color = widget.color ?? SemanticColors.getPrimary(context);
    final iconColor = widget.iconColor ?? Colors.white;
    final textColor = widget.textColor ?? Colors.white;

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onPressed();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: Spacing.lg + (_morphAnimation.value * 4),
                vertical: Spacing.md,
              ),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(
                  28 + (_morphAnimation.value * 8),
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 12 - (_morphAnimation.value * 4),
                    offset: Offset(0, 6 - (_morphAnimation.value * 2)),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(widget.icon, color: iconColor, size: IconSizes.md),
                  const SizedBox(width: Spacing.sm),
                  Text(
                    widget.label,
                    style: TextStyle(
                      color: textColor,
                      fontSize: TypeScale.callout,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Mini FAB with pulse animation
class LiquidMiniFAB extends StatefulWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final Color? color;
  final Color? iconColor;

  const LiquidMiniFAB({
    super.key,
    required this.onPressed,
    required this.icon,
    this.color,
    this.iconColor,
  });

  @override
  State<LiquidMiniFAB> createState() => _LiquidMiniFABState();
}

class _LiquidMiniFABState extends State<LiquidMiniFAB>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: AppDurations.pulse,
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.stop();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? SemanticColors.getPrimary(context);
    final iconColor = widget.iconColor ?? Colors.white;

    return GestureDetector(
      onTap: widget.onPressed,
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          final pulseScale = 1.0 + (_pulseController.value * 0.05);

          return Transform.scale(
            scale: pulseScale,
            child: Container(
              width: ComponentSizes.fabSizeSmall,
              height: ComponentSizes.fabSizeSmall,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(
                        alpha: 0.3 + (_pulseController.value * 0.2)),
                    blurRadius: 8 + (_pulseController.value * 4),
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                widget.icon,
                color: iconColor,
                size: IconSizes.md,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Morphing FAB that changes between circular and pill shape
class MorphingFAB extends StatefulWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String? label;
  final bool isExpanded;
  final Color? color;

  const MorphingFAB({
    super.key,
    required this.onPressed,
    required this.icon,
    this.label,
    this.isExpanded = false,
    this.color,
  });

  @override
  State<MorphingFAB> createState() => _MorphingFABState();
}

class _MorphingFABState extends State<MorphingFAB>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _widthAnimation;
  late Animation<double> _radiusAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AppDurations.medium,
      vsync: this,
    );

    _widthAnimation = Tween<double>(
      begin: ComponentSizes.fabSize,
      end: 180.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: MotionCurves.spring,
    ));

    _radiusAnimation = Tween<double>(
      begin: ComponentSizes.fabSize / 2,
      end: 28.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: MotionCurves.spring,
    ));

    if (widget.isExpanded) {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(MorphingFAB oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isExpanded != oldWidget.isExpanded) {
      if (widget.isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? SemanticColors.getPrimary(context);

    return GestureDetector(
      onTap: widget.onPressed,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Container(
            width: _widthAnimation.value,
            height: ComponentSizes.fabSize,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(_radiusAnimation.value),
              boxShadow: Shadows.fab(color),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  widget.icon,
                  color: Colors.white,
                  size: IconSizes.fabIcon,
                ),
                if (_controller.value > 0.3 && widget.label != null) ...[
                  const SizedBox(width: Spacing.sm),
                  Opacity(
                    opacity: (_controller.value - 0.3) / 0.7,
                    child: Text(
                      widget.label!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: TypeScale.callout,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
