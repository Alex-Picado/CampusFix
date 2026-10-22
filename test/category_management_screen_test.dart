import 'dart:async';

import 'package:campusfix/app/providers/app_providers.dart';
import 'package:campusfix/features/catalogs/controllers/category_management_controller.dart';
import 'package:campusfix/features/catalogs/repositories/category_repository.dart';
import 'package:campusfix/features/users/models/user_profile.dart';
import 'package:campusfix/features/users/models/user_role.dart';
import 'package:campusfix/main.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'support/category_service.dart';
import 'support/report_repositories.dart';
import 'support/test_repositories.dart';

void main() {
  testWidgets('Only an open administrator catalog observes all categories', (
    tester,
  ) async {
    final app = await _mount(tester, role: UserRole.reporter);
    expect(find.byKey(const ValueKey('nav-categories')), findsNothing);
    expect(app.categories.allCalls, 0);
    app.users.put(_profile(UserRole.technician));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('nav-categories')), findsNothing);
    app.users.put(_profile(UserRole.administrator));
    await tester.pumpAndSettle();
    expect(app.categories.allCalls, 0);
    await _open(tester);
    expect(app.categories.activeAllWatches, 1);
    await _tap(tester, 'nav-overview');
    expect(app.categories.activeAllWatches, 0);
    await _open(tester);
    expect(app.categories.allCalls, 2);
    app.users.put(_profile(UserRole.reporter));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('categories-page')), findsNothing);
    expect(app.categories.activeAllWatches, 0);
  });

  testWidgets(
    'Creates renames deactivates and reactivates categories through live snapshots',
    (tester) async {
      final app = await _mount(tester);
      await _open(tester);
      expect(find.text('Inactiva'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), '  Accesibilidad  ');
      await _tap(tester, 'category-save');
      expect(find.text('Categoría creada.'), findsOneWidget);
      expect(app.categories.documents['new-1'], {
        'name': 'Accesibilidad',
        'isActive': true,
      });
      await _tap(tester, 'category-edit-new-1');
      await tester.ensureVisible(find.byType(TextFormField));
      await tester.enterText(
        find.byType(TextFormField),
        '  Acceso al campus  ',
      );
      await _tap(tester, 'category-save');
      expect(find.text('Acceso al campus'), findsOneWidget);
      await _tap(tester, 'category-active-new-1');
      expect(app.categories.documents['new-1']!['isActive'], false);
      expect(app.categories.documents['new-1']!['name'], 'Acceso al campus');
      await _tap(tester, 'category-active-new-1');
      expect(app.categories.documents['new-1']!['isActive'], true);
      expect(app.categories.documents.length, 3);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Blank names never write and cancelling edit restores the creation form',
    (tester) async {
      final app = await _mount(tester);
      await _open(tester);
      await tester.enterText(find.byType(TextFormField), '   ');
      await _tap(tester, 'category-save');
      expect(find.text('Ingresá el nombre de la categoría.'), findsOneWidget);
      expect(app.categories.creates, 0);
      await _tap(tester, 'category-edit-lighting');
      expect(find.text('Editar categoría'), findsOneWidget);
      await _tap(tester, 'category-cancel');
      expect(find.text('Nueva categoría'), findsOneWidget);
      expect(
        tester.widget<TextFormField>(find.byType(TextFormField)).initialValue,
        '',
      );
      expect(app.categories.updates, 0);
    },
  );

  testWidgets(
    'Pending writes disable editing and reject overlapping submissions',
    (tester) async {
      final app = await _mount(tester);
      await _open(tester);
      final blocker = _block(app.categories);
      await tester.enterText(find.byType(TextFormField), 'Nueva');
      await _tap(tester, 'category-save', settle: false);
      expect(find.text('Guardando categoría...'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('category-save')))
            .onPressed,
        isNull,
      );
      final controller = tester
          .element(find.byKey(const ValueKey('categories-page')))
          .read<CategoryManagementController>();
      expect(await controller.save(), false);
      expect(app.categories.creates, 1);
      blocker.complete();
      await tester.pumpAndSettle();
      expect(find.text('Categoría creada.'), findsOneWidget);
    },
  );

  testWidgets(
    'Query failures clear records and retry separately from write failures',
    (tester) async {
      final app = await _mount(tester);
      await _open(tester);
      app.categories.changes.addError(_denied());
      await tester.pumpAndSettle();
      expect(find.text('Iluminación'), findsNothing);
      expect(app.categories.activeAllWatches, 0);
      await _tap(tester, 'categories-retry');
      expect(find.text('Iluminación'), findsOneWidget);
      app.categories.writeError = _denied();
      await tester.enterText(find.byType(TextFormField), 'Nueva');
      await _tap(tester, 'category-save');
      expect(
        find.text('No tenés permiso para realizar esta acción.'),
        findsOneWidget,
      );
      expect(find.text('Categoría creada.'), findsNothing);
      app.categories.writeError = null;
      await _tap(tester, 'category-save');
      expect(find.text('Categoría creada.'), findsOneWidget);
      expect(app.categories.activeAllWatches, 1);
    },
  );

  testWidgets(
    'Losing the administrator role clears a pending editor and ignores acknowledgement',
    (tester) async {
      final app = await _mount(tester);
      await _open(tester);
      final blocker = _block(app.categories);
      await tester.enterText(find.byType(TextFormField), 'Privada');
      await _tap(tester, 'category-save', settle: false);
      app.users.put(_profile(UserRole.reporter));
      await tester.pumpAndSettle();
      blocker.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('categories-page')), findsNothing);
      expect(find.text('Categoría creada.'), findsNothing);
      expect(app.categories.activeAllWatches, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Signing out and switching accounts never reuses a category draft or feedback',
    (tester) async {
      final app = await _mount(tester);
      await _open(tester);
      final blocker = _block(app.categories);
      await tester.enterText(find.byType(TextFormField), 'Anterior');
      await _tap(tester, 'category-save', settle: false);
      await _tap(tester, 'session-sign-out');
      app.users.put(
        const UserProfile(
          id: 'next',
          fullName: 'Otra cuenta',
          email: 'next@campusfix.test',
          role: UserRole.administrator,
        ),
      );
      app.auth.setUser('next');
      await tester.pumpAndSettle();
      await _open(tester);
      blocker.complete();
      await tester.pumpAndSettle();
      expect(find.text('Categoría creada.'), findsNothing);
      expect(
        tester.widget<TextFormField>(find.byType(TextFormField)).initialValue,
        '',
      );
      expect(app.categories.activeAllWatches, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Tablet layout handles long category names without overflow', (
    tester,
  ) async {
    final app = await _mount(tester, size: const Size(768, 1024));
    app.categories.documents['lighting']!['name'] = 'Iluminación y mantenimiento de espacios comunes del campus universitario';
    await _open(tester);
    await _tap(tester, 'category-edit-lighting');
    await tester.ensureVisible(find.byType(TextFormField));
    await tester.enterText(find.byType(TextFormField), 'Mantenimiento');
    await _tap(tester, 'category-save');
    expect(app.categories.documents['lighting']!['name'], 'Mantenimiento');
    expect(tester.takeException(), isNull);
  });
}

