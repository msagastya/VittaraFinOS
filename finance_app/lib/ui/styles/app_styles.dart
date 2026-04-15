import 'package:flutter/material.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';

// ============================================================
// AETHER DESIGN SYSTEM — VittaraFinOS
// ============================================================
// Design philosophy: "Bioluminescent Void"
//   — Pure black void as canvas
//   — Elements emit light rather than reflect it
//   — Chromatic borders that refract like crystal
//   — Emissive glows instead of drop shadows
//   — Depth through luminance, not flat color blocks
// ============================================================

class AppStyles {
  // ── Core Color Palette ────────────────────────────────────────────────────

  static const Color lightBackground = Color(0xFFF2F6FF);
  static const Color darkBackground = Color(0xFF000000); // True void

  static const Color lightCard = Color(0xFFFFFFFF);
  // Elevation language — the 5-layer void depth system (L0–L4)
  // Every surface in the app must use one of these exactly — no inline hex.
  static const Color darkL0 = Color(0xFF000000); // Pure void — app background
  static const Color darkL1 = Color(0xFF0D0D0D); // Standard card / section
  static const Color darkL2 = Color(0xFF141414); // Elevated card / modal
  static const Color darkL3 = Color(0xFF1C1C1C); // Interactive surface / selected chip
  static const Color darkL4Divider = Color(0xFF1C1C1E); // Hairline divider / subtle border
  // Legacy alias — kept to avoid refactor churn, same value as darkL1
  static const Color darkCard = darkL1;

  // AU10-03 — WCAG AA verified: lightText #0C1E3A on lightBackground #F2F6FF ~10:1 contrast ratio
  static const Color lightText = Color(0xFF0C1E3A);
  // Starlight white — slight blue cast like light filtered through deep space
  static const Color darkText = Color(0xFFEDF2FF);

  // ── Aether Accent Palette ─────────────────────────────────────────────────
  // Each color is designed to feel like it emits photons, not reflects paint.

  /// Phosphorescent teal — primary brand color
  static const Color aetherTeal = Color(0xFF00D4AA);

  /// Electric violet — secondary, analytical contexts
  static const Color novaPurple = Color(0xFF9B7FFF);

  /// Bioluminescent gold — investments, wealth
  static const Color solarGold = Color(0xFFFFD166);

  /// Plasma crimson — loss, warnings
  static const Color plasmaRed = Color(0xFFFF4560);

  /// Bio-green — gains, success
  static const Color bioGreen = Color(0xFF00E896);

  // Legacy accent names (keep for backward compat)
  static const Color accentBlue = Color(0xFF3B8BFF);
  static const Color accentGreen = Color(0xFF00E896);
  static const Color accentOrange = Color(0xFFFF9E2C);
  static const Color accentCoral = Color(0xFFFF5580);
  static const Color accentTeal = Color(0xFF00D4AA);
  static const Color accentPurple = Color(0xFF9B7FFF);
  static const Color accentAmber = Color(0xFFFFD166);

  // ── Theme-Aware Color Getters ─────────────────────────────────────────────

  static Color getBackground(BuildContext context) =>
      isDarkMode(context) ? darkBackground : lightBackground;

  static Color getCardColor(BuildContext context) =>
      isDarkMode(context) ? darkCard : lightCard;

  static Color getTextColor(BuildContext context) =>
      isDarkMode(context) ? darkText : lightText;

  static Color getSecondaryTextColor(BuildContext context) => isDarkMode(context)
      ? Colors.white.withValues(alpha: 0.55) // 55% white — legible but clearly secondary
      : Colors.black.withValues(alpha: 0.45); // 45% black on light bg

  /// Tertiary text — captions, placeholders, timestamps, helper lines.
  static Color getTertiaryTextColor(BuildContext context) => isDarkMode(context)
      ? Colors.white.withValues(alpha: 0.30)
      : Colors.black.withValues(alpha: 0.25);

  /// Disabled text — non-interactive labels, greyed out items.
  static Color getDisabledTextColor(BuildContext context) => isDarkMode(context)
      ? Colors.white.withValues(alpha: 0.20)
      : Colors.black.withValues(alpha: 0.18);

  static Color getPrimaryColor(BuildContext context) =>
      isDarkMode(context) ? aetherTeal : const Color(0xFF0077CC);

  static Color getDividerColor(BuildContext context) => isDarkMode(context)
      ? darkL4Divider // hairline — slightly lighter than L3
      : const Color(0xFFC6C6C8); // iOS system separator

