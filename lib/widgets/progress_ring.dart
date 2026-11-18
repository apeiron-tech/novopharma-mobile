import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:novopharma/design/design.dart';

/// Progress drawn as a ring: a tinted track, a rounded stroke that fills with
/// a soft gradient of [progressColor], and the percentage in display type.
class ProgressRing extends StatefulWidget {
  final double progress; // 0.0 to 1.0
  final double size;
  final double strokeWidth;
  final Color trackColor;
  final Color progressColor;
  final bool showPercentage;
  final TextStyle? textStyle;

  const ProgressRing({
    super.key,
    required this.progress,
    this.size = 64.0,
    this.strokeWidth = 6.0,
    this.trackColor = AppColors.indigoTint,
    this.progressColor = AppColors.indigo,
    this.showPercentage = true,
    this.textStyle,
  });

  @override
  State<ProgressRing> createState() => _ProgressRingState();
}

class _ProgressRingState extends State<ProgressRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: AppMotion.hero,
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.0, end: widget.progress).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: AppMotion.emphasized,
      ),
    );
    _animationController.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduced motion: show the final value straight away.
    if (AppMotion.reduced(context)) {
      _animationController.value = 1;
    }
  }

  @override
  void didUpdateWidget(ProgressRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress) {
      _animation = Tween<double>(begin: _animation.value, end: widget.progress)
          .animate(
            CurvedAnimation(
              parent: _animationController,
              curve: AppMotion.emphasized,
            ),
          );
      _animationController.reset();
      if (AppMotion.reduced(context)) {
        _animationController.value = 1;
      } else {
        _animationController.forward();
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final target =
        widget.progress.isNaN ? 0.0 : widget.progress.clamp(0.0, 1.0);
    return Semantics(
      value: '${(target * 100).round()}%',
      child: SizedBox(
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
                  painter: ProgressRingPainter(
                    progress: _animation.value,
                    strokeWidth: widget.strokeWidth,
                    trackColor: widget.trackColor,
                    progressColor: widget.progressColor,
                  ),
                );
              },
            ),
            if (widget.showPercentage)
              AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  final percentage = (_animation.value * 100).round();
                  return ExcludeSemantics(
                    child: Text(
                      '$percentage%',
                      maxLines: 1,
                      softWrap: false,
                      style:
                          widget.textStyle ??
                          AppText.display(
                            size: widget.size * 0.24,
                            color: AppColors.text,
                          ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class ProgressRingPainter extends CustomPainter {
  final double progress;
  final double strokeWidth;
  final Color trackColor;
  final Color progressColor;

  ProgressRingPainter({
    required this.progress,
    required this.strokeWidth,
    required this.trackColor,
    required this.progressColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final bounds = Rect.fromCircle(center: center, radius: radius);

    // Draw track
    final trackPaint = Paint()
      ..color = trackColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    // Draw progress
    final value = progress.isNaN ? 0.0 : progress.clamp(0.0, 1.0);
    if (value > 0) {
      // Lit from the top-left like every other filled shape in the app, so
      // the stroke has no seam when the ring closes.
      final progressPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(progressColor, Colors.white, 0.32)!,
            progressColor,
          ],
        ).createShader(bounds.inflate(strokeWidth / 2))
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final sweepAngle = 2 * math.pi * value;
      canvas.drawArc(
        bounds,
        -math.pi / 2, // Start from top
        sweepAngle,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(ProgressRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
