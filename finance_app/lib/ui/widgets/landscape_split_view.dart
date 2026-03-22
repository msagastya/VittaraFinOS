import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// LandscapeSplitView — SYS-04
// ─────────────────────────────────────────────────────────────────────────────
// In landscape: shows leftPanel + divider + rightPanel side by side.
// In portrait:  shows portraitLayout (or rightPanel if not provided).
//
// Usage:
//   LandscapeSplitView(
//     leftFlex: 2,
//     rightFlex: 3,
//     leftPanel: CategoryTabsAndSummary(),
//     rightPanel: HoldingsList(),
//     portraitLayout: FullScreenList(),
//   )
// ─────────────────────────────────────────────────────────────────────────────

class LandscapeSplitView extends StatelessWidget {
  /// Content in the left panel (sidebar in landscape).
  final Widget leftPanel;

  /// Content in the right panel (main content in landscape).
  final Widget rightPanel;

  /// Shown in portrait mode. Defaults to [rightPanel] if not supplied.
  final Widget? portraitLayout;

  /// Flex factor for left panel (default 2 → ~40% of width).
  final int leftFlex;

  /// Flex factor for right panel (default 3 → ~60% of width).
  final int rightFlex;

  /// Width of the divider between panels.
  final double dividerWidth;

  const LandscapeSplitView({
    super.key,
    required this.leftPanel,
    required this.rightPanel,
    this.portraitLayout,
    this.leftFlex = 2,
    this.rightFlex = 3,
    this.dividerWidth = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    if (!isLandscape) {
      return portraitLayout ?? rightPanel;
    }

    final dividerColor = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF1A2E4A) // Aether ocean border
        : const Color(0xFFCCDDEE);

    return Row(
      children: [
        // ── Left panel ──────────────────────────────────────────────────────
        Flexible(
          flex: leftFlex,
          child: leftPanel,
        ),
        // ── Vertical divider ─────────────────────────────────────────────────
        Container(
          width: dividerWidth,
          color: dividerColor,
        ),
        // ── Right panel ──────────────────────────────────────────────────────
        Flexible(
          flex: rightFlex,
          child: rightPanel,
        ),
      ],
    );
  }
}
