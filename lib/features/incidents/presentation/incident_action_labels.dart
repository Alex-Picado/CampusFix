import '../models/incident_history_action.dart';

/// Spanish labels shared by workflow controls and immutable history.
extension IncidentActionLabels on IncidentHistoryAction {
  String get label => switch (this) {
    IncidentHistoryAction.created => 'Incidencia reportada',
    IncidentHistoryAction.classified => 'Clasificar incidencia',
    IncidentHistoryAction.assigned => 'Asignar técnico',
    IncidentHistoryAction.assignmentDeclined => 'Rechazar asignación',
    IncidentHistoryAction.started => 'Iniciar atención',
    IncidentHistoryAction.progressAdded => 'Avance registrado',
    IncidentHistoryAction.resolved => 'Resolver incidencia',
    IncidentHistoryAction.solutionAccepted => 'Aceptar solución',
    IncidentHistoryAction.reviewRequested => 'Solicitar nueva revisión',
    IncidentHistoryAction.reviewDismissed =>
      'Responder revisión y solicitar conformidad',
    IncidentHistoryAction.closed => 'Aprobar cierre',
    IncidentHistoryAction.rejected => 'Rechazar incidencia',
    IncidentHistoryAction.cancelled => 'Cancelar incidencia',
    IncidentHistoryAction.reopened => 'Reabrir incidencia',
  };
}
