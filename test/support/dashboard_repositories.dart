import 'dart:async';

import 'package:campusfix/features/incidents/models/incident.dart';
import 'package:campusfix/features/incidents/models/incident_status.dart';
import 'package:campusfix/features/incidents/repositories/incident_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// Supplies one case per lifecycle state, with category totals of 4, 3 and 2.
List<Incident> dashboardFixtures() => [
  for (final (index, status) in IncidentStatus.values.indexed)
    Incident(
      id: 'case-$index',
      sequenceNumber: index + 1,
      title: 'Reporte ${index + 1}',
      description: 'Inspección del campus',
      categoryId: index < 4
          ? 'lighting'
          : index < 7
          ? 'network'
          : 'building',
      location: 'Edificio A',
      createdAt: DateTime.utc(2026, 10, 21),
      updatedAt: DateTime.utc(2026, 10, 21),
      createdByUserId: index.isEven ? 'reporter' : 'other-reporter',
      assignedTechnicianId: index.isEven ? 'tech' : null,
      status: status,
    ),
];

/// Controllable global query with observable cancellation and pending snapshots.
class TestDashboardIncidents extends Fake implements IncidentRepository {
  List<Incident> rows = dashboardFixtures();
  final changes = StreamController<List<Incident>>.broadcast();
  int calls = 0;
  int activeWatches = 0;
  bool loadImmediately = true;
  Object? watchError;

  @override
  Stream<List<Incident>> watchAll() {
    calls++;
    if (watchError != null) throw watchError!;
    return Stream.multi((sink) {
      activeWatches++;
      if (loadImmediately) sink.add(List.unmodifiable(rows));
      final subscription = changes.stream.listen(
        sink.add,
        onError: sink.addError,
        onDone: sink.close,
      );
      sink.onCancel = () {
        activeWatches--;
        subscription.cancel().ignore();
      };
    });
  }

  void replace(List<Incident> next) {
    rows = List.of(next);
    changes.add(List.unmodifiable(rows));
  }

  Future<void> close() => changes.close();
}
