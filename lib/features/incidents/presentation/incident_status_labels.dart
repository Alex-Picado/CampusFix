import '../models/incident_status.dart';

/// Spanish presentation labels without changing stored lifecycle values.
extension IncidentStatusLabels on IncidentStatus {
  String get label => switch (this) {
    IncidentStatus.reported => 'Reportada',
    IncidentStatus.underReview => 'En revisión',
    IncidentStatus.assigned => 'Asignada',
    IncidentStatus.inProgress => 'En atención',
    IncidentStatus.resolved => 'Resuelta',
    IncidentStatus.closed => 'Cerrada',
    IncidentStatus.rejected => 'Rechazada',
    IncidentStatus.cancelled => 'Cancelada',
    IncidentStatus.reopened => 'Reabierta',
  };
}
