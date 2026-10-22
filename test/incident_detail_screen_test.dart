import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:campusfix/app/providers/app_providers.dart';
import 'package:campusfix/features/catalogs/models/category.dart' as catalogs;
import 'package:campusfix/features/incidents/models/incident.dart';
import 'package:campusfix/features/incidents/models/incident_evidence.dart';
import 'package:campusfix/features/incidents/models/incident_history_event.dart';
import 'package:campusfix/features/incidents/models/incident_history_action.dart';
import 'package:campusfix/features/incidents/models/incident_progress.dart';
import 'package:campusfix/features/incidents/models/incident_status.dart';
import 'package:campusfix/features/incidents/models/selected_photo.dart';
import 'package:campusfix/features/incidents/repositories/evidence_repository.dart';
import 'package:campusfix/features/incidents/repositories/incident_repository.dart';
import 'package:campusfix/features/users/models/user_profile.dart';
import 'package:campusfix/features/users/models/user_role.dart';
import 'package:campusfix/main.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/report_repositories.dart';
import 'support/test_repositories.dart';

final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAIAAAD91JpzAAAACXBIWXMAAAPoAAAD6AG1e1JrAAAADklEQVQImWP4DwYMEAoAU7oL9W/sIDEAAAAASUVORK5CYII=',
);
FirebaseException _offline() =>
    FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');

