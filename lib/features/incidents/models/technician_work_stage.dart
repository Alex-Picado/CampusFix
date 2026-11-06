import 'incident_status.dart';

/// Groups a technician's assigned incidents by what work remains.
enum TechnicianWorkStage {
  newAssignments,
  inProgress,
  history;

  static TechnicianWorkStage forStatus(IncidentStatus status) =>
      switch (status) {
        IncidentStatus.inProgress => inProgress,
        IncidentStatus.resolved ||
        IncidentStatus.closed ||
        IncidentStatus.rejected ||
        IncidentStatus.cancelled => history,
        _ => newAssignments,
      };
}
