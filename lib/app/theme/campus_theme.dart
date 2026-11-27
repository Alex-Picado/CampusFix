import 'package:material_ui/material_ui.dart';

import 'campus_palette.dart';

/// Defines CampusFix's shared institutional themes.
abstract final class CampusTheme {
  static final light = _build(
    ColorScheme.fromSeed(
      seedColor: CampusPalette.blue,
      primary: CampusPalette.blue,
      onPrimary: CampusPalette.white,
      primaryContainer: const Color(0xFFD8F4FD),
      onPrimaryContainer: CampusPalette.navy,
      secondary: CampusPalette.navy,
      onSecondary: CampusPalette.white,
      secondaryContainer: CampusPalette.sky,
      onSecondaryContainer: CampusPalette.navy,
      tertiary: CampusPalette.warning,
      onTertiary: CampusPalette.white,
      error: CampusPalette.danger,
      onError: CampusPalette.white,
      errorContainer: const Color(0xFFFFDAD6),
      onErrorContainer: CampusPalette.danger,
      surface: CampusPalette.white,
      surfaceContainerLowest: CampusPalette.white,
      surfaceContainerLow: const Color(0xFFFAFAFA),
      surfaceContainer: CampusPalette.neutral,
      surfaceContainerHigh: const Color(0xFFEAEAEA),
      surfaceContainerHighest: const Color(0xFFE4E4E4),
      onSurface: CampusPalette.ink,
      onSurfaceVariant: CampusPalette.muted,
      outline: CampusPalette.muted,
      outlineVariant: const Color(0xFFD5D5D5),
      inverseSurface: CampusPalette.ink,
      onInverseSurface: CampusPalette.white,
    ),
    background: CampusPalette.neutral,
  );

  static final dark = _build(
    ColorScheme.fromSeed(
      seedColor: CampusPalette.blue,
      brightness: Brightness.dark,
      primary: CampusPalette.sky,
      onPrimary: CampusPalette.navy,
      primaryContainer: CampusPalette.blue,
      onPrimaryContainer: CampusPalette.white,
      secondary: CampusPalette.cyan,
      onSecondary: CampusPalette.navy,
      secondaryContainer: CampusPalette.navy,
      onSecondaryContainer: CampusPalette.sky,
      tertiary: CampusPalette.yellow,
      onTertiary: CampusPalette.ink,
      error: CampusPalette.softRed,
      onError: CampusPalette.danger,
      errorContainer: CampusPalette.danger,
      onErrorContainer: const Color(0xFFFFDAD6),
      surface: const Color(0xFF11191E),
      surfaceContainerLowest: const Color(0xFF0C1216),
      surfaceContainerLow: const Color(0xFF19252D),
      surfaceContainer: const Color(0xFF1D2C35),
      surfaceContainerHigh: const Color(0xFF233743),
      surfaceContainerHighest: const Color(0xFF2C4351),
      onSurface: CampusPalette.neutral,
      onSurfaceVariant: const Color(0xFFBCC8CE),
      outline: const Color(0xFF8698A3),
      outlineVariant: const Color(0xFF425965),
      inverseSurface: CampusPalette.neutral,
      onInverseSurface: CampusPalette.ink,
    ),
    background: const Color(0xFF11191E),
  );

  static ThemeData _build(ColorScheme colors, {required Color background}) {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Trueno',
      colorScheme: colors,
      scaffoldBackgroundColor: background,
      dividerColor: colors.outlineVariant,
      appBarTheme: const AppBarTheme(
        backgroundColor: CampusPalette.navy,
        foregroundColor: CampusPalette.white,
        iconTheme: IconThemeData(color: CampusPalette.white),
        actionsIconTheme: IconThemeData(color: CampusPalette.white),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: Border(bottom: BorderSide(color: CampusPalette.cyan, width: 2)),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        border: const OutlineInputBorder(),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: colors.outline),
        ),
        contentPadding: const EdgeInsets.all(16),
      ),
    );
  }
}
