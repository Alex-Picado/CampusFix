import '../models/incident.dart';
import '../models/incident_status.dart';

/// Administrative stages used by both the global summary and management tabs.
List<(String, String, List<Incident>)> administrativeIncidentStages(
  List<Incident> reports,
) => [
  (
    'Pendientes',
    'Reportes nuevos o devueltos a revisión que esperan clasificación o asignación.',
    reports
        .where(
          (item) => {
            IncidentStatus.reported,
            IncidentStatus.underReview,
            IncidentStatus.reopened,
          }.contains(item.status),
        )
        .toList(),
  ),
  (
    'Asignadas',
    'Reportes con técnico asignado cuya atención todavía no inicia.',
    reports.where((item) => item.status == IncidentStatus.assigned).toList(),
  ),
  (
    'En atención',
    'Reportes que están siendo atendidos por un técnico.',
    reports.where((item) => item.status == IncidentStatus.inProgress).toList(),
  ),
  (
    'Solucionadas',
    'El técnico registró una solución. Revisá si corresponde cerrar el caso.',
    reports.where((item) => item.status == IncidentStatus.resolved).toList(),
  ),
  (
    'Revisión solicitada',
    'El reportante pidió otra revisión. Decidí si reabrir o cerrar la solicitud.',
    reports
        .where((item) => item.status == IncidentStatus.reviewRequested)
        .toList(),
  ),
  (
    'Finalizadas',
    'Reportes cerrados, rechazados o cancelados.',
    reports
        .where(
          (item) => {
            IncidentStatus.closed,
            IncidentStatus.rejected,
            IncidentStatus.cancelled,
          }.contains(item.status),
        )
        .toList(),
  ),
];
