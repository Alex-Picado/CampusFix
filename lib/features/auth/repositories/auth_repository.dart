import '../services/auth_service.dart';

/// Exposes authentication operations to the application.
class AuthRepository {
  final AuthService _authService;

  /// Creates a repository using the provided authentication service.
  AuthRepository({required this._authService});

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
}
