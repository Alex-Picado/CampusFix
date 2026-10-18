import '../../users/models/user_profile.dart';
import '../../users/models/user_role.dart';
import '../../users/repositories/user_repository.dart';
import '../services/auth_service.dart';

/// Exposes authentication operations to the application.
class AuthRepository {
  final AuthService _authService;
  final UserRepository _userRepository;

  /// Creates a repository using authentication and profile dependencies.
  AuthRepository({required this._authService, required this._userRepository});

  /// Signs in an existing user with [email] and [password].
  ///
  /// Completes when authentication succeeds.
  /// Propagates errors reported by the authentication service.
  Future<void> signIn({required String email, required String password}) async {
    await _authService.signIn(email: email, password: password);
  }

  /// Signs out the current user.
  ///
  /// Completes when the sign-out operation finishes.
  /// Propagates errors reported by the authentication service.
  Future<void> signOut() {
    return _authService.signOut();
  }

  /// Watches the current user ID and subsequent session changes.
  ///
  /// Emits null when no user is signed in.
  /// Forwards authentication errors to the stream listener.
  /// The caller must cancel its subscription when no longer needed.
  Stream<String?> watchUserId() {
    return _authService.watchAuthState().map<String?>((user) {
      if (user == null) {
        return null;
      }

      return user.uid;
    });
  }

  /// Creates an account and initializes its reporter profile.
  ///
  /// Trims the name and email while preserving the password unchanged.
  /// Throws a [FormatException] if required fields are empty.
  /// Throws a [StateError] if a user is already signed in.
  /// Propagates authentication and profile errors.
  ///
  /// If profile setup fails after account creation, the account remains
  /// signed in. Retry through [completeProfile] instead of registering again.
  Future<UserProfile> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final normalizedName = fullName.trim();
    final normalizedEmail = email.trim();

    if (normalizedName.isEmpty || normalizedEmail.isEmpty || password.isEmpty) {
      throw const FormatException('All registration fields are required.');
    }

    if (_authService.getCurrentUser() != null) {
      throw StateError('Sign out before creating another account.');
    }

    await _authService.register(email: normalizedEmail, password: password);

    return completeProfile(fullName: normalizedName);
  }

  /// Completes profile setup for the currently authenticated user.
  ///
  /// Uses the account UID and email, and assigns the reporter role.
  /// Returns an existing profile without rewriting it.
  /// Throws a [FormatException] if [fullName] is empty.
  /// Throws a [StateError] if no authenticated account with email exists.
  /// Propagates profile lookup, parsing, and persistence errors.
  Future<UserProfile> completeProfile({required String fullName}) async {
    final normalizedName = fullName.trim();

    if (normalizedName.isEmpty) {
      throw const FormatException('Full name is required.');
    }

    final user = _authService.getCurrentUser();

    if (user == null) {
      throw StateError('An authenticated user is required.');
    }

    final email = user.email;

    if (email == null || email.isEmpty) {
      throw StateError('The authenticated account must have an email.');
    }

    final existingProfile = await _userRepository.getById(user.uid);

    if (existingProfile != null) {
      return existingProfile;
    }

    final profile = UserProfile(
      id: user.uid,
      fullName: normalizedName,
      email: email,
      role: UserRole.reporter,
    );

    await _userRepository.saveProfile(profile);

    return profile;
  }
}
