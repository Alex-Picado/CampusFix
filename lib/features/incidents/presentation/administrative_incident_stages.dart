import '../models/incident.dart';
import '../models/incident_status.dart';

const _pending = {
  IncidentStatus.reported,
  IncidentStatus.underReview,
  IncidentStatus.reopened,
};

const _finished = {
  IncidentStatus.closed,
  IncidentStatus.rejected,
  IncidentStatus.cancelled,
};

const _stages = [
  (
    'Pendientes',
    'Reportes nuevos o devueltos a revisión que esperan clasificación o asignación.',
    _pending,
  ),
  (
    'Asignadas',
    'Reportes con técnico asignado cuya atención todavía no inicia.',
    {IncidentStatus.assigned},
  ),
  (
    'En atención',
    'Reportes que están siendo atendidos por un técnico.',
    {IncidentStatus.inProgress},
  ),
  (
    'Solucionadas',
    'El técnico registró una solución. Revisá si corresponde cerrar el caso.',
    {IncidentStatus.resolved},
  ),
  (
    'Revisión solicitada',
    'El reportante pidió otra revisión. Decidí si reabrir o cerrar la solicitud.',
    {IncidentStatus.reviewRequested},
  ),
  ('Finalizadas', 'Reportes cerrados, rechazados o cancelados.', _finished),
];

/// Administrative states selected by a shortcut from the overview.
Set<IncidentStatus> administrativeStageStatuses(int index) =>
    index > 0 && index <= _stages.length ? _stages[index - 1].$3 : const {};

/// Administrative stages shown on the overview.
List<(String, String, List<Incident>)> administrativeIncidentStages(
  List<Incident> reports,
) => [
  for (final (label, description, statuses) in _stages)
    (
      label,
      description,
      reports.where((item) => statuses.contains(item.status)).toList(),
    ),
];

/// Quick filters on the management screen, independent of the overview cards.
enum IncidentManagementView {
  all('all', 'Todas', {}),
  action('action', 'Por gestionar', {
    ..._pending,
    IncidentStatus.resolved,
    IncidentStatus.reviewRequested,
  }),
  inProgress('in-progress', 'En curso', {
    IncidentStatus.assigned,
    IncidentStatus.inProgress,
  }),
  finished('finished', 'Finalizadas', _finished);

  final String id;
  final String label;
  final Set<IncidentStatus> statuses;

  const IncidentManagementView(this.id, this.label, this.statuses);
}

/// Local ordering of authorized incidents.
enum IncidentManagementOrder {
  recent('Más recientes'),
  oldest('Más antiguas'),
  priority('Prioridad alta primero'),
  descendingNumber('Consecutivo mayor a menor'),
  ascendingNumber('Consecutivo menor a mayor');

  final String label;
  const IncidentManagementOrder(this.label);

  int compare(Incident a, Incident b) {
    final byUpdate = b.updatedAt.compareTo(a.updatedAt);
    final byNumber = b.sequenceNumber.compareTo(a.sequenceNumber);
    final byPriority = (b.priority?.index ?? -1).compareTo(
      a.priority?.index ?? -1,
    );
    final result = switch (this) {
      recent => byUpdate,
      oldest => -byUpdate,
      priority => byPriority == 0 ? byUpdate : byPriority,
      descendingNumber => byNumber,
      ascendingNumber => -byNumber,
    };
    if (result != 0) return result;
    return byNumber == 0 ? a.id.compareTo(b.id) : byNumber;
  }
}
