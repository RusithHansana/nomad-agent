import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Typography scale for NomadAgent.
///
/// Uses Inter for UI text and JetBrains Mono for the thought‑log viewer.
/// All sizes/weights match the UX design specification.
class AppTypography {
  AppTypography._();

  // ── Inter type scale ───────────────────────────────────────────────

  /// Display — 28/700
  static TextStyle display({Color? color}) => GoogleFonts.inter(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: color,
      );

  /// H1 — 24/600
  static TextStyle h1({Color? color}) => GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: color,
      );

  /// H2 — 20/600
  static TextStyle h2({Color? color}) => GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: color,
      );

  /// H3 — 17/500
  static TextStyle h3({Color? color}) => GoogleFonts.inter(
        fontSize: 17,
        fontWeight: FontWeight.w500,
        color: color,
      );

  /// Body — 15/400
  static TextStyle body({Color? color}) => GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: color,
      );

  /// Body Small — 13/400
  static TextStyle bodySmall({Color? color}) => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: color,
      );

  /// Caption — 11/500
  static TextStyle caption({Color? color}) => GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: color,
      );

  // ── Monospace (Thought Log) ────────────────────────────────────────

  /// ThoughtLog — 14/400 JetBrains Mono
  static TextStyle thoughtLog({Color? color}) => GoogleFonts.jetBrainsMono(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: color,
      );

  // ── TextTheme builder (used by AppTheme) ───────────────────────────

  /// Builds a [TextTheme] mapped to Material 3 slots using the Inter
  /// type scale and the given [textColor] / [secondaryColor].
  static TextTheme textTheme({
    required Color textColor,
    required Color secondaryColor,
  }) {
    return TextTheme(
      displayLarge: display(color: textColor),
      headlineLarge: h1(color: textColor),
      headlineMedium: h2(color: textColor),
      headlineSmall: h3(color: textColor),
      bodyLarge: body(color: textColor),
      bodyMedium: body(color: textColor),
      bodySmall: bodySmall(color: secondaryColor),
      labelLarge: bodySmall(color: textColor),
      labelMedium: caption(color: secondaryColor),
      labelSmall: caption(color: secondaryColor),
    );
  }
}
