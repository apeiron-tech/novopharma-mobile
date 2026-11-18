import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tokens.dart';

/// Wraps anything tappable. Sinks under the finger and springs back, with a
/// light haptic tick, so every action in the app answers the same way.
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double pressedScale;
  final bool haptic;
  final String? semanticLabel;

  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.pressedScale = 0.96,
    this.haptic = true,
    this.semanticLabel,
  });

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;
  Timer? _release;

  void _set(bool value) {
    if (!mounted || _down == value) return;
    setState(() => _down = value);
  }

  @override
  void dispose() {
    _release?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null || widget.onLongPress != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => _set(true) : null,
        onTapCancel: enabled ? () => _set(false) : null,
        onTapUp: enabled
            ? (_) {
                // Hold the pressed state a beat so a quick tap still reads.
                _release?.cancel();
                _release = Timer(AppMotion.instant, () => _set(false));
              }
            : null,
        onTap: widget.onTap == null
            ? null
            : () {
                if (widget.haptic) HapticFeedback.selectionClick();
                widget.onTap!();
              },
        onLongPress: widget.onLongPress == null
            ? null
            : () {
                if (widget.haptic) HapticFeedback.mediumImpact();
                _set(false);
                widget.onLongPress!();
              },
        child: AnimatedScale(
          scale: _down ? widget.pressedScale : 1,
          duration: _down ? AppMotion.instant : AppMotion.medium,
          curve: _down ? Curves.easeOut : AppMotion.spring,
          child: widget.child,
        ),
      ),
    );
  }
}

/// Fades and lifts its child into place once, after [delay].
///
/// Use [Entrance.staggered] for the first screenful of a list. Entrances are
/// for arrival, not decoration: content that changes later should not replay.
class Entrance extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;
  final Offset offset;
  final double scaleFrom;

  const Entrance({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = AppMotion.slow,
    this.offset = const Offset(0, 20),
    this.scaleFrom = 1,
  });

  /// Delays by position. Capped so long lists never wait on their tail.
  factory Entrance.staggered({
    Key? key,
    required int index,
    required Widget child,
    Duration base = Duration.zero,
    Duration step = const Duration(milliseconds: 60),
    int maxSteps = 8,
    Offset offset = const Offset(0, 20),
  }) {
    final steps = index.clamp(0, maxSteps);
    return Entrance(
      key: key,
      delay: base + step * steps,
      offset: offset,
      child: child,
    );
  }

  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: widget.duration);
  late final Animation<double> _curve =
      CurvedAnimation(parent: _controller, curve: AppMotion.emphasized);
  Timer? _timer;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (AppMotion.reduced(context)) {
      _controller.value = 1;
    } else if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      _timer = Timer(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _curve,
      child: AnimatedBuilder(
        animation: _curve,
        child: widget.child,
        builder: (context, child) {
          final t = _curve.value;
          final scale = widget.scaleFrom + (1 - widget.scaleFrom) * t;
          return Transform.translate(
            offset: Offset.lerp(widget.offset, Offset.zero, t)!,
            child: scale == 1 ? child : Transform.scale(scale: scale, child: child),
          );
        },
      ),
    );
  }
}

/// A number that rolls to its value. When the value changes it rolls from
/// where it was, so earning points is visible rather than a silent swap.
class CountUp extends StatelessWidget {
  final num value;
  final TextStyle style;
  final Duration duration;
  final String Function(num) format;
  final TextAlign? textAlign;

  const CountUp({
    super.key,
    required this.value,
    required this.style,
    this.duration = AppMotion.hero,
    this.format = formatPoints,
    this.textAlign,
  });

  @override
  Widget build(BuildContext context) {
    final end = value.toDouble();
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: end),
      duration: AppMotion.reduced(context) ? Duration.zero : duration,
      curve: AppMotion.emphasized,
      builder: (context, v, _) {
        final settled = (v - end).abs() < 0.005;
        return Text(
          format(settled ? value : v.roundToDouble()),
          style: style,
          textAlign: textAlign,
          maxLines: 1,
          softWrap: false,
        );
      },
    );
  }
}

/// Sweeps a soft highlight across its child, like light catching a glossy
/// capsule. Runs once by default; pass [period] to repeat.
class Sheen extends StatefulWidget {
  final Widget child;
  final BorderRadius borderRadius;
  final Duration delay;
  final Duration sweep;
  final Duration? period;
  final double intensity;