FirebaseException _denied() =>
    FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied');

Completer<void> _block(TestCategoryService categories) {
  final blocker = Completer<void>();
  categories.blocker = blocker;
  addTearDown(() {
    if (!blocker.isCompleted) blocker.complete();
  });
  return blocker;
}

Future<void> _open(WidgetTester tester) async {
  if (find.byKey(const ValueKey('nav-categories')).evaluate().isEmpty) {
    await tester.tap(find.byTooltip('Abrir menú'));
    await tester.pumpAndSettle();
  }
  await _tap(tester, 'nav-categories');
}

Future<void> _tap(WidgetTester tester, String key, {bool settle = true}) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

UserProfile _profile(UserRole role) => UserProfile(
  id: 'admin',
  fullName: 'Daniel',
  email: 'daniel@campusfix.test',
  role: role,
);

Future<
  ({
    TestUserRepository users,
    TestAuthRepository auth,
    TestCategoryService categories,
    CategoryRepository repository,
  })
>
_mount(
  WidgetTester tester, {
  UserRole role = UserRole.administrator,
  Size size = const Size(1280, 900),
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final users = TestUserRepository()..profiles['admin'] = _profile(role);
  final auth = TestAuthRepository(users: users, currentUserId: 'admin');
  final categories = TestCategoryService()
    ..documents.addAll({
      'lighting': {'name': 'Iluminación', 'isActive': true},
      'old': {'name': 'Categoría anterior', 'isActive': false},
    });
  final repository = CategoryRepository(categoryService: categories);
  final incidents = TestReportIncidents();
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
      categoryRepository: repository,
      incidentRepository: incidents,
      child: const MyApp(),
    ),
  );
  await tester.pumpAndSettle();
  return (
    users: users,
    auth: auth,
    categories: categories,
    repository: repository,
  );
}
