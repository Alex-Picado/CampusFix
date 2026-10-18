/// Represents a category used to classify incidents.
class Category {
  /// Unique identifier of the category document.
  final String id;

  /// Category name displayed in the application.
  final String name;

  /// Whether this category can be selected for new incidents.
  final bool isActive;

  /// Creates a category that is active by default.
  const Category({required this.id, required this.name, this.isActive = true});

  /// Returns the category fields to store in Firestore.
  ///
  /// The identifier is used as the document ID and is not included.
  Map<String, dynamic> toMap() {
    return {'name': name, 'isActive': isActive};
  }

  /// Creates a category from a Firestore document ID and its fields.
  ///
  /// Throws a [FormatException] if required fields have invalid types.
  factory Category.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    final name = data['name'];
    final isActive = data['isActive'];

    if (name is! String || isActive is! bool) {
      throw const FormatException('Invalid category data.');
    }

    return Category(id: id, name: name, isActive: isActive);
  }

  /// Returns a new category with the provided changes.
  ///
  /// Preserves the identifier and any fields omitted by the caller.
  Category copyWith({String? name, bool? isActive}) {
    var updatedName = this.name;
    var updatedIsActive = this.isActive;

    if (name != null) {
      updatedName = name;
    }

    if (isActive != null) {
      updatedIsActive = isActive;
    }

    return Category(id: id, name: updatedName, isActive: updatedIsActive);
  }
}
