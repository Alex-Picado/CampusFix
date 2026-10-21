/// Represents an immutable progress entry on an incident.
class IncidentProgress {
  /// Identifier of the progress document within its incident.
  final String id;

  /// Identifier of the account that recorded the progress.
  final String authorUserId;

  /// Confirmed time when the progress was recorded.
  final DateTime createdAt;

  /// Progress description displayed as a follow-up comment.
  final String description;

  /// Creates a progress entry with its author and confirmed date.
  const IncidentProgress({
    required this.id,
    required this.authorUserId,
    required this.createdAt,
    required this.description,
  });

  /// Returns the progress fields without duplicating the document ID.
  ///
  /// Dates remain [DateTime] values at the model boundary.
  Map<String, dynamic> toMap() {
    return {
      'authorUserId': authorUserId,
      'createdAt': createdAt,
      'description': description,
    };
  }

  /// Parses progress fields after timestamp normalization by the service.
  ///
  /// Preserves valid description text without trimming it.
  /// Throws a [FormatException] for blank identifiers or description,
  /// invalid types, or a missing or unresolved date.
  factory IncidentProgress.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    final authorUserId = data['authorUserId'];
    final createdAt = data['createdAt'];
    final description = data['description'];

    if (id.trim().isEmpty ||
        authorUserId is! String ||
        authorUserId.trim().isEmpty ||
        createdAt is! DateTime ||
        description is! String ||
        description.trim().isEmpty) {
      throw const FormatException('Invalid incident progress data.');
    }

    return IncidentProgress(
      id: id,
      authorUserId: authorUserId,
      createdAt: createdAt,
      description: description,
    );
  }
}
