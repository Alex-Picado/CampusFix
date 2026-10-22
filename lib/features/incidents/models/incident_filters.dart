import 'incident.dart';
import 'incident_priority.dart';
import 'incident_status.dart';

/// Available administrative priority choices, including unclassified reports.
enum IncidentPriorityFilter {
  /// Includes assigned and missing priorities.
  all(null),

  /// Includes only reports without a priority.
  withoutPriority(null),

  /// Includes low-priority reports.
  low(IncidentPriority.low),

  /// Includes medium-priority reports.
  medium(IncidentPriority.medium),

  /// Includes high-priority reports.
  high(IncidentPriority.high);

  /// Stored incident priority for a specific choice; null for aggregate choices.
  final IncidentPriority? priority;
  const IncidentPriorityFilter(this.priority);
}

/// Immutable administrative criteria combined with local search using AND.
///
/// These criteria never authorize reads or change incident records.
class IncidentFilters {
  /// Exact lifecycle state, or null for every state.
  final IncidentStatus? status;

  /// Includes a specific priority, all priorities, or only missing priorities.
  final IncidentPriorityFilter priority;

  /// Exact responsible UID; null when not restricting to one technician.
  final String? technicianId;

  /// Whether only incidents with no assigned technician should match.
  final bool unassignedOnly;

  /// Creates criteria; an unassigned-only choice cannot also specify a UID.
  const IncidentFilters({
    this.status,
    this.priority = IncidentPriorityFilter.all,
    this.technicianId,
    this.unassignedOnly = false,
  }) : assert(!unassignedOnly || technicianId == null);

  /// Whether at least one administrative criterion restricts the source.
  bool get hasCriteria =>
      status != null ||
      priority != IncidentPriorityFilter.all ||
      technicianId != null ||
      unassignedOnly;

  /// Checks all criteria, treating missing priority and assignment explicitly.
  bool matches(Incident incident) {
    if (status != null && incident.status != status) return false;
    if (priority == IncidentPriorityFilter.withoutPriority &&
        incident.priority != null) {
      return false;
    }
    if (priority.priority != null && incident.priority != priority.priority) {
      return false;
    }
    if (unassignedOnly && incident.assignedTechnicianId != null) return false;
    if (technicianId != null && incident.assignedTechnicianId != technicianId) {
      return false;
    }
    return true;
  }

  /// Copies criteria, with explicit flags to clear nullable state or UID values.
  ///
  /// Callers changing assignment must also set [unassignedOnly] consistently.
  IncidentFilters copyWith({
    IncidentStatus? status,
    bool clearStatus = false,
    IncidentPriorityFilter? priority,
    String? technicianId,
    bool clearTechnician = false,
    bool? unassignedOnly,
  }) => IncidentFilters(
    status: clearStatus ? null : status ?? this.status,
    priority: priority ?? this.priority,
    technicianId: clearTechnician ? null : technicianId ?? this.technicianId,
    unassignedOnly: unassignedOnly ?? this.unassignedOnly,
  );
}
