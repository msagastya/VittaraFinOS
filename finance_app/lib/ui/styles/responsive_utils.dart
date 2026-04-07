// ─────────────────────────────────────────────────────────────────────────────
// responsive_utils.dart — VittaraFinOS Responsive Design System
// ─────────────────────────────────────────────────────────────────────────────
//
// Provides:
//   Breakpoints — device breakpoint detection (xs → tabletLarge + foldInner)
//   RS          — responsive spacing (scales Spacing.* by screen width)
//   RT          — responsive typography (scales TypeScale.* by screen width)
//   RLayout     — layout helpers (tablet constraints, dynamic grid ratios)
//
// Reference design width: 480dp (Samsung Galaxy S24 Ultra)
// Critical fix target:    393dp (Motorola G-series)
// Scale at 393dp: 393/480 = 0.819  →  RT factor = 0.91
//
// Usage:
//   import 'package:vittara_fin_os/ui/styles/responsive_utils.dart';
//
//   RS.lg(context)         instead of  Spacing.lg
//   RT.title2(context)     instead of  TypeScale.title2
//   Breakpoints.of(context)            → AppBreakpoint enum value
//   RLayout.tabletConstrain(context, child)
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Breakpoints
// ─────────────────────────────────────────────────────────────────────────────

enum AppBreakpoint {
  /// 0–359dp — budget Android, very compact phones
  xs,

  /// 360–392dp — Motorola G series, Galaxy A-series, Pixel 3a
  sm,

  /// 393–411dp — iPhone 14/15 standard, Pixel 7/8, most flagships
  md,

  /// 412–479dp — Galaxy S22/S23, Pixel 7 Pro, iPhone 14/15 Plus
  lg,

  /// 480–767dp — Galaxy S24 Ultra (reference width), Fold outer screen
  xl,

  /// 720–840dp with aspect ratio < 1.4 — Galaxy Z Fold 6 inner, Pixel Fold inner
  foldInner,

  /// 768–1023dp — iPad mini, Samsung Galaxy Tab A
  tablet,

  /// 1024dp+ — iPad Pro, Samsung Galaxy Tab S
  tabletLarge,
}

class Breakpoints {
  Breakpoints._();

  static AppBreakpoint of(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final w = size.width;
    final ratio = size.width / size.height;

    // Fold inner: wide but near-square (both dimensions large)
    if (w >= 720 && w < 900 && ratio < 1.4) return AppBreakpoint.foldInner;
    if (w >= 1024) return AppBreakpoint.tabletLarge;
    if (w >= 768)  return AppBreakpoint.tablet;
    if (w >= 480)  return AppBreakpoint.xl;
    if (w >= 412)  return AppBreakpoint.lg;
    if (w >= 393)  return AppBreakpoint.md;
    if (w >= 360)  return AppBreakpoint.sm;
    return AppBreakpoint.xs;
  }

  /// True on iPad, Galaxy Tab, and Fold inner screens
  static bool isTabletOrLarger(BuildContext context) {
    final bp = of(context);
    return bp == AppBreakpoint.tablet ||
        bp == AppBreakpoint.tabletLarge ||
        bp == AppBreakpoint.foldInner;
  }

  /// True on Galaxy Z Fold inner / Pixel Fold inner
  static bool isFoldInner(BuildContext context) =>
      of(context) == AppBreakpoint.foldInner;

  /// True on narrow phones (Motorola G, budget Android, Fold outer)
  static bool isNarrowPhone(BuildContext context) {
    final bp = of(context);
    return bp == AppBreakpoint.xs || bp == AppBreakpoint.sm;
  }

  /// True on wide phones (Galaxy S22/S23/S24 Ultra)
  static bool isWidePhone(BuildContext context) {
    final bp = of(context);
    return bp == AppBreakpoint.lg || bp == AppBreakpoint.xl;
  }

  /// True in landscape OR on tablet/fold inner (both should show split layout)
  static bool shouldShowSplitLayout(BuildContext context) =>
      AppStyles.isLandscape(context) || isTabletOrLarger(context);
}

// ─────────────────────────────────────────────────────────────────────────────
// RS — Responsive Spacing
//
// Scale factor = screenWidth / 480dp, clamped [0.78, 1.15].
// At 393dp: 393/480 = 0.819 → all spacing ~18% smaller than reference.
// At 360dp: clamped to 0.78.
// At 768dp: clamped to 1.15.
//
// Usage: RS.lg(context) returns a double — use as padding/margin/gap value.
// ─────────────────────────────────────────────────────────────────────────────

class RS {
  RS._();

  /// Raw scale factor (0.78 – 1.15)
  static double factor(BuildContext context) =>
      (MediaQuery.of(context).size.width / 480.0).clamp(0.78, 1.15);

  // Scaled spacing values — drop-in replacements for Spacing.*
  static double xxs(BuildContext context)  => Spacing.xxs  * factor(context);
  static double xs(BuildContext context)   => Spacing.xs   * factor(context);
  static double sm(BuildContext context)   => Spacing.sm   * factor(context);
  static double md(BuildContext context)   => Spacing.md   * factor(context);
  static double lg(BuildContext context)   => Spacing.lg   * factor(context);
  static double xl(BuildContext context)   => Spacing.xl   * factor(context);
  static double xxl(BuildContext context)  => Spacing.xxl  * factor(context);
  static double xxxl(BuildContext context) => Spacing.xxxl * factor(context);
  static double huge(BuildContext context) => Spacing.huge * factor(context);

  // Convenience EdgeInsets builders
  static EdgeInsets all(BuildContext context, double base) =>
      EdgeInsets.all(base * factor(context));

