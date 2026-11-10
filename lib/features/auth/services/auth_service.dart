import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Handles authentication operations through Firebase.
class AuthService {
  final FirebaseAuth _auth;

  /// Creates a service using the provided Firebase Auth instance.
  AuthService({required this._auth});

  Future<void> useLocalPersistence() async {
    if (kIsWeb) await _auth.setPersistence(Persistence.LOCAL);
  }

  /// Signs in an existing user with [email] and [password].
  ///
  /// Returns the authentication result, including the signed-in user.
  /// Propagates a [FirebaseAuthException] if authentication fails.
  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  /// Signs out the current user.
  ///
  /// Completes when the sign-out operation finishes.
  /// Propagates errors reported by Firebase.
  Future<void> signOut() {
    return _auth.signOut();
  }

  Future<void> sendPasswordReset({required String email}) =>
      _auth.sendPasswordResetEmail(email: email);

  /// Creates an account using [email] and [password].
  ///
  /// Returns the authentication result and signs in the new user.
  /// Propagates a [FirebaseAuthException] if account creation fails.
  Future<UserCredential> register({
    required String email,
    required String password,
  }) {
    return _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Watches the current user and subsequent authentication changes.
  ///
  /// Emits the current state when subscribed, then sign-in and
  /// sign-out changes. The user is null while signed out.
  /// Forwards errors reported by Firebase to the stream listener.
  Stream<User?> watchAuthState() {
    return _auth.authStateChanges();
  }

  /// Returns the currently authenticated user, or null if unavailable.
  ///
  /// May return null while Firebase is restoring the initial session.
  User? getCurrentUser() {
    return _auth.currentUser;
  }
}
