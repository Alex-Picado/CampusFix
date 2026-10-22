import '../models/incident.dart';
import '../models/incident_workflow.dart';
import '../models/incident_history_event.dart';
import '../models/incident_progress.dart';
import '../services/incident_service.dart';

/// Validates report submissions and converts confirmed incident documents.
class IncidentRepository {
  final IncidentService _incidentService;

  /// Creates a repository with the provided incident service.
  IncidentRepository({required this._incidentService});

  /// Watches every incident authorized for an administrator.
  Stream<List<Incident>> watchAll() => _watchQueue();

  /// Watches only the authenticated technician's server-filtered assignments.
  Stream<List<Incident>> watchAssigned({required String userId}) {
    _requireIncidentId(userId);
    return _watchQueue(technicianId: userId);
  }

  Stream<List<Incident>> _watchQueue({String? technicianId}) =>
      _incidentService.watchQueue(technicianId: technicianId).map((documents) {
        final rows = documents.entries
            .map((entry) => Incident.fromMap(id: entry.key, data: entry.value))
            .toList();
        if (technicianId != null &&
            rows.any((row) => row.assignedTechnicianId != technicianId)) {
          throw const FormatException(
            'The assignment query returned a foreign case.',
          );
        }
        rows.sort((a, b) {
          final byDate = b.updatedAt.compareTo(a.updatedAt);
          return byDate != 0
              ? byDate
              : b.sequenceNumber.compareTo(a.sequenceNumber);
        });
        return List<Incident>.unmodifiable(rows);
      });

  /// Validates identifiers before forwarding a stable lifecycle command.
  ///
  /// Commands must use normalized text. State, role and related records are
  /// checked by the transactional service and independently by Firestore rules.
  Future<void> applyWorkflow({
    required String incidentId,
    required IncidentWorkflowCommand command,
  }) {
    _requireIncidentId(incidentId);
    _requireIncidentId(command.eventId);
    if (command.eventId == 'created') {
      throw const FormatException('Reserved event ID.');
    }
    for (final id in [command.categoryId, command.technicianId]) {
      if (id != null) _requireIncidentId(id);
    }
    if (command.reason != null &&
        (command.reason!.trim().isEmpty ||
            command.reason != command.reason!.trim())) {
      throw const FormatException('Normalized workflow text is required.');
    }
    return _incidentService.applyWorkflow(
      incidentId: incidentId,
      command: command,
    );
  }

  /// Allocates a document ID without writing a report or advancing its sequence.
  ///
  /// Retain this ID for all retries of the same submission.
  String newIncidentId() => _incidentService.newIncidentId();

  /// Validates a stable progress submission before invoking its atomic service.
  Future<void> addProgress({
    required String incidentId,
    required String progressId,
    required String description,
    String? evidenceId,
    Map<String, dynamic>? reference,
  }) async {
    _requireIncidentId(incidentId);
    _requireIncidentId(progressId);
    if (progressId == 'created' ||
        description.trim().isEmpty ||
        (evidenceId == null) != (reference == null)) {
      throw const FormatException('Valid progress fields are required.');
    }
    if (evidenceId != null) _requireIncidentId(evidenceId);
    await _incidentService.addProgress(
      incidentId: incidentId,
      progressId: progressId,
      description: description.trim(),
      evidenceId: evidenceId,
      reference: reference,
    );
  }

  /// Watches the authenticated reporter's incidents, newest first.
  ///
  /// The service filters by UID in Firestore. Lists are unmodifiable; creation
  /// time, descending sequence and ID provide deterministic presentation order.
  /// Invalid documents and source errors are delivered to the listener.
  Stream<List<Incident>> watchOwn({required String userId}) async* {
    if (userId.trim().isEmpty) {
      throw const FormatException('A user ID is required.');
    }
    yield* _incidentService.watchOwn(userId: userId).map((documents) {
      final incidents = documents.entries.map((entry) {
        final incident = Incident.fromMap(id: entry.key, data: entry.value);
        if (incident.createdByUserId != userId) {
          throw const FormatException(
            'The own-report query returned another author.',
          );
        }
        return incident;
      }).toList();
      incidents.sort((first, second) {
        final byDate = second.createdAt.compareTo(first.createdAt);
        if (byDate != 0) return byDate;
        final bySequence = second.sequenceNumber.compareTo(
          first.sequenceNumber,
        );
        return bySequence != 0 ? bySequence : first.id.compareTo(second.id);
      });
      return List<Incident>.unmodifiable(incidents);
    });
  }

