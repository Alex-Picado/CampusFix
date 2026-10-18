import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/errors/app_error_messages.dart';
import '../models/user_profile.dart';
import '../models/user_role.dart';
import '../repositories/user_repository.dart';

/// Manages user observations and administrator role changes.
///
/// The owning administrative screen must dispose this controller when closed.
/// Firestore rules independently authorize queries and writes.
class UserManagementController extends ChangeNotifier {
  final UserRepository _userRepository;
  final String _currentUserId;

  StreamSubscription<List<UserProfile>>? _subscription;
  List<UserProfile> _users = const [];

  bool _isLoading = false;
  bool _isSaving = false;
  bool _disposed = false;
  int _watchVersion = 0;

  String? _loadErrorMessage;
  String? _saveErrorMessage;

  /// Creates the controller and starts observing user profiles.
  UserManagementController({
    required this._userRepository,
    required this._currentUserId,
  }) {
    start();
  }

  /// The latest unmodifiable list of observed profiles.
  List<UserProfile> get users => _users;

  /// Whether the initial or retried query is loading.
  bool get isLoading => _isLoading;

  /// Whether a role change is currently running.
  bool get isSaving => _isSaving;

  /// The latest user-facing query error.
  String? get loadErrorMessage => _loadErrorMessage;

  /// The latest user-facing role change error.
  String? get saveErrorMessage => _saveErrorMessage;

  /// Starts or restarts user observation.
  ///
  /// Clears previously exposed users and query errors.
  /// Preserves role change errors until another update is attempted.
  /// Ignores callbacks from previous subscriptions.
  void start() {
    if (_disposed || _isSaving) {
      return;
    }

    final version = ++_watchVersion;
    _subscription?.cancel().ignore();
    _subscription = null;

    _users = const [];
    _isLoading = true;
    _loadErrorMessage = null;
    notifyListeners();

    if (_disposed || version != _watchVersion) {
      return;
    }

    try {
      final subscription = _userRepository.watchAll().listen(
        (profiles) {
          if (_disposed || version != _watchVersion) {
            return;
          }

          _users = List<UserProfile>.unmodifiable(profiles);
          _isLoading = false;
          _loadErrorMessage = null;
          notifyListeners();
        },
        onError: (Object error) {
          if (_disposed || version != _watchVersion) {
            return;
          }

          _users = const [];
          _isLoading = false;
          _loadErrorMessage = AppErrorMessages.fromError(error);
          notifyListeners();
        },
        cancelOnError: true,
      );

      if (_disposed || version != _watchVersion) {
        subscription.cancel().ignore();
        return;
      }

      _subscription = subscription;
    } catch (error) {
      if (!_disposed && version == _watchVersion) {
        _isLoading = false;
        _loadErrorMessage = AppErrorMessages.fromError(error);
        notifyListeners();
      }
    }
  }

  /// Changes the role of the profile identified by userId.
  ///
  /// Returns false on failure, unavailable data, overlapping calls or disposal.
  /// Prevents accidental removal of the current account's administrator role.
  /// The observed stream supplies the updated list.
  Future<bool> updateRole({
    required String userId,
    required UserRole role,
  }) async {
    if (_disposed ||
        _isLoading ||
        _isSaving ||
        _loadErrorMessage != null) {
      return false;
    }

    if (userId == _currentUserId && role != UserRole.administrator) {
      _saveErrorMessage =
          'Tu cuenta debe conservar el rol de administrador.';
      notifyListeners();
      return false;
    }

    _isSaving = true;
    _saveErrorMessage = null;
    notifyListeners();

    try {
      if (_disposed) {
        return false;
      }

      await _userRepository.updateRole(
        userId: userId,
        role: role,
      );

      return !_disposed;
    } catch (error) {
      if (!_disposed) {
        _saveErrorMessage = AppErrorMessages.fromError(error);
      }

      return false;
    } finally {
      if (!_disposed) {
        _isSaving = false;
        notifyListeners();
      }
    }
  }

  /// Cancels observation and clears private state.
  ///
  /// A repository write already running may still finish.
  @override
  void dispose() {
    _disposed = true;
    _watchVersion++;

    _subscription?.cancel().ignore();
    _subscription = null;

    _users = const [];
    _isLoading = false;
    _isSaving = false;
    _loadErrorMessage = null;
    _saveErrorMessage = null;
    super.dispose();
  }
}