import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:flutter_test/flutter_test.dart';

import 'package:campusfix/features/auth/controllers/session_controller.dart';
import 'package:campusfix/features/auth/models/session_status.dart';
import 'package:campusfix/features/catalogs/models/category.dart';
import 'package:campusfix/features/catalogs/repositories/category_repository.dart';
import 'package:campusfix/features/incidents/controllers/incident_report_controller.dart';
import 'package:campusfix/features/incidents/models/incident.dart';
import 'package:campusfix/features/incidents/repositories/incident_repository.dart';
import 'package:campusfix/features/users/models/user_profile.dart';
import 'package:campusfix/features/users/models/user_role.dart';

const _lighting = Category(id: 'lighting', name: 'Iluminación');
const _plumbing = Category(id: 'plumbing', name: 'Fontanería');

UserProfile _profile({
  String id = 'reporter-1',
  UserRole role = UserRole.reporter,
  String name = 'Reporter',
}) =>
    UserProfile(id: id, fullName: name, email: '$id@example.test', role: role);

Future<void> _flush() => Future<void>.delayed(Duration.zero);

FirebaseException _unavailable() =>
    FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');

void main() {
  late _ReportHarness harness;
  late IncidentReportController controller;

  setUp(() {
    harness = _ReportHarness();
    controller = harness.controller;
  });

  tearDown(() => harness.dispose());

  test(
    'Preserves editable input while loading and distinguishes empty data',
    () async {
      expect(controller.isLoadingCategories, isTrue);
      controller.updateDraft(title: '  Private title  ');
      expect(await controller.submit(), isNull);
      expect(controller.draft.title, '  Private title  ');
      expect(harness.incidents.allocations, 0);

      await harness.categories.emit([]);
      expect(controller.isLoadingCategories, isFalse);
      expect(controller.categories, isEmpty);
      expect(controller.loadErrorMessage, isNull);
      expect(controller.canSubmit, isFalse);

      await harness.categories.emit([_lighting]);
      expect(controller.canSubmit, isTrue);
      expect(() => controller.categories.clear(), throwsUnsupportedError);
      expect(controller.draft.title, '  Private title  ');
    },
  );

  test(
    'Retries failed category observation without losing draft text',
    () async {
      controller.updateDraft(description: 'Detailed input');
      harness.categories.channels.single.addError(_unavailable());
      await _flush();
      expect(controller.loadErrorMessage, isNotNull);
      expect(controller.isLoadingCategories, isFalse);
      expect(controller.canSubmit, isFalse);
      expect(harness.categories.cancellations, 1);

      controller.startCategories();
      expect(controller.isLoadingCategories, isTrue);
      expect(controller.loadErrorMessage, isNull);
      await harness.categories.emit([_lighting]);
      expect(controller.canSubmit, isTrue);
      expect(controller.draft.description, 'Detailed input');
      expect(harness.categories.channels, hasLength(2));
    },
  );

  test(
    'Treats an unexpectedly closed category stream as an observation error',
    () async {
      await harness.categories.emit([_lighting]);
      await harness.categories.channels.single.close();
      expect(controller.categories, isEmpty);
      expect(controller.loadErrorMessage, isNotNull);
      expect(controller.canSubmit, isFalse);
    },
  );

  test(
    'Validates required fields before allocating IDs or submitting',
    () async {
      await harness.categories.emit([_lighting]);
      controller.updateDraft(title: ' \t ', description: '\n', location: '  ');
      expect(await controller.submit(), isNull);
      expect(
        controller.fieldErrors.keys,
        unorderedEquals(['title', 'description', 'location', 'categoryId']),
      );
      expect(() => controller.fieldErrors.clear(), throwsUnsupportedError);
      expect(harness.incidents.allocations, 0);
      expect(harness.incidents.submissions, isEmpty);

      controller.updateDraft(title: 'Light', categoryId: 'lighting');
      expect(
        controller.fieldErrors.keys,
        unorderedEquals(['description', 'location']),
      );
    },
  );

  test(
    'Clears an invalid category instead of silently retaining an older choice',
    () async {
      await harness.readyDraft();
      controller.updateDraft(categoryId: 'unknown');
      expect(controller.draft.categoryId, isNull);
      expect(controller.selectedCategoryName, isNull);
      expect(controller.fieldErrors, contains('categoryId'));
      expect(await controller.submit(), isNull);
      expect(harness.incidents.allocations, 0);
    },
  );

  test(
    'Tracks category renames and invalidates removed editable selections',
    () async {
      await harness.readyDraft();
      await harness.categories.emit([
        const Category(id: 'lighting', name: 'Electricidad'),
        _plumbing,
      ]);
      expect(controller.selectedCategoryName, 'Electricidad');
      await harness.categories.emit([_plumbing]);
      expect(controller.draft.categoryId, isNull);
      expect(controller.fieldErrors, contains('categoryId'));
      expect(
        controller.draft.description,
        '  Does not turn on.\nSecond line.  ',
      );
      expect(await controller.submit(), isNull);
      expect(harness.incidents.allocations, 0);
    },
  );

  test(
    'Keeps raw draft input until confirmation and submits normalized text',
    () async {
      await harness.readyDraft();
      final response = Completer<Incident>();
      harness.incidents.onCreate = (_) => response.future;
      final result = controller.submit();
      final request = harness.incidents.submissions.single;
      expect(controller.isSubmitting, isTrue);
      expect(controller.draft.title, '  Broken light  ');
      expect(request.title, 'Broken light');
      expect(request.description, 'Does not turn on.\nSecond line.');
      expect(request.location, 'Building A');
      expect(request.categoryId, 'lighting');
      expect(controller.successMessage, isNull);

      response.complete(request.confirmed());
      expect((await result)?.id, request.id);
      expect(controller.isSubmitting, isFalse);
      expect(controller.draft.title, 'Broken light');
      expect(controller.createdIncident?.sequenceNumber, 1);
      expect(controller.successMessage, contains('#1'));
      expect(controller.canEditDraft, isFalse);
      expect(controller.canSubmit, isFalse);
    },
  );

  test(
    'Blocks overlapping submissions and edits throughout a pending write',
    () async {
      await harness.readyDraft();
      final response = Completer<Incident>();
      harness.incidents.onCreate = (_) => response.future;
      final first = controller.submit();
      controller.updateDraft(title: 'Overlapping edit');
      controller.startCategories();
      expect(await controller.submit(), isNull);
      expect(await controller.resumeEditing(), isFalse);
      expect(controller.resetDraft(), isFalse);
      expect(controller.draft.title, '  Broken light  ');
      expect(harness.categories.channels, hasLength(1));
      expect(harness.incidents.submissions, hasLength(1));
      expect(harness.incidents.allocations, 1);
      response.complete(harness.incidents.submissions.single.confirmed());
      await first;
    },
  );

  test(
    'Blocks a reentrant submit triggered by submission notifications',
    () async {
      await harness.readyDraft();
      var notifications = 0;
      controller.addListener(() {
        notifications++;
        unawaited(controller.submit());
      });
      await controller.submit();
      expect(notifications, 2);
      expect(harness.incidents.allocations, 1);
      expect(harness.incidents.submissions, hasLength(1));
    },
  );

  test(
    'Retains the exact submission ID and payload after an uncertain failure',
    () async {
      await harness.readyDraft();
      harness.incidents.onCreate = (_) => Future.error(_unavailable());
      expect(await controller.submit(), isNull);
      final first = harness.incidents.submissions.single;
      expect(controller.submitErrorMessage, isNotNull);
      expect(controller.createdIncident, isNull);
      expect(controller.hasUnconfirmedSubmission, isTrue);
      expect(controller.canEditDraft, isFalse);
      expect(controller.canSubmit, isTrue);
      expect(controller.resetDraft(), isFalse);
      controller.updateDraft(title: 'Unsafe edit', clearCategory: true);
      expect(controller.draft.title, '  Broken light  ');
      expect(controller.draft.categoryId, 'lighting');

      harness.incidents.onCreate = null;
      expect((await controller.submit())?.id, first.id);
      expect(harness.incidents.allocations, 1);
      expect(harness.incidents.submissions.last.values, first.values);
      expect(controller.submitErrorMessage, isNull);
    },
  );

  test(
    'Recovers the original attempt even when its category is no longer listed',
    () async {
      await harness.readyDraft();
      harness.incidents.onCreate = (_) => Future.error(_unavailable());
      await controller.submit();
      final message = controller.submitErrorMessage;
      await harness.categories.emit([]);
      expect(controller.submitErrorMessage, message);
      expect(controller.draft.categoryId, 'lighting');
      expect(controller.selectedCategoryName, 'Iluminación');
      expect(controller.canSubmit, isTrue);
      harness.categories.channels.last.addError(_unavailable());
      await _flush();
      expect(controller.loadErrorMessage, isNotNull);
      expect(controller.canSubmit, isTrue);

      harness.incidents.onCreate = null;
      expect(await controller.submit(), isNotNull);
      expect(harness.incidents.submissions.last.categoryId, 'lighting');
      expect(harness.incidents.allocations, 1);
    },
  );

  test(
    'Leaves the draft editable when ID allocation fails before any write',
    () async {
      await harness.readyDraft();
      harness.incidents.allocationError = StateError('ID unavailable');
      expect(await controller.submit(), isNull);
      expect(controller.submitErrorMessage, isNotNull);
      expect(controller.hasUnconfirmedSubmission, isFalse);
      expect(controller.canEditDraft, isTrue);
      expect(harness.incidents.submissions, isEmpty);
      controller.updateDraft(title: 'Revised title');
      harness.incidents.allocationError = null;
      expect((await controller.submit())?.title, 'Revised title');
    },
  );

  test('Reconciles a saved report after a failed confirmation instead of unlocking edits', () async {
    await harness.failedSubmission();
    final request = harness.incidents.submissions.single;
    final review = controller.resumeEditing();
    expect(controller.isReviewing, isTrue);
    harness.incidents.reviews.single.add(request.confirmed());
    expect(await review, isFalse);
    expect(controller.createdIncident?.id, request.id);
    expect(controller.hasUnconfirmedSubmission, isFalse);
    expect(controller.isReviewing, isFalse);
    expect(controller.canEditDraft, isFalse);
    expect(harness.incidents.reviewCancellations, 1);
    expect(harness.incidents.submissions, hasLength(1));
  });

  test(
    'Unlocks a confirmed missing report but retains its reserved ID for edits',
    () async {
      await harness.failedSubmission();
      final first = harness.incidents.submissions.single;
      final review = controller.resumeEditing();
      harness.incidents.reviews.single.add(null);
      expect(await review, isTrue);
      expect(controller.hasUnconfirmedSubmission, isFalse);
      expect(controller.canEditDraft, isTrue);
      expect(controller.draft.title, '  Broken light  ');
      controller.updateDraft(title: 'Updated title');
      harness.incidents.onCreate = null;
      expect((await controller.submit())?.title, 'Updated title');
      expect(harness.incidents.submissions.last.id, first.id);
      expect(harness.incidents.allocations, 1);
      expect(harness.incidents.reviewCancellations, 1);
    },
  );

  test(
    'Revalidates a removed category after a confirmed missing report',
    () async {
      await harness.failedSubmission();
      await harness.categories.emit([_plumbing]);
      final review = controller.resumeEditing();
      harness.incidents.reviews.single.add(null);
      expect(await review, isTrue);
      expect(controller.draft.categoryId, isNull);
      expect(controller.fieldErrors, contains('categoryId'));
      expect(await controller.submit(), isNull);
      expect(harness.incidents.submissions, hasLength(1));
    },
  );

  test('Retains the locked submission when a server check fails', () async {
    await harness.failedSubmission();
    final review = controller.resumeEditing();
    harness.incidents.reviews.single.addError(_unavailable());
    expect(await review, isFalse);
    expect(controller.submitErrorMessage, isNotNull);
    expect(controller.hasUnconfirmedSubmission, isTrue);
    expect(controller.canEditDraft, isFalse);
    expect(controller.canResumeEditing, isTrue);
    expect(harness.incidents.reviewCancellations, 1);
  });

  test(
    'Does not interpret a closed check stream as confirmed absence',
    () async {
      await harness.failedSubmission();
      final review = controller.resumeEditing();
      await harness.incidents.reviews.single.close();
      expect(await review, isFalse);
      expect(controller.hasUnconfirmedSubmission, isTrue);
      expect(controller.submitErrorMessage, isNotNull);
    },
  );

  test(
    'Blocks writes, edits and duplicate checks during reconciliation',
    () async {
      await harness.failedSubmission();
      final review = controller.resumeEditing();
      expect(await controller.submit(), isNull);
      expect(await controller.resumeEditing(), isFalse);
      expect(controller.resetDraft(), isFalse);
      controller.updateDraft(title: 'Overlapping edit');
      expect(controller.draft.title, '  Broken light  ');
      expect(harness.incidents.reviews, hasLength(1));
      expect(harness.incidents.submissions, hasLength(1));
      harness.incidents.reviews.single.add(null);
      await review;
    },
  );

  test(
    'Releases an ID only after confirmation when starting another report',
    () async {
      await harness.readyDraft();
      final first = await controller.submit();
      expect(controller.resetDraft(), isTrue);
      expect(controller.createdIncident, isNull);
      expect(controller.successMessage, isNull);
      expect(controller.draft.title, isEmpty);
      expect(controller.draft.categoryId, isNull);
      expect(controller.canEditDraft, isTrue);
      await harness.readyDraft();
      final second = await controller.submit();
      expect(second?.id, isNot(first?.id));
      expect(harness.incidents.allocations, 2);
    },
  );

  test(
    'Retains a reserved ID when resetting after confirmed absence',
    () async {
      await harness.failedSubmission();
      final firstId = harness.incidents.submissions.single.id;
      final review = controller.resumeEditing();
      harness.incidents.reviews.single.add(null);
      await review;
      expect(controller.resetDraft(), isTrue);
      expect(controller.draft.title, isEmpty);
      await harness.readyDraft();
      harness.incidents.onCreate = null;
      expect((await controller.submit())?.id, firstId);
      expect(harness.incidents.allocations, 1);
    },
  );

  test(
    'Preserves the draft for a name update in the same reporter session',
    () async {
      await harness.readyDraft();
      harness.session.change(_profile(name: 'Updated name'));
      expect(controller.isActive, isTrue);
      expect(controller.draft.categoryId, 'lighting');
      expect(controller.draft.title, '  Broken light  ');
      expect(harness.categories.cancellations, 0);
      expect(await controller.submit(), isNotNull);
    },
  );

  for (final change in [
    (
      name: 'account change',
      profile: _profile(id: 'reporter-2'),
      status: SessionStatus.authenticated,
    ),
    (
      name: 'role change',
      profile: _profile(role: UserRole.technician),
      status: SessionStatus.authenticated,
    ),
    (name: 'sign out', profile: null, status: SessionStatus.signedOut),
    (
      name: 'profile failure',
      profile: _profile(),
      status: SessionStatus.failure,
    ),
  ]) {
    test(
      'Clears private state and cancels a pending check after ${change.name}',
      () async {
        await harness.failedSubmission();
        final review = controller.resumeEditing();
        harness.session.change(change.profile, status: change.status);
        expect(await review, isFalse);
        expect(controller.isActive, isFalse);
        expect(controller.draft.title, isEmpty);
        expect(controller.draft.categoryId, isNull);
        expect(controller.categories, isEmpty);
        expect(controller.fieldErrors, isEmpty);
        expect(controller.selectedCategoryName, isNull);
        expect(controller.createdIncident, isNull);
        expect(controller.submitErrorMessage, isNull);
        expect(controller.loadErrorMessage, isNull);
        expect(controller.isBusy, isFalse);
        expect(harness.categories.cancellations, 1);
        expect(harness.incidents.reviewCancellations, 1);
        harness.session.change(_profile());
        expect(controller.isActive, isFalse);
        controller.updateDraft(title: 'Obsolete edit');
        controller.startCategories();
        expect(controller.draft.title, isEmpty);
        expect(await controller.submit(), isNull);
        expect(harness.categories.channels, hasLength(1));
      },
    );
  }

  test('Ignores a late write completion after switching accounts', () async {
    await harness.readyDraft();
    final response = Completer<Incident>();
    harness.incidents.onCreate = (_) => response.future;
    final result = controller.submit();
    final request = harness.incidents.submissions.single;
    harness.session.change(_profile(id: 'reporter-2'));
    response.complete(request.confirmed());
    expect(await result, isNull);
    expect(controller.createdIncident, isNull);
    expect(controller.successMessage, isNull);
    expect(controller.draft.title, isEmpty);
    expect(controller.submitErrorMessage, isNull);
  });

  test(
    'Cancels a reconciliation and clears state when the view is disposed',
    () async {
      await harness.failedSubmission();
      final review = controller.resumeEditing();
      harness.disposeController();
      expect(await review, isFalse);
      expect(harness.categories.cancellations, 1);
      expect(harness.incidents.reviewCancellations, 1);
      expect(controller.draft.title, isEmpty);
      expect(controller.hasUnconfirmedSubmission, isFalse);
      expect(controller.isActive, isFalse);
    },
  );

  test(
    'Ignores a late failed write after disposal without notifying listeners',
    () async {
      await harness.readyDraft();
      final response = Completer<Incident>();
      harness.incidents.onCreate = (_) => response.future;
      final result = controller.submit();
      harness.disposeController();
      response.completeError(_unavailable());
      expect(await result, isNull);
      expect(controller.submitErrorMessage, isNull);
      expect(controller.draft.title, isEmpty);
      expect(harness.categories.cancellations, 1);
    },
  );

  test('Rejects confirmation for a different incident ID or author', () async {
    await harness.readyDraft();
    harness.incidents.onCreate = (request) async =>
        request.confirmed(id: 'foreign-id');
    expect(await controller.submit(), isNull);
    expect(controller.createdIncident, isNull);
    expect(controller.submitErrorMessage, isNotNull);
    harness.incidents.onCreate = (request) async =>
        request.confirmed(author: 'reporter-2');
    expect(await controller.submit(), isNull);
    expect(controller.createdIncident, isNull);
    expect(controller.hasUnconfirmedSubmission, isTrue);
    expect(harness.incidents.allocations, 1);
  });

  test(
    'Does not observe categories for an initially unauthorized session',
    () async {
      final other = _ReportHarness(
        profile: _profile(role: UserRole.technician),
      );
      addTearDown(other.dispose);
      expect(other.controller.isActive, isFalse);
      expect(other.categories.channels, isEmpty);
      other.controller.updateDraft(title: 'Unauthorized');
      expect(other.controller.draft.title, isEmpty);
      expect(await other.controller.submit(), isNull);
      expect(other.incidents.allocations, 0);
    },
  );
}

