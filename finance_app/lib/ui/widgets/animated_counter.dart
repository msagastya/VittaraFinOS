import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';

/// Animated number counter with smooth transitions
class AnimatedCounter extends StatefulWidget {
  final double value;
  final String prefix;
  final String suffix;
  final int decimalPlaces;
  final TextStyle? textStyle;
  final Duration duration;
  final Curve curve;

  const AnimatedCounter({
    super.key,
    required this.value,
    this.prefix = '',
    this.suffix = '',
    this.decimalPlaces = 0,
    this.textStyle,
    this.duration = const Duration(milliseconds: 800),
    this.curve = Curves.easeOutCubic,
  });

  @override
  State<AnimatedCounter> createState() => _AnimatedCounterState();
}

class _AnimatedCounterState extends State<AnimatedCounter>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _previousValue = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _animation = Tween<double>(
      begin: _previousValue,
      end: widget.value,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    ));

    _controller.forward();
  }

  @override
  void didUpdateWidget(AnimatedCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _previousValue = oldWidget.value;
      _animation = Tween<double>(
        begin: _previousValue,
        end: widget.value,
      ).animate(CurvedAnimation(
        parent: _controller,
        curve: widget.curve,
      ));
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final displayValue = _animation.value.toStringAsFixed(widget.decimalPlaces);
        return Text(
          '${widget.prefix}$displayValue${widget.suffix}',
          style: widget.textStyle,
        );
      },
    );
  }
}

/// Odometer-style rolling number counter
class RollingCounter extends StatefulWidget {
  final int value;
  final TextStyle? textStyle;
  final Duration duration;

  const RollingCounter({
    super.key,
    required this.value,
    this.textStyle,
    this.duration = const Duration(milliseconds: 600),
  });

  @override
  State<RollingCounter> createState() => _RollingCounterState();
}

class _RollingCounterState extends State<RollingCounter> {
  late List<int> _digits;
  late List<int> _previousDigits;

  @override
  void initState() {
    super.initState();
    _digits = _getDigits(widget.value);
    _previousDigits = List.from(_digits);
  }

  @override
  void didUpdateWidget(RollingCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      setState(() {
        _previousDigits = _digits;
        _digits = _getDigits(widget.value);
      });
    }
  }

  List<int> _getDigits(int value) {
    return value.toString().split('').map((e) => int.parse(e)).toList();
  }

  @override
  Widget build(BuildContext context) {
    // Pad with zeros if needed
    final maxLength = _digits.length > _previousDigits.length
        ? _digits.length
        : _previousDigits.length;

    while (_digits.length < maxLength) {
      _digits.insert(0, 0);
    }
    while (_previousDigits.length < maxLength) {
      _previousDigits.insert(0, 0);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(_digits.length, (index) {
        return _RollingDigit(
          value: _digits[index],
          previousValue: _previousDigits[index],
          textStyle: widget.textStyle,
          duration: widget.duration,
        );
      }),
    );
  }
}

class _RollingDigit extends StatefulWidget {
  final int value;
  final int previousValue;
  final TextStyle? textStyle;
  final Duration duration;

  const _RollingDigit({
    required this.value,
    required this.previousValue,
    this.textStyle,
    required this.duration,
  });

  @override
  State<_RollingDigit> createState() => _RollingDigitState();
}

class _RollingDigitState extends State<_RollingDigit>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _animation = Tween<double>(
      begin: widget.previousValue.toDouble(),
      end: widget.value.toDouble(),
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    if (widget.value != widget.previousValue) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(_RollingDigit oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _animation = Tween<double>(
        begin: widget.previousValue.toDouble(),
        end: widget.value.toDouble(),
      ).animate(CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ));
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final currentValue = _animation.value.round();
        return Text(
          currentValue.toString(),
          style: widget.textStyle,
        );
      },
    );
  }
}

/// Currency counter with formatting
class CurrencyCounter extends StatelessWidget {
  final double value;
  final String currencySymbol;
  final TextStyle? textStyle;
  final TextStyle? symbolStyle;
  final int decimalPlaces;
  final bool showPlusSign;

  const CurrencyCounter({
    super.key,
    required this.value,
    this.currencySymbol = '₹',
    this.textStyle,
    this.symbolStyle,
    this.decimalPlaces = 2,
    this.showPlusSign = false,
  });

