import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:campusfix/app/providers/app_providers.dart';
import 'package:campusfix/features/catalogs/models/category.dart' as catalogs;
import 'package:campusfix/features/incidents/models/incident.dart';
import 'package:campusfix/features/incidents/models/incident_history_event.dart';
import 'package:campusfix/features/incidents/models/incident_progress.dart';
import 'package:campusfix/features/incidents/repositories/incident_repository.dart';
import 'package:campusfix/features/users/models/user_profile.dart';
import 'package:campusfix/features/users/models/user_role.dart';
import 'package:campusfix/main.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/report_repositories.dart';
import 'support/test_repositories.dart';

void main() {
  setUpAll(() async {
    if (!const bool.fromEnvironment('CAPTURE_SEARCH_EVIDENCE')) return;
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
  for (final role in UserRole.values) {
    testWidgets(
      '${role.name} searches only authorized cases by sequence text and inactive category',
      (tester) async {
        final app = await _mount(tester, role: role);
        expect(app.reports.activeListWatches, 1);
        expect(
          find.byKey(const ValueKey('incident-foreign')),
          role == UserRole.administrator ? findsOneWidget : findsNothing,
        );
        await _enter(tester, '#12');
        expect(find.byKey(const ValueKey('incident-light')), findsOneWidget);
        expect(find.byKey(const ValueKey('incident-network')), findsNothing);
        expect(find.byKey(const ValueKey('incident-foreign')), findsNothing);
        await _enter(tester, 'ILUMINACION');
        expect(find.byKey(const ValueKey('incident-light')), findsOneWidget);
        await _chooseCategory(tester, 'Redes (inactiva)');
        expect(
          find.text('No hay incidencias que coincidan con la búsqueda.'),
          findsOneWidget,
        );
        await _enter(tester, 'biblioteca');
        expect(find.byKey(const ValueKey('incident-network')), findsOneWidget);
        expect(find.byKey(const ValueKey('incident-light')), findsNothing);
        expect(app.reports.queryCalls, 1);
        expect(
          app.reports.lastScope,
          role == UserRole.administrator
              ? 'all'
              : role == UserRole.technician
              ? 'assigned:tech'
              : 'own:reporter',
        );
        await _tap(tester, 'incident-search-clear');
        expect(find.byKey(const ValueKey('incident-light')), findsOneWidget);
        expect(find.byKey(const ValueKey('incident-network')), findsOneWidget);
        expect(
          find.text(
            'Resultados: ${role == UserRole.administrator ? 3 : 2} de ${role == UserRole.administrator ? 3 : 2}',
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'Live snapshots reapply the current search without restarting its query',
    (tester) async {
      final app = await _mount(tester);
      await _enter(tester, 'biblioteca');
      app.reports.rows['new'] = _incident(
        'new',
        30,
        title: 'Luz de biblioteca',
      );
      app.reports.changes.add(null);
      await tester.pumpAndSettle();
      expect(find.text('Resultados: 2 de 4'), findsOneWidget);
      app.reports.rows.remove('network');
      app.reports.changes.add(null);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('incident-network')), findsNothing);
      expect(find.byKey(const ValueKey('incident-new')), findsOneWidget);
      expect(app.reports.queryCalls, 1);
    },
  );

  testWidgets(
    'Returning from detail restores criteria after releasing list and category listeners',
    (tester) async {
      final app = await _mount(tester, role: UserRole.reporter);
      await _enter(tester, '#12');
      await _chooseCategory(tester, 'Iluminación');
      await _tap(tester, 'detail-light');
      expect(
        find.byKey(const ValueKey('incident-detail-page')),
        findsOneWidget,
      );
      expect(app.reports.activeListWatches, 0);
      expect(app.categories.activeByIdWatches, 1);
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      expect(find.text('Resultados: 1 de 2'), findsOneWidget);
      expect(
        _query(tester).controller?.text ?? _query(tester).initialValue,
        '#12',
      );
      expect(find.byKey(const ValueKey('incident-network')), findsNothing);
      expect(app.reports.activeListWatches, 1);
      expect(app.categories.activeByIdWatches, 2);
    },
  );

  testWidgets(
    'A list error clears results and category reads and retry retains text',
    (tester) async {
      final app = await _mount(tester);
      await _enter(tester, '#12');
      app.reports.changes.addError(_offline());
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('incident-light')), findsNothing);
      expect(find.byKey(const ValueKey('incident-search-count')), findsNothing);
      expect(app.categories.activeByIdWatches, 0);
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('incident-light')), findsOneWidget);
      expect(find.byKey(const ValueKey('incident-network')), findsNothing);
      expect(find.text('Resultados: 1 de 3'), findsOneWidget);
    },
  );

  testWidgets(
    'Category failures are explicit and retry without dropping search results',
    (tester) async {
      final app = await _mount(tester);
      await _enter(tester, '#12');
      app.categories.changes.addError(_offline());
      await tester.pumpAndSettle();
      expect(
        find.text('No se pudieron cargar algunas categorías.'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('incident-light')), findsOneWidget);
      await _tap(tester, 'incident-search-retry-categories');
      expect(
        find.text('No se pudieron cargar algunas categorías.'),
        findsNothing,
      );
      expect(app.reports.queryCalls, 1);
      expect(app.categories.activeByIdWatches, 2);
    },
  );

  testWidgets(
    'Switching accounts clears private text and restarts only the new authorized source',
    (tester) async {
      final app = await _mount(tester);
      await _enter(tester, 'privado del administrador');
      app.auth.setUser('reporter');
      await tester.pumpAndSettle();
      await _tap(tester, 'nav-incidents');
      expect(_query(tester).initialValue, '');
      expect(find.textContaining('privado del administrador'), findsNothing);
      expect(find.byKey(const ValueKey('incident-foreign')), findsNothing);
      expect(find.text('Resultados: 2 de 2'), findsOneWidget);
      await _tap(tester, 'session-sign-out');
      expect(app.categories.activeByIdWatches, 0);
      expect(app.reports.activeListWatches, 0);
      expect(find.byKey(const ValueKey('incident-search-count')), findsNothing);
    },
  );

  testWidgets(
    'A foreign assignment snapshot is rejected before it reaches technician search',
    (tester) async {
      final app = await _mount(tester, role: UserRole.technician);
      app.reports.leakAssignments = true;
      app.reports.changes.add(null);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('incident-foreign')), findsNothing);
      expect(
        find.text('No se pudo verificar la información de tus asignaciones.'),
        findsOneWidget,
      );
      expect(app.categories.activeByIdWatches, 0);
      expect(app.reports.activeListWatches, 0);
    },
  );

  for (final tablet in [false, true]) {
    testWidgets(
      'Search layout and results fit ${tablet ? 'tablet' : 'desktop'}',
      (tester) async {
        final app = await _mount(tester, tablet: tablet);
        await _enter(tester, 'iluminacion');
        await _chooseCategory(tester, 'Iluminación');
        expect(find.text('Resultados: 2 de 3'), findsOneWidget);
        expect(tester.takeException(), isNull);
        if (const bool.fromEnvironment('CAPTURE_SEARCH_EVIDENCE')) {
          FocusManager.instance.primaryFocus?.unfocus();
          await tester.pumpAndSettle();
          await tester.runAsync(() async {
            final boundary =
                app.captureKey.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await boundary.toImage(pixelRatio: 1);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final directory = Directory('build/evidence')
              ..createSync(recursive: true);
            File(
              '${directory.path}/phase_2_search_${tablet ? 'tablet' : 'desktop'}.png',
            ).writeAsBytesSync(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
      },
    );
  }
}

FirebaseException _offline() =>
    FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');
TextFormField _query(WidgetTester tester) => tester.widget<TextFormField>(
  find.byWidgetPredicate(
    (widget) =>
        widget is TextFormField &&
        widget.key.toString().contains('incident-search-query-'),
  ),
);
Future<void> _enter(WidgetTester tester, String text) async {
  final finder = find.byWidgetPredicate(
    (widget) =>
        widget is TextFormField &&
        widget.key.toString().contains('incident-search-query-'),
  );
  await tester.ensureVisible(finder);
  await tester.enterText(finder, text);
  await tester.pumpAndSettle();
}

Future<void> _chooseCategory(WidgetTester tester, String label) async {
  final finder = find.byWidgetPredicate(
    (widget) =>
        widget is DropdownButtonFormField<String> &&
        widget.key.toString().contains('incident-search-category-'),
  );
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Incident _incident(
  String id,
  int sequence, {
  String title = 'Iluminación del aula',
  String category = 'lighting',
  String author = 'reporter',
  String technician = 'tech',
  String location = 'Edificio A',
}) => Incident(
  id: id,
  sequenceNumber: sequence,
  title: title,
  description: 'Inspección de servicio en el campus',
  categoryId: category,
  location: location,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  createdByUserId: author,
  assignedTechnicianId: technician,
);

Future<
  ({
    TestAuthRepository auth,
    TestUserRepository users,
    _Reports reports,
    TestReportCategories categories,
    GlobalKey captureKey,
  })
>
_mount(
  WidgetTester tester, {
  UserRole role = UserRole.administrator,
  bool tablet = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = tablet
      ? const Size(768, 1024)
      : const Size(1440, 1100);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final users = TestUserRepository();
  for (final entry in {
    'admin': UserRole.administrator,
    'reporter': UserRole.reporter,
    'tech': UserRole.technician,
  }.entries) {
    users.profiles[entry.key] = UserProfile(
      id: entry.key,
      fullName: entry.key,
      email: '${entry.key}@campusfix.test',
      role: entry.value,
    );
  }
  final uid = role == UserRole.administrator
      ? 'admin'
      : role == UserRole.technician
      ? 'tech'
      : 'reporter';
  final auth = TestAuthRepository(users: users, currentUserId: uid);
  final reports = _Reports()
    ..rows.addAll({
      'light': _incident('light', 12),
      'network': _incident(
        'network',
        112,
        title: 'Conexión inestable',
        category: 'network',
        location: 'Biblioteca',
      ),
      'foreign': _incident(
        'foreign',
        3,
        title: 'Iluminación del pasillo',
        author: 'other-reporter',
        technician: 'other-tech',
      ),
    });
  final categories = TestReportCategories();
  categories.initial = const [
    catalogs.Category(id: 'lighting', name: 'Iluminación'),
    catalogs.Category(id: 'network', name: 'Redes', isActive: false),
  ];
  final captureKey = GlobalKey();
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await auth.close();
    await users.close();
    await reports.changes.close();
    await categories.close();
  });
  await tester.pumpWidget(
    RepaintBoundary(
      key: captureKey,
      child: AppProviders(
        authRepository: auth,
        userRepository: users,
        categoryRepository: categories,
        incidentRepository: reports,
        child: const MyApp(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  if (tablet) {
    await tester.tap(find.byTooltip('Abrir menú'));
    await tester.pumpAndSettle();
  }
  await _tap(
    tester,
    role == UserRole.administrator
        ? 'nav-management'
        : role == UserRole.technician
        ? 'nav-workspace'
        : 'nav-incidents',
  );
  return (
    auth: auth,
    users: users,
    reports: reports,
    categories: categories,
    captureKey: captureKey,
  );
}

class _Reports extends Fake implements IncidentRepository {
  final rows = <String, Incident>{};
  final changes = StreamController<void>.broadcast();
  int queryCalls = 0, activeListWatches = 0;
  String? lastScope;
  bool leakAssignments = false;
  Stream<List<Incident>> _watch(String scope, bool Function(Incident) accepts) {
    queryCalls++;
    lastScope = scope;
    return Stream.multi((sink) {
      activeListWatches++;
      void emit() => sink.add(List.unmodifiable(rows.values.where(accepts)));
      emit();
      final subscription = changes.stream.listen(
        (_) => emit(),
        onError: sink.addError,
      );
      sink.onCancel = () {
        activeListWatches--;
        subscription.cancel().ignore();
      };
    });
  }

  @override
  Stream<List<Incident>> watchAll() => _watch('all', (_) => true);
  @override
  Stream<List<Incident>> watchOwn({required String userId}) =>
      _watch('own:$userId', (row) => row.createdByUserId == userId);
  @override
  Stream<List<Incident>> watchAssigned({required String userId}) => _watch(
    'assigned:$userId',
    (row) => leakAssignments || row.assignedTechnicianId == userId,
  );
  @override
  Stream<Incident?> watchById({required String incidentId}) =>
      Stream.multi((sink) => sink.add(rows[incidentId]));
  @override
  Stream<List<IncidentHistoryEvent>> watchHistory({
    required String incidentId,
  }) => Stream.multi((sink) => sink.add(const []));
  @override
  Stream<List<IncidentProgress>> watchProgress({required String incidentId}) =>
      Stream.multi((sink) => sink.add(const []));
}
