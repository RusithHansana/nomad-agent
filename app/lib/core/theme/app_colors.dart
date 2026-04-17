import 'package:flutter/material.dart';

/// Earth Tones design tokens for NomadAgent.
///
/// All color constants for the app live here. Widgets should reference
/// these tokens (or the resolved [ThemeData]) rather than hard‑coding
/// hex values.
class AppColors {
  AppColors._(); // prevent instantiation

  // ── Light mode tokens ──────────────────────────────────────────────

  static const Color primary = Color(0xFF2C3E2D); // Deep Forest Green
  static const Color primaryVariant = Color(0xFF4A7A50); // Sage Green
  static const Color secondary = Color(0xFFC8956C); // Terracotta
  static const Color secondaryVariant = Color(0xFF8A7F72); // Earthy Brown
  static const Color surface = Color(0xFFFFFFFF); // Warm White
  static const Color surfaceLight = Color(0xFFFAF7F2); // Soft Cream
  static const Color background = Color(0xFFFAF7F2); // Beige Sand
  static const Color onPrimary = Color(0xFFF5F0E8);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF2C3E2D);
  static const Color textSecondary = Color(0xFF8A7F72);
  static const Color success = Color(0xFF4A7A50);
  static const Color warning = Color(0xFFD49A6A);
  static const Color error = Color(0xFFB55B52);
  static const Color thoughtLog = Color(0xFF6B8F71);
  static const Color thoughtLogBackgroundLight = Color(0xFFF0F4F0);

  // ── Dark mode tokens ───────────────────────────────────────────────

  static const Color darkBackground = Color(0xFF1E1E1E);
  static const Color darkSurface = Color(0xFF2D2D2D);
  static const Color darkPrimary = Color(0xFF6B8F71);
  static const Color darkTextPrimary = Color(0xFFF5F0E8);
  static const Color darkTextSecondary = Color(0xFFA8A8A8);

  // Dark mode variants derived from the light palette for completeness
  static const Color darkPrimaryVariant = Color(0xFF4A7A50);
  static const Color darkSecondary = Color(0xFFC8956C);
  static const Color darkSecondaryVariant = Color(0xFF8A7F72);
  static const Color darkOnPrimary = Color(0xFF1E1E1E);
  static const Color darkOnSecondary = Color(0xFF1E1E1E);
  static const Color darkSurfaceLight = Color(0xFF383838);
  static const Color darkSuccess = Color(0xFF6B8F71);
  static const Color darkWarning = Color(0xFFD49A6A);
  static const Color darkError = Color(0xFFCF7B73);
  static const Color darkThoughtLog = Color(0xFF6B8F71);
  static const Color thoughtLogBackgroundDark = Color(0xFF1E2A1E);
}
