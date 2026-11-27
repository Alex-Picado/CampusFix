import 'package:material_ui/material_ui.dart';

/// Institutional swatches from the UCR accessible palette.
abstract final class CampusPalette {
  static const navy = Color(0xFF0C344E);
  static const blue = Color(0xFF02477B);
  static const cyan = Color(0xFF00C0F3);
  static const sky = Color(0xFF8ED8F8);
  static const paleBlue = Color(0xFFBAD2ED);
  static const white = Color(0xFFFFFFFF);
  static const neutral = Color(0xFFF2F2F2);
  static const muted = Color(0xFF666666);
  static const ink = Color(0xFF232323);
  static const success = Color(0xFF008641);
  static const warning = Color(0xFF7B3400);
  static const danger = Color(0xFF670000);

  static const green = Color(0xFF6DC067);
  static const yellow = Color(0xFFFFE06A);
  static const softRed = Color(0xFFFFB4AB);

  static Color statusNeutral(Brightness brightness) =>
      brightness == Brightness.dark ? paleBlue : muted;

  static Color statusAssigned(Brightness brightness) =>
      brightness == Brightness.dark ? sky : blue;

  static Color statusInProgress(Brightness brightness) =>
      brightness == Brightness.dark ? cyan : navy;

  static Color statusReview(Brightness brightness) =>
      brightness == Brightness.dark ? yellow : warning;

  static Color statusResolved(Brightness brightness) =>
      brightness == Brightness.dark ? green : const Color(0xFF00652F);

  static Color statusCritical(Brightness brightness) =>
      brightness == Brightness.dark ? softRed : danger;
}
