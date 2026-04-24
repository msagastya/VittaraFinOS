import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/styles/typography.dart';
import 'package:vittara_fin_os/ui/widgets/animations.dart';

/// A spotlight-style coach mark overlay.
///
/// Usage:
///   CoachMark.show(
///     context: context,
///     targetKey: _searchIconKey,
///     title: 'Search with natural language',
///     body: "Try 'food last week' or 'show goals'",
///   );
class CoachMark {
  /// Displays the coach mark as a fullscreen overlay.
  /// Returns after the user dismisses it.
  static Future<void> show({
    required BuildContext context,
    required GlobalKey targetKey,
    required String title,
    required String body,
    String? actionLabel,
    VoidCallback? onAction,
  }) async {
    // Measure target widget position
    Rect? targetRect;
    final ro = targetKey.currentContext?.findRenderObject();
    if (ro is RenderBox && ro.hasSize) {
      final offset = ro.localToGlobal(Offset.zero);
      targetRect = offset & ro.size;
    }

    await Navigator.of(context, rootNavigator: true).push<void>(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.transparent,
        pageBuilder: (_, animation, __) => _CoachMarkOverlay(
          animation: animation,
          targetRect: targetRect,
          title: title,
          body: body,
          actionLabel: actionLabel,
          onAction: onAction,
        ),
      ),
    );
  }
}

class _CoachMarkOverlay extends StatelessWidget {
  final Animation<double> animation;
  final Rect? targetRect;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _CoachMarkOverlay({
    required this.animation,
    required this.targetRect,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDark = AppStyles.isDarkMode(context);

    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: FadeTransition(
        opacity: animation,
        child: Stack(
          children: [
            // Semi-transparent backdrop with spotlight cutout
            if (targetRect != null)
              CustomPaint(
                size: size,
                painter: _SpotlightPainter(
                  spotRect: targetRect!,
                  backdropColor: Colors.black.withValues(alpha: 0.72),
                ),
              )
            else
              Container(color: Colors.black.withValues(alpha: 0.72)),

            // Tooltip card — positioned below or above the target
            Positioned(
              left: _cardLeft(size),
              top: _cardTop(size),
              width: min(size.width - 48, 320),
              child: ScaleTransition(
                scale: CurvedAnimation(
                  parent: animation,
                  curve: Curves.elasticOut,
                ),
                alignment: _cardAlignment(),
                child: Container(
                  padding: const EdgeInsets.all(Spacing.lg),
                  decoration: BoxDecoration(
                    color: isDark ? AppStyles.darkL1 : CupertinoColors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: AppStyles.aetherTeal.withValues(alpha: 0.3),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppStyles.aetherTeal.withValues(alpha: 0.2),
                        blurRadius: 24,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color:
                                  AppStyles.aetherTeal.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              CupertinoIcons.lightbulb_fill,
                              size: 14,
                              color: AppStyles.aetherTeal,
                            ),
                          ),
                          const SizedBox(width: Spacing.sm),
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                fontSize: TypeScale.subhead,
                                fontWeight: FontWeight.w700,
                                color: AppStyles.aetherTeal,
                              ),
                            ),
                          ),
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            minSize: 0,
                            onPressed: () => Navigator.of(context).pop(),
                            child: Icon(
                              CupertinoIcons.xmark,
                              size: 14,
                              color: AppStyles.aetherTeal.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: Spacing.sm),
                      Text(
                        body,
                        style: TextStyle(
                          fontSize: TypeScale.footnote,
                          color: isDark
                              ? CupertinoColors.white.withValues(alpha: 0.8)
                              : const Color(0xFF333333),
                          height: 1.4,
                        ),
                      ),
                      if (actionLabel != null) ...[
                        const SizedBox(height: Spacing.md),
                        BouncyButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            onAction?.call();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: Spacing.md, vertical: Spacing.xs),
                            decoration: BoxDecoration(
                              color: AppStyles.aetherTeal,
                              borderRadius: BorderRadius.circular(Radii.full),
                            ),
                            child: Text(
                              actionLabel!,
                              style: const TextStyle(
                                fontSize: TypeScale.caption,
                                fontWeight: FontWeight.w700,
                                color: CupertinoColors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: Spacing.sm),
                      Text(
                        'Tap anywhere to dismiss',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppStyles.aetherTeal.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _cardLeft(Size size) {
    if (targetRect == null) return 24;
    final cardWidth = min(size.width - 48.0, 320.0);
    // Centre under the target, clamped to screen edges
    double left = targetRect!.center.dx - cardWidth / 2;
    return left.clamp(24.0, size.width - cardWidth - 24);
  }

  double _cardTop(Size size) {
    if (targetRect == null) return size.height * 0.3;
    // Show below target if there's room; otherwise above
    const cardHeight = 160.0;
    const gap = 12.0;
    final belowY = targetRect!.bottom + gap;
    if (belowY + cardHeight < size.height - 40) return belowY;
    return targetRect!.top - cardHeight - gap;
  }

  Alignment _cardAlignment() {
    if (targetRect == null) return Alignment.center;
    return Alignment.topCenter;
  }
}

/// Paints a dark backdrop with a rounded spotlight cutout around [spotRect].
class _SpotlightPainter extends CustomPainter {
  final Rect spotRect;
  final Color backdropColor;

  const _SpotlightPainter({
    required this.spotRect,
    required this.backdropColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = backdropColor;
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(
        spotRect.inflate(6),
        const Radius.circular(12),
      ))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) => old.spotRect != spotRect;
}
