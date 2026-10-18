/// Defines the available user roles in CampusFix.
enum UserRole {
  /// Creates incidents and follows their progress.
  reporter,

  /// Handles assigned incidents and records progress.
  technician,

  /// Classifies incidents, assigns technicians, and manages users.
  administrator,
}