import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LightModeColors {
  // Primary color palette based on novoPharmaBlue (#3A39EE)
  static const lightPrimary = Color(0xFF3A39EE); // novoPharmaBlue
  static const lightOnPrimary = Color(0xFFFFFFFF);
  static const lightPrimaryContainer = Color(0xFFE6E6FF); // Lighter version of primary
  static const lightOnPrimaryContainer = Color(0xFF0A0A26); // Darker version of primary
  static const lightSecondary = Color(0xFF5B5AE4); // Slightly lighter than primary
  static const lightOnSecondary = Color(0xFFFFFFFF);
  static const lightTertiary = Color(0xFF7B7BFF); // Lighter version of primary
  static const lightOnTertiary = Color(0xFFFFFFFF);

  // Error colors
  static const lightError = Color(0xFFFF676F); 
  static const lightOnError = Color(0xFFFFFFFF);
  static const lightErrorContainer = Color(0xFFFCEEEE);
  static const lightOnErrorContainer = Color(0xFF410002);
  
  // Surface and background colors
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightOnSurface = Color(0xFF1C1C1C);
  static const lightSurfaceVariant = Color(0xFFF5F5F5);
  static const lightOnSurfaceVariant = Color(0xFF444444);
  
  // Background colors
  static const lightBackground = Color(0xFFF8FAFC);
  static const lightOnBackground = Color(0xFF1C1C1C);
  
  // Outline and border colors
  static const lightOutline = Color(0xFFD1D5DA);
  static const lightOutlineVariant = Color(0xFFE5E7EB);
  
  // App bar and navigation colors
  static const lightAppBarBackground = Color(0xFFFFFFFF);
  static const lightAppBarForeground = Color(0xFF1C1C1C);
  static const lightNavigationBar = Color(0xFFFFFFFF);
  static const lightNavigationOnItem = Color(0xFF3A39EE);
  static const lightNavigationItem = Color(0xFF9CA3AF);
  
  // Specific brand colors
  static const novoPharmaBlue = Color(0xFF3A39EE); // Primary brand color
  static const novoPharmaLightBlue = Color(0xFFE6E6FF); // Light background
  static const novoPharmaDarkBlue = Color(0xFF2A29A0); // Darker accent
  static const novoPharmaGray = Color(0xFF6B7280); // Neutral gray
  static const novoPharmaLightGray = Color(0xFFF3F4F6); // Light gray background
  
  // Dashboard specific colors
  static const dashboardTextPrimary = Color(0xFF111827); // Dark text
  static const dashboardTextSecondary = Color(0xFF6B7280); // Medium text
  static const dashboardTextTertiary = Color(0xFF9CA3AF); // Light text
  
  // Success and warning colors
  static const success = Color(0xFF73DB94);
  static const successContainer = Color(0xFFD1FAE5);
  static const warning = Color(0xFFFFB388);
  static const lightwarning = Color(0xFFFED7AA); // Light orange/yellow
  static const warningContainer = Color(0xFFFFF3CD);
    
  // Card and container colors
  static const cardBackground = Color(0xFFFFFFFF);
  static const cardElevated = Color(0xFFFFFFFF);
  static const cardBorder = Color(0xFFE5E7EB);
}

class DarkModeColors {
  // Primary color palette for dark mode
  static const darkPrimary = Color(0xFFB0B0FF); // Lighter version of primary for dark mode
  static const darkOnPrimary = Color(0xFF1A1A40);
  static const darkPrimaryContainer = Color(0xFF2A2A60); // Darker container
  static const darkOnPrimaryContainer = Color(0xFFD0D0FF);
  static const darkSecondary = Color(0xFF9090E0);
  static const darkOnSecondary = Color(0xFF0A0A26);
  static const darkTertiary = Color(0xFFA0A0FF);
  static const darkOnTertiary = Color(0xFF0A0A26);
  
  // Error colors for dark mode
  static const darkError = Color(0xFFFFB4AB);
  static const darkOnError = Color(0xFF690005);
  static const darkErrorContainer = Color(0xFF93000A);
  static const darkOnErrorContainer = Color(0xFFFFDAD6);
  
