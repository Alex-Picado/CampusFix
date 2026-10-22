import 'dart:async';

import 'package:flutter/foundation.dart' show ChangeNotifier;

import '../../../core/errors/app_error_messages.dart';
import '../../auth/controllers/session_controller.dart';
import '../../auth/models/session_status.dart';
import '../../catalogs/models/category.dart';
import '../../catalogs/repositories/category_repository.dart';
import '../../users/models/user_role.dart';
import '../models/incident.dart';
import '../models/incident_evidence.dart';
import '../models/incident_history_event.dart';
import '../models/incident_progress.dart';
import '../models/incident_status.dart';
import '../models/selected_photo.dart';
import '../repositories/incident_repository.dart';
import '../repositories/evidence_repository.dart';

/// Owns authorized detail subscriptions and one stable technician submission.
class IncidentDetailController extends ChangeNotifier {
  final IncidentRepository repository;

  /// Resolves referenced category names without requiring a full catalog query.
  final CategoryRepository categoryRepository;
  final EvidenceRepository? evidenceRepository;
  final SessionController session;
  final String incidentId;
  final String uid;
  final UserRole role;
  final _subscriptions = <StreamSubscription<dynamic>>[];
  StreamSubscription<Category?>? _categorySubscription;
  int _categoryVersion = 0;
  String? _categoryId;
  int _version = 0;
  int _operationVersion = 0;
  bool _disposed = false;
  bool _invalidated = false;
  bool _childrenStarted = false;
  Incident? incident;

  /// Current category, including inactive records; null while missing or loading.
  Category? category;

  /// Whether the referenced category is awaiting its first snapshot.
  bool categoryLoading = false;

  /// Spanish category feedback, independent of incident and progress failures.
  String? categoryError;
  List<IncidentHistoryEvent> history = const [];
  List<IncidentProgress> progress = const [];
  List<IncidentEvidence> evidence = const [];
  final loadingSections = <String>{};
  bool loading = true;
  bool notFound = false;
  String? error;
  String description = '';
  SelectedPhoto? photo;
  Map<String, dynamic>? uploaded;
  String? progressId;
  String? evidenceId;
  bool saving = false;
  bool selecting = false;
  String? progressError;
  String? progressSuccess;

  IncidentDetailController({
    required this.repository,
    required this.categoryRepository,
    required this.evidenceRepository,
    required this.session,
    required this.incidentId,
    required this.uid,
    required this.role,
  }) {
    session.addListener(_sessionChanged);
    final saved = role == UserRole.technician
        ? evidenceRepository?.recover(uid, incidentId, 'progress')
        : null;
    if (saved != null) {
      progressId = saved['id'] as String?;
      evidenceId = saved['evidenceId'] as String?;
      description = saved['description'] as String? ?? '';
      uploaded = saved['reference'] == null
          ? null
          : Map<String, dynamic>.from(saved['reference'] as Map);
    }
    start();
  }

  bool get active =>
      !_disposed &&
      !_invalidated &&
      session.status == SessionStatus.authenticated &&
      session.profile?.id == uid &&
      session.profile?.role == role;
  bool get canAddProgress =>
      active &&
      role == UserRole.technician &&
      incident?.assignedTechnicianId == uid &&
      incident?.status == IncidentStatus.inProgress;
  bool get frozen => progressId != null;
  bool get canSelect =>
      canAddProgress &&
      evidenceRepository != null &&
      !saving &&
      !selecting &&
      (!frozen || (evidenceId != null && photo == null && uploaded == null));

