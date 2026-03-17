import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';

class FintechLoader extends StatefulWidget {
  final double size;

  const FintechLoader({super.key, this.size = 300});

  @override
  State<FintechLoader> createState() => _FintechLoaderState();
}

class _FintechLoaderState extends State<FintechLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppStyles.isDarkMode(context);
    final bgCenter = isDark ? const Color(0xFF1C1C1E) : const Color(0xFFFAFAFA);
    final bgOuter = isDark ? const Color(0xFF000000) : const Color(0xFFE0E0E0);

    return Container(
      width: double.infinity,
      height: widget.size,
      decoration: BoxDecoration(
        gradient: RadialGradient(
          colors: [bgCenter, bgOuter],
          center: Alignment.center,
          radius: 1.0,
        ),
      ),
      child: CustomPaint(
        painter: _FuturisticLoaderPainter(_controller, isDark),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _FuturisticLoaderPainter extends CustomPainter {
  final Animation<double> animation;
  final bool isDark;
  final Random _random = Random(42);

  _FuturisticLoaderPainter(this.animation, this.isDark)
      : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final t = animation.value;
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2);
    final scale = min(w, h) / 100.0;

    // --- Palette ---
    const deepBlue = Color(0xFF1565C0);
    const vibrantTeal = Color(0xFF00BFA5);
    final gridColor = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : deepBlue.withValues(alpha: 0.1);

    final Paint fillPaint = Paint()..style = PaintingStyle.fill;
    final Paint strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;

    // --- Layer 1: Digital Floor Grid ---
    final double gridSpeed = t * 50 * scale;
    final Paint gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1 * scale;

    for (int i = 0; i < 10; i++) {
      final double y = h * 0.6 + (i * 15 * scale);
      final double offset = (gridSpeed + i * 20) % (w / 2);
      canvas.drawLine(Offset(0, y), Offset(w, y), gridPaint);
      for (double x = offset; x < w; x += 40 * scale) {
        canvas.drawLine(Offset(x, y), Offset(x, y + 5 * scale), gridPaint);
      }
    }

    // --- Layer 2: Fast Radar Sweep ---
    final double sweepAngle = (t * 4 * pi) % (2 * pi);
    final Paint radarPaint = Paint()
      ..shader = SweepGradient(
        colors: [
          vibrantTeal.withValues(alpha: 0.0),
          vibrantTeal.withValues(alpha: 0.2)
        ],
        startAngle: sweepAngle - 0.5,
        endAngle: sweepAngle,
        transform: GradientRotation(sweepAngle),
      ).createShader(Rect.fromCircle(center: center, radius: 100 * scale));

    canvas.drawCircle(center, 90 * scale, radarPaint);

    // --- Layer 3: Corner HUD Brackets ---
    if (t > 0.05) {
      final double bracketProgress = ((t - 0.05) / 0.2).clamp(0.0, 1.0);
      final double offset =
          (1.0 - Curves.easeOutExpo.transform(bracketProgress)) * 50 * scale;
      final double margin = 20 * scale;
      final double len = 40 * scale;

      final Paint bracketPaint = Paint()
        ..style = PaintingStyle.stroke
        ..color = deepBlue.withValues(alpha: 0.8)
        ..strokeWidth = 3 * scale;

      // Draw brackets (TL, TR, BL, BR)
      final Path tl = Path()
        ..moveTo(margin - offset, margin + len - offset)
        ..lineTo(margin - offset, margin - offset)
        ..lineTo(margin + len - offset, margin - offset);
      canvas.drawPath(tl, bracketPaint);
      final Path tr = Path()
        ..moveTo(w - margin - len + offset, margin - offset)
        ..lineTo(w - margin + offset, margin - offset)
        ..lineTo(w - margin + offset, margin + len - offset);
      canvas.drawPath(tr, bracketPaint);
      final Path bl = Path()
        ..moveTo(margin - offset, h - margin - len + offset)
        ..lineTo(margin - offset, h - margin + offset)
        ..lineTo(margin + len - offset, h - margin + offset);
      canvas.drawPath(bl, bracketPaint);
      final Path br = Path()
        ..moveTo(w - margin - len + offset, h - margin + offset)
        ..lineTo(w - margin + offset, h - margin + offset)
        ..lineTo(w - margin + offset, h - margin - len + offset);
      canvas.drawPath(br, bracketPaint);
    }

    // --- Layer 4: Bullish Trend Line ---
    final Path trendPath = Path();
    trendPath.moveTo(0, h * 0.7);
    const int points = 20;
    final double stepX = w / points;
    for (int i = 1; i <= points; i++) {
      final double targetY = h * 0.7 - (i * (h * 0.4) / points);
      final double noise = sin(i * 99.1 + t * 10) * 15 * scale;
      trendPath.lineTo(i * stepX, targetY + noise);
    }

    final double trendProgress = (t / 0.6).clamp(0.0, 1.0);
    if (trendProgress > 0) {
      final PathMetric trendMetric = trendPath.computeMetrics().first;
      final Path animatedTrend =
          trendMetric.extractPath(0.0, trendMetric.length * trendProgress);

      final Paint trendPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5 * scale
        ..color = vibrantTeal
        ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4.0);

      canvas.drawPath(animatedTrend, trendPaint);

      if (trendProgress < 1.0) {
        final Tangent? tip =
            trendMetric.getTangentForOffset(trendMetric.length * trendProgress);
        if (tip != null) {
          canvas.drawCircle(
              tip.position, 5 * scale, fillPaint..color = vibrantTeal);
          canvas.drawCircle(
              tip.position,
              10 * scale,
              strokePaint
                ..color = vibrantTeal.withValues(alpha: 0.4)
                ..strokeWidth = 1);
        }
      }
    }

    // --- Layer 5: Rotating Data Ring ---
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(t * 3 * pi);

    final Paint ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * scale
      ..color = deepBlue.withValues(alpha: 0.3);

    for (int i = 0; i < 4; i++) {
      canvas.drawArc(Rect.fromCircle(center: Offset.zero, radius: 60 * scale),
          (i * 90 * pi / 180), 1.0, false, ringPaint);
    }
    canvas.restore();

    // --- Layer 6: The "V" Assembly ---
    if (t > 0.05 && t < 0.95) {
      final double vProgress = ((t - 0.05) / 0.4).clamp(0.0, 1.0);

      final Path vPath = Path();
      vPath.moveTo(center.dx - 35 * scale, center.dy - 30 * scale);
      vPath.lineTo(center.dx, center.dy + 35 * scale);
      vPath.lineTo(center.dx + 35 * scale, center.dy - 30 * scale);

      final Shader vGradient = LinearGradient(
        colors: [deepBlue, vibrantTeal, deepBlue, vibrantTeal],
        stops: const [0.0, 0.4, 0.6, 1.0],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        transform: GradientRotation(t * 4 * pi),
      ).createShader(Rect.fromLTWH(center.dx - 40 * scale,
          center.dy - 40 * scale, 80 * scale, 80 * scale));

      final Paint vStrokePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14 * scale
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..shader = vGradient;

      final PathMetric metric = vPath.computeMetrics().first;
      final double drawLen =
          metric.length * Curves.easeInOutQuart.transform(vProgress);
      final Path partialV = metric.extractPath(0.0, drawLen);

      final Paint shadowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 20 * scale
        ..color = deepBlue.withValues(alpha: 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12.0);
      canvas.drawPath(partialV, shadowPaint);
      canvas.drawPath(partialV, vStrokePaint);

      if (vProgress < 1.0 && vProgress > 0.01) {
        final Tangent? pos = metric.getTangentForOffset(drawLen);
        if (pos != null) {
          canvas.drawCircle(
              pos.position, 10 * scale, fillPaint..color = Colors.white);
        }
      }
    } else if (t >= 0.95) {
      final Path vPath = Path();
      vPath.moveTo(center.dx - 35 * scale, center.dy - 30 * scale);
      vPath.lineTo(center.dx, center.dy + 35 * scale);
      vPath.lineTo(center.dx + 35 * scale, center.dy - 30 * scale);

      final double flash = 1.0 - ((t - 0.95) / 0.05);
      final Shader vFinalGradient = const LinearGradient(
        colors: [deepBlue, vibrantTeal],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ).createShader(Rect.fromLTWH(center.dx - 40 * scale,
          center.dy - 40 * scale, 80 * scale, 80 * scale));

      final Paint vSolidPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14 * scale
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..shader = flash > 0.1 ? null : vFinalGradient
        ..color = flash > 0.1
            ? Color.lerp(deepBlue, Colors.white, flash)!
            : Colors.white;

      canvas.drawPath(vPath, vSolidPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _FuturisticLoaderPainter oldDelegate) => true;
}