  // Surface and background colors for dark mode
  static const darkSurface = Color(0xFF121212);
  static const darkOnSurface = Color(0xFFE0E0E0);
  static const darkSurfaceVariant = Color(0xFF1E1E1E);
  static const darkOnSurfaceVariant = Color(0xFFC9C9C9);
  
  // Background colors for dark mode
  static const darkBackground = Color(0xFF0F0F0F);
  static const darkOnBackground = Color(0xFFE0E0E0);
  
  // Outline and border colors for dark mode
  static const darkOutline = Color(0xFF4B5563);
  static const darkOutlineVariant = Color(0xFF374151);
  
  // App bar and navigation colors for dark mode
  static const darkAppBarBackground = Color(0xFF1F1F1F);
  static const darkAppBarForeground = Color(0xFFE0E0E0);
  static const darkNavigationBar = Color(0xFF1F1F1F);
  static const darkNavigationOnItem = Color(0xFFB0B0FF);
  static const darkNavigationItem = Color(0xFF9CA3AF);
  
  // Brand colors for dark mode
  static const darkNovoPharmaBlue = Color(0xFFB0B0FF);
  static const darkNovoPharmaGray = Color(0xFF9CA3AF);
  static const darkNovoPharmaLightGray = Color(0xFF1F2937);
  
  // Success and warning colors for dark mode
  static const darkSuccess = Color(0xFF34D399);
  static const darkSuccessContainer = Color(0xFF064E3B);
  static const darkWarning = Color(0xFFFBBF24);
  static const darkWarningContainer = Color(0xFF78350F);
    
