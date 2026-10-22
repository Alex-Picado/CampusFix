import 'dart:async';

import 'package:campusfix/features/catalogs/services/category_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Controls category snapshots and acknowledgements through the real repository.
class TestCategoryService extends Fake implements CategoryService {
  final documents = <String, Map<String, dynamic>>{};
  final changes = StreamController<void>.broadcast();
  int activeAllWatches = 0, allCalls = 0, activeIdWatches = 0;
  int creates = 0, updates = 0;
  bool loadImmediately = true;
  Completer<void>? blocker;
  Object? writeError;

  Stream<T> _watch<T>(T Function() read, void Function(int) count) =>
      Stream.multi((sink) {
        count(1);
        if (loadImmediately) sink.add(read());
        final subscription = changes.stream.listen(
          (_) => sink.add(read()),
          onError: sink.addError,
        );
        sink.onCancel = () {
          count(-1);
          subscription.cancel().ignore();
        };
      });

  @override
  Stream<Map<String, Map<String, dynamic>>> watchAll() {
    allCalls++;
    return _watch(
      () => Map.of(documents),
      (delta) => activeAllWatches += delta,
    );
  }

  @override
  Stream<Map<String, Map<String, dynamic>>> watchActive() => _watch(
    () => Map.fromEntries(
      documents.entries.where((row) => row.value['isActive'] == true),
    ),
    (_) {},
  );

  @override
  Stream<Map<String, dynamic>?> watchById(String categoryId) =>
      _watch(() => documents[categoryId], (delta) => activeIdWatches += delta);

  @override
  Future<String> create({required String name}) async {
    final id = 'new-${++creates}';
    await blocker?.future;
    if (writeError != null) throw writeError!;
    documents[id] = {'name': name, 'isActive': true};
    changes.add(null);
    return id;
  }

  @override
  Future<void> update({
    required String categoryId,
    required String name,
    required bool isActive,
  }) async {
    updates++;
    await blocker?.future;
    if (writeError != null) throw writeError!;
    if (!documents.containsKey(categoryId)) {
      throw StateError('Missing category.');
    }
    documents[categoryId] = {'name': name, 'isActive': isActive};
    changes.add(null);
  }

  Future<void> close() => changes.close();
}
