import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:campusfix/app/navigation/campus_destination.dart';
import 'package:campusfix/app/providers/app_providers.dart';
import 'package:campusfix/features/incidents/models/incident.dart';
import 'package:campusfix/features/incidents/models/incident_priority.dart';
import 'package:campusfix/features/incidents/models/incident_status.dart';
import 'package:campusfix/features/users/models/user_profile.dart';
import 'package:campusfix/features/users/models/user_role.dart';
import 'package:campusfix/main.dart';

import 'support/test_repositories.dart';
import 'support/report_repositories.dart';

void main() {
  testWidgets(
    'Recordarme is optional, submitted at login and reset after signing out',
    (tester) async {
      final app = await _mountApp(tester);
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(const ValueKey('auth-remember-me')),
            )
            .value,
        false,
      );
      await _enter(tester, 'auth-email', 'alex@campusfix.test');
      await _enter(tester, 'auth-password', 'class-project-password');
      await _tap(tester, 'auth-remember-me');
      await _tap(tester, 'auth-submit');
      expect(app.auth.submittedRememberMe, true);
      await _tap(tester, 'session-sign-out');
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(const ValueKey('auth-remember-me')),
            )
            .value,
        false,
      );
      await _enter(tester, 'auth-email', 'alex@campusfix.test');
      await _enter(tester, 'auth-password', 'class-project-password');
      await _tap(tester, 'auth-submit');
      expect(app.auth.submittedRememberMe, false);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'An open notification panel clears private content when the session changes',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final app = await _mountApp(tester, role: UserRole.reporter);
      await _tap(tester, 'notification-bell');
      expect(find.text('Notificaciones'), findsOneWidget);
      app.auth.setUser(null);
      await tester.pumpAndSettle();
      expect(
        find.text('La sesión cambió. Cerrá este panel para continuar.'),
        findsOneWidget,
      );
      expect(find.text('Marcar todas como leídas'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Password recovery validates email and sends a link without signing in',
    (tester) async {
      final app = await _mountApp(tester);
      await _tap(tester, 'auth-forgot-password');
      expect(find.byKey(const ValueKey('auth-password')), findsNothing);
      await _enter(tester, 'auth-email', 'invalid');
      await _tap(tester, 'auth-submit');
      expect(app.auth.passwordResetCalls, 0);
      await _enter(tester, 'auth-email', '  alex@campusfix.test  ');
      await _tap(tester, 'auth-submit');
      expect(app.auth.passwordResetCalls, 1);
      expect(app.auth.submittedEmail, 'alex@campusfix.test');
      expect(app.auth.currentUserId, isNull);
      expect(find.textContaining('recibirás un enlace'), findsOneWidget);
      await _tap(tester, 'auth-switch');
      expect(find.byKey(const ValueKey('auth-password')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final role in UserRole.values) {
    testWidgets(
      'Dashboard cards open the selected stage and sidebar animates for ${role.name}',
      (tester) async {
        await _mountApp(tester, role: role);
        final originalLeft = tester
            .getTopLeft(find.byKey(const ValueKey('overview-page')))
            .dx;
        await _tap(tester, 'sidebar-toggle');
        expect(find.byTooltip('Mostrar menú'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('nav-overview')).hitTestable(),
          findsNothing,
        );
        expect(
          tester.getTopLeft(find.byKey(const ValueKey('overview-page'))).dx,
          originalLeft - 241,
        );
        await _tap(tester, 'sidebar-toggle');
        expect(find.byTooltip('Ocultar menú'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('nav-overview')).hitTestable(),
          findsOneWidget,
        );
        expect(
          tester.getTopLeft(find.byKey(const ValueKey('overview-page'))).dx,
          originalLeft,
        );
        final prefix = role == UserRole.administrator
            ? 'admin-home'
            : role == UserRole.technician
            ? 'technician-home'
            : 'home';
        await _tap(tester, '$prefix-count-2');
        final tab = find.byType(TabBar);
        expect(
          DefaultTabController.of(tester.element(tab)).index,
          role == UserRole.administrator ? 3 : 2,
        );
        expect(find.byKey(const ValueKey('notification-bell')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'Appearance follows the system and remembers an explicit choice',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      addTearDown(() => SharedPreferences.setMockInitialValues({}));
      final dispatcher = tester.platformDispatcher;
      dispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(dispatcher.clearPlatformBrightnessTestValue);

      await _mountApp(
        tester,
        role: UserRole.reporter,
        size: const Size(390, 844),
      );
      Brightness pageBrightness(String key) =>
          Theme.of(tester.element(find.byKey(ValueKey(key)))).brightness;
      expect(pageBrightness('overview-page'), Brightness.dark);

      dispatcher.platformBrightnessTestValue = Brightness.light;
      await tester.pumpAndSettle();
      expect(pageBrightness('overview-page'), Brightness.light);
      await tester.tap(find.byTooltip('Abrir menú'));
      await tester.pumpAndSettle();
      await _tap(tester, 'nav-profile');
      await _tap(tester, 'appearance-mode');
      await tester.tap(
        find.widgetWithText(MenuItemButton, 'Oscuro').hitTestable(),
      );
      await tester.pumpAndSettle();
      expect(pageBrightness('profile-page'), Brightness.dark);

      final preferences = await SharedPreferences.getInstance();
      await preferences.reload();
      await tester.pumpWidget(const SizedBox.shrink());
      await _mountApp(tester, role: UserRole.reporter);
      expect(pageBrightness('overview-page'), Brightness.dark);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Administrator home summarizes campus cases and opens management',
    (tester) async {
      final app = await _mountApp(tester, role: UserRole.administrator);
      expect(
        find.text('Todavía no hay incidencias registradas.'),
        findsOneWidget,
      );
      final now = DateTime.utc(2026, 11, 8);
      Incident caseFor(int number, IncidentStatus status) => Incident(
        id: 'admin-$number',
        sequenceNumber: number,
        title: 'Caso $number',
        description: 'Descripción del caso $number',
        categoryId: 'lighting',
        location: 'Biblioteca',
        createdAt: now,
        updatedAt: now.add(Duration(minutes: number)),
        createdByUserId: 'reporter-user',
        status: status,
      );
      final rows = [
        caseFor(1, IncidentStatus.reported),
        caseFor(2, IncidentStatus.assigned),
        caseFor(3, IncidentStatus.inProgress),
        caseFor(4, IncidentStatus.resolved),
        caseFor(5, IncidentStatus.reviewRequested),
        caseFor(6, IncidentStatus.closed),
      ];
      app.incidents.saved.addAll({for (final row in rows) row.id: row});
      app.incidents.ownChanges.add(rows);
      await tester.pumpAndSettle();
      expect(find.text('#6 · Caso 6'), findsOneWidget);
      expect(find.text('#2 · Caso 2'), findsNothing);
      for (var index = 0; index < 6; index++) {
        expect(
          find.descendant(
            of: find.byKey(ValueKey('admin-home-count-$index')),
            matching: find.text('1'),
          ),
          findsOneWidget,
        );
      }
      expect(find.byKey(const ValueKey('home-create-incident')), findsNothing);
      await _tap(tester, 'admin-home-management');
      expect(find.byKey(const ValueKey('incident-queue')), findsOneWidget);
      expect(find.text('Todas (6)'), findsOneWidget);
      expect(find.text('Revisión solicitada (1)'), findsOneWidget);
      expect(find.byKey(const ValueKey('incident-admin-1')), findsOneWidget);
      await _tap(tester, 'management-tab-5');
      expect(find.byKey(const ValueKey('incident-admin-5')), findsOneWidget);
      expect(find.byKey(const ValueKey('incident-admin-1')), findsNothing);
      expect(find.textContaining('Revisá el motivo'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Administrator home error retries and fits a phone', (
    tester,
  ) async {
    final app = await _mountApp(
      tester,
      role: UserRole.administrator,
      size: const Size(390, 844),
    );
    app.incidents.ownChanges.addError(
      FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('No pudimos cargar las incidencias del campus.'),
      findsOneWidget,
    );
    await _tap(tester, 'admin-home-retry');
    expect(find.byKey(const ValueKey('admin-home-count-5')), findsOneWidget);
    await _tap(tester, 'admin-home-management');
    await _tap(tester, 'management-tab-6');
    expect(find.text('No hay incidencias disponibles.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Reporter home summarizes live reports and opens report actions',
    (tester) async {
      final app = await _mountApp(tester, role: UserRole.reporter);
      expect(
        find.text(
          'Todavía no tenés incidencias. Creá tu primer reporte para comenzar.',
        ),
        findsOneWidget,
      );
      final now = DateTime.utc(2026, 11, 8);
      app.incidents.ownChanges.add([
        Incident(
          id: 'one',
          sequenceNumber: 1,
          title: 'Lámpara dañada',
          description: 'No enciende',
          categoryId: 'lighting',
          location: 'Biblioteca',
          createdAt: now,
          updatedAt: now,
          createdByUserId: 'campus-user',
        ),
        Incident(
          id: 'two',
          sequenceNumber: 2,
          title: 'Pupitre roto',
          description: 'Pata rota',
          categoryId: 'lighting',
          location: 'Aula',
          createdAt: now,
          updatedAt: now.add(const Duration(minutes: 1)),
          createdByUserId: 'campus-user',
          status: IncidentStatus.resolved,
        ),
        Incident(
          id: 'three',
          sequenceNumber: 3,
          title: 'Caso cerrado',
          description: 'Resuelto',
          categoryId: 'lighting',
          location: 'Aula',
          createdAt: now,
          updatedAt: now.add(const Duration(minutes: 2)),
          createdByUserId: 'campus-user',
          status: IncidentStatus.closed,
        ),
        Incident(
          id: 'other',
          sequenceNumber: 4,
          title: 'Reporte ajeno',
          description: 'Ajeno',
          categoryId: 'lighting',
          location: 'Aula',
          createdAt: now,
          updatedAt: now,
          createdByUserId: 'other-user',
        ),
      ]);
      await tester.pumpAndSettle();
      expect(find.text('Reporte ajeno'), findsNothing);
      expect(find.text('#2 · Pupitre roto'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('home-count-0')),
          matching: find.text('1'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('home-count-3')),
          matching: find.text('1'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('home-count-4')),
          matching: find.text('1'),
        ),
        findsOneWidget,
      );
      expect(
        tester.widget(find.byKey(const ValueKey('home-create-incident'))),
        isA<FloatingActionButton>(),
      );
      await _tap(tester, 'home-create-incident');
      expect(find.byKey(const ValueKey('report-page')), findsOneWidget);
      expect(find.byKey(const ValueKey('home-create-incident')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Reporter home keeps loading and errors distinct from an empty summary',
    (tester) async {
      final app = await _mountApp(tester, role: UserRole.reporter);
      app.incidents.ownChanges.addError(
        FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
      );
      await tester.pumpAndSettle();
      expect(find.text('No pudimos cargar tus incidencias.'), findsOneWidget);
      expect(
        find.text(
          'Todavía no tenés incidencias. Creá tu primer reporte para comenzar.',
        ),
        findsNothing,
      );
      await _tap(tester, 'home-retry');
      expect(
        find.text(
          'Todavía no tenés incidencias. Creá tu primer reporte para comenzar.',
        ),
        findsOneWidget,
      );
      await _tap(tester, 'home-view-incidents');
      expect(find.byKey(const ValueKey('my-incidents-page')), findsOneWidget);
      expect(app.incidents.activeOwnWatches, 1);
    },
  );

  testWidgets(
    'Reporter home fits a phone and its list shortcut opens the tabs',
    (tester) async {
      await _mountApp(
        tester,
        role: UserRole.reporter,
        size: const Size(390, 844),
      );
      expect(find.byKey(const ValueKey('home-count-4')), findsOneWidget);
      final createButton = find.byKey(const ValueKey('home-create-incident'));
      expect(tester.getBottomRight(createButton).dx, greaterThan(350));
      expect(tester.getBottomRight(createButton).dy, greaterThan(780));
      await _tap(tester, 'home-view-incidents');
      expect(find.byKey(const ValueKey('my-incidents-page')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Technician home summarizes assigned work and opens its queue', (
    tester,
  ) async {
    final app = await _mountApp(tester, role: UserRole.technician);
    expect(
      find.text('Todavía no tenés incidencias asignadas.'),
      findsOneWidget,
    );
    final now = DateTime.utc(2026, 11, 8);
    Incident assignment(
      String id,
      int number,
      IncidentStatus status, {
      String technician = 'campus-user',
      IncidentPriority? priority,
    }) => Incident(
      id: id,
      sequenceNumber: number,
      title: 'Caso $number',
      description: 'Descripción',
      categoryId: 'lighting',
      location: 'Biblioteca',
      createdAt: now,
      updatedAt: now.add(Duration(minutes: number)),
      createdByUserId: 'reporter-user',
      assignedTechnicianId: technician,
      status: status,
      priority: priority,
    );
    final rows = [
      assignment(
        'assigned',
        1,
        IncidentStatus.assigned,
        priority: IncidentPriority.high,
      ),
      assignment(
        'working',
        2,
        IncidentStatus.inProgress,
        priority: IncidentPriority.medium,
      ),
      assignment(
        'resolved',
        3,
        IncidentStatus.resolved,
        priority: IncidentPriority.low,
      ),
      assignment('review', 4, IncidentStatus.reviewRequested),
      assignment('closed', 5, IncidentStatus.closed),
      assignment(
        'foreign',
        6,
        IncidentStatus.assigned,
        technician: 'other-tech',
      ),
    ];
    app.incidents.saved.addAll({for (final row in rows) row.id: row});
    app.incidents.ownChanges.add(rows);
    await tester.pumpAndSettle();
    expect(find.text('Caso 6'), findsNothing);
    expect(find.text('#5 · Caso 5'), findsOneWidget);
    for (var index = 0; index < 5; index++) {
      expect(
        find.descendant(
          of: find.byKey(ValueKey('technician-home-count-$index')),
          matching: find.text('1'),
        ),
        findsOneWidget,
      );
    }
    expect(find.byKey(const ValueKey('home-create-incident')), findsNothing);
    await _tap(tester, 'technician-home-view-workspace');
    expect(find.byKey(const ValueKey('incident-queue')), findsOneWidget);
    expect(find.text('Asignadas (1)'), findsOneWidget);
    expect(find.text('En atención (1)'), findsOneWidget);
    expect(find.text('Solucionadas (1)'), findsOneWidget);
    expect(find.text('En revisión (1)'), findsOneWidget);
    expect(find.text('Finalizadas (1)'), findsOneWidget);
    expect(find.byKey(const ValueKey('incident-assigned')), findsOneWidget);
    expect(find.byKey(const ValueKey('incident-working')), findsNothing);
    expect(find.text('Ubicación: Biblioteca'), findsOneWidget);
    expect(find.text('Prioridad ALTA'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('incident-assigned')),
        matching: find.byType(Chip),
      ),
      findsNWidgets(2),
    );
    expect(
      tester
          .widget<Chip>(find.byKey(const ValueKey('priority-assigned')))
          .backgroundColor,
      const Color(0xFFC62828).withValues(alpha: 0.10),
    );
    await _tap(tester, 'workspace-tab-1');
    expect(find.byKey(const ValueKey('incident-working')), findsOneWidget);
    expect(find.byKey(const ValueKey('incident-assigned')), findsNothing);
    expect(find.text('Prioridad MEDIA'), findsOneWidget);
    app.incidents.ownChanges.add([
      for (final row in rows)
        row.id == 'working'
            ? row.copyWith(status: IncidentStatus.resolved)
            : row,
    ]);
    await tester.pumpAndSettle();
    expect(find.text('En atención (0)'), findsOneWidget);
    expect(find.text('Solucionadas (2)'), findsOneWidget);
    expect(find.byKey(const ValueKey('incident-working')), findsNothing);
    await _tap(tester, 'workspace-tab-2');
    expect(find.byKey(const ValueKey('incident-working')), findsOneWidget);
    expect(find.text('Prioridad BAJA'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Technician home handles read errors and fits a phone', (
    tester,
  ) async {
    final app = await _mountApp(
      tester,
      role: UserRole.technician,
      size: const Size(390, 844),
    );
    app.incidents.ownChanges.addError(
      FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
    );
    await tester.pumpAndSettle();
    expect(find.text('No pudimos cargar tus asignaciones.'), findsOneWidget);
    expect(find.text('Todavía no tenés incidencias asignadas.'), findsNothing);
    await _tap(tester, 'technician-home-retry');
    expect(
      find.byKey(const ValueKey('technician-home-count-4')),
      findsOneWidget,
    );
    await _tap(tester, 'technician-home-view-workspace');
    await _tap(tester, 'workspace-tab-4');
    expect(find.text('No hay incidencias disponibles.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

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
        } else if (destination == CampusDestination.categories) {
          expect(find.byKey(const ValueKey('categories-page')), findsOneWidget);
          expect(find.text('Nueva categoría'), findsOneWidget);
        } else if (destination == CampusDestination.dashboard) {
          expect(find.byKey(const ValueKey('dashboard-page')), findsOneWidget);
          expect(find.text('Indicadores del campus'), findsOneWidget);
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
  testWidgets('Profile sends a password-change link to the signed-in email', (
    tester,
  ) async {
    final app = await _mountApp(tester, role: UserRole.reporter);
    await _tap(tester, 'nav-profile');
    expect(find.textContaining('alex@campusfix.test'), findsWidgets);
    await _tap(tester, 'profile-change-password');
    expect(app.auth.passwordResetCalls, 1);
    expect(app.auth.submittedEmail, 'alex@campusfix.test');
    expect(
      find.textContaining('Enlace enviado. Revisá tu correo'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('profile-page')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Profile password link errors allow retry without claiming success',
    (tester) async {
      final app = await _mountApp(tester, role: UserRole.technician);
      await _tap(tester, 'nav-profile');
      app.auth.signInError = FirebaseAuthException(
        code: 'network-request-failed',
      );
      await _tap(tester, 'profile-change-password');
      expect(
        find.text('No pudimos conectar. Revisá tu conexión a internet.'),
        findsOneWidget,
      );
      expect(find.textContaining('Enlace enviado.'), findsNothing);
      app.auth.signInError = null;
      await _tap(tester, 'profile-change-password');
      expect(app.auth.passwordResetCalls, 2);
      expect(
        find.textContaining('Enlace enviado. Revisá tu correo'),
        findsOneWidget,
      );
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
  return _TestApp(auth, users, incidents);
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
  final TestReportIncidents incidents;

  _TestApp(this.auth, this.users, this.incidents);
}
