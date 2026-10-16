import 'package:flutter/material.dart';

/// Centralized color palette matching exact brand requirements.
class AppColors {
  // Dark Palette
  static const Color darkBackground = Color(0xFF0B0F19);
  static const Color darkSurface = Color(0xFF111827);
  static const Color darkCard = Color(0xFF151D2E);
  static const Color darkBorder = Color(0xFF263244);
  static const Color darkPrimary = Color(0xFF06B6D4);
  static const Color darkPrimaryDark = Color(0xFF0891B2);
  static const Color darkText = Color(0xFFF8FAFC);
  static const Color darkSecondary = Color(0xFF94A3B8);
  static const Color darkMuted = Color(0xFF64748B);

  // Light Palette
  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightPrimary = Color(0xFF0891B2);
  static const Color lightText = Color(0xFF0F172A);
  static const Color lightSecondary = Color(0xFF475569);
  static const Color lightMuted = Color(0xFF64748B);

  // Functional Semantic Accents (Shared)
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF38BDF8);

  // Indian Tricolor Accents for delicate editorial micro-branding
  static const Color saffron = Color(0xFFFF9933);
  static const Color indiaGreen = Color(0xFF138808);

  // AA steps for *type* sitting on the default surfaces. The brand fills above
  // stay exactly as they are, so buttons, chips and hero art keep their colour;
  // only text and hairlines move to the darker/lighter step. `lightPrimary`
  // (#0891B2) measures 3.68:1 on white and `error` (#EF4444) 3.76:1, both below
  // the 4.5:1 AA floor for small text.
  static const Color lightPrimaryText = Color(0xFF0E7490);
  static const Color lightErrorText = Color(0xFFDC2626);
  static const Color darkErrorText = Color(0xFFF87171);
  static const Color lightSaffronText = Color(0xFF9A3412);

  /// Brand-coloured link/label text that clears AA in both themes.
  static Color linkText(Brightness brightness) =>
      brightness == Brightness.dark ? darkPrimary : lightPrimaryText;
}
