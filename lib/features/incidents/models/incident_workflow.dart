import '../../users/models/user_role.dart';
import 'incident.dart';
import 'incident_history_action.dart';
import 'incident_priority.dart';
import 'incident_status.dart';

/// An immutable operation retained, including its ID, through uncertain retries.
///
/// The expected state and date prevent a stale form from overwriting a newer
/// classification. Actors are supplied by the authenticated service, never UI.
class IncidentWorkflowCommand {
  final String eventId;
  final IncidentHistoryAction action;
  final IncidentStatus expectedStatus;
  final DateTime expectedUpdatedAt;
  final String? categoryId;
  final IncidentPriority? priority;
  final String? technicianId;

  /// Ordered backup technicians frozen with the assignment command.
  final List<String> technicianQueue;
  final String? reason;

  const IncidentWorkflowCommand({
    required this.eventId,
    required this.action,
    required this.expectedStatus,
    required this.expectedUpdatedAt,
    this.categoryId,
    this.priority,
    this.technicianId,
    this.technicianQueue = const [],
    this.reason,
  });

  /// Payload fields retained in history to distinguish identical retry attempts.
  Map<String, dynamic> get details => {
    'categoryId': categoryId,
    'priority': priority?.value,
    'technicianId': technicianId,
    if (technicianQueue.isNotEmpty) 'technicianQueue': technicianQueue,
    'reason': reason,
  };
}

/// Defines permitted actions and validates the complete lifecycle before writes.
abstract final class IncidentWorkflow {
  /// Bounds atomic security checks to one principal and four backup technicians.
  static const maxBackupTechnicians = 4;

  /// Returns the actions available to the stored role and current assignment.
  static List<IncidentHistoryAction> actions(
    Incident incident,
    UserRole role,
    String uid,
  ) {
    final status = incident.status;
    if (role == UserRole.administrator) {
      return [
        if ([
          IncidentStatus.reported,
          IncidentStatus.underReview,
        ].contains(status))
          IncidentHistoryAction.classified,
        if (status == IncidentStatus.underReview) ...[
          if (incident.priority != null) IncidentHistoryAction.assigned,
          IncidentHistoryAction.rejected,
        ],
        if ([
          IncidentStatus.reported,
          IncidentStatus.underReview,
          IncidentStatus.assigned,
          IncidentStatus.inProgress,
        ].contains(status))
          IncidentHistoryAction.cancelled,
        if (status == IncidentStatus.resolved &&
            !incident.adminApproved &&
            incident.technicianApproved)
          IncidentHistoryAction.closed,
        if ([
          IncidentStatus.resolved,
          IncidentStatus.closed,
          IncidentStatus.reviewRequested,
        ].contains(status))
          IncidentHistoryAction.reopened,
        if (status == IncidentStatus.reviewRequested)
          IncidentHistoryAction.reviewDismissed,
      ];
    }
    if (role == UserRole.technician && incident.assignedTechnicianId == uid) {
      return [
        if (status == IncidentStatus.assigned) IncidentHistoryAction.started,
        if (status == IncidentStatus.inProgress) IncidentHistoryAction.resolved,
        if ([
          IncidentStatus.assigned,
          IncidentStatus.inProgress,
        ].contains(status))
          IncidentHistoryAction.assignmentDeclined,
      ];
    }
    if (role == UserRole.reporter && incident.createdByUserId == uid) {
      return [
        if (status == IncidentStatus.resolved &&
            !incident.reporterApproved &&
            incident.technicianApproved)
          IncidentHistoryAction.solutionAccepted,
        if ([IncidentStatus.resolved, IncidentStatus.closed].contains(status))
          IncidentHistoryAction.reviewRequested,
      ];
    }
    return const [];
  }

