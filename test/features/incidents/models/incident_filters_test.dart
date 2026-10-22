import 'package:campusfix/features/incidents/models/incident.dart';
import 'package:campusfix/features/incidents/models/incident_filters.dart';
import 'package:campusfix/features/incidents/models/incident_priority.dart';
import 'package:campusfix/features/incidents/models/incident_search.dart';
import 'package:campusfix/features/incidents/models/incident_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final base = Incident(
    id: 'case',
    sequenceNumber: 12,
    title: 'Iluminación',
    description: 'Inspección del aula',
    categoryId: 'lighting',
    location: 'A',
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
    createdByUserId: 'reporter',
  );

  test('Every lifecycle state matches exactly, including alternate states', () {
    final rows = [
      for (final state in IncidentStatus.values) base.copyWith(status: state),
    ];
    for (final state in IncidentStatus.values) {
      final matches = rows
          .where(IncidentFilters(status: state).matches)
          .toList();
      expect(matches.length, 1);
      expect(matches.single.status, state);
    }
    expect(rows.where(const IncidentFilters().matches).length, 9);
  });

  test('Priority choices distinguish null low medium high and all', () {
    final rows = [
      base,
      for (final priority in IncidentPriority.values)
        base.copyWith(priority: priority),
    ];
    for (final choice in IncidentPriorityFilter.values) {
      final matches = rows
          .where(IncidentFilters(priority: choice).matches)
          .toList();
      expect(matches.length, choice == IncidentPriorityFilter.all ? 4 : 1);
      if (choice != IncidentPriorityFilter.all) {
        expect(matches.single.priority, choice.priority);
      }
    }
  });

  test('Unassigned and exact UID filters handle absent assignments without prefix matches', () {
    final rows = [
      base,
      base.copyWith(assignedTechnicianId: 'tech'),
      base.copyWith(assignedTechnicianId: 'tech-other'),
    ];
    expect(
      rows
          .where(const IncidentFilters(unassignedOnly: true).matches)
          .single
          .assignedTechnicianId,
      isNull,
    );
    expect(
      rows
          .where(const IncidentFilters(technicianId: 'tech').matches)
          .single
          .assignedTechnicianId,
      'tech',
    );
    expect(
      rows.where(const IncidentFilters(technicianId: 'missing').matches),
      isEmpty,
    );
  });

  test(
    'All five criteria combine using AND and retain immutable repository order',
    () {
      final matching = base.copyWith(
        status: IncidentStatus.inProgress,
        priority: IncidentPriority.high,
        assignedTechnicianId: 'tech',
      );
      final rows = [
        matching,
        matching.copyWith(priority: IncidentPriority.low),
        matching.copyWith(assignedTechnicianId: 'other'),
        matching.copyWith(status: IncidentStatus.resolved),
        matching.copyWith(categoryId: 'network'),
      ];
      const criteria = IncidentSearch(
        query: 'iluminacion',
        categoryId: 'lighting',
        filters: IncidentFilters(
          status: IncidentStatus.inProgress,
          priority: IncidentPriorityFilter.high,
          technicianId: 'tech',
        ),
      );
      final result = criteria.applyTo(rows);
      expect(result, [matching]);
      expect(() => result.clear(), throwsUnsupportedError);
      expect(criteria.copyWith(query: 'missing').applyTo(rows), isEmpty);
      expect(criteria.hasCriteria, true);
      expect(
        const IncidentSearch(filters: IncidentFilters(unassignedOnly: true))
            .hasCriteria,
        true,
      );
    },
  );

  test(
    'Copying and explicitly clearing one choice preserve all other criteria',
    () {
      const filters = IncidentFilters(
        status: IncidentStatus.assigned,
        priority: IncidentPriorityFilter.high,
        technicianId: 'tech',
      );
      final noStatus = filters.copyWith(clearStatus: true);
      expect(noStatus.status, isNull);
      expect(noStatus.priority, IncidentPriorityFilter.high);
      expect(noStatus.technicianId, 'tech');
      final unassigned = filters.copyWith(
        clearTechnician: true,
        unassignedOnly: true,
      );
      expect(unassigned.technicianId, isNull);
      expect(unassigned.unassignedOnly, true);
      expect(unassigned.status, IncidentStatus.assigned);
      expect(const IncidentFilters().hasCriteria, false);
    },
  );
}
