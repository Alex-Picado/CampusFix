import '../models/user_role.dart';

/// Keeps Spanish display labels separate from stored role identifiers.
extension UserRoleLabels on UserRole {
  String get label {
    switch (this) {
      case UserRole.reporter:
        return 'Reportante';
      case UserRole.technician:
        return 'Técnico';
      case UserRole.administrator:
        return 'Administrador';
    }
  }
}
