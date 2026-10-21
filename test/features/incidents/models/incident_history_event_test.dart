import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:campusfix/features/incidents/models/incident_history_action.dart';
import 'package:campusfix/features/incidents/models/incident_history_event.dart';
import 'package:campusfix/features/incidents/models/incident_status.dart';

void main() {
  final createdAt = DateTime.utc(2026, 10, 21, 12, 15, 30, 456, 789);

  Map<String, dynamic> historyData() => {
    'actorUserId': 'administrator-1',
    'createdAt': createdAt,
    'action': 'assigned',
    'fromStatus': 'EN_REVISION',
    'toStatus': 'ASIGNADA',
    'fromTechnicianId': null,
    'toTechnicianId': 'technician-1',
    'reason': 'Electrical maintenance coverage.',
  };

  test('Serializes an initial event with the stored reported status', () {
    final event = IncidentHistoryEvent(
      id: 'created',
      actorUserId: 'reporter-1',
      createdAt: createdAt,
      action: IncidentHistoryAction.created,
      toStatus: IncidentStatus.reported,
    );

    expect(event.toMap(), {
      'actorUserId': 'reporter-1',
      'createdAt': createdAt,
      'action': 'created',
      'fromStatus': null,
      'toStatus': 'REPORTADA',
      'fromTechnicianId': null,
      'toTechnicianId': null,
      'reason': null,
    });
    expect(event.toMap(), isNot(contains('id')));
  });

  test(
    'Restores status technician and reason fields without losing precision',
    () {
      final data = historyData()..['fromTechnicianId'] = 'technician-2';
      final event = IncidentHistoryEvent.fromMap(id: 'event-1', data: data);

      expect(event.id, 'event-1');
      expect(event.actorUserId, 'administrator-1');
      expect(event.action, IncidentHistoryAction.assigned);
      expect(event.fromStatus, IncidentStatus.underReview);
      expect(event.toStatus, IncidentStatus.assigned);
      expect(event.fromTechnicianId, 'technician-2');
      expect(event.toTechnicianId, 'technician-1');
      expect(
        event.createdAt.microsecondsSinceEpoch,
        createdAt.microsecondsSinceEpoch,
      );
      expect(event.toMap(), data);
    },
  );

  test(
    'Missing optional history fields become null and extra fields are ignored',
    () {
      final event = IncidentHistoryEvent.fromMap(
        id: 'event-1',
        data: {
          'actorUserId': 'technician-1',
          'createdAt': createdAt,
          'action': 'progressAdded',
          'id': 'untrusted-id',
          'futureField': true,
        },
      );

      expect(event.id, 'event-1');
      expect(event.toMap(), {
        'actorUserId': 'technician-1',
        'createdAt': createdAt,
        'action': 'progressAdded',
        'fromStatus': null,
        'toStatus': null,
        'fromTechnicianId': null,
        'toTechnicianId': null,
        'reason': null,
      });
    },
  );

  test('Preserves every shared English history action code', () {
    const codes = {
      'created': IncidentHistoryAction.created,
      'classified': IncidentHistoryAction.classified,
      'assigned': IncidentHistoryAction.assigned,
      'started': IncidentHistoryAction.started,
      'progressAdded': IncidentHistoryAction.progressAdded,
      'resolved': IncidentHistoryAction.resolved,
      'closed': IncidentHistoryAction.closed,
      'rejected': IncidentHistoryAction.rejected,
      'cancelled': IncidentHistoryAction.cancelled,
      'reopened': IncidentHistoryAction.reopened,
    };
    expect(IncidentHistoryAction.values, unorderedEquals(codes.values));

    for (final entry in codes.entries) {
      expect(IncidentHistoryAction.fromValue(entry.key), entry.value);
      expect(entry.value.value, entry.key);
      final event = IncidentHistoryEvent.fromMap(
        id: 'event-1',
        data: historyData()..['action'] = entry.key,
      );
      expect(event.toMap()['action'], entry.key);
    }
  });

  test('Rejects unsupported action codes and action field types', () {
    for (final action in <Object?>[
      'progress_added',
      'CREATED',
      '',
      123,
      null,
    ]) {
      expect(
        () => IncidentHistoryEvent.fromMap(
          id: 'event-1',
          data: historyData()..['action'] = action,
        ),
        throwsA(isA<FormatException>()),
      );
    }
    expect(
      () => IncidentHistoryAction.fromValue('unknownAction'),
      throwsA(isA<FormatException>()),
    );
  });

  test(
    'Rejects unsupported statuses and status enum names in stored fields',
    () {
      for (final field in ['fromStatus', 'toStatus']) {
        for (final status in <Object>['inProgress', 'UNKNOWN', '', 1]) {
          expect(
            () => IncidentHistoryEvent.fromMap(
              id: 'event-1',
              data: historyData()..[field] = status,
            ),
            throwsA(isA<FormatException>()),
          );
        }
      }
    },
  );

  test('Rejects events missing an actor date or action', () {
    for (final field in ['actorUserId', 'createdAt', 'action']) {
      expect(
        () => IncidentHistoryEvent.fromMap(
          id: 'event-1',
          data: historyData()..remove(field),
        ),
        throwsA(isA<FormatException>()),
      );
    }
  });

  test('Rejects invalid actor technician and reason metadata', () {
    for (final entry in <MapEntry<String, Object>>[
      const MapEntry('actorUserId', 1),
      const MapEntry('actorUserId', ' \t '),
      const MapEntry('fromTechnicianId', 1),
      const MapEntry('fromTechnicianId', ' '),
      const MapEntry('toTechnicianId', false),
      const MapEntry('toTechnicianId', ' '),
      const MapEntry('reason', 1),
      const MapEntry('reason', ' \n '),
    ]) {
      expect(
        () => IncidentHistoryEvent.fromMap(
          id: 'event-1',
          data: historyData()..[entry.key] = entry.value,
        ),
        throwsA(isA<FormatException>()),
        reason: 'Invalid ${entry.key} must be rejected.',
      );
    }
    expect(
      () => IncidentHistoryEvent.fromMap(id: ' ', data: historyData()),
      throwsA(isA<FormatException>()),
    );
  });

  test('Rejects unresolved or unnormalized history dates', () {
    for (final date in <Object?>[
      null,
      '2026-10-21T12:15:00Z',
      createdAt.millisecondsSinceEpoch,
      Timestamp.fromDate(createdAt),
    ]) {
      expect(
        () => IncidentHistoryEvent.fromMap(
          id: 'event-1',
          data: historyData()..['createdAt'] = date,
        ),
        throwsA(isA<FormatException>()),
      );
    }
  });

  test('Preserves a valid reason including whitespace and line breaks', () {
    final data = historyData()
      ..['reason'] = '  First reason.\nAdditional detail.  ';

    final event = IncidentHistoryEvent.fromMap(id: 'event-1', data: data);

    expect(event.reason, '  First reason.\nAdditional detail.  ');
    expect(event.toMap(), data);
  });
}
