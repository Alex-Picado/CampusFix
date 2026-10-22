import 'package:campusfix/features/incidents/models/incident.dart';
import 'package:campusfix/features/incidents/models/incident_history_action.dart';
import 'package:campusfix/features/incidents/models/incident_priority.dart';
import 'package:campusfix/features/incidents/models/incident_status.dart';
import 'package:campusfix/features/incidents/models/incident_workflow.dart';
import 'package:campusfix/features/incidents/services/incident_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/incident_firestore.dart';

void main() {
  late IncidentTestFirestore database;
  late IncidentTestAuth auth;
  late IncidentService service;
  var sequence = 0;
  Incident current() {
    final data = database.documents['incidents/case']!;
    return Incident.fromMap(
      id: 'case',
      data: {
        ...data,
        'createdAt': (data['createdAt'] as Timestamp).toDate(),
        'updatedAt': (data['updatedAt'] as Timestamp).toDate(),
      },
    );
  }

  IncidentWorkflowCommand command(
    IncidentHistoryAction action, {
    String? reason,
    String? technicianId,
    bool classify = false,
  }) {
    final incident = current();
    return IncidentWorkflowCommand(
      eventId: 'workflow-${++sequence}',
      action: action,
      expectedStatus: incident.status,
      expectedUpdatedAt: incident.updatedAt,
      categoryId: classify ? 'lighting' : null,
      priority: classify ? IncidentPriority.high : null,
      technicianId: technicianId,
      reason: reason,
    );
  }

  Future<void> save(IncidentWorkflowCommand command) =>
      service.applyWorkflow(incidentId: 'case', command: command);
  Future<void> classify() =>
      save(command(IncidentHistoryAction.classified, classify: true));
  Future<void> assign() =>
      save(command(IncidentHistoryAction.assigned, technicianId: 'tech'));
  setUp(() async {
    sequence = 0;
    database = IncidentTestFirestore();
    auth = IncidentTestAuth();
    service = IncidentService(firestore: database, authService: auth);
    await service.create(
      incidentId: 'case',
      title: 'Broken light',
      description: 'Hall is dark',
      categoryId: 'lighting',
      location: 'Building A',
    );
    database.store('users/admin', {'role': 'administrator'});
    database.store('users/tech', {'role': 'technician'});
    database.store('users/other-tech', {'role': 'technician'});
    auth.userId = 'admin';
  });

  test('The full lifecycle preserves immutable incident data and records every actor', () async {
    final original = current();
    await classify();
    expect(current().priority, IncidentPriority.high);
    await assign();
    auth.userId = 'tech';
    await save(command(IncidentHistoryAction.started));
    await save(
      command(IncidentHistoryAction.resolved, reason: 'Replaced the light'),
    );
    auth.userId = 'admin';
    await save(command(IncidentHistoryAction.closed));
    expect(current().status, IncidentStatus.closed);
    expect(current().createdByUserId, original.createdByUserId);
    expect(current().sequenceNumber, original.sequenceNumber);
    expect(current().createdAt, original.createdAt);
    expect(
      database.documents['incidents/case/history/workflow-3']?['actorUserId'],
      'tech',
    );
    expect(
      database.documents['incidents/case/history/workflow-5']?['actorUserId'],
      'admin',
    );
    expect(
      database.documents['incidents/case']?['lastWorkflowEventId'],
      'workflow-5',
    );
  });
  test('Reopening preserves the previous solution and requires new classification and assignment', () async {
    await classify();
    await assign();
    auth.userId = 'tech';
    await save(command(IncidentHistoryAction.started));
    await save(command(IncidentHistoryAction.resolved, reason: 'Repaired'));
    auth.userId = 'admin';
    await save(
      command(IncidentHistoryAction.reopened, reason: 'Problem returned'),
    );
    expect(current().status, IncidentStatus.underReview);
    expect(current().resolutionDescription, isNull);
    expect(current().assignedTechnicianId, isNull);
    expect(current().priority, isNull);
    expect(
      database
          .documents['incidents/case/history/workflow-5']?['previousResolutionDescription'],
      'Repaired',
    );
    expect(
      database
          .documents['incidents/case/history/workflow-5']?['fromTechnicianId'],
      'tech',
    );
    await expectLater(assign(), throwsStateError);
    await classify();
    await assign();
  });
  test('A nonassigned technician and a stored role downgrade cannot start attention', () async {
    await classify();
    await assign();
    auth.userId = 'other-tech';
    await expectLater(
      save(command(IncidentHistoryAction.started)),
      throwsStateError,
    );
    auth.userId = 'tech';
    database.store('users/tech', {'role': 'reporter'});
    await expectLater(
      save(command(IncidentHistoryAction.started)),
      throwsA(isA<FirebaseException>()),
    );
    expect(current().status, IncidentStatus.assigned);
  });
  test('Assignment requires an active category, classification and a stored technician', () async {
    await expectLater(assign(), throwsStateError);
    await classify();
    await expectLater(
      save(command(IncidentHistoryAction.assigned, technicianId: 'reporter-1')),
      throwsFormatException,
    );
    database.store('categories/lighting', {
      'isActive': false,
      'name': 'Lighting',
    });
    await expectLater(assign(), throwsFormatException);
    expect(current().status, IncidentStatus.underReview);
  });
  test('Only a resolved case can be closed and solutions or reasons cannot be blank', () async {
    await expectLater(
      save(command(IncidentHistoryAction.closed)),
      throwsStateError,
    );
    await expectLater(
      save(command(IncidentHistoryAction.cancelled, reason: '  ')),
      throwsFormatException,
    );
    await classify();
    await assign();
    auth.userId = 'tech';
    await expectLater(
      save(command(IncidentHistoryAction.resolved, reason: 'Solution')),
      throwsStateError,
    );
    await save(command(IncidentHistoryAction.started));
    await expectLater(
      save(command(IncidentHistoryAction.resolved, reason: '  ')),
      throwsFormatException,
    );
    expect(current().status, IncidentStatus.inProgress);
  });
  test(
    'Rejection and cancellation are terminal and always record the reason',
    () async {
      await classify();
      await save(
        command(IncidentHistoryAction.rejected, reason: 'Duplicate report'),
      );
      expect(current().status, IncidentStatus.rejected);
      await expectLater(
        save(command(IncidentHistoryAction.reopened, reason: 'Retry')),
        throwsStateError,
      );
    },
  );
  test('Lost confirmation retries one stable event without replaying its transition', () async {
    final attempt = command(IncidentHistoryAction.classified, classify: true);
    database.nextServerReadError = FirebaseException(
      plugin: 'cloud_firestore',
      code: 'unavailable',
    );
    await expectLater(save(attempt), throwsA(isA<FirebaseException>()));
    final commits = database.writeCommits;
    await save(attempt);
    expect(database.writeCommits, commits);
    final conflict = IncidentWorkflowCommand(
      eventId: attempt.eventId,
      action: attempt.action,
      expectedStatus: attempt.expectedStatus,
      expectedUpdatedAt: attempt.expectedUpdatedAt,
      categoryId: 'lighting',
      priority: IncidentPriority.low,
    );
    await expectLater(save(conflict), throwsFormatException);
  });
  test('Rejected transactions leave neither an incident change nor an orphan event', () async {
    final attempt = command(IncidentHistoryAction.classified, classify: true);
    database.nextCommitError = FirebaseException(
      plugin: 'cloud_firestore',
      code: 'permission-denied',
    );
    await expectLater(save(attempt), throwsA(isA<FirebaseException>()));
    expect(current().status, IncidentStatus.reported);
    expect(
      database.documents['incidents/case/history/${attempt.eventId}'],
      isNull,
    );
    await save(attempt);
  });
  test('A stale form cannot overwrite a newer incident and account switches cannot report success', () async {
    final attempt = command(IncidentHistoryAction.classified, classify: true);
    final data = database.documents['incidents/case']!;
    database.store('incidents/case', {
      ...data,
      'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 10, 22)),
    });
    await expectLater(save(attempt), throwsStateError);
    database.beforeServerRead = (_) => auth.userId = 'other-tech';
    await expectLater(classify(), throwsStateError);
  });
}
