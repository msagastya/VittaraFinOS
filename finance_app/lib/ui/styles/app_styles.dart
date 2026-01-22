import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class AppStyles {
  // --- Colors ---
  static const Color lightBackground = Color(0xFFF5F5F7);
  static const Color darkBackground = Color(0xFF000000); // AMOLED
  
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color darkCard = Color(0xFF1C1C1E);
  
  static const Color lightText = Color(0xFF1C1C1E);
  static const Color darkText = Color(0xFFFFFFFF);
  
  static const Color accentBlue = Color(0xFF007AFF);
  static const Color accentGreen = Color(0xFF34C759);
  static const Color accentOrange = Color(0xFFFF9500);

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
    return isDarkMode(context) ? const Color(0xFF8E8E93) : const Color(0xFF8E8E93);
  }

  static bool isDarkMode(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  // --- Decorations (The "Insane" Look) ---
  static BoxDecoration cardDecoration(BuildContext context) {
    final isDark = isDarkMode(context);
    return BoxDecoration(
      color: getCardColor(context),
      borderRadius: BorderRadius.circular(24), // Modern, soft corners
      boxShadow: isDark
          ? [
              // Subtle glow for AMOLED
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.05),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ]
          : [
              // Soft, premium shadow for Light mode
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                offset: const Offset(0, 4),
                blurRadius: 12,
                spreadRadius: 0,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                offset: const Offset(0, 2),
                blurRadius: 4,
                spreadRadius: 0,
              ),
            ],
    );
  }

  static BoxDecoration iconBoxDecoration(BuildContext context, Color color) {
    return BoxDecoration(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(16),
    );
  }

  // --- Text Styles ---
  static TextStyle headerStyle(BuildContext context) {
    return TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: isDarkMode(context) ? const Color(0xFF8E8E93) : const Color(0xFF636366),
      letterSpacing: 0.5,
    );
  }
  
  static TextStyle titleStyle(BuildContext context) {
    return TextStyle(
      fontSize: 17,
      fontWeight: FontWeight.w600,
      color: getTextColor(context),
      letterSpacing: -0.3,
    );
  }
}
