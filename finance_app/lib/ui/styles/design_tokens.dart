import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

// ============================================================
// DESIGN TOKENS - VittaraFinOS Design System
// ============================================================
// This file contains all design tokens for consistent UI/UX
// across the entire application. Use these tokens instead of
// hardcoded values for maintainability and consistency.
// ============================================================

/// Spacing scale for consistent padding and margins
class Spacing {
  Spacing._();

  static const double xxs = 2.0;
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double xxxl = 32.0;
  static const double huge = 48.0;
  static const double massive = 64.0;

  // Common padding presets
  static const EdgeInsets screenPadding = EdgeInsets.symmetric(horizontal: lg);
  static const EdgeInsets cardPadding = EdgeInsets.all(xl);
  static const EdgeInsets listItemPadding = EdgeInsets.symmetric(horizontal: lg, vertical: md);
  static const EdgeInsets modalPadding = EdgeInsets.all(xxl);
  static const EdgeInsets buttonPadding = EdgeInsets.symmetric(horizontal: lg, vertical: md);
}

/// Animation durations for consistent timing
class AppDurations {
  AppDurations._();

  static const Duration instant = Duration(milliseconds: 50);
  static const Duration fastest = Duration(milliseconds: 100);
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 200);
  static const Duration medium = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 400);
  static const Duration slower = Duration(milliseconds: 500);
  static const Duration slowest = Duration(milliseconds: 600);
  static const Duration emphasis = Duration(milliseconds: 800);
  static const Duration dramatic = Duration(milliseconds: 1000);
  static const Duration stagger = Duration(milliseconds: 50);

  // Specific animation contexts
  static const Duration pageTransition = Duration(milliseconds: 300);
  static const Duration pageTransitionReverse = Duration(milliseconds: 250);
  static const Duration buttonPress = Duration(milliseconds: 100);
  static const Duration fadeIn = Duration(milliseconds: 400);
  static const Duration counter = Duration(milliseconds: 800);
  static const Duration toast = Duration(milliseconds: 300);
  static const Duration toastDisplay = Duration(seconds: 3);
  static const Duration fabFade = Duration(seconds: 4);
  static const Duration shake = Duration(milliseconds: 400);
  static const Duration pulse = Duration(milliseconds: 1500);
}

/// Border radius tokens for consistent corner rounding
class Radii {
  Radii._();

  static const double none = 0.0;
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double full = 999.0;

  // Common border radius presets
  static BorderRadius get cardRadius => BorderRadius.circular(xxl);
  static BorderRadius get buttonRadius => BorderRadius.circular(md);
  static BorderRadius get inputRadius => BorderRadius.circular(md);
  static BorderRadius get modalRadius => const BorderRadius.vertical(top: Radius.circular(24));
  static BorderRadius get iconBoxRadius => BorderRadius.circular(lg);
  static BorderRadius get pillRadius => BorderRadius.circular(full);
  static BorderRadius get chipRadius => BorderRadius.circular(sm);
}

/// Shadow presets for elevation effects
class Shadows {
  Shadows._();

  // Light mode shadows
  static List<BoxShadow> cardLight = [
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
  ];

  // Dark mode shadows (subtle glow for AMOLED)
  static List<BoxShadow> cardDark = [
    BoxShadow(
      color: Colors.white.withValues(alpha: 0.05),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];

  // FAB shadow
  static List<BoxShadow> fab(Color color) => [
    BoxShadow(
      color: color.withValues(alpha: 0.4),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ];

  // Elevated shadow for modals/sheets
  static List<BoxShadow> elevated = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.15),
      offset: const Offset(0, -4),
      blurRadius: 20,
      spreadRadius: 0,
    ),
  ];

  // Icon glow effect
  static List<BoxShadow> iconGlow(Color color) => [
    BoxShadow(
      color: color.withValues(alpha: 0.2),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ];
}

/// Semantic colors for different states and actions
class SemanticColors {
  SemanticColors._();

  // Primary actions
  static const Color primary = Color(0xFF007AFF);
  static const Color primaryDark = Color(0xFF0A84FF);

  // Success states
  static const Color success = Color(0xFF34C759);
  static const Color successDark = Color(0xFF30D158);

  // Warning states
  static const Color warning = Color(0xFFFF9500);
  static const Color warningDark = Color(0xFFFF9F0A);

  // Error/Destructive states
  static const Color error = Color(0xFFFF3B30);
  static const Color errorDark = Color(0xFFFF453A);

  // Info states
  static const Color info = Color(0xFF5856D6);
  static const Color infoDark = Color(0xFF5E5CE6);

  // Domain-specific colors
  static const Color banks = Color(0xFF007AFF);
  static const Color accounts = Color(0xFF34C759);
  static const Color paymentApps = Color(0xFF5856D6);
  static const Color investments = Color(0xFFFF9500);
  static const Color liabilities = Color(0xFFFF3B30);
  static const Color categories = Color(0xFFAF52DE);
  static const Color contacts = Color(0xFF8B4513);
  static const Color lending = Color(0xFF30B0C0);
  static const Color tags = Color(0xFF5856D6);

  /// Get color based on theme
  static Color getPrimary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? primaryDark : primary;
  }

  static Color getSuccess(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? successDark : success;
  }

  static Color getWarning(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? warningDark : warning;
  }

  static Color getError(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? errorDark : error;
  }

  static Color getInfo(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? infoDark : info;
  }
}

