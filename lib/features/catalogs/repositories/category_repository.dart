import '../models/category.dart';
import '../services/category_service.dart';

/// Validates category data for report selection and catalog administration.
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

  /// Watches all categories, including inactive ones, in name and ID order.
  ///
  /// Administrator-only database rules protect this query. Emits immutable
  /// lists; malformed snapshots raise FormatException and service errors pass
  /// through. Cancelling observation releases the service subscription.
  Stream<List<Category>> watchAll() {
    return _categoryService.watchAll().map((documents) {
      final categories = [
        for (final entry in documents.entries) _parse(entry.key, entry.value),
      ];
      categories.sort((first, second) {
        final byName = first.name.toLowerCase().compareTo(
          second.name.toLowerCase(),
        );
        return byName != 0 ? byName : first.id.compareTo(second.id);
      });
      return List<Category>.unmodifiable(categories);
    });
  }

  /// Watches a category by ID, preserving inactive names in historical reports.
  ///
  /// Emits null when absent. Rejects invalid IDs and malformed records with
  /// FormatException; forwards service errors and subscription cancellation.
  Stream<Category?> watchById(String categoryId) async* {
    _validateId(categoryId);
    yield* _categoryService
        .watchById(categoryId)
        .map((data) => data == null ? null : _parse(categoryId, data));
  }

  /// Creates an active category with a trimmed, nonblank name.
  ///
  /// Returns the acknowledged category. Blank names raise FormatException before
  /// any write; database authorization and connection errors propagate.
  Future<Category> create({required String name}) async {
    final normalized = _normalizeName(name);
    final id = await _categoryService.create(name: normalized);
    return Category(id: id, name: normalized);
  }

  /// Updates a name and active flag while preserving the category ID.
  ///
  /// Trims names and rejects blank names or invalid IDs with FormatException.
  /// Propagates database errors. Never deletes a category or edits incidents.
  Future<void> update({
    required String categoryId,
    required String name,
    required bool isActive,
  }) async {
    _validateId(categoryId);
    final normalized = _normalizeName(name);
    await _categoryService.update(
      categoryId: categoryId,
      name: normalized,
      isActive: isActive,
    );
  }

  Category _parse(String id, Map<String, dynamic> data) {
    _validateId(id);
    final category = Category.fromMap(id: id, data: data);
    _normalizeName(category.name);
    return category;
  }

  String _normalizeName(String name) {
    final normalized = name.trim();
    if (normalized.isEmpty) {
      throw const FormatException('A nonblank category name is required.');
    }
    return normalized;
  }

  void _validateId(String id) {
    if (id.isEmpty ||
        id != id.trim() ||
        id.contains('/') ||
        id == '.' ||
        id == '..' ||
        RegExp(r'^__.*__$').hasMatch(id)) {
      throw const FormatException('A valid category document ID is required.');
    }
  }
}
