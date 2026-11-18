import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'tokens.dart';

/// Which glass a surface is made of.
enum GlassStyle {
  /// Frosted white, for the pastel canvas. Dark text.
  light,

  /// Clear glass for ink and aurora surfaces. White text.
  dark,

  /// Smoked ink glass — the dock, toasts, anything that floats over content.
  smoked,
}

/// A pane of glass: translucent fill, a rim that catches light along the
/// top-left edge, and a shadow that falls only outside the pane so the glass
/// itself stays clear.
///
/// Set [blur] above zero to frost what is behind it. Blur costs a layer, so
/// keep it for surfaces that float over moving or detailed content (the
/// dock, sheets, cards on the aurora). Cards resting on the pastel canvas
/// already read as glass through translucency alone — leave [blur] at 0.
class Glass extends StatelessWidget {
  final Widget child;
  final GlassStyle style;
  final BorderRadius borderRadius;
  final double blur;
  final EdgeInsetsGeometry padding;
  final Color? tint;
  final bool shadow;
  final double? width;
  final double? height;

  const Glass({
    super.key,
    required this.child,
    this.style = GlassStyle.light,
    this.borderRadius = const BorderRadius.all(Radius.circular(AppRadii.lg)),
    this.blur = 0,
    this.padding = EdgeInsets.zero,
    this.tint,
    this.shadow = true,
    this.width,
    this.height,
  });

  static const double frost = 22;

  LinearGradient get _fill {
    switch (style) {
      case GlassStyle.light:
        final base = tint ?? Colors.white;
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            base.withValues(alpha: 0.74),
            base.withValues(alpha: 0.46),
          ],
        );
      case GlassStyle.dark:
        final base = tint ?? Colors.white;
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            base.withValues(alpha: tint == null ? 0.20 : 0.50),
            base.withValues(alpha: tint == null ? 0.07 : 0.26),
          ],
        );
      case GlassStyle.smoked:
        final base = tint ?? AppColors.ink;
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(base, AppColors.inkSoft, 0.5)!.withValues(alpha: 0.80),
            base.withValues(alpha: 0.74),
          ],
        );
    }
  }

  List<Color> get _rim {
    switch (style) {
      case GlassStyle.light:
        return [
          Colors.white,
          Colors.white.withValues(alpha: 0.35),
        ];
      case GlassStyle.dark:
        return [
          Colors.white.withValues(alpha: 0.55),
          Colors.white.withValues(alpha: 0.08),
        ];
      case GlassStyle.smoked:
        return [
          Colors.white.withValues(alpha: 0.28),
          Colors.white.withValues(alpha: 0.04),
        ];
    }
  }

  List<BoxShadow> get _shadow {
    switch (style) {
      case GlassStyle.light:
        return const [
          BoxShadow(
            color: Color(0x1A2423B8),
            blurRadius: 30,
            offset: Offset(0, 14),
          ),
        ];
      case GlassStyle.dark:
        return const [
          BoxShadow(
            color: Color(0x33080630),
            blurRadius: 30,
            offset: Offset(0, 16),
          ),
        ];
      case GlassStyle.smoked:
        return const [
          BoxShadow(
            color: Color(0x520F0D45),
            blurRadius: 32,
            offset: Offset(0, 14),
          ),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget pane = DecoratedBox(
      decoration: BoxDecoration(gradient: _fill),
      child: Padding(padding: padding, child: child),
    );
    if (blur > 0) {
      pane = BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: pane,
      );
    }
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: shadow ? _OuterShadowPainter(borderRadius, _shadow) : null,
        foregroundPainter: _RimPainter(borderRadius, _rim),
        child: ClipRRect(borderRadius: borderRadius, child: pane),
      ),
    );
  }
}

/// Draws box shadows clipped to the outside of the shape, so they never
/// muddy a translucent surface.
class _OuterShadowPainter extends CustomPainter {
  final BorderRadius radius;
  final List<BoxShadow> shadows;
  const _OuterShadowPainter(this.radius, this.shadows);

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = radius.toRRect(Offset.zero & size);
    canvas.save();
    canvas.clipPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addRect((Offset.zero & size).inflate(120))
        ..addRRect(rrect),
    );
    for (final s in shadows) {
      canvas.drawRRect(
        rrect.shift(s.offset).inflate(s.spreadRadius),
        s.toPaint(),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_OuterShadowPainter oldDelegate) =>
      oldDelegate.radius != radius || oldDelegate.shadows != shadows;
}

/// The lit rim: a hairline that is bright at the top-left and fades away
/// toward the bottom-right.
class _RimPainter extends CustomPainter {
  final BorderRadius radius;
  final List<Color> colors;
  const _RimPainter(this.radius, this.colors);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = radius.toRRect(rect).deflate(0.6);
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_RimPainter oldDelegate) =>
      oldDelegate.radius != radius || oldDelegate.colors != colors;
}

/// The canvas every content screen rests on: a cool lab-coat white washed
/// with soft fields of indigo, mint and peach. Glass cards pick up these
/// colours as they scroll across — that drift is what makes them read as
/// glass.
///
/// Put it directly under the Scaffold (which should be transparent or
/// canvas-coloured) and let the page scroll on top.
class AppBackground extends StatelessWidget {
  final Widget child;

  /// Leans the wash toward one feature colour.
  final Tone? accent;