  const Sheen({
    super.key,
    required this.child,
    this.borderRadius = BorderRadius.zero,
    this.delay = const Duration(milliseconds: 500),
    this.sweep = const Duration(milliseconds: 1100),
    this.period,
    this.intensity = 0.26,
  });

  @override
  State<Sheen> createState() => _SheenState();
}

class _SheenState extends State<Sheen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: widget.period ?? widget.sweep);
  Timer? _timer;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (AppMotion.reduced(context)) return;
    _timer = Timer(widget.delay, () {
      if (!mounted) return;
      if (widget.period != null) {
        _controller.repeat();
      } else {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sweepFraction = widget.period == null
        ? 1.0
        : (widget.sweep.inMilliseconds / widget.period!.inMilliseconds)
            .clamp(0.05, 1.0);
    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: ClipRRect(
              borderRadius: widget.borderRadius,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  final raw = _controller.value / sweepFraction;
                  if (raw <= 0 || raw >= 1) return const SizedBox.shrink();
                  final t = Curves.easeInOut.transform(raw);
                  return DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: const Alignment(-1, -0.4),
                        end: const Alignment(1, 0.4),
                        colors: [
                          Colors.white.withValues(alpha: 0),
                          Colors.white.withValues(alpha: widget.intensity),
                          Colors.white.withValues(alpha: 0),
                        ],
                        stops: const [0.38, 0.5, 0.62],
                        transform: _SlideGradient(-1.2 + 2.4 * t),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SlideGradient extends GradientTransform {
  final double fraction;
  const _SlideGradient(this.fraction);

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(bounds.width * fraction, 0, 0);
}

/// Soft halos that expand and fade behind [child] — the pharmacy cross sign
/// breathing in a window. Reserved for the single most important action.
class PulseRings extends StatefulWidget {
  final Widget child;
  final Color color;
  final bool active;
  final double maxScale;
  final int rings;
  final Duration period;

  /// Peak opacity of a halo as it leaves the child.
  final double strength;

  const PulseRings({
    super.key,
    required this.child,
    required this.color,
    this.active = true,
    this.maxScale = 1.75,
    this.rings = 2,
    this.period = const Duration(milliseconds: 2600),
    this.strength = 0.42,
  });

  @override
  State<PulseRings> createState() => _PulseRingsState();
}

class _PulseRingsState extends State<PulseRings>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: widget.period);

  void _sync() {
    final shouldRun = widget.active && !AppMotion.reduced(context);
    if (shouldRun && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!shouldRun && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(PulseRings oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: widget.active
          ? _PulsePainter(
              animation: _controller,
              color: widget.color,
              maxScale: widget.maxScale,
              rings: widget.rings,
              strength: widget.strength,
            )
          : null,
      child: widget.child,
    );
  }
}

class _PulsePainter extends CustomPainter {
  final Animation<double> animation;
  final Color color;
  final double maxScale;
  final int rings;
  final double strength;

  _PulsePainter({
    required this.animation,
    required this.color,
    required this.maxScale,
    required this.rings,
    required this.strength,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    if (animation.status == AnimationStatus.dismissed && animation.value == 0) {
      return;
    }
    final center = size.center(Offset.zero);
    final base = math.min(size.width, size.height) / 2;
    for (var i = 0; i < rings; i++) {
      final t = (animation.value + i / rings) % 1.0;
      final eased = Curves.easeOut.transform(t);
      final radius = base * (1 + (maxScale - 1) * eased);
      final alpha = (1 - t) * (1 - t) * strength;
      canvas.drawCircle(
        center,
        radius,
        Paint()..color = color.withValues(alpha: alpha),
      );
    }
  }

  @override
  bool shouldRepaint(_PulsePainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.maxScale != maxScale ||
      oldDelegate.rings != rings ||
      oldDelegate.strength != strength;
}

/// Fades between routes without sliding. Used for tab switches so the dock
/// stays put while the page changes underneath it.
class FadeRoute<T> extends PageRouteBuilder<T> {
  FadeRoute({required WidgetBuilder builder, super.settings})
      : super(
          pageBuilder: (context, _, __) => builder(context),
          transitionDuration: const Duration(milliseconds: 260),
          reverseTransitionDuration: const Duration(milliseconds: 200),
          transitionsBuilder: (context, animation, _, child) => FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: child,
          ),
        );
}
