import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF1976D2),
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      canvasColor: Colors.white,
      dividerColor: const Color(0xFFE5E7EB),
      dialogBackgroundColor: Colors.white,
      cardColor: Colors.white,
    );
  }

  static ThemeData dark() {
    const surface = Color(0xFF1E293B);
    const background = Color(0xFF0F172A);
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF3B82F6),
        onPrimary: Colors.white,
        secondary: Color(0xFF6366F1),
        onSecondary: Colors.white,
        surface: surface,
        onSurface: Color(0xFFE5E7EB),
        error: Color(0xFFEF4444),
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: background,
      canvasColor: surface,
      dividerColor: const Color(0xFF334155),
      dialogBackgroundColor: surface,
      cardColor: surface,
    );
  }
}

/// Theme-aware color helpers. Each method returns the light or dark variant
/// based on the current Theme's brightness.
class AppColors {
  static bool _dark(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark;

  /// Page background (under scaffolds / large areas).
  static Color background(BuildContext c) =>
      _dark(c) ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);

  /// Card / surface background (tiles, dialogs, input fields).
  static Color surface(BuildContext c) =>
      _dark(c) ? const Color(0xFF1E293B) : Colors.white;

  /// Slightly elevated surface (e.g. hover / selected state).
  static Color surfaceAlt(BuildContext c) =>
      _dark(c) ? const Color(0xFF273449) : const Color(0xFFF3F4F6);

  /// Primary text.
  static Color textPrimary(BuildContext c) =>
      _dark(c) ? const Color(0xFFF1F5F9) : const Color(0xFF111418);

  /// Secondary text (labels, sub-titles).
  static Color textSecondary(BuildContext c) =>
      _dark(c) ? const Color(0xFFCBD5E1) : const Color(0xFF374151);

  /// Muted / tertiary text (timestamps, helper text).
  static Color textMuted(BuildContext c) =>
      _dark(c) ? const Color(0xFF94A3B8) : const Color(0xFF9CA3AF);

  /// Border / outline color.
  static Color border(BuildContext c) =>
      _dark(c) ? const Color(0xFF334155) : const Color(0xFFE5E7EB);

  /// Subtle tint for chip / pill backgrounds.
  static Color tint(BuildContext c) =>
      _dark(c) ? const Color(0xFF1E3A5F) : const Color(0xFFEFF6FF);

  /// Blue accent (icons + text on `tint` backgrounds). Lightens in dark mode
  /// so it remains readable on the dark-navy tint.
  static Color accent(BuildContext c) =>
      _dark(c) ? const Color(0xFF93C5FD) : const Color(0xFF2563EB);

  /// Shadow colour (use with reduced opacity). Dark mode uses pure black.
  static Color shadow(BuildContext c) =>
      _dark(c) ? Colors.black : Colors.black;
}