  // Card and container colors for dark mode
  static const darkCardBackground = Color(0xFF1F1F1F);
  static const darkCardElevated = Color(0xFF252525);
  static const darkCardBorder = Color(0xFF374151);
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

ThemeData get lightTheme => ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.light(
    primary: LightModeColors.lightPrimary,
    onPrimary: LightModeColors.lightOnPrimary,
    primaryContainer: LightModeColors.lightPrimaryContainer,
    onPrimaryContainer: LightModeColors.lightOnPrimaryContainer,
    secondary: LightModeColors.lightSecondary,
    onSecondary: LightModeColors.lightOnSecondary,
    tertiary: LightModeColors.lightTertiary,
    onTertiary: LightModeColors.lightOnTertiary,
    error: LightModeColors.lightError,
    onError: LightModeColors.lightOnError,
    errorContainer: LightModeColors.lightErrorContainer,
    onErrorContainer: LightModeColors.lightOnErrorContainer,
    surface: LightModeColors.lightSurface,
    onSurface: LightModeColors.lightOnSurface,
    surfaceContainerHighest: LightModeColors.lightSurfaceVariant,
    onSurfaceVariant: LightModeColors.lightOnSurfaceVariant,
    outline: LightModeColors.lightOutline,
    outlineVariant: LightModeColors.lightOutlineVariant,
  ),
  brightness: Brightness.light,
  appBarTheme: const AppBarTheme(
    backgroundColor: LightModeColors.lightAppBarBackground,
    foregroundColor: LightModeColors.lightAppBarForeground,
    elevation: 0,
  ),

  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: LightModeColors.lightPrimary,
      foregroundColor: LightModeColors.lightOnPrimary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: LightModeColors.lightPrimary),
      ),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: LightModeColors.lightPrimary,
      side: BorderSide(color: LightModeColors.lightPrimary, width: 1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: LightModeColors.lightSurface,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: LightModeColors.lightOutline),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: LightModeColors.lightOutline),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: LightModeColors.lightPrimary, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: LightModeColors.lightError),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: LightModeColors.lightError, width: 2),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: LightModeColors.lightPrimary,
    ),
  ),
  textTheme: TextTheme(
    displayLarge: GoogleFonts.inter(
      fontSize: FontSizes.displayLarge,
      fontWeight: FontWeight.w300,
      color: LightModeColors.dashboardTextPrimary,
    ),
    displayMedium: GoogleFonts.inter(
      fontSize: FontSizes.displayMedium,
      fontWeight: FontWeight.w300,
      color: LightModeColors.dashboardTextPrimary,
    ),
    displaySmall: GoogleFonts.inter(
      fontSize: FontSizes.displaySmall,
      fontWeight: FontWeight.w400,
      color: LightModeColors.dashboardTextPrimary,
    ),
    headlineLarge: GoogleFonts.inter(
      fontSize: FontSizes.headlineLarge,
      fontWeight: FontWeight.w400,
      color: LightModeColors.dashboardTextPrimary,
    ),
    headlineMedium: GoogleFonts.inter(
      fontSize: FontSizes.headlineMedium,
      fontWeight: FontWeight.w500,
      color: LightModeColors.dashboardTextPrimary,
    ),
    headlineSmall: GoogleFonts.inter(
      fontSize: FontSizes.headlineSmall,
      fontWeight: FontWeight.w600,
      color: LightModeColors.dashboardTextPrimary,
    ),
    titleLarge: GoogleFonts.inter(
      fontSize: FontSizes.titleLarge,
      fontWeight: FontWeight.w500,
      color: LightModeColors.dashboardTextPrimary,
    ),
    titleMedium: GoogleFonts.inter(
      fontSize: FontSizes.titleMedium,
      fontWeight: FontWeight.w500,
      color: LightModeColors.dashboardTextPrimary,
    ),
    titleSmall: GoogleFonts.inter(
      fontSize: FontSizes.titleSmall,
      fontWeight: FontWeight.w500,
      color: LightModeColors.dashboardTextSecondary,
    ),
    labelLarge: GoogleFonts.inter(
      fontSize: FontSizes.labelLarge,
      fontWeight: FontWeight.w500,
      color: LightModeColors.dashboardTextPrimary,
    ),
    labelMedium: GoogleFonts.inter(
      fontSize: FontSizes.labelMedium,
      fontWeight: FontWeight.w500,
      color: LightModeColors.dashboardTextPrimary,
    ),
    labelSmall: GoogleFonts.inter(
      fontSize: FontSizes.labelSmall,
      fontWeight: FontWeight.w500,
      color: LightModeColors.dashboardTextSecondary,
    ),
    bodyLarge: GoogleFonts.inter(
      fontSize: FontSizes.bodyLarge,
      fontWeight: FontWeight.w400,
      color: LightModeColors.dashboardTextPrimary,
    ),
    bodyMedium: GoogleFonts.inter(
      fontSize: FontSizes.bodyMedium,
      fontWeight: FontWeight.w400,
      color: LightModeColors.dashboardTextPrimary,
    ),
    bodySmall: GoogleFonts.inter(
      fontSize: FontSizes.bodySmall,
      fontWeight: FontWeight.w400,
      color: LightModeColors.dashboardTextSecondary,
    ),
  ),
);

