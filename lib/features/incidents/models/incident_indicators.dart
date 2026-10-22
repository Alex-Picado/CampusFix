import 'incident.dart';
import 'incident_status.dart';

/// Global administrative counts, independent of presentation search criteria.
class IncidentIndicators {
  final int total;
  final int open;
  final int inProgress;
  final int resolved;
  final int closed;
  final Map<String, int> byCategory;

  const IncidentIndicators._({
    required this.total,
    required this.open,
    required this.inProgress,
    required this.resolved,
    required this.closed,
    required this.byCategory,
  });

  /// Counts every record once by stable category ID, including inactive IDs.
  ///
  /// Open follows HU-17's four-state definition. In-progress is a subset of
  /// open; reopened, rejected and cancelled records contribute only to total
  /// and their category. Category names never affect grouping.
  factory IncidentIndicators.fromIncidents(Iterable<Incident> incidents) {
    var total = 0;
    var open = 0;
    var inProgress = 0;
    var resolved = 0;
    var closed = 0;
    final categories = <String, int>{};
    for (final incident in incidents) {
      total++;
      categories.update(
        incident.categoryId,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
      switch (incident.status) {
        case IncidentStatus.reported:
        case IncidentStatus.underReview:
        case IncidentStatus.assigned:
          open++;
        case IncidentStatus.inProgress:
          open++;
          inProgress++;
        case IncidentStatus.resolved:
          resolved++;
        case IncidentStatus.closed:
          closed++;
        case IncidentStatus.rejected:
        case IncidentStatus.cancelled:
        case IncidentStatus.reopened:
          break;
      }
    }
    return IncidentIndicators._(
      total: total,
      open: open,
      inProgress: inProgress,
      resolved: resolved,
      closed: closed,
      byCategory: Map.unmodifiable(categories),
    );
  }
}
