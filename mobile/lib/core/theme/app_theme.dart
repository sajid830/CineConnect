import 'package:flutter/material.dart';

class CineColors {
  // User Specified Design Tokens
  static const Color gold = Color(0xFFD4AF37);
  static const Color goldLight = Color(0xFFF1D675);
  static const Color surface = Color(0xFF161616);
  static const Color border = Color(0xFF2A2A2A);
  static const Color textPrimary = Color(0xFFF5F5F5);
  static const Color textMuted = Color(0xFF9A9A9A);
  static const Color error = Color(0xFFE5484D);

  // Cinematic Dark Environment Tokens
  static const Color background = Color(0xFF0B0C10);
  static const Color surfaceElevated = Color(0xFF1C1C22);
  static const Color surfaceCard = Color(0xFF141419);
  static const Color accentCyan = Color(0xFF00E5FF); // Anamorphic Production Mode
  static const Color success = Color(0xFF10B981);    // 96% Match / Verified Badges
  static const Color warning = Color(0xFFF59E0B);    // 35mm Amber Warning / In Review
  static const Color goldGlow = Color(0x33D4AF37);
}

class CineTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: CineColors.background,
      primaryColor: CineColors.gold,
      colorScheme: const ColorScheme.dark(
        primary: CineColors.gold,
        onPrimary: Colors.black,
        secondary: CineColors.goldLight,
        onSecondary: Colors.black,
        surface: CineColors.surface,
        onSurface: CineColors.textPrimary,
        error: CineColors.error,
        onError: Colors.white,
      ),
      fontFamily: 'Inter',
      appBarTheme: const AppBarTheme(
        backgroundColor: CineColors.background,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: CineColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
        iconTheme: IconThemeData(color: CineColors.gold),
      ),
      cardTheme: CardThemeData(
        color: CineColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: CineColors.border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: CineColors.surface,
        hintStyle: const TextStyle(color: CineColors.textMuted, fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: CineColors.border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: CineColors.border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: CineColors.gold, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: CineColors.gold,
          foregroundColor: Colors.black,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: CineColors.gold,
          side: const BorderSide(color: CineColors.gold, width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: CineColors.border,
        thickness: 1,
        space: 1,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: CineColors.textPrimary, fontSize: 26, fontWeight: FontWeight.w800),
        titleLarge: TextStyle(color: CineColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
        titleMedium: TextStyle(color: CineColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(color: CineColors.textPrimary, fontSize: 14, fontWeight: FontWeight.normal),
        bodyMedium: TextStyle(color: CineColors.textMuted, fontSize: 13, fontWeight: FontWeight.normal),
        labelSmall: TextStyle(color: CineColors.gold, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8),
      ),
    );
  }
}
