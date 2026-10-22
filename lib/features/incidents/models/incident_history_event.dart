import 'incident_history_action.dart';
import 'incident_status.dart';

/// Represents an immutable event in an incident's chronological history.
class IncidentHistoryEvent {
  /// Identifier of the event document within its incident.
  final String id;

  /// Identifier of the account that performed the recorded action.
  final String actorUserId;

  /// Confirmed time when the event was recorded.
  final DateTime createdAt;

  /// Action represented by the event.
  final IncidentHistoryAction action;

  /// Incident status before the action, if applicable.
  final IncidentStatus? fromStatus;

  /// Incident status after the action, if applicable.
  final IncidentStatus? toStatus;

  /// Assigned technician before the action, if applicable.
  final String? fromTechnicianId;

  /// Assigned technician after the action, if applicable.
  final String? toTechnicianId;

  /// Explanation associated with the action, if applicable.
  final String? reason;

  /// Workflow payload used to reconcile retries and show classification changes.
  final Map<String, dynamic>? details;

  /// Solution preserved before reopening clears the current resolution.
  final String? previousResolutionDescription;

  /// Creates an event with optional previous and resulting values.
  const IncidentHistoryEvent({
    required this.id,
    required this.actorUserId,
    required this.createdAt,
    required this.action,
    this.fromStatus,
    this.toStatus,
    this.fromTechnicianId,
    this.toTechnicianId,
    this.reason,
    this.details,
    this.previousResolutionDescription,
  });

  /// Returns history fields with stored action and status values.
  ///
  /// Excludes the document ID and includes null optional fields. Dates remain
  /// [DateTime] values. Serialization does not enforce lifecycle transitions.
  Map<String, dynamic> toMap() {
    return {
      'actorUserId': actorUserId,
      'createdAt': createdAt,
      'action': action.value,
      'fromStatus': fromStatus?.value,
      'toStatus': toStatus?.value,
      'fromTechnicianId': fromTechnicianId,
      'toTechnicianId': toTechnicianId,
      'reason': reason,
      if (details != null) 'details': details,
      if (details != null || previousResolutionDescription != null)
        'previousResolutionDescription': previousResolutionDescription,
    };
  }

  /// Parses history fields after timestamp normalization by the service.
  ///
  /// Missing optional fields become null. Throws a [FormatException] for
  /// invalid types, blank identifiers or reasons, unsupported action or status
  /// values, or a missing or unresolved date.
  factory IncidentHistoryEvent.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    final actorUserId = data['actorUserId'];
    final createdAt = data['createdAt'];
    final action = data['action'];
    final fromStatus = data['fromStatus'];
    final toStatus = data['toStatus'];
    final fromTechnicianId = data['fromTechnicianId'];
    final toTechnicianId = data['toTechnicianId'];
    final reason = data['reason'];
    final details = data['details'];
    final previousResolution = data['previousResolutionDescription'];

    if ((details != null && details is! Map<String, dynamic>) ||
        (previousResolution != null && previousResolution is! String) ||
        id.trim().isEmpty ||
        actorUserId is! String ||
        actorUserId.trim().isEmpty ||
        createdAt is! DateTime ||
        action is! String ||
        (fromStatus != null && fromStatus is! String) ||
        (toStatus != null && toStatus is! String) ||
        (fromTechnicianId != null &&
            (fromTechnicianId is! String || fromTechnicianId.trim().isEmpty)) ||
        (toTechnicianId != null &&
            (toTechnicianId is! String || toTechnicianId.trim().isEmpty)) ||
        (reason != null && (reason is! String || reason.trim().isEmpty))) {
      throw const FormatException('Invalid incident history data.');
    }

    return IncidentHistoryEvent(
      id: id,
      actorUserId: actorUserId,
      createdAt: createdAt,
      action: IncidentHistoryAction.fromValue(action),
      fromStatus: fromStatus == null
          ? null
          : IncidentStatus.fromValue(fromStatus),
      toStatus: toStatus == null ? null : IncidentStatus.fromValue(toStatus),
      fromTechnicianId: fromTechnicianId,
      toTechnicianId: toTechnicianId,
      reason: reason,
      details: details == null
          ? null
          : Map<String, dynamic>.unmodifiable(details as Map<String, dynamic>),
      previousResolutionDescription: previousResolution as String?,
    );
  }
}
