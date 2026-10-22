import 'dart:async';

import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:firebase_core/firebase_core.dart';

import '../../../core/errors/app_error_messages.dart';
import '../../auth/controllers/session_controller.dart';
import '../../auth/models/session_status.dart';
import '../../catalogs/models/category.dart';
import '../../catalogs/repositories/category_repository.dart';
import '../../users/models/user_profile.dart';
import '../../users/models/user_role.dart';
import '../../users/repositories/user_repository.dart';
import '../models/incident.dart';
import '../models/incident_history_action.dart';
import '../models/incident_priority.dart';
import '../models/incident_workflow.dart';
import '../repositories/incident_repository.dart';

/// Owns workflow permissions, selection sources and one recoverable submission.
class IncidentWorkflowController extends ChangeNotifier {
  final IncidentRepository repository;
  final CategoryRepository categoryRepository;
  final UserRepository userRepository;
  final SessionController session;
  final String uid;
  final UserRole role;
  final String incidentId;
  final _subscriptions = <StreamSubscription<dynamic>>[];
  int _version = 0;
  bool _disposed = false;
  bool _invalidated = false;
  Incident? incident;
  List<Category> categories = const [];
  List<UserProfile> technicians = const [];
  final loadingSources = <String>{};
  String? readError;
  String? saveError;
  String? success;
  bool saving = false;
  IncidentWorkflowCommand? pending;

  IncidentWorkflowController({
    required this.repository,
    required this.categoryRepository,
    required this.userRepository,
    required this.session,
    required this.uid,
    required this.role,
    required this.incidentId,
  }) {
    session.addListener(_sessionChanged);
    start();
  }

  bool get active =>
      !_disposed &&
      !_invalidated &&
      session.status == SessionStatus.authenticated &&
      session.profile?.id == uid &&
      session.profile?.role == role;
  List<IncidentHistoryAction> get actions =>
      active && incident != null && readError == null
      ? IncidentWorkflow.actions(incident!, role, uid)
      : const [];
  bool get ready =>
      active && readError == null && loadingSources.isEmpty && incident != null;

  /// Retries all read sources without erasing a pending write or its feedback.
  void start() {
    if (!active) return;
    _stop();
    final version = _version;
    incident = null;
    categories = const [];
    technicians = const [];
    readError = null;
    loadingSources.addAll([
      'incident',
      if (role == UserRole.administrator) ...['categories', 'technicians'],
    ]);
    notifyListeners();
    _watch(
      'incident',
      () => repository.watchById(incidentId: incidentId),
      version,
      (Incident? value) {
        if (value == null) throw StateError('Missing incident.');
        incident = value;
      },
    );
    if (role == UserRole.administrator) {
      _watch(
        'categories',
        categoryRepository.watchActive,
        version,
        (List<Category> rows) => categories = rows,
      );
      _watch('technicians', userRepository.watchAll, version, (
        List<UserProfile> rows,
      ) {
        technicians = List.unmodifiable(
          rows.where((row) => row.role == UserRole.technician),
        );
      });
    }
  }

  void _watch<T>(
    String name,
    Stream<T> Function() source,
    int version,
    void Function(T) receive,
  ) {
    if (!active || version != _version) return;
    try {
      final subscription = source().listen(
        (value) {
          if (!active || version != _version) return;
          try {
            receive(value);
            loadingSources.remove(name);
            notifyListeners();
          } catch (failure) {
            _fail(failure);
          }
        },
        onError: (Object failure) {
          if (active && version == _version) _fail(failure);
        },
        onDone: () {
          if (active && version == _version) {
            _fail(StateError('Observation ended.'));
          }
        },
      );
      if (active && version == _version) {
        _subscriptions.add(subscription);
      } else {
        subscription.cancel().ignore();
      }
    } catch (failure) {
      if (active && version == _version) _fail(failure);
    }
  }

  void _fail(Object failure) {
    _stop();
    incident = null;
    categories = const [];
    technicians = const [];
    readError = AppErrorMessages.fromError(failure);
    notifyListeners();
  }

