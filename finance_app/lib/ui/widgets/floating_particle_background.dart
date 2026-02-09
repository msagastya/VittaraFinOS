import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';

/// Floating particle background with animated particles
class FloatingParticleBackground extends StatefulWidget {
  final Widget child;
  final int particleCount;
  final Color? particleColor;
  final double minSize;
  final double maxSize;
  final double speed;
  final bool interactive;

  const FloatingParticleBackground({
    super.key,
    required this.child,
    this.particleCount = 30,
    this.particleColor,
    this.minSize = 2.0,
    this.maxSize = 6.0,
    this.speed = 1.0,
    this.interactive = false,
  });

  @override
  State<FloatingParticleBackground> createState() =>
      _FloatingParticleBackgroundState();
}

class _FloatingParticleBackgroundState
    extends State<FloatingParticleBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<Particle> _particles = [];
  Offset? _touchPosition;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 60),
      vsync: this,
    )..repeat();

    _controller.addListener(() {
      setState(() {
        for (var particle in _particles) {
          particle.update(widget.speed, _touchPosition);
        }
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_particles.isEmpty) {
      final size = MediaQuery.of(context).size;
      for (int i = 0; i < widget.particleCount; i++) {
        _particles.add(Particle(
          size: size,
          minSize: widget.minSize,
          maxSize: widget.maxSize,
        ));
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final particleColor = widget.particleColor ??
        (isDark
            ? Colors.white.withValues(alpha: 0.15)
            : Colors.black.withValues(alpha: 0.08));

    Widget content = Stack(
      children: [
        CustomPaint(
          painter: ParticlePainter(
            particles: _particles,
            color: particleColor,
          ),
          child: Container(),
        ),
        widget.child,
      ],
    );

    if (widget.interactive) {
      content = GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _touchPosition = details.localPosition;
          });
        },
        onPanEnd: (_) {
          setState(() {
            _touchPosition = null;
          });
        },
        child: content,
      );
    }

    return content;
  }
}

/// Single particle with physics
class Particle {
  double x;
  double y;
  double vx;
  double vy;
  double size;
  double opacity;
  final Size screenSize;

  Particle({
    required this.screenSize,
    required double minSize,
    required double maxSize,
  })  : x = math.Random().nextDouble() * screenSize.width,
        y = math.Random().nextDouble() * screenSize.height,
        vx = (math.Random().nextDouble() - 0.5) * 2,
        vy = (math.Random().nextDouble() - 0.5) * 2,
        size = minSize + math.Random().nextDouble() * (maxSize - minSize),
        opacity = 0.3 + math.Random().nextDouble() * 0.7;

  void update(double speed, Offset? touchPosition) {
    // Update position
    x += vx * speed;
    y += vy * speed;

    // Interactive repulsion
    if (touchPosition != null) {
      final dx = x - touchPosition.dx;
      final dy = y - touchPosition.dy;
      final distance = math.sqrt(dx * dx + dy * dy);

      if (distance < 100) {
        final force = (100 - distance) / 100;
        x += (dx / distance) * force * 5;
        y += (dy / distance) * force * 5;
      }
    }

    // Wrap around screen edges
    if (x < -size) x = screenSize.width + size;
    if (x > screenSize.width + size) x = -size;
    if (y < -size) y = screenSize.height + size;
    if (y > screenSize.height + size) y = -size;
  }
}

/// Custom painter for particles
class ParticlePainter extends CustomPainter {
  final List<Particle> particles;
  final Color color;

