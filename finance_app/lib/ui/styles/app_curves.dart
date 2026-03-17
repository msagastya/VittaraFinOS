import 'package:flutter/animation.dart';

/// Animation curve tokens for VittaraFinOS.
///
/// Use these constants instead of bare [Curves] references so that
/// all transitions can be updated from one place.
class AppCurves {
  AppCurves._();

  /// Default curve for symmetric transitions (in + out).
  static const Curve standard = Curves.easeInOut;

  /// Curve for elements entering the screen (decelerating).
  static const Curve enter = Curves.easeOut;

  /// Curve for elements leaving the screen (accelerating).
  static const Curve exit = Curves.easeIn;

  /// Springy over-shoot curve for celebratory or playful animations.
  static const Curve spring = Curves.elasticOut;

  /// Smooth deceleration for scrolling-style transitions.
  static const Curve decelerate = Curves.decelerate;

  /// Fast snap for instant-feel micro-interactions.
  static const Curve snap = Curves.fastOutSlowIn;
}
