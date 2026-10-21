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

  @override
  Stream<List<Category>> watchActive() => Stream.multi((sink) {
    activeWatches++;
    if (initial != null) sink.add(initial!);
    final subscription = changes.stream.listen(
      sink.add,
      onError: sink.addError,
    );
    sink.onCancel = () {
      activeWatches--;
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

  TestReportIncidents({String Function()? author})
    : author = author ?? (() => 'campus-user');

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
    return incident;
  }

  @override
  Stream<Incident?> watchById({required String incidentId}) {
    reviews++;
    return reviewError == null
        ? Stream.value(saved[incidentId])
        : Stream.error(reviewError!);
  }
}