  const AppBackground({super.key, required this.child, this.accent});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.passthrough,
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(painter: _MeshPainter(accent?.color)),
          ),
        ),
        child,
      ],
    );
  }
}

class _MeshPainter extends CustomPainter {
  final Color? accent;
  const _MeshPainter(this.accent);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = AppColors.canvas);

    void field(Alignment at, double radius, Color color, double alpha) {
      final center = at.withinRect(rect);
      final r = size.longestSide * radius;
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..shader = RadialGradient(
            colors: [
              color.withValues(alpha: alpha),
              color.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: center, radius: r)),
      );
    }

    field(const Alignment(1.1, -0.75), 0.52, AppColors.indigoBright, 0.36);
    field(const Alignment(-1.2, -0.1), 0.46, AppColors.mint, 0.30);
    field(
      const Alignment(1.0, 0.75),
      0.5,
      accent ?? AppColors.peach,
      accent == null ? 0.28 : 0.30,
    );
    field(const Alignment(-0.9, 1.1), 0.42, AppColors.indigo, 0.22);
  }

  @override
  bool shouldRepaint(_MeshPainter oldDelegate) => oldDelegate.accent != accent;
}

/// A frosted sheet for `showModalBottomSheet`. Use with
/// `backgroundColor: Colors.transparent` so the page shows through.
class GlassSheet extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool showHandle;

  const GlassSheet({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(20, 8, 20, 20),
    this.showHandle = true,
  });

  @override
  Widget build(BuildContext context) {
    return Glass(
      blur: Glass.frost,
      shadow: false,
      tint: Colors.white,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppRadii.xl),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: padding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showHandle)
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    margin: const EdgeInsets.only(top: 4, bottom: 14),
                    decoration: BoxDecoration(
                      color: AppColors.ink.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

/// A frosted dialog body. Use as the `child` of a [Dialog] with a
/// transparent background, or through [showGlassDialog].
class GlassDialog extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const GlassDialog({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Glass(
        blur: Glass.frost,
        padding: padding,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        child: child,
      ),
    );
  }
}

/// Shows [child] in a frosted dialog that scales up out of the page.
Future<T?> showGlassDialog<T>({
  required BuildContext context,
  required Widget child,
  bool barrierDismissible = true,
  EdgeInsetsGeometry padding = const EdgeInsets.all(24),
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: AppColors.ink.withValues(alpha: 0.45),
    transitionDuration: AppMotion.medium,
    pageBuilder: (context, _, __) => GlassDialog(padding: padding, child: child),
    transitionBuilder: (context, animation, _, dialog) {
      final curved =
          CurvedAnimation(parent: animation, curve: AppMotion.emphasized);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween(begin: 0.92, end: 1.0).animate(curved),
          child: dialog,
        ),
      );
    },
  );
}

/// Restyles inputs, checkboxes and text buttons for a form that sits on
/// dark glass over the aurora: translucent fields, white text, mint focus.
class GlassFormTheme extends StatelessWidget {
  final Widget child;
  const GlassFormTheme({super.key, required this.child});

  /// The style to give `TextFormField.style` inside this theme.
  static TextStyle get fieldText =>
      AppText.body(size: 16, color: Colors.white, weight: FontWeight.w500);

  static OutlineInputBorder _border(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
        borderSide: BorderSide(color: color, width: width),
      );

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    const errorColor = Color(0xFFFFA8B0);
    return Theme(
      data: base.copyWith(
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.10),
          hintStyle: AppText.body(
            size: 15,
            color: Colors.white.withValues(alpha: 0.42),
          ),
          labelStyle: AppText.body(
            size: 15,
            color: Colors.white.withValues(alpha: 0.7),
          ),
          floatingLabelStyle: AppText.body(
            size: 15,
            color: AppColors.mintBright,
            weight: FontWeight.w600,
          ),
          prefixIconColor: Colors.white.withValues(alpha: 0.82),
          suffixIconColor: Colors.white.withValues(alpha: 0.7),
          border: _border(Colors.white.withValues(alpha: 0.2)),
          enabledBorder: _border(Colors.white.withValues(alpha: 0.2)),
          disabledBorder: _border(Colors.white.withValues(alpha: 0.1)),
          focusedBorder: _border(AppColors.mintBright, 1.6),
          errorBorder: _border(errorColor),
          focusedErrorBorder: _border(errorColor, 1.6),
          errorStyle: AppText.body(
            size: 12.5,
            color: errorColor,
            weight: FontWeight.w600,
          ),
          errorMaxLines: 3,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
        ),
        textSelectionTheme: TextSelectionThemeData(
          cursorColor: AppColors.mintBright,
          selectionColor: AppColors.mintBright.withValues(alpha: 0.3),
          selectionHandleColor: AppColors.mintBright,
        ),
        checkboxTheme: CheckboxThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          side: BorderSide(
            color: Colors.white.withValues(alpha: 0.6),
            width: 1.6,
          ),
          fillColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? AppColors.mint
                : Colors.transparent,
          ),
          checkColor: const WidgetStatePropertyAll(AppColors.ink),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
            shape: const StadiumBorder(),
            textStyle: AppText.body(size: 14, weight: FontWeight.w700),
          ),
        ),
        iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(
            foregroundColor: Colors.white.withValues(alpha: 0.8),
          ),
        ),
      ),
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: Colors.white),
        child: child,
      ),
    );
  }
}
