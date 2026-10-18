import 'package:flutter_test/flutter_test.dart';
import 'package:campusfix/features/catalogs/models/category.dart';

void main() {
  test('Rejects text values for the active flag', () {
    expect(
      () => Category.fromMap(
        id: 'category-1',
        data: {'name': 'Connectivity', 'isActive': 'false'},
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('Deactivates a copy without changing identity or original', () {
    const original = Category(id: 'category-1', name: 'Connectivity');

    final updated = original.copyWith(isActive: false);

    expect(updated.id, original.id);
    expect(updated.name, original.name);
    expect(updated.isActive, false);
    expect(original.isActive, true);
  });
}
