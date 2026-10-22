import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../models/incident_evidence.dart';
import '../models/selected_photo.dart';
import '../services/incident_service.dart';
import '../services/local_evidence_service.dart';
import '../services/pending_evidence_store.dart';
import '../services/photo_picker.dart';

/// Validates photographs and separates local bytes from Firestore metadata.
class EvidenceRepository {
  final IncidentService incidents;
  final LocalEvidenceService files;
  StreamSubscription<dynamic>? _authentication;
  EvidenceRepository({required this.incidents, required this.files}) {
    var previous = files.auth.currentUser?.uid;
    void clearPrevious() {
      if (previous != null) {
        try {
          clearPendingUser(previous!);
        } catch (_) {
          /* Browser storage may be disabled. */
        }
      }
      previous = null;
    }

    _authentication = files.auth.authStateChanges().listen(
      (user) {
        if (previous != null && previous != user?.uid) clearPrevious();
        previous = user?.uid;
      },
      onError: (Object _) => clearPrevious(),
      onDone: clearPrevious,
    );
  }

  /// Cancels account observation and closes the authenticated HTTP client.
  void dispose() {
    _authentication?.cancel().ignore();
    files.client.close();
  }

  /// Allocates an evidence ID that can be retained through retries.
  String newId() => incidents.newIncidentId();

  /// Checks file signatures and decodes the selected image before upload.
  Future<SelectedPhoto?> selectPhoto() async {
    final selected = await pickPhoto();
    if (selected == null) return null;
    return validatePhoto(selected);
  }

  /// Validates size, filename, signature, dimensions and single-frame decoding.
  Future<SelectedPhoto> validatePhoto(SelectedPhoto selected) async {
    final bytes = selected.bytes;
    if (bytes.isEmpty || bytes.length > IncidentEvidence.maxFileSizeBytes) {
      throw const FormatException('Invalid photo size.');
    }
    final mime =
        bytes.length >= 8 &&
            bytes.take(8).join(',') == '137,80,78,71,13,10,26,10'
        ? 'image/png'
        : bytes.length >= 3 &&
              bytes[0] == 255 &&
              bytes[1] == 216 &&
              bytes[2] == 255
        ? 'image/jpeg'
        : bytes.length >= 12 &&
              ascii.decode(bytes.sublist(0, 4), allowInvalid: true) == 'RIFF' &&
              ascii.decode(bytes.sublist(8, 12), allowInvalid: true) == 'WEBP'
        ? 'image/webp'
        : null;
    if (mime == null ||
        selected.fileName.trim().isEmpty ||
        selected.fileName.length > 160 ||
        RegExp(r'[\x00-\x1f\x7f/\\]').hasMatch(selected.fileName)) {
      throw const FormatException('Invalid photograph.');
    }
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    ui.Codec? codec;
    try {
      // This API obtains intrinsic dimensions on both web and native engines.
      // It takes ownership of the encoded buffer and disposes it after decoding.
      codec = await ui.instantiateImageCodecWithSize(
        buffer,
        getTargetSize: (width, height) {
          if (width * height > 40000000) {
            throw const FormatException('Image dimensions exceed the limit.');
          }
          return ui.TargetImageSize(width: width > 1600 ? 1600 : width);
        },
      );
      if (codec.frameCount != 1) {
        throw const FormatException('Select a single-frame photograph.');
      }
      final frame = await codec.getNextFrame();
      frame.image.dispose();
    } finally {
      codec?.dispose();
    }
    return SelectedPhoto(
      bytes: bytes,
      fileName: selected.fileName,
      contentType: mime,
    );
  }

  /// Uploads bytes without committing their Firestore association.
  Future<Map<String, dynamic>> upload(
    String uid,
    String incidentId,
    String id,
    SelectedPhoto photo, {
    String? progressId,
  }) => files.upload(uid, incidentId, id, photo, progressId: progressId);

  /// Confirms an uploaded initial photograph as the report owner.
  Future<void> attach(
    String incidentId,
    String id,
    Map<String, dynamic> reference,
  ) => incidents.attachEvidence(
    incidentId: incidentId,
    evidenceId: id,
    reference: reference,
  );

  /// Observes immutable photograph metadata through the incident's permissions.
  Stream<List<IncidentEvidence>> watch(String incidentId) => incidents
      .watchEvidence(incidentId: incidentId)
      .map(
        (rows) => List.unmodifiable(
          rows.entries.map(
            (entry) =>
                IncidentEvidence.fromMap(id: entry.key, data: entry.value),
          ),
        ),
      );

  /// Downloads protected bytes for the current account.
  Future<Uint8List> download(String uid, IncidentEvidence evidence) =>
      files.download(uid, evidence.url);

  /// Persists only acknowledged references and progress text for association recovery.
  Map<String, dynamic>? recover(String uid, String incidentId, String kind) {
    try {
      final raw = readPending('campusfix:evidence:$uid:$incidentId:$kind');
      if (raw == null) return null;
      final saved = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final id = saved['id'];
      if (id is! String || !RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(id)) {
        return null;
      }
      if (kind == 'progress' && saved['description'] is! String) return null;
      if (saved['evidenceId'] != null && saved['evidenceId'] is! String) {
        return null;
      }
      if (saved['fileName'] != null && saved['fileName'] is! String) {
        return null;
      }
      if (saved['reference'] != null) {
        final reference = Map<String, dynamic>.from(saved['reference'] as Map);
        final photoId = kind == 'progress' ? saved['evidenceId'] : id;
        if (photoId is! String ||
            reference['assetId'] != '$incidentId/$photoId' ||
            reference['url'] != '/incidents/$incidentId/evidence/$photoId') {
          return null;
        }
        IncidentEvidence.fromMap(
          id: photoId,
          data: {
            ...reference,
            'provider': 'local',
            'uploadedByUserId': uid,
            'createdAt': DateTime.utc(2026),
            'progressId': kind == 'progress' ? id : null,
          },
        );
      }
      return saved;
    } catch (_) {
      return null;
    }
  }

  /// Stores or removes an account-scoped recovery journal without tokens or bytes.
  void remember(
    String uid,
    String incidentId,
    String kind,
    Map<String, dynamic>? value,
  ) {
    try {
      writePending(
        'campusfix:evidence:$uid:$incidentId:$kind',
        value == null ? null : jsonEncode(value),
      );
    } catch (_) {
      /* A full browser quota leaves the in-memory retry state intact. */
    }
  }
}
