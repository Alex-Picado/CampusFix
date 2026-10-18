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

  /// Returns the profile fields to store in Firestore.
  ///
  /// The identifier is used as the document ID and is not included.
  Map<String, dynamic> toMap() {
    return {'fullName': fullName, 'email': email, 'role': role.name};
  }

  /// Creates a profile from a Firestore document ID and its fields.
  ///
  /// Throws a [FormatException] if required fields have invalid types
  /// or the role is unsupported.
  factory UserProfile.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    final fullName = data['fullName'];
    final email = data['email'];
    final roleName = data['role'];

    if (fullName is! String || email is! String || roleName is! String) {
      throw const FormatException('Invalid user profile data.');
    }

    final UserRole role;

    if (roleName == 'reporter') {
      role = UserRole.reporter;
    } else if (roleName == 'technician') {
      role = UserRole.technician;
    } else if (roleName == 'administrator') {
      role = UserRole.administrator;
    } else {
      throw const FormatException('Unsupported user role.');
    }

    return UserProfile(id: id, fullName: fullName, email: email, role: role);
  }
}
