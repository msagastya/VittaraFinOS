import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/widgets/animations.dart';

// ============================================================
// APP DIVIDER
// ============================================================

/// Consistent thin divider line
class AppDivider extends StatelessWidget {
  final double? indent;
  final double? endIndent;
  const AppDivider({super.key, this.indent, this.endIndent});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Divider(
      height: 1,
      thickness: 0.5,
      indent: indent,
      endIndent: endIndent,
      color: isDark ? const Color(0xFF0D1829) : const Color(0xFFCCDDEE),
    );
  }
}

// ============================================================
// SKELETON ANIMATION PROVIDER
// ============================================================

/// Holds a single shared [AnimationController] for all [SkeletonLoader]
/// widgets in its subtree, so every shimmer pulse is in phase.
///
/// Usage: wrap any screen that shows multiple skeleton loaders:
/// ```dart
/// SkeletonAnimationProvider(child: SkeletonListView())
/// ```
/// [SkeletonLoader] automatically uses the nearest provider when present,
/// falling back to its own controller if no provider is found.
class SkeletonAnimationProvider extends StatefulWidget {
  final Widget child;
  const SkeletonAnimationProvider({super.key, required this.child});

  /// Returns the shared [Animation<double>] from the nearest provider, or
  /// null if there is no [SkeletonAnimationProvider] in the tree.
  static Animation<double>? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_SkeletonAnimationScope>()
        ?.animation;
  }

  @override
  State<SkeletonAnimationProvider> createState() =>
      _SkeletonAnimationProviderState();
}

class _SkeletonAnimationProviderState extends State<SkeletonAnimationProvider>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    _animation = Tween<double>(begin: -2.0, end: 2.0).animate(
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
    return _SkeletonAnimationScope(
      animation: _animation,
      child: widget.child,
    );
  }
}

class _SkeletonAnimationScope extends InheritedWidget {
  final Animation<double> animation;

  const _SkeletonAnimationScope({
    required this.animation,
    required super.child,
  });

  @override
  bool updateShouldNotify(_SkeletonAnimationScope oldWidget) =>
      animation != oldWidget.animation;
}

// ============================================================
// SKELETON LOADER
// ============================================================

/// A single shimmering placeholder bar.
/// Uses a pure-Flutter gradient animation — no external package needed.
///
/// When a [SkeletonAnimationProvider] is present in the widget tree, all
/// [SkeletonLoader] instances share its controller so their shimmer is in sync.
/// When no provider is found, each loader manages its own controller.
class SkeletonLoader extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const SkeletonLoader({
    super.key,
    this.width = double.infinity,
    this.height = 16,
    this.borderRadius = 8,
  });

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader> {
  @override
  Widget build(BuildContext context) {
    final shared = SkeletonAnimationProvider.maybeOf(context);
    final isDark = AppStyles.isDarkMode(context);

    if (shared != null) {
      return Semantics(
        label: 'Loading...',
        child: _buildContent(context, shared, isDark),
      );
    }

    // No provider — use TweenAnimationBuilder for a self-contained shimmer
    // that does not require managing an AnimationController.
    return Semantics(
      label: 'Loading...',
      child: _SkeletonShimmer(
        width: widget.width,
        height: widget.height,
        borderRadius: widget.borderRadius,
        isDark: isDark,
      ),
    );
  }

  Widget _buildContent(
      BuildContext context, Animation<double> animation, bool isDark) {
    if (isDark) {
      const base = Color(0xFF060C16);
      const beamColor = Color(0xFF00D4AA);
      return AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          final x = animation.value;
          return Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              gradient: LinearGradient(
                begin: Alignment(x - 0.8, 0),
                end: Alignment(x + 0.8, 0),
                colors: [
                  base,
                  beamColor.withValues(alpha: 0.0),
                  beamColor.withValues(alpha: 0.18),
                  beamColor.withValues(alpha: 0.35),
                  beamColor.withValues(alpha: 0.18),
                  beamColor.withValues(alpha: 0.0),
                  base,
                ],
                stops: const [0.0, 0.30, 0.44, 0.50, 0.56, 0.70, 1.0],
              ),
            ),
          );
        },
      );
    } else {
      const base = Color(0xFFE8EEF6);
      const highlight = Color(0xFFF8FBFF);
      return AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          return Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              gradient: LinearGradient(
                begin: Alignment(animation.value - 1, 0),
                end: Alignment(animation.value + 1, 0),
                colors: [base, highlight, base],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          );
        },
      );
    }
  }
}

