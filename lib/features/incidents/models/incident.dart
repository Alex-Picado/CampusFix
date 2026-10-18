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
}
