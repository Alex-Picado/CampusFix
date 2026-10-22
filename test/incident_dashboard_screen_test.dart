import 'dart:io';
import 'dart:ui' as ui;

import 'package:campusfix/app/providers/app_providers.dart';
import 'package:campusfix/features/catalogs/repositories/category_repository.dart';
import 'package:campusfix/features/incidents/models/incident_status.dart';
import 'package:campusfix/features/users/models/user_profile.dart';
import 'package:campusfix/features/users/models/user_role.dart';
import 'package:campusfix/main.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/category_service.dart';
import 'support/dashboard_repositories.dart';
import 'support/test_repositories.dart';

void main() {
  setUpAll(() async {
    if (!const bool.fromEnvironment('CAPTURE_DASHBOARD_EVIDENCE')) return;
    const directory = '.fvm/sdk-3.47.5/bin/cache/artifacts/material_fonts';
    for (final entry in {
      'Roboto': 'roboto-regular.ttf',
      'MaterialIcons': 'materialicons-regular.otf',
    }.entries) {
      final loader = FontLoader(entry.key)
        ..addFont(
          Future.value(
            ByteData.sublistView(
              await File('$directory/${entry.value}').readAsBytes(),
            ),
          ),
        );
      await loader.load();
    }
  });

  for (final tablet in [false, true]) {
    testWidgets(
      '${tablet ? 'Tablet' : 'Desktop'} shows the nine-state acceptance dataset without overflow',
      (tester) async {
        final app = await _mount(tester, tablet: tablet);
        await _navigate(tester, 'dashboard', tablet: tablet);
        _expectMetrics(
          tester,
          total: '9',
          open: '4',
          inProgress: '1',
          resolved: '1',
          closed: '1',
        );
        for (final entry in {
          'lighting': '4',
          'network': '3',
          'building': '2',
        }.entries) {
          expect(
            _value(tester, 'dashboard-category-count-${entry.key}'),
            entry.value,
          );
        }
        expect(find.text('ID: network · Inactiva'), findsOneWidget);
        expect(find.byType(LinearProgressIndicator), findsNWidgets(3));
        expect(app.reports.activeWatches, 1);
        expect(app.users.allUsersWatchCalls, 0);
        expect(tester.takeException(), isNull);
        if (const bool.fromEnvironment('CAPTURE_DASHBOARD_EVIDENCE')) {
          await _capture(
            tester,
            app.captureKey,
            'phase_4_dashboard_${tablet ? 'tablet' : 'desktop'}',
          );
        }
      },
    );
  }

  testWidgets(
    'Global totals remain complete after a restrictive Management search',
    (tester) async {
      final app = await _mount(tester);
      await _navigate(tester, 'management');
      final query = find.byWidgetPredicate(
        (widget) =>
            widget is TextFormField &&
            widget.key.toString().contains('incident-search-query-'),
      );
      await tester.enterText(query, '#1');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('incident-case-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('incident-case-1')), findsNothing);
      await _navigate(tester, 'dashboard');
      _expectMetrics(
        tester,
        total: '9',
        open: '4',
        inProgress: '1',
        resolved: '1',
        closed: '1',
      );
      expect(app.reports.activeWatches, 1);
      expect(app.users.activeAllUsersWatches, 0);
      expect(query, findsNothing);
    },
  );

  testWidgets(
    'Live incident and category changes refresh labels and separate identical names',
    (tester) async {
      final app = await _mount(tester);
      await _navigate(tester, 'dashboard');
      app.reports.replace([
        app.reports.rows.first.copyWith(status: IncidentStatus.closed),
        app.reports.rows[4],
      ]);
      app.categories.documents['lighting'] = {
        'name': 'Redes',
        'isActive': false,
      };
      app.categories.changes.add(null);
      await tester.pumpAndSettle();
      _expectMetrics(
        tester,
        total: '2',
        open: '0',
        inProgress: '0',
        resolved: '1',
        closed: '1',
      );
      expect(find.text('Redes'), findsNWidgets(2));
      expect(_value(tester, 'dashboard-category-count-lighting'), '1');
      expect(_value(tester, 'dashboard-category-count-network'), '1');
      expect(find.text('ID: lighting · Inactiva'), findsOneWidget);
      expect(app.reports.calls, 1);
    },
  );

  testWidgets(
    'Missing catalog records remain counted and show their stable ID',
    (tester) async {
      final app = await _mount(tester);
      app.categories.documents.remove('network');
      await _navigate(tester, 'dashboard');
      expect(find.text('Categoría no disponible'), findsOneWidget);
      expect(find.text('ID: network'), findsOneWidget);
      expect(_value(tester, 'dashboard-category-count-network'), '3');
      expect(_value(tester, 'dashboard-total'), '9');
    },
  );

  testWidgets('Empty data shows zero metrics and an explicit empty state', (
    tester,
  ) async {
    final app = await _mount(tester);
    app.reports.rows = [];
    await _navigate(tester, 'dashboard');
    _expectMetrics(
      tester,
      total: '0',
      open: '0',
      inProgress: '0',
      resolved: '0',
      closed: '0',
    );
    expect(
      find.text('Todavía no hay incidencias registradas.'),
      findsOneWidget,
    );
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets(
    'Loading and a failed incident query never masquerade as zero data',
    (tester) async {
      final app = await _mount(tester);
      app.reports.loadImmediately = false;
      await tester.tap(find.byKey(const ValueKey('nav-dashboard')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byKey(const ValueKey('dashboard-total')), findsNothing);
      app.reports.changes.addError(_unavailable());
      await tester.pumpAndSettle();
      expect(
        find.text('No se pudieron actualizar los indicadores.'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('dashboard-total')), findsNothing);
      expect(
        find.text('Todavía no hay incidencias registradas.'),
        findsNothing,
      );
      app.reports.loadImmediately = true;
      await tester.tap(find.byKey(const ValueKey('dashboard-retry')));
      await tester.pumpAndSettle();
      expect(_value(tester, 'dashboard-total'), '9');
      expect(app.categories.allCalls, 1);
    },
  );

  testWidgets(
    'A category failure keeps global counts visible and retries labels alone',
    (tester) async {
      final app = await _mount(tester);
      await _navigate(tester, 'dashboard');
      app.categories.changes.addError(_unavailable());
      await tester.pumpAndSettle();
      expect(_value(tester, 'dashboard-total'), '9');
      expect(
        find.text('No se pudieron consultar los nombres de las categorías.'),
        findsOneWidget,
      );
      expect(find.byType(LinearProgressIndicator), findsNothing);
      await tester.ensureVisible(
        find.byKey(const ValueKey('dashboard-categories-retry')),
      );
      await tester.tap(
        find.byKey(const ValueKey('dashboard-categories-retry')),
      );
      await tester.pumpAndSettle();
      expect(_value(tester, 'dashboard-category-count-network'), '3');
      expect(app.reports.calls, 1);
    },
  );

  testWidgets(
    'Leaving the dashboard releases both streams and reopening reads fresh data',
    (tester) async {
      final app = await _mount(tester);
      await _navigate(tester, 'dashboard');
      await _navigate(tester, 'overview');
      expect(app.reports.activeWatches, 0);
      expect(app.categories.activeAllWatches, 0);
      app.reports.rows = [];
      await _navigate(tester, 'dashboard');
      expect(_value(tester, 'dashboard-total'), '0');
      expect(app.reports.calls, 2);
      expect(app.reports.activeWatches, 1);
    },
  );

  testWidgets(
    'Role loss removes the dashboard and cancels administrative observations',
    (tester) async {
      final app = await _mount(tester);
      await _navigate(tester, 'dashboard');
      app.users.put(_profile(UserRole.reporter));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('dashboard-page')), findsNothing);
      expect(find.byKey(const ValueKey('nav-dashboard')), findsNothing);
      expect(app.reports.activeWatches, 0);
      expect(app.categories.activeAllWatches, 0);
      expect(tester.takeException(), isNull);
    },
  );
}

FirebaseException _unavailable() =>
    FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');

String? _value(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(ValueKey(key))).data;

void _expectMetrics(
  WidgetTester tester, {
  required String total,
  required String open,
  required String inProgress,
  required String resolved,
  required String closed,
}) {
  for (final entry in {
    'total': total,
    'open': open,
    'in-progress': inProgress,
    'resolved': resolved,
    'closed': closed,
  }.entries) {
    expect(_value(tester, 'dashboard-${entry.key}'), entry.value);
  }
}

Future<void> _navigate(
  WidgetTester tester,
  String page, {
  bool tablet = false,
}) async {
  if (tablet) {
    await tester.tap(find.byTooltip('Abrir menú'));
    await tester.pumpAndSettle();
  }
  await tester.tap(find.byKey(ValueKey('nav-$page')));
  await tester.pumpAndSettle();
}

Future<void> _capture(
  WidgetTester tester,
  GlobalKey captureKey,
  String name,
) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.ensureVisible(find.text('Indicadores del campus'));
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    final boundary =
        captureKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final directory = Directory('build/evidence/parte_4')
      ..createSync(recursive: true);
    File('${directory.path}/$name.png')
        .writeAsBytesSync(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

UserProfile _profile(UserRole role) => UserProfile(
  id: 'admin',
  fullName: 'Daniel',
  email: 'daniel@campusfix.test',
  role: role,
);

Future<
  ({
    TestAuthRepository auth,
    TestUserRepository users,
    TestDashboardIncidents reports,
    TestCategoryService categories,
    GlobalKey captureKey,
  })
>
_mount(WidgetTester tester, {bool tablet = false}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = tablet
      ? const Size(768, 1024)
      : const Size(1440, 1100);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final users = TestUserRepository()..put(_profile(UserRole.administrator));
  final auth = TestAuthRepository(users: users, currentUserId: 'admin');
  final reports = TestDashboardIncidents();
  final categories = TestCategoryService()
    ..documents.addAll({
      'lighting': {'name': 'Iluminación', 'isActive': true},
      'network': {'name': 'Redes', 'isActive': false},
      'building': {'name': 'Infraestructura', 'isActive': true},
    });
  final captureKey = GlobalKey();
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    expect(reports.activeWatches, 0);
    expect(categories.activeAllWatches, 0);
    await auth.close();
    await users.close();
    await reports.close();
    await categories.close();
  });
  await tester.pumpWidget(
    RepaintBoundary(
      key: captureKey,
      child: AppProviders(
        authRepository: auth,
        userRepository: users,
        categoryRepository: CategoryRepository(categoryService: categories),
        incidentRepository: reports,
        child: const MyApp(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (
    auth: auth,
    users: users,
    reports: reports,
    categories: categories,
    captureKey: captureKey,
  );
}
