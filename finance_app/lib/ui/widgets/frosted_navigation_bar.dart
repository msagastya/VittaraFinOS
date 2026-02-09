import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';

/// Frosted glass navigation bar with blur effect
class FrostedNavigationBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<FrostedNavigationItem> items;
  final double height;
  final double blurAmount;
  final Color? backgroundColor;
  final double opacity;

  const FrostedNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
    this.height = 65.0,
    this.blurAmount = 20.0,
    this.backgroundColor,
    this.opacity = 0.8,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveBackgroundColor = backgroundColor ??
        (isDark
            ? Colors.black.withValues(alpha: opacity)
            : Colors.white.withValues(alpha: opacity));

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: blurAmount,
          sigmaY: blurAmount,
        ),
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: effectiveBackgroundColor,
            border: Border(
              top: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.1),
                width: 0.5,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(items.length, (index) {
                return _FrostedNavigationButton(
                  item: items[index],
                  isSelected: currentIndex == index,
                  onTap: () => onTap(index),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

/// Navigation item configuration
class FrostedNavigationItem {
  final IconData icon;
  final IconData? activeIcon;
  final String label;
  final Color? color;

  const FrostedNavigationItem({
    required this.icon,
    this.activeIcon,
    required this.label,
    this.color,
  });
}

/// Individual navigation button with animation
class _FrostedNavigationButton extends StatefulWidget {
  final FrostedNavigationItem item;
  final bool isSelected;
  final VoidCallback onTap;

  const _FrostedNavigationButton({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_FrostedNavigationButton> createState() =>
      _FrostedNavigationButtonState();
}

class _FrostedNavigationButtonState extends State<_FrostedNavigationButton>
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

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _opacityAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    if (widget.isSelected) {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(_FrostedNavigationButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected != oldWidget.isSelected) {
      if (widget.isSelected) {
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = widget.item.color ?? SemanticColors.getPrimary(context);

    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Container(
            padding: EdgeInsets.symmetric(
              horizontal: Spacing.md,
              vertical: Spacing.sm,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Icon(
                    widget.isSelected
                        ? (widget.item.activeIcon ?? widget.item.icon)
                        : widget.item.icon,
                    color: widget.isSelected
                        ? color
                        : (isDark
                            ? Colors.white.withValues(alpha: _opacityAnimation.value * 0.6)
                            : Colors.black.withValues(alpha: _opacityAnimation.value * 0.6)),
                    size: IconSizes.md,
                  ),
                ),
                SizedBox(height: Spacing.xs),
                Text(
                  widget.item.label,
                  style: TextStyle(
                    fontSize: TypeScale.caption,
                    fontWeight:
                        widget.isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: widget.isSelected
                        ? color
                        : (isDark
                            ? Colors.white.withValues(alpha: _opacityAnimation.value * 0.6)
                            : Colors.black.withValues(alpha: _opacityAnimation.value * 0.6)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Frosted navigation bar with floating style
class FrostedFloatingNavigationBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<FrostedNavigationItem> items;
  final EdgeInsets margin;
  final double borderRadius;

  const FrostedFloatingNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
    this.margin = const EdgeInsets.all(16.0),
    this.borderRadius = 24.0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: 70.0,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.7)
                  : Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.15)
                    : Colors.black.withValues(alpha: 0.1),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.3)
                      : Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(items.length, (index) {
                return _FrostedNavigationButton(
                  item: items[index],
                  isSelected: currentIndex == index,
                  onTap: () => onTap(index),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

/// Frosted navigation bar with indicator
class FrostedIndicatorNavigationBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<FrostedNavigationItem> items;
  final double height;

  const FrostedIndicatorNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
    this.height = 65.0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: isDark
                ? Colors.black.withValues(alpha: 0.8)
                : Colors.white.withValues(alpha: 0.8),
            border: Border(
              top: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.1),
                width: 0.5,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Stack(
              children: [
                // Animated indicator
                AnimatedPositioned(
                  duration: AppDurations.fast,
                  curve: MotionCurves.spring,
                  left: (MediaQuery.of(context).size.width / items.length) *
                      currentIndex,
                  top: 0,
                  width: MediaQuery.of(context).size.width / items.length,
                  height: 3,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          SemanticColors.getPrimary(context),
                          SemanticColors.getPrimary(context).withValues(alpha: 0.5),
                        ],
                      ),
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(2),
                      ),
                    ),
                  ),
                ),
                // Navigation buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: List.generate(items.length, (index) {
                    return _FrostedNavigationButton(
                      item: items[index],
                      isSelected: currentIndex == index,
                      onTap: () => onTap(index),
                    );
                  }),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Minimal frosted navigation bar
class MinimalFrostedNavigationBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<FrostedNavigationItem> items;

  const MinimalFrostedNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          height: 60.0,
          decoration: BoxDecoration(
            color: isDark
                ? Colors.black.withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.6),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(items.length, (index) {
                final isSelected = currentIndex == index;
                final color = items[index].color ??
                    SemanticColors.getPrimary(context);

                return GestureDetector(
                  onTap: () => onTap(index),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: Spacing.md,
                      vertical: Spacing.sm,
                    ),
                    child: Icon(
                      isSelected
                          ? (items[index].activeIcon ?? items[index].icon)
                          : items[index].icon,
                      color: isSelected
                          ? color
                          : (isDark
                              ? Colors.white.withValues(alpha: 0.5)
                              : Colors.black.withValues(alpha: 0.5)),
                      size: IconSizes.lg,
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

/// Frosted top navigation bar (for headers)
class FrostedTopNavigationBar extends StatelessWidget {
  final String? title;
  final Widget? leading;
  final List<Widget>? trailing;
  final double height;
  final double blurAmount;

  const FrostedTopNavigationBar({
    super.key,
    this.title,
    this.leading,
    this.trailing,
    this.height = 44.0,
    this.blurAmount = 20.0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: blurAmount,
          sigmaY: blurAmount,
        ),
        child: Container(
          height: height + MediaQuery.of(context).padding.top,
          decoration: BoxDecoration(
            color: isDark
                ? Colors.black.withValues(alpha: 0.7)
                : Colors.white.withValues(alpha: 0.7),
            border: Border(
              bottom: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.1),
                width: 0.5,
              ),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: Spacing.md),
              child: Row(
                children: [
                  if (leading != null) leading!,
                  if (leading != null) SizedBox(width: Spacing.md),
                  if (title != null)
                    Expanded(
                      child: Text(
                        title!,
                        style: TextStyle(
                          fontSize: TypeScale.headline,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                  if (trailing != null)
                    ...trailing!.map((widget) => Padding(
                          padding: EdgeInsets.only(left: Spacing.sm),
                          child: widget,
                        )),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
