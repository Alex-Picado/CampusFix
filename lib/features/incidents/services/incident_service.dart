import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../auth/services/auth_service.dart';
import '../../users/models/user_role.dart';
import '../models/incident_history_action.dart';
import '../models/incident_status.dart';

/// Handles authenticated incident persistence and confirmed live observations.
class IncidentService {
  final FirebaseFirestore _firestore;
  final AuthService _authService;
  final Duration _initialSnapshotTimeout;

  /// Stable history document ID used for the single initial event.
  static const initialHistoryEventId = 'created';

  // Sequences must remain exactly representable by Flutter Web integers.
  static const _maxSequenceNumber = 9007199254740991;

  /// Creates a service with explicit database and authentication dependencies.
  ///
  /// The first confirmed snapshot must arrive within [initialSnapshotTimeout].
  IncidentService({
    required this._firestore,
    required this._authService,
    this._initialSnapshotTimeout = const Duration(seconds: 30),
  }) : assert(_initialSnapshotTimeout > Duration.zero);

  /// Allocates an incident ID locally without writing any documents.
  String newIncidentId() => _firestore.collection('incidents').doc().id;

  /// Watches server-confirmed reports filtered by the authenticated owner's UID.
  ///
  /// Metadata events deliver the acknowledged snapshot after pending writes.
  /// Cached and pending snapshots are withheld rather than parsed as confirmed.
  /// Account changes and source errors terminate the observation.
  Stream<Map<String, Map<String, dynamic>>> watchOwn({required String userId}) {
    _requireSession(userId);
    return _watchSession(userId, () {
      return _firestore
          .collection('incidents')
          .where('createdByUserId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .snapshots(includeMetadataChanges: true)
          .where((snapshot) => _isConfirmed(snapshot.metadata))
          .map(
            (snapshot) => {
              for (final document in snapshot.docs)
                document.id: _normalizeDates(document.data(), [
                  'createdAt',
                  'updatedAt',
                ]),
            },
          );
    });
  }

  /// Watches one server-confirmed document under Firestore detail permissions.
  Stream<Map<String, dynamic>?> watchById({required String incidentId}) {
    final userId = _requireSession();
    return _watchSession(userId, () {
      return _firestore
          .collection('incidents')
          .doc(incidentId)
          .snapshots(includeMetadataChanges: true)
          .where((snapshot) => _isConfirmed(snapshot.metadata))
          .map(
            (snapshot) => snapshot.exists
                ? _normalizeDates(snapshot.data()!, ['createdAt', 'updatedAt'])
                : null,
          );
    });
  }

  /// Watches authorized initial and operational history records.
  Stream<Map<String, Map<String, dynamic>>> watchHistory({
    required String incidentId,
  }) {
    return _watchRecords(incidentId, 'history');
  }

  /// Watches authorized technician progress descriptions and their authors.
  Stream<Map<String, Map<String, dynamic>>> watchProgress({
    required String incidentId,
  }) {
    return _watchRecords(incidentId, 'progress');
  }

  /// Watches authorized local photograph metadata with confirmed server dates.
  Stream<Map<String, Map<String, dynamic>>> watchEvidence({
    required String incidentId,
  }) => _watchRecords(incidentId, 'evidence');

  /// Associates a previously uploaded report photograph without duplicate writes.
  Future<void> attachEvidence({
    required String incidentId,
    required String evidenceId,
    required Map<String, dynamic> reference,
  }) async {
    final uid = _requireSession();
    final parent = _firestore.collection('incidents').doc(incidentId);
    final target = parent.collection('evidence').doc(evidenceId);
    await _firestore.runTransaction<void>((tx) async {
      _requireSession(uid);
      final incident = await tx.get(parent);
      final profile = await tx.get(_firestore.collection('users').doc(uid));
      final existing = await tx.get(target);
      if (incident.data()?['createdByUserId'] != uid ||
          profile.data()?['role'] != 'reporter') {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
        );
      }
      final fields = {
        ...reference,
        'provider': 'local',
        'uploadedByUserId': uid,
        'progressId': null,
      };
      if (existing.exists) {
        if (!fields.entries.every(
          (entry) => existing.data()?[entry.key] == entry.value,
        )) {
          throw const FormatException('Conflicting evidence reference.');
        }
        return;
      }
      _requireSession(uid);
      tx.set(target, {...fields, 'createdAt': FieldValue.serverTimestamp()});
    });
    _requireSession(uid);
    final confirmed = await target.get(const GetOptions(source: Source.server));
    _requireSession(uid);
    if (confirmed.data()?['createdAt'] is! Timestamp ||
        confirmed.metadata.hasPendingWrites ||
        confirmed.metadata.isFromCache) {
      throw FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');
    }
  }

