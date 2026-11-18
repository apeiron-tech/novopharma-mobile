import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:novopharma/design/tokens.dart';

/// Legacy colour names, kept so existing screens keep compiling. Every value
/// now resolves to the Capsule palette in `design/tokens.dart` — new code
/// should use [AppColors] directly.
class LightModeColors {
  static const lightPrimary = AppColors.indigo;
  static const lightOnPrimary = Color(0xFFFFFFFF);
  static const lightPrimaryContainer = AppColors.indigoTint;
  static const lightOnPrimaryContainer = AppColors.ink;
  static const lightSecondary = AppColors.indigoBright;
  static const lightOnSecondary = Color(0xFFFFFFFF);
  static const lightTertiary = Color(0xFF8B8AFF);
  static const lightOnTertiary = Color(0xFFFFFFFF);

  static const lightError = AppColors.coral;
  static const lightOnError = Color(0xFFFFFFFF);
  static const lightErrorContainer = AppColors.coralTint;
  static const lightOnErrorContainer = Color(0xFF5C0A14);

  static const lightSurface = AppColors.surface;
  static const lightOnSurface = AppColors.text;
  static const lightSurfaceVariant = Color(0xFFF1F2FA);
  static const lightOnSurfaceVariant = Color(0xFF45476B);

  static const lightBackground = AppColors.canvas;
  static const lightOnBackground = AppColors.text;

  static const lightOutline = AppColors.lineStrong;
  static const lightOutlineVariant = AppColors.line;

  static const lightAppBarBackground = AppColors.canvas;
  static const lightAppBarForeground = AppColors.text;
  static const lightNavigationBar = AppColors.ink;
  static const lightNavigationOnItem = Color(0xFFFFFFFF);
  static const lightNavigationItem = Color(0xFF9D9FBC);

  static const novoPharmaBlue = AppColors.indigo;
  static const novoPharmaLightBlue = AppColors.indigoTint;
  static const novoPharmaDarkBlue = AppColors.indigoDeep;
  static const novoPharmaGray = AppColors.textMuted;
  static const novoPharmaLightGray = Color(0xFFF1F2FA);

  static const dashboardTextPrimary = AppColors.text;
  static const dashboardTextSecondary = AppColors.textMuted;
  static const dashboardTextTertiary = AppColors.textFaint;

  static const success = AppColors.mint;
  static const successContainer = AppColors.mintTint;
  static const warning = AppColors.peach;
  static const lightwarning = Color(0xFFFFC24D);
  static const warningContainer = AppColors.amberTint;

  static const cardBackground = AppColors.surface;
  static const cardElevated = AppColors.surface;
  static const cardBorder = AppColors.line;
}

class FontSizes {
  static const double displayLarge = 57.0;
  static const double displayMedium = 45.0;
  static const double displaySmall = 36.0;
  static const double headlineLarge = 32.0;
  static const double headlineMedium = 24.0;
  static const double headlineSmall = 22.0;
  static const double titleLarge = 22.0;
  static const double titleMedium = 18.0;
  static const double titleSmall = 16.0;
  static const double labelLarge = 16.0;
  static const double labelMedium = 14.0;
  static const double labelSmall = 12.0;
  static const double bodyLarge = 16.0;
  static const double bodyMedium = 14.0;
  static const double bodySmall = 12.0;
}

