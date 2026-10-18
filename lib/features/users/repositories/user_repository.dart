import '../models/user_profile.dart';
import '../services/user_service.dart';
import '../models/user_role.dart';
/// Converts stored user data into application profiles and back.
class UserRepository {
  final UserService _userService;

  /// Creates a repository using the provided user service.
  UserRepository({required this._userService});

  /// Retrieves the profile identified by [userId].
  ///
  /// Returns null if the profile does not exist.
  /// Throws a [FormatException] if stored profile data is invalid.
  /// Propagates errors reported by the service.
  Future<UserProfile?> getById(String userId) async {
    final data = await _userService.getById(userId);

    if (data == null) {
      return null;
    }

    return UserProfile.fromMap(id: userId, data: data);
  }

  /// Watches the profile identified by [userId].
  ///
  /// Emits the initial profile and subsequent changes.
  /// Emits null if the profile does not exist.
  /// Forwards service and parsing errors to the stream listener.
  /// The caller must cancel its subscription when no longer needed.
  Stream<UserProfile?> watchById(String userId) {
    return _userService.watchById(userId).map<UserProfile?>((data) {
      if (data == null) {
        return null;
      }

      return UserProfile.fromMap(id: userId, data: data);
    });
  }

  /// Creates or replaces the complete document for [profile].
  ///
  /// Stores all profile fields, including the supplied role.
  /// Firestore security rules enforce write permissions.
  /// Propagates errors reported by the service.
  Future<void> saveProfile(UserProfile profile) {
    return _userService.setProfile(userId: profile.id, data: profile.toMap());
  }


  /// Updates the name of the profile identified by [userId].
  ///
  /// Removes surrounding name whitespace.
  /// Throws a [FormatException] if the identifier or name is empty.
  /// Propagates errors reported by the service.
  Future<void> updateFullName({
    required String userId,
    required String fullName,
  }) {
    final normalizedName = fullName.trim();

    if (userId.trim().isEmpty || normalizedName.isEmpty) {
      throw const FormatException('User ID and full name are required.');
    }

    return _userService.updateFullName(
      userId: userId,
      fullName: normalizedName,
    );
  }



  /// Watches all profiles sorted by their case-insensitive full name.
  ///
  /// Converts stored documents into application models.
  /// Emits an unmodifiable list.
  /// Forwards service and profile parsing errors to the listener.
  /// The caller must cancel its subscription when no longer needed.
  Stream<List<UserProfile>> watchAll() {
    return _userService.watchAll().map((documents) {
      final profiles = <UserProfile>[];

      for (final entry in documents.entries) {
        profiles.add(
          UserProfile.fromMap(
            id: entry.key,
            data: entry.value,
          ),
        );
      }

      profiles.sort((first, second) {
        return first.fullName.toLowerCase().compareTo(
          second.fullName.toLowerCase(),
        );
      });

      return List<UserProfile>.unmodifiable(profiles);
    });
  }

  /// Updates the role of the profile identified by [userId].
  ///
  /// Stores the enum name used by the profile model and security rules.
  /// Throws a [FormatException] if the identifier is empty.
  /// Propagates errors reported by the service.
  Future<void> updateRole({
    required String userId,
    required UserRole role,
  }) {
    if (userId.trim().isEmpty) {
      throw const FormatException('User ID is required.');
    }

    return _userService.updateRole(
      userId: userId,
      role: role.name,
    );
  }



}
