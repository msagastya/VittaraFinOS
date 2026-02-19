import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';

/// Hybrid card combining neumorphism and glassmorphism
class NeumorphicGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final VoidCallback? onTap;
  final bool isPressed;

  const NeumorphicGlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.onTap,
    this.isPressed = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Neumorphic shadow colors
    final lightShadow = isDark
        ? Colors.white.withValues(alpha: 0.03)
        : Colors.white.withValues(alpha: 0.7);
    final darkShadow = isDark
        ? Colors.black.withValues(alpha: 0.5)
        : Colors.grey[400]!.withValues(alpha: 0.5);

    // Glass background
    final glassColor = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.white.withValues(alpha: 0.3);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: margin,
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Radii.xxl),
          // Neumorphic shadows
          boxShadow: isPressed
              ? [
                  BoxShadow(
                    color: darkShadow,
                    offset: const Offset(2, 2),
                    blurRadius: 4,
                  ),
                  BoxShadow(
                    color: lightShadow,
                    offset: const Offset(-2, -2),
                    blurRadius: 4,
                  ),
                ]
              : [
                  BoxShadow(
                    color: darkShadow,
                    offset: const Offset(6, 6),
                    blurRadius: 12,
                  ),
                  BoxShadow(
                    color: lightShadow,
                    offset: const Offset(-6, -6),
                    blurRadius: 12,
                  ),
                ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(Radii.xxl),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: padding ?? EdgeInsets.all(Spacing.lg),
              decoration: BoxDecoration(
                color: glassColor,
                borderRadius: BorderRadius.circular(Radii.xxl),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.white.withValues(alpha: 0.5),
                  width: 1.5,
                ),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Elevated neumorphic glass card with more prominent shadows
class NeumorphicGlassCardElevated extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;

  const NeumorphicGlassCardElevated({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final lightShadow = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.white.withValues(alpha: 0.9);
    final darkShadow = isDark
        ? Colors.black.withValues(alpha: 0.6)
        : Colors.grey[500]!.withValues(alpha: 0.6);

    final glassColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.white.withValues(alpha: 0.4);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: margin,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Radii.xxl),
          boxShadow: [
            BoxShadow(
              color: darkShadow,
              offset: const Offset(8, 8),
              blurRadius: 16,
            ),
            BoxShadow(
              color: lightShadow,
              offset: const Offset(-8, -8),
              blurRadius: 16,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(Radii.xxl),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              padding: padding ?? EdgeInsets.all(Spacing.xl),
              decoration: BoxDecoration(
                color: glassColor,
                borderRadius: BorderRadius.circular(Radii.xxl),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.15)
                      : Colors.white.withValues(alpha: 0.6),
                  width: 2.0,
                ),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Interactive neumorphic glass button
class NeumorphicGlassButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onPressed;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;

  const NeumorphicGlassButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.padding,
    this.width,
    this.height,
  });

  @override
  State<NeumorphicGlassButton> createState() => _NeumorphicGlassButtonState();
}

class _NeumorphicGlassButtonState extends State<NeumorphicGlassButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onPressed();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: NeumorphicGlassCard(
        padding: widget.padding ??
            EdgeInsets.symmetric(
              horizontal: Spacing.xl,
              vertical: Spacing.md,
            ),
        width: widget.width,
        height: widget.height,
        isPressed: _isPressed,
        child: widget.child,
      ),
    );
  }
}

/// Concave neumorphic glass card (sunken effect)
class NeumorphicGlassConcave extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  const NeumorphicGlassConcave({
    super.key,
    required this.child,
    this.padding,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final innerLightShadow = isDark
        ? Colors.white.withValues(alpha: 0.02)
        : Colors.white.withValues(alpha: 0.5);
    final innerDarkShadow = isDark
        ? Colors.black.withValues(alpha: 0.4)
        : Colors.grey[400]!.withValues(alpha: 0.4);

    final glassColor = isDark
        ? Colors.black.withValues(alpha: 0.3)
        : Colors.grey[100]!.withValues(alpha: 0.5);

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.xxl),
        color: isDark ? Colors.grey[900] : Colors.grey[200],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Radii.xxl),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: padding ?? EdgeInsets.all(Spacing.lg),
            decoration: BoxDecoration(
              // Simulated inset effect with gradient
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  innerDarkShadow,
                  glassColor,
                  glassColor,
                  innerLightShadow,
                ],
              ),
              borderRadius: BorderRadius.circular(Radii.xxl),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Neumorphic glass toggle switch
class NeumorphicGlassToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color? activeColor;

  const NeumorphicGlassToggle({
    super.key,
    required this.value,
    required this.onChanged,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = activeColor ?? SemanticColors.getPrimary(context);

    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: AppDurations.normal,
        width: 60,
        height: 32,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: value
              ? color.withValues(alpha: 0.3)
              : (isDark ? Colors.grey[800] : Colors.grey[300]),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.4)
                  : Colors.grey[400]!.withValues(alpha: 0.4),
              offset: const Offset(3, 3),
              blurRadius: 6,
            ),
            BoxShadow(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.02)
                  : Colors.white.withValues(alpha: 0.6),
              offset: const Offset(-3, -3),
              blurRadius: 6,
            ),
          ],
        ),
        child: Stack(
          children: [
            // Glass blur effect
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                ),
              ),
            ),
            // Toggle knob
            AnimatedAlign(
              duration: AppDurations.normal,
              curve: MotionCurves.spring,
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.all(4),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: value
                      ? color
                      : (isDark ? Colors.grey[700] : Colors.white),
                  boxShadow: [
                    BoxShadow(
                      color: isDark
                          ? Colors.black.withValues(alpha: 0.5)
                          : Colors.grey[600]!.withValues(alpha: 0.3),
                      offset: const Offset(2, 2),
                      blurRadius: 4,
                    ),
                    BoxShadow(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.03)
                          : Colors.white,
                      offset: const Offset(-1, -1),
                      blurRadius: 2,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Neumorphic glass slider
class NeumorphicGlassSlider extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;
  final double min;
  final double max;
  final Color? activeColor;

  const NeumorphicGlassSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0.0,
    this.max = 1.0,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = activeColor ?? SemanticColors.getPrimary(context);
    final normalizedValue = (value - min) / (max - min);

    return GestureDetector(
      onPanUpdate: (details) {
        // Calculate new value based on pan position
        final RenderBox box = context.findRenderObject() as RenderBox;
        final localX = details.localPosition.dx;
        final width = box.size.width;
        final newValue = (localX / width).clamp(0.0, 1.0);
        onChanged(min + (newValue * (max - min)));
      },
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              isDark
                  ? Colors.black.withValues(alpha: 0.4)
                  : Colors.grey[400]!.withValues(alpha: 0.4),
              isDark ? Colors.grey[900]! : Colors.grey[200]!,
              isDark
                  ? Colors.white.withValues(alpha: 0.02)
                  : Colors.white.withValues(alpha: 0.5),
            ],
          ),
        ),
        child: Stack(
          children: [
            // Progress indicator
            FractionallySizedBox(
              widthFactor: normalizedValue,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    colors: [
                      color.withValues(alpha: 0.3),
                      color.withValues(alpha: 0.5),
                    ],
                  ),
                ),
              ),
            ),
            // Glass effect
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                ),
              ),
            ),
            // Thumb
            Align(
              alignment: Alignment(normalizedValue * 2 - 1, 0),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
