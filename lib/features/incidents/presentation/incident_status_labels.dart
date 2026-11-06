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

  /// Explains the current stage without changing the shared status label.
  String get reporterExplanation => switch (this) {
    IncidentStatus.reported =>
      'Recibimos tu reporte. Está pendiente de revisión.',
    IncidentStatus.underReview =>
      'El administrador está revisando el caso antes de asignar un técnico.',
    IncidentStatus.assigned =>
      'Ya hay un técnico asignado. Falta que inicie la atención.',
    IncidentStatus.inProgress =>
      'Un técnico está atendiendo el caso. Podés consultar sus avances.',
    IncidentStatus.resolved => 'El técnico registró una solución. Falta que el administrador cierre el caso.',
    IncidentStatus.closed => 'El administrador cerró el caso.',
    IncidentStatus.rejected =>
      'El reporte no fue aceptado. Consultá el motivo en el historial.',
    IncidentStatus.cancelled =>
      'El caso fue cancelado. Consultá el motivo en el historial.',
    IncidentStatus.reopened => 'El caso volvió a revisión.',
  };
}
