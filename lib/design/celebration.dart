import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tokens.dart';

/// Showers the screen with tiny capsules. For wins that were earned: a quiz
/// passed, a badge unlocked, points converted. Does nothing when the person
/// asked for reduced motion.
void celebrate(BuildContext context, {int pieces = 70}) {
  if (AppMotion.reduced(context)) return;
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  HapticFeedback.mediumImpact();
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _CapsuleShower(pieces: pieces, onDone: () => entry.remove()),
  );
  overlay.insert(entry);
}

class _CapsuleShower extends StatefulWidget {
  final int pieces;
  final VoidCallback onDone;
  const _CapsuleShower({required this.pieces, required this.onDone});

  @override
  State<_CapsuleShower> createState() => _CapsuleShowerState();
}

class _CapsuleShowerState extends State<_CapsuleShower>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );
  late final List<_Piece> _pieces;

  static const _pairs = [
    [AppColors.indigo, AppColors.indigoTint],
    [AppColors.mint, Colors.white],
    [AppColors.coral, AppColors.coralTint],
    [AppColors.amber, Colors.white],
    [AppColors.indigoBright, AppColors.mintBright],
  ];

  @override
  void initState() {
    super.initState();
    final random = math.Random();
    _pieces = List.generate(widget.pieces, (i) {
      final pair = _pairs[random.nextInt(_pairs.length)];
      return _Piece(
        x: random.nextDouble(),
        delay: random.nextDouble() * 0.25,
        speed: 0.75 + random.nextDouble() * 0.6,
        drift: (random.nextDouble() - 0.5) * 0.3,
        spin: (random.nextDouble() - 0.5) * 14,
        phase: random.nextDouble() * math.pi * 2,
        length: 14 + random.nextDouble() * 12,
        a: pair[0],
        b: pair[1],
      );
    });
    _controller.forward().whenComplete(widget.onDone);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: _ShowerPainter(_controller, _pieces),
        ),
      ),
    );
  }
}

class _Piece {
  final double x, delay, speed, drift, spin, phase, length;
  final Color a, b;
  const _Piece({
    required this.x,
    required this.delay,
    required this.speed,
    required this.drift,
    required this.spin,
    required this.phase,
    required this.length,
    required this.a,
    required this.b,
  });
}

class _ShowerPainter extends CustomPainter {
  final Animation<double> animation;
  final List<_Piece> pieces;
  _ShowerPainter(this.animation, this.pieces) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final time = animation.value;
    for (final p in pieces) {
      final t = ((time - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (t <= 0) continue;
      final fall = t * p.speed;
      final x = size.width * (p.x + p.drift * t) +
          math.sin(p.phase + t * 9) * 14;
      final y = -40 + (size.height + 80) * fall * fall * 0.6 +
          (size.height + 80) * fall * 0.5;
      if (y > size.height + 40) continue;
      final opacity = t > 0.8 ? (1 - t) / 0.2 : 1.0;
      final thickness = p.length * 0.42;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.phase + p.spin * t);
      final rect = Rect.fromCenter(
        center: Offset.zero,
        width: p.length,
        height: thickness,
      );
      final capsule = RRect.fromRectAndRadius(rect, Radius.circular(thickness));
      canvas.clipRRect(capsule);
      canvas.drawRect(
        Rect.fromLTRB(rect.left, rect.top, 0, rect.bottom),
        Paint()..color = p.a.withValues(alpha: opacity),
      );
      canvas.drawRect(
        Rect.fromLTRB(0, rect.top, rect.right, rect.bottom),
        Paint()..color = p.b.withValues(alpha: opacity),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ShowerPainter oldDelegate) => false;
}
