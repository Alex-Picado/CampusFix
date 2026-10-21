import 'dart:async';

import 'package:campusfix/app/providers/app_providers.dart';
import 'package:campusfix/features/users/models/user_profile.dart';
import 'package:campusfix/features/users/models/user_role.dart';
import 'package:campusfix/main.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_repositories.dart';
import 'support/report_repositories.dart';

void main() {
  testWidgets('Only an open administrator user page observes all accounts', (
    tester,
  ) async {
    final app = await _mount(tester, role: UserRole.reporter);
    expect(find.byKey(const ValueKey('nav-users')), findsNothing);
    expect(app.users.allUsersWatchCalls, 0);

    app.users.put(_currentUser(UserRole.technician));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('nav-users')), findsNothing);
    expect(app.users.allUsersWatchCalls, 0);

    app.users.put(_currentUser(UserRole.administrator));
    await tester.pumpAndSettle();
    expect(app.users.allUsersWatchCalls, 0);
    await _tap(tester, 'nav-users');
    expect(app.users.activeAllUsersWatches, 1);
    await _tap(tester, 'nav-overview');
    expect(app.users.activeAllUsersWatches, 0);
    await _tap(tester, 'nav-users');
    expect(app.users.allUsersWatchCalls, 2);
    expect(app.users.activeAllUsersWatches, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Observed users are sorted and role updates preserve identity', (
    tester,
  ) async {
    final app = await _mount(tester);
    await _tap(tester, 'nav-users');
    final names = tester
        .widgetList<Text>(find.byType(Text))
        .map((text) => text.data)
        .where((text) => text == 'Alex de prueba' || text == 'Daniel de prueba')
        .toList();
    expect(names, ['Alex de prueba', 'Daniel de prueba']);
    expect(_selector(tester, 'current-user').onChanged, isNull);
    expect(find.text('Tu cuenta'), findsOneWidget);

    await _selectRole(tester, UserRole.technician);
    final profile = app.users.profiles['other-user']!;
    expect(profile.role, UserRole.technician);
    expect(profile.id, 'other-user');
    expect(profile.fullName, 'Daniel de prueba');
    expect(profile.email, 'daniel@campusfix.test');
    expect(_selector(tester, 'other-user').value, UserRole.technician);
    expect(find.text('Rol de Daniel de prueba actualizado.'), findsOneWidget);
    expect(app.users.roleUpdateCalls, 1);
    await _tap(tester, 'session-sign-out');
    expect(find.text('Rol de Daniel de prueba actualizado.'), findsNothing);
    expect(find.text('Daniel de prueba'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Pending role updates disable selectors and prevent duplicates', (
    tester,
  ) async {
    final app = await _mount(tester);
    await _tap(tester, 'nav-users');
    final blocker = _blockRoleUpdate(app.users);
    await _selectRole(tester, UserRole.technician, settleWrite: false);
    expect(find.byKey(const ValueKey('users-saving')), findsOneWidget);
    expect(_selector(tester, 'other-user').onChanged, isNull);
    expect(_selector(tester, 'current-user').onChanged, isNull);
    await tester.tap(find.byKey(const ValueKey('user-role-other-user')));
    await tester.pump();
    expect(app.users.roleUpdateCalls, 1);

    blocker.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('users-saving')), findsNothing);
    expect(_selector(tester, 'other-user').onChanged, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('A rejected role change survives snapshots and can be retried', (
    tester,
  ) async {
    final app = await _mount(tester);
    await _tap(tester, 'nav-users');
    app.users.saveError = FirebaseException(
      plugin: 'cloud_firestore',
      code: 'permission-denied',
    );
    await _selectRole(tester, UserRole.technician);
    expect(find.byKey(const ValueKey('users-save-error')), findsOneWidget);
    expect(find.text('Rol de Daniel de prueba actualizado.'), findsNothing);
    expect(_selector(tester, 'other-user').value, UserRole.reporter);

    app.users.put(_otherUser(fullName: 'Daniel revisado'));
    await tester.pumpAndSettle();
    expect(find.text('Daniel revisado'), findsOneWidget);
    expect(find.byKey(const ValueKey('users-save-error')), findsOneWidget);

    app.users.saveError = null;
    await _selectRole(tester, UserRole.technician);
    expect(find.byKey(const ValueKey('users-save-error')), findsNothing);
    expect(app.users.profiles['other-user']!.role, UserRole.technician);
    expect(find.text('Rol de Daniel revisado actualizado.'), findsOneWidget);
    expect(app.users.roleUpdateCalls, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'A list failure hides accounts and retries without ending session',
    (tester) async {
      final app = await _mount(tester);
      await _tap(tester, 'nav-users');
      app.users.failUserList(
        FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('users-page')), findsOneWidget);
      expect(find.byKey(const ValueKey('users-load-error')), findsOneWidget);
      expect(find.text('daniel@campusfix.test'), findsNothing);
      expect(app.users.activeAllUsersWatches, 0);

      await _tap(tester, 'users-retry');
      expect(find.text('daniel@campusfix.test'), findsOneWidget);
      expect(find.byKey(const ValueKey('users-load-error')), findsNothing);
      expect(app.users.activeAllUsersWatches, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Losing the administrator role removes accounts and observation',
    (tester) async {
      final app = await _mount(tester);
      await _tap(tester, 'nav-users');
      app.users.put(_currentUser(UserRole.reporter));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('overview-page')), findsOneWidget);
      expect(find.byKey(const ValueKey('users-page')), findsNothing);
      expect(find.byKey(const ValueKey('nav-users')), findsNothing);
      expect(find.text('daniel@campusfix.test'), findsNothing);
      expect(app.users.activeAllUsersWatches, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Leaving a pending role write cannot confirm on the next view', (
    tester,
  ) async {
    final app = await _mount(tester);
    await _tap(tester, 'nav-users');
    final blocker = _blockRoleUpdate(app.users);
    await _selectRole(tester, UserRole.technician, settleWrite: false);
    await _tap(tester, 'nav-overview');
    expect(app.users.activeAllUsersWatches, 0);
    blocker.complete();
    await tester.pumpAndSettle();
    expect(app.users.profiles['other-user']!.role, UserRole.technician);
    expect(find.text('Rol de Daniel de prueba actualizado.'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'An old role write cannot leak users or feedback into a new account',
    (tester) async {
      final app = await _mount(tester);
      await _tap(tester, 'nav-users');
      final blocker = _blockRoleUpdate(app.users);
      await _selectRole(tester, UserRole.technician, settleWrite: false);
      await _tap(tester, 'session-sign-out');
      expect(app.users.activeAllUsersWatches, 0);
      expect(find.byKey(const ValueKey('auth-email')), findsOneWidget);

      app.users.put(
        const UserProfile(
          id: 'next-user',
          fullName: 'Otra cuenta',
          email: 'other@campusfix.test',
          role: UserRole.reporter,
        ),
      );
      app.auth.setUser('next-user');
      await tester.pumpAndSettle();
      blocker.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('overview-page')), findsOneWidget);
      expect(find.byKey(const ValueKey('users-page')), findsNothing);
      expect(find.text('daniel@campusfix.test'), findsNothing);
      expect(find.text('Rol de Daniel de prueba actualizado.'), findsNothing);
      expect(app.users.profiles['next-user']!.role, UserRole.reporter);
      expect(app.users.activeAllUsersWatches, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Users and their role selectors fit the tablet layout', (
    tester,
  ) async {
    final app = await _mount(tester, size: const Size(768, 1024));
    await tester.tap(find.byTooltip('Abrir menú'));
    await tester.pumpAndSettle();
    await _tap(tester, 'nav-users');
    expect(find.text('daniel@campusfix.test'), findsOneWidget);
    expect(_selector(tester, 'other-user').onChanged, isNotNull);
    expect(app.users.activeAllUsersWatches, 1);
    expect(
      tester.state<ScaffoldState>(find.byType(Scaffold)).isDrawerOpen,
      isFalse,
    );
    expect(tester.takeException(), isNull);
  });
}

DropdownButton<UserRole> _selector(WidgetTester tester, String userId) {
  return tester.widget<DropdownButton<UserRole>>(
    find.byKey(ValueKey('user-role-$userId')),
  );
}

Future<void> _selectRole(
  WidgetTester tester,
  UserRole role, {
  bool settleWrite = true,
}) async {
  await _tap(tester, 'user-role-other-user');
  var label = 'Reportante';
  if (role == UserRole.technician) {
    label = 'Técnico';
  } else if (role == UserRole.administrator) {
    label = 'Administrador';
  }
  await tester.tap(find.text(label).last);
  if (settleWrite) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }
}

Completer<void> _blockRoleUpdate(TestUserRepository users) {
  final blocker = Completer<void>();
  users.roleUpdateBlocker = blocker;
  addTearDown(() {
    if (!blocker.isCompleted) {
      blocker.complete();
    }
  });
  return blocker;
}

Future<void> _tap(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Uses the real app and controllers without making Firebase requests.
Future<_TestApp> _mount(
  WidgetTester tester, {
  UserRole role = UserRole.administrator,
  Size size = const Size(1280, 900),
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  final users = TestUserRepository();
  users.profiles['current-user'] = _currentUser(role);
  users.profiles['other-user'] = _otherUser();
  final auth = TestAuthRepository(users: users, currentUserId: 'current-user');
  final categories = TestReportCategories();
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
      incidentRepository: TestReportIncidents(),
      child: const MyApp(),
    ),
  );
  await tester.pumpAndSettle();
  return _TestApp(auth, users);
}

UserProfile _currentUser(UserRole role) {
  return UserProfile(
    id: 'current-user',
    fullName: 'Alex de prueba',
    email: 'alex@campusfix.test',
    role: role,
  );
}

UserProfile _otherUser({String fullName = 'Daniel de prueba'}) {
  return UserProfile(
    id: 'other-user',
    fullName: fullName,
    email: 'daniel@campusfix.test',
    role: UserRole.reporter,
  );
}

class _TestApp {
  final TestAuthRepository auth;
  final TestUserRepository users;

  _TestApp(this.auth, this.users);
}
