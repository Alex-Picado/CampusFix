import 'incident_priority.dart';
import 'incident_status.dart';

/// Represents an incident reported on campus.
class Incident {
  /// Unique identifier of the incident document.
  final String id;

  /// Consecutive number displayed to users.
  final int sequenceNumber;

  /// Short title describing the reported problem.
  final String title;

  /// Detailed description of the reported problem.
  final String description;

  /// Identifier of the category associated with this incident.
  final String categoryId;

  /// Location where the reported problem occurred.
  final String location;

  /// Priority assigned during administrative review, if available.
  final IncidentPriority? priority;

  /// Current state in the incident lifecycle.
  final IncidentStatus status;

  /// Time when the incident was created.
  final DateTime createdAt;

  /// Time of the most recent saved change.
  final DateTime updatedAt;

  /// Identifier of the user who reported the incident.
  final String createdByUserId;

  /// Identifier of the assigned technician, if available.
  final String? assignedTechnicianId;

  /// Solution recorded by the technician when resolving the incident.
  final String? resolutionDescription;

  /// Creates an incident with the reported state by default.
  const Incident({
    required this.id,
    required this.sequenceNumber,
    required this.title,
    required this.description,
    required this.categoryId,
    required this.location,
    required this.createdAt,
    required this.updatedAt,
    required this.createdByUserId,
    this.priority,
    this.status = IncidentStatus.reported,
    this.assignedTechnicianId,
    this.resolutionDescription,
  });

  /// Returns the agreed incident fields, excluding the document identifier.
  ///
  /// Stores enum values rather than Dart enum names and includes null optional
  /// fields. Dates remain [DateTime] values; the Firestore service must convert
  /// them to timestamps and use server timestamps for confirmed writes.
  Map<String, dynamic> toMap() {
    return {
      'sequenceNumber': sequenceNumber,
      'title': title,
      'description': description,
      'categoryId': categoryId,
      'location': location,
      'priority': priority?.value,
      'status': status.value,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'createdByUserId': createdByUserId,
      'assignedTechnicianId': assignedTechnicianId,
      'resolutionDescription': resolutionDescription,
    };
  }

  /// Creates an incident from a document ID and normalized stored fields.
  ///
  /// The service must convert confirmed Firestore timestamps to [DateTime]
  /// before calling this factory. Missing or pending dates are rejected instead
  /// of replaced with local estimates. Missing optional fields become null.
  /// Throws a [FormatException] for invalid field types, unsupported enum
  /// values, blank required text or identifiers, or a non-positive sequence.
  factory Incident.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    final sequenceNumber = data['sequenceNumber'];
    final title = data['title'];
    final description = data['description'];
    final categoryId = data['categoryId'];
    final location = data['location'];
    final priority = data['priority'];
    final status = data['status'];
    final createdAt = data['createdAt'];
    final updatedAt = data['updatedAt'];
    final createdByUserId = data['createdByUserId'];
    final assignedTechnicianId = data['assignedTechnicianId'];
    final resolutionDescription = data['resolutionDescription'];

    if (id.trim().isEmpty ||
        sequenceNumber is! int ||
        sequenceNumber <= 0 ||
        title is! String ||
        title.trim().isEmpty ||
        description is! String ||
        description.trim().isEmpty ||
        categoryId is! String ||
        categoryId.trim().isEmpty ||
        location is! String ||
        location.trim().isEmpty ||
        status is! String ||
        createdAt is! DateTime ||
        updatedAt is! DateTime ||
        createdByUserId is! String ||
        createdByUserId.trim().isEmpty ||
        (priority != null && priority is! String) ||
        (assignedTechnicianId != null &&
            (assignedTechnicianId is! String ||
                assignedTechnicianId.trim().isEmpty)) ||
        (resolutionDescription != null && resolutionDescription is! String)) {
      throw const FormatException('Invalid incident data.');
    }

    return Incident(
      id: id,
      sequenceNumber: sequenceNumber,
      title: title,
      description: description,
      categoryId: categoryId,
      location: location,
      priority: priority == null ? null : IncidentPriority.fromValue(priority),
      status: IncidentStatus.fromValue(status),
      createdAt: createdAt,
      updatedAt: updatedAt,
      createdByUserId: createdByUserId,
      assignedTechnicianId: assignedTechnicianId,
      resolutionDescription: resolutionDescription,
    );
  }

  /// Returns a copy with the requested editable fields replaced.
  ///
  /// Preserves the ID, sequence number, creator and creation time. Null arguments
  /// preserve existing fields. Use [clearPriority], [clearAssignedTechnician]
  /// or [clearResolution] to set the corresponding nullable field to null.
  /// Clear flags take precedence over supplied replacements. This method does
  /// not authorize writes or enforce lifecycle transitions.
  Incident copyWith({
    String? title,
    String? description,
    String? categoryId,
    String? location,
    IncidentPriority? priority,
    IncidentStatus? status,
    DateTime? updatedAt,
    String? assignedTechnicianId,
    String? resolutionDescription,
    bool clearPriority = false,
    bool clearAssignedTechnician = false,
    bool clearResolution = false,
  }) {
    return Incident(
      id: id,
      sequenceNumber: sequenceNumber,
      title: title ?? this.title,
      description: description ?? this.description,
      categoryId: categoryId ?? this.categoryId,
      location: location ?? this.location,
      priority: clearPriority ? null : priority ?? this.priority,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdByUserId: createdByUserId,
      assignedTechnicianId: clearAssignedTechnician
          ? null
          : assignedTechnicianId ?? this.assignedTechnicianId,
      resolutionDescription: clearResolution
          ? null
          : resolutionDescription ?? this.resolutionDescription,
    );
  }
}
