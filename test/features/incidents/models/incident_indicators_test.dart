import 'package:campusfix/features/incidents/models/incident_indicators.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/dashboard_repositories.dart';

void main() {
  test('Nine statuses produce the agreed global and category totals', () {
    final result = IncidentIndicators.fromIncidents(dashboardFixtures());
    expect(result.total, 9);
    expect(result.open, 4);
    expect(result.inProgress, 1);
    expect(result.resolved, 1);
    expect(result.closed, 1);
    expect(result.byCategory, {'lighting': 4, 'network': 3, 'building': 2});
    expect(result.byCategory.values.reduce((a, b) => a + b), result.total);
  });

  test('An empty authorized snapshot has genuine zero metrics', () {
    final result = IncidentIndicators.fromIncidents([]);
    expect([
      result.total,
      result.open,
      result.inProgress,
      result.resolved,
      result.closed,
    ], everyElement(0));
    expect(result.byCategory, isEmpty);
  });

  test(
    'Aggregates are immutable snapshots grouped by ID rather than labels',
    () {
      final source = dashboardFixtures();
      final previous = IncidentIndicators.fromIncidents(source);
      source.removeRange(0, 4);
      final next = IncidentIndicators.fromIncidents(source);
      expect(previous.total, 9);
      expect(next.total, 5);
      expect(next.open, 0);
      expect(next.byCategory, {'network': 3, 'building': 2});
      expect(
        () => previous.byCategory['lighting'] = 100,
        throwsUnsupportedError,
      );
    },
  );
}