  /// Restarts confirmed detail observation and discards obsolete private snapshots.
  void start() {
    if (!active) return;
    _stop();
    final version = _version;
    _clearRecords();
    loading = true;
    error = null;
    notFound = false;
    notifyListeners();
    if (!active || version != _version) return;
    _watch<Incident?>(repository.watchById(incidentId: incidentId), version, (
      value,
    ) {
      if (value == null) {
        _stop();
        _clearRecords();
        loading = false;
        notFound = true;
        notifyListeners();
        return;
      }
      if (value.createdByUserId != uid &&
          role != UserRole.administrator &&
          !(role == UserRole.technician && value.assignedTechnicianId == uid)) {
        _fail('No tenés permiso para consultar esta incidencia.');
        return;
      }
      incident = value;
      _watchCategory(value.categoryId);
      loading = false;
      if (!_childrenStarted) {
        _childrenStarted = true;
        loadingSections.addAll([
          'history',
          'progress',
          if (evidenceRepository != null) 'evidence',
        ]);
        _watch<List<IncidentHistoryEvent>>(
          repository.watchHistory(incidentId: incidentId),
          version,
          (rows) {
            history = rows;
            loadingSections.remove('history');
          },
        );
        _watch<List<IncidentProgress>>(
          repository.watchProgress(incidentId: incidentId),
          version,
          (rows) {
            progress = rows;
            loadingSections.remove('progress');
          },
        );
        if (evidenceRepository != null) {
          _watch<List<IncidentEvidence>>(
            evidenceRepository!.watch(incidentId),
            version,
            (rows) {
              evidence = rows;
              loadingSections.remove('evidence');
            },
          );
        }
      }
    });
  }

  /// Retries only the referenced category without interrupting incident progress.
  ///
  /// Does nothing after the original session or authorized incident has ended.
  void retryCategory() {
    if (!active || incident == null) return;
    _categoryId = null;
    _watchCategory(incident!.categoryId);
    notifyListeners();
  }

  void _watchCategory(String id) {
    if (_categoryId == id) return;
    _categorySubscription?.cancel().ignore();
    _categorySubscription = null;
    _categoryId = id;
    final version = ++_categoryVersion;
    category = null;
    categoryLoading = true;
    categoryError = null;
    bool current() =>
        active && version == _categoryVersion && _categoryId == id;
    void fail(Object failure) {
      if (!current()) return;
      category = null;
      categoryLoading = false;
      categoryError = AppErrorMessages.fromError(failure);
      notifyListeners();
    }

    try {
      final subscription = categoryRepository
          .watchById(id)
          .listen(
            (value) {
              if (!current()) return;
              category = value;
              categoryLoading = false;
              categoryError = value == null
                  ? 'La categoría ya no está disponible.'
                  : null;
              notifyListeners();
            },
            onError: (Object failure) => fail(failure),
            onDone: () {
              fail(StateError('Category observation ended.'));
            },
            cancelOnError: true,
          );
      if (current()) {
        _categorySubscription = subscription;
      } else {
        subscription.cancel().ignore();
      }
    } catch (failure) {
      fail(failure);
    }
  }

  void _watch<T>(Stream<T> stream, int version, void Function(T) receive) {
    try {
      final subscription = stream.listen(
        (value) {
          if (!active || version != _version) return;
          receive(value);
          if (active && version == _version) notifyListeners();
        },
        onError: (Object failure) {
          if (active && version == _version) {
            _fail(AppErrorMessages.fromError(failure));
          }
        },
        onDone: () {
          if (active && version == _version) {
            _fail('No se pudo mantener el seguimiento. Intentá nuevamente.');
          }
        },
        cancelOnError: true,
      );
      if (active && version == _version) {
        _subscriptions.add(subscription);
      } else {
        subscription.cancel().ignore();
      }
    } catch (failure) {
      if (active && version == _version) {
        _fail(AppErrorMessages.fromError(failure));
      }
    }
  }

  /// Updates the editable progress draft before its first submission attempt.
  void setDescription(String value) {
    if (!canAddProgress || saving || frozen) return;
    description = value;
    progressError = null;
    progressSuccess = null;
    notifyListeners();
  }