/// Self-contained shimmer widget that uses [TweenAnimationBuilder] to loop
/// without requiring an explicit [AnimationController].  Used as fallback
/// when no [SkeletonAnimationProvider] is found in the widget tree.
class _SkeletonShimmer extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;
  final bool isDark;

  const _SkeletonShimmer({
    required this.width,
    required this.height,
    required this.borderRadius,
    required this.isDark,
  });

  @override
  State<_SkeletonShimmer> createState() => _SkeletonShimmerState();
}

class _SkeletonShimmerState extends State<_SkeletonShimmer> {
  double _target = 2.0;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: -2.0, end: _target),
      duration: const Duration(milliseconds: 1800),
      curve: Curves.easeInOut,
      onEnd: () {
        if (mounted) setState(() => _target = _target > 0 ? -2.0 : 2.0);
      },
      builder: (context, value, _) {
        if (widget.isDark) {
          const base = Color(0xFF060C16);
          const beamColor = Color(0xFF00D4AA);
          return Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              gradient: LinearGradient(
                begin: Alignment(value - 0.8, 0),
                end: Alignment(value + 0.8, 0),
                colors: [
                  base,
                  beamColor.withValues(alpha: 0.0),
                  beamColor.withValues(alpha: 0.18),
                  beamColor.withValues(alpha: 0.35),
                  beamColor.withValues(alpha: 0.18),
                  beamColor.withValues(alpha: 0.0),
                  base,
                ],
                stops: const [0.0, 0.30, 0.44, 0.50, 0.56, 0.70, 1.0],
              ),
            ),
          );
        } else {
          const base = Color(0xFFE8EEF6);
          const highlight = Color(0xFFF8FBFF);
          return Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              gradient: LinearGradient(
                begin: Alignment(value - 1, 0),
                end: Alignment(value + 1, 0),
                colors: [base, highlight, base],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          );
        }
      },
    );
  }
}

/// Pre-built skeleton that mimics a standard list card
/// (icon box + two text lines).
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(Spacing.lg),
      decoration: AppStyles.cardDecoration(context),
      child: const Row(
        children: [
          SkeletonLoader(width: 48, height: 48, borderRadius: 14),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonLoader(height: 14, width: double.infinity),
                SizedBox(height: Spacing.sm),
                SkeletonLoader(height: 11, width: 120, borderRadius: 6),
              ],
            ),
          ),
          SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SkeletonLoader(height: 14, width: 72),
              SizedBox(height: Spacing.sm),
              SkeletonLoader(height: 11, width: 48, borderRadius: 6),
            ],
          ),
        ],
      ),
    );
  }
}

/// A full-screen skeleton list (5 cards) for list screens.
/// Wraps itself in a [SkeletonAnimationProvider] so all cards pulse in sync.
/// If a provider already exists in the tree, the inner one is a no-op because
/// [SkeletonLoader] will use the nearest ancestor's animation.
class SkeletonListView extends StatelessWidget {
  final int itemCount;
  const SkeletonListView({super.key, this.itemCount = 5});

  @override
  Widget build(BuildContext context) {
    return SkeletonAnimationProvider(
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        itemCount: itemCount,
        itemBuilder: (_, __) => const SkeletonCard(),
      ),
    );
  }
}

