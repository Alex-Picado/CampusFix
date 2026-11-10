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
    IncidentStatus.resolved => 'Revisá la solución y aceptala si estás de acuerdo. Si el problema continúa, solicitá otra revisión.',
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

  /// Plain-language progress for the technician assigned to a case.
  String get technicianGuidance => switch (this) {
    IncidentStatus.assigned =>
      'La incidencia está lista para que iniciés la atención.',
    IncidentStatus.inProgress =>
      'La atención está en curso. Registrá los avances en el detalle.',
    IncidentStatus.resolved => 'Registraste una solución. El cierre espera la conformidad del reportante y administración.',
    IncidentStatus.reviewRequested => 'El reportante solicitó otra revisión. Administración decidirá los próximos pasos.',
    IncidentStatus.closed =>
      'La incidencia se cerró con la conformidad de las tres partes.',
    IncidentStatus.rejected =>
      'La incidencia fue rechazada. Consultá el motivo en el detalle.',
    IncidentStatus.cancelled =>
      'La incidencia fue cancelada. Consultá el motivo en el detalle.',
    IncidentStatus.reported ||
    IncidentStatus.underReview ||
    IncidentStatus.reopened =>
      'Administración está revisando la incidencia antes de continuar.',
  };

  /// Next action or context for the administrator managing a case.
  String get administratorGuidance => switch (this) {
    IncidentStatus.reported => 'El reporte espera revisión y clasificación.',
    IncidentStatus.underReview => 'Revisá el reporte y decidí cómo continuar.',
    IncidentStatus.assigned =>
      'El técnico asignado todavía no inicia la atención.',
    IncidentStatus.inProgress => 'El técnico está atendiendo la incidencia.',
    IncidentStatus.resolved =>
      'El técnico registró una solución. Revisá el cierre del caso.',
    IncidentStatus.reviewRequested => 'El reportante pidió otra revisión. Revisá el motivo y decidí si reabrir.',
    IncidentStatus.reopened =>
      'El caso volvió a revisión. Definí los siguientes pasos.',
    IncidentStatus.closed => 'La incidencia está cerrada.',
    IncidentStatus.rejected =>
      'La incidencia fue rechazada. El motivo está en el detalle.',
    IncidentStatus.cancelled =>
      'La incidencia fue cancelada. El motivo está en el detalle.',
  };
}