  /// Selects optional progress evidence without changing a frozen submission.
  Future<void> selectPhoto() async {
    if (!canSelect || evidenceRepository == null) return;
    final version = _operationVersion;
    selecting = true;
    progressError = null;
    notifyListeners();
    try {
      final selected = await evidenceRepository!.selectPhoto();
      if (active && version == _operationVersion && selected != null) {
        photo = selected;
      }
    } catch (failure) {
      if (active && version == _operationVersion) {
        progressError = AppErrorMessages.fromError(failure);
      }
    } finally {
      if (active && version == _operationVersion) {
        selecting = false;
        notifyListeners();
      }
    }
  }

  /// Retries the same normalized progress ID, description and evidence atomically.
  Future<bool> saveProgress() async {
    if (!active ||
        role != UserRole.technician ||
        saving ||
        selecting ||
        (!canAddProgress && !frozen)) {
      return false;
    }
    if (description.trim().isEmpty) {
      progressError = 'Describí el avance realizado.';
      notifyListeners();
      return false;
    }
    if (evidenceId != null && photo == null && uploaded == null) {
      progressError =
          'Volvé a seleccionar la misma fotografía para reintentar.';
      notifyListeners();
      return false;
    }
    final version = _operationVersion;
    progressId ??= repository.newIncidentId();
    if (photo != null) evidenceId ??= evidenceRepository!.newId();
    description = description.trim();
    saving = true;
    progressError = null;
    progressSuccess = null;
    _remember();
    notifyListeners();
    try {
      if (!active || version != _operationVersion) return false;
      if (photo != null && uploaded == null) {
        final result = await evidenceRepository!.upload(
          uid,
          incidentId,
          evidenceId!,
          photo!,
          progressId: progressId,
        );
        if (!active || version != _operationVersion) return false;
        uploaded = result;
        _remember();
      }
      await repository.addProgress(
        incidentId: incidentId,
        progressId: progressId!,
        description: description,
        evidenceId: evidenceId,
        reference: uploaded,
      );
      if (!active || version != _operationVersion) return false;
      evidenceRepository?.remember(uid, incidentId, 'progress', null);
      description = '';
      photo = null;
      uploaded = null;
      progressId = null;
      evidenceId = null;
      progressSuccess = 'Avance guardado correctamente.';
      return true;
    } catch (failure) {
      if (active && version == _operationVersion) {
        progressError = AppErrorMessages.fromError(failure);
      }
      return false;
    } finally {
      if (active && version == _operationVersion) {
        saving = false;
        notifyListeners();
      }
    }
  }

  void _remember() =>
      evidenceRepository?.remember(uid, incidentId, 'progress', {
        'id': progressId,
        'description': description,
        'evidenceId': evidenceId,
        'reference': uploaded,
      });

  void _fail(String message) {
    _stop();
    _clearRecords();
    loading = false;
    error = message;
    notifyListeners();
  }

  void _stop() {
    _version++;
    _categoryVersion++;
    _categorySubscription?.cancel().ignore();
    _categorySubscription = null;
    _categoryId = null;
    _childrenStarted = false;
    for (final subscription in _subscriptions) {
      subscription.cancel().ignore();
    }
    _subscriptions.clear();
  }

  void _clearRecords() {
    incident = null;
    category = null;
    categoryError = null;
    categoryLoading = false;
    history = const [];
    progress = const [];
    evidence = const [];
    loadingSections.clear();
  }

  void _sessionChanged() {
    if (active || _disposed) return;
    _invalidated = true;
    _operationVersion++;
    _stop();
    _clearRecords();
    evidenceRepository?.remember(uid, incidentId, 'progress', null);
    description = '';
    photo = null;
    uploaded = null;
    progressId = null;
    evidenceId = null;
    error = null;
    progressError = null;
    progressSuccess = null;
    saving = false;
    selecting = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _operationVersion++;
    _stop();
    _clearRecords();
    session.removeListener(_sessionChanged);
    description = '';
    photo = null;
    uploaded = null;
    progressError = null;
    progressSuccess = null;
    progressId = null;
    evidenceId = null;
    super.dispose();
  }
}