TextTheme _buildTextTheme() {
  TextStyle display(double size, FontWeight weight) =>
      GoogleFonts.bricolageGrotesque(
        fontSize: size,
        fontWeight: weight,
        color: AppColors.text,
        height: 1.1,
        letterSpacing: -0.02 * size,
      );
  TextStyle body(double size, FontWeight weight, [Color? color]) =>
      GoogleFonts.figtree(
        fontSize: size,
        fontWeight: weight,
        color: color ?? AppColors.text,
        height: 1.4,
      );

  return TextTheme(
    displayLarge: display(FontSizes.displayLarge, FontWeight.w700),
    displayMedium: display(FontSizes.displayMedium, FontWeight.w700),
    displaySmall: display(FontSizes.displaySmall, FontWeight.w700),
    headlineLarge: display(FontSizes.headlineLarge, FontWeight.w700),
    headlineMedium: display(FontSizes.headlineMedium, FontWeight.w700),
    headlineSmall: display(FontSizes.headlineSmall, FontWeight.w700),
    titleLarge: display(FontSizes.titleLarge, FontWeight.w600),
    titleMedium: body(FontSizes.titleMedium, FontWeight.w700),
    titleSmall: body(FontSizes.titleSmall, FontWeight.w600, AppColors.textMuted),
    labelLarge: body(FontSizes.labelLarge, FontWeight.w600),
    labelMedium: body(FontSizes.labelMedium, FontWeight.w600),
    labelSmall: body(FontSizes.labelSmall, FontWeight.w600, AppColors.textMuted),
    bodyLarge: body(FontSizes.bodyLarge, FontWeight.w400),
    bodyMedium: body(FontSizes.bodyMedium, FontWeight.w400),
    bodySmall: body(FontSizes.bodySmall, FontWeight.w400, AppColors.textMuted),
  );
}

OutlineInputBorder _inputBorder(Color color, [double width = 1]) =>
    OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadii.md),
      borderSide: BorderSide(color: color, width: width),
    );

