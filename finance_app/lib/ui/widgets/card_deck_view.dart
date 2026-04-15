import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:vittara_fin_os/ui/styles/app_springs.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CardDeckView — Bloomberg-level swipeable card deck
// ─────────────────────────────────────────────────────────────────────────────
// UX contract:
//   • Shows 3 cards as a depth stack (front, mid, back).
//   • Swipe left OR right on the front card → sends it to the back (circular).
//   • If swipe < threshold, card springs back with spring physics.
//   • Bottom dot indicators show current front card index.
//   • Depth illusion: scale 1.0 / 0.95 / 0.90, translateY 0 / 10 / 20px,
//     opacity 1.0 / 0.85 / 0.65.
// ─────────────────────────────────────────────────────────────────────────────

class CardDeckView extends StatefulWidget {
  final List<Widget> cards;
  final void Function(int index)? onCardChanged;

  /// Horizontal drag distance (dp) that triggers a card flip.
  final double swipeThreshold;

  /// How much each depth-level card is scaled down.
  final double depthScaleStep;

  /// How many dp each depth-level card is pushed down.
  final double depthTranslateStep;

  const CardDeckView({
    super.key,
    required this.cards,
    this.onCardChanged,
    this.swipeThreshold = 80.0,
    this.depthScaleStep = 0.055,
    this.depthTranslateStep = 14.0,
  });

  @override
  State<CardDeckView> createState() => _CardDeckViewState();
}

