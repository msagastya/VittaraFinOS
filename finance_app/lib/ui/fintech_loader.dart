import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';

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
    return Container(
      width: double.infinity,
      height: widget.size,
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          colors: [
            Color(0xFFFAFAFA),
            Color(0xFFE0E0E0),
          ],
          center: Alignment.center,
          radius: 1.0,
        ),
      ),
      child: CustomPaint(
        painter: _FuturisticLoaderPainter(_controller),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _FuturisticLoaderPainter extends CustomPainter {
  final Animation<double> animation;
  final Random _random = Random(42);

  _FuturisticLoaderPainter(this.animation) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final t = animation.value;
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2);
    final scale = min(w, h) / 100.0;

    // --- Palette ---
    const deepBlue = Color(0xFF1565C0); // Trust/Finance
    const vibrantTeal = Color(0xFF00BFA5); // Growth/Tech

    final Paint fillPaint = Paint()..style = PaintingStyle.fill;
    final Paint strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;

    // --- Layer 1: Digital Floor Grid (Perspective Effect) ---
    // Moving grid lines at bottom to simulate speed
    double gridSpeed = t * 50 * scale;
    Paint gridPaint = Paint()
      ..color = deepBlue.withValues(alpha: 0.1)
      ..strokeWidth = 1 * scale;
    
    for (int i = 0; i < 10; i++) {
      double y = h * 0.6 + (i * 15 * scale);
      double offset = (gridSpeed + i * 20) % (w / 2);
      // Horizontal perspective lines
      canvas.drawLine(Offset(0, y), Offset(w, y), gridPaint);
      // Moving vertical ticks
      for (double x = offset; x < w; x += 40 * scale) {
        canvas.drawLine(Offset(x, y), Offset(x, y + 5 * scale), gridPaint);
      }
    }

    // --- Layer 2: Fast Radar Sweep ---
    // A radar scanner sweeping 360 degrees
    double sweepAngle = (t * 4 * pi) % (2 * pi); // 2 full rotations
    Paint radarPaint = Paint()
      ..shader = SweepGradient(
        colors: [vibrantTeal.withValues(alpha: 0.0), vibrantTeal.withValues(alpha: 0.2)],
        startAngle: sweepAngle - 0.5,
        endAngle: sweepAngle,
        transform: GradientRotation(sweepAngle),
      ).createShader(Rect.fromCircle(center: center, radius: 100 * scale));
    
    canvas.drawCircle(center, 90 * scale, radarPaint);

    // --- Layer 3: Corner HUD Brackets (Snap In) ---
    if (t > 0.05) {
      double bracketProgress = ((t - 0.05) / 0.2).clamp(0.0, 1.0);
      double offset = (1.0 - Curves.easeOutExpo.transform(bracketProgress)) * 50 * scale;
      double margin = 20 * scale;
      double len = 40 * scale;

      Paint bracketPaint = Paint()
        ..style = PaintingStyle.stroke
        ..color = deepBlue.withValues(alpha: 0.8)
        ..strokeWidth = 3 * scale;

      // Top-Left
      Path tl = Path()..moveTo(margin - offset, margin + len - offset)..lineTo(margin - offset, margin - offset)..lineTo(margin + len - offset, margin - offset);
      canvas.drawPath(tl, bracketPaint);
      
      // Top-Right
      Path tr = Path()..moveTo(w - margin - len + offset, margin - offset)..lineTo(w - margin + offset, margin - offset)..lineTo(w - margin + offset, margin + len - offset);
      canvas.drawPath(tr, bracketPaint);
      
      // Bottom-Left
      Path bl = Path()..moveTo(margin - offset, h - margin - len + offset)..lineTo(margin - offset, h - margin + offset)..lineTo(margin + len - offset, h - margin + offset);
      canvas.drawPath(bl, bracketPaint);

      // Bottom-Right
      Path br = Path()..moveTo(w - margin - len + offset, h - margin + offset)..lineTo(w - margin + offset, h - margin + offset)..lineTo(w - margin + offset, h - margin - len + offset);
      canvas.drawPath(br, bracketPaint);
    }

    // --- Layer 4: Bullish Trend Line (Accelerated) ---
    Path trendPath = Path();
    trendPath.moveTo(0, h * 0.7);
    int points = 20; // More points for jagged look
    double stepX = w / points;
    for (int i = 1; i <= points; i++) {
      double targetY = h * 0.7 - (i * (h * 0.4) / points);
      double noise = sin(i * 99.1 + t * 10) * 15 * scale; // Animated noise!
      trendPath.lineTo(i * stepX, targetY + noise);
    }

    double trendProgress = (t / 0.6).clamp(0.0, 1.0); // Faster drawing
    if (trendProgress > 0) {
      PathMetric trendMetric = trendPath.computeMetrics().first;
      Path animatedTrend = trendMetric.extractPath(0.0, trendMetric.length * trendProgress);
      
      Paint trendPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5 * scale
        ..color = vibrantTeal
        ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4.0);
        
      canvas.drawPath(animatedTrend, trendPaint);

      // Current Price Dot
      if (trendProgress < 1.0) {
        Tangent? tip = trendMetric.getTangentForOffset(trendMetric.length * trendProgress);
        if (tip != null) {
          canvas.drawCircle(tip.position, 5 * scale, fillPaint..color = vibrantTeal);
          // Ripple
          canvas.drawCircle(tip.position, 10 * scale, strokePaint..color = vibrantTeal.withValues(alpha:0.4)..strokeWidth=1);
        }
      }
    }

    // --- Layer 5: Rotating Data Ring ---
    // Faster rotation
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(t * 3 * pi); // 1.5 rotations
    
    Paint ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * scale
      ..color = deepBlue.withValues(alpha: 0.3);
      
    for (int i = 0; i < 4; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset.zero, radius: 60 * scale),
        (i * 90 * pi / 180), 
        1.0, 
        false, 
        ringPaint
      );
    }
    canvas.restore();

    // --- Layer 6: The "V" Assembly (Fast & Bold) ---
    if (t > 0.05 && t < 0.95) {
       double vProgress = ((t - 0.05) / 0.4).clamp(0.0, 1.0); // Super fast assembly
       
       Path vPath = Path();
       vPath.moveTo(center.dx - 35 * scale, center.dy - 30 * scale); 
       vPath.lineTo(center.dx, center.dy + 35 * scale); 
       vPath.lineTo(center.dx + 35 * scale, center.dy - 30 * scale);

       // Gradient matching the icon: Blue (Left) to Teal (Right)
       final Shader vGradient = LinearGradient(
         colors: [deepBlue, vibrantTeal, deepBlue, vibrantTeal],
         stops: const [0.0, 0.4, 0.6, 1.0],
         begin: Alignment.topLeft,
         end: Alignment.bottomRight,
         transform: GradientRotation(t * 4 * pi), // Fast gradient cycle
       ).createShader(Rect.fromLTWH(center.dx - 40*scale, center.dy - 40*scale, 80*scale, 80*scale));

       Paint vStrokePaint = Paint()
         ..style = PaintingStyle.stroke
         ..strokeWidth = 14 * scale // Even thicker
         ..strokeCap = StrokeCap.round
         ..strokeJoin = StrokeJoin.round
         ..shader = vGradient;

       PathMetric metric = vPath.computeMetrics().first;
       double drawLen = metric.length * Curves.easeInOutQuart.transform(vProgress);
       Path partialV = metric.extractPath(0.0, drawLen);
       
       // Heavy Glow
       Paint shadowPaint = Paint()
         ..style = PaintingStyle.stroke
         ..strokeWidth = 20 * scale
         ..color = deepBlue.withValues(alpha: 0.4)
         ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12.0);
       canvas.drawPath(partialV, shadowPaint);

       canvas.drawPath(partialV, vStrokePaint);

       // Leading Spark
       if (vProgress < 1.0 && vProgress > 0.01) {
         Tangent? pos = metric.getTangentForOffset(drawLen);
         if (pos != null) {
           canvas.drawCircle(pos.position, 10 * scale, fillPaint..color = Colors.white);
           // Explosion particles
           for(int k=0; k<8; k++) {
              double r = 20 * scale * _random.nextDouble();
              double theta = 2 * pi * _random.nextDouble();
              canvas.drawCircle(
                pos.position + Offset(cos(theta)*r, sin(theta)*r), 
                3 * scale, 
                fillPaint..color = (k%2==0 ? deepBlue : vibrantTeal)
              );
           }
         }
       }
    } else if (t >= 0.95) {
       // Solid V state
       Path vPath = Path();
       vPath.moveTo(center.dx - 35 * scale, center.dy - 30 * scale); 
       vPath.lineTo(center.dx, center.dy + 35 * scale); 
       vPath.lineTo(center.dx + 35 * scale, center.dy - 30 * scale);
       
       // Flash effect at the end
       double flash = 1.0 - ((t - 0.95) / 0.05); // Fade out flash
       
       // Final state gradient: Blue to Teal (Static)
       final Shader vFinalGradient = const LinearGradient(
         colors: [deepBlue, vibrantTeal],
         begin: Alignment.centerLeft,
         end: Alignment.centerRight,
       ).createShader(Rect.fromLTWH(center.dx - 40*scale, center.dy - 40*scale, 80*scale, 80*scale));

       Paint vSolidPaint = Paint()
         ..style = PaintingStyle.stroke
         ..strokeWidth = 14 * scale 
         ..strokeCap = StrokeCap.round
         ..strokeJoin = StrokeJoin.round
         ..shader = flash > 0.1 ? null : vFinalGradient
         ..color = flash > 0.1 ? Color.lerp(deepBlue, Colors.white, flash)! : Colors.white; // Fallback color when shader is used

       canvas.drawPath(vPath, vSolidPaint);
    }

    // --- Layer 7: Binary Rain (Subtle) ---
    if (t > 0.1) {
       int cols = 10;
       double colWidth = w / cols;
       for (int i = 0; i < cols; i++) {
         if (i % 2 == 0) continue; // Skip every other col
         double speed = 200 * scale;
         double y = ((t * speed) + (i * 50)) % h;
         
         Paint textPaint = Paint()
           ..color = vibrantTeal.withValues(alpha: 0.2)
           ..style = PaintingStyle.fill;
         
         // Draw simple "bits" as rectangles instead of text for performance
         canvas.drawRect(Rect.fromLTWH(i * colWidth, y, 4 * scale, 8 * scale), textPaint);
         canvas.drawRect(Rect.fromLTWH(i * colWidth, y - 15 * scale, 4 * scale, 8 * scale), textPaint);
       }
    }
  }

  @override
  bool shouldRepaint(covariant _FuturisticLoaderPainter oldDelegate) => true;
}
