import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Landscape infrastructure — LandscapeRail, LandscapeRailHeader, LandscapeScaffold
//
// These three widgets are the building blocks for every landscape screen.
// In portrait mode every widget becomes a no-op / transparent pass-through.
// ─────────────────────────────────────────────────────────────────────────────

/// Fixed-width left panel container used by all landscape screens.
///
/// Provides a consistent background, optional right-border divider, and
/// ensures content never overflows the fixed width.
class LandscapeRail extends StatelessWidget {
  final Widget child;
  final double width;
  final bool showBorder;

  const LandscapeRail({
    super.key,
    required this.child,
    this.width = 210,
    this.showBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF5F5F5);
    final border =
        isDark ? const Color(0xFF1C1C1C) : const Color(0xFFDDDDDD);

    return SizedBox(
      width: width,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: bg,
          border: showBorder
              ? Border(
                  right: BorderSide(color: border, width: 0.5),
                )
              : null,
        ),
        child: child,
      ),
    );
  }
}

/// The standardised 44 px header row that sits at the top of every
/// [LandscapeRail]: back-chevron → title (caps) → optional trailing widget.
class LandscapeRailHeader extends StatelessWidget {
  final String title;
  final BuildContext outerContext;
  final Widget? trailing;
  final VoidCallback? onBack;

  const LandscapeRailHeader({
    super.key,
    required this.title,
    required this.outerContext,
    this.trailing,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? Colors.white : Colors.black;
    final subtle =
        isDark ? const Color(0xFF666666) : const Color(0xFF999999);

    return SizedBox(
      height: 44,
      child: Row(
        children: [
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: const Size(44, 44),
            onPressed:
                onBack ?? () => Navigator.of(outerContext).maybePop(),
            child: Icon(
              CupertinoIcons.chevron_left,
              size: 18,
              color: subtle,
            ),
          ),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
                color: fg,
                fontFamily: 'SpaceGrotesk',
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Two-panel landscape scaffold.
///
/// In portrait: renders [body] full-width (left rail is hidden).
/// In landscape: renders [LandscapeRail(leftRail)] | Expanded([body]) side by side.
///
/// Example:
/// ```dart
/// LandscapeScaffold(
///   railWidth: 220,
///   leftRail: Column(children: [header, summaryCard, ...]),
///   body: transactionList,
///   portraitBody: entirePortraitScreen,
/// )
/// ```
class LandscapeScaffold extends StatelessWidget {
  final Widget leftRail;
  final Widget body;

  /// Override for portrait — if null, [body] is used in portrait too.
  final Widget? portraitBody;

  final double railWidth;
  final bool showRailBorder;

  const LandscapeScaffold({
    super.key,
    required this.leftRail,
    required this.body,
    this.portraitBody,
    this.railWidth = 210,
    this.showRailBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    if (!isLandscape) {
      return portraitBody ?? body;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LandscapeRail(
          width: railWidth,
          showBorder: showRailBorder,
          child: leftRail,
        ),
        Expanded(child: body),
      ],
    );
  }
}

/// Thin horizontal divider used inside rails to separate sections.
class RailDivider extends StatelessWidget {
  final double indent;

  const RailDivider({super.key, this.indent = 12});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 0.5,
      margin: EdgeInsets.symmetric(horizontal: indent, vertical: 4),
      color: isDark ? const Color(0xFF1C1C1C) : const Color(0xFFDDDDDD),
    );
  }
}

/// A compact stat row for rail panels: label on left, value on right.
class RailStatRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const RailStatRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labelColor =
        isDark ? const Color(0xFF666666) : const Color(0xFF999999);
    final valueColor_ = valueColor ??
        (isDark ? Colors.white : Colors.black);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: labelColor,
                letterSpacing: 0.3,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: valueColor_,
              fontFamily: 'SpaceGrotesk',
            ),
          ),
        ],
      ),
    );
  }
}
