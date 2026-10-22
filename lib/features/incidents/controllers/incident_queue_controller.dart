import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/errors/app_error_messages.dart';
import '../../auth/controllers/session_controller.dart';
import '../../auth/models/session_status.dart';
import '../../catalogs/repositories/category_repository.dart';
import '../../users/models/user_role.dart';
import '../models/incident.dart';
import '../repositories/incident_repository.dart';
import 'incident_search_controller.dart';

/// Owns a live administrative or personal technician queue for one session.
class IncidentQueueController extends ChangeNotifier {
  final IncidentRepository repository;
  final SessionController session;
  final String uid;
  final UserRole role;
  StreamSubscription<List<Incident>>? _subscription;
  bool _disposed = false;
  bool _invalidated = false;
  int _version = 0;
  List<Incident> incidents = const [];
  bool loading = true;
  String? error;

  /// Local criteria and category names for the current authorized queue.
  late final IncidentSearchController search;

  IncidentQueueController({
    required this.repository,
    required this.session,
    required this.uid,
    required this.role,
    required CategoryRepository categoryRepository,
  }) {
    search = IncidentSearchController(
      categories: categoryRepository,
      session: session,
      uid: uid,
      role: role,
    );
    search.addListener(_searchChanged);
    session.addListener(_sessionChanged);
    start();
  }

  /// Permanently rejects old controllers after account, role or session changes.
  bool get active =>
      !_disposed &&
      !_invalidated &&
      session.status == SessionStatus.authenticated &&
      session.profile?.id == uid &&
      session.profile?.role == role &&
      [UserRole.administrator, UserRole.technician].contains(role);

  /// Restarts after errors or navigation, clearing obsolete private records.
  void start() {
    if (!active) return;
    pause();
    final version = _version;
    loading = true;
    notifyListeners();
    try {
      final stream = role == UserRole.administrator
          ? repository.watchAll()
          : repository.watchAssigned(userId: uid);
      final subscription = stream.listen(
        (rows) {
          if (!active || version != _version) return;
          if (role == UserRole.technician &&
              rows.any((row) => row.assignedTechnicianId != uid)) {
            _fail('No se pudo verificar la información de tus asignaciones.');
            return;
          }
          incidents = List.unmodifiable(rows);
          loading = false;
          error = null;
          search.replaceIncidents(incidents);
          notifyListeners();
        },
        onError: (Object failure) {
          if (active && version == _version) {
            _fail(AppErrorMessages.fromError(failure));
          }
        },
        onDone: () {
          if (active && version == _version) {
            _fail('Se interrumpió la actualización. Intentá nuevamente.');
          }
        },
      );
      if (active && version == _version) {
        _subscription = subscription;
      } else {
        subscription.cancel().ignore();
      }
    } catch (failure) {
      if (active && version == _version) {
        _fail(AppErrorMessages.fromError(failure));
      }
    }
  }

  void _fail(String message) {
    pause();
    error = message;
    notifyListeners();
  }

  /// Releases the queue while a protected detail route is visible.
  void pause() {
    _version++;
    _subscription?.cancel().ignore();
    _subscription = null;
    incidents = const [];
    search.clearIncidents();
    loading = false;
    error = null;
    if (!_disposed) notifyListeners();
  }

  void _sessionChanged() {
    if (active || _disposed) return;
    _invalidated = true;
    pause();
    search.clearIncidents(resetCriteria: true);
  }

  @override
  void dispose() {
    _disposed = true;
    pause();
    search.removeListener(_searchChanged);
    search.dispose();
    session.removeListener(_sessionChanged);
    super.dispose();
  }

  void _searchChanged() {
    if (!_disposed) notifyListeners();
  }
}
