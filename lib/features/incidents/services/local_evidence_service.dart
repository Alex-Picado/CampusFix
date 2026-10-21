import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../models/selected_photo.dart';

/// Sends authenticated requests to the local file service without public URLs.
class LocalEvidenceService {
  final FirebaseAuth auth;
  final http.Client client;
  final Uri base;
  LocalEvidenceService({
    required this.auth,
    http.Client? client,
    String? baseUrl,
  }) : client = client ?? http.Client(),
       base = Uri.parse(
         baseUrl ??
             const String.fromEnvironment(
               'LOCAL_EVIDENCE_URL',
               defaultValue: 'http://127.0.0.1:8787',
             ),
       ) {
    if (!['http', 'https'].contains(base.scheme) ||
        !['127.0.0.1', 'localhost', '::1'].contains(base.host) ||
        base.userInfo.isNotEmpty ||
        base.query.isNotEmpty ||
        base.fragment.isNotEmpty ||
        (base.path.isNotEmpty && base.path != '/')) {
      throw const FormatException(
        'The evidence service must use a local HTTP origin.',
      );
    }
  }

  Future<http.Response> _request(
    String uid,
    String path, {
    SelectedPhoto? photo,
    String? progressId,
  }) async {
    if (auth.currentUser?.uid != uid) throw StateError('The account changed.');
    if (!RegExp(r'^/incidents/[A-Za-z0-9_-]+/evidence/[A-Za-z0-9_-]+$')
        .hasMatch(path)) {
      throw const FormatException('Invalid local evidence path.');
    }
    final token = await auth.currentUser!.getIdToken();
    if (token == null || auth.currentUser?.uid != uid) {
      throw StateError('The account changed.');
    }
    final headers = {'Authorization': 'Bearer $token'};
    late http.Response response;
    try {
      final url = base.resolve(path);
      if (photo != null) {
        headers.addAll({
          'Content-Type': photo.contentType,
          'X-File-Name': Uri.encodeComponent(photo.fileName),
        });
        if (progressId != null) headers['X-Progress-Id'] = progressId;
      }
      final request = http.Request(photo == null ? 'GET' : 'PUT', url)
        ..followRedirects = false
        ..headers.addAll(headers);
      if (photo != null) request.bodyBytes = photo.bytes;
      response = await client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(const Duration(seconds: 30));
    } catch (_) {
      throw FirebaseException(plugin: 'local_evidence', code: 'unavailable');
    }
    if (auth.currentUser?.uid != uid) throw StateError('The account changed.');
    if (response.statusCode != 200) {
      throw FirebaseException(
        plugin: 'local_evidence',
        code: switch (response.statusCode) {
          401 => 'unauthenticated',
          403 => 'permission-denied',
          404 => 'not-found',
          409 => 'already-exists',
          413 || 415 || 400 => 'invalid-argument',
          _ => 'unavailable',
        },
      );
    }
    return response;
  }

  /// Uploads original bytes under stable incident/evidence IDs for safe retries.
  Future<Map<String, dynamic>> upload(
    String uid,
    String incidentId,
    String evidenceId,
    SelectedPhoto photo, {
    String? progressId,
  }) async {
    final response = await _request(
      uid,
      '/incidents/$incidentId/evidence/$evidenceId',
      photo: photo,
      progressId: progressId,
    );
    final data = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    if (data['id'] != evidenceId ||
        data['assetId'] != '$incidentId/$evidenceId' ||
        data['url'] != '/incidents/$incidentId/evidence/$evidenceId' ||
        data['contentType'] != photo.contentType ||
        data['sizeBytes'] != photo.bytes.length ||
        data['fileName'] != photo.fileName ||
        data['progressId'] != progressId) {
      throw const FormatException('Invalid upload acknowledgement.');
    }
    data.remove('id');
    data.remove('progressId');
    return data;
  }

  /// Fetches bytes with a fresh session token; image widgets never use public URLs.
  Future<Uint8List> download(String uid, String path) async =>
      (await _request(uid, path)).bodyBytes;
}
