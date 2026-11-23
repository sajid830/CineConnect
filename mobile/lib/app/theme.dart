import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

export '../core/theme/app_theme.dart' show CineColors, CineTheme;

/// CineConnect color palette specification.
class AppColors {
  AppColors._();

  // Exact Brand Palette
  static const Color gold = Color(0xFFD4AF37);
  static const Color goldLight = Color(0xFFF1D675);
  static const Color surface = Color(0xFF161616);
  static const Color border = Color(0xFF2A2A2A);
  static const Color textPrimary = Color(0xFFF5F5F5);
  static const Color textMuted = Color(0xFF9A9A9A);
  static const Color error = Color(0xFFE5484D);

  // Background and helper constants for deep dark cinema styling
  static const Color black = Color(0xFF0B0C10);
  static const Color background = Color(0xFF0D0D0D);
  static const Color surfaceElevated = Color(0xFF1F1F1F);
  static const Color surfaceCard = Color(0xFF141419);
  static const Color card = surfaceCard;
  static const Color darkest = Color(0xFF080808);
  static const Color textSecondary = textMuted;
  static const Color goldDark = Color(0xFFB08D23);
  static const Color accent = goldLight;
  static const Color accentCyan = Color(0xFF00E5FF);
  static const Color success = Color(0xFF30A46C);
  static const Color warning = Color(0xFFF59E0B);
  static const Color goldGlow = Color(0x33D4AF37);
}

/// CineConnect Dark Theme specification adhering to Material 3 guidelines.
class AppTheme {
  AppTheme._();

  static ThemeData get dark => darkTheme;

  // Backward-compatible aliases mapped to the updated CineConnect palette
  static const Color primaryAmber = AppColors.gold;
  static const Color primaryAmberLight = AppColors.goldLight;
  static const Color primaryAmberDark = AppColors.goldDark;

  static const Color slateDarkest = AppColors.darkest;
  static const Color slateBackground = AppColors.background;
  static const Color slateCard = AppColors.surface;
  static const Color slateCardElevated = AppColors.surfaceElevated;
  static const Color slateBorder = AppColors.border;

  static const Color textPrimary = AppColors.textPrimary;
  static const Color textSecondary = AppColors.textMuted;
  static const Color textMuted = AppColors.textMuted;
  static const Color accentCyan = AppColors.goldLight;
  static const Color successGreen = AppColors.success;
  static const Color errorRed = AppColors.error;

  static ThemeData get darkTheme {
    const colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.gold,
      onPrimary: Colors.black,
      primaryContainer: AppColors.goldDark,
      onPrimaryContainer: Colors.white,
      secondary: AppColors.goldLight,
      onSecondary: Colors.black,
      secondaryContainer: Color(0xFF2E260F),
      onSecondaryContainer: Colors.white,
      tertiary: AppColors.goldLight,
      onTertiary: Colors.black,
      error: AppColors.error,
      onError: Colors.white,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      surfaceContainerHighest: AppColors.surfaceElevated,
      outline: AppColors.border,
      outlineVariant: AppColors.border,
    );

    final baseTextTheme = GoogleFonts.interTextTheme(const TextTheme(
      displayLarge: TextStyle(
          color: AppColors.textPrimary, fontWeight: FontWeight.bold),
      displayMedium: TextStyle(
          color: AppColors.textPrimary, fontWeight: FontWeight.bold),
      headlineLarge: TextStyle(
          color: AppColors.textPrimary, fontWeight: FontWeight.w700),
      headlineMedium: TextStyle(
          color: AppColors.textPrimary, fontWeight: FontWeight.w600),
      titleLarge: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600),
      titleMedium: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w500),
      bodyLarge: TextStyle(color: AppColors.textPrimary, fontSize: 16),
      bodyMedium: TextStyle(color: AppColors.textPrimary, fontSize: 14),
      bodySmall: TextStyle(color: AppColors.textMuted, fontSize: 12),
    ));

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      canvasColor: AppColors.background,
      dividerColor: AppColors.border,
      textTheme: baseTextTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          color: AppColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
        labelStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border, width: 1),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.gold, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith<Color>(
            (Set<WidgetState> states) {
              if (states.contains(WidgetState.disabled)) {
                return AppColors.border;
              }
              if (states.contains(WidgetState.hovered) ||
                  states.contains(WidgetState.pressed)) {
                return AppColors.goldLight;
              }
              return AppColors.gold;
            },
          ),
          foregroundColor: WidgetStateProperty.resolveWith<Color>(
            (Set<WidgetState> states) {
              if (states.contains(WidgetState.disabled)) {
                return AppColors.textMuted;
              }
              return Colors.black;
            },
          ),
          elevation: WidgetStateProperty.all(0),
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          textStyle: WidgetStateProperty.all(
            const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.goldLight,
          side: const BorderSide(color: AppColors.border),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
      ),
    );
  }
}
