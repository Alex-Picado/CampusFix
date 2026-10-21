import '../models/category.dart';
import '../services/category_service.dart';

/// Converts active category documents into immutable lists for report forms.
class CategoryRepository {
  final CategoryService _categoryService;

  /// Creates a repository using the provided category service.
  CategoryRepository({required this._categoryService});

  /// Watches active categories sorted by case-insensitive name and then ID.
  ///
  /// Emits an unmodifiable list, including an empty list when no categories
  /// match. Rejects malformed, blank or inactive records instead of exposing
  /// unusable selections. Preserves valid category names unchanged.
  /// Forwards service and parsing errors; later snapshots can still be emitted.
  /// Cancelling the returned subscription cancels the underlying observation.
  Stream<List<Category>> watchActive() {
    return _categoryService.watchActive().map((documents) {
      final categories = <Category>[];

      for (final entry in documents.entries) {
        final category = Category.fromMap(id: entry.key, data: entry.value);

        if (category.id.trim().isEmpty ||
            category.name.trim().isEmpty ||
            !category.isActive) {
          throw const FormatException('Invalid active category data.');
        }

        categories.add(category);
      }

      categories.sort((first, second) {
        final byName = first.name.toLowerCase().compareTo(
          second.name.toLowerCase(),
        );
        return byName != 0 ? byName : first.id.compareTo(second.id);
      });

      return List<Category>.unmodifiable(categories);
    });
  }
}
