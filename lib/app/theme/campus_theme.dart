import 'package:flutter/material.dart';

/// Defines the common colors and standard Material controls for CampusFix.
abstract final class CampusTheme {
  static const _primary = Color(0xFF02477B);

  static final light = _build(
    ColorScheme.fromSeed(
      seedColor: _primary,
      primary: _primary,
      secondary: const Color(0xFF00C0F3),
      primaryContainer: const Color(0xFFD9F3FC),
      onPrimaryContainer: const Color(0xFF0C344E),
      surface: Colors.white,
      onSurfaceVariant: const Color(0xFF59636B),
    ),
    background: const Color(0xFFF3F7FA),
    divider: const Color(0xFFDEE2E5),
  );

  static final dark = _build(
    ColorScheme.fromSeed(seedColor: _primary, brightness: Brightness.dark),
  );

  static ThemeData _build(
    ColorScheme colors, {
    Color? background,
    Color? divider,
  }) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: colors,
      scaffoldBackgroundColor: background ?? colors.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: colors.surface,
        foregroundColor: colors.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      dividerColor: divider ?? colors.outlineVariant,
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.all(16),
      ),
    );
  }
}