void main() {
  for (final tablet in [false, true]) {
    testWidgets(
      'Photo-disabled client saves text progress on ${tablet ? 'tablet' : 'desktop'} without local photo operations',
      (tester) async {
        final app = await _mount(
          tester,
          technician: true,
          tablet: tablet,
          photosEnabled: false,
        );
        expect(
          find.textContaining(
            'Las fotografías están disponibles en la versión local.',
          ),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('progress-photo')), findsNothing);
        expect(find.byKey(const ValueKey('photo-select')), findsNothing);
        await _enter(
          tester,
          'progress-description',
          'Inspección sin fotografía',
        );
        await _tap(tester, 'progress-save');
        expect(find.text('Avance guardado correctamente.'), findsOneWidget);
        expect(app.reports.entries, hasLength(1));
        expect(app.reports.photoReference, isNull);
        expect(app.photos.uploads, 0);
        expect(app.photos.attachments, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'Inactive category names remain live in historical details and release on sign-out',
    (tester) async {
      final app = await _mount(tester);
      expect(find.text('Categoría: Iluminación'), findsOneWidget);
      app.categories.changes.add(const [
        catalogs.Category(id: 'lighting', name: 'Alumbrado', isActive: false),
      ]);
      await tester.pumpAndSettle();
      expect(find.text('Categoría: Alumbrado (inactiva)'), findsOneWidget);
      expect(app.categories.activeByIdWatches, 1);
      app.categories.changes.addError(_offline());
      await tester.pumpAndSettle();
      expect(find.text('Categoría: Alumbrado (inactiva)'), findsNothing);
      expect(
        find.byKey(const ValueKey('incident-detail-page')),
        findsOneWidget,
      );
      app.categories.initial = const [
        catalogs.Category(id: 'lighting', name: 'Alumbrado', isActive: false),
      ];
      await _tap(tester, 'category-retry');
      expect(find.text('Categoría: Alumbrado (inactiva)'), findsOneWidget);
      app.auth.setUser(null);
      await tester.pumpAndSettle();
      expect(app.categories.activeByIdWatches, 0);
      expect(find.text('Categoría: Alumbrado (inactiva)'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Protected routes show detail, history and live comments after authentication',
    (tester) async {
      final app = await _mount(tester, signedIn: false);
      expect(find.byKey(const ValueKey('auth-email')), findsOneWidget);
      expect(app.reports.active, 0);
      app.auth.setUser('reporter');
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('incident-detail-page')),
        findsOneWidget,
      );
      expect(find.text('Incidencia #1'), findsOneWidget);
      expect(find.textContaining('Incidencia reportada'), findsOneWidget);
      expect(find.byKey(const ValueKey('progress-save')), findsNothing);
      app.reports.entries['p'] = IncidentProgress(
        id: 'p',
        authorUserId: 'tech',
        createdAt: DateTime.utc(2026),
        description: 'Live inspection',
      );
      app.reports.changes.add(null);
      await tester.pumpAndSettle();
      expect(find.text('Live inspection'), findsOneWidget);
      app.users.put(_profile('reporter', UserRole.technician));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('progress-save')), findsNothing);
      app.auth.setUser(null);
      await tester.pumpAndSettle();
      expect(app.reports.active, 0);
      expect(find.text('Live inspection'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'The assigned technician saves progress and retries the same failed submission',
    (tester) async {
      final app = await _mount(tester, technician: true);
      await _tap(tester, 'progress-save');
      expect(find.text('Describí el avance realizado.'), findsOneWidget);
      await _enter(tester, 'progress-description', '  Inspection complete  ');
      app.reports.failure = _offline();
      await _tap(tester, 'progress-save');
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('progress-description')),
            )
            .readOnly,
        isTrue,
      );
      final id = app.reports.submissions.single;
      app.reports.failure = null;
      await _tap(tester, 'progress-save');
      expect(app.reports.submissions, [id, id]);
      expect(find.text('Avance guardado correctamente.'), findsOneWidget);
      expect(find.text('Inspection complete'), findsWidgets);
      expect(app.reports.entries, hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'An uploaded photograph retries association without uploading twice',
    (tester) async {
      final app = await _mount(tester);
      await _tap(tester, 'photo-select');
      app.photos.attachFailure = _offline();
      await _tap(tester, 'photo-upload');
      expect(app.photos.uploads, 1);
      expect(app.photos.journal, isNotEmpty);
      app.photos.attachFailure = null;
      await _tap(tester, 'photo-upload');
      expect(app.photos.uploads, 1);
      expect(app.photos.attachments, 2);
      expect(app.photos.journal, isEmpty);
      expect(find.text('Fotografía guardada correctamente.'), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Permission errors clear detail and photographs instead of retaining stale data',
    (tester) async {
      final app = await _mount(tester);
      app.reports.changes.addError(
        FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('incident-detail-page')), findsNothing);
      expect(
        find.text('No tenés permiso para realizar esta acción.'),
        findsOneWidget,
      );
      expect(app.reports.active, 0);
      await _tap(tester, 'detail-retry');
      expect(
        find.byKey(const ValueKey('incident-detail-page')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'A missing document has a missing state without opening child queries',
    (tester) async {
      final app = await _mount(tester, missing: true);
      expect(find.text('No se encontró esta incidencia.'), findsOneWidget);
      expect(app.reports.childWatches, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Tablet progress supports optional evidence and blocks duplicate pending submissions',
    (tester) async {
      final app = await _mount(tester, technician: true, tablet: true);
      await _enter(tester, 'progress-description', 'Inspected with photo');
      await _tap(tester, 'progress-photo');
      final blocker = Completer<void>();
      app.reports.blocker = blocker;
      addTearDown(() {
        if (!blocker.isCompleted) blocker.complete();
      });
      await tester.ensureVisible(find.byKey(const ValueKey('progress-save')));
      await tester.tap(find.byKey(const ValueKey('progress-save')));
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('progress-save')))
            .onPressed,
        isNull,
      );
      blocker.complete();
      await tester.pumpAndSettle();
      expect(app.photos.uploads, 1);
      expect(app.reports.photoReference, isNotNull);
      expect(app.reports.submissions, hasLength(1));
      expect(find.text('Avance guardado correctamente.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _tap(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _enter(WidgetTester tester, String key, String text) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.enterText(finder, text);
  await tester.pump();
}

UserProfile _profile(String id, UserRole role) =>
    UserProfile(id: id, fullName: id, email: '$id@test.invalid', role: role);

Future<
  ({
    TestAuthRepository auth,
    TestUserRepository users,
    _Reports reports,
    _Photos photos,
    TestReportCategories categories,
  })
>
_mount(
  WidgetTester tester, {
  bool technician = false,
  bool signedIn = true,
  bool missing = false,
  bool tablet = false,
  bool photosEnabled = true,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = tablet
      ? const Size(768, 1024)
      : const Size(1280, 900);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final uid = technician ? 'tech' : 'reporter';
  final users = TestUserRepository()
    ..profiles[uid] = _profile(
      uid,
      technician ? UserRole.technician : UserRole.reporter,
    );
  final auth = TestAuthRepository(
    users: users,
    currentUserId: signedIn ? uid : null,
  );
  final reports = _Reports()..missing = missing;
  final photos = _Photos(uid);
  final categories = TestReportCategories();
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await auth.close();
    await users.close();
    await reports.changes.close();
    await photos.changes.close();
    await categories.close();
  });
  await tester.pumpWidget(
    AppProviders(
      authRepository: auth,
      userRepository: users,
      categoryRepository: categories,
      incidentRepository: reports,
      evidenceRepository: photosEnabled ? photos : null,
      child: const MyApp(),
    ),
  );
  await tester.pumpAndSettle();
  unawaited(
    tester
        .state<NavigatorState>(find.byType(Navigator))
        .pushNamed('/incidents/case'),
  );
  await tester.pumpAndSettle();
  return (
    auth: auth,
    users: users,
    reports: reports,
    photos: photos,
    categories: categories,
  );
}

class _Reports extends Fake implements IncidentRepository {
  final changes = StreamController<void>.broadcast();
  final entries = <String, IncidentProgress>{};
  final submissions = <String>[];
  Object? failure;
  Completer<void>? blocker;
  Map<String, dynamic>? photoReference;
  bool missing = false;
  int active = 0, childWatches = 0, ids = 0;
  @override
  String newIncidentId() => 'progress-${++ids}';
  Stream<T> watch<T>(T Function() current) => Stream.multi((sink) {
    active++;
    sink.add(current());
    final subscription = changes.stream.listen(
      (_) => sink.add(current()),
      onError: sink.addError,
    );
    sink.onCancel = () {
      active--;
      subscription.cancel().ignore();
    };
  });
  @override
  Stream<Incident?> watchById({required String incidentId}) => watch(
    () => missing
        ? null
        : Incident(
            id: 'case',
            sequenceNumber: 1,
            title: 'Broken light',
            description: 'Inspect the classroom.',
            categoryId: 'lighting',
            location: 'Building A',
            createdAt: DateTime.utc(2026),
            updatedAt: DateTime.utc(2026),
            createdByUserId: 'reporter',
            assignedTechnicianId: 'tech',
            status: IncidentStatus.inProgress,
          ),
  );
  @override
  Stream<List<IncidentProgress>> watchProgress({required String incidentId}) {
    childWatches++;
    return watch(() => entries.values.toList());
  }

  @override
  Stream<List<IncidentHistoryEvent>> watchHistory({
    required String incidentId,
  }) {
    childWatches++;
    return watch(
      () => [
        IncidentHistoryEvent(
          id: 'created',
          actorUserId: 'reporter',
          createdAt: DateTime.utc(2026),
          action: IncidentHistoryAction.created,
        ),
        ...entries.values.map(
          (entry) => IncidentHistoryEvent(
            id: entry.id,
            actorUserId: entry.authorUserId,
            createdAt: entry.createdAt,
            action: IncidentHistoryAction.progressAdded,
          ),
        ),
      ],
    );
  }

  @override
  Future<void> addProgress({
    required String incidentId,
    required String progressId,
    required String description,
    String? evidenceId,
    Map<String, dynamic>? reference,
  }) async {
    submissions.add(progressId);
    photoReference = reference;
    await blocker?.future;
    if (failure != null) throw failure!;
    entries[progressId] = IncidentProgress(
      id: progressId,
      authorUserId: 'tech',
      createdAt: DateTime.utc(2026, 2),
      description: description,
    );
    changes.add(null);
  }
}

class _Photos extends Fake implements EvidenceRepository {
  final String uid;
  _Photos(this.uid);
  final journal = <String, Map<String, dynamic>>{};
  final changes = StreamController<void>.broadcast();
  final metadata = <IncidentEvidence>[];
  int ids = 0, uploads = 0, attachments = 0;
  Object? attachFailure;
  @override
  String newId() => 'photo-${++ids}';
  @override
  Future<SelectedPhoto?> selectPhoto() async => SelectedPhoto(
    bytes: _png,
    fileName: 'photo.png',
    contentType: 'image/png',
  );
  @override
  Future<Map<String, dynamic>> upload(
    String uid,
    String incidentId,
    String id,
    SelectedPhoto photo, {
    String? progressId,
  }) async {
    uploads++;
    return {
      'assetId': '$incidentId/$id',
      'url': '/incidents/$incidentId/evidence/$id',
      'fileName': 'photo.png',
      'contentType': 'image/png',
      'sizeBytes': _png.length,
    };
  }

  @override
  Future<void> attach(
    String incidentId,
    String id,
    Map<String, dynamic> reference,
  ) async {
    attachments++;
    if (attachFailure != null) throw attachFailure!;
    metadata.add(
      IncidentEvidence.fromMap(
        id: id,
        data: {
          ...reference,
          'provider': 'local',
          'createdAt': DateTime.utc(2026),
          'uploadedByUserId': uid,
        },
      ),
    );
    changes.add(null);
  }

  @override
  Stream<List<IncidentEvidence>> watch(String incidentId) =>
      Stream.multi((sink) {
        sink.add(List.of(metadata));
        final subscription = changes.stream.listen(
          (_) => sink.add(List.of(metadata)),
        );
        sink.onCancel = subscription.cancel;
      });
  @override
  Future<Uint8List> download(String uid, IncidentEvidence evidence) async =>
      _png;
  @override
  Map<String, dynamic>? recover(String uid, String incidentId, String kind) =>
      journal['$uid:$incidentId:$kind'];
  @override
  void remember(
    String uid,
    String incidentId,
    String kind,
    Map<String, dynamic>? value,
  ) {
    final key = '$uid:$incidentId:$kind';
    if (value == null) {
      journal.remove(key);
    } else {
      journal[key] = Map.of(value);
    }
  }
}
