import '../models/incident_status.dart';

/// Spanish presentation labels without changing stored lifecycle values.
extension IncidentStatusLabels on IncidentStatus {
  String get label => switch (this) {
    IncidentStatus.reported => 'Reportada',
    IncidentStatus.underReview => 'En revisión',
    IncidentStatus.assigned => 'Asignada',
    IncidentStatus.inProgress => 'En atención',
    IncidentStatus.resolved => 'Solución registrada',
    IncidentStatus.reviewRequested => 'Revisión solicitada',
    IncidentStatus.closed => 'Cerrada',
    IncidentStatus.rejected => 'Rechazada',
    IncidentStatus.cancelled => 'Cancelada',
    IncidentStatus.reopened => 'Reabierta',
  };

  /// Plain-language progress for the person who submitted the report.
  String get reporterGuidance => switch (this) {
    IncidentStatus.reported =>
      'Recibimos tu reporte. Está pendiente de revisión.',
    IncidentStatus.underReview =>
      'El equipo está revisando el reporte antes de asignarlo.',
    IncidentStatus.assigned =>
      'Ya tiene un técnico asignado. La atención aún no inicia.',
    IncidentStatus.inProgress => 'El técnico está trabajando en este reporte.',
    IncidentStatus.resolved => 'El técnico registró una solución. Si el problema continúa, solicitá otra revisión.',
    IncidentStatus.reviewRequested => 'Solicitaste otra revisión. Administración decidirá si se reabre el caso.',
    IncidentStatus.closed =>
      'La solución fue revisada y el reporte quedó cerrado.',
    IncidentStatus.rejected =>
      'El reporte no continuará. Consultá el motivo en el detalle.',
    IncidentStatus.cancelled =>
      'El reporte fue cancelado. Consultá el motivo en el detalle.',
    IncidentStatus.reopened =>
      'El reporte volvió a revisión para definir los siguientes pasos.',
  };
}
