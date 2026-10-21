import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:campusfix/features/incidents/models/selected_photo.dart';
import 'package:campusfix/features/incidents/repositories/evidence_repository.dart';
import 'package:campusfix/features/incidents/services/local_evidence_service.dart';
import 'package:campusfix/features/incidents/services/incident_service.dart';

import '../../../support/incident_firestore.dart';

final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAIAAAD91JpzAAAACXBIWXMAAAPoAAAD6AG1e1JrAAAADklEQVQImWP4DwYMEAoAU7oL9W/sIDEAAAAASUVORK5CYII=',
);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Auth auth;
  setUp(() => auth = _Auth());
  tearDown(() => auth.changes.close());

  test('Sends bearer sessions and stable relative references without tokens in URLs', () async {
    final service = LocalEvidenceService(
      auth: auth,
      client: MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer session-token');
        expect(
          request.url.toString(),
          'http://127.0.0.1:8787/incidents/case/evidence/photo',
        );
        expect(request.headers['X-Progress-Id'], 'p1');
        expect(request.bodyBytes, _png);
        return http.Response(
          jsonEncode({
            'id': 'photo',
            'assetId': 'case/photo',
            'url': '/incidents/case/evidence/photo',
            'fileName': 'photo.png',
            'contentType': 'image/png',
            'sizeBytes': _png.length,
            'progressId': 'p1',
          }),
          200,
        );
      }),
    );
    addTearDown(service.client.close);
    final result = await service.upload(
      'user',
      'case',
      'photo',
      SelectedPhoto(
        bytes: _png,
        fileName: 'photo.png',
        contentType: 'image/png',
      ),
      progressId: 'p1',
    );
    expect(result['assetId'], 'case/photo');
    expect(result.containsKey('id'), isFalse);
  });
  test('Rejects foreign sessions and endpoint origins and ignores a late account response', () async {
    expect(
      () =>
          LocalEvidenceService(auth: auth, baseUrl: 'https://external.invalid'),
      throwsFormatException,
    );
    final service = LocalEvidenceService(
      auth: auth,
      client: MockClient((_) async {
        auth.user = null;
        return http.Response('image', 200);
      }),
    );
    addTearDown(service.client.close);
    await expectLater(
      service.download('foreign', '/incidents/case/evidence/photo'),
      throwsStateError,
    );
    await expectLater(
      service.download('user', '/incidents/case/evidence/photo'),
      throwsStateError,
    );
  });
  test(
    'Checks real image contents and size in the client before upload',
    () async {
      final repository = EvidenceRepository(
        incidents: IncidentService(
          firestore: IncidentTestFirestore(),
          authService: IncidentTestAuth(),
        ),
        files: LocalEvidenceService(
          auth: auth,
          client: MockClient((_) async => http.Response('', 500)),
        ),
      );
      addTearDown(repository.dispose);
      final valid = await repository.validatePhoto(
        SelectedPhoto(bytes: _png, fileName: 'photo.png', contentType: ''),
      );
      expect(valid.contentType, 'image/png');
      await expectLater(
        repository.validatePhoto(
          SelectedPhoto(
            bytes: Uint8List(3000001),
            fileName: 'large.png',
            contentType: 'image/png',
          ),
        ),
        throwsFormatException,
      );
      await expectLater(
        repository.validatePhoto(
          SelectedPhoto(
            bytes: Uint8List.fromList(utf8.encode('<svg/>')),
            fileName: 'fake.png',
            contentType: 'image/png',
          ),
        ),
        throwsFormatException,
      );
    },
  );
  test('Recovers acknowledged metadata by account and clears private retry state on logout', () async {
    final repository = EvidenceRepository(
      incidents: IncidentService(
        firestore: IncidentTestFirestore(),
        authService: IncidentTestAuth(),
      ),
      files: LocalEvidenceService(
        auth: auth,
        client: MockClient((_) async => http.Response('', 500)),
      ),
    );
    addTearDown(repository.dispose);
    await Future<void>.delayed(Duration.zero);
    repository.remember('user', 'case', 'report', {
      'id': 'photo',
      'fileName': 'photo.png',
      'reference': null,
    });
    expect(repository.recover('user', 'case', 'report')?['id'], 'photo');
    expect(repository.recover('other', 'case', 'report'), isNull);
    auth.user = null;
    auth.changes.add(null);
    await Future<void>.delayed(Duration.zero);
    expect(repository.recover('user', 'case', 'report'), isNull);
    repository.remember('user', 'case', 'report', {'id': 12});
    expect(repository.recover('user', 'case', 'report'), isNull);
  });
}

class _Auth extends Fake implements FirebaseAuth {
  User? user = _User();
  final changes = StreamController<User?>.broadcast();
  @override
  User? get currentUser => user;
  @override
  Stream<User?> authStateChanges() => Stream.multi((sink) {
    sink.add(user);
    final subscription = changes.stream.listen(sink.add);
    sink.onCancel = subscription.cancel;
  });
}

class _User extends Fake implements User {
  @override
  String get uid => 'user';
  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async =>
      'session-token';
}