  /// Produces only the mutable fields for a valid, current command.
  ///
  /// Throws [StateError] for stale or unauthorized operations and
  /// [FormatException] for missing or extraneous fields. The service separately
  /// verifies that selected categories are active and assignees are technicians.
  static Map<String, dynamic> changes(
    Incident incident,
    IncidentWorkflowCommand command,
    UserRole role,
    String uid, {
    Set<String> unavailableTechnicianIds = const {},
  }) {
    if (incident.status != command.expectedStatus ||
        incident.updatedAt != command.expectedUpdatedAt) {
      throw StateError(
        'The incident changed. Refresh before submitting again.',
      );
    }
    if (!actions(incident, role, uid).contains(command.action)) {
      throw StateError(
        'This action is not permitted for the current incident.',
      );
    }
    final action = command.action;
    final classification = action == IncidentHistoryAction.classified;
    final assignment = action == IncidentHistoryAction.assigned;
    if (command.technicianQueue.length > maxBackupTechnicians ||
        command.technicianQueue.toSet().length !=
            command.technicianQueue.length ||
        command.technicianQueue.contains(command.technicianId) ||
        command.technicianQueue.any(
          (id) => id.trim().isEmpty || id.contains('/'),
        ) ||
        (!assignment && command.technicianQueue.isNotEmpty)) {
      throw const FormatException('Invalid backup technician order.');
    }
    final remaining = incident.technicianQueue
        .skipWhile(unavailableTechnicianIds.contains)
        .toList();
    final nextTechnician = remaining.firstOrNull;
    final needsReason = [
      IncidentHistoryAction.resolved,
      IncidentHistoryAction.rejected,
      IncidentHistoryAction.cancelled,
      IncidentHistoryAction.reopened,
      IncidentHistoryAction.reviewRequested,
      IncidentHistoryAction.reviewDismissed,
      IncidentHistoryAction.assignmentDeclined,
    ].contains(action);
    if ((classification &&
            (command.categoryId == null || command.priority == null)) ||
        (!classification &&
            (command.categoryId != null || command.priority != null)) ||
        (assignment != (command.technicianId != null)) ||
        (needsReason != (command.reason != null)) ||
        (command.reason != null && command.reason!.trim().isEmpty)) {
      throw const FormatException('Invalid workflow fields.');
    }
    final status = switch (action) {
      IncidentHistoryAction.classified ||
      IncidentHistoryAction.reopened => IncidentStatus.underReview,
      IncidentHistoryAction.assignmentDeclined =>
        nextTechnician == null
            ? IncidentStatus.underReview
            : IncidentStatus.assigned,
      IncidentHistoryAction.reviewRequested => IncidentStatus.reviewRequested,
      IncidentHistoryAction.assigned => IncidentStatus.assigned,
      IncidentHistoryAction.started => IncidentStatus.inProgress,
      IncidentHistoryAction.resolved => IncidentStatus.resolved,
      IncidentHistoryAction.closed =>
        incident.reporterApproved && incident.technicianApproved
            ? IncidentStatus.closed
            : IncidentStatus.resolved,
      IncidentHistoryAction.solutionAccepted =>
        incident.adminApproved && incident.technicianApproved
            ? IncidentStatus.closed
            : IncidentStatus.resolved,
      IncidentHistoryAction.reviewDismissed => IncidentStatus.resolved,
      IncidentHistoryAction.rejected => IncidentStatus.rejected,
      IncidentHistoryAction.cancelled => IncidentStatus.cancelled,
      _ => throw const FormatException('Unsupported workflow action.'),
    };
    if (assignment && incident.priority == null) {
      throw const FormatException(
        'Classification is required before assignment.',
      );
    }
    return {
      'status': status.value,
      if (classification) 'categoryId': command.categoryId,
      if (classification) 'priority': command.priority!.value,
      if (assignment) ...{
        'assignedTechnicianId': command.technicianId,
        'technicianQueue': command.technicianQueue,
      },
      if (action == IncidentHistoryAction.assignmentDeclined) ...{
        'assignedTechnicianId': nextTechnician,
        'technicianQueue': remaining.skip(1).toList(),
      },
      if (action == IncidentHistoryAction.resolved)
        'resolutionDescription': command.reason,
      if (action == IncidentHistoryAction.resolved) ...{
        'technicianApproved': true,
        'reporterApproved': false,
        'adminApproved': false,
      },
      if (action == IncidentHistoryAction.closed) 'adminApproved': true,
      if (action == IncidentHistoryAction.solutionAccepted)
        'reporterApproved': true,
      if ([
        IncidentHistoryAction.reviewRequested,
        IncidentHistoryAction.reviewDismissed,
      ].contains(action)) ...{
        'reporterApproved': false,
        'adminApproved': false,
      },
      if (action == IncidentHistoryAction.reopened) ...{
        'technicianApproved': false,
        'reporterApproved': false,
        'adminApproved': false,
        'assignedTechnicianId': null,
        'technicianQueue': <String>[],
        'priority': null,
        'resolutionDescription': null,
      },
    };
  }
}
