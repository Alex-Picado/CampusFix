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

  /// Names each stage in terms of the reporter's request.
  String get reporterLabel => switch (this) {
    IncidentStatus.reported => 'Reporte recibido',
    IncidentStatus.underReview => 'Revisando tu solicitud',
    IncidentStatus.assigned => 'Pendiente de atención',
    IncidentStatus.inProgress => 'Atendiendo tu solicitud',
    IncidentStatus.resolved => 'Solución registrada',
    IncidentStatus.closed => 'Solicitud cerrada',
    IncidentStatus.rejected => 'Reporte no aceptado',
    IncidentStatus.cancelled => 'Solicitud cancelada',
    IncidentStatus.reopened => 'Tu solicitud volvió a revisión',
  };

  /// Explains the current stage without changing stored workflow states.
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
