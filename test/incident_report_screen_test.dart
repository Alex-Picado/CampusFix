import 'dart:async';

import 'package:campusfix/app/providers/app_providers.dart';
import 'package:campusfix/features/catalogs/models/category.dart';
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
      await _tap(tester, 'nav-incidents');
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
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Displays loading, empty and failed categories with a usable retry',
    (tester) async {
      final app = await _mount(tester);
      app.categories.initial = null;
      await tester.tap(find.byKey(const ValueKey('nav-incidents')));
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
      await _tap(tester, 'nav-incidents');
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
      await _tap(tester, 'nav-incidents');
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
      await _tap(tester, 'nav-incidents');
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
      await _tap(tester, 'nav-incidents');
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
    await _tap(tester, 'nav-incidents');
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
      await _tap(tester, 'nav-incidents');
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
      await _tap(tester, 'nav-incidents');
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
    await _tap(tester, 'nav-incidents');
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
}

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
