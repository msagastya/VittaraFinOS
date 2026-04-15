import 'package:flutter/physics.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AppSprings — physics-first spring presets for every interaction layer
// ─────────────────────────────────────────────────────────────────────────────
//
// Usage:
//   final sim = SpringSimulation(AppSprings.natural, from, to, initialVelocity);
//   _controller.animateWith(sim);
//
// All springs are critically-damped or under-damped (no bounce unless intended).
// Never use Curves.* for interactive, touch-driven animations — use these.
// ─────────────────────────────────────────────────────────────────────────────

abstract final class AppSprings {
  /// Tight and instant — toolbar buttons, toggle switches, chips.
  /// Over-damped so it never overshoots. Settles in ~100ms.
  static const SpringDescription crisp = SpringDescription(
    mass: 1.0,
    stiffness: 500.0,
    damping: 38.0,
  );

  /// The everyday workhorse — list items, cards, sheet presents.
  /// Lightly under-damped: a single tiny overshoot that feels alive.
  static const SpringDescription natural = SpringDescription(
    mass: 1.0,
    stiffness: 220.0,
    damping: 22.0,
  );

  /// Playful — FAB, success states, onboarding transitions.
  /// Clear underdamped bounce (ζ ≈ 0.45). Overshoots ~8%.
  static const SpringDescription bouncy = SpringDescription(
    mass: 1.0,
    stiffness: 180.0,
    damping: 12.0,
  );

  /// Slow and graceful — page route transitions, large panels sliding in.
  /// Barely under-damped: smooth deceleration, negligible overshoot.
  static const SpringDescription gentle = SpringDescription(
    mass: 1.0,
    stiffness: 120.0,
    damping: 20.0,
  );

  /// Ultra-tight — nav bar elements, status indicators, pill animations.
  /// Heavily over-damped, snaps in under 80ms. Zero overshoot.
  static const SpringDescription snappy = SpringDescription(
    mass: 1.0,
    stiffness: 700.0,
    damping: 50.0,
  );

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Build a simulation from [start] → [end] with [initialVelocity].
  /// `initialVelocity` should be in units-per-second (same unit as start/end).
  static SpringSimulation simulate(
    SpringDescription description,
    double start,
    double end,
    double initialVelocity,
  ) {
    return SpringSimulation(description, start, end, initialVelocity);
  }

  /// Convenience: zero-velocity simulation (most common case for UI releases).
  static SpringSimulation from(
    SpringDescription description,
    double start,
    double end,
  ) {
    return SpringSimulation(description, start, end, 0.0);
  }
}