  /// Watches an authorized incident; a confirmed missing document emits null.
  Stream<Incident?> watchById({required String incidentId}) async* {
    _requireIncidentId(incidentId);
    yield* _incidentService.watchById(incidentId: incidentId).map((data) {
      return data == null ? null : Incident.fromMap(id: incidentId, data: data);
    });
  }

  /// Watches immutable history lists in chronological order with ID tie breaks.
  Stream<List<IncidentHistoryEvent>> watchHistory({
    required String incidentId,
  }) async* {
    _requireIncidentId(incidentId);
    yield* _incidentService.watchHistory(incidentId: incidentId).map((
      documents,
    ) {
      final events = documents.entries.map((entry) {
        return IncidentHistoryEvent.fromMap(id: entry.key, data: entry.value);
      }).toList();
      events.sort((first, second) {
        final byDate = first.createdAt.compareTo(second.createdAt);
        return byDate != 0 ? byDate : first.id.compareTo(second.id);
      });
      return List<IncidentHistoryEvent>.unmodifiable(events);
    });
  }

  /// Watches immutable chronological technician progress and comment records.
  Stream<List<IncidentProgress>> watchProgress({
    required String incidentId,
  }) async* {
    _requireIncidentId(incidentId);
    yield* _incidentService.watchProgress(incidentId: incidentId).map((
      documents,
    ) {
      final entries = documents.entries.map((entry) {
        return IncidentProgress.fromMap(id: entry.key, data: entry.value);
      }).toList();
      entries.sort((first, second) {
        final byDate = first.createdAt.compareTo(second.createdAt);
        return byDate != 0 ? byDate : first.id.compareTo(second.id);
      });
      return List<IncidentProgress>.unmodifiable(entries);
    });
  }

  /// Creates a report or recovers a matching previously confirmed submission.
  ///
  /// Trims report text and requires nonblank fields and valid document IDs.
  /// The author is obtained from the authenticated session by the service.
  /// Returns an incident only after a server read confirms its timestamps.
  /// Retrying with the same [incidentId] does not create another sequence or
  /// history event. A different payload for an occupied ID is rejected.
  /// Propagates authentication, transaction and confirmation-read failures.
  Future<Incident> create({
    required String incidentId,
    required String title,
    required String description,
    required String categoryId,
    required String location,
  }) async {
    final normalizedTitle = title.trim();
    final normalizedDescription = description.trim();
    final normalizedLocation = location.trim();

    if (!_isDocumentId(incidentId) ||
        !_isDocumentId(categoryId) ||
        normalizedTitle.isEmpty ||
        normalizedDescription.isEmpty ||
        normalizedLocation.isEmpty) {
      throw const FormatException(
        'Valid report fields and document IDs are required.',
      );
    }

    final data = await _incidentService.create(
      incidentId: incidentId,
      title: normalizedTitle,
      description: normalizedDescription,
      categoryId: categoryId,
      location: normalizedLocation,
    );
    return Incident.fromMap(id: incidentId, data: data);
  }

  /// Rejects invalid incident IDs before opening an observation.
  void _requireIncidentId(String value) {
    if (!_isDocumentId(value)) {
      throw const FormatException('A valid incident ID is required.');
    }
  }

  /// Checks single-segment IDs without silently changing document identity.
  bool _isDocumentId(String value) {
    return value.trim().isNotEmpty &&
        value == value.trim() &&
        !value.contains('/') &&
        value != '.' &&
        value != '..' &&
        !RegExp(r'^__.*__$').hasMatch(value);
  }
}
