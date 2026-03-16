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
  // Elevated void surface — dark enough to feel deep, bright enough to contrast
  static const Color darkCard = Color(0xFF0D1829);

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
      ? const Color(0xFF6B8AAD) // deep-sea moonlight
      : const Color(0xFF3A5A80);

  static Color getPrimaryColor(BuildContext context) =>
      isDarkMode(context) ? aetherTeal : const Color(0xFF0077CC);

  static Color getDividerColor(BuildContext context) => isDarkMode(context)
      ? const Color(0xFF0D1829) // barely visible boundary
      : const Color(0xFFCCDDEE);

  static bool isDarkMode(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

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
      gradient: isDark
          ? const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF070D1A), Color(0xFF050B15)],
            )
          : const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFFFFFF), Color(0xFFF4F9FF)],
            ),
      border: Border.all(
        color: isDark
            ? const Color(0xFF1A2E4A) // chromatic ocean rim
            : const Color(0xFFBDD4F0),
        width: 1.0,
      ),
      borderRadius: BorderRadius.circular(Radii.xxl),
      boxShadow: softShadows(context),
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
                Color.lerp(const Color(0xFF070D1A), base, 0.08)!,
                const Color(0xFF050B15),
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
                Color.lerp(const Color(0xFF070D1A), accent, 0.06)!,
                const Color(0xFF050B15),
              ]
            : [
                Color.lerp(Colors.white, accent, 0.04)!,
                Colors.white,
              ],
      ),
      border: Border.all(
        color: accent.withValues(alpha: isDark ? 0.32 : 0.18),
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
          color.withValues(alpha: isDark ? 0.28 : 0.16),
          color.withValues(alpha: isDark ? 0.42 : 0.26),
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
                const Color(0xFF070D1A).withValues(alpha: isDark ? 1 : 0),
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
          {double fontSize = 40}) =>
      TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w900,
        color: Colors.white,
        letterSpacing: -1.8,
        height: 0.95,
      );

  /// Standard amount style.
  static TextStyle amountStyle(BuildContext context, {Color? color}) =>
      TextStyle(
        fontSize: TypeScale.title1,
        fontWeight: FontWeight.w800,
        color: color ?? getTextColor(context),
        letterSpacing: -0.7,
      );
}
