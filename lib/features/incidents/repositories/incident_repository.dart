import '../models/incident.dart';
import '../services/incident_service.dart';

/// Validates report submissions and converts confirmed incident documents.
class IncidentRepository {
  final IncidentService _incidentService;

  /// Creates a repository with the provided incident service.
  IncidentRepository({required this._incidentService});

  /// Allocates a document ID without writing a report or advancing its sequence.
  ///
  /// Retain this ID for all retries of the same submission.
  String newIncidentId() => _incidentService.newIncidentId();

  /// Creates a report or recovers a matching previously confirmed submission.
  ///
  /// Trims report text and requires nonblank fields and valid document IDs.
  /// The author is obtained from the authenticated session by the service.
  /// Returns an incident only after a server read confirms its timestamps.
  /// Retrying with the same [incidentId] does not create another sequence or
  /// history event. A different payload for an occupied ID is rejected.
  /// Propagates authentication, transaction and confirmation-read failures.
  Future<Incident> create({
    required String incidentId,
    required String title,
    required String description,
    required String categoryId,
    required String location,
  }) async {
    final normalizedTitle = title.trim();
    final normalizedDescription = description.trim();
    final normalizedLocation = location.trim();

    if (!_isDocumentId(incidentId) ||
        !_isDocumentId(categoryId) ||
        normalizedTitle.isEmpty ||
        normalizedDescription.isEmpty ||
        normalizedLocation.isEmpty) {
      throw const FormatException(
        'Valid report fields and document IDs are required.',
      );
    }

    final data = await _incidentService.create(
      incidentId: incidentId,
      title: normalizedTitle,
      description: normalizedDescription,
      categoryId: categoryId,
      location: normalizedLocation,
    );
    return Incident.fromMap(id: incidentId, data: data);
  }

  /// Checks single-segment IDs without silently changing document identity.
  bool _isDocumentId(String value) {
    return value.trim().isNotEmpty &&
        value == value.trim() &&
        !value.contains('/') &&
        value != '.' &&
        value != '..' &&
        !RegExp(r'^__.*__$').hasMatch(value);
  }
}
