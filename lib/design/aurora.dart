import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'tokens.dart';

/// The ink surface behind every hero area: two slow glows drifting over deep
/// indigo, textured with a blister-pack dot grid.
///
/// The drift is ambient and stops for reduced motion and whenever the route
/// is covered. Keep one per screen.
class AuroraBackground extends StatefulWidget {
  final Widget? child;
  final BorderRadius borderRadius;
  final bool pattern;
  final bool animate;

  const AuroraBackground({
    super.key,
    this.child,
    this.borderRadius = BorderRadius.zero,
    this.pattern = true,
    this.animate = true,
  });

  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 18),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final run = widget.animate && !AppMotion.reduced(context);
    if (run && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!run && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(painter: _GlowPainter(_controller)),
            ),
          ),
          if (widget.pattern)
            const Positioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(painter: _BlisterPainter()),
              ),
            ),
          if (widget.child != null) widget.child!,
        ],
      ),
    );
  }
}

class _GlowPainter extends CustomPainter {
  final Animation<double> animation;
  _GlowPainter(this.animation) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()..shader = AppGradients.ink.createShader(rect),
    );

    final a = animation.value * 2 * math.pi;
    final unit = math.max(size.width, size.height);

    void glow(Offset center, double radius, Color color) {
      final bounds = Rect.fromCircle(center: center, radius: radius);
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [color, color.withValues(alpha: 0)],
          ).createShader(bounds),
      );
    }

    // Indigo bloom, top right.
    glow(
      Offset(
        size.width * (0.86 + 0.10 * math.cos(a)),
        size.height * (0.08 + 0.16 * math.sin(a)),
      ),
      unit * 0.72,
      AppColors.indigoBright.withValues(alpha: 0.62),
    );
    // Mint ember, bottom left — the cross glowing through the window.
    glow(
      Offset(
        size.width * (0.06 + 0.14 * math.sin(a + 1.3)),
        size.height * (0.96 + 0.10 * math.cos(a + 1.3)),
      ),
      unit * 0.46,
      AppColors.mint.withValues(alpha: 0.26),
    );
    // A second, cooler indigo that crosses the first.
    glow(
      Offset(
        size.width * (0.42 + 0.22 * math.cos(a * 2 + 2.1)),
        size.height * (0.62 + 0.18 * math.sin(a + 0.6)),
      ),
      unit * 0.4,
      AppColors.indigo.withValues(alpha: 0.42),
    );
  }

  @override
  bool shouldRepaint(_GlowPainter oldDelegate) => false;
}

/// Staggered rows of domes, fading out from the top-right corner.
class _BlisterPainter extends CustomPainter {
  const _BlisterPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const gap = 22.0;
    const radius = 3.2;
    final origin = Offset(size.width, 0);
    final reach = size.width * 0.95;
    final paint = Paint();
    var row = 0;
    for (var y = gap / 2; y < size.height; y += gap * 0.86, row++) {
      final shift = row.isOdd ? gap / 2 : 0.0;
      for (var x = gap / 2 + shift; x < size.width; x += gap) {
        final d = (Offset(x, y) - origin).distance / reach;
        if (d >= 1) continue;
        final alpha = (1 - d) * (1 - d) * 0.16;
        paint.color = Colors.white.withValues(alpha: alpha);
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_BlisterPainter oldDelegate) => false;
}