  @override
  Widget build(BuildContext context) {
    final isNegative = value < 0;
    final prefix = isNegative ? '-' : (showPlusSign && value > 0 ? '+' : '');

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (prefix.isNotEmpty)
          Text(
            prefix,
            style: textStyle,
          ),
        Text(
          currencySymbol,
          style: symbolStyle ?? textStyle?.copyWith(
            fontSize: (textStyle?.fontSize ?? 16) * 0.8,
          ),
        ),
        AnimatedCounter(
          value: value.abs(),
          decimalPlaces: decimalPlaces,
          textStyle: textStyle,
        ),
      ],
    );
  }
}

/// Percentage counter with animated arc
class PercentageCounter extends StatefulWidget {
  final double percentage;
  final double size;
  final Color? color;
  final TextStyle? textStyle;
  final double strokeWidth;

  const PercentageCounter({
    super.key,
    required this.percentage,
    this.size = 100.0,
    this.color,
    this.textStyle,
    this.strokeWidth = 8.0,
  });

  @override
  State<PercentageCounter> createState() => _PercentageCounterState();
}

class _PercentageCounterState extends State<PercentageCounter>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AppDurations.counter,
      vsync: this,
    );

    _animation = Tween<double>(
      begin: 0.0,
      end: widget.percentage / 100,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _controller.forward();
  }

  @override
  void didUpdateWidget(PercentageCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.percentage != widget.percentage) {
      _animation = Tween<double>(
        begin: _animation.value,
        end: widget.percentage / 100,
      ).animate(CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ));
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? SemanticColors.getPrimary(context);

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return CustomPaint(
                size: Size(widget.size, widget.size),
                painter: _PercentageArcPainter(
                  progress: _animation.value,
                  color: color,
                  strokeWidth: widget.strokeWidth,
                ),
              );
            },
          ),
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              final displayValue = (_animation.value * 100).toStringAsFixed(1);
              return Text(
                '$displayValue%',
                style: widget.textStyle,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PercentageArcPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  _PercentageArcPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Background arc
    final backgroundPaint = Paint()
      ..color = color.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, backgroundPaint);

    // Progress arc
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * 3.14159 * progress;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -3.14159 / 2, // Start from top
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_PercentageArcPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// Counting up number with particles
class ParticleCounter extends StatefulWidget {
  final double value;
  final String prefix;
  final String suffix;
  final TextStyle? textStyle;
  final Color? particleColor;

  const ParticleCounter({
    super.key,
    required this.value,
    this.prefix = '',
    this.suffix = '',
    this.textStyle,
    this.particleColor,
  });

  @override
  State<ParticleCounter> createState() => _ParticleCounterState();
}

class _ParticleCounterState extends State<ParticleCounter>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  final List<_Particle> _particles = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _animation = Tween<double>(
      begin: 0.0,
      end: widget.value,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _controller.forward();

    // Generate particles
    for (int i = 0; i < 10; i++) {
      _particles.add(_Particle());
    }
  }

  @override
  void didUpdateWidget(ParticleCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _animation = Tween<double>(
        begin: _animation.value,
        end: widget.value,
      ).animate(CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ));
      _controller.forward(from: 0.0);
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
      alignment: Alignment.center,
      children: [
        // Particles
        ...List.generate(_particles.length, (index) {
          final particle = _particles[index];
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final progress = _controller.value;
              final x = particle.dx * progress * 50;
              final y = particle.dy * progress * 50 - (progress * 30);
              final opacity = (1 - progress) * 0.6;

              return Transform.translate(
                offset: Offset(x, y),
                child: Opacity(
                  opacity: opacity,
                  child: Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.particleColor ?? SemanticColors.getPrimary(context),
                    ),
                  ),
                ),
              );
            },
          );
        }),
        // Counter
        AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            final displayValue = _animation.value.toStringAsFixed(0);
            return Text(
              '${widget.prefix}$displayValue${widget.suffix}',
              style: widget.textStyle,
            );
          },
        ),
      ],
    );
  }
}

class _Particle {
  final double dx;
  final double dy;

  _Particle()
      : dx = (0.5 - (0.5 * (1.0 - 0.5))) * 2,
        dy = (0.5 - (0.5 * (1.0 - 0.5))) * 2;
}
