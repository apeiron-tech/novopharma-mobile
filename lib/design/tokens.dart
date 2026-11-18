import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Capsule — the MyChallenge design language.
///
/// Borrowed from the pharmacy counter: the two-tone gélule, the blister pack
/// and the glowing green cross. Deep ink surfaces carry identity (headers,
/// dock), a cool "lab coat" canvas carries content, and one saturated accent
/// per feature keeps people oriented.
class AppColors {
  AppColors._();

  // Ink — hero surfaces. Derived from the brand hue, never neutral black.
  static const ink = Color(0xFF0F0D45);
  static const inkSoft = Color(0xFF1C1A75);
  static const inkLine = Color(0xFF2E2B8F);

  // Indigo — the NovoPharma brand colour.
  static const indigo = Color(0xFF3A39EE);
  static const indigoBright = Color(0xFF6563FF);
  static const indigoDeep = Color(0xFF2423B8);
  static const indigoTint = Color(0xFFEDEDFF);

  // Mint — the pharmacy cross. Gains, success, the scanner.
  static const mint = Color(0xFF14CC9E);
  static const mintBright = Color(0xFF4CF0C3);
  static const mintDeep = Color(0xFF0A8F6E);
  static const mintTint = Color(0xFFDFF8F0);

  // Coral — spending points, alerts.
  static const coral = Color(0xFFFF5C6C);
  static const coralDeep = Color(0xFFE23A4E);
  static const coralTint = Color(0xFFFFE7E9);

  // Amber — points, medals, rewards.
  static const amber = Color(0xFFFFAE1F);
  static const amberDeep = Color(0xFFC77700);
  static const amberTint = Color(0xFFFFF2D9);

  // Peach — sales.
  static const peach = Color(0xFFFF9257);
  static const peachTint = Color(0xFFFFEBDD);

  // Neutrals, cooled toward the brand hue.
  static const canvas = Color(0xFFF3F4FB);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceSunken = Color(0xFFF7F8FD);
  static const line = Color(0xFFE5E6F3);
  static const lineStrong = Color(0xFFD3D5E8);
  static const text = Color(0xFF14133A);
  static const textMuted = Color(0xFF65678A);
  static const textFaint = Color(0xFF9D9FBC);

  // Podium metals.
  static const gold = Color(0xFFFFC53D);
  static const silver = Color(0xFFB8BED6);
  static const bronze = Color(0xFFE39A6B);
}

/// A feature's two-tone identity: a saturated tone and its pale tint.
class Tone {
  final Color color;
  final Color deep;
  final Color tint;
  const Tone(this.color, this.deep, this.tint);

  static const indigo =
      Tone(AppColors.indigo, AppColors.indigoDeep, AppColors.indigoTint);
  static const mint = Tone(AppColors.mint, AppColors.mintDeep, AppColors.mintTint);
  static const coral =
      Tone(AppColors.coral, AppColors.coralDeep, AppColors.coralTint);
  static const amber =
      Tone(AppColors.amber, AppColors.amberDeep, AppColors.amberTint);
  static const peach =
      Tone(AppColors.peach, Color(0xFFD9652A), AppColors.peachTint);

  LinearGradient get gradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color.lerp(color, Colors.white, 0.18)!, color, deep],
        stops: const [0, 0.45, 1],
      );
}

class AppGradients {
  AppGradients._();

  static const ink = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.ink, Color(0xFF17146A), AppColors.inkSoft],
  );

  static const indigo = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.indigoBright, AppColors.indigo, AppColors.indigoDeep],
    stops: [0, 0.5, 1],
  );

  static const mint = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.mintBright, AppColors.mint],
  );

  static const coral = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF7A86), AppColors.coral, AppColors.coralDeep],
    stops: [0, 0.5, 1],
  );

  static const amber = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFD166), AppColors.amber],
  );
}

class AppRadii {
  AppRadii._();
  static const double xs = 10;
  static const double sm = 14;
  static const double md = 20;
  static const double lg = 28;
  static const double xl = 36;
  static const double pill = 999;

  static BorderRadius circular(double r) => BorderRadius.circular(r);
}

class AppSpace {
  AppSpace._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 28;
  static const double page = 20;
}

/// Shadows are tinted with ink instead of grey so cards feel lit by the
/// header above them.
class AppShadows {
  AppShadows._();

  static const card = [
    BoxShadow(color: Color(0x0A14133A), blurRadius: 2, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x0F14133A), blurRadius: 24, offset: Offset(0, 10)),
  ];

  static const lifted = [
    BoxShadow(color: Color(0x1414133A), blurRadius: 4, offset: Offset(0, 2)),
    BoxShadow(color: Color(0x1F14133A), blurRadius: 40, offset: Offset(0, 18)),
  ];

  static List<BoxShadow> glow(Color color, {double strength = 0.38}) => [
        BoxShadow(
          color: color.withValues(alpha: strength),
          blurRadius: 24,
          offset: const Offset(0, 10),
        ),
      ];
}

class AppMotion {
  AppMotion._();

  static const instant = Duration(milliseconds: 90);
  static const fast = Duration(milliseconds: 180);
  static const medium = Duration(milliseconds: 320);
  static const slow = Duration(milliseconds: 560);
  static const hero = Duration(milliseconds: 900);

  /// Decisive start, long settle. The default for anything entering.
  static const emphasized = Cubic(0.2, 0.0, 0.0, 1.0);

  /// Slight overshoot for things that respond to a touch.
  static const spring = Cubic(0.34, 1.4, 0.64, 1.0);

  static const exit = Cubic(0.4, 0.0, 1.0, 1.0);

  /// True when the person asked the OS to reduce motion. Ambient loops stop
  /// and entrances resolve immediately.
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;
}

/// Type. Bricolage Grotesque for headlines and scores, Figtree for reading.
class AppText {
  AppText._();

  static const _tabular = [FontFeature.tabularFigures()];

  static TextStyle display({
    double size = 28,
    FontWeight weight = FontWeight.w700,
    Color color = AppColors.text,
    double? height,
    double? letterSpacing,
  }) =>
      GoogleFonts.bricolageGrotesque(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height ?? 1.08,
        letterSpacing: letterSpacing ?? -0.022 * size,
        fontFeatures: _tabular,
      );

  static TextStyle body({
    double size = 15,
    FontWeight weight = FontWeight.w400,
    Color color = AppColors.text,
    double? height,
    double? letterSpacing,
  }) =>
      GoogleFonts.figtree(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height ?? 1.4,
        letterSpacing: letterSpacing,
      );

  static TextStyle label({
    double size = 13,
    FontWeight weight = FontWeight.w600,
    Color color = AppColors.textMuted,
    double? letterSpacing,
  }) =>
      GoogleFonts.figtree(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: 1.2,
        letterSpacing: letterSpacing ?? 0.1,
      );
}

/// Groups thousands with a thin space and keeps up to two decimals:
/// 12480 -> "12 480", 3.5 -> "3.5".
String formatPoints(num value) {
  final negative = value < 0;
  final rounded = (value.abs() * 100).round() / 100;
  final whole = rounded.truncate();
  var fraction = '';
  if (rounded != whole.toDouble()) {
    fraction = rounded
        .toStringAsFixed(2)
        .split('.')[1]
        .replaceAll(RegExp(r'0+$'), '');
  }
  final digits = whole.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('\u202F');
    buffer.write(digits[i]);
  }
  final body = fraction.isEmpty ? buffer.toString() : '$buffer.$fraction';
  return negative ? '-$body' : body;
}
