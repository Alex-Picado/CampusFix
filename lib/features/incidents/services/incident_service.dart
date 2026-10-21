import 'package:cloud_firestore/cloud_firestore.dart';

import '../../auth/services/auth_service.dart';
import '../../users/models/user_role.dart';
import '../models/incident_history_action.dart';
import '../models/incident_status.dart';

/// Persists reports, sequences and initial history in a Firestore transaction.
class IncidentService {
  final FirebaseFirestore _firestore;
  final AuthService _authService;

  /// Stable history document ID used for the single initial event.
  static const initialHistoryEventId = 'created';

  // Sequences must remain exactly representable by Flutter Web integers.
  static const _maxSequenceNumber = 9007199254740991;

  /// Creates a service with explicit database and authentication dependencies.
  IncidentService({required this._firestore, required this._authService});

  /// Allocates an incident ID locally without writing any documents.
  String newIncidentId() => _firestore.collection('incidents').doc().id;

  /// Atomically creates a report, its counter increment and its initial event.
  ///
  /// Expects normalized fields and a stable ID supplied by the repository.
  /// Reads the current reporter profile and active category before writing.
  /// Uses server timestamps, the authenticated UID and the reported state.
  /// All document IDs are fixed before the retryable transaction callback.
  /// Matching existing reports are returned without rewriting any documents;
  /// conflicting IDs are rejected. Transaction callbacks have no file or UI
  /// side effects. A failed server confirmation can be retried with the same ID.
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

    await _firestore.runTransaction<void>((transaction) async {
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
            message: 'The incident ID is associated with a different report.',
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
        throw const FormatException('An active valid category is required.');
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
