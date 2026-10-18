import 'package:flutter_test/flutter_test.dart';
import 'package:campusfix/features/incidents/models/incident_status.dart';
import 'package:campusfix/features/incidents/models/incident_priority.dart';

void main() {
  test('Validates stored incident statuses', () {
    expect(IncidentStatus.fromValue('EN_ATENCION'), IncidentStatus.inProgress);

    expect(
      () => IncidentStatus.fromValue('UNKNOWN'),
      throwsA(isA<FormatException>()),
    );
  });

  test('Validates stored incident priorities', () {
    expect(IncidentPriority.fromValue('ALTA'), IncidentPriority.high);

    expect(
      () => IncidentPriority.fromValue('UNKNOWN'),
      throwsA(isA<FormatException>()),
    );
  });
}
