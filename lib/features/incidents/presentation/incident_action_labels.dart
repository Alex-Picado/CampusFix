import '../models/incident_history_action.dart';

/// Spanish labels shared by workflow controls and immutable history.
extension IncidentActionLabels on IncidentHistoryAction {
  String get label => switch (this) {
    IncidentHistoryAction.created => 'Incidencia reportada',
    IncidentHistoryAction.classified => 'Clasificar incidencia',
    IncidentHistoryAction.assigned => 'Asignar técnico',
    IncidentHistoryAction.started => 'Iniciar atención',
    IncidentHistoryAction.progressAdded => 'Avance registrado',
    IncidentHistoryAction.resolved => 'Resolver incidencia',
    IncidentHistoryAction.closed => 'Cerrar incidencia',
    IncidentHistoryAction.rejected => 'Rechazar incidencia',
    IncidentHistoryAction.cancelled => 'Cancelar incidencia',
    IncidentHistoryAction.reopened => 'Reabrir incidencia',
  };
}