  /// Atomically records immutable progress, its matching history and optional evidence.
  Future<void> addProgress({
    required String incidentId,
    required String progressId,
    required String description,
    String? evidenceId,
    Map<String, dynamic>? reference,
  }) async {
    final uid = _requireSession();
    final parent = _firestore.collection('incidents').doc(incidentId);
    final progress = parent.collection('progress').doc(progressId);
    final event = parent.collection('history').doc(progressId);
    final evidence = evidenceId == null
        ? null
        : parent.collection('evidence').doc(evidenceId);
    await _firestore.runTransaction<void>((tx) async {
      _requireSession(uid);
      final incident = await tx.get(parent);
      final profile = await tx.get(_firestore.collection('users').doc(uid));
      final existing = await tx.get(progress);
      final existingEvent = await tx.get(event);
      final existingEvidence = evidence == null ? null : await tx.get(evidence);
      final data = incident.data();
      if (existing.exists) {
        if (existing.data()?['authorUserId'] != uid ||
            existing.data()?['description'] != description ||
            existingEvent.data()?['action'] != 'progressAdded' ||
            existingEvent.data()?['reason'] != description ||
            (evidence != null &&
                (existingEvidence?.data()?['progressId'] != progressId ||
                    !reference!.entries.every(
                      (entry) =>
                          existingEvidence?.data()?[entry.key] == entry.value,
                    )))) {
          throw const FormatException('Conflicting progress submission.');
        }
        return;
      }
      if (data?['assignedTechnicianId'] != uid ||
          data?['status'] != 'EN_ATENCION' ||
          profile.data()?['role'] != 'technician') {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
        );
      }
      _requireSession(uid);
      final timestamp = FieldValue.serverTimestamp();
      tx.set(progress, {
        'authorUserId': uid,
        'createdAt': timestamp,
        'description': description,
      });
      tx.set(event, {
        'actorUserId': uid,
        'createdAt': timestamp,
        'action': 'progressAdded',
        'fromStatus': 'EN_ATENCION',
        'toStatus': 'EN_ATENCION',
        'fromTechnicianId': null,
        'toTechnicianId': null,
        'reason': description,
      });
      if (evidence != null) {
        tx.set(evidence, {
          ...reference!,
          'provider': 'local',
          'uploadedByUserId': uid,
          'createdAt': timestamp,
          'progressId': progressId,
        });
      }
    });
    _requireSession(uid);
    final confirmed = await progress.get(
      const GetOptions(source: Source.server),
    );
    _requireSession(uid);
    if (confirmed.data()?['createdAt'] is! Timestamp ||
        confirmed.metadata.hasPendingWrites ||
        confirmed.metadata.isFromCache) {
      throw FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');
    }
  }

  Stream<Map<String, Map<String, dynamic>>> _watchRecords(
    String incidentId,
    String name,
  ) {
    final userId = _requireSession();
    return _watchSession(userId, () {
      return _firestore
          .collection('incidents')
          .doc(incidentId)
          .collection(name)
          .orderBy('createdAt')
          .snapshots(includeMetadataChanges: true)
          .where((snapshot) => _isConfirmed(snapshot.metadata))
          .map(
            (snapshot) => {
              for (final document in snapshot.docs)
                document.id: _normalizeDates(document.data(), ['createdAt']),
            },
          );
    });
  }

  bool _isConfirmed(SnapshotMetadata metadata) {
    return !metadata.isFromCache && !metadata.hasPendingWrites;
  }

  Map<String, dynamic> _normalizeDates(
    Map<String, dynamic> data,
    List<String> fields,
  ) {
    final normalized = Map<String, dynamic>.of(data);
    for (final field in fields) {
      final value = data[field];
      if (value is! Timestamp) {
        throw const FormatException(
          'Confirmed record timestamps are required.',
        );
      }
      normalized[field] = value.toDate();
    }
    return normalized;
  }

  /// Owns both subscriptions and terminates them when the session is unavailable.
  Stream<T> _watchSession<T>(String userId, Stream<T> Function() source) {
    late StreamController<T> controller;
    StreamSubscription<T>? documents;
    StreamSubscription<User?>? authentication;
    Future<void>? cancellation;
    Timer? firstSnapshotDeadline;
    var stopped = false;

    Future<void> cancelSubscriptions() {
      firstSnapshotDeadline?.cancel();
      return cancellation ??= Future.wait<void>([
        if (documents != null) documents!.cancel(),
        if (authentication != null) authentication!.cancel(),
      ]).then((_) {});
    }

    Future<void> stop([Object? error, StackTrace? stack]) async {
      if (stopped) return;
      stopped = true;
      if (error != null) controller.addError(error, stack);
      await cancelSubscriptions();
      unawaited(controller.close());
    }

    controller = StreamController<T>(
      onListen: () {
        try {
          _requireSession(userId);
          firstSnapshotDeadline = Timer(_initialSnapshotTimeout, () {
            unawaited(
              stop(
                FirebaseException(
                  plugin: 'cloud_firestore',
                  code: 'unavailable',
                  message: 'No confirmed server snapshot was received.',
                ),
              ),
            );
          });
          authentication = _authService.watchAuthState().listen(
            (user) {
              if (user?.uid != userId) {
                unawaited(stop(StateError('The observed session changed.')));
              }
            },
            onError: (Object error, StackTrace stack) =>
                unawaited(stop(error, stack)),
            onDone: () => unawaited(
              stop(StateError('Authentication observation ended.')),
            ),
          );
          if (stopped) {
            unawaited(authentication!.cancel());
            return;
          }
          documents = source().listen(
            (value) {
              if (stopped) return;
              try {
                _requireSession(userId);
                firstSnapshotDeadline?.cancel();
                controller.add(value);
              } catch (error, stack) {
                unawaited(stop(error, stack));
              }
            },
            onError: (Object error, StackTrace stack) =>
                unawaited(stop(error, stack)),
            onDone: () => unawaited(stop()),
          );
          if (stopped) unawaited(documents!.cancel());
        } catch (error, stack) {
          unawaited(stop(error, stack));
        }
      },
      onPause: () => documents?.pause(),
      onResume: () => documents?.resume(),
      onCancel: () {
        stopped = true;
        return cancelSubscriptions();
      },
    );
    return controller.stream.map((value) {
      _requireSession(userId);
      return value;
    });
  }

  /// Atomically creates a report, its counter increment and its initial event.
  ///
  /// Expects normalized fields and a stable ID supplied by the repository.
  /// Reads the current reporter profile and active category before writing.
  /// Uses server timestamps, the authenticated UID and the reported state.
  /// All document IDs are fixed before the retryable transaction callback.
  /// Matching existing reports are returned without rewriting any documents;
  /// conflicting IDs are rejected. Transaction callbacks have no file or UI
  /// side effects. A failed server confirmation can be retried with the same ID.
  /// Rejected counter races allow at most three transaction invocations, only
  /// when a fresh server read confirms that the counter advanced.
  Future<Map<String, dynamic>> create({
    required String incidentId,
    required String title,
    required String description,
    required String categoryId,
    required String location,
  }) async {
    final userId = _requireSession();
    final incident = _firestore.collection('incidents').doc(incidentId);
    final history = incident.collection('history').doc(initialHistoryEventId);
    final counter = _firestore.collection('counters').doc('incidents');
    final profile = _firestore.collection('users').doc(userId);
    final category = _firestore.collection('categories').doc(categoryId);

    for (var attempt = 0; attempt < 3; attempt++) {
      int? attemptedSequence;
      try {
        await _firestore.runTransaction<void>((transaction) async {
          attemptedSequence = null;
          _requireSession(userId);
          final existing = await transaction.get(incident);
          if (existing.exists) {
            final data = existing.data()!;
            if (data['createdByUserId'] != userId) {
              throw FirebaseException(
                plugin: 'cloud_firestore',
                code: 'permission-denied',
                message: 'The incident belongs to another account.',
              );
            }
            if (data['title'] != title ||
                data['description'] != description ||
                data['categoryId'] != categoryId ||
                data['location'] != location) {
              throw FirebaseException(
                plugin: 'cloud_firestore',
                code: 'already-exists',
                message:
                    'The incident ID is associated with a different report.',
              );
            }
            _requireSession(userId);
            return;
          }

          final profileSnapshot = await transaction.get(profile);
          if (profileSnapshot.data()?['role'] != UserRole.reporter.name) {
            throw FirebaseException(
              plugin: 'cloud_firestore',
              code: 'permission-denied',
              message: 'Only reporter profiles can create incidents.',
            );
          }

          final categorySnapshot = await transaction.get(category);
          final categoryData = categorySnapshot.data();
          final categoryName = categoryData?['name'];
          if (categoryData?['isActive'] != true ||
              categoryName is! String ||
              categoryName.trim().isEmpty) {
            throw const FormatException(
              'An active valid category is required.',
            );
          }

          final counterSnapshot = await transaction.get(counter);
          final counterData = counterSnapshot.data();
          var previousSequence = 0;
          if (counterSnapshot.exists) {
            final storedSequence = counterData?['lastSequenceNumber'];
            final storedIncidentId = counterData?['lastIncidentId'];
            if (storedSequence is! int ||
                storedSequence < 1 ||
                storedIncidentId is! String ||
                storedIncidentId.trim().isEmpty) {
              throw const FormatException('Invalid incident sequence counter.');
            }
            previousSequence = storedSequence;
          }
          if (previousSequence >= _maxSequenceNumber) {
            throw FirebaseException(
              plugin: 'cloud_firestore',
              code: 'resource-exhausted',
              message: 'The incident sequence has reached its supported limit.',
            );
          }

          _requireSession(userId);
          final sequenceNumber = previousSequence + 1;
          attemptedSequence = sequenceNumber;
          final timestamp = FieldValue.serverTimestamp();
          transaction.set(counter, {
            'lastSequenceNumber': sequenceNumber,
            'lastIncidentId': incidentId,
          });
          transaction.set(incident, {
            'sequenceNumber': sequenceNumber,
            'title': title,
            'description': description,
            'categoryId': categoryId,
            'location': location,
            'priority': null,
            'status': IncidentStatus.reported.value,
            'createdAt': timestamp,
            'updatedAt': timestamp,
            'createdByUserId': userId,
            'assignedTechnicianId': null,
            'resolutionDescription': null,
          });
          transaction.set(history, {
            'actorUserId': userId,
            'createdAt': timestamp,
            'action': IncidentHistoryAction.created.value,
            'fromStatus': null,
            'toStatus': IncidentStatus.reported.value,
            'fromTechnicianId': null,
            'toTechnicianId': null,
            'reason': null,
          });
        });
        break;
      } on FirebaseException catch (error) {
        final sequence = attemptedSequence;
        if (attempt == 2 ||
            sequence == null ||
            !['permission-denied', 'aborted'].contains(error.code)) {
          rethrow;
        }
        _requireSession(userId);
        if (!await _counterAdvanced(counter, sequence)) rethrow;
        _requireSession(userId);
      }
    }

    _requireSession(userId);
    final confirmed = await incident.get(
      const GetOptions(source: Source.server),
    );
    _requireSession(userId);
    if (confirmed.metadata.hasPendingWrites || confirmed.metadata.isFromCache) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
        message: 'A confirmed server snapshot is required.',
      );
    }
    final data = confirmed.data();
    if (!confirmed.exists || data == null) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'not-found',
        message: 'The confirmed report could not be loaded.',
      );
    }
    if (data['createdByUserId'] != userId) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message: 'The confirmed report belongs to another account.',
      );
    }

    final createdAt = data['createdAt'];
    final updatedAt = data['updatedAt'];
    if (createdAt is! Timestamp || updatedAt is! Timestamp) {
      throw const FormatException('Confirmed report timestamps are required.');
    }
    return {
      ...data,
      'createdAt': createdAt.toDate(),
      'updatedAt': updatedAt.toDate(),
    };
  }

  /// Confirms a counter advance before retrying a rejected creation attempt.
  ///
  /// Unavailable or unconfirmed probes preserve the original transaction error.
  /// No retry is authorized by a local cache value or a pending write.
  Future<bool> _counterAdvanced(
    DocumentReference<Map<String, dynamic>> counter,
    int attemptedSequence,
  ) async {
    try {
      final snapshot = await counter.get(
        const GetOptions(source: Source.server),
      );
      final data = snapshot.data();
      final sequence = data?['lastSequenceNumber'];
      final incidentId = data?['lastIncidentId'];
      return !snapshot.metadata.hasPendingWrites &&
          !snapshot.metadata.isFromCache &&
          sequence is int &&
          sequence >= attemptedSequence &&
          sequence <= _maxSequenceNumber &&
          incidentId is String &&
          incidentId.trim().isNotEmpty;
    } on FirebaseException {
      return false;
    }
  }

  /// Requires an authenticated account and preserves the submission identity.
  String _requireSession([String? expectedUserId]) {
    final userId = _authService.getCurrentUser()?.uid;
    if (userId == null || userId.isEmpty) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unauthenticated',
        message: 'An authenticated reporter is required.',
      );
    }
    if (expectedUserId != null && userId != expectedUserId) {
      throw StateError('The authenticated account changed during submission.');
    }
    return userId;
  }
}
