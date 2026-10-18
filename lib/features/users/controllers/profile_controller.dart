import 'package:flutter/foundation.dart';

import '../../../core/errors/app_error_messages.dart';
import '../repositories/user_repository.dart';

/// Manages name updates for one authenticated account.
///
/// Stores form action state. SessionController observes profile changes.
/// The owner must dispose this controller when its account scope ends.
class ProfileController extends ChangeNotifier {
  final UserRepository _userRepository;
  final String _userId;

  bool _isSaving = false;
  String? _errorMessage;
  bool _disposed = false;

  /// Creates a controller bound to the authenticated account's [userId].
  ProfileController({
    required this._userRepository,
    required this._userId,
  });

  /// Whether a name update is currently running.
  bool get isSaving => _isSaving;

  /// The latest user-facing error, or null when unavailable.
  String? get errorMessage => _errorMessage;

  /// Updates the current account's name through the repository.
  ///
  /// Returns true on success.
  /// Returns false on failure, overlapping calls, or disposal.
  Future<bool> updateFullName(String fullName) async {
    if (_disposed || _isSaving) {
      return false;
    }

    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (_disposed) {
        return false;
      }

      await _userRepository.updateFullName(
        userId: _userId,
        fullName: fullName,
      );

      return !_disposed;
    } catch (error) {
      if (!_disposed) {
        _errorMessage = AppErrorMessages.fromError(error);
      }

      return false;
    } finally {
      if (!_disposed) {
        _isSaving = false;
        notifyListeners();
      }
    }
  }

  /// Stops notifications and clears local form state.
  ///
  /// A repository operation already running may still finish.
  @override
  void dispose() {
    _disposed = true;
    _isSaving = false;
    _errorMessage = null;
    super.dispose();
  }
}