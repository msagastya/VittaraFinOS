import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';

/// Typography system for consistent text styling
class AppTypography {
  AppTypography._();

  /// Font families
  static const String systemFont = '.SF Pro Text';
  static const String displayFont = '.SF Pro Display';
  static const String monoFont = 'SF Mono';

  /// Font weights
  static const FontWeight ultraLight = FontWeight.w200;
  static const FontWeight light = FontWeight.w300;
  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semiBold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;
  static const FontWeight heavy = FontWeight.w800;
  static const FontWeight black = FontWeight.w900;

  /// Line heights (as multipliers)
  static const double lineHeightTight = 1.2;
  static const double lineHeightNormal = 1.4;
  static const double lineHeightRelaxed = 1.6;
  static const double lineHeightLoose = 1.8;

  /// Letter spacing
  static const double letterSpacingTight = -0.5;
  static const double letterSpacingNormal = 0.0;
  static const double letterSpacingWide = 0.5;
  static const double letterSpacingWider = 1.0;

  /// Display text styles (for heroes and large titles)
  static TextStyle display({
    Color? color,
    FontWeight? fontWeight,
  }) {
    return TextStyle(
      fontFamily: displayFont,
      fontSize: TypeScale.display,
      fontWeight: fontWeight ?? bold,
      letterSpacing: letterSpacingTight,
      height: lineHeightTight,
      color: color,
    );
  }

  static TextStyle hero({
    Color? color,
    FontWeight? fontWeight,
  }) {
    return TextStyle(
      fontFamily: displayFont,
      fontSize: TypeScale.hero,
      fontWeight: fontWeight ?? heavy,
      letterSpacing: letterSpacingTight,
      height: lineHeightTight,
      color: color,
    );
  }

  /// Title text styles
  static TextStyle largeTitle({
    Color? color,
    FontWeight? fontWeight,
  }) {
    return TextStyle(
      fontFamily: displayFont,
      fontSize: TypeScale.largeTitle,
      fontWeight: fontWeight ?? bold,
      letterSpacing: letterSpacingTight,
      height: lineHeightNormal,
      color: color,
    );
  }

  static TextStyle title1({
    Color? color,
    FontWeight? fontWeight,
  }) {
    return TextStyle(
      fontFamily: systemFont,
      fontSize: TypeScale.title1,
      fontWeight: fontWeight ?? semiBold,
      letterSpacing: letterSpacingNormal,
      height: lineHeightNormal,
      color: color,
    );
  }

  static TextStyle title2({
    Color? color,
    FontWeight? fontWeight,
  }) {
    return TextStyle(
      fontFamily: systemFont,
      fontSize: TypeScale.title2,
      fontWeight: fontWeight ?? semiBold,
      letterSpacing: letterSpacingNormal,
      height: lineHeightNormal,
      color: color,
    );
  }

  static TextStyle title3({
    Color? color,
    FontWeight? fontWeight,
  }) {
    return TextStyle(
      fontFamily: systemFont,
      fontSize: TypeScale.title3,
      fontWeight: fontWeight ?? semiBold,
      letterSpacing: letterSpacingNormal,
      height: lineHeightNormal,
      color: color,
    );
  }

  /// Body text styles
  static TextStyle headline({
    Color? color,
    FontWeight? fontWeight,
  }) {
    return TextStyle(
      fontFamily: systemFont,
      fontSize: TypeScale.headline,
      fontWeight: fontWeight ?? semiBold,
      letterSpacing: letterSpacingNormal,
      height: lineHeightNormal,
      color: color,
    );
  }

  static TextStyle body({
    Color? color,
    FontWeight? fontWeight,
  }) {
    return TextStyle(
      fontFamily: systemFont,
      fontSize: TypeScale.body,
      fontWeight: fontWeight ?? regular,
      letterSpacing: letterSpacingNormal,
      height: lineHeightRelaxed,
      color: color,
    );
  }

