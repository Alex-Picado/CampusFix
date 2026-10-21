import 'package:flutter/foundation.dart' show ChangeNotifier;

import '../../../core/errors/app_error_messages.dart';
import '../../auth/controllers/session_controller.dart';
import '../../auth/models/session_status.dart';
import '../../users/models/user_role.dart';
import '../models/selected_photo.dart';
import '../repositories/evidence_repository.dart';

/// Retains a stable upload and its association journal until confirmation.
class EvidenceUploadController extends ChangeNotifier {
  final EvidenceRepository repository;
  final SessionController session;
  final String uid;
  final String incidentId;
  SelectedPhoto? photo;
  Map<String, dynamic>? reference;
  String? id;
  String? fileName;
  String? error;
  String? success;
  bool busy = false;
  bool attempted = false;
  bool _disposed = false;
  bool _invalidated = false;
  int _version = 0;

  EvidenceUploadController({
    required this.repository,
    required this.session,
    required this.uid,
    required this.incidentId,
  }) {
    final saved = repository.recover(uid, incidentId, 'report');
    if (saved != null) {
      id = saved['id'] as String?;
      fileName = saved['fileName'] as String?;
      reference = saved['reference'] == null
          ? null
          : Map<String, dynamic>.from(saved['reference'] as Map);
      attempted = id != null;
    }
    session.addListener(_sessionChanged);
  }

  bool get active =>
      !_disposed &&
      !_invalidated &&
      session.status == SessionStatus.authenticated &&
      session.profile?.id == uid &&
      session.profile?.role == UserRole.reporter;
  bool get canSelect =>
      active && !busy && (!attempted || (photo == null && reference == null));

  /// Selects a validated photograph while retaining any pending upload identity.
  Future<void> select() async {
    if (!canSelect) return;
    final version = _version;
    busy = true;
    error = null;
    success = null;
    notifyListeners();
    try {
      final selected = await repository.selectPhoto();
      if (!active || version != _version || selected == null) return;
      if (attempted && fileName != selected.fileName) {
        throw const FormatException('Select the original photograph.');
      }
      photo = selected;
      fileName = selected.fileName;
      id ??= repository.newId();
    } catch (failure) {
      if (active && version == _version) {
        error = AppErrorMessages.fromError(failure);
      }
    } finally {
      if (active && version == _version) {
        busy = false;
        notifyListeners();
      }
    }
  }

  /// Uploads once and retries metadata association using the acknowledged reference.
  Future<void> upload() async {
    if (!active || busy || (photo == null && reference == null)) return;
    final version = _version;
    busy = true;
    attempted = true;
    error = null;
    success = null;
    _remember();
    notifyListeners();
    try {
      if (!active || version != _version) return;
      if (reference == null) {
        final result = await repository.upload(uid, incidentId, id!, photo!);
        if (!active || version != _version) return;
        reference = result;
      }
      if (!active || version != _version) return;
      _remember();
      await repository.attach(incidentId, id!, reference!);
      if (!active || version != _version) return;
      repository.remember(uid, incidentId, 'report', null);
      photo = null;
      reference = null;
      id = null;
      fileName = null;
      attempted = false;
      success = 'Fotografía guardada correctamente.';
    } catch (failure) {
      if (active && version == _version) {
        error = AppErrorMessages.fromError(failure);
      }
    } finally {
      if (active && version == _version) {
        busy = false;
        notifyListeners();
      }
    }
  }

  void _remember() => repository.remember(uid, incidentId, 'report', {
    'id': id,
    'fileName': fileName,
    'reference': reference,
  });

  void _sessionChanged() {
    if (active || _disposed) return;
    _invalidated = true;
    session.removeListener(_sessionChanged);
    _version++;
    photo = null;
    reference = null;
    id = null;
    fileName = null;
    busy = false;
    error = null;
    success = null;
    repository.remember(uid, incidentId, 'report', null);
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _version++;
    session.removeListener(_sessionChanged);
    photo = null;
    reference = null;
    id = null;
    fileName = null;
    error = null;
    success = null;
    super.dispose();
  }
}
