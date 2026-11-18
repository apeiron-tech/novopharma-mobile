import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'tokens.dart';

/// The MyChallenge mark: a capsule on its way up, split by a bolt.
///
/// The capsule is the pharmacy counter; the bolt-shaped seam is the
/// challenge — and a nod to the zigzag of the previous logo. The leading
/// half is mint, the colour of the cross above the door.
///
/// [join] and [spark] drive the launch animation: at 0 the two halves are
/// apart and the sparkle is hidden, at 1 the mark is complete.
class BrandMark extends StatelessWidget {
  final double size;
  final bool onDark;
  final double join;
  final double spark;

  const BrandMark({
    super.key,
    this.size = 48,
    this.onDark = true,
    this.join = 1,
    this.spark = 1,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: BrandMarkPainter(onDark: onDark, join: join, spark: spark),
      ),
    );
  }
}

class BrandMarkPainter extends CustomPainter {
  final bool onDark;
  final double join;
  final double spark;

  const BrandMarkPainter({this.onDark = true, this.join = 1, this.spark = 1});

  static const double _tilt = -38 * math.pi / 180;

  @override
  void paint(Canvas canvas, Size size) {
    paintMark(canvas, Offset.zero & size, onDark: onDark, join: join, spark: spark);
  }

  /// Paints the mark inside [rect]. Shared by the widget, the app-icon tile
  /// and the asset renderer so there is a single source for the logo.
  static void paintMark(
    Canvas canvas,
    Rect rect, {
    bool onDark = true,
    double join = 1,
    double spark = 1,
  }) {
    final s = rect.shortestSide;
    final length = s * 0.70;
    final thickness = s * 0.34;
    final h = thickness / 2;
    final a = length * 0.10;
    final gap = s * 0.034;

    final capsule = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: length, height: thickness),
          Radius.circular(h),
        ),
      );

    // The bolt, top to bottom, in the capsule's own coordinates.
    final seam = [
      Offset(a, -h * 1.2),
      Offset(-a, h * 0.14),
      Offset(a, -h * 0.14),
      Offset(-a, h * 1.2),
    ];

    Path half(double side) {
      final polygon = Path()..moveTo(side * length, -h * 1.2);
      for (final p in seam) {
        polygon.lineTo(p.dx + side * gap / 2, p.dy);
      }
      polygon
        ..lineTo(side * length, h * 1.2)
        ..close();
      return Path.combine(PathOperation.intersect, capsule, polygon);
    }

    final trailColors = onDark
        ? const [Colors.white, Color(0xFFDADBFF)]
        : const [AppColors.indigoBright, AppColors.indigoDeep];
    const leadColors = [AppColors.mintBright, AppColors.mint];

    final t = join.clamp(0.0, 1.0);
    final apart = (1 - t) * s * 0.26;
    final alpha = t;

    canvas.save();
    canvas.translate(
      rect.left + rect.width * 0.47,
      rect.top + rect.height * 0.54,
    );
    canvas.rotate(_tilt);

    final bounds =
        Rect.fromCenter(center: Offset.zero, width: length, height: thickness);

    void drawHalf(double side, List<Color> colors) {
      canvas.save();
      canvas.translate(side * apart, 0);
      canvas.drawPath(
        half(side),
        Paint()
          ..isAntiAlias = true
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colors[0].withValues(alpha: alpha),
              colors[1].withValues(alpha: alpha),
            ],
          ).createShader(bounds),
      );
      canvas.restore();
    }

    drawHalf(-1, trailColors);
    drawHalf(1, leadColors);
    canvas.restore();

    // The sparkle off the leading tip: the win.
    final k = spark.clamp(0.0, 1.0);
    if (k > 0) {
      final sparkColor = onDark ? Colors.white : AppColors.indigo;
      _star(
        canvas,
        Offset(rect.left + rect.width * 0.83, rect.top + rect.height * 0.19),
        s * 0.092 * k,
        sparkColor,
      );
      _star(
        canvas,
        Offset(rect.left + rect.width * 0.66, rect.top + rect.height * 0.105),
        s * 0.04 * k,
        sparkColor.withValues(alpha: 0.75),
      );
    }
  }

  static void _star(Canvas canvas, Offset c, double r, Color color) {
    if (r <= 0) return;
    final q = r * 0.16;
    final path = Path()
      ..moveTo(c.dx, c.dy - r)
      ..quadraticBezierTo(c.dx + q, c.dy - q, c.dx + r, c.dy)
      ..quadraticBezierTo(c.dx + q, c.dy + q, c.dx, c.dy + r)
      ..quadraticBezierTo(c.dx - q, c.dy + q, c.dx - r, c.dy)
      ..quadraticBezierTo(c.dx - q, c.dy - q, c.dx, c.dy - r)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(BrandMarkPainter oldDelegate) =>
      oldDelegate.onDark != onDark ||
      oldDelegate.join != join ||
      oldDelegate.spark != spark;
}

/// Paints the app icon: the mark on an ink tile lit by an indigo bloom.
/// Full-bleed, so the OS can apply its own corner mask.
void paintBrandTile(Canvas canvas, Rect rect, {double markScale = 0.8}) {
  canvas.drawRect(
    rect,
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF17146A), AppColors.ink],
      ).createShader(rect),
  );
  void bloom(Alignment at, double radius, Color color) {
    final center = at.withinRect(rect);
    final r = rect.shortestSide * radius;
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: center, radius: r)),
    );
  }

  canvas.save();
  canvas.clipRect(rect);
  bloom(const Alignment(0.9, -0.9), 0.85, AppColors.indigoBright.withValues(alpha: 0.75));
  bloom(const Alignment(-1.0, 1.0), 0.6, AppColors.mint.withValues(alpha: 0.28));
  canvas.restore();

  final inset = rect.shortestSide * (1 - markScale) / 2;
  BrandMarkPainter.paintMark(canvas, rect.deflate(inset));
}

/// The mark on its rounded tile, as it appears on the home screen.
class BrandTile extends StatelessWidget {
  final double size;
  const BrandTile({super.key, this.size = 64});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.26),
      child: SizedBox.square(
        dimension: size,
        child: const CustomPaint(painter: _TilePainter()),
      ),
    );
  }
}

class _TilePainter extends CustomPainter {
  const _TilePainter();

  @override
  void paint(Canvas canvas, Size size) =>
      paintBrandTile(canvas, Offset.zero & size);

  @override
  bool shouldRepaint(_TilePainter oldDelegate) => false;
}

/// The name, set in the display face.
class BrandWordmark extends StatelessWidget {
  final double size;
  final Color color;

  const BrandWordmark({
    super.key,
    this.size = 26,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      'MyChallenge',
      maxLines: 1,
      softWrap: false,
      style: AppText.display(
        size: size,
        weight: FontWeight.w800,
        color: color,
        letterSpacing: -0.035 * size,
        height: 1,
      ),
    );
  }
}

/// Mark and name side by side. [height] is the height of the mark.
class BrandLogo extends StatelessWidget {
  final double height;
  final bool onDark;

  const BrandLogo({super.key, this.height = 36, this.onDark = true});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'MyChallenge',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          BrandMark(size: height, onDark: onDark),
          SizedBox(width: height * 0.16),
          BrandWordmark(
            size: height * 0.66,
            color: onDark ? Colors.white : AppColors.ink,
          ),
        ],
      ),
    );
  }
}
