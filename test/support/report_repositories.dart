import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:campusfix/features/catalogs/models/category.dart';
import 'package:campusfix/features/catalogs/repositories/category_repository.dart';
import 'package:campusfix/features/incidents/models/incident.dart';
import 'package:campusfix/features/incidents/repositories/incident_repository.dart';

/// Controls category loading and updates without initializing Firebase.
class TestReportCategories extends Fake implements CategoryRepository {
  List<Category>? initial = const [
    Category(id: 'lighting', name: 'Iluminación'),
  ];
  final changes = StreamController<List<Category>>.broadcast();
  int activeWatches = 0;
  int activeByIdWatches = 0;

  @override
  Stream<List<Category>> watchAll() => Stream.multi((sink) {
    if (initial != null) sink.add(List.unmodifiable(initial!));
    final subscription = changes.stream.listen(
      sink.add,
      onError: sink.addError,
    );
    sink.onCancel = subscription.cancel;
  });

  @override
  Stream<List<Category>> watchActive() => Stream.multi((sink) {
    activeWatches++;
    if (initial != null) {
      sink.add(List.unmodifiable(initial!.where((row) => row.isActive)));
    }
    final subscription = changes.stream.listen(
      (rows) => sink.add(List.unmodifiable(rows.where((row) => row.isActive))),
      onError: sink.addError,
    );
    sink.onCancel = () {
      activeWatches--;
      subscription.cancel().ignore();
    };
  });

  @override
  Stream<Category?> watchById(String categoryId) => Stream.multi((sink) {
    activeByIdWatches++;
    void emit(List<Category> rows) =>
        sink.add(rows.where((row) => row.id == categoryId).firstOrNull);
    if (initial != null) emit(initial!);
    final subscription = changes.stream.listen(emit, onError: sink.addError);
    sink.onCancel = () {
      activeByIdWatches--;
      subscription.cancel().ignore();
    };
  });

  Future<void> close() => changes.close();
}

/// Controls report acknowledgements and checks through real presentation code.
class TestReportIncidents extends Fake implements IncidentRepository {
  final String Function() author;
  final requests = <Map<String, String>>[];
  final saved = <String, Incident>{};
  Completer<void>? blocker;
  Object? createError;
  Object? reviewError;
  bool saveBeforeError = false;
  int allocations = 0;
  int reviews = 0;
  bool loadOwnImmediately = true;
  int activeOwnWatches = 0;
  final ownWatchUserIds = <String>[];
  final ownChanges = StreamController<List<Incident>>.broadcast();

  TestReportIncidents({String Function()? author})
    : author = author ?? (() => 'campus-user');

  @override
  Stream<List<Incident>> watchAll() => Stream.multi((sink) {
    sink.add(List.unmodifiable(saved.values));
    final sub = ownChanges.stream.listen(sink.add, onError: sink.addError);
    sink.onCancel = sub.cancel;
  });

  @override
  Stream<List<Incident>> watchAssigned({required String userId}) =>
      watchAll().map(
        (rows) => List.unmodifiable(
          rows.where((row) => row.assignedTechnicianId == userId),
        ),
      );

  @override
  String newIncidentId() => 'report-${++allocations}';

  @override
  Future<Incident> create({
    required String incidentId,
    required String title,
    required String description,
    required String categoryId,
    required String location,
  }) async {
    final userId = author();
    requests.add({
      'id': incidentId,
      'title': title,
      'description': description,
      'categoryId': categoryId,
      'location': location,
    });
    await blocker?.future;
    final incident =
        saved[incidentId] ??
        Incident(
          id: incidentId,
          sequenceNumber: allocations,
          title: title,
          description: description,
          categoryId: categoryId,
          location: location,
          createdAt: DateTime.utc(2026, 10, 21),
          updatedAt: DateTime.utc(2026, 10, 21),
          createdByUserId: userId,
        );
    if (createError != null) {
      if (saveBeforeError) saved[incidentId] = incident;
      throw createError!;
    }
    saved[incidentId] = incident;
    ownChanges.add(saved.values.toList());
    return incident;
  }

  @override
  Stream<List<Incident>> watchOwn({required String userId}) => Stream.multi((
    sink,
  ) {
    ownWatchUserIds.add(userId);
    activeOwnWatches++;
    void emit(List<Incident> reports) {
      final own = reports
          .where((incident) => incident.createdByUserId == userId)
          .toList();
      own.sort((first, second) {
        final byDate = second.createdAt.compareTo(first.createdAt);
        if (byDate != 0) return byDate;
        final bySequence = second.sequenceNumber.compareTo(
          first.sequenceNumber,
        );
        return bySequence != 0 ? bySequence : first.id.compareTo(second.id);
      });
      sink.add(own);
    }

    if (loadOwnImmediately) emit(saved.values.toList());
    final subscription = ownChanges.stream.listen(emit, onError: sink.addError);
    sink.onCancel = () {
      activeOwnWatches--;
      subscription.cancel().ignore();
    };
  });

  @override
  Stream<Incident?> watchById({required String incidentId}) {
    reviews++;
    return reviewError == null
        ? Stream.value(saved[incidentId])
        : Stream.error(reviewError!);
  }

  Future<void> close() => ownChanges.close();
}
