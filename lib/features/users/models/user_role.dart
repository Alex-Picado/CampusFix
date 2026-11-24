/// Defines the available user roles in CampusFix.
enum UserRole {
  /// Creates incidents and follows their progress.
  reporter,

  /// Handles assigned incidents and records progress.
  technician,

  /// Manages incidents, catalogs, reporters, and technicians.
  administrator,

  /// Also manages administrator accounts.
  superAdministrator;

  bool get isAdministrative =>
      this == administrator || this == superAdministrator;

  /// Whether this account can assign or change the given role.
  bool canManageRole(UserRole role) =>
      isAdministrative &&
      role != superAdministrator &&
      (role != administrator || this == superAdministrator);

  static UserRole? fromName(Object? name) {
    for (final role in values) {
      if (role.name == name) return role;
    }
    return null;
  }
}
