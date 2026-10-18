import 'package:flutter/foundation.dart';

import '../../../core/errors/app_error_messages.dart';
import '../repositories/auth_repository.dart';

/// Manages authentication form actions, loading state, and errors.
///
/// Actions return true on success and false on failure, overlapping calls,
/// or disposal. User-facing errors are available through [errorMessage].
class AuthController extends ChangeNotifier {
  final AuthRepository _authRepository;

  bool _isLoading = false;
  String? _errorMessage;
  bool _disposed = false;

  /// Creates a controller using the provided authentication repository.
  AuthController({required this._authRepository});

  /// Whether an authentication action is currently running.
  bool get isLoading => _isLoading;

  /// The latest user-facing error, or null when no error is available.
  String? get errorMessage => _errorMessage;

  /// Signs in using [email] and [password].
  ///
  /// Removes surrounding email whitespace and preserves the password.
  Future<bool> signIn({required String email, required String password}) {
    return _execute(() {
      return _authRepository.signIn(email: email.trim(), password: password);
    });
  }

  /// Creates an account and its initial reporter profile.
  ///
  /// If profile setup fails, the account may remain signed in.
  /// Its profile can then be completed through [completeProfile].
  Future<bool> register({
    required String fullName,
    required String email,
    required String password,
  }) {
    return _execute(() async {
      await _authRepository.register(
        fullName: fullName,
        email: email,
        password: password,
      );
    });
  }

  /// Completes profile setup for the authenticated user.
  ///
  /// Uses the account identity and reporter role defined by the repository.
  Future<bool> completeProfile({required String fullName}) {
    return _execute(() async {
      await _authRepository.completeProfile(fullName: fullName);
    });
  }

  /// Executes [action] with shared loading and error handling.
  ///
  /// Rejects overlapping calls and calls after disposal.
  /// Converts operation errors into user-facing messages.
  /// Notifies listeners only while the controller remains active.
  Future<bool> _execute(Future<void> Function() action) async {
    if (_disposed || _isLoading) {
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (_disposed) {
        return false;
      }

      await action();
      return !_disposed;
    } catch (error) {
      if (!_disposed) {
        _errorMessage = AppErrorMessages.fromError(error);
      }

      return false;
    } finally {
      if (!_disposed) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Stops notifications and clears local state.
  ///
  /// Repository operations already running may still finish.
  @override
  void dispose() {
    _disposed = true;
    _isLoading = false;
    _errorMessage = null;
    super.dispose();
  }
}
