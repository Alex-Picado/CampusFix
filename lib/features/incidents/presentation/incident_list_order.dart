import '../models/incident.dart';

/// Local ordering of authorized incidents.
enum IncidentListOrder {
  recent('Más recientes'),
  oldest('Más antiguas'),
  priority('Prioridad alta primero'),
  descendingNumber('Consecutivo mayor a menor'),
  ascendingNumber('Consecutivo menor a mayor');

  final String label;
  const IncidentListOrder(this.label);

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
