/// Defines the available incident priorities.
enum IncidentPriority {
  /// An incident with low urgency.
  low('BAJA'),

  /// An incident with moderate urgency.
  medium('MEDIA'),

  /// An incident requiring prompt attention.
  high('ALTA');

  /// Value stored in Firestore.
  final String value;

  /// Creates a priority with its stored value.
  const IncidentPriority(this.value);

  /// Returns the priority associated with a stored value.
  ///
  /// Throws a [FormatException] if the value is unsupported.
  static IncidentPriority fromValue(String value) {
    for (final priority in IncidentPriority.values) {
      if (priority.value == value) {
        return priority;
      }
    }
    throw FormatException('Unsupported incident priority: $value');
  }
}
