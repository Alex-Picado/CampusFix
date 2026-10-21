import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:campusfix/features/incidents/models/incident.dart';
import 'package:campusfix/features/incidents/models/incident_priority.dart';
import 'package:campusfix/features/incidents/models/incident_status.dart';

void main() {
  final createdAt = DateTime.utc(2026, 10, 21, 8, 30, 15, 123, 456);
  final updatedAt = DateTime.utc(2026, 10, 21, 9, 45, 30, 654, 321);

  Map<String, dynamic> confirmedData() => {
    'sequenceNumber': 12,
    'title': 'Broken classroom light',
    'description': 'The ceiling light does not turn on.',
    'categoryId': 'lighting',
    'location': 'Building A, classroom 2',
    'priority': 'ALTA',
    'status': 'EN_ATENCION',
    'createdAt': createdAt,
    'updatedAt': updatedAt,
    'createdByUserId': 'reporter-1',
    'assignedTechnicianId': 'technician-1',
    'resolutionDescription': null,
  };

  Incident confirmedIncident() => Incident(
    id: 'incident-1',
    sequenceNumber: 12,
    title: 'Broken classroom light',
    description: 'The ceiling light does not turn on.',
    categoryId: 'lighting',
    location: 'Building A, classroom 2',
    priority: IncidentPriority.high,
    status: IncidentStatus.inProgress,
    createdAt: createdAt,
    updatedAt: updatedAt,
    createdByUserId: 'reporter-1',
    assignedTechnicianId: 'technician-1',
  );

  test('Serializes the agreed fields without duplicating the document ID', () {
    final data = confirmedIncident().toMap();

    expect(data, confirmedData());
    expect(data, isNot(contains('id')));
    expect(data['status'], 'EN_ATENCION');
    expect(data['priority'], 'ALTA');
  });

  test('Restores every confirmed field without losing date precision', () {
    final restored = Incident.fromMap(id: 'incident-1', data: confirmedData());

    expect(restored.id, 'incident-1');
    expect(restored.sequenceNumber, 12);
    expect(restored.priority, IncidentPriority.high);
    expect(restored.status, IncidentStatus.inProgress);
    expect(
      restored.createdAt.microsecondsSinceEpoch,
      createdAt.microsecondsSinceEpoch,
    );
    expect(
      restored.updatedAt.microsecondsSinceEpoch,
      updatedAt.microsecondsSinceEpoch,
    );
    expect(restored.toMap(), confirmedData());
  });

  test('New reports serialize their initial state and nullable fields', () {
    final incident = Incident(
      id: 'new-incident',
      sequenceNumber: 1,
      title: 'Water leak',
      description: 'Water is leaking below the sink.',
      categoryId: 'plumbing',
      location: 'Building B',
      createdAt: createdAt,
      updatedAt: createdAt,
      createdByUserId: 'reporter-1',
    );

    final data = incident.toMap();
    expect(data['status'], 'REPORTADA');
    expect(
      data.keys,
      containsAll([
        'priority',
        'assignedTechnicianId',
        'resolutionDescription',
      ]),
    );
    expect(data['priority'], isNull);
    expect(data['assignedTechnicianId'], isNull);
    expect(data['resolutionDescription'], isNull);
    expect(Incident.fromMap(id: incident.id, data: data).toMap(), data);
  });

  test(
    'Missing optional fields become null while unknown fields are ignored',
    () {
      final data = confirmedData()
        ..remove('priority')
        ..remove('assignedTechnicianId')
        ..remove('resolutionDescription')
        ..['futureField'] = 'Reserved for another module';

      final incident = Incident.fromMap(id: 'incident-1', data: data);

      expect(incident.priority, isNull);
      expect(incident.assignedTechnicianId, isNull);
      expect(incident.resolutionDescription, isNull);
      expect(incident.toMap(), isNot(contains('futureField')));
    },
  );

  test('Uses the document ID instead of an untrusted stored ID', () {
    final data = confirmedData()..['id'] = 'another-incident';

    final incident = Incident.fromMap(id: 'incident-1', data: data);

    expect(incident.id, 'incident-1');
    expect(incident.toMap(), isNot(contains('id')));
  });

  test(
    'Preserves original text instead of silently normalizing stored data',
    () {
      final data = confirmedData()
        ..['title'] = '  Report title  '
        ..['description'] = 'First line.\nSecond line.  ';

      final incident = Incident.fromMap(id: 'incident-1', data: data);

      expect(incident.title, '  Report title  ');
      expect(incident.description, 'First line.\nSecond line.  ');
      expect(incident.toMap(), data);
    },
  );

  test('Rejects missing required fields instead of supplying defaults', () {
    const fields = [
      'sequenceNumber',
      'title',
      'description',
      'categoryId',
      'location',
      'status',
      'createdAt',
      'updatedAt',
      'createdByUserId',
    ];

    for (final field in fields) {
      final data = confirmedData()..remove(field);
      expect(
        () => Incident.fromMap(id: 'incident-1', data: data),
        throwsA(isA<FormatException>()),
        reason: 'Missing $field must not be silently accepted.',
      );
    }
  });

  test('Rejects invalid required field types', () {
    final invalidFields = <String, Object>{
      'title': 123,
      'description': false,
      'categoryId': 123,
      'location': <String>[],
      'status': IncidentStatus.inProgress,
      'createdAt': '2026-10-21T08:30:00Z',
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'createdByUserId': 123,
    };

    for (final entry in invalidFields.entries) {
      final data = confirmedData()..[entry.key] = entry.value;
      expect(
        () => Incident.fromMap(id: 'incident-1', data: data),
        throwsA(isA<FormatException>()),
        reason: 'Invalid ${entry.key} type must be rejected.',
      );
    }
  });

  test('Requires a positive integer sequence number', () {
    for (final value in <Object?>[0, -1, 12.0, '12', null]) {
      final data = confirmedData()..['sequenceNumber'] = value;
      expect(
        () => Incident.fromMap(id: 'incident-1', data: data),
        throwsA(isA<FormatException>()),
        reason: 'Invalid sequence number: $value.',
      );
    }
  });

  test('Rejects blank document IDs and required text', () {
    for (final id in ['', ' \t ']) {
      expect(
        () => Incident.fromMap(id: id, data: confirmedData()),
        throwsA(isA<FormatException>()),
      );
    }

    for (final field in [
      'title',
      'description',
      'categoryId',
      'location',
      'createdByUserId',
    ]) {
      final data = confirmedData()..[field] = ' \t\n ';
      expect(
        () => Incident.fromMap(id: 'incident-1', data: data),
        throwsA(isA<FormatException>()),
        reason: 'Blank $field must be rejected.',
      );
    }
  });

  test(
    'Rejects null dates and raw timestamps until the service normalizes them',
    () {
      for (final field in ['createdAt', 'updatedAt']) {
        for (final value in [null, Timestamp.fromDate(createdAt)]) {
          final data = confirmedData()..[field] = value;
          expect(
            () => Incident.fromMap(id: 'incident-1', data: data),
            throwsA(isA<FormatException>()),
            reason: '$field requires a confirmed DateTime.',
          );
        }
      }
    },
  );

  test('Rejects enum names and unsupported stored values', () {
    for (final status in ['inProgress', 'UNKNOWN', '']) {
      expect(
        () => Incident.fromMap(
          id: 'incident-1',
          data: confirmedData()..['status'] = status,
        ),
        throwsA(isA<FormatException>()),
      );
    }
    for (final priority in ['high', 'UNKNOWN', '']) {
      expect(
        () => Incident.fromMap(
          id: 'incident-1',
          data: confirmedData()..['priority'] = priority,
        ),
        throwsA(isA<FormatException>()),
      );
    }
  });

  test('Rejects invalid optional field types and empty technician IDs', () {
    for (final entry in <MapEntry<String, Object>>[
      const MapEntry('priority', 1),
      const MapEntry('assignedTechnicianId', 123),
      const MapEntry('assignedTechnicianId', '  '),
      const MapEntry('resolutionDescription', false),
    ]) {
      final data = confirmedData()..[entry.key] = entry.value;
      expect(
        () => Incident.fromMap(id: 'incident-1', data: data),
        throwsA(isA<FormatException>()),
        reason: 'Invalid optional field: ${entry.key}.',
      );
    }
  });

  test('Preserves a saved resolution through serialization', () {
    final data = confirmedData()
      ..['status'] = 'RESUELTA'
      ..['resolutionDescription'] = 'Replaced the damaged lamp.';

    final incident = Incident.fromMap(id: 'incident-1', data: data);

    expect(incident.resolutionDescription, 'Replaced the damaged lamp.');
    expect(incident.toMap(), data);
  });

  test(
    'An unchanged copy preserves every field without mutating the original',
    () {
      final original = confirmedIncident();
      final copy = original.copyWith();

      expect(identical(copy, original), isFalse);
      expect(copy.id, original.id);
      expect(copy.toMap(), original.toMap());
    },
  );

  test('A changed copy preserves report identity and creation metadata', () {
    final original = confirmedIncident();
    final later = DateTime.utc(2026, 10, 22, 10);
    final updated = original.copyWith(
      title: 'Updated title',
      description: 'Updated description',
      categoryId: 'electrical',
      location: 'Building B',
      priority: IncidentPriority.medium,
      status: IncidentStatus.resolved,
      updatedAt: later,
      assignedTechnicianId: 'technician-2',
      resolutionDescription: 'Replaced the damaged lamp.',
    );

    expect(updated.id, original.id);
    expect(updated.sequenceNumber, original.sequenceNumber);
    expect(updated.createdByUserId, original.createdByUserId);
    expect(updated.createdAt, original.createdAt);
    expect(updated.toMap(), {
      ...confirmedData(),
      'title': 'Updated title',
      'description': 'Updated description',
      'categoryId': 'electrical',
      'location': 'Building B',
      'priority': 'MEDIA',
      'status': 'RESUELTA',
      'updatedAt': later,
      'assignedTechnicianId': 'technician-2',
      'resolutionDescription': 'Replaced the damaged lamp.',
    });
    expect(original.toMap(), confirmedData());
  });

  test('Explicit null replacements preserve existing optional fields', () {
    final original = confirmedIncident().copyWith(
      resolutionDescription: 'Saved resolution',
    );
    final copy = original.copyWith(
      priority: null,
      assignedTechnicianId: null,
      resolutionDescription: null,
    );

    expect(copy.toMap(), original.toMap());
  });

  test('Each clear flag removes only its corresponding nullable field', () {
    final original = confirmedIncident().copyWith(
      resolutionDescription: 'Saved resolution',
    );

    expect(original.copyWith(clearPriority: true).toMap(), {
      ...original.toMap(),
      'priority': null,
    });
    expect(original.copyWith(clearAssignedTechnician: true).toMap(), {
      ...original.toMap(),
      'assignedTechnicianId': null,
    });
    expect(original.copyWith(clearResolution: true).toMap(), {
      ...original.toMap(),
      'resolutionDescription': null,
    });
    expect(original.priority, IncidentPriority.high);
    expect(original.assignedTechnicianId, 'technician-1');
    expect(original.resolutionDescription, 'Saved resolution');
  });

  test(
    'Clear flags take precedence over simultaneous optional replacements',
    () {
      final copy = confirmedIncident().copyWith(
        priority: IncidentPriority.low,
        assignedTechnicianId: 'technician-2',
        resolutionDescription: 'Replacement resolution',
        clearPriority: true,
        clearAssignedTechnician: true,
        clearResolution: true,
      );

      expect(copy.priority, isNull);
      expect(copy.assignedTechnicianId, isNull);
      expect(copy.resolutionDescription, isNull);
    },
  );
}