  ParticlePainter({
    required this.particles,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (var particle in particles) {
      paint.color = color.withValues(alpha: particle.opacity * color.a);
      canvas.drawCircle(
        Offset(particle.x, particle.y),
        particle.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(ParticlePainter oldDelegate) => true;
}

/// Glowing particle background with blur
class GlowingParticleBackground extends StatefulWidget {
  final Widget child;
  final int particleCount;
  final List<Color> particleColors;
  final double speed;

  const GlowingParticleBackground({
    super.key,
    required this.child,
    this.particleCount = 20,
    this.particleColors = const [
      Color(0xFF667EEA),
      Color(0xFF764BA2),
      Color(0xFFF093FB),
    ],
    this.speed = 0.5,
  });

  @override
  State<GlowingParticleBackground> createState() =>
      _GlowingParticleBackgroundState();
}

class _GlowingParticleBackgroundState extends State<GlowingParticleBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<GlowingParticle> _particles = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 60),
      vsync: this,
    )..repeat();

    _controller.addListener(() {
      setState(() {
        for (var particle in _particles) {
          particle.update(widget.speed);
        }
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_particles.isEmpty) {
      final size = MediaQuery.of(context).size;
      for (int i = 0; i < widget.particleCount; i++) {
        _particles.add(GlowingParticle(
          size: size,
          color: widget.particleColors[
              i % widget.particleColors.length],
        ));
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        CustomPaint(
          painter: GlowingParticlePainter(particles: _particles),
          child: Container(),
        ),
        widget.child,
      ],
    );
  }
}

/// Glowing particle with radial gradient
class GlowingParticle {
  double x;
  double y;
  double vx;
  double vy;
  double size;
  double pulsePhase;
  final Color color;
  final Size screenSize;

  GlowingParticle({
    required this.screenSize,
    required this.color,
  })  : x = math.Random().nextDouble() * screenSize.width,
        y = math.Random().nextDouble() * screenSize.height,
        vx = (math.Random().nextDouble() - 0.5) * 1.5,
        vy = (math.Random().nextDouble() - 0.5) * 1.5,
        size = 30 + math.Random().nextDouble() * 50,
        pulsePhase = math.Random().nextDouble() * math.pi * 2;

  void update(double speed) {
    x += vx * speed;
    y += vy * speed;
    pulsePhase += 0.02;

    if (x < -size) x = screenSize.width + size;
    if (x > screenSize.width + size) x = -size;
    if (y < -size) y = screenSize.height + size;
    if (y > screenSize.height + size) y = -size;
  }

  double get currentSize => size * (1 + math.sin(pulsePhase) * 0.3);
}

/// Custom painter for glowing particles
class GlowingParticlePainter extends CustomPainter {
  final List<GlowingParticle> particles;

  GlowingParticlePainter({required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    for (var particle in particles) {
      final gradient = RadialGradient(
        colors: [
          particle.color.withValues(alpha: 0.6),
          particle.color.withValues(alpha: 0.3),
          particle.color.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.5, 1.0],
      );

      final paint = Paint()
        ..shader = gradient.createShader(
          Rect.fromCircle(
            center: Offset(particle.x, particle.y),
            radius: particle.currentSize,
          ),
        );

      canvas.drawCircle(
        Offset(particle.x, particle.y),
        particle.currentSize,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(GlowingParticlePainter oldDelegate) => true;
}

/// Connected particle network background
class ConnectedParticleBackground extends StatefulWidget {
  final Widget child;
  final int particleCount;
  final Color? particleColor;
  final Color? lineColor;
  final double connectionDistance;

  const ConnectedParticleBackground({
    super.key,
    required this.child,
    this.particleCount = 25,
    this.particleColor,
    this.lineColor,
    this.connectionDistance = 120.0,
  });

  @override
  State<ConnectedParticleBackground> createState() =>
      _ConnectedParticleBackgroundState();
}

class _ConnectedParticleBackgroundState
    extends State<ConnectedParticleBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<Particle> _particles = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 60),
      vsync: this,
    )..repeat();

    _controller.addListener(() {
      setState(() {
        for (var particle in _particles) {
          particle.update(0.5, null);
        }
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_particles.isEmpty) {
      final size = MediaQuery.of(context).size;
      for (int i = 0; i < widget.particleCount; i++) {
        _particles.add(Particle(
          size: size,
          minSize: 3.0,
          maxSize: 5.0,
        ));
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final particleColor = widget.particleColor ??
        (isDark ? Colors.white.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.15));
    final lineColor = widget.lineColor ??
        (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05));

    return Stack(
      children: [
        CustomPaint(
          painter: ConnectedParticlePainter(
            particles: _particles,
            particleColor: particleColor,
            lineColor: lineColor,
            connectionDistance: widget.connectionDistance,
          ),
          child: Container(),
        ),
        widget.child,
      ],
    );
  }
}

/// Custom painter for connected particles
class ConnectedParticlePainter extends CustomPainter {
  final List<Particle> particles;
  final Color particleColor;
  final Color lineColor;
  final double connectionDistance;

  ConnectedParticlePainter({
    required this.particles,
    required this.particleColor,
    required this.lineColor,
    required this.connectionDistance,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final particlePaint = Paint()
      ..color = particleColor
      ..style = PaintingStyle.fill;

    final linePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Draw connections
    for (int i = 0; i < particles.length; i++) {
      for (int j = i + 1; j < particles.length; j++) {
        final p1 = particles[i];
        final p2 = particles[j];

        final dx = p1.x - p2.x;
        final dy = p1.y - p2.y;
        final distance = math.sqrt(dx * dx + dy * dy);

        if (distance < connectionDistance) {
          final opacity = (1 - distance / connectionDistance) * lineColor.a;
          linePaint.color = lineColor.withValues(alpha: opacity);

          canvas.drawLine(
            Offset(p1.x, p1.y),
            Offset(p2.x, p2.y),
            linePaint,
          );
        }
      }
    }

    // Draw particles
    for (var particle in particles) {
      canvas.drawCircle(
        Offset(particle.x, particle.y),
        particle.size,
        particlePaint,
      );
    }
  }

  @override
  bool shouldRepaint(ConnectedParticlePainter oldDelegate) => true;
}

/// Subtle particle overlay
class SubtleParticleOverlay extends StatefulWidget {
  final Widget child;
  final int particleCount;

  const SubtleParticleOverlay({
    super.key,
    required this.child,
    this.particleCount = 50,
  });

  @override
  State<SubtleParticleOverlay> createState() => _SubtleParticleOverlayState();
}

class _SubtleParticleOverlayState extends State<SubtleParticleOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<Particle> _particles = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 120),
      vsync: this,
    )..repeat();

    _controller.addListener(() {
      setState(() {
        for (var particle in _particles) {
          particle.update(0.2, null);
        }
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_particles.isEmpty) {
      final size = MediaQuery.of(context).size;
      for (int i = 0; i < widget.particleCount; i++) {
        _particles.add(Particle(
          size: size,
          minSize: 1.0,
          maxSize: 2.5,
        ));
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final particleColor = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.black.withValues(alpha: 0.03);

    return Stack(
      children: [
        widget.child,
        IgnorePointer(
          child: CustomPaint(
            painter: ParticlePainter(
              particles: _particles,
              color: particleColor,
            ),
            child: Container(),
          ),
        ),
      ],
    );
  }
}

/// Star field particle background
class StarFieldBackground extends StatefulWidget {
  final Widget child;
  final int starCount;
  final Color? starColor;
  final bool twinkle;

  const StarFieldBackground({
    super.key,
    required this.child,
    this.starCount = 100,
    this.starColor,
    this.twinkle = true,
  });

  @override
  State<StarFieldBackground> createState() => _StarFieldBackgroundState();
}

class _StarFieldBackgroundState extends State<StarFieldBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<Star> _stars = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 60),
      vsync: this,
    )..repeat();

    _controller.addListener(() {
      if (widget.twinkle) {
        setState(() {
          for (var star in _stars) {
            star.updateTwinkle();
          }
        });
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_stars.isEmpty) {
      final size = MediaQuery.of(context).size;
      for (int i = 0; i < widget.starCount; i++) {
        _stars.add(Star(size: size));
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final starColor = widget.starColor ??
        (isDark ? Colors.white.withValues(alpha: 0.8) : Colors.black.withValues(alpha: 0.2));

    return Stack(
      children: [
        CustomPaint(
          painter: StarFieldPainter(
            stars: _stars,
            color: starColor,
          ),
          child: Container(),
        ),
        widget.child,
      ],
    );
  }
}

/// Single star particle
class Star {
  final double x;
  final double y;
  final double size;
  double twinklePhase;
  final double twinkleSpeed;

  Star({required Size size})
      : x = math.Random().nextDouble() * size.width,
        y = math.Random().nextDouble() * size.height,
        size = 1.0 + math.Random().nextDouble() * 2.5,
        twinklePhase = math.Random().nextDouble() * math.pi * 2,
        twinkleSpeed = 0.02 + math.Random().nextDouble() * 0.03;

  void updateTwinkle() {
    twinklePhase += twinkleSpeed;
  }

  double get brightness => 0.3 + (math.sin(twinklePhase) * 0.7);
}

/// Custom painter for star field
class StarFieldPainter extends CustomPainter {
  final List<Star> stars;
  final Color color;

  StarFieldPainter({
    required this.stars,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (var star in stars) {
      paint.color = color.withValues(alpha: color.a * star.brightness);
      canvas.drawCircle(
        Offset(star.x, star.y),
        star.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(StarFieldPainter oldDelegate) => true;
}
