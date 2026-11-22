import 'package:flutter/material.dart';

/// CineConnect Design System Color Palette.
/// Cinema-inspired palette with deep slate, cinema dark, and amber/gold accents.
class AppColors {
  AppColors._();

  // Primary brand palette (Cinematic Amber / Gold)
  static const Color gold = Color(0xFFD4AF37);
  static const Color goldLight = Color(0xFFF1D675);
  static const Color primary = Color(0xFFE5A93C);
  static const Color onPrimary = Color(0xFF1E1705);
  static const Color primaryContainer = Color(0xFF3F2E09);
  static const Color onPrimaryContainer = Color(0xFFFFDF9E);

  // Surface & text aliases for compatibility
  static const Color surface = Color(0xFF161616);
  static const Color border = Color(0xFF2A2A2A);
  static const Color textPrimary = Color(0xFFF5F5F5);
  static const Color textMuted = Color(0xFF9A9A9A);
  static const Color background = Color(0xFF0D0D0D);

  // Secondary brand palette (Cinema Teal)
  static const Color secondary = Color(0xFF4DB6AC);
  static const Color onSecondary = Color(0xFF003731);
  static const Color secondaryContainer = Color(0xFF005048);
  static const Color onSecondaryContainer = Color(0xFF70F3E5);

  // Dark background / surface
  static const Color darkBackground = Color(0xFF0E1116);
  static const Color darkSurface = Color(0xFF161B22);
  static const Color darkSurfaceVariant = Color(0xFF21262D);
  static const Color onDarkSurface = Color(0xFFE6EDF3);
  static const Color onDarkSurfaceVariant = Color(0xFF8B949E);

  // Light background / surface
  static const Color lightBackground = Color(0xFFF6F8FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceVariant = Color(0xFFEAEFF5);
  static const Color onLightSurface = Color(0xFF1F2328);
  static const Color onLightSurfaceVariant = Color(0xFF656D76);

  // Semantic
  static const Color success = Color(0xFF3FB950);
  static const Color warning = Color(0xFFD29922);
  static const Color error = Color(0xFFF85149);
  static const Color onError = Color(0xFFFFFFFF);
}