  static bool isDarkMode(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  // ── Elevation Getters — Phase 1A ─────────────────────────────────────────
  // Dark mode: true depth layers. Light mode: white card / system-grey surface.
  // Use these everywhere instead of darkBackground / darkCard directly.

  /// L0 — app background (pure void in dark, off-white in light)
  static Color l0(BuildContext context) =>
      isDarkMode(context) ? darkL0 : lightBackground;

  /// L1 — standard card / section surface
  static Color l1(BuildContext context) =>
      isDarkMode(context) ? darkL1 : lightCard;

  /// L2 — elevated card / modal container
  static Color l2(BuildContext context) =>
      isDarkMode(context) ? darkL2 : lightCard;

  /// L3 — interactive surface (selected chip, pressed state, input field bg)
  static Color l3(BuildContext context) =>
      isDarkMode(context) ? darkL3 : const Color(0xFFF2F2F7);

  // ── Unified Card Shadow — Phase 1B ───────────────────────────────────────
  // Dark: phosphorescent emissive glow. Light: true drop shadow.

  /// Standard card shadow — glow in dark, crisp drop shadow in light.
  static List<BoxShadow> cardShadow(BuildContext context) {
    if (isDarkMode(context)) return softShadows(context);
    return [
      const BoxShadow(
        color: Color(0x0F000000), // 6% black
        blurRadius: 8,
        offset: Offset(0, 2),
      ),
      const BoxShadow(
        color: Color(0x08000000), // 3% black
        blurRadius: 4,
        offset: Offset(0, 1),
      ),
    ];
  }

  /// Elevated card shadow — stronger for modals / hero cards.
  static List<BoxShadow> elevatedCardShadow(BuildContext context) {
    if (isDarkMode(context)) return elevatedShadows(context);
    return [
      const BoxShadow(
        color: Color(0x1A000000), // 10% black
        blurRadius: 16,
        offset: Offset(0, 4),
      ),
      const BoxShadow(
        color: Color(0x0A000000), // 4% black
        blurRadius: 8,
        offset: Offset(0, 2),
      ),
    ];
  }

  /// True when the device is in landscape orientation.
  /// Use this to switch between portrait and landscape layouts.
  static bool isLandscape(BuildContext context) =>
      MediaQuery.of(context).orientation == Orientation.landscape;

  /// Max width for content in landscape so it doesn't stretch edge-to-edge.
  /// Wrap modal/sheet content with ConstrainedBox(constraints: landscapeContentConstraints(context)).
  static BoxConstraints landscapeContentConstraints(BuildContext context) =>
      isLandscape(context)
          ? const BoxConstraints(maxWidth: 560)
          : const BoxConstraints(maxWidth: double.infinity);

  /// Max height for bottom sheets — 85% in portrait, 95% in landscape.
  static double sheetMaxHeight(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return isLandscape(context) ? size.height * 0.95 : size.height * 0.85;
  }

  // ── Theme-Aware Semantic Accent Getters ───────────────────────────────────
  // These are the CORRECT way to use accent colors — they adapt to light/dark.
  // Never use bioGreen/plasmaRed/solarGold/aetherTeal directly in UI widgets.
  // Those constants are designed for AMOLED void; they are harsh in light mode.

  /// Income / gain / success — bio-green in dark, deep forest green in light.
  static Color gain(BuildContext context) => isDarkMode(context)
      ? bioGreen // 0xFF00E896 — bioluminescent on void
      : const Color(0xFF00875A); // deep forest — WCAG AA on light bg

  /// Expense / loss / error — plasma crimson in dark, deep crimson in light.
  static Color loss(BuildContext context) => isDarkMode(context)
      ? plasmaRed // 0xFFFF4560 — plasma on void
      : const Color(0xFFCC1A35); // deep crimson — WCAG AA on light bg

  /// Gold / investment / wealth — solar gold in dark, dark amber in light.
  static Color gold(BuildContext context) => isDarkMode(context)
      ? solarGold // 0xFFFFD166 — bioluminescent gold on void
      : const Color(0xFF9A6800); // dark amber — WCAG AA on light bg

  /// Teal / primary brand — phosphorescent in dark, deep teal in light.
  static Color teal(BuildContext context) => isDarkMode(context)
      ? aetherTeal // 0xFF00D4AA — phosphorescent on void
      : const Color(0xFF007A6E); // deep teal — WCAG AA on light bg

  /// Violet / analytical — nova purple in dark, deeper violet in light.
  static Color violet(BuildContext context) => isDarkMode(context)
      ? novaPurple // 0xFF9B7FFF — on void
      : const Color(0xFF5B3FCC); // deep violet — WCAG AA on light bg

  // ── Semantic Color Aliases ────────────────────────────────────────────────

  /// Success state — bio-green (gains, confirmations)
  static const Color successColor = bioGreen;

  /// Error / loss state — plasma crimson
  static const Color errorColor = plasmaRed;

  /// Warning / caution state — amber
  static const Color warningColor = accentOrange;

  /// Primary interactive action — phosphorescent teal
  static const Color primaryAction = aetherTeal;

  /// Disabled / muted state — theme-aware neutral
  static Color disabledColor(BuildContext context) => isDarkMode(context)
      ? const Color(0xFF3A4A5C)
      : const Color(0xFFBBCCDD);

  /// Neutral / flat / zero-change state — mid-gray, readable in both themes.
  static Color neutral(BuildContext context) => isDarkMode(context)
      ? const Color(0xFF8E8E93)
      : const Color(0xFF6B6B6B);

  /// Warning / 80% budget / caution — amber adapts for WCAG AA in light.
  static Color warning(BuildContext context) => isDarkMode(context)
      ? const Color(0xFFFF9F0A) // iOS systemOrange, vivid on void
      : const Color(0xFF9A5700); // dark amber — WCAG AA on light bg

  /// Informational / neutral action — blue adapts for WCAG AA in light.
  static Color info(BuildContext context) => isDarkMode(context)
      ? const Color(0xFF0A84FF) // iOS systemBlue on dark
      : const Color(0xFF0062CC); // deep blue — WCAG AA on light bg

  /// Card surface — elevated void in dark, white in light.
  static Color surface(BuildContext context) =>
      isDarkMode(context) ? darkCard : lightCard;

  // ── Background Gradients ──────────────────────────────────────────────────

  static LinearGradient backgroundGradient(BuildContext context) {
    if (isDarkMode(context)) {
      // Void depth: pure black → ultra-subtle cosmic tint toward center
      return const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF000000),
          Color(0xFF020509),
          Color(0xFF030710),
          Color(0xFF020509),
          Color(0xFF000000),
        ],
        stops: [0.0, 0.2, 0.5, 0.8, 1.0],
      );
    }
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFF6FAFF), Color(0xFFEEF5FF), Color(0xFFE6F0FF)],
    );
  }

  // ── Premium Hero Gradient ─────────────────────────────────────────────────

  /// Deep space hero — aetherTeal emissive edge at bottom
  static LinearGradient heroGradient({bool isDark = true}) => isDark
      ? const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF040D1E), // deep void
            Color(0xFF071428), // cosmic indigo
            Color(0xFF061832), // deep ocean
            Color(0xFF082B40), // aether-tinted deep
          ],
          stops: [0.0, 0.35, 0.70, 1.0],
        )
      : const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0055AA),
            Color(0xFF0077CC),
            Color(0xFF0099CC),
          ],
        );

  // ── Investment-type Hero Gradient ─────────────────────────────────────────

  /// Returns a hero gradient tinted toward the given accent color.
  static LinearGradient accentHeroGradient(Color accent, {bool isDark = true}) {
    if (!isDark) return heroGradient(isDark: false);
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        const Color(0xFF040D1E),
        Color.lerp(const Color(0xFF071428), accent, 0.12)!,
        Color.lerp(const Color(0xFF061832), accent, 0.20)!,
      ],
    );
  }

  // ── Shadow System — Emissive Glows ────────────────────────────────────────
  // Traditional drop shadows simulate light from above.
  // Emissive glows simulate an element that IS a light source.

  /// Primary emissive glow — large, soft, colour-tinted.
  static List<BoxShadow> elevatedShadows(
    BuildContext context, {
    Color? tint,
    double strength = 1.0,
  }) {
    final isDark = isDarkMode(context);
    final glow = tint ?? getPrimaryColor(context);

    if (isDark) {
      return [
        // Wide ambient glow — the element "breathing" light into the void
        BoxShadow(
          color: glow.withValues(alpha: 0.18 * strength),
          blurRadius: 48,
          spreadRadius: -6,
          offset: const Offset(0, 0),
        ),
        // Tight focused emissive ring
        BoxShadow(
          color: glow.withValues(alpha: 0.28 * strength),
          blurRadius: 20,
          spreadRadius: -4,
          offset: const Offset(0, 8),
        ),
        // Subtle depth anchor (downward only)
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.70 * strength),
          blurRadius: 16,
          spreadRadius: 0,
          offset: const Offset(0, 12),
        ),
      ];
    }
    return [
      BoxShadow(
        color: glow.withValues(alpha: 0.20 * strength),
        blurRadius: 32,
        spreadRadius: -4,
        offset: const Offset(0, 12),
      ),
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.08 * strength),
        blurRadius: 12,
        spreadRadius: -2,
        offset: const Offset(0, 4),
      ),
    ];
  }

  /// Soft ambient glow — used on most cards.
  static List<BoxShadow> softShadows(BuildContext context) {
    final isDark = isDarkMode(context);
    if (isDark) {
      return [
        // Ultra-subtle ambient teal emission (like phosphorescence)
        BoxShadow(
          color: aetherTeal.withValues(alpha: 0.05),
          blurRadius: 40,
          spreadRadius: -8,
          offset: const Offset(0, 0),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.60),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ];
    }
    return [
      BoxShadow(
        color: const Color(0xFF0077CC).withValues(alpha: 0.08),
        blurRadius: 20,
        offset: const Offset(0, 6),
      ),
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.05),
        blurRadius: 10,
        offset: const Offset(0, 3),
      ),
    ];
  }

  // ── Card Decorations ──────────────────────────────────────────────────────

  /// Standard card — void depth with chromatic crystal border.
  /// The border gradient makes it feel like light refracting through crystal edge.
  static BoxDecoration cardDecoration(BuildContext context) {
    final isDark = isDarkMode(context);
    return BoxDecoration(
      color: isDark ? darkL1 : lightCard,
      border: Border.all(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06) // barely-there crystal rim
            : const Color(0xFFDDE8F5),
        width: 1.0,
      ),
      borderRadius: BorderRadius.circular(Radii.xxl),
      boxShadow: cardShadow(context),
    );
  }

  /// Bottom sheet / modal — same card gradient with top-only rounded corners.
  /// Use this for ALL showCupertinoModalPopup / showModalBottomSheet containers.
  ///
  /// AU11-03 — Tablet responsiveness: callers should wrap sheet content with:
  ///   `ConstrainedBox(constraints: BoxConstraints(maxWidth: 600), child: ...)`
  /// and center it for landscape tablet layouts. This ensures sheets don't
  /// stretch to the full screen width on iPad or large-screen Android devices.
  static BoxDecoration bottomSheetDecoration(BuildContext context) {
    final isDark = isDarkMode(context);
    return BoxDecoration(
      color: isDark ? darkL2 : lightCard,
      border: Border(
        top: BorderSide(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFFDDE8F5),
          width: 0.5,
        ),
      ),
      borderRadius: Radii.modalRadius,
    );
  }

  /// Hero card — deep space with aether emissive border glow.
  static BoxDecoration heroCardDecoration(BuildContext context) {
    final isDark = isDarkMode(context);
    return BoxDecoration(
      gradient: heroGradient(isDark: isDark),
      border: Border.all(
        color: isDark
            ? aetherTeal.withValues(alpha: 0.35) // teal emissive rim
            : const Color(0xFF0077CC).withValues(alpha: 0.60),
        width: 1.2,
      ),
      borderRadius: BorderRadius.circular(Radii.xxl),
      boxShadow: elevatedShadows(
        context,
        tint: isDark ? aetherTeal : accentBlue,
        strength: 1.0,
      ),
    );
  }

  /// Quantum card — near-transparent fill, luminous chromatic border.
  /// Used for premium/featured items. The card "exists" only as its emissive border.
  static BoxDecoration quantumCardDecoration(
    BuildContext context,
    Color accent,
  ) {
    final isDark = isDarkMode(context);
    return BoxDecoration(
      color: isDark
          ? accent.withValues(alpha: 0.04) // nearly invisible fill
          : accent.withValues(alpha: 0.06),
      border: Border.all(
        color: accent.withValues(alpha: isDark ? 0.50 : 0.35),
        width: 1.2,
      ),
      borderRadius: BorderRadius.circular(Radii.xxl),
      boxShadow: [
        // Wide emissive glow
        BoxShadow(
          color: accent.withValues(alpha: isDark ? 0.14 : 0.10),
          blurRadius: 44,
          spreadRadius: -8,
          offset: Offset.zero,
        ),
        // Tight inner emissive ring
        BoxShadow(
          color: accent.withValues(alpha: isDark ? 0.22 : 0.15),
          blurRadius: 16,
          spreadRadius: -4,
          offset: const Offset(0, 6),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.65 : 0.05),
          blurRadius: 14,
          offset: const Offset(0, 10),
        ),
      ],
    );
  }

  /// Section card — accent tint with luminous border.
  static BoxDecoration sectionDecoration(
    BuildContext context, {
    Color? tint,
    double radius = 22,
    bool elevated = true,
  }) {
    final base = tint ?? getPrimaryColor(context);
    final isDark = isDarkMode(context);
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? [
                Color.lerp(darkL1, base, 0.10)!,
                Color.lerp(darkL2, base, 0.04)!,
              ]
            : [
                Colors.white,
                Color.lerp(Colors.white, base, 0.04)!,
              ],
      ),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: base.withValues(alpha: isDark ? 0.40 : 0.22),
        width: 1.0,
      ),
      boxShadow: elevated
          ? elevatedShadows(context, tint: base, strength: 0.80)
          : null,
    );
  }

  /// Accent card — emissive left-edge glow tinted by accent.
  static BoxDecoration accentCardDecoration(
    BuildContext context,
    Color accent,
  ) {
    final isDark = isDarkMode(context);
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? [
                Color.lerp(darkL1, accent, 0.08)!,
                Color.lerp(darkL2, accent, 0.03)!,
              ]
            : [
                Color.lerp(Colors.white, accent, 0.08)!,
                Colors.white,
              ],
      ),
      border: Border.all(
        color: accent.withValues(alpha: isDark ? 0.32 : 0.28),
        width: 1.0,
      ),
      borderRadius: BorderRadius.circular(Radii.xxl),
      boxShadow: elevatedShadows(context, tint: accent, strength: 0.60),
    );
  }

  /// Icon box — gradient fill with emissive glow matching the icon color.
  static BoxDecoration iconBoxDecoration(BuildContext context, Color color) {
    final isDark = isDarkMode(context);
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          color.withValues(alpha: isDark ? 0.28 : 0.24),
          color.withValues(alpha: isDark ? 0.42 : 0.40),
        ],
      ),
      border: Border.all(
        color: color.withValues(alpha: isDark ? 0.55 : 0.38),
        width: 1.0,
      ),
      borderRadius: BorderRadius.circular(Radii.lg),
      boxShadow: [
        BoxShadow(
          color: color.withValues(alpha: isDark ? 0.28 : 0.18),
          blurRadius: 18,
          spreadRadius: -3,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  /// Tab chip — selected state has emissive glow border.
  static BoxDecoration tabDecoration(
    BuildContext context, {
    required bool selected,
    required Color color,
  }) {
    final isDark = isDarkMode(context);
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: selected
            ? [
                color.withValues(alpha: isDark ? 0.28 : 0.16),
                color.withValues(alpha: isDark ? 0.16 : 0.08),
              ]
            : [
                isDark ? darkL1 : Colors.transparent,
                Colors.transparent,
              ],
      ),
      borderRadius: BorderRadius.circular(Radii.lg),
      border: Border.all(
        color: selected
            ? color.withValues(alpha: isDark ? 0.85 : 0.70)
            : getDividerColor(context).withValues(alpha: 0.60),
        width: selected ? 1.2 : 0.8,
      ),
      boxShadow: selected
          ? [
              BoxShadow(
                color: color.withValues(alpha: isDark ? 0.20 : 0.14),
                blurRadius: 16,
                spreadRadius: -4,
                offset: Offset.zero,
              ),
            ]
          : null,
    );
  }

  // ── Text Styles ───────────────────────────────────────────────────────────

  /// Section/label header — ultra-tight tracking, technical data-terminal feel.
  static TextStyle headerStyle(BuildContext context) => TextStyle(
        fontSize: TypeScale.caption,
        fontWeight: FontWeight.w700,
        color: isDarkMode(context)
            ? const Color(0xFF4A6B8A) // distant starlight
            : const Color(0xFF3A5A80),
        letterSpacing: 0.9,
      );

  /// Card/screen title — tight tracking, bold, tech terminal aesthetic.
  static TextStyle titleStyle(BuildContext context) => TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: getTextColor(context),
        letterSpacing: -0.5,
      );

  /// Large financial number — extreme tight tracking like HFT terminal display.
  static TextStyle heroNumberStyle(BuildContext context,
          {double? fontSize}) =>
      TextStyle(
        fontSize: fontSize ?? _heroFontSize(context),
        fontWeight: FontWeight.w900,
        color: Colors.white,
        letterSpacing: -1.8,
        height: 0.95,
      );

  static double _heroFontSize(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    if (w < 360) return 32;
    if (w < 393) return 34;
    if (w < 412) return 36;
    if (w < 480) return 38;
    return 40;
  }

  /// Standard amount style.
  static TextStyle amountStyle(BuildContext context, {Color? color}) =>
      TextStyle(
        fontSize: _amountFontSize(context),
        fontWeight: FontWeight.w800,
        color: color ?? getTextColor(context),
        letterSpacing: -0.7,
      );

  static double _amountFontSize(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    if (w < 360) return 18;
    if (w < 393) return 19;
    if (w < 412) return 20;
    if (w < 480) return 21;
    return 22;
  }
}