  static TextStyle callout({
    Color? color,
    FontWeight? fontWeight,
  }) {
    return TextStyle(
      fontFamily: systemFont,
      fontSize: TypeScale.callout,
      fontWeight: fontWeight ?? regular,
      letterSpacing: letterSpacingNormal,
      height: lineHeightNormal,
      color: color,
    );
  }

  static TextStyle subhead({
    Color? color,
    FontWeight? fontWeight,
  }) {
    return TextStyle(
      fontFamily: systemFont,
      fontSize: TypeScale.subhead,
      fontWeight: fontWeight ?? regular,
      letterSpacing: letterSpacingNormal,
      height: lineHeightNormal,
      color: color,
    );
  }

  /// Small text styles
  static TextStyle footnote({
    Color? color,
    FontWeight? fontWeight,
  }) {
    return TextStyle(
      fontFamily: systemFont,
      fontSize: TypeScale.footnote,
      fontWeight: fontWeight ?? regular,
      letterSpacing: letterSpacingNormal,
      height: lineHeightNormal,
      color: color,
    );
  }

  static TextStyle caption({
    Color? color,
    FontWeight? fontWeight,
  }) {
    return TextStyle(
      fontFamily: systemFont,
      fontSize: TypeScale.caption,
      fontWeight: fontWeight ?? regular,
      letterSpacing: letterSpacingWide,
      height: lineHeightNormal,
      color: color,
    );
  }

  /// Special purpose styles
  static TextStyle monospace({
    double? fontSize,
    Color? color,
    FontWeight? fontWeight,
  }) {
    return TextStyle(
      fontFamily: monoFont,
      fontSize: fontSize ?? TypeScale.body,
      fontWeight: fontWeight ?? regular,
      letterSpacing: letterSpacingNormal,
      height: lineHeightNormal,
      color: color,
    );
  }

  static TextStyle button({
    Color? color,
    FontWeight? fontWeight,
  }) {
    return TextStyle(
      fontFamily: systemFont,
      fontSize: TypeScale.callout,
      fontWeight: fontWeight ?? semiBold,
      letterSpacing: letterSpacingWide,
      height: lineHeightNormal,
      color: color,
    );
  }

  static TextStyle label({
    Color? color,
    FontWeight? fontWeight,
  }) {
    return TextStyle(
      fontFamily: systemFont,
      fontSize: TypeScale.footnote,
      fontWeight: fontWeight ?? medium,
      letterSpacing: letterSpacingWide,
      height: lineHeightNormal,
      color: color,
    );
  }

  /// Numeric styles (for currency, statistics)
  static TextStyle numeric({
    double? fontSize,
    Color? color,
    FontWeight? fontWeight,
  }) {
    return TextStyle(
      fontFamily: systemFont,
      fontSize: fontSize ?? TypeScale.body,
      fontWeight: fontWeight ?? semiBold,
      fontFeatures: const [FontFeature.tabularFigures()],
      letterSpacing: letterSpacingNormal,
      height: lineHeightNormal,
      color: color,
    );
  }

  static TextStyle currencyLarge({
    Color? color,
    FontWeight? fontWeight,
  }) {
    return TextStyle(
      fontFamily: displayFont,
      fontSize: TypeScale.largeTitle,
      fontWeight: fontWeight ?? bold,
      fontFeatures: const [FontFeature.tabularFigures()],
      letterSpacing: letterSpacingTight,
      height: lineHeightTight,
      color: color,
    );
  }

  static TextStyle currencyMedium({
    Color? color,
    FontWeight? fontWeight,
  }) {
    return TextStyle(
      fontFamily: systemFont,
      fontSize: TypeScale.title2,
      fontWeight: fontWeight ?? semiBold,
      fontFeatures: const [FontFeature.tabularFigures()],
      letterSpacing: letterSpacingNormal,
      height: lineHeightNormal,
      color: color,
    );
  }