class _CardDeckViewState extends State<CardDeckView>
    with TickerProviderStateMixin {
  int _frontIndex = 0;
  double _dragOffset = 0.0;

  /// Drives swipe-away animation (front card exits stage).
  late final AnimationController _swipeController;

  /// Drives spring-return animation (card snaps back).
  /// Unbounded so SpringSimulation can drive pixel-space values (e.g. 120 → 0).
  late final AnimationController _returnController;

  /// Drives depth-slot promotions (back cards animate into new positions).
  late final AnimationController _promotionController;

  bool _isSwiping = false;
  bool _swipingRight = false;

  @override
  void initState() {
    super.initState();

    _swipeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _advanceCard();
          _promotionController
            ..reset()
            ..forward().whenComplete(_swipeController.reset);
        }
      });

    // Unbounded: spring drives pixel values like 80.0 → 0.0
    _returnController = AnimationController.unbounded(vsync: this)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          setState(() {
            _dragOffset = 0;
          });
        }
      });

    _promotionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
  }

  @override
  void dispose() {
    _swipeController.dispose();
    _returnController.dispose();
    _promotionController.dispose();
    super.dispose();
  }

  int get _cardCount => widget.cards.length;

  int _indexAt(int depth) {
    if (_swipingRight && depth > 0) {
      return (_frontIndex - depth + _cardCount) % _cardCount;
    }
    return (_frontIndex + depth) % _cardCount;
  }

  void _advanceCard() {
    setState(() {
      // Swipe right = go to previous card; swipe left = go to next card.
      _frontIndex = _swipingRight
          ? (_frontIndex - 1 + _cardCount) % _cardCount
          : (_frontIndex + 1) % _cardCount;
      _dragOffset = 0;
      _isSwiping = false;
    });
    HapticFeedback.lightImpact();
    widget.onCardChanged?.call(_frontIndex);
  }

  void _onPanStart(DragStartDetails _) {
    // Don't start a new gesture while any animation is still running.
    if (_swipeController.isAnimating ||
        _returnController.isAnimating ||
        _promotionController.isAnimating) return;
    setState(() {
      _isSwiping = true;
    });
    _returnController.reset();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!_isSwiping) return;
    setState(() {
      _dragOffset += details.delta.dx;
      _swipingRight = _dragOffset > 0;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (!_isSwiping) return;
    if (_dragOffset.abs() >= widget.swipeThreshold) {
      // Commit swipe
      _swipeController.forward();
    } else {
      // Spring back using real finger velocity so the card feels anchored.
      final velocityX = details.velocity.pixelsPerSecond.dx;
      setState(() => _isSwiping = false);
      _returnController.animateWith(
        SpringSimulation(AppSprings.natural, _dragOffset, 0.0, velocityX),
      );
    }
  }

  /// Called when the OS cancels the gesture (scroll conflict, system interrupt, etc.).
  /// Without this, _isSwiping stays true and the card freezes mid-drag.
  void _onPanCancel() {
    if (!_isSwiping) return;
    setState(() => _isSwiping = false);
    _returnController.animateWith(
      SpringSimulation(AppSprings.natural, _dragOffset, 0.0, 0.0),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_cardCount == 0) return const SizedBox.shrink();
    if (_cardCount == 1) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: widget.cards[0],
      );
    }

    final visibleDepth = math.min(_cardCount, 3);

    return Column(
      children: [
        Expanded(
          child: GestureDetector(
            onPanStart: _onPanStart,
            onPanUpdate: _onPanUpdate,
            onPanEnd: _onPanEnd,
            onPanCancel: _onPanCancel,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                // Render from back to front so front card is on top
                for (int depth = visibleDepth - 1; depth >= 0; depth--)
                  _buildDepthSlot(depth),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildDotIndicators(),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildDepthSlot(int depth) {
    final isSwipingCard = depth == 0 && _isSwiping;

    // Promotion animation: when a swipe completes, back cards slide up
    final promotionProgress = _promotionController.value;

    // Base transform values for this depth
    final baseScale = 1.0 - depth * widget.depthScaleStep;
    final baseTranslateY = depth * widget.depthTranslateStep;
    final baseOpacity = 1.0 - depth * 0.15;

    // During promotion, depth[1] approaches depth[0] values, depth[2] approaches depth[1]
    final targetScale = depth > 0
        ? (1.0 - (depth - 1) * widget.depthScaleStep)
        : 1.0;
    final targetTranslateY = depth > 0
        ? ((depth - 1) * widget.depthTranslateStep)
        : 0.0;
    final targetOpacity = depth > 0 ? (1.0 - (depth - 1) * 0.15) : 1.0;

    double scale, translateY, opacity;

    if (_swipeController.isAnimating && depth == 0) {
      // Front card: animate off screen
      scale = baseScale;
      translateY = baseTranslateY;
      opacity = 1.0 - _swipeController.value;
    } else if (_promotionController.isAnimating && depth > 0) {
      // Back cards promote forward
      scale = baseScale + (targetScale - baseScale) * promotionProgress;
      translateY = baseTranslateY +
          (targetTranslateY - baseTranslateY) * promotionProgress;
      opacity = baseOpacity + (targetOpacity - baseOpacity) * promotionProgress;
    } else {
      scale = baseScale;
      translateY = baseTranslateY;
      opacity = baseOpacity;
    }

    // Horizontal offset for front card
    double offsetX = 0.0;
    double rotationZ = 0.0;
    if (depth == 0) {
      if (_isSwiping) {
        offsetX = _dragOffset;
        rotationZ = (_dragOffset / 400) * 0.08; // subtle tilt
      } else if (_returnController.isAnimating) {
        offsetX = _returnController.value;
        rotationZ = (_returnController.value / 400) * 0.08;
      } else if (_swipeController.isAnimating) {
        final screenWidth = MediaQuery.of(context).size.width;
        offsetX = (_swipingRight ? 1 : -1) *
            screenWidth *
            1.3 *
            _swipeController.value;
        rotationZ = (_swipingRight ? 1 : -1) *
            0.3 *
            _swipeController.value;
      }
    }

    return Positioned.fill(
      child: AnimatedBuilder(
        animation: Listenable.merge(
            [_swipeController, _returnController, _promotionController]),
        builder: (context, child) {
          // Recalculate live values inside AnimatedBuilder for smooth animation
          double liveScale = scale;
          double liveTranslateY = translateY;
          double liveOpacity = opacity.clamp(0.0, 1.0);
          double liveOffsetX = offsetX;
          double liveRotationZ = rotationZ;

          if (_swipeController.isAnimating && depth == 0) {
            final screenWidth = MediaQuery.of(context).size.width;
            liveOffsetX = (_swipingRight ? 1 : -1) *
                screenWidth *
                1.3 *
                _swipeController.value;
            liveRotationZ =
                (_swipingRight ? 1 : -1) * 0.3 * _swipeController.value;
            liveOpacity = (1.0 - _swipeController.value).clamp(0.0, 1.0);
          }

          if (_promotionController.isAnimating && depth > 0) {
            final p = _promotionController.value;
            liveScale = baseScale + (targetScale - baseScale) * p;
            liveTranslateY = baseTranslateY +
                (targetTranslateY - baseTranslateY) * p;
            liveOpacity =
                (baseOpacity + (targetOpacity - baseOpacity) * p).clamp(0.0, 1.0);
          }

          if (_returnController.isAnimating && depth == 0) {
            liveOffsetX = _returnController.value;
            liveRotationZ = (_returnController.value / 400) * 0.08;
          }

          return Opacity(
            opacity: liveOpacity,
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..translate(liveOffsetX, liveTranslateY, 0.0)
                ..rotateZ(liveRotationZ)
                ..scale(liveScale, liveScale, 1.0),
              child: child,
            ),
          );
        },
        child: Semantics(
          label: 'Card ${depth + 1} of $_cardCount',
          child: Padding(
            // Reduced from 16 → 8 so depth-stack back cards peek at edges,
            // giving a clear visual cue that more cards exist.
            padding: EdgeInsets.symmetric(
              horizontal: depth == 0 ? 8.0 : (8.0 + depth * 6.0),
            ),
            child: widget.cards[_indexAt(depth)],
          ),
        ),
      ),
    );
  }

  Widget _buildDotIndicators() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_cardCount, (i) {
        final isActive = i == _frontIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: isActive ? 20 : 6,
          height: 6,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            color: isActive
                ? SemanticColors.getPrimary(context)
                : SemanticColors.getPrimary(context).withValues(alpha: 0.25),
          ),
        );
      }),
    );
  }
}
