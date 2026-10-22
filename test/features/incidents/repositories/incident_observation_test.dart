import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:campusfix/features/incidents/models/incident.dart';
import 'package:campusfix/features/incidents/repositories/incident_repository.dart';
import 'package:campusfix/features/incidents/services/incident_service.dart';

import '../../../support/incident_observation.dart';

void main() {
  late ObservationFirestore database;
  late ObservationAuth auth;
  late IncidentRepository repository;
  final subscriptions = <StreamSubscription<dynamic>>[];
  final date = Timestamp.fromDate(DateTime.utc(2026, 10, 21, 12));

  Map<String, dynamic> incident({
    int sequence = 1,
    Timestamp? createdAt,
    String owner = 'reporter-1',
  }) => {
    'sequenceNumber': sequence,
    'title': 'Broken light',
    'description': 'Classroom light',
    'categoryId': 'lighting',
    'location': 'Building A',
    'priority': null,
    'status': 'REPORTADA',
    'createdAt': createdAt ?? date,
    'updatedAt': date,
    'createdByUserId': owner,
    'assignedTechnicianId': null,
    'resolutionDescription': null,
  };

  Future<void> settle() => pumpEventQueue(times: 5);

  setUp(() {
    database = ObservationFirestore();
    auth = ObservationAuth();
    repository = IncidentRepository(
      incidentService: IncidentService(firestore: database, authService: auth),
    );
  });

  tearDown(() async {
    for (final subscription in subscriptions) {
      await subscription.cancel();
    }
    subscriptions.clear();
    await database.dispose();
    await auth.states.close();
  });

  test('Technician queues filter by the authenticated UID and cancel on account changes', () async {
    auth.userId = 'tech';
    final values = <List<Incident>>[];
    final errors = <Object>[];
    subscriptions.add(
      repository
          .watchAssigned(userId: 'tech')
          .listen(values.add, onError: errors.add),
    );
    await settle();
    final channel = database.queries.single;
    expect(channel.filterField, 'assignedTechnicianId');
    expect(channel.filterValue, 'tech');
    channel.emit({
      'case': {
        ...incident(),
        'assignedTechnicianId': 'tech',
        'status': 'ASIGNADA',
      },
    });
    await settle();
    expect(values.single.single.assignedTechnicianId, 'tech');
    channel.emit({'foreign': incident()});
    await settle();
    expect(errors.single, isA<FormatException>());
    auth.changeAccount('other');
    await settle();
    expect(channel.events.hasListener, isFalse);
  });

  test('Administrative queues use confirmed unfiltered snapshots and immutable lists', () async {
    auth.userId = 'admin';
    final values = <List<Incident>>[];
    subscriptions.add(repository.watchAll().listen(values.add));
    await settle();
    final channel = database.queries.single;
    expect(channel.filterField, isNull);
    channel.emit({'case': incident()}, cache: true);
    await settle();
    expect(values, isEmpty);
    channel.emit({'case': incident()});
    await settle();
    expect(values.single.single.id, 'case');
    expect(() => values.single.clear(), throwsUnsupportedError);
  });

  test('Own reports use a server UID filter date ordering and immutable parsed results', () async {
    final values = <List<Incident>>[];
    subscriptions.add(
      repository.watchOwn(userId: 'reporter-1').listen(values.add),
    );
    await settle();
    final channel = database.queries.single;
    expect(channel.path, 'incidents');
    expect(channel.filterField, 'createdByUserId');
    expect(channel.filterValue, 'reporter-1');
    expect(channel.orderField, 'createdAt');
    expect(channel.descending, isTrue);
    channel.emit({
      'old': incident(
        createdAt: Timestamp.fromDate(DateTime.utc(2026, 10, 20)),
      ),
      'second': incident(sequence: 2),
      'third': incident(sequence: 3),
    });
    await settle();
    expect(values.single.map((value) => value.id), ['third', 'second', 'old']);
    expect(values.single.first.createdAt, date.toDate());
    expect(() => values.single.clear(), throwsUnsupportedError);
  });

  test(
    'Own report updates removals and empty snapshots are emitted live',
    () async {
      final values = <List<Incident>>[];
      subscriptions.add(
        repository.watchOwn(userId: 'reporter-1').listen(values.add),
      );
      await settle();
      final channel = database.queries.single;
      channel.emit({'report': incident()});
      channel.emit({
        'report': {...incident(), 'title': 'Updated light'},
      });
      channel.emit({});
      await settle();
      expect(values.length, 3);
      expect(values[1].single.title, 'Updated light');
      expect(values.last, isEmpty);
    },
  );

  test(
    'Another UID and signed-out sessions cannot open database observations',
    () async {
      await expectLater(
        repository.watchOwn(userId: 'reporter-2'),
        emitsError(isA<StateError>()),
      );
      auth.userId = null;
      await expectLater(
        repository.watchById(incidentId: 'report'),
        emitsError(isA<FirebaseException>()),
      );
      expect(database.queries, isEmpty);
      expect(database.documents, isEmpty);
    },
  );

  test('Cached and pending query snapshots are withheld until server acknowledgement', () async {
    final values = <List<Incident>>[];
    subscriptions.add(
      repository.watchOwn(userId: 'reporter-1').listen(values.add),
    );
    await settle();
    final channel = database.queries.single;
    channel.emit({'report': incident()}, cache: true);
    channel.emit({
      'report': {...incident(), 'createdAt': null},
    }, pending: true);
    await settle();
    expect(values, isEmpty);
    channel.emit({'report': incident()});
    await settle();
    expect(values.single.single.id, 'report');
  });

  test('A detail distinguishes confirmed absence from cached absence and later updates', () async {
    final values = <Incident?>[];
    subscriptions.add(
      repository.watchById(incidentId: 'report').listen(values.add),
    );
    await settle();
    final channel = database.documents.single;
    expect(channel.path, 'incidents/report');
    channel.emit(null, cache: true);
    await settle();
    expect(values, isEmpty);
    channel.emit(null);
    channel.emit(incident());
    channel.emit({
      ...incident(),
      'status': 'EN_ATENCION',
      'assignedTechnicianId': 'technician-1',
    });
    await settle();
    expect(values.length, 3);
    expect(values.first, isNull);
    expect(values[1]!.title, 'Broken light');
    expect(values.last!.assignedTechnicianId, 'technician-1');
  });

  test(
    'History and progress are normalized chronological immutable lists',
    () async {
      final history = <dynamic>[];
      final progress = <dynamic>[];
      subscriptions.add(
        repository.watchHistory(incidentId: 'report').listen(history.add),
      );
      subscriptions.add(
        repository.watchProgress(incidentId: 'report').listen(progress.add),
      );
      await settle();
      final historyChannel = database.queries.firstWhere(
        (channel) => channel.path.endsWith('/history'),
      );
      final progressChannel = database.queries.firstWhere(
        (channel) => channel.path.endsWith('/progress'),
      );
      for (final channel in database.queries) {
        expect(channel.path.startsWith('incidents/report/'), isTrue);
        expect(channel.orderField, 'createdAt');
        expect(channel.descending, isFalse);
      }
      historyChannel.emit({
        'b': {
          'actorUserId': 'reporter-1',
          'createdAt': date,
          'action': 'created',
        },
        'a': {
          'actorUserId': 'reporter-1',
          'createdAt': date,
          'action': 'created',
        },
      });
      progressChannel.emit({
        'later': {
          'authorUserId': 'technician-1',
          'createdAt': date,
          'description': 'Replacement installed',
        },
        'earlier': {
          'authorUserId': 'technician-1',
          'createdAt': Timestamp.fromDate(DateTime.utc(2026, 10, 20)),
          'description': 'Inspection',
        },
      });
      await settle();
      expect((history.single as List).map((event) => event.id), ['a', 'b']);
      expect((progress.single as List).map((entry) => entry.id), [
        'earlier',
        'later',
      ]);
      expect(history.single.first.createdAt, date.toDate());
      expect(() => history.single.clear(), throwsUnsupportedError);
      expect(() => progress.single.clear(), throwsUnsupportedError);
    },
  );

  test(
    'Source permission errors are forwarded and terminate both subscriptions',
    () async {
      final errors = <Object>[];
      var done = false;
      subscriptions.add(
        repository
            .watchById(incidentId: 'report')
            .listen((_) {}, onError: errors.add, onDone: () => done = true),
      );
      await settle();
      final failure = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
      );
      database.documents.single.events.addError(failure);
      await settle();
      expect(errors.single, same(failure));
      expect(done, isTrue);
      expect(database.documents.single.events.hasListener, isFalse);
      expect(auth.states.hasListener, isFalse);
    },
  );

  test('A confirmed record with an unresolved timestamp fails without invented dates', () async {
    final errors = <Object>[];
    subscriptions.add(
      repository
          .watchOwn(userId: 'reporter-1')
          .listen((_) {}, onError: errors.add),
    );
    await settle();
    database.queries.single.emit({
      'report': {...incident(), 'createdAt': null},
    });
    await settle();
    expect(errors.single, isA<FormatException>());
    expect(database.queries.single.events.hasListener, isFalse);
    expect(auth.states.hasListener, isFalse);
  });

  test('Malformed model data raises an error and later valid snapshots can recover', () async {
    final errors = <Object>[];
    final values = <List<Incident>>[];
    subscriptions.add(
      repository
          .watchOwn(userId: 'reporter-1')
          .listen(values.add, onError: errors.add),
    );
    await settle();
    database.queries.single.emit({
      'report': {...incident(), 'title': false},
    });
    database.queries.single.emit({'report': incident()});
    await settle();
    expect(errors.single, isA<FormatException>());
    expect(values.single.single.id, 'report');
  });

  test('An unexpected foreign author is rejected rather than silently filtered locally', () async {
    final errors = <Object>[];
    final values = <List<Incident>>[];
    subscriptions.add(
      repository
          .watchOwn(userId: 'reporter-1')
          .listen(values.add, onError: errors.add),
    );
    await settle();
    database.queries.single.emit({'foreign': incident(owner: 'reporter-2')});
    await settle();
    expect(errors.single, isA<FormatException>());
    expect(values, isEmpty);
  });

  for (final nextUser in ['reporter-2', null]) {
    test(
      'Changing the observed account to $nextUser closes private data streams',
      () async {
        final errors = <Object>[];
        final values = <Incident?>[];
        var done = false;
        subscriptions.add(
          repository
              .watchById(incidentId: 'report')
              .listen(
                values.add,
                onError: errors.add,
                onDone: () => done = true,
              ),
        );
        await settle();
        auth.changeAccount(nextUser);
        database.documents.single.emit(incident());
        await settle();
        expect(values, isEmpty);
        expect(errors, isNotEmpty);
        expect(done, isTrue);
        expect(database.documents.single.events.hasListener, isFalse);
        expect(auth.states.hasListener, isFalse);
      },
    );
  }

  test(
    'Current identity is rechecked even before an authentication event arrives',
    () async {
      final errors = <Object>[];
      final values = <Incident?>[];
      subscriptions.add(
        repository
            .watchById(incidentId: 'report')
            .listen(values.add, onError: errors.add),
      );
      await settle();
      auth.userId = 'reporter-2';
      database.documents.single.emit(incident());
      await settle();
      expect(values, isEmpty);
      expect(errors.single, isA<StateError>());
      expect(database.documents.single.events.hasListener, isFalse);
    },
  );

  test(
    'Authentication observation failures stop the document subscription',
    () async {
      final errors = <Object>[];
      subscriptions.add(
        repository
            .watchById(incidentId: 'report')
            .listen((_) {}, onError: errors.add),
      );
      await settle();
      final failure = StateError('Authentication unavailable');
      auth.states.addError(failure);
      await settle();
      expect(errors.single, same(failure));
      expect(database.documents.single.events.hasListener, isFalse);
    },
  );

  test(
    'Consumer cancellation cancels database and authentication subscriptions',
    () async {
      final subscription = repository
          .watchOwn(userId: 'reporter-1')
          .listen((_) {});
      subscriptions.add(subscription);
      await settle();
      await subscription.cancel();
      expect(database.queries.single.events.hasListener, isFalse);
      expect(auth.states.hasListener, isFalse);
    },
  );

  test('Account changes are still observed while a consumer pauses document events', () async {
    final errors = <Object>[];
    final values = <Incident?>[];
    final subscription = repository
        .watchById(incidentId: 'report')
        .listen(values.add, onError: errors.add);
    subscriptions.add(subscription);
    await settle();
    subscription.pause();
    database.documents.single.emit(incident());
    auth.changeAccount('reporter-2');
    await settle();
    subscription.resume();
    await settle();
    expect(values, isEmpty);
    expect(errors, isNotEmpty);
    expect(database.documents.single.events.hasListener, isFalse);
    expect(auth.states.hasListener, isFalse);
  });

  test(
    'Ending authentication observation also cancels the database listener',
    () async {
      final errors = <Object>[];
      subscriptions.add(
        repository
            .watchById(incidentId: 'report')
            .listen((_) {}, onError: errors.add),
      );
      await settle();
      await auth.states.close();
      await settle();
      expect(errors.single, isA<StateError>());
      expect(database.documents.single.events.hasListener, isFalse);
    },
  );

  test('An initial cache-only observation times out instead of loading indefinitely', () async {
    final errors = <Object>[];
    repository = IncidentRepository(
      incidentService: IncidentService(
        firestore: database,
        authService: auth,
        initialSnapshotTimeout: const Duration(milliseconds: 100),
      ),
    );
    final completed = Completer<void>();
    subscriptions.add(
      repository
          .watchById(incidentId: 'report')
          .listen((_) {}, onError: errors.add, onDone: completed.complete),
    );
    await settle();
    expect(database.documents.length, 1);
    database.documents.single.emit(null, cache: true);
    await completed.future.timeout(const Duration(seconds: 2));
    expect(
      errors.single,
      isA<FirebaseException>().having(
        (error) => error.code,
        'code',
        'unavailable',
      ),
    );
    expect(database.documents.single.events.hasListener, isFalse);
    expect(auth.states.hasListener, isFalse);
  });

  test(
    'Invalid paths fail before opening document or subcollection subscriptions',
    () async {
      for (final id in ['', ' ', 'a/b', '.', '..', '__reserved__']) {
        await expectLater(
          repository.watchById(incidentId: id),
          emitsError(isA<FormatException>()),
        );
        await expectLater(
          repository.watchHistory(incidentId: id),
          emitsError(isA<FormatException>()),
        );
        await expectLater(
          repository.watchProgress(incidentId: id),
          emitsError(isA<FormatException>()),
        );
      }
      expect(database.documents, isEmpty);
      expect(database.queries, isEmpty);
    },
  );
}
