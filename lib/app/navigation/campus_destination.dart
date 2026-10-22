import 'package:flutter/material.dart';

import '../../features/users/models/user_role.dart';

/// Presentation metadata and menu visibility for the application's modules.
///
/// Visibility guides the interface. Firestore rules must independently authorize
/// each data operation when the corresponding module is implemented.
enum CampusDestination {
  overview(
    'Inicio',
    Icons.home_outlined,
    'Gestión de incidencias del campus.',
    [],
  ),
  incidents(
    'Mis incidencias',
    Icons.description_outlined,
    'Reportá problemas y consultá el seguimiento de tus reportes.',
    [
      'Crear incidencias con categoría, ubicación y descripción.',
      'Adjuntar fotografías como evidencia.',
      'Consultar el detalle y el historial de tus incidencias.',
    ],
  ),
  management(
    'Gestión',
    Icons.assignment_outlined,
    'Organizá la atención de las incidencias.',
    [
      'Clasificar reportes y establecer su prioridad.',
      'Asignar técnicos y supervisar el seguimiento.',
      'Revisar resoluciones y cerrar incidencias.',
    ],
  ),
  workspace(
    'Mi trabajo',
    Icons.handyman_outlined,
    'Consultá las incidencias que tenés asignadas.',
    [
      'Consultar asignaciones e iniciar la atención.',
      'Documentar la solución de cada incidencia.',
    ],
  ),
  dashboard(
    'Indicadores',
    Icons.bar_chart_outlined,
    'Consultá los resultados de la atención del campus.',
    [
      'Consultar totales por estado y categoría.',
      'Ver indicadores globales actualizados en vivo.',
      'Incluir categorías inactivas en los resultados históricos.',
    ],
  ),
  categories(
    'Categorías',
    Icons.category_outlined,
    'Organizá los tipos de incidencias disponibles.',
    [
      'Consultar y crear categorías.',
      'Actualizar nombres de categorías.',
      'Activar o desactivar categorías.',
    ],
  ),
  users(
    'Usuarios',
    Icons.manage_accounts_outlined,
    'Administrá los roles de las personas registradas.',
    [
      'Consultar perfiles registrados.',
      'Asignar roles de reportante, técnico y administrador.',
    ],
  ),
  profile(
    'Mi perfil',
    Icons.person_outline,
    'Consultá tu información y actualizá tu nombre.',
    [
      'Consultar nombre, correo electrónico y rol.',
      'Actualizar tu nombre completo.',
      'Acceder a las opciones de tu cuenta.',
    ],
  );

  final String label;
  final IconData icon;
  final String description;
  final List<String> capabilities;

  const CampusDestination(
    this.label,
    this.icon,
    this.description,
    this.capabilities,
  );

  /// Whether this menu entry is relevant to [role].
  bool isVisibleTo(UserRole role) {
    switch (this) {
      case CampusDestination.overview:
      case CampusDestination.profile:
        return true;
      case CampusDestination.incidents:
        return role == UserRole.reporter;
      case CampusDestination.workspace:
        return role == UserRole.technician;
      case CampusDestination.management:
      case CampusDestination.dashboard:
      case CampusDestination.categories:
      case CampusDestination.users:
        return role == UserRole.administrator;
    }
  }

  /// Returns the visible destinations in their normal display order.
  static List<CampusDestination> forRole(UserRole role) {
    return values
        .where((item) => item.isVisibleTo(role))
        .toList(growable: false);
  }
}
