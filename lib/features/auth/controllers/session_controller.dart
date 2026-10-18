import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/errors/app_error_messages.dart';
import '../../users/models/user_profile.dart';
import '../../users/repositories/user_repository.dart';
import '../models/session_status.dart';
import '../repositories/auth_repository.dart';

/// Observes authentication and the current user's profile.
///
/// Clears profile data when the account changes or observation fails.
/// Keeps authenticated accounts with missing profiles in a recoverable state.
class SessionController extends ChangeNotifier {
  final AuthRepository _authRepository;
  final UserRepository _userRepository;

  StreamSubscription<String?>? _authSubscription;
  StreamSubscription<UserProfile?>? _profileSubscription;

  SessionStatus _status = SessionStatus.loading;
  UserProfile? _profile;
  String? _errorMessage;
  bool _disposed = false;

  // Invalidates callbacks from previous profile subscriptions.
  int _profileVersion = 0;

  /// Creates the controller and starts observing the session.
  SessionController({
    required this._authRepository,
    required this._userRepository,
  }) {
    start();
  }

  /// The current session state.
  SessionStatus get status => _status;

  /// The current profile, or null while unavailable.
  UserProfile? get profile => _profile;

  /// The latest user-facing observation error.
  String? get errorMessage => _errorMessage;

  /// Starts or restarts session observation.
  ///
  /// Clears previously exposed profile data.
  /// May be called to retry after an observation failure.
  void start() {
    if (_disposed) {
      return;
    }

    _authSubscription?.cancel().ignore();
    _authSubscription = null;

    _handleUserChanged(null, initializing: true);

    if (_disposed) {
      return;
    }

    try {
      _authSubscription = _authRepository.watchUserId().listen(
        _handleUserChanged,
        onError: (Object error) {
          _handleUserChanged(null, error: error);
        },
      );
    } catch (error) {
      _handleUserChanged(null, error: error);
    }
  }

  /// Processes account changes and observes the matching profile.
  ///
  /// Cancels the previous profile subscription and clears its data.
  /// Converts observation errors into a recoverable failure state.
  /// Ignores callbacks belonging to an earlier session.
  void _handleUserChanged(
    String? userId, {
    bool initializing = false,
    Object? error,
  }) {
    if (_disposed) {
      return;
    }

    final version = ++_profileVersion;

    _profileSubscription?.cancel().ignore();
    _profileSubscription = null;
    _profile = null;
    _errorMessage = null;

    if (error != null) {
      _status = SessionStatus.failure;
      _errorMessage = AppErrorMessages.fromError(error);
    } else if (initializing || userId != null) {
      _status = SessionStatus.loading;
    } else {
      _status = SessionStatus.signedOut;
    }

    notifyListeners();

    if (_disposed ||
        version != _profileVersion ||
        userId == null ||
        error != null) {
      return;
    }

    try {
      final subscription = _userRepository
          .watchById(userId)
          .listen(
            (profile) {
              if (_disposed || version != _profileVersion) {
                return;
              }

              _profile = profile;
              _errorMessage = null;

              if (profile == null) {
                _status = SessionStatus.profileRequired;
              } else {
                _status = SessionStatus.authenticated;
              }

              notifyListeners();
            },
            onError: (Object error) {
              if (_disposed || version != _profileVersion) {
                return;
              }

              _handleUserChanged(userId, error: error);
            },
          );

      if (_disposed || version != _profileVersion) {
        subscription.cancel().ignore();
        return;
      }

      _profileSubscription = subscription;
    } catch (error) {
      if (!_disposed && version == _profileVersion) {
        _handleUserChanged(userId, error: error);
      }
    }
  }

  /// Cancels subscriptions and clears private session data.
  ///
  /// Asynchronous subscription cleanup errors are ignored.
  @override
  void dispose() {
    _disposed = true;
    _profileVersion++;

    _authSubscription?.cancel().ignore();
    _profileSubscription?.cancel().ignore();

    _authSubscription = null;
    _profileSubscription = null;
    _profile = null;
    _errorMessage = null;

    super.dispose();
  }
}
