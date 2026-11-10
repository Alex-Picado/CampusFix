import 'dart:async';

import 'package:campusfix/features/incidents/models/incident.dart';
import 'package:campusfix/features/incidents/models/incident_history_action.dart';
import 'package:campusfix/features/incidents/models/incident_history_event.dart';
import 'package:campusfix/features/incidents/repositories/incident_repository.dart';
import 'package:campusfix/features/notifications/controllers/notification_controller.dart';
import 'package:campusfix/features/users/models/user_profile.dart';
import 'package:campusfix/features/users/models/user_role.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final role in UserRole.values) {
    test(
      'Unread progress persists by account, reacts live and revokes access for ${role.name}',
      () async {
        final repository = _Feed();
        final profile = UserProfile(
          id: 'me',
          fullName: 'Me',
          email: 'me@test.invalid',
          role: role,
        );
        var controller = NotificationController(
          repository: repository,
          profile: profile,
        );
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
        expect(repository.watchedRole, role);
        expect(controller.unread, 1);
        await controller.markRead(controller.entries);
        expect(controller.unread, 0);
        controller.dispose();
        controller = NotificationController(
          repository: repository,
          profile: profile,
        );
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
        expect(controller.unread, 0);
        repository.events.add(
          IncidentHistoryEvent(
            id: 'progress',
            actorUserId: 'other',
            createdAt: DateTime.utc(2026, 11, 9),
            action: IncidentHistoryAction.progressAdded,
          ),
        );
        repository.changes.add(null);
        await Future<void>.delayed(Duration.zero);
        expect(controller.unread, 1);
        repository.rows = [];
        repository.changes.add(null);
        await Future<void>.delayed(Duration.zero);
        expect(controller.entries, isEmpty);
        controller.dispose();
        await repository.changes.close();
      },
    );
  }
}

class _Feed extends Fake implements IncidentRepository {
  final changes = StreamController<void>.broadcast();
  UserRole? watchedRole;
  List<Incident> rows = [
    Incident(
      id: 'case',
      sequenceNumber: 1,
      title: 'Luz',
      description: 'Aula',
      categoryId: 'light',
      location: 'A',
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
      createdByUserId: 'me',
      assignedTechnicianId: 'me',
    ),
  ];
  final events = [
    IncidentHistoryEvent(
      id: 'assignment',
      actorUserId: 'admin',
      createdAt: DateTime.utc(2026),
      action: IncidentHistoryAction.assigned,
    ),
  ];
  Stream<T> watch<T>(T Function() value) => Stream.multi((sink) {
    sink.add(value());
    final subscription = changes.stream.listen((_) => sink.add(value()));
    sink.onCancel = subscription.cancel;
  });
  @override
  Stream<List<Incident>> watchAll() {
    watchedRole = UserRole.administrator;
    return watch(() => rows);
  }

  @override
  Stream<List<Incident>> watchOwn({required String userId}) {
    watchedRole = UserRole.reporter;
    return watch(() => rows);
  }

  @override
  Stream<List<Incident>> watchAssigned({required String userId}) {
    watchedRole = UserRole.technician;
    return watch(() => rows);
  }

  @override
  Stream<List<IncidentHistoryEvent>> watchHistory({
    required String incidentId,
  }) => watch(() => List.of(events));
}
