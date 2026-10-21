import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:campusfix/features/incidents/models/incident.dart';
import 'package:campusfix/features/incidents/models/incident_status.dart';
import 'package:campusfix/features/incidents/repositories/incident_repository.dart';
import 'package:campusfix/features/incidents/services/incident_service.dart';

import '../../../support/incident_firestore.dart';

void main() {
  late IncidentTestFirestore database;
  late IncidentTestAuth auth;
  late IncidentRepository repository;

  setUp(() {
    database = IncidentTestFirestore();
    auth = IncidentTestAuth();
    repository = IncidentRepository(
      incidentService: IncidentService(firestore: database, authService: auth),
    );
  });

  Future<Incident> create({
    String incidentId = 'report-1',
    String title = 'Broken light',
    String description = 'The classroom light does not turn on.',
    String categoryId = 'lighting',
    String location = 'Building A',
  }) {
    return repository.create(
      incidentId: incidentId,
      title: title,
      description: description,
      categoryId: categoryId,
      location: location,
    );
  }

  List<String> reportPaths() => database.documents.keys
      .where((path) => path.startsWith('incidents/'))
      .toList();

  Matcher firebaseCode(String code) =>
      isA<FirebaseException>().having((error) => error.code, 'code', code);

  test(
    'Allocates distinct stable IDs without writing or advancing a counter',
    () {
      final first = repository.newIncidentId();
      final second = repository.newIncidentId();

      expect(first, isNot(second));
      expect(database.allocatedIds, 2);
      expect(database.transactionAttempts, 0);
      expect(reportPaths(), isEmpty);
      expect(database.documents.containsKey('counters/incidents'), isFalse);
    },
  );

  test(
    'Commits the first report counter and initial event with server dates',
    () async {
      final incidentId = repository.newIncidentId();
      final incident = await create(
        incidentId: incidentId,
        title: '  Broken light  ',
        description: '  First line.\nSecond line.  ',
        location: '  Building A  ',
      );

      expect(incident.id, incidentId);
      expect(incident.sequenceNumber, 1);
      expect(incident.title, 'Broken light');
      expect(incident.description, 'First line.\nSecond line.');
      expect(incident.location, 'Building A');
      expect(incident.createdByUserId, 'reporter-1');
      expect(incident.status, IncidentStatus.reported);
      expect(incident.priority, isNull);
      expect(incident.assignedTechnicianId, isNull);
      expect(incident.resolutionDescription, isNull);
      expect(incident.createdAt, database.serverTime.toDate());
      expect(incident.updatedAt, incident.createdAt);
      expect(database.documents['incidents/$incidentId'], {
        ...incident.toMap(),
        'createdAt': database.serverTime,
        'updatedAt': database.serverTime,
      });
      expect(database.documents['counters/incidents'], {
        'lastSequenceNumber': 1,
        'lastIncidentId': incidentId,
      });
      expect(database.documents['incidents/$incidentId/history/created'], {
        'actorUserId': 'reporter-1',
        'createdAt': database.serverTime,
        'action': 'created',
        'fromStatus': null,
        'toStatus': 'REPORTADA',
        'fromTechnicianId': null,
        'toTechnicianId': null,
        'reason': null,
      });
      expect(reportPaths().length, 2);
      expect(database.writeCommits, 1);
      expect(database.allocatedIds, 1);
    },
  );

  test(
    'Continues an existing sequence without resetting or replacing old reports',
    () async {
      database.store('counters/incidents', {
        'lastSequenceNumber': 41,
        'lastIncidentId': 'previous',
      });
      database.store('incidents/previous', {'title': 'Previous report'});

      final incident = await create();

      expect(incident.sequenceNumber, 42);
      expect(database.documents['incidents/previous'], {
        'title': 'Previous report',
      });
      expect(
        database.documents['counters/incidents']?['lastIncidentId'],
        'report-1',
      );
    },
  );

  test('Concurrent creations retry conflicts and receive distinct consecutive numbers', () async {
    final firstId = repository.newIncidentId();
    final secondId = repository.newIncidentId();
    final incidents = await Future.wait([
      create(incidentId: firstId),
      create(incidentId: secondId),
    ]);

    expect(incidents.map((incident) => incident.sequenceNumber).toSet(), {
      1,
      2,
    });
    expect(incidents.map((incident) => incident.id).toSet(), {
      firstId,
      secondId,
    });
    expect(database.documents['counters/incidents']?['lastSequenceNumber'], 2);
    expect(reportPaths().where((path) => path.contains('/history/')).length, 2);
    expect(database.writeCommits, 2);
    expect(database.transactionAttempts, greaterThan(2));
    expect(database.allocatedIds, 2);
  });

  test(
    'Concurrent submissions with one ID create one report and one event',
    () async {
      final incidents = await Future.wait([create(), create()]);

      expect(incidents.map((incident) => incident.sequenceNumber), [1, 1]);
      expect(reportPaths().length, 2);
      expect(database.writeCommits, 1);
      expect(
        database.documents['counters/incidents']?['lastSequenceNumber'],
        1,
      );
    },
  );

  test('Retries a lost confirmation without another counter increment or initial event', () async {
    final failure = FirebaseException(
      plugin: 'cloud_firestore',
      code: 'unavailable',
    );
    database.nextServerReadError = failure;
    await expectLater(create(), throwsA(same(failure)));

    expect(database.writeCommits, 1);
    final savedHistory = Map.of(
      database.documents['incidents/report-1/history/created']!,
    );
    final recovered = await create();

    expect(recovered.sequenceNumber, 1);
    expect(database.writeCommits, 1);
    expect(reportPaths().length, 2);
    expect(
      database.documents['incidents/report-1/history/created'],
      savedHistory,
    );
  });

  test(
    'A rejected transaction leaves no partial report counter or history',
    () async {
      final failure = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
      );
      database.nextCommitError = failure;

      await expectLater(create(), throwsA(same(failure)));

      expect(database.writeCommits, 0);
      expect(reportPaths(), isEmpty);
      expect(database.documents.containsKey('counters/incidents'), isFalse);
      final recovered = await create();
      expect(recovered.sequenceNumber, 1);
      expect(database.writeCommits, 1);
    },
  );

  test(
    'An occupied ID rejects a changed payload without overwriting the report',
    () async {
      await create();
      final saved = Map.of(database.documents['incidents/report-1']!);

      for (final changed in [
        () => create(title: 'Different title'),
        () => create(description: 'Different description'),
        () => create(categoryId: 'another-category'),
        () => create(location: 'Different location'),
      ]) {
        await expectLater(changed(), throwsA(firebaseCode('already-exists')));
      }
      expect(database.documents['incidents/report-1'], saved);
      expect(database.writeCommits, 1);
    },
  );

  test(
    'The current account cannot recover a report owned by another account',
    () async {
      await create();
      auth.userId = 'reporter-2';
      database.store('users/reporter-2', {'role': 'reporter'});

      await expectLater(create(), throwsA(firebaseCode('permission-denied')));
      expect(database.writeCommits, 1);
      expect(
        database.documents['incidents/report-1']?['createdByUserId'],
        'reporter-1',
      );
    },
  );

  test('Signed-out sessions cannot begin a report transaction', () async {
    auth.userId = null;

    await expectLater(create(), throwsA(firebaseCode('unauthenticated')));
    expect(database.transactionAttempts, 0);
    expect(reportPaths(), isEmpty);
  });

  test('Only an existing reporter profile permits a new report', () async {
    for (final role in ['technician', 'administrator', 'invalid', null]) {
      database.store('users/reporter-1', {'role': role});
      await expectLater(create(), throwsA(firebaseCode('permission-denied')));
    }
    database.documents.remove('users/reporter-1');
    await expectLater(create(), throwsA(firebaseCode('permission-denied')));
    expect(database.writeCommits, 0);
    expect(reportPaths(), isEmpty);
  });

  test(
    'Missing inactive and malformed categories reject creation without writes',
    () async {
      for (final fields in [
        {'name': 'Lighting', 'isActive': false},
        {'name': 'Lighting', 'isActive': 'true'},
        {'isActive': true},
        {'name': '  ', 'isActive': true},
        {'name': 1, 'isActive': true},
      ]) {
        database.store('categories/lighting', fields);
        await expectLater(create(), throwsA(isA<FormatException>()));
      }
      database.documents.remove('categories/lighting');
      await expectLater(create(), throwsA(isA<FormatException>()));
      expect(reportPaths(), isEmpty);
      expect(database.writeCommits, 0);
    },
  );

  test(
    'Malformed counters are rejected instead of resetting the sequence',
    () async {
      for (final fields in [
        <String, dynamic>{},
        {'lastSequenceNumber': 0, 'lastIncidentId': 'previous'},
        {'lastSequenceNumber': -1, 'lastIncidentId': 'previous'},
        {'lastSequenceNumber': 1.5, 'lastIncidentId': 'previous'},
        {'lastSequenceNumber': '1', 'lastIncidentId': 'previous'},
        {'lastSequenceNumber': 1},
        {'lastSequenceNumber': 1, 'lastIncidentId': ' '},
      ]) {
        database.store('counters/incidents', fields);
        await expectLater(create(), throwsA(isA<FormatException>()));
        expect(database.documents['counters/incidents'], fields);
      }
      expect(reportPaths(), isEmpty);
      expect(database.writeCommits, 0);
    },
  );

  test(
    'Sequence values stay within the exact Flutter Web integer range',
    () async {
      database.store('counters/incidents', {
        'lastSequenceNumber': 9007199254740990,
        'lastIncidentId': 'previous',
      });
      final last = await create();
      expect(last.sequenceNumber, 9007199254740991);

      await expectLater(
        create(incidentId: 'overflow'),
        throwsA(firebaseCode('resource-exhausted')),
      );
      expect(database.writeCommits, 1);
      expect(database.documents.containsKey('incidents/overflow'), isFalse);
    },
  );

  test(
    'A category deactivated during creation is reread before any commit',
    () async {
      var changed = false;
      database.onTransactionRead = (path) {
        if (path == 'categories/lighting' && !changed) {
          changed = true;
          database.store(path, {'name': 'Lighting', 'isActive': false});
        }
      };

      await expectLater(create(), throwsA(isA<FormatException>()));
      expect(database.transactionAttempts, 2);
      expect(database.writeCommits, 0);
      expect(reportPaths(), isEmpty);
    },
  );

  test(
    'A role change during creation prevents a retried reporter write',
    () async {
      var changed = false;
      database.onTransactionRead = (path) {
        if (path == 'users/reporter-1' && !changed) {
          changed = true;
          database.store(path, {'role': 'technician'});
        }
      };

      await expectLater(create(), throwsA(firebaseCode('permission-denied')));
      expect(database.transactionAttempts, 2);
      expect(database.writeCommits, 0);
    },
  );

  test(
    'Switching accounts before writes cannot change the report author',
    () async {
      database.onTransactionRead = (path) {
        if (path == 'categories/lighting') auth.userId = 'reporter-2';
      };

      await expectLater(create(), throwsA(isA<StateError>()));
      expect(database.writeCommits, 0);
      expect(reportPaths(), isEmpty);
    },
  );

  test('Switching accounts after a commit cannot expose its result to the next session', () async {
    database.beforeServerRead = (_) => auth.userId = 'reporter-2';

    await expectLater(create(), throwsA(isA<StateError>()));
    expect(database.writeCommits, 1);
    expect(
      database.documents['incidents/report-1']?['createdByUserId'],
      'reporter-1',
    );

    database.beforeServerRead = null;
    auth.userId = 'reporter-1';
    expect((await create()).sequenceNumber, 1);
    expect(database.writeCommits, 1);
  });

  test('Confirmation requires resolved server timestamps instead of local estimates', () async {
    await create();
    final original = Map.of(database.documents['incidents/report-1']!);
    for (final field in ['createdAt', 'updatedAt']) {
      for (final value in [null, DateTime.utc(2026, 10, 21)]) {
        database.store('incidents/report-1', {...original, field: value});
        await expectLater(create(), throwsA(isA<FormatException>()));
      }
    }
    expect(database.writeCommits, 1);
  });

  test(
    'Cached or pending confirmation snapshots cannot announce success',
    () async {
      database.pendingServerWrites = true;
      await expectLater(create(), throwsA(firebaseCode('unavailable')));
      database.pendingServerWrites = false;
      database.cachedServerRead = true;
      await expectLater(create(), throwsA(firebaseCode('unavailable')));
      database.cachedServerRead = false;

      expect((await create()).sequenceNumber, 1);
      expect(database.writeCommits, 1);
    },
  );

  test('Retrying an advanced report preserves its status priority and audit records', () async {
    await create();
    database.store('incidents/report-1', {
      ...database.documents['incidents/report-1']!,
      'status': 'EN_ATENCION',
      'priority': 'ALTA',
      'assignedTechnicianId': 'technician-1',
    });
    database.store('incidents/report-1/history/started', {'action': 'started'});

    final recovered = await create();

    expect(recovered.status, IncidentStatus.inProgress);
    expect(recovered.assignedTechnicianId, 'technician-1');
    expect(database.documents['incidents/report-1/history/started'], {
      'action': 'started',
    });
    expect(database.writeCommits, 1);
  });

  test(
    'Invalid report fields and document paths fail before a transaction begins',
    () async {
      for (final invalidId in [
        '',
        ' ',
        ' report',
        'report ',
        'a/b',
        '.',
        '..',
        '__id__',
      ]) {
        await expectLater(
          create(incidentId: invalidId),
          throwsA(isA<FormatException>()),
        );
        await expectLater(
          create(categoryId: invalidId),
          throwsA(isA<FormatException>()),
        );
      }
      await expectLater(create(title: ' '), throwsA(isA<FormatException>()));
      await expectLater(
        create(description: '\n'),
        throwsA(isA<FormatException>()),
      );
      await expectLater(create(location: ''), throwsA(isA<FormatException>()));
      expect(database.transactionAttempts, 0);
      expect(database.writeCommits, 0);
    },
  );
}
