import 'package:campusfix/features/catalogs/repositories/category_repository.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/category_service.dart';

void main() {
  late TestCategoryService service;
  late CategoryRepository repository;
  setUp(() {
    service = TestCategoryService();
    repository = CategoryRepository(categoryService: service);
  });
  tearDown(() => service.close());

  test(
    'Full catalog includes inactive records in deterministic immutable order',
    () async {
      service.documents.addAll({
        'z': {'name': 'Lighting', 'isActive': true},
        'a': {'name': 'lighting', 'isActive': false},
        'b': {'name': 'Accessibility', 'isActive': true},
      });
      final rows = await repository.watchAll().first;
      expect(rows.map((row) => row.id), ['b', 'a', 'z']);
      expect(rows[1].isActive, false);
      expect(() => rows.clear(), throwsUnsupportedError);
    },
  );

  test(
    'Individual observation retains an inactive name and emits later renames',
    () async {
      service.documents['old'] = {'name': 'Old lighting', 'isActive': false};
      final events = <String?>[];
      final subscription = repository
          .watchById('old')
          .listen((row) => events.add(row?.name));
      await Future<void>.delayed(Duration.zero);
      await repository.update(
        categoryId: 'old',
        name: '  Lighting  ',
        isActive: false,
      );
      await Future<void>.delayed(Duration.zero);
      service.documents.remove('old');
      service.changes.add(null);
      await Future<void>.delayed(Duration.zero);
      expect(events, ['Old lighting', 'Lighting', null]);
      await subscription.cancel();
      expect(service.activeIdWatches, 0);
    },
  );

  test(
    'Creation trims names and returns an acknowledged active category',
    () async {
      final category = await repository.create(name: '  Iluminación  ');
      expect(category.name, 'Iluminación');
      expect(category.isActive, true);
      expect(service.documents[category.id], {
        'name': 'Iluminación',
        'isActive': true,
      });
    },
  );

  test(
    'Updating preserves the ID while changing the normalized name and flag',
    () async {
      service.documents['lighting'] = {'name': 'Lighting', 'isActive': true};
      await repository.update(
        categoryId: 'lighting',
        name: '  Lights ',
        isActive: false,
      );
      expect(service.documents.keys, ['lighting']);
      expect(service.documents['lighting'], {
        'name': 'Lights',
        'isActive': false,
      });
      expect(await repository.watchActive().first, isEmpty);
    },
  );

  test('Blank names and invalid IDs never reach the write service', () async {
    await expectLater(repository.create(name: ' \t '), throwsFormatException);
    await expectLater(
      repository.update(categoryId: 'ok', name: ' ', isActive: true),
      throwsFormatException,
    );
    for (final id in ['', ' ', ' a', 'a/b', '.', '..', '__private__']) {
      await expectLater(
        repository.update(categoryId: id, name: 'Valid', isActive: true),
        throwsFormatException,
      );
      await expectLater(repository.watchById(id).first, throwsFormatException);
    }
    expect(service.creates, 0);
    expect(service.updates, 0);
    expect(service.activeIdWatches, 0);
  });

  test(
    'Malformed snapshots fail explicitly and a subsequent snapshot recovers',
    () async {
      service.loadImmediately = false;
      final expectation = expectLater(
        repository.watchAll(),
        emitsInOrder([
          emitsError(isA<FormatException>()),
          predicate<List<dynamic>>((rows) => rows.length == 1),
        ]),
      );
      await Future<void>.delayed(Duration.zero);
      service.documents['bad'] = {'name': ' ', 'isActive': false};
      service.changes.add(null);
      await Future<void>.delayed(Duration.zero);
      service.documents['bad'] = {'name': 'Recovered', 'isActive': false};
      service.changes.add(null);
      await expectation;
    },
  );

  test('Write failures propagate without returning success', () async {
    final error = FirebaseException(
      plugin: 'cloud_firestore',
      code: 'permission-denied',
    );
    service.writeError = error;
    await expectLater(
      repository.create(name: 'Lighting'),
      throwsA(same(error)),
    );
    expect(service.documents, isEmpty);
  });

  test(
    'Cancelling the full catalog releases its service observation',
    () async {
      final subscription = repository.watchAll().listen((_) {});
      await Future<void>.delayed(Duration.zero);
      expect(service.activeAllWatches, 1);
      await subscription.cancel();
      expect(service.activeAllWatches, 0);
    },
  );
}
