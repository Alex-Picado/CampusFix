import 'dart:async';

import 'package:campusfix/app/providers/app_providers.dart';
import 'package:campusfix/features/catalogs/models/category.dart';
import 'package:campusfix/features/incidents/models/incident.dart';
import 'package:campusfix/features/incidents/models/incident_status.dart';
import 'package:campusfix/features/users/models/user_profile.dart';
import 'package:campusfix/features/users/models/user_role.dart';
import 'package:campusfix/main.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/report_repositories.dart';
import 'support/test_repositories.dart';

FirebaseException _unavailable() =>
    FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');

void main() {
  testWidgets(
    'Observes categories only on the report page and validates fields',
    (tester) async {
      final app = await _mount(tester);
      expect(app.categories.activeWatches, 0);
      await _openReport(tester);
      expect(app.categories.activeWatches, 1);
      await _tap(tester, 'report-submit');
      expect(find.text('Ingresá un título.'), findsOneWidget);
      expect(find.text('Describí el problema.'), findsOneWidget);
      expect(find.text('Seleccioná una categoría activa.'), findsOneWidget);
      expect(find.text('Indicá la ubicación.'), findsOneWidget);
      expect(app.incidents.requests, isEmpty);
      expect(app.incidents.allocations, 0);
      await _tap(tester, 'report-back');
      expect(app.categories.activeWatches, 0);
      expect(find.byKey(const ValueKey('my-incidents-page')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Displays loading, empty and failed categories with a usable retry',
    (tester) async {
      final app = await _mount(tester);
      app.categories.initial = null;
      await _tap(tester, 'nav-incidents');
      await tester.tap(find.byKey(const ValueKey('incidents-create')));
      await tester.pump();
      expect(find.text('Cargando categorías...'), findsOneWidget);
      expect(_submit(tester).onPressed, isNull);
      app.categories.changes.add([]);
      await tester.pumpAndSettle();
      expect(
        find.text('No hay categorías activas. Intentá nuevamente más tarde.'),
        findsOneWidget,
      );
      app.categories.changes.addError(_unavailable());
      await tester.pumpAndSettle();
      expect(
        find.text('El servicio no está disponible. Intentá nuevamente.'),
        findsOneWidget,
      );
      expect(app.categories.activeWatches, 0);
      app.categories.initial = const [
        Category(id: 'lighting', name: 'Iluminación'),
      ];
      await _tap(tester, 'report-retry-categories');
      expect(_submit(tester).onPressed, isNotNull);
      expect(app.categories.activeWatches, 1);
    },
  );

  testWidgets(
    'Creates a normalized report and clears the form for another report',
    (tester) async {
      final app = await _mount(tester);
      await _openReport(tester);
      await _fill(tester);
      await _tap(tester, 'report-submit');
      expect(app.incidents.requests.single['title'], 'Broken light');
      expect(app.incidents.requests.single['categoryId'], 'lighting');
      expect(
        find.text('Incidencia #1 guardada correctamente.'),
        findsOneWidget,
      );
      expect(_field(tester, 'title').readOnly, isTrue);
      await _tap(tester, 'report-new');
      expect(_field(tester, 'title').controller!.text, isEmpty);
      expect(_field(tester, 'description').controller!.text, isEmpty);
      expect(_field(tester, 'location').controller!.text, isEmpty);
      expect(find.text('Incidencia #1 guardada correctamente.'), findsNothing);
      await _fill(tester);
      await _tap(tester, 'report-submit');
      expect(app.incidents.allocations, 2);
      expect(
        find.text('Incidencia #2 guardada correctamente.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Locks a pending form and retries a failed submission without changing its ID',
    (tester) async {
      final app = await _mount(tester);
      await _openReport(tester);
      await _fill(tester);
      final blocker = Completer<void>();
      app.incidents.blocker = blocker;
      app.incidents.createError = _unavailable();
      addTearDown(() {
        if (!blocker.isCompleted) blocker.complete();
      });
      await tester.tap(find.byKey(const ValueKey('report-submit')));
      await tester.pump();
      expect(_submit(tester).onPressed, isNull);
      expect(_field(tester, 'description').readOnly, isTrue);
      expect(find.text('Guardando...'), findsOneWidget);
      blocker.complete();
      await tester.pumpAndSettle();
      expect(
        find.text('El servicio no está disponible. Intentá nuevamente.'),
        findsOneWidget,
      );
      expect(_field(tester, 'title').controller!.text, '  Broken light  ');
      expect(_field(tester, 'title').readOnly, isTrue);
      app.categories.changes.add([]);
      await tester.pumpAndSettle();
      expect(find.text('Iluminación'), findsOneWidget);
      app.incidents.createError = null;
      await _tap(tester, 'report-submit');
      expect(app.incidents.requests, hasLength(2));
      expect(app.incidents.requests.first, app.incidents.requests.last);
      expect(app.incidents.allocations, 1);
      expect(
        find.text('Incidencia #1 guardada correctamente.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Checks an uncertain save before unlocking edits and keeps its reserved ID',
    (tester) async {
      final app = await _mount(tester);
      await _openReport(tester);
      await _fill(tester);
      app.incidents.createError = _unavailable();
      await _tap(tester, 'report-submit');
      app.incidents.reviewError = _unavailable();
      await _tap(tester, 'report-edit');
      expect(_field(tester, 'title').readOnly, isTrue);
      app.incidents.reviewError = null;
      await _tap(tester, 'report-edit');
      expect(_field(tester, 'title').readOnly, isFalse);
      await _enter(tester, 'title', 'Updated title');
      app.incidents.createError = null;
      await _tap(tester, 'report-submit');
      expect(app.incidents.allocations, 1);
      expect(app.incidents.requests.last['title'], 'Updated title');
      expect(app.incidents.reviews, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Shows a previously saved result instead of allowing another creation',
    (tester) async {
      final app = await _mount(tester);
      await _openReport(tester);
      await _fill(tester);
      app.incidents.createError = _unavailable();
      app.incidents.saveBeforeError = true;
      await _tap(tester, 'report-submit');
      await _tap(tester, 'report-edit');
      expect(
        find.text('Incidencia #1 guardada correctamente.'),
        findsOneWidget,
      );
      expect(app.incidents.requests, hasLength(1));
      expect(_field(tester, 'title').readOnly, isTrue);
    },
  );

  testWidgets('Removes a deactivated selection without losing entered text', (
    tester,
  ) async {
    final app = await _mount(tester);
    await _openReport(tester);
    await _fill(tester);
    app.categories.changes.add(const [
      Category(id: 'plumbing', name: 'Fontanería'),
    ]);
    await tester.pumpAndSettle();
    expect(
      find.text('La categoría seleccionada dejó de estar disponible.'),
      findsOneWidget,
    );
    expect(_field(tester, 'title').controller!.text, '  Broken light  ');
    await _tap(tester, 'report-submit');
    expect(app.incidents.requests, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Leaving a pending report cannot show its result on another account',
    (tester) async {
      final app = await _mount(tester);
      await _openReport(tester);
      await _fill(tester);
      final blocker = Completer<void>();
      app.incidents.blocker = blocker;
      addTearDown(() {
        if (!blocker.isCompleted) blocker.complete();
      });
      await tester.tap(find.byKey(const ValueKey('report-submit')));
      await tester.pump();
      app.users.put(_profile('second-user'));
      app.auth.setUser('second-user');
      await tester.pumpAndSettle();
      expect(app.categories.activeWatches, 0);
      await _openReport(tester);
      blocker.complete();
      await tester.pumpAndSettle();
      expect(_field(tester, 'title').controller!.text, isEmpty);
      expect(find.text('Incidencia #1 guardada correctamente.'), findsNothing);
      app.users.put(_profile('second-user', role: UserRole.technician));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('report-page')), findsNothing);
      expect(app.categories.activeWatches, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Report fields and actions fit tablet navigation and scrolling', (
    tester,
  ) async {
    final app = await _mount(tester, size: const Size(768, 1024));
    await tester.tap(find.byTooltip('Abrir menú'));
    await tester.pumpAndSettle();
    await _openReport(tester);
    expect(
      tester.state<ScaffoldState>(find.byType(Scaffold)).isDrawerOpen,
      isFalse,
    );
    await _fill(tester);
    await _tap(tester, 'report-submit');
    expect(app.incidents.requests, hasLength(1));
    expect(find.text('Incidencia #1 guardada correctamente.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Lists only the requested owner and displays later changes and removals',
    (tester) async {
      final app = await _mount(tester);
      final older = _incident('older', 1);
      final newer = _incident('newer', 2);
      final foreign = _incident('foreign', 3, author: 'other-user');
      app.incidents.saved.addAll({
        older.id: older,
        newer.id: newer,
        foreign.id: foreign,
      });
      await _tap(tester, 'nav-incidents');
      expect(app.incidents.ownWatchUserIds, ['campus-user']);
      expect(app.incidents.activeOwnWatches, 1);
      expect(app.categories.activeWatches, 0);
      expect(find.byKey(const ValueKey('incident-foreign')), findsNothing);
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('incident-newer'))).dy,
        lessThan(
          tester.getTopLeft(find.byKey(const ValueKey('incident-older'))).dy,
        ),
      );
      app.incidents.ownChanges.add([
        newer.copyWith(status: IncidentStatus.inProgress),
        foreign,
      ]);
      await tester.pumpAndSettle();
      expect(find.text('En atención'), findsOneWidget);
      expect(find.text('Ubicación: Building A'), findsOneWidget);
      expect(find.byKey(const ValueKey('incident-older')), findsNothing);
      expect(find.byKey(const ValueKey('incident-foreign')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Distinguishes list loading and empty data and retries failed observation',
    (tester) async {
      final app = await _mount(tester);
      app.incidents.loadOwnImmediately = false;
      await tester.tap(find.byKey(const ValueKey('nav-incidents')));
      await tester.pump();
      expect(find.text('Cargando incidencias...'), findsOneWidget);
      expect(
        find.text('Todavía no tenés incidencias reportadas.'),
        findsNothing,
      );
      app.incidents.ownChanges.add([]);
      await tester.pumpAndSettle();
      expect(
        find.text('Todavía no tenés incidencias reportadas.'),
        findsOneWidget,
      );
      app.incidents.ownChanges.addError(_unavailable());
      await tester.pumpAndSettle();
      expect(app.incidents.activeOwnWatches, 0);
      expect(
        find.text('Todavía no tenés incidencias reportadas.'),
        findsNothing,
      );
      expect(
        find.text('El servicio no está disponible. Intentá nuevamente.'),
        findsOneWidget,
      );
      app.incidents.loadOwnImmediately = true;
      final report = _incident('recovered', 1);
      app.incidents.saved[report.id] = report;
      await _tap(tester, 'incidents-retry');
      expect(find.byKey(const ValueKey('incident-recovered')), findsOneWidget);
      expect(app.incidents.activeOwnWatches, 1);
      app.incidents.ownChanges.addError(_unavailable());
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('incident-recovered')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Returning from the form reads the confirmed report without a page reload',
    (tester) async {
      final app = await _mount(tester);
      await _openReport(tester);
      expect(app.incidents.activeOwnWatches, 0);
      expect(app.categories.activeWatches, 1);
      await _fill(tester);
      await _tap(tester, 'report-submit');
      await _tap(tester, 'report-back');
      expect(app.categories.activeWatches, 0);
      expect(app.incidents.activeOwnWatches, 1);
      expect(find.text('#1 · Broken light'), findsOneWidget);
      expect(find.text('Reportada'), findsOneWidget);
      expect(app.incidents.requests, hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Leaving the list cancels observation and reopening reads current records',
    (tester) async {
      final app = await _mount(tester);
      final first = _incident('old', 1);
      app.incidents.saved[first.id] = first;
      await _tap(tester, 'nav-incidents');
      expect(find.byKey(const ValueKey('incident-old')), findsOneWidget);
      await _tap(tester, 'nav-profile');
      expect(app.incidents.activeOwnWatches, 0);
      final second = _incident('new', 2);
      app.incidents.saved
        ..clear()
        ..[second.id] = second;
      app.incidents.ownChanges.add([second]);
      await _tap(tester, 'nav-incidents');
      expect(find.byKey(const ValueKey('incident-old')), findsNothing);
      expect(find.byKey(const ValueKey('incident-new')), findsOneWidget);
      expect(app.incidents.ownWatchUserIds, ['campus-user', 'campus-user']);
      expect(app.incidents.activeOwnWatches, 1);
    },
  );

  testWidgets(
    'Switching account and losing the reporter role remove private list state',
    (tester) async {
      final app = await _mount(tester);
      final first = _incident('private', 1);
      final second = _incident('second', 2, author: 'second-user');
      app.incidents.saved.addAll({first.id: first, second.id: second});
      await _tap(tester, 'nav-incidents');
      expect(find.byKey(const ValueKey('incident-private')), findsOneWidget);
      app.users.put(_profile('second-user'));
      app.auth.setUser('second-user');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('incident-private')), findsNothing);
      expect(app.incidents.activeOwnWatches, 0);
      await _tap(tester, 'nav-incidents');
      expect(find.byKey(const ValueKey('incident-second')), findsOneWidget);
      expect(find.byKey(const ValueKey('incident-private')), findsNothing);
      expect(app.incidents.ownWatchUserIds, ['campus-user', 'second-user']);
      app.users.put(_profile('second-user', role: UserRole.technician));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('my-incidents-page')), findsNothing);
      expect(app.incidents.activeOwnWatches, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Long report summaries wrap within the tablet layout', (
    tester,
  ) async {
    final app = await _mount(tester, size: const Size(768, 1024));
    final report = _incident('long', 1).copyWith(
      title: List.filled(12, 'Classroom lighting').join(' '),
      location: List.filled(8, 'Building A north hallway').join(' '),
    );
    app.incidents.saved[report.id] = report;
    await tester.tap(find.byTooltip('Abrir menú'));
    await tester.pumpAndSettle();
    await _tap(tester, 'nav-incidents');
    expect(find.byKey(const ValueKey('incident-long')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('incident-long'))).width,
      lessThanOrEqualTo(720),
    );
    await _tap(tester, 'incidents-create');
    expect(find.byKey(const ValueKey('report-page')), findsOneWidget);
    expect(app.incidents.activeOwnWatches, 0);
    expect(tester.takeException(), isNull);
  });
}

Incident _incident(String id, int sequence, {String author = 'campus-user'}) =>
    Incident(
      id: id,
      sequenceNumber: sequence,
      title: 'Report $id',
      description: 'Reported problem.',
      categoryId: 'lighting',
      location: 'Building A',
      createdAt: DateTime.utc(2026, 10, 21, 15, sequence),
      updatedAt: DateTime.utc(2026, 10, 21, 15, sequence),
      createdByUserId: author,
    );

TextField _field(WidgetTester tester, String name) =>
    tester.widget(find.byKey(ValueKey('report-$name')));
FilledButton _submit(WidgetTester tester) =>
    tester.widget(find.byKey(const ValueKey('report-submit')));

Future<void> _enter(WidgetTester tester, String name, String value) async {
  final finder = find.byKey(ValueKey('report-$name'));
  await tester.ensureVisible(finder);
  await tester.enterText(finder, value);
  await tester.pump();
}

Future<void> _tap(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _openReport(WidgetTester tester) async {
  await _tap(tester, 'nav-incidents');
  await _tap(tester, 'incidents-create');
}

Future<void> _fill(WidgetTester tester) async {
  await _enter(tester, 'title', '  Broken light  ');
  await _enter(tester, 'description', 'Does not turn on.');
  await _enter(tester, 'location', 'Building A');
  await _tap(tester, 'report-category');
  await tester.tap(find.text('Iluminación').last);
  await tester.pumpAndSettle();
}

UserProfile _profile(String id, {UserRole role = UserRole.reporter}) =>
    UserProfile(
      id: id,
      fullName: 'Reporter',
      email: '$id@example.test',
      role: role,
    );

Future<
  ({
    TestAuthRepository auth,
    TestUserRepository users,
    TestReportCategories categories,
    TestReportIncidents incidents,
  })
>
_mount(WidgetTester tester, {Size size = const Size(1280, 900)}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  final users = TestUserRepository()
    ..profiles['campus-user'] = _profile('campus-user');
  final auth = TestAuthRepository(users: users, currentUserId: 'campus-user');
  final categories = TestReportCategories();
  final incidents = TestReportIncidents(author: () => auth.currentUserId!);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await auth.close();
    await users.close();
    await categories.close();
    await incidents.close();
  });
  await tester.pumpWidget(
    AppProviders(
      authRepository: auth,
      userRepository: users,
      categoryRepository: categories,
      incidentRepository: incidents,
      child: const MyApp(),
    ),
  );
  await tester.pumpAndSettle();
  return (
    auth: auth,
    users: users,
    categories: categories,
    incidents: incidents,
  );
}
