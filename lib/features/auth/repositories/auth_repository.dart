import '../../users/models/user_profile.dart';
import '../../users/models/user_role.dart';
import '../../users/repositories/user_repository.dart';
import '../services/auth_service.dart';
import '../services/session_retention.dart';
import '../services/session_retention_ports.dart';

/// Exposes authentication operations to the application.
class AuthRepository {
  final AuthService _authService;
  final UserRepository _userRepository;
  final SessionRetention? _sessionRetention;
  final SessionPageLifecycle? _pageLifecycle;
  Future<void>? _expirationSignOut;

  /// Creates a repository using authentication and profile dependencies.
  AuthRepository({
    required this._authService,
    required this._userRepository,
    this._sessionRetention,
    this._pageLifecycle,
  });

  /// Signs in an existing user with [email] and [password].
  ///
  /// Completes when authentication succeeds.
  /// Propagates errors reported by the authentication service.
  Future<void> signIn({
    required String email,
    required String password,
    bool rememberMe = false,
  }) async {
    await _expirationSignOut;
    if (_sessionRetention != null) {
      await _authService.useLocalPersistence();
      _sessionRetention.prepareLogin(email, rememberMe);
    }
    try {
      final result = await _authService.signIn(
        email: email,
        password: password,
      );
      final user = result.user;
      if (user != null &&
          _sessionRetention != null &&
          !_sessionRetention.accept(user.uid, user.email)) {
        await _authService.signOut();
        throw StateError('The sign-in session could not be retained.');
      }
    } catch (_) {
      _sessionRetention?.cancelLogin();
      rethrow;
    }
  }

  /// Signs out the current user.
  ///
  /// Completes when the sign-out operation finishes.
  /// Propagates errors reported by the authentication service.
  Future<void> signOut() async {
    final uid = _authService.getCurrentUser()?.uid;
    await _authService.signOut();
    _sessionRetention?.end(uid);
    _pageLifecycle?.stop();
  }

  Future<void> sendPasswordReset({required String email}) =>
      _authService.sendPasswordReset(email: email.trim());

  /// Watches the current user ID and subsequent session changes.
  ///
  /// Emits null when no user is signed in.
  /// Forwards authentication errors to the stream listener.
  /// The caller must cancel its subscription when no longer needed.
  Stream<String?> watchUserId() {
    return Stream<String?>.multi((sink) {
      var cancelled = false;
      void receive() {
        if (cancelled) return;
        final user = _authService.getCurrentUser();
        if (user == null) {
          _sessionRetention?.release();
          _pageLifecycle?.stop();
          sink.add(null);
          return;
        }
        try {
          if (_sessionRetention != null &&
              !_sessionRetention.accept(user.uid, user.email)) {
            _pageLifecycle?.stop();
            sink.add(null);
            _expirationSignOut ??= _authService.signOut().whenComplete(
              () => _expirationSignOut = null,
            );
            _expirationSignOut!.then(
              (_) => _sessionRetention.end(user.uid),
              onError: (Object error) {
                if (!cancelled) sink.addError(error);
              },
            );
            return;
          }
          if (_sessionRetention != null) {
            _pageLifecycle?.start(
              _sessionRetention.touch,
              _sessionRetention.suspend,
            );
          }
          sink.add(user.uid);
        } catch (error) {
          sink.addError(error);
        }
      }

      final auth = _authService.watchAuthState().listen(
        (_) => receive(),
        onError: sink.addError,
        onDone: sink.close,
      );
      final reopen = _pageLifecycle?.reopens.listen((_) => receive());
      sink.onCancel = () async {
        cancelled = true;
        _pageLifecycle?.stop();
        await auth.cancel();
        await reopen?.cancel();
      };
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
    bool rememberMe = false,
  }) async {
    final normalizedName = fullName.trim();
    final normalizedEmail = email.trim();

    if (normalizedName.isEmpty || normalizedEmail.isEmpty || password.isEmpty) {
      throw const FormatException('All registration fields are required.');
    }

    await _expirationSignOut;
    if (_authService.getCurrentUser() != null) {
      throw StateError('Sign out before creating another account.');
    }

    if (_sessionRetention != null) {
      await _authService.useLocalPersistence();
      _sessionRetention.prepareLogin(normalizedEmail, rememberMe);
    }
    try {
      final result = await _authService.register(
        email: normalizedEmail,
        password: password,
      );
      final user = result.user;
      if (user != null && _sessionRetention != null) {
        if (!_sessionRetention.accept(user.uid, user.email)) {
          await _authService.signOut();
          throw StateError('The sign-up session could not be retained.');
        }
      }
    } catch (_) {
      _sessionRetention?.cancelLogin();
      rethrow;
    }

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