  static TextStyle currencySmall({
    Color? color,
    FontWeight? fontWeight,
  }) {
    return TextStyle(
      fontFamily: systemFont,
      fontSize: TypeScale.body,
      fontWeight: fontWeight ?? medium,
      fontFeatures: const [FontFeature.tabularFigures()],
      letterSpacing: letterSpacingNormal,
      height: lineHeightNormal,
      color: color,
    );
  }
}

/// Text theme extensions for BuildContext
extension TextThemeExtension on BuildContext {
  /// Get semantic text color based on brightness
  Color get textPrimary {
    return Theme.of(this).brightness == Brightness.dark
        ? Colors.white
        : Colors.black;
  }

  Color get textSecondary {
    return Theme.of(this).brightness == Brightness.dark
        ? Colors.white.withValues(alpha: 0.6)
        : Colors.black.withValues(alpha: 0.6);
  }

  Color get textTertiary {
    return Theme.of(this).brightness == Brightness.dark
        ? Colors.white.withValues(alpha: 0.4)
        : Colors.black.withValues(alpha: 0.4);
  }

  Color get textDisabled {
    return Theme.of(this).brightness == Brightness.dark
        ? Colors.white.withValues(alpha: 0.38)
        : Colors.black.withValues(alpha: 0.38);
  }

  Color get textOnPrimary {
    return Colors.white;
  }

  /// Quick access to text styles with context colors
  TextStyle get displayStyle => AppTypography.display(color: textPrimary);
  TextStyle get heroStyle => AppTypography.hero(color: textPrimary);
  TextStyle get largeTitleStyle => AppTypography.largeTitle(color: textPrimary);
  TextStyle get title1Style => AppTypography.title1(color: textPrimary);
  TextStyle get title2Style => AppTypography.title2(color: textPrimary);
  TextStyle get title3Style => AppTypography.title3(color: textPrimary);
  TextStyle get headlineStyle => AppTypography.headline(color: textPrimary);
  TextStyle get bodyStyle => AppTypography.body(color: textPrimary);
  TextStyle get calloutStyle => AppTypography.callout(color: textPrimary);
  TextStyle get subheadStyle => AppTypography.subhead(color: textSecondary);
  TextStyle get footnoteStyle => AppTypography.footnote(color: textSecondary);
  TextStyle get captionStyle => AppTypography.caption(color: textTertiary);
}

/// Responsive typography utilities
class ResponsiveTypography {
  ResponsiveTypography._();

  /// Get scale factor based on screen width
  static double getScaleFactor(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 375) return 0.9; // Small phones
    if (width < 414) return 1.0; // Regular phones
    if (width < 768) return 1.1; // Large phones / small tablets
    return 1.2; // Tablets
  }

  /// Scale font size based on screen size
  static double scaledFontSize(BuildContext context, double baseSize) {
    return baseSize * getScaleFactor(context);
  }

  /// Create responsive text style
  static TextStyle responsive(
    BuildContext context,
    TextStyle baseStyle,
  ) {
    final scaleFactor = getScaleFactor(context);
    return baseStyle.copyWith(
      fontSize: (baseStyle.fontSize ?? 14.0) * scaleFactor,
    );
  }
}

/// Text decoration utilities
class TextDecorations {
  TextDecorations._();

  /// Gradient text effect
  static Widget gradient(
    String text,
    TextStyle style,
    Gradient gradient,
  ) {
    return ShaderMask(
      shaderCallback: (bounds) => gradient.createShader(
        Rect.fromLTWH(0, 0, bounds.width, bounds.height),
      ),
      child: Text(
        text,
        style: style.copyWith(color: Colors.white),
      ),
    );
  }