class _ReportHarness {
  final _TestIncidentRepository incidents = _TestIncidentRepository();
  final _TestCategoryRepository categories = _TestCategoryRepository();
  late final _TestSession session;
  late final IncidentReportController controller;
  bool _controllerDisposed = false;

  _ReportHarness({UserProfile? profile}) {
    session = _TestSession(profile ?? _profile());
    controller = IncidentReportController(
      incidentRepository: incidents,
      categoryRepository: categories,
      sessionController: session,
      userId: 'reporter-1',
    );
  }

  Future<void> readyDraft() async {
    await categories.emit([_lighting, _plumbing]);
    controller.updateDraft(
      title: '  Broken light  ',
      description: '  Does not turn on.\nSecond line.  ',
      categoryId: 'lighting',
      location: '  Building A  ',
    );
  }

  Future<void> failedSubmission() async {
    await readyDraft();
    incidents.onCreate = (_) => Future.error(_unavailable());
    await controller.submit();
  }

  void disposeController() {
    if (_controllerDisposed) return;
    _controllerDisposed = true;
    controller.dispose();
  }

  Future<void> dispose() async {
    disposeController();
    session.dispose();
    await categories.close();
    await incidents.close();
  }
}

class _TestSession extends ChangeNotifier implements SessionController {
  @override
  UserProfile? profile;