  /// Validates editable input and freezes a stable command before any write.
  ///
  /// A later snapshot cannot change the frozen payload. Uncertain failures retain
  /// the ID for retry; confirmed validation or permission failures unlock edits.
  Future<bool> submit(
    IncidentHistoryAction action, {
    String? categoryId,
    IncidentPriority? priority,
    String? technicianId,
    String? reason,
  }) async {
    if (!ready || saving || pending != null || !actions.contains(action)) {
      return false;
    }
    if (action == IncidentHistoryAction.classified &&
        (priority == null || !categories.any((row) => row.id == categoryId))) {
      return _invalid('Seleccioná una categoría activa y una prioridad.');
    }
    if (action == IncidentHistoryAction.assigned &&
        !categories.any((row) => row.id == incident?.categoryId)) {
      return _invalid(
        'Clasificá nuevamente la incidencia con una categoría activa.',
      );
    }
    if (action == IncidentHistoryAction.assigned &&
        !technicians.any((row) => row.id == technicianId)) {
      return _invalid('Seleccioná un usuario con rol Técnico.');
    }
    if ([
          IncidentHistoryAction.resolved,
          IncidentHistoryAction.rejected,
          IncidentHistoryAction.cancelled,
          IncidentHistoryAction.reopened,
        ].contains(action) &&
        (reason == null || reason.trim().isEmpty)) {
      return _invalid(
        action == IncidentHistoryAction.resolved
            ? 'Escribí la solución realizada.'
            : 'Escribí el motivo de la operación.',
      );
    }
    try {
      final current = incident!;
      final command = IncidentWorkflowCommand(
        eventId: repository.newIncidentId(),
        action: action,
        expectedStatus: current.status,
        expectedUpdatedAt: current.updatedAt,
        categoryId: categoryId,
        priority: priority,
        technicianId: technicianId,
        reason: reason?.trim(),
      );
      IncidentWorkflow.changes(current, command, role, uid);
      pending = command;
    } catch (failure) {
      return _invalid(AppErrorMessages.fromError(failure));
    }
    return retry();
  }

  bool _invalid(String message) {
    saveError = message;
    success = null;
    notifyListeners();
    return false;
  }

  /// Confirms the same operation after a lost acknowledgement without duplicates.
  Future<bool> retry() async {
    if (!active || saving || pending == null) return false;
    final command = pending!;
    saving = true;
    saveError = null;
    success = null;
    notifyListeners();
    try {
      if (!active) return false;
      await repository.applyWorkflow(incidentId: incidentId, command: command);
      if (!active) return false;
      pending = null;
      success = 'Cambio guardado correctamente.';
      return true;
    } catch (failure) {
      if (!active) return false;
      saveError = failure is StateError
          ? 'La incidencia cambió o la acción ya no está permitida. Revisá su estado actual.'
          : failure is FormatException
          ? 'Revisá la categoría, la prioridad y el técnico seleccionados.'
          : AppErrorMessages.fromError(failure);
      if (failure is StateError ||
          failure is FormatException ||
          (failure is FirebaseException &&
              [
                'permission-denied',
                'not-found',
                'invalid-argument',
              ].contains(failure.code))) {
        pending = null;
      }
      return false;
    } finally {
      if (active) {
        saving = false;
        notifyListeners();
      }
    }
  }

  void _stop() {
    _version++;
    for (final subscription in _subscriptions) {
      subscription.cancel().ignore();
    }
    _subscriptions.clear();
    loadingSources.clear();
  }

  void _clear() {
    _stop();
    incident = null;
    categories = const [];
    technicians = const [];
    pending = null;
    saving = false;
    readError = null;
    saveError = null;
    success = null;
  }

  void _sessionChanged() {
    if (active || _disposed) return;
    _invalidated = true;
    _clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _clear();
    session.removeListener(_sessionChanged);
    super.dispose();
  }
}