  /// Outlined text
  static Widget outlined(
    String text,
    TextStyle style, {
    Color? strokeColor,
    double strokeWidth = 2.0,
  }) {
    return Stack(
      children: [
        Text(
          text,
          style: style.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = strokeWidth
              ..color = strokeColor ?? Colors.black,
          ),
        ),
        Text(text, style: style),
      ],
    );
  }

  /// Text with shadow
  static TextStyle withShadow(
    TextStyle style, {
    Color? shadowColor,
    double blurRadius = 4.0,
    Offset offset = const Offset(0, 2),
  }) {
    return style.copyWith(
      shadows: [
        Shadow(
          color: shadowColor ?? Colors.black.withValues(alpha: 0.3),
          blurRadius: blurRadius,
          offset: offset,
        ),
      ],
    );
  }

  /// Animated gradient text
  static Widget animatedGradient(
    String text,
    TextStyle style,
    Animation<double> animation,
    List<Color> colors,
  ) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: colors,
              stops: [
                animation.value - 0.3,
                animation.value,
                animation.value + 0.3,
              ].map((e) => e.clamp(0.0, 1.0)).toList(),
            ).createShader(bounds);
          },
          child: Text(
            text,
            style: style.copyWith(color: Colors.white),
          ),
        );
      },
    );
  }
}

/// Rich text builders for common patterns
class RichTextBuilders {
  RichTextBuilders._();

  /// Build currency text with symbol
  static TextSpan currency(
    String symbol,
    String amount, {
    TextStyle? symbolStyle,
    TextStyle? amountStyle,
  }) {
    return TextSpan(
      children: [
        TextSpan(text: symbol, style: symbolStyle),
        TextSpan(text: amount, style: amountStyle),
      ],
    );
  }

  /// Build highlighted text
  static TextSpan highlighted(
    String text,
    String highlight,
    TextStyle normalStyle,
    TextStyle highlightStyle,
  ) {
    final parts = text.split(highlight);
    final spans = <TextSpan>[];

    for (int i = 0; i < parts.length; i++) {
      if (parts[i].isNotEmpty) {
        spans.add(TextSpan(text: parts[i], style: normalStyle));
      }
      if (i < parts.length - 1) {
        spans.add(TextSpan(text: highlight, style: highlightStyle));
      }
    }

    return TextSpan(children: spans);
  }

  /// Build label-value pair
  static TextSpan labelValue(
    String label,
    String value, {
    TextStyle? labelStyle,
    TextStyle? valueStyle,
  }) {
    return TextSpan(
      children: [
        TextSpan(text: '$label: ', style: labelStyle),
        TextSpan(text: value, style: valueStyle),
      ],
    );
  }
}

/// Prebuilt text widgets for common use cases
class TextWidgets {
  TextWidgets._();

  /// Screen title
  static Widget screenTitle(String text, {Color? color}) {
    return Text(
      text,
      style: AppTypography.largeTitle(color: color, fontWeight: AppTypography.bold),
    );
  }

  /// Section header
  static Widget sectionHeader(String text, {Color? color}) {
    return Text(
      text,
      style: AppTypography.headline(color: color, fontWeight: AppTypography.semiBold),
    );
  }

  /// Card title
  static Widget cardTitle(String text, {Color? color}) {
    return Text(
      text,
      style: AppTypography.title3(color: color, fontWeight: AppTypography.semiBold),
    );
  }

  /// List item title
  static Widget listItemTitle(String text, {Color? color}) {
    return Text(
      text,
      style: AppTypography.callout(color: color, fontWeight: AppTypography.medium),
    );
  }

  /// List item subtitle
  static Widget listItemSubtitle(BuildContext context, String text) {
    return Text(
      text,
      style: AppTypography.footnote(
        color: context.textSecondary,
        fontWeight: AppTypography.regular,
      ),
    );
  }

  /// Empty state message
  static Widget emptyStateMessage(BuildContext context, String text) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: AppTypography.body(
        color: context.textSecondary,
        fontWeight: AppTypography.regular,
      ),
    );
  }

  /// Error message
  static Widget errorMessage(String text) {
    return Text(
      text,
      style: AppTypography.callout(
        color: SemanticColors.error,
        fontWeight: AppTypography.medium,
      ),
    );
  }

  /// Success message
  static Widget successMessage(String text) {
    return Text(
      text,
      style: AppTypography.callout(
        color: SemanticColors.success,
        fontWeight: AppTypography.medium,
      ),
    );
  }
}
