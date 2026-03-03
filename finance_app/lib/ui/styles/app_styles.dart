import 'package:flutter/material.dart';

class AppStyles {
  // --- Colors ---
  static const Color lightBackground = Color(0xFFF3F9FF);
  static const Color darkBackground = Color(0xFF000000);

  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color darkCard = Color(0xFF0D0D0D);

  static const Color lightText = Color(0xFF102746);
  static const Color darkText = Color(0xFFF2F7FF);

  static const Color accentBlue = Color(0xFF0A84FF);
  static const Color accentGreen = Color(0xFF1CCF87);
  static const Color accentOrange = Color(0xFFFFAA2C);
  static const Color accentCoral = Color(0xFFFF5F7A);
  static const Color accentTeal = Color(0xFF07B2CC);

  // --- Getters for Theme-Aware Colors ---
  static Color getBackground(BuildContext context) {
    return isDarkMode(context) ? darkBackground : lightBackground;
  }

  static Color getCardColor(BuildContext context) {
    return isDarkMode(context) ? darkCard : lightCard;
  }

  static Color getTextColor(BuildContext context) {
    return isDarkMode(context) ? darkText : lightText;
  }

  static Color getSecondaryTextColor(BuildContext context) {
    return isDarkMode(context)
        ? const Color(0xFF8E8E93)
        : const Color(0xFF49617F);
  }

  static Color getPrimaryColor(BuildContext context) {
    return isDarkMode(context) ? const Color(0xFF67C2FF) : accentBlue;
  }

  static Color getDividerColor(BuildContext context) {
    return isDarkMode(context)
        ? const Color(0xFF1C1C1C)
        : const Color(0xFFC5D9F9);
  }

  static bool isDarkMode(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  static LinearGradient backgroundGradient(BuildContext context) {
    if (isDarkMode(context)) {
      return const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF000000),
          Color(0xFF050505),
          Color(0xFF080808),
        ],
      );
    }
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFFF9FDFF),
        Color(0xFFF2F8FF),
        Color(0xFFEAF3FF),
      ],
    );
  }

  static List<BoxShadow> elevatedShadows(
    BuildContext context, {
    Color? tint,
    double strength = 1.0,
  }) {
    final isDark = isDarkMode(context);
    final glow = tint ?? getPrimaryColor(context);
    if (isDark) {
      return [
        BoxShadow(
          color: glow.withValues(alpha: 0.22 * strength),
          blurRadius: 26,
          offset: const Offset(0, 12),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.42 * strength),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ];
    }
    return [
      BoxShadow(
        color: glow.withValues(alpha: 0.16 * strength),
        blurRadius: 28,
        offset: const Offset(0, 12),
      ),
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.09 * strength),
        blurRadius: 14,
        offset: const Offset(0, 5),
      ),
    ];
  }

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
        colors: [
          getCardColor(context),
          isDark
              ? const Color(0xFF111111).withValues(alpha: 0.95)
              : Colors.white.withValues(alpha: 0.92),
        ],
      ),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: base.withValues(alpha: isDark ? 0.40 : 0.22),
        width: 1.0,
      ),
      boxShadow: elevated
          ? elevatedShadows(
              context,
              tint: base.withValues(alpha: isDark ? 0.85 : 1.0),
              strength: 0.9,
            )
          : null,
    );
  }

  // --- Decorations (The "Insane" Look) ---
  static BoxDecoration cardDecoration(BuildContext context) {
    final isDark = isDarkMode(context);
    return BoxDecoration(
      gradient: isDark
          ? const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF111111),
                Color(0xFF0A0A0A),
              ],
            )
          : const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFFFFFFF),
                Color(0xFFF4FAFF),
              ],
            ),
      border: Border.all(
        color: isDark
            ? const Color(0xFF2A2A2A).withValues(alpha: 0.90)
            : const Color(0xFFBCD6FF).withValues(alpha: 0.96),
        width: 1.05,
      ),
      borderRadius: BorderRadius.circular(24),
      boxShadow: elevatedShadows(context),
    );
  }

  static BoxDecoration iconBoxDecoration(BuildContext context, Color color) {
    final isDark = isDarkMode(context);
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          color.withValues(alpha: isDark ? 0.30 : 0.20),
          color.withValues(alpha: isDark ? 0.44 : 0.34),
        ],
      ),
      border: Border.all(
        color: color.withValues(alpha: isDark ? 0.58 : 0.40),
      ),
      borderRadius: BorderRadius.circular(18),
      boxShadow: [
        BoxShadow(
          color: color.withValues(alpha: isDark ? 0.26 : 0.18),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  // --- Text Styles ---
  static TextStyle headerStyle(BuildContext context) {
    return TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: isDarkMode(context)
          ? const Color(0xFF8E8E93)
          : const Color(0xFF365A88),
      letterSpacing: 0.4,
    );
  }

  static TextStyle titleStyle(BuildContext context) {
    return TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w800,
      color: getTextColor(context),
      letterSpacing: -0.2,
    );
  }

  static BoxDecoration tabDecoration(
    BuildContext context, {
    required bool selected,
    required Color color,
  }) {
    final background = selected
        ? color.withValues(alpha: isDarkMode(context) ? 0.34 : 0.19)
        : getCardColor(context).withValues(alpha: 0.82);
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: selected
            ? [
                color.withValues(alpha: isDarkMode(context) ? 0.34 : 0.22),
                color.withValues(alpha: isDarkMode(context) ? 0.22 : 0.14),
              ]
            : [
                background,
                getCardColor(context).withValues(alpha: 0.92),
              ],
      ),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: selected
            ? color.withValues(alpha: 0.85)
            : getDividerColor(context).withValues(alpha: 0.55),
      ),
      boxShadow: selected
          ? elevatedShadows(
              context,
              tint: color,
              strength: 0.7,
            )
          : null,
    );
  }
}
