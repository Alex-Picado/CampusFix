import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:campusfix/features/incidents/models/incident_evidence.dart';

void main() {
  final createdAt = DateTime.utc(2026, 10, 21, 12, 30, 45, 789, 123);

  Map<String, dynamic> evidenceData() => {
    'uploadedByUserId': 'reporter-1',
    'createdAt': createdAt,
    'provider': 'local',
    'assetId': 'incident-1/evidence-1.png',
    'url': '/incidents/incident-1/evidence/evidence-1',
    'fileName': 'Classroom light.png',
    'contentType': 'image/png',
    'sizeBytes': 1024,
    'progressId': null,
  };

  test('Serializes local metadata without image bytes or a duplicate ID', () {
    final evidence = IncidentEvidence(
      id: 'evidence-1',
      uploadedByUserId: 'reporter-1',
      createdAt: createdAt,
      assetId: 'incident-1/evidence-1.png',
      url: '/incidents/incident-1/evidence/evidence-1',
      fileName: 'Classroom light.png',
      contentType: 'image/png',
      sizeBytes: 1024,
    );

    expect(evidence.provider, 'local');
    expect(evidence.toMap(), evidenceData());
    expect(evidence.toMap().keys, isNot(contains('id')));
    expect(evidence.toMap().keys, isNot(contains('bytes')));
  });

  test('Restores progress associations and file references exactly', () {
    final data = evidenceData()
      ..['uploadedByUserId'] = 'technician-1'
      ..['progressId'] = 'progress-1'
      ..['fileName'] = 'Repair photo 01.png';
    final evidence = IncidentEvidence.fromMap(id: 'evidence-1', data: data);

    expect(evidence.id, 'evidence-1');
    expect(evidence.uploadedByUserId, 'technician-1');
    expect(evidence.progressId, 'progress-1');
    expect(evidence.assetId, 'incident-1/evidence-1.png');
    expect(evidence.url, '/incidents/incident-1/evidence/evidence-1');
    expect(
      evidence.createdAt.microsecondsSinceEpoch,
      createdAt.microsecondsSinceEpoch,
    );
    expect(evidence.toMap(), data);
  });

  test(
    'Missing progress association becomes null and extra fields are ignored',
    () {
      final data = evidenceData()
        ..remove('progressId')
        ..['id'] = 'untrusted-id'
        ..['futureField'] = true;
      final evidence = IncidentEvidence.fromMap(id: 'evidence-1', data: data);

      expect(evidence.id, 'evidence-1');
      expect(evidence.progressId, isNull);
      expect(evidence.toMap(), evidenceData());
    },
  );

  test('Accepts the three supported canonical image content types', () {
    expect(
      IncidentEvidence.supportedContentTypes,
      unorderedEquals(['image/jpeg', 'image/png', 'image/webp']),
    );

    for (final contentType in ['image/jpeg', 'image/png', 'image/webp']) {
      final evidence = IncidentEvidence.fromMap(
        id: 'evidence-1',
        data: evidenceData()..['contentType'] = contentType,
      );
      expect(evidence.contentType, contentType);
    }
  });

  test('Rejects unsupported or malformed content types', () {
    for (final contentType in <Object?>[
      'image/gif',
      'image/svg+xml',
      'text/plain',
      'image/jpg',
      '',
      1,
      null,
    ]) {
      expect(
        () => IncidentEvidence.fromMap(
          id: 'evidence-1',
          data: evidenceData()..['contentType'] = contentType,
        ),
        throwsA(isA<FormatException>()),
      );
    }
  });

  test(
    'Accepts exactly three million bytes and rejects invalid file sizes',
    () {
      expect(IncidentEvidence.maxFileSizeBytes, 3000000);
      final evidence = IncidentEvidence.fromMap(
        id: 'evidence-1',
        data: evidenceData()..['sizeBytes'] = 3000000,
      );
      expect(evidence.sizeBytes, 3000000);

      for (final size in <Object?>[3000001, 0, -1, 1024.0, '1024', null]) {
        expect(
          () => IncidentEvidence.fromMap(
            id: 'evidence-1',
            data: evidenceData()..['sizeBytes'] = size,
          ),
          throwsA(isA<FormatException>()),
          reason: 'Invalid size: $size.',
        );
      }
    },
  );

  test('Rejects nonlocal providers and missing provider metadata', () {
    for (final provider in <Object?>[
      'cloudinary',
      'firebaseStorage',
      '',
      1,
      null,
    ]) {
      expect(
        () => IncidentEvidence.fromMap(
          id: 'evidence-1',
          data: evidenceData()..['provider'] = provider,
        ),
        throwsA(isA<FormatException>()),
      );
    }
  });

  test('Rejects missing required evidence fields', () {
    for (final field in [
      'uploadedByUserId',
      'createdAt',
      'provider',
      'assetId',
      'url',
      'fileName',
      'contentType',
      'sizeBytes',
    ]) {
      expect(
        () => IncidentEvidence.fromMap(
          id: 'evidence-1',
          data: evidenceData()..remove(field),
        ),
        throwsA(isA<FormatException>()),
        reason: 'Missing $field must be rejected.',
      );
    }
  });

  test('Rejects blank identifiers references and invalid text field types', () {
    for (final field in ['uploadedByUserId', 'assetId', 'url', 'fileName']) {
      for (final value in <Object>[' \t ', 1]) {
        expect(
          () => IncidentEvidence.fromMap(
            id: 'evidence-1',
            data: evidenceData()..[field] = value,
          ),
          throwsA(isA<FormatException>()),
          reason: 'Invalid $field must be rejected.',
        );
      }
    }
    for (final progressId in <Object>[' ', 1]) {
      expect(
        () => IncidentEvidence.fromMap(
          id: 'evidence-1',
          data: evidenceData()..['progressId'] = progressId,
        ),
        throwsA(isA<FormatException>()),
      );
    }
    expect(
      () => IncidentEvidence.fromMap(id: ' ', data: evidenceData()),
      throwsA(isA<FormatException>()),
    );
  });

  test('Rejects unresolved or unnormalized evidence dates', () {
    for (final date in <Object?>[
      null,
      '2026-10-21T12:30:00Z',
      createdAt.millisecondsSinceEpoch,
      Timestamp.fromDate(createdAt),
    ]) {
      expect(
        () => IncidentEvidence.fromMap(
          id: 'evidence-1',
          data: evidenceData()..['createdAt'] = date,
        ),
        throwsA(isA<FormatException>()),
      );
    }
  });
}