/// The one theme the app ships. Screens are designed for a light canvas
/// under ink headers, so there is no separate dark appearance.
ThemeData get lightTheme {
  final textTheme = _buildTextTheme();
  final buttonLabel = GoogleFonts.figtree(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    height: 1.1,
  );
  const pill = StadiumBorder();

  const scheme = ColorScheme.light(
    primary: AppColors.indigo,
    onPrimary: Colors.white,
    primaryContainer: AppColors.indigoTint,
    onPrimaryContainer: AppColors.ink,
    secondary: AppColors.indigoBright,
    onSecondary: Colors.white,
    secondaryContainer: AppColors.indigoTint,
    onSecondaryContainer: AppColors.ink,
    tertiary: AppColors.mint,
    onTertiary: AppColors.ink,
    tertiaryContainer: AppColors.mintTint,
    onTertiaryContainer: AppColors.mintDeep,
    error: AppColors.coral,
    onError: Colors.white,
    errorContainer: AppColors.coralTint,
    onErrorContainer: LightModeColors.lightOnErrorContainer,
    surface: AppColors.surface,
    onSurface: AppColors.text,
    onSurfaceVariant: AppColors.textMuted,
    surfaceContainerLowest: AppColors.surface,
    surfaceContainerLow: AppColors.surfaceSunken,
    surfaceContainer: AppColors.surfaceSunken,
    surfaceContainerHigh: LightModeColors.lightSurfaceVariant,
    surfaceContainerHighest: LightModeColors.lightSurfaceVariant,
    outline: AppColors.lineStrong,
    outlineVariant: AppColors.line,
    surfaceTint: Colors.transparent,
    shadow: AppColors.ink,
    scrim: AppColors.ink,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.canvas,
    canvasColor: AppColors.canvas,
    textTheme: textTheme,
    primaryTextTheme: textTheme,
    splashColor: AppColors.indigo.withValues(alpha: 0.08),
    highlightColor: AppColors.indigo.withValues(alpha: 0.04),
    dividerColor: AppColors.line,
    iconTheme: const IconThemeData(color: AppColors.text),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(
          backgroundColor: AppColors.canvas,
        ),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.canvas,
      foregroundColor: AppColors.text,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleSpacing: 4,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      iconTheme: const IconThemeData(color: AppColors.text),
      titleTextStyle: GoogleFonts.bricolageGrotesque(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: AppColors.text,
        letterSpacing: -0.4,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.indigo,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.lineStrong,
        disabledForegroundColor: AppColors.textMuted,
        elevation: 0,
        shadowColor: Colors.transparent,
        minimumSize: const Size(64, 52),
        shape: pill,
        textStyle: buttonLabel,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.indigo,
        foregroundColor: Colors.white,
        minimumSize: const Size(64, 52),
        shape: pill,
        textStyle: buttonLabel,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.indigo,
        side: const BorderSide(color: AppColors.lineStrong, width: 1.4),
        minimumSize: const Size(64, 52),
        shape: pill,
        textStyle: buttonLabel,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.indigo,
        shape: pill,
        textStyle: buttonLabel.copyWith(fontSize: 15),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: AppColors.text),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.indigo,
      foregroundColor: Colors.white,
      elevation: 6,
      highlightElevation: 2,
      shape: CircleBorder(),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceSunken,
      hintStyle: GoogleFonts.figtree(color: AppColors.textFaint, fontSize: 15),
      labelStyle: GoogleFonts.figtree(color: AppColors.textMuted, fontSize: 15),
      floatingLabelStyle: GoogleFonts.figtree(
        color: AppColors.indigo,
        fontWeight: FontWeight.w600,
      ),
      prefixIconColor: AppColors.indigo,
      suffixIconColor: AppColors.textMuted,
      border: _inputBorder(AppColors.line),
      enabledBorder: _inputBorder(AppColors.line),
      disabledBorder: _inputBorder(AppColors.line),
      focusedBorder: _inputBorder(AppColors.indigo, 1.8),
      errorBorder: _inputBorder(AppColors.coral),
      focusedErrorBorder: _inputBorder(AppColors.coral, 1.8),
      errorStyle: GoogleFonts.figtree(
        color: AppColors.coralDeep,
        fontSize: 12.5,
        fontWeight: FontWeight.w500,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: AppColors.indigo,
      selectionColor: AppColors.indigo.withValues(alpha: 0.2),
      selectionHandleColor: AppColors.indigo,
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shadowColor: AppColors.ink.withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      titleTextStyle: GoogleFonts.bricolageGrotesque(
        fontSize: 21,
        fontWeight: FontWeight.w700,
        color: AppColors.text,
        letterSpacing: -0.3,
      ),
      contentTextStyle: GoogleFonts.figtree(
        fontSize: 15,
        height: 1.45,
        color: AppColors.textMuted,
      ),
      barrierColor: AppColors.ink.withValues(alpha: 0.55),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      modalBackgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      modalBarrierColor: AppColors.ink.withValues(alpha: 0.55),
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
      ),
      clipBehavior: Clip.antiAlias,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.ink,
      elevation: 0,
      insetPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      contentTextStyle: GoogleFonts.figtree(
        fontSize: 14.5,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
      actionTextColor: AppColors.mintBright,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 10,
      shadowColor: AppColors.ink.withValues(alpha: 0.18),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      textStyle: GoogleFonts.figtree(fontSize: 15, color: AppColors.text),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.surface,
      selectedColor: AppColors.indigo,
      disabledColor: AppColors.line,
      side: const BorderSide(color: AppColors.line),
      shape: pill,
      showCheckmark: false,
      labelStyle: GoogleFonts.figtree(
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
        color: AppColors.text,
      ),
      secondaryLabelStyle: GoogleFonts.figtree(
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: AppColors.indigo,
      unselectedLabelColor: AppColors.textMuted,
      indicatorColor: AppColors.indigo,
      indicatorSize: TabBarIndicatorSize.label,
      dividerColor: Colors.transparent,
      labelStyle: GoogleFonts.figtree(fontSize: 15, fontWeight: FontWeight.w700),
      unselectedLabelStyle:
          GoogleFonts.figtree(fontSize: 15, fontWeight: FontWeight.w500),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.indigo,
      linearTrackColor: AppColors.indigoTint,
      circularTrackColor: Colors.transparent,
      refreshBackgroundColor: AppColors.surface,
      linearMinHeight: 6,
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.line,
      thickness: 1,
      space: 1,
    ),
    listTileTheme: ListTileThemeData(
      iconColor: AppColors.indigo,
      titleTextStyle: GoogleFonts.figtree(
        fontSize: 15.5,
        fontWeight: FontWeight.w600,
        color: AppColors.text,
      ),
      subtitleTextStyle: GoogleFonts.figtree(
        fontSize: 13.5,
        color: AppColors.textMuted,
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      side: const BorderSide(color: AppColors.lineStrong, width: 1.6),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(AppRadii.xs),
      ),
      textStyle: GoogleFonts.figtree(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
    ),
    badgeTheme: const BadgeThemeData(
      backgroundColor: AppColors.coral,
      textColor: Colors.white,
    ),
  );
}

/// Kept for call sites that still ask for it; the app has one appearance.
ThemeData get darkTheme => lightTheme;