  @override
  SessionStatus status = SessionStatus.authenticated;

  _TestSession(this.profile);

  @override
  String? get errorMessage => null;

  @override
  void start() {}

  void change(
    UserProfile? next, {
    SessionStatus status = SessionStatus.authenticated,
  }) {
    profile = next;
    this.status = status;
    notifyListeners();
  }
}

class _TestCategoryRepository extends Fake implements CategoryRepository {
  final channels = <StreamController<List<Category>>>[];
  int cancellations = 0;

  @override
  Stream<List<Category>> watchActive() {
    final channel = StreamController<List<Category>>.broadcast(
      onCancel: () => cancellations++,
    );
    channels.add(channel);
    return channel.stream;
  }

  Future<void> emit(List<Category> values) async {
    channels.last.add(values);
    await _flush();
  }

  Future<void> close() async {
    for (final channel in channels) {
      await channel.close();
    }
  }
}

class _Submission {
  final String id;
  final String title;
  final String description;
  final String categoryId;
  final String location;
  final int sequence;

  _Submission(
    this.id,
    this.title,
    this.description,
    this.categoryId,
    this.location,
    this.sequence,
  );

  List<String> get values => [id, title, description, categoryId, location];

  Incident confirmed({String? id, String author = 'reporter-1'}) => Incident(
    id: id ?? this.id,
    sequenceNumber: sequence,
    title: title,
    description: description,
    categoryId: categoryId,
    location: location,
    createdAt: DateTime.utc(2026, 10, 21),
    updatedAt: DateTime.utc(2026, 10, 21),
    createdByUserId: author,
  );
}

class _TestIncidentRepository extends Fake implements IncidentRepository {
  int allocations = 0;
  int reviewCancellations = 0;
  Object? allocationError;
  Future<Incident> Function(_Submission)? onCreate;
  final submissions = <_Submission>[];
  final reviews = <StreamController<Incident?>>[];

  @override
  String newIncidentId() {
    allocations++;
    if (allocationError != null) throw allocationError!;
    return 'request-$allocations';
  }

  @override
  Future<Incident> create({
    required String incidentId,
    required String title,
    required String description,
    required String categoryId,
    required String location,
  }) async {
    final request = _Submission(
      incidentId,
      title,
      description,
      categoryId,
      location,
      allocations,
    );
    submissions.add(request);
    return onCreate == null ? request.confirmed() : await onCreate!(request);
  }

  @override
  Stream<Incident?> watchById({required String incidentId}) {
    final channel = StreamController<Incident?>.broadcast(
      onCancel: () => reviewCancellations++,
    );
    reviews.add(channel);
    return channel.stream;
  }

  Future<void> close() async {
    for (final channel in reviews) {
      await channel.close();
    }
  }
}