/// A large summary card skeleton (used on Net Worth / dashboard cards).
/// Wraps itself in a [SkeletonAnimationProvider] so all internal loaders
/// are in phase. If a provider already exists in the tree it is reused.
class SkeletonSummaryCard extends StatelessWidget {
  const SkeletonSummaryCard({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonAnimationProvider(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(Spacing.xl),
        decoration: AppStyles.cardDecoration(context),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonLoader(height: 12, width: 100),
            SizedBox(height: Spacing.md),
            SkeletonLoader(height: 32, width: 200),
            SizedBox(height: Spacing.lg),
            Row(
              children: [
                Expanded(child: SkeletonLoader(height: 10)),
                SizedBox(width: Spacing.md),
                Expanded(child: SkeletonLoader(height: 10)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// COMMON REUSABLE WIDGETS - VittaraFinOS
// ============================================================
// This file contains reusable UI components that maintain
// consistency across the entire application.
// ============================================================

// ============================================================
// SKELETON CHART — bar chart placeholder for loading states
// ============================================================

/// Five shimmering bars of varying height, simulating a bar chart.
/// Used on Investments, Budget, and Reports screens during first paint.
class SkeletonChart extends StatelessWidget {
  final int barCount;
  final double height;

  const SkeletonChart({super.key, this.barCount = 5, this.height = 80});

  static const _heights = [0.45, 0.70, 0.55, 0.90, 0.65, 0.40, 0.80];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(barCount, (i) {
          final fraction = _heights[i % _heights.length];
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: SkeletonLoader(
                height: height * fraction,
                borderRadius: 4,
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ============================================================
// EMPTY STATE WIDGET
// ============================================================

/// A consistent empty state view for lists and screens
class EmptyStateView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool showPulse;

  const EmptyStateView({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.showPulse = true,
  });

  @override
  Widget build(BuildContext context) {
    return FadeInAnimation(
      child: Center(
        child: Padding(
          padding: Spacing.screenPadding,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildIcon(context),
              const SizedBox(height: Spacing.lg),
              Text(
                title,
                style: TextStyle(
                  color: AppStyles.getSecondaryTextColor(context),
                  fontSize: TypeScale.title3,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: Spacing.sm),
                Text(
                  subtitle!,
                  style: TextStyle(
                    color: AppStyles.getSecondaryTextColor(context)
                        .withValues(alpha: 0.7),
                    fontSize: TypeScale.body,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: Spacing.xxl),
                _buildActionButton(context),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIcon(BuildContext context) {
    final primary = AppStyles.getPrimaryColor(context);
    final iconWidget = Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primary.withValues(alpha: 0.18),
            primary.withValues(alpha: 0.08),
          ],
        ),
        shape: BoxShape.circle,
        border: Border.all(
          color: primary.withValues(alpha: 0.25),
          width: 1.0,
        ),
      ),
      child: Center(
        child: Icon(
          icon,
          size: IconSizes.emptyStateIcon * 0.70,
          color: primary.withValues(alpha: 0.60),
        ),
      ),
    );

    if (showPulse && onAction != null) {
      return PulseAnimation(
        minScale: 0.96,
        maxScale: 1.04,
        child: iconWidget,
      );
    }
    return iconWidget;
  }

  Widget _buildActionButton(BuildContext context) {
    return BouncyButton(
      onPressed: onAction!,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.xxl,
          vertical: Spacing.md,
        ),
        decoration: BoxDecoration(
          color: SemanticColors.getPrimary(context),
          borderRadius: Radii.buttonRadius,
          boxShadow: Shadows.fab(SemanticColors.getPrimary(context)),
        ),
        child: Text(
          actionLabel!,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: TypeScale.callout,
          ),
        ),
      ),
    );
  }
}

// ============================================================
// FADING FLOATING ACTION BUTTON (Shared)
// ============================================================

/// A floating action button that fades after inactivity
class FadingFAB extends StatefulWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final Color? color;
  final String? heroTag;

  const FadingFAB({
    super.key,
    required this.onPressed,
    this.icon = CupertinoIcons.add,
    this.color,
    this.heroTag,
  });

  @override
  State<FadingFAB> createState() => _FadingFABState();
}

class _FadingFABState extends State<FadingFAB>
    with SingleTickerProviderStateMixin {
  Timer? _timer;
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppDurations.toast,
    );
    _animation = Tween<double>(begin: 1.0, end: Opacities.fadedFab).animate(
      CurvedAnimation(parent: _controller, curve: MotionCurves.standard),
    );
    _startInactivityTimer();
  }

  void _startInactivityTimer() {
    _timer?.cancel();
    if (_controller.value > 0) _controller.reverse();
    _timer = Timer(AppDurations.fabFade, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fabColor = widget.color ?? SemanticColors.getPrimary(context);

    final fab = AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value,
          child: GestureDetector(
            onTapDown: (_) => _startInactivityTimer(),
            onTap: () {
              _startInactivityTimer();
              Haptics.light();
              widget.onPressed();
            },
            child: Container(
              width: ComponentSizes.fabSize,
              height: ComponentSizes.fabSize,
              decoration: BoxDecoration(
                color: fabColor,
                shape: BoxShape.circle,
                boxShadow: Shadows.fab(fabColor),
              ),
              child: Icon(
                widget.icon,
                color: Colors.white,
                size: IconSizes.fabIcon,
              ),
            ),
          ),
        );
      },
    );

    if (widget.heroTag != null) {
      return Hero(tag: widget.heroTag!, child: fab);
    }
    return fab;
  }
}

// ============================================================
// MODAL HANDLE BAR
// ============================================================

/// Consistent handle bar for bottom sheets and modals
class ModalHandle extends StatelessWidget {
  const ModalHandle({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(top: Spacing.md),
      width: ComponentSizes.modalHandleWidth,
      height: ComponentSizes.modalHandleHeight,
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF2A3F5F) // moonlit ridge on void
            : const Color(0xFFBBCCDD),
        borderRadius:
            BorderRadius.circular(ComponentSizes.modalHandleHeight / 2),
      ),
    );
  }
}

// ============================================================
// SECTION HEADER
// ============================================================

/// Consistent section header for lists
class SectionHeader extends StatelessWidget {
  final String title;
  final int? count;
  final Widget? trailing;

  const SectionHeader({
    super.key,
    required this.title,
    this.count,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppStyles.isDarkMode(context);
    return Padding(
      padding: const EdgeInsets.only(
        left: Spacing.sm,
        top: Spacing.lg,
        bottom: Spacing.sm,
        right: Spacing.sm,
      ),
      child: Row(
        children: [
          // Accent dot
          Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppStyles.accentBlue,
                  AppStyles.accentTeal,
                ],
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              count != null ? '$title  ·  $count' : title,
              style: TextStyle(
                fontSize: TypeScale.caption,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? const Color(0xFF6E6E80)
                    : const Color(0xFF4A6080),
                letterSpacing: 0.6,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

// ============================================================
// ICON BOX
// ============================================================

/// Consistent icon container with background
class IconBox extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final double iconSize;
  final bool showGlow;

  const IconBox({
    super.key,
    required this.icon,
    required this.color,
    this.size = ComponentSizes.iconBoxMedium,
    this.iconSize = IconSizes.listItemIcon,
    this.showGlow = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: AppStyles.iconBoxDecoration(context, color).copyWith(
        borderRadius: Radii.iconBoxRadius,
        boxShadow: showGlow
            ? AppStyles.elevatedShadows(
                context,
                tint: color,
                strength: 0.48,
              )
            : null,
      ),
      child: Center(
        child: Icon(
          icon,
          color: color,
          size: iconSize,
        ),
      ),
    );
  }
}

// ============================================================
// ACTION BUTTON ROW
// ============================================================

/// Consistent action button row for modals/sheets
class ActionButtonRow extends StatelessWidget {
  final String primaryLabel;
  final VoidCallback onPrimaryPressed;
  final String? secondaryLabel;
  final VoidCallback? onSecondaryPressed;
  final bool isPrimaryDestructive;
  final bool isLoading;

  const ActionButtonRow({
    super.key,
    required this.primaryLabel,
    required this.onPrimaryPressed,
    this.secondaryLabel,
    this.onSecondaryPressed,
    this.isPrimaryDestructive = false,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: Spacing.screenPadding,
      child: Row(
        children: [
          if (secondaryLabel != null && onSecondaryPressed != null) ...[
            Expanded(
              child: BouncyButton(
                onPressed: onSecondaryPressed!,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: Spacing.md),
                  decoration: AppStyles.tabDecoration(
                    context,
                    selected: false,
                    color: AppStyles.accentBlue,
                  ),
                  child: Center(
                    child: Text(
                      secondaryLabel!,
                      style: TextStyle(
                        color: AppStyles.getTextColor(context),
                        fontWeight: FontWeight.w600,
                        fontSize: TypeScale.body,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: Spacing.md),
          ],
          Expanded(
            child: BouncyButton(
              onPressed: isLoading ? () {} : onPrimaryPressed,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: Spacing.md),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      isPrimaryDestructive
                          ? SemanticColors.getError(context)
                          : SemanticColors.getPrimary(context),
                      isPrimaryDestructive
                          ? SemanticColors.getError(context)
                              .withValues(alpha: 0.80)
                          : AppStyles.accentTeal,
                    ],
                  ),
                  borderRadius: Radii.buttonRadius,
                  boxShadow: AppStyles.elevatedShadows(
                    context,
                    tint: isPrimaryDestructive
                        ? SemanticColors.getError(context)
                        : SemanticColors.getPrimary(context),
                    strength: 0.55,
                  ),
                ),
                child: Center(
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CupertinoActivityIndicator(
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          primaryLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: TypeScale.body,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// SMALL ACTION BUTTON (for inline actions)
// ============================================================

/// Small action button for inline actions (Edit, Delete, etc.)
class SmallActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const SmallActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return BouncyButton(
      onPressed: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: Spacing.md),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withValues(alpha: 0.24),
              color.withValues(alpha: 0.10),
            ],
          ),
          borderRadius: Radii.buttonRadius,
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: IconSizes.sm, color: color),
            const SizedBox(width: Spacing.xs + 2),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: TypeScale.body,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// SEARCH BAR
// ============================================================

/// Consistent search bar for screens
class AppSearchBar extends StatelessWidget {
  final String placeholder;
  final ValueChanged<String> onChanged;
  final TextEditingController? controller;

  const AppSearchBar({
    super.key,
    this.placeholder = 'Search',
    required this.onChanged,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(Spacing.lg),
      decoration: AppStyles.sectionDecoration(
        context,
        tint: AppStyles.accentBlue.withValues(alpha: 0.72),
        radius: Radii.md,
        elevated: false,
      ),
      child: CupertinoSearchTextField(
        controller: controller,
        backgroundColor: Colors.transparent,
        style: TextStyle(color: AppStyles.getTextColor(context)),
        placeholder: placeholder,
        placeholderStyle: TextStyle(
          color: AppStyles.getSecondaryTextColor(context),
        ),
        onChanged: onChanged,
      ),
    );
  }
}

// ============================================================
// SUMMARY CARD
// ============================================================

/// Consistent summary card for totals and stats
class SummaryCard extends StatelessWidget {
  final String label;
  final double value;
  final String? subtitle;
  final String prefix;
  final int decimals;
  final Color? valueColor;
  final bool useAnimatedCounter;
  final Widget? trailing;
  final bool useGradientBorder;
  final List<Color>? gradientColors;

  const SummaryCard({
    super.key,
    required this.label,
    required this.value,
    this.subtitle,
    this.prefix = '',
    this.decimals = 2,
    this.valueColor,
    this.useAnimatedCounter = true,
    this.trailing,
    this.useGradientBorder = false,
    this.gradientColors,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: Spacing.cardPadding,
      decoration: useGradientBorder ? null : AppStyles.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: AppStyles.getSecondaryTextColor(context),
                    fontSize: TypeScale.body,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: Spacing.sm),
          useAnimatedCounter
              ? AnimatedCounter(
                  value: value,
                  prefix: prefix,
                  decimals: decimals,
                  duration: AppDurations.counter,
                  style: AppStyles.titleStyle(context).copyWith(
                    fontSize: TypeScale.display,
                    color: valueColor ?? SemanticColors.getPrimary(context),
                    fontWeight: FontWeight.bold,
                  ),
                )
              : Text(
                  '$prefix${value.toStringAsFixed(decimals)}',
                  style: AppStyles.titleStyle(context).copyWith(
                    fontSize: TypeScale.display,
                    color: valueColor ?? SemanticColors.getPrimary(context),
                    fontWeight: FontWeight.bold,
                  ),
                ),
          if (subtitle != null) ...[
            const SizedBox(height: Spacing.md),
            Text(
              subtitle!,
              style: TextStyle(
                color: AppStyles.getSecondaryTextColor(context),
                fontSize: TypeScale.footnote,
              ),
            ),
          ],
        ],
      ),
    );

    if (useGradientBorder) {
      return GradientBorderContainer(
        gradientColors:
            gradientColors ?? ColorPalettes.gradientPresets.take(3).toList(),
        borderWidth: 2,
        child: card,
      );
    }

    return card;
  }
}

// ============================================================
// LIST CARD
// ============================================================

/// Consistent card layout for list items
class ListCard extends StatelessWidget {
  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final String? heroTag;
  final EdgeInsets? padding;

  const ListCard({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.heroTag,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      margin: const EdgeInsets.only(bottom: Spacing.lg),
      decoration: AppStyles.cardDecoration(context),
      child: Padding(
        padding: padding ?? Spacing.cardPadding,
        child: Row(
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: Spacing.lg),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppStyles.titleStyle(context)),
                  if (subtitle != null) ...[
                    const SizedBox(height: Spacing.xs),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: TypeScale.footnote,
                        color: AppStyles.getSecondaryTextColor(context),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );

    if (onTap != null) {
      final tappableCard = BouncyButton(onPressed: onTap!, child: card);
      if (heroTag != null) {
        return Hero(tag: heroTag!, child: tappableCard);
      }
      return tappableCard;
    }

    if (heroTag != null) {
      return Hero(tag: heroTag!, child: card);
    }
    return card;
  }
}

// ============================================================
// OPTION CARD (for selection modals)
// ============================================================

/// Large option card for selection screens
class OptionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final double height;

  const OptionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
    this.height = ComponentSizes.optionCardHeight,
  });

  @override
  Widget build(BuildContext context) {
    return BouncyButton(
      onPressed: onTap,
      child: Container(
        height: height,
        decoration: AppStyles.cardDecoration(context).copyWith(
          border: Border.all(
            color: color.withValues(alpha: Opacities.borderSubtle),
            width: 1,
          ),
        ),
        padding: Spacing.cardPadding,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(Spacing.lg),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: IconSizes.cardIcon, color: color),
            ),
            const SizedBox(height: Spacing.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppStyles.titleStyle(context).copyWith(
                fontSize: TypeScale.headline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// SETTINGS ROW
// ============================================================

/// Consistent row for settings screens
class SettingsRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const SettingsRow({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      decoration: AppStyles.cardDecoration(context),
      child: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Row(
          children: [
            IconBox(icon: icon, color: iconColor),
            const SizedBox(width: Spacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppStyles.titleStyle(context)),
                  if (subtitle != null) ...[
                    const SizedBox(height: Spacing.xxs),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: TypeScale.footnote,
                        color: AppStyles.getSecondaryTextColor(context),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );

    if (onTap != null) {
      return BouncyButton(onPressed: onTap!, child: content);
    }
    return content;
  }
}

// ============================================================
// COLOR PICKER ROW
// ============================================================

/// Horizontal color picker for forms
class ColorPickerRow extends StatelessWidget {
  final Color selectedColor;
  final ValueChanged<Color> onColorSelected;
  final List<Color>? colors;

  const ColorPickerRow({
    super.key,
    required this.selectedColor,
    required this.onColorSelected,
    this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final colorList = colors ?? ColorPalettes.categoryColors;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: colorList.map((color) {
          final isSelected = selectedColor == color;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
            child: GestureDetector(
              onTap: () {
                Haptics.selection();
                onColorSelected(color);
              },
              child: AnimatedContainer(
                duration: AppDurations.fast,
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? Colors.white : Colors.transparent,
                    width: 3,
                  ),
                  boxShadow: isSelected ? Shadows.iconGlow(color) : null,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ============================================================
// LOADING OVERLAY
// ============================================================

// ============================================================
// SMOOTH SCROLL PHYSICS
// ============================================================

/// Drop-in ScrollPhysics for large lists.
///
/// On fast flings the ballistic simulation uses low friction → long momentum
/// glide. On slow flings it switches to higher friction so the list stops
/// quickly, giving a precise "slow scroll" feel — matching the user's
/// expectation of "fast = loads fast, slow = stops where I want".
class SmoothScrollPhysics extends ScrollPhysics {
  const SmoothScrollPhysics({super.parent});

  @override
  SmoothScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      SmoothScrollPhysics(parent: buildParent(ancestor));

  /// Lower threshold makes flings easier to trigger.
  @override
  double get minFlingVelocity => 80.0;

  @override
  Simulation? createBallisticSimulation(
      ScrollMetrics position, double velocity) {
    final tolerance = toleranceFor(position);
    if (velocity.abs() < tolerance.velocity ||
        (position.pixels <= position.minScrollExtent && velocity < 0) ||
        (position.pixels >= position.maxScrollExtent && velocity > 0)) {
      return null;
    }
    // Fast fling (> 2000 px/s): low friction → long glide.
    // Slow fling: higher friction → stops sooner.
    final friction = velocity.abs() > 2000.0 ? 0.010 : 0.030;
    return FrictionSimulation(
      friction,
      position.pixels,
      velocity,
      tolerance: tolerance,
    );
  }
}

/// Full-screen loading overlay
class LoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final Widget child;
  final String? message;

  const LoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Container(
            color: Colors.black.withValues(alpha: Opacities.overlay),
            child: Center(
              child: GlassContainer(
                padding: Spacing.cardPadding,
                borderRadius: Radii.cardRadius,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CupertinoActivityIndicator(radius: 16),
                    if (message != null) ...[
                      const SizedBox(height: Spacing.lg),
                      Text(
                        message!,
                        style: TextStyle(
                          color: AppStyles.getTextColor(context),
                          fontSize: TypeScale.body,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ============================================================
// JARGON TOOLTIP — AU14-01
// ============================================================
// Tap-to-explain info icon for financial jargon terms.
// Usage: Row(children: [Text('PRAN'), SizedBox(width: 4), JargonTooltip.pran()])
// ============================================================

class JargonTooltip extends StatelessWidget {
  final String term;
  final String definition;

  const JargonTooltip({
    super.key,
    required this.term,
    required this.definition,
  });

  // ── Named constructors for common terms ──────────────────
  const JargonTooltip.pran({super.key})
      : term = 'PRAN',
        definition =
            'Permanent Retirement Account Number — your unique 12-digit NPS account ID issued by the Central Recordkeeping Agency (CRA). Required for all NPS transactions.';

  const JargonTooltip.nav({super.key})
      : term = 'NAV',
        definition =
            'Net Asset Value — the per-unit market price of a mutual fund. Calculated daily as (Total Assets − Liabilities) ÷ Total Units. You buy/sell MF units at NAV.';

  const JargonTooltip.cagr({super.key})
      : term = 'CAGR',
        definition =
            'Compound Annual Growth Rate — the steady annual rate at which an investment would have grown from its initial to final value. Formula: (End/Start)^(1/Years) − 1.';

  const JargonTooltip.xirr({super.key})
      : term = 'XIRR',
        definition =
            'Extended Internal Rate of Return — measures actual returns when investments/withdrawals happen at irregular dates (unlike CAGR which assumes lump sum). Higher XIRR = better returns.';

  const JargonTooltip.tds({super.key})
      : term = 'TDS',
        definition =
            'Tax Deducted at Source — the bank deducts 10% tax on FD interest >₹40,000/year (₹50,000 for seniors) before crediting you. Submit Form 15G/H to avoid TDS if your income is below taxable limit.';

  const JargonTooltip.isin({super.key})
      : term = 'ISIN',
        definition =
            'International Securities Identification Number — a 12-character alphanumeric code (e.g. INE009A01021) that uniquely identifies a security across global markets.';

  const JargonTooltip.greeks({super.key})
      : term = 'Greeks',
        definition =
            'Options Greeks measure sensitivity of an option\'s price to various factors:\n• Delta: price change per ₹1 move in underlying\n• Theta: time decay per day\n• Vega: sensitivity to volatility\n• Gamma: rate of Delta change';

  const JargonTooltip.drawdown({super.key})
      : term = 'Drawdown',
        definition =
            'Maximum Drawdown — the peak-to-trough decline before a new peak is reached. E.g. if a fund fell from ₹100 to ₹70 before recovering, the drawdown is 30%.';

  const JargonTooltip.section80c({super.key})
      : term = '80C',
        definition =
            'Section 80C of the Income Tax Act — allows deductions up to ₹1.5L/year for investments in PPF, ELSS, NPS (Tier 1), LIC, NSC, tax-saver FDs, etc. Reduces your taxable income.';

  const JargonTooltip.sipDate({super.key})
      : term = 'SIP Date',
        definition =
            'Systematic Investment Plan Date — the date each month when your SIP amount is auto-debited and invested in the mutual fund. Common SIP dates: 1st, 5th, 10th, 15th, 25th of the month.';

  void _showDefinition(BuildContext context) {
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(term),
        content: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(definition),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showDefinition(context),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Icon(
          CupertinoIcons.info_circle,
          size: 14,
          color: AppStyles.aetherTeal.withValues(alpha: 0.75),
        ),
      ),
    );
  }
}
