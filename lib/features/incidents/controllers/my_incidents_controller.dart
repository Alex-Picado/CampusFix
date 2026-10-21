import 'dart:async';

import 'package:flutter/foundation.dart' show ChangeNotifier;

import '../../../core/errors/app_error_messages.dart';
import '../../auth/controllers/session_controller.dart';
import '../../auth/models/session_status.dart';
import '../../users/models/user_role.dart';
import '../models/incident.dart';
import '../repositories/incident_repository.dart';

/// Observes one reporter's incidents for the lifetime of the owning list view.
class MyIncidentsController extends ChangeNotifier {
  final IncidentRepository _incidentRepository;
  final SessionController _sessionController;
  final String _userId;
  StreamSubscription<List<Incident>>? _subscription;
  List<Incident> _incidents = const [];
  String? _errorMessage;
  bool _isLoading = false;
  bool _isActive = false;
  bool _disposed = false;
  int _watchVersion = 0;

  /// Binds observation to the original authenticated reporter session.
  MyIncidentsController({
    required this._incidentRepository,
    required this._sessionController,
    required this._userId,
  }) {
    _isActive = _matchesSession();
    if (_isActive) {
      _sessionController.addListener(_handleSession);
      start();
    }
  }

  /// Unmodifiable confirmed reports, in repository presentation order.
  List<Incident> get incidents => _incidents;

  /// Whether the first confirmed query result is still pending.
  bool get isLoading => _isLoading;

  /// Spanish observation feedback; failed queries never become empty successes.
  String? get errorMessage => _errorMessage;

  /// Whether the original reporter session can still use this instance.
  bool get isActive => _isActive && !_disposed;

  /// Releases the list while a protected detail route covers its view.
  void pause() {
    _watchVersion++;
    _subscription?.cancel().ignore();
    _subscription = null;
    _incidents = const [];
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }

  /// Retries observation after clearing previously displayed private records.
  void start() {
    if (!isActive || !_matchesSession()) return;
    final version = ++_watchVersion;
    _subscription?.cancel().ignore();
    _subscription = null;
    _incidents = const [];
    _errorMessage = null;
    _isLoading = true;
    notifyListeners();
    if (!_isCurrent(version)) return;
    try {
      final subscription = _incidentRepository
          .watchOwn(userId: _userId)
          .listen(
            (incidents) {
              if (!_isCurrent(version)) return;
              if (incidents.any(
                (incident) => incident.createdByUserId != _userId,
              )) {
                _fail(
                  'No se pudo verificar la información de tus incidencias.',
                );
                return;
              }
              _incidents = List.unmodifiable(incidents);
              _isLoading = false;
              _errorMessage = null;
              notifyListeners();
            },
            onError: (Object error) {
              if (_isCurrent(version)) _fail(AppErrorMessages.fromError(error));
            },
            onDone: () {
              if (_isCurrent(version)) {
                _fail(
                  'No se pudo mantener la lista de incidencias. Intentá nuevamente.',
                );
              }
            },
            cancelOnError: true,
          );
      if (_isCurrent(version)) {
        _subscription = subscription;
      } else {
        subscription.cancel().ignore();
      }
    } catch (error) {
      if (_isCurrent(version)) _fail(AppErrorMessages.fromError(error));
    }
  }

  /// Stops the failed observation without retaining records from it.
  void _fail(String message) {
    _watchVersion++;
    _subscription?.cancel().ignore();
    _subscription = null;
    _incidents = const [];
    _isLoading = false;
    _errorMessage = message;
    notifyListeners();
  }

  /// Requires the original UID and an available reporter profile.
  bool _matchesSession() =>
      _sessionController.status == SessionStatus.authenticated &&
      _sessionController.profile?.id == _userId &&
      _sessionController.profile?.role == UserRole.reporter;

  /// Rejects queued callbacks from earlier queries or an obsolete session.
  bool _isCurrent(int version) =>
      isActive && version == _watchVersion && _matchesSession();

  /// Permanently clears the scope on account, role or session availability changes.
  void _handleSession() {
    if (!isActive || _matchesSession()) return;
    _clear();
    notifyListeners();
  }

  /// Cancels the query and removes all account-specific state and listeners.
  void _clear() {
    _isActive = false;
    _watchVersion++;
    _sessionController.removeListener(_handleSession);
    _subscription?.cancel().ignore();
    _subscription = null;
    _incidents = const [];
    _isLoading = false;
    _errorMessage = null;
  }

  /// Cancels observation and discards all account-specific state.
  @override
  void dispose() {
    _disposed = true;
    _clear();
    super.dispose();
  }
}
