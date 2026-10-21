import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:campusfix/features/catalogs/models/category.dart';
import 'package:campusfix/features/catalogs/repositories/category_repository.dart';
import 'package:campusfix/features/catalogs/services/category_service.dart';

typedef _CategoryDocuments = Map<String, Map<String, dynamic>>;

void main() {
  CategoryRepository repository(Stream<_CategoryDocuments> documents) {
    return CategoryRepository(categoryService: _TestCategoryService(documents));
  }

  test(
    'Sorts active categories by name and uses IDs to break name ties',
    () async {
      final categories = await repository(
        Stream.value({
          'plumbing': {'name': 'Plumbing', 'isActive': true},
          'z-lighting': {'name': 'lighting', 'isActive': true},
          'a-lighting': {'name': 'Lighting', 'isActive': true},
          'connectivity': {'name': 'Connectivity', 'isActive': true},
        }),
      ).watchActive().first;

      expect(categories.map((category) => category.id), [
        'connectivity',
        'a-lighting',
        'z-lighting',
        'plumbing',
      ]);
      expect(categories.map((category) => category.name), [
        'Connectivity',
        'Lighting',
        'lighting',
        'Plumbing',
      ]);
    },
  );

  test('Emits updates and removals from later category snapshots', () async {
    final documents = StreamController<_CategoryDocuments>();
    final results = expectLater(
      repository(documents.stream).watchActive().map(
        (categories) => categories.map((category) => category.id).toList(),
      ),
      emitsInOrder([
        ['lighting'],
        ['connectivity', 'lighting'],
        ['connectivity'],
        emitsDone,
      ]),
    );

    documents.add({
      'lighting': {'name': 'Lighting', 'isActive': true},
    });
    documents.add({
      'lighting': {'name': 'Lighting', 'isActive': true},
      'connectivity': {'name': 'Connectivity', 'isActive': true},
    });
    documents.add({
      'connectivity': {'name': 'Connectivity', 'isActive': true},
    });
    await documents.close();
    await results;
  });

  test(
    'Emits an empty list without supplying demonstration categories',
    () async {
      final categories = await repository(
        Stream.value(<String, Map<String, dynamic>>{}),
      ).watchActive().first;

      expect(categories, isEmpty);
    },
  );

  test('Exposes unmodifiable category lists', () async {
    final categories = await repository(
      Stream.value({
        'lighting': {'name': 'Lighting', 'isActive': true},
      }),
    ).watchActive().first;

    expect(() => categories.clear(), throwsUnsupportedError);
    expect(
      () => categories.add(const Category(id: 'other', name: 'Other')),
      throwsUnsupportedError,
    );
  });

  test('Rejects malformed blank and inactive category selections', () async {
    final invalidDocuments = <_CategoryDocuments>[
      {
        'lighting': {'isActive': true},
      },
      {
        'lighting': {'name': 1, 'isActive': true},
      },
      {
        'lighting': {'name': 'Lighting', 'isActive': 'true'},
      },
      {
        'lighting': {'name': ' ', 'isActive': true},
      },
      {
        ' ': {'name': 'Lighting', 'isActive': true},
      },
      {
        'lighting': {'name': 'Lighting', 'isActive': false},
      },
    ];

    for (final documents in invalidDocuments) {
      await expectLater(
        repository(Stream.value(documents)).watchActive().first,
        throwsA(isA<FormatException>()),
      );
    }
  });

  test(
    'Forwards service errors and can emit a later recovered snapshot',
    () async {
      final documents = StreamController<_CategoryDocuments>();
      final error = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
      );
      final results = expectLater(
        repository(documents.stream).watchActive().map(
          (categories) => categories.map((category) => category.id).toList(),
        ),
        emitsInOrder([
          emitsError(same(error)),
          ['lighting'],
          emitsDone,
        ]),
      );

      documents.addError(error);
      documents.add({
        'lighting': {'name': 'Lighting', 'isActive': true},
      });
      await documents.close();
      await results;
    },
  );

  test(
    'Reports parsing errors without poisoning later valid snapshots',
    () async {
      final documents = StreamController<_CategoryDocuments>();
      final results = expectLater(
        repository(documents.stream).watchActive().map(
          (categories) => categories.map((category) => category.id).toList(),
        ),
        emitsInOrder([
          emitsError(isA<FormatException>()),
          ['lighting'],
          emitsDone,
        ]),
      );

      documents.add({
        'lighting': {'name': false, 'isActive': true},
      });
      documents.add({
        'lighting': {'name': 'Lighting', 'isActive': true},
      });
      await documents.close();
      await results;
    },
  );

  test(
    'Cancelling category observation cancels the underlying subscription',
    () async {
      var cancelled = false;
      final documents = StreamController<_CategoryDocuments>(
        onCancel: () => cancelled = true,
      );
      final subscription = repository(documents.stream)
          .watchActive()
          .listen((_) {});

      await subscription.cancel();

      expect(cancelled, isTrue);
      await documents.close();
    },
  );
}

/// Supplies category snapshots without opening a Firebase connection.
class _TestCategoryService implements CategoryService {
  final Stream<_CategoryDocuments> _documents;

  _TestCategoryService(this._documents);

  @override
  Stream<_CategoryDocuments> watchActive() => _documents;
}
