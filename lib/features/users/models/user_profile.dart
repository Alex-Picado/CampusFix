import 'user_role.dart';

/// Represents a CampusFix user's profile.
class UserProfile {
  /// Unique identifier associated with the Firebase Auth account.
  final String id;

  /// User's full name displayed in the application.
  final String fullName;

  /// Email address associated with the account.
  final String email;

  /// Role used to determine the user's permitted operations.
  final UserRole role;

  /// Creates a user profile with all required information.
  const UserProfile({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
  });
}