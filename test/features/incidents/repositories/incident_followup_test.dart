import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:campusfix/features/incidents/services/incident_service.dart';

import '../../../support/incident_firestore.dart';

void main() {
  late IncidentTestFirestore database;
  late IncidentTestAuth auth;
  late IncidentService service;
  final reference = {
    'assetId': 'case/photo',
    'url': '/incidents/case/evidence/photo',
    'fileName': 'photo.png',
    'contentType': 'image/png',
    'sizeBytes': 100,
  };
  setUp(() {
    database = IncidentTestFirestore();
    auth = IncidentTestAuth()..userId = 'tech';
    database.store('users/tech', {'role': 'technician'});
    database.store('incidents/case', {
      'createdByUserId': 'reporter-1',
      'assignedTechnicianId': 'tech',
      'status': 'EN_ATENCION',
    });
    service = IncidentService(firestore: database, authService: auth);
  });
  Future<void> save({
    String description = 'Inspection complete',
    bool photo = true,
  }) => service.addProgress(
    incidentId: 'case',
    progressId: 'p1',
    description: description,
    evidenceId: photo ? 'photo' : null,
    reference: photo ? reference : null,
  );

  test(
    'Commits progress history and photograph metadata in one atomic write',
    () async {
      await save();
      expect(database.writeCommits, 1);
      expect(database.documents['incidents/case/progress/p1'], {
        'authorUserId': 'tech',
        'createdAt': database.serverTime,
        'description': 'Inspection complete',
      });
      expect(
        database.documents['incidents/case/history/p1']?['action'],
        'progressAdded',
      );
      expect(
        database.documents['incidents/case/history/p1']?['reason'],
        'Inspection complete',
      );
      expect(database.documents['incidents/case/evidence/photo'], {
        ...reference,
        'provider': 'local',
        'uploadedByUserId': 'tech',
        'createdAt': database.serverTime,
        'progressId': 'p1',
      });
      await save();
      expect(database.writeCommits, 1);
    },
  );
  test(
    'A rejected transaction leaves no partial progress, history or evidence',
    () async {
      database.nextCommitError = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
      );
      await expectLater(save(), throwsA(isA<FirebaseException>()));
      expect(
        database.documents.keys.where(
          (path) => path.startsWith('incidents/case/'),
        ),
        isEmpty,
      );
      await save();
      expect(database.writeCommits, 1);
    },
  );
  test(
    'Lost confirmation retries the same progress without another history event',
    () async {
      database.nextServerReadError = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
      );
      await expectLater(save(photo: false), throwsA(isA<FirebaseException>()));
      await save(photo: false);
      expect(database.writeCommits, 1);
      await expectLater(
        save(description: 'Different', photo: false),
        throwsFormatException,
      );
    },
  );
  test(
    'Rejects changed assignment, stored role and non-attention state',
    () async {
      database.store('incidents/case', {
        'assignedTechnicianId': 'other',
        'status': 'EN_ATENCION',
      });
      await expectLater(save(), throwsA(isA<FirebaseException>()));
      database.store('incidents/case', {
        'assignedTechnicianId': 'tech',
        'status': 'RESUELTA',
      });
      await expectLater(save(), throwsA(isA<FirebaseException>()));
      database.store('incidents/case', {
        'assignedTechnicianId': 'tech',
        'status': 'EN_ATENCION',
      });
      database.store('users/tech', {'role': 'reporter'});
      await expectLater(save(), throwsA(isA<FirebaseException>()));
      expect(database.writeCommits, 0);
    },
  );
  test('Associates initial evidence as the owner and recovers a lost acknowledgement', () async {
    auth.userId = 'reporter-1';
    database.nextServerReadError = FirebaseException(
      plugin: 'cloud_firestore',
      code: 'unavailable',
    );
    await expectLater(
      service.attachEvidence(
        incidentId: 'case',
        evidenceId: 'photo',
        reference: reference,
      ),
      throwsA(isA<FirebaseException>()),
    );
    await service.attachEvidence(
      incidentId: 'case',
      evidenceId: 'photo',
      reference: reference,
    );
    expect(database.writeCommits, 1);
    expect(
      database.documents['incidents/case/evidence/photo']?['progressId'],
      isNull,
    );
    auth.userId = 'tech';
    await expectLater(
      service.attachEvidence(
        incidentId: 'case',
        evidenceId: 'other',
        reference: reference,
      ),
      throwsA(isA<FirebaseException>()),
    );
  });
  test(
    'Account changes during confirmation cannot expose progress success',
    () async {
      database.beforeServerRead = (_) => auth.userId = 'other';
      await expectLater(save(), throwsStateError);
      expect(
        database.documents['incidents/case/progress/p1']?['authorUserId'],
        'tech',
      );
    },
  );
}