ThemeData get darkTheme => ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.dark(
    primary: DarkModeColors.darkPrimary,
    onPrimary: DarkModeColors.darkOnPrimary,
    primaryContainer: DarkModeColors.darkPrimaryContainer,
    onPrimaryContainer: DarkModeColors.darkOnPrimaryContainer,
    secondary: DarkModeColors.darkSecondary,
    onSecondary: DarkModeColors.darkOnSecondary,
    tertiary: DarkModeColors.darkTertiary,
    onTertiary: DarkModeColors.darkOnTertiary,
    error: DarkModeColors.darkError,
    onError: DarkModeColors.darkOnError,
    errorContainer: DarkModeColors.darkErrorContainer,
    onErrorContainer: DarkModeColors.darkOnErrorContainer,
    surface: DarkModeColors.darkSurface,
    onSurface: DarkModeColors.darkOnSurface,
    surfaceContainerHighest: DarkModeColors.darkSurfaceVariant,
    onSurfaceVariant: DarkModeColors.darkOnSurfaceVariant,
    outline: DarkModeColors.darkOutline,
    outlineVariant: DarkModeColors.darkOutlineVariant,
  ),
  brightness: Brightness.dark,
  appBarTheme: const AppBarTheme(
    backgroundColor: DarkModeColors.darkAppBarBackground,
    foregroundColor: DarkModeColors.darkAppBarForeground,
    elevation: 0,
  ),

  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: DarkModeColors.darkPrimary,
      foregroundColor: DarkModeColors.darkOnPrimary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: DarkModeColors.darkPrimary),
      ),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: DarkModeColors.darkPrimary,
      side: BorderSide(color: DarkModeColors.darkPrimary, width: 1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: DarkModeColors.darkSurface,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: DarkModeColors.darkOutline),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: DarkModeColors.darkOutline),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: DarkModeColors.darkPrimary, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: DarkModeColors.darkError),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: DarkModeColors.darkError, width: 2),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: DarkModeColors.darkPrimary,
    ),
  ),
  textTheme: TextTheme(
    displayLarge: GoogleFonts.inter(
      fontSize: FontSizes.displayLarge,
      fontWeight: FontWeight.w300,
      color: DarkModeColors.darkOnSurface,
    ),
    displayMedium: GoogleFonts.inter(
      fontSize: FontSizes.displayMedium,
      fontWeight: FontWeight.w300,
      color: DarkModeColors.darkOnSurface,
    ),
    displaySmall: GoogleFonts.inter(
      fontSize: FontSizes.displaySmall,
      fontWeight: FontWeight.w400,
      color: DarkModeColors.darkOnSurface,
    ),
    headlineLarge: GoogleFonts.inter(
      fontSize: FontSizes.headlineLarge,
      fontWeight: FontWeight.w400,
      color: DarkModeColors.darkOnSurface,
    ),
    headlineMedium: GoogleFonts.inter(
      fontSize: FontSizes.headlineMedium,
      fontWeight: FontWeight.w500,
      color: DarkModeColors.darkOnSurface,
    ),
    headlineSmall: GoogleFonts.inter(
      fontSize: FontSizes.headlineSmall,
      fontWeight: FontWeight.w600,
      color: DarkModeColors.darkOnSurface,
    ),
    titleLarge: GoogleFonts.inter(
      fontSize: FontSizes.titleLarge,
      fontWeight: FontWeight.w500,
      color: DarkModeColors.darkOnSurface,
    ),
    titleMedium: GoogleFonts.inter(
      fontSize: FontSizes.titleMedium,
      fontWeight: FontWeight.w500,
      color: DarkModeColors.darkOnSurface,
    ),
    titleSmall: GoogleFonts.inter(
      fontSize: FontSizes.titleSmall,
      fontWeight: FontWeight.w500,
      color: DarkModeColors.darkOnSurfaceVariant,
    ),
    labelLarge: GoogleFonts.inter(
      fontSize: FontSizes.labelLarge,
      fontWeight: FontWeight.w500,
      color: DarkModeColors.darkOnSurface,
    ),
    labelMedium: GoogleFonts.inter(
      fontSize: FontSizes.labelMedium,
      fontWeight: FontWeight.w500,
      color: DarkModeColors.darkOnSurface,
    ),
    labelSmall: GoogleFonts.inter(
      fontSize: FontSizes.labelSmall,
      fontWeight: FontWeight.w500,
      color: DarkModeColors.darkOnSurfaceVariant,
    ),
    bodyLarge: GoogleFonts.inter(
      fontSize: FontSizes.bodyLarge,
      fontWeight: FontWeight.w400,
      color: DarkModeColors.darkOnSurface,
    ),
    bodyMedium: GoogleFonts.inter(
      fontSize: FontSizes.bodyMedium,
      fontWeight: FontWeight.w400,
      color: DarkModeColors.darkOnSurface,
    ),
    bodySmall: GoogleFonts.inter(
      fontSize: FontSizes.bodySmall,
      fontWeight: FontWeight.w400,
      color: DarkModeColors.darkOnSurfaceVariant,
    ),
  ),
);
