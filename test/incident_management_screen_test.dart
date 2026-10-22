import 'dart:async';

import 'package:campusfix/app/providers/app_providers.dart';
import 'package:campusfix/features/incidents/models/incident.dart';
import 'package:campusfix/features/incidents/models/incident_history_action.dart';
import 'package:campusfix/features/incidents/models/incident_history_event.dart';
import 'package:campusfix/features/incidents/models/incident_priority.dart';
import 'package:campusfix/features/incidents/models/incident_progress.dart';
import 'package:campusfix/features/incidents/models/incident_status.dart';
import 'package:campusfix/features/incidents/models/incident_workflow.dart';
import 'package:campusfix/features/incidents/repositories/incident_repository.dart';
import 'package:campusfix/features/users/models/user_profile.dart';
import 'package:campusfix/features/users/models/user_role.dart';
import 'package:campusfix/main.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/report_repositories.dart';
import 'support/test_repositories.dart';

void main() {
  testWidgets(
    'Administrator and assigned technician complete classification through reopening in the real UI',
    (tester) async {
      final app = await _mount(tester);
      await _tapText(tester, 'Abrir incidencia');
      await _tapKey(tester, 'workflow-save');
      expect(
        find.text('Seleccioná una categoría activa y una prioridad.'),
        findsOneWidget,
      );
      await _choose<IncidentPriority>(tester, 'ALTA');
      await _tapKey(tester, 'workflow-save');
      expect(app.reports.incident.status, IncidentStatus.underReview);
      await _choose<IncidentHistoryAction>(tester, 'Asignar técnico');
      await _choose<String>(tester, 'tech · tech@test.invalid');
      await _tapKey(tester, 'workflow-save');
      expect(app.reports.incident.assignedTechnicianId, 'tech');
      app.auth.setUser('tech');
      await tester.pumpAndSettle();
      await _tapKey(tester, 'workflow-save');
      expect(app.reports.incident.status, IncidentStatus.inProgress);
      await _tapKey(tester, 'workflow-save');
      expect(find.text('Escribí la solución realizada.'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const ValueKey('workflow-reason')));
      await tester.enterText(
        find.byKey(const ValueKey('workflow-reason')),
        'Reemplacé la luminaria',
      );
      await _tapKey(tester, 'workflow-save');
      expect(app.reports.incident.status, IncidentStatus.resolved);
      app.auth.setUser('admin');
      await tester.pumpAndSettle();
      await _tapKey(tester, 'workflow-save');
      expect(app.reports.incident.status, IncidentStatus.closed);
      await tester.enterText(
        find.byKey(const ValueKey('workflow-reason')),
        'La falla volvió',
      );
      await _tapKey(tester, 'workflow-save');
      expect(app.reports.incident.status, IncidentStatus.underReview);
      expect(app.reports.incident.priority, isNull);
      expect(app.reports.incident.assignedTechnicianId, isNull);
      expect(
        app.reports.history.last.previousResolutionDescription,
        'Reemplacé la luminaria',
      );
      expect(
        find.text('Solución anterior: Reemplacé la luminaria'),
        findsOneWidget,
      );
      expect(app.reports.history.map((event) => event.actorUserId), [
        'admin',
        'admin',
        'tech',
        'tech',
        'admin',
        'admin',
      ]);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Uncertain saves freeze one command, retain errors through snapshots and retry without duplicates',
    (tester) async {
      final app = await _mount(tester);
      await _tapText(tester, 'Abrir incidencia');
      await _choose<IncidentPriority>(tester, 'ALTA');
      app.reports.failure = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
      );
      app.reports.commitBeforeError = true;
      await _tapKey(tester, 'workflow-save');
      expect(find.byKey(const ValueKey('workflow-retry')), findsOneWidget);
      final original = app.reports.submissions.single;
      app.reports.changes.add(null);
      await tester.pumpAndSettle();
      expect(
        find.text('El servicio no está disponible. Intentá nuevamente.'),
        findsOneWidget,
      );
      app.reports.failure = null;
      await _tapKey(tester, 'workflow-retry');
      expect(app.reports.submissions, [original, original]);
      expect(app.reports.history, hasLength(1));
      expect(find.text('Cambio guardado correctamente.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Sign-out clears private state and ignores a pending submission completion',
    (tester) async {
      final app = await _mount(tester);
      await _tapText(tester, 'Abrir incidencia');
      await _choose<IncidentPriority>(tester, 'ALTA');
      final blocker = Completer<void>();
      app.reports.blocker = blocker;
      await tester.ensureVisible(find.byKey(const ValueKey('workflow-save')));
      await tester.tap(find.byKey(const ValueKey('workflow-save')));
      await tester.pump();
      app.auth.setUser(null);
      await tester.pumpAndSettle();
      expect(app.reports.active, 0);
      expect(app.users.activeAllUsersWatches, 0);
      blocker.complete();
      await tester.pumpAndSettle();
      expect(find.text('Cambio guardado correctamente.'), findsNothing);
      expect(find.byKey(const ValueKey('auth-email')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'A live administrator role downgrade removes workflow sources and controls',
    (tester) async {
      final app = await _mount(tester);
      await _tapText(tester, 'Abrir incidencia');
      expect(app.users.activeAllUsersWatches, 1);
      app.users.put(
        const UserProfile(
          id: 'admin',
          fullName: 'admin',
          email: 'admin@test.invalid',
          role: UserRole.reporter,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('workflow-save')), findsNothing);
      expect(app.users.activeAllUsersWatches, 0);
      expect(app.reports.active, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Cancellation requires a reason and leaves no further workflow actions',
    (tester) async {
      final app = await _mount(tester);
      await _tapText(tester, 'Abrir incidencia');
      await _choose<IncidentHistoryAction>(tester, 'Cancelar incidencia');
      await _tapKey(tester, 'workflow-save');
      expect(find.text('Escribí el motivo de la operación.'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('workflow-reason')),
        'Duplicado',
      );
      await _tapKey(tester, 'workflow-save');
      expect(app.reports.incident.status, IncidentStatus.cancelled);
      expect(find.byKey(const ValueKey('workflow-save')), findsNothing);
      expect(app.reports.history.single.reason, 'Duplicado');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Technician queues show only assigned cases and recover from read errors on a tablet',
    (tester) async {
      final app = await _mount(tester, technician: true, tablet: true);
      expect(find.textContaining('Broken light'), findsOneWidget);
      app.reports.changes.addError(
        FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Broken light'), findsNothing);
      await _tapText(tester, 'Reintentar');
      expect(find.textContaining('Broken light'), findsOneWidget);
      app.reports.incident = app.reports.incident.copyWith(
        assignedTechnicianId: 'other',
      );
      app.reports.changes.add(null);
      await tester.pumpAndSettle();
      expect(find.text('No hay incidencias disponibles.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _tapKey(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _tapText(WidgetTester tester, String text) async {
  final finder = find.text(text);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _choose<T>(WidgetTester tester, String text) async {
  final finder = find.byWidgetPredicate(
    (widget) => widget is DropdownButtonFormField<T>,
  );
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
  await tester.tap(find.text(text).last);
  await tester.pumpAndSettle();
}

Future<({TestAuthRepository auth, TestUserRepository users, _Reports reports})>
_mount(
  WidgetTester tester, {
  bool technician = false,
  bool tablet = false,
}) async {
  tester.view.physicalSize = tablet
      ? const Size(800, 1100)
      : const Size(1440, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final users = TestUserRepository();
  for (final role in UserRole.values) {
    final id = role == UserRole.administrator
        ? 'admin'
        : role == UserRole.technician
        ? 'tech'
        : 'owner';
    users.profiles[id] = UserProfile(
      id: id,
      fullName: id,
      email: '$id@test.invalid',
      role: role,
    );
  }
  final auth = TestAuthRepository(
    users: users,
    currentUserId: technician ? 'tech' : 'admin',
  );
  final reports = _Reports(auth: auth, users: users);
  if (technician) {
    reports.incident = reports.incident.copyWith(
      status: IncidentStatus.assigned,
      assignedTechnicianId: 'tech',
      priority: IncidentPriority.high,
    );
  }
  final categories = TestReportCategories();
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await auth.close();
    await users.close();
    await reports.changes.close();
    await categories.close();
  });
  await tester.pumpWidget(
    AppProviders(
      authRepository: auth,
      userRepository: users,
      categoryRepository: categories,
      incidentRepository: reports,
      child: const MyApp(),
    ),
  );
  await tester.pumpAndSettle();
  if (tablet) {
    await tester.tap(find.byTooltip('Abrir menú'));
    await tester.pumpAndSettle();
  }
  await _tapKey(tester, technician ? 'nav-workspace' : 'nav-management');
  return (auth: auth, users: users, reports: reports);
}

class _Reports extends Fake implements IncidentRepository {
  final TestAuthRepository auth;
  final TestUserRepository users;
  final changes = StreamController<void>.broadcast();
  final history = <IncidentHistoryEvent>[];
  final submissions = <String>[];
  Completer<void>? blocker;
  Object? failure;
  bool commitBeforeError = false;
  int active = 0, ids = 0;
  Incident incident = Incident(
    id: 'case',
    sequenceNumber: 1,
    title: 'Broken light',
    description: 'Dark classroom',
    categoryId: 'lighting',
    location: 'A',
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
    createdByUserId: 'owner',
  );
  _Reports({required this.auth, required this.users});
  @override
  String newIncidentId() => 'operation-${++ids}';
  Stream<T> watch<T>(T Function() value) => Stream.multi((sink) {
    active++;
    sink.add(value());
    final subscription = changes.stream.listen((_) {
      sink.add(value());
    }, onError: sink.addError);
    sink.onCancel = () {
      active--;
      subscription.cancel().ignore();
    };
  });
  @override
  Stream<List<Incident>> watchAll() => watch(() => [incident]);
  @override
  Stream<List<Incident>> watchAssigned({required String userId}) =>
      watch(() => [if (incident.assignedTechnicianId == userId) incident]);
  @override
  Stream<Incident?> watchById({required String incidentId}) =>
      watch(() => incident);
  @override
  Stream<List<IncidentHistoryEvent>> watchHistory({
    required String incidentId,
  }) => watch(() => List.of(history));
  @override
  Stream<List<IncidentProgress>> watchProgress({required String incidentId}) =>
      watch(() => const []);
  @override
  Future<void> applyWorkflow({
    required String incidentId,
    required IncidentWorkflowCommand command,
  }) async {
    submissions.add(command.eventId);
    final uid = auth.currentUserId!;
    final role = users.profiles[uid]!.role;
    await blocker?.future;
    if (failure != null && !commitBeforeError) throw failure!;
    if (!history.any((event) => event.id == command.eventId)) {
      final before = incident;
      final fields = IncidentWorkflow.changes(before, command, role, uid);
      incident = Incident.fromMap(
        id: 'case',
        data: {
          ...before.toMap(),
          ...fields,
          'updatedAt': before.updatedAt.add(const Duration(seconds: 1)),
        },
      );
      history.add(
        IncidentHistoryEvent(
          id: command.eventId,
          actorUserId: uid,
          createdAt: incident.updatedAt,
          action: command.action,
          fromStatus: before.status,
          toStatus: incident.status,
          fromTechnicianId: before.assignedTechnicianId,
          toTechnicianId: incident.assignedTechnicianId,
          reason: command.reason,
          details: command.details,
          previousResolutionDescription:
              command.action == IncidentHistoryAction.reopened
              ? before.resolutionDescription
              : null,
        ),
      );
      changes.add(null);
    }
    if (failure != null) throw failure!;
  }
}