  static EdgeInsets symmetric(
    BuildContext context, {
    double h = 0,
    double v = 0,
  }) =>
      EdgeInsets.symmetric(
        horizontal: h * factor(context),
        vertical: v * factor(context),
      );

  static EdgeInsets only(
    BuildContext context, {
    double left = 0,
    double right = 0,
    double top = 0,
    double bottom = 0,
  }) {
    final f = factor(context);
    return EdgeInsets.only(
      left: left * f,
      right: right * f,
      top: top * f,
      bottom: bottom * f,
    );
  }

  /// Standard horizontal screen padding (responsive)
  static EdgeInsets screenH(BuildContext context) =>
      EdgeInsets.symmetric(horizontal: lg(context));

  /// Standard card padding (responsive)
  static EdgeInsets card(BuildContext context) =>
      EdgeInsets.all(xl(context));
}

// ─────────────────────────────────────────────────────────────────────────────
// RT — Responsive Typography
//
// Per-breakpoint scale factors applied to TypeScale.* values.
// Caption/footnote/micro are clamped to prevent unreadably tiny text.
//
// Usage: RT.title2(context) returns a double fontSize.
// ─────────────────────────────────────────────────────────────────────────────

class RT {
  RT._();

  /// Scale factor per breakpoint
  static double factor(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    if (w < 360) return 0.86;   // xs  — very small budget phones
    if (w < 393) return 0.91;   // sm  — Motorola G-series (critical)
    if (w < 412) return 0.96;   // md  — iPhone 14/15, Pixel 7
    if (w < 480) return 1.00;   // lg  — Galaxy S22/S23
    if (w >= 768) return 1.10;  // tablet / tabletLarge
    return 1.04;                 // xl  — Galaxy S24 Ultra (reference)
  }

  // Display / Hero — largest sizes, most impact on narrow screens
  static double display(BuildContext context) =>
      TypeScale.display     * factor(context);
  static double displayLarge(BuildContext context) =>
      TypeScale.displayLarge * factor(context);
  static double hero(BuildContext context) =>
      TypeScale.hero        * factor(context);

  // Titles
  static double largeTitle(BuildContext context) =>
      TypeScale.largeTitle  * factor(context);
  static double title1(BuildContext context) =>
      TypeScale.title1      * factor(context);
  static double title2(BuildContext context) =>
      TypeScale.title2      * factor(context);
  static double title3(BuildContext context) =>
      TypeScale.title3      * factor(context);

  // Body
  static double headline(BuildContext context) =>
      TypeScale.headline    * factor(context);
  static double body(BuildContext context) =>
      TypeScale.body        * factor(context);
  static double callout(BuildContext context) =>
      TypeScale.callout     * factor(context);
  static double subhead(BuildContext context) =>
      TypeScale.subhead     * factor(context);

  // Small — clamped to readable minimums
  static double footnote(BuildContext context) =>
      (TypeScale.footnote * factor(context)).clamp(11.0, 14.0);
  static double caption(BuildContext context) =>
      (TypeScale.caption  * factor(context)).clamp(10.0, 13.0);
  static double label(BuildContext context) =>
      (TypeScale.label    * factor(context)).clamp(9.0,  12.0);
  static double micro(BuildContext context) =>
      (TypeScale.micro    * factor(context)).clamp(8.0,  10.0);
}

// ─────────────────────────────────────────────────────────────────────────────
// RLayout — Responsive Layout Helpers
// ─────────────────────────────────────────────────────────────────────────────

class RLayout {
  RLayout._();

  /// Max width for modal/sheet content on tablet and fold inner screens.
  /// Returns double.infinity on phones (no constraint needed).
  static double sheetMaxWidth(BuildContext context) =>
      Breakpoints.isTabletOrLarger(context) ? 560.0 : double.infinity;

  /// Wraps [child] in a centered ConstrainedBox(maxWidth: 560) on
  /// tablet/fold inner, passthrough on phones.
  static Widget tabletConstrain(BuildContext context, Widget child) {
    if (!Breakpoints.isTabletOrLarger(context)) return child;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: child,
      ),
    );
  }

  /// Compute a dynamic childAspectRatio from a LayoutBuilder's constraints.
  ///
  /// [constraints]       — from LayoutBuilder builder parameter
  /// [crossAxisCount]    — number of columns in the grid
  /// [crossAxisSpacing]  — spacing between columns
  /// [targetHeightRatio] — desired height as fraction of item width (e.g. 1.1
  ///                       means height = 110% of width)
  ///
  /// Usage:
  ///   LayoutBuilder(builder: (ctx, constraints) {
  ///     return GridView.builder(
  ///       gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
  ///         crossAxisCount: 2,
  ///         childAspectRatio: RLayout.gridAspectRatio(constraints, 2),
  ///         ...
  ///       ),
  ///     );
  ///   })
  static double gridAspectRatio(
    BoxConstraints constraints,
    int crossAxisCount, {
    double crossAxisSpacing = 12.0,
    double targetHeightRatio = 1.1,
  }) {
    final itemWidth = (constraints.maxWidth -
            (crossAxisCount - 1) * crossAxisSpacing) /
        crossAxisCount;
    final itemHeight = itemWidth * targetHeightRatio;
    return itemWidth / itemHeight;
  }

  /// Particle count for SubtleParticleOverlay — reduced on larger screens
  /// to avoid rendering overhead.
  static int particleCount(BuildContext context, {int phone = 30}) {
    if (Breakpoints.isTabletOrLarger(context)) return (phone * 0.5).round();
    if (Breakpoints.isNarrowPhone(context)) return (phone * 0.8).round();
    return phone;
  }
}
