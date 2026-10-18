import 'package:flutter/material.dart';

/// Defines the common colors and standard Material controls for CampusFix.
abstract final class CampusTheme {
  static const primary = Color(0xFF28634F);
  static const background = Color(0xFFF6F7F8);
  static const border = Color(0xFFDEE2E5);
  static const secondaryText = Color(0xFF59636B);

  /// Creates the light theme without external assets or extra dependencies.
  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        surface: Colors.white,
      ),
      scaffoldBackgroundColor: background,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Color(0xFF25302A),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      dividerColor: border,
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.all(16),
      ),
    );
  }
}
