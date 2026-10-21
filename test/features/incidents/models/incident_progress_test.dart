import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:campusfix/features/incidents/models/incident_progress.dart';

void main() {
  final createdAt = DateTime.utc(2026, 10, 21, 11, 30, 15, 123, 456);

  Map<String, dynamic> progressData() => {
    'authorUserId': 'technician-1',
    'createdAt': createdAt,
    'description': 'The electrical circuit was inspected.',
  };

  test('Serializes the progress contract without its document ID', () {
    final progress = IncidentProgress(
      id: 'progress-1',
      authorUserId: 'technician-1',
      createdAt: createdAt,
      description: 'The electrical circuit was inspected.',
    );

    expect(progress.toMap(), progressData());
    expect(progress.toMap(), isNot(contains('id')));
    final restored = IncidentProgress.fromMap(
      id: progress.id,
      data: progress.toMap(),
    );
    expect(restored.id, 'progress-1');
    expect(restored.authorUserId, 'technician-1');
    expect(
      restored.createdAt.microsecondsSinceEpoch,
      createdAt.microsecondsSinceEpoch,
    );
    expect(restored.toMap(), progressData());
  });

  test(
    'Preserves multiline comments and uses the supplied document identity',
    () {
      final data = progressData()
        ..['description'] = '  First inspection.\nReplacement requested.  '
        ..['id'] = 'untrusted-id'
        ..['futureField'] = true;

      final progress = IncidentProgress.fromMap(id: 'progress-1', data: data);

      expect(progress.id, 'progress-1');
      expect(
        progress.description,
        '  First inspection.\nReplacement requested.  ',
      );
      expect(progress.toMap(), {
        'authorUserId': 'technician-1',
        'createdAt': createdAt,
        'description': '  First inspection.\nReplacement requested.  ',
      });
    },
  );

  test('Rejects a progress entry missing any required field', () {
    for (final field in ['authorUserId', 'createdAt', 'description']) {
      expect(
        () => IncidentProgress.fromMap(
          id: 'progress-1',
          data: progressData()..remove(field),
        ),
        throwsA(isA<FormatException>()),
        reason: 'Missing $field must not be replaced with a default.',
      );
    }
  });

  test('Rejects invalid author and description types', () {
    for (final entry in <String, Object>{
      'authorUserId': 123,
      'description': <String>['Not a description'],
    }.entries) {
      expect(
        () => IncidentProgress.fromMap(
          id: 'progress-1',
          data: progressData()..[entry.key] = entry.value,
        ),
        throwsA(isA<FormatException>()),
      );
    }
  });

  test('Rejects blank document IDs authors and descriptions', () {
    for (final id in ['', ' \t ']) {
      expect(
        () => IncidentProgress.fromMap(id: id, data: progressData()),
        throwsA(isA<FormatException>()),
      );
    }
    for (final field in ['authorUserId', 'description']) {
      expect(
        () => IncidentProgress.fromMap(
          id: 'progress-1',
          data: progressData()..[field] = ' \n ',
        ),
        throwsA(isA<FormatException>()),
      );
    }
  });

  test('Rejects unresolved or unnormalized progress dates', () {
    for (final date in <Object?>[
      null,
      '2026-10-21T11:30:00Z',
      createdAt.millisecondsSinceEpoch,
      Timestamp.fromDate(createdAt),
    ]) {
      expect(
        () => IncidentProgress.fromMap(
          id: 'progress-1',
          data: progressData()..['createdAt'] = date,
        ),
        throwsA(isA<FormatException>()),
      );
    }
  });
}
