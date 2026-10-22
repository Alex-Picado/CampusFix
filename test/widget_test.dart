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
import 'support/report_repositories.dart';

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
        } else if (destination == CampusDestination.users) {
          expect(find.byKey(const ValueKey('users-page')), findsOneWidget);
        } else if (destination == CampusDestination.incidents) {
          expect(
            find.byKey(const ValueKey('my-incidents-page')),
            findsOneWidget,
          );
        } else if (destination == CampusDestination.management ||
            destination == CampusDestination.workspace) {
          expect(find.byKey(const ValueKey('incident-queue')), findsOneWidget);
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
      expect(find.byKey(const ValueKey('users-page')), findsNothing);
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
  testWidgets('Profile saves validate names and preserve the email and role', (
    tester,
  ) async {
    final app = await _mountApp(tester, role: UserRole.technician);
    await _tap(tester, 'nav-profile');
    expect(_profileSaveButton(tester).onPressed, isNull);
    await _enter(tester, 'profile-name', '   ');
    await _tap(tester, 'profile-save');
    expect(find.text('Ingresá tu nombre completo.'), findsOneWidget);
    expect(app.users.nameUpdateCalls, 0);

    final blocker = Completer<void>();
    app.users.nameUpdateBlocker = blocker;
    addTearDown(() {
      if (!blocker.isCompleted) {
        blocker.complete();
      }
    });
    await _enter(tester, 'profile-name', '  Alex actualizado  ');
    await tester.tap(find.byKey(const ValueKey('profile-save')));
    await tester.pump();
    expect(_profileSaveButton(tester).onPressed, isNull);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('profile-name')))
          .enabled,
      isFalse,
    );
    await tester.tap(find.byKey(const ValueKey('profile-save')));
    expect(app.users.nameUpdateCalls, 1);

    blocker.complete();
    await tester.pumpAndSettle();
    final saved = app.users.profiles['campus-user']!;
    expect(saved.fullName, 'Alex actualizado');
    expect(saved.email, 'alex@campusfix.test');
    expect(saved.role, UserRole.technician);
    expect(find.text('Nombre actualizado.'), findsOneWidget);
    expect(_profileName(tester), 'Alex actualizado');
    expect(_profileSaveButton(tester).onPressed, isNull);
    await _tap(tester, 'nav-overview');
    await _tap(tester, 'nav-profile');
    expect(_profileName(tester), 'Alex actualizado');
    expect(tester.takeException(), isNull);
  });

  testWidgets('A rejected save preserves its draft through observed rollbacks', (
    tester,
  ) async {
    final app = await _mountApp(tester, role: UserRole.reporter);
    await _tap(tester, 'nav-profile');
    final blocker = Completer<void>();
    app.users.nameUpdateBlocker = blocker;
    app.users.saveError = FirebaseException(
      plugin: 'cloud_firestore',
      code: 'permission-denied',
    );
    addTearDown(() {
      if (!blocker.isCompleted) {
        blocker.complete();
      }
    });
    await _enter(tester, 'profile-name', 'Nombre pendiente');
    await tester.tap(find.byKey(const ValueKey('profile-save')));
    await tester.pump();
    expect(app.users.nameUpdateCalls, 1);

    // Simulates an optimistic snapshot followed by a rejected write's rollback.
    app.users.put(
      const UserProfile(
        id: 'campus-user',
        fullName: 'Nombre pendiente',
        email: 'alex@campusfix.test',
        role: UserRole.reporter,
      ),
    );
    await tester.pump();
    app.users.put(_profile(UserRole.reporter));
    await tester.pump();
    blocker.complete();
    await tester.pumpAndSettle();
    expect(_profileName(tester), 'Nombre pendiente');
    expect(app.users.profiles['campus-user']!.fullName, 'Alex de prueba');
    expect(
      find.text('No tenés permiso para realizar esta acción.'),
      findsOneWidget,
    );

    app.users.saveError = null;
    await _tap(tester, 'profile-save');
    expect(find.text('Nombre actualizado.'), findsOneWidget);
    expect(app.users.profiles['campus-user']!.fullName, 'Nombre pendiente');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Observed name changes refresh only an untouched profile form', (
    tester,
  ) async {
    final app = await _mountApp(tester, role: UserRole.reporter);
    await _tap(tester, 'nav-profile');
    app.users.put(
      const UserProfile(
        id: 'campus-user',
        fullName: 'Nombre externo',
        email: 'alex@campusfix.test',
        role: UserRole.reporter,
      ),
    );
    await tester.pumpAndSettle();
    expect(_profileName(tester), 'Nombre externo');

    await _enter(tester, 'profile-name', 'Mi borrador');
    app.users.put(_profile(UserRole.reporter));
    await tester.pumpAndSettle();
    expect(_profileName(tester), 'Mi borrador');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'A pending name save cannot update the next account or its screen',
    (tester) async {
      final app = await _mountApp(tester, role: UserRole.reporter);
      await _tap(tester, 'nav-profile');
      final blocker = Completer<void>();
      app.users.nameUpdateBlocker = blocker;
      addTearDown(() {
        if (!blocker.isCompleted) {
          blocker.complete();
        }
      });
      await _enter(tester, 'profile-name', 'Nombre de la cuenta anterior');
      await tester.tap(find.byKey(const ValueKey('profile-save')));
      await tester.pump();
      expect(app.users.nameUpdateCalls, 1);
      await _tap(tester, 'session-sign-out');
      expect(find.byKey(const ValueKey('auth-email')), findsOneWidget);

      app.users.put(
        const UserProfile(
          id: 'next-account',
          fullName: 'Otra cuenta',
          email: 'other@campusfix.test',
          role: UserRole.technician,
        ),
      );
      app.auth.setUser('next-account');
      await tester.pumpAndSettle();
      await _tap(tester, 'nav-profile');
      blocker.complete();
      await tester.pumpAndSettle();
      expect(_profileName(tester), 'Otra cuenta');
      expect(app.users.profiles['next-account']!.fullName, 'Otra cuenta');
      expect(find.text('Nombre actualizado.'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

String _profileName(WidgetTester tester) {
  return tester
      .widget<TextFormField>(find.byKey(const ValueKey('profile-name')))
      .controller!
      .text;
}

FilledButton _profileSaveButton(WidgetTester tester) {
  return tester.widget<FilledButton>(
    find.byKey(const ValueKey('profile-save')),
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
  final categories = TestReportCategories();
  final incidents = TestReportIncidents();
  if (role != null) {
    auth.currentUserId = 'campus-user';
  }

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
  await tester.pump();
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
