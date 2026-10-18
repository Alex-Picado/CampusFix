import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:campusfix/app/navigation/campus_destination.dart';
import 'package:campusfix/app/providers/app_providers.dart';
import 'package:campusfix/features/users/models/user_profile.dart';
import 'package:campusfix/features/users/models/user_role.dart';
import 'package:campusfix/main.dart';

import 'support/test_repositories.dart';

void main() {
  testWidgets(
    'Invalid forms avoid requests and mode changes clear old errors',
    (tester) async {
      final app = await _mountApp(tester);
      await _tap(tester, 'auth-submit');
      expect(
        find.text('Ingresá un correo electrónico válido.'),
        findsOneWidget,
      );
      expect(app.auth.signInCalls, 0);

      app.auth.signInError = FirebaseAuthException(code: 'invalid-credential');
      await _enter(tester, 'auth-email', 'alex@campusfix.test');
      await _enter(tester, 'auth-password', 'incorrect-password');
      await _tap(tester, 'auth-submit');
      expect(
        find.text('El correo o la contraseña son incorrectos.'),
        findsOneWidget,
      );

      await _tap(tester, 'auth-switch');
      expect(
        find.text('El correo o la contraseña son incorrectos.'),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('auth-name')), findsOneWidget);
      expect(_passwordInput(tester).controller!.text, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Sign-in blocks duplicate requests and sign-out removes the profile',
    (tester) async {
      final app = await _mountApp(tester);
      final blocker = Completer<void>();
      app.auth.signInBlocker = blocker;
      addTearDown(() {
        if (!blocker.isCompleted) {
          blocker.complete();
        }
      });

      await _enter(tester, 'auth-email', '  alex@campusfix.test  ');
      await _enter(tester, 'auth-password', ' password-with-spaces ');
      await tester.tap(find.byKey(const ValueKey('auth-submit')));
      await tester.pump();
      final button = tester.widget<FilledButton>(
        find.descendant(
          of: find.byKey(const ValueKey('auth-submit')),
          matching: find.byType(FilledButton),
        ),
      );
      expect(button.onPressed, isNull);
      await tester.tap(find.byKey(const ValueKey('auth-submit')));
      expect(app.auth.signInCalls, 1);

      blocker.complete();
      await tester.pumpAndSettle();
      expect(app.auth.submittedEmail, 'alex@campusfix.test');
      expect(app.auth.submittedPassword, ' password-with-spaces ');
      await _tap(tester, 'nav-profile');
      expect(find.text('Alex de prueba'), findsOneWidget);
      expect(find.text('alex@campusfix.test'), findsOneWidget);
      await _tap(tester, 'session-sign-out');
      expect(find.byKey(const ValueKey('auth-email')), findsOneWidget);
      expect(find.text('Alex de prueba'), findsNothing);
      expect(find.byKey(const ValueKey('profile-page')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Registration checks confirmation and opens a reporter session', (
    tester,
  ) async {
    final app = await _mountApp(tester);
    await _fillRegistration(tester, confirmation: 'different-password');
    await _tap(tester, 'auth-submit');
    expect(find.text('Las contraseñas no coinciden.'), findsOneWidget);
    expect(app.auth.registerCalls, 0);

    await _enter(tester, 'auth-confirmation', 'class-project-password');
    await _tap(tester, 'auth-submit');
    expect(find.byKey(const ValueKey('overview-page')), findsOneWidget);
    expect(app.users.profiles['registered-user']!.fullName, 'Estudiante UCR');
    expect(app.users.profiles['registered-user']!.role, UserRole.reporter);
    expect(find.byKey(const ValueKey('nav-users')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'A failed profile write can be retried without registering again',
    (tester) async {
      final app = await _mountApp(tester);
      app.users.saveError = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
      );
      await _fillRegistration(tester);
      await _tap(tester, 'auth-submit');
      expect(find.text('Completá tu perfil'), findsOneWidget);
      expect(
        find.text('No tenés permiso para realizar esta acción.'),
        findsOneWidget,
      );
      expect(app.auth.registerCalls, 1);

      app.users.saveError = null;
      await _enter(tester, 'complete-profile-name', 'Estudiante UCR');
      await _tap(tester, 'complete-profile-submit');
      expect(find.byKey(const ValueKey('overview-page')), findsOneWidget);
      expect(app.auth.registerCalls, 1);
      expect(app.auth.completeProfileCalls, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Observation failures hide private views and allow retry or exit',
    (tester) async {
      final app = await _mountApp(tester, role: UserRole.reporter);
      await _tap(tester, 'nav-profile');
      app.users.failObservation(
        FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
      );
      await tester.pumpAndSettle();
      expect(find.text('No pudimos cargar tu sesión'), findsOneWidget);
      expect(find.text('Alex de prueba'), findsNothing);
      await _tap(tester, 'session-retry');
      expect(find.byKey(const ValueKey('overview-page')), findsOneWidget);

      app.users.failObservation(
        FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cerrar sesión'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('auth-email')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  const visibleByRole = {
    UserRole.reporter: [
      CampusDestination.overview,
      CampusDestination.incidents,
      CampusDestination.profile,
    ],
    UserRole.technician: [
      CampusDestination.overview,
      CampusDestination.workspace,
      CampusDestination.profile,
    ],
    UserRole.administrator: [
      CampusDestination.overview,
      CampusDestination.management,
      CampusDestination.dashboard,
      CampusDestination.categories,
      CampusDestination.users,
      CampusDestination.profile,
    ],
  };

  for (final entry in visibleByRole.entries) {
    testWidgets('${entry.key.name} sees and opens only the expected modules', (
      tester,
    ) async {
      await _mountApp(tester, role: entry.key);
      for (final destination in CampusDestination.values) {
        final finder = find.byKey(ValueKey('nav-${destination.name}'));
        if (!entry.value.contains(destination)) {
          expect(finder, findsNothing);
          continue;
        }
        expect(finder, findsOneWidget);
        await _tap(tester, 'nav-${destination.name}');
        if (destination == CampusDestination.overview) {
          expect(find.byKey(const ValueKey('overview-page')), findsOneWidget);
        } else if (destination == CampusDestination.profile) {
          expect(find.byKey(const ValueKey('profile-page')), findsOneWidget);
        } else {
          expect(
            find.byKey(ValueKey('preview-${destination.name}')),
            findsOneWidget,
          );
          expect(find.text('Funcionalidad pendiente'), findsOneWidget);
        }
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'A live role downgrade closes the previously selected admin view',
    (tester) async {
      final app = await _mountApp(tester, role: UserRole.administrator);
      await _tap(tester, 'nav-users');
      app.users.put(_profile(UserRole.reporter));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('overview-page')), findsOneWidget);
      expect(find.byKey(const ValueKey('nav-users')), findsNothing);
      expect(find.byKey(const ValueKey('preview-users')), findsNothing);
      expect(find.byKey(const ValueKey('nav-incidents')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Tablet navigation closes the drawer after selecting the profile',
    (tester) async {
      await _mountApp(
        tester,
        role: UserRole.reporter,
        size: const Size(768, 1024),
      );
      await tester.tap(find.byTooltip('Abrir menú'));
      await tester.pumpAndSettle();
      await _tap(tester, 'nav-profile');
      expect(find.byKey(const ValueKey('profile-page')), findsOneWidget);
      final scaffold = tester.state<ScaffoldState>(find.byType(Scaffold));
      expect(scaffold.isDrawerOpen, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Sign-out errors preserve the session and show a recoverable message',
    (tester) async {
      final app = await _mountApp(tester, role: UserRole.reporter);
      app.auth.signOutError = FirebaseAuthException(
        code: 'network-request-failed',
      );
      await _tap(tester, 'session-sign-out');
      expect(find.byKey(const ValueKey('overview-page')), findsOneWidget);
      expect(
        find.text('No pudimos conectar. Revisá tu conexión a internet.'),
        findsOneWidget,
      );

      app.auth.signOutError = null;
      await _tap(tester, 'session-sign-out');
      expect(find.byKey(const ValueKey('auth-email')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

/// Mounts the real application and controllers with isolated repository doubles.
Future<_TestApp> _mountApp(
  WidgetTester tester, {
  UserRole? role,
  Size size = const Size(1280, 900),
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  final users = TestUserRepository();
  users.profiles['campus-user'] = _profile(role ?? UserRole.reporter);
  final auth = TestAuthRepository(users: users);
  if (role != null) {
    auth.currentUserId = 'campus-user';
  }

  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await auth.close();
    await users.close();
  });
  await tester.pumpWidget(
    AppProviders(
      authRepository: auth,
      userRepository: users,
      child: const MyApp(),
    ),
  );
  await tester.pumpAndSettle();
  return _TestApp(auth, users);
}

UserProfile _profile(UserRole role) {
  return UserProfile(
    id: 'campus-user',
    fullName: 'Alex de prueba',
    email: 'alex@campusfix.test',
    role: role,
  );
}

Future<void> _enter(WidgetTester tester, String key, String value) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.enterText(finder, value);
}

Future<void> _tap(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _fillRegistration(
  WidgetTester tester, {
  String confirmation = 'class-project-password',
}) async {
  await _tap(tester, 'auth-switch');
  await _enter(tester, 'auth-name', '  Estudiante UCR  ');
  await _enter(tester, 'auth-email', 'student@campusfix.test');
  await _enter(tester, 'auth-password', 'class-project-password');
  await _enter(tester, 'auth-confirmation', confirmation);
}

TextFormField _passwordInput(WidgetTester tester) {
  return tester.widget<TextFormField>(
    find.descendant(
      of: find.byKey(const ValueKey('auth-password')),
      matching: find.byType(TextFormField),
    ),
  );
}

class _TestApp {
  final TestAuthRepository auth;
  final TestUserRepository users;

  _TestApp(this.auth, this.users);
}
