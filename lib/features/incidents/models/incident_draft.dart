/// Stores editable report fields in memory without persistence metadata.
class IncidentDraft {
  /// Untrimmed title entered in the report form.
  final String title;

  /// Untrimmed description, including line breaks.
  final String description;

  /// Selected category identity, or null before a valid selection.
  final String? categoryId;

  /// Untrimmed campus location entered in the report form.
  final String location;

  /// Creates an empty draft unless field values are supplied.
  const IncidentDraft({
    this.title = '',
    this.description = '',
    this.categoryId,
    this.location = '',
  });

  /// Returns a separate draft, with explicit clearing of the category selection.
  IncidentDraft copyWith({
    String? title,
    String? description,
    String? categoryId,
    String? location,
    bool clearCategory = false,
  }) {
    return IncidentDraft(
      title: title ?? this.title,
      description: description ?? this.description,
      categoryId: clearCategory ? null : categoryId ?? this.categoryId,
      location: location ?? this.location,
    );
  }

  /// Trims report text while preserving the selected document identity.
  IncidentDraft normalized() => IncidentDraft(
    title: title.trim(),
    description: description.trim(),
    categoryId: categoryId,
    location: location.trim(),
  );
}