/// Icon sizes for consistency
class IconSizes {
  IconSizes._();

  static const double xs = 14.0;
  static const double sm = 18.0;
  static const double md = 22.0;
  static const double lg = 26.0;
  static const double xl = 32.0;
  static const double xxl = 40.0;
  static const double huge = 64.0;

  // Context-specific sizes
  static const double navIcon = 24.0;
  static const double listItemIcon = 26.0;
  static const double cardIcon = 32.0;
  static const double emptyStateIcon = 64.0;
  static const double fabIcon = 28.0;
}

/// Typography scale
class TypeScale {
  TypeScale._();

  static const double caption = 11.0;
  static const double footnote = 12.0;
  static const double subhead = 13.0;
  static const double body = 14.0;
  static const double callout = 15.0;
  static const double headline = 16.0;
  static const double title3 = 17.0;
  static const double title2 = 20.0;
  static const double title1 = 22.0;
  static const double largeTitle = 28.0;
  static const double display = 32.0;
  static const double hero = 40.0;
}

/// Component sizes for consistent dimensions
class ComponentSizes {
  ComponentSizes._();

  // Icon boxes
  static const double iconBoxSmall = 40.0;
  static const double iconBoxMedium = 52.0;
  static const double iconBoxLarge = 60.0;
  static const double iconBoxXLarge = 80.0;

  // Buttons
  static const double buttonHeight = 44.0;
  static const double buttonHeightSmall = 36.0;
  static const double buttonHeightLarge = 52.0;

  // FAB
  static const double fabSize = 56.0;
  static const double fabSizeSmall = 44.0;

  // Cards
  static const double cardMinHeight = 80.0;
  static const double optionCardHeight = 160.0;

  // Modal
  static const double modalHandleWidth = 40.0;
  static const double modalHandleHeight = 5.0;

  // Touch targets (minimum 44pt for accessibility)
  static const double minTouchTarget = 44.0;

  // Avatar/Profile
  static const double avatarSmall = 32.0;
  static const double avatarMedium = 44.0;
  static const double avatarLarge = 64.0;
}

/// Animation curves for consistent motion
class MotionCurves {
  MotionCurves._();

  // Standard curves
  static const Curve standard = Curves.easeOutCubic;
  static const Curve standardIn = Curves.easeInCubic;
  static const Curve standardInOut = Curves.easeInOutCubic;

  // Emphasis curves (for important transitions)
  static const Curve emphasis = Curves.easeOutQuart;
  static const Curve emphasisIn = Curves.easeInQuart;

  // Bounce curves (for playful interactions)
  static const Curve bounce = Curves.elasticOut;
  static const Curve bounceIn = Curves.elasticIn;

  // Decelerate (for entering elements)
  static const Curve decelerate = Curves.decelerate;

  // Accelerate (for exiting elements)
  static const Curve accelerate = Curves.easeIn;

  // Spring-like (for natural motion)
  static const Curve spring = Curves.fastOutSlowIn;
}

/// Opacity values for consistent transparency
class Opacities {
  Opacities._();

  static const double disabled = 0.38;
  static const double hint = 0.5;
  static const double secondary = 0.6;
  static const double divider = 0.12;
  static const double overlay = 0.5;
  static const double hoverHighlight = 0.04;
  static const double pressHighlight = 0.12;
  static const double iconBackground = 0.15;
  static const double borderSubtle = 0.2;
  static const double glassDark = 0.1;
  static const double glassLight = 0.7;
  static const double fadedFab = 0.3;
}

/// Z-index/elevation levels
class Elevations {
  Elevations._();

  static const int background = 0;
  static const int card = 1;
  static const int stickyHeader = 2;
  static const int fab = 3;
  static const int modal = 4;
  static const int toast = 5;
  static const int overlay = 6;
  static const int dialog = 7;
}

/// Preset color palettes for pickers
class ColorPalettes {
  ColorPalettes._();

  static const List<Color> categoryColors = [
    Color(0xFFFF6B6B), // Red
    Color(0xFF51CF66), // Green
    Color(0xFF0099FF), // Blue
    Color(0xFFFF9800), // Orange
    Color(0xFF9C27B0), // Purple
    Color(0xFFE91E63), // Pink
    Color(0xFF00BCD4), // Cyan
    Color(0xFF4CAF50), // Light Green
    Color(0xFF8B4513), // Brown
    Color(0xFF607D8B), // Blue Grey
  ];

  static const List<Color> accountColors = [
    Color(0xFF007AFF), // Blue
    Color(0xFF34C759), // Green
    Color(0xFFFF9500), // Orange
    Color(0xFFAF52DE), // Purple
    Color(0xFFFF3B30), // Red
    Color(0xFF5856D6), // Indigo
    Color(0xFF00C7BE), // Teal
    Color(0xFFFF2D55), // Pink
  ];

  static const List<Color> gradientPresets = [
    Color(0xFF667EEA), // Purple-Blue
    Color(0xFF764BA2), // Purple
    Color(0xFFF093FB), // Pink
    Color(0xFFF5576C), // Red-Pink
    Color(0xFF4FACFE), // Light Blue
    Color(0xFF00F2FE), // Cyan
    Color(0xFF43E97B), // Green
    Color(0xFF38F9D7), // Teal
    Color(0xFFFA709A), // Rose
    Color(0xFFFEE140), // Yellow
  ];
}
